-- Modules/Objectives/Options.lua
-- AceConfig options group for the Objectives module.

local _, ns = ...
local Addon = ns.Addon
local Objectives = Addon:GetModule("Objectives")

function Objectives:GetOptions()
    local L = ns.L

    -- Text styling. The single text color is replaced by the three boss-state
    -- colors (pending name, defeated name, split time), shown on the last row.
    local textOpts = Addon:ElementTextOptions(self, ns.E.objectiveText, 20, { name = L["Text"], icon = true })
    textOpts.args.openColor = Addon:ElementColorOption(self, ns.E.objectiveText, "openColor", L["Pending boss name"], 13, { 1, 1, 1, 1 })
    textOpts.args.doneColor = Addon:ElementColorOption(self, ns.E.objectiveText, "doneColor", L["Defeated boss name"], 14, { 0.20, 1.00, 0.60, 1 })
    textOpts.args.timeColor = Addon:ElementColorOption(self, ns.E.objectiveText, "timeColor", L["Split time"], 15, { 0.80, 0.80, 0.80, 1 })

    local function pendingOff() return Objectives:GetSettings().showPendingIcon == false end
    local function doneOff() return Objectives:GetSettings().showDoneIcon == false end
    local function iconsOff() return (Objectives:GetSettings().layout or "text") == "text" end
    local function shapesOff()
        local style = Objectives:GetSettings().iconStyle or "portrait"
        return iconsOff() or style == "portrait" or style == "status"
    end

    return {
        type = "group",
        name = L["Objectives"],
        order = 30,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\objectives",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            layout = {
                type = "group", inline = true, name = L["Layout"], order = 1.5,
                args = {
                    layout = {
                        type = "select", name = L["Layout"], order = 1,
                        desc = L["The text list takes a whole row; the icon layouts show one icon per boss and fit a single column."],
                        values = {
                            text = L["Text list"], row = L["Icons side by side"],
                            column = L["Icons stacked"], grid = L["Icon grid"],
                        },
                        sorting = { "text", "row", "column", "grid" },
                        get = function() return Objectives:GetSettings().layout or "text" end,
                        set = function(_, v)
                            Objectives:GetSettings().layout = v
                            -- Text needs a whole row again, icons free it up.
                            Addon.MainWindow:InvalidateRows()
                            Addon.StyleRestyle(Objectives)
                            Addon.MainWindow:Refresh()
                        end,
                    },
                    perRow = {
                        type = "range", name = L["Icons per row"], order = 2, min = 2, max = 8, step = 1,
                        disabled = function() return Objectives:GetSettings().layout ~= "grid" end,
                        get = function() return Objectives:GetSettings().perRow or 3 end,
                        set = function(_, v) Objectives:GetSettings().perRow = v; Addon.StyleRestyle(Objectives) end,
                    },
                    nl = Addon:OptLine(3),
                    iconStyle = {
                        type = "select", name = L["Icon style"], order = 4,
                        desc = L["Boss portraits come from the Dungeon Journal and grey out until the boss is defeated; the demo mode shows your own portrait, outside a dungeon the status icons are shown instead. The shapes show an outline per boss that fills once it is defeated."],
                        values = {
                            portrait = L["Boss portrait"], status = L["Status icon"],
                            circle = L["Circle"], square = L["Rounded square"],
                            octagon = L["Octagon"], diamond = L["Diamond"],
                        },
                        sorting = { "portrait", "status", "circle", "square", "octagon", "diamond" },
                        disabled = iconsOff,
                        get = function() return Objectives:GetSettings().iconStyle or "portrait" end,
                        set = function(_, v) Objectives:GetSettings().iconStyle = v; Addon.StyleRestyle(Objectives) end,
                    },
                    iconSize = {
                        type = "range", name = L["Icon size"], order = 5, min = 12, max = 64, step = 1,
                        disabled = iconsOff,
                        get = function() return Objectives:GetSettings().iconSize or 24 end,
                        set = function(_, v) Objectives:GetSettings().iconSize = v; Addon.StyleRestyle(Objectives) end,
                    },
                    iconShape = Addon:IconShapeOption(
                        function() return Objectives:GetSettings().iconMask end,
                        function(v) Objectives:GetSettings().iconMask = v; Addon.StyleRestyle(Objectives) end,
                        5.5, function() return iconsOff() or not shapesOff() end),
                    iconGap = {
                        type = "range", name = L["Icon spacing"], order = 6, min = 0, max = 20, step = 1,
                        disabled = iconsOff,
                        get = function() return Objectives:GetSettings().iconGap or 4 end,
                        set = function(_, v) Objectives:GetSettings().iconGap = v; Addon.StyleRestyle(Objectives) end,
                    },
                    nlShapes = Addon:OptLine(7),
                    shapePending = Addon:IconColorOption(self, "shapePendingColor", L["Pending color"], 8,
                        { disabled = shapesOff }),
                    shapeDone = Addon:IconColorOption(self, "shapeDoneColor", L["Defeated color"], 9,
                        { disabled = shapesOff }),
                },
            },
            settings = {
                type = "group", inline = true, name = L["Settings"], order = 2,
                args = {
                    rowSpacing = {
                        type = "range", name = L["Row spacing"], order = 2, min = 0, max = 30, step = 1,
                        desc = L["Extra vertical space between objective rows."],
                        get = function() return Objectives:GetSettings().rowSpacing or 0 end,
                        set = function(_, v) Objectives:GetSettings().rowSpacing = v; Addon.StyleRestyle(Objectives) end,
                    },
                    showForcesRow = {
                        type = "toggle", name = L["Show Enemy Forces row"], order = 2.5, width = "full",
                        desc = L["Add an Enemy Forces entry at the end of the list: live percentage while in progress, completion time once done."],
                        get = function() return Objectives:GetSettings().showForcesRow == true end,
                        set = function(_, v)
                            Objectives:GetSettings().showForcesRow = v
                            Addon.MainWindow:Refresh()
                        end,
                    },
                    nlShorten = Addon:OptLine(3),
                    -- Optional boss-name shortening (display only). The max-length
                    -- slider applies to the truncate mode.
                    nameShorten = {
                        type = "select", name = L["Shorten boss names"], order = 4,
                        desc = L["How boss names are shortened for display; internally the full name is always kept."],
                        values = {
                            off = L["Off"],
                            truncate = L["Truncate with ellipsis"],
                            firstword = L["First word only"],
                            abbrev = L["Abbreviate following words"],
                        },
                        sorting = { "off", "truncate", "firstword", "abbrev" },
                        get = function() return Objectives:GetSettings().nameShorten or "off" end,
                        set = function(_, v) Objectives:GetSettings().nameShorten = v; Addon.StyleRestyle(Objectives) end,
                    },
                    nameMaxLength = {
                        type = "range", name = L["Max characters"], order = 5, min = 4, max = 40, step = 1,
                        desc = L["Names longer than this are cut and end with an ellipsis."],
                        disabled = function() return (Objectives:GetSettings().nameShorten or "off") ~= "truncate" end,
                        get = function() return Objectives:GetSettings().nameMaxLength or 12 end,
                        set = function(_, v) Objectives:GetSettings().nameMaxLength = v; Addon.StyleRestyle(Objectives) end,
                    },
                },
            },
            symbols = {
                type = "group", inline = true, name = L["Symbols"], order = 10,
                args = {
                    showPending = {
                        type = "toggle", name = L["Show pending icon"], order = 1,
                        get = function() return Objectives:GetSettings().showPendingIcon ~= false end,
                        set = function(_, v) Objectives:GetSettings().showPendingIcon = v; Addon.StyleRestyle(Objectives) end,
                    },
                    showDone = {
                        type = "toggle", name = L["Show defeated icon"], order = 2,
                        get = function() return Objectives:GetSettings().showDoneIcon ~= false end,
                        set = function(_, v) Objectives:GetSettings().showDoneIcon = v; Addon.StyleRestyle(Objectives) end,
                    },
                    nlIcons = Addon:OptLine(3),
                    pendingIcon = Addon:IconSelectOption(self, "pending", "pendingIcon", L["Pending icon"], 4,
                        { width = "normal", disabled = pendingOff }),
                    doneIcon = Addon:IconSelectOption(self, "done", "doneIcon", L["Defeated icon"], 5,
                        { width = "normal", disabled = doneOff }),
                    nlColors = Addon:OptLine(6),
                    pendingIconColor = Addon:IconColorOption(self, "pendingIconColor", L["Pending icon color"], 7,
                        { disabled = pendingOff }),
                    doneIconColor = Addon:IconColorOption(self, "doneIconColor", L["Defeated icon color"], 8,
                        { disabled = doneOff }),
                },
            },
            text = textOpts,
        },
    }
end
