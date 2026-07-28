-- Modules/Checkpoints/Module.lua
-- Compares the live forces percentage against the per-dungeon targets.
-- Midnight-safe: aggregate forces, boss state and elapsed time only.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Checkpoints = Addon:NewMauiModule("Checkpoints", "checkpoints")
Checkpoints.state = { demo = false, frozen = false }

function Checkpoints:OnEnable()
    self:RegisterMessage("MMT_FORCES_UPDATED", "OnForces")
    self:RegisterMessage("MMT_OBJECTIVE_COMPLETED", "Recompute")
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_COMPLETED", "OnRunCompleted")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "LoadSettings")

    self.UI:Build()
    if Addon.Demo:IsActive() then
        self:SetDemo(true)
    elseif Addon.RunState:Get() then
        self:Recompute()
    end
end

function Checkpoints:OnDisable()
    self:UnregisterAllEvents()
    self.UI:Hide()
end

function Checkpoints:OnRunStart()
    self.state.demo = false
    self.state.frozen = false
    self._reached = {}
    self:Recompute()
end

function Checkpoints:OnRunCompleted()
    self.state.frozen = true
end

function Checkpoints:OnRunEnd()
    self.state.frozen = false
    if not self.state.demo then
        self.UI:Hide()
    end
end

-- The current section is this + 1.
local function killedBosses(run)
    local n = 0
    if run and run.bosses then
        for _, boss in ipairs(run.bosses) do
            if boss.done then n = n + 1 end
        end
    end
    return n
end

function Checkpoints:OnForces(_, percent)
    if self.state.demo or self.state.frozen then return end
    self:Compute(percent and percent * 100 or nil)
end

function Checkpoints:Recompute()
    if self.state.demo or self.state.frozen then return end
    local run = Addon.RunState:Get()
    local currentPct
    if run and run.forces and run.forces.total and run.forces.total > 0 then
        currentPct = run.forces.current / run.forces.total * 100
    end
    self:Compute(currentPct)
end

function Checkpoints:Compute(currentPct)
    local run = Addon.RunState:Get()
    if not run or not run.mapID or not currentPct then
        self.UI:Update(nil, nil)
        return
    end

    local section = killedBosses(run) + 1
    local sectionTarget = self.Data.GetSectionTarget(run.mapID, section)
    local sectionDelta = sectionTarget and (currentPct - sectionTarget) or nil

    local ponr
    local nextPonr = self.Data.GetNextPoNR(run.mapID, currentPct)
    if nextPonr then
        ponr = { next = nextPonr, remaining = nextPonr - currentPct }
    end

    -- Announced once per section.
    if sectionTarget and currentPct >= sectionTarget then
        self._reached = self._reached or {}
        if not self._reached[section] then
            self._reached[section] = true
            Addon:SendMessage("MMT_CHECKPOINT_REACHED", section)
        end
    end

    self.UI:Update(sectionDelta, ponr)
end

function Checkpoints:SetDemo(state)
    self.state.demo = state
    if state then
        self.UI:Build()
        self.UI:Update(3.2, { next = 90, remaining = 12 })
    elseif Addon.RunState:Get() then
        self:Recompute()
    else
        self.UI:Hide()
    end
end
