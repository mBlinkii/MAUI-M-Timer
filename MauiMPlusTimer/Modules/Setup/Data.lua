-- Modules/Setup/Data.lua
-- Preset profiles offered by the setup wizard.
--
-- To add a preset:
--   1. Configure a profile in-game, then export it via Options -> Share ->
--      "Export as Lua table" and paste the table as `profile`.
--   2. (Optional) Add a screenshot as a power-of-two TGA under Assets/Setup/
--      and set `screenshot` to its texture path (plus `screenshotSize` with
--      the original pixel size for the correct aspect ratio).
--   3. Add the `description` key to both localization files.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Setup = Addon:GetModule("Setup")

local Data = {}
Setup.Data = Data

-- Ordered list of selectable presets.
--   key            stable identifier (used in debug output)
--   name           display name (plain data, deliberately not localized)
--   description    localization key for the short description
--   screenshot     optional texture path (power-of-two TGA) shown as preview
--   screenshotSize optional { width, height } display size for the preview
--   profile        plain profile table to apply, or nil = factory defaults
Data.profiles = {
    {
        key = "maui",
        name = "MaUI",
        description = "The author's personal MAUI look.",
        screenshot = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Setup\\maui",
        screenshotSize = { 450, 342 },
        profile = {
            debug = false,
            minimap = {
                hide = false,
                minimapPos = 175.63474320513,
            },
            modules = {
                Automation = {
                    autoSlotKeystone = true,
                    enabled = true,
                    hideTracker = true,
                },
                Changelog = {
                },
                Checkpoints = {
                    align = "left",
                    enabled = true,
                    labelIcons = true,
                    ponrIconColor = {
                        [1] = 1,
                        [2] = 0.38431376218796,
                        [3] = 0,
                    },
                },
                Cooldowns = {
                    align = "left",
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
                        border = false,
                        borderColor = {
                            [1] = 0,
                            [2] = 0,
                            [3] = 0,
                            [4] = 1,
                        },
                        borderSize = 3,
                        borderTexture = "",
                        color = {
                            [1] = 0.13725490868092,
                            [2] = 0.27058824896812,
                            [3] = 0.47843140363693,
                            [4] = 0.5,
                        },
                        show = false,
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
                    segmentCountdown = true,
                    segmentCountdownAll = true,
                    showCount = false,
                    showMarkers = true,
                    splitBar = true,
                    splitGap = 6,
                },
                Objectives = {
                    align = "right",
                    doneIcon = "Interface\\RaidFrame\\ReadyCheck-Ready",
                    doneIconColor = {
                        [1] = 1,
                        [2] = 1,
                        [3] = 1,
                    },
                    enabled = true,
                    nameMaxLength = 12,
                    nameShorten = "abbrev",
                    pendingIcon = "Interface\\RaidFrame\\ReadyCheck-Waiting",
                    pendingIconColor = {
                        [1] = 1,
                        [2] = 1,
                        [3] = 1,
                    },
                    rowSpacing = 0,
                    showDoneIcon = true,
                    showForcesRow = true,
                    showPendingIcon = true,
                    timeSide = "auto",
                },
                Setup = {
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
                        resurrect = {
                            on = true,
                            sound = "Alarm",
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
                    labelIcon = true,
                    labelIconColor = {
                        [1] = 0,
                        [2] = 0.75686281919479,
                        [3] = 1,
                    },
                    storeMode = "all",
                },
                Timer = {
                    align = "right",
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
                    borderColor = {
                        [1] = 0,
                        [2] = 0,
                        [3] = 0,
                        [4] = 1,
                    },
                    borderSize = 1,
                    borderTexture = "Interface\\Buttons\\WHITE8X8",
                    color = {
                        [1] = 0,
                        [2] = 0,
                        [3] = 0,
                        [4] = 0.21093600988388,
                    },
                    show = false,
                },
                blockRows = {
                    { left = "dungeon" },
                    { left = "timer" },
                    { left = "objectives" },
                    { left = "forces" },
                    { left = "checkpoints", right = "splits" },
                    { left = "cooldowns", right = "deaths" },
                    {},
                    {},
                    {},
                    {},
                },
                demo = false,
                elements = {
                    checkpointsText = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 18,
                        textColor = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 1,
                        },
                        xOffset = 0,
                        yOffset = 0,
                    },
                    cooldownsText = {
                        cdColor = {
                            [1] = 1,
                            [2] = 0.38,
                            [3] = 0.38,
                            [4] = 1,
                        },
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 20,
                        rechargeColor = {
                            [1] = 0.60000002384186,
                            [2] = 0.60000002384186,
                            [3] = 0.60000002384186,
                            [4] = 1,
                        },
                        textColor = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 1,
                        },
                        xOffset = 0,
                        yOffset = 0,
                    },
                    deathsText = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontFlags = "OUTLINE",
                        fontSize = 20,
                        penaltyColor = {
                            [1] = 1,
                            [2] = 0.38,
                            [3] = 0.38,
                            [4] = 1,
                        },
                        textColor = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 1,
                        },
                        xOffset = 0,
                        yOffset = 0,
                    },
                    deltas = {
                        ahead = {
                            [1] = 0.2,
                            [2] = 1,
                            [3] = 0.6,
                            [4] = 1,
                        },
                        behind = {
                            [1] = 1,
                            [2] = 0.38,
                            [3] = 0.38,
                            [4] = 1,
                        },
                    },
                    dungeonAffixes = {
                        fontFlags = "OUTLINE",
                        fontSize = 14,
                        textColor = {
                            [1] = 0.60000002384186,
                            [2] = 0.60000002384186,
                            [3] = 0.60000002384186,
                            [4] = 1,
                        },
                        xOffset = 0,
                        yOffset = 0,
                    },
                    dungeonName = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 20,
                        textColor = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 1,
                        },
                        xOffset = 0,
                        yOffset = 0,
                    },
                    forcesBar = {
                        barColor = {
                            [1] = 0.2,
                            [2] = 0.6,
                            [3] = 1,
                            [4] = 1,
                        },
                        barTexture = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Statusbars\\bar4.tga",
                        bgColor = {
                            [1] = 0,
                            [2] = 0,
                            [3] = 0,
                            [4] = 0.6,
                        },
                        borderColor = {
                            [1] = 0,
                            [2] = 0,
                            [3] = 0,
                            [4] = 1,
                        },
                        borderOffset = 1,
                        borderOn = true,
                        borderSize = 1,
                        borderTexture = "1 Pixel",
                        height = 20,
                        markerColor = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 1,
                        },
                        reverse = false,
                    },
                    forcesSegment = {
                        countdownPos = "center",
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 14,
                        textColor = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 1,
                        },
                        xOffset = 0,
                        yOffset = 0,
                    },
                    forcesText = {
                        countColor = {
                            [1] = 0.60000002384186,
                            [2] = 0.60000002384186,
                            [3] = 0.60000002384186,
                            [4] = 1,
                        },
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 14,
                        textColor = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 1,
                        },
                        textPos = "barLeft",
                        xOffset = 4,
                        yOffset = 0,
                    },
                    hudTitle = {
                    },
                    objectiveText = {
                        doneColor = {
                            [1] = 0.2,
                            [2] = 1,
                            [3] = 0.6,
                            [4] = 1,
                        },
                        fontSize = 18,
                        openColor = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 1,
                        },
                        textColor = {
                            [1] = 1,
                            [2] = 0.29019609093666,
                            [3] = 0.66666668653488,
                            [4] = 1,
                        },
                        timeColor = {
                            [1] = 0.60000002384186,
                            [2] = 0.60000002384186,
                            [3] = 0.60000002384186,
                            [4] = 1,
                        },
                        xOffset = 0,
                        yOffset = 0,
                    },
                    splitsText = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 18,
                        textColor = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 1,
                        },
                        xOffset = 0,
                        yOffset = 0,
                    },
                    timerBar = {
                        barTexture = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Statusbars\\bar4.tga",
                        bgColor = {
                            [1] = 0,
                            [2] = 0,
                            [3] = 0,
                            [4] = 0.6,
                        },
                        borderColor = {
                            [1] = 0,
                            [2] = 0,
                            [3] = 0,
                            [4] = 1,
                        },
                        borderOffset = 1,
                        borderOn = true,
                        borderSize = 1,
                        borderTexture = "Interface\\Buttons\\WHITE8X8",
                        dividerWidth = 1,
                        height = 6,
                        reverse = false,
                        sectionColors = {
                            [0] = {
                                [1] = 0.85,
                                [2] = 0.2,
                                [3] = 0.2,
                                [4] = 1,
                            },
                            [1] = {
                                [1] = 0.95,
                                [2] = 0.75,
                                [3] = 0.1,
                                [4] = 1,
                            },
                            [2] = {
                                [1] = 0.55,
                                [2] = 0.8,
                                [3] = 0.1,
                                [4] = 1,
                            },
                            [3] = {
                                [1] = 0.1,
                                [2] = 0.8,
                                [3] = 0.2,
                                [4] = 1,
                            },
                        },
                        sectionDividerColor = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 1,
                        },
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
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 14,
                        posH = "right",
                        posV = "top",
                        xOffset = -5,
                        yOffset = -5,
                    },
                    timerText = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 32,
                        maxColor = {
                            [1] = 0.60000002384186,
                            [2] = 0.60000002384186,
                            [3] = 0.60000002384186,
                            [4] = 1,
                        },
                        textColor = {
                            [1] = 0.98431378602982,
                            [2] = 1,
                            [3] = 0.98431378602982,
                            [4] = 1,
                        },
                        xOffset = 0,
                        yOffset = 0,
                    },
                },
                font = {
                    applySize = false,
                    font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                    fontSize = 14,
                },
                locked = true,
                point = "TOPRIGHT",
                scale = 1,
                separators = {
                    [1] = {
                        color = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 0.5,
                        },
                        enabled = false,
                        height = 2,
                        width = 400,
                    },
                    [2] = {
                        color = {
                            [1] = 1,
                            [2] = 1,
                            [3] = 1,
                            [4] = 0.5,
                        },
                        enabled = false,
                        height = 2,
                        width = 400,
                    },
                },
                showBest = true,
                spacing = 5,
                style = {
                    barTexture = "Interface\\AddOns\\BigWigs\\Media\\Textures\\Smoothv2",
                    borderSize = 4,
                    fontFlags = "OUTLINE",
                    fontSize = 14,
                    sectionDividerColor = {
                        [1] = 1,
                        [2] = 1,
                        [3] = 1,
                        [4] = 0.64999997615814,
                    },
                },
                theme = "default",
                title = {
                    show = true,
                    text = "",
                },
                width = 400,
                x = -10.000774383545,
                y = -286.16677856445,
            },
        },
    },
    {
        key = "standard",
        name = "MAUI Standard",
        description = "The classic MAUI look with all default settings.",
        screenshot = nil,
        profile = nil, -- factory defaults
    },
}
