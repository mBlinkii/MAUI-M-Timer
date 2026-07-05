-- UI/RunCard.lua
-- A small private AceGUI container widget: a bordered "card" whose border colour
-- can be set at runtime. Used by the Splits manager to flag stored runs as timed
-- (green) or over time (red).
--
-- It is registered under a unique widget type ("MMTRunCard") so it has its own
-- AceGUI object pool. Recolouring the border therefore never leaks into the
-- shared pools used by stock widgets (InlineGroup/SimpleGroup), which is why a
-- dedicated widget is used instead of recolouring an InlineGroup border.

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI then return end

local Type, Version = "MMTRunCard", 1
if (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local pairs, unpack = pairs, unpack
local CreateFrame, UIParent = CreateFrame, UIParent

-- Neutral default border (used until SetBorderColor overrides it, and restored
-- on acquire so a pooled card never keeps a previous run's colour).
local DEFAULT_BORDER = { 0.4, 0.4, 0.4, 1 }

-- Vertical gap (px) left below each card so stacked cards in a List layout show
-- a small visual separation between their borders.
local GAP = 2

local backdrop = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local methods = {
    ["OnAcquire"] = function(self)
        self:SetWidth(300)
        self:SetHeight(100)
        self:SetBorderColor() -- reset to neutral
    end,

    -- Set the card's border colour. Called with no args resets to neutral.
    ["SetBorderColor"] = function(self, r, g, b, a)
        if not r then r, g, b, a = unpack(DEFAULT_BORDER) end
        self.border:SetBackdropBorderColor(r, g, b, a or 1)
    end,

    ["LayoutFinished"] = function(self, width, height)
        if self.noAutoHeight then return end
        self:SetHeight((height or 0) + 20 + GAP)
    end,

    ["OnWidthSet"] = function(self, width)
        local content = self.content
        local w = width - 20
        if w < 0 then w = 0 end
        content:SetWidth(w)
        content.width = w
    end,

    ["OnHeightSet"] = function(self, height)
        local content = self.content
        local h = height - 20
        if h < 0 then h = 0 end
        content:SetHeight(h)
        content.height = h
    end,
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, GAP)
    border:SetBackdrop(backdrop)
    border:SetBackdropColor(0.08, 0.08, 0.08, 0.55)
    border:SetBackdropBorderColor(unpack(DEFAULT_BORDER))

    -- Container content area (AceGUI lays the card's children out in here).
    local content = CreateFrame("Frame", nil, border)
    content:SetPoint("TOPLEFT", 8, -8)
    content:SetPoint("BOTTOMRIGHT", -8, 8)

    local widget = {
        frame   = frame,
        border  = border,
        content = content,
        type    = Type,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
