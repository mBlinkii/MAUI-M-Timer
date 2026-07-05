-- UI/Widgets.lua
-- Frame/region factory and pools. Modules build their displays ONLY through
-- this layer so we stay frugal with frames (ARCHITECTURE.md 8.6). Styling is
-- resolved from: theme defaults -> global style overrides (profile.ui.style)
-- -> per-element overrides (profile.ui.elements[key]).

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Widgets = {}
ns.Widgets = Widgets
Addon.Widgets = Widgets

-- Resolved styles are cached per element key because resolving (merging theme +
-- global font + per-element override into a fresh table) is called very often
-- (every timer tick, every scenario update). Without the cache this churned a
-- lot of short-lived tables and inflated the addon's memory. The cache is wiped
-- whenever styles can change (Widgets:InvalidateStyle, called from restyle /
-- MainWindow:Refresh / profile change). Callers must treat the result as
-- read-only (they only read fields), which they do.
local styleCache = {}

-- Merge theme -> global font baseline -> per-element override into one table.
local function resolveStyle(elementKey)
    local cacheKey = elementKey or "\1base"
    local cached = styleCache[cacheKey]
    if cached then return cached end

    local style = {}
    for k, v in pairs(Addon:GetTheme()) do style[k] = v end

    -- Global font baseline (font, fontSize, fontFlags) applies to everything.
    local font = Addon.db and Addon.db.profile.ui.font
    if font then
        for k, v in pairs(font) do style[k] = v end
    end

    local override = elementKey and Addon.db and Addon.db.profile.ui.elements[elementKey] or nil
    if override then
        for k, v in pairs(override) do style[k] = v end
    end

    styleCache[cacheKey] = style
    return style
end
Widgets.ResolveStyle = resolveStyle

-- Drop all cached resolved styles (call after any style/profile change).
function Widgets:InvalidateStyle()
    wipe(styleCache)
end

-- Shared +/- comparison color and best-time color. The resolution lives in
-- Core/Utilities (so the Core formatters have no UI dependency); these methods
-- remain as the UI-layer API for options/widget code.
function Widgets:GetDeltaColor(ahead)
    return Addon.Utils.GetDeltaColor(ahead)
end

function Widgets:GetBestColor()
    return Addon.Utils.GetBestColor()
end

-- Build a texture escape for an inline icon. Falls back to the default texture
-- when the configured path is empty/nil, so a cleared value never produces a
-- broken icon. size 0 = match the surrounding text height.
-- When color ({r,g,b} in 0..1) is given, the icon is tinted via the long
-- vertex-color form, which needs an explicit size (0 falls back to 16). Without
-- a color the compact form is used so the auto-size behaviour is preserved.
function Widgets:IconEscape(path, default, size, color)
    if not path or path == "" then path = default end
    size = size or 0
    if color then
        local r = math.floor((color[1] or 1) * 255 + 0.5)
        local g = math.floor((color[2] or 1) * 255 + 0.5)
        local b = math.floor((color[3] or 1) * 255 + 0.5)
        local s = (size > 0) and size or 16
        -- |Tpath:h:w:offX:offY:texW:texH:l:r:t:b:rC:gC:bC|t (full texture, RGB 0-255).
        return string.format("|T%s:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t", path, s, s, r, g, b)
    end
    return "|T" .. path .. ":" .. size .. "|t"
end

-- The stored best time wrapped in the configurable bracket characters
-- (profile.ui.bestPrefix / bestSuffix, default "(" / ")"; either may be empty).
-- No color. Returns "" for nil. Used for the timer's own best-time FontString.
function Widgets:BestText(seconds)
    if not seconds then return "" end
    local ui = Addon.db and Addon.db.profile.ui
    local pre = (ui and ui.bestPrefix) or "("
    local suf = (ui and ui.bestSuffix) or ")"
    return pre .. Addon.Utils.FormatTime(seconds) .. suf
end

-- Same as BestText but tinted with the best-time color, for inline use behind
-- other elements (Enemy Forces, Objectives). Returns "" for nil.
function Widgets:FormatBest(seconds)
    if not seconds then return "" end
    return "|c" .. Addon.Utils.ColorHex(self:GetBestColor()) .. self:BestText(seconds) .. "|r"
end

-- Per-element x/y text offset (pixels).
function Widgets:GetOffset(elementKey)
    local s = resolveStyle(elementKey)
    return s.xOffset or 0, s.yOffset or 0
end

-- True rendered line height for a text element, so modules size and position
-- their text by what the font actually occupies (not a guess) and never overlap
-- when the size grows. Measured with a hidden FontString using the element's
-- real font + flags; falls back to an estimate if measurement is unavailable.
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

-- Replace visible digits with the widest digit ("8") while leaving WoW escape
-- sequences (|T texture |t, |c color, |r) untouched, so a ticking value keeps a
-- constant rendered width (it depends on the digit layout, not the values) and
-- icons/colors still measure correctly.
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

-- Width (px) a text occupies with the element's font, measured with every
-- visible digit treated as the widest one. Modules SetWidth a frequently
-- updating text (running timer, cooldown) to this so it never resizes per tick
-- and stops pushing neighboring elements around. nil if unmeasurable.
function Widgets:StableTextWidth(elementKey, text)
    if not text then return nil end
    local s = resolveStyle(elementKey)
    if not s.font then return nil end
    if not measureFS then measureFS = UIParent:CreateFontString(nil, "ARTWORK") end
    if not measureFS:SetFont(s.font, s.fontSize or 14, s.fontFlags) then return nil end
    measureFS:SetText(widenDigits(text))
    local w = measureFS:GetStringWidth()
    -- +2px safety margin: with word wrap disabled the line can never break, so
    -- the reserved width must comfortably exceed the rendered width to avoid
    -- truncation when outline flags / font hinting make the glyphs slightly
    -- wider than GetStringWidth reports.
    if w and w > 0 then return math.ceil(w) + 2 end
    return nil
end

-- Anchor a single-line FontString to ONE point matching the alignment (the same
-- approach the timer text uses): LEFT -> left edge, RIGHT -> right edge,
-- CENTER -> center. This repositions reliably on a direct left<->right switch,
-- unlike a full-width anchor that depends on SetJustifyH reflowing in place.
-- vAnchor "TOP" pins to the top of the parent; otherwise vertically centered.
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

-- Create a container frame (one per module block, not one per element).
function Widgets:CreateContainer(parent, name)
    return CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
end

-- Apply font + text color from the resolved style to a FontString.
function Widgets:ApplyTextStyle(fs, elementKey)
    local style = resolveStyle(elementKey)
    fs:SetFont(style.font, style.fontSize, style.fontFlags)
    fs:SetTextColor(unpack(style.textColor))
    return style
end

-- Create a styled FontString region on a frame.
-- HUD text elements are single-line displays (timer, sections, deaths, ...).
-- Word wrap is disabled so a width-constrained value (see StableTextWidth) can
-- never spill onto a second line when a particular font/size renders a hair
-- wider than the reserved width. Width is kept generous in StableTextWidth so
-- the single line is never truncated either.
function Widgets:CreateText(parent, elementKey, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetWordWrap(false)
    self:ApplyTextStyle(fs, elementKey)
    return fs
end

-- Default border edge texture (a real bordered texture, not a solid block).
local DEFAULT_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
-- Default statusbar fill texture.
local DEFAULT_BAR = "Interface\\TargetingFrame\\UI-StatusBar"

-- Resolve a stored media value to an actual texture path. Settings now store the
-- LibSharedMedia *name* (chosen via the preview dropdowns), but legacy/preset
-- data stored a raw path. Names are resolved through LibSharedMedia; a raw path
-- (containing a separator) is passed through unchanged; anything else falls back
-- to `fallback`. This keeps styling correct no matter which form was saved.
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

-- Whether the border is enabled. Honors the explicit toggle, falling back to
-- "on when a size was set" so older profiles keep their border.
local function borderEnabled(style)
    if style.borderOn ~= nil then return style.borderOn == true end
    return (style.borderSize or 0) > 0
end

-- Apply (or refresh) a border on a frame from a style table. The border lives on
-- a dedicated child frame so it can be offset from the frame's edges (positive
-- offset = outside the frame). borderSize is the edge thickness, borderTexture
-- the edge file.
function Widgets:ApplyBorder(frame, style)
    -- Clear any legacy backdrop set directly on the frame itself.
    if frame.SetBackdrop then frame:SetBackdrop(nil) end

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

-- Apply an optional panel (background fill + border) to a BackdropTemplate frame
-- from a bg settings table: { show, color, border, borderTexture, borderSize,
-- borderColor }. The border requires the background, so with the background off
-- the whole panel is cleared. Shared by the HUD panel and the dungeon block.
function Widgets:ApplyPanel(frame, bg)
    bg = bg or {}
    local showBorder = bg.show and bg.border
    local backdrop
    if bg.show then
        backdrop = { bgFile = "Interface\\Buttons\\WHITE8X8" }
        if showBorder then
            backdrop.edgeFile = mediaPath("border", bg.borderTexture, DEFAULT_BORDER)
            backdrop.edgeSize = bg.borderSize or 12
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

-- Apply texture + background + border (not the fill color, which is dynamic).
function Widgets:ApplyBarStyle(bar, elementKey)
    local style = resolveStyle(elementKey)
    bar:SetStatusBarTexture(mediaPath("statusbar", style.barTexture, DEFAULT_BAR))
    if bar.bg then
        bar.bg:SetTexture(mediaPath("statusbar", style.barTexture, DEFAULT_BAR))
        bar.bg:SetVertexColor(unpack(style.bgColor))
    end
    self:ApplyBorder(bar, style)
    return style
end

-- Create a styled StatusBar region with a background and border.
function Widgets:CreateBar(parent, elementKey)
    local style = resolveStyle(elementKey)
    local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
    bar:SetStatusBarColor(unpack(style.barColor))

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bar.bg = bg

    self:ApplyBarStyle(bar, elementKey)
    return bar
end

-- Reusable frame pool for recurring rows.
function Widgets:CreateRowPool(parent, template, resetFn)
    return CreateFramePool("Frame", parent, template, resetFn)
end

-- Module UI base ------------------------------------------------------------
-- Shared behaviour for a module's UI table. Show/Hide are identical across
-- modules (build lazily, toggle the block, relayout the HUD), so they live here
-- instead of being copied into every module. A module overrides Build, Update,
-- Restyle (and, if needed, Show/Hide) on the table returned by NewModuleUI.

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

-- Build is module-specific; the base is a no-op so Show works before a module
-- has defined its own Build (it never should reach this in practice).
function UIBase:Build() end

-- Create a fresh UI table inheriting the shared Show/Hide (and any base passed
-- in, e.g. the text-block base below).
function Addon:NewModuleUI(base)
    return setmetatable({}, { __index = base or UIBase })
end

-- Single-line text block base ------------------------------------------------
-- Many modules are just one line of text in the HUD (deaths, splits,
-- checkpoints, ...). They share the same Build/Restyle; only the displayed text
-- (Update) differs. A module creates its UI with NewTextBlockUI{...} and then
-- implements only Update. Spec fields:
--   name     module name (used for the alignment lookup + block name/key)
--   element  per-element style key (e.g. "deathsText")
--   order    stacking order in the HUD
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

-- Create a text-block UI table from a spec; the module implements only Update.
function Addon:NewTextBlockUI(spec)
    local ui = setmetatable({}, { __index = TextBlock })
    ui.name = spec.name
    ui.element = spec.element
    ui.order = spec.order
    return ui
end
