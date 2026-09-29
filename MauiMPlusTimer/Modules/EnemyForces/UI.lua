-- Modules/EnemyForces/UI.lua
-- HUD block for Enemy Forces: progress bar plus percentage and remaining count.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Forces = Addon:GetModule("EnemyForces")

local UI = Addon:NewModuleUI()
Forces.UI = UI

local DEFAULT_SEGMENT_GAP = 2 -- pixels between split segments

local DEMO_PERCENTS = { 30, 55, 80 } -- read-only
local NO_PERCENTS = {}               -- read-only

local function hideSegment(seg)
    seg:Hide()
end

local function isSplit()
    return Forces:GetSettings().splitBar == true
end

-- Checkpoint "% needed" labels: on the split segments, or at the single bar's
-- checkpoint markers.
local function countdownOn()
    return Forces:GetSettings().segmentCountdown == true
end

-- The single bar is always positioned, even in split mode where it is hidden:
-- it still anchors the percentage text.
function UI:LayoutBar()
    if not self.bar then return end
    local s = Addon.Widgets.ResolveStyle(ns.E.forcesBar)
    local h = s.height or 16

    -- Space claimed by texts above/below the bar. Shifting the bar by the
    -- difference keeps them inside the block, off the neighbouring ones.
    local textShown = Forces:GetSettings().showText ~= false
    local textMode = Addon:GetElementSetting(ns.E.forcesText).textPos or "center"
    local textExtra = textShown and (Addon.Widgets:LineHeight(ns.E.forcesText) + 2) or 0
    local topExtra = (textMode == "above") and textExtra or 0
    local bottomExtra = (textMode == "below") and textExtra or 0
    if countdownOn() then
        local segMode = Addon:GetElementSetting(ns.E.forcesSegment).countdownPos or "above"
        local segExtra = Addon.Widgets:LineHeight(ns.E.forcesSegment) + 2
        if segMode == "below" then
            bottomExtra = math.max(bottomExtra, segExtra)
        elseif segMode ~= "barLeft" and segMode ~= "barRight"
            and segMode ~= "center" then
            -- above/left/right sit on top; the in-bar modes claim nothing.
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

    -- With the text inside the bar, take the taller of the two, so a large font
    -- cannot overflow into the neighbouring blocks.
    local coreH = (textShown and textMode == "center")
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

-- Ascending 0..100, or demo samples outside a key. The result is shared and
-- must not be modified.
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

-- { lo, hi } slices spanning 0..1. Each checkpoint below 100% becomes a cut, so
-- N usable checkpoints yield N+1 segments; a 100% target is the bar's own end.
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

-- Cheap signature of the split geometry, so Update only rebuilds the segments
-- on a real change. The generation counter stands in for the checkpoint set
-- itself, which avoids per-tick table churn.
function UI:SplitSignature()
    local w = (self.bar and self.bar:GetWidth()) or 0
    local run = Addon.RunState:Get()
    local mapID = (run and run.mapID) or 0
    local Checkpoints = Addon:GetModule("Checkpoints", true)
    local gen = (Checkpoints and Checkpoints.Data
        and Checkpoints.Data.GetGeneration()) or 0
    return string.format("%d|%d|%d", math.floor(w + 0.5), mapID, gen)
end

-- Pools; extras beyond `count` are hidden, not destroyed.
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

-- Proportional widths across the bar span, mirrored on a reversed fill. The
-- fill fraction itself is applied per tick in UpdateSegments.
function UI:LayoutSegments(style, h, vShift)
    vShift = vShift or 0
    local defs = self:SegmentDefs()
    self._segDefs = defs
    self:EnsureSegments(#defs)

    local frameW = self.frame:GetWidth()
    if not frameW or frameW <= 0 then frameW = Addon.MainWindow:GetWidth() end
    local total = (style.width and style.width > 0) and style.width or frameW
    if not total or total <= 0 then total = Addon.MainWindow:GetWidth() end

    -- Whole pixels throughout, with the last segment taking the remainder, so
    -- every gap renders at the same width.
    local gap = Forces:GetSettings().splitGap or DEFAULT_SEGMENT_GAP
    gap = Addon.Widgets:Snap(self.frame, gap, gap > 0 and 1 or nil)
    local startX = Addon.Widgets:Snap(self.frame, (frameW - total) / 2)
    local avail = total - gap * math.max(0, #defs - 1)
    local reverse = Addon:GetElementSetting(ns.E.forcesBar).reverse == true
    local color = style.barColor or { 0.85, 0.20, 0.20, 1 }

    -- Gap centers in bar-relative coordinates; the countdown labels anchor
    -- there. 0% and 100% never produce a cut, so the bar ends stay clean.
    local boundaryX, boundaryPct, boundaryMid = {}, {}, {}
    local lastSectionMid -- center of the final segment (100% countdown)

    local x = 0 -- cumulative used width from the left of the bar span
    for i, seg in ipairs(self.segBars) do
        local def = defs[i]
        if def then
            local w = (i == #defs) and (avail - (x - gap * (i - 1)))
                or Addon.Widgets:Snap(self.frame, avail * (def.hi - def.lo))
            local leftX = reverse and (startX + total - x - w) or (startX + x)
            seg:ClearAllPoints()
            seg:SetSize(math.max(1, w), h)
            seg:SetPoint("LEFT", self.frame, "LEFT", leftX, vShift)
            seg:SetReverseFill(reverse)
            -- Screen-space slice, so the gradient runs across the whole bar
            -- rather than restarting in every segment.
            local lo, hi = def.lo, def.hi
            if reverse then lo, hi = 1 - hi, 1 - lo end
            Addon.Widgets:SetBarGradientRange(seg, lo, hi)
            seg:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
            seg:Show()
            if i < #defs then
                local cut = x + w + gap / 2
                boundaryX[i] = reverse and (total - cut) or cut
                boundaryPct[i] = def.hi * 100
                -- Center of the segment leading up to this checkpoint, for the
                -- "in bar, centered" countdown position.
                local mid = x + w / 2
                boundaryMid[i] = reverse and (total - mid) or mid
            else
                local mid = x + w / 2
                lastSectionMid = reverse and (total - mid) or mid
            end
            x = x + w + gap
        else
            hideSegment(seg)
        end
    end

    self._boundaryX, self._boundaryPct = boundaryX, boundaryPct
    self._boundaryMid, self._lastSectionMid = boundaryMid, lastSectionMid
end

-- The bar frame stays a valid anchor in split mode: hidden frames keep their
-- geometry.
function UI:LayoutMainText()
    if not (self.text and self.bar) then return end
    if Forces:GetSettings().showText == false then
        self.text:Hide()
        return
    end
    self.text:Show()
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
    else -- center
        fs:SetJustifyH("CENTER")
        fs:SetPoint("CENTER", self.bar, "CENTER", x, y)
    end
end

-- Each segment fills relative to its own checkpoint slice. The countdown labels
-- belong to LayoutMarkers: they anchor at the boundaries, not the segments.
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
    -- Parented to the block, not the bar, so it survives split mode where the
    -- single bar is hidden. The frame level clears the bar's border child and
    -- the segment bars, so the percentage text is never covered.
    local overlay = CreateFrame("Frame", nil, block)
    overlay:SetAllPoints(block)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 10)
    local text = Addon.Widgets:CreateText(overlay, ns.E.forcesText, "OVERLAY")

    self.frame, self.bar, self.text, self.overlay = block, bar, text, overlay

    self:LayoutBar()
    self:LayoutMainText()

    bar:SetScript("OnSizeChanged", function() UI:LayoutMarkers() end)
    self:LayoutMarkers()

    block:Hide()
    Addon.MainWindow:AddBlock("forces", block, 20)
end

-- Same modes as the timer's dividers. The extra "center" mode anchors to the
-- bar instead of the line, so LayoutMarkers handles that one.
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
    else -- above
        lbl:SetPoint("BOTTOM", line, "TOP", lx, 2 + ly)
    end
end

-- Markers sit at the checkpoint percentages, or invisibly at the segment-gap
-- centers in split mode. They are positioned even while hidden, because they
-- anchor the countdown labels.
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
    -- Even pixel count: the marker is centered on its x.
    local markerW = Addon.Widgets:Snap(self.bar, 1, 1) * 2
    local reverse = Addon:GetElementSetting(ns.E.forcesBar).reverse == true
    local mode = Addon:GetElementSetting(ns.E.forcesSegment).countdownPos or "above"
    local lx, ly = Addon.Widgets:GetOffset(ns.E.forcesSegment)
    local showAll = Forces:GetSettings().segmentCountdownAll == true
    -- Escape hatch against the first label overlapping the main text.
    local hideFirst = Forces:GetSettings().segmentHideFirst == true

    -- Nothing counts as reached in demo mode, so every marker stays visible
    -- for positioning.
    local livePct = (self._percent or 0) * 100
    local reached = Addon.Demo:IsActive() and -1 or livePct

    local percents = self:CheckpointPercents()
    local boundaryX = split and self._boundaryX
    local boundaryPct = split and self._boundaryPct
    local count = split and (boundaryPct and #boundaryPct or 0) or #percents

    local nearest
    for i = 1, count do
        local pct = split and boundaryPct[i] or percents[i]
        if pct > livePct and pct < 100
            and (not nearest or pct < nearest) then
            nearest = pct
        end
    end

    local used = 0
    local prevPct = 0 -- section start for the "in bar, centered" mode
    for i = 1, count do
        local pct = split and boundaryPct[i] or percents[i]
        -- The bar's own ends carry no marker or countdown.
        if pct > 0 and pct < 100 then
            used = used + 1
            local m = self.markers[used]
            if not m then
                m = self.bar:CreateTexture(nil, "OVERLAY")
                self.markers[used] = m
            end

            local bx
            if split then
                bx = boundaryX[i]
            else
                local frac = math.max(0, math.min(1, pct / 100))
                if reverse then frac = 1 - frac end
                bx = width * frac
            end
            bx = Addon.Widgets:Snap(self.bar, bx)
            m:ClearAllPoints()
            m:SetWidth(markerW)
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
                if mode == "center" then
                    -- Centered in the section leading up to this checkpoint,
                    -- not on the line.
                    local cx
                    if split then
                        cx = (self._boundaryMid and self._boundaryMid[i]) or bx
                    else
                        local midFrac = ((prevPct + pct) / 2) / 100
                        if reverse then midFrac = 1 - midFrac end
                        cx = width * midFrac
                    end
                    lbl:ClearAllPoints()
                    lbl:SetPoint("CENTER", self.bar, "LEFT", cx + lx, ly)
                else
                    anchorCountdownLabel(lbl, m, mode, lx, ly)
                end
                local remaining = pct - livePct
                if remaining > 0.05 and (showAll or pct == nearest)
                    and not (hideFirst and used == 1) then
                    lbl:SetText(string.format("%.1f%%", remaining))
                    lbl:Show()
                else
                    lbl:Hide()
                end
            elseif lbl then
                lbl:Hide()
            end
            prevPct = pct
        end
    end

    -- Label-only 100% countdown for the final stretch; no line at the bar's end.
    if showCountdown then
        used = used + 1
        local m = self.markers[used]
        if not m then
            m = self.bar:CreateTexture(nil, "OVERLAY")
            self.markers[used] = m
        end
        local bx = reverse and 0 or width
        m:ClearAllPoints()
        m:SetWidth(markerW)
        m:SetPoint("TOP", self.bar, "TOPLEFT", bx, 0)
        m:SetPoint("BOTTOM", self.bar, "BOTTOMLEFT", bx, 0)
        m:Hide()

        local lbl = m.cdLabel
        if not lbl then
            lbl = Addon.Widgets:CreateText(self.overlay, ns.E.forcesSegment, "OVERLAY")
            m.cdLabel = lbl
        end
        if mode == "center" then
            local cx
            if split then
                cx = self._lastSectionMid or (width / 2)
            else
                local midFrac = ((prevPct + 100) / 2) / 100
                if reverse then midFrac = 1 - midFrac end
                cx = width * midFrac
            end
            lbl:ClearAllPoints()
            lbl:SetPoint("CENTER", self.bar, "LEFT", cx + lx, ly)
        else
            anchorCountdownLabel(lbl, m, mode, lx, ly)
        end
        local remaining = 100 - livePct
        if remaining > 0.05 and (showAll or nearest == nil) then
            lbl:SetText(string.format("%.1f%%", remaining))
            lbl:Show()
        else
            lbl:Hide()
        end
    end

    for i = used + 1, #self.markers do
        local m = self.markers[i]
        m:Hide()
        if m.cdLabel then m.cdLabel:Hide() end
    end
end

-- current/total are absolute counts, percent is 0..1. completionTime and delta
-- only arrive on completion; bestForces is the stored best.
function UI:Update(current, total, percent, completionTime, delta, bestForces)
    if not self.frame then return end
    total = total or 0
    current = current or 0

    -- Kept for the markers and the segment fill.
    self._percent = percent or (total > 0 and current / total) or 0

    if isSplit() then
        -- Geometry only on a real change, not on every criteria tick.
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

    -- Strips count, best time and the completion time/delta from the main text.
    local percentOnly = Forces:GetSettings().percentOnly == true

    local str
    if total > 0 and current >= total and not percentOnly then
        -- Texture icon; a font check glyph renders as a missing-glyph box.
        local timeStr = completionTime
            and ("  |cffcccccc" .. Addon.Utils.FormatTime(completionTime) .. "|r") or ""
        local deltaStr = delta and ("  " .. Addon.Utils.FormatDelta(delta)) or ""
        str = "|cff33ff99100%|r |TInterface\\RaidFrame\\ReadyCheck-Ready:"
            .. Addon.Widgets:IconSize(ns.E.forcesText) .. "|t" .. timeStr .. deltaStr
    else
        local pct = string.format("%.2f%%", (percent or 0) * 100)
        if percentOnly or Forces:GetSettings().showCount == false then
            str = pct
        else
            local remaining = math.max(0, total - current)
            local countHex = Addon.Utils.ColorHex(
                Addon:GetElementSetting(ns.E.forcesText).countColor or { 0.6, 0.6, 0.6, 1 })
            str = string.format("%s  |c%s%d|r", pct, countHex, remaining)
        end
    end
    if not percentOnly and Addon.db.profile.ui.showBest == true and bestForces then
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
    self._segSig = nil -- width, gap or checkpoints may have changed
    self:LayoutBar()
    self:LayoutMainText()
    self:LayoutMarkers()
    if isSplit() then self:UpdateSegments(self._percent) end
end
