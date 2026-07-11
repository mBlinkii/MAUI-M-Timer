-- Modules/Checkpoints/UI.lua
-- HUD block showing how far the current forces % is ahead/behind the per-boss
-- and per-time targets. Hidden when no targets apply. A single-line text block:
-- Build/Restyle/Show/Hide come from the shared text-block base, so this file
-- only defines the content (Update).

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Checkpoints = Addon:GetModule("Checkpoints")

local UI = Addon:NewTextBlockUI({ name = "Checkpoints", element = ns.E.checkpointsText, order = 60 })
Checkpoints.UI = UI

-- Inline icons that can replace the "Boss" / "PoNR" labels (module option
-- "labelIcons"); they scale with the font and are tinted via the per-icon
-- color settings ("bossIconColor" / "ponrIconColor").
local ICON_BOSS_PATH = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Labels\\boss.tga"
local ICON_PONR_PATH = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Labels\\ponr.tga"

-- sectionDelta: forces-% difference to the current boss target (positive =
-- ahead), or nil. ponr: { next, remaining } for the next not-yet-reached Point
-- of No Return threshold, or nil. When both are nil the whole block hides.
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
    -- The boss label/delta keeps its semantic green/red coloring; the Point of
    -- No Return readout uses the configurable element text color (it is a target
    -- to reach, not an ahead/behind pace). Optionally both labels are replaced
    -- by compact icons with their own tint.
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
