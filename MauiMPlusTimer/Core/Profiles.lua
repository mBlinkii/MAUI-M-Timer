-- Core/Profiles.lua
-- Profile import/export on top of AceDB. A profile is serialized, compressed
-- and encoded into a printable string that can be shared and re-imported.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Profiles = {}
Addon.Profiles = Profiles

-- Optional libs are loaded silently; import/export is unavailable without them.
local LibSerialize = LibStub("LibSerialize", true)
local LibDeflate   = LibStub("LibDeflate", true)

-- Export the current profile as a printable, shareable string.
-- Returns the string, or nil plus an error message.
function Profiles:Export()
    if not (LibSerialize and LibDeflate) then
        return nil, "LibSerialize/LibDeflate not available"
    end
    local serialized = LibSerialize:Serialize(Addon.db.profile)
    local compressed = LibDeflate:CompressDeflate(serialized)
    return LibDeflate:EncodeForPrint(compressed)
end

-- Export the current profile as readable Lua source (a table constructor),
-- e.g. for embedding a curated preset directly into addon code (Core/DB.lua).
-- Note: this format is for developers and cannot be re-imported via Import().
function Profiles:ExportPlain()
    return Addon.Utils.SerializeTable(Addon.db.profile)
end

-- Apply an embedded profile preset (a plain Lua profile table, e.g. from the
-- setup wizard). The profile is reset to the factory defaults first so the
-- preset starts from a clean base, then the preset is merged with the same
-- typed merge used by Import (type conflicts are skipped, defaults backfill
-- anything the preset omits). Pass nil to just restore the factory defaults.
function Profiles:ApplyTable(tbl)
    Addon.db:ResetProfile() -- fires OnProfileReset -> Addon:OnProfileChanged
    if type(tbl) == "table" then
        Addon.Utils.CopyIntoTyped(Addon.db.profile, tbl)
        Addon:OnProfileChanged()
    end
    return true
end

-- Import a profile string onto the current profile.
-- Returns true on success, or false plus an error message.
function Profiles:Import(str)
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

    -- Merge decoded values onto the live profile (defaults backfill anything
    -- missing; unknown keys simply have no effect on behaviour). The typed merge
    -- skips values whose type conflicts with the existing profile structure, so
    -- a corrupt/hand-edited string cannot corrupt the live profile.
    Addon.Utils.CopyIntoTyped(Addon.db.profile, data)
    Addon:SendMessage("MMT_PROFILE_CHANGED")
    return true
end
