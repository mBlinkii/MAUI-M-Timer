-- Modules/Splits/Manager.lua
-- Panel for viewing and cleaning up stored run times, via "/mauimpt splits".

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Splits = Addon:GetModule("Splits")

local AceGUI = LibStub("AceGUI-3.0")

local Manager = {}
Splits.Manager = Manager

local Utils = Addon.Utils

local OUTDATED = "__outdated__" -- sentinel tree value for the previous seasons' group

local function dungeonNode(mapID)
    return {
        value = tostring(mapID),
        text = Utils.GetMapName(mapID),
        icon = Utils.GetMapTexture(mapID),
    }
end

-- Current season at the top level, everything else grouped as outdated; flat
-- per dungeon, because selecting one shows all its runs as cards.
local function buildTree()
    local L = ns.L
    local tree = {}
    for _, mapID in ipairs(Utils.GetSeasonMaps()) do
        tree[#tree + 1] = dungeonNode(mapID)
    end

    local old = Utils.GetOutdatedMaps(Splits.Data.GetDungeons())
    if #old > 0 then
        local children = {}
        for _, mapID in ipairs(old) do children[#children + 1] = dungeonNode(mapID) end
        tree[#tree + 1] = {
            value = OUTDATED,
            text = "|cff888888" .. L["Outdated"] .. "|r",
            children = children,
        }
    end
    return tree
end

local COLOR_INTIME  = { 0.2, 0.8, 0.2, 1 }
local COLOR_OVER    = { 0.85, 0.2, 0.2, 1 }
local COLOR_UNKNOWN = { 0.45, 0.45, 0.45, 1 }

local function addRunCard(scroll, mapID, level, run, best, limit)
    local L = ns.L

    local timed -- nil when the dungeon has no known time limit
    if limit and run.total then timed = (run.total <= limit) end
    local color = (timed == nil and COLOR_UNKNOWN) or (timed and COLOR_INTIME or COLOR_OVER)
    -- Signed against the dungeon timer: "-1:20" is time to spare.
    local delta = (limit and run.total) and Utils.FormatDelta(run.total - limit) or ""

    local card = AceGUI:Create("MMTRunCard")
    card:SetFullWidth(true)
    card:SetLayout("Flow")
    card:SetBorderColor(unpack(color))
    scroll:AddChild(card)

    local lines = {}
    lines[#lines + 1] = Utils.KeystoneLevelTag(level, true) .. "    |cffffffff" .. Utils.FormatTime(run.total or 0) .. "|r"
        .. (delta ~= "" and ("    " .. delta) or "")
        .. (run == best and ("  |cffffd200(" .. L["Best"] .. ")|r") or "")
    local meta = { (run.deaths or 0) .. " " .. L["Deaths"] }
    if run.date then meta[#meta + 1] = date("%Y-%m-%d %H:%M", run.date) end
    lines[#lines + 1] = "|cff888888" .. table.concat(meta, "    ") .. "|r"
    if run.sections then
        for i, t in ipairs(run.sections) do
            if t then
                lines[#lines + 1] = "|cffaaaaaa   " .. L["Boss"] .. " " .. i .. ": " .. Utils.FormatTime(t) .. "|r"
            end
        end
    end

    local label = AceGUI:Create("Label")
    label:SetRelativeWidth(0.74)
    label:SetText(table.concat(lines, "\n"))
    card:AddChild(label)

    local del = AceGUI:Create("Button")
    del:SetText(L["Remove"])
    del:SetRelativeWidth(0.24)
    del:SetCallback("OnClick", function()
        Splits.Data.DeleteRun(mapID, level, run)
        Manager:Refresh()
    end)
    del:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Remove"])
        GameTooltip:AddLine(L["Removes only this run."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    del:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    card:AddChild(del)
end

-- Overview of the outdated group, with a one-click cleanup.
function Manager:ShowOutdated(container)
    local L = ns.L

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local head = AceGUI:Create("Label")
    head:SetFullWidth(true)
    head:SetText("|cffffffff" .. L["Outdated"] .. "|r\n"
        .. L["Dungeons from earlier seasons that still have stored data."] .. "\n")
    scroll:AddChild(head)

    local del = AceGUI:Create("Button")
    del:SetText(L["Delete outdated data"])
    del:SetFullWidth(true)
    del:SetCallback("OnClick", function()
        local old = Utils.GetOutdatedMaps(Splits.Data.GetDungeons())
        for _, mapID in ipairs(old) do Splits.Data.DeleteDungeon(mapID) end
        Addon:Info(L["Removed the stored times of %d outdated dungeon(s)."], #old)
        Manager:Refresh()
    end)
    del:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Delete outdated data"])
        GameTooltip:AddLine(L["Removes all stored times of dungeons outside the current season. Cannot be undone."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    del:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    scroll:AddChild(del)
end

-- One coloured card per stored run.
function Manager:ShowDetail(container, path)
    container:ReleaseChildren()
    local L = ns.L

    -- Last segment: outdated dungeons sit below their group node.
    local key = path:match("[^\001]+$")
    if key == OUTDATED then
        self:ShowOutdated(container)
        return
    end

    local mapID = tonumber(key)
    if not mapID then return end

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local head = AceGUI:Create("Label")
    head:SetFullWidth(true)
    head:SetText("|cffffffff" .. Utils.GetMapName(mapID) .. "|r\n")
    scroll:AddChild(head)

    local limit = Utils.GetMapTimeLimit(mapID)
    local levels = Splits.Data.GetLevels(mapID)

    if #levels == 0 then
        local hint = AceGUI:Create("Label")
        hint:SetFullWidth(true)
        hint:SetText(L["No data"])
        scroll:AddChild(hint)
        return
    end

    -- Highest levels first.
    for i = #levels, 1, -1 do
        local level = levels[i]
        local runs, best = Splits.Data.GetRuns(mapID, level)
        for _, run in ipairs(runs) do
            addRunCard(scroll, mapID, level, run, best, limit)
        end
    end

    local delDun = AceGUI:Create("Button")
    delDun:SetText(L["Delete dungeon"])
    delDun:SetFullWidth(true)
    delDun:SetCallback("OnClick", function()
        Splits.Data.DeleteDungeon(mapID)
        Manager:Refresh()
    end)
    delDun:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Delete dungeon"])
        GameTooltip:AddLine(L["Removes all stored times for this dungeon (every key level). Cannot be undone."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    delDun:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    scroll:AddChild(delDun)
end

function Manager:Open()
    if self.frame then return end
    local L = ns.L

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("MAUI M+ Timer \226\128\148 " .. L["Manage times"])
    frame:SetLayout("Fill")
    frame:SetCallback("OnClose", function(widget)
        Manager.frame, Manager.tree = nil, nil
        AceGUI:Release(widget)
    end)
    self.frame = frame

    local tree = AceGUI:Create("TreeGroup")
    tree:SetLayout("Fill")
    tree:SetFullWidth(true)
    tree:SetFullHeight(true)
    tree:EnableButtonTooltips(false)
    tree:SetTree(buildTree())
    tree:SetCallback("OnGroupSelected", function(widget, _, path)
        Manager:ShowDetail(widget, path)
    end)
    frame:AddChild(tree)
    self.tree = tree
end

function Manager:Close()
    if self.frame then
        self.frame:Hide() -- triggers OnClose -> release
    end
end

function Manager:Toggle()
    if self.frame then
        self:Close()
    else
        self:Open()
    end
end

-- After a deletion.
function Manager:Refresh()
    if not self.tree then return end
    self.tree:SetTree(buildTree())
    self.tree:ReleaseChildren()
end
