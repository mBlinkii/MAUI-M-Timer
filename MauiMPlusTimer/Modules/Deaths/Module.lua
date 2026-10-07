-- Modules/Deaths/Module.lua
-- Death count, time penalty and the timestamped death log. The penalty is
-- already part of the Blizzard timer, so this only displays and logs.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Deaths = Addon:NewMauiModule("Deaths", "deaths")
Deaths.state = { demo = false, frozen = false, count = 0, timeLost = 0, pendingSelf = false }

function Deaths:OnEnable()
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_COMPLETED", "OnRunCompleted")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "LoadSettings")
    -- Independent of the run messages, like the count itself: the display
    -- follows the challenge mode, whatever the run bookkeeping missed. The
    -- poll backs up the count event.
    self:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED", "OnDeathCountUpdated")
    self:RegisterEvent("PLAYER_DEAD", "OnPlayerDead")
    self.poll = self.poll or self:ScheduleRepeatingTimer("OnDeathCountUpdated", 1)

    self.UI:Build()
    if Addon.Demo:IsActive() then
        self:SetDemo(true)
    elseif Addon.RunState:Get() then
        self.UI:Show()
        self:Refresh()
    end
end

function Deaths:OnDisable()
    self:UnregisterAllEvents()
    self:CancelAllTimers()
    self.poll = nil
    self.UI:Hide()
end

-- The count and penalty as plain numbers, or nil while the API hides them.
local function readDeathCount()
    if not (C_ChallengeMode and C_ChallengeMode.GetDeathCount) then return nil end
    local count, timeLost = C_ChallengeMode.GetDeathCount()
    if issecretvalue and (issecretvalue(count) or issecretvalue(timeLost)) then
        Addon:Debug("Deaths: death count is a secret value")
        return nil
    end
    return count or 0, timeLost or 0
end

function Deaths:OnRunStart()
    self.state.demo = false
    self.state.frozen = false
    self.state.count = 0
    self.state.timeLost = 0
    self.state.pendingSelf = false
    self.UI:Show()
    self:Refresh()
end

function Deaths:OnRunCompleted()
    self.state.frozen = true
end

function Deaths:OnRunEnd()
    self.state.frozen = false
    if not self.state.demo then
        self.UI:Hide()
    end
end

-- Best effort: Midnight no longer exposes party member identities reliably, so
-- the next count increment is attributed to the player.
function Deaths:OnPlayerDead()
    if not (C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()) then return end
    self.state.pendingSelf = true
end

function Deaths:OnDeathCountUpdated()
    if self.state.frozen or self.state.demo then return end
    -- After completion the scenario reports 0 again; only a running key counts.
    if not (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()) then return end
    local count, timeLost = readDeathCount()
    -- The poll calls this every second, so skip when nothing changed.
    if not count or (count == self.state.count and timeLost == self.state.timeLost) then return end
    Addon:Debug("Deaths: %s (+%ss)", tostring(count), tostring(timeLost))

    -- One log entry per new death, via RunState, the only writer of the log.
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
    -- Shown here too, in case the run start was missed.
    if not self.UI.frame:IsShown() then self.UI:Show() end
    self.UI:Update(count, timeLost)
    Addon:SendMessage("MMT_DEATH_COUNT_CHANGED", count, timeLost)
end

function Deaths:Refresh()
    if self.state.demo or self.state.frozen then return end
    local count, timeLost = readDeathCount()
    local logged = Addon.RunState:GetDeathCount()
    -- Highest of API count, logged deaths and current; never regress.
    self.state.count = math.max(count or 0, logged, self.state.count or 0)
    self.state.timeLost = (timeLost and timeLost > 0) and timeLost or (self.state.timeLost or 0)
    self.UI:Update(self.state.count, self.state.timeLost)
end

function Deaths:SetDemo(state)
    self.state.demo = state
    if state then
        self.UI:Build()
        self.UI:Show()
        self.UI:Update(3, 15) -- sample: 3 deaths, 15s lost
    elseif Addon.RunState:Get() then
        self.UI:Show()
        self:Refresh()
    else
        self.UI:Hide()
    end
end
