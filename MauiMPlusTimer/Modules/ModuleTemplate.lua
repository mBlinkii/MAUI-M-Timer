-- Modules/ModuleTemplate.lua
-- Base class and factory for every MAUI module; unoverridden standard methods
-- fall back to the no-op defaults here.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local ModuleBase = {}
ns.ModuleBase = ModuleBase

function ModuleBase:RegisterEvents() end
function ModuleBase:UnregisterEvents() end
function ModuleBase:SaveSettings() end
function ModuleBase:SetDemo(state) end
function ModuleBase:GetOptions() return nil end

-- Applies the saved enabled state and registers the options page. Modules only
-- override this when they need extra one-time setup.
function ModuleBase:OnInitialize()
    local enabled = self:GetSettings().enabled
    if enabled == nil then enabled = self.enabledByDefault ~= false end
    self:SetEnabledState(enabled and true or false)
    if self.optionsKey and self.GetOptions then
        Addon:RegisterModuleOptions(self.optionsKey, self:GetOptions())
    end
end

-- Modules map MMT_PROFILE_CHANGED to this themselves.
function ModuleBase:LoadSettings()
    if self.UI and self.UI.Restyle then self.UI:Restyle() end
end

-- name doubles as the db.profile.modules key. enabledByDefault defaults to
-- true; pass false for opt-in modules.
function Addon:NewMauiModule(name, optionsKey, enabledByDefault)
    local module = self:NewModule(name, "AceEvent-3.0", "AceTimer-3.0")
    module.optionsKey = optionsKey
    module.enabledByDefault = enabledByDefault

    for key, fn in pairs(ModuleBase) do
        if module[key] == nil then
            module[key] = fn
        end
    end

    function module:GetSettings()
        local modules = Addon.db.profile.modules
        modules[name] = modules[name] or {}
        return modules[name]
    end

    return module
end
