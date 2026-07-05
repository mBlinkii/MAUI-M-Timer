-- Modules/Objectives/Options.lua
-- AceConfig options group for the Objectives module.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Objectives = Addon:GetModule("Objectives")

function Objectives:GetOptions()
    local L = ns.L

    -- Text styling. The single text color is replaced by the three boss-state
    -- colors (pending name, defeated name, split time), shown on the last row.
    local textOpts = Addon:ElementTextOptions(self, ns.E.objectiveText, 20, { name = L["Text"] })
    textOpts.args.openColor = Addon:ElementColorOption(self, ns.E.objectiveText, "openColor", L["Pending boss name"], 13, { 1, 1, 1, 1 })
    textOpts.args.doneColor = Addon:ElementColorOption(self, ns.E.objectiveText, "doneColor", L["Defeated boss name"], 14, { 0.20, 1.00, 0.60, 1 })
    textOpts.args.timeColor = Addon:ElementColorOption(self, ns.E.objectiveText, "timeColor", L["Split time"], 15, { 0.80, 0.80, 0.80, 1 })

    local function pendingOff() return Objectives:GetSettings().showPendingIcon == false end
    local function doneOff() return Objectives:GetSettings().showDoneIcon == false end

    return {
        type = "group",
        name = L["Objectives"],
        order = 30,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\objectives",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            settings = {
                type = "group", inline = true, name = L["Settings"], order = 2,
                args = {
                    align = Addon:ModuleAlignOption(self, 1),
                    rowSpacing = {
                        type = "range", name = L["Row spacing"], order = 2, min = 0, max = 30, step = 1,
                        desc = L["Extra vertical space between objective rows."],
                        get = function() return Objectives:GetSettings().rowSpacing or 0 end,
                        set = function(_, v) Objectives:GetSettings().rowSpacing = v; Addon.StyleRestyle(Objectives) end,
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
