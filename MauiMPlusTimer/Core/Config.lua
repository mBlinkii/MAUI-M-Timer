-- Core/Config.lua
-- The /mauimpt command, module states and the loader for the settings, which
-- live in the load-on-demand addon MauiMPlusTimer_Options.

local _, ns = ...
local Addon = ns.Addon

local OPTIONS_ADDON = "MauiMPlusTimer_Options"
local TITLE = "MAUI M+ Timer"

-- Loads the settings half on first use. Returns true once it is available.
function Addon:LoadOptions()
    if self.OptionsWindow then return true end
    local loaded, reason = C_AddOns.LoadAddOn(OPTIONS_ADDON)
    if not loaded then
        self:Error(ns.L["Could not load the settings (%s)."], _G["ADDON_" .. tostring(reason)] or tostring(reason))
        return false
    end
    return self.OptionsWindow ~= nil
end

-- page is an optional deeplink key, resolved through Addon._optionPath.
function Addon:OpenOptions(page)
    if self:LoadOptions() then self.OptionsWindow:Open(page) end
end

function Addon:ToggleOptions()
    if self:LoadOptions() then self.OptionsWindow:Toggle() end
end

-- The game's AddOns list gets an entry whose button opens the own window, so
-- nothing has to load before it is clicked.
local function registerSettingsCategory()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(TITLE)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(200, 26)
    button:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    button:SetText(ns.L["Open settings"])
    button:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        Addon:OpenOptions()
    end)
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, TITLE))
end

-- Called from OnInitialize.
function Addon:SetupConfig()
    registerSettingsCategory()
    self:RegisterChatCommand("mauimpt", "HandleSlash")
end

-- Modules only reload settings on MMT_PROFILE_CHANGED, they never toggle their
-- own AceAddon state, so a profile switch needs this to hide disabled blocks.
function Addon:ApplyModuleStates()
    for name, module in self:IterateModules() do
        if type(module.GetSettings) == "function" then
            local settings = module:GetSettings()
            local want = settings and settings.enabled
            if want == nil then want = module.enabledByDefault ~= false end
            local isOn = module:IsEnabled()
            if want and not isOn then
                self:EnableModule(name)
            elseif not want and isOn then
                self:DisableModule(name)
            end
        end
    end
end

function Addon:ToggleModule(name, enabled)
    if enabled then self:EnableModule(name) else self:DisableModule(name) end
    if self.Demo and self.Demo:IsActive() then
        local m = self:GetModule(name, true)
        if enabled and m and m.SetDemo and m:IsEnabled() then
            m:SetDemo(true) -- re-feed sample data so the block appears at once
        end
    end
    -- Dependants react to this (e.g. Objectives hides splits when Splits is off).
    self:SendMessage("MMT_MODULE_TOGGLED", name, enabled)
    -- The row cache keys on blockRows alone, so it misses the enabled change.
    self.MainWindow:InvalidateRows()
    self.MainWindow:Layout()
end

-- The windows behind these deeplinks come with the settings addon.
local PANELS = {
    splits = function() return Addon:GetModule("Splits", true), "Manager" end,
    checkpoints = function() return Addon:GetModule("Checkpoints", true), "Editor" end,
}

-- /mauimpt [subcommand] -> open the GUI, optionally jumping to a sub page.
function Addon:HandleSlash(input)
    input = (input or ""):gsub("%s+", ""):lower()

    if input == "demo" then
        Addon.Demo:Toggle()
        return
    end

    if PANELS[input] then
        if not self:LoadOptions() then return end
        local module, field = PANELS[input]()
        if module and module[field] then module[field]:Toggle() end
        return
    end
    if input == "setup" then
        local m = Addon:GetModule("Setup", true)
        if m then m:Show() end
        return
    end

    self:OpenOptions(input ~= "" and input or nil)
end
