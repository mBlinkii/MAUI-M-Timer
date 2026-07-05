-- Modules/Deaths/Module.lua
-- Tracks the group death count and the resulting time penalty, and writes each
-- death into the run's timestamped death log. The penalty itself is already
-- included in the Blizzard timer, so this module only displays and logs.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Deaths = Addon:NewMauiModule("Deaths", "deaths")
Deaths.state = { demo = false, frozen = false, count = 0, timeLost = 0, pendingSelf = false }

-- Lifecycle (OnInitialize/LoadSettings come from ModuleBase) -------------------

function Deaths:OnEnable()
    -- Only run-lifecycle messages are always listened to; the death events are
    -- (un)registered with the run (RegisterRunEvents) so the module is idle
    -- outside an active Mythic+ key.
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_COMPLETED", "OnRunCompleted")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "LoadSettings")

    self.UI:Build()
    if Addon.Demo:IsActive() then
        self:SetDemo(true)
    elseif Addon.RunState:Get() then
        self:RegisterRunEvents() -- enabled mid-key: begin listening now
        self.UI:Show()
        self:Refresh()
    end
end

-- Death tracking events are registered only for the duration of an active
-- Mythic+ run (PLAYER_DEAD fires everywhere; the count event is M+-only).
function Deaths:RegisterRunEvents()
    self:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED", "OnDeathCountUpdated")
    self:RegisterEvent("PLAYER_DEAD", "OnPlayerDead")
end

function Deaths:UnregisterRunEvents()
    self:UnregisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    self:UnregisterEvent("PLAYER_DEAD")
end

function Deaths:OnDisable()
    self:UnregisterAllEvents()
    self.UI:Hide()
end

-- Handlers -------------------------------------------------------------------

function Deaths:OnRunStart()
    self:RegisterRunEvents()
    self.state.demo = false
    self.state.frozen = false
    self.state.count = 0
    self.state.timeLost = 0
    self.state.pendingSelf = false
    self.UI:Show()
    self:Refresh()
end

-- Freeze on completion without re-reading.
function Deaths:OnRunCompleted()
    self.state.frozen = true
end

function Deaths:OnRunEnd()
    self:UnregisterRunEvents()
    self.state.frozen = false
    if not self.state.demo then
        self.UI:Hide()
    end
end

-- Mark the next death-count increment as the player's own (best effort: party
-- member identities are not reliably available in Midnight).
function Deaths:OnPlayerDead()
    if not Addon.RunState:Get() then return end -- only track deaths within a key
    self.state.pendingSelf = true
end

function Deaths:OnDeathCountUpdated()
    if self.state.frozen then return end
    if not (C_ChallengeMode and C_ChallengeMode.GetDeathCount) then return end
    local count, timeLost = C_ChallengeMode.GetDeathCount()
    count = count or 0
    timeLost = timeLost or 0

    -- Never regress (the scenario can report 0 again on completion).
    if count < (self.state.count or 0) then return end

    -- Append one timestamped log entry per new death, through the RunState API
    -- (the only writer of the persistent death log).
    if Addon.RunState:Get() then
        while Addon.RunState:GetDeathCount() < count do
            local isSelf = self.state.pendingSelf
            self.state.pendingSelf = false
            Addon.RunState:AddDeath(
                isSelf and UnitName("player") or nil,
                Addon.Utils.ChallengeElapsed())
        end
    end

    self.state.count = count
    self.state.timeLost = timeLost
    self.UI:Update(count, timeLost)
    Addon:SendMessage("MMT_DEATH_COUNT_CHANGED", count, timeLost)
end

-- Re-read the current count/penalty and update the display.
function Deaths:Refresh()
    if self.state.demo or self.state.frozen then return end
    local count, timeLost = 0, 0
    if C_ChallengeMode and C_ChallengeMode.GetDeathCount then
        count, timeLost = C_ChallengeMode.GetDeathCount()
    end
    local logged = Addon.RunState:GetDeathCount()
    -- Never regress: keep the highest of API count, logged deaths and current.
    self.state.count = math.max(count or 0, logged, self.state.count or 0)
    self.state.timeLost = (timeLost and timeLost > 0) and timeLost or (self.state.timeLost or 0)
    self.UI:Update(self.state.count, self.state.timeLost)
end

-- Demo mode ------------------------------------------------------------------

function Deaths:SetDemo(state)
    self.state.demo = state
    if state then
        self.UI:Build()
        self.UI:Show()
        self.UI:Update(3, 15) -- 3 deaths, 15s lost sample
    elseif Addon.RunState:Get() then
        self.UI:Show()
        self:Refresh()
    else
        self.UI:Hide()
    end
end
