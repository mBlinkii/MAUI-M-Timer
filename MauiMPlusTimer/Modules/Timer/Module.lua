-- Modules/Timer/Module.lua
-- Timer display. Pure consumer of the MMT_RUN_* messages -- run detection and
-- the timeout broadcast live in Core/RunController, so this can be toggled off
-- without affecting the rest of the addon.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Timer = Addon:NewMauiModule("Timer", "timer")

-- In-memory display state; the persistent record lives in RunState. `active` is
-- true while a key runs, `running` only after the pre-run countdown.
-- `lastElapsed` stops the time regressing when the scenario resets on completion.
Timer.state = { active = false, running = false,
                timeLimit = 0, demo = false, lastElapsed = 0 }

-- Soft Splits dependency via Addon:GetBestRun.
function Timer:GetBestTotal()
    local run = Addon.RunState:Get()
    if not run then return nil end
    local best = Addon:GetBestRun(run.mapID, run.keyLevel)
    return best and best.total or nil
end

function Timer:OnEnable()
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_TIMER_STARTED", "OnTimerStarted")
    self:RegisterMessage("MMT_RUN_COMPLETED", "OnRunCompleted")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "LoadSettings")
    self:RegisterMessage("MMT_MODULE_TOGGLED", "OnModuleToggled")

    self.UI:Build()
    -- Catch up: the module can be enabled mid-run or after a /reload.
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

function Timer:OnRunStart()
    self.state.demo = false
    self.state.active = true
    self.state.lastElapsed = 0
    self.state.timeLimit = Addon.Utils.GetChallengeTimeLimit()
    -- After a restore the run may already be past the countdown, so the ticker
    -- has to count immediately instead of waiting at 0.
    local run = Addon.RunState:Get()
    self.state.running = run ~= nil and run.timerStartedAt ~= nil
    self.UI:Show()
    self:StartTicker()
end

function Timer:OnTimerStarted()
    self.state.running = true
end

function Timer:OnRunEnd()
    self.state.active = false
    self.state.running = false
    self:StopTicker()
    if not self.state.demo then
        self.UI:Hide()
    end
end

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

    -- Frozen at 0 during the countdown. A world timer value appearing anyway
    -- means MMT_RUN_TIMER_STARTED was missed, so anchor and start counting.
    if not self.state.running then
        if official and official > 0 then
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

    -- Wall-clock fallback from the recorded run start.
    local elapsed = official
    if not elapsed then
        local run = Addon.RunState:Get()
        elapsed = (run and run.timerStartedAt) and (time() - run.timerStartedAt) or 0
    end

    -- A scenario reset on completion briefly reports 0; never regress.
    if self.state.lastElapsed and elapsed < self.state.lastElapsed then
        elapsed = self.state.lastElapsed
    end
    self.state.lastElapsed = elapsed

    local bonus = self.Data.GetBonusLevel(elapsed, limit)
    self.UI:Update(elapsed, limit, bonus, self:GetBestTotal())
end

-- Freezes the display on the final time; MMT_RUN_ENDED hides it later.
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

-- A live run refreshes on its next tick anyway; this covers demo mode.
function Timer:OnModuleToggled(_, name)
    if name == "Splits" and self.state.demo then
        self:SetDemo(true)
    end
end

-- Picked at random per activation, so styling sees varied bar states.
local DEMO_ELAPSED_CHOICES = { 300, 720, 1200, 1680 }
local DEMO_LIMIT = 1800

function Timer:RollDemoValues()
    self.state.demoElapsed = DEMO_ELAPSED_CHOICES[math.random(#DEMO_ELAPSED_CHOICES)]
end

function Timer:SetDemo(state)
    local wasDemo = self.state.demo
    self.state.demo = state
    if state then
        -- Only on a real off -> on, not on the repeated SetDemo(true) that
        -- Demo:Refresh fires after every settings change.
        if not wasDemo or not self.state.demoElapsed then
            self:RollDemoValues()
        end
        self:StopTicker()
        self.UI:Build()
        self.UI:Show()
        local elapsed = self.state.demoElapsed
        local splits = Addon:GetModule("Splits", true)
        local best = (splits and splits:IsEnabled()) and 1500 or nil
        self.UI:Update(elapsed, DEMO_LIMIT, self.Data.GetBonusLevel(elapsed, DEMO_LIMIT), best)
    else
        if self.state.active then
            self:StartTicker()
        else
            self.UI:Hide()
        end
    end
end
