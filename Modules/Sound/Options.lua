-- Modules/Sound/Options.lua
-- AceConfig options group for the Sound module: a per-trigger enable toggle and
-- sound selection. Triggers are disabled while the module itself is off.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Sound = Addon:GetModule("Sound")

local function moduleOff()
    return Sound:GetSettings().enabled ~= true
end

function Sound:GetOptions()
    local L = ns.L

    -- Build an inline group (toggle + sound select) for one trigger.
    local function triggerGroup(key, name, order)
        return {
            type = "group",
            inline = true,
            name = name,
            order = order,
            disabled = moduleOff,
            args = {
                on = {
                    type = "toggle",
                    name = L["Enable"],
                    order = 1,
                    get = function() return Sound:GetSettings().triggers[key].on end,
                    set = function(_, v) Sound:GetSettings().triggers[key].on = v end,
                },
                sound = {
                    type = "select",
                    name = L["Sound"],
                    order = 2,
                    dialogControl = "LSM30_Sound",
                    values = function() return Sound.Data.GetSoundList() end,
                    get = function() return Sound:GetSettings().triggers[key].sound or "None" end,
                    set = function(_, v)
                        Sound:GetSettings().triggers[key].sound = v
                        Sound.Data.Play(v) -- preview
                    end,
                },
            },
        }
    end

    return {
        type = "group",
        name = L["Sound"],
        order = 80,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\sound",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            death     = triggerGroup("death", L["Death"], 10),
            forces    = triggerGroup("forces", L["Forces complete"], 11),
            timeout   = triggerGroup("timeout", L["Time expired"], 12),
            completed  = triggerGroup("completed", L["Run completed"], 13),
            checkpoint = triggerGroup("checkpoint", L["Checkpoint reached"], 14),
            heroism    = triggerGroup("heroism", L["Heroism active"], 15),
        },
    }
end
