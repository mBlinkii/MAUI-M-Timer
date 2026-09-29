-- Modules/Checkpoints/Data.lua
-- The only API to db.global.checkpoints: per-dungeon target forces percentages,
-- either bySection (target % before a boss) or ponr (Point of No Return gates).

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Checkpoints = Addon:GetModule("Checkpoints")

local Data = {}
Checkpoints.Data = Data

local function store()
    Addon.db.global.checkpoints = Addon.db.global.checkpoints or {}
    return Addon.db.global.checkpoints
end

-- Bumped on every mutation, so consumers like the Enemy Forces split bar can
-- detect changes without re-reading the data.
local generation = 0

-- Keyed by mapID; returned by reference and read-only for callers.
local percentsCache = {}

local function invalidate()
    generation = generation + 1
    wipe(percentsCache)
end

function Data.GetGeneration()
    return generation
end

function Data.Get(mapID)
    return store()[mapID]
end

function Data.GetOrCreate(mapID)
    local s = store()
    s[mapID] = s[mapID] or { bySection = {}, ponr = {} }
    s[mapID].bySection = s[mapID].bySection or {}
    s[mapID].ponr = s[mapID].ponr or {}
    return s[mapID]
end

-- Map IDs that have a stored record, in no particular order.
function Data.GetDungeons()
    local list = {}
    for mapID in pairs(store()) do list[#list + 1] = mapID end
    return list
end

function Data.GetSectionTarget(mapID, sectionIndex)
    local e = store()[mapID]
    if not e or not e.bySection then return nil end
    for _, s in ipairs(e.bySection) do
        if s.bossIndex == sectionIndex then return s.targetPct end
    end
    return nil
end

-- Ascending; empty when none are defined.
function Data.GetPointsOfNoReturn(mapID)
    local e = store()[mapID]
    if not e or not e.ponr then return {} end
    local out = {}
    for _, p in ipairs(e.ponr) do
        if p.pct then out[#out + 1] = p.pct end
    end
    table.sort(out)
    return out
end

-- Nil once every threshold is met.
function Data.GetNextPoNR(mapID, currentPct)
    for _, pct in ipairs(Data.GetPointsOfNoReturn(mapID)) do
        if pct > (currentPct or 0) then return pct end
    end
    return nil
end

local EMPTY_PERCENTS = {} -- read-only

-- Distinct targets across both kinds, ascending. Cached and shared; callers
-- must not modify the result.
function Data.GetTargetPercents(mapID)
    local cached = percentsCache[mapID]
    if cached then return cached end

    local e = store()[mapID]
    if not e then return EMPTY_PERCENTS end

    local seen, out = {}, {}
    local function collect(list)
        if not list then return end
        for _, item in ipairs(list) do
            local p = item.targetPct or item.pct
            if p and p > 0 and p <= 100 then
                local key = math.floor(p * 10 + 0.5) -- dedupe to 0.1%
                if not seen[key] then
                    seen[key] = true
                    out[#out + 1] = p
                end
            end
        end
    end
    collect(e.bySection)
    collect(e.ponr)
    table.sort(out)
    percentsCache[mapID] = out
    return out
end

function Data.AddSection(mapID, bossIndex, targetPct)
    local e = Data.GetOrCreate(mapID)
    table.insert(e.bySection, { bossIndex = bossIndex or 1, targetPct = targetPct or 0 })
    invalidate()
end

function Data.AddPoNR(mapID, pct)
    local e = Data.GetOrCreate(mapID)
    table.insert(e.ponr, { pct = pct or 0 })
    invalidate()
end

function Data.RemoveSection(mapID, index)
    local e = store()[mapID]
    if e and e.bySection then
        table.remove(e.bySection, index)
        invalidate()
    end
end

function Data.RemovePoNR(mapID, index)
    local e = store()[mapID]
    if e and e.ponr then
        table.remove(e.ponr, index)
        invalidate()
    end
end

-- Non-numeric input is ignored, the value floored and kept >= 1.
function Data.SetSectionBossIndex(mapID, index, value)
    local e = store()[mapID]
    local row = e and e.bySection and e.bySection[index]
    local v = tonumber(value)
    if not (row and v) then return end
    row.bossIndex = math.max(1, math.floor(v))
    invalidate()
end

-- Non-numeric input is ignored, the value clamped to 0..100.
function Data.SetSectionTargetPct(mapID, index, value)
    local e = store()[mapID]
    local row = e and e.bySection and e.bySection[index]
    local v = tonumber(value)
    if not (row and v) then return end
    row.targetPct = Addon.Utils.Clamp(v, 0, 100)
    invalidate()
end

-- Non-numeric input is ignored, the value clamped to 0..100.
function Data.SetPoNRPct(mapID, index, value)
    local e = store()[mapID]
    local row = e and e.ponr and e.ponr[index]
    local v = tonumber(value)
    if not (row and v) then return end
    row.pct = Addon.Utils.Clamp(v, 0, 100)
    invalidate()
end

-- All dungeons at once; nil plus an error message on failure.
-- meta sits beside the mapID keys; older imports skip non-numeric keys, so the
-- string stays readable for them.
function Data.Export()
    local payload = { meta = Addon.Utils.ShareMeta() }
    for mapID, entry in pairs(store()) do payload[mapID] = entry end
    return Addon.Utils.EncodeShare("checkpoints", payload)
end

-- Readable Lua source for embedding a preset in addon code. Developer format;
-- Import() cannot read it back.
function Data.ExportPlain()
    return Addon.Utils.SerializeTable(store())
end

-- Rebuilds an entry from untrusted data, keeping only well-formed values.
-- Returns nil when nothing is usable, so garbage never reaches the store.
local function sanitizeEntry(entry)
    if type(entry) ~= "table" then return nil end
    local out = { bySection = {}, ponr = {} }
    if type(entry.bySection) == "table" then
        for _, item in ipairs(entry.bySection) do
            if type(item) == "table"
                and type(item.bossIndex) == "number" and type(item.targetPct) == "number" then
                out.bySection[#out.bySection + 1] = {
                    bossIndex = math.max(1, math.floor(item.bossIndex)),
                    targetPct = Addon.Utils.Clamp(item.targetPct, 0, 100),
                }
            end
        end
    end
    if type(entry.ponr) == "table" then
        for _, item in ipairs(entry.ponr) do
            if type(item) == "table" and type(item.pct) == "number" then
                out.ponr[#out.ponr + 1] = { pct = Addon.Utils.Clamp(item.pct, 0, 100) }
            end
        end
    end
    if #out.bySection == 0 and #out.ponr == 0 then return nil end
    return out
end

-- Per dungeon: an incoming entry overwrites the existing one, dungeons absent
-- from the string are kept. Returns true plus the count, or false plus an error.
-- Validates without applying, for the import preview. Returns
-- { maps = { [mapID] = entry }, count, meta }, or nil plus an error message.
function Data.Decode(str)
    local incoming, err = Addon.Utils.DecodeShare("checkpoints", str)
    if not incoming then return nil, err end

    local maps, count = {}, 0
    for mapID, entry in pairs(incoming) do
        local sanitized = type(mapID) == "number" and sanitizeEntry(entry)
        if sanitized then
            maps[mapID] = sanitized
            count = count + 1
        end
    end
    if count == 0 then return nil, "no valid checkpoint data" end
    return { maps = maps, count = count, meta = incoming.meta }
end

function Data.Import(str)
    local decoded, err = Data.Decode(str)
    if not decoded then return false, err end

    local s = store()
    for mapID, entry in pairs(decoded.maps) do s[mapID] = entry end
    invalidate()
    return true, decoded.count
end

-- Shipped defaults, keyed by mapID; edit here to update them.
local AUTHOR_PRESET = {
    [161] = {
        bySection = {
            { bossIndex = 1, targetPct = 28.05 },
            { bossIndex = 2, targetPct = 52.2 },
            { bossIndex = 3, targetPct = 60.09 },
            { bossIndex = 4, targetPct = 100 },
        },
    },
    [239] = {
        bySection = {
            { bossIndex = 1, targetPct = 20.4 },
            { bossIndex = 2, targetPct = 60.7 },
            { bossIndex = 3, targetPct = 100 },
        },
        ponr = {
            { pct = 82.2 },
        },
    },
    [249] = {
        bySection = {
            { bossIndex = 1, targetPct = 23.68 },
            { bossIndex = 2, targetPct = 70.23 },
            { bossIndex = 3, targetPct = 96.55 },
            { bossIndex = 4, targetPct = 100 },
        },
    },
    [250] = {
        bySection = {
            { bossIndex = 1, targetPct = 24.81 },
            { bossIndex = 2, targetPct = 60.4 },
            { bossIndex = 3, targetPct = 81.66 },
            { bossIndex = 4, targetPct = 100 },
        },
    },
    [399] = {
        bySection = {
            { bossIndex = 1, targetPct = 37.43 },
            { bossIndex = 2, targetPct = 77.58 },
            { bossIndex = 3, targetPct = 100 },
        },
    },
    [402] = {
        bySection = {
            { bossIndex = 1, targetPct = 21.5 },
            { bossIndex = 2, targetPct = 42.1 },
            { bossIndex = 3, targetPct = 77.1 },
            { bossIndex = 4, targetPct = 100 },
        },
    },
    [556] = {
        bySection = {
            { bossIndex = 1, targetPct = 57.3 },
            { bossIndex = 2, targetPct = 78.6 },
            { bossIndex = 3, targetPct = 100 },
        },
    },
    [557] = {
        bySection = {
            { bossIndex = 1, targetPct = 45.1 },
            { bossIndex = 2, targetPct = 70.5 },
            { bossIndex = 3, targetPct = 100 },
        },
    },
    [558] = {
        bySection = {
            { bossIndex = 1, targetPct = 28.1 },
            { bossIndex = 2, targetPct = 50.05 },
            { bossIndex = 3, targetPct = 83 },
            { bossIndex = 4, targetPct = 100 },
        },
    },
    [559] = {
        bySection = {
            { bossIndex = 1, targetPct = 28.5 },
            { bossIndex = 2, targetPct = 73.3 },
            { bossIndex = 3, targetPct = 100 },
        },
    },
    [560] = {
        bySection = {
            { bossIndex = 1, targetPct = 45.9 },
            { bossIndex = 2, targetPct = 88.8 },
            { bossIndex = 3, targetPct = 100 },
        },
    },
    [584] = {
        bySection = {
            { bossIndex = 1, targetPct = 41.07 },
            { bossIndex = 2, targetPct = 60 },
            { bossIndex = 3, targetPct = 80.15 },
            { bossIndex = 4, targetPct = 100 },
        },
    },
    [585] = {
        bySection = {
            { bossIndex = 1, targetPct = 36.72 },
            { bossIndex = 2, targetPct = 62.2 },
            { bossIndex = 3, targetPct = 100 },
        },
    },
    [586] = {
        bySection = {
            { bossIndex = 1, targetPct = 34.71 },
            { bossIndex = 2, targetPct = 74.35 },
            { bossIndex = 3, targetPct = 100 },
        },
    },
    [587] = {
        bySection = {
            { bossIndex = 1, targetPct = 34.81 },
            { bossIndex = 2, targetPct = 38.78 },
            { bossIndex = 3, targetPct = 66.26 },
            { bossIndex = 4, targetPct = 100 },
        },
    },
    [588] = {
        bySection = {
            { bossIndex = 1, targetPct = 41.74 },
            { bossIndex = 2, targetPct = 65.24 },
            { bossIndex = 3, targetPct = 100 },
        },
        ponr = {
            { pct = 90.09 },
        },
    },
}

-- Overwrites the dungeons it covers and keeps the rest, validated like a normal
-- import. Returns true plus the count.
function Data.ImportAuthorPreset()
    local s = store()
    local count = 0
    for mapID, entry in pairs(AUTHOR_PRESET) do
        local sanitized = sanitizeEntry(entry)
        if sanitized then
            s[mapID] = sanitized
            count = count + 1
        end
    end
    invalidate()
    return true, count
end
