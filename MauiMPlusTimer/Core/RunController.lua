-- Core/RunController.lua
-- Always-on Mythic+ run lifecycle detection. This is Core, NOT a toggleable
-- module: it owns the challenge-mode/instance events and drives Core/RunState
-- (Start/Stop) plus the MMT_RUN_* message bus that every display module listens
-- to. It also owns the mid-run timeout detection (MMT_RUN_TIMED_OUT), so the
-- depleted signal keeps firing even when the Timer display module is disabled.
-- Living in Core means disabling any display module (including the Timer)
-- never stops run detection for the rest of the addon.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local RunController = {}
Addon.RunController = RunController
LibStub("AceEvent-3.0"):Embed(RunController)
LibStub("AceTimer-3.0"):Embed(RunController)

-- Whether we are inside a Mythic+ dungeon instance. Stays true until the player
-- actually leaves (unlike IsChallengeModeActive, which is false right after a
-- key completes), so a finished run can still be reviewed before leaving.
local function inMythicPlusInstance()
    local _, instanceType, difficultyID = GetInstanceInfo()
    return instanceType == "party" and difficultyID == 8
end

-- A key was inserted and started: open a fresh run record (sends MMT_RUN_STARTED).
function RunController:OnChallengeStart()
    local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
        and C_ChallengeMode.GetActiveChallengeMapID()
    local level, affixes
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
    end
    Addon.RunState:Start({ mapID = mapID, keyLevel = level, affixes = affixes })
    -- Start the timeout watch with the run itself (not only on the world timer
    -- event): the check is a no-op while elapsed is 0 during the countdown, and
    -- this way a missed WORLD_STATE_TIMER_START can never lose the signal.
    self:StartTimeoutWatch()
end

-- Key finished (in or over time): broadcast completion with the authoritative
-- final time so display modules can freeze. Does NOT clear the run record — that
-- happens when the player leaves (so the summary stays reviewable).
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

-- Key abandoned/reset: clear the run record (sends MMT_RUN_ENDED).
function RunController:OnChallengeReset()
    self:StopTimeoutWatch()
    Addon.RunState:Stop()
end

-- The timed run actually began (start countdown finished). Anchor the start time
-- on the run record so elapsed time survives a /reload, then notify the Timer.
function RunController:OnTimerStart()
    local run = Addon.RunState:Get()
    if not run then return end
    if not run.timerStartedAt then
        run.timerStartedAt = time() - (Addon.Utils.ChallengeElapsed() or 0)
    end
    Addon:SendMessage("MMT_RUN_TIMER_STARTED")
end

-- World/zone transition: if a run record still exists but we have left the
-- Mythic+ instance, end the run. (Entering an in-progress key on login/reload is
-- restored by RunState:Restore from Core/Init, which sends MMT_RUN_RESTORED.)
function RunController:OnWorldChanged()
    if Addon.RunState:Get() and not inMythicPlusInstance() then
        self:StopTimeoutWatch()
        Addon.RunState:Stop()
    end
end

-- An in-progress key was restored after a /reload: resume the timeout watch.
-- If the limit was already exceeded before the reload, the immediate check in
-- StartTimeoutWatch re-fires MMT_RUN_TIMED_OUT for this session.
function RunController:OnRunRestored()
    self:StartTimeoutWatch()
end

-- Timeout detection -----------------------------------------------------------
-- Broadcasts MMT_RUN_TIMED_OUT exactly once per session the moment the elapsed
-- time first exceeds the dungeon's time limit mid-run (key depleted).

-- Elapsed seconds for the timeout check: the official challenge timer, with a
-- wall-clock fallback anchored on the run record (reload-safe).
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

-- Register the lifecycle events. Called once from Addon:OnEnable.
function RunController:Setup()
    self:RegisterEvent("CHALLENGE_MODE_START", "OnChallengeStart")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "OnChallengeCompleted")
    self:RegisterEvent("CHALLENGE_MODE_RESET", "OnChallengeReset")
    self:RegisterEvent("WORLD_STATE_TIMER_START", "OnTimerStart")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnWorldChanged")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnWorldChanged")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunRestored")
end
