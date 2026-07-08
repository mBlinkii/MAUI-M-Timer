-- Modules/Checkpoints/Editor.lua
-- AceGUI panel to define per-dungeon forces targets: a target % before each boss
-- (section targets) and the Point of No Return thresholds. Laid out like the
-- Splits manager: a dungeon tree on the left, the editor on the right, plus an
-- "Import / Export" entry in the tree. Opened via the options button or
-- "/mauimpt checkpoints".

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Checkpoints = Addon:GetModule("Checkpoints")

local AceGUI = LibStub("AceGUI-3.0")

local Editor = {}
Checkpoints.Editor = Editor

-- Sentinel tree value for the Import / Export page.
local SHARE = "__share__"

-- Challenge-map helpers are shared (Core/Utilities): name and texture.
local Utils = Addon.Utils

-- Available dungeons: current season's maps + the active key + any already set.
local function dungeonList()
    local list, order = {}, {}
    local seen = {}
    local function add(mapID)
        if mapID and not seen[mapID] then
            seen[mapID] = true
            list[mapID] = Utils.GetMapName(mapID)
            order[#order + 1] = mapID
        end
    end
    if C_ChallengeMode and C_ChallengeMode.GetMapTable then
        for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do add(mapID) end
    end
    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        add(C_ChallengeMode.GetActiveChallengeMapID())
    end
    for mapID in pairs(Addon.db.global.checkpoints or {}) do add(mapID) end
    table.sort(order, function(a, b) return (list[a] or "") < (list[b] or "") end)
    return list, order
end

-- Left-hand tree: one node per dungeon, with an Import/Export entry pinned to
-- the very bottom (own icon + a distinct gold label so it stands out).
local function buildTree()
    local L = ns.L
    local tree = {}
    local list, order = dungeonList()
    for _, mapID in ipairs(order) do
        tree[#tree + 1] = { value = tostring(mapID), text = list[mapID], icon = Utils.GetMapTexture(mapID) }
    end
    tree[#tree + 1] = {
        value = SHARE,
        text = "|cff40c057" .. L["Import / Export"] .. "|r",
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Menu\\share",
    }
    return tree
end

-- Build one editable row (two inputs + remove button) inside a parent.
local function addRow(parent, leftLabel, leftValue, rightValue, onLeft, onRight, onRemove)
    local L = ns.L
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    parent:AddChild(row)

    local left = AceGUI:Create("EditBox")
    left:SetLabel(leftLabel)
    left:SetWidth(110)
    left:SetText(leftValue)
    left:SetCallback("OnEnterPressed", function(_, _, text) onLeft(text) end)
    row:AddChild(left)

    local right = AceGUI:Create("EditBox")
    right:SetLabel(L["Target %"])
    right:SetWidth(90)
    right:SetText(rightValue)
    right:SetCallback("OnEnterPressed", function(_, _, text) onRight(text) end)
    row:AddChild(right)

    local del = AceGUI:Create("Button")
    del:SetText(L["Remove"])
    del:SetWidth(90)
    del:SetCallback("OnClick", onRemove)
    row:AddChild(del)
end

-- Build one Point of No Return row (single % input + remove button).
local function addPonrRow(parent, value, onValue, onRemove)
    local L = ns.L
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    parent:AddChild(row)

    local pct = AceGUI:Create("EditBox")
    pct:SetLabel(L["Minimum %"])
    pct:SetWidth(110)
    pct:SetText(value)
    pct:SetCallback("OnEnterPressed", function(_, _, text) onValue(text) end)
    row:AddChild(pct)

    local del = AceGUI:Create("Button")
    del:SetText(L["Remove"])
    del:SetWidth(90)
    del:SetCallback("OnClick", onRemove)
    row:AddChild(del)
end

-- Right pane: the boss-section + Point of No Return editor for one dungeon.
function Editor:ShowDungeon(container, mapID)
    container:ReleaseChildren()
    local L = ns.L
    if not mapID then return end

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local head = AceGUI:Create("Label")
    head:SetFullWidth(true)
    head:SetText("|cffffd200" .. Utils.GetMapName(mapID) .. "|r\n")
    scroll:AddChild(head)

    -- Read without creating an entry, so merely browsing a dungeon does not store
    -- an empty record. The Add buttons create the entry on first use.
    local entry = Checkpoints.Data.Get(mapID)
    local bySection = (entry and entry.bySection) or {}
    local ponr = (entry and entry.ponr) or {}

    -- Boss section targets ----------------------------------------------------
    local h1 = AceGUI:Create("Heading")
    h1:SetFullWidth(true)
    h1:SetText(L["Boss section targets"])
    scroll:AddChild(h1)

    for i, s in ipairs(bySection) do
        -- Inputs are validated: boss index is a whole number >= 1, the target
        -- is clamped to 0..100 %. Non-numeric input keeps the previous value.
        addRow(scroll, L["Boss"] .. " #", tostring(s.bossIndex or 1), tostring(s.targetPct or 0),
            function(text)
                local v = tonumber(text)
                if v then s.bossIndex = math.max(1, math.floor(v)) end
            end,
            function(text)
                local v = tonumber(text)
                if v then s.targetPct = Utils.Clamp(v, 0, 100) end
            end,
            function()
                Checkpoints.Data.RemoveSection(mapID, i)
                Editor:ReShow()
            end)
    end

    local addBoss = AceGUI:Create("Button")
    addBoss:SetText(L["Add boss target"])
    addBoss:SetWidth(180)
    addBoss:SetCallback("OnClick", function()
        Checkpoints.Data.AddSection(mapID, (#bySection + 1), 0)
        Editor:ReShow()
    end)
    scroll:AddChild(addBoss)

    -- Point of No Return thresholds -------------------------------------------
    local h2 = AceGUI:Create("Heading")
    h2:SetFullWidth(true)
    h2:SetText(L["Point of No Return"])
    scroll:AddChild(h2)

    for i, p in ipairs(ponr) do
        -- The threshold is clamped to 0..100 %; non-numeric input is ignored.
        addPonrRow(scroll, tostring(p.pct or 0),
            function(text)
                local v = tonumber(text)
                if v then p.pct = Utils.Clamp(v, 0, 100) end
            end,
            function()
                Checkpoints.Data.RemovePoNR(mapID, i)
                Editor:ReShow()
            end)
    end

    local addPonr = AceGUI:Create("Button")
    addPonr:SetText(L["Add point of no return"])
    addPonr:SetWidth(220)
    addPonr:SetCallback("OnClick", function()
        Checkpoints.Data.AddPoNR(mapID, 0)
        Editor:ReShow()
    end)
    scroll:AddChild(addPonr)
end

-- Right pane: export / import of all checkpoints.
function Editor:ShowShare(container)
    container:ReleaseChildren()
    local L = ns.L

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    -- Export ------------------------------------------------------------------
    local h1 = AceGUI:Create("Heading")
    h1:SetFullWidth(true)
    h1:SetText(L["Export"])
    scroll:AddChild(h1)

    local d1 = AceGUI:Create("Label")
    d1:SetFullWidth(true)
    d1:SetText(L["Click Export to generate a shareable string of all your checkpoints, then copy it."])
    scroll:AddChild(d1)

    -- Format toggle: shareable string (default) vs. readable Lua code for
    -- embedding checkpoints into addon code (not re-importable).
    local exportAsLua = false

    local plainToggle = AceGUI:Create("CheckBox")
    plainToggle:SetLabel(L["Export as Lua table"])
    plainToggle:SetDescription(L["Output the profile as readable Lua code (for use in an addon) instead of a shareable string. This format cannot be re-imported."])
    plainToggle:SetFullWidth(true)
    scroll:AddChild(plainToggle)

    local exportBox = AceGUI:Create("MultiLineEditBox")
    exportBox:SetLabel(L["Export string"])
    exportBox:SetFullWidth(true)
    exportBox:SetNumLines(6)
    exportBox:DisableButton(true)
    scroll:AddChild(exportBox)

    local function generateExport()
        return (exportAsLua and Checkpoints.Data.ExportPlain()
            or Checkpoints.Data.Export()) or ""
    end

    plainToggle:SetCallback("OnValueChanged", function(_, _, value)
        exportAsLua = value and true or false
        -- Regenerate an already visible export in the new format.
        if exportBox:GetText() ~= "" then
            exportBox:SetText(generateExport())
        end
    end)

    local exportBtn = AceGUI:Create("Button")
    exportBtn:SetText(L["Export"])
    exportBtn:SetWidth(180)
    exportBtn:SetCallback("OnClick", function()
        exportBox:SetText(generateExport())
    end)
    scroll:AddChild(exportBtn)

    -- Import ------------------------------------------------------------------
    local h2 = AceGUI:Create("Heading")
    h2:SetFullWidth(true)
    h2:SetText(L["Import"])
    scroll:AddChild(h2)

    local d2 = AceGUI:Create("Label")
    d2:SetFullWidth(true)
    d2:SetText(L["Paste a string and accept to import checkpoints."])
    scroll:AddChild(d2)

    local importBox = AceGUI:Create("MultiLineEditBox")
    importBox:SetLabel(L["Import"])
    importBox:SetFullWidth(true)
    importBox:SetNumLines(6)
    importBox:DisableButton(true)
    scroll:AddChild(importBox)

    local importBtn = AceGUI:Create("Button")
    importBtn:SetText(L["Import"])
    importBtn:SetWidth(180)
    importBtn:SetCallback("OnClick", function()
        local ok, res = Checkpoints.Data.Import(importBox:GetText())
        if ok then
            Addon:Info(L["Imported checkpoints for %d dungeon(s)."], res or 0)
            importBox:SetText("")
            Editor:Refresh() -- new dungeons may have appeared in the tree
        else
            Addon:Error(L["Import failed: %s"], tostring(res))
        end
    end)
    scroll:AddChild(importBtn)
end

-- Dispatch the right pane based on the selected tree node.
function Editor:ShowDetail(container, path)
    if path == SHARE then
        self:ShowShare(container)
    else
        self:ShowDungeon(container, tonumber(path))
    end
end

-- Re-render the currently selected node in place (after add/remove).
function Editor:ReShow()
    if self.tree and self.selected then
        self:ShowDetail(self.tree, self.selected)
    end
end

-- Rebuild the tree (e.g. after an import added dungeons) and re-render.
function Editor:Refresh()
    if not self.tree then return end
    self.tree:SetTree(buildTree())
    if self.selected then
        self:ShowDetail(self.tree, self.selected)
    end
end

function Editor:Open()
    if self.frame then return end
    local L = ns.L

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("MAUI M+ Timer \226\128\148 " .. L["Edit checkpoints"])
    frame:SetLayout("Fill")
    frame:SetCallback("OnClose", function(widget)
        Editor.frame, Editor.tree, Editor.selected = nil, nil, nil
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
        Editor.selected = path
        Editor:ShowDetail(widget, path)
    end)
    frame:AddChild(tree)
    self.tree = tree

    -- Default to the active dungeon if any, otherwise the Import/Export page.
    local active = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
        and C_ChallengeMode.GetActiveChallengeMapID()
    tree:SelectByValue(active and tostring(active) or SHARE)
end

function Editor:Close()
    if self.frame then self.frame:Hide() end
end

function Editor:Toggle()
    if self.frame then self:Close() else self:Open() end
end
