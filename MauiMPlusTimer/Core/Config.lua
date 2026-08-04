-- Core/Config.lua
-- Builds the AceConfig options tree and the /mauimpt slash command. No data logic.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

-- Extension-less paths; WoW resolves the bundled .tga.
local MENU_ICON_DIR = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Menu\\"
local ICON_GENERAL  = MENU_ICON_DIR .. "general"
local ICON_MODULES  = MENU_ICON_DIR .. "modules"
local ICON_PROFILES = MENU_ICON_DIR .. "profiles"

local LOGO_TEXTURE = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\icon_big"

local DISCORD_URL = "https://discord.gg/ZScRCUyqjY"

-- Fallback only: a persisted db.global.optionsWindow geometry wins over these.
local OPTIONS_DEFAULT_WIDTH  = 900
local OPTIONS_DEFAULT_HEIGHT = 650

-- WoW |c colour codes (AARRGGBB).
local MENU_COLORS = {
    core      = "ffffd100", -- gold  : core / appearance pages
    modules   = "ff40c057", -- green : module pages
    profiles  = "ff4a9eff", -- blue  : profile management
    changelog = "fff040a0", -- pink  : version history (matches the logo "+")
    about     = "ffb0b0b0", -- grey  : informational / about
}

-- Presentation of every top-level node, applied in BuildOptions so pages
-- registered elsewhere still get a consistent order, icon and colour.
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

-- Strips an existing wrap first, so repeated tree rebuilds never stack codes.
local function Colorize(text, color)
    text = tostring(text or "")
    text = text:gsub("^|c%x%x%x%x%x%x%x%x", ""):gsub("|r$", "")
    return "|c" .. color .. text .. "|r"
end

-- Unlisted nodes are left untouched.
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

-- Keys match MainWindow's block keys.
local function blockLabels()
    local L = ns.L
    return {
        dungeon = L["Dungeon"], timer = L["Timer"], timerbar = L["Timer bar"],
        forces = L["Enemy Forces"],
        objectives = L["Objectives"], deaths = L["Deaths"], splits = L["Splits"],
        checkpoints = L["Checkpoints"], cooldowns = L["Cooldowns"],
        separator1 = L["Separator line"] .. " 1",
        separator2 = L["Separator line"] .. " 2",
    }
end

-- One dropdown pair (left/right half) per HUD row. Clearing a slot re-adds the
-- module on the lowest free row, so a module can never get lost.
function Addon:BuildBlockOrderArgs()
    local L = ns.L
    local MainWindow = Addon.MainWindow
    local labels = blockLabels()

    -- Full-row blocks only offered on the left: they occupy the whole row.
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
        -- Full-width spacer after each row forces the flow layout onto a new
        -- line, so rows stack vertically at any options window width.
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

-- Root options table; appearance and module pages are merged in from
-- Addon:RegisterModuleOptions().
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
                            setup = {
                                type = "execute",
                                name = L["Run setup wizard"],
                                desc = L["Reopen the first-start setup wizard to pick a profile and load the recommended checkpoint targets."],
                                order = 4,
                                func = function()
                                    local m = Addon:GetModule("Setup", true)
                                    if m and m.UI then m.UI:Show() end
                                end,
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

    local categories = self._optionCategories or {}
    for key, group in pairs(categories.root or {}) do
        options.args[key] = group
    end
    for key, group in pairs(categories.modules or {}) do
        options.args.modules.args[key] = group
    end

    -- AceDBOptions shares its `args` table across every addon using the library,
    -- so it must never be modified. Reference the entries from an own group.
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
    profiles.args.share = self:BuildShareOptions()
    options.args.profiles = profiles

    ApplyMenuStyle(options.args)
    return options
end

-- UI only; the serialization lives in Core/Profiles.lua.
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

-- Values come from the .toc metadata so they stay in sync with releases.
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
            -- AceGUI's Label renders the image left of the text on a wide row.
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
                    -- WoW cannot open browser links, so the URL sits in an
                    -- edit box the user can select and copy; set is a no-op.
                    discord = { type = "input", order = 3, width = "double",
                        name = L["Discord"],
                        get = function() return DISCORD_URL end,
                        set = function() end },
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

    if self.BuildGlobalFontOptions then
        self:RegisterModuleOptions("globalfont", self:BuildGlobalFontOptions(), "root")
    end

    if self.BuildColorsOptions then
        self:RegisterModuleOptions("colors", self:BuildColorsOptions(), "root")
    end

    if self.BuildWindowOptions then
        self:RegisterModuleOptions("window", self:BuildWindowOptions(), "root")
    end

    if self.BuildAboutOptions then
        self:RegisterModuleOptions("about", self:BuildAboutOptions(), "root")
    end

    AceConfig:RegisterOptionsTable(ADDON_NAME, function() return Addon:BuildOptions() end)
    self.AceConfigDialog:SetDefaultSize(ADDON_NAME, OPTIONS_DEFAULT_WIDTH, OPTIONS_DEFAULT_HEIGHT)
    self.optionsFrame = self.AceConfigDialog:AddToBlizOptions(ADDON_NAME, "MAUI M+ Timer")

    -- AceConfigDialog re-runs :Open on every NotifyChange and rebinds its own
    -- default-size status table, resetting the geometry. Rebind ours after each.
    hooksecurefunc(self.AceConfigDialog, "Open", function(_, appName)
        if appName == ADDON_NAME then
            Addon:ApplyOptionsWindowStatus()
        end
    end)

    self:RegisterChatCommand("mauimpt", "HandleSlash")
end

-- Geometry binding and reset control come from the Open hook in SetupConfig.
function Addon:OpenOptions()
    if not self.AceConfigDialog then return end
    self.AceConfigDialog:Open(ADDON_NAME)
end

-- The AceGUI Frame writes its geometry into its status table after every move
-- or resize, so pointing that at SavedVariables persists it across sessions.
function Addon:ApplyOptionsWindowStatus()
    local widget = self.AceConfigDialog and self.AceConfigDialog.OpenFrames[ADDON_NAME]
    if not widget then return end
    if widget.SetStatusTable then
        widget:SetStatusTable(self.db.global.optionsWindow)
    end
    self:EnsureOptionsResetButton(widget)
end

function Addon:ToggleOptions()
    if not self.AceConfigDialog then return end
    if self.AceConfigDialog.OpenFrames[ADDON_NAME] then
        self.AceConfigDialog:Close(ADDON_NAME)
    else
        self:OpenOptions()
    end
end

-- Also clears the persisted geometry so the default survives the session.
function Addon:ResetOptionsWindowSize()
    wipe(self.db.global.optionsWindow)
    local widget = self.AceConfigDialog and self.AceConfigDialog.OpenFrames[ADDON_NAME]
    if not widget then return end
    widget:SetWidth(OPTIONS_DEFAULT_WIDTH)
    widget:SetHeight(OPTIONS_DEFAULT_HEIGHT)
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint("CENTER")
end

-- One shared button, reparented on every open; the OnShow guard hides it when
-- AceGUI recycles the host frame for another dialog (possibly another addon's).
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
        btn:SetScript("OnShow", function(s)
            local open = Addon.AceConfigDialog
                and Addon.AceConfigDialog.OpenFrames[ADDON_NAME]
            if not (open and open.frame == s:GetParent()) then s:Hide() end
        end)
        self._optionsResetButton = btn
    end

    btn:SetParent(widget.frame)
    btn:ClearAllPoints()
    -- Centered on the AceGUI status bar (~15px above the bottom, ~24px tall).
    btn:SetPoint("BOTTOMLEFT", widget.frame, "BOTTOMLEFT", 20, 19)
    btn:SetFrameLevel(widget.frame:GetFrameLevel() + 10)
    btn:Show()
end

-- Attach an options group to the tree. category "modules" (default) nests it
-- under the Modules node, "root" keeps it top level. Safe before SetupConfig.
function Addon:RegisterModuleOptions(key, group, category)
    category = category or "modules"
    self._optionCategories = self._optionCategories or {}
    self._optionCategories[category] = self._optionCategories[category] or {}
    self._optionCategories[category][key] = group

    -- Path per page so /mauimpt <page> can deeplink into a nested node.
    self._optionPath = self._optionPath or {}
    if category == "modules" then
        self._optionPath[key:lower()] = { "modules", key }
    else
        self._optionPath[key:lower()] = { key }
    end
end

-- Falls back to the module's enabledByDefault when nothing is saved.
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
            -- Refresh, not Restyle: mirrored rows depend on the alignment.
            Addon.MainWindow:Refresh()
        end,
    }
end

-- Modules only reload settings on MMT_PROFILE_CHANGED, they never toggle their
-- own AceAddon state, so a profile switch needs this to hide disabled blocks.
function Addon:ApplyModuleStates()
    for name, module in self:IterateModules() do
        if type(module.GetSettings) == "function" then
            local settings = module:GetSettings()
            local want = settings and settings.enabled
            if want == nil then want = module.enabledByDefault ~= false end
            local isOn = module:IsEnabled()
            if want and not isOn then
                self:EnableModule(name)
            elseif not want and isOn then
                self:DisableModule(name)
            end
        end
    end
end

function Addon:ToggleModule(name, enabled)
    if enabled then self:EnableModule(name) else self:DisableModule(name) end
    if self.Demo and self.Demo:IsActive() then
        local m = self:GetModule(name, true)
        if enabled and m and m.SetDemo and m:IsEnabled() then
            m:SetDemo(true) -- re-feed sample data so the block appears at once
        end
    end
    -- Dependants react to this (e.g. Objectives hides splits when Splits is off).
    self:SendMessage("MMT_MODULE_TOGGLED", name, enabled)
    -- The row cache keys on blockRows alone, so it misses the enabled change.
    self.MainWindow:InvalidateRows()
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
    if input == "setup" then
        local m = Addon:GetModule("Setup", true)
        if m and m.UI then m.UI:Show() end
        return
    end

    self:OpenOptions()

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
