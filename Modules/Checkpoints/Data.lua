-- Modules/Checkpoints/Data.lua
-- Per-dungeon target forces percentages, stored account-wide. Two kinds:
--   bySection: target % to reach before a given boss (sectionIndex/bossIndex)
--   ponr:      "Point of No Return" thresholds — minimum % you must have reached
--              by a stage of the pull; defined as plain forces-% gates.
-- The only API to db.global.checkpoints.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Checkpoints = Addon:GetModule("Checkpoints")

local Data = {}
Checkpoints.Data = Data

-- Optional libs for the shareable export/import string (silent fetch); without
-- them export/import is simply unavailable.
local LibSerialize = LibStub("LibSerialize", true)
local LibDeflate   = LibStub("LibDeflate", true)

local function store()
    Addon.db.global.checkpoints = Addon.db.global.checkpoints or {}
    return Addon.db.global.checkpoints
end

-- Return the entry for a dungeon (or nil).
function Data.Get(mapID)
    return store()[mapID]
end

-- Return the entry for a dungeon, creating an empty one if needed.
function Data.GetOrCreate(mapID)
    local s = store()
    s[mapID] = s[mapID] or { bySection = {}, ponr = {} }
    s[mapID].bySection = s[mapID].bySection or {}
    s[mapID].ponr = s[mapID].ponr or {}
    return s[mapID]
end

-- Target % to have reached before the boss at sectionIndex, or nil if not set.
function Data.GetSectionTarget(mapID, sectionIndex)
    local e = store()[mapID]
    if not e or not e.bySection then return nil end
    for _, s in ipairs(e.bySection) do
        if s.bossIndex == sectionIndex then return s.targetPct end
    end
    return nil
end

-- Sorted list (ascending) of Point of No Return thresholds (% values) for a
-- dungeon. Empty when none are defined.
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

-- The next not-yet-reached Point of No Return above currentPct, or nil if all
-- thresholds are already met (or none are defined).
function Data.GetNextPoNR(mapID, currentPct)
    for _, pct in ipairs(Data.GetPointsOfNoReturn(mapID)) do
        if pct > (currentPct or 0) then return pct end
    end
    return nil
end

-- Distinct target percentages (0..100) across the section and time targets,
-- sorted ascending. Used to draw checkpoint markers on the Enemy Forces bar.
function Data.GetTargetPercents(mapID)
    local e = store()[mapID]
    if not e then return {} end

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
    return out
end

-- Editor helpers -------------------------------------------------------------

function Data.AddSection(mapID, bossIndex, targetPct)
    local e = Data.GetOrCreate(mapID)
    table.insert(e.bySection, { bossIndex = bossIndex or 1, targetPct = targetPct or 0 })
end

function Data.AddPoNR(mapID, pct)
    local e = Data.GetOrCreate(mapID)
    table.insert(e.ponr, { pct = pct or 0 })
end

function Data.RemoveSection(mapID, index)
    local e = store()[mapID]
    if e and e.bySection then table.remove(e.bySection, index) end
end

function Data.RemovePoNR(mapID, index)
    local e = store()[mapID]
    if e and e.ponr then table.remove(e.ponr, index) end
end

-- Share (export / import) ----------------------------------------------------

-- Export ALL stored checkpoint data as a printable, shareable string, or nil
-- plus an error message.
function Data.Export()
    if not (LibSerialize and LibDeflate) then
        return nil, "LibSerialize/LibDeflate not available"
    end
    local payload = { version = 1, checkpoints = store() }
    local serialized = LibSerialize:Serialize(payload)
    local compressed = LibDeflate:CompressDeflate(serialized)
    return LibDeflate:EncodeForPrint(compressed)
end

-- Rebuild a dungeon entry from untrusted import data, keeping only well-formed
-- values: bySection items need a numeric bossIndex/targetPct, ponr items a
-- numeric pct (percentages clamped to 0..100). Returns nil when nothing in the
-- entry is usable, so garbage never reaches the stored table.
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

-- Import a checkpoint string. Per dungeon: an incoming entry overwrites the
-- existing one for that dungeon; dungeons not present in the string are kept.
-- Incoming entries are sanitized (see sanitizeEntry); invalid ones are skipped.
-- Returns true plus the number of imported dungeons, or false plus an error.
function Data.Import(str)
    if not (LibSerialize and LibDeflate) then
        return false, "LibSerialize/LibDeflate not available"
    end
    if type(str) ~= "string" or str == "" then
        return false, "empty import string"
    end

    local decoded = LibDeflate:DecodeForPrint(str)
    if not decoded then return false, "invalid string" end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return false, "decompression failed" end

    local ok, data = LibSerialize:Deserialize(decompressed)
    if not ok or type(data) ~= "table" then
        return false, "deserialization failed"
    end

    -- Accept both the wrapped payload and a raw checkpoints table.
    local incoming = (type(data.checkpoints) == "table" and data.checkpoints) or data
    if type(incoming) ~= "table" then return false, "no checkpoint data" end

    local s = store()
    local count = 0
    for mapID, entry in pairs(incoming) do
        local sanitized = sanitizeEntry(entry)
        if type(mapID) == "number" and sanitized then
            s[mapID] = sanitized
            count = count + 1
        end
    end
    if count == 0 then return false, "no valid checkpoint data" end
    return true, count
end
