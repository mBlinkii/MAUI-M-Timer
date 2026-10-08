-- MauiMPlusTimer_Options/Config.lua
-- Builds the AceConfig options tree. Loaded on demand with the rest of the settings.

local _, ns = ...
local ADDON_NAME = ns.ADDON_NAME
local Addon = ns.Addon

-- Extension-less paths; WoW resolves the bundled .tga.
local MENU_ICON_DIR = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Menu\\"
local ICON_GENERAL  = MENU_ICON_DIR .. "general"
local ICON_MODULES  = MENU_ICON_DIR .. "modules"
local ICON_PROFILES = MENU_ICON_DIR .. "profiles"

local LOGO_TEXTURE = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\icon_big"

local DISCORD_URL = "https://discord.gg/ZScRCUyqjY"

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
        dungeon = L["Dungeon name"], dungeonicon = L["Dungeon icon"],
        level = L["Keystone level"], affixes = L["Affixes"],
        timer = L["Timer"], timerbar = L["Timer bar"],
        forces = L["Enemy Forces"],
        objectives = L["Objectives"], deaths = L["Deaths"], splits = L["Splits"],
        checkpoints = L["Checkpoints"],
        brez = L["Battle resurrections"], bloodlust = L["Heroism"],
        separator1 = L["Separator line"] .. " 1",
        separator2 = L["Separator line"] .. " 2",
    }
end

-- The column strip: one cell per column at its real share of the width.
-- Dragging a divider moves width between its two neighbors, clicking a cell
-- flips its alignment, a right-click resets the widths. Fixed height, so it
-- never moves the page while dragging.
local STRIP_H = 40
local STRIP_GAP = 2
local DIVIDER_W = 10
local MIN_SHARE, SHARE_STEP = 25, 5

local strip

local function cursorX()
    return GetCursorPosition() / strip.frame:GetEffectiveScale()
end

local function layoutStrip()
    local MainWindow, OT, L = Addon.MainWindow, ns.OT, ns.L
    local cols, width = MainWindow:GetGrid().cols, strip.width
    local total = 0
    for c = 1, cols do total = total + MainWindow:GetColumnWidth(c) end
    local avail = width - STRIP_GAP * (cols - 1)
    strip.pps = avail / total
    local labels = { LEFT = L["Left"], CENTER = L["Center"], RIGHT = L["Right"] }
    local x = 0
    for c = 1, MainWindow.MAX_COLS do
        local cell, divider = strip.cells[c], strip.dividers[c]
        if c <= cols then
            local w = c == cols and (width - x) or math.floor(avail * MainWindow:GetColumnWidth(c) / total + 0.5)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", x, 0)
            cell:SetSize(math.max(1, w), STRIP_H)
            cell.adjustable = MainWindow:IsAdjustableColumn(c)
            cell.bg:SetColorTexture(OT:Unpack(cell:IsMouseOver() and cell.adjustable and "hover" or "line"))
            -- Share of the whole width, so equal columns are easy to set.
            local percent = math.floor(MainWindow:GetColumnWidth(c) / total * 100 + 0.5)
            cell.label:SetText(string.format("%d: %s\n%d %%", c, labels[MainWindow:GetColumnJustify(c)], percent))
            cell.label:SetTextColor(OT:Unpack(cell.adjustable and "accent" or "muted"))
            cell:Show()
            x = x + w + STRIP_GAP
            if divider then
                -- Re-applied each time: the strip is re-parented on every redraw.
                divider:SetFrameLevel(strip.frame:GetFrameLevel() + 5)
                divider:SetShown(c < cols)
                divider:ClearAllPoints()
                divider:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", x - STRIP_GAP / 2 - DIVIDER_W / 2, 0)
            end
        else
            cell:Hide()
            if divider then divider:Hide() end
        end
    end
end

local function newCell(c)
    local MainWindow, OT = Addon.MainWindow, ns.OT
    local cell = CreateFrame("Button", nil, strip.frame)
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetAllPoints()
    cell.label = OT:Text(cell, "small", "muted")
    cell.label:SetPoint("CENTER")
    cell.label:SetJustifyH("CENTER")
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cell:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            MainWindow:ResetColumnWidths()
        elseif cell.adjustable then
            MainWindow:SetColumnAlign(c, MainWindow:GetColumnAlign(c) == "left" and "right" or "left")
        end
        layoutStrip()
    end)
    cell:SetScript("OnEnter", layoutStrip)
    cell:SetScript("OnLeave", layoutStrip)
    return cell
end

-- The divider right of column c.
local function newDivider(c)
    local MainWindow, OT = Addon.MainWindow, ns.OT
    local d = CreateFrame("Frame", nil, strip.frame)
    d:SetSize(DIVIDER_W, STRIP_H)
    d:SetFrameLevel(strip.frame:GetFrameLevel() + 5)
    d:EnableMouse(true)
    d.line = d:CreateTexture(nil, "OVERLAY")
    d.line:SetWidth(2)
    d.line:SetPoint("TOP")
    d.line:SetPoint("BOTTOM")
    d.line:SetColorTexture(OT:Unpack("muted"))
    local function drag()
        local delta = (cursorX() - d.startX) / strip.pps
        local sum = d.a + d.b
        local a = math.floor((d.a + delta) / SHARE_STEP + 0.5) * SHARE_STEP
        a = math.max(MIN_SHARE, math.min(sum - MIN_SHARE, a))
        if a ~= MainWindow:GetColumnWidth(c) then
            MainWindow:SetColumnWidth(c, a, true)
            MainWindow:SetColumnWidth(c + 1, sum - a, true)
            layoutStrip()
        end
    end
    d:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            MainWindow:ResetColumnWidths()
            layoutStrip()
            return
        end
        if button ~= "LeftButton" then return end
        d.startX, d.a, d.b = cursorX(), MainWindow:GetColumnWidth(c), MainWindow:GetColumnWidth(c + 1)
        d:SetScript("OnUpdate", drag)
    end)
    d:SetScript("OnMouseUp", function()
        d:SetScript("OnUpdate", nil)
        MainWindow:Refresh()
    end)
    d:SetScript("OnEnter", function() d.line:SetColorTexture(OT:Unpack("accent")) end)
    d:SetScript("OnLeave", function() d.line:SetColorTexture(OT:Unpack("muted")) end)
    return d
end

function Addon.DrawColumnStrip(width)
    if not strip then
        strip = { frame = CreateFrame("Frame"), cells = {}, dividers = {} }
        for c = 1, Addon.MainWindow.MAX_COLS do
            strip.cells[c] = newCell(c)
            if c < Addon.MainWindow.MAX_COLS then strip.dividers[c] = newDivider(c) end
        end
    end
    strip.width = width
    strip.frame:SetSize(width, STRIP_H)
    layoutStrip()
    return strip.frame, STRIP_H
end

-- One dropdown per grid cell of each HUD row. Clearing a slot re-adds the
-- module in a free slot, so a module can never get lost.
function Addon:BuildBlockOrderArgs()
    local L = ns.L
    local MainWindow = Addon.MainWindow
    local labels = blockLabels()

    local values, sorting = { none = "-" }, { "none" }
    for _, key in ipairs(MainWindow.MODULE_BLOCKS) do
        values[key] = labels[key]
        sorting[#sorting + 1] = key
    end
    for i = 1, 2 do
        if MainWindow:IsSeparatorEnabled(i) then
            local key = "separator" .. i
            values[key] = labels[key]
            sorting[#sorting + 1] = key
        end
    end

    local function notify()
        LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
    end

    local args = {
        orientation = {
            type = "select", order = 0,
            name = L["Orientation"],
            desc = L["Vertical stacks the elements in a narrow grid with 3 columns, horizontal lays them out in a wide grid with 5 columns and 3 rows. Each orientation keeps its own element order and width."],
            values = { vertical = L["Vertical"], horizontal = L["Horizontal"] },
            sorting = { "vertical", "horizontal" },
            get = function() return MainWindow:GetOrientation() end,
            set = function(_, v)
                MainWindow:SetOrientation(v)
                notify()
            end,
        },
        columns = {
            type = "select", order = 0.5,
            name = L["Columns"],
            desc = L["Number of columns of the horizontal grid. Both share one element order; elements in columns 6 and 7 move to a free slot with 5 columns."],
            values = { ["5"] = "5", ["7"] = "7" },
            sorting = { "5", "7" },
            hidden = function() return MainWindow:GetOrientation() ~= "horizontal" end,
            get = function() return tostring(MainWindow:GetHorizontalColumns()) end,
            set = function(_, v)
                MainWindow:SetHorizontalColumns(tonumber(v))
                notify()
            end,
        },
        desc = {
            type = "description", order = 1,
            name = L["Assign each element to a grid slot (top to bottom). A row holds several blocks side by side, depending on the orientation; cleared modules re-appear in a free slot. Bars, objectives and separator lines always take a whole row."],
        },
    }

    -- One set of dropdowns per orientation; widths are static in AceConfig.
    -- Columns align their text, so full-row blocks may sit in any of them.
    local grids = {
        { orientation = "vertical", prefix = "v", cols = 3, width = 0.9 },
        { orientation = "horizontal", prefix = "h", cols = 5, width = 0.55 },
        { orientation = "horizontal", prefix = "h7", cols = 7, width = 0.39 },
    }
    for _, grid in ipairs(grids) do
        for index = 1, MainWindow.MAX_ROWS do
            local base = index * 10
            local id = grid.prefix .. "row" .. index
            -- Overflow rows only exist while full-row blocks exceed the grid.
            local function hidden()
                return MainWindow:GetOrientation() ~= grid.orientation
                    or MainWindow:GetGrid().cols ~= grid.cols
                    or MainWindow:GetBlockRows()[index] == nil
            end
            args[id .. "Num"] = {
                type = "description", order = base, width = 0.25, fontSize = "medium",
                name = string.format("%d.", index), hidden = hidden,
            }
            -- Full-width spacer after each row forces the flow layout onto a new
            -- line, so rows stack vertically at any options window width.
            args[id .. "Break"] = {
                type = "description", order = base + 9, width = "full", name = " ",
                fontSize = "small", hidden = hidden,
            }
            for col = 1, grid.cols do
                args[id .. "Col" .. col] = {
                    type = "select", order = base + col, width = grid.width, name = "",
                    values = values, sorting = sorting,
                    hidden = hidden,
                    get = function()
                        local row = MainWindow:GetBlockRows()[index]
                        return row and row[col] or "none"
                    end,
                    set = function(_, v)
                        local before = #MainWindow:GetBlockRows()
                        MainWindow:SetBlockSlot(index, col, v ~= "none" and v or nil)
                        if #MainWindow:GetBlockRows() ~= before then notify() end
                    end,
                }
            end
        end
    end

    -- Widths and alignments of the columns in one strip instead of a slider
    -- and a dropdown per column.
    args.columnStrip = {
        type = "description", order = (MainWindow.MAX_ROWS + 1) * 10 + 0.1, width = "full", name = "",
        arg = { preview = Addon.DrawColumnStrip },
    }
    args.columnHint = {
        type = "description", order = (MainWindow.MAX_ROWS + 1) * 10 + 0.2, fontSize = "small",
        name = L["Drag a divider to make columns wider or narrower. Click a column to switch its alignment where it can lean either way. Right-click resets the widths."],
    }

    args.resetOrder = {
        type = "execute", order = (MainWindow.MAX_ROWS + 1) * 10 + 1, width = 1.0,
        name = L["Reset order"],
        confirm = function() return L["Reset the element order to the default layout?"] end,
        func = function()
            MainWindow:ResetBlockRows()
            notify()
        end,
    }
    args.equalWidths = {
        type = "execute", order = (MainWindow.MAX_ROWS + 1) * 10 + 2, width = 1.0,
        name = L["Equal column widths"],
        func = function()
            MainWindow:ResetColumnWidths()
            if strip then layoutStrip() end
        end,
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
                    interface = Addon:InterfaceOptions(2),
                    settings = {
                        type = "group", inline = true, name = L["Settings"], order = 1,
                        args = {
                            width = {
                                type = "range",
                                name = L["Width"],
                                desc = L["Width of the display in pixels (increase if text is cut off)."],
                                order = 1,
                                min = 150, max = 1200, step = 5,
                                get = function() return Addon.MainWindow:GetWidth() end,
                                set = function(_, v)
                                    Addon.MainWindow:SetWidthSetting(v)
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

-- Every refresh asks, so the last decode is kept until the string changes.
local peekedString, peekedPayload

local function peekImport()
    local str = Addon._importString or ""
    if str ~= peekedString then
        peekedString = str
        peekedPayload = str ~= "" and Addon.Profiles:DecodeImport(str) or nil
    end
    return peekedPayload
end

-- What the import box shows in place of a valid string; nil while there is none.
local function importPreview()
    local payload = peekImport()
    if not payload then return nil end
    local L = ns.L

    local profile = payload.name
    if Addon.Profiles:Exists(payload.name) then
        profile = profile .. "  |cfff09020" .. L["(exists, will be overwritten)"] .. "|r"
    end
    return strjoin("\n", Addon.Utils.ShareLine(L["Profile"], profile),
        Addon.Utils.ShareMetaLines(payload.meta))
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
                set = function() end,
                arg = "readOnly", -- UI/Options: select and copy only, no Accept
            },
            importDesc = {
                type = "description", order = 10,
                name = L["Paste a profile string, check its details and click Import. The profile is created under its exported name; your current profile is kept."],
            },
            import = {
                type = "input", multiline = 6, width = "full", order = 11,
                name = function()
                    if (Addon._importString or "") ~= "" and not peekImport() then
                        return L["Import string"] .. "  |cfff04a4a" .. L["Not a valid profile string."] .. "|r"
                    end
                    return L["Import string"]
                end,
                arg = "live", -- UI/Options: stored while pasting, so the box turns into the preview
                -- A valid string is shown as its details; the string itself stays in _importString.
                get = function() return importPreview() or Addon._importString or "" end,
                set = function(_, value)
                    local preview = importPreview()
                    if preview then
                        if value == preview then return end
                        -- Pasted beside the preview instead of over it (Ace's box does not select all).
                        local from, to = value:find(preview, 1, true)
                        if from then value = value:sub(1, from - 1) .. value:sub(to + 1) end
                    end
                    Addon._importString = strtrim(value)
                end,
            },
            importBtn = {
                type = "execute", order = 13, name = L["Import"],
                disabled = function() return peekImport() == nil end,
                -- Only a name that already exists needs asking about.
                confirm = function()
                    local payload = peekImport()
                    if payload and Addon.Profiles:Exists(payload.name) then
                        return string.format(L["Profile '%s' already exists. Overwrite it?"], payload.name)
                    end
                    return false
                end,
                func = function()
                    local ok, res = Addon.Profiles:Import(Addon._importString or "")
                    if ok then
                        Addon._importString = nil
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

-- On/off of one HUD block; switching it on keeps the slot the grid gives it.
function Addon:BlockEnableOption(blockKey, order)
    local L = ns.L
    local MainWindow = Addon.MainWindow
    return {
        type = "toggle",
        name = L["Enable"],
        order = order or 1,
        get = function() return MainWindow:IsBlockActive(blockKey) end,
        set = function(_, v)
            MainWindow:SetBlockActive(blockKey, v)
            MainWindow:InvalidateRows()
            if v then MainWindow:SaveRows() end
            MainWindow:Refresh()
        end,
    }
end
