-- UI/StyleOptions.lua
-- Reusable AceConfig builders for per-element styling, plus the global font,
-- colors and HUD panel pages.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local function fontList()
    local t = { [STANDARD_TEXT_FONT] = "Default" }
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then for name, path in pairs(LSM:HashTable("font")) do t[path] = name end end
    return t
end

-- The LSM30 preview dropdowns key on the LibSharedMedia name, not the path, so
-- these map name -> name.
local function textureList()
    local t = {}
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then for _, name in ipairs(LSM:List("statusbar")) do t[name] = name end end
    return t
end

local DEFAULT_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

local function borderList()
    local t = {}
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then for _, name in ipairs(LSM:List("border")) do t[name] = name end end
    return t
end

-- Maps a legacy raw path back to its registered name (without mutating the
-- saved value) so the dropdown shows the right selection.
local function mediaName(mtype, value, default)
    if not value or value == "" then return default end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        if LSM:IsValid(mtype, value) then return value end
        for name, path in pairs(LSM:HashTable(mtype)) do
            if path == value then return name end
        end
    end
    return default
end

local OUTLINES = { [""] = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick" }

local function element(key)
    local e = Addon.db.profile.ui.elements
    e[key] = e[key] or {}
    return e[key]
end

-- For get/disabled handlers: never creates the table, so merely opening the
-- options cannot write empty tables into SavedVariables. Never write to EMPTY.
local EMPTY = {}
local function elementRead(key)
    return Addon.db.profile.ui.elements[key] or EMPTY
end

-- Auto-creates the element table; option setters write through this reference.
function Addon:GetElementSetting(key)
    return element(key)
end

local function restyle(module)
    Addon.Widgets:InvalidateStyle()
    if module and module.UI and module.UI.Restyle then module.UI:Restyle() end
    -- Re-feed demo values so dynamic colors refresh at once.
    if module and module.SetDemo and Addon.Demo:IsActive() and module:IsEnabled() then
        module:SetDemo(true)
    end
    Addon.MainWindow:Layout()
end
Addon.StyleRestyle = restyle

-- Element override or resolved default.
local function eff(key, field)
    return Addon.Widgets.ResolveStyle(key)[field]
end

-- Full-width spacer that forces a line break between option controls.
function Addon:OptLine(order)
    return { type = "description", name = "", width = "full", order = order }
end

function Addon:BuildGlobalFontOptions()
    local L = ns.L
    -- Holds font/fontFlags/fontSize plus the applyFont/applyFlags/applySize
    -- flags that decide what the "Apply" button overwrites.
    local function fontCfg()
        Addon.db.profile.ui.font = Addon.db.profile.ui.font or {}
        return Addon.db.profile.ui.font
    end
    -- Staged, not applied: nothing changes until "Apply to all elements", so
    -- individually customized elements are never silently overwritten.
    local function fontSet(field)
        return function(_, v)
            fontCfg()[field] = v
        end
    end
    -- Effective staged value for the page controls: the staged global baseline,
    -- else the theme default. Read directly (not via the resolve cache) so the
    -- dropdowns always show the staged selection, even before Apply.
    local function staged(field)
        local v = fontCfg()[field]
        if v ~= nil then return v end
        return Addon:GetTheme()[field]
    end
    -- Whether a given "apply" checkbox is enabled. Each defaults to true (nil ->
    -- true) so a fresh profile keeps the original "apply everything" behaviour.
    local function applyEnabled(field)
        local v = fontCfg()[field]
        return v == nil or v == true
    end
    local function applyToggle(field)
        return function(_, v) fontCfg()[field] = v end
    end
    -- Overwrites explicitly instead of clearing to nil: AceDB backfills nil
    -- fields from the defaults on the next login, which silently restored the
    -- factory fonts after a /reload. Fields that are absent already follow the
    -- global baseline and stay untouched.
    local function applyToAll()
        local doFont, doFlags, doSize =
            applyEnabled("applyFont"), applyEnabled("applyFlags"), applyEnabled("applySize")
        local font, flags, size = staged("font"), staged("fontFlags"), staged("fontSize")
        for _, e in pairs(Addon.db.profile.ui.elements) do
            if doFont and e.font ~= nil then e.font = font end
            if doFlags and e.fontFlags ~= nil then e.fontFlags = flags end
            if doSize and e.fontSize ~= nil then e.fontSize = size end
        end
        Addon.MainWindow:Refresh()
    end
    local function nothingSelected()
        return not (applyEnabled("applyFont") or applyEnabled("applyFlags")
            or applyEnabled("applySize"))
    end
    return {
        type = "group",
        name = L["Global font"],
        order = 5,
        icon = "Interface\\ICONS\\INV_Misc_Book_09",
        args = {
            note = { type = "description", order = 0,
                name = L["Pick a font, then click Apply to overwrite the font of every element."] },
            font = {
                type = "group", inline = true, name = L["Fonts"], order = 1,
                args = {
                    font = { type = "select", name = L["Font"], order = 1, values = fontList,
                        get = function() return staged("font") end,
                        set = fontSet("font") },
                    fontFlags = { type = "select", name = L["Outline"], order = 2, values = OUTLINES,
                        get = function() return staged("fontFlags") or "" end,
                        set = fontSet("fontFlags") },
                    fontSize = { type = "range", name = L["Font size"], order = 3,
                        min = 8, max = 64, step = 1,
                        get = function() return staged("fontSize") end,
                        set = fontSet("fontSize") },
                },
            },
            applyWhat = {
                type = "group", inline = true, name = L["Apply to all elements"], order = 2,
                args = {
                    note = { type = "description", order = 0,
                        name = L["Choose which properties are overwritten on every element."] },
                    applyFont = { type = "toggle", name = L["Font"], order = 1,
                        get = function() return applyEnabled("applyFont") end,
                        set = applyToggle("applyFont") },
                    applyFlags = { type = "toggle", name = L["Outline"], order = 2,
                        get = function() return applyEnabled("applyFlags") end,
                        set = applyToggle("applyFlags") },
                    applySize = { type = "toggle", name = L["Font size"], order = 3,
                        get = function() return applyEnabled("applySize") end,
                        set = applyToggle("applySize") },
                },
            },
            apply = { type = "execute", name = L["Apply to all elements"], order = 3,
                disabled = nothingSelected,
                confirm = function()
                    return L["This overwrites the selected font properties of every element. Continue?"]
                end,
                func = applyToAll },
        },
    }
end

-- Bound to element[key][field]; refreshes every module so the change shows
-- across the whole HUD at once.
local function areaColor(key, field, name, order, default)
    return {
        type = "color", name = name, order = order, hasAlpha = true,
        get = function()
            local c = Addon.Widgets.ResolveStyle(key)[field] or default or { 1, 1, 1, 1 }
            return c[1], c[2], c[3], c[4] or 1
        end,
        set = function(_, r, g, b, a)
            element(key)[field] = { r, g, b, a }
            Addon.MainWindow:Refresh()
        end,
    }
end

-- timerBar.sectionColors[level]; writing one level preserves the others.
local function sectionAreaColor(level, name, order)
    return {
        type = "color", name = name, order = order, hasAlpha = true,
        get = function()
            local sc = Addon.Widgets.ResolveStyle(ns.E.timerBar).sectionColors or {}
            local c = sc[level] or { 1, 1, 1, 1 }
            return c[1], c[2], c[3], c[4] or 1
        end,
        set = function(_, r, g, b, a)
            local e = element(ns.E.timerBar)
            local cur = Addon.Widgets.ResolveStyle(ns.E.timerBar).sectionColors or {}
            e.sectionColors = e.sectionColors or {}
            for k, v in pairs(cur) do
                if e.sectionColors[k] == nil then e.sectionColors[k] = v end
            end
            e.sectionColors[level] = { r, g, b, a }
            Addon.MainWindow:Refresh()
        end,
    }
end

-- Mirrors the controls on the module pages; both write the same settings.
function Addon:BuildColorsOptions()
    local L = ns.L
    return {
        type = "group",
        name = L["Colors"],
        order = 6,
        icon = "Interface\\ICONS\\INV_Misc_Gem_Variety_01",
        args = {
            note = { type = "description", order = 0, name = L["All element colors, grouped by area."] },
            deltas = {
                type = "group", inline = true, name = L["Comparison (+/-)"], order = 4,
                args = {
                    ahead = { type = "color", name = L["Ahead of best"], order = 1, hasAlpha = true,
                        get = function() local c = Addon.Widgets:GetDeltaColor(true); return c[1], c[2], c[3], c[4] or 1 end,
                        set = function(_, r, g, b, a) element(ns.E.deltas).ahead = { r, g, b, a }; Addon.MainWindow:Refresh() end },
                    behind = { type = "color", name = L["Behind best"], order = 2, hasAlpha = true,
                        get = function() local c = Addon.Widgets:GetDeltaColor(false); return c[1], c[2], c[3], c[4] or 1 end,
                        set = function(_, r, g, b, a) element(ns.E.deltas).behind = { r, g, b, a }; Addon.MainWindow:Refresh() end },
                    best = { type = "color", name = L["Best time"], order = 3, hasAlpha = true,
                        get = function() local c = Addon.Widgets:GetBestColor(); return c[1], c[2], c[3], c[4] or 1 end,
                        set = function(_, r, g, b, a) element(ns.E.best).color = { r, g, b, a }; Addon.MainWindow:Refresh() end },
                },
            },
            dungeon = {
                type = "group", inline = true, name = L["Dungeon"], order = 5,
                args = {
                    name = areaColor(ns.E.dungeonName, "textColor", L["Dungeon name"], 1),
                    affixes = areaColor(ns.E.dungeonAffixes, "textColor", L["Affixes"], 2),
                },
            },
            timer = {
                type = "group", inline = true, name = L["Timer"], order = 10,
                args = {
                    general = {
                        type = "group", inline = true, name = L["General"], order = 1,
                        args = {
                            overtime = sectionAreaColor(0, L["Over time"], 1),
                        },
                    },
                    text = {
                        type = "group", inline = true, name = L["Text"], order = 2,
                        args = {
                            timeText = areaColor(ns.E.timerText, "textColor", L["Time text"], 1),
                            max = areaColor(ns.E.timerText, "maxColor", L["Max time color"], 2, { 0.6, 0.6, 0.6, 1 }),
                            countdown = areaColor(ns.E.timerSection, "textColor", L["Countdown label"], 3),
                        },
                    },
                    bar = {
                        type = "group", inline = true, name = L["Bar"], order = 3,
                        args = {
                            c3 = sectionAreaColor(3, "+3", 1),
                            c2 = sectionAreaColor(2, "+2", 2),
                            c1 = sectionAreaColor(1, "+1", 3),
                            divider = areaColor(ns.E.timerBar, "sectionDividerColor", L["Divider color"], 4),
                            barBg = areaColor(ns.E.timerBar, "bgColor", L["Bar background color"], 5),
                            border = areaColor(ns.E.timerBar, "borderColor", L["Border color"], 6),
                        },
                    },
                },
            },
            -- Enemy Forces split into Text and Bar groups.
            forces = {
                type = "group", inline = true, name = L["Enemy Forces"], order = 20,
                args = {
                    text = {
                        type = "group", inline = true, name = L["Text"], order = 1,
                        args = {
                            text = areaColor(ns.E.forcesText, "textColor", L["Text"], 1),
                            count = areaColor(ns.E.forcesText, "countColor", L["Remaining count color"], 2, { 0.6, 0.6, 0.6, 1 }),
                            segment = areaColor(ns.E.forcesSegment, "textColor", L["Segment percentage"], 3),
                        },
                    },
                    bar = {
                        type = "group", inline = true, name = L["Bar"], order = 2,
                        args = {
                            bar = areaColor(ns.E.forcesBar, "barColor", L["Bar color"], 1),
                            marker = areaColor(ns.E.forcesBar, "markerColor", L["Marker color"], 2),
                            barBg = areaColor(ns.E.forcesBar, "bgColor", L["Bar background color"], 3),
                            border = areaColor(ns.E.forcesBar, "borderColor", L["Border color"], 4),
                        },
                    },
                },
            },
            objectives = {
                type = "group", inline = true, name = L["Objectives"], order = 30,
                args = {
                    done = areaColor(ns.E.objectiveText, "doneColor", L["Defeated boss name"], 1, { 0.20, 1.00, 0.60, 1 }),
                    open = areaColor(ns.E.objectiveText, "openColor", L["Pending boss name"], 2, { 1, 1, 1, 1 }),
                    time = areaColor(ns.E.objectiveText, "timeColor", L["Split time"], 3, { 0.80, 0.80, 0.80, 1 }),
                },
            },
            deaths = {
                type = "group", inline = true, name = L["Deaths"], order = 40,
                args = {
                    text = areaColor(ns.E.deathsText, "textColor", L["Text"], 1),
                    penalty = areaColor(ns.E.deathsText, "penaltyColor", L["Time penalty color"], 2, { 1, 0.38, 0.38, 1 }),
                },
            },
            splits = {
                type = "group", inline = true, name = L["Splits"], order = 50,
                args = { text = areaColor(ns.E.splitsText, "textColor", L["Text"], 1) },
            },
            checkpoints = {
                type = "group", inline = true, name = L["Checkpoints"], order = 60,
                args = { text = areaColor(ns.E.checkpointsText, "textColor", L["Text"], 1) },
            },
            cooldowns = {
                type = "group", inline = true, name = L["Cooldowns"], order = 70,
                args = {
                    text = areaColor(ns.E.cooldownsText, "textColor", L["Text"], 1),
                    cd = areaColor(ns.E.cooldownsText, "cdColor", L["Cooldown color"], 2, { 1, 0.38, 0.38, 1 }),
                    recharge = areaColor(ns.E.cooldownsText, "rechargeColor", L["Recharge color"], 3, { 0.60, 0.60, 0.60, 1 }),
                },
            },
        },
    }
end

-- Injects a Background and a Border group into an existing args table; the
-- border depends on the background. `bg` returns the settings table.
function Addon:AddBackgroundGroups(args, bg, apply, order)
    local L = ns.L
    args.bgGroup = {
        type = "group", inline = true, name = L["Background"], order = order,
        args = {
            show = { type = "toggle", name = L["Show background"], order = 1,
                get = function() return bg().show == true end,
                set = function(_, v) bg().show = v; apply() end },
            nl = Addon:OptLine(2),
            color = { type = "color", name = L["Background color"], order = 3, hasAlpha = true,
                disabled = function() return not bg().show end,
                get = function() local c = bg().color or { 0, 0, 0, 0.6 }; return c[1], c[2], c[3], c[4] or 1 end,
                set = function(_, r, g, b, a) bg().color = { r, g, b, a }; apply() end },
        },
    }
    args.borderGroup = {
        type = "group", inline = true, name = L["Border"], order = order + 1,
        disabled = function() return not bg().show end,
        args = {
            show = { type = "toggle", name = L["Show border"], order = 1,
                get = function() return bg().border == true end,
                set = function(_, v) bg().border = v; apply() end },
            nl = Addon:OptLine(2),
            texture = { type = "select", name = L["Border texture"], order = 3, values = borderList, dialogControl = "LSM30_Border",
                disabled = function() return not (bg().show and bg().border) end,
                get = function() return mediaName("border", bg().borderTexture, "Blizzard Tooltip") end,
                set = function(_, v) bg().borderTexture = v; apply() end },
            size = { type = "range", name = L["Border size"], order = 4, min = 1, max = 32, step = 1,
                disabled = function() return not (bg().show and bg().border) end,
                get = function() return bg().borderSize or 12 end,
                set = function(_, v) bg().borderSize = v; apply() end },
            color = { type = "color", name = L["Border color"], order = 5, hasAlpha = true,
                disabled = function() return not (bg().show and bg().border) end,
                get = function() local c = bg().borderColor or { 0, 0, 0, 1 }; return c[1], c[2], c[3], c[4] or 1 end,
                set = function(_, r, g, b, a) bg().borderColor = { r, g, b, a }; apply() end },
        },
    }
end

function Addon:BuildWindowOptions()
    local L = ns.L
    local function bg()
        Addon.db.profile.ui.bg = Addon.db.profile.ui.bg or {}
        return Addon.db.profile.ui.bg
    end
    local function apply()
        Addon.MainWindow:ApplyPanel()
        Addon.MainWindow:Layout()
    end
    local page = {
        type = "group", name = L["HUD panel"], order = 4,
        icon = "Interface\\ICONS\\INV_Misc_Spyglass_02", args = {},
    }
    Addon:AddBackgroundGroups(page.args, bg, apply, 1)

    local function sepCfg(i)
        local ui = Addon.db.profile.ui
        ui.separators = ui.separators or {}
        ui.separators[i] = ui.separators[i] or {}
        return ui.separators[i]
    end
    -- Toggling a separator changes which entries the row layout has to place.
    local function sepApply()
        Addon.MainWindow:InvalidateRows()
        Addon.MainWindow:Layout()
    end
    local function separatorGroup(i, order)
        local function off() return sepCfg(i).enabled ~= true end
        return {
            type = "group", inline = true, name = L["Separator line"] .. " " .. i, order = order,
            args = {
                enabled = {
                    type = "toggle", name = L["Enable"], order = 1,
                    get = function() return sepCfg(i).enabled == true end,
                    set = function(_, v) sepCfg(i).enabled = v; sepApply() end,
                },
                width = {
                    type = "range", name = L["Width"], order = 3, min = 10, max = 600, step = 2,
                    disabled = off,
                    get = function() return sepCfg(i).width or 180 end,
                    set = function(_, v) sepCfg(i).width = v; sepApply() end,
                },
                height = {
                    type = "range", name = L["Height"], order = 4, min = 1, max = 20, step = 1,
                    disabled = off,
                    get = function() return sepCfg(i).height or 2 end,
                    set = function(_, v) sepCfg(i).height = v; sepApply() end,
                },
                color = {
                    type = "color", name = L["Color"], order = 5, hasAlpha = true,
                    disabled = off,
                    get = function()
                        local c = sepCfg(i).color or { 1, 1, 1, 0.5 }
                        return c[1], c[2], c[3], c[4] or 1
                    end,
                    set = function(_, r, g, b, a) sepCfg(i).color = { r, g, b, a }; sepApply() end,
                },
            },
        }
    end
    page.args.separators = {
        type = "group", inline = true, name = L["Separator lines"], order = 10,
        args = { sep1 = separatorGroup(1, 1), sep2 = separatorGroup(2, 2) },
    }
    return page
end

-- Flat args, so the same controls can be a group of their own or merged into a
-- larger one. Occupies orders base+1 .. base+13.
function Addon:ElementTextArgs(module, key, base, opts)
    base = base or 0
    opts = opts or {}
    local L = ns.L
    local args = {
        font = { type = "select", name = L["Font"], order = base + 1, values = fontList,
            get = function() return eff(key, "font") end,
            set = function(_, v) element(key).font = v; restyle(module) end },
        fontFlags = { type = "select", name = L["Outline"], order = base + 2, values = OUTLINES,
            get = function() return eff(key, "fontFlags") or "" end,
            set = function(_, v) element(key).fontFlags = v; restyle(module) end },
        nlSize = Addon:OptLine(base + 3),
        fontSize = { type = "range", name = L["Font size"], order = base + 4, min = 8, max = 64, step = 1,
            get = function() return eff(key, "fontSize") end,
            set = function(_, v) element(key).fontSize = v; restyle(module) end },
        nlOffset = Addon:OptLine(base + 9),
        xOffset = { type = "range", name = L["X offset"], order = base + 10, min = -150, max = 150, step = 1,
            get = function() return elementRead(key).xOffset or 0 end,
            set = function(_, v) element(key).xOffset = v; restyle(module) end },
        yOffset = { type = "range", name = L["Y offset"], order = base + 11, min = -150, max = 150, step = 1,
            get = function() return elementRead(key).yOffset or 0 end,
            set = function(_, v) element(key).yOffset = v; restyle(module) end },
        nlColor = Addon:OptLine(base + 12),
    }
    if opts.color then
        args.textColor = { type = "color", name = L["Text color"], order = base + 13, hasAlpha = true,
            get = function() local c = eff(key, "textColor") or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1 end,
            set = function(_, r, g, b, a) element(key).textColor = { r, g, b, a }; restyle(module) end }
    end
    return args
end

-- ElementTextArgs in its own inline group. Modules may inject extra size
-- controls at orders 5..8 and extra colors at 14..19.
function Addon:ElementTextOptions(module, key, order, opts)
    opts = opts or {}
    return {
        type = "group", inline = true, name = opts.name or ns.L["Text"], order = order,
        args = Addon:ElementTextArgs(module, key, 0, opts),
    }
end

-- opts.noColor omits the bar color, for the Timer, whose fill is colored per
-- section. The bar background color lives on the Colors page.
function Addon:ElementBarOptions(module, key, order, opts)
    local L = ns.L
    opts = opts or {}
    local args = {
        texture = { type = "select", name = L["Bar texture"], order = 1, values = textureList, dialogControl = "LSM30_Statusbar",
            get = function() return mediaName("statusbar", eff(key, "barTexture"), "Blizzard") end,
            set = function(_, v) element(key).barTexture = v; restyle(module) end },
        fillDirection = { type = "select", name = L["Fill direction"], order = 2,
            values = { ltr = L["Left to right"], rtl = L["Right to left"] },
            sorting = { "ltr", "rtl" },
            get = function() return elementRead(key).reverse and "rtl" or "ltr" end,
            set = function(_, v) element(key).reverse = (v == "rtl"); restyle(module) end },
        nlSize = Addon:OptLine(3),
        width = { type = "range", name = L["Bar width"], order = 4, min = 0, max = 600, step = 5,
            desc = L["0 = use the display width."],
            get = function() return elementRead(key).width or 0 end,
            set = function(_, v) element(key).width = (v > 0 and v or nil); restyle(module) end },
        height = { type = "range", name = L["Bar height"], order = 5, min = 4, max = 48, step = 1,
            get = function() return elementRead(key).height or 14 end,
            set = function(_, v) element(key).height = v; restyle(module) end },
        nlColor = Addon:OptLine(6),
        edge = {
            type = "group", inline = true, name = L["Edge line"], order = 15,
            args = {
                enabled = { type = "toggle", name = L["Show edge line"], order = 1,
                    desc = L["Draw a line at the moving edge of the fill."],
                    get = function() return elementRead(key).edgeOn == true end,
                    set = function(_, v) element(key).edgeOn = v; restyle(module) end },
                nl = Addon:OptLine(2),
                width = { type = "range", name = L["Edge line width"], order = 3, min = 1, max = 12, step = 1,
                    disabled = function() return not elementRead(key).edgeOn end,
                    get = function() return elementRead(key).edgeWidth or 2 end,
                    set = function(_, v) element(key).edgeWidth = v; restyle(module) end },
                height = { type = "range", name = L["Edge line height"], order = 4, min = 0, max = 64, step = 1,
                    desc = L["0 = use the bar height."],
                    disabled = function() return not elementRead(key).edgeOn end,
                    get = function() return elementRead(key).edgeHeight or 0 end,
                    set = function(_, v) element(key).edgeHeight = (v > 0 and v or nil); restyle(module) end },
                color = { type = "color", name = L["Edge line color"], order = 5, hasAlpha = true,
                    disabled = function() return not elementRead(key).edgeOn end,
                    get = function() local c = eff(key, "edgeColor") or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1 end,
                    set = function(_, r, g, b, a) element(key).edgeColor = { r, g, b, a }; restyle(module) end },
            },
        },
        gradient = {
            type = "group", inline = true, name = L["Gradient"], order = 16,
            args = {
                enabled = { type = "toggle", name = L["Show gradient"], order = 1,
                    desc = L["Fade the fill from the bar color to a scaled version of it."],
                    get = function() return elementRead(key).gradientOn == true end,
                    set = function(_, v) element(key).gradientOn = v; restyle(module) end },
                swap = { type = "toggle", name = L["Swap colors"], order = 2,
                    desc = L["Run the fade from the end color back to the bar color."],
                    disabled = function() return not elementRead(key).gradientOn end,
                    get = function() return elementRead(key).gradientSwap == true end,
                    set = function(_, v) element(key).gradientSwap = v; restyle(module) end },
                nl = Addon:OptLine(3),
                mult = { type = "range", name = L["Color multiplier"], order = 4,
                    min = 0.1, max = 2, step = 0.05, isPercent = false,
                    desc = L["Below 1 darkens the second color, above 1 brightens it."],
                    disabled = function()
                        local e = elementRead(key)
                        return not e.gradientOn or e.gradientCustom == true
                    end,
                    get = function() return elementRead(key).gradientMult or 0.5 end,
                    set = function(_, v) element(key).gradientMult = v; restyle(module) end },
                nlCustom = Addon:OptLine(5),
                custom = { type = "toggle", name = L["Custom end color"], order = 6,
                    desc = L["Use a fixed end color instead of the multiplied bar color."],
                    disabled = function() return not elementRead(key).gradientOn end,
                    get = function() return elementRead(key).gradientCustom == true end,
                    set = function(_, v) element(key).gradientCustom = v; restyle(module) end },
                color = { type = "color", name = L["End color"], order = 7, hasAlpha = true,
                    disabled = function()
                        local e = elementRead(key)
                        return not (e.gradientOn and e.gradientCustom)
                    end,
                    get = function()
                        local c = elementRead(key).gradientColor or { 1, 1, 1, 1 }
                        return c[1], c[2], c[3], c[4] or 1
                    end,
                    set = function(_, r, g, b, a) element(key).gradientColor = { r, g, b, a }; restyle(module) end },
            },
        },
        border = {
            type = "group", inline = true, name = L["Border"], order = 20,
            args = {
                enabled = { type = "toggle", name = L["Show border"], order = 1,
                    get = function()
                        local e = elementRead(key)
                        if e.borderOn ~= nil then return e.borderOn end
                        return (e.borderSize or 0) > 0
                    end,
                    set = function(_, v) element(key).borderOn = v; restyle(module) end },
                nl = Addon:OptLine(2),
                texture = { type = "select", name = L["Border texture"], order = 3, values = borderList, dialogControl = "LSM30_Border",
                    disabled = function() return not elementRead(key).borderOn end,
                    get = function() return mediaName("border", eff(key, "borderTexture"), "Blizzard Tooltip") end,
                    set = function(_, v) element(key).borderTexture = v; restyle(module) end },
                size = { type = "range", name = L["Border size"], order = 4, min = 1, max = 16, step = 1,
                    disabled = function() return not elementRead(key).borderOn end,
                    get = function() return elementRead(key).borderSize or 12 end,
                    set = function(_, v) element(key).borderSize = v; restyle(module) end },
                offset = { type = "range", name = L["Border offset"], order = 5, min = -8, max = 16, step = 1,
                    disabled = function() return not elementRead(key).borderOn end,
                    get = function() return elementRead(key).borderOffset or 0 end,
                    set = function(_, v) element(key).borderOffset = v; restyle(module) end },
                color = { type = "color", name = L["Border color"], order = 6, hasAlpha = true,
                    disabled = function() return not elementRead(key).borderOn end,
                    get = function() local c = eff(key, "borderColor") or { 0, 0, 0, 1 }; return c[1], c[2], c[3], c[4] or 1 end,
                    set = function(_, r, g, b, a) element(key).borderColor = { r, g, b, a }; restyle(module) end },
            },
        },
    }
    if not opts.noColor then
        args.color = { type = "color", name = L["Bar color"], order = 11, hasAlpha = true,
            get = function() local c = eff(key, "barColor") or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1 end,
            set = function(_, r, g, b, a) element(key).barColor = { r, g, b, a }; restyle(module) end }
    end
    return {
        type = "group", inline = true, name = opts.name or L["Bar"], order = order, args = args,
    }
end

-- `default` is shown when neither an override nor a theme value exists, so the
-- picker matches what the module renders.
function Addon:ElementColorOption(module, key, field, name, order, default)
    return {
        type = "color", name = name, order = order, hasAlpha = true,
        get = function()
            local c = Addon.Widgets.ResolveStyle(key)[field] or default or { 1, 1, 1, 1 }
            return c[1], c[2], c[3], c[4] or 1
        end,
        set = function(_, r, g, b, a)
            element(key)[field] = { r, g, b, a }
            restyle(module)
        end,
    }
end

-- Icon picker over an ns.Icons category; stores the texture path in
-- module settings under `field`, falling back to the category default.
function Addon:IconSelectOption(module, category, field, name, order, opts)
    opts = opts or {}
    return {
        type = "select", name = name, order = order, width = opts.width or "double",
        desc = opts.desc, disabled = opts.disabled,
        values = function() return (ns.Icons:BuildSelect(category)) end,
        sorting = function() local _, s = ns.Icons:BuildSelect(category); return s end,
        get = function() return module:GetSettings()[field] or ns.Icons:Default(category) end,
        set = function(_, v) module:GetSettings()[field] = v; restyle(module) end,
    }
end

-- Tint for a module's inline icon, stored as {r,g,b}. No alpha: the inline
-- texture vertex color is RGB only.
function Addon:IconColorOption(module, field, name, order, opts)
    opts = opts or {}
    return {
        type = "color", name = name, order = order, hasAlpha = false,
        desc = opts.desc, disabled = opts.disabled,
        get = function()
            local c = module:GetSettings()[field] or { 1, 1, 1 }
            return c[1], c[2], c[3]
        end,
        set = function(_, r, g, b)
            module:GetSettings()[field] = { r, g, b }
            restyle(module)
        end,
    }
end
