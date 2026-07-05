-- Modules/ModuleTemplate.lua
-- Base class + factory for every MAUI module. Real modules are created with
-- Addon:NewMauiModule(name); any standard method they do not override falls
-- back to the no-op defaults below. This guarantees the module contract from
-- ARCHITECTURE.md section 5 without boilerplate in each module.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

-- Default (no-op) implementations of the standard module methods.
local ModuleBase = {}
ns.ModuleBase = ModuleBase

-- Register/unregister this module's WoW events. Override in the module.
function ModuleBase:RegisterEvents() end
function ModuleBase:UnregisterEvents() end

-- Save this module's settings to db.profile. Override as needed.
function ModuleBase:SaveSettings() end

-- Show or hide synthetic demo values. Override to feed the module's UI.
function ModuleBase:SetDemo(state) end

-- Return this module's AceConfig options group (nil = no page). Override.
function ModuleBase:GetOptions() return nil end

-- Standard initialization shared by every module: apply the saved enabled state
-- (falling back to enabledByDefault) and register the module's options page.
-- A module only overrides this if it needs extra one-time setup.
function ModuleBase:OnInitialize()
    local enabled = self:GetSettings().enabled
    if enabled == nil then enabled = self.enabledByDefault ~= false end
    self:SetEnabledState(enabled and true or false)
    if self.optionsKey and self.GetOptions then
        Addon:RegisterModuleOptions(self.optionsKey, self:GetOptions())
    end
end

-- Standard reaction to a profile change: restyle the display. Modules register
-- this themselves (RegisterMessage "MMT_PROFILE_CHANGED" -> "LoadSettings").
function ModuleBase:LoadSettings()
    if self.UI and self.UI.Restyle then self.UI:Restyle() end
end

-- Create a standard MAUI module with the base methods pre-mixed.
--   name            module name (also the db.profile.modules key).
--   optionsKey      key used to register the module's options page (or nil).
--   enabledByDefault default enabled state when the profile has no value set
--                   (defaults to true; pass false for opt-in modules).
-- Mixins: AceEvent (per-module event/message bus) and AceTimer (scheduling).
function Addon:NewMauiModule(name, optionsKey, enabledByDefault)
    local module = self:NewModule(name, "AceEvent-3.0", "AceTimer-3.0")
    module.optionsKey = optionsKey
    module.enabledByDefault = enabledByDefault

    -- Backfill any standard method the module does not define itself.
    for key, fn in pairs(ModuleBase) do
        if module[key] == nil then
            module[key] = fn
        end
    end

    -- Shortcut to this module's own settings table (auto-created).
    function module:GetSettings()
        local modules = Addon.db.profile.modules
        modules[name] = modules[name] or {}
        return modules[name]
    end

    return module
end
