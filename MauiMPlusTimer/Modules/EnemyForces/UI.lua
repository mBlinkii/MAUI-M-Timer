-- Modules/EnemyForces/UI.lua
-- HUD block for Enemy Forces: a progress bar with the percentage and remaining
-- count centered on it. Anchored below the timer in the shared MainWindow.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Forces = Addon:GetModule("EnemyForces")

local UI = Addon:NewModuleUI()
Forces.UI = UI

local DEFAULT_SEGMENT_GAP = 2 -- pixels between split segments (fallback)

-- Fixed sample checkpoints shown in demo mode (read-only).
local DEMO_PERCENTS = { 30, 55, 80 }

-- Shared empty result for "no checkpoints" (read-only).
local NO_PERCENTS = {}

-- Hide a pooled segment bar (the countdown labels live on the checkpoint
-- markers, not on the segments; see LayoutMarkers).
local function hideSegment(seg)
    seg:Hide()
end

-- Whether the checkpoint split-bar mode is active.
local function isSplit()
    return Forces:GetSettings().splitBar == true
end

-- Whether the checkpoint "% needed" countdown labels are enabled. They are
-- shown on the split segments, or - with the split bar disabled - at the
-- checkpoint markers of the single bar.
local function countdownOn()
    return Forces:GetSettings().segmentCountdown == true
end

-- Apply bar height/width/color from the per-element style. The single bar is
-- always geometry-positioned (it also anchors the percentage text and is shown
-- in normal mode); in checkpoint split mode it is hidden and the segment bars
-- are laid out in its place.
function UI:LayoutBar()
    if not self.bar then return end
    local s = Addon.Widgets.ResolveStyle(ns.E.forcesBar)
    local h = s.height or 16

    -- Vertical space claimed by texts positioned above/below the bar: the main
    -- percentage text (textPos) and, in split mode, the segment countdown
    -- (countdownPos). The bar is shifted by the difference so those texts stay
    -- inside the block and cannot overlap neighboring blocks.
    local textMode = Addon:GetElementSetting(ns.E.forcesText).textPos or "center"
    local textExtra = Addon.Widgets:LineHeight(ns.E.forcesText) + 2
    local topExtra = (textMode == "above") and textExtra or 0
    local bottomExtra = (textMode == "below") and textExtra or 0
    if countdownOn() then
        local segMode = Addon:GetElementSetting(ns.E.forcesSegment).countdownPos or "above"
        local segExtra = Addon.Widgets:LineHeight(ns.E.forcesSegment) + 2
        if segMode == "below" then
            bottomExtra = math.max(bottomExtra, segExtra)
        elseif segMode ~= "barLeft" and segMode ~= "barRight" then
            -- above/left/right all sit on top of the bar (timer semantics).
            topExtra = math.max(topExtra, segExtra)
        end
    end
    local vShift = (bottomExtra - topExtra) / 2

    self.bar:ClearAllPoints()
    self.bar:SetHeight(h)
    if s.width and s.width > 0 then
        self.bar:SetPoint("CENTER", self.frame, "CENTER", 0, vShift)
        self.bar:SetWidth(s.width)
    else
        self.bar:SetPoint("LEFT", self.frame, "LEFT", 0, vShift)
        self.bar:SetPoint("RIGHT", self.frame, "RIGHT", 0, vShift)
    end
    if s.barColor then self.bar:SetStatusBarColor(unpack(s.barColor)) end
    self.bar:SetReverseFill(Addon:GetElementSetting(ns.E.forcesBar).reverse == true)

    -- Block height: bar plus the outside texts; with the text in the bar, the
    -- taller of bar and text (so a large font cannot overflow into the
    -- neighboring blocks).
    local coreH = (textMode == "center")
        and math.max(h, Addon.Widgets:LineHeight(ns.E.forcesText)) or h
    self.frame:SetHeight(coreH + topExtra + bottomExtra)

    if isSplit() then
        self.bar:Hide()
        self:LayoutSegments(s, h, vShift)
    else
        if self.segBars then
            for _, b in ipairs(self.segBars) do hideSegment(b) end
        end
        self.bar:Show()
    end
end

-- Checkpoint target percentages (0..100, ascending) for the current dungeon, or
-- a fixed sample set in demo mode so the split/markers can be styled outside a
-- key. Shared by the markers and the split segments. The returned table is
-- shared/cached and must not be modified.
function UI:CheckpointPercents()
    local run = Addon.RunState:Get()
    local Checkpoints = Addon:GetModule("Checkpoints", true)
    if run and run.mapID and Checkpoints and Checkpoints.Data then
        return Checkpoints.Data.GetTargetPercents(run.mapID)
    elseif Addon.Demo:IsActive() then
        return DEMO_PERCENTS
    end
    return NO_PERCENTS
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

-- A cheap signature of the split geometry inputs (bar width, dungeon, checkpoint
-- store generation) so Update only rebuilds the segment frames when they actually
-- change, not on every criteria tick. The generation counter stands in for the
-- checkpoint set itself, avoiding any per-tick table/string churn.
function UI:SplitSignature()
    local w = (self.bar and self.bar:GetWidth()) or 0
    local run = Addon.RunState:Get()
    local mapID = (run and run.mapID) or 0
    local Checkpoints = Addon:GetModule("Checkpoints", true)
    local gen = (Checkpoints and Checkpoints.Data
        and Checkpoints.Data.GetGeneration()) or 0
    return string.format("%d|%d|%d", math.floor(w + 0.5), mapID, gen)
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
        hideSegment(self.segBars[i])
    end
end

-- Lay out the checkpoint segments across the bar span with proportional widths
-- and a configurable gap, mirroring the timer's split bar. Segment colors follow
-- the bar's fill color; the fill fraction is applied per tick in UpdateSegments.
-- When the bar fills right-to-left the whole arrangement is mirrored.
function UI:LayoutSegments(style, h, vShift)
    vShift = vShift or 0
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

    -- Checkpoint boundaries (gap centers) in bar-relative coordinates: the
    -- countdown labels anchor there, exactly like the timer bar's divider
    -- labels (see LayoutMarkers). 0% and 100% targets never produce a cut,
    -- so the bar's own ends stay free of dividers and labels.
    local boundaryX, boundaryPct = {}, {}

    local x = 0 -- cumulative used width (px) from the left of the bar span
    for i, seg in ipairs(self.segBars) do
        local def = defs[i]
        if def then
            local w = avail * (def.hi - def.lo)
            -- Mirror each segment's left edge around the bar span when reversed.
            local leftX = reverse and (startX + total - x - w) or (startX + x)
            seg:ClearAllPoints()
            seg:SetSize(math.max(1, w), h)
            -- Anchor by LEFT, vertically shifted exactly like the single bar.
            seg:SetPoint("LEFT", self.frame, "LEFT", leftX, vShift)
            seg:SetReverseFill(reverse)
            seg:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
            seg:Show()
            if i < #defs then
                local cut = x + w + gap / 2
                boundaryX[i] = reverse and (total - cut) or cut
                boundaryPct[i] = def.hi * 100
            end
            x = x + w + gap
        else
            hideSegment(seg)
        end
    end

    self._boundaryX, self._boundaryPct = boundaryX, boundaryPct
end

-- Anchor the main percentage text relative to the bar span: above/below the
-- bar, or inside it centered / at the left/right bar edge. The bar frame
-- stays a valid anchor in split mode (hidden frames keep their geometry).
function UI:LayoutMainText()
    if not (self.text and self.bar) then return end
    local mode = Addon:GetElementSetting(ns.E.forcesText).textPos or "center"
    local x, y = Addon.Widgets:GetOffset(ns.E.forcesText)
    local fs = self.text
    fs:ClearAllPoints()
    if mode == "above" then
        fs:SetJustifyH("CENTER")
        fs:SetPoint("BOTTOM", self.bar, "TOP", x, 2 + y)
    elseif mode == "below" then
        fs:SetJustifyH("CENTER")
        fs:SetPoint("TOP", self.bar, "BOTTOM", x, -2 + y)
    elseif mode == "barLeft" then
        fs:SetJustifyH("LEFT")
        fs:SetPoint("LEFT", self.bar, "LEFT", 2 + x, y)
    elseif mode == "barRight" then
        fs:SetJustifyH("RIGHT")
        fs:SetPoint("RIGHT", self.bar, "RIGHT", -2 + x, y)
    else -- center (default)
        fs:SetJustifyH("CENTER")
        fs:SetPoint("CENTER", self.bar, "CENTER", x, y)
    end
end

-- Fill each segment relative to its own checkpoint slice from the current forces
-- percentage (0..1). A slice below the current percent is full, the active slice
-- is partial, later slices are empty. The countdown labels are handled by
-- LayoutMarkers (they anchor at the checkpoint boundaries, not the segments).
function UI:UpdateSegments(percent)
    if not (self.segBars and self._segDefs) then return end
    percent = percent or 0
    for i, seg in ipairs(self.segBars) do
        local def = self._segDefs[i]
        if def then
            local span = def.hi - def.lo
            local frac = span > 0 and ((percent - def.lo) / span) or 0
            frac = math.max(0, math.min(1, frac))
            seg:SetMinMaxValues(0, 1)
            seg:SetValue(frac)
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
    self:LayoutMainText()

    -- Reposition checkpoint markers whenever the bar resizes (e.g. width change).
    bar:SetScript("OnSizeChanged", function() UI:LayoutMarkers() end)
    self:LayoutMarkers()

    block:Hide()
    -- Effective position comes from the user-configurable block order
    -- (MainWindow:GetBlockRows); the value here is only the fallback.
    Addon.MainWindow:AddBlock("forces", block, 20)
end

-- Anchor a checkpoint countdown label relative to its marker/boundary line,
-- with exactly the timer bar's position modes:
--   above / below       -> outside the bar, centered on the line
--   left / right        -> outside the bar (top), to one side of the line
--   barLeft / barRight  -> inside the bar, to one side of the line
local function anchorCountdownLabel(lbl, line, mode, lx, ly)
    lbl:ClearAllPoints()
    if mode == "below" then
        lbl:SetPoint("TOP", line, "BOTTOM", lx, -2 + ly)
    elseif mode == "left" then
        lbl:SetPoint("BOTTOMRIGHT", line, "TOP", -2 + lx, ly)
    elseif mode == "right" then
        lbl:SetPoint("BOTTOMLEFT", line, "TOP", 2 + lx, ly)
    elseif mode == "barLeft" then
        lbl:SetPoint("RIGHT", line, "LEFT", -2 + lx, ly)
    elseif mode == "barRight" then
        lbl:SetPoint("LEFT", line, "RIGHT", 2 + lx, ly)
    else -- above (default)
        lbl:SetPoint("BOTTOM", line, "TOP", lx, 2 + ly)
    end
end

-- Vertical checkpoint markers plus the "% needed" countdown labels, behaving
-- exactly like the timer bar's dividers: in single-bar mode the markers sit
-- at the checkpoint percentages (and anchor the labels even while the marker
-- display itself is off); in split mode they sit invisibly at the segment-gap
-- centers computed by LayoutSegments and only anchor the labels. By default
-- only the nearest upcoming checkpoint shows its countdown; an option shows
-- all of them at once.
function UI:LayoutMarkers()
    if not self.bar then return end
    self.markers = self.markers or {}

    local split = isSplit()
    local showMarkers = not split and Forces:GetSettings().showMarkers == true
    local showCountdown = countdownOn()
    if not (showMarkers or showCountdown) then
        for _, m in ipairs(self.markers) do
            m:Hide()
            if m.cdLabel then m.cdLabel:Hide() end
        end
        return
    end

    local width = self.bar:GetWidth()
    if not width or width <= 0 then width = Addon.MainWindow:GetWidth() end
    local mc = Addon.Widgets.ResolveStyle(ns.E.forcesBar).markerColor or { 1, 0.82, 0, 0.9 }
    -- Mirror marker positions when the bar fills right-to-left.
    local reverse = Addon:GetElementSetting(ns.E.forcesBar).reverse == true
    local mode = Addon:GetElementSetting(ns.E.forcesSegment).countdownPos or "above"
    local lx, ly = Addon.Widgets:GetOffset(ns.E.forcesSegment)
    local showAll = Forces:GetSettings().segmentCountdownAll == true

    -- A marker disappears once its target percentage has been reached. In demo
    -- mode nothing is "reached", so all markers stay visible for positioning.
    local livePct = (self._percent or 0) * 100
    local reached = Addon.Demo:IsActive() and -1 or livePct

    -- Position/target source: split mode uses the gap-center boundaries
    -- recorded by LayoutSegments; single-bar mode the raw percentages.
    local percents = self:CheckpointPercents()
    local boundaryX = split and self._boundaryX
    local boundaryPct = split and self._boundaryPct
    local count = split and (boundaryPct and #boundaryPct or 0) or #percents

    -- The nearest upcoming checkpoint is the only one with a countdown,
    -- unless the show-all option is on (timer semantics).
    local nearest
    for i = 1, count do
        local pct = split and boundaryPct[i] or percents[i]
        if pct > livePct and pct < 100
            and (not nearest or pct < nearest) then
            nearest = pct
        end
    end

    local used = 0
    for i = 1, count do
        local pct = split and boundaryPct[i] or percents[i]
        -- 0% and 100% targets are skipped entirely: the bar's own ends carry
        -- no divider, marker or countdown (split cuts exclude them already).
        if pct > 0 and pct < 100 then
            used = used + 1
            local m = self.markers[used]
            if not m then
                m = self.bar:CreateTexture(nil, "OVERLAY")
                self.markers[used] = m
            end

            -- Bar-relative x: precomputed gap center in split mode, percentage
            -- position otherwise. Positioned even while hidden - the texture
            -- anchors the countdown label (hidden regions keep their geometry).
            local bx
            if split then
                bx = boundaryX[i]
            else
                local frac = math.max(0, math.min(1, pct / 100))
                if reverse then frac = 1 - frac end
                bx = width * frac
            end
            m:ClearAllPoints()
            m:SetWidth(2)
            m:SetPoint("TOP", self.bar, "TOPLEFT", bx, 0)
            m:SetPoint("BOTTOM", self.bar, "BOTTOMLEFT", bx, 0)
            m:SetColorTexture(mc[1], mc[2], mc[3], mc[4] or 1)
            m:SetShown(showMarkers and pct > reached)

            -- Countdown to this checkpoint; hides once it is reached.
            local lbl = m.cdLabel
            if showCountdown then
                if not lbl then
                    lbl = Addon.Widgets:CreateText(self.overlay, ns.E.forcesSegment, "OVERLAY")
                    m.cdLabel = lbl
                end
                anchorCountdownLabel(lbl, m, mode, lx, ly)
                local remaining = pct - livePct
                if remaining > 0.05 and (showAll or pct == nearest) then
                    lbl:SetText(string.format("%.1f%%", remaining))
                    lbl:Show()
                else
                    lbl:Hide()
                end
            elseif lbl then
                lbl:Hide()
            end
        end
    end
    for i = used + 1, #self.markers do
        local m = self.markers[i]
        m:Hide()
        if m.cdLabel then m.cdLabel:Hide() end
    end
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
    if self.markers then
        for _, m in ipairs(self.markers) do
            if m.cdLabel then
                Addon.Widgets:ApplyTextStyle(m.cdLabel, ns.E.forcesSegment)
            end
        end
    end
    -- Force the next Update to rebuild the split geometry (width/gap/checkpoints
    -- may have changed) instead of relying on the cached signature.
    self._segSig = nil
    self:LayoutBar()
    self:LayoutMainText()
    self:LayoutMarkers()
    if isSplit() then self:UpdateSegments(self._percent) end
end

-- Show / Hide are provided by the shared UI base (Addon:NewModuleUI).
