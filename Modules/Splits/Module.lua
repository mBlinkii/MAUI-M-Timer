-- Modules/Splits/Module.lua
-- Records finished runs and shows a live +/- delta against your best run for the
-- same dungeon and key level (compared at each boss).

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Splits = Addon:NewMauiModule("Splits", "splits")
Splits.state = { demo = false }

-- Lifecycle (LoadSettings comes from ModuleBase) -------------------------------

-- Standard initialization plus a one-time data migration: backfill the in-time
-- flag on runs stored by older versions, so comparison lookups during a key
-- never have to derive it (see Data.MigrateOnTimeFlags).
function Splits:OnInitialize()
    ns.ModuleBase.OnInitialize(self)
    self.Data.MigrateOnTimeFlags()
end

function Splits:OnEnable()
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")
    self:RegisterMessage("MMT_RUN_DELTA", "OnDelta")
    self:RegisterMessage("MMT_RUN_COMPLETED", "OnRunCompleted")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "LoadSettings")

    self.UI:Build()
    if Addon.Demo:IsActive() then
        self:SetDemo(true)
    elseif Addon.RunState:Get() then
        self:UpdateDelta()
    end
end

function Splits:OnDisable()
    self:UnregisterAllEvents()
    self.UI:Hide()
end

-- Best recorded run for a dungeon+level, or nil while this module is disabled.
-- Single source of best-time data for dependent displays (Timer total, Enemy
-- Forces, Objectives), so turning Splits off hides their best times and deltas.
function Splits:GetBest(mapID, keyLevel)
    if not self:IsEnabled() then return nil end
    return self.Data.GetBestWithFallback(mapID, keyLevel)
end

--- Soft-dependency accessor for other modules: the best recorded run for a
--- dungeon+level, or nil when the Splits module is unavailable or disabled.
--- Defined here (not in Core) so the Core layer stays free of module knowledge;
--- consumers (Timer, EnemyForces, Objectives) call this instead of duplicating
--- the GetModule lookup.
function Addon:GetBestRun(mapID, keyLevel)
    local splits = self:GetModule("Splits", true)
    if not (splits and splits.GetBest) then return nil end
    return splits:GetBest(mapID, keyLevel)
end

-- Show/hide ------------------------------------------------------------------

function Splits:OnRunStart()
    self.state.demo = false
    self.UI:Update(nil) -- hidden until a best-time comparison exists
end

function Splits:OnRunEnd()
    if not self.state.demo then
        self.UI:Hide()
    end
end

-- Live comparison ------------------------------------------------------------

-- The Objectives module is the single source of the run-vs-best difference: it
-- computes each boss's cumulative time difference vs the best run and broadcasts
-- the latest completed boss's value via MMT_RUN_DELTA. That value is the run's
-- total-so-far time difference (negative = ahead), and at the final boss it is
-- the overall total-time difference. We just display it.
function Splits:OnDelta(_, delta)
    if self.state.demo then return end
    self.UI:Update(delta) -- nil hides until a comparison exists
end

-- Re-read the current standing on demand (e.g. after a reload mid-run, before
-- the next objective update broadcasts). Uses the same per-boss differences the
-- Objectives module stored on the run, so the value always matches the tracker.
function Splits:UpdateDelta()
    if self.state.demo then return end
    local run = Addon.RunState:Get()
    if not run or not run.bosses then self.UI:Update(nil); return end
    local delta
    for _, boss in ipairs(run.bosses) do
        if boss.done and boss.delta ~= nil then delta = boss.delta end
    end
    self.UI:Update(delta)
end

-- Recording ------------------------------------------------------------------

function Splits:OnRunCompleted(_, onTime)
    local run = Addon.RunState:Get()
    if not run or not run.mapID or not run.keyLevel then return end

    -- Prefer the official completion time (ms); fall back to elapsed.
    local total
    if C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo then
        local info = C_ChallengeMode.GetChallengeCompletionInfo()
        if info and info.time and info.time > 0 then total = info.time / 1000 end
    end
    if not total then
        total = Addon.Utils.ChallengeElapsedRaw()
    end

    -- In-time flag for the comparison fallback: prefer the official value from
    -- the completion event; otherwise derive it from the dungeon's time limit.
    if onTime == nil and total then
        local limit = Addon.Utils.GetChallengeTimeLimit()
        if limit > 0 then onTime = total <= limit end
    end

    local sections = {}
    if run.bosses then
        for i, boss in ipairs(run.bosses) do sections[i] = boss.time end
    end

    -- Final overall delta vs the existing best (computed before we record this
    -- run, so the comparison is against the previous best, not itself). Uses the
    -- level fallback so a first run at a new level still shows a comparison.
    local prevBest = self.Data.GetBestWithFallback(run.mapID, run.keyLevel)
    if prevBest and prevBest.total and total then
        self.UI:Update(total - prevBest.total)
    end

    self.Data.Record(run.mapID, run.keyLevel, {
        total      = total,
        sections   = sections,
        forcesTime = run.forcesTime,
        deaths     = run.deaths and #run.deaths or 0,
        onTime     = onTime,
        date       = time(),
    }, self:GetSettings().storeMode or "best")
end

-- Demo mode ------------------------------------------------------------------

function Splits:SetDemo(state)
    self.state.demo = state
    if state then
        self.UI:Update(-8) -- 8s ahead of best sample
    elseif Addon.RunState:Get() then
        self:UpdateDelta()
    else
        self.UI:Hide()
    end
end
