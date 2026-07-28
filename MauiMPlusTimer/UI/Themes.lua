-- UI/Themes.lua
-- Theme presets and ns.E, the registry of per-element style keys.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Themes = {
    default = {
        font        = STANDARD_TEXT_FONT,
        fontSize    = 14,
        fontFlags   = "OUTLINE",
        textColor   = { 1, 1, 1, 1 },
        barColor    = { 0.20, 0.60, 1.00, 1 },
        bgColor     = { 0, 0, 0, 0.60 },
        borderColor = { 0, 0, 0, 1 },
        borderSize  = 1,
        barTexture  = "Interface\\TargetingFrame\\UI-StatusBar",
        barFill     = "elapsed", -- "elapsed" fills up, "remaining" drains

        sectionColors = {
            [3] = { 0.10, 0.80, 0.20, 1 }, -- +3
            [2] = { 0.55, 0.80, 0.10, 1 }, -- +2
            [1] = { 0.95, 0.75, 0.10, 1 }, -- +1
            [0] = { 0.85, 0.20, 0.20, 1 }, -- depleted / over time
        },
        -- Light, so the dividers stay visible over both the colored fill and the
        -- dark empty background.
        sectionDividerColor = { 1, 1, 1, 0.65 },

        deltaAhead  = { 0.20, 1.00, 0.60, 1 },
        deltaBehind = { 1.00, 0.38, 0.38, 1 },
        bestColor   = { 0.55, 0.78, 1.00, 1 },
    },
}

ns.Themes = Themes

-- Keys into profile.ui.elements. Referencing them through this table turns a
-- typo into a nil-index error instead of a silent style miss. The values are
-- saved keys and must stay stable.
ns.E = {
    -- Timer
    timerText    = "timerText",
    timerBar     = "timerBar",
    timerSection = "timerSection",
    timerBest    = "timerBest",
    -- Dungeon
    dungeonName    = "dungeonName",
    dungeonAffixes = "dungeonAffixes",
    -- Enemy Forces
    forcesText    = "forcesText",
    forcesBar     = "forcesBar",
    forcesSegment = "forcesSegment",
    -- Single-line text modules
    objectiveText   = "objectiveText",
    deathsText      = "deathsText",
    splitsText      = "splitsText",
    checkpointsText = "checkpointsText",
    cooldownsText   = "cooldownsText",
    -- Shared color buckets
    deltas = "deltas",
    best   = "best",
}

function Addon:GetTheme()
    local key = (self.db and self.db.profile.ui.theme) or "default"
    return Themes[key] or Themes.default
end
