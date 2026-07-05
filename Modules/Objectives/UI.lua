-- Modules/Objectives/UI.lua
-- HUD block listing the dungeon bosses with a status icon, split time and +/-.
-- Layout follows the module alignment:
--   left   -> icon + name (best time after) on the left, split time on the right
--   right  -> full mirror of left: split time on the left, name on the right with
--             the best time before it and the status icon after it
--   center -> name + time combined and centered
-- Rows are reused (created once, hidden when not needed).

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Objectives = Addon:GetModule("Objectives")

local UI = Addon:NewModuleUI()
Objectives.UI = UI

-- Default status icon textures; the path is configurable per state (see Options).
local DEFAULT_DONE    = "Interface\\RaidFrame\\ReadyCheck-Ready"
local DEFAULT_PENDING = "Interface\\RaidFrame\\ReadyCheck-Waiting"

local function alignH()
    return Addon.MainWindow:GetJustifyH("Objectives")
end

-- Per-row height derived from the font size (so rows never overlap when the
-- font grows) plus the configurable extra spacing between objectives.
local function rowHeight()
    return Addon.Widgets:LineHeight(ns.E.objectiveText)
        + (Objectives:GetSettings().rowSpacing or 0)
end

function UI:Build()
    if self.frame then return end
    local hud = Addon.MainWindow:Get()
    local block = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerObjectivesBlock")
    block:SetSize(Addon.MainWindow:GetWidth(), rowHeight())
    self.frame = block
    self.rows = {}
    block:Hide()
    Addon.MainWindow:AddBlock("objectives", block, 30)
end

function UI:GetRow(i)
    local row = self.rows[i]
    if not row then
        row = {
            name = Addon.Widgets:CreateText(self.frame, ns.E.objectiveText),
            time = Addon.Widgets:CreateText(self.frame, ns.E.objectiveText),
            index = i,
        }
        row.name:SetWordWrap(false)
        self.rows[i] = row
    end
    return row
end

-- Position a row's name/time for the alignment mode, applying the x/y offset.
function UI:LayoutRow(row, mode, x, y, rowH)
    local yy = -(row.index - 1) * (rowH or rowHeight()) + (y or 0)
    row.name:ClearAllPoints()
    row.time:ClearAllPoints()

    -- Single-point anchors per alignment (like the timer text) so a direct
    -- left<->right switch repositions reliably. The name and time sit on
    -- opposite edges; in center mode the name (which already includes the time)
    -- is anchored at the top-center.
    if mode == "CENTER" then
        row.name:SetPoint("TOP", self.frame, "TOP", x, yy)
        row.name:SetJustifyH("CENTER")
    elseif mode == "RIGHT" then
        row.name:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", x, yy)
        row.name:SetJustifyH("RIGHT")
        row.time:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, yy)
        row.time:SetJustifyH("LEFT")
    else -- LEFT
        row.name:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, yy)
        row.name:SetJustifyH("LEFT")
        row.time:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", x, yy)
        row.time:SetJustifyH("RIGHT")
    end
end

function UI:Update(bosses)
    if not self.frame then return end
    bosses = bosses or {}
    self._lastBosses = bosses -- cached so Restyle can rebuild on alignment change
    local mode = alignH()
    local x, y = Addon.Widgets:GetOffset(ns.E.objectiveText)
    local rowH = rowHeight()

    -- Configurable colors: defeated boss name, pending boss name and split time.
    -- The +/- delta keeps the shared comparison colors (Utils.FormatDelta).
    local e = Addon:GetElementSetting(ns.E.objectiveText)
    local doneHex = Addon.Utils.ColorHex(e.doneColor or { 0.20, 1.00, 0.60, 1 })
    local openHex = Addon.Utils.ColorHex(e.openColor or { 1, 1, 1, 1 })
    local timeHex = Addon.Utils.ColorHex(e.timeColor or { 0.80, 0.80, 0.80, 1 })

    -- Status icons are optional per state (defaults on).
    local s = Objectives:GetSettings()
    local showDone = s.showDoneIcon ~= false
    local showPending = s.showPendingIcon ~= false
    local showBest = Addon.db.profile.ui.showBest == true

    -- Optional boss-name shortening (display only; boss.name stays complete).
    local shortenMode = s.nameShorten or "off"
    local shortenLen = s.nameMaxLength or 12

    for i, boss in ipairs(bosses) do
        local row = self:GetRow(i)
        self:LayoutRow(row, mode, x, y, rowH)

        -- Optional ready/waiting status icon (glyph only; the spacing/side is
        -- decided below). The name is colored by the done/pending color.
        local iconGlyph = ""
        if boss.done then
            if showDone then iconGlyph = Addon.Widgets:IconEscape(s.doneIcon, DEFAULT_DONE, 12, s.doneIconColor) end
        elseif showPending then
            iconGlyph = Addon.Widgets:IconEscape(s.pendingIcon, DEFAULT_PENDING, 12, s.pendingIconColor)
        end
        local displayName = Addon.Utils.ShortenName(boss.name or "?", shortenMode, shortenLen)
        local coloredName = "|c" .. (boss.done and doneHex or openHex) .. displayName .. "|r"
        -- Best time sits directly beside the boss name so the time/delta column
        -- is not pushed around when it is shown.
        local bestStr = (showBest and boss.best) and Addon.Widgets:FormatBest(boss.best) or nil

        -- Compose the name line so right alignment is the mirror of left: in
        -- LEFT/CENTER the icon is on the left and the best time on the right; in
        -- RIGHT the order flips (best time on the left, icon on the right).
        local nameStr
        if mode == "RIGHT" then
            nameStr = (bestStr and (bestStr .. " ") or "")
                .. coloredName
                .. (iconGlyph ~= "" and (" " .. iconGlyph) or "")
        else
            nameStr = (iconGlyph ~= "" and (iconGlyph .. " ") or "")
                .. coloredName
                .. (bestStr and (" " .. bestStr) or "")
        end

        local timeStr = (boss.done and boss.time)
            and ("|c" .. timeHex .. Addon.Utils.FormatTime(boss.time) .. "|r") or ""
        local deltaStr = boss.delta and ("  " .. Addon.Utils.FormatDelta(boss.delta)) or ""
        timeStr = timeStr .. deltaStr

        if mode == "CENTER" then
            -- Combine name + time into one centered line.
            row.name:SetText(timeStr ~= "" and (nameStr .. "   " .. timeStr) or nameStr)
            row.time:SetText("")
            row.time:Hide()
        else
            row.name:SetText(nameStr)
            row.time:SetText(timeStr)
            row.time:Show()
        end
        row.name:Show()
    end

    for i = #bosses + 1, #self.rows do
        self.rows[i].name:Hide()
        self.rows[i].time:Hide()
    end

    self.frame:SetSize(Addon.MainWindow:GetWidth(), math.max(#bosses * rowH, 1))
    Addon.MainWindow:Layout()
end

-- Re-apply row style + layout after an alignment/style/profile change.
function UI:Restyle()
    if not self.rows then return end
    -- Refresh fonts on the existing rows first.
    for _, row in ipairs(self.rows) do
        Addon.Widgets:ApplyTextStyle(row.name, ns.E.objectiveText)
        Addon.Widgets:ApplyTextStyle(row.time, ns.E.objectiveText)
    end
    -- Then fully rebuild from the last data so a right-aligned switch (whose row
    -- layout mirrors name/time) and the configurable colors apply immediately.
    if self._lastBosses then self:Update(self._lastBosses) end
end

-- Show / Hide are provided by the shared UI base (Addon:NewModuleUI).
