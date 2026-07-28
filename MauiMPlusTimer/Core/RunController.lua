-- Core/RunController.lua
-- Owns the run lifecycle: challenge-mode events, RunState and the MMT_RUN_* bus.
-- Deliberately Core and not a module, so disabling any display module (Timer
-- included) never stops run detection or the timeout signal.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local RunController = {}
Addon.RunController = RunController
LibStub("AceEvent-3.0"):Embed(RunController)
LibStub("AceTimer-3.0"):Embed(RunController)

-- Stays true until the player leaves, unlike IsChallengeModeActive, which drops
-- the moment a key completes -- a finished run stays reviewable.
local function inMythicPlusInstance()
    local _, instanceType, difficultyID = GetInstanceInfo()
    return instanceType == "party" and difficultyID == 8
end

-- Opens a fresh run record; RunState sends MMT_RUN_STARTED.
function RunController:OnChallengeStart()
    local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
        and C_ChallengeMode.GetActiveChallengeMapID()
    local level, affixes
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
    end
    Addon.RunState:Start({ mapID = mapID, keyLevel = level, affixes = affixes })
    -- Watch from the run, not only from WORLD_STATE_TIMER_START: the check is a
    -- no-op during the countdown, and a missed event cannot lose the signal.
    self:StartTimeoutWatch()
end

-- Freezes the displays but keeps the run record; only leaving clears it.
function RunController:OnChallengeCompleted()
    self:StopTimeoutWatch()
    local onTime, total
    if C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo then
        local info = C_ChallengeMode.GetChallengeCompletionInfo()
        if info then
            onTime = info.onTime
            if info.time and info.time > 0 then total = info.time / 1000 end
        end
    end
    Addon:SendMessage("MMT_RUN_COMPLETED", onTime, total)
end

-- Clears the run record; RunState sends MMT_RUN_ENDED.
function RunController:OnChallengeReset()
    self:StopTimeoutWatch()
    Addon.RunState:Stop()
end

-- Countdown finished. Anchoring the start time on the record keeps the elapsed
-- time correct across a /reload.
function RunController:OnTimerStart()
    local run = Addon.RunState:Get()
    if not run then return end
    if not run.timerStartedAt then
        run.timerStartedAt = time() - (Addon.Utils.ChallengeElapsed() or 0)
    end
    Addon:SendMessage("MMT_RUN_TIMER_STARTED")
end

-- Ends a run whose instance we have left. The reverse case (logging into a key
-- in progress) is handled by RunState:Restore.
function RunController:OnWorldChanged()
    if Addon.RunState:Get() and not inMythicPlusInstance() then
        self:StopTimeoutWatch()
        Addon.RunState:Stop()
    end
end

-- The immediate check in StartTimeoutWatch re-fires MMT_RUN_TIMED_OUT when the
-- limit was already exceeded before the reload.
function RunController:OnRunRestored()
    self:StartTimeoutWatch()
end

-- Official challenge timer, with a wall-clock fallback anchored on the run
-- record so it survives a reload.
local function timeoutElapsed()
    local elapsed = Addon.Utils.ChallengeElapsedRaw()
    if elapsed then return elapsed end
    local run = Addon.RunState:Get()
    return (run and run.timerStartedAt) and (time() - run.timerStartedAt) or 0
end

function RunController:StartTimeoutWatch()
    if not Addon.RunState:Get() then return end
    self._timedOutFired = false
    if not self._timeoutTicker then
        self._timeoutTicker = self:ScheduleRepeatingTimer("CheckTimeout", 1)
    end
    self:CheckTimeout()
end

function RunController:StopTimeoutWatch()
    if self._timeoutTicker then
        self:CancelTimer(self._timeoutTicker)
        self._timeoutTicker = nil
    end
end

function RunController:CheckTimeout()
    if self._timedOutFired then
        self:StopTimeoutWatch()
        return
    end
    local limit = Addon.Utils.GetChallengeTimeLimit()
    if limit <= 0 then return end
    if timeoutElapsed() > limit then
        self._timedOutFired = true
        self:StopTimeoutWatch()
        Addon:SendMessage("MMT_RUN_TIMED_OUT")
        Addon:Debug("RunController: time limit exceeded (key depleted)")
    end
end

-- Called once from Addon:OnEnable.
function RunController:Setup()
    self:RegisterEvent("CHALLENGE_MODE_START", "OnChallengeStart")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "OnChallengeCompleted")
    self:RegisterEvent("CHALLENGE_MODE_RESET", "OnChallengeReset")
    self:RegisterEvent("WORLD_STATE_TIMER_START", "OnTimerStart")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnWorldChanged")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnWorldChanged")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunRestored")
end
