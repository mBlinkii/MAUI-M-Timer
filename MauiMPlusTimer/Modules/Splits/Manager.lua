-- Modules/Splits/Manager.lua
-- Panel for viewing and cleaning up stored run times, via "/mauimpt splits".
-- The window itself is ns.Panel; this file only supplies the list and the page.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Splits = Addon:GetModule("Splits")

local Utils = Addon.Utils

local OUTDATED = "__outdated__" -- list key for the bulk cleanup page

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

    for _, mapID in ipairs(Utils.GetSeasonMaps()) do
        entries[#entries + 1] = dungeonEntry(mapID)
    end

    local old = Utils.GetOutdatedMaps(Splits.Data.GetDungeons())
    if #old > 0 then
        entries[#entries + 1] = { header = true, text = L["Outdated"],
            right = format("%d", #old) }
        for _, mapID in ipairs(old) do
            local entry = dungeonEntry(mapID)
            entry.dim = true
            entries[#entries + 1] = entry
        end
        entries[#entries + 1] = { key = OUTDATED, text = L["Delete outdated data"],
            dim = true }
    end
    return entries
end

-- Page ---------------------------------------------------------------------

-- One card per stored run, in the shape of the banner above the page: the key
-- level and the run's particulars on the left, the total on the right, and the
-- bar for the time against the dungeon's limit.
local function runNode(mapID, level, run, best, limit, order)
    local L = ns.L

    local timed -- nil when the dungeon has no known time limit
    if limit and run.total then timed = (run.total <= limit) end

    local meta = { (run.deaths or 0) .. " " .. L["Deaths"] }
    if run.date then meta[#meta + 1] = date("%Y-%m-%d %H:%M", run.date) end

    local splits = {}
    for i, t in ipairs(run.sections or {}) do
        if t then
            splits[#splits + 1] = L["Boss"] .. " " .. i .. ": " .. Utils.FormatTime(t)
        end
    end

    local tag = Utils.KeystoneLevelTag(level, true)
    local total = Utils.FormatTime(run.total or 0)

    return {
        type = "run", order = order,
        -- The tooltip's heading; the card itself carries no label.
        name = tag .. "  " .. total,
        desc = L["Removes only this run."],
        tag = tag,
        badge = (run == best) and L["Best"] or "",
        total = total,
        totalColor = (timed == nil and "muted") or (timed and "on" or "danger"),
        delta = (limit and run.total) and Utils.FormatDelta(run.total - limit) or "",
        meta = table.concat(meta, "   \194\183   "),
        splits = table.concat(splits, "   "),
        progress = (limit and run.total) and (run.total / limit) or nil,
        confirm = true,
        confirmText = L["Removes only this run."],
        func = function()
            Splits.Data.DeleteRun(mapID, level, run)
            Splits.Manager:Refresh()
        end,
    }
end

local function outdatedPage()
    local L = ns.L
    local old = Utils.GetOutdatedMaps(Splits.Data.GetDungeons())
    return {
        type = "group", name = L["Outdated"],
        args = {
            note = { type = "description", order = 1,
                name = L["Dungeons from earlier seasons that still have stored data."] },
            wipe = {
                type = "execute", order = 2,
                name = L["Delete outdated data"],
                desc = L["Removes all stored times of dungeons outside the current season. Cannot be undone."],
                confirm = true,
                confirmText = L["Removes all stored times of dungeons outside the current season. Cannot be undone."],
                disabled = function() return #old == 0 end,
                func = function()
                    for _, mapID in ipairs(old) do Splits.Data.DeleteDungeon(mapID) end
                    Addon:Info(L["Removed the stored times of %d outdated dungeon(s)."], #old)
                    Splits.Manager:Refresh()
                end,
            },
        },
    }
end

local function dungeonPage(mapID)
    local L = ns.L
    local args = {}
    local limit = Utils.GetMapTimeLimit(mapID)
    local levels = Splits.Data.GetLevels(mapID)
    local order = 0

    if #levels == 0 then
        args.empty = { type = "description", order = 1, name = L["No data"] }
    else
        local runs = { type = "group", inline = true, name = L["Stored runs"], order = 1, args = {} }
        -- Highest levels first.
        for i = #levels, 1, -1 do
            local level = levels[i]
            local list, best = Splits.Data.GetRuns(mapID, level)
            for _, run in ipairs(list) do
                order = order + 1
                runs.args["run" .. order] = runNode(mapID, level, run, best, limit, order)
            end
        end
        args.runs = runs
    end

    return { type = "group", name = Utils.GetMapName(mapID), args = args }
end

-- Wiping the dungeon belongs to the page, not into it: as the last row it
-- scrolled out of sight behind a long list of runs.
local function dungeonAction(mapID)
    local L = ns.L
    local levels = Splits.Data.GetLevels(mapID)
    return {
        type = "execute",
        name = L["Delete dungeon"],
        desc = L["Removes all stored times for this dungeon (every key level). Cannot be undone."],
        confirm = true,
        confirmText = L["Removes all stored times for this dungeon (every key level). Cannot be undone."],
        disabled = function() return #levels == 0 end,
        func = function()
            Splits.Data.DeleteDungeon(mapID)
            Splits.Manager:Refresh()
        end,
    }
end

-- Banner -------------------------------------------------------------------

-- Headline of a dungeon page: the highest key that beat the timer, and within
-- that key the best time. A faster run on a lower key is not the better result,
-- so it only stands in when nothing was timed at all.
local function dungeonBanner(mapID)
    local L = ns.L
    local limit = Utils.GetMapTimeLimit(mapID)

    local count = 0
    local best, bestLevel       -- highest timed key, best time within it
    local fastest, fastestLevel -- fallback while nothing has been timed

    for _, level in ipairs(Splits.Data.GetLevels(mapID)) do
        local list = Splits.Data.GetRuns(mapID, level)
        count = count + #list
        for _, run in ipairs(list) do
            if run.total then
                if not fastest or run.total < fastest.total then
                    fastest, fastestLevel = run, level
                end
                if limit and run.total <= limit
                    and (not best or level > bestLevel
                        or (level == bestLevel and run.total < best.total)) then
                    best, bestLevel = run, level
                end
            end
        end
    end

    local run, level = best, bestLevel
    if not run then run, level = fastest, fastestLevel end

    local data = {
        title = Utils.GetMapName(mapID),
        tag = level and Utils.KeystoneLevelTag(level, true) or "",
        sub = limit and format(L["%d run(s), limit %s"], count, Utils.FormatTime(limit))
            or format(L["%d run(s)"], count),
    }

    if not run then
        data.big = "\226\128\148" -- em dash
        data.bigSub = L["No data"]
        return data
    end

    data.big = Utils.FormatTime(run.total)
    data.bigColor = (run == best) and "on" or "danger"
    data.bigSub = limit and Utils.FormatDelta(run.total - limit) or L["Best"]
    data.progress = limit and (run.total / limit) or nil
    return data
end

Splits.Manager = ns.Panel.New("splits", {
    title = function() return "MAUI M+ Timer \226\128\148 " .. ns.L["Manage times"] end,
    globalName = "MauiMPlusTimerSplitsPanel",
    width = 900, height = 620,
    BuildList = buildList,
    BuildPage = function(_, key)
        if key == OUTDATED then return outdatedPage() end
        local mapID = tonumber(key)
        return mapID and dungeonPage(mapID) or nil
    end,
    BuildBanner = function(_, key)
        local mapID = tonumber(key)
        return mapID and dungeonBanner(mapID) or nil
    end,
    BuildAction = function(_, key)
        local mapID = tonumber(key)
        return mapID and dungeonAction(mapID) or nil
    end,
})
