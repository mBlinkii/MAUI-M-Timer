-- Modules/Automation/Options.lua
-- AceConfig options group for the Automation module: two independent toggles,
-- both disabled while the module itself is off.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Automation = Addon:GetModule("Automation")

local function moduleOff()
    return Automation:GetSettings().enabled ~= true
end

function Automation:GetOptions()
    local L = ns.L

    return {
        type = "group",
        name = L["Automation"],
        order = 85,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\automation",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            settings = {
                type = "group", inline = true, name = L["Settings"], order = 2,
                args = {
                    hideTracker = {
                        type = "toggle", name = L["Auto-hide objective tracker"], order = 1, width = "full",
                        desc = L["Hide Blizzard's objective tracker while a Mythic+ run is active."],
                        disabled = moduleOff,
                        get = function() return Automation:GetSettings().hideTracker == true end,
                        set = function(_, v) Automation:GetSettings().hideTracker = v; Automation:ApplyTracker() end,
                    },
                    autoSlotKeystone = {
                        type = "toggle", name = L["Auto-slot keystone"], order = 2, width = "full",
                        desc = L["Automatically place your keystone when the Font of Power is opened."],
                        disabled = moduleOff,
                        get = function() return Automation:GetSettings().autoSlotKeystone == true end,
                        set = function(_, v) Automation:GetSettings().autoSlotKeystone = v end,
                    },
                },
            },
        },
    }
end
