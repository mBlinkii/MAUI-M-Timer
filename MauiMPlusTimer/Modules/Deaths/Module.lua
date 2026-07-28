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

    self.UI:Build()
    if Addon.Demo:IsActive() then
        self:SetDemo(true)
    elseif Addon.RunState:Get() then
        self:RegisterRunEvents() -- enabled mid-key
        self.UI:Show()
        self:Refresh()
    end
end

-- Only for the duration of a run: PLAYER_DEAD fires everywhere.
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

-- Best effort: Midnight no longer exposes party member identities reliably, so
-- the next count increment is attributed to the player.
function Deaths:OnPlayerDead()
    if not Addon.RunState:Get() then return end
    self.state.pendingSelf = true
end

function Deaths:OnDeathCountUpdated()
    if self.state.frozen then return end
    if not (C_ChallengeMode and C_ChallengeMode.GetDeathCount) then return end
    local count, timeLost = C_ChallengeMode.GetDeathCount()
    count = count or 0
    timeLost = timeLost or 0

    -- The scenario reports 0 again on completion; never regress.
    if count < (self.state.count or 0) then return end

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
    self.UI:Update(count, timeLost)
    Addon:SendMessage("MMT_DEATH_COUNT_CHANGED", count, timeLost)
end

function Deaths:Refresh()
    if self.state.demo or self.state.frozen then return end
    local count, timeLost = 0, 0
    if C_ChallengeMode and C_ChallengeMode.GetDeathCount then
        count, timeLost = C_ChallengeMode.GetDeathCount()
    end
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
