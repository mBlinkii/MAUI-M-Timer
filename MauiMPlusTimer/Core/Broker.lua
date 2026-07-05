-- Core/Broker.lua
-- LibDataBroker launcher + optional LibDBIcon minimap button, and the AddOn
-- Compartment click handler. Left-click opens options, right-click toggles demo.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local ICON = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\icon_small"

-- Open the central options GUI.
function Addon:OpenOptions()
    if self.AceConfigDialog then
        self.AceConfigDialog:Open(ADDON_NAME)
    end
end

function Addon:SetupBroker()
    local LDB = LibStub("LibDataBroker-1.1", true)
    if not LDB then return end

    local dataobj = LDB:NewDataObject(ADDON_NAME, {
        type = "launcher",
        text = "MAUI M+ Timer",
        icon = ICON,
        OnClick = function(_, button)
            if button == "RightButton" then
                Addon.Demo:Toggle()
            else
                Addon:OpenOptions()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("MAUI M+ Timer")
            tt:AddLine("|cffeda55fLeft-click|r: Options", 1, 1, 1)
            tt:AddLine("|cffeda55fRight-click|r: Toggle demo", 1, 1, 1)
        end,
    })
    self.ldb = dataobj

    -- Minimap button (optional; saved show/hide + position live in the profile).
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if LDBIcon then
        self.db.profile.minimap = self.db.profile.minimap or { hide = true }
        LDBIcon:Register(ADDON_NAME, dataobj, self.db.profile.minimap)
    end
end

-- Show/hide the minimap button at runtime (from the options toggle).
function Addon:SetMinimapShown(show)
    self.db.profile.minimap = self.db.profile.minimap or { hide = true }
    self.db.profile.minimap.hide = not show
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if LDBIcon then
        if show then LDBIcon:Show(ADDON_NAME) else LDBIcon:Hide(ADDON_NAME) end
    end
end

-- AddOn Compartment entry click (referenced by ## AddonCompartmentFunc).
function _G.MauiMPlusTimer_OnCompartmentClick(_, _)
    Addon:OpenOptions()
end
