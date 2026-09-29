-- Core/Profiles.lua
-- Profile import/export on top of AceDB. A profile is serialized, compressed
-- and encoded into a printable string that can be shared and re-imported.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Profiles = {}
Addon.Profiles = Profiles

-- The payload carries the profile name so an import can recreate it under that
-- name, and `meta` for the import preview; older strings have no meta.
-- Returns the string, or nil plus an error message.
function Profiles:Export()
    return Addon.Utils.EncodeShare("profile", {
        name = Addon.db:GetCurrentProfile(),
        profile = Addon.db.profile,
        meta = Addon.Utils.ShareMeta(),
    })
end

-- Readable Lua source for embedding a preset in Core/DB.lua. Developer format;
-- Import() cannot read it back.
function Profiles:ExportPlain()
    return Addon.Utils.SerializeTable(Addon.db.profile)
end

-- Applies an embedded preset table onto a freshly reset profile. Pass nil to
-- only restore the factory defaults.
function Profiles:ApplyTable(tbl)
    Addon.db:ResetProfile() -- fires OnProfileReset -> Addon:OnProfileChanged
    if type(tbl) == "table" then
        Addon.Utils.CopyIntoTyped(Addon.db.profile, tbl)
        Addon:OnProfileChanged()
    end
    return true
end

-- Validates without applying, so the UI can ask before overwriting a profile.
-- Returns { name, profile }, or nil plus an error message.
function Profiles:DecodeImport(str)
    local payload, err = Addon.Utils.DecodeShare("profile", str)
    if not payload then return nil, err end
    if type(payload.profile) ~= "table" then
        return nil, "no profile data"
    end
    if type(payload.name) ~= "string" or payload.name == "" then
        payload.name = "Imported"
    end
    if type(payload.meta) ~= "table" then payload.meta = {} end
    return payload
end

function Profiles:Exists(name)
    for _, profileName in ipairs(Addon.db:GetProfiles()) do
        if profileName == name then return true end
    end
    return false
end

-- Creates (or overwrites) the profile named in the string and switches to it;
-- the current profile is untouched unless it carries that name, which callers
-- confirm via Profiles:Exists. Returns true plus the name, or false plus an error.
function Profiles:Import(str)
    local payload, err = self:DecodeImport(str)
    if not payload then return false, err end

    -- Reset first, then merge typed: a corrupt or hand-edited string cannot
    -- break the profile, and defaults backfill whatever it omits.
    Addon.db:SetProfile(payload.name)
    Addon.db:ResetProfile()
    Addon.Utils.CopyIntoTyped(Addon.db.profile, payload.profile)
    Addon:OnProfileChanged()
    return true, payload.name
end
