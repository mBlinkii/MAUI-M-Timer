-- Core/Utilities.lua
-- Stateless helpers: pure functions plus thin read-only wrappers around the
-- WoW challenge-mode API. Holds no state of its own; no UI, no module logic.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Utils = {}
ns.Utils = Utils
Addon.Utils = Utils

-- Format a duration in seconds as "m:ss" (or "h:mm:ss" past one hour).
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

-- Name shortening ------------------------------------------------------------

-- Byte length of the UTF-8 sequence starting with byte `b` (1 for ASCII).
local function utf8Step(b)
    return (b < 0x80 and 1) or (b < 0xE0 and 2) or (b < 0xF0 and 3) or 4
end

-- UTF-8 aware truncation: cut `text` to at most `maxChars` characters without
-- splitting a multi-byte sequence (names contain umlauts and similar).
-- Returns the (possibly cut) text and whether it was actually cut.
local function utf8Truncate(text, maxChars)
    local pos, chars, len = 1, 0, #text
    while pos <= len and chars < maxChars do
        pos = pos + utf8Step(text:byte(pos))
        chars = chars + 1
    end
    if pos > len then return text, false end
    return text:sub(1, pos - 1), true
end

-- The first UTF-8 character of a word (initial for the abbreviation mode).
local function utf8First(word)
    local b = word:byte(1)
    if not b then return word end
    return word:sub(1, utf8Step(b))
end

-- Shorten a display name (e.g. objective/boss names) according to `mode`:
--   "truncate"  -> cut to `maxChars` characters, appending "…" when cut
--   "firstword" -> keep only the first word
--   "abbrev"    -> keep the first word, following words become initials ("S.")
-- Any other mode (or nil/"off") returns the name unchanged. Pure string logic;
-- callers apply this for DISPLAY only, stored names stay complete.
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

-- Current Mythic+ challenge elapsed time in seconds (world elapsed timer #1),
-- or nil when the API is unavailable. Use this raw form when the caller needs
-- to distinguish "no timer API" (nil) from "pre-run countdown" (0), e.g. to
-- fall back to a wall-clock estimate.
function Utils.ChallengeElapsedRaw()
    if not GetWorldElapsedTime then return nil end
    local _, elapsed = GetWorldElapsedTime(1)
    return elapsed
end

-- Like ChallengeElapsedRaw, but never nil (0 when unavailable). Shared by
-- modules that timestamp events (deaths, checkpoints, forces completion).
function Utils.ChallengeElapsed()
    return Utils.ChallengeElapsedRaw() or 0
end

-- The active challenge map's time limit in seconds, or 0 if unavailable.
function Utils.GetChallengeTimeLimit()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then return 0 end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapID then return 0 end
    local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    return timeLimit or 0
end

-- Challenge map info helpers (shared by the Splits manager, the checkpoint
-- editor and the Dungeon module) ----------------------------------------------

-- Readable dungeon name for a challenge map id ("Map <id>" fallback).
function Utils.GetMapName(mapID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name and name ~= "" then return name end
    end
    return "Map " .. tostring(mapID)
end

-- The dungeon's icon texture (from the challenge-mode map info), or nil.
function Utils.GetMapTexture(mapID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local _, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
        return texture
    end
    return nil
end

-- The dungeon's base time limit (seconds), or nil if unavailable.
function Utils.GetMapTimeLimit(mapID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
        if timeLimit and timeLimit > 0 then return timeLimit end
    end
    return nil
end

-- Build a "+<level>" keystone tag, optionally tinted with Blizzard's keystone
-- level rarity color. Returns the plain tag when colored is falsy or the color
-- API is unavailable.
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

-- Heroism/Bloodlust availability ----------------------------------------------
-- Exhaustion-style debuffs that block another Heroism/Bloodlust. Single source
-- for both the Cooldowns display and the Sound module's Heroism cue.
local LUST_DEBUFFS = {
    57724,  -- Sated (Bloodlust)
    57723,  -- Exhaustion (Heroism)
    80354,  -- Temporal Displacement (Time Warp)
    264689, -- Fatigued (Primal Rage)
    390435, -- Exhaustion (Fury of the Aspects, Evoker)
    95809,  -- Insanity (Hunter pet Ancient Hysteria)
}

-- Seconds remaining on the player's lust exhaustion debuff, or nil when no such
-- debuff is present (i.e. Heroism/Bloodlust is available again).
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

-- Deep-copy a table (used for cloning defaults).
function Utils.CopyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = Utils.CopyTable(v)
    end
    return dst
end

-- Recursively copy values from `src` into `dst`, overwriting existing keys.
-- Used to merge the factory preset onto the structural defaults (trusted data).
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

-- Type-safe variant of CopyInto for UNTRUSTED data (profile import strings):
-- when a key already exists in `dst`, the incoming value is only applied if its
-- type matches, so a corrupt import (e.g. a color stored as a string) can never
-- replace a table the UI later unpacks. Unknown keys are accepted as-is (they
-- have no effect on behaviour). Valid exports match types everywhere, so this
-- behaves identically to CopyInto for well-formed strings.
function Utils.CopyIntoTyped(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return dst end
    for k, v in pairs(src) do
        local cur = dst[k]
        if type(v) == "table" and type(cur) == "table" then
            Utils.CopyIntoTyped(cur, v)
        elseif cur == nil or type(cur) == type(v) then
            dst[k] = (type(v) == "table") and Utils.CopyTable(v) or v
        end
        -- Mismatched types are skipped silently (corrupt/foreign import data).
    end
    return dst
end

-- Serialize a table into readable Lua source (a table constructor). Used by
-- the plain-text profile export so a profile can be pasted directly into addon
-- code (e.g. the factory preset in Core/DB.lua). Supports string, number,
-- boolean and nested table values; other types are skipped. Keys are emitted
-- in a stable order (numeric ascending, then strings alphabetically).
function Utils.SerializeTable(tbl, indent)
    indent = indent or 0
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

-- Convert an {r,g,b,a} color (0..1) into a WoW "AARRGGBB" hex escape body.
-- The byte helper and white fallback are module-local so no closure/table is
-- allocated per call (this runs once per colored text, every tick).
local WHITE = { 1, 1, 1, 1 }
local function colorByte(v) return math.floor((v or 0) * 255 + 0.5) end
function Utils.ColorHex(c)
    c = c or WHITE
    return string.format("%02x%02x%02x%02x",
        colorByte(c[4] or 1), colorByte(c[1]), colorByte(c[2]), colorByte(c[3]))
end

-- Shared comparison colors ----------------------------------------------------
-- Resolved here (not in the UI layer) so the Core formatters below have no
-- upward dependency; UI/Widgets delegates its GetDeltaColor/GetBestColor to
-- these. Hoisted fallbacks so no table is allocated per call.
local DELTA_AHEAD_FALLBACK  = { 0.20, 1.00, 0.60, 1 }
local DELTA_BEHIND_FALLBACK = { 1.00, 0.38, 0.38, 1 }
local BEST_FALLBACK         = { 0.55, 0.78, 1.00, 1 }

-- Shared +/- comparison color (green = ahead of best, red = behind). Central
-- override (profile.ui.elements.deltas.ahead/.behind) over the theme default.
function Utils.GetDeltaColor(ahead)
    local theme = (Addon.GetTheme and Addon:GetTheme()) or nil
    local e = Addon.db and Addon.db.profile.ui.elements.deltas
    if ahead then
        return (e and e.ahead) or (theme and theme.deltaAhead) or DELTA_AHEAD_FALLBACK
    end
    return (e and e.behind) or (theme and theme.deltaBehind) or DELTA_BEHIND_FALLBACK
end

-- Configurable color for stored best-run reference times (override on the
-- Colors page, otherwise the theme default).
function Utils.GetBestColor()
    local e = Addon.db and Addon.db.profile.ui.elements.best
    local theme = (Addon.GetTheme and Addon:GetTheme()) or nil
    return (e and e.color) or (theme and theme.bestColor) or BEST_FALLBACK
end

-- Format a +/- time delta as a colored string (ahead/negative vs behind/
-- positive). Colors come from the shared, configurable comparison pair
-- (Utils.GetDeltaColor). Returns "" for nil. Used for best-time comparisons.
function Utils.FormatDelta(delta)
    if not delta then return "" end
    local ahead = delta <= 0
    local hex = Utils.ColorHex(Utils.GetDeltaColor(ahead))
    local sign = ahead and "-" or "+"
    return string.format("|c%s%s%s|r", hex, sign, Utils.FormatTime(math.abs(delta)))
end

-- Format a percentage delta as a colored string (positive/ahead = green,
-- negative/behind = red). Uses the shared comparison colors. Used by Checkpoints
-- (more forces than target = good).
function Utils.FormatPctDelta(delta)
    if not delta then return "" end
    -- Round to the displayed precision (0.1) FIRST, then derive sign/color. A
    -- value a hair below the target (e.g. -0.04) would otherwise render as the
    -- misleading "-0.0%" (looked like an unreached checkpoint); rounding it to
    -- 0 makes it count as reached and show "+0.0%".
    local rounded = math.floor(delta * 10 + 0.5) / 10
    if rounded == 0 then rounded = 0 end -- normalize a possible -0.0 to 0
    local ahead = rounded >= 0
    local hex = Utils.ColorHex(Utils.GetDeltaColor(ahead))
    local sign = ahead and "+" or "-"
    return string.format("|c%s%s%.1f%%|r", hex, sign, math.abs(rounded))
end

-- Linearly interpolate between two numbers (used later by Checkpoints).
function Utils.Lerp(a, b, t)
    return a + (b - a) * t
end

-- Clamp a number into the [min, max] range.
function Utils.Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end
