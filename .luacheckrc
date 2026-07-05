-- .luacheckrc — luacheck configuration for MAUI M+ Timer (WoW Retail addon)
--
-- Run from the repo root:   luacheck .
-- Install luacheck:         luarocks install luacheck
--
-- The goal is a clean signal: WoW client APIs and addon-wide globals are declared
-- as read-only so luacheck only flags real problems (typos, undefined locals,
-- unused variables, shadowing). Embedded third-party libraries are not linted.

-- Lua 5.1 is the dialect the WoW client runs.
std = "lua51"

-- Line length in addon code is not a useful signal here.
max_line_length = false

-- Do not lint embedded libraries or non-Lua artifacts.
exclude_files = {
    "MauiMPlusTimer/Libs/",
}

-- Globals the addon itself defines (written by the client / TOC).
globals = {
    "MauiMPlusTimerDB",                 -- SavedVariables table
    "MauiMPlusTimer_OnCompartmentClick",-- AddonCompartmentFunc from the .toc
}

-- Suppress noise that is idiomatic in addon/Ace3 code.
ignore = {
    "212/self",  -- unused "self" argument (method stubs / lifecycle hooks)
    "212/event", -- unused "event" argument in event handlers
    "431",       -- shadowing an upvalue (common with local L = ns.L per file)
    "542",       -- empty if branch (e.g. intentional no-op OnDisable)
}

-- WoW client APIs and base globals used across the addon. Declared read-only so
-- assigning to them is still flagged. Extend this list when a new API is used.
read_globals = {
    -- Ace3 / library loader
    "LibStub",

    -- Lua/WoW string & table helpers exposed as globals
    "wipe", "tinsert", "tremove", "sort", "unpack", "select",
    "strsplit", "strjoin", "strtrim", "strmatch", "strfind", "strsub",
    "strlower", "strupper", "strrep", "format", "gsub", "gmatch",
    "max", "min", "abs", "floor", "ceil", "mod", "tonumber", "tostring",
    "date", "time", "bit",

    -- Timing
    "GetTime", "GetTimePreciseSec", "debugprofilestop",
    "GetWorldElapsedTime", "GetWorldElapsedTimers",

    -- Frames / UI
    "CreateFrame", "UIParent", "GameTooltip",
    "GameFontNormal", "GameFontHighlight", "GameFontNormalLarge",
    "hooksecurefunc", "issecure", "securecall", "geterrorhandler",
    "PlaySound", "PlaySoundFile", "StopSound",

    -- Settings / interface options
    "Settings", "InterfaceOptions_AddCategory",

    -- Colors / quality
    "RAID_CLASS_COLORS", "ITEM_QUALITY_COLORS", "GetItemQualityColor",
    "NORMAL_FONT_COLOR", "HIGHLIGHT_FONT_COLOR", "WHITE_FONT_COLOR",
    "RED_FONT_COLOR", "GREEN_FONT_COLOR",
    "CreateColor", "ColorMixin",

    -- C_* namespaces referenced in this addon
    "C_AddOns",
    "C_ChallengeMode",
    "C_Container",
    "C_Map",
    "C_MythicPlus",
    "C_Scenario",
    "C_ScenarioInfo",
    "C_Spell",
    "C_Timer",
    "C_UnitAuras",
}
