-- UI/OptionsApp.lua
-- The timer's settings window, built by the embedded BlinkiiOptions lib. This
-- file only supplies what is the timer's own: the option tree, where things
-- are stored, the accent rules and how the sidebar is arranged.

local _, ns = ...
local ADDON_NAME = ns.ADDON_NAME
local Addon = ns.Addon
local BlinkiiOptions = BlinkiiOptions

local OT = BlinkiiOptions.OT
local Tree = BlinkiiOptions.Tree

-- Sidebar dots. A module keeps its colour whatever the accent is, so the list
-- stays readable at a glance; anything not listed falls back to the muted grey.
local MODULE_COLOR = {
    Dungeon     = { 0.353, 0.722, 0.941 },
    Timer       = { 0.941, 0.706, 0.161 },
    EnemyForces = { 0.878, 0.341, 0.290 },
    Objectives  = { 0.310, 0.820, 0.773 },
    Splits      = { 0.949, 0.482, 0.627 },
    Checkpoints = { 0.561, 0.820, 0.310 },
    Deaths      = { 0.518, 0.580, 0.659 },
    Cooldowns   = { 0.710, 0.494, 0.863 },
    Sound       = { 0.941, 0.565, 0.310 },
    Automation  = { 0.839, 0.827, 0.310 },
}

-- Display pages, modules, system pages. Anything new lands under Display unless
-- it is a module or named here, so the list cannot silently lose a page.
local SYSTEM_KEYS = { profiles = true, changelog = true, about = true }

local function windowSettings()
    local db = Addon.db
    local profile = db and db.profile
    return profile and profile.ui
end

-- A page is keyed by the module's optionsKey ("enemyForces"), the module by its
-- name ("EnemyForces"). Built once; modules register long before a window opens.
local moduleByKey

local function moduleFor(key)
    if not moduleByKey then
        moduleByKey = {}
        for _, module in Addon:IterateModules() do
            if module.optionsKey then moduleByKey[module.optionsKey] = module end
        end
    end
    return moduleByKey[key]
end

-- A page with no module behind it counts as on, so the ratio never reads as broken.
local function enabledCount(children)
    local on = 0
    for i = 1, #children do
        local module = moduleFor(children[i].key)
        if not module or module:IsEnabled() then on = on + 1 end
    end
    return format("%d / %d", on, #children)
end

local function sections(window)
    local root = window:RootContext()
    local display, system, modules = {}, {}, nil

    for _, entry in ipairs(Tree.SortedArgs(window.options, Tree.IsPage, root)) do
        if entry.key == "modules" then
            modules = entry
        elseif SYSTEM_KEYS[entry.key] then
            system[#system + 1] = entry
        else
            display[#display + 1] = entry
        end
    end

    local list = { { title = ns.L["Display"], entries = display } }
    if modules then
        local children = Tree.SortedArgs(modules.node, Tree.IsPage,
            Tree.ChildContext(root, modules.key, modules.node))
        for _, child in ipairs(children) do
            local module = moduleFor(child.key)
            child.dot = {
                on = not module or module:IsEnabled(),
                color = MODULE_COLOR[module and module:GetName() or child.key],
            }
        end
        list[#list + 1] = {
            title = ns.L["Modules"], entries = children,
            parentKey = modules.key, count = enabledCount(children),
        }
    end
    list[#list + 1] = { title = ns.L["System"], entries = system }
    return list
end

local app = BlinkiiOptions:NewApp(ADDON_NAME, {
    title = "MAUI M+ Timer",
    logo = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\icon_small",
    frameName = "MauiMPlusTimerOptions",
    mediaPath = "Interface\\AddOns\\MauiMPlusTimer_Options\\Libs\\BlinkiiOptions\\Assets\\",
    defaultPath = { "general" },
    version = function() return Addon.version end,
    options = function() return Addon:BuildOptions() end,
    resolvePath = function(key) return Addon._optionPath and Addon._optionPath[key] end,
    sections = sections,

    storage = function() return Addon.db.global.optionsWindow end,
    panelStorage = function(id)
        local global = Addon.db.global
        global.panels = global.panels or {}
        global.panels[id] = global.panels[id] or {}
        return global.panels[id]
    end,
    profile = function()
        local db = Addon.db
        return db and db.GetCurrentProfile and db:GetCurrentProfile() or nil
    end,
    warn = function(message) Addon:Warning("%s", message) end,

    -- The class colour unless the profile picks the default or a custom one;
    -- returning nothing lets the lib use the class colour.
    accent = function()
        local ui = windowSettings()
        local cfg = ui and ui.accent
        local mode = cfg and cfg.mode or "class"
        if mode == "custom" and cfg.color then
            return cfg.color[1], cfg.color[2], cfg.color[3]
        end
        if mode == "default" then
            local c = OT.color.accent
            return c[1], c[2], c[3]
        end
    end,
    windowAlpha = function()
        local ui = windowSettings()
        return ui and ui.window and ui.window.alpha
    end,
    font = function()
        local ui = windowSettings()
        return ui and ui.window and ui.window.font
    end,
    slug = function()
        local ui = windowSettings()
        return not (ui and ui.window and ui.window.slug == false)
    end,
    -- A run bar reads as good or bad in the colours the +/- times already use.
    progressColor = function(ahead)
        local Utils = Addon.Utils
        return Utils and Utils.GetDeltaColor and Utils.GetDeltaColor(ahead)
    end,
})

-- The names the rest of the addon already uses.
ns.OptionsApp = app
ns.OT = OT
ns.Controls = BlinkiiOptions.Controls
Addon.OptionsWindow = app.window
Addon.OptionControls = BlinkiiOptions.Controls
ns.Panel = {
    New = function(id, config) return app:NewPanel(id, config) end,
}
Addon.Panel = ns.Panel

-- The timer still drives its own option tables through AceConfig; a change
-- there that shows or hides options re-lays the open page out.
local registry = LibStub("AceConfigRegistry-3.0", true)
if registry then
    registry.RegisterCallback(app, "ConfigTableChange", function(_, appName)
        if appName == ADDON_NAME then app:NotifyChange() end
    end)
end
