-- Core/Config.lua
-- Builds the AceConfig options tree, registers it with the Blizzard settings
-- panel, and maps the /mauimpt slash command to GUI deeplinks. No data logic.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

-- Custom top-level menu icons, bundled under Assets/Icons/Menu (extension-less so
-- WoW resolves the .tga). Generated to match the addon logo and tinted per colour
-- group. Module icons live in each module's own Options file.
local MENU_ICON_DIR = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Menu\\"
local ICON_GENERAL  = MENU_ICON_DIR .. "general"
local ICON_MODULES  = MENU_ICON_DIR .. "modules"
local ICON_PROFILES = MENU_ICON_DIR .. "profiles"

-- Logo texture (extension-less so WoW resolves the bundled .tga). icon_big is a
-- 512x512 master scaled down where it is displayed.
local LOGO_TEXTURE = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\icon_big"

-- Functional colour scheme for the top-level menu entries. Grouping the entries
-- by purpose (core appearance, modules, profiles, about) gives the tree a quick
-- visual hierarchy. Colours are WoW |c colour codes (AARRGGBB).
local MENU_COLORS = {
    core     = "ffffd100", -- gold  : core / appearance pages
    modules  = "ff40c057", -- green : module pages
    profiles = "ff4a9eff", -- blue  : profile management
    about    = "ffb0b0b0", -- grey  : informational / about
}

-- Single source of truth for the presentation of every top-level tree node:
-- display order, icon and the colour group above. Applied centrally in
-- BuildOptions so ordering, icons and colours stay consistent regardless of
-- which file registered the page.
local MENU_NODES = {
    general    = { order = 1,   group = "core",     icon = ICON_GENERAL },
    window     = { order = 2,   group = "core",     icon = MENU_ICON_DIR .. "window" },
    globalfont = { order = 3,   group = "core",     icon = MENU_ICON_DIR .. "fonts" },
    colors     = { order = 4,   group = "core",     icon = MENU_ICON_DIR .. "colors" },
    modules    = { order = 10,  group = "modules",  icon = ICON_MODULES },
    profiles   = { order = 90,  group = "profiles", icon = ICON_PROFILES },
    about      = { order = 100, group = "about",    icon = MENU_ICON_DIR .. "about" },
}

-- Wrap a node name in a colour code. Idempotent: any previously applied wrap is
-- stripped first so repeated option-tree rebuilds never stack colour codes.
-- @param text  string  the (possibly already coloured) display name.
-- @param color string  an AARRGGBB colour code.
-- @return string the name wrapped in exactly one colour code.
local function Colorize(text, color)
    text = tostring(text or "")
    text = text:gsub("^|c%x%x%x%x%x%x%x%x", ""):gsub("|r$", "")
    return "|c" .. color .. text .. "|r"
end

-- Apply the MENU_NODES presentation (order, icon, colour) to the assembled
-- top-level args. Pages registered in other files are styled here so the menu
-- stays consistent from one place. Unlisted nodes are left untouched.
-- @param args table  options.args (the top-level tree nodes).
local function ApplyMenuStyle(args)
    for key, def in pairs(MENU_NODES) do
        local node = args[key]
        if node then
            node.order = def.order
            node.icon = def.icon
            node.name = Colorize(node.name, MENU_COLORS[def.group])
        end
    end
end

-- Build the root options table. Appearance pages and modules are added later via
-- Addon:RegisterModuleOptions(); the root statically defines General, the
-- Modules parent node and (at the end) Profiles.
function Addon:BuildOptions()
    local L = ns.L
    local options = {
        type = "group",
        name = "MAUI M+ Timer",
        childGroups = "tree",
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                icon = ICON_GENERAL,
                args = {
                    settings = {
                        type = "group", inline = true, name = L["Settings"], order = 1,
                        args = {
                            width = {
                                type = "range",
                                name = L["Width"],
                                desc = L["Width of the display in pixels (increase if text is cut off)."],
                                order = 1,
                                min = 150, max = 600, step = 5,
                                get = function() return Addon.db.profile.ui.width or 220 end,
                                set = function(_, v)
                                    Addon.db.profile.ui.width = v
                                    Addon.MainWindow:ApplyWidth()
                                    -- Restyle so width-dependent layouts (e.g. the
                                    -- split bar segments) and demo data refresh live.
                                    Addon.MainWindow:Refresh()
                                end,
                            },
                            spacing = {
                                type = "range",
                                name = L["Element spacing"],
                                desc = L["Vertical gap between the stacked HUD elements (e.g. between the timer and forces bars)."],
                                order = 1.5,
                                min = 0, max = 20, step = 1,
                                get = function() return Addon.db.profile.ui.spacing or 2 end,
                                set = function(_, v)
                                    Addon.db.profile.ui.spacing = v
                                    Addon.MainWindow:Layout()
                                end,
                            },
                            minimap = {
                                type = "toggle",
                                name = L["Minimap button"],
                                desc = L["Show the minimap button."],
                                order = 2,
                                get = function() return not (Addon.db.profile.minimap and Addon.db.profile.minimap.hide) end,
                                set = function(_, v) Addon:SetMinimapShown(v) end,
                            },
                        },
                    },
                    misc = {
                        type = "group", inline = true, name = L["Other"], order = 2,
                        args = {
                            locked = {
                                type = "toggle",
                                name = L["Lock display"],
                                desc = L["Prevent the display from being dragged."],
                                order = 1,
                                get = function() return Addon.db.profile.ui.locked end,
                                set = function(_, v) Addon.db.profile.ui.locked = v end,
                            },
                            demo = {
                                type = "toggle",
                                name = L["Demo mode"],
                                desc = L["Show sample data so the display can be positioned and styled."],
                                order = 2,
                                get = function() return Addon.db.profile.ui.demo end,
                                set = function(_, v) Addon.Demo:Toggle(v) end,
                            },
                            debug = {
                                type = "toggle",
                                name = L["Debug mode"],
                                desc = L["Show debug messages in chat."],
                                order = 3,
                                get = function() return Addon.db.profile.debug end,
                                set = function(_, v) Addon.db.profile.debug = v end,
                            },
                        },
                    },
                },
            },
            -- Parent node that collects every module page as a collapsible child.
            modules = {
                type = "group",
                name = L["Modules"],
                order = 10,
                icon = ICON_MODULES,
                args = {
                    desc = {
                        type = "description",
                        order = 0,
                        name = L["Enable, disable and configure each display element."],
                    },
                },
            },
        },
    }

    -- Merge in registered option pages by category. "root" pages (HUD panel,
    -- font, colors) sit at the top level next to General; "modules" pages are
    -- nested under the Modules parent node defined above.
    local categories = self._optionCategories or {}
    for key, group in pairs(categories.root or {}) do
        options.args[key] = group
    end
    for key, group in pairs(categories.modules or {}) do
        options.args.modules.args[key] = group
    end

    -- Standard profile management page (switch/copy/reset/delete).
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    options.args.profiles.order = -1
    options.args.profiles.icon = ICON_PROFILES
    -- Nest profile sharing (import/export) as its own page under the profile
    -- node, the same way modules are nested under the Modules node.
    options.args.profiles.args.share = self:BuildShareOptions()

    -- Apply the consistent order/icon/colour scheme to the top-level entries.
    ApplyMenuStyle(options.args)
    return options
end

-- Import/Export page for the current profile, shown as a sub-page under the
-- profile node. The serialization lives in Core/Profiles.lua; this only wires
-- the UI. The export string is generated on demand (Export button) so the field
-- stays empty until the user asks for it.
function Addon:BuildShareOptions()
    local L = ns.L
    return {
        type = "group",
        name = L["Import / Export"],
        order = 100,
        icon = "Interface\\ICONS\\INV_Misc_Note_02",
        args = {
            exportDesc = {
                type = "description", order = 1,
                name = L["Click Export to generate a shareable string of your current profile, then copy it."],
            },
            exportBtn = {
                type = "execute", order = 2, name = L["Export"],
                func = function()
                    Addon._exportString = Addon.Profiles:Export() or ""
                    LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
                end,
            },
            export = {
                type = "input", multiline = 6, width = "full", order = 3,
                name = L["Export string"],
                hidden = function() return not Addon._exportString or Addon._exportString == "" end,
                get = function() return Addon._exportString or "" end,
                set = function() end, -- read-only: select the text and copy it
            },
            importDesc = {
                type = "description", order = 10,
                name = L["Paste a string and accept to overwrite the current profile."],
            },
            import = {
                type = "input", multiline = 6, width = "full", order = 11,
                name = L["Import"],
                confirm = function() return L["Overwrite the current profile with the imported settings?"] end,
                get = function() return "" end,
                set = function(_, value)
                    local ok, err = Addon.Profiles:Import(value)
                    if ok then
                        Addon:Info(L["Profile imported."])
                        if Addon.MainWindow then Addon.MainWindow:Refresh() end
                    else
                        Addon:Error(L["Import failed: %s"], tostring(err))
                    end
                end,
            },
        },
    }
end

-- About page: addon name, version, author, the slash commands and project info.
-- All values are read from the .toc metadata so they stay in sync with releases.
function Addon:BuildAboutOptions()
    local L = ns.L
    local function meta(field)
        return (C_AddOns and C_AddOns.GetAddOnMetadata
            and C_AddOns.GetAddOnMetadata(ADDON_NAME, field)) or ""
    end
    return {
        type = "group",
        name = L["About"],
        order = 100,
        icon = "Interface\\ICONS\\INV_Misc_QuestionMark",
        args = {
            -- Logo and title in one description: the AceGUI Label widget renders
            -- the image to the left of the text when the row is wide enough.
            title = {
                type = "description", order = 1, width = "full",
                fontSize = "large", name = "MAUI M+ Timer",
                image = LOGO_TEXTURE,
                imageWidth = 40, imageHeight = 40,
                imageCoords = { 0, 1, 0, 1 },
            },
            version = { type = "description", order = 2,
                name = "|cffffd200" .. L["Version"] .. ":|r " .. (Addon.version or meta("Version")) },
            author = { type = "description", order = 3,
                name = "|cffffd200" .. L["Author"] .. ":|r " .. meta("Author") },
            commands = {
                type = "group", inline = true, name = L["Commands"], order = 10,
                args = {
                    list = { type = "description", order = 1, name = L["Command list"] },
                },
            },
            info = {
                type = "group", inline = true, name = L["Links"], order = 20,
                args = {
                    category = { type = "description", order = 1,
                        name = "|cffffd200" .. L["Category"] .. ":|r " .. meta("X-Category") },
                    license = { type = "description", order = 2,
                        name = "|cffffd200" .. L["License"] .. ":|r " .. meta("X-License") },
                },
            },
            credits = {
                type = "group", inline = true, name = L["Credits"], order = 30,
                args = {
                    icons  = { type = "description", order = 1, name = L["Icon credit"] },
                    sounds = { type = "description", order = 2, name = L["Sound credit"] },
                },
            },
        },
    }
end

-- Register options + slash command. Called from OnInitialize.
function Addon:SetupConfig()
    local AceConfig = LibStub("AceConfig-3.0")
    self.AceConfigDialog = LibStub("AceConfigDialog-3.0")

    -- Register the global font page (baseline for all elements).
    if self.BuildGlobalFontOptions then
        self:RegisterModuleOptions("globalfont", self:BuildGlobalFontOptions(), "root")
    end

    -- Register the aggregated colors page (all element colors by area).
    if self.BuildColorsOptions then
        self:RegisterModuleOptions("colors", self:BuildColorsOptions(), "root")
    end

    -- Register the HUD panel page (background, border, title).
    if self.BuildWindowOptions then
        self:RegisterModuleOptions("window", self:BuildWindowOptions(), "root")
    end

    -- About page (name, version, author, commands, project info).
    if self.BuildAboutOptions then
        self:RegisterModuleOptions("about", self:BuildAboutOptions(), "root")
    end

    AceConfig:RegisterOptionsTable(ADDON_NAME, function() return Addon:BuildOptions() end)
    self.optionsFrame = self.AceConfigDialog:AddToBlizOptions(ADDON_NAME, "MAUI M+ Timer")

    self:RegisterChatCommand("mauimpt", "HandleSlash")
end

-- Allow modules (and core appearance pages) to attach their own options group
-- to the tree. category "modules" (default) nests the page under the Modules
-- parent node; category "root" keeps it at the top level next to General.
-- Safe to call before SetupConfig finishes; the tree is rebuilt on demand.
-- @param key      string  unique page key used by the slash-command deeplinks.
-- @param group    table   the AceConfig options group for the page.
-- @param category string  "modules" (default) or "root".
function Addon:RegisterModuleOptions(key, group, category)
    category = category or "modules"
    self._optionCategories = self._optionCategories or {}
    self._optionCategories[category] = self._optionCategories[category] or {}
    self._optionCategories[category][key] = group

    -- Remember where each page lives so /mauimpt <page> can deeplink into the
    -- (possibly nested) tree node.
    self._optionPath = self._optionPath or {}
    if category == "modules" then
        self._optionPath[key:lower()] = { "modules", key }
    else
        self._optionPath[key:lower()] = { key }
    end
end

-- Reusable enable/disable toggle for a module. Reads the saved state (falling
-- back to the module's enabledByDefault) and toggles the module live.
function Addon:ModuleEnableOption(module, order)
    local L = ns.L
    local default = module.enabledByDefault ~= false
    return {
        type = "toggle",
        name = L["Enable"],
        order = order or 1,
        get = function()
            local v = module:GetSettings().enabled
            if v == nil then return default end
            return v
        end,
        set = function(_, v)
            module:GetSettings().enabled = v
            Addon:ToggleModule(module:GetName(), v)
        end,
    }
end

-- Reusable per-module alignment option ("inherit" follows the global setting).
function Addon:ModuleAlignOption(module, order)
    local L = ns.L
    return {
        type = "select",
        name = L["Alignment"],
        desc = L["Text alignment for this element."],
        order = order or 90,
        values = {
            left = L["Left"],
            center = L["Center"],
            right = L["Right"],
        },
        get = function()
            local a = module:GetSettings().align
            if a ~= "left" and a ~= "right" then a = "center" end
            return a
        end,
        set = function(_, v)
            module:GetSettings().align = v
            -- Refresh restyles every module and, in demo mode, re-feeds sample
            -- data, so the alignment change (including content that depends on
            -- the alignment, e.g. mirrored rows) is reflected immediately.
            Addon.MainWindow:Refresh()
        end,
    }
end

-- Enable/disable a module and keep the display in sync. In demo mode the module
-- is re-fed sample data so it appears/disappears at once instead of only after
-- a /reload while previewing.
function Addon:ToggleModule(name, enabled)
    if enabled then self:EnableModule(name) else self:DisableModule(name) end
    if self.Demo and self.Demo:IsActive() then
        local m = self:GetModule(name, true)
        if enabled and m and m.SetDemo and m:IsEnabled() then
            m:SetDemo(true)
        end
    end
    -- Let other modules react to a dependency's state change (e.g. the Objectives
    -- list hides its split times when the Splits module is disabled).
    self:SendMessage("MMT_MODULE_TOGGLED", name, enabled)
    self.MainWindow:Layout()
end

-- /mauimpt [subcommand] -> open the GUI, optionally jumping to a sub page.
function Addon:HandleSlash(input)
    input = (input or ""):gsub("%s+", ""):lower()
    local dialog = self.AceConfigDialog

    if input == "demo" then
        Addon.Demo:Toggle()
        return
    end

    -- Deeplinks that open a dedicated panel instead of an options page.
    if input == "splits" then
        local m = Addon:GetModule("Splits", true)
        if m and m.Manager then m.Manager:Toggle() end
        return
    end
    if input == "checkpoints" then
        local m = Addon:GetModule("Checkpoints", true)
        if m and m.Editor then m.Editor:Toggle() end
        return
    end

    dialog:Open(ADDON_NAME)

    -- Deeplink to a sub page when one exists (e.g. /mauimpt profiles or, for a
    -- module page now nested under the Modules node, /mauimpt timer).
    if input ~= "" then
        local path = self._optionPath and self._optionPath[input]
        pcall(function()
            if path then
                dialog:SelectGroup(ADDON_NAME, unpack(path))
            else
                dialog:SelectGroup(ADDON_NAME, input)
            end
        end)
    end
end
