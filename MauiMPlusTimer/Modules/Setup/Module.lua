-- Modules/Setup/Module.lua
-- First-start setup wizard: pops up once after a fresh installation and walks
-- the user through picking a starting profile and loading the recommended
-- checkpoint targets. Existing installations never see it uninvited; it can
-- be re-run anytime via "/mauimpt setup".

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Setup = Addon:NewMauiModule("Setup")

-- Seconds after login before the auto-show check runs, so the wizard never
-- competes with the loading screen or other login-time addon windows.
local AUTO_SHOW_DELAY = 4

function Setup:OnEnable()
    self:ScheduleTimer("TryAutoShow", AUTO_SHOW_DELAY)
end

function Setup:OnDisable()
    self:UnregisterAllEvents()
end

-- The wizard auto-opens only while the first-start flag is armed (set for a
-- brand-new installation in Core/DB.lua and cleared once the wizard was
-- finished, skipped or closed).
function Setup:ShouldAutoShow()
    return Addon.db.global.setupPending == true
end

-- Run the auto-show check. Never interrupts an active key or combat: during a
-- run the wizard is skipped entirely (it stays armed for the next login); in
-- combat it waits for the combat to end.
function Setup:TryAutoShow()
    if not self:ShouldAutoShow() then return end
    if Addon.RunState:Get() then return end
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")
        return
    end
    self.UI:Show()
end

function Setup:OnCombatEnded()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:TryAutoShow()
end

-- Mark the setup as handled (finished, skipped or closed): never auto-open
-- again, and suppress the changelog popup for this fresh install - right
-- after installing, nothing in the changelog is "new" to the user.
function Setup:MarkDone()
    Addon.db.global.setupPending = false
    Addon.db.global.setupDone = true
    Addon.db.global.lastChangelogVersion = Addon.version
end
