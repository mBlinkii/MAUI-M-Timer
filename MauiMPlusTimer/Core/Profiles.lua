-- Core/Profiles.lua
-- Profile import/export on top of AceDB. A profile is serialized, compressed
-- and encoded into a printable string that can be shared and re-imported.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Profiles = {}
Addon.Profiles = Profiles

-- Export the current profile as a printable, shareable string. The string is
-- tagged and validated by the shared codec (Utils.EncodeShare/DecodeShare),
-- so only genuine MAUI profile strings can be re-imported. The payload also
-- carries the profile NAME, so the import can recreate the profile under it.
-- Returns the string, or nil plus an error message.
function Profiles:Export()
    return Addon.Utils.EncodeShare("profile", {
        name = Addon.db:GetCurrentProfile(),
        profile = Addon.db.profile,
    })
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

-- Decode (and fully validate) an import string WITHOUT applying it, so the UI
-- can inspect it first - e.g. to ask before overwriting an existing profile.
-- Returns { name, profile } on success, or nil plus an error message.
function Profiles:DecodeImport(str)
    local payload, err = Addon.Utils.DecodeShare("profile", str)
    if not payload then return nil, err end
    if type(payload.profile) ~= "table" then
        return nil, "no profile data"
    end
    if type(payload.name) ~= "string" or payload.name == "" then
        payload.name = "Imported"
    end
    return payload
end

-- Whether a profile with this name already exists in the database.
function Profiles:Exists(name)
    for _, profileName in ipairs(Addon.db:GetProfiles()) do
        if profileName == name then return true end
    end
    return false
end

-- Import a profile string: creates the profile named in the string (or
-- overwrites an existing one with that name) and switches to it. The CURRENT
-- profile is never touched unless it happens to carry the imported name -
-- callers ask the user first in that case (see Profiles:Exists).
-- Returns true plus the profile name, or false plus an error message.
function Profiles:Import(str)
    local payload, err = self:DecodeImport(str)
    if not payload then return false, err end

    -- Switch to the named profile (created from defaults when new), reset it
    -- to a clean base and merge the imported values. The typed merge skips
    -- values whose type conflicts with the profile structure, so a corrupt or
    -- hand-edited string cannot break the profile; defaults backfill anything
    -- the string omits.
    Addon.db:SetProfile(payload.name)
    Addon.db:ResetProfile()
    Addon.Utils.CopyIntoTyped(Addon.db.profile, payload.profile)
    Addon:OnProfileChanged()
    return true, payload.name
end
