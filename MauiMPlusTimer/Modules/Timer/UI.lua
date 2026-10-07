-- Modules/Timer/UI.lua
-- Two independently orderable blocks: the "timer" text (elapsed/limit + best)
-- and the "timerbar" (fill bar, section dividers, countdown labels).

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Timer = Addon:GetModule("Timer")

local UI = Addon:NewModuleUI()
Timer.UI = UI

-- Hoisted so the per-tick Update allocates nothing when a style field is unset.
local DEFAULT_MAX_COLOR = { 0.6, 0.6, 0.6, 1 }
local DEFAULT_SECTION_COLOR = { 0.85, 0.20, 0.20, 1 }

-- Relative widths and time thresholds of the split-bar segments.
local SEGMENTS = {
    { lo = 0.0, hi = 0.6, level = 3 },
    { lo = 0.6, hi = 0.8, level = 2 },
    { lo = 0.8, hi = 1.0, level = 1 },
}
local SEGMENT_GAP = 2 -- pixels between split segments

local function isSplit()
    return Timer:GetSettings().splitBar == true
end

-- Vertical space the countdown labels claim outside the bar, as (top, bottom).
-- Reserved in the block so the labels cannot overflow into neighboring ones.
function UI:CountdownExtra()
    if Timer:GetSettings().sectionCountdown ~= true then return 0, 0 end
    local mode = Addon:GetElementSetting(ns.E.timerSection).countdownPos or "above"
    if mode == "barLeft" or mode == "barRight" then return 0, 0 end
    local extra = Addon.Widgets:LineHeight(ns.E.timerSection) + 2
    if mode == "below" then return 0, extra end
    return extra, 0 -- above / left / right
end

-- Anchors the bar at the block's bottom, offset by the reserved countdown space.
function UI:LayoutBar()
    if not (self.bar and self.barFrame) then return end
    local s = Addon.Widgets.ResolveStyle(ns.E.timerBar)
    local h = s.height or 14
    local topExtra, bottomExtra = self:CountdownExtra()
    self._barBottom = bottomExtra
    self.barFrame:SetHeight(topExtra + h + bottomExtra)

    if isSplit() then
        self.bar:Hide()
        self:LayoutSegments(s, h, bottomExtra)
        return
    end

    if self.segBars then
        for _, b in ipairs(self.segBars) do b:Hide() end
    end
    self.bar:Show()
    self.bar:ClearAllPoints()
    self.bar:SetHeight(h)
    if s.width and s.width > 0 then
        self.bar:SetPoint("BOTTOM", self.barFrame, "BOTTOM", 0, bottomExtra)
        self.bar:SetWidth(s.width)
    else
        self.bar:SetPoint("BOTTOMLEFT", self.barFrame, "BOTTOMLEFT", 0, bottomExtra)
        self.bar:SetPoint("BOTTOMRIGHT", self.barFrame, "BOTTOMRIGHT", 0, bottomExtra)
    end
end

function UI:EnsureSegments()
    if self.segBars then return end
    self.segBars = {}
    for i = 1, #SEGMENTS do
        local b = Addon.Widgets:CreateBar(self.barFrame, ns.E.timerBar)
        b:Hide()
        self.segBars[i] = b
    end
end

-- A right-to-left fill mirrors the whole arrangement, segment fills and
-- boundary positions included.
function UI:LayoutSegments(style, h, bottomExtra)
    self:EnsureSegments()
    bottomExtra = bottomExtra or 0
    local frameW = self.barFrame:GetWidth()
    if not frameW or frameW <= 0 then frameW = Addon.MainWindow:GetWidth() end
    local total = (style.width and style.width > 0) and style.width or frameW
    if not total or total <= 0 then total = Addon.MainWindow:GetWidth() end
    -- Whole pixels throughout, with the last segment taking the remainder, so
    -- every gap renders at the same width.
    local frame = self.barFrame
    local gap = Timer:GetSettings().splitGap or SEGMENT_GAP
    gap = Addon.Widgets:Snap(frame, gap, gap > 0 and 1 or nil)
    local startX = Addon.Widgets:Snap(frame, (frameW - total) / 2)
    local avail = total - gap * (#SEGMENTS - 1)
    local reverse = Addon:GetElementSetting(ns.E.timerBar).reverse == true
    -- Frame-local x of each gap center; the countdown labels anchor to these.
    self._boundaryX = {}
    local x = 0
    for i, seg in ipairs(self.segBars) do
        local w = (i == #self.segBars) and (avail - (x - gap * (i - 1)))
            or Addon.Widgets:Snap(frame, avail * (SEGMENTS[i].hi - SEGMENTS[i].lo))
        local leftX = reverse and (startX + total - x - w) or (startX + x)
        seg:ClearAllPoints()
        seg:SetSize(math.max(1, w), h)
        seg:SetPoint("BOTTOMLEFT", self.barFrame, "BOTTOMLEFT", leftX, bottomExtra)
        seg:SetReverseFill(reverse)
        -- Screen-space slice, so the gradient runs across the whole bar rather
        -- than restarting in every segment.
        local lo, hi = SEGMENTS[i].lo, SEGMENTS[i].hi
        if reverse then lo, hi = 1 - hi, 1 - lo end
        Addon.Widgets:SetBarGradientRange(seg, lo, hi)
        seg:Show()
        if i < #self.segBars then
            local b = startX + x + w + gap / 2
            if reverse then b = 2 * startX + total - b end
            self._boundaryX[i] = b
        end
        x = x + w + gap
    end
end

-- Time text layouts. main: what the big value shows; second: the smaller
-- value ("max" or "remaining"), placed by secondPos.
UI.TEXT_LAYOUTS = {
    inline           = { main = "elapsed", second = "max" },
    elapsed          = { main = "elapsed" },
    remaining        = { main = "remaining" },
    remainingMax     = { main = "remaining", second = "max" },
    elapsedRemaining = { main = "elapsed", second = "remaining" },
}
UI.TEXT_LAYOUT_ORDER = { "inline", "elapsedRemaining", "elapsed", "remaining", "remainingMax" }
-- Where the second value and the best time sit relative to the time.
UI.PART_POSITIONS = { "left", "right", "above", "below" }

local function partPos(key)
    local pos = Timer:GetSettings()[key]
    if pos == "left" or pos == "above" or pos == "below" then return pos end
    return "right"
end

local PART_GAP = 6 -- between the parts on one line

local function textLayout()
    return UI.TEXT_LAYOUTS[Timer:GetSettings().textLayout] or UI.TEXT_LAYOUTS.inline
end

-- Second value and best time follow the time's face and outline, each at its
-- own size.
local function partSizes()
    local base = Addon.Widgets.ResolveStyle(ns.E.timerText)
    return base, Addon:GetElementSetting(ns.E.timerMax).fontSize or base.fontSize,
        Addon:GetElementSetting(ns.E.timerBest).fontSize or base.fontSize
end

-- t: { frame, main, second, best } -- the HUD block or the options preview.
function UI:ApplyTextFonts(t)
    local base, secondSize, bestSize = partSizes()
    Addon.Widgets:ApplyTextStyle(t.main, ns.E.timerText)
    t.second:SetFont(base.font, secondSize, base.fontFlags)
    t.best:SetFont(base.font, bestSize, base.fontFlags)
    Addon.Widgets:ApplyShadow(t.second, base)
    Addon.Widgets:ApplyShadow(t.best, base)
end

-- Stable width, or the ticking time shifts itself and its neighbors.
local function setPart(fs, text)
    fs:SetText(text)
    local w = text ~= "" and Addon.Widgets:StableTextWidth(ns.E.timerText, text, fs) or 0
    fs:SetWidth(math.max(1, w))
    fs:SetShown(text ~= "")
end

-- best: seconds or nil (hidden).
function UI:FillText(t, elapsed, timeLimit, best)
    local layout = textLayout()
    local overtime = timeLimit > 0 and elapsed > timeLimit
    local fmt = Addon.Utils.FormatTime
    local maxHex = Addon.Utils.ColorHex(Addon:GetElementSetting(ns.E.timerText).maxColor or DEFAULT_MAX_COLOR)
    local over = overtime and fmt(elapsed - timeLimit) or nil

    local main
    if layout.main == "remaining" then
        main = overtime and ("|cffff4040+" .. over .. "|r") or fmt(math.max(0, timeLimit - elapsed))
    else
        main = overtime and ("|cffff4040" .. fmt(elapsed) .. "|r") or fmt(elapsed)
    end

    local second = ""
    if layout.second then
        local value
        if layout.second == "remaining" then
            value = overtime and ("+" .. over) or fmt(math.max(0, timeLimit - elapsed))
        else
            value = fmt(timeLimit)
            if overtime and layout.main ~= "remaining" then value = value .. "  (+" .. over .. ")" end
        end
        second = "|c" .. (overtime and "ffff4040" or maxHex) .. value .. "|r"
    end

    setPart(t.main, main)
    setPart(t.second, second)
    if best then
        setPart(t.best, Addon.Widgets:BestText(best))
        t.best:SetTextColor(unpack(Addon.Widgets:GetBestColor()))
    else
        setPart(t.best, "")
    end
end

-- Lines top to bottom, each a run of parts aligned as a whole.
local lines = { {}, {}, {}, {}, {} }

-- Returns the height the parts need; the caller sizes its frame to it.
function UI:PlaceText(t, justify)
    local bestPos, secondPos = partPos("bestPos"), partPos("secondPos")
    local _, secondSize, bestSize = partSizes()
    local hasBest = t.best:IsShown()
    local hasSecond = t.second:IsShown()
    for _, l in ipairs(lines) do
        for i = #l, 1, -1 do l[i] = nil end
    end

    -- Outermost first: the best time frames the time and its second value.
    local n = 0
    local function newLine() n = n + 1; return lines[n] end
    if hasBest and bestPos == "above" then table.insert(newLine(), t.best) end
    if hasSecond and secondPos == "above" then table.insert(newLine(), t.second) end
    local first = newLine()
    if hasBest and bestPos == "left" then first[#first + 1] = t.best end
    if hasSecond and secondPos == "left" then first[#first + 1] = t.second end
    first[#first + 1] = t.main
    if hasSecond and secondPos == "right" then first[#first + 1] = t.second end
    if hasBest and bestPos == "right" then first[#first + 1] = t.best end
    if hasSecond and secondPos == "below" then table.insert(newLine(), t.second) end
    if hasBest and bestPos == "below" then table.insert(newLine(), t.best) end

    local function heightOf(fs)
        if fs == t.main then return Addon.Widgets:LineHeight(ns.E.timerText, 16) end
        return Addon.Widgets:LineHeight(ns.E.timerText, 16, fs == t.second and secondSize or bestSize)
    end

    local frameW = t.frame:GetWidth() or 0
    local ox, oy = Addon.Widgets:GetOffset(ns.E.timerText)
    local top = 0
    for li = 1, n do
        local l = lines[li]
        local lineW, lineH = 0, 0
        for i, fs in ipairs(l) do
            lineW = lineW + fs:GetWidth() + (i > 1 and PART_GAP or 0)
            lineH = math.max(lineH, heightOf(fs))
        end
        local x = 0
        if justify == "RIGHT" then
            x = frameW - lineW
        elseif justify == "CENTER" then
            x = (frameW - lineW) / 2
        end
        x = Addon.Widgets:Snap(t.frame, x + ox)
        for _, fs in ipairs(l) do
            fs:SetJustifyH("LEFT")
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", t.frame, "TOPLEFT", x, -(top + lineH / 2) + oy)
            x = x + fs:GetWidth() + PART_GAP
        end
        top = top + lineH
    end
    return math.max(1, top)
end

function UI:LayoutText()
    if not (self.text and self.frame) then return end
    self.frame:SetHeight(self:PlaceText(self.parts, Addon.MainWindow:GetJustifyH("Timer")))
end

function UI:Build()
    if self.frame then return end

    local hud = Addon.MainWindow:Get()
    local width = Addon.MainWindow:GetWidth()

    local textBlock = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerTimerBlock")
    textBlock:SetSize(width, 20)
    -- Own FontStrings, so the second value and the best time have own sizes.
    local text = Addon.Widgets:CreateText(textBlock, ns.E.timerText)
    local secondText = Addon.Widgets:CreateText(textBlock, ns.E.timerText)
    local bestText = Addon.Widgets:CreateText(textBlock, ns.E.timerText)
    secondText:Hide()
    bestText:Hide()
    self.frame, self.text, self.bestText = textBlock, text, bestText
    self.parts = { frame = textBlock, main = text, second = secondText, best = bestText }
    self:ApplyTextFonts(self.parts)
    -- The column width arrives after the first placement.
    textBlock:SetScript("OnSizeChanged", function() UI:LayoutText() end)

    local barBlock = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerTimerBarBlock")
    barBlock:SetSize(width, 14)
    local bar = Addon.Widgets:CreateBar(barBlock, ns.E.timerBar)
    self.barFrame, self.bar = barBlock, bar

    -- Own frame level, so dividers and labels always draw on top of the fill.
    local overlay = CreateFrame("Frame", nil, barBlock)
    overlay:SetAllPoints(barBlock)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 10)
    self.overlay = overlay

    -- On the overlay, not the bar, so they survive split-bar mode. The 100%
    -- marker is label-only: its "line" is the bar's own end edge.
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

    self:LayoutText()
    self:LayoutBar()
    bar:SetReverseFill(Addon:GetElementSetting(ns.E.timerBar).reverse == true)
    bar:SetScript("OnSizeChanged", function() UI:LayoutDividers() end)
    self:LayoutDividers()

    textBlock:Hide()
    barBlock:Hide()
    Addon.MainWindow:AddBlock("timer", textBlock, 10)
    Addon.MainWindow:AddBlock("timerbar", barBlock, 11)
end

-- Text and bar follow their own flags while the timer is shown.
function UI:ApplyBlocksShown()
    if not (self.frame and self.barFrame) then return end
    local s = Timer:GetSettings()
    self.frame:SetShown(self.visible == true and s.showText ~= false)
    self.barFrame:SetShown(self.visible == true and s.showBar ~= false)
end

function Timer:ApplyBlocksShown()
    self.UI:ApplyBlocksShown()
    Addon.MainWindow:Layout()
end

function UI:Show()
    self:Build()
    self.visible = true
    self:ApplyBlocksShown()
    Addon.MainWindow:Layout()
end

function UI:Hide()
    self.visible = false
    if self.frame then self.frame:Hide() end
    if self.barFrame then self.barFrame:Hide() end
    Addon.MainWindow:Layout()
end

-- mode: above/below (outside, centered on the line), left/right (outside, to
-- one side), barLeft/barRight (inside the bar).
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
    else -- above
        label:SetPoint("BOTTOM", line, "TOP", lx, 2 + ly)
    end
end

-- Markers sit at the threshold positions, or at the segment gap centers in
-- split-bar mode. Visibility is UpdateSections' job.
function UI:LayoutDividers()
    if not self.barFrame or not self.dividers then return end

    local split = isSplit()
    local frameW = self.barFrame:GetWidth()
    if not frameW or frameW <= 0 then frameW = Addon.MainWindow:GetWidth() end
    local bottomExtra = self._barBottom or 0

    local reverse = Addon:GetElementSetting(ns.E.timerBar).reverse == true
    local barStyle = Addon.Widgets.ResolveStyle(ns.E.timerBar)
    local fillElapsed = barStyle.barFill ~= "remaining"
    local dc = barStyle.sectionDividerColor or { 1, 1, 1, 0.65 }
    local dw = Addon.Widgets:Snap(self.barFrame, barStyle.dividerWidth or 1, 1)
    local h = barStyle.height or 14

    local barW = (barStyle.width and barStyle.width > 0) and barStyle.width or frameW
    local barLeft = Addon.Widgets:Snap(self.barFrame, (frameW - barW) / 2)

    local ls = Addon.Widgets.ResolveStyle(ns.E.timerSection)
    local mode = ls.countdownPos or "above"
    local lx, ly = Addon.Widgets:GetOffset(ns.E.timerSection)

    for i, line in ipairs(self.dividers) do
        local x
        if split and not line._labelOnly then
            x = (self._boundaryX and self._boundaryX[i]) or (frameW * line._threshold)
        else
            -- Also used by the label-only limit marker, so it lands on the bar's
            -- end edge, mirrored when the fill is reversed.
            local base = fillElapsed and line._threshold or (1 - line._threshold)
            local frac = reverse and (1 - base) or base
            x = Addon.Widgets:Snap(self.barFrame, barLeft + barW * frac)
        end

        line:ClearAllPoints()
        line:SetSize(dw, h)
        line:SetPoint("BOTTOMLEFT", self.barFrame, "BOTTOMLEFT", x, bottomExtra)
        line:SetColorTexture(dc[1], dc[2], dc[3], dc[4] or 1)
        if split or line._labelOnly then line:Hide() end -- label anchor only

        if line.label then
            line.label:SetFont(ls.font, ls.fontSize or 11, ls.fontFlags)
            Addon.Widgets:ApplyShadow(line.label, ls)
            anchorCountdown(line.label, line, mode, lx, ly)
        end
    end
end

function UI:UpdateSections(elapsed, timeLimit)
    if not self.dividers then return end
    elapsed = elapsed or 0
    local limit = timeLimit or 0
    local split = isSplit()
    local s = Timer:GetSettings()
    local showCountdown = s.sectionCountdown == true
    local showAll = s.sectionCountdownAll == true -- all thresholds, not just the next

    local nearest
    for _, line in ipairs(self.dividers) do
        local tTime = line._threshold * limit
        if elapsed < tTime and (not nearest or tTime < nearest) then nearest = tTime end
    end

    for _, line in ipairs(self.dividers) do
        local tTime = line._threshold * limit
        local passed = limit > 0 and elapsed >= tTime
        if split or passed or line._labelOnly then line:Hide() else line:Show() end
        if line.label then
            if showCountdown and not passed and (showAll or tTime == nearest) then
                local cd = Addon.Utils.FormatTime(tTime - elapsed)
                line.label:SetText(cd)
                -- Stable width + LEFT, or the ticking countdown jitters.
                local w = Addon.Widgets:StableTextWidth(ns.E.timerSection, cd, line.label)
                if w then line.label:SetWidth(w) end
                line.label:SetJustifyH("LEFT")
                line.label:Show()
            else
                line.label:Hide()
            end
        end
    end
end

-- Each segment fills relative to its own time slice (split-bar mode).
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
    elseif self.bar then
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

    -- The ticker runs at 0.1s for a smooth bar fill, but the text only has
    -- second resolution, so gate the string work on a real change -- rebuilding
    -- it every tick allocated ~10x more garbage. Restyle resets the gate.
    local sec = math.floor(elapsed)
    local best = Addon.db.profile.ui.showBest == true and bestTotal or nil
    if self._lastSec ~= sec or self._lastLimit ~= timeLimit or self._lastBest ~= best then
        self._lastSec, self._lastLimit, self._lastBest = sec, timeLimit, best
        self:FillText(self.parts, elapsed, timeLimit, best)
        self:LayoutText()
        self:UpdateSections(elapsed, timeLimit)
    end
end

function UI:Restyle()
    if not self.frame then return end
    -- Clear the Update gates, or a font/color change would only show on the
    -- next second boundary.
    self._lastSec, self._lastLimit, self._lastBest = nil, nil, nil
    self:ApplyTextFonts(self.parts)
    Addon.Widgets:ApplyBarStyle(self.bar, ns.E.timerBar)
    if self.segBars then
        for _, seg in ipairs(self.segBars) do
            Addon.Widgets:ApplyBarStyle(seg, ns.E.timerBar)
        end
    end
    self:LayoutText()
    self:LayoutBar()
    self:ApplyBlocksShown()
    self.bar:SetReverseFill(Addon:GetElementSetting(ns.E.timerBar).reverse == true)
    self:LayoutDividers()
    Addon.MainWindow:ApplyPosition()
end
