-- Modules/Deaths/UI.lua
-- One-line block with the death count and the time penalty.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Deaths = Addon:GetModule("Deaths")

local UI = Addon:NewTextBlockUI({ name = "Deaths", element = ns.E.deathsText, order = 40 })
Deaths.UI = UI

local DEFAULT_SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local function skull()
    local s = Deaths:GetSettings()
    return Addon.Widgets:IconEscape(s.icon, DEFAULT_SKULL, Addon.Widgets:IconSize(ns.E.deathsText), s.iconColor)
end

function UI:Update(count, timeLost)
    if not self.frame then return end
    self:Remember(count, timeLost)
    count = count or 0
    timeLost = timeLost or 0
    if count <= 0 then
        self.text:SetText(skull() .. " 0")
    else
        local penHex = Addon.Utils.ColorHex(
            Addon:GetElementSetting(ns.E.deathsText).penaltyColor or { 1, 0.38, 0.38, 1 })
        self.text:SetText(string.format(
            "%s %d  |c%s(+%s)|r",
            skull(), count, penHex, Addon.Utils.FormatTime(timeLost)))
    end
end
