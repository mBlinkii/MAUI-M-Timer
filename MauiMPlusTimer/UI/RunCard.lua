-- UI/RunCard.lua
-- Private AceGUI container with a runtime-colourable border, used by the Splits
-- manager. Its own widget type gives it its own object pool, so recolouring
-- cannot leak into the pools shared by InlineGroup/SimpleGroup.

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI then return end

local Type, Version = "MMTRunCard", 1
if (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local pairs, unpack = pairs, unpack
local CreateFrame, UIParent = CreateFrame, UIParent

-- Restored on acquire, so a pooled card never keeps a previous run's colour.
local DEFAULT_BORDER = { 0.4, 0.4, 0.4, 1 }

local GAP = 2 -- px below each card, so stacked borders stay separated

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

    -- No args resets to neutral.
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
