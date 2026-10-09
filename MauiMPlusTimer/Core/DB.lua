-- Core/DB.lua
-- AceDB setup: defaults, scopes (profile/char/global) and version migration.
-- This is the only place that touches the SavedVariables table directly.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

-- AceDB deep-merges these, so new keys appear on existing installs.
local defaults = {
    profile = {
        debug = false,
        modules = {
            Timer       = {
                enabled = true,
                showText = true,   -- the time text block ("timer")
                textLayout = "inline", secondPos = "right", bestPos = "right", -- see Timer UI.TEXT_LAYOUTS
                showBar = true,    -- the bar is a separate orderable block ("timerbar")
                splitBar = false,  -- split the bar into three segments (+3/+2/+1)
                splitGap = 2,      -- pixel gap between the three split segments
                sectionCountdown = false, sectionCountdownAll = false, -- threshold countdowns
            },
            Dungeon     = {
                -- One block each: "dungeon", "affixes", "level", "dungeonicon".
                enabled = true, showName = true, nameShort = false, showAffixes = true,
                showLevel = true, levelColor = false, -- keystone level
                -- Optional badge: "none" | "square" | "rounded" | "pill" | "circle".
                levelBg = "none", levelBgColorBy = "rarity", levelBgPadX = 6, levelBgPadY = 2, levelBgRadius = 4,
                showIcon = false, iconSize = 20, -- optional map icon
                affixStyle = "text", affixIconSize = 20, affixIconGap = 4, -- "text" | "icons"
            },
            EnemyForces = { enabled = true, showMarkers = false }, -- checkpoint markers on the bar
            Objectives  = {
                enabled = true, rowSpacing = 0,
                -- "text" list, or icons: "row" | "column" | "grid" (perRow per line).
                layout = "text", perRow = 3, iconStyle = "portrait", iconSize = 24, iconGap = 4,
                shapePendingColor = { 1, 1, 1 }, shapeDoneColor = { 0.2, 1, 0.6 }, -- shape icon styles
                -- Boss-name shortening for display: "off" | "truncate" (with
                -- nameMaxLength characters + ellipsis) | "firstword" | "abbrev".
                nameShorten = "off", nameMaxLength = 12,
            },
            Deaths      = { enabled = true },
            Splits      = { enabled = true, storeMode = "best", showText = true }, -- "best" | "all"; showText = HUD line visible (recording is independent)
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
            -- gridCols/gridRows size the element grid; unset, MainWindow.GetGrid
            -- falls back to its defaults.
            width   = 220,      -- HUD width in pixels (configurable)
            spacing = 2,        -- vertical gap (px) between stacked HUD blocks
            theme   = "default",
            locked  = true,     -- locked by default; unlock to drag the HUD
            demo    = false,
            showBest = false,    -- show the stored best run's split times behind live elements
            bestPrefix = "(", bestSuffix = ")", -- bracket characters around best times (either may be empty)
            -- Accent of the settings window. "class" follows the player's class
            -- colour, "custom" uses the stored one, "default" the value below.
            accent  = { mode = "class", color = { 0.161, 0.659, 0.941 } },
            -- Settings window typeface and how solid its surfaces are. font =
            -- false picks the most legible face LibSharedMedia offers; slug
            -- asks for WoW's outline renderer, for the window and the HUD.
            window  = { font = false, slug = true, alpha = 1 },
            font = {},           -- global font baseline (font, fontSize, fontFlags)
            elements = {},       -- per-element style overrides, keyed by elementKey
            separatorCount = 0,  -- separators 1..count exist; each shows once placed
            separators = {
                ["*"] = { width = 180, height = 2, color = { 1, 1, 1, 0.5 } }, -- width 0 = whole row
            },
            bg = {
                show        = false,
                color       = { 0, 0, 0, 0.6 },
                border      = false,
                borderTexture = "Solid",
                borderSize  = 1,
                borderColor = { 0, 0, 0, 1 },
            },
        },
        minimap = { hide = true }, -- minimap button hidden by default (optional)
    },
    -- Written continuously so a /reload mid-key loses nothing.
    char = {
        activeRun = false, -- false = no active run
    },
    global = {
        version     = 1,
        splits      = {},
        checkpoints = {},
        lastChangelogVersion = "", -- last version whose changelog was auto-shown
        optionsWindow = {},        -- settings window geometry and folded sections
        panels      = {},          -- geometry per side panel, keyed by its id
        setupPending = false,      -- armed on a fresh install, cleared once handled
        setupDone    = false,      -- wizard ran (finished, skipped or closed)
    },
}

-- Factory preset, deep-merged onto the structural defaults above (which still
-- backfill any key it omits). Edit here to change the out-of-the-box config.
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
            enabled = true,
        },
        Cooldowns = {
            brez = {
                on = true,
            },
            enabled = true,
            lust = {
                on = true,
            },
        },
        Deaths = {
            enabled = true,
            icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
        },
        Dungeon = {
            enabled = true,
            iconSize = 42,
            levelColor = true,
            showAffixes = true,
            showIcon = true,
            showLevel = true,
        },
        EnemyForces = {
            enabled = true,
            showCount = false,
            showMarkers = true,
        },
        Objectives = {
            doneIcon = "Interface\\RaidFrame\\ReadyCheck-Ready",
            doneIconColor = { 1, 1, 1 },
            enabled = true,
            pendingIcon = "Interface\\RaidFrame\\ReadyCheck-Waiting",
            pendingIconColor = { 1, 1, 1 },
            rowSpacing = 0,
            showDoneIcon = true,
            showPendingIcon = true,
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
            enabled = true,
            storeMode = "all",
        },
        Timer = {
            enabled = true,
            sectionCountdown = true,
            sectionCountdownAll = true,
            showBar = true,
            splitBar = true,
            splitGap = 6,
        },
    },
    ui = {
        bestPrefix = "",
        bestSuffix = "",
        -- ui.blockRows is deliberately absent: AceDB merges defaults index-wise
        -- into saved arrays and would corrupt user layouts. Fallback lives in
        -- UI/MainWindow.lua (MODULE_BLOCKS).
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
            brezText = {
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 20,
                rechargeColor = { 0.6, 0.6, 0.6, 1 },
                textColor = { 1, 1, 1, 1 },
                xOffset = 0,
                yOffset = 0,
            },
            lustText = {
                cdColor = { 1, 0.38, 0.38, 1 },
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 20,
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
            dungeonLevel = {
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
            forcesSegment = {
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 11,
                textColor = { 1, 1, 1, 1 },
                xOffset = 0,
                yOffset = 0,
            },
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
        showBest = true,
        spacing = 5,
        theme = "default",
        width = 400,
        x = -22,
        y = 265,
    },
}
Addon.Utils.CopyInto(defaults.profile, preset)

function Addon:SetupDB()
    local AceDB = LibStub("AceDB-3.0")
    -- Must be read before AceDB touches SavedVariables; only a truly fresh
    -- install arms the setup wizard, never an update.
    local freshInstall = (_G.MauiMPlusTimerDB == nil)

    self.db = AceDB:New("MauiMPlusTimerDB", defaults, true) -- shared "Default" profile

    if freshInstall then
        self.db.global.setupPending = true
    end

    self:MigrateDB()
    self:CleanProfile()

    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
end

function Addon:OnProfileChanged()
    self:CleanProfile() -- a switched/imported profile may carry stale keys
    if self.Widgets then self.Widgets:InvalidateStyle() end
    if self.RefreshMinimapButton then self:RefreshMinimapButton() end

    -- Blocks the old profile showed must go; the row cache depends on those states.
    self:ApplyModuleStates()
    if self.MainWindow then self.MainWindow:InvalidateRows() end

    -- Not MainWindow:Refresh: its per-module Restyle would re-show blocks the
    -- new profile disabled. Enabled modules restyle from LoadSettings instead.
    self:SendMessage("MMT_PROFILE_CHANGED")

    if self.Demo then self.Demo:Apply() end
    if self.MainWindow then
        self.MainWindow:ApplyPosition()
        self.MainWindow:ApplyWidth() -- also relayouts
    end
end

-- Settings of earlier HUD layouts that nothing reads anymore. Profiles from
-- before the grid are not carried over; this only keeps them from piling up.
local OBSOLETE_UI = {
    "align", "blocksSplit", "blockOrder", "orientation", "horizontalColumns", "blockRowsHorizontal",
    "widthHorizontal", "widthHorizontal7", "widthHorizontal9", "title", "style",
    "horizontalAlign2", "horizontalAlign3", "horizontalAlign4", "horizontalAlign5",
    "horizontalAlign6", "horizontalAlign7", "horizontalAlign8",
}
local OBSOLETE_ELEMENTS = { "hudTitle", "timerBonus", "timerLevel", "cooldownsText" }
local OBSOLETE_MODULE = {
    Timer = { "showLevel" },
    Dungeon = { "bg", "levelPos", "levelSep", "iconPos", "levelBgRarity" },
    EnemyForces = { "position" },
    Objectives = { "timeSide" },
    Deaths = { "iconSize" },
    Cooldowns = { "brezIconSize", "lustIconSize" },
}

-- Idempotent: also runs after every profile switch, copy, reset and import.
function Addon:CleanProfile()
    local p = self.db.profile
    for _, key in ipairs(OBSOLETE_UI) do p.ui[key] = nil end
    if p.ui.elements then
        for _, key in ipairs(OBSOLETE_ELEMENTS) do p.ui.elements[key] = nil end
    end
    for name, settings in pairs(p.modules or {}) do
        if type(settings) == "table" then
            settings.align = nil
            for _, key in ipairs(OBSOLETE_MODULE[name] or {}) do settings[key] = nil end
        end
    end
    for _, sep in pairs(p.ui.separators or {}) do
        if type(sep) == "table" then sep.after, sep.enabled = nil, nil end
    end
    if self.MainWindow and self.MainWindow.InvalidateRows then
        self.MainWindow:InvalidateRows()
    end
end

-- Versioned migrations of the global scope, keyed on g.version.
function Addon:MigrateDB()
    local g = self.db.global
    g.version = g.version or 1
end
