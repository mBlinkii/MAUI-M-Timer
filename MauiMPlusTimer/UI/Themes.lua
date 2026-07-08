-- UI/Themes.lua
-- Theme presets that supply default visual styling. Per-element overrides in
-- db.profile.ui.elements take precedence over the active theme.

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
        -- How a bar represents the timer: "elapsed" fills up as time passes,
        -- "remaining" drains. Overridable per element (per bar) later.
        barFill     = "elapsed",

        -- Timer bar fill color per achievable bonus section (configurable later).
        sectionColors = {
            [3] = { 0.10, 0.80, 0.20, 1 }, -- +3
            [2] = { 0.55, 0.80, 0.10, 1 }, -- +2
            [1] = { 0.95, 0.75, 0.10, 1 }, -- +1
            [0] = { 0.85, 0.20, 0.20, 1 }, -- depleted / over time
        },
        -- Color of the section divider lines drawn on the timer bar. Light so it
        -- stays visible over both the colored fill and the dark empty background.
        sectionDividerColor = { 1, 1, 1, 0.65 },

        -- Shared comparison colors for +/- time/percentage deltas, used by every
        -- module via Utils.FormatDelta / FormatPctDelta (green = ahead of best,
        -- red = behind). Overridable centrally on the Colors page.
        deltaAhead  = { 0.20, 1.00, 0.60, 1 },
        deltaBehind = { 1.00, 0.38, 0.38, 1 },

        -- Reference color for the stored best run's split times shown behind the
        -- live elements (Objectives bosses, Enemy Forces, Timer) when enabled.
        bestColor = { 0.55, 0.78, 1.00, 1 },
    },
}

ns.Themes = Themes

-- Per-element style keys. These strings address profile.ui.elements[key] and the
-- per-element style resolution; every module/options/colors reference goes
-- through this table so a typo is a nil-index error instead of a silent miss,
-- and all keys are visible in one place. The values MUST stay stable (they are
-- the saved keys).
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
    -- Shared comparison (+/-) color bucket and best-time reference color bucket
    deltas = "deltas",
    best   = "best",
}

-- Return the active theme table (falls back to default).
function Addon:GetTheme()
    local key = (self.db and self.db.profile.ui.theme) or "default"
    return Themes[key] or Themes.default
end
