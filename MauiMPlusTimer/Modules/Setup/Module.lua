-- Modules/Setup/Module.lua
-- First-start wizard: profile choice and recommended checkpoints. Auto-opens
-- once on a fresh install, otherwise only via "/mauimpt setup".

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Setup = Addon:NewMauiModule("Setup")

-- Delay so the wizard never competes with the loading screen or other
-- login-time addon windows.
local AUTO_SHOW_DELAY = 4

function Setup:OnEnable()
    self:ScheduleTimer("TryAutoShow", AUTO_SHOW_DELAY)
end

function Setup:OnDisable()
    self:UnregisterAllEvents()
end

function Setup:ShouldAutoShow()
    return Addon.db.global.setupPending == true
end

-- Never interrupts a key or combat: during a run it stays armed for the next
-- login, in combat it waits for PLAYER_REGEN_ENABLED.
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

-- Also marks the changelog as seen: right after installing, nothing in it is
-- new to the user.
function Setup:MarkDone()
    Addon.db.global.setupPending = false
    Addon.db.global.setupDone = true
    Addon.db.global.lastChangelogVersion = Addon.version
end
