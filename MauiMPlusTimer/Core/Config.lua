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

-- Default (and reset) size of the standalone options window. Once the user
-- moves or resizes the window, their geometry is persisted account-wide in
-- db.global.optionsWindow and wins over these values (see Addon:OpenOptions).
local OPTIONS_DEFAULT_WIDTH  = 900
local OPTIONS_DEFAULT_HEIGHT = 650

-- Functional colour scheme for the top-level menu entries. Grouping the entries
-- by purpose (core appearance, modules, profiles, about) gives the tree a quick
-- visual hierarchy. Colours are WoW |c colour codes (AARRGGBB).
local MENU_COLORS = {
    core      = "ffffd100", -- gold  : core / appearance pages
    modules   = "ff40c057", -- green : module pages
    profiles  = "ff4a9eff", -- blue  : profile management
    changelog = "fff040a0", -- pink  : version history (matches the logo "+")
    about     = "ffb0b0b0", -- grey  : informational / about
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
    changelog  = { order = 95,  group = "changelog", icon = MENU_ICON_DIR .. "changelog" },
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

-- Localized display names of the orderable HUD blocks (module blocks plus the
-- two separator lines; keys match MainWindow's block keys).
local function blockLabels()
    local L = ns.L
    return {
        dungeon = L["Dungeon"], timer = L["Timer"], forces = L["Enemy Forces"],
        objectives = L["Objectives"], deaths = L["Deaths"], splits = L["Splits"],
        checkpoints = L["Checkpoints"], cooldowns = L["Cooldowns"],
        separator1 = L["Separator line"] .. " 1",
        separator2 = L["Separator line"] .. " 2",
    }
end

-- Args for the "Element order" section on the General page: one dropdown pair
-- (left / right half) per HUD row. Assigning a block moves it out of its old
-- slot; clearing a slot re-adds the module on the lowest free row, so modules
-- can never get lost. Enabled separator lines appear as entries too and
-- always occupy a full row (the right dropdown is disabled next to one).
-- Rebuilt on every options refresh (BuildOptions is registered as a function).
function Addon:BuildBlockOrderArgs()
    local L = ns.L
    local MainWindow = Addon.MainWindow
    local labels = blockLabels()

    -- Dropdown content: empty + modules; separators (while enabled on the HUD
    -- panel page). Full-row blocks - timer, forces, objectives, separators -
    -- can only go into the LEFT dropdown: they always occupy the whole row.
    local leftValues, rightValues = { none = "-" }, { none = "-" }
    local leftSorting, rightSorting = { "none" }, { "none" }
    for _, key in ipairs(MainWindow.MODULE_BLOCKS) do
        leftValues[key] = labels[key]
        leftSorting[#leftSorting + 1] = key
        if not MainWindow:IsFullRowKey(key) then
            rightValues[key] = labels[key]
            rightSorting[#rightSorting + 1] = key
        end
    end
    for i = 1, 2 do
        if MainWindow:IsSeparatorEnabled(i) then
            local key = "separator" .. i
            leftValues[key] = labels[key]
            leftSorting[#leftSorting + 1] = key
        end
    end

    local args = {
        desc = {
            type = "description", order = 0,
            name = L["Assign each element to a row (top to bottom). A row can hold two blocks side by side (left/right); cleared modules re-appear on the lowest free row. Enabled separator lines are placed here as well."],
        },
    }

    for index = 1, MainWindow.MAX_ROWS do
        local base = index * 10
        args["row" .. index .. "Num"] = {
            type = "description", order = base, width = 0.25, fontSize = "medium",
            name = string.format("%d.", index),
        }
        -- Full-width spacer AFTER each row (order base+3, added below) forces
        -- the flow layout onto a new line, so the rows always stack vertically
        -- no matter how wide the options window is.
        args["row" .. index .. "Break"] = {
            type = "description", order = base + 3, width = "full", name = " ",
            fontSize = "small",
        }
        args["row" .. index .. "Left"] = {
            type = "select", order = base + 1, width = 1.0, name = "",
            values = leftValues, sorting = leftSorting,
            get = function()
                return MainWindow:GetBlockRows()[index].left or "none"
            end,
            set = function(_, v)
                MainWindow:SetBlockSlot(index, "left", v ~= "none" and v or nil)
            end,
        }
        args["row" .. index .. "Right"] = {
            type = "select", order = base + 2, width = 1.0, name = "",
            values = rightValues, sorting = rightSorting,
            -- Full-row blocks occupy the whole row; no right-hand neighbor.
            disabled = function()
                return MainWindow:IsFullRowKey(MainWindow:GetBlockRows()[index].left)
            end,
            get = function()
                return MainWindow:GetBlockRows()[index].right or "none"
            end,
            set = function(_, v)
                MainWindow:SetBlockSlot(index, "right", v ~= "none" and v or nil)
            end,
        }
    end

    args.resetOrder = {
        type = "execute", order = (MainWindow.MAX_ROWS + 1) * 10, width = 1.0,
        name = L["Reset order"],
        confirm = function() return L["Reset the element order to the default layout?"] end,
        func = function() MainWindow:ResetBlockRows() end,
    }
    return args
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
                    elementOrder = {
                        type = "group", inline = true, name = L["Element order"], order = 3,
                        args = Addon:BuildBlockOrderArgs(),
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
    -- IMPORTANT: the table returned by AceDBOptions shares its `args` across
    -- EVERY addon that uses the library (tbl.args = optionsTable in the lib),
    -- so it must never be modified - adding entries there would inject them
    -- into other addons' profile pages (e.g. ElvUI). Build an own group that
    -- only references the shared entries and add the share page to that.
    local dbOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    local profiles = {
        type = "group",
        name = dbOptions.name,
        desc = dbOptions.desc,
        handler = dbOptions.handler, -- inherited by the referenced entries
        order = -1,
        icon = ICON_PROFILES,
        args = {},
    }
    for key, option in pairs(dbOptions.args) do
        profiles.args[key] = option -- read-only reference, never modified
    end
    -- Nest profile sharing (import/export) as its own page under the profile
    -- node, the same way modules are nested under the Modules node.
    profiles.args.share = self:BuildShareOptions()
    options.args.profiles = profiles

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
        icon = MENU_ICON_DIR .. "share",
        args = {
            exportDesc = {
                type = "description", order = 1,
                name = L["Click Export to generate a shareable string of your current profile, then copy it."],
            },
            exportPlain = {
                type = "toggle", order = 2, width = "full",
                name = L["Export as Lua table"],
                desc = L["Output the profile as readable Lua code (for use in an addon) instead of a shareable string. This format cannot be re-imported."],
                get = function() return Addon._exportPlain end,
                set = function(_, v)
                    Addon._exportPlain = v
                    -- Regenerate an already visible export in the new format.
                    if Addon._exportString and Addon._exportString ~= "" then
                        Addon._exportString = (v and Addon.Profiles:ExportPlain()
                            or Addon.Profiles:Export()) or ""
                    end
                end,
            },
            exportBtn = {
                type = "execute", order = 3, name = L["Export"],
                func = function()
                    Addon._exportString = (Addon._exportPlain and Addon.Profiles:ExportPlain()
                        or Addon.Profiles:Export()) or ""
                    LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
                end,
            },
            export = {
                type = "input", multiline = 6, width = "full", order = 4,
                name = L["Export string"],
                hidden = function() return not Addon._exportString or Addon._exportString == "" end,
                get = function() return Addon._exportString or "" end,
                set = function() end, -- read-only: select the text and copy it
            },
            importDesc = {
                type = "description", order = 10,
                name = L["Paste a string and accept to import the profile. It is created under its exported name; your current profile is kept."],
            },
            import = {
                type = "input", multiline = 6, width = "full", order = 11,
                name = L["Import"],
                -- Confirmation is only needed when the imported name collides
                -- with an existing profile. Invalid strings return false here
                -- (no popup) and fail fast with an error in `set` instead.
                confirm = function(_, value)
                    local payload = Addon.Profiles:DecodeImport(value)
                    if payload and Addon.Profiles:Exists(payload.name) then
                        return string.format(
                            L["Profile '%s' already exists. Overwrite it?"], payload.name)
                    end
                    return false
                end,
                get = function() return "" end,
                set = function(_, value)
                    local ok, res = Addon.Profiles:Import(value)
                    if ok then
                        Addon:Info(L["Imported profile '%s'."], tostring(res))
                        if Addon.MainWindow then Addon.MainWindow:Refresh() end
                    else
                        Addon:Error(L["Import failed: %s"], tostring(res))
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
    self.AceConfigDialog:SetDefaultSize(ADDON_NAME, OPTIONS_DEFAULT_WIDTH, OPTIONS_DEFAULT_HEIGHT)
    self.optionsFrame = self.AceConfigDialog:AddToBlizOptions(ADDON_NAME, "MAUI M+ Timer")

    -- AceConfigDialog re-runs :Open for an already-open frame on every options
    -- refresh (NotifyChange after a setting change) and rebinds ITS internal
    -- status table - which carries only the default size - to the frame each
    -- time. That reset the window geometry on the first change after a reload.
    -- Rebinding our persisted table after EVERY Open keeps the geometry stable.
    hooksecurefunc(self.AceConfigDialog, "Open", function(_, appName)
        if appName == ADDON_NAME then
            Addon:ApplyOptionsWindowStatus()
        end
    end)

    self:RegisterChatCommand("mauimpt", "HandleSlash")
end

-- Open the standalone options window. The geometry binding and the reset
-- control are attached by the Open hook installed in SetupConfig, so they are
-- applied on every open path (slash command, minimap button, compartment,
-- changelog auto-show) AND on every internal refresh re-open.
function Addon:OpenOptions()
    if not self.AceConfigDialog then return end
    self.AceConfigDialog:Open(ADDON_NAME)
end

-- Bind the persisted window geometry to the open options frame and attach the
-- size-reset control. The AceGUI Frame writes its geometry (width/height/
-- top/left) into its status table whenever the user finishes moving or
-- resizing; pointing it at a SavedVariables table persists the geometry
-- across sessions. While the table is empty (first use / after a reset) the
-- default size from SetDefaultSize stays in effect.
function Addon:ApplyOptionsWindowStatus()
    local widget = self.AceConfigDialog and self.AceConfigDialog.OpenFrames[ADDON_NAME]
    if not widget then return end
    if widget.SetStatusTable then
        widget:SetStatusTable(self.db.global.optionsWindow)
    end
    self:EnsureOptionsResetButton(widget)
end

-- Toggle the standalone options window: close it when it is open, otherwise
-- open it. Used by the minimap button and the addon compartment entry, so a
-- second click on either dismisses the window again.
function Addon:ToggleOptions()
    if not self.AceConfigDialog then return end
    if self.AceConfigDialog.OpenFrames[ADDON_NAME] then
        self.AceConfigDialog:Close(ADDON_NAME)
    else
        self:OpenOptions()
    end
end

-- Reset the options window to its default size, re-center it and clear the
-- persisted geometry (so the default also applies to future sessions).
function Addon:ResetOptionsWindowSize()
    wipe(self.db.global.optionsWindow)
    local widget = self.AceConfigDialog and self.AceConfigDialog.OpenFrames[ADDON_NAME]
    if not widget then return end
    widget:SetWidth(OPTIONS_DEFAULT_WIDTH)
    widget:SetHeight(OPTIONS_DEFAULT_HEIGHT)
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint("CENTER")
end

-- Attach the small "reset window size" control to the bottom-left edge of the
-- options window (on the status bar, left of the resize handles). One shared
-- button is reparented on every open; its OnShow guard hides it when AceGUI
-- recycles the host frame for a different dialog (possibly another addon's).
function Addon:EnsureOptionsResetButton(widget)
    local L = ns.L
    local btn = self._optionsResetButton
    if not btn then
        btn = CreateFrame("Button", nil, widget.frame)
        btn:SetSize(16, 16)
        btn:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
        btn:SetHighlightTexture("Interface\\Buttons\\UI-RefreshButton", "ADD")
        btn:SetScript("OnClick", function()
            Addon:ResetOptionsWindowSize()
        end)
        btn:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(L["Reset window size"])
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        -- Hide the button whenever its host frame is shown for anything that
        -- is not our own options window (AceGUI widget recycling).
        btn:SetScript("OnShow", function(s)
            local open = Addon.AceConfigDialog
                and Addon.AceConfigDialog.OpenFrames[ADDON_NAME]
            if not (open and open.frame == s:GetParent()) then s:Hide() end
        end)
        self._optionsResetButton = btn
    end

    btn:SetParent(widget.frame)
    btn:ClearAllPoints()
    -- Vertically centered on the AceGUI Frame's status bar (which starts
    -- ~15px above the frame's bottom edge and is ~24px tall).
    btn:SetPoint("BOTTOMLEFT", widget.frame, "BOTTOMLEFT", 20, 19)
    btn:SetFrameLevel(widget.frame:GetFrameLevel() + 10)
    btn:Show()
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
    -- "/mauimpt setup" deeplink is PARKED together with the Setup module
    -- (planned for a later release); the silent module lookup keeps this a
    -- harmless no-op until the module is loaded again.
    if input == "setup" then
        local m = Addon:GetModule("Setup", true)
        if m and m.UI then m.UI:Show() end
        return
    end

    self:OpenOptions()

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
