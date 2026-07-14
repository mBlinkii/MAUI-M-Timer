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
                showBar = true,    -- the bar is a separate orderable block ("timerbar")
                splitBar = false,  -- split the bar into three segments (+3/+2/+1)
                splitGap = 2,      -- pixel gap between the three split segments
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
            EnemyForces = { enabled = true, showMarkers = false }, -- checkpoint markers on the bar
            Objectives  = {
                enabled = true, rowSpacing = 0,
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
            -- a block in the HUD stack; the position is configured like any
            -- other block via the row layout (General -> Element order).
            -- NOTE: no `after` key here - legacy anchors in the DEFAULTS would
            -- be re-injected into profiles on every login and re-trigger the
            -- one-time migration in MigrateProfile over and over.
            separators = {
                { enabled = false, width = 180, height = 2, color = { 1, 1, 1, 0.5 } },
                { enabled = false, width = 180, height = 2, color = { 1, 1, 1, 0.5 } },
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
        -- Last addon version whose changelog was auto-shown (Modules/Changelog).
        lastChangelogVersion = "",
        -- Persisted geometry (width/height/top/left) of the standalone options
        -- window; written by the AceGUI Frame status table (Core/Config.lua).
        optionsWindow = {},
        -- First-start setup wizard (Modules/Setup): `setupPending` is armed on
        -- a fresh installation and cleared once the wizard was handled;
        -- `setupDone` records that it ran (finished, skipped or closed).
        setupPending = false,
        setupDone    = false,
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
            enabled = true,
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
            enabled = true,
            sectionCountdown = true,
            sectionCountdownAll = true,
            showBar = true,
            showLevel = true,
            splitBar = true,
            splitGap = 6,
        },
    },
    ui = {
        align = "center",
        bestPrefix = "",
        bestSuffix = "",
        -- NOTE: ui.blockRows (the user-configurable row layout) is deliberately
        -- NOT part of the defaults/preset: AceDB merges defaults index-wise
        -- into saved arrays, which would corrupt user layouts. The factory
        -- fallback lives in UI/MainWindow.lua (MODULE_BLOCKS).
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
            forcesSegment = {
                font = "Fonts\\FRIZQT__.TTF",
                fontSize = 11,
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
                color = { 0.6784, 0.6784, 0.6784, 1 },
                enabled = false,
                height = 2,
                width = 400,
            },
            {
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
    -- Detect a fresh install BEFORE AceDB touches the SavedVariables: only a
    -- brand-new installation (no stored data at all) arms the one-time setup
    -- wizard, so existing users updating the addon are never bothered.
    local freshInstall = (_G.MauiMPlusTimerDB == nil)

    -- Third arg `true` -> use a single shared "Default" profile to start with.
    self.db = AceDB:New("MauiMPlusTimerDB", defaults, true)

    if freshInstall then
        self.db.global.setupPending = true
    end

    self:MigrateDB()
    self:MigrateProfile()

    -- When the active profile changes, tell every module to reload its settings.
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
end

-- Broadcast a profile change so modules can re-read db.profile.
function Addon:OnProfileChanged()
    self:MigrateProfile() -- a switched/imported profile may carry legacy keys
    if self.Widgets then self.Widgets:InvalidateStyle() end -- new profile -> new styles
    if self.RefreshMinimapButton then self:RefreshMinimapButton() end -- new minimap state
    self:SendMessage("MMT_PROFILE_CHANGED")
end

-- One-time migrations of removed options in the ACTIVE profile (idempotent;
-- runs at startup and after every profile switch/copy/reset/import).
function Addon:MigrateProfile()
    local p = self.db.profile

    -- Write a fresh single-block-per-row layout from a flat key list.
    local function writeRows(keys)
        local rows = {}
        for i, key in ipairs(keys) do
            rows[i] = { left = key }
        end
        p.ui.blockRows = rows
    end

    -- Never-released intermediate format of the row layout; drop it.
    if p.ui.blockOrder ~= nil then
        p.ui.blockOrder = nil
    end

    -- The Enemy Forces "Bar position" select became the free row ordering.
    -- The default rows already place the bar below the objectives (the old
    -- factory default), so only a saved "top" needs carrying over; the dead
    -- key is dropped either way. The module's alignment option was removed
    -- too (the main text has its own position setting now).
    local forces = p.modules and p.modules.EnemyForces
    if forces then
        if forces.position ~= nil then
            if forces.position == "top" then
                writeRows({ "dungeon", "timer", "forces", "objectives",
                    "deaths", "splits", "checkpoints", "cooldowns" })
            end
            forces.position = nil
        end
        forces.align = nil
    end

    -- Separator lines lost their "after <element>" anchor; they are ordinary
    -- row entries now. Rebuild the rows once from the legacy anchors so each
    -- separator ends up right below its old anchor module.
    local seps = p.ui.separators
    if seps and ((seps[1] and seps[1].after ~= nil)
        or (seps[2] and seps[2].after ~= nil)) then
        -- Only separators that still carry a legacy anchor are recreated from
        -- it; strip exactly those from the flattened base so they cannot end
        -- up duplicated. A separator without an anchor keeps its current row.
        local migrating = {}
        for i = 1, 2 do
            if seps[i] and seps[i].after ~= nil then
                migrating["separator" .. i] = true
            end
        end
        local base = {}
        if type(p.ui.blockRows) == "table" then
            for _, row in ipairs(p.ui.blockRows) do
                if type(row) == "table" then
                    if row.left and not migrating[row.left] then
                        base[#base + 1] = row.left
                    end
                    if row.right and not migrating[row.right] then
                        base[#base + 1] = row.right
                    end
                end
            end
        end
        if #base == 0 then
            base = { "dungeon", "timer", "objectives", "forces",
                "deaths", "splits", "checkpoints", "cooldowns" }
        end
        local keys = {}
        for _, key in ipairs(base) do
            keys[#keys + 1] = key
            for i = 1, 2 do
                if seps[i] and seps[i].after == key then
                    keys[#keys + 1] = "separator" .. i
                end
            end
        end
        writeRows(keys)
        for i = 1, 2 do
            if seps[i] then seps[i].after = nil end
        end
    end

    -- Repair row layouts written by earlier (pre-release) iterations: the
    -- re-running legacy migration above accumulated duplicate keys and rows
    -- beyond the configurable range. Only rewrites when actually damaged, so
    -- intentional row gaps are preserved for healthy layouts.
    local rows = p.ui.blockRows
    if type(rows) == "table" then
        local maxRows = (self.MainWindow and self.MainWindow.MAX_ROWS) or 10
        local seen, damaged = {}, #rows > maxRows
        for _, row in ipairs(rows) do
            if type(row) == "table" then
                if row.left ~= nil then
                    if seen[row.left] then damaged = true end
                    seen[row.left] = true
                end
                if row.right ~= nil then
                    if seen[row.right] then damaged = true end
                    seen[row.right] = true
                end
            end
        end
        if damaged then
            local clean, taken = {}, {}
            for _, row in ipairs(rows) do
                if type(row) == "table" and #clean < maxRows then
                    local left = (type(row.left) == "string" and not taken[row.left])
                        and row.left or nil
                    if left then taken[left] = true end
                    local right = (type(row.right) == "string" and not taken[row.right])
                        and row.right or nil
                    if right then taken[right] = true end
                    if left or right then
                        clean[#clean + 1] = { left = left, right = right }
                    end
                end
            end
            p.ui.blockRows = clean
        end
    end

    -- The row layout may have changed above (or a different profile became
    -- active): drop the cached normalized rows.
    if self.MainWindow and self.MainWindow.InvalidateRows then
        self.MainWindow:InvalidateRows()
    end
end

-- Apply versioned migrations to the global scope.
function Addon:MigrateDB()
    local g = self.db.global
    g.version = g.version or 1
    -- Future migration steps are added here, keyed on g.version.
end
