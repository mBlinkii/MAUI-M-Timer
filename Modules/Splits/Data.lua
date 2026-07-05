-- Modules/Splits/Data.lua
-- Persistent storage + access for run times. Lives in the account-wide scope,
-- keyed by dungeon (mapID) and keystone level. The only API to db.global.splits.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Splits = Addon:GetModule("Splits")

local Data = {}
Splits.Data = Data

-- Internal: the splits store, creating the path as needed.
local function store()
    Addon.db.global.splits = Addon.db.global.splits or {}
    return Addon.db.global.splits
end

local function levelEntry(mapID, keyLevel, create)
    local s = store()
    if create then
        s[mapID] = s[mapID] or {}
        s[mapID][keyLevel] = s[mapID][keyLevel] or {}
    end
    return s[mapID] and s[mapID][keyLevel] or nil
end

-- Return the best recorded run for a dungeon+level, or nil.
function Data.GetBest(mapID, keyLevel)
    local e = levelEntry(mapID, keyLevel, false)
    return e and e.best or nil
end

-- Whether a stored run counts as "in time". Reads the recorded onTime flag;
-- legacy runs are backfilled once at load (MigrateOnTimeFlags). A run that
-- still has no flag (time limit unavailable) counts as in time.
local function isInTime(run)
    return run.onTime ~= false
end

-- Backfill the onTime flag on runs stored by versions that did not record it,
-- classifying each run against its dungeon's time limit (same rule as the
-- splits manager cards). Called once at addon load; only touches runs without
-- the flag, so repeated calls are cheap and maps whose time limit is not yet
-- available are simply retried on the next load.
function Data.MigrateOnTimeFlags()
    for mapID, levels in pairs(store()) do
        local limit = Addon.Utils.GetMapTimeLimit(mapID)
        if limit then
            for _, e in pairs(levels) do
                if e.best and e.best.onTime == nil and e.best.total then
                    e.best.onTime = e.best.total <= limit
                end
                if e.history then
                    for _, run in ipairs(e.history) do
                        if run.onTime == nil and run.total then
                            run.onTime = run.total <= limit
                        end
                    end
                end
            end
        end
    end
end

-- Comparison run for a dungeon+level. Selection priority:
--   1. same level, in-time best
--   2. same level, over-time best
--   3. nearest HIGHER level with an in-time best
--   4. nearest HIGHER level with an over-time best
--   5. nearest LOWER level with an in-time best
--   6. nearest LOWER level with an over-time best
-- At any single level the in-time best is always the fastest run, so the exact
-- level's stored best already covers priorities 1-2. Returns best, sourceLevel
-- (nil, nil if none).
function Data.GetBestWithFallback(mapID, keyLevel)
    local exact = Data.GetBest(mapID, keyLevel)
    if exact then return exact, keyLevel end

    local s = store()
    if not mapID or not keyLevel or not s[mapID] then return nil, nil end

    local higherIn, higherOver, lowerIn, lowerOver
    for level, e in pairs(s[mapID]) do
        if type(level) == "number" and e and e.best then
            if level > keyLevel then
                if isInTime(e.best) then
                    if not higherIn or level < higherIn then higherIn = level end
                else
                    if not higherOver or level < higherOver then higherOver = level end
                end
            elseif level < keyLevel then
                if isInTime(e.best) then
                    if not lowerIn or level > lowerIn then lowerIn = level end
                else
                    if not lowerOver or level > lowerOver then lowerOver = level end
                end
            end
        end
    end

    local pick = higherIn or higherOver or lowerIn or lowerOver
    if pick then return s[mapID][pick].best, pick end
    return nil, nil
end

-- Record a finished run. `run` = { total, sections = { [i]=time }, deaths, date }.
-- storeMode "best" keeps only the fastest total; "all" also appends to history.
function Data.Record(mapID, keyLevel, run, storeMode)
    if not mapID or not keyLevel or not run then return end
    local e = levelEntry(mapID, keyLevel, true)

    if not e.best or (run.total and run.total < (e.best.total or math.huge)) then
        e.best = run
    end

    if storeMode == "all" then
        e.history = e.history or {}
        table.insert(e.history, run)
    end
end

-- Trim stored history down to just the best (used when switching to "best").
function Data.TrimToBest()
    for _, levels in pairs(store()) do
        for _, e in pairs(levels) do
            e.history = nil
        end
    end
end

-- Cleanup helpers used by the Manager.
function Data.DeleteLevel(mapID, keyLevel)
    local s = store()
    if s[mapID] then
        s[mapID][keyLevel] = nil
        if not next(s[mapID]) then s[mapID] = nil end
    end
end

function Data.DeleteDungeon(mapID)
    store()[mapID] = nil
end

-- Runs to display for a dungeon+level: the full history when kept ("all" mode),
-- otherwise just the best. Returns (runs, best) where best is the reference to
-- the fastest run (for flagging it in the UI). Empty list when nothing stored.
function Data.GetRuns(mapID, keyLevel)
    local e = levelEntry(mapID, keyLevel, false)
    if not e then return {}, nil end
    if e.history and #e.history > 0 then return e.history, e.best end
    if e.best then return { e.best }, e.best end
    return {}, nil
end

-- Delete a single stored run (by table identity). Recomputes the best from the
-- remaining history; drops the level (and dungeon) once nothing is left.
function Data.DeleteRun(mapID, keyLevel, run)
    local e = levelEntry(mapID, keyLevel, false)
    if not e then return end

    if e.history then
        for i, r in ipairs(e.history) do
            if r == run then table.remove(e.history, i) break end
        end
        local best
        for _, r in ipairs(e.history) do
            if not best or (r.total and r.total < (best.total or math.huge)) then best = r end
        end
        e.best = best
        if #e.history == 0 then e.history = nil end
    elseif e.best == run then
        e.best = nil
    end

    if not e.best and not (e.history and #e.history > 0) then
        Data.DeleteLevel(mapID, keyLevel)
    end
end

function Data.ClearHistory(mapID, keyLevel)
    local e = levelEntry(mapID, keyLevel, false)
    if e then e.history = nil end
end

function Data.Wipe()
    Addon.db.global.splits = {}
end

-- Sorted list of mapIDs that have data (for the Manager tree).
function Data.GetDungeons()
    local list = {}
    for mapID in pairs(store()) do list[#list + 1] = mapID end
    table.sort(list)
    return list
end

-- Sorted list of key levels recorded for a dungeon.
function Data.GetLevels(mapID)
    local list = {}
    local s = store()
    if s[mapID] then
        for level in pairs(s[mapID]) do list[#list + 1] = level end
    end
    table.sort(list)
    return list
end
