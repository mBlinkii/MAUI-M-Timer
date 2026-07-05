-- Core/DB.lua
-- AceDB setup: defaults, scopes (profile/char/global) and version migration.
-- This is the only place that touches the SavedVariables table directly.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

-- Default values are deep-merged by AceDB for any missing key, so new fields
-- in future versions appear automatically on existing installs.
local defaults = {
    profile = {
        debug = false,
        modules = {
            Timer       = {
                enabled = true,
                splitBar = false,  -- split the bar into three segments (+3/+2/+1)
                splitGap = 2,      -- pixel gap between the three split segments
                barTextGap = 0,    -- vertical pixels reserved between the bar and the time text
                sectionCountdown = false, sectionCountdownAll = false, -- threshold countdowns
            },
            Dungeon     = {
                enabled = true, showAffixes = true,
                showLevel = true, levelPos = "left", levelColor = false, levelSep = true, -- keystone level tag
                showIcon = false, iconPos = "left", iconSize = 20, -- optional map icon
                bg = {
                    show = false, color = { 0, 0, 0, 0.5 },
                    border = false, borderTexture = "Interface\\Tooltips\\UI-Tooltip-Border",
                    borderSize = 12, borderColor = { 0, 0, 0, 1 },
                },
            },
            EnemyForces = { enabled = true, showMarkers = false, position = "top" }, -- markers; bar above/below objectives
            Objectives  = {
                enabled = true, rowSpacing = 0,
                -- Boss-name shortening for display: "off" | "truncate" (with
                -- nameMaxLength characters + ellipsis) | "firstword" | "abbrev".
                nameShorten = "off", nameMaxLength = 12,
            },
            Deaths      = { enabled = true },
            Splits      = { enabled = true, storeMode = "best" }, -- "best" | "all"
            Checkpoints = { enabled = true },
            Cooldowns   = { enabled = true, brez = { on = false }, lust = { on = false } },
            Automation  = { enabled = true, hideTracker = false, autoSlotKeystone = false }, -- auto-hide Blizzard tracker / auto-slot keystone
            Sound       = {
                enabled = false,
                triggers = {
                    death     = { on = false, sound = "MAUI: Death" },
                    forces    = { on = false, sound = "MAUI: Forces" },
                    timeout   = { on = false, sound = "MAUI: Timeout" },
                    completed  = { on = false, sound = "MAUI: Success" },
                    checkpoint = { on = false, sound = "MAUI: Checkpoint" },
                    heroism    = { on = false, sound = "MAUI: Heroism" },
                },
            },
        },
        ui = {
            point   = "CENTER",
            x       = 0,
            y       = 0,
            scale   = 1,
            width   = 220,      -- HUD width in pixels (configurable)
            spacing = 2,        -- vertical gap (px) between stacked HUD blocks
            theme   = "default",
            align   = "center", -- "left" | "center" | "right"
            locked  = true,     -- locked by default; unlock to drag the HUD
            demo    = false,
            showBest = false,    -- show the stored best run's split times behind live elements
            bestPrefix = "(", bestSuffix = ")", -- bracket characters around best times (either may be empty)
            font = {},           -- global font baseline (font, fontSize, fontFlags)
            elements = {},       -- per-element style overrides, keyed by elementKey
            -- Up to two optional separator lines placed between modules. Each is
            -- a block in the HUD stack anchored just after `after` (a module block
            -- key), so enabling one shifts the following modules down.
            separators = {
                { enabled = false, after = "timer",      width = 180, height = 2, color = { 1, 1, 1, 0.5 } },
                { enabled = false, after = "objectives", width = 180, height = 2, color = { 1, 1, 1, 0.5 } },
            },
            -- Optional HUD panel: background fill, border and a title bar.
            bg = {
                show        = false,
                color       = { 0, 0, 0, 0.6 },
                border      = false,
                borderTexture = "Interface\\Tooltips\\UI-Tooltip-Border",
                borderSize  = 12,
                borderColor = { 0, 0, 0, 1 },
            },
        },
        minimap = { hide = true }, -- minimap button hidden by default (optional)
    },
    -- Per-character scope: the in-progress key, written continuously so it
    -- survives a /reload. `false` means no active run.
    char = {
        activeRun = false,
    },
    -- Account-wide scope: reference data that is independent of the profile.
    global = {
        version     = 1,
        splits      = {},
        checkpoints = {},
    },
}

-- Curated "factory" preset for a fresh install / new profile. Generated from an
-- exported profile string (see Core/Profiles.lua) and deep-merged onto the
-- structural defaults below, so the structural defaults still backfill any key
-- the preset omits. Edit here to change the out-of-the-box configuration.
local preset = {
    debug = false,
    minimap = {
        hide = false,
        minimapPos = 207,
    },
    modules = {
        Automation = {
            autoSlotKeystone = true,
            enabled = true,
            hideTracker = true,
        },
        Checkpoints = {
            align = "right",
            enabled = true,
        },
        Cooldowns = {
            align = "right",
            brez = {
                on = true,
            },
            enabled = true,
            lust = {
                on = true,
            },
        },
        Deaths = {
            align = "right",
            enabled = true,
            icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
        },
        Dungeon = {
            align = "right",
            bg = {
                border = true,
                borderColor = { 0, 0, 0, 1 },
                borderSize = 1,
                borderTexture = "Interface\\Buttons\\WHITE8X8",
                color = { 0.1373, 0.2706, 0.4784, 0.5 },
                show = true,
            },
            enabled = true,
            iconPos = "right",
            iconSize = 42,
            levelColor = true,
            levelPos = "left",
            levelSep = true,
            showAffixes = true,
            showIcon = true,
            showLevel = true,
        },
        EnemyForces = {
            align = "left",
            enabled = true,
            position = "bottom",
            showCount = false,
            showMarkers = true,
        },
        Objectives = {
            align = "right",
            doneIcon = "Interface\\RaidFrame\\ReadyCheck-Ready",
            doneIconColor = { 1, 1, 1 },
            enabled = true,
            pendingIcon = "Interface\\RaidFrame\\ReadyCheck-Waiting",
            pendingIconColor = { 1, 1, 1 },
            rowSpacing = 0,
            showDoneIcon = true,
            showPendingIcon = true,
            timeSide = "auto",
        },
        Sound = {
            enabled = true,
            triggers = {
                checkpoint = {
                    on = true,
                    sound = "MAUI: Success (Winner)",
                },
                completed = {
                    on = true,
                    sound = "MAUI: Success",
                },
                death = {
                    on = true,
                    sound = "MAUI: Death (Evil Laugh)",
                },
                forces = {
                    on = true,
                    sound = "MAUI: Combo 1",
                },
                heroism = {
                    on = true,
                    sound = "MAUI: Heroism (Upgrade)",
                },
                timeout = {
                    on = true,
                    sound = "MAUI: Timeout",
                },
            },
        },
        Splits = {
            align = "right",
            enabled = true,
            storeMode = "all",
        },
        Timer = {
            align = "center",
            barTextGap = 5,
            enabled = true,
            sectionCountdown = true,
            sectionCountdownAll = true,
            showLevel = true,
            splitBar = true,
            splitGap = 6,
        },
    },
    ui = {
        align = "center",
        bestPrefix = "",
        bestSuffix = "",
        bg = {
            border = true,
            borderColor = { 0, 0, 0, 1 },
            borderSize = 1,
            borderTexture = "Interface\\Buttons\\WHITE8X8",
            color = { 0, 0, 0, 0.2109 },
            show = false,
        },
        demo = false,
        elements = {
            checkpointsText = {
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 20,
                textColor = { 1, 1, 1, 1 },
                xOffset = 0,
                yOffset = 0,
            },
            cooldownsText = {
                cdColor = { 1, 0.38, 0.38, 1 },
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 20,
                rechargeColor = { 0.6, 0.6, 0.6, 1 },
                textColor = { 1, 1, 1, 1 },
                xOffset = 0,
                yOffset = 0,
            },
            deathsText = {
                font = "Fonts\\FRIZQT__.TTF",
                fontFlags = "OUTLINE",
                fontSize = 20,
                penaltyColor = { 1, 0.38, 0.38, 1 },
                textColor = { 1, 1, 1, 1 },
                xOffset = 0,
                yOffset = 0,
            },
            deltas = {
                ahead = { 0.2, 1, 0.6, 1 },
                behind = { 1, 0.38, 0.38, 1 },
            },
            dungeonAffixes = {
                fontFlags = "OUTLINE",
                fontSize = 14,
                textColor = { 0.6, 0.6, 0.6, 1 },
                xOffset = 0,
                yOffset = 0,
            },
            dungeonName = {
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 20,
                textColor = { 1, 1, 1, 1 },
                xOffset = 0,
                yOffset = 0,
            },
            forcesBar = {
                barColor = { 0.2, 0.6, 1, 1 },
                barTexture = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Statusbars\\bar4.tga",
                bgColor = { 0, 0, 0, 0.6 },
                borderColor = { 0, 0, 0, 1 },
                borderOffset = 1,
                borderOn = true,
                borderSize = 1,
                borderTexture = "Interface\\Buttons\\WHITE8X8",
                height = 20,
                markerColor = { 1, 1, 1, 1 },
                reverse = false,
            },
            forcesText = {
                countColor = { 0.6, 0.6, 0.6, 1 },
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 14,
                textColor = { 1, 1, 1, 1 },
                xOffset = 0,
                yOffset = 0,
            },
            hudTitle = {},
            objectiveText = {
                doneColor = { 0.2, 1, 0.6, 1 },
                fontSize = 18,
                openColor = { 1, 1, 1, 1 },
                textColor = { 1, 0.2902, 0.6667, 1 },
                timeColor = { 0.6, 0.6, 0.6, 1 },
                xOffset = 0,
                yOffset = 0,
            },
            splitsText = {
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 20,
                textColor = { 1, 1, 1, 1 },
                xOffset = 0,
                yOffset = 0,
            },
            timerBar = {
                barTexture = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Statusbars\\bar4.tga",
                bgColor = { 0, 0, 0, 0.6 },
                borderColor = { 0, 0, 0, 1 },
                borderOffset = 1,
                borderOn = true,
                borderSize = 1,
                borderTexture = "Interface\\Buttons\\WHITE8X8",
                dividerWidth = 1,
                height = 6,
                reverse = false,
                sectionColors = {
                    [0] = { 0.85, 0.2, 0.2, 1 },
                    [1] = { 0.95, 0.75, 0.1, 1 },
                    [2] = { 0.55, 0.8, 0.1, 1 },
                    [3] = { 0.1, 0.8, 0.2, 1 },
                },
                sectionDividerColor = { 1, 1, 1, 1 },
            },
            timerBest = {
                fontSize = 18,
            },
            timerBonus = {
                fontSize = 16,
            },
            timerLevel = {
                fontSize = 16,
            },
            timerSection = {
                countdownPos = "left",
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 14,
                posH = "right",
                posV = "top",
                xOffset = -5,
                yOffset = -5,
            },
            timerText = {
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 32,
                maxColor = { 0.6, 0.6, 0.6, 1 },
                textColor = { 0.9843, 1, 0.9843, 1 },
                xOffset = 0,
                yOffset = 0,
            },
        },
        font = {
            fontSize = 14,
        },
        locked = true,
        point = "RIGHT",
        scale = 1,
        separators = {
            {
                after = "objectives",
                color = { 0.6784, 0.6784, 0.6784, 1 },
                enabled = false,
                height = 2,
                width = 400,
            },
            {
                after = "deaths",
                color = { 1, 1, 1, 0.5 },
                enabled = false,
                height = 2,
                width = 180,
            },
        },
        showBest = true,
        spacing = 5,
        style = {
            barTexture = "Interface\\AddOns\\BigWigs\\Media\\Textures\\Smoothv2",
            borderSize = 4,
            fontFlags = "OUTLINE",
            fontSize = 14,
            sectionDividerColor = { 1, 1, 1, 0.65 },
        },
        theme = "default",
        title = {
            show = true,
            text = "",
        },
        width = 400,
        x = -22,
        y = 265,
    },
}
Addon.Utils.CopyInto(defaults.profile, preset)

-- Create the database and wire up profile-change callbacks.
function Addon:SetupDB()
    local AceDB = LibStub("AceDB-3.0")
    -- Third arg `true` -> use a single shared "Default" profile to start with.
    self.db = AceDB:New("MauiMPlusTimerDB", defaults, true)

    self:MigrateDB()

    -- When the active profile changes, tell every module to reload its settings.
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
end

-- Broadcast a profile change so modules can re-read db.profile.
function Addon:OnProfileChanged()
    if self.Widgets then self.Widgets:InvalidateStyle() end -- new profile -> new styles
    if self.RefreshMinimapButton then self:RefreshMinimapButton() end -- new minimap state
    self:SendMessage("MMT_PROFILE_CHANGED")
end

-- Apply versioned migrations to the global scope.
function Addon:MigrateDB()
    local g = self.db.global
    g.version = g.version or 1
    -- Future migration steps are added here, keyed on g.version.
end
