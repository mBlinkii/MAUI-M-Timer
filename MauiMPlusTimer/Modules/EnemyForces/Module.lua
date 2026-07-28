-- Modules/EnemyForces/Module.lua
-- Tracks the aggregate Enemy Forces percentage and drives its HUD bar. Broadcasts
-- MMT_FORCES_UPDATED for other modules (Checkpoints, Splits) to consume.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Forces = Addon:NewMauiModule("EnemyForces", "enemyForces")
Forces.state = { demo = false, frozen = false, lastCurrent = 0 }

-- Picked at random per activation, so styling sees varied fill states.
local DEMO_PERCENT_CHOICES = { 5, 30, 50, 65, 95 }
local DEMO_TOTAL           = 1000 -- synthetic total the % maps onto

function Forces:OnEnable()
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
        self:RegisterRunEvents() -- enabled mid-key
        self.UI:Show()
        self:Refresh()
    end
end

-- Criteria events fire in any scenario, Delves included, so they are only
-- registered for the duration of a Mythic+ run.
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

-- Freeze without re-reading: the criteria are already reset at this point, so
-- the final values on screen are the only correct ones left.
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

function Forces:Refresh()
    if self.state.demo or self.state.frozen then return end
    -- Without this guard a Delve's criteria would be read and rebroadcast as
    -- MMT_FORCES_UPDATED, e.g. firing the forces sound outside Mythic+.
    if not Addon.RunState:Get() then return end
    local current, total = self.Data.Read()

    local run = Addon.RunState:Get()
    if not current and run and run.forces then
        current, total = run.forces.current, run.forces.total -- stored snapshot
    end
    if not current then return end

    -- Completion resets the criteria to 0; the value only rises during a run,
    -- so never regress and the final 100% stays on screen.
    if total and total > 0 and current < (self.state.lastCurrent or 0) then
        return
    end
    self.state.lastCurrent = current

    local percent = total > 0 and (current / total) or 0

    if run then
        -- Reused, not reallocated on every criteria update.
        run.forces = run.forces or {}
        run.forces.current, run.forces.total = current, total
    end

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

-- Soft Splits dependency; the level fallback matches Timer and Objectives.
function Forces:GetBest()
    local run = Addon.RunState:Get()
    if not run then return nil end
    return Addon:GetBestRun(run.mapID, run.keyLevel)
end

-- A live run refreshes on its next criteria update anyway; this covers demo.
function Forces:OnModuleToggled(_, name)
    if name ~= "Splits" then return end
    if self.state.demo then
        self:SetDemo(true)
    elseif Addon.RunState:Get() and not self.state.frozen then
        self:Refresh()
    end
end

function Forces:RollDemoValues()
    local pct = DEMO_PERCENT_CHOICES[math.random(#DEMO_PERCENT_CHOICES)]
    self.state.demoPercent = pct / 100
    self.state.demoCurrent = pct / 100 * DEMO_TOTAL
end

function Forces:SetDemo(state)
    local wasDemo = self.state.demo
    self.state.demo = state
    if state then
        -- Only on a real off -> on, not on the repeated SetDemo(true) that
        -- Demo:Refresh fires after every settings change.
        if not wasDemo or not self.state.demoPercent then
            self:RollDemoValues()
        end
        self.UI:Build()
        self.UI:Show()
        local splits = Addon:GetModule("Splits", true)
        local best = (splits and splits:IsEnabled()) and 720 or nil
        self.UI:Update(self.state.demoCurrent, DEMO_TOTAL, self.state.demoPercent, nil, nil, best)
    elseif self:IsRunActive() then
        self.UI:Show()
        self:Refresh()
    else
        self.UI:Hide()
    end
end
