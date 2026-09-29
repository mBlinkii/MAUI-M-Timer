-- Modules/Changelog/Module.lua
-- Version-history page that opens once per update, then only on request.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Changelog = Addon:NewMauiModule("Changelog")

-- Delay so the popup never competes with the loading screen or other
-- login-time addon windows.
local AUTO_SHOW_DELAY = 4

-- Overridden to register at the root of the tree, like About, instead of under
-- the Modules node.
function Changelog:OnInitialize()
    local enabled = self:GetSettings().enabled
    if enabled == nil then enabled = self.enabledByDefault ~= false end
    self:SetEnabledState(enabled and true or false)
    Addon:RegisterModuleOptions("changelog", self:GetOptions(), "root")
end

function Changelog:OnEnable()
    self:ScheduleTimer("TryAutoShow", AUTO_SHOW_DELAY)
end

function Changelog:OnDisable()
    self:UnregisterAllEvents()
end

-- A pending setup wizard takes precedence; it marks the version as seen itself.
function Changelog:ShouldAutoShow()
    return self:GetSettings().autoShow ~= false
        and Addon.db.global.setupPending ~= true
        and Addon.db.global.lastChangelogVersion ~= Addon.version
end

-- Never interrupts a key or combat: during a run it is not marked as seen, so
-- it reappears on the next login; in combat it waits for PLAYER_REGEN_ENABLED.
function Changelog:TryAutoShow()
    if not self:ShouldAutoShow() then return end
    if Addon.RunState:Get() then return end
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")
        return
    end
    self:Show()
end

function Changelog:OnCombatEnded()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:TryAutoShow()
end

-- Records the version account-wide, so the auto-show fires once per update.
function Changelog:Show()
    Addon.db.global.lastChangelogVersion = Addon.version
    Addon:OpenOptions("changelog")
end
