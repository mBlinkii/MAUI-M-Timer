-- Modules/EnemyForces/UI.lua
-- HUD block for Enemy Forces: a progress bar with the percentage and remaining
-- count centered on it. Anchored below the timer in the shared MainWindow.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Forces = Addon:GetModule("EnemyForces")

local UI = Addon:NewModuleUI()
Forces.UI = UI

-- Stacking order: "top" keeps the bar above the objectives (default), "bottom"
-- moves it just below them (objectives are order 30, deaths order 40).
local function blockOrder()
    return Forces:GetSettings().position == "bottom" and 35 or 20
end

-- Re-apply the bar's stacking order after the position option changes.
function UI:UpdatePosition()
    if self.frame then
        Addon.MainWindow:SetBlockOrder("forces", blockOrder())
    end
end

-- Apply bar height/width/color from the per-element style.
function UI:LayoutBar()
    if not self.bar then return end
    local s = Addon.Widgets.ResolveStyle(ns.E.forcesBar)
    local h = s.height or 16
    self.bar:ClearAllPoints()
    self.bar:SetHeight(h)
    if s.width and s.width > 0 then
        self.bar:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
        self.bar:SetWidth(s.width)
    else
        self.bar:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
        self.bar:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
    end
    if s.barColor then self.bar:SetStatusBarColor(unpack(s.barColor)) end
    self.bar:SetReverseFill(Addon:GetElementSetting(ns.E.forcesBar).reverse == true)
    -- Block must fit the taller of the bar and the (bar-centered) text so a large
    -- font cannot overflow into the neighboring blocks.
    self.frame:SetHeight(math.max(h, Addon.Widgets:LineHeight(ns.E.forcesText)))
end

function UI:Build()
    if self.frame then return end

    local hud = Addon.MainWindow:Get()
    local block = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerForcesBlock")
    block:SetSize(Addon.MainWindow:GetWidth(), 16)

    local bar = Addon.Widgets:CreateBar(block, ns.E.forcesBar)
    -- Text parented to the bar on OVERLAY so it stays above the fill texture.
    local text = Addon.Widgets:CreateText(bar, ns.E.forcesText, "OVERLAY")

    self.frame, self.bar, self.text = block, bar, text

    self:LayoutBar()
    Addon.Widgets:LayoutText(text, bar, ns.E.forcesText, Addon.MainWindow:GetJustifyH("EnemyForces"))

    -- Reposition checkpoint markers whenever the bar resizes (e.g. width change).
    bar:SetScript("OnSizeChanged", function() UI:LayoutMarkers() end)
    self:LayoutMarkers()

    block:Hide()
    Addon.MainWindow:AddBlock("forces", block, blockOrder())
end

-- Draw vertical markers on the bar at each checkpoint target percentage, when
-- the option is on. Targets come from the current dungeon's checkpoint data (or
-- a sample set in demo mode so they can be positioned/styled outside a key).
function UI:LayoutMarkers()
    if not self.bar then return end
    self.markers = self.markers or {}

    if Forces:GetSettings().showMarkers ~= true then
        for _, m in ipairs(self.markers) do m:Hide() end
        return
    end

    local percents
    local run = Addon.RunState:Get()
    local Checkpoints = Addon:GetModule("Checkpoints", true)
    if run and run.mapID and Checkpoints and Checkpoints.Data then
        percents = Checkpoints.Data.GetTargetPercents(run.mapID)
    elseif Addon.Demo:IsActive() then
        percents = { 30, 55, 80 }
    end
    percents = percents or {}

    local width = self.bar:GetWidth()
    if not width or width <= 0 then width = Addon.MainWindow:GetWidth() end
    local mc = Addon.Widgets.ResolveStyle(ns.E.forcesBar).markerColor or { 1, 0.82, 0, 0.9 }
    -- Mirror marker positions when the bar fills right-to-left.
    local reverse = Addon:GetElementSetting(ns.E.forcesBar).reverse == true

    -- A marker disappears once its target percentage has been reached. In demo
    -- mode nothing is "reached", so all markers stay visible for positioning.
    local reached = Addon.Demo:IsActive() and -1 or ((self._percent or 0) * 100)

    for i, pct in ipairs(percents) do
        local m = self.markers[i]
        if not m then
            m = self.bar:CreateTexture(nil, "OVERLAY")
            self.markers[i] = m
        end
        if pct <= reached then
            m:Hide()
        else
            local frac = math.max(0, math.min(1, pct / 100))
            if reverse then frac = 1 - frac end
            m:ClearAllPoints()
            m:SetWidth(2)
            m:SetPoint("TOP", self.bar, "TOPLEFT", width * frac, 0)
            m:SetPoint("BOTTOM", self.bar, "BOTTOMLEFT", width * frac, 0)
            m:SetColorTexture(mc[1], mc[2], mc[3], mc[4] or 1)
            m:Show()
        end
    end
    for i = #percents + 1, #self.markers do self.markers[i]:Hide() end
end

-- current/total absolute counts, percent in 0..1. On completion, completionTime
-- (seconds) and delta (vs best, seconds) are also shown. bestForces is the stored
-- best forces-completion time, shown behind the text when the option is on.
function UI:Update(current, total, percent, completionTime, delta, bestForces)
    if not self.frame then return end
    total = total or 0
    current = current or 0

    self.bar:SetMinMaxValues(0, total > 0 and total or 1)
    self.bar:SetValue(current)

    -- Remember the live percentage so reached checkpoint markers can disappear.
    self._percent = percent or (total > 0 and current / total) or 0

    local str
    if total > 0 and current >= total then
        -- Texture icon (a font check glyph renders as a missing-glyph box) plus
        -- the completion time and the +/- delta versus the best run.
        local timeStr = completionTime
            and ("  |cffcccccc" .. Addon.Utils.FormatTime(completionTime) .. "|r") or ""
        local deltaStr = delta and ("  " .. Addon.Utils.FormatDelta(delta)) or ""
        str = "|cff33ff99100%|r |TInterface\\RaidFrame\\ReadyCheck-Ready:12|t" .. timeStr .. deltaStr
    else
        local pct = string.format("%.2f%%", (percent or 0) * 100)
        if Forces:GetSettings().showCount == false then
            -- Percentage only (the remaining absolute count is hidden).
            str = pct
        else
            local remaining = math.max(0, total - current)
            local countHex = Addon.Utils.ColorHex(
                Addon:GetElementSetting(ns.E.forcesText).countColor or { 0.6, 0.6, 0.6, 1 })
            str = string.format("%s  |c%s%d|r", pct, countHex, remaining)
        end
    end
    if Addon.db.profile.ui.showBest == true and bestForces then
        str = str .. "  " .. Addon.Widgets:FormatBest(bestForces)
    end
    self.text:SetText(str)

    self:LayoutMarkers()
end

function UI:Restyle()
    if not self.frame then return end
    Addon.Widgets:ApplyTextStyle(self.text, ns.E.forcesText)
    Addon.Widgets:ApplyBarStyle(self.bar, ns.E.forcesBar)
    self:LayoutBar()
    Addon.Widgets:LayoutText(self.text, self.bar, ns.E.forcesText, Addon.MainWindow:GetJustifyH("EnemyForces"))
    self:LayoutMarkers()
end

-- Show / Hide are provided by the shared UI base (Addon:NewModuleUI).
