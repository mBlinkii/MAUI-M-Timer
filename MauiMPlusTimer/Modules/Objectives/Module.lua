-- Modules/Objectives/Module.lua
-- Tracks the dungeon bosses and drives the objectives checklist. Broadcasts
-- MMT_OBJECTIVE_COMPLETED when a boss is newly defeated.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Objectives = Addon:NewMauiModule("Objectives", "objectives")
Objectives.state = { demo = false, frozen = false }

function Objectives:OnEnable()
    self._completed = {}
    self._bossTimes = {}
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_COMPLETED", "OnRunCompleted")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "LoadSettings")
    self:RegisterMessage("MMT_MODULE_TOGGLED", "OnModuleToggled")
    self:RegisterMessage("MMT_FORCES_UPDATED", "OnForcesUpdated")

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
function Objectives:RegisterRunEvents()
    self:RegisterEvent("SCENARIO_CRITERIA_UPDATE", "Refresh")
    self:RegisterEvent("SCENARIO_POI_UPDATE", "Refresh")
end

function Objectives:UnregisterRunEvents()
    self:UnregisterEvent("SCENARIO_CRITERIA_UPDATE")
    self:UnregisterEvent("SCENARIO_POI_UPDATE")
end

function Objectives:OnDisable()
    self:UnregisterAllEvents()
    self.UI:Hide()
end

function Objectives:IsRunActive()
    return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()
end

function Objectives:OnRunStart()
    self:RegisterRunEvents()
    self.state.demo = false
    self.state.frozen = false
    self._completed = {}
    self._bossTimes = {}
    self._doneIndex = {}
    self.UI:Show()
    self:Refresh()
end

-- Freeze without re-reading: the criteria are already reset at this point.
function Objectives:OnRunCompleted()
    self.state.frozen = true
end

function Objectives:OnRunEnd()
    self:UnregisterRunEvents()
    self.state.frozen = false
    if not self.state.demo then
        self.UI:Hide()
    end
end

function Objectives:Refresh()
    if self.state.demo or self.state.frozen then return end
    -- Without this guard a Delve's criteria would be read and broadcast as
    -- MMT_OBJECTIVE_COMPLETED outside Mythic+.
    if not Addon.RunState:Get() then return end
    local bosses = self.Data.Read()

    local run = Addon.RunState:Get()
    if (not bosses or #bosses == 0) and run and run.bosses then
        bosses = run.bosses -- stored snapshot
    end

    -- Sticky by index: the scenario reset on completion reports bosses as not
    -- done again, which must not undo them.
    self._doneIndex = self._doneIndex or {}
    for i, boss in ipairs(bosses) do
        if boss.done then self._doneIndex[i] = true end
        if self._doneIndex[i] then boss.done = true end
    end

    if run and bosses and #bosses > 0 then
        run.bosses = bosses
    end

    -- Keyed by index, not name, so two bosses sharing a name each announce.
    for i, boss in ipairs(bosses) do
        if boss.done and not self._completed[i] then
            self._completed[i] = true
            Addon:SendMessage("MMT_OBJECTIVE_COMPLETED", boss.name)
        end
    end

    -- Captured once per boss, so the displayed time stays stable.
    self._bossTimes = self._bossTimes or {}
    local bestSections = self:GetBestSections()
    for i, boss in ipairs(bosses) do
        if boss.done then
            if not self._bossTimes[i] and boss.time then
                self._bossTimes[i] = boss.time
            end
            boss.time = self._bossTimes[i] or boss.time
        end
        if boss.done and boss.time and bestSections and bestSections[i] then
            boss.delta = boss.time - bestSections[i]
        else
            boss.delta = nil
        end
        boss.best = bestSections and bestSections[i] or nil
    end

    -- Sent after the deltas are computed, so the Splits "Run vs best" shows
    -- exactly this value.
    local latestDelta
    for _, boss in ipairs(bosses) do
        if boss.done and boss.delta ~= nil then latestDelta = boss.delta end
    end
    Addon:SendMessage("MMT_RUN_DELTA", latestDelta)

    self.UI:Update(self:ForDisplay(bosses))
end

-- Split times belong to the Splits module; without it the list is names only.
function Objectives:TimesVisible()
    local splits = Addon:GetModule("Splits", true)
    return splits and splits:IsEnabled()
end

-- Keeps the optional forces row in sync, including the completion tick, which
-- EnemyForces may process after our own criteria handler already ran. Works
-- while frozen: it renders from the stored boss list, reading no criteria.
function Objectives:OnForcesUpdated()
    if self:GetSettings().showForcesRow ~= true or self.state.demo then return end
    local run = Addon.RunState:Get()
    if run and run.bosses then
        self.UI:Update(self:ForDisplay(run.bosses))
    end
end

-- Synthetic row appended last. Reads the RunState forces snapshot, which the
-- same scenario events keep current, so it needs no wiring of its own.
function Objectives:ForcesRow()
    if self:GetSettings().showForcesRow ~= true then return nil end
    local L = ns.L
    if self.state.demo then
        return {
            name = L["Enemy Forces"], done = false, progress = "65.0%",
            best = self:TimesVisible() and 720 or nil,
        }
    end
    local run = Addon.RunState:Get()
    local f = run and run.forces
    if not (f and f.total and f.total > 0) then return nil end
    local percent = (f.current or 0) / f.total
    local done = percent >= 1

    local row = {
        name = L["Enemy Forces"],
        done = done,
        progress = (not done) and string.format("%.1f%%", percent * 100) or nil,
    }
    if self:TimesVisible() then
        local best = Addon:GetBestRun(run.mapID, run.keyLevel)
        row.best = best and best.forcesTime or nil
        if done then
            row.time = run.forcesTime
            if row.time and row.best then
                row.delta = row.time - row.best
            end
        end
    end
    return row
end

-- Copies before dropping time fields or appending the forces row, because the
-- input may alias run.bosses, which must never be mutated.
function Objectives:ForDisplay(bosses)
    local out
    if self:TimesVisible() then
        out = bosses
    else
        out = {}
        for i, b in ipairs(bosses or {}) do
            out[i] = { name = b.name, done = b.done, encounterID = b.encounterID }
        end
    end

    local forcesRow = self:ForcesRow()
    if forcesRow then
        if out == bosses then
            local copy = {}
            for i, b in ipairs(bosses or {}) do copy[i] = b end
            out = copy
        end
        out[#out + 1] = forcesRow
    end
    return out
end

-- Shows/hides the split-time columns without waiting for a scenario update.
function Objectives:OnModuleToggled(_, name)
    if name ~= "Splits" then return end
    if self.state.demo then
        self:SetDemo(true)
    elseif self.state.frozen then
        local run = Addon.RunState:Get()
        self.UI:Update(self:ForDisplay(run and run.bosses or {}))
    elseif Addon.RunState:Get() then
        self:Refresh()
    end
end

-- Soft Splits dependency; the level fallback matches the Timer's total best.
function Objectives:GetBestSections()
    local run = Addon.RunState:Get()
    if not run then return nil end
    local best = Addon:GetBestRun(run.mapID, run.keyLevel)
    return best and best.sections or nil
end

function Objectives:SetDemo(state)
    self.state.demo = state
    if state then
        local L = ns.L
        self.UI:Build()
        self.UI:Show()
        self.UI:Update(self:ForDisplay({
            { name = L["Boss"] .. " 1", done = true, time = 312, delta = -8, best = 320 },
            { name = L["Boss"] .. " 2", done = true, time = 640, delta = 12, best = 628 },
            { name = L["Boss"] .. " 3", done = false, best = 940 },
        }))
    elseif self:IsRunActive() then
        self.UI:Show()
        self:Refresh()
    else
        self.UI:Hide()
    end
end
