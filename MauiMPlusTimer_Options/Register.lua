-- MauiMPlusTimer_Options/Register.lua
-- Builds every page once all builders are loaded, and registers the tree with
-- AceConfigRegistry so a NotifyChange reaches the open window.

local _, ns = ...
local Addon = ns.Addon

Addon:RegisterModuleOptions("globalfont", Addon:BuildGlobalFontOptions(), "root")
Addon:RegisterModuleOptions("colors", Addon:BuildColorsOptions(), "root")
Addon:RegisterModuleOptions("window", Addon:BuildWindowOptions(), "root")
Addon:RegisterModuleOptions("about", Addon:BuildAboutOptions(), "root")
Addon:RegisterModuleOptions("separators", Addon:BuildSeparatorOptions(), "modules")

for _, module in Addon:IterateModules() do
    local group = module.optionsKey and module:GetOptions()
    if group then
        Addon:RegisterModuleOptions(module.optionsKey, group, module.optionsCategory)
    end
    -- Modules split into several HUD blocks bring one page per block.
    if module.GetOptionPages then
        for key, page in pairs(module:GetOptionPages()) do
            Addon:RegisterModuleOptions(key, page, module.optionsCategory)
        end
    end
end

LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(ns.ADDON_NAME, function() return Addon:BuildOptions() end)
