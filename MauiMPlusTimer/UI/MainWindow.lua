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

-- What the last Layout placed, to skip unchanged ones without building strings.
local lastFrames, lastH, lastN, lastX, lastW = {}, {}, {}, {}, {}
local lastCount, lastPad, lastSpacing, lastWidth

local function roundedHeight(frame)
    return frame and math.floor((frame:GetHeight() or 0) + 0.5) or 0
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

-- Columns 2 and 4 of the horizontal grid sit between two others, so they
-- may lean either way.
MainWindow.ADJUSTABLE_COLUMNS = { 2, 4 }

function MainWindow:GetColumnAlign(col)
    local align = Addon.db.profile.ui["horizontalAlign" .. col]
    if align == "left" or align == "right" then return align end
    return col == 2 and "left" or "right"
end

function MainWindow:SetColumnAlign(col, align)
    Addon.db.profile.ui["horizontalAlign" .. col] = align
    self:Refresh()
end

-- The grid column decides the alignment, not the module.
function MainWindow:GetColumnJustify(col)
    local grid = self:GetGrid()
    if col == 1 then return "LEFT" end
    if col == grid.cols then return "RIGHT" end
    if col == (grid.cols + 1) / 2 then return "CENTER" end
    return self:GetColumnAlign(col) == "right" and "RIGHT" or "LEFT"
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
    self:ApplyPosition()
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
local SEPARATOR_BLOCKS = { "separator1", "separator2" }

local ORDERABLE = {}
for _, key in ipairs(MODULE_BLOCKS) do ORDERABLE[key] = true end
for _, key in ipairs(SEPARATOR_BLOCKS) do ORDERABLE[key] = true end

-- Every block can have a row of its own in the vertical grid.
local MAX_ROWS = #MODULE_BLOCKS + #SEPARATOR_BLOCKS
local MAX_COLS = 5
MainWindow.MAX_ROWS, MainWindow.MAX_COLS = MAX_ROWS, MAX_COLS

-- Each orientation keeps its own layout and width.
local GRIDS = {
    vertical   = { cols = 3, rows = MAX_ROWS, rowsKey = "blockRows", widthKey = "width", width = 220,
        default = {
            { "dungeonicon", "dungeon" }, { nil, "affixes" },
            { "level", "timer", "deaths" }, { "timerbar" },
            { nil, nil, "objectives" }, { "forces" }, { nil, nil, "splits" },
            { "brez", nil, "bloodlust" }, { nil, nil, "checkpoints" },
        },
    },
    horizontal = { cols = 5, rows = 3, rowsKey = "blockRowsHorizontal", widthKey = "widthHorizontal",
        width = 560, pack = true,
        default = {
            { "dungeonicon", "level", "dungeon", "affixes", "timer" },
            { "timerbar" }, { "forces" },
            { "deaths", "splits", "brez", "bloodlust", "checkpoints" }, { "objectives" },
        },
    },
}
MainWindow.GRIDS = GRIDS

function MainWindow:GetOrientation()
    return Addon.db.profile.ui.orientation == "horizontal" and "horizontal" or "vertical"
end

function MainWindow:GetGrid()
    return GRIDS[self:GetOrientation()]
end

function MainWindow:SetOrientation(orientation)
    Addon.db.profile.ui.orientation = orientation
    self:InvalidateRows()
    self:ApplyWidth()
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
local FULL_ROW_BLOCKS = {
    timerbar = true, forces = true, objectives = true,
    separator1 = true, separator2 = true,
}

function MainWindow:IsFullRowKey(key)
    return key ~= nil and FULL_ROW_BLOCKS[key] == true
end

-- The column of the row's full-row block, or nil when the row has none.
function MainWindow:GetFullRowColumn(row, cols)
    for c = 1, cols or self:GetGrid().cols do
        if row[c] and FULL_ROW_BLOCKS[row[c]] then return c end
    end
    return nil
end

function MainWindow:IsSeparatorKey(key)
    return key == "separator1" or key == "separator2"
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

function MainWindow:IsSeparatorEnabled(i)
    local cfgs = Addon.db.profile.ui.separators
    return (cfgs and cfgs[i] and cfgs[i].enabled == true) or false
end

-- Inactive blocks are dropped from the rows and never auto-placed, so the
-- element order doubles as the enable/disable control.
function MainWindow:IsBlockActive(key)
    if not key then return false end
    if self:IsSeparatorKey(key) then
        return self:IsSeparatorEnabled(key == "separator1" and 1 or 2)
    end
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
    if self:IsSeparatorKey(key) then
        local i = key == "separator1" and 1 or 2
        local cfgs = Addon.db.profile.ui.separators
        if cfgs and cfgs[i] then cfgs[i].enabled = active end
        return
    end
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

-- At least grid.rows entries, more only while full-row blocks overflow the
-- grid. Unknown and duplicate keys are dropped, missing active blocks go into
-- free slots so nothing can get lost. Cached.
function MainWindow:GetBlockRows()
    local grid = self:GetGrid()
    local cols = grid.cols
    local saved = Addon.db.profile.ui[grid.rowsKey]
    if self._rowsCache and self._rowsCacheSource == saved and self._rowsCacheGrid == grid then
        return self._rowsCache
    end

    local rows, seen = {}, {}
    local function claim(key)
        if key and ORDERABLE[key] and not seen[key] and self:IsBlockActive(key) then
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

    -- A full-row block keeps its row alone, its neighbors are placed again
    -- below. It keeps its column, which aligns it.
    for i = 1, count do
        local row = rows[i]
        for c = 1, cols do
            local key = row[c]
            if key and FULL_ROW_BLOCKS[key] then
                for o = 1, cols do
                    if row[o] and o ~= c then seen[row[o]] = nil end
                    row[o] = nil
                end
                row[c] = key
                break
            end
        end
    end

    local function isFullRow(row)
        return self:GetFullRowColumn(row, cols) ~= nil
    end

    -- Vertical takes the first empty row below the used ones, horizontal packs
    -- into the last used row first. Then any free slot, else a new row.
    local function place(key)
        if seen[key] then return end
        seen[key] = true
        local full = FULL_ROW_BLOCKS[key]
        local lastUsed = 0
        for i = #rows, 1, -1 do
            if not rowEmpty(rows[i], cols) then lastUsed = i; break end
        end
        if grid.pack and not full and lastUsed > 0 and not isFullRow(rows[lastUsed]) then
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
            elseif not isFullRow(row) then
                for c = 1, cols do
                    if not row[c] then row[c] = key; return end
                end
            end
        end
        rows[#rows + 1] = { key }
    end

    -- Keeps the bar on its own row below the timer text, including for layouts
    -- saved before the two were split.
    local function placeTimerBar()
        if seen["timerbar"] then return end
        local idx
        for i = 1, #rows do
            for c = 1, cols do
                if rows[i][c] == "timer" then idx = i end
            end
            if idx then break end
        end
        if not idx then place("timerbar"); return end
        seen["timerbar"] = true
        if rows[idx + 1] and rowEmpty(rows[idx + 1], cols) then
            rows[idx + 1][1] = "timerbar"
        else
            table.insert(rows, idx + 1, { "timerbar" })
        end
    end

    for _, key in ipairs(MODULE_BLOCKS) do
        if key ~= "timerbar" and self:IsBlockActive(key) then place(key) end
    end
    if self:IsBlockActive("timerbar") then placeTimerBar() end
    for i, key in ipairs(SEPARATOR_BLOCKS) do
        if self:IsSeparatorEnabled(i) then place(key) end
    end

    for i = #rows, grid.rows + 1, -1 do
        if not rowEmpty(rows[i], cols) then break end
        rows[i] = nil
    end

    self._rowsCache, self._rowsCacheSource, self._rowsCacheGrid = rows, saved, grid
    return rows
end

function MainWindow:InvalidateRows()
    self._rowsCache, self._rowsCacheSource, self._rowsCacheGrid = nil, nil, nil
end

-- Clearing the saved rows makes the normalization fall back to MODULE_BLOCKS.
function MainWindow:ResetBlockRows()
    Addon.db.profile.ui[self:GetGrid().rowsKey] = nil
    self:InvalidateRows()
    self:Refresh() -- grid columns may justify the moved text differently
end

-- Keeps where the normalization just placed a block switched on elsewhere.
function MainWindow:SaveRows()
    Addon.db.profile.ui[self:GetGrid().rowsKey] = self:GetBlockRows()
    self:InvalidateRows()
end

-- nil clears the slot. The key is removed from any other slot first, so each
-- block exists exactly once; a full-row block clears the rest of its row.
function MainWindow:SetBlockSlot(rowIndex, col, key)
    -- Must run before reading the rows, or the normalization drops the block
    -- as inactive.
    if key then self:SetBlockActive(key, true) end

    local grid = self:GetGrid()
    local cols = grid.cols
    local rows = self:GetBlockRows()
    local row = rows[rowIndex]
    if not row or col > cols then return end
    local fullCol = self:GetFullRowColumn(row, cols)
    local full = self:IsFullRowKey(key)
    -- A block placed next to a full-row block pushes it to another row; it
    -- stays active, so the normalization places it again.
    if key and not full and fullCol and fullCol ~= col then
        row[fullCol] = nil
    end

    local prev = row[col]

    if key then
        for _, r in ipairs(rows) do
            for c = 1, cols do
                if r[c] == key then r[c] = nil end
            end
        end
    end
    if full then
        for c = 1, cols do row[c] = nil end
    end
    row[col] = key

    -- Clearing deactivates the previous block instead of re-placing it; a
    -- replacement leaves it active so it restacks elsewhere.
    if not key and prev then
        self:SetBlockActive(prev, false)
    end

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
    for i = 1, 2 do
        local cfg = cfgs and cfgs[i]
        local sep = self.separators[i]
        if cfg and cfg.enabled and active then
            sep = sep or self:CreateSeparator(i)
            self.separators[i] = sep
            local h = math.max(1, cfg.height or 2)
            local w = math.max(1, cfg.width or 180)
            local c = cfg.color or { 1, 1, 1, 0.5 }
            sep.frame:SetHeight(h)
            sep.line:SetSize(w, h)
            sep.line:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
            local key = "separator" .. i
            local justify = self:GetJustifyH(key)
            if sep.justify ~= justify then -- Layout runs every tick
                sep.justify = justify
                sep.line:ClearAllPoints()
                sep.line:SetPoint(justify, sep.frame, justify, 0, 0)
            end
            sep.frame:Show()
            -- Register directly; AddBlock would recurse back into Layout.
            self.blocks = self.blocks or {}
            self.blocks["separator" .. i] = self.blocks["separator" .. i]
                or { frame = sep.frame, order = 100 }
        elseif sep then
            sep.frame:Hide()
        end
    end
end

-- Stacks the visible rows, resizes the container and shows or hides it.
function MainWindow:Layout()
    if not self.blocks then return end
    local hud = self:Get()

    self:UpdateSeparators()

    local function snap(v) return Addon.Widgets:Snap(hud, v) end
    local width = snap(self:GetWidth())
    local pad = snap(self:PanelInsets())
    local spacing = snap(Addon.db.profile.ui.spacing or 2)
    local cols = self:GetGrid().cols
    local cell = snap((width - SPLIT_GAP * (cols - 1)) / cols)
    local step = cell + SPLIT_GAP

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
            if occupied[c] == true and not FULL_ROW_BLOCKS[row[c]] and self:GetColumnJustify(c) == "CENTER" then
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
                if FULL_ROW_BLOCKS[row[c]] then
                    lo, hi = 1, cols
                elseif justify == "LEFT" then
                    while hi < cols and not occupied[hi + 1] do hi = hi + 1 end
                elseif justify == "RIGHT" then
                    while lo > 1 and not occupied[lo - 1] do lo = lo - 1 end
                else
                    while lo > 1 and occupied[lo - 1] == c do lo = lo - 1 end
                    while hi < cols and occupied[hi + 1] == c do hi = hi + 1 end
                end
                entryX[k] = (lo - 1) * step
                -- Right edge as x; turned into a width below.
                entryW[k] = hi == cols and width or hi * step - SPLIT_GAP
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
    end

    if count > 0 then
        -- Even pixel counts, so the centered HUD and its centered rows keep
        -- whole-pixel edges.
        hud:SetSize(snap((width + pad * 2) / 2) * 2, snap(((y - spacing) + pad) / 2) * 2)
        self:ApplyPanel()
        hud:Show()
    else
        hud:Hide()
    end
end
