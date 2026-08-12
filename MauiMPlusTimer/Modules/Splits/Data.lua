-- Modules/Splits/Data.lua
-- The only API to db.global.splits: run times keyed by mapID and key level.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Splits = Addon:GetModule("Splits")

local Data = {}
Splits.Data = Data

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

function Data.GetBest(mapID, keyLevel)
    local e = levelEntry(mapID, keyLevel, false)
    return e and e.best or nil
end

-- A run with no flag at all (time limit unavailable) counts as in time.
local function isInTime(run)
    return run.onTime ~= false
end

-- Only touches runs without the flag, so repeated calls are cheap and a map
-- whose time limit is not loaded yet is simply retried next session.
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

-- Priority: exact level, then the nearest higher level, then the nearest lower
-- one, in-time before over-time. The exact level needs no in/over distinction:
-- its stored best is the fastest run there by definition. Returns best, level.
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

-- run = { total, sections = { [i] = time }, deaths, date }. storeMode "best"
-- keeps only the fastest total, "all" also appends to the history.
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

-- For the switch back to storeMode "best".
function Data.TrimToBest()
    for _, levels in pairs(store()) do
        for _, e in pairs(levels) do
            e.history = nil
        end
    end
end

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

-- Returns (runs, best); best is a reference into runs, for flagging it in the UI.
function Data.GetRuns(mapID, keyLevel)
    local e = levelEntry(mapID, keyLevel, false)
    if not e then return {}, nil end
    if e.history and #e.history > 0 then return e.history, e.best end
    if e.best then return { e.best }, e.best end
    return {}, nil
end

-- By table identity. Recomputes the best and drops the level once it is empty.
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

-- Sorted mapIDs that have data, for the Manager tree.
-- Map IDs that have stored runs, in no particular order.
function Data.GetDungeons()
    local list = {}
    for mapID in pairs(store()) do list[#list + 1] = mapID end
    return list
end

function Data.GetLevels(mapID)
    local list = {}
    local s = store()
    if s[mapID] then
        for level in pairs(s[mapID]) do list[#list + 1] = level end
    end
    table.sort(list)
    return list
end
