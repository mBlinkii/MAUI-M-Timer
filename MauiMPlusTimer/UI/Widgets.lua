-- UI/Widgets.lua
-- Frame/region factory and pools; modules build their displays only through
-- this layer. Style chain: theme -> profile.ui.font -> profile.ui.elements[key].

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Widgets = {}
ns.Widgets = Widgets
Addon.Widgets = Widgets

-- Resolving runs on every tick and every scenario update; without this cache
-- the short-lived merge tables dominated the addon's memory. Results are
-- shared, so callers must treat them as read-only.
local styleCache = {}

local function resolveStyle(elementKey)
    local cacheKey = elementKey or "\1base"
    local cached = styleCache[cacheKey]
    if cached then return cached end

    local style = {}
    for k, v in pairs(Addon:GetTheme()) do style[k] = v end

    local font = Addon.db and Addon.db.profile.ui.font
    if font then
        for k, v in pairs(font) do style[k] = v end
    end

    local override = elementKey and Addon.db and Addon.db.profile.ui.elements[elementKey] or nil
    if override then
        for k, v in pairs(override) do style[k] = v end
    end

    -- The outline renderer is a global choice rather than an element's, and it
    -- rides on whatever outline the element already asked for. ns.OT owns the
    -- probe; it is loaded by the time any style is resolved.
    local OT = ns.OT
    if OT and OT:FontFlags() == "SLUG" then
        style.fontFlags = (style.fontFlags and style.fontFlags ~= "")
            and (style.fontFlags .. ",SLUG") or "SLUG"
    end

    styleCache[cacheKey] = style
    return style
end
Widgets.ResolveStyle = resolveStyle

-- Mandatory after any style or profile change.
function Widgets:InvalidateStyle()
    wipe(styleCache)
end

-- UI-layer API; the resolution lives in Core/Utilities so the Core formatters
-- have no dependency on this file.
function Widgets:GetDeltaColor(ahead)
    return Addon.Utils.GetDeltaColor(ahead)
end

function Widgets:GetBestColor()
    return Addon.Utils.GetBestColor()
end

-- A length or offset in `region`'s coordinates rounded to whole screen pixels,
-- so thin lines and gaps render at the same width at any HUD scale.
function Widgets:Snap(region, value, minPixels)
    return PixelUtil.GetNearestPixelSize(value, region:GetEffectiveScale(), minPixels)
end

-- Inline icons follow the element's font size rather than a fixed pixel size.
function Widgets:IconSize(elementKey)
    return math.floor((resolveStyle(elementKey).fontSize or 14) + 0.5)
end

-- size 0 matches the surrounding text height. A color forces the long
-- vertex-color form, which needs an explicit size, so 0 becomes 16 there.
function Widgets:IconEscape(path, default, size, color)
    if not path or path == "" then path = default end
    size = size or 0
    if color then
        local r = math.floor((color[1] or 1) * 255 + 0.5)
        local g = math.floor((color[2] or 1) * 255 + 0.5)
        local b = math.floor((color[3] or 1) * 255 + 0.5)
        local s = (size > 0) and size or 16
        -- |Tpath:h:w:offX:offY:texW:texH:l:r:t:b:rC:gC:bC|t, RGB 0-255.
        return string.format("|T%s:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t", path, s, s, r, g, b)
    end
    return "|T" .. path .. ":" .. size .. "|t"
end

-- Best time in the configurable brackets, uncolored. "" for nil.
function Widgets:BestText(seconds)
    if not seconds then return "" end
    local ui = Addon.db and Addon.db.profile.ui
    local pre = (ui and ui.bestPrefix) or "("
    local suf = (ui and ui.bestSuffix) or ")"
    return pre .. Addon.Utils.FormatTime(seconds) .. suf
end

-- BestText tinted with the best-time color, for inline use.
function Widgets:FormatBest(seconds)
    if not seconds then return "" end
    return "|c" .. Addon.Utils.ColorHex(self:GetBestColor()) .. self:BestText(seconds) .. "|r"
end

function Widgets:GetOffset(elementKey)
    local s = resolveStyle(elementKey)
    return s.xOffset or 0, s.yOffset or 0
end

-- Measured with a hidden FontString rather than estimated, so blocks never
-- overlap when the font size grows.
local measureFS
function Widgets:LineHeight(elementKey, fallback)
    local s = resolveStyle(elementKey)
    local size = s.fontSize or fallback or 14
    if s.font then
        if not measureFS then
            measureFS = UIParent:CreateFontString(nil, "ARTWORK")
        end
        if measureFS:SetFont(s.font, size, s.fontFlags) then
            measureFS:SetText("Ag|")
            local h = measureFS:GetStringHeight()
            if h and h > 0 then return math.ceil(h) + 4 end
        end
    end
    return math.ceil(size * 1.3) + 4
end

-- Replaces digits with the widest one, leaving |T/|c/|r escapes intact, so a
-- ticking value measures to a constant width.
local function widenDigits(text)
    local out, i, n = {}, 1, #text
    while i <= n do
        local c = text:sub(i, i)
        if c == "|" then
            local nxt = text:sub(i + 1, i + 1)
            if nxt == "T" then
                local _, e = text:find("|t", i + 2, true)
                e = e or n
                out[#out + 1] = text:sub(i, e); i = e + 1
            elseif nxt == "c" then
                out[#out + 1] = text:sub(i, i + 9); i = i + 10 -- |c + 8 hex digits
            elseif nxt == "r" then
                out[#out + 1] = "|r"; i = i + 2
            else
                out[#out + 1] = c; i = i + 1
            end
        elseif c:match("%d") then
            out[#out + 1] = "8"; i = i + 1
        else
            out[#out + 1] = c; i = i + 1
        end
    end
    return table.concat(out)
end

-- Modules SetWidth a ticking text to this, so it stops resizing every tick and
-- pushing its neighbours around. nil if unmeasurable.
function Widgets:StableTextWidth(elementKey, text)
    if not text then return nil end
    local s = resolveStyle(elementKey)
    if not s.font then return nil end
    if not measureFS then measureFS = UIParent:CreateFontString(nil, "ARTWORK") end
    if not measureFS:SetFont(s.font, s.fontSize or 14, s.fontFlags) then return nil end
    measureFS:SetText(widenDigits(text))
    local w = measureFS:GetStringWidth()
    -- +2px: outline flags and font hinting can render slightly wider than
    -- GetStringWidth reports, and word wrap is off, so it would be truncated.
    if w and w > 0 then return math.ceil(w) + 2 end
    return nil
end

-- Anchors to a single point matching the alignment; a full-width anchor would
-- rely on SetJustifyH reflowing in place and misses a direct left<->right
-- switch. vAnchor "TOP" pins to the top, otherwise vertically centered.
function Widgets:LayoutText(fs, parent, elementKey, justify, vAnchor)
    local x, y = self:GetOffset(elementKey)
    justify = justify or "CENTER"
    local top = (vAnchor == "TOP")
    fs:ClearAllPoints()
    if justify == "LEFT" then
        fs:SetPoint(top and "TOPLEFT" or "LEFT", parent, top and "TOPLEFT" or "LEFT", x, y)
    elseif justify == "RIGHT" then
        fs:SetPoint(top and "TOPRIGHT" or "RIGHT", parent, top and "TOPRIGHT" or "RIGHT", x, y)
    else
        fs:SetPoint(top and "TOP" or "CENTER", parent, top and "TOP" or "CENTER", x, y)
    end
    fs:SetJustifyH(justify)
end

-- One per module block, never one per element.
function Widgets:CreateContainer(parent, name)
    return CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
end

function Widgets:ApplyTextStyle(fs, elementKey)
    local style = resolveStyle(elementKey)
    fs:SetFont(style.font, style.fontSize, style.fontFlags)
    fs:SetTextColor(unpack(style.textColor))
    return style
end

-- Word wrap off: HUD texts are single-line, and a width-constrained value must
-- never spill onto a second line (StableTextWidth reserves the space instead).
function Widgets:CreateText(parent, elementKey, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetWordWrap(false)
    self:ApplyTextStyle(fs, elementKey)
    return fs
end

-- Flat, like the bars: the rounded tooltip edge clashes with the square HUD.
local DEFAULT_BORDER = "Interface\\Buttons\\WHITE8X8"
local DEFAULT_BAR = "Interface\\TargetingFrame\\UI-StatusBar"

-- Settings store a LibSharedMedia name, but legacy and preset data stored raw
-- paths, so both forms have to resolve.
local function mediaPath(mtype, value, fallback)
    if not value or value == "" then return fallback end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local path = LSM:Fetch(mtype, value, true) -- noDefault: nil if not a name
        if path then return path end
    end
    if type(value) == "string" and value:find("\\") then return value end -- legacy raw path
    return fallback
end

-- Without an explicit toggle a set size counts as on, so older profiles keep
-- their border.
local function borderEnabled(style)
    if style.borderOn ~= nil then return style.borderOn == true end
    return (style.borderSize or 0) > 0
end

-- The border lives on a child frame so it can sit outside the frame's edges
-- (positive borderOffset).
function Widgets:ApplyBorder(frame, style)
    if frame.SetBackdrop then frame:SetBackdrop(nil) end -- clear legacy backdrops

    local size = style.borderSize or 0
    if not borderEnabled(style) or size <= 0 then
        if frame.borderFrame then frame.borderFrame:Hide() end
        return
    end

    if not frame.borderFrame then
        frame.borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end
    local b = frame.borderFrame
    local off = style.borderOffset or 0
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", -off, off)
    b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", off, -off)
    b:SetBackdrop({ edgeFile = mediaPath("border", style.borderTexture, DEFAULT_BORDER), edgeSize = size })
    b:SetBackdropBorderColor(unpack(style.borderColor or { 0, 0, 0, 1 }))
    b:Show()
end

-- The border requires the background, so bg.show off clears the whole panel.
function Widgets:ApplyPanel(frame, bg)
    bg = bg or {}
    local showBorder = bg.show and bg.border
    local backdrop
    if bg.show then
        backdrop = { bgFile = "Interface\\Buttons\\WHITE8X8" }
        if showBorder then
            backdrop.edgeFile = mediaPath("border", bg.borderTexture, DEFAULT_BORDER)
            backdrop.edgeSize = bg.borderSize or 1
        end
    end
    frame:SetBackdrop(backdrop) -- nil clears any previous panel
    if backdrop then
        local c = bg.color or { 0, 0, 0, 0.6 }
        frame:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
        if showBorder then
            local bc = bg.borderColor or { 0, 0, 0, 1 }
            frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
        end
    end
end

local DEFAULT_EDGE_COLOR = { 1, 1, 1, 1 }
local DEFAULT_GRADIENT_MULT = 0.5
local DEFAULT_GRADIENT_COLOR = { 1, 1, 1, 1 }

local function lerp(from, to, t)
    return from + (to - from) * t
end

-- Repaints the fill as a gradient from the bar's own color to that color scaled
-- by the multiplier, so the second stop follows every color change on its own -
-- the Timer recolors per bonus section, and nothing should have to know that.
-- The two ColorMixins are cached per bar because this runs on every tick.
local function updateGradient(bar, r, g, b, a)
    if not bar._gradientOn then return end
    local fill = bar:GetStatusBarTexture()
    if not (fill and fill.SetGradient) then return end
    a = a or 1

    -- Far end of the fade across the whole bar: a fixed color when one is set,
    -- otherwise the bar color scaled by the multiplier.
    local er, eg, eb, ea
    local custom = bar._gradientColor
    if custom then
        er, eg, eb, ea = custom[1], custom[2], custom[3], custom[4] or a
    else
        local m = bar._gradientMult or DEFAULT_GRADIENT_MULT
        er, eg, eb, ea =
            math.min(r * m, 1), math.min(g * m, 1), math.min(b * m, 1), a
    end

    -- Slice of the overall fade this bar covers, so neighbouring segments meet
    -- on the same color. Swapping mirrors the run instead of flipping the stops
    -- per bar, which would break that at every segment boundary.
    local t0, t1 = bar._gradT0 or 0, bar._gradT1 or 1
    if bar._gradientSwap then t0, t1 = 1 - t0, 1 - t1 end

    bar._gradFrom = bar._gradFrom or CreateColor(1, 1, 1, 1)
    bar._gradTo = bar._gradTo or CreateColor(1, 1, 1, 1)
    bar._gradFrom:SetRGBA(
        lerp(r, er, t0), lerp(g, eg, t0), lerp(b, eb, t0), lerp(a, ea, t0))
    bar._gradTo:SetRGBA(
        lerp(r, er, t1), lerp(g, eg, t1), lerp(b, eb, t1), lerp(a, ea, t1))
    fill:SetGradient("HORIZONTAL", bar._gradFrom, bar._gradTo)
end

-- Which part of the overall fade a split segment covers, as screen-space
-- fractions of the full bar (left to right). Set by the split layouts; a bar
-- that never calls this simply spans the whole range.
function Widgets:SetBarGradientRange(bar, t0, t1)
    bar._gradT0, bar._gradT1 = t0, t1
    if bar._gradientOn then
        bar:SetStatusBarColor(bar:GetStatusBarColor())
    end
end

-- Turning the gradient off needs no reset of its own: re-issuing the current
-- color writes a plain vertex color, which is what clears a gradient.
function Widgets:ApplyBarGradient(bar, style)
    bar._gradientOn = style.gradientOn == true
    bar._gradientMult = style.gradientMult or DEFAULT_GRADIENT_MULT
    bar._gradientSwap = style.gradientSwap == true
    -- nil unless the custom end color is switched on; the multiplier path keys
    -- on its absence.
    bar._gradientColor = (style.gradientCustom == true)
        and (style.gradientColor or DEFAULT_GRADIENT_COLOR) or nil
    bar:SetStatusBarColor(bar:GetStatusBarColor())
end

-- Only while the fill is actually moving: at either end the line sits on the
-- bar's own edge, where it reads as a stray border rather than a marker.
local function updateEdgeShown(bar)
    if not bar.edge then return end
    local min, max = bar:GetMinMaxValues()
    local value = bar:GetValue() or 0
    bar.edge:SetShown(bar._edgeOn == true
        and value > (min or 0) and value < (max or 0))
end

-- Thin line at the moving edge of the fill. Anchored to the fill texture itself,
-- so it follows every SetValue without a ticker of its own.
function Widgets:ApplyBarEdge(bar, style)
    local edge = bar.edge
    if not edge then return end

    bar._edgeOn = style.edgeOn == true
    if not bar._edgeOn then
        edge:Hide()
        return
    end

    local c = style.edgeColor or DEFAULT_EDGE_COLOR
    edge:SetColorTexture(c[1], c[2], c[3], c[4] or 1)

    -- Centered on the edge, so the line straddles it instead of sitting inside
    -- the fill; mirrored with the fill direction.
    local w = math.max(1, style.edgeWidth or 2)
    local side = style.reverse and "LEFT" or "RIGHT"
    local dx = style.reverse and -(w / 2) or (w / 2)
    local fill = bar:GetStatusBarTexture()
    local h = style.edgeHeight or 0

    edge:SetWidth(w)
    edge:ClearAllPoints()
    if h > 0 then
        -- Fixed height, centered on the bar; a single point leaves the height
        -- to SetHeight instead of letting the fill stretch it.
        edge:SetHeight(h)
        edge:SetPoint("CENTER", fill, side, dx, 0)
    else
        edge:SetPoint("TOP" .. side, fill, "TOP" .. side, dx, 0)
        edge:SetPoint("BOTTOM" .. side, fill, "BOTTOM" .. side, dx, 0)
    end
    updateEdgeShown(bar)
end

-- Not the fill color; that one is dynamic.
function Widgets:ApplyBarStyle(bar, elementKey)
    local style = resolveStyle(elementKey)
    bar:SetStatusBarTexture(mediaPath("statusbar", style.barTexture, DEFAULT_BAR))
    if bar.bg then
        bar.bg:SetTexture(mediaPath("statusbar", style.barTexture, DEFAULT_BAR))
        bar.bg:SetVertexColor(unpack(style.bgColor))
    end
    self:ApplyBorder(bar, style)
    self:ApplyBarEdge(bar, style)
    self:ApplyBarGradient(bar, style)
    return style
end

function Widgets:CreateBar(parent, elementKey)
    local style = resolveStyle(elementKey)
    local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
    bar:SetStatusBarColor(unpack(style.barColor))

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bar.bg = bg

    bar.edge = bar:CreateTexture(nil, "OVERLAY")
    bar.edge:Hide()
    -- SetValue is the only thing that moves the fill, so the visibility check
    -- rides along with it instead of polling.
    hooksecurefunc(bar, "SetValue", updateEdgeShown)
    hooksecurefunc(bar, "SetStatusBarColor", updateGradient)

    self:ApplyBarStyle(bar, elementKey)
    return bar
end

function Widgets:CreateRowPool(parent, template, resetFn)
    return CreateFramePool("Frame", parent, template, resetFn)
end

-- Shared base for a module's UI table; modules override Build, Update and
-- Restyle on the table returned by NewModuleUI.
local UIBase = {}
ns.UIBase = UIBase

function UIBase:Show()
    self:Build()
    if self.frame then self.frame:Show() end
    Addon.MainWindow:Layout()
end

function UIBase:Hide()
    if self.frame then self.frame:Hide() end
    Addon.MainWindow:Layout()
end

-- No-op so Show works before a module defines its own Build.
function UIBase:Build() end

function Addon:NewModuleUI(base)
    return setmetatable({}, { __index = base or UIBase })
end

-- Base for the one-line HUD modules: shared Build/Restyle, only Update differs.
local TextBlock = setmetatable({}, { __index = UIBase })
ns.TextBlockUI = TextBlock

function TextBlock:Build()
    if self.frame then return end
    local hud = Addon.MainWindow:Get()
    local block = Widgets:CreateContainer(hud, "MauiMPlusTimer" .. self.name .. "Block")
    block:SetSize(Addon.MainWindow:GetWidth(), Widgets:LineHeight(self.element))

    self.text = Widgets:CreateText(block, self.element)
    self.frame = block
    Widgets:LayoutText(self.text, block, self.element, Addon.MainWindow:GetJustifyH(self.name))
    block:Hide()
    Addon.MainWindow:AddBlock(self.name:lower(), block, self.order)
end

function TextBlock:Restyle()
    if not (self.frame and self.text) then return end
    Widgets:ApplyTextStyle(self.text, self.element)
    self.frame:SetHeight(Widgets:LineHeight(self.element))
    Widgets:LayoutText(self.text, self.frame, self.element, Addon.MainWindow:GetJustifyH(self.name))
end

-- spec: name (module name, also the block key), element (style key), order.
function Addon:NewTextBlockUI(spec)
    local ui = setmetatable({}, { __index = TextBlock })
    ui.name = spec.name
    ui.element = spec.element
    ui.order = spec.order
    return ui
end
