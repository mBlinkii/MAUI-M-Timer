-- UI/MainWindow.lua
-- The HUD: one movable container hosting every module's display as a block.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local MainWindow = {}
Addon.MainWindow = MainWindow

local PANEL_PAD = 8 -- inner padding when the background/border/title is shown

-- Parallel scratch arrays so the hot Layout path allocates nothing. entryLeft
-- is the only frame of a full-width row; entryRight is false there.
local entryLeft, entryRight = {}, {}

-- What the last Layout placed, to skip unchanged ones without building strings.
local lastLeft, lastRight, lastLeftH, lastRightH = {}, {}, {}, {}
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

local function alignToJustify(align)
    if align == "left" then return "LEFT" end
    if align == "right" then return "RIGHT" end
    return "CENTER"
end

-- "inherit" or no key falls back to the global alignment.
function MainWindow:GetJustifyH(moduleKey)
    local align
    if moduleKey then
        local m = Addon.db.profile.modules[moduleKey]
        align = m and m.align
    end
    if not align or align == "inherit" then
        align = Addon.db.profile.ui.align or "center"
    end
    return alignToJustify(align)
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

function MainWindow:GetWidth()
    return math.max(120, Addon.db.profile.ui.width or 220)
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

-- The HUD is a stack of configurable rows; profile.ui.blockRows stores
-- { left = key, right = key } per row, empty rows collapse.

-- Factory top-to-bottom order and single source of the default layout:
-- blockRows is deliberately not an AceDB default, since AceDB merges arrays
-- index-wise and would inject or strip entries in user layouts.
local MODULE_BLOCKS = {
    "dungeon", "timer", "timerbar", "objectives", "forces",
    "deaths", "splits", "checkpoints", "cooldowns",
}
MainWindow.MODULE_BLOCKS = MODULE_BLOCKS

-- Pseudo keys; the frames are registered by UpdateSeparators.
local SEPARATOR_BLOCKS = { "separator1", "separator2" }

local ORDERABLE = {}
for _, key in ipairs(MODULE_BLOCKS) do ORDERABLE[key] = true end
for _, key in ipairs(SEPARATOR_BLOCKS) do ORDERABLE[key] = true end

-- Every module and separator can have a row of its own.
local MAX_ROWS = #MODULE_BLOCKS + #SEPARATOR_BLOCKS
MainWindow.MAX_ROWS = MAX_ROWS

local SPLIT_GAP = 10 -- horizontal gap between the two blocks of a split row

-- The timer TEXT block can share a row; only the BAR stays full-row.
local FULL_ROW_BLOCKS = {
    timerbar = true, forces = true, objectives = true,
    separator1 = true, separator2 = true,
}

function MainWindow:IsFullRowKey(key)
    return key ~= nil and FULL_ROW_BLOCKS[key] == true
end

function MainWindow:IsSeparatorKey(key)
    return key == "separator1" or key == "separator2"
end

-- Splittable block keys only, for the auto-alignment on placement.
local BLOCK_MODULE = {
    dungeon = "Dungeon", timer = "Timer", deaths = "Deaths", splits = "Splits",
    checkpoints = "Checkpoints", cooldowns = "Cooldowns",
}

-- All module block keys; ties a block's active state to its module. "timerbar"
-- is absent on purpose -- it is a Timer sub-block, special-cased via showBar.
local BLOCK_MODULE_NAME = {
    dungeon = "Dungeon", timer = "Timer", objectives = "Objectives",
    forces = "EnemyForces", deaths = "Deaths", splits = "Splits",
    checkpoints = "Checkpoints", cooldowns = "Cooldowns",
}

-- Returns true when the alignment actually changed.
local function setModuleAlign(key, align)
    local name = key and BLOCK_MODULE[key]
    local module = name and Addon:GetModule(name, true)
    if not (module and module.GetSettings) then return false end
    local settings = module:GetSettings()
    if settings.align == align then return false end
    settings.align = align
    return true
end

-- Snaps the two modules of a split row to their side. Runs only from
-- SetBlockSlot, so a manual alignment afterwards is never overwritten.
function MainWindow:ApplyAutoAlign(row)
    if not (row.left and row.right) then return false end
    local changedLeft = setModuleAlign(row.left, "left")
    local changedRight = setModuleAlign(row.right, "right")
    return changedLeft or changedRight
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
    if key == "timerbar" then
        local timer = Addon:GetModule("Timer", true)
        return (timer and timer:IsEnabled()
            and timer:GetSettings().showBar ~= false) or false
    end
    -- Splits keeps recording best times when its HUD line is removed.
    if key == "splits" then
        local splits = Addon:GetModule("Splits", true)
        return (splits and splits:IsEnabled()
            and splits:GetSettings().showText ~= false) or false
    end
    local name = BLOCK_MODULE_NAME[key]
    local module = name and Addon:GetModule(name, true)
    return (module and module:IsEnabled()) and true or false
end

-- Placing a block activates it, clearing its slot deactivates it. The timer bar
-- maps to showBar (enabling the Timer module first if needed).
function MainWindow:SetBlockActive(key, active)
    if not key then return end
    if self:IsSeparatorKey(key) then
        local i = key == "separator1" and 1 or 2
        local cfgs = Addon.db.profile.ui.separators
        if cfgs and cfgs[i] then cfgs[i].enabled = active end
        return
    end
    if key == "timerbar" then
        local timer = Addon:GetModule("Timer", true)
        if not (timer and timer.GetSettings) then return end
        timer:GetSettings().showBar = active
        if active and not timer:IsEnabled() then
            timer:GetSettings().enabled = true
            Addon:ToggleModule("Timer", true)
        end
        if timer.UI and timer.UI.ApplyBarShown then timer.UI:ApplyBarShown() end
        return
    end
    if key == "splits" then
        local splits = Addon:GetModule("Splits", true)
        if not (splits and splits.GetSettings) then return end
        splits:GetSettings().showText = active
        if active and not splits:IsEnabled() then
            splits:GetSettings().enabled = true
            Addon:ToggleModule("Splits", true)
        end
        if splits.ApplyTextShown then splits:ApplyTextShown() end
        return
    end
    local name = BLOCK_MODULE_NAME[key]
    local module = name and Addon:GetModule(name, true)
    if module and module.GetSettings then
        module:GetSettings().enabled = active
        Addon:ToggleModule(name, active)
    end
end

-- Exactly MAX_ROWS entries; unknown and duplicate keys are dropped, missing
-- active blocks go onto the lowest free row so nothing can get lost. Cached.
function MainWindow:GetBlockRows()
    local saved = Addon.db.profile.ui.blockRows
    if self._rowsCache and self._rowsCacheSource == saved then
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

    for i = 1, MAX_ROWS do
        local s = (type(saved) == "table") and saved[i] or nil
        rows[i] = {
            left  = claim(type(s) == "table" and s.left or nil),
            right = claim(type(s) == "table" and s.right or nil),
        }
    end

    -- Guards hand-edited or pre-rule data: a full-row block in a right half
    -- moves left, or is unclaimed so the placement below gives it its own row.
    for i = 1, MAX_ROWS do
        local row = rows[i]
        if row.right and FULL_ROW_BLOCKS[row.right] then
            if not row.left then
                row.left, row.right = row.right, nil
            else
                seen[row.right] = nil
                row.right = nil
            end
        end
    end

    -- First empty row below the used ones, or any free left half.
    local function place(key)
        if seen[key] then return end
        local lastUsed = 0
        for i = 1, MAX_ROWS do
            if rows[i].left or rows[i].right then lastUsed = i end
        end
        for i = lastUsed + 1, MAX_ROWS do
            if not rows[i].left then
                rows[i].left, seen[key] = key, true
                return
            end
        end
        for i = 1, MAX_ROWS do
            if not rows[i].left then
                rows[i].left, seen[key] = key, true
                return
            end
        end
    end

    -- Keeps the bar on its own row below the timer text, including for layouts
    -- saved before the two were split.
    local function placeTimerBar()
        if seen["timerbar"] then return end
        local idx
        for i = 1, MAX_ROWS do
            if rows[i].left == "timer" or rows[i].right == "timer" then idx = i; break end
        end
        if not idx then place("timerbar"); return end
        for i = MAX_ROWS, idx + 2, -1 do
            rows[i] = rows[i - 1]
        end
        rows[idx + 1] = { left = "timerbar" }
        seen["timerbar"] = true
    end

    for _, key in ipairs(MODULE_BLOCKS) do
        if key ~= "timerbar" and self:IsBlockActive(key) then place(key) end
    end
    if self:IsBlockActive("timerbar") then placeTimerBar() end
    for i, key in ipairs(SEPARATOR_BLOCKS) do
        if self:IsSeparatorEnabled(i) then place(key) end
    end

    self._rowsCache, self._rowsCacheSource = rows, saved
    return rows
end

function MainWindow:InvalidateRows()
    self._rowsCache, self._rowsCacheSource = nil, nil
end

-- Clearing the saved rows makes the normalization fall back to MODULE_BLOCKS.
function MainWindow:ResetBlockRows()
    Addon.db.profile.ui.blockRows = nil
    self:InvalidateRows()
    self:Layout()
end

-- nil clears the slot. The key is removed from any other slot first, so each
-- block exists exactly once; a full-row block always claims the left half.
function MainWindow:SetBlockSlot(rowIndex, side, key)
    -- Must run before reading the rows, or the normalization drops the block
    -- as inactive.
    if key then self:SetBlockActive(key, true) end

    local rows = self:GetBlockRows()
    local row = rows[rowIndex]
    if not row then return end
    if side == "right" and key and self:IsFullRowKey(row.left) then
        return -- no right-hand neighbor next to a full-row block
    end

    local prev = row[side]

    if key then
        for _, r in ipairs(rows) do
            if r.left == key then r.left = nil end
            if r.right == key then r.right = nil end
        end
    end
    if key and self:IsFullRowKey(key) then
        side = "left"
        row.right = nil
    end
    row[side] = key

    -- Clearing deactivates the previous block instead of re-placing it; a
    -- replacement leaves it active so it restacks elsewhere.
    if not key and prev then
        self:SetBlockActive(prev, false)
    end

    local aligned = self:ApplyAutoAlign(row)

    Addon.db.profile.ui.blockRows = rows
    self:InvalidateRows()
    if aligned then
        self:Refresh() -- restyle so the snapped alignment shows immediately
    else
        self:Layout()
    end
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
    local half = snap((width - SPLIT_GAP) / 2)

    -- A split row whose second block is hidden collapses to full width.
    local count = 0
    for _, row in ipairs(self:GetBlockRows()) do
        local lb = row.left and self.blocks[row.left]
        local rb = row.right and self.blocks[row.right]
        local lf = lb and lb.frame:IsShown() and lb.frame or nil
        local rf = rb and rb.frame:IsShown() and rb.frame or nil
        if lf or rf then
            count = count + 1
            if lf and rf then
                entryLeft[count], entryRight[count] = lf, rf
            else
                entryLeft[count], entryRight[count] = lf or rf, false
            end
        end
    end
    for i = count + 1, #entryLeft do
        entryLeft[i], entryRight[i] = nil, nil
    end

    for i = 1, count do
        if entryRight[i] then
            entryLeft[i]:SetWidth(half)
            entryRight[i]:SetWidth(half)
        else
            entryLeft[i]:SetWidth(width)
        end
    end

    -- Modules call Layout on nearly every tick, almost always with unchanged
    -- sizes. Re-anchoring the HUD each time made the display jitter, so bail
    -- out unless something structural changed.
    local changed = count ~= lastCount or pad ~= lastPad
        or spacing ~= lastSpacing or width ~= lastWidth
    for i = 1, count do
        local lf, rf = entryLeft[i], entryRight[i]
        local lh, rh = roundedHeight(lf), roundedHeight(rf)
        if lastLeft[i] ~= lf or lastRight[i] ~= rf or lastLeftH[i] ~= lh or lastRightH[i] ~= rh then
            changed = true
        end
        lastLeft[i], lastRight[i], lastLeftH[i], lastRightH[i] = lf, rf, lh, rh
    end
    lastCount, lastPad, lastSpacing, lastWidth = count, pad, spacing, width
    if not changed then return end

    local y = pad
    for i = 1, count do
        local lf, rf = entryLeft[i], entryRight[i]
        lf:ClearAllPoints()
        if rf then
            lf:SetPoint("TOPLEFT", hud, "TOPLEFT", pad, -y)
            rf:ClearAllPoints()
            rf:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -pad, -y)
            y = y + snap(math.max(lf:GetHeight(), rf:GetHeight())) + spacing
        else
            lf:SetPoint("TOP", hud, "TOP", 0, -y)
            y = y + snap(lf:GetHeight()) + spacing
        end
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
