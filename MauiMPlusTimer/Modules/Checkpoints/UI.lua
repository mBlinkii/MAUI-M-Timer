-- Modules/Checkpoints/UI.lua
-- One-line block showing the distance to the per-boss and PoNR targets.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Checkpoints = Addon:GetModule("Checkpoints")

local UI = Addon:NewTextBlockUI({ name = "Checkpoints", element = ns.E.checkpointsText, order = 60 })
Checkpoints.UI = UI

-- Optional replacements for the "Boss" / "PoNR" labels.
local ICON_BOSS_PATH = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Labels\\boss.tga"
local ICON_PONR_PATH = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Labels\\ponr.tga"

-- sectionDelta: forces-% to the current boss target, positive is ahead.
-- ponr: { next, remaining }. Both nil hides the block.
function UI:Update(sectionDelta, ponr)
    self:Build()
    if sectionDelta == nil and ponr == nil then
        self.frame:Hide()
        Addon.MainWindow:Layout()
        return
    end

    local L = ns.L
    local settings = Checkpoints:GetSettings()
    local useIcons = settings.labelIcons == true
    local parts = {}
    -- The boss delta keeps the semantic green/red; PoNR uses the plain element
    -- color, since it is a target to reach, not an ahead/behind pace.
    if sectionDelta ~= nil then
        local label = useIcons
            and Addon.Utils.IconTag(ICON_BOSS_PATH, settings.bossIconColor) or L["Boss"]
        parts[#parts + 1] = label .. " " .. Addon.Utils.FormatPctDelta(sectionDelta)
    end
    if ponr ~= nil then
        local label = useIcons
            and Addon.Utils.IconTag(ICON_PONR_PATH, settings.ponrIconColor) or L["PoNR"]
        parts[#parts + 1] = string.format("%s %g%% (+%.1f%%)",
            label, ponr.next, math.max(ponr.remaining or 0, 0))
    end

    self.text:SetText(table.concat(parts, "   "))
    self.frame:Show()
    Addon.MainWindow:Layout()
end
