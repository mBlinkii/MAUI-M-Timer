-- Modules/Changelog/Module.lua
-- In-game changelog: a version-history page in the options tree that opens
-- automatically ONCE after the addon has been updated to a new version.
-- The auto-show can be disabled on the page itself; the history stays
-- available anytime via the options tree or "/mauimpt changelog".

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Changelog = Addon:NewMauiModule("Changelog")

-- Seconds after login before the auto-show check runs, so the popup never
-- competes with the loading screen or other login-time addon windows.
local AUTO_SHOW_DELAY = 4

-- Informational page like About: registered at the root of the options tree
-- instead of under the Modules node (which the base OnInitialize would do).
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

-- Whether the changelog should be auto-shown: the option is on (default),
-- this addon version has not been shown yet on this account, and no
-- first-start setup is pending (the setup wizard takes precedence and marks
-- the current version as seen when it completes).
function Changelog:ShouldAutoShow()
    return self:GetSettings().autoShow ~= false
        and Addon.db.global.setupPending ~= true
        and Addon.db.global.lastChangelogVersion ~= Addon.version
end

-- Run the auto-show check. Never interrupts an active key or combat: during a
-- run the popup is skipped entirely (and NOT marked as seen, so it appears on
-- the next regular login); in combat it waits for the combat to end.
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

-- Open the options window on the changelog page and remember the current
-- version account-wide so the auto-show fires only once per update.
function Changelog:Show()
    Addon.db.global.lastChangelogVersion = Addon.version
    Addon:OpenOptions()
    Addon.AceConfigDialog:SelectGroup(ADDON_NAME, "changelog")
end
