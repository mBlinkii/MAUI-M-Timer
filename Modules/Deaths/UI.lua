-- Modules/Deaths/UI.lua
-- HUD block showing the death count and the time penalty. A single-line text
-- block: Build/Restyle/Show/Hide come from the shared text-block base, so this
-- file only defines the displayed content (Update).

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Deaths = Addon:GetModule("Deaths")

local UI = Addon:NewTextBlockUI({ name = "Deaths", element = ns.E.deathsText, order = 40 })
Deaths.UI = UI

local DEFAULT_SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

-- The death-counter icon texture and tint are configurable (see Options). When a
-- tint is set the icon needs an explicit size, so it follows the text font size;
-- without a tint it stays auto-sized (0 = match the line height).
local function skull()
    local s = Deaths:GetSettings()
    local size = s.iconColor and math.floor(Addon.Widgets.ResolveStyle(ns.E.deathsText).fontSize or 16) or 0
    return Addon.Widgets:IconEscape(s.icon, DEFAULT_SKULL, size, s.iconColor)
end

function UI:Update(count, timeLost)
    if not self.frame then return end
    count = count or 0
    timeLost = timeLost or 0
    if count <= 0 then
        self.text:SetText(skull() .. " 0")
    else
        -- The time penalty uses its own configurable color.
        local penHex = Addon.Utils.ColorHex(
            Addon:GetElementSetting(ns.E.deathsText).penaltyColor or { 1, 0.38, 0.38, 1 })
        self.text:SetText(string.format(
            "%s %d  |c%s(+%s)|r",
            skull(), count, penHex, Addon.Utils.FormatTime(timeLost)))
    end
end
