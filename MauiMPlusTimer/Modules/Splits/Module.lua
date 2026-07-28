-- Modules/Splits/Module.lua
-- Records finished runs and shows a live +/- delta against your best run for the
-- same dungeon and key level (compared at each boss).

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Splits = Addon:NewMauiModule("Splits", "splits")
Splits.state = { demo = false }

-- Backfills the in-time flag on older records, so lookups during a key never
-- have to derive it.
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

-- Nil while disabled, which is what hides the dependent displays' best times.
function Splits:GetBest(mapID, keyLevel)
    if not self:IsEnabled() then return nil end
    return self.Data.GetBestWithFallback(mapID, keyLevel)
end

-- Soft-dependency accessor for Timer, EnemyForces and Objectives. Defined here
-- rather than in Core, which stays free of module knowledge.
function Addon:GetBestRun(mapID, keyLevel)
    local splits = self:GetModule("Splits", true)
    if not (splits and splits.GetBest) then return nil end
    return splits:GetBest(mapID, keyLevel)
end

function Splits:OnRunStart()
    self.state.demo = false
    self.UI:Update(nil) -- hidden until a best-time comparison exists
end

function Splits:OnRunEnd()
    if not self.state.demo then
        self.UI:Hide()
    end
end

-- Objectives owns the run-vs-best difference and broadcasts the latest
-- completed boss's cumulative value; this only displays it.
function Splits:OnDelta(_, delta)
    if self.state.demo then return end
    self.UI:Update(delta) -- nil hides until a comparison exists
end

-- For a reload mid-run, before the next broadcast. Reads the same per-boss
-- differences Objectives stored, so the value always matches the tracker.
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

function Splits:OnRunCompleted(_, onTime)
    local run = Addon.RunState:Get()
    if not run or not run.mapID or not run.keyLevel then return end

    -- Official completion time in ms, with elapsed as the fallback.
    local total
    if C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo then
        local info = C_ChallengeMode.GetChallengeCompletionInfo()
        if info and info.time and info.time > 0 then total = info.time / 1000 end
    end
    if not total then
        total = Addon.Utils.ChallengeElapsedRaw()
    end

    -- Derived only when the completion event carried no official value.
    if onTime == nil and total then
        local limit = Addon.Utils.GetChallengeTimeLimit()
        if limit > 0 then onTime = total <= limit end
    end

    local sections = {}
    if run.bosses then
        for i, boss in ipairs(run.bosses) do sections[i] = boss.time end
    end

    -- Read before recording, or the run would be compared against itself.
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

-- Only the HUD line; recording keeps running either way.
function Splits:ApplyTextShown()
    if self.state.demo then
        self.UI:Update(-8)
    elseif Addon.RunState:Get() then
        self:UpdateDelta()
    else
        self.UI:Hide()
    end
end

function Splits:SetDemo(state)
    self.state.demo = state
    if state then
        self.UI:Update(-8) -- sample: 8s ahead of best
    elseif Addon.RunState:Get() then
        self:UpdateDelta()
    else
        self.UI:Hide()
    end
end
