-- Modules/EnemyForces/UI.lua
-- HUD block for Enemy Forces: a progress bar with the percentage and remaining
-- count centered on it. Anchored below the timer in the shared MainWindow.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Forces = Addon:GetModule("EnemyForces")

local UI = Addon:NewModuleUI()
Forces.UI = UI

local DEFAULT_SEGMENT_GAP = 2 -- pixels between split segments (fallback)

-- Stacking order: "top" keeps the bar above the objectives (default), "bottom"
-- moves it just below them (objectives are order 30, deaths order 40).
local function blockOrder()
    return Forces:GetSettings().position == "bottom" and 35 or 20
end

-- Whether the checkpoint split-bar mode is active.
local function isSplit()
    return Forces:GetSettings().splitBar == true
end

-- Re-apply the bar's stacking order after the position option changes.
function UI:UpdatePosition()
    if self.frame then
        Addon.MainWindow:SetBlockOrder("forces", blockOrder())
    end
end

-- Apply bar height/width/color from the per-element style. The single bar is
-- always geometry-positioned (it also anchors the percentage text and is shown
-- in normal mode); in checkpoint split mode it is hidden and the segment bars
-- are laid out in its place.
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

    if isSplit() then
        self.bar:Hide()
        self:LayoutSegments(s, h)
    else
        if self.segBars then
            for _, b in ipairs(self.segBars) do
                b:Hide()
                if b.cdLabel then b.cdLabel:Hide() end
            end
        end
        self.bar:Show()
    end
end

-- Whether the per-segment "% needed" countdown labels should be shown.
local function segmentCountdownOn()
    return isSplit() and Forces:GetSettings().segmentCountdown == true
end

-- Which segments carry a countdown label. Only the first segment is skipped
-- because the main total percentage sits there; every other segment (including
-- the trailing slice up to 100%) shows its still-needed percentage.
local function segmentHasLabel(index, _def)
    return index > 1
end

-- Checkpoint target percentages (0..100, ascending) for the current dungeon, or
-- a fixed sample set in demo mode so the split/markers can be styled outside a
-- key. Shared by the markers and the split segments.
function UI:CheckpointPercents()
    local run = Addon.RunState:Get()
    local Checkpoints = Addon:GetModule("Checkpoints", true)
    if run and run.mapID and Checkpoints and Checkpoints.Data then
        return Checkpoints.Data.GetTargetPercents(run.mapID)
    elseif Addon.Demo:IsActive() then
        return { 30, 55, 80 }
    end
    return {}
end

-- Split boundaries as fractions (0..1). Each checkpoint below 100% becomes a cut;
-- the trailing 100% target is intentionally ignored (it is the bar's own end).
-- Returns a list of { lo, hi } segment slices spanning 0..1, so N usable
-- checkpoints yield N+1 segments.
function UI:SegmentDefs()
    local defs = {}
    local prev = 0
    for _, pct in ipairs(self:CheckpointPercents()) do
        if pct > 0 and pct < 100 then
            local frac = pct / 100
            if frac > prev then
                defs[#defs + 1] = { lo = prev, hi = frac }
                prev = frac
            end
        end
    end
    defs[#defs + 1] = { lo = prev, hi = 1 }
    return defs
end

-- A cheap signature of the split geometry inputs (bar width + checkpoint set) so
-- Update only rebuilds the segment frames when they actually change, not on every
-- criteria tick.
function UI:SplitSignature()
    local w = (self.bar and self.bar:GetWidth()) or 0
    return string.format("%d|%s", math.floor(w + 0.5),
        table.concat(self:CheckpointPercents(), ","))
end

-- Create segment bars on demand up to `count`, pooling and hiding any extras
-- (and their countdown labels).
function UI:EnsureSegments(count)
    self.segBars = self.segBars or {}
    for i = 1, count do
        if not self.segBars[i] then
            self.segBars[i] = Addon.Widgets:CreateBar(self.frame, ns.E.forcesBar)
        end
    end
    for i = count + 1, #self.segBars do
        self.segBars[i]:Hide()
        if self.segBars[i].cdLabel then self.segBars[i].cdLabel:Hide() end
    end
end

-- Lay out the checkpoint segments across the bar span with proportional widths
-- and a configurable gap, mirroring the timer's split bar. Segment colors follow
-- the bar's fill color; the fill fraction is applied per tick in UpdateSegments.
-- When the bar fills right-to-left the whole arrangement is mirrored.
function UI:LayoutSegments(style, h)
    local defs = self:SegmentDefs()
    self._segDefs = defs
    self:EnsureSegments(#defs)

    local frameW = self.frame:GetWidth()
    if not frameW or frameW <= 0 then frameW = Addon.MainWindow:GetWidth() end
    local total = (style.width and style.width > 0) and style.width or frameW
    if not total or total <= 0 then total = Addon.MainWindow:GetWidth() end

    local gap = Forces:GetSettings().splitGap or DEFAULT_SEGMENT_GAP
    local startX = (frameW - total) / 2
    local avail = total - gap * math.max(0, #defs - 1)
    local reverse = Addon:GetElementSetting(ns.E.forcesBar).reverse == true
    local color = style.barColor or { 0.85, 0.20, 0.20, 1 }

    local x = 0 -- cumulative used width (px) from the left of the bar span
    for i, seg in ipairs(self.segBars) do
        local def = defs[i]
        if def then
            local w = avail * (def.hi - def.lo)
            -- Mirror each segment's left edge around the bar span when reversed.
            local leftX = reverse and (startX + total - x - w) or (startX + x)
            seg:ClearAllPoints()
            seg:SetSize(math.max(1, w), h)
            -- Anchor by LEFT so the segment is vertically centered like the bar.
            seg:SetPoint("LEFT", self.frame, "LEFT", leftX, 0)
            seg:SetReverseFill(reverse)
            seg:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
            seg:Show()
            self:LayoutSegmentLabel(seg, def, i)
            x = x + w + gap
        else
            seg:Hide()
            if seg.cdLabel then seg.cdLabel:Hide() end
        end
    end
end

-- Create/position the "% needed" countdown label centered on a segment. Only
-- segments selected by segmentHasLabel carry one (every segment except the first,
-- which holds the main total). The live text + reached-hide logic runs in
-- UpdateSegments; here we only (re)apply the font/color and anchor, so a style
-- change takes effect at once.
function UI:LayoutSegmentLabel(seg, def, index)
    if not (segmentCountdownOn() and segmentHasLabel(index, def)) then
        if seg.cdLabel then seg.cdLabel:Hide() end
        return
    end
    local lbl = seg.cdLabel
    if not lbl then
        lbl = Addon.Widgets:CreateText(self.overlay, ns.E.forcesSegment, "OVERLAY")
        seg.cdLabel = lbl
    else
        Addon.Widgets:ApplyTextStyle(lbl, ns.E.forcesSegment)
    end
    local lx, ly = Addon.Widgets:GetOffset(ns.E.forcesSegment)
    lbl:SetJustifyH("CENTER")
    lbl:ClearAllPoints()
    lbl:SetPoint("CENTER", seg, "CENTER", lx, ly)
end

-- Fill each segment relative to its own checkpoint slice from the current forces
-- percentage (0..1). A slice below the current percent is full, the active slice
-- is partial, later slices are empty.
function UI:UpdateSegments(percent)
    if not (self.segBars and self._segDefs) then return end
    percent = percent or 0
    local showCountdown = segmentCountdownOn()
    for i, seg in ipairs(self.segBars) do
        local def = self._segDefs[i]
        if def then
            local span = def.hi - def.lo
            local frac = span > 0 and ((percent - def.lo) / span) or 0
            frac = math.max(0, math.min(1, frac))
            seg:SetMinMaxValues(0, 1)
            seg:SetValue(frac)

            -- "% needed" countdown: percentage still missing to this segment's
            -- checkpoint (def.hi). It counts down as forces rise and hides once
            -- the checkpoint is reached. The trailing 100% slice carries no label.
            local lbl = seg.cdLabel
            if lbl then
                local remaining = (def.hi - percent) * 100
                if showCountdown and segmentHasLabel(i, def) and remaining > 0.05 then
                    lbl:SetText(string.format("%.1f%%", remaining))
                    lbl:Show()
                else
                    lbl:Hide()
                end
            end
        end
    end
end

function UI:Build()
    if self.frame then return end

    local hud = Addon.MainWindow:Get()
    local block = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerForcesBlock")
    block:SetSize(Addon.MainWindow:GetWidth(), 16)

    local bar = Addon.Widgets:CreateBar(block, ns.E.forcesBar)
    -- Dedicated overlay above every bar/border frame. It is parented to the block
    -- (NOT the bar) so it survives split mode, where the single bar is hidden and
    -- the segment bars take over. Its frame level sits above the bar border frame
    -- (Widgets:ApplyBorder puts the border on a child at bar level + 1) and above
    -- the segment bars and their borders, so the percentage text is never covered.
    local overlay = CreateFrame("Frame", nil, block)
    overlay:SetAllPoints(block)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 10)
    -- Text on the overlay OVERLAY layer so it stays above the fill and border.
    local text = Addon.Widgets:CreateText(overlay, ns.E.forcesText, "OVERLAY")

    self.frame, self.bar, self.text, self.overlay = block, bar, text, overlay

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

    -- In split mode the segment gaps already mark every checkpoint, so the
    -- separate marker textures are redundant and are hidden.
    if isSplit() or Forces:GetSettings().showMarkers ~= true then
        for _, m in ipairs(self.markers) do m:Hide() end
        return
    end

    local percents = self:CheckpointPercents()

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

    -- Remember the live percentage so reached checkpoint markers can disappear
    -- and the split segments know their fill.
    self._percent = percent or (total > 0 and current / total) or 0

    if isSplit() then
        -- Rebuild the segment geometry only when the checkpoint set or bar width
        -- changes (not every criteria tick), then apply the per-segment fill.
        local sig = self:SplitSignature()
        if sig ~= self._segSig then
            self._segSig = sig
            self:LayoutBar()
        end
        self:UpdateSegments(self._percent)
    else
        self._segSig = nil
        self.bar:SetMinMaxValues(0, total > 0 and total or 1)
        self.bar:SetValue(current)
    end

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
    if self.segBars then
        for _, seg in ipairs(self.segBars) do
            Addon.Widgets:ApplyBarStyle(seg, ns.E.forcesBar)
        end
    end
    -- Force the next Update to rebuild the split geometry (width/gap/checkpoints
    -- may have changed) instead of relying on the cached signature.
    self._segSig = nil
    self:LayoutBar()
    Addon.Widgets:LayoutText(self.text, self.bar, ns.E.forcesText, Addon.MainWindow:GetJustifyH("EnemyForces"))
    self:LayoutMarkers()
    if isSplit() then self:UpdateSegments(self._percent) end
end

-- Show / Hide are provided by the shared UI base (Addon:NewModuleUI).
