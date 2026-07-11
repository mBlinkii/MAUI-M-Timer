-- Modules/Objectives/Module.lua
-- Tracks the dungeon bosses and drives the objectives checklist. Broadcasts
-- MMT_OBJECTIVE_COMPLETED when a boss is newly defeated.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Objectives = Addon:NewMauiModule("Objectives", "objectives")
Objectives.state = { demo = false, frozen = false }

-- Lifecycle ------------------------------------------------------------------

function Objectives:OnEnable()
    self._completed = {}
    self._bossTimes = {}
    -- Only run-lifecycle messages are always listened to; the scenario criteria
    -- events are (un)registered with the run (RegisterRunEvents) so the module is
    -- idle outside an active Mythic+ key.
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
        self:RegisterRunEvents() -- enabled mid-key: begin listening now
        self.UI:Show()
        self:Refresh()
    end
end

-- Scenario criteria events fire in any scenario (Delves included), so they are
-- registered only for the duration of an active Mythic+ run.
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

-- Helpers --------------------------------------------------------------------

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

-- Freeze on completion WITHOUT re-reading (criteria are already reset); the
-- last good boss list/times stay on screen.
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
    -- Only process during an active Mythic+ run. The scenario criteria events that
    -- drive this (SCENARIO_CRITERIA_UPDATE / POI_UPDATE) also fire in other
    -- scenario content such as Delves; without this guard their criteria would be
    -- read and broadcast (MMT_OBJECTIVE_COMPLETED) outside Mythic+.
    if not Addon.RunState:Get() then return end
    local bosses = self.Data.Read()

    local run = Addon.RunState:Get()
    if (not bosses or #bosses == 0) and run and run.bosses then
        -- Criteria not readable (e.g. after completion): use the stored snapshot.
        bosses = run.bosses
    end

    -- Sticky completion by index: once a boss is defeated it stays defeated,
    -- even if the scenario reset (on completion) reports it as not done again.
    self._doneIndex = self._doneIndex or {}
    for i, boss in ipairs(bosses) do
        if boss.done then self._doneIndex[i] = true end
        if self._doneIndex[i] then boss.done = true end
    end

    if run and bosses and #bosses > 0 then
        run.bosses = bosses
    end

    -- Announce newly completed bosses exactly once. Keyed by boss INDEX (not
    -- name), so two bosses sharing a name still each announce once.
    for i, boss in ipairs(bosses) do
        if boss.done and not self._completed[i] then
            self._completed[i] = true
            Addon:SendMessage("MMT_OBJECTIVE_COMPLETED", boss.name)
        end
    end

    -- Capture each boss's completion time once (stable), instead of recomputing
    -- it every refresh, then derive the +/- delta versus the best run.
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
        -- Stored best section time (shown behind the boss when the option is on).
        boss.best = bestSections and bestSections[i] or nil
    end

    -- Broadcast the latest completed boss's cumulative difference vs the best run
    -- (negative = ahead) AFTER it has been computed, so the Splits "Run vs best"
    -- can display the exact same value -- the run's total-so-far time difference.
    local latestDelta
    for _, boss in ipairs(bosses) do
        if boss.done and boss.delta ~= nil then latestDelta = boss.delta end
    end
    Addon:SendMessage("MMT_RUN_DELTA", latestDelta)

    self.UI:Update(self:ForDisplay(bosses))
end

-- Split times in the objectives list are a Splits-module feature. When that
-- module is disabled, the list shows only boss names + status.
function Objectives:TimesVisible()
    local splits = Addon:GetModule("Splits", true)
    return splits and splits:IsEnabled()
end

-- Re-render when the forces snapshot changes so the optional forces row stays
-- in sync - including the completion tick, which the forces module may
-- process after our own criteria handler already ran (works while frozen,
-- since it renders from the stored boss list without reading criteria).
function Objectives:OnForcesUpdated()
    if self:GetSettings().showForcesRow ~= true or self.state.demo then return end
    local run = Addon.RunState:Get()
    if run and run.bosses then
        self.UI:Update(self:ForDisplay(run.bosses))
    end
end

-- Optional synthetic "Enemy Forces" row, always appended LAST: shows the live
-- forces percentage while in progress and the forces completion time once
-- done. It reads the run's forces snapshot (RunState) - the same scenario
-- events that drive this module also update that snapshot, so the row stays
-- live without extra wiring. In demo mode it mirrors the demo forces value.
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
    -- Split-time fields (completion time, best, +/- delta) follow the same
    -- visibility rule as the boss rows: they belong to the Splits module.
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

-- Boss list for display: as-is when split times are visible, otherwise a shallow
-- copy with the time/delta/best fields dropped (run.bosses stays untouched).
-- The optional Enemy Forces row is appended last; the list is copied first when
-- it would otherwise alias run.bosses, which must never be mutated.
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

-- React to the Splits module being enabled/disabled so the split-time columns
-- appear/disappear live without waiting for the next scenario update.
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

-- Best run's boss section times for the current dungeon+level (or nil). Uses the
-- same level fallback as the Timer's total best (nearest higher/lower level when
-- this exact level has no record yet), so the objective best times appear
-- whenever the timer best does, instead of only on an exact-level match.
-- Soft dependency on the Splits module (Addon:GetBestRun); works without it.
function Objectives:GetBestSections()
    local run = Addon.RunState:Get()
    if not run then return nil end
    local best = Addon:GetBestRun(run.mapID, run.keyLevel)
    return best and best.sections or nil
end

-- Demo mode ------------------------------------------------------------------

function Objectives:SetDemo(state)
    self.state.demo = state
    if state then
        self.UI:Build()
        self.UI:Show()
        self.UI:Update(self:ForDisplay({
            { name = "First Boss", done = true, time = 312, delta = -8, best = 320 },
            { name = "Second Boss", done = true, time = 640, delta = 12, best = 628 },
            { name = "Final Boss", done = false, best = 940 },
        }))
    elseif self:IsRunActive() then
        self.UI:Show()
        self:Refresh()
    else
        self.UI:Hide()
    end
end
