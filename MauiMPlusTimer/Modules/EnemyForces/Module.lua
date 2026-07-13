-- Modules/EnemyForces/Module.lua
-- Tracks the aggregate Enemy Forces percentage and drives its HUD bar. Broadcasts
-- MMT_FORCES_UPDATED for other modules (Checkpoints, Splits) to consume.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Forces = Addon:NewMauiModule("EnemyForces", "enemyForces")
Forces.state = { demo = false, frozen = false, lastCurrent = 0 }

-- Demo mode sample pools. On each activation one entry is picked at random from
-- each pool, so styling the HUD shows the forces display in varied states.
local DEMO_PERCENT_CHOICES = { 5, 30, 50, 65, 95 }      -- forces %
local DEMO_TIME_CHOICES    = { 300, 720, 1200, 1680 }   -- best time: 5/12/20/28 min
local DEMO_TOTAL           = 1000                        -- synthetic total the % maps onto


-- Lifecycle ------------------------------------------------------------------

function Forces:OnEnable()
    -- Only the run-lifecycle messages are always listened to. The scenario
    -- criteria events are (un)registered with the run (RegisterRunEvents), so the
    -- module is completely idle outside an active Mythic+ key.
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_COMPLETED", "OnRunCompleted")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "LoadSettings")
    self:RegisterMessage("MMT_MODULE_TOGGLED", "OnModuleToggled")

    self.UI:Build()
    if Addon.Demo:IsActive() then
        self:SetDemo(true)
    elseif Addon.RunState:Get() then
        self:RegisterRunEvents() -- enabled mid-key: begin listening now
        self.UI:Show()
        self:Refresh()
    end
end

-- Scenario criteria events fire in any scenario (Delves included), so they are
-- registered only for the duration of an active Mythic+ run.
function Forces:RegisterRunEvents()
    self:RegisterEvent("SCENARIO_CRITERIA_UPDATE", "Refresh")
    self:RegisterEvent("SCENARIO_POI_UPDATE", "Refresh")
end

function Forces:UnregisterRunEvents()
    self:UnregisterEvent("SCENARIO_CRITERIA_UPDATE")
    self:UnregisterEvent("SCENARIO_POI_UPDATE")
end

function Forces:OnDisable()
    self:UnregisterAllEvents()
    self.UI:Hide()
end

-- Helpers --------------------------------------------------------------------

function Forces:IsRunActive()
    return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()
end

function Forces:OnRunStart()
    self:RegisterRunEvents()
    self.state.demo = false
    self.state.frozen = false
    self.state.lastCurrent = 0
    self.UI:Show()
    self:Refresh()
end

-- Freeze on completion WITHOUT re-reading: the scenario criteria are already
-- reset at this point, so we keep the last (final) values already on screen.
function Forces:OnRunCompleted()
    self.state.frozen = true
end

function Forces:OnRunEnd()
    self:UnregisterRunEvents()
    self.state.frozen = false
    if not self.state.demo then
        self.UI:Hide()
    end
end

-- Read the current forces and update the display + broadcast.
function Forces:Refresh()
    if self.state.demo or self.state.frozen then return end
    -- Only ever read/broadcast forces during an active Mythic+ run. The scenario
    -- criteria events that drive this (SCENARIO_CRITERIA_UPDATE / POI_UPDATE) also
    -- fire in other scenario content such as Delves; without this guard their
    -- criteria would be read and rebroadcast as MMT_FORCES_UPDATED, which can
    -- e.g. trigger the forces sound outside Mythic+.
    if not Addon.RunState:Get() then return end
    local current, total = self.Data.Read()

    local run = Addon.RunState:Get()
    if not current and run and run.forces then
        -- Criteria not readable (e.g. after completion): use the stored snapshot.
        current, total = run.forces.current, run.forces.total
    end
    if not current then return end

    -- Never regress: when the dungeon completes the scenario resets its criteria
    -- to 0, which we must ignore so the final 100% stays on screen. The value only ever increases during a run.
    if total and total > 0 and current < (self.state.lastCurrent or 0) then
        return
    end
    self.state.lastCurrent = current

    local percent = total > 0 and (current / total) or 0

    if run then
        -- Reuse the table instead of allocating one on every criteria update.
        run.forces = run.forces or {}
        run.forces.current, run.forces.total = current, total
    end

    -- On completion: capture the completion time once and the delta vs best.
    local best = self:GetBest()
    local completionTime, delta
    if total > 0 and current >= total then
        if run and not run.forcesTime then
            run.forcesTime = Addon.Utils.ChallengeElapsed()
        end
        completionTime = run and run.forcesTime
        if best and best.forcesTime and completionTime then
            delta = completionTime - best.forcesTime
        end
    end

    self.UI:Update(current, total, percent, completionTime, delta, best and best.forcesTime)
    Addon:SendMessage("MMT_FORCES_UPDATED", percent, current, total)
end

-- Best run for the current dungeon+level (soft dependency on Splits via
-- Addon:GetBestRun). Uses the same level fallback as the Timer/Objectives bests
-- so the forces best time shows whenever a comparable run exists, not only on
-- an exact-level match.
function Forces:GetBest()
    local run = Addon.RunState:Get()
    if not run then return nil end
    return Addon:GetBestRun(run.mapID, run.keyLevel)
end

-- React to the Splits module toggling so the best forces time shows/hides at
-- once (live runs refresh on the next criteria update; this covers demo mode).
function Forces:OnModuleToggled(_, name)
    if name ~= "Splits" then return end
    if self.state.demo then
        self:SetDemo(true)
    elseif Addon.RunState:Get() and not self.state.frozen then
        self:Refresh()
    end
end

-- Demo mode ------------------------------------------------------------------

-- Pick fresh random demo values (a forces percentage and a best-time sample)
-- from the pools above, so each demo activation shows a different state. Stored
-- on state so a later refresh reuses them instead of re-rolling.
function Forces:RollDemoValues()
    local pct = DEMO_PERCENT_CHOICES[math.random(#DEMO_PERCENT_CHOICES)]
    self.state.demoPercent = pct / 100
    self.state.demoCurrent = pct / 100 * DEMO_TOTAL
    self.state.demoTime = DEMO_TIME_CHOICES[math.random(#DEMO_TIME_CHOICES)]
end

function Forces:SetDemo(state)
    local wasDemo = self.state.demo
    self.state.demo = state
    if state then
        -- Re-roll only on a real activation (off -> on), not on the repeated
        -- SetDemo(true) that Demo:Refresh fires after every settings change.
        if not wasDemo or not self.state.demoPercent then
            self:RollDemoValues()
        end
        self.UI:Build()
        self.UI:Show()
        -- The best time belongs to the Splits module, shown only when enabled.
        local splits = Addon:GetModule("Splits", true)
        local best = (splits and splits:IsEnabled()) and self.state.demoTime or nil
        self.UI:Update(self.state.demoCurrent, DEMO_TOTAL, self.state.demoPercent, nil, nil, best)
    elseif self:IsRunActive() then
        self.UI:Show()
        self:Refresh()
    else
        self.UI:Hide()
    end
end
