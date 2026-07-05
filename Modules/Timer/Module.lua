-- Modules/Timer/Module.lua
-- The Mythic+ timer display. Run start/stop detection AND the mid-run timeout
-- broadcast (MMT_RUN_TIMED_OUT) live in Core/RunController; this module only
-- reacts to the MMT_RUN_* messages, so it can be enabled/disabled without
-- affecting the rest of the addon.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Timer = Addon:NewMauiModule("Timer", "timer")

-- Per-run display state held in memory; the persistent record lives in RunState.
-- `active` is true while a key is running; `running` is false during the pre-run
-- countdown and true once the timed run has actually started
-- (WORLD_STATE_TIMER_START). `lastElapsed` guards against the elapsed time
-- regressing when the scenario resets on completion.
Timer.state = { active = false, running = false,
                timeLimit = 0, demo = false, lastElapsed = 0 }

-- Stored best total time for the current dungeon+level (soft Splits dependency),
-- shown behind the timer when the "best times" option is on.
function Timer:GetBestTotal()
    local run = Addon.RunState:Get()
    if not run then return nil end
    local best = Addon:GetBestRun(run.mapID, run.keyLevel)
    return best and best.total or nil
end

-- Lifecycle (OnInitialize is provided by ModuleBase via the optionsKey) -------

function Timer:OnEnable()
    -- Run lifecycle is owned by Core/RunController; the Timer is a pure display
    -- module driven by the MMT_RUN_* messages and can be toggled freely.
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_TIMER_STARTED", "OnTimerStarted")
    self:RegisterMessage("MMT_RUN_COMPLETED", "OnRunCompleted")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "LoadSettings")
    self:RegisterMessage("MMT_MODULE_TOGGLED", "OnModuleToggled")

    self.UI:Build()
    -- Demo display (e.g. after a /reload), or the live display if a key is
    -- already running (login/reload mid-key, or enabled mid-run).
    if Addon.Demo:IsActive() then
        self:SetDemo(true)
    elseif Addon.RunState:Get() then
        self:OnRunStart()
    end
end

function Timer:OnDisable()
    self:UnregisterAllEvents()
    self:StopTicker()
    self.UI:Hide()
end

-- Run display (driven by Core/RunController via the MMT_RUN_* messages) --------

-- A key started, was restored after a /reload, or the module was enabled mid
-- run: show the live timer and start ticking. The run record itself is created
-- by Core/RunController, not here.
function Timer:OnRunStart()
    self.state.demo = false
    self.state.active = true
    self.state.lastElapsed = 0
    self.state.timeLimit = Addon.Utils.GetChallengeTimeLimit()
    -- If the timed run already began (restore / mid-run enable), reflect it so
    -- the ticker counts immediately instead of waiting at 0.
    local run = Addon.RunState:Get()
    self.state.running = run ~= nil and run.timerStartedAt ~= nil
    self.UI:Show()
    self:StartTicker()
end

-- The timed run actually began (start countdown finished).
function Timer:OnTimerStarted()
    self.state.running = true
end

-- The run ended (player left/abandoned the key): hide and clear display state.
-- The run record is cleared by Core/RunController (RunState:Stop).
function Timer:OnRunEnd()
    self.state.active = false
    self.state.running = false
    self:StopTicker()
    if not self.state.demo then
        self.UI:Hide()
    end
end

-- Ticker ---------------------------------------------------------------------

function Timer:StartTicker()
    if self.ticker then return end
    self.ticker = self:ScheduleRepeatingTimer("OnTick", 0.1)
end

function Timer:StopTicker()
    if self.ticker then
        self:CancelTimer(self.ticker)
        self.ticker = nil
    end
end

function Timer:OnTick()
    local official = Addon.Utils.ChallengeElapsedRaw()

    local limit = self.state.timeLimit
    if limit <= 0 then
        limit = Addon.Utils.GetChallengeTimeLimit()
        self.state.timeLimit = limit
    end

    -- During the start countdown the run has not begun: keep the display frozen
    -- at 0. If the world timer starts reporting a value, treat the run as begun
    -- (backup in case WORLD_STATE_TIMER_START did not fire).
    if not self.state.running then
        if official and official > 0 then
            -- Backup if MMT_RUN_TIMER_STARTED was missed: anchor and start counting.
            self.state.running = true
            local run = Addon.RunState:Get()
            if run and not run.timerStartedAt then
                run.timerStartedAt = time() - official
            end
        else
            self.UI:Update(0, limit, self.Data.GetBonusLevel(0, limit), self:GetBestTotal())
            return
        end
    end

    -- Prefer the Blizzard challenge timer; fall back to wall-clock elapsed from
    -- the recorded run start (reload-safe if the world timer API differs).
    local elapsed = official
    if not elapsed then
        local run = Addon.RunState:Get()
        elapsed = (run and run.timerStartedAt) and (time() - run.timerStartedAt) or 0
    end

    -- Never regress: a scenario reset on completion can briefly report 0, which
    -- must not overwrite the elapsed time on screen.
    if self.state.lastElapsed and elapsed < self.state.lastElapsed then
        elapsed = self.state.lastElapsed
    end
    self.state.lastElapsed = elapsed

    -- The timed-out broadcast (key depleted) is owned by Core/RunController.
    local bonus = self.Data.GetBonusLevel(elapsed, limit)
    self.UI:Update(elapsed, limit, bonus, self:GetBestTotal())
end

-- Event handlers -------------------------------------------------------------

-- Run completion (broadcast by Core/RunController with the final time): freeze
-- the display on screen so the group can review the summary; it is hidden later
-- on MMT_RUN_ENDED when the player leaves the dungeon.
function Timer:OnRunCompleted(_, _, total)
    self.state.active = false
    self.state.running = false
    self:StopTicker()

    if total then
        local limit = self.state.timeLimit
        if limit <= 0 then limit = Addon.Utils.GetChallengeTimeLimit() end
        self.state.lastElapsed = total
        self.UI:Update(total, limit, self.Data.GetBonusLevel(total, limit), self:GetBestTotal())
    end
end

-- React to the Splits module toggling so the best total shows/hides at once.
-- A live run already refreshes on its next ticker tick; this covers demo mode.
function Timer:OnModuleToggled(_, name)
    if name == "Splits" and self.state.demo then
        self:SetDemo(true)
    end
end

-- Demo mode ------------------------------------------------------------------

function Timer:SetDemo(state)
    self.state.demo = state
    if state then
        self:StopTicker()
        self.UI:Build()
        self.UI:Show()
        -- Static sample: 12:00 elapsed of a 30:00 limit -> +2 in range, +18 key.
        -- The best time is part of the Splits module, so it only shows when enabled.
        local splits = Addon:GetModule("Splits", true)
        local best = (splits and splits:IsEnabled()) and 1500 or nil -- sample best 25:00
        self.UI:Update(720, 1800, self.Data.GetBonusLevel(720, 1800), best)
    else
        if self.state.active then
            self:StartTicker()
        else
            self.UI:Hide()
        end
    end
end
