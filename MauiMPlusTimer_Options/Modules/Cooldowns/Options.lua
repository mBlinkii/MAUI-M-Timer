-- Modules/Cooldowns/Options.lua
-- AceConfig pages for the Cooldowns blocks: battle resurrections and Heroism.

local _, ns = ...
local Addon = ns.Addon
local Cooldowns = Addon:GetModule("Cooldowns")

local ICON = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\cooldowns"

local function head(blockKey)
    return { enabled = Addon:BlockEnableOption(blockKey, 1) }
end

function Cooldowns:GetOptionPages()
    local L = ns.L

    -- The charge count follows the base text color, the recharge timer its own.
    local brezArgs = head("brez")
    brezArgs.text = Addon:ElementTextOptions(self, ns.E.brezText, 20, { color = true })
    brezArgs.text.args.rechargeColor = Addon:ElementColorOption(self, ns.E.brezText, "rechargeColor",
        L["Recharge color"], 15, { 0.60, 0.60, 0.60, 1 })

    local lustArgs = head("bloodlust")
    lustArgs.symbols = {
        type = "group", inline = true, name = L["Symbols"], order = 10,
        args = {
            readyIcon = Addon:IconSelectOption(self, "ready", "readyIcon", L["Heroism ready icon"], 1),
            nl = Addon:OptLine(2),
            readyIconColor = Addon:IconColorOption(self, "readyIconColor", L["Heroism ready icon color"], 3),
        },
    }
    lustArgs.text = Addon:ElementTextOptions(self, ns.E.lustText, 20, { color = true })
    lustArgs.text.args.cdColor = Addon:ElementColorOption(self, ns.E.lustText, "cdColor",
        L["Cooldown color"], 14, { 1, 0.38, 0.38, 1 })

    return {
        brez = { type = "group", name = L["Battle resurrections"], order = 70, icon = ICON, args = brezArgs },
        bloodlust = { type = "group", name = L["Heroism"], order = 71, icon = ICON, args = lustArgs },
    }
end
