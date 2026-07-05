-- Modules/Timer/UI.lua
-- HUD display for the Timer module: a container with a fill bar, the time text,
-- the +3/+2 section dividers and optional per-section countdown labels. The
-- achievable upgrade tier is read from the bar's section colors (no badge).
-- Styling (font, colors, bar size/texture, divider color/width, offsets) is
-- per element.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Timer = Addon:GetModule("Timer")

local UI = Addon:NewModuleUI()
Timer.UI = UI

local TEXT_AREA = 20 -- fallback height reserved for the time text above the bar

-- Shared fallback colors, hoisted so the per-tick Update never allocates a new
-- table when a style field is unset.
local DEFAULT_MAX_COLOR = { 0.6, 0.6, 0.6, 1 }
local DEFAULT_SECTION_COLOR = { 0.85, 0.20, 0.20, 1 }

-- Relative widths of the three bar segments (+3 large, +2 / +1 small) and the
-- time thresholds that bound them. Used by the optional split-bar mode.
local SEGMENTS = {
    { lo = 0.0, hi = 0.6, level = 3 },
    { lo = 0.6, hi = 0.8, level = 2 },
    { lo = 0.8, hi = 1.0, level = 1 },
}
local SEGMENT_GAP = 2 -- pixels between split segments

-- Whether the split-bar mode is active.
local function isSplit()
    return Timer:GetSettings().splitBar == true
end

-- Vertical layout reserved for the time text, returned as
-- (top padding, text line height, gap-to-bar). The gap is user-configurable
-- (barTextGap) and sits between the text and the bar, so increasing it pushes
-- the bar further below the time text and grows the block height accordingly.
-- Kept as a function so LayoutBar/LayoutCluster share it.
function UI:TextArea()
    local gap = Timer:GetSettings().barTextGap or 0
    return 0, Addon.Widgets:LineHeight(ns.E.timerText, 16), gap
end

-- Apply the bar's height/width from the per-element style, choosing the single
-- bar or the three-segment layout depending on the split setting.
function UI:LayoutBar()
    if not self.bar then return end
    local s = Addon.Widgets.ResolveStyle(ns.E.timerBar)
    local h = s.height or 14
    local top, textH, bottom = self:TextArea()
    self._areaTop, self._textH = top, textH
    self.frame:SetHeight(top + textH + bottom + h)

    if isSplit() then
        self.bar:Hide()
        self:LayoutSegments(s, h)
        return
    end

    if self.segBars then
        for _, b in ipairs(self.segBars) do b:Hide() end
    end
    self.bar:Show()
    self.bar:ClearAllPoints()
    self.bar:SetHeight(h)
    if s.width and s.width > 0 then
        self.bar:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 0)
        self.bar:SetWidth(s.width)
    else
        self.bar:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 0)
        self.bar:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    end
end

-- Create the three segment bars on first use (split-bar mode only).
function UI:EnsureSegments()
    if self.segBars then return end
    self.segBars = {}
    for i = 1, #SEGMENTS do
        local b = Addon.Widgets:CreateBar(self.frame, ns.E.timerBar)
        b:Hide()
        self.segBars[i] = b
    end
end

-- Lay out the three segments with proportional widths. When the bar fills
-- right-to-left the whole arrangement is mirrored (the large +3 segment sits on
-- the right, the small +2/+1 on the left) so it is an exact mirror of the
-- left-to-right layout, including the segment fills and the boundary positions.
function UI:LayoutSegments(style, h)
    self:EnsureSegments()
    local total = (style.width and style.width > 0) and style.width or self.frame:GetWidth()
    if not total or total <= 0 then total = Addon.MainWindow:GetWidth() end
    local gap = Timer:GetSettings().splitGap or SEGMENT_GAP
    local startX = (self.frame:GetWidth() - total) / 2
    local avail = total - gap * (#SEGMENTS - 1)
    local reverse = Addon:GetElementSetting(ns.E.timerBar).reverse == true
    -- Frame-local x of each gap center, so the countdown can anchor to it.
    self._boundaryX = {}
    local x = 0
    for i, seg in ipairs(self.segBars) do
        local w = avail * (SEGMENTS[i].hi - SEGMENTS[i].lo)
        -- Mirror each segment's left edge around the bar span when reversed.
        local leftX = reverse and (startX + total - x - w) or (startX + x)
        seg:ClearAllPoints()
        seg:SetSize(math.max(1, w), h)
        seg:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", leftX, 0)
        seg:SetReverseFill(reverse)
        seg:Show()
        if i < #self.segBars then
            local b = startX + x + w + gap / 2
            if reverse then b = 2 * startX + total - b end -- mirror the boundary
            self._boundaryX[i] = b
        end
        x = x + w + gap
    end
end


-- The best-time FontString follows the time text's font family + outline but
-- keeps its own configurable size (element timerBest).
function UI:ApplyBestFont()
    if not self.bestText then return end
    local base = Addon.Widgets.ResolveStyle(ns.E.timerText)
    local size = Addon:GetElementSetting(ns.E.timerBest).fontSize or base.fontSize
    self.bestText:SetFont(base.font, size, base.fontFlags)
end

-- Anchor the time text per the module alignment. Left-justifying inside the
-- fixed-width box (when centered) keeps the elapsed value's left edge from
-- re-centering (and jittering) each tick. The best time (own FontString) sits
-- next to the time on the inner side so it never overhangs the aligned edge.
function UI:LayoutCluster()
    if not self.text then return end
    local justify = Addon.MainWindow:GetJustifyH("Timer")
    self.text:SetJustifyH(justify == "CENTER" and "LEFT" or justify)

    local textH = self._textH or TEXT_AREA
    local tx, ty = Addon.Widgets:GetOffset(ns.E.timerText)
    local rowY = -(textH / 2) + ty -- no badges, so no top padding to account for

    self.text:ClearAllPoints()
    if justify == "LEFT" then
        self.text:SetPoint("LEFT", self.frame, "TOPLEFT", tx, rowY)
    elseif justify == "RIGHT" then
        self.text:SetPoint("RIGHT", self.frame, "TOPRIGHT", tx, rowY)
    else
        self.text:SetPoint("CENTER", self.frame, "TOP", tx, rowY)
    end

    if self.bestText then
        self.bestText:ClearAllPoints()
        if justify == "RIGHT" then
            self.bestText:SetPoint("RIGHT", self.text, "LEFT", -4, 0)
        else
            self.bestText:SetPoint("LEFT", self.text, "RIGHT", 4, 0)
        end
    end
end

function UI:Build()
    if self.frame then return end

    local hud = Addon.MainWindow:Get()
    local block = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerTimerBlock")
    block:SetSize(Addon.MainWindow:GetWidth(), 34)

    local bar = Addon.Widgets:CreateBar(block, ns.E.timerBar)
    local text = Addon.Widgets:CreateText(block, ns.E.timerText)
    -- Separate FontString for the stored best time so it can have its own size.
    local bestText = Addon.Widgets:CreateText(block, ns.E.timerText)
    bestText:Hide()

    self.frame, self.bar, self.text, self.bestText = block, bar, text, bestText

    self:LayoutBar()
    self:ApplyBestFont()
    self:LayoutCluster()
    bar:SetReverseFill(Addon:GetElementSetting(ns.E.timerBar).reverse == true)

    -- Dedicated overlay frame above the bar(s) so the divider lines and the
    -- countdown labels always draw ON TOP of the fill, never behind it. Its frame
    -- level is raised above the bar and the split-mode segment bars.
    local overlay = CreateFrame("Frame", nil, block)
    overlay:SetAllPoints(block)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 10)
    self.overlay = overlay

    -- Section markers + optional countdown labels, created on the overlay (not
    -- the bar) so they stay visible in split-bar mode. The +3 (60%) and +2 (80%)
    -- markers draw a line; the +1 (100% = time limit) marker is label-only (its
    -- "line" is the bar's end edge) and exists only to anchor that countdown.
    self.dividers = {}
    for _, def in ipairs({ { 0.6 }, { 0.8 }, { 1.0, labelOnly = true } }) do
        local line = overlay:CreateTexture(nil, "OVERLAY")
        line._threshold = def[1]
        line._labelOnly = def.labelOnly
        local label = overlay:CreateFontString(nil, "OVERLAY")
        label:SetWordWrap(false) -- countdown is single-line; never wrap to 2 rows
        label:Hide()
        line.label = label
        table.insert(self.dividers, line)
    end
    bar:SetScript("OnSizeChanged", function() UI:LayoutDividers() end)
    self:LayoutDividers()

    block:Hide()
    Addon.MainWindow:AddBlock("timer", block, 10)
end

-- Anchor a single countdown label relative to its divider line, according to
-- the chosen position mode. The line spans the full bar height.
--   above / below       -> outside the bar, centered on the line
--   left / right        -> outside the bar (top), to one side of the line
--   barLeft / barRight  -> inside the bar, to one side of the line
local function anchorCountdown(label, line, mode, lx, ly)
    label:ClearAllPoints()
    if mode == "below" then
        label:SetPoint("TOP", line, "BOTTOM", lx, -2 + ly)
    elseif mode == "left" then
        label:SetPoint("BOTTOMRIGHT", line, "TOP", -2 + lx, ly)
    elseif mode == "right" then
        label:SetPoint("BOTTOMLEFT", line, "TOP", 2 + lx, ly)
    elseif mode == "barLeft" then
        label:SetPoint("RIGHT", line, "LEFT", -2 + lx, ly)
    elseif mode == "barRight" then
        label:SetPoint("LEFT", line, "RIGHT", 2 + lx, ly)
    else -- above (default)
        label:SetPoint("BOTTOM", line, "TOP", lx, 2 + ly)
    end
end

-- Position the divider markers and their countdown labels (frame-local). In
-- single-bar mode markers sit at the threshold positions along the bar; in
-- split-bar mode they sit at the gap centers between segments, so the countdown
-- labels stay visible there too. Visibility is handled in UpdateSections.
function UI:LayoutDividers()
    if not self.frame or not self.dividers then return end

    local split = isSplit()
    local frameW = self.frame:GetWidth()
    if not frameW or frameW <= 0 then frameW = Addon.MainWindow:GetWidth() end

    local reverse = Addon:GetElementSetting(ns.E.timerBar).reverse == true
    local barStyle = Addon.Widgets.ResolveStyle(ns.E.timerBar)
    local fillElapsed = barStyle.barFill ~= "remaining"
    local dc = barStyle.sectionDividerColor or { 1, 1, 1, 0.65 }
    local dw = barStyle.dividerWidth or 1
    local h = barStyle.height or 14

    -- Single-bar horizontal extent within the frame.
    local barW = (barStyle.width and barStyle.width > 0) and barStyle.width or frameW
    local barLeft = (frameW - barW) / 2

    local ls = Addon.Widgets.ResolveStyle(ns.E.timerSection)
    local mode = ls.countdownPos or "above"
    local lx, ly = Addon.Widgets:GetOffset(ns.E.timerSection)

    for i, line in ipairs(self.dividers) do
        local x
        if split and not line._labelOnly then
            x = (self._boundaryX and self._boundaryX[i]) or (frameW * line._threshold)
        else
            -- Single-bar position (also used for the label-only limit marker so it
            -- sits at the bar's end edge, mirrored when the fill is reversed).
            local base = fillElapsed and line._threshold or (1 - line._threshold)
            local frac = reverse and (1 - base) or base
            x = barLeft + barW * frac
        end

        line:ClearAllPoints()
        line:SetSize(dw, h)
        line:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x, 0)
        line:SetColorTexture(dc[1], dc[2], dc[3], dc[4] or 1)
        -- Split mode and the limit marker never draw a line (label anchor only).
        if split or line._labelOnly then line:Hide() end

        if line.label then
            line.label:SetFont(ls.font, ls.fontSize or 11, ls.fontFlags)
            anchorCountdown(line.label, line, mode, lx, ly)
        end
    end
end

-- Show the divider lines (single-bar mode only) up to the current section, and
-- the countdown label on the nearest upcoming threshold in BOTH bar modes.
function UI:UpdateSections(elapsed, timeLimit)
    if not self.dividers then return end
    elapsed = elapsed or 0
    local limit = timeLimit or 0
    local split = isSplit()
    local s = Timer:GetSettings()
    local showCountdown = s.sectionCountdown == true
    -- Show every upcoming threshold's countdown at once instead of just the next.
    local showAll = s.sectionCountdownAll == true

    local nearest
    for _, line in ipairs(self.dividers) do
        local tTime = line._threshold * limit
        if elapsed < tTime and (not nearest or tTime < nearest) then nearest = tTime end
    end

    for _, line in ipairs(self.dividers) do
        local tTime = line._threshold * limit
        local passed = limit > 0 and elapsed >= tTime
        -- Divider line: drawn only in single-bar mode, before it is passed, and
        -- never for the label-only limit marker.
        if split or passed or line._labelOnly then line:Hide() else line:Show() end
        -- Countdown label: all upcoming thresholds (showAll) or just the nearest.
        if line.label then
            if showCountdown and not passed and (showAll or tTime == nearest) then
                local cd = Addon.Utils.FormatTime(tTime - elapsed)
                line.label:SetText(cd)
                -- Stable width + left-justify so the ticking countdown does not jitter.
                local w = Addon.Widgets:StableTextWidth(ns.E.timerSection, cd)
                if w then line.label:SetWidth(w) end
                line.label:SetJustifyH("LEFT")
                line.label:Show()
            else
                line.label:Hide()
            end
        end
    end
end

-- Fill each segment relative to its own time slice and color it with the
-- matching section color (split-bar mode).
function UI:UpdateSegments(elapsed, timeLimit, style)
    if not self.segBars then return end
    local colors = style.sectionColors or {}
    for i, seg in ipairs(self.segBars) do
        local def = SEGMENTS[i]
        local frac = 0
        if timeLimit > 0 then
            local lo, hi = def.lo * timeLimit, def.hi * timeLimit
            frac = (elapsed - lo) / (hi - lo)
            frac = math.max(0, math.min(1, frac))
        end
        seg:SetMinMaxValues(0, 1)
        seg:SetValue(frac)
        local c = colors[def.level] or { 0.85, 0.20, 0.20, 1 }
        seg:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    end
end

function UI:Update(elapsed, timeLimit, bonus, bestTotal)
    if not self.frame then return end
    elapsed = elapsed or 0
    timeLimit = timeLimit or 0
    local overtime = timeLimit > 0 and elapsed > timeLimit

    local style = Addon.Widgets.ResolveStyle(ns.E.timerBar)
    if isSplit() then
        self:UpdateSegments(elapsed, timeLimit, style)
    else
        local fillElapsed = style.barFill ~= "remaining"
        if timeLimit > 0 then
            self.bar:SetMinMaxValues(0, timeLimit)
            local value
            if fillElapsed then
                value = math.min(elapsed, timeLimit)
            else
                value = overtime and timeLimit or math.max(0, timeLimit - elapsed)
            end
            self.bar:SetValue(value)
        end

        local colors = style.sectionColors or {}
        local c = colors[bonus or 0] or colors[0] or DEFAULT_SECTION_COLOR
        self.bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    end

    -- The displayed time is whole-second resolution, but the ticker runs at 0.1s
    -- for a smooth bar fill (set above, a cheap C call). Rebuilding the text and
    -- countdown strings every tick would allocate ~10x more garbage than needed,
    -- so the (relatively expensive) string work only runs when the second, the
    -- time limit or the over-time state actually changes. Restyle resets the gate.
    local sec = math.floor(elapsed)
    local textDirty = self._lastSec ~= sec or self._lastLimit ~= timeLimit or self._lastOver ~= overtime
    if textDirty then
        self._lastSec, self._lastLimit, self._lastOver = sec, timeLimit, overtime

        local timeStr
        if overtime then
            timeStr = string.format(
                "|cffff4040%s / %s  (+%s)|r",
                Addon.Utils.FormatTime(elapsed),
                Addon.Utils.FormatTime(timeLimit),
                Addon.Utils.FormatTime(elapsed - timeLimit))
        else
            -- The "/ max" portion uses the configurable max-time color.
            local maxHex = Addon.Utils.ColorHex(
                Addon:GetElementSetting(ns.E.timerText).maxColor or DEFAULT_MAX_COLOR)
            timeStr = string.format(
                "%s  |c%s/ %s|r",
                Addon.Utils.FormatTime(elapsed),
                maxHex,
                Addon.Utils.FormatTime(timeLimit))
        end
        self.text:SetText(timeStr)
        -- Reserve a per-tick-stable width so the ticking time never shifts itself
        -- (or the best-time text anchored to it) in left/right alignment.
        local w = Addon.Widgets:StableTextWidth(ns.E.timerText, timeStr)
        if w then self.text:SetWidth(w) end

        self:UpdateSections(elapsed, timeLimit)
    end

    -- Stored best total in its own FontString (own size + best color) beside the
    -- time when the option is on; only rewritten when the value/visibility change.
    if self.bestText then
        local showBest = Addon.db.profile.ui.showBest == true and bestTotal or false
        if showBest ~= self._bestShown or bestTotal ~= self._bestVal then
            self._bestShown, self._bestVal = showBest, bestTotal
            if showBest then
                self.bestText:SetText(Addon.Widgets:BestText(bestTotal))
                self.bestText:SetTextColor(unpack(Addon.Widgets:GetBestColor()))
                self.bestText:Show()
            else
                self.bestText:Hide()
            end
        end
    end
end

function UI:Restyle()
    if not self.frame then return end
    -- Force the next Update to rebuild the (gated) time/best text so font and
    -- color changes apply at once instead of on the next second boundary.
    self._lastSec, self._lastLimit, self._lastOver = nil, nil, nil
    self._bestShown, self._bestVal = nil, nil
    Addon.Widgets:ApplyTextStyle(self.text, ns.E.timerText)
    Addon.Widgets:ApplyBarStyle(self.bar, ns.E.timerBar)
    if self.segBars then
        for _, seg in ipairs(self.segBars) do
            Addon.Widgets:ApplyBarStyle(seg, ns.E.timerBar)
        end
    end
    self:ApplyBestFont()
    self:LayoutBar()
    self:LayoutCluster()
    self.bar:SetReverseFill(Addon:GetElementSetting(ns.E.timerBar).reverse == true)
    self:LayoutDividers()
    Addon.MainWindow:ApplyPosition()
end

-- Show / Hide are provided by the shared UI base (Addon:NewModuleUI).
