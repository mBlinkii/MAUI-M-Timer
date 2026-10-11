-- UI/MainWindow.lua
-- The HUD: one movable container hosting every module's display as a block.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local MainWindow = {}
Addon.MainWindow = MainWindow

local PANEL_PAD = 8 -- inner padding when the background/border/title is shown

-- Flat scratch arrays so the hot Layout path allocates nothing: the visible
-- frames of row i sit at (i - 1) * MAX_COLS + 1 .. + entryN[i], with the
-- horizontal span (x, width, reaching the right edge) each one gets.
local entryFrames, entryN = {}, {}
local entryX, entryW, entryRight = {}, {}, {}
local occupied = {}
local colX, colW, colShares = {}, {}, {}
local rowEnds = {} -- y of the boundary below each laid-out row, for the guides
local placed = {}

-- What the last Layout placed, to skip unchanged ones without building strings.
local lastFrames, lastH, lastN, lastX, lastW = {}, {}, {}, {}, {}
local lastCount, lastPad, lastSpacing, lastWidth

local function roundedHeight(frame)
    return frame and math.floor((frame:GetHeight() or 0) + 0.5) or 0
end

-- Whole HUD pixels; a file-level function, as Layout runs on every module update.
local function snap(v)
    return Addon.Widgets:Snap(MainWindow.frame, v)
end

-- Created lazily on first use.
function MainWindow:Get()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "MauiMPlusTimerHUD", UIParent, "BackdropTemplate")
    f:SetSize(220, 40)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(frame)
        -- The lock also applies in demo mode, so styling cannot drag the HUD.
        if not Addon.db.profile.ui.locked then
            frame:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        MainWindow:SavePosition()
    end)

    self.frame = f
    self:ApplyPosition()
    f:Hide() -- modules show the HUD once they have something to display
    return f
end

function MainWindow:ApplyPosition()
    if not self.frame then return end
    local ui = Addon.db.profile.ui
    local f = self.frame
    -- Scale first: the offsets are in the frame's scaled units and are snapped
    -- to whole pixels so every child lands on the pixel grid.
    f:SetScale(ui.scale or 1)
    f:ClearAllPoints()
    f:SetPoint(ui.point or "CENTER", UIParent, ui.point or "CENTER",
        Addon.Widgets:Snap(f, ui.x or 0), Addon.Widgets:Snap(f, ui.y or 0))
end

function MainWindow:SavePosition()
    if not self.frame then return end
    local ui = Addon.db.profile.ui
    local point, _, _, x, y = self.frame:GetPoint()
    ui.point, ui.x, ui.y = point, x, y
end

local ALIGNS = { left = true, center = true, right = true }

-- Every column picks its own alignment. Unset, the outer ones lean outwards,
-- the middle one centers and the rest lean towards the nearer edge.
function MainWindow:GetColumnAlign(col)
    local aligns = Addon.db.profile.ui.columnAlign
    local align = aligns and aligns[col]
    if ALIGNS[align] then return align end
    local cols = self:GetGrid().cols
    local mid = (cols + 1) / 2
    if cols == 1 or col == mid then return "center" end
    return col < mid and "left" or "right"
end

function MainWindow:SetColumnAlign(col, align)
    local ui = Addon.db.profile.ui
    ui.columnAlign = ui.columnAlign or {}
    ui.columnAlign[col] = align
    self:Refresh()
end

-- The grid column decides the alignment, not the module.
function MainWindow:GetColumnJustify(col)
    return string.upper(self:GetColumnAlign(col))
end

-- With an odd column count the middle column can stay on the HUD's center
-- line, whatever the other columns' shares are.
function MainWindow:IsCenterLocked()
    return Addon.db.profile.ui.centerColumn ~= false and self:GetGrid().cols % 2 == 1
end

function MainWindow:SetCenterLocked(locked)
    Addon.db.profile.ui.centerColumn = locked
    self:Refresh()
end

-- Fills outX/outW (1..cols) with each column's offset and width. shares holds
-- the per-column shares; centered, the middle column sits on the center line
-- and both sides get the same room, split by their own shares. The last
-- column of a side takes the rounding remainder.
-- Columns first..last share room by their shares, starting at x.
local function fillColumns(first, last, room, x, gap, shares, outX, outW, round)
    local sum = 0
    for c = first, last do sum = sum + shares[c] end
    local used = 0
    for c = first, last do
        outX[c] = x
        outW[c] = c == last and (room - used) or round(room * shares[c] / sum)
        used = used + outW[c]
        x = x + outW[c] + gap
    end
    return x
end

function MainWindow:ColumnGeometry(width, gap, shares, outX, outW, round)
    round = round or math.floor
    local cols = self:GetGrid().cols
    local avail = width - gap * (cols - 1)
    local total = 0
    for c = 1, cols do total = total + shares[c] end

    if self:IsCenterLocked() and cols > 1 then
        local mid = (cols + 1) / 2
        local midW = round(avail * shares[mid] / total)
        local leftRoom = round((avail - midW) / 2)
        local x = fillColumns(1, mid - 1, leftRoom, 0, gap, shares, outX, outW, round)
        outX[mid], outW[mid] = x, midW
        fillColumns(mid + 1, cols, avail - midW - leftRoom, x + midW + gap, gap, shares, outX, outW, round)
    else
        fillColumns(1, cols, avail, 0, gap, shares, outX, outW, round)
    end
end

-- The current shares of the active grid, into out (1..cols).
function MainWindow:GetColumnShares(out)
    for c = 1, self:GetGrid().cols do out[c] = self:GetColumnWidth(c) end
    return out
end

-- blockKey defaults to the lowered module name. A block that is not in the
-- grid is hidden anyway.
function MainWindow:GetJustifyH(moduleKey, blockKey)
    blockKey = blockKey or (moduleKey and moduleKey:lower())
    if blockKey then
        local cols = self:GetGrid().cols
        for _, row in ipairs(self:GetBlockRows()) do
            for c = 1, cols do
                if row[c] == blockKey then return self:GetColumnJustify(c) end
            end
        end
    end
    return "CENTER"
end

-- Restyles every module and relayouts.
function MainWindow:Refresh()
    Addon.Widgets:InvalidateStyle()
    -- First, so styles that depend on the real pixel scale see the new one.
    self:ApplyPosition()
    for _, module in Addon:IterateModules() do
        -- Enabled only: a disabled module's Restyle can re-show its hidden
        -- block from cached values.
        if module.UI and module.UI.Restyle and module:IsEnabled() then
            -- Isolated, so one faulty module cannot break the whole refresh.
            local ok, err = pcall(module.UI.Restyle, module.UI)
            if not ok then
                Addon:Error("Restyle failed for module %s: %s",
                    module:GetName(), tostring(err))
            end
        end
    end
    -- Re-feed the samples so bar fills, colors and deltas follow the change too.
    if Addon.Demo and Addon.Demo:IsActive() then
        Addon.Demo:Refresh()
    end
    self:Layout()
end

-- The HUD is a stack of configurable rows; each row is an array of up to
-- grid.cols keys (holes allowed), empty rows collapse.

-- Fallback placement order. Saved layouts are deliberately not AceDB
-- defaults, since AceDB merges arrays index-wise and would inject or strip
-- entries in user layouts.
local MODULE_BLOCKS = {
    "dungeon", "dungeonicon", "level", "affixes", "timer", "timerbar", "objectives",
    "forces", "deaths", "splits", "checkpoints", "brez", "bloodlust",
}
MainWindow.MODULE_BLOCKS = MODULE_BLOCKS

-- Pseudo keys; the frames are registered by UpdateSeparators.
local MAX_SEPARATORS = 8
local SEPARATOR_BLOCKS = {}
for i = 1, MAX_SEPARATORS do SEPARATOR_BLOCKS[i] = "separator" .. i end
local SEPARATOR_COLOR = { 1, 1, 1, 0.5 }
local NO_CONFIG = {}
MainWindow.MAX_SEPARATORS = MAX_SEPARATORS

local ORDERABLE = {}
for _, key in ipairs(MODULE_BLOCKS) do ORDERABLE[key] = true end
for _, key in ipairs(SEPARATOR_BLOCKS) do ORDERABLE[key] = true end

local MAX_ROWS = 15
local MAX_COLS = 9
MainWindow.MAX_ROWS, MainWindow.MAX_COLS = MAX_ROWS, MAX_COLS
local DEFAULT_COLS = 5

-- Starting layouts when nothing is saved: the standard layout at the default
-- column count, otherwise a narrow stack for few columns, a wide band for many.
local STANDARD_DEFAULT = {
    { "level", "dungeon", nil, nil, "affixes" },
    { nil, nil, "timer" }, { nil, nil, "timerbar" },
    { "objectives" }, { nil, nil, "forces" },
    { "deaths", nil, "splits", nil, "checkpoints" },
    { "brez", nil, nil, nil, "bloodlust" },
}
-- Column shares of the standard layout until the user sets their own.
local STANDARD_WIDTHS = { 50, 150 }
local NARROW_DEFAULT = {
    { "dungeonicon", "dungeon" }, { nil, "affixes" },
    { "level", "timer", "deaths" }, { "timerbar" },
    { nil, nil, "objectives" }, { "forces" }, { nil, nil, "splits" },
    { "brez", nil, "bloodlust" }, { nil, nil, "checkpoints" },
}
local WIDE_DEFAULT = {
    { "dungeonicon", "level", "dungeon", "affixes", "timer" },
    { "timerbar" }, { "forces" },
    { "deaths", "splits", "brez", "bloodlust", "checkpoints" }, { "objectives" },
}

-- One grid, sized by the user. Reused, so callers may compare it by identity;
-- the row cache keys on cols/rows as well.
local GRID = { id = "grid", rowsKey = "blockRows", widthKey = "width", width = 220 }

function MainWindow:GetGrid()
    local ui = Addon.db.profile.ui
    local cols = math.max(1, math.min(MAX_COLS, tonumber(ui.gridCols) or DEFAULT_COLS))
    GRID.cols = cols
    GRID.rows = math.max(1, math.min(MAX_ROWS, tonumber(ui.gridRows) or MAX_ROWS))
    -- Wide grids fill the last used row before opening a new one.
    GRID.pack = cols > 3
    GRID.default = (cols == DEFAULT_COLS and STANDARD_DEFAULT)
        or (cols > 3 and WIDE_DEFAULT) or NARROW_DEFAULT
    return GRID
end

function MainWindow:SetGridSize(cols, rows)
    local ui = Addon.db.profile.ui
    ui.gridCols, ui.gridRows = cols or ui.gridCols, rows or ui.gridRows
    self:InvalidateRows()
    self:ApplyWidth()
    self:Refresh()
end

-- The saved shares of the current grid; nothing saved means the standard
-- layout's at the default column count, even ones otherwise. An empty table
-- stands for even columns.
local function savedWidths(self)
    local widths = Addon.db.profile.ui.columnWidths
    local saved = widths and widths[self:GetGrid().id]
    if saved then return saved end
    return self:GetGrid().cols == DEFAULT_COLS and STANDARD_WIDTHS or nil
end

-- Share of the width per column in percent of an even split, per grid.
function MainWindow:GetColumnWidth(col)
    local w = savedWidths(self)
    w = w and w[col]
    return (type(w) == "number" and w > 0) and w or 100
end

-- live only relayouts, for a drag; the full restyle follows on release.
function MainWindow:SetColumnWidth(col, percent, live)
    local ui = Addon.db.profile.ui
    local id = self:GetGrid().id
    ui.columnWidths = ui.columnWidths or {}
    -- The first change starts from what is shown, the standard shares included.
    ui.columnWidths[id] = ui.columnWidths[id] or Addon.Utils.CopyTable(savedWidths(self) or {})
    ui.columnWidths[id][col] = percent ~= 100 and percent or nil
    if live then self:Layout() else self:Refresh() end
end

-- Even columns, not the standard shares.
function MainWindow:ResetColumnWidths()
    local ui = Addon.db.profile.ui
    ui.columnWidths = ui.columnWidths or {}
    ui.columnWidths[self:GetGrid().id] = {}
    self:Refresh()
end

function MainWindow:GetWidth()
    local grid = self:GetGrid()
    return math.max(120, Addon.db.profile.ui[grid.widthKey] or grid.width)
end

function MainWindow:SetWidthSetting(width)
    Addon.db.profile.ui[self:GetGrid().widthKey] = width
    self:ApplyWidth()
end

function MainWindow:ApplyWidth()
    if not self.blocks then return end
    local w = self:GetWidth()
    for _, b in pairs(self.blocks) do
        if b.frame then b.frame:SetWidth(w) end
    end
    self:Layout()
end

-- `order` only applies to keys that are not user-orderable; orderable blocks
-- take their position from GetBlockRows on every Layout.
function MainWindow:AddBlock(key, frame, order)
    self.blocks = self.blocks or {}
    self.blocks[key] = { frame = frame, order = order or 100 }
    -- Registering means the block just became active.
    self:InvalidateRows()
    self:Layout()
end

local SPLIT_GAP = 10 -- horizontal gap between two grid columns

-- The timer TEXT block can share a row; only the BAR stays full-row.
local FULL_ROW_BLOCKS = { timerbar = true, forces = true, objectives = true }

-- The objectives only need a whole row for their text list; as icons they
-- fit a cell. Separators share rows like any other element.
local function fullRowKey(key)
    if key == "objectives" then
        local settings = Addon.db.profile.modules.Objectives
        return not (settings and settings.layout and settings.layout ~= "text")
    end
    return key ~= nil and FULL_ROW_BLOCKS[key] == true
end

function MainWindow:IsFullRowKey(key)
    return fullRowKey(key)
end

-- The column of the row's full-row block, or nil when the row has none.
function MainWindow:GetFullRowColumn(row, cols)
    for c = 1, cols or self:GetGrid().cols do
        if row[c] and fullRowKey(row[c]) then return c end
    end
    return nil
end

-- The separator's number for a "separatorN" key, else nil.
function MainWindow:IsSeparatorKey(key)
    return type(key) == "string" and tonumber(key:match("^separator(%d)$")) or nil
end

function MainWindow:GetSeparatorCount()
    return math.max(0, math.min(MAX_SEPARATORS, tonumber(Addon.db.profile.ui.separatorCount) or 0))
end

-- Blocks that are a whole module of their own.
local BLOCK_MODULE_NAME = {
    objectives = "Objectives", forces = "EnemyForces", deaths = "Deaths",
    checkpoints = "Checkpoints",
}

-- Blocks that are one part of a module, switched by a flag in its settings.
-- optIn flags are off unless set; nested ones live in settings[field].on.
-- The module keeps running without them (Splits keeps recording, for one).
local SUB_BLOCKS = {
    dungeon     = { module = "Dungeon", field = "showName" },
    dungeonicon = { module = "Dungeon", field = "showIcon", optIn = true },
    level       = { module = "Dungeon", field = "showLevel" },
    affixes     = { module = "Dungeon", field = "showAffixes" },
    timer       = { module = "Timer", field = "showText" },
    timerbar    = { module = "Timer", field = "showBar" },
    splits      = { module = "Splits", field = "showText" },
    brez        = { module = "Cooldowns", field = "brez", nested = true },
    bloodlust   = { module = "Cooldowns", field = "lust", nested = true },
}

local function subFlag(settings, sub)
    local v = settings[sub.field]
    if sub.nested then return type(v) == "table" and v.on == true end
    if sub.optIn then return v == true end
    return v ~= false
end

-- A separator exists while its number is within the configured count.
function MainWindow:IsSeparatorEnabled(i)
    return i <= self:GetSeparatorCount()
end

-- Inactive blocks are dropped from the rows and never auto-placed, so the
-- element order doubles as the enable/disable control.
function MainWindow:IsBlockActive(key)
    if not key then return false end
    local sep = self:IsSeparatorKey(key)
    if sep then return self:IsSeparatorEnabled(sep) end
    local sub = SUB_BLOCKS[key]
    if sub then
        local module = Addon:GetModule(sub.module, true)
        return (module and module:IsEnabled() and subFlag(module:GetSettings(), sub)) or false
    end
    local name = BLOCK_MODULE_NAME[key]
    local module = name and Addon:GetModule(name, true)
    return (module and module:IsEnabled()) and true or false
end

-- Placing a block activates it, clearing its slot deactivates it. A part of a
-- module maps to its flag, enabling the module first if needed.
function MainWindow:SetBlockActive(key, active)
    if not key then return end
    -- Separators exist by count; placing one is all it takes to show it.
    if self:IsSeparatorKey(key) then return end
    local sub = SUB_BLOCKS[key]
    if sub then
        local module = Addon:GetModule(sub.module, true)
        if not (module and module.GetSettings) then return end
        local settings = module:GetSettings()
        if sub.nested then
            settings[sub.field] = settings[sub.field] or {}
            settings[sub.field].on = active
        else
            settings[sub.field] = active
        end
        if active and not module:IsEnabled() then
            -- Only the placed part comes back, not the module's other parts.
            for otherKey, other in pairs(SUB_BLOCKS) do
                if other.module == sub.module and otherKey ~= key then
                    if other.nested then
                        settings[other.field] = settings[other.field] or {}
                        settings[other.field].on = false
                    else
                        settings[other.field] = false
                    end
                end
            end
            settings.enabled = true
            Addon:ToggleModule(sub.module, true)
        end
        if module.ApplyBlocksShown then module:ApplyBlocksShown() end
        self:InvalidateRows()
        return
    end
    local name = BLOCK_MODULE_NAME[key]
    local module = name and Addon:GetModule(name, true)
    if module and module.GetSettings then
        module:GetSettings().enabled = active
        Addon:ToggleModule(name, active)
    end
end

-- Legacy rows stored { left = key, right = key }.
local function savedCell(s, c)
    if type(s) ~= "table" then return nil end
    return s[c] or (c == 1 and s.left) or (c == 2 and s.right) or nil
end

local function rowEmpty(row, cols)
    for c = 1, cols do
        if row[c] then return false end
    end
    return true
end

local function rowHasFullBlock(row, cols)
    for c = 1, cols do
        if row[c] and fullRowKey(row[c]) then return true end
    end
    return false
end

-- Finds a free slot for a block that lost its own: vertical takes the first
-- empty row below the used ones, horizontal packs into the last used row
-- first. Then any free slot, else a new row.
local function placeKey(rows, grid, key)
    local cols = grid.cols
    local full = fullRowKey(key)
    local lastUsed = 0
    for i = #rows, 1, -1 do
        if not rowEmpty(rows[i], cols) then lastUsed = i; break end
    end
    if grid.pack and not full and lastUsed > 0 and not rowHasFullBlock(rows[lastUsed], cols) then
        local row = rows[lastUsed]
        for c = 1, cols do
            if not row[c] then row[c] = key; return end
        end
    end
    for i = lastUsed + 1, #rows do
        if rowEmpty(rows[i], cols) then rows[i][1] = key; return end
    end
    for i = 1, #rows do
        local row = rows[i]
        if full then
            if rowEmpty(row, cols) then row[1] = key; return end
        elseif not rowHasFullBlock(row, cols) then
            for c = 1, cols do
                if not row[c] then row[c] = key; return end
            end
        end
    end
    rows[#rows + 1] = { key }
end

-- Only what was placed shows: switching a module on adds nothing here. At
-- least grid.rows entries, more only while full-row blocks overflow the grid.
-- Unknown and duplicate keys are dropped; a block pushed out of its row by a
-- full-row block moves to a free slot instead. Cached.
function MainWindow:GetBlockRows()
    local grid = self:GetGrid()
    local cols = grid.cols
    local saved = Addon.db.profile.ui[grid.rowsKey]
    if self._rowsCache and self._rowsCacheSource == saved and self._rowsCacheSize == grid.cols * 100 + grid.rows then
        return self._rowsCache
    end

    local rows, seen = {}, {}
    local function claim(key)
        if key and ORDERABLE[key] and not seen[key] then
            seen[key] = true
            return key
        end
        return nil
    end

    local source = type(saved) == "table" and saved or grid.default
    local count = grid.rows
    if source then count = math.min(MAX_ROWS, math.max(count, #source)) end
    for i = 1, count do
        local s = source and source[i] or nil
        local row = {}
        for c = 1, cols do
            row[c] = claim(savedCell(s, c))
        end
        rows[i] = row
    end

    -- A full-row block keeps its row alone, its neighbors move. It keeps its
    -- column, which aligns it.
    local displaced = {}
    for i = 1, count do
        local row = rows[i]
        for c = 1, cols do
            local key = row[c]
            if key and fullRowKey(key) then
                for o = 1, cols do
                    if row[o] and o ~= c then displaced[#displaced + 1] = row[o] end
                    row[o] = nil
                end
                row[c] = key
                break
            end
        end
    end
    for _, key in ipairs(displaced) do placeKey(rows, grid, key) end

    for i = #rows, grid.rows + 1, -1 do
        if not rowEmpty(rows[i], cols) then break end
        rows[i] = nil
    end

    self._rowsCache, self._rowsCacheSource, self._rowsCacheSize = rows, saved, grid.cols * 100 + grid.rows
    return rows
end

function MainWindow:InvalidateRows()
    self._rowsCache, self._rowsCacheSource, self._rowsCacheSize = nil, nil, nil
end

-- Clearing the saved rows makes the normalization fall back to the default.
function MainWindow:ResetBlockRows()
    Addon.db.profile.ui[self:GetGrid().rowsKey] = nil
    self:InvalidateRows()
    self:Refresh() -- grid columns may justify the moved text differently
end

-- An empty layout, unlike nil, which means the default one.
function MainWindow:ClearBlockRows()
    Addon.db.profile.ui[self:GetGrid().rowsKey] = {}
    self:InvalidateRows()
    self:Refresh()
end

-- nil clears the slot. The key is removed from any other slot first, so each
-- block exists exactly once. Whatever the new block covers leaves the table:
-- the block it replaces, the rest of the row for a full-row block, a full-row
-- neighbor for a normal one. Modules stay as they are, only the HUD drops them.
function MainWindow:SetBlockSlot(rowIndex, col, key)
    -- Placing shows the block, so a part or module that was off comes on.
    if key then self:SetBlockActive(key, true) end

    local grid = self:GetGrid()
    local cols = grid.cols
    local rows = self:GetBlockRows()
    local row = rows[rowIndex]
    if not row or col > cols then return end
    local fullCol = self:GetFullRowColumn(row, cols)
    local full = self:IsFullRowKey(key)

    if key then
        for _, r in ipairs(rows) do
            for c = 1, cols do
                if r[c] == key then r[c] = nil end
            end
        end
    end
    if key and not full and fullCol and fullCol ~= col then
        row[fullCol] = nil
    end
    if full then
        for c = 1, cols do row[c] = nil end
    end
    row[col] = key

    Addon.db.profile.ui[grid.rowsKey] = rows
    self:InvalidateRows()
    self:Refresh() -- columns align, so any move may change a justification
end

-- The border only exists together with the background, so bg.show alone
-- decides the padding.
function MainWindow:PanelInsets()
    local bg = Addon.db.profile.ui.bg or {}
    return bg.show and PANEL_PAD or 0
end

function MainWindow:ApplyPanel()
    if not self.frame then return end
    Addon.Widgets:ApplyPanel(self.frame, Addon.db.profile.ui.bg)
end

function MainWindow:CreateSeparator(i)
    local f = CreateFrame("Frame", "MauiMPlusTimerSeparator" .. i, self:Get())
    f:SetWidth(self:GetWidth())
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetPoint("CENTER", f, "CENTER", 0, 0)
    return { frame = f, line = line }
end

-- Syncs the separator frames with profile.ui.separators and registers each as
-- block "separatorN". Called from Layout before rendering; never calls Layout.
function MainWindow:UpdateSeparators()
    local cfgs = Addon.db.profile.ui.separators
    self.separators = self.separators or {}
    -- Decoration between modules, so they follow the modules' visibility and
    -- never float on their own outside a key.
    local active = (Addon.RunState and Addon.RunState:Get())
        or (Addon.Demo and Addon.Demo:IsActive()) or false
    for i = 1, MAX_SEPARATORS do
        local cfg = cfgs and cfgs[i] or NO_CONFIG
        local sep = self.separators[i]
        if self:IsSeparatorEnabled(i) and active then
            sep = sep or self:CreateSeparator(i)
            self.separators[i] = sep
            local h = math.max(1, cfg.height or 2)
            local w = math.max(0, cfg.width or 180)
            local c = cfg.color or SEPARATOR_COLOR
            if sep.c ~= c then
                sep.c = c
                sep.line:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
            end
            local justify = self:GetJustifyH(SEPARATOR_BLOCKS[i])
            -- Re-anchored only on a change: Layout runs every tick. Width 0
            -- spans the whole row.
            if sep.justify ~= justify or sep.w ~= w or sep.h ~= h then
                sep.justify, sep.w, sep.h = justify, w, h
                sep.frame:SetHeight(h)
                sep.line:ClearAllPoints()
                if w == 0 then
                    sep.line:SetHeight(h)
                    sep.line:SetPoint("LEFT", sep.frame, "LEFT", 0, 0)
                    sep.line:SetPoint("RIGHT", sep.frame, "RIGHT", 0, 0)
                else
                    sep.line:SetSize(w, h)
                    sep.line:SetPoint(justify, sep.frame, justify, 0, 0)
                end
            end
            sep.frame:Show()
            -- Register directly; AddBlock would recurse back into Layout.
            self.blocks = self.blocks or {}
            local key = SEPARATOR_BLOCKS[i]
            self.blocks[key] = self.blocks[key] or { frame = sep.frame, order = 100 }
        elseif sep then
            sep.frame:Hide()
        end
    end
end

-- Setup aid: thin lines on the column and row boundaries, so blocks can be
-- lined up against their cells. Drawn only after a real relayout.
local GUIDE_COLOR = { 1, 0.82, 0, 0.6 }

function MainWindow:SetShowGuides(show)
    Addon.db.profile.ui.showGuides = show or nil
    lastCount = nil -- forces the next Layout to redraw
    self:Layout()
end

function MainWindow:UpdateGuides(count, pad, width, cols)
    local hud = self.frame
    self.guides = self.guides or {}
    local n = 0
    local function line(x1, y1, x2, y2)
        n = n + 1
        local g = self.guides[n]
        if not g then
            g = hud:CreateTexture(nil, "OVERLAY", nil, 7)
            g:SetColorTexture(unpack(GUIDE_COLOR))
            self.guides[n] = g
        end
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", hud, "TOPLEFT", x1, -y1)
        g:SetSize(math.max(1, x2 - x1), math.max(1, y2 - y1))
        g:Show()
    end
    if Addon.db.profile.ui.showGuides and count > 0 then
        local bottom = rowEnds[count]
        -- Outline of the content area, then the column and row boundaries.
        line(pad, pad, pad + width, pad + 1)
        line(pad, bottom, pad + width, bottom + 1)
        line(pad, pad, pad + 1, bottom)
        line(pad + width - 1, pad, pad + width, bottom)
        for c = 1, cols - 1 do
            local x = pad + colX[c] + colW[c] + SPLIT_GAP / 2
            line(x, pad, x + 1, bottom)
        end
        for i = 1, count - 1 do
            line(pad, rowEnds[i], pad + width, rowEnds[i] + 1)
        end
    end
    for i = n + 1, #self.guides do self.guides[i]:Hide() end
end

-- Stacks the visible rows, resizes the container and shows or hides it.
function MainWindow:Layout()
    if not self.blocks then return end
    local hud = self:Get()

    self:UpdateSeparators()

    local width = snap(self:GetWidth())
    local pad = snap(self:PanelInsets())
    local spacing = snap(Addon.db.profile.ui.spacing or 2)
    local cols = self:GetGrid().cols
    self:ColumnGeometry(width, SPLIT_GAP, self:GetColumnShares(colShares), colX, colW, snap)

    -- A block without a slot may still be switched on and shown by its module;
    -- parked on a hidden frame it stays invisible instead of lingering where
    -- it was last placed.
    local rows = self:GetBlockRows()
    wipe(placed)
    for _, row in ipairs(rows) do
        for c = 1, cols do
            if row[c] then placed[row[c]] = true end
        end
    end
    if not self.parking then
        self.parking = CreateFrame("Frame", nil, hud)
        self.parking:Hide()
    end
    for key, b in pairs(self.blocks) do
        local parent = placed[key] and hud or self.parking
        if b.frame:GetParent() ~= parent then b.frame:SetParent(parent) end
    end

    -- Every column owns a fixed slice of the width, so a block always sits
    -- where it was placed. It may reach into empty (or hidden) neighbors, but
    -- only away from its aligned edge: a right-aligned block in column 2 still
    -- ends where column 2 ends. Centered blocks claim their neighbors first;
    -- a left- and a right-aligned block reaching into the same gap split it.
    -- Full-row blocks span the whole width.
    local count = 0
    for _, row in ipairs(self:GetBlockRows()) do
        local base, n = count * MAX_COLS, 0
        for c = 1, cols do
            local b = row[c] and self.blocks[row[c]]
            occupied[c] = (b and b.frame:IsShown()) and true or false
        end
        -- Centered spans first, so the others stop at them.
        for c = 1, cols do
            if occupied[c] == true and not fullRowKey(row[c]) and self:GetColumnJustify(c) == "CENTER" then
                local lo, hi = c, c
                while lo > 1 and hi < cols and not occupied[lo - 1] and not occupied[hi + 1] do
                    lo, hi = lo - 1, hi + 1
                    occupied[lo], occupied[hi] = c, c
                end
            end
        end
        for c = 1, cols do
            if occupied[c] == true then
                n = n + 1
                local k = base + n
                entryFrames[k] = self.blocks[row[c]].frame
                local lo, hi = c, c
                local justify = self:GetColumnJustify(c)
                if fullRowKey(row[c]) then
                    lo, hi = 1, cols
                elseif justify == "LEFT" then
                    while hi < cols and not occupied[hi + 1] do hi = hi + 1 end
                elseif justify == "RIGHT" then
                    while lo > 1 and not occupied[lo - 1] do lo = lo - 1 end
                else
                    while lo > 1 and occupied[lo - 1] == c do lo = lo - 1 end
                    while hi < cols and occupied[hi + 1] == c do hi = hi + 1 end
                end
                entryX[k] = colX[lo]
                -- Right edge as x; turned into a width below.
                entryW[k] = colX[hi] + colW[hi]
                entryRight[k] = hi == cols
                -- Only a right-aligned block can overlap the one before it,
                -- and only inside an empty gap: split that gap.
                if n > 1 and entryW[k - 1] + SPLIT_GAP > entryX[k] then
                    local mid = snap((entryW[k - 1] + entryX[k]) / 2)
                    entryW[k - 1] = mid - math.floor(SPLIT_GAP / 2)
                    entryX[k] = entryW[k - 1] + SPLIT_GAP
                end
            end
        end
        for k = base + 1, base + n do
            entryW[k] = entryW[k] - entryX[k]
        end
        if n > 0 then
            count = count + 1
            entryN[count] = n
        end
    end
    for i = count + 1, #entryN do
        entryN[i] = nil
    end

    for i = 1, count do
        local base = (i - 1) * MAX_COLS
        for k = base + 1, base + entryN[i] do
            entryFrames[k]:SetWidth(entryW[k])
        end
    end

    -- Modules call Layout on nearly every tick, almost always with unchanged
    -- sizes. Re-anchoring the HUD each time made the display jitter, so bail
    -- out unless something structural changed.
    local changed = count ~= lastCount or pad ~= lastPad
        or spacing ~= lastSpacing or width ~= lastWidth
    for i = 1, count do
        local n, base = entryN[i], (i - 1) * MAX_COLS
        if lastN[i] ~= n then changed = true end
        lastN[i] = n
        for k = base + 1, base + n do
            local f = entryFrames[k]
            local h = roundedHeight(f)
            if lastFrames[k] ~= f or lastH[k] ~= h or lastX[k] ~= entryX[k] or lastW[k] ~= entryW[k] then
                changed = true
            end
            lastFrames[k], lastH[k], lastX[k], lastW[k] = f, h, entryX[k], entryW[k]
        end
    end
    lastCount, lastPad, lastSpacing, lastWidth = count, pad, spacing, width
    if not changed then return end

    local y = pad
    for i = 1, count do
        local base = (i - 1) * MAX_COLS
        local h = 0
        for k = base + 1, base + entryN[i] do
            h = math.max(h, entryFrames[k]:GetHeight())
        end
        h = snap(h)
        for k = base + 1, base + entryN[i] do
            local f = entryFrames[k]
            -- Vertically centered in the row, so blocks with different font
            -- sizes share one middle line instead of one top edge.
            local dy = y + snap((h - f:GetHeight()) / 2)
            f:ClearAllPoints()
            -- Spans reaching the right edge anchor there, so rounding never
            -- leaves the last column short of the panel edge.
            if entryRight[k] then
                f:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -pad, -dy)
            else
                f:SetPoint("TOPLEFT", hud, "TOPLEFT", pad + entryX[k], -dy)
            end
        end
        y = y + h + spacing
        rowEnds[i] = y - spacing / 2
    end
    for i = count + 1, #rowEnds do rowEnds[i] = nil end

    if count > 0 then
        -- Even pixel counts, so the centered HUD and its centered rows keep
        -- whole-pixel edges.
        hud:SetSize(snap((width + pad * 2) / 2) * 2, snap(((y - spacing) + pad) / 2) * 2)
        self:ApplyPanel()
        self:UpdateGuides(count, pad, width, cols)
        hud:Show()
    else
        hud:Hide()
    end
end
