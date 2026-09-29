-- Modules/Objectives/UI.lua
-- Boss list with status icon, split time and +/-. Right alignment is a full
-- mirror of left; center combines name and time into one line. Rows are pooled.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Objectives = Addon:GetModule("Objectives")

local UI = Addon:NewModuleUI()
Objectives.UI = UI

local DEFAULT_DONE    = "Interface\\RaidFrame\\ReadyCheck-Ready"
local DEFAULT_PENDING = "Interface\\RaidFrame\\ReadyCheck-Waiting"

local function alignH()
    return Addon.MainWindow:GetJustifyH("Objectives")
end

-- Derived from the font size, so rows never overlap when it grows.
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

function UI:LayoutRow(row, mode, x, y, rowH)
    local yy = -(row.index - 1) * (rowH or rowHeight()) + (y or 0)
    row.name:ClearAllPoints()
    row.time:ClearAllPoints()

    -- Single-point anchors, or a direct left<->right switch does not reposition.
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
    self._lastBosses = bosses -- Restyle rebuilds from this on an alignment change
    local mode = alignH()
    local x, y = Addon.Widgets:GetOffset(ns.E.objectiveText)
    local rowH = rowHeight()

    -- The +/- delta keeps the shared comparison colors instead.
    local e = Addon:GetElementSetting(ns.E.objectiveText)
    local doneHex = Addon.Utils.ColorHex(e.doneColor or { 0.20, 1.00, 0.60, 1 })
    local openHex = Addon.Utils.ColorHex(e.openColor or { 1, 1, 1, 1 })
    local timeHex = Addon.Utils.ColorHex(e.timeColor or { 0.80, 0.80, 0.80, 1 })

    local s = Objectives:GetSettings()
    local iconSize = Addon.Widgets:IconSize(ns.E.objectiveText)
    local width = self.frame:GetWidth()
    if not width or width <= 0 then width = Addon.MainWindow:GetWidth() end
    local showDone = s.showDoneIcon ~= false
    local showPending = s.showPendingIcon ~= false
    local showBest = Addon.db.profile.ui.showBest == true

    -- Display only; boss.name stays complete.
    local shortenMode = s.nameShorten or "off"
    local shortenLen = s.nameMaxLength or 12

    for i, boss in ipairs(bosses) do
        local row = self:GetRow(i)
        self:LayoutRow(row, mode, x, y, rowH)

        local iconGlyph = ""
        if boss.done then
            if showDone then iconGlyph = Addon.Widgets:IconEscape(s.doneIcon, DEFAULT_DONE, iconSize, s.doneIconColor) end
        elseif showPending then
            iconGlyph = Addon.Widgets:IconEscape(s.pendingIcon, DEFAULT_PENDING, iconSize, s.pendingIconColor)
        end
        local displayName = Addon.Utils.ShortenName(boss.name or "?", shortenMode, shortenLen)
        local coloredName = "|c" .. (boss.done and doneHex or openHex) .. displayName .. "|r"
        -- Beside the name, not in the time column, which would otherwise get
        -- pushed around whenever it appears.
        local bestStr = (showBest and boss.best) and Addon.Widgets:FormatBest(boss.best) or nil

        local progressStr = boss.progress and ("|c" .. timeHex .. boss.progress .. "|r") or nil

        -- RIGHT flips the order so the whole line mirrors LEFT.
        local nameStr
        if mode == "RIGHT" then
            nameStr = (bestStr and (bestStr .. " ") or "")
                .. (progressStr and (progressStr .. " ") or "")
                .. coloredName
                .. (iconGlyph ~= "" and (" " .. iconGlyph) or "")
        else
            nameStr = (iconGlyph ~= "" and (iconGlyph .. " ") or "")
                .. coloredName
                .. (progressStr and (" " .. progressStr) or "")
                .. (bestStr and (" " .. bestStr) or "")
        end

        local timeStr = (boss.done and boss.time)
            and ("|c" .. timeHex .. Addon.Utils.FormatTime(boss.time) .. "|r") or ""
        local deltaStr = boss.delta and ("  " .. Addon.Utils.FormatDelta(boss.delta)) or ""
        timeStr = timeStr .. deltaStr

        -- The name gets what the time column leaves, so a long one ends in "..."
        -- instead of running into the time.
        if mode == "CENTER" then
            row.name:SetWidth(math.max(20, width - math.abs(x)))
            row.name:SetText(timeStr ~= "" and (nameStr .. "   " .. timeStr) or nameStr)
            row.time:SetText("")
            row.time:Hide()
        else
            row.time:SetText(timeStr)
            row.time:Show()
            local timeW = timeStr ~= "" and (math.ceil(row.time:GetStringWidth()) + 8) or 0
            row.name:SetWidth(math.max(20, width - math.abs(x) - timeW))
            row.name:SetText(nameStr)
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

function UI:Restyle()
    if not self.rows then return end
    for _, row in ipairs(self.rows) do
        Addon.Widgets:ApplyTextStyle(row.name, ns.E.objectiveText)
        Addon.Widgets:ApplyTextStyle(row.time, ns.E.objectiveText)
    end
    -- Full rebuild, because an alignment switch mirrors the composed strings.
    if self._lastBosses then self:Update(self._lastBosses) end
end
