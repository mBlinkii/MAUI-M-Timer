-- Core/MinimapButton.lua
-- Self-contained minimap button plus the AddOn Compartment click handler.
-- State persists under the same db.profile.minimap keys LibDBIcon used
-- (hide, minimapPos), so positions saved by older versions carry over.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local ICON = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\icon_small"
local BUTTON_SIZE = 26
local EDGE_OFFSET = 5   -- how far the button sits outside the minimap edge
local DEFAULT_ANGLE = 207 -- degrees; matches the previous LibDBIcon default

local function settings()
    Addon.db.profile.minimap = Addon.db.profile.minimap or { hide = true }
    return Addon.db.profile.minimap
end

-- Square minimaps are detected via the GetMinimapShape addon convention.
local function updatePosition(button)
    local angle = math.rad(settings().minimapPos or DEFAULT_ANGLE)
    local cx, cy = math.cos(angle), math.sin(angle)
    local w = (Minimap:GetWidth() / 2) + EDGE_OFFSET
    local h = (Minimap:GetHeight() / 2) + EDGE_OFFSET

    local x, y
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        -- Project onto the square edge, clamped to the corners.
        x = math.max(-w, math.min(cx * w * 1.4142, w))
        y = math.max(-h, math.min(cy * h * 1.4142, h))
    else
        x, y = cx * w, cy * h
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Runs as the button's OnUpdate while dragging.
local function onDragUpdate(button)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    settings().minimapPos = math.deg(math.atan2(py - my, px - mx)) % 360
    updatePosition(button)
end

local function createButton()
    local button = CreateFrame("Button", "MauiMPlusTimerMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477) -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            Addon.Demo:Toggle()
        else
            Addon:ToggleOptions()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", onDragUpdate)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)

    button:SetScript("OnEnter", function(self)
        local L = ns.L
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine("MAUI M+ Timer")
        GameTooltip:AddLine("|cffeda55f" .. L["Left-click"] .. "|r: " .. L["Options"], 1, 1, 1)
        GameTooltip:AddLine("|cffeda55f" .. L["Right-click"] .. "|r: " .. L["Toggle demo"], 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

-- Called once from Addon:OnInitialize.
function Addon:SetupMinimapButton()
    if self.minimapButton then return end
    self.minimapButton = createButton()
    self:RefreshMinimapButton()
end

-- Re-applies position and visibility; both are per profile.
function Addon:RefreshMinimapButton()
    if not self.minimapButton then return end
    updatePosition(self.minimapButton)
    self.minimapButton:SetShown(not settings().hide)
end

function Addon:SetMinimapShown(show)
    settings().hide = not show
    self:RefreshMinimapButton()
end

-- Referenced by ## AddonCompartmentFunc in the .toc.
function _G.MauiMPlusTimer_OnCompartmentClick(_, _)
    Addon:ToggleOptions()
end
