-- UI/Options/Preview.lua
-- Development harness: renders one of every control against a scratch table so
-- the widget layer can be judged in game before Render.lua exists. Opened with
-- /mauimpt controls. Strings are developer-facing and stay unlocalized; the
-- file is removed once the real settings window renders real option pages.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local OT = ns.OT
local Controls = ns.Controls

local Preview = {}
Addon.OptionPreview = Preview

local WIDTH, HEIGHT = 440, 640
local PAD = OT.space.lg

-- Stand-in for a profile table; the sample nodes read and write only this.
local scratch = {
    toggle = true,
    locked = false,
    size = 18,
    scale = 1,
    align = "center",
    color = { 0.161, 0.659, 0.941, 1 },
    tint = { 0.941, 0.251, 0.627, 0.5 },
    name = "MAUI",
    share = "MMT:1:abcdef0123456789",
}

local function field(key)
    return function() return scratch[key] end, function(_, v) scratch[key] = v end
end

local function colorField(key)
    return function()
        local c = scratch[key]
        return c[1], c[2], c[3], c[4]
    end, function(_, r, g, b, a)
        scratch[key] = { r, g, b, a }
    end
end

local sizeGet, sizeSet = field("size")
local scaleGet, scaleSet = field("scale")
local toggleGet, toggleSet = field("toggle")
local lockedGet, lockedSet = field("locked")
local alignGet, alignSet = field("align")
local nameGet, nameSet = field("name")
local shareGet, shareSet = field("share")
local colorGet, colorSet = colorField("color")
local tintGet, tintSet = colorField("tint")

-- Disabled while the first toggle is off, so the disabled styling of every
-- control type can be checked without a second sample of each.
local function gated()
    return not scratch.toggle
end

local SAMPLES = {
    { kind = "Header", node = { name = "Toggles" } },
    { kind = "Toggle", node = { name = "Enable element", desc = "Turns the whole sample block on.",
        get = toggleGet, set = toggleSet } },
    { kind = "Toggle", node = { name = "Lock position", disabled = gated,
        get = lockedGet, set = lockedSet } },

    { kind = "Header", node = { name = "Ranges" } },
    { kind = "Range", node = { name = "Font size", min = 8, max = 64, step = 1, disabled = gated,
        get = sizeGet, set = sizeSet } },
    { kind = "Range", node = { name = "Scale", min = 0.5, max = 2, step = 0.05, isPercent = true,
        get = scaleGet, set = scaleSet } },

    { kind = "Header", node = { name = "Select" } },
    { kind = "Select", node = { name = "Alignment", desc = "Text alignment for this element.",
        values = { left = "Left", center = "Center", right = "Right" },
        get = alignGet, set = alignSet } },
    { kind = "Select", node = { name = "Alignment (disabled)", disabled = gated,
        values = { left = "Left", center = "Center", right = "Right" },
        get = alignGet, set = alignSet } },

    { kind = "Header", node = { name = "Colors" } },
    { kind = "Color", node = { name = "Bar color", get = colorGet, set = colorSet } },
    { kind = "Color", node = { name = "Background tint", hasAlpha = true, disabled = gated,
        get = tintGet, set = tintSet } },

    { kind = "Header", node = { name = "Text" } },
    { kind = "Input", node = { name = "Profile name", get = nameGet, set = nameSet } },
    { kind = "Input", node = { name = "Share string", multiline = true,
        get = shareGet, set = shareSet } },

    { kind = "Header", node = { name = "Actions" } },
    { kind = "Execute", node = { name = "Apply", func = function()
        Addon:Debug("Preview: apply pressed")
    end } },
    { kind = "Execute", node = { name = "Reset", confirm = true,
        confirmText = "Reset every sample value?",
        func = function()
            scratch.size, scratch.scale, scratch.align = 18, 1, "center"
            Addon:Debug("Preview: reset confirmed")
        end } },
    { kind = "Description", node = { name =
        "Description nodes wrap at the content width and report their measured height back to the layout, which is how the renderer will size them." } },
}

local function build()
    if Preview.frame then return Preview.frame end

    local f = CreateFrame("Frame", "MauiMPlusTimerControlPreview", UIParent)
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    OT:Fill(f, "base")
    OT:Outline(f, "lineStrong")

    local title = OT:Text(f, "title", "text")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("Control preview")

    local close = CreateFrame("Button", nil, f)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -OT.space.sm, -OT.space.sm)
    local x = OT:Text(close, "heading", "muted")
    x:SetPoint("CENTER")
    x:SetText("x")
    close:SetScript("OnEnter", function() x:SetTextColor(OT:Unpack("danger")) end)
    close:SetScript("OnLeave", function() x:SetTextColor(OT:Unpack("muted")) end)
    close:SetScript("OnClick", function() Preview:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", PAD, -(PAD + OT.size.header))
    scroll:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - PAD * 2, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(s, delta)
        local range = max(0, content:GetHeight() - s:GetHeight())
        s:SetVerticalScroll(min(range, max(0, s:GetVerticalScroll() - delta * 40)))
    end)

    f.content = content
    tinsert(UISpecialFrames, "MauiMPlusTimerControlPreview")
    Preview.frame = f
    return f
end

-- Rebuilt on every show: the harness has no diffing, which is exactly what
-- Render.lua will have to add.
function Preview:Layout()
    local f = self.frame
    local width = f.content:GetWidth()
    local y = 0

    Controls:ReleaseAll()
    for i = 1, #SAMPLES do
        local sample = SAMPLES[i]
        local control = Controls:Acquire(sample.kind, f.content)
        control:SetOption(sample.node)
        control:SetWidth(width)
        control.frame:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -y)
        y = y + control:GetHeight() + OT.space.sm
    end
    f.content:SetHeight(max(1, y))
end

function Preview:Show()
    build()
    self:Layout()
    self.frame:Show()
end

function Preview:Hide()
    if not self.frame then return end
    Controls:CloseList()
    Controls:ReleaseAll()
    self.frame:Hide()
end

function Preview:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
