-- Modules/Cooldowns/Options.lua
-- AceConfig options group for the Cooldowns module.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Cooldowns = Addon:GetModule("Cooldowns")

-- Re-apply the display immediately after a toggle so changes are visible at once
-- (in demo mode too, without re-toggling demo).
local function refresh()
    if Cooldowns.state.demo then
        Cooldowns:SetDemo(true)
    elseif Cooldowns:IsEnabled() and Addon.RunState:Get() then
        Cooldowns:Start()
    end
end

function Cooldowns:GetOptions()
    local L = ns.L

    -- Separate colors for the lust cooldown countdown and the battle-rez recharge
    -- timer; the charge count itself follows the base text color.
    local textOpts = Addon:ElementTextOptions(self, ns.E.cooldownsText, 20, { color = true })
    textOpts.args.cdColor = Addon:ElementColorOption(self, ns.E.cooldownsText, "cdColor", L["Cooldown color"], 14, { 1, 0.38, 0.38, 1 })
    textOpts.args.rechargeColor = Addon:ElementColorOption(self, ns.E.cooldownsText, "rechargeColor", L["Recharge color"], 15, { 0.60, 0.60, 0.60, 1 })

    local function moduleOff() return Cooldowns:GetSettings().enabled == false end
    local function lustOff()
        local s = Cooldowns:GetSettings()
        return s.enabled == false or not (s.lust and s.lust.on)
    end

    return {
        type = "group",
        name = L["Cooldowns"],
        order = 70,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\cooldowns",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            settings = {
                type = "group", inline = true, name = L["Settings"], order = 2,
                args = {
                    align = Addon:ModuleAlignOption(self, 1),
                    brez = {
                        type = "toggle", name = L["Battle resurrections"], order = 2,
                        desc = L["Show available battle resurrections and the recharge timer."],
                        disabled = moduleOff,
                        get = function() local s = Cooldowns:GetSettings(); return s.brez and s.brez.on end,
                        set = function(_, v)
                            local s = Cooldowns:GetSettings(); s.brez = s.brez or {}; s.brez.on = v; refresh()
                        end,
                    },
                    lust = {
                        type = "toggle", name = L["Heroism availability"], order = 3,
                        desc = L["Show when Heroism/Bloodlust is available again."],
                        disabled = moduleOff,
                        get = function() local s = Cooldowns:GetSettings(); return s.lust and s.lust.on end,
                        set = function(_, v)
                            local s = Cooldowns:GetSettings(); s.lust = s.lust or {}; s.lust.on = v; refresh()
                        end,
                    },
                },
            },
            symbols = {
                type = "group", inline = true, name = L["Symbols"], order = 10,
                args = {
                    readyIcon = Addon:IconSelectOption(self, "ready", "readyIcon", L["Heroism ready icon"], 1,
                        { disabled = lustOff }),
                    nl = Addon:OptLine(2),
                    readyIconColor = Addon:IconColorOption(self, "readyIconColor", L["Heroism ready icon color"], 3,
                        { disabled = lustOff }),
                },
            },
            text = textOpts,
        },
    }
end
