-- Modules/Checkpoints/Editor.lua
-- Panel for the per-dungeon forces targets, opened via "/mauimpt checkpoints".
-- The window itself is ns.Panel; this file only supplies the list and the page.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Checkpoints = Addon:GetModule("Checkpoints")

local Utils = Addon.Utils

local SHARE = "__share__" -- list key for the Import / Export page

-- Current season's maps, plus the active key should the cache miss it.
local function seasonList()
    local list = Utils.GetSeasonMaps()
    local active = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
        and C_ChallengeMode.GetActiveChallengeMapID()
    if not active then return list end
    for _, mapID in ipairs(list) do
        if mapID == active then return list end
    end
    list[#list + 1] = active
    return list
end

-- List ---------------------------------------------------------------------

local function dungeonEntry(mapID)
    return {
        key = tostring(mapID),
        text = Utils.GetMapName(mapID),
        icon = Utils.GetMapTexture(mapID),
    }
end

local function buildList()
    local L = ns.L
    local entries = { { header = true, text = L["Current season"] } }

    for _, mapID in ipairs(seasonList()) do
        entries[#entries + 1] = dungeonEntry(mapID)
    end

    local old = Utils.GetOutdatedMaps(Checkpoints.Data.GetDungeons())
    if #old > 0 then
        entries[#entries + 1] = { header = true, text = L["Outdated"],
            right = format("%d", #old) }
        for _, mapID in ipairs(old) do
            local entry = dungeonEntry(mapID)
            entry.dim = true
            entries[#entries + 1] = entry
        end
    end

    entries[#entries + 1] = { header = true, text = L["Other"] }
    entries[#entries + 1] = {
        key = SHARE,
        text = L["Import / Export"],
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Menu\\share",
    }
    return entries
end

-- Page: one dungeon -------------------------------------------------------

-- Boss index, target and the remove button share a line: none of the three
-- carries an explanation, so the renderer keeps them in its column flow.
local function sectionArgs(mapID, bySection)
    local L = ns.L
    local args = {}
    for i, section in ipairs(bySection) do
        local base = i * 10
        args["boss" .. i] = {
            type = "input", order = base, width = 1,
            name = L["Boss"] .. " #",
            get = function() return tostring(section.bossIndex or 1) end,
            set = function(_, text) Checkpoints.Data.SetSectionBossIndex(mapID, i, text) end,
        }
        args["pct" .. i] = {
            type = "input", order = base + 1, width = 1,
            name = L["Target %"],
            get = function() return tostring(section.targetPct or 0) end,
            set = function(_, text) Checkpoints.Data.SetSectionTargetPct(mapID, i, text) end,
        }
        args["del" .. i] = {
            type = "execute", order = base + 2, width = 1,
            name = L["Remove"],
            func = function()
                Checkpoints.Data.RemoveSection(mapID, i)
                Checkpoints.Editor:Refresh()
            end,
        }
        args["break" .. i] = Addon:OptLine(base + 3)
    end

    args.add = {
        type = "execute", order = 900, width = 1.5,
        name = L["Add boss target"],
        func = function()
            Checkpoints.Data.AddSection(mapID, #bySection + 1, 0)
            Checkpoints.Editor:Refresh()
        end,
    }
    return args
end

local function ponrArgs(mapID, ponr)
    local L = ns.L
    local args = {}
    for i, point in ipairs(ponr) do
        local base = i * 10
        args["pct" .. i] = {
            type = "input", order = base, width = 1,
            name = L["Minimum %"],
            get = function() return tostring(point.pct or 0) end,
            set = function(_, text) Checkpoints.Data.SetPoNRPct(mapID, i, text) end,
        }
        args["del" .. i] = {
            type = "execute", order = base + 1, width = 1,
            name = L["Remove"],
            func = function()
                Checkpoints.Data.RemovePoNR(mapID, i)
                Checkpoints.Editor:Refresh()
            end,
        }
        args["break" .. i] = Addon:OptLine(base + 2)
    end

    args.add = {
        type = "execute", order = 900, width = 1.5,
        name = L["Add point of no return"],
        func = function()
            Checkpoints.Data.AddPoNR(mapID, 0)
            Checkpoints.Editor:Refresh()
        end,
    }
    return args
end

local function dungeonPage(mapID)
    local L = ns.L
    -- Get, not GetOrCreate: browsing a dungeon must not store an empty record.
    -- The Add buttons create the entry on first use.
    local entry = Checkpoints.Data.Get(mapID)
    local bySection = (entry and entry.bySection) or {}
    local ponr = (entry and entry.ponr) or {}

    return {
        type = "group", name = Utils.GetMapName(mapID),
        args = {
            sections = {
                type = "group", inline = true, order = 1,
                name = L["Boss section targets"],
                args = sectionArgs(mapID, bySection),
            },
            ponr = {
                type = "group", inline = true, order = 2,
                name = L["Point of No Return"],
                args = ponrArgs(mapID, ponr),
            },
        },
    }
end

-- Page: import and export --------------------------------------------------

-- Every refresh asks, so the last decode is kept until the string changes.
local peekedText, peekedImport

local function peekImport()
    local text = Checkpoints.Editor.importText or ""
    if text ~= peekedText then
        peekedText = text
        peekedImport = text ~= "" and Checkpoints.Data.Decode(text) or nil
    end
    return peekedImport
end

local function overwritten(decoded)
    local count = 0
    for mapID in pairs(decoded.maps) do
        if Checkpoints.Data.Get(mapID) then count = count + 1 end
    end
    return count
end

-- What the import box shows in place of a valid string; nil while there is none.
local function importPreview()
    local decoded = peekImport()
    if not decoded then return nil end
    local L = ns.L

    local names = {}
    for mapID in pairs(decoded.maps) do names[#names + 1] = Utils.GetMapName(mapID) end
    sort(names)
    local count = tostring(decoded.count)
    local taken = overwritten(decoded)
    if taken > 0 then
        count = count .. "  |cfff09020" .. format(L["(%d configured, will be overwritten)"], taken) .. "|r"
    end
    return strjoin("\n", Utils.ShareLine(L["Dungeons"], count), table.concat(names, ", "),
        Utils.ShareMetaLines(decoded.meta))
end

local function sharePage()
    local L = ns.L
    local Editor = Checkpoints.Editor

    local function generate()
        return (Editor.exportAsLua and Checkpoints.Data.ExportPlain()
            or Checkpoints.Data.Export()) or ""
    end

    return {
        type = "group", name = L["Import / Export"],
        args = {
            export = {
                type = "group", inline = true, order = 1, name = L["Export"],
                args = {
                    note = { type = "description", order = 1,
                        name = L["Click Export to generate a shareable string of all your checkpoints, then copy it."] },
                    plain = {
                        type = "toggle", order = 2,
                        name = L["Export as Lua table"],
                        desc = L["Output the checkpoints as readable Lua code (for use in an addon) instead of a shareable string. This format cannot be re-imported."],
                        get = function() return Editor.exportAsLua == true end,
                        set = function(_, value)
                            Editor.exportAsLua = value and true or false
                            -- Regenerate an already visible export in the new format.
                            if Editor.exportText and Editor.exportText ~= "" then
                                Editor.exportText = generate()
                            end
                        end,
                    },
                    run = {
                        type = "execute", order = 3, width = 1.5,
                        name = L["Export"],
                        func = function() Editor.exportText = generate() end,
                    },
                    nl = Addon:OptLine(4),
                    text = {
                        type = "input", order = 5, width = "full", multiline = true,
                        name = L["Export string"],
                        get = function() return Editor.exportText or "" end,
                        set = function() end,
                        arg = "readOnly", -- UI/Options: select and copy only, no Accept
                    },
                },
            },
            import = {
                type = "group", inline = true, order = 2, name = L["Import"],
                args = {
                    note = { type = "description", order = 1,
                        name = L["Paste a checkpoint string, check its details and click Import."] },
                    text = {
                        type = "input", order = 2, width = "full", multiline = true,
                        name = function()
                            if (Editor.importText or "") ~= "" and not peekImport() then
                                return L["Import string"] .. "  |cfff04a4a" .. L["Not a valid checkpoint string."] .. "|r"
                            end
                            return L["Import string"]
                        end,
                        arg = "live", -- UI/Options: stored while pasting, so the box turns into the preview
                        -- A valid string is shown as its details; the string itself stays in importText.
                        get = function() return importPreview() or Editor.importText or "" end,
                        set = function(_, text)
                            local preview = importPreview()
                            if preview then
                                if text == preview then return end
                                -- Pasted beside the preview instead of over it (Ace's box does not select all).
                                local from, to = text:find(preview, 1, true)
                                if from then text = text:sub(1, from - 1) .. text:sub(to + 1) end
                            end
                            Editor.importText = strtrim(text)
                        end,
                    },
                    run = {
                        type = "execute", order = 3, width = 1.5,
                        name = L["Import"],
                        disabled = function() return peekImport() == nil end,
                        confirm = function()
                            local decoded = peekImport()
                            return decoded and overwritten(decoded) > 0
                                and L["Import checkpoints? Matching dungeons will be overwritten."] or false
                        end,
                        func = function()
                            local ok, res = Checkpoints.Data.Import(Editor.importText or "")
                            if ok then
                                Addon:Info(L["Imported checkpoints for %d dungeon(s)."], res or 0)
                                Editor.importText = ""
                                -- New dungeons may have appeared in the list.
                                Editor:Refresh()
                            else
                                Addon:Error(L["Import failed: %s"], tostring(res))
                            end
                        end,
                    },
                },
            },
        },
    }
end

-- Banner -------------------------------------------------------------------

-- Headline of a dungeon page: what is configured for this map.
local function dungeonBanner(mapID)
    local entry = Checkpoints.Data.Get(mapID)
    local sections = (entry and entry.bySection) or {}
    local ponr = (entry and entry.ponr) or {}
    return {
        title = Utils.GetMapName(mapID),
        sub = format(ns.L["%d boss target(s), %d point(s) of no return"],
            #sections, #ponr),
    }
end

Checkpoints.Editor = ns.Panel.New("checkpoints", {
    title = function() return "MAUI M+ Timer \226\128\148 " .. ns.L["Edit checkpoints"] end,
    globalName = "MauiMPlusTimerCheckpointsPanel",
    width = 900, height = 620,
    BuildList = buildList,
    BuildPage = function(_, key)
        if key == SHARE then return sharePage() end
        local mapID = tonumber(key)
        return mapID and dungeonPage(mapID) or nil
    end,
    BuildBanner = function(_, key)
        local mapID = tonumber(key)
        return mapID and dungeonBanner(mapID) or nil
    end,
    -- The dungeon being run, if any; otherwise Import / Export.
    Default = function()
        local active = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
            and C_ChallengeMode.GetActiveChallengeMapID()
        return active and tostring(active) or SHARE
    end,
})
