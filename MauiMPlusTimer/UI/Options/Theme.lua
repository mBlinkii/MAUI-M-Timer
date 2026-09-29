-- UI/Options/Theme.lua
-- Design tokens for the settings window (ns.OT, "options theme"). Deliberately
-- fixed: ns.Themes and profile.ui style the HUD and must not reach the chrome.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local OT = {}
ns.OT = OT

-- Flat by design: solid fills plus hairlines, no edge files anywhere here.
OT.color = {
    base       = { 0.090, 0.106, 0.133, 0.94 },
    baseTop    = { 0.169, 0.192, 0.239, 0.94 },
    -- Translucent, but it has to read darker than the content panel over any
    -- background: too little alpha and the bright world behind lifts it above
    -- the body instead. tools/check_options_ui.lua checks the composite.
    sidebar    = { 0.051, 0.063, 0.078, 0.90 },
    sidebarTop = { 0.102, 0.118, 0.149, 0.90 },
    header     = { 0.141, 0.165, 0.204, 0.97 },
    headerTop  = { 0.200, 0.227, 0.282, 0.97 },
    -- The dropdown list floats over the page, so it cannot take the page's
    -- alpha -- what is under it would read through the entries. It takes the
    -- window's darkest tone at almost full alpha instead: solid enough to read
    -- on, and the same material rather than a lighter grey plate.
    raised     = { 0.075, 0.086, 0.110, 0.97 },
    card       = { 1.000, 1.000, 1.000, 0.030 },
    input      = { 0.055, 0.067, 0.086, 0.55 },
    -- accent, selected and the two hover tints take the player's class colour
    -- (see OT:Unpack); the values here are the fallback until the unit exists,
    -- and their alphas are what keeps the four states apart.
    hover       = { 0.161, 0.659, 0.941, 0.14 },
    hoverStrong = { 0.161, 0.659, 0.941, 0.20 },
    selected    = { 0.161, 0.659, 0.941, 0.32 },

    line       = { 1.000, 1.000, 1.000, 0.10 },
    lineStrong = { 1.000, 1.000, 1.000, 0.20 },
    switchOff  = { 1.000, 1.000, 1.000, 0.17 },

    text       = { 0.941, 0.941, 0.941, 1.00 },
    muted      = { 0.604, 0.627, 0.671, 1.00 },
    faint      = { 0.420, 0.447, 0.502, 1.00 },

    accent     = { 0.161, 0.659, 0.941, 1.00 },
    on         = { 0.251, 0.753, 0.341, 1.00 },
    warn       = { 0.941, 0.565, 0.125, 1.00 },
    danger     = { 0.941, 0.290, 0.290, 1.00 },
    pink       = { 0.941, 0.251, 0.627, 1.00 },
}

OT.space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24 }

-- Four widths for the widget in a labelled row, and nothing in between. A
-- button that hugs its own text is a different width in every row, which is
-- what made a column of rows look ragged; rounding up to the next step costs a
-- little air and buys an order that can be seen.
OT.width = { xs = 56, sm = 96, md = 140, lg = 200 }
OT.widthOrder = { "xs", "sm", "md", "lg" }

-- The step that fits, or the largest one. Never smaller than what was asked
-- for, unless nothing fits: a clipped label is worse than a wide button.
function OT:SnapWidth(want)
    for i = 1, #self.widthOrder do
        local step = self.width[self.widthOrder[i]]
        if want <= step then return step end
    end
    return max(want, self.width.lg)
end

OT.size = {
    row     = 26,
    control = 22,
    check   = 15,
    swatch  = 17,
    sidebar = 208,
    header  = 44,
    indent  = 14,
    listRow = 21,
    listMax = 14,
}

-- Sidebar dots. A module keeps its colour whatever the accent is, so the list
-- stays readable at a glance; anything not listed falls back to the muted grey.
OT.moduleColor = {
    Dungeon     = { 0.353, 0.722, 0.941 },
    Timer       = { 0.941, 0.706, 0.161 },
    EnemyForces = { 0.878, 0.341, 0.290 },
    Objectives  = { 0.310, 0.820, 0.773 },
    Splits      = { 0.949, 0.482, 0.627 },
    Checkpoints = { 0.561, 0.820, 0.310 },
    Deaths      = { 0.518, 0.580, 0.659 },
    Cooldowns   = { 0.710, 0.494, 0.863 },
    Sound       = { 0.941, 0.565, 0.310 },
    Automation  = { 0.839, 0.827, 0.310 },
}

OT.font = {
    title   = 18,
    heading = 14,
    normal  = 12,
    small   = 11,
}

-- The window's own typeface, by LibSharedMedia name. Friz Quadrata is the
-- client default and is hard going at 11 and 12 pixels, so a cleaner face is
-- preferred when one is registered.
local FACE_PREFERENCE = { "Expressway", "PT Sans Narrow", "Roboto", "Continuum Medium" }

-- Shapes the window draws with. dot.tga holds two glyphs side by side, a
-- filled disc and a ring, picked with the tex coords below.
local ASSETS = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Options\\"
OT.DOT = ASSETS .. "dot"
OT.DOT_FILLED = { 0, 0.5, 0, 1 }
OT.DOT_RING = { 0.5, 1, 0, 1 }
OT.SWITCH = ASSETS .. "switch"

-- Tiled grain overlay. The tile is a power of two and seamless, so the repeat
-- is done through tex coords that follow the frame size.
OT.NOISE = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Options\\noise"
OT.BACKDROP = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Options\\backdrop"
OT.TRASH = ASSETS .. "trash"
OT.CLOSE = ASSETS .. "close"
OT.RESET = ASSETS .. "reset"
OT.NOISE_TILE = 128

local px

-- One physical pixel in UI units. Hairlines carry the whole visual language,
-- so a half-pixel line that blurs at some resolutions is not acceptable.
function OT:Pixel()
    if not px then
        local _, height = GetPhysicalScreenSize()
        px = 768 / (height or 768) / (UIParent:GetScale() or 1)
    end
    return px
end

-- Call after a UI scale change; the next Pixel() re-measures.
function OT:InvalidatePixel()
    px = nil
end

-- Regions painted from the accent, so a change repaints them in place. A
-- rebuild is not an option: WoW never destroys a frame, so dropping the widget
-- pools would leak every one of them.
local fills, vertices, washes, gradients = {}, {}, {}, {}

-- Every text region this file makes, with the size key it was made at, so a
-- change of face can re-apply it: a FontString keeps no reference to its font.
local texts = {}
local face

local classColor

-- The player's class colour, resolved on first use: at file load the unit does
-- not necessarily exist yet, so a miss is not cached. CUSTOM_CLASS_COLORS is
-- the community table other addons write, and honouring it keeps the window in
-- step with whatever the rest of the UI uses.
function OT:ClassColor()
    if classColor then
        return classColor[1], classColor[2], classColor[3]
    end
    local _, class = UnitClass("player")
    -- Fall through rather than switching tables: a custom table that is missing
    -- this class should not cost the Blizzard colour.
    local c = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if not c then
        local fallback = self.color.accent
        return fallback[1], fallback[2], fallback[3]
    end
    classColor = { c.r, c.g, c.b }
    return c.r, c.g, c.b
end

function OT:InvalidateClassColor()
    classColor = nil
end

-- The accent the settings window paints with: the player's class colour, or the
-- one stored in the profile. Falls back to the class while the database is not
-- up yet, which is the case while the very first frames are built.
function OT:AccentColor()
    local db = Addon.db
    local profile = db and db.profile
    local cfg = profile and profile.ui and profile.ui.accent
    local mode = cfg and cfg.mode or "class"
    if mode == "custom" and cfg.color then
        return cfg.color[1], cfg.color[2], cfg.color[3]
    end
    if mode == "default" then
        local c = self.color.accent
        return c[1], c[2], c[3]
    end
    return self:ClassColor()
end

-- The window's own surfaces, the ones the opacity slider thins out. The
-- semantic colours and anything drawn on top of a surface keep their alpha, or
-- a see-through window would take its text with it.
local SURFACE = {
    base = true, baseTop = true, sidebar = true, sidebarTop = true,
    header = true, headerTop = true, input = true, raised = true,
}

local function windowAlpha()
    local db = Addon.db
    local profile = db and db.profile
    local cfg = profile and profile.ui and profile.ui.window
    local alpha = cfg and cfg.alpha
    if type(alpha) ~= "number" then return 1 end
    return min(1, max(0.3, alpha))
end

-- Everything that marks a live or chosen element is painted from the accent.
-- Only the alpha stays fixed, so the four states are told apart by strength
-- rather than by hue -- a bright colour tints a row instead of flooding it, and
-- a selected row still stands out under the cursor. The semantic colours (on,
-- warn, danger, pink) are deliberately not in here.
local ACCENT_TINTED = {
    accent = true, selected = true, hover = true, hoverStrong = true,
}

function OT:IsAccentKey(key)
    return ACCENT_TINTED[key] == true
end

-- The LibSharedMedia name of the face in use, so the dropdown shows what is
-- actually on screen rather than an empty "automatic".
function OT:FaceName()
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM then return "" end
    local path = self:Face()
    for name, file in pairs(LSM:HashTable("font")) do
        if file == path then return name end
    end
    return ""
end

function OT:Face()
    if face then return face end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local db = Addon.db
    local profile = db and db.profile
    local chosen = profile and profile.ui and profile.ui.window and profile.ui.window.font

    if LSM then
        if chosen and LSM:IsValid("font", chosen) then
            face = LSM:Fetch("font", chosen)
        else
            for i = 1, #FACE_PREFERENCE do
                if LSM:IsValid("font", FACE_PREFERENCE[i]) then
                    face = LSM:Fetch("font", FACE_PREFERENCE[i])
                    break
                end
            end
        end
    end
    face = face or STANDARD_TEXT_FONT
    return face
end

-- WoW's Slug renderer builds glyphs from outlines instead of a rasterised
-- atlas, which is what makes text at 11 and 12 pixels hold together. Probed
-- once and guarded: a client that does not know the flag must not error.
local slugOk

function OT:SlugAvailable()
    if slugOk == nil then
        local probe = UIParent:CreateFontString(nil, "BACKGROUND")
        probe:Hide()
        local ok, valid = pcall(probe.SetFont, probe, STANDARD_TEXT_FONT, 12, "SLUG")
        slugOk = ok and valid ~= false
    end
    return slugOk
end

function OT:FontFlags()
    if not self:SlugAvailable() then return "" end
    local db = Addon.db
    local profile = db and db.profile
    local cfg = profile and profile.ui and profile.ui.window
    if cfg and cfg.slug == false then return "" end
    return "SLUG"
end

-- Sets a font and remembers the region, so FontChanged can re-apply it.
function OT:ApplyFont(region, sizeKey)
    texts[region] = sizeKey or "normal"
    region:SetFont(self:Face(), self.font[texts[region]], self:FontFlags())
    return region
end

function OT:FontChanged()
    face = nil
    local resolved, flags = self:Face(), self:FontFlags()
    for region, sizeKey in pairs(texts) do
        region:SetFont(resolved, self.font[sizeKey], flags)
    end
end

function OT:Unpack(key)
    local c = self.color[key] or self.color.text
    local alpha = c[4] or 1
    if SURFACE[key] then alpha = alpha * windowAlpha() end
    if ACCENT_TINTED[key] then
        local r, g, b = self:AccentColor()
        return r, g, b, alpha
    end
    return c[1], c[2], c[3], alpha
end

-- Paint a texture and, when the colour comes from the accent, remember it so a
-- later change repaints it. Calling this again with another key replaces the
-- entry, which is what the enabled/disabled switching in Refresh does.
function OT:Tint(region, key)
    fills[region] = key
    region:SetColorTexture(self:Unpack(key))
    return region
end

-- The same, for a shaped texture whose colour is a vertex tint (the chevron).
function OT:TintVertex(region, key)
    vertices[region] = key
    region:SetVertexColor(self:Unpack(key))
    return region
end

-- A time bar is not an accent: it says how much of the dungeon timer a run
-- used, so it has to read as good or bad on its own. Green with time to spare,
-- through amber, red at the limit. The two ends are the colours the +/- times
-- already use, so the bar and the number beside it never disagree.
local PROGRESS_MID = 0.85

local function deltaColor(ahead, fallback)
    local Utils = Addon.Utils
    local c = Utils and Utils.GetDeltaColor and Utils.GetDeltaColor(ahead)
    if type(c) == "table" and c[1] then return c end
    return OT.color[fallback]
end

function OT:Progress(progress)
    local p = min(1, max(0, progress or 0))
    local from, to, t
    if p <= PROGRESS_MID then
        from, to, t = deltaColor(true, "on"), self.color.warn, p / PROGRESS_MID
    else
        from, to, t = self.color.warn, deltaColor(false, "danger"),
            (p - PROGRESS_MID) / (1 - PROGRESS_MID)
    end
    return from[1] + (to[1] - from[1]) * t,
        from[2] + (to[2] - from[2]) * t,
        from[3] + (to[3] - from[3]) * t, 1
end

-- Drops any accent registration the region had: this colour follows the run,
-- not the class.
function OT:PaintProgress(region, progress)
    fills[region] = nil
    region:SetColorTexture(self:Progress(progress))
    return region
end

function OT:Repaint()
    for region, key in pairs(fills) do
        region:SetColorTexture(self:Unpack(key))
    end
    for region, key in pairs(vertices) do
        region:SetVertexColor(self:Unpack(key))
    end
    for region, wash in pairs(washes) do
        self:PaintWash(region, wash.key, wash.alpha, wash.edge)
    end
    for texture, keys in pairs(gradients) do
        self:PaintGradient(texture, keys[1], keys[2])
    end
end

-- The opacity slider moves every surface at once, so it is the same repaint.
function OT:AlphaChanged()
    self:Repaint()
end

-- Clears the cached class colour and repaints everything the accent touches.
function OT:AccentChanged()
    classColor = nil
    self:Repaint()
end

function OT:Fill(frame, key, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(frame)
    return self:Tint(t, key)
end

-- Hairline on one edge: "TOP", "BOTTOM", "LEFT" or "RIGHT".
function OT:Line(frame, edge, key, inset)
    local t = frame:CreateTexture(nil, "BORDER")
    self:Tint(t, key or "line")
    local p = self:Pixel()
    inset = inset or 0
    if edge == "TOP" or edge == "BOTTOM" then
        t:SetHeight(p)
        t:SetPoint(edge .. "LEFT", frame, edge .. "LEFT", inset, 0)
        t:SetPoint(edge .. "RIGHT", frame, edge .. "RIGHT", -inset, 0)
    else
        t:SetWidth(p)
        t:SetPoint("TOP" .. edge, frame, "TOP" .. edge, 0, -inset)
        t:SetPoint("BOTTOM" .. edge, frame, "BOTTOM" .. edge, 0, inset)
    end
    return t
end

-- Four hairlines instead of a backdrop: crisper and one texture cheaper.
function OT:Outline(frame, key)
    return {
        self:Line(frame, "TOP", key), self:Line(frame, "BOTTOM", key),
        self:Line(frame, "LEFT", key), self:Line(frame, "RIGHT", key),
    }
end

-- Four hairlines around an arbitrary region, created on `parent`. Lets a framed
-- box be drawn without a Frame whose only job was to be something to anchor to.
function OT:OutlineRegion(parent, region, key)
    local lines, p = {}, self:Pixel()
    for i, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = parent:CreateTexture(nil, "BORDER")
        self:Tint(t, key or "line")
        if edge == "TOP" or edge == "BOTTOM" then
            t:SetHeight(p)
            t:SetPoint(edge .. "LEFT", region, edge .. "LEFT")
            t:SetPoint(edge .. "RIGHT", region, edge .. "RIGHT")
        else
            t:SetWidth(p)
            t:SetPoint("TOP" .. edge, region, "TOP" .. edge)
            t:SetPoint("BOTTOM" .. edge, region, "BOTTOM" .. edge)
        end
        lines[i] = t
    end
    return lines
end

function OT:Recolor(lines, key)
    for i = 1, #lines do
        self:Tint(lines[i], key)
    end
end

-- A colour key at a different alpha, for gradients that fade out.
function OT:Alpha(key, alpha)
    local r, g, b = self:Unpack(key)
    return { r, g, b, alpha }
end

-- SetGradient takes the low end first: bottom for VERTICAL, left for
-- HORIZONTAL. Alpha interpolates too, which is what lets a wash fade to
-- nothing rather than to a colour.
function OT:GradientFill(texture, orientation, from, to)
    texture:SetColorTexture(to[1], to[2], to[3], to[4] or 1)
    if texture.SetGradient and CreateColor then
        texture:SetGradient(orientation,
            CreateColor(from[1], from[2], from[3], from[4] or 1),
            CreateColor(to[1], to[2], to[3], to[4] or 1))
    end
    return texture
end

-- Vertical two-tone fill. A flat panel this large reads as dead space, and a
-- few percent of tone difference is enough to give it a top and a bottom.
function OT:Gradient(frame, topKey, bottomKey, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(frame)
    gradients[t] = { topKey, bottomKey }
    return self:PaintGradient(t, topKey, bottomKey)
end

function OT:PaintGradient(texture, topKey, bottomKey)
    return self:GradientFill(texture, "VERTICAL",
        { self:Unpack(bottomKey) }, { self:Unpack(topKey) })
end

-- Accent wash pinned to one edge, fading out across `width`. Gives the title
-- bar something of its own without turning it into a second colour field.
function OT:PaintWash(region, key, alpha, edge)
    local strong, gone = self:Alpha(key, alpha), self:Alpha(key, 0)
    if edge == "LEFT" then
        return self:GradientFill(region, "HORIZONTAL", strong, gone)
    end
    return self:GradientFill(region, "HORIZONTAL", gone, strong)
end

function OT:Wash(frame, key, alpha, width, edge, layer)
    local t = frame:CreateTexture(nil, layer or "BORDER")
    edge = edge or "LEFT"
    alpha = alpha or 0.10
    t:SetPoint("TOP" .. edge)
    t:SetPoint("BOTTOM" .. edge)
    t:SetWidth(width or 320)
    if ACCENT_TINTED[key] then
        washes[t] = { key = key, alpha = alpha, edge = edge }
    end
    return self:PaintWash(t, key, alpha, edge)
end

-- Additive so the grain only lifts; on a dark panel that reads as texture
-- instead of dirt. Over the backdrop its job is no longer texture but
-- dithering: a soft gradient across 600 pixels of a dark surface only has a
-- handful of steps to work with, and those show up as bands. One number for
-- all three panels, so it can be tuned in one place.
OT.NOISE_ALPHA = 0.02

function OT:Noise(frame, alpha, layer)
    local t = frame:CreateTexture(nil, layer or "BORDER")
    t:SetAllPoints(frame)
    t:SetTexture(self.NOISE, "REPEAT", "REPEAT")
    t:SetBlendMode("ADD")
    t:SetVertexColor(1, 1, 1, alpha or self.NOISE_ALPHA)
    return t
end

-- One picture behind the whole window rather than a tile: soft shapes survive
-- being stretched, which is exactly what grain cannot do. Each panel shows its
-- own slice (see PlaceBackdrop), so the bands run on across the three of them.
function OT:Backdrop(frame, alpha, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(frame)
    t:SetTexture(self.BACKDROP)
    t:SetBlendMode("ADD")
    t:SetVertexColor(1, 1, 1, alpha or 0.10)
    return t
end

-- The rectangle this panel occupies in the window, as fractions. Taken from
-- the layout rather than from GetLeft/GetTop: those are nil until the frame has
-- been placed, and a draw can happen before that.
function OT:PlaceBackdrop(texture, left, right, top, bottom)
    if not texture then return end
    texture:SetTexCoord(min(left, right), max(left, right),
        min(top, bottom), max(top, bottom))
end

function OT:TileNoise(texture, width, height)
    if not texture then return end
    texture:SetTexCoord(0, (width or 1) / self.NOISE_TILE, 0, (height or 1) / self.NOISE_TILE)
end

-- Shadow cleared on purpose: the default drop shadow reads as embossed.
function OT:Text(parent, sizeKey, colorKey, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    self:ApplyFont(fs, sizeKey)
    fs:SetTextColor(self:Unpack(colorKey or "text"))
    fs:SetShadowColor(0, 0, 0, 0)
    return fs
end
