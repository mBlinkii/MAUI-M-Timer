-- Core/Utilities.lua
-- Stateless helpers and read-only wrappers around the challenge-mode API.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Utils = {}
ns.Utils = Utils
Addon.Utils = Utils

-- "m:ss", or "h:mm:ss" past one hour.
function Utils.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end

-- Byte length of the UTF-8 sequence starting with byte `b`.
local function utf8Step(b)
    return (b < 0x80 and 1) or (b < 0xE0 and 2) or (b < 0xF0 and 3) or 4
end

-- Cuts to `maxChars` characters without splitting a multi-byte sequence.
-- Returns the text and whether it was cut.
local function utf8Truncate(text, maxChars)
    local pos, chars, len = 1, 0, #text
    while pos <= len and chars < maxChars do
        pos = pos + utf8Step(text:byte(pos))
        chars = chars + 1
    end
    if pos > len then return text, false end
    return text:sub(1, pos - 1), true
end

local function utf8First(word)
    local b = word:byte(1)
    if not b then return word end
    return word:sub(1, utf8Step(b))
end

-- mode: "truncate" (maxChars + ellipsis) | "firstword" | "abbrev" (following
-- words become initials). Anything else returns the name unchanged. Display
-- only -- stored names stay complete.
function Utils.ShortenName(name, mode, maxChars)
    if type(name) ~= "string" or name == "" or not mode or mode == "off" then
        return name
    end
    if mode == "truncate" then
        local cut, wasCut = utf8Truncate(name, math.max(1, maxChars or 12))
        return wasCut and (cut .. "\226\128\166") or cut -- U+2026 ellipsis
    end
    if mode == "firstword" then
        return name:match("^%S+") or name
    end
    if mode == "abbrev" then
        local first, rest = name:match("^(%S+)%s+(.+)$")
        if not first then return name end
        local out = { first }
        for word in rest:gmatch("%S+") do
            out[#out + 1] = utf8First(word) .. "."
        end
        return table.concat(out, " ")
    end
    return name
end

-- Nil when the timer API is unavailable, so callers can tell that apart from
-- the pre-run countdown (0) and fall back to a wall-clock estimate.
function Utils.ChallengeElapsedRaw()
    if not GetWorldElapsedTime then return nil end
    local _, elapsed = GetWorldElapsedTime(1)
    return elapsed
end

-- Like ChallengeElapsedRaw, but 0 instead of nil.
function Utils.ChallengeElapsed()
    return Utils.ChallengeElapsedRaw() or 0
end

-- Seconds, or 0 if unavailable.
function Utils.GetChallengeTimeLimit()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then return 0 end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapID then return 0 end
    local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    return timeLimit or 0
end

-- "Map <id>" fallback when the API has no name.
function Utils.GetMapName(mapID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name and name ~= "" then return name end
    end
    return "Map " .. tostring(mapID)
end

function Utils.GetMapTexture(mapID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local _, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
        return texture
    end
    return nil
end

-- Base time limit in seconds, or nil.
function Utils.GetMapTimeLimit(mapID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
        if timeLimit and timeLimit > 0 then return timeLimit end
    end
    return nil
end

-- "+<level>", optionally tinted with Blizzard's keystone rarity color.
function Utils.KeystoneLevelTag(level, colored)
    local tag = "+" .. level
    if colored and C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor then
        local c = C_ChallengeMode.GetKeystoneLevelRarityColor(level)
        if c then
            local hex = (c.GenerateHexColor and c:GenerateHexColor())
                or Utils.ColorHex({ c.r or 1, c.g or 1, c.b or 1, c.a or 1 })
            return "|c" .. hex .. tag .. "|r"
        end
    end
    return tag
end

-- Exhaustion-style debuffs that block another Heroism/Bloodlust.
local LUST_DEBUFFS = {
    57724,  -- Sated (Bloodlust)
    57723,  -- Exhaustion (Heroism)
    80354,  -- Temporal Displacement (Time Warp)
    264689, -- Fatigued (Primal Rage)
    390435, -- Exhaustion (Fury of the Aspects, Evoker)
    95809,  -- Insanity (Hunter pet Ancient Hysteria)
}

-- Nil means no exhaustion debuff, i.e. lust is available again.
function Utils.GetLustDebuffRemaining()
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
    for _, id in ipairs(LUST_DEBUFFS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if aura and aura.expirationTime and aura.expirationTime > 0 then
            return aura.expirationTime - GetTime()
        end
    end
    return nil
end

function Utils.CopyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = Utils.CopyTable(v)
    end
    return dst
end

-- Trusted data only (factory preset); see CopyIntoTyped for imports.
function Utils.CopyInto(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return dst end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            Utils.CopyInto(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

-- CopyInto for untrusted imports: an existing key is only overwritten when the
-- types match, so a corrupt value can never replace a table the UI unpacks.
function Utils.CopyIntoTyped(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return dst end
    for k, v in pairs(src) do
        local cur = dst[k]
        if type(v) == "table" and type(cur) == "table" then
            Utils.CopyIntoTyped(cur, v)
        elseif cur == nil or type(cur) == type(v) then
            dst[k] = (type(v) == "table") and Utils.CopyTable(v) or v
        end
    end
    return dst
end

-- Inline texture escape for FontStrings; 0/0 makes the icon scale with the
-- line's font height. Expects 64x64 textures.
function Utils.IconTag(path, color)
    local function byte(x)
        return math.floor(math.min(math.max(x or 1, 0), 1) * 255 + 0.5)
    end
    local r = byte(color and color[1])
    local g = byte(color and color[2])
    local b = byte(color and color[3])
    return string.format("|T%s:0:0:0:0:64:64:0:64:0:64:%d:%d:%d|t", path, r, g, b)
end

-- Export strings carry a readable prefix ("!MAUI:<kind>:<v>!") AND this marker
-- inside the envelope; import requires both, so foreign strings built on the
-- same libraries, wrong kinds and corrupted data are all rejected.
local SHARE_MARKER  = "MauiMPlusTimer"
local SHARE_VERSION = 1

-- Silent fetch; without them share strings are unavailable.
local function shareLibs()
    return LibStub("LibSerialize", true), LibStub("LibDeflate", true)
end

-- kind: payload tag, e.g. "profile" or "checkpoints". Returns the string, or
-- nil plus an error message.
function Utils.EncodeShare(kind, payload)
    local LibSerialize, LibDeflate = shareLibs()
    if not (LibSerialize and LibDeflate) then
        return nil, "LibSerialize/LibDeflate not available"
    end
    local envelope = {
        addon   = SHARE_MARKER,
        kind    = kind,
        version = SHARE_VERSION,
        payload = payload,
    }
    local compressed = LibDeflate:CompressDeflate(LibSerialize:Serialize(envelope))
    return string.format("!MAUI:%s:%d!%s", kind, SHARE_VERSION,
        LibDeflate:EncodeForPrint(compressed))
end

-- Returns the payload table, or nil plus an error message.
function Utils.DecodeShare(kind, str)
    local LibSerialize, LibDeflate = shareLibs()
    if not (LibSerialize and LibDeflate) then
        return nil, "LibSerialize/LibDeflate not available"
    end
    if type(str) ~= "string" or str == "" then
        return nil, "empty import string"
    end

    -- Neither the prefix nor the printable encoding contains whitespace, so
    -- anything picked up while copying can be dropped.
    str = str:gsub("%s+", "")

    local strKind, strVersion, body = str:match("^!MAUI:(%w+):(%d+)!(.+)$")
    if not strKind then
        return nil, "not a MAUI export string"
    end
    if strKind ~= kind then
        return nil, string.format("wrong export type (expected %s, got %s)", kind, strKind)
    end
    if tonumber(strVersion) ~= SHARE_VERSION then
        return nil, "unsupported export version"
    end

    local decoded = LibDeflate:DecodeForPrint(body)
    if not decoded then return nil, "invalid string" end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return nil, "decompression failed" end

    local ok, envelope = LibSerialize:Deserialize(decompressed)
    if not ok or type(envelope) ~= "table" then
        return nil, "deserialization failed"
    end

    -- The prefix alone could be pasted onto foreign data, so the envelope has
    -- to prove independently that it is ours and of this kind.
    if envelope.addon ~= SHARE_MARKER or envelope.kind ~= kind
        or type(envelope.payload) ~= "table" then
        return nil, "not a valid MAUI export"
    end

    return envelope.payload
end

-- Guards against cycles, which would otherwise overflow the stack.
local SERIALIZE_MAX_DEPTH = 20

-- Readable Lua table constructor for the plain-text profile export, so a
-- profile can be pasted into addon code. Skips types other than string,
-- number, boolean and table; key order is stable (numbers, then strings).
function Utils.SerializeTable(tbl, indent)
    indent = indent or 0
    if indent >= SERIALIZE_MAX_DEPTH then
        return "{} --[[ depth limit reached ]]"
    end
    local pad = string.rep("    ", indent + 1)
    local lines = { "{" }

    local numKeys, strKeys = {}, {}
    for k in pairs(tbl) do
        if type(k) == "number" then
            numKeys[#numKeys + 1] = k
        elseif type(k) == "string" then
            strKeys[#strKeys + 1] = k
        end
    end
    table.sort(numKeys)
    table.sort(strKeys)

    local function keyStr(k)
        if type(k) == "number" then return "[" .. tostring(k) .. "]" end
        if k:match("^[%a_][%w_]*$") then return k end
        return string.format("[%q]", k)
    end

    local function append(k)
        local v = tbl[k]
        local t = type(v)
        if t == "table" then
            lines[#lines + 1] = pad .. keyStr(k) .. " = " .. Utils.SerializeTable(v, indent + 1) .. ","
        elseif t == "string" then
            lines[#lines + 1] = pad .. keyStr(k) .. " = " .. string.format("%q", v) .. ","
        elseif t == "number" or t == "boolean" then
            lines[#lines + 1] = pad .. keyStr(k) .. " = " .. tostring(v) .. ","
        end
    end

    for _, k in ipairs(numKeys) do append(k) end
    for _, k in ipairs(strKeys) do append(k) end

    lines[#lines + 1] = string.rep("    ", indent) .. "}"
    return table.concat(lines, "\n")
end

-- {r,g,b,a} (0..1) to a WoW "AARRGGBB" escape body. Helper and fallback are
-- file-local so nothing is allocated per call -- this runs on every tick.
local WHITE = { 1, 1, 1, 1 }
local function colorByte(v) return math.floor((v or 0) * 255 + 0.5) end
function Utils.ColorHex(c)
    c = c or WHITE
    return string.format("%02x%02x%02x%02x",
        colorByte(c[4] or 1), colorByte(c[1]), colorByte(c[2]), colorByte(c[3]))
end

-- Comparison colors live here, not in the UI layer, so the Core formatters
-- below have no upward dependency; UI/Widgets delegates to these.
local DELTA_AHEAD_FALLBACK  = { 0.20, 1.00, 0.60, 1 }
local DELTA_BEHIND_FALLBACK = { 1.00, 0.38, 0.38, 1 }
local BEST_FALLBACK         = { 0.55, 0.78, 1.00, 1 }

-- Green ahead of best, red behind; profile override wins over the theme.
function Utils.GetDeltaColor(ahead)
    local theme = (Addon.GetTheme and Addon:GetTheme()) or nil
    local e = Addon.db and Addon.db.profile.ui.elements.deltas
    if ahead then
        return (e and e.ahead) or (theme and theme.deltaAhead) or DELTA_AHEAD_FALLBACK
    end
    return (e and e.behind) or (theme and theme.deltaBehind) or DELTA_BEHIND_FALLBACK
end

-- Color of stored best-run reference times.
function Utils.GetBestColor()
    local e = Addon.db and Addon.db.profile.ui.elements.best
    local theme = (Addon.GetTheme and Addon:GetTheme()) or nil
    return (e and e.color) or (theme and theme.bestColor) or BEST_FALLBACK
end

-- Colored +/- time delta; negative counts as ahead. "" for nil.
function Utils.FormatDelta(delta)
    if not delta then return "" end
    local ahead = delta <= 0
    local hex = Utils.ColorHex(Utils.GetDeltaColor(ahead))
    local sign = ahead and "-" or "+"
    return string.format("|c%s%s%s|r", hex, sign, Utils.FormatTime(math.abs(delta)))
end

-- Colored percentage delta; positive counts as ahead (more forces than target).
function Utils.FormatPctDelta(delta)
    if not delta then return "" end
    -- Round to the displayed precision before deriving sign and color, or a
    -- value a hair below the target renders as a misleading "-0.0%".
    local rounded = math.floor(delta * 10 + 0.5) / 10
    if rounded == 0 then rounded = 0 end -- normalize a possible -0.0 to 0
    local ahead = rounded >= 0
    local hex = Utils.ColorHex(Utils.GetDeltaColor(ahead))
    local sign = ahead and "+" or "-"
    return string.format("|c%s%s%.1f%%|r", hex, sign, math.abs(rounded))
end

function Utils.Lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end
