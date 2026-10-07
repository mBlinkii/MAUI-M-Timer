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
                enabled = true, showName = true, showAffixes = true,
                showLevel = true, levelColor = false, -- keystone level
                showIcon = false, iconSize = 20, -- optional map icon
                bg = {
                    show = false, color = { 0, 0, 0, 0.5 },
                    border = false, borderTexture = "Solid",
                    borderSize = 1, borderColor = { 0, 0, 0, 1 },
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
            orientation = "vertical", -- "vertical" (3 x 11 grid) | "horizontal" (5 x 3 grid)
            width   = 220,      -- HUD width in pixels (configurable)
            widthHorizontal = 560, -- HUD width of the horizontal grid
            spacing = 2,        -- vertical gap (px) between stacked HUD blocks
            theme   = "default",
            align   = "center", -- "left" | "center" | "right"
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
            -- No `after` key here: a legacy anchor in the DEFAULTS would be
            -- re-injected on every login and re-trigger MigrateProfile forever.
            separators = {
                { enabled = false, width = 180, height = 2, color = { 1, 1, 1, 0.5 } },
                { enabled = false, width = 180, height = 2, color = { 1, 1, 1, 0.5 } },
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
    self:MigrateProfile()

    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
end

function Addon:OnProfileChanged()
    self:MigrateProfile() -- a switched/imported profile may carry legacy keys
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

-- Idempotent: also runs after every profile switch, copy, reset and import.
function Addon:MigrateProfile()
    local p = self.db.profile

    local function writeRows(keys) -- one block per row, from a flat key list
        local rows = {}
        for i, key in ipairs(keys) do
            rows[i] = { key }
        end
        p.ui.blockRows = rows
    end

    local maxCols = (self.MainWindow and self.MainWindow.MAX_COLS) or 5

    -- Rows were { left = key, right = key } before the grid got more columns.
    for _, rowsKey in ipairs({ "blockRows", "blockRowsHorizontal" }) do
        local rows = p.ui[rowsKey]
        if type(rows) == "table" then
            for i, row in ipairs(rows) do
                if type(row) == "table" and (row.left ~= nil or row.right ~= nil) then
                    rows[i] = { row[1] or row.left, row[2] or row.right }
                end
            end
        end
    end

    -- Never-released intermediate format of the row layout; drop it.
    if p.ui.blockOrder ~= nil then
        p.ui.blockOrder = nil
    end

    -- "Bar position" became the free row ordering. The default rows already
    -- match the old default, so only a saved "top" needs carrying over.
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

    -- Separators lost their "after <element>" anchor and are ordinary row
    -- entries now; rebuild the rows once so each keeps its old position.
    local seps = p.ui.separators
    if seps and ((seps[1] and seps[1].after ~= nil)
        or (seps[2] and seps[2].after ~= nil)) then
        -- Strip exactly the anchored ones from the base so they cannot end up
        -- duplicated; an unanchored separator keeps its current row.
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
                    for c = 1, maxCols do
                        if row[c] and not migrating[row[c]] then
                            base[#base + 1] = row[c]
                        end
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

    -- The stacked timer layouts became a position of the second value.
    local timer = p.modules and p.modules.Timer
    if timer then
        if timer.textLayout == "stacked" then
            timer.textLayout, timer.secondPos = "inline", "below"
        elseif timer.textLayout == "stackedRemaining" then
            timer.textLayout, timer.secondPos = "elapsedRemaining", "below"
        end
        if timer.bestPos == "beside" then timer.bestPos = nil end
    end

    -- Dungeon and Cooldowns became one block per part. The new parts go next
    -- to where the old block sat, so a saved layout keeps its look.
    local dungeon = p.modules and p.modules.Dungeon or {}
    local grids = self.MainWindow and self.MainWindow.GRIDS
    for _, grid in ipairs({ { "blockRows", 3 }, { "blockRowsHorizontal", 5 } }) do
        local rowsKey = grid[1]
        local cols = (grids and grids[rowsKey == "blockRows" and "vertical" or "horizontal"].cols) or grid[2]
        local rows = p.ui[rowsKey]
        if type(rows) == "table" then
            local function find(key)
                for i, row in ipairs(rows) do
                    if type(row) == "table" then
                        for c = 1, cols do
                            if row[c] == key then return i, c end
                        end
                    end
                end
            end
            local function putNear(key, i, c, side)
                local row = rows[i]
                for _, cc in ipairs({ c + side, c - side }) do
                    if cc >= 1 and cc <= cols and row[cc] == nil then row[cc] = key; return end
                end
                for cc = 1, cols do
                    if row[cc] == nil then row[cc] = key; return end
                end
                table.insert(rows, i + 1, { [c] = key })
            end

            local i, c = find("cooldowns")
            if i then
                rows[i][c] = "brez"
                putNear("bloodlust", i, c, 1)
            end

            i, c = find("dungeon")
            if i and not (find("level") or find("affixes") or find("dungeonicon")) then
                if dungeon.showIcon == true then
                    putNear("dungeonicon", i, c, dungeon.iconPos == "right" and 1 or -1)
                end
                if dungeon.showLevel ~= false then
                    putNear("level", i, c, dungeon.levelPos == "right" and 1 or -1)
                end
                if dungeon.showAffixes ~= false then
                    table.insert(rows, i + 1, { [c] = "affixes" })
                end
            end
        end
    end
    dungeon.levelPos, dungeon.levelSep, dungeon.iconPos = nil, nil, nil

    -- The parts take over the old shared text style once.
    local elements = p.ui.elements
    if elements then
        local function copyOnto(from, to)
            local target = elements[to] or {}
            for k, v in pairs(from) do
                target[k] = type(v) == "table" and Addon.Utils.CopyTable(v) or v
            end
            elements[to] = target
        end
        if type(elements.cooldownsText) == "table" then
            copyOnto(elements.cooldownsText, "brezText")
            copyOnto(elements.cooldownsText, "lustText")
            elements.cooldownsText = nil
        end
        if not p.ui.blocksSplit and type(elements.dungeonName) == "table" then
            copyOnto(elements.dungeonName, "dungeonLevel")
        end
    end
    p.ui.blocksSplit = true

    -- Earlier pre-release iterations of the migration above accumulated
    -- duplicates and overlong layouts. Only rewrite when actually damaged, so
    -- intentional row gaps survive.
    local maxRows = (self.MainWindow and self.MainWindow.MAX_ROWS) or 11
    for _, rowsKey in ipairs({ "blockRows", "blockRowsHorizontal" }) do
        local rows = p.ui[rowsKey]
        if type(rows) == "table" then
            local seen, damaged = {}, #rows > maxRows
            for _, row in ipairs(rows) do
                if type(row) == "table" then
                    for c = 1, maxCols do
                        if row[c] ~= nil then
                            if seen[row[c]] then damaged = true end
                            seen[row[c]] = true
                        end
                    end
                end
            end
            if damaged then
                local clean, taken = {}, {}
                for _, row in ipairs(rows) do
                    if type(row) == "table" and #clean < maxRows then
                        local out, any = {}, false
                        for c = 1, maxCols do
                            local key = row[c]
                            if type(key) == "string" and not taken[key] then
                                taken[key], out[c], any = true, key, true
                            end
                        end
                        if any then clean[#clean + 1] = out end
                    end
                end
                p.ui[rowsKey] = clean
            end
        end
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
