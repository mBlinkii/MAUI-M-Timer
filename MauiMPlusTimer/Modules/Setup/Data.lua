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
                minimapPos = 175.63474320512941,
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
                        border = false,
                        borderColor = {
                            [1] = 0.0,
                            [2] = 0.0,
                            [3] = 0.0,
                            [4] = 1.0,
                        },
                        borderSize = 3.0,
                        borderTexture = "",
                        color = {
                            [1] = 0.1372549086809158,
                            [2] = 0.27058824896812439,
                            [3] = 0.47843140363693237,
                            [4] = 0.5,
                        },
                        show = false,
                    },
                    enabled = true,
                    iconPos = "right",
                    iconSize = 42.0,
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
                    segmentCountdown = true,
                    showCount = false,
                    showMarkers = true,
                    splitBar = true,
                    splitGap = 6.0,
                },
                Objectives = {
                    align = "right",
                    doneIcon = "Interface\\RaidFrame\\ReadyCheck-Ready",
                    doneIconColor = {
                        [1] = 1.0,
                        [2] = 1.0,
                        [3] = 1.0,
                    },
                    enabled = true,
                    nameMaxLength = 12.0,
                    nameShorten = "abbrev",
                    pendingIcon = "Interface\\RaidFrame\\ReadyCheck-Waiting",
                    pendingIconColor = {
                        [1] = 1.0,
                        [2] = 1.0,
                        [3] = 1.0,
                    },
                    rowSpacing = 0.0,
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
                    storeMode = "all",
                },
                Timer = {
                    align = "center",
                    barTextGap = 5.0,
                    enabled = true,
                    sectionCountdown = true,
                    sectionCountdownAll = true,
                    showLevel = true,
                    splitBar = true,
                    splitGap = 6.0,
                },
            },
            ui = {
                align = "center",
                bestPrefix = "",
                bestSuffix = "",
                bg = {
                    border = true,
                    borderColor = {
                        [1] = 0.0,
                        [2] = 0.0,
                        [3] = 0.0,
                        [4] = 1.0,
                    },
                    borderSize = 1.0,
                    borderTexture = "Interface\\Buttons\\WHITE8X8",
                    color = {
                        [1] = 0.0,
                        [2] = 0.0,
                        [3] = 0.0,
                        [4] = 0.21093600988388059,
                    },
                    show = false,
                },
                elements = {
                    checkpointsText = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 20.0,
                        textColor = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                        xOffset = 0.0,
                        yOffset = 0.0,
                    },
                    cooldownsText = {
                        cdColor = {
                            [1] = 1.0,
                            [2] = 0.38,
                            [3] = 0.38,
                            [4] = 1.0,
                        },
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 20.0,
                        rechargeColor = {
                            [1] = 0.60000002384185791,
                            [2] = 0.60000002384185791,
                            [3] = 0.60000002384185791,
                            [4] = 1.0,
                        },
                        textColor = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                        xOffset = 0.0,
                        yOffset = 0.0,
                    },
                    deathsText = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontFlags = "OUTLINE",
                        fontSize = 20.0,
                        penaltyColor = {
                            [1] = 1.0,
                            [2] = 0.38,
                            [3] = 0.38,
                            [4] = 1.0,
                        },
                        textColor = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                        xOffset = 0.0,
                        yOffset = 0.0,
                    },
                    deltas = {
                        ahead = {
                            [1] = 0.2,
                            [2] = 1.0,
                            [3] = 0.6,
                            [4] = 1.0,
                        },
                        behind = {
                            [1] = 1.0,
                            [2] = 0.38,
                            [3] = 0.38,
                            [4] = 1.0,
                        },
                    },
                    dungeonAffixes = {
                        fontFlags = "OUTLINE",
                        fontSize = 14.0,
                        textColor = {
                            [1] = 0.60000002384185791,
                            [2] = 0.60000002384185791,
                            [3] = 0.60000002384185791,
                            [4] = 1.0,
                        },
                        xOffset = 0.0,
                        yOffset = 0.0,
                    },
                    dungeonName = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 20.0,
                        textColor = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                        xOffset = 0.0,
                        yOffset = 0.0,
                    },
                    forcesBar = {
                        barColor = {
                            [1] = 0.2,
                            [2] = 0.6,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                        barTexture = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Statusbars\\bar4.tga",
                        bgColor = {
                            [1] = 0.0,
                            [2] = 0.0,
                            [3] = 0.0,
                            [4] = 0.6,
                        },
                        borderColor = {
                            [1] = 0.0,
                            [2] = 0.0,
                            [3] = 0.0,
                            [4] = 1.0,
                        },
                        borderOffset = 1.0,
                        borderOn = true,
                        borderSize = 1.0,
                        borderTexture = "Interface\\Buttons\\WHITE8X8",
                        height = 20.0,
                        markerColor = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                        reverse = false,
                    },
                    forcesSegment = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 14.0,
                        textColor = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                        xOffset = 0.0,
                        yOffset = 0.0,
                    },
                    forcesText = {
                        countColor = {
                            [1] = 0.60000002384185791,
                            [2] = 0.60000002384185791,
                            [3] = 0.60000002384185791,
                            [4] = 1.0,
                        },
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 14.0,
                        textColor = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                        xOffset = 4.0,
                        yOffset = 0.0,
                    },
                    hudTitle = {
                    },
                    objectiveText = {
                        doneColor = {
                            [1] = 0.2,
                            [2] = 1.0,
                            [3] = 0.6,
                            [4] = 1.0,
                        },
                        fontSize = 18.0,
                        openColor = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                        textColor = {
                            [1] = 1.0,
                            [2] = 0.29019609093666082,
                            [3] = 0.66666668653488159,
                            [4] = 1.0,
                        },
                        timeColor = {
                            [1] = 0.60000002384185791,
                            [2] = 0.60000002384185791,
                            [3] = 0.60000002384185791,
                            [4] = 1.0,
                        },
                        xOffset = 0.0,
                        yOffset = 0.0,
                    },
                    splitsText = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 20.0,
                        textColor = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                        xOffset = 0.0,
                        yOffset = 0.0,
                    },
                    timerBar = {
                        barTexture = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Statusbars\\bar4.tga",
                        bgColor = {
                            [1] = 0.0,
                            [2] = 0.0,
                            [3] = 0.0,
                            [4] = 0.6,
                        },
                        borderColor = {
                            [1] = 0.0,
                            [2] = 0.0,
                            [3] = 0.0,
                            [4] = 1.0,
                        },
                        borderOffset = 1.0,
                        borderOn = true,
                        borderSize = 1.0,
                        borderTexture = "Interface\\Buttons\\WHITE8X8",
                        dividerWidth = 1.0,
                        height = 6.0,
                        reverse = false,
                        sectionColors = {
                            [0] = {
                                [1] = 0.85,
                                [2] = 0.2,
                                [3] = 0.2,
                                [4] = 1.0,
                            },
                            [1] = {
                                [1] = 0.95,
                                [2] = 0.75,
                                [3] = 0.1,
                                [4] = 1.0,
                            },
                            [2] = {
                                [1] = 0.55,
                                [2] = 0.8,
                                [3] = 0.1,
                                [4] = 1.0,
                            },
                            [3] = {
                                [1] = 0.1,
                                [2] = 0.8,
                                [3] = 0.2,
                                [4] = 1.0,
                            },
                        },
                        sectionDividerColor = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 1.0,
                        },
                    },
                    timerBest = {
                        fontSize = 18.0,
                    },
                    timerBonus = {
                        fontSize = 16.0,
                    },
                    timerLevel = {
                        fontSize = 16.0,
                    },
                    timerSection = {
                        countdownPos = "left",
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 14.0,
                        posH = "right",
                        posV = "top",
                        xOffset = -5.0,
                        yOffset = -5.0,
                    },
                    timerText = {
                        font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                        fontSize = 32.0,
                        maxColor = {
                            [1] = 0.60000002384185791,
                            [2] = 0.60000002384185791,
                            [3] = 0.60000002384185791,
                            [4] = 1.0,
                        },
                        textColor = {
                            [1] = 0.98431378602981567,
                            [2] = 1.0,
                            [3] = 0.98431378602981567,
                            [4] = 1.0,
                        },
                        xOffset = 0.0,
                        yOffset = 0.0,
                    },
                },
                font = {
                    applySize = false,
                    font = "Interface\\AddOns\\!mMT_MediaPack\\media\\fonts\\Ubuntu-Medium.ttf",
                    fontSize = 14.0,
                },
                locked = true,
                point = "RIGHT",
                scale = 1.0,
                separators = {
                    [1] = {
                        after = "objectives",
                        color = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 0.5,
                        },
                        enabled = false,
                        height = 2.0,
                        width = 400.0,
                    },
                    [2] = {
                        after = "deaths",
                        color = {
                            [1] = 1.0,
                            [2] = 1.0,
                            [3] = 1.0,
                            [4] = 0.5,
                        },
                        enabled = false,
                        height = 2.0,
                        width = 400.0,
                    },
                },
                showBest = true,
                spacing = 5.0,
                style = {
                    barTexture = "Interface\\AddOns\\BigWigs\\Media\\Textures\\Smoothv2",
                    borderSize = 4.0,
                    fontFlags = "OUTLINE",
                    fontSize = 14.0,
                    sectionDividerColor = {
                        [1] = 1.0,
                        [2] = 1.0,
                        [3] = 1.0,
                        [4] = 0.64999997615814209,
                    },
                },
                theme = "default",
                title = {
                    show = true,
                    text = "",
                },
                width = 400.0,
                x = -30.00074577331543,
                y = 219.83354187011719,
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
