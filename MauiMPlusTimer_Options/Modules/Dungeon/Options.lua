-- Modules/Dungeon/Options.lua
-- AceConfig pages for the Dungeon blocks: name, icon, keystone level, affixes.

local _, ns = ...
local Addon = ns.Addon
local Dungeon = Addon:GetModule("Dungeon")

local ICON = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\dungeon"

local function head(blockKey)
    return { enabled = Addon:BlockEnableOption(blockKey, 1) }
end

function Dungeon:GetOptions()
    local L = ns.L
    local options = {
        type = "group",
        name = L["Dungeon name"],
        order = 5,
        icon = ICON,
        args = head("dungeon"),
    }
    options.args.short = {
        type = "group", inline = true, name = L["Dungeon name"], order = 10,
        args = {
            short = {
                type = "toggle", name = L["Abbreviate dungeon name"], order = 1, width = "full",
                desc = L["Shows the common short name, e.g. AA for Algeth'ar Academy; dungeons without one use their initials."],
                get = function() return Dungeon:GetSettings().nameShort == true end,
                set = function(_, v)
                    Dungeon:GetSettings().nameShort = v
                    if Dungeon.state.demo then Dungeon:SetDemo(true) else Dungeon:Refresh() end
                end,
            },
        },
    }
    options.args.name = Addon:ElementTextOptions(self, ns.E.dungeonName, 20, { color = true, name = L["Dungeon name"] })
    return options
end

function Dungeon:GetOptionPages()
    local L = ns.L

    local iconArgs = head("dungeonicon")
    iconArgs.icon = {
        type = "group", inline = true, name = L["Dungeon icon"], order = 10,
        args = {
            size = {
                type = "range", name = L["Icon size"], order = 1, min = 8, max = 64, step = 1,
                get = function() return Dungeon:GetSettings().iconSize or 20 end,
                set = function(_, v) Dungeon:GetSettings().iconSize = v; Addon.StyleRestyle(Dungeon) end,
            },
            shape = Addon:IconShapeOption(
                function() return Dungeon:GetSettings().iconMask end,
                function(v) Dungeon:GetSettings().iconMask = v; Addon.StyleRestyle(Dungeon) end, 2),
        },
    }

    local levelArgs = head("level")
    levelArgs.color = {
        type = "group", inline = true, name = L["Keystone level"], order = 10,
        args = {
            color = {
                type = "toggle", name = L["Color by level rarity"], order = 1,
                desc = L["Color the keystone level with Blizzard's rarity color."],
                get = function() return Dungeon:GetSettings().levelColor == true end,
                set = function(_, v) Dungeon:GetSettings().levelColor = v; Addon.StyleRestyle(Dungeon) end,
            },
        },
    }
    local function badgeOff() return (Dungeon:GetSettings().levelBg or "none") == "none" end
    levelArgs.badge = {
        type = "group", inline = true, name = L["Background"], order = 15,
        args = {
            shape = {
                type = "select", name = L["Shape"], order = 1,
                values = {
                    none = L["None"], square = L["Square"], rounded = L["Rounded"],
                    pill = L["Pill"], circle = L["Circle"],
                },
                sorting = { "none", "square", "rounded", "pill", "circle" },
                get = function() return Dungeon:GetSettings().levelBg or "none" end,
                set = function(_, v) Dungeon:GetSettings().levelBg = v; Addon.StyleRestyle(Dungeon) end,
            },
            radius = {
                type = "range", name = L["Corner rounding"], order = 2, min = 1, max = 16, step = 1,
                disabled = function() return Dungeon:GetSettings().levelBg ~= "rounded" end,
                get = function() return Dungeon:GetSettings().levelBgRadius or 4 end,
                set = function(_, v) Dungeon:GetSettings().levelBgRadius = v; Addon.StyleRestyle(Dungeon) end,
            },
            nl = Addon:OptLine(3),
            colorBy = {
                type = "select", name = L["Color source"], order = 4,
                desc = L["Rarity follows Blizzard's color for the keystone level, class uses your class color."],
                values = { rarity = L["Level rarity"], class = L["Class color"], fixed = L["Custom color"] },
                sorting = { "rarity", "class", "fixed" },
                disabled = badgeOff,
                get = function() return Dungeon:GetSettings().levelBgColorBy or "rarity" end,
                set = function(_, v) Dungeon:GetSettings().levelBgColorBy = v; Addon.StyleRestyle(Dungeon) end,
            },
            color = {
                type = "color", name = L["Background color"], order = 5, hasAlpha = true,
                desc = L["Also the opacity of the rarity and class color."],
                disabled = badgeOff,
                get = function()
                    local c = Dungeon:GetSettings().levelBgColor or { 1, 0.5, 0, 1 }
                    return c[1], c[2], c[3], c[4] or 1
                end,
                set = function(_, r, g, b, a)
                    Dungeon:GetSettings().levelBgColor = { r, g, b, a }
                    Addon.StyleRestyle(Dungeon)
                end,
            },
            nl2 = Addon:OptLine(6),
            padX = {
                type = "range", name = L["Horizontal padding"], order = 7, min = 0, max = 20, step = 1,
                disabled = badgeOff,
                get = function() return Dungeon:GetSettings().levelBgPadX or 6 end,
                set = function(_, v) Dungeon:GetSettings().levelBgPadX = v; Addon.StyleRestyle(Dungeon) end,
            },
            padY = {
                type = "range", name = L["Vertical padding"], order = 8, min = 0, max = 12, step = 1,
                disabled = badgeOff,
                get = function() return Dungeon:GetSettings().levelBgPadY or 2 end,
                set = function(_, v) Dungeon:GetSettings().levelBgPadY = v; Addon.StyleRestyle(Dungeon) end,
            },
        },
    }
    levelArgs.text = Addon:ElementTextOptions(self, ns.E.dungeonLevel, 20, { color = true })

    local affixArgs = head("affixes")
    local function affixIconsOff() return Dungeon:GetSettings().affixStyle ~= "icons" end
    affixArgs.display = {
        type = "group", inline = true, name = L["Display"], order = 10,
        args = {
            style = {
                type = "select", name = L["Display"], order = 1,
                values = { text = L["Text"], icons = L["Icons"] },
                sorting = { "text", "icons" },
                get = function() return Dungeon:GetSettings().affixStyle or "text" end,
                set = function(_, v) Dungeon:GetSettings().affixStyle = v; Addon.StyleRestyle(Dungeon) end,
            },
            shape = Addon:IconShapeOption(
                function() return Dungeon:GetSettings().affixIconMask end,
                function(v) Dungeon:GetSettings().affixIconMask = v; Addon.StyleRestyle(Dungeon) end,
                2, affixIconsOff),
            nl = Addon:OptLine(3),
            size = {
                type = "range", name = L["Icon size"], order = 4, min = 12, max = 48, step = 1,
                disabled = affixIconsOff,
                get = function() return Dungeon:GetSettings().affixIconSize or 20 end,
                set = function(_, v) Dungeon:GetSettings().affixIconSize = v; Addon.StyleRestyle(Dungeon) end,
            },
            gap = {
                type = "range", name = L["Icon spacing"], order = 5, min = 0, max = 12, step = 1,
                disabled = affixIconsOff,
                get = function() return Dungeon:GetSettings().affixIconGap or 4 end,
                set = function(_, v) Dungeon:GetSettings().affixIconGap = v; Addon.StyleRestyle(Dungeon) end,
            },
        },
    }
    affixArgs.text = Addon:ElementTextOptions(self, ns.E.dungeonAffixes, 20, { color = true })

    return {
        dungeonicon = { type = "group", name = L["Dungeon icon"], order = 6, icon = ICON, args = iconArgs },
        level = { type = "group", name = L["Keystone level"], order = 7, icon = ICON, args = levelArgs },
        affixes = { type = "group", name = L["Affixes"], order = 8, icon = ICON, args = affixArgs },
    }
end
