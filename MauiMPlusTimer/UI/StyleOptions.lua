-- UI/StyleOptions.lua
-- Reusable AceConfig option builders for per-element styling, plus the global
-- font page, colors page and HUD panel page. Per-element values are stored in
-- profile.ui.elements[key] and applied live; the global font baseline lives in
-- profile.ui.font. No data logic beyond reading/writing settings.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

-- Shared lists ---------------------------------------------------------------

local function fontList()
    local t = { [STANDARD_TEXT_FONT] = "Default" }
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then for name, path in pairs(LSM:HashTable("font")) do t[path] = name end end
    return t
end

-- Statusbar / border lists for the LSM30 preview dropdowns. These widgets key
-- their list and stored value on the LibSharedMedia *name* (not the path), so the
-- values table maps name -> name. Bundled media (UI/Media.lua) is registered with
-- LibSharedMedia, so it shows up here automatically.
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

-- Resolve a stored media value to its LibSharedMedia name. New values are stored
-- as names by the LSM30 dropdowns, but legacy/preset data stored raw texture
-- paths; this maps such a path back to its registered name (without mutating the
-- saved value) so the dropdown shows the right selection. Falls back to `default`
-- when the value is empty or cannot be resolved.
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

-- Helpers --------------------------------------------------------------------

local function element(key)
    local e = Addon.db.profile.ui.elements
    e[key] = e[key] or {}
    return e[key]
end

-- Read-only accessor for get/disabled handlers: never creates the element
-- table, so merely opening the options cannot write empty tables into the
-- SavedVariables. EMPTY must never be written to.
local EMPTY = {}
local function elementRead(key)
    return Addon.db.profile.ui.elements[key] or EMPTY
end

-- Public accessor for module-specific style fields. Auto-creates the element
-- table because option setters write through the returned reference.
function Addon:GetElementSetting(key)
    return element(key)
end

local function restyle(module)
    Addon.Widgets:InvalidateStyle() -- styles may have changed; drop the cache
    if module and module.UI and module.UI.Restyle then module.UI:Restyle() end
    -- In demo mode re-run the module's display so dynamic colors refresh at once.
    if module and module.SetDemo and Addon.Demo:IsActive() and module:IsEnabled() then
        module:SetDemo(true)
    end
    Addon.MainWindow:Layout()
end
Addon.StyleRestyle = restyle

-- Effective value (element override or resolved default).
local function eff(key, field)
    return Addon.Widgets.ResolveStyle(key)[field]
end

-- A full-width spacer used to force a line break between option controls, so the
-- layout matches the intended grouping regardless of each widget's own width.
-- @param order number the AceConfig order at which the break sits.
function Addon:OptLine(order)
    return { type = "description", name = "", width = "full", order = order }
end

-- Global font page -----------------------------------------------------------

function Addon:BuildGlobalFontOptions()
    local L = ns.L
    -- Settings table for the global font baseline. Besides the three font fields
    -- (font/fontFlags/fontSize) it also stores which of them the "Apply" button
    -- overwrites: applyFont / applyFlags / applySize.
    local function fontCfg()
        Addon.db.profile.ui.font = Addon.db.profile.ui.font or {}
        return Addon.db.profile.ui.font
    end
    -- Stage the selection into ui.font WITHOUT restyling. Nothing changes on
    -- screen until the user clicks "Apply to all elements"; this avoids silently
    -- overwriting elements that the user has individually customized.
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
    -- Force the selected global font properties onto every element, then
    -- restyle. The values are written EXPLICITLY over existing per-element
    -- values (never cleared to nil): AceDB backfills nil fields from the
    -- defaults on the next login, which silently restored the factory fonts
    -- after a /reload. Entries without the field already follow the global
    -- baseline and stay untouched. Which properties are written is controlled
    -- by the applyFont/applyFlags/applySize checkboxes. Destructive for the
    -- affected per-element settings, which is why it is gated behind an
    -- explicit button + confirmation popup.
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
    -- Disable the Apply button while no property is selected; nothing to apply.
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
            -- All three font controls live in one "Schrift" group; the destructive
            -- Apply button sits below it.
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
            -- Checkboxes selecting which font properties the Apply button writes
            -- onto every element. Each maps to one per-element override field.
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

-- Colors page ----------------------------------------------------------------

-- A color control bound to element[key][field], refreshing every module so a
-- change is visible across the whole HUD at once.
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

-- A section-color control (timerBar.sectionColors[level]); preserves the other
-- levels when writing one.
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

-- Aggregated colors page: every element color in one place, grouped by area.
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
            -- Timer is split into General (over-time color), Text and Bar groups.
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

-- Background + border groups --------------------------------------------------

-- Inject a "# Background" group (show + color) and a "# Border" group (show,
-- texture, size, color) into an existing args table. The border group depends on
-- the background being enabled. `bg` returns the settings table; `apply` refreshes
-- the affected display. Used by the HUD panel page and the Dungeon module page.
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

-- HUD panel page (whole-window background + border + optical separators).
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

    -- Optical separator lines between modules (rendered by
    -- MainWindow:UpdateSeparators; stored in profile.ui.separators).
    local function sepCfg(i)
        local ui = Addon.db.profile.ui
        ui.separators = ui.separators or {}
        ui.separators[i] = ui.separators[i] or {}
        return ui.separators[i]
    end
    local function sepApply() Addon.MainWindow:Layout() end
    -- Module block keys a separator can be anchored after (see the AddBlock calls
    -- in each module's UI). The separator sits between this module and the next.
    local positions = {
        dungeon = L["Dungeon"], timer = L["Timer"], forces = L["Enemy Forces"],
        objectives = L["Objectives"], deaths = L["Deaths"], splits = L["Splits"],
        checkpoints = L["Checkpoints"], cooldowns = L["Cooldowns"],
    }
    local positionSorting = {
        "dungeon", "timer", "forces", "objectives", "deaths", "splits", "checkpoints", "cooldowns",
    }
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
                after = {
                    type = "select", name = L["After element"], order = 2,
                    values = positions, sorting = positionSorting, disabled = off,
                    get = function() return sepCfg(i).after or "timer" end,
                    set = function(_, v) sepCfg(i).after = v; sepApply() end,
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

-- Per-element builders -------------------------------------------------------

-- Build the shared text-style controls (font, outline, size, x/y offset and an
-- optional text color) as a flat args table, with line breaks between rows, so
-- the same layout can be embedded either as its own group (ElementTextOptions)
-- or merged into a larger group (e.g. the Affixes group with its own toggle).
-- @param base number order offset; controls occupy base+1 .. base+13.
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

-- Font, size, outline, x/y offset (and optionally text color) for an element,
-- wrapped in its own inline group. Modules may inject extra size controls (after
-- fontSize, orders 5..8) or extra colors (after textColor, orders 14..19).
function Addon:ElementTextOptions(module, key, order, opts)
    opts = opts or {}
    return {
        type = "group", inline = true, name = opts.name or ns.L["Text"], order = order,
        args = Addon:ElementTextArgs(module, key, 0, opts),
    }
end

-- Bar (texture, fill direction, width, height, optional color) plus a nested
-- Border group, for an element. opts.noColor omits the single bar color (used by
-- the Timer, whose fill is colored per section instead). The bar background color
-- is configured on the Colors page, not here.
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

-- Reusable color option bound to a module-specific element field. `default` is
-- the fallback color shown when neither an override nor a theme value exists, so
-- the picker matches what the module renders by default.
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

-- Icon picker (dropdown) for a module setting. The selectable textures come from
-- the central catalog (ns.Icons) for the given category; the value stored is the
-- texture path. Unset falls back to the category default so the dropdown always
-- shows a selection. opts.disabled / opts.desc / opts.width are passed through.
-- @param module table the owning module (uses module:GetSettings())
-- @param category string ns.Icons category ("done"|"pending"|"death"|"ready")
-- @param field string settings key holding the chosen texture path
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

-- Color (tint) for a module's inline icon. Stored as {r,g,b} in module settings;
-- unset means no tint (the icon shows in its native colors). No alpha, since the
-- inline texture vertex color is RGB only.
-- @param module table the owning module (uses module:GetSettings())
-- @param field string settings key holding the {r,g,b} tint
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
