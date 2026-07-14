-- UI/MainWindow.lua
-- The HUD: a single movable container that hosts every module's display as an
-- anchored block. Created lazily on first access to avoid spending a frame
-- before anything is shown.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local MainWindow = {}
Addon.MainWindow = MainWindow

local PANEL_PAD = 8 -- inner padding when the background/border/title is shown

-- Reused scratch list + hoisted comparator for Layout(), so the frequently
-- called layout pass allocates neither a new table nor a new closure per call.
-- Reusable scratch for Layout's render entries (parallel arrays, so the hot
-- Layout path allocates no tables): entryLeft[i] holds the (only) frame of a
-- full-width row; entryRight[i] holds the right frame of a split row or false.
local entryLeft, entryRight = {}, {}

-- Return the HUD container, creating it on first use.
function MainWindow:Get()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "MauiMPlusTimerHUD", UIParent, "BackdropTemplate")
    f:SetSize(220, 40)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(frame)
        -- The lock option is authoritative in every mode - including demo
        -- mode, so the HUD cannot be dragged accidentally while styling.
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
    -- Start hidden; modules show the HUD when they have something to display.
    f:Hide()
    return f
end

-- Apply the stored position and scale.
function MainWindow:ApplyPosition()
    if not self.frame then return end
    local ui = Addon.db.profile.ui
    self.frame:ClearAllPoints()
    self.frame:SetPoint(ui.point or "CENTER", UIParent, ui.point or "CENTER", ui.x or 0, ui.y or 0)
    self.frame:SetScale(ui.scale or 1)
end

-- Persist the current position back to the profile.
function MainWindow:SavePosition()
    if not self.frame then return end
    local ui = Addon.db.profile.ui
    local point, _, _, x, y = self.frame:GetPoint()
    ui.point, ui.x, ui.y = point, x, y
end

-- Translate an alignment value into a FontString justification.
local function alignToJustify(align)
    if align == "left" then return "LEFT" end
    if align == "right" then return "RIGHT" end
    return "CENTER"
end

-- Resolve the justification for a module (its own setting, or "inherit" -> the
-- global alignment). Called with no key it returns the global justification.
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

-- Re-apply styling (alignment, fonts) to every module and relayout the HUD.
-- Used after a global or per-module alignment/style change.
function MainWindow:Refresh()
    Addon.Widgets:InvalidateStyle() -- styles may have changed; drop the cache
    for _, module in Addon:IterateModules() do
        -- Only restyle ACTIVE modules: a disabled module's Restyle can re-show
        -- its (hidden) block from cached values, which would resurrect blocks the
        -- current profile turned off.
        if module.UI and module.UI.Restyle and module:IsEnabled() then
            -- Isolate each module's restyle so one faulty module cannot break
            -- the whole refresh, but surface the error instead of hiding it.
            local ok, err = pcall(module.UI.Restyle, module.UI)
            if not ok then
                Addon:Error("Restyle failed for module %s: %s",
                    module:GetName(), tostring(err))
            end
        end
    end
    -- In demo mode, re-feed the synthetic values so dynamic content (bar fills,
    -- colors, deltas) reflects the change live, not just the static styling.
    if Addon.Demo and Addon.Demo:IsActive() then
        Addon.Demo:Refresh()
    end
    self:ApplyPosition()
    self:Layout()
end

-- The configured HUD width (shared by all module blocks).
function MainWindow:GetWidth()
    return math.max(120, Addon.db.profile.ui.width or 220)
end

-- Re-apply the configured width to every registered block and restack.
function MainWindow:ApplyWidth()
    if not self.blocks then return end
    local w = self:GetWidth()
    for _, b in pairs(self.blocks) do
        if b.frame then b.frame:SetWidth(w) end
    end
    self:Layout()
end

-- Register a module's display block so the HUD can stack the blocks vertically.
-- `order` is only the fallback for keys that are not user-orderable; the
-- orderable module blocks get their effective order from the configured list
-- (see GetBlockRows below) on every Layout.
function MainWindow:AddBlock(key, frame, order)
    self.blocks = self.blocks or {}
    self.blocks[key] = { frame = frame, order = order or 100 }
    -- A module registering its block means it just became active; drop the
    -- cached rows so the (active-state-dependent) normalization includes it.
    self:InvalidateRows()
    self:Layout()
end

-- Block rows -------------------------------------------------------------------
-- The HUD is a stack of user-configurable ROWS (options: General -> Element
-- order). Each row holds one block at full width or two blocks side by side
-- (left/right half); rows without visible content collapse. Separator lines
-- take part as normal entries ("separator1"/"separator2") while enabled and
-- always occupy a full row. profile.ui.blockRows stores
-- { left = key, right = key } per row.

-- User-orderable module blocks in FACTORY top-to-bottom order (forces bar
-- below the objectives). This is the single source of the default layout:
-- profile.ui.blockRows is deliberately NOT part of the AceDB defaults, because
-- AceDB would merge default rows index-wise into user layouts (injecting or
-- stripping entries); an empty/missing table simply falls back to this order.
local MODULE_BLOCKS = {
    "dungeon", "timer", "timerbar", "objectives", "forces",
    "deaths", "splits", "checkpoints", "cooldowns",
}
MainWindow.MODULE_BLOCKS = MODULE_BLOCKS

-- Pseudo block keys of the two separator lines (frames are registered by
-- UpdateSeparators).
local SEPARATOR_BLOCKS = { "separator1", "separator2" }

-- All orderable keys, for filtering saved rows.
local ORDERABLE = {}
for _, key in ipairs(MODULE_BLOCKS) do ORDERABLE[key] = true end
for _, key in ipairs(SEPARATOR_BLOCKS) do ORDERABLE[key] = true end

-- Number of configurable rows: every module and separator can have its own.
local MAX_ROWS = #MODULE_BLOCKS + #SEPARATOR_BLOCKS
MainWindow.MAX_ROWS = MAX_ROWS

-- Horizontal gap between the two blocks of a split row.
local SPLIT_GAP = 10

-- Blocks that always occupy a FULL row (no left/right neighbor): the wide
-- bar/list modules plus the separator lines.
-- The timer TEXT block is half-row capable (it can share a row); only the timer
-- BAR stays full-row (nothing sits next to it).
local FULL_ROW_BLOCKS = {
    timerbar = true, forces = true, objectives = true,
    separator1 = true, separator2 = true,
}

-- Whether `key` must occupy a full row of its own.
function MainWindow:IsFullRowKey(key)
    return key ~= nil and FULL_ROW_BLOCKS[key] == true
end

-- Whether `key` names a separator entry.
function MainWindow:IsSeparatorKey(key)
    return key == "separator1" or key == "separator2"
end

-- Module (AceAddon) name per splittable block key, for the automatic
-- alignment on placement (full-row blocks and separators have no entry).
local BLOCK_MODULE = {
    dungeon = "Dungeon", timer = "Timer", deaths = "Deaths", splits = "Splits",
    checkpoints = "Checkpoints", cooldowns = "Cooldowns",
}

-- Module (AceAddon) name for EVERY module block key (full-row ones included),
-- used to derive a block's active state from its module and to enable/disable
-- the module when the block is placed/cleared in the element order. "timerbar"
-- is intentionally absent: it is a sub-block of the Timer module (see
-- IsBlockActive/SetBlockActive, which special-case it via the showBar setting).
local BLOCK_MODULE_NAME = {
    dungeon = "Dungeon", timer = "Timer", objectives = "Objectives",
    forces = "EnemyForces", deaths = "Deaths", splits = "Splits",
    checkpoints = "Checkpoints", cooldowns = "Cooldowns",
}

-- Set a block's module alignment; returns true when it actually changed.
local function setModuleAlign(key, align)
    local name = key and BLOCK_MODULE[key]
    local module = name and Addon:GetModule(name, true)
    if not (module and module.GetSettings) then return false end
    local settings = module:GetSettings()
    if settings.align == align then return false end
    settings.align = align
    return true
end

-- Auto-alignment on placement: when a row holds two modules, snap them to
-- their side (left half -> left aligned, right half -> right aligned). Runs
-- ONLY from SetBlockSlot, i.e. the moment something is re-placed in the
-- element-order options - manual alignment changes afterwards stay untouched,
-- and full-row blocks are never affected (they cannot share a row).
-- Returns true when any alignment changed.
function MainWindow:ApplyAutoAlign(row)
    if not (row.left and row.right) then return false end
    local changedLeft = setModuleAlign(row.left, "left")
    local changedRight = setModuleAlign(row.right, "right")
    return changedLeft or changedRight
end

-- Whether separator line i (1 or 2) is enabled in the profile.
function MainWindow:IsSeparatorEnabled(i)
    local cfgs = Addon.db.profile.ui.separators
    return (cfgs and cfgs[i] and cfgs[i].enabled == true) or false
end

-- Whether a block is "active", i.e. should take part in the element-order list.
-- Module blocks are active while their module is enabled; the timer bar sub-
-- block is active while the Timer module is enabled AND its bar is not hidden;
-- separators while enabled. Inactive blocks are dropped from the rows and are
-- not auto-placed, so the element order doubles as the enable/disable control.
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
    -- Splits is a recording module: removing it from the order only hides its
    -- HUD line (showText), it keeps recording best times for other displays.
    if key == "splits" then
        local splits = Addon:GetModule("Splits", true)
        return (splits and splits:IsEnabled()
            and splits:GetSettings().showText ~= false) or false
    end
    local name = BLOCK_MODULE_NAME[key]
    local module = name and Addon:GetModule(name, true)
    return (module and module:IsEnabled()) and true or false
end

-- Enable or disable the block behind `key`. Placing a block activates it,
-- clearing its slot deactivates it (see SetBlockSlot). Modules toggle their
-- AceAddon state (and persist it, matching the per-module enable option); the
-- timer bar toggles the Timer showBar setting (enabling the Timer module first
-- when the bar is placed while the module was off); separators toggle enabled.
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

-- Normalized copy of the configured rows: exactly MAX_ROWS entries; unknown
-- and duplicate keys are dropped. Blocks that must be placed but are not -
-- modules always, separators while enabled - go onto the lowest free row, so
-- nothing can get lost. The result is cached until the rows change.
function MainWindow:GetBlockRows()
    local saved = Addon.db.profile.ui.blockRows
    if self._rowsCache and self._rowsCacheSource == saved then
        return self._rowsCache
    end

    local rows, seen = {}, {}
    local function claim(key)
        -- Inactive (disabled) blocks are dropped, so the element order reflects
        -- exactly the enabled modules.
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

    -- A full-row block can never sit in a right half (guards hand-edited or
    -- pre-rule saved data): move it to the free left half, or unclaim it so
    -- the placement below finds it a row of its own.
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

    -- Place a missing key on the first empty row below the used ones (or,
    -- packed layouts, on any free left half).
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

    -- Keep the timer bar glued to its own row directly below the timer text,
    -- even for layouts/presets saved before the split (where it is not listed).
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

    -- Auto-place any ACTIVE block not yet positioned (disabled blocks stay out).
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

-- Drop the cached normalized rows (rows changed, separator toggled or the
-- profile switched).
function MainWindow:InvalidateRows()
    self._rowsCache, self._rowsCacheSource = nil, nil
end

-- Reset the row layout to the factory default (one block per row in
-- MODULE_BLOCKS order) and restack: clearing the saved rows makes the
-- normalization fall back to that order. Enabled separators re-place
-- themselves on the lowest free rows.
function MainWindow:ResetBlockRows()
    Addon.db.profile.ui.blockRows = nil
    self:InvalidateRows()
    self:Layout()
end

-- Assign `key` (or nil to clear) to one side of a row, persist and restack.
-- The key is removed from any other slot first (each block exists exactly
-- once). A full-row block (timer, forces, objectives, separators) always
-- claims the left half and clears the right one; nothing can be placed next
-- to it.
function MainWindow:SetBlockSlot(rowIndex, side, key)
    -- Activate a block being placed BEFORE reading the rows, so the
    -- normalization keeps it instead of dropping it as inactive.
    if key then self:SetBlockActive(key, true) end

    local rows = self:GetBlockRows()
    local row = rows[rowIndex]
    if not row then return end
    if side == "right" and key and self:IsFullRowKey(row.left) then
        return -- no right-hand neighbor next to a full-row block
    end

    local prev = row[side] -- what we are replacing or clearing

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

    -- Clearing a slot (to "-") deactivates the block that was there and leaves
    -- the slot empty, instead of re-placing it on a free row. A replacement
    -- (key set) leaves the displaced block active so it restacks as before.
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

-- Inner padding reserved around the blocks when the panel is decorated. The
-- border only exists together with the background, so the padding tracks
-- bg.show alone.
function MainWindow:PanelInsets()
    local bg = Addon.db.profile.ui.bg or {}
    return bg.show and PANEL_PAD or 0
end

-- Apply the optional HUD panel (background + border) from profile.ui.bg via the
-- shared Widgets:ApplyPanel helper.
function MainWindow:ApplyPanel()
    if not self.frame then return end
    Addon.Widgets:ApplyPanel(self.frame, Addon.db.profile.ui.bg)
end

-- Optical separator lines ----------------------------------------------------
-- Up to two thin lines the user can drop between modules (configured on the HUD
-- panel page). Each separator is a normal block in the stack, anchored just
-- after a chosen module, so enabling one pushes the following modules down by
-- its height. Config lives in profile.ui.separators.

-- Create a separator's frame + centered line texture on first use.
function MainWindow:CreateSeparator(i)
    local f = CreateFrame("Frame", "MauiMPlusTimerSeparator" .. i, self:Get())
    f:SetWidth(self:GetWidth())
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetPoint("CENTER", f, "CENTER", 0, 0)
    return { frame = f, line = line }
end

-- Sync the separator frames with profile.ui.separators: create and style each
-- enabled line and register it as block "separatorN", so the row layout can
-- place it like any other block (its position comes from the configured rows,
-- not from an anchor). Called from Layout BEFORE the rows are rendered; it
-- never calls Layout itself.
function MainWindow:UpdateSeparators()
    local cfgs = Addon.db.profile.ui.separators
    self.separators = self.separators or {}
    -- Separators are decoration between modules, so they follow the same
    -- visibility as the modules: only shown while a run or demo is active,
    -- never floating on their own outside a key.
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

-- Stack all visible rows vertically (full-width or left/right split), resize
-- the container to fit and show/hide it depending on whether anything is
-- visible.
function MainWindow:Layout()
    if not self.blocks then return end
    local hud = self:Get()

    self:UpdateSeparators()

    local width = self:GetWidth()
    local pad = self:PanelInsets()
    local spacing = Addon.db.profile.ui.spacing or 2
    local half = (width - SPLIT_GAP) / 2

    -- Collect the visible rows into the reusable scratch. A split row whose
    -- second block is hidden collapses to a full-width row.
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

    -- Apply the widths dictated by the placement (full or half row).
    for i = 1, count do
        if entryRight[i] then
            entryLeft[i]:SetWidth(half)
            entryRight[i]:SetWidth(half)
        else
            entryLeft[i]:SetWidth(width)
        end
    end

    -- Skip when the resulting stack is identical to the last one. Modules call
    -- Layout very frequently while a key runs (timer, forces, cooldowns), almost
    -- always with unchanged sizes/visibility. Re-anchoring and resizing the HUD
    -- on every one of those calls is what made the whole display jitter, so we
    -- no-op unless something structural (rows, their frames, rounded heights or
    -- the panel padding) actually changed.
    local sig = pad .. "/" .. spacing .. "/" .. width
    for i = 1, count do
        sig = sig .. "|" .. tostring(entryLeft[i])
            .. ":" .. math.floor((entryLeft[i]:GetHeight() or 0) + 0.5)
        if entryRight[i] then
            sig = sig .. "+" .. tostring(entryRight[i])
                .. ":" .. math.floor((entryRight[i]:GetHeight() or 0) + 0.5)
        end
    end
    if sig == self._layoutSig then return end
    self._layoutSig = sig

    local y = pad
    for i = 1, count do
        local lf, rf = entryLeft[i], entryRight[i]
        lf:ClearAllPoints()
        if rf then
            lf:SetPoint("TOPLEFT", hud, "TOPLEFT", pad, -y)
            rf:ClearAllPoints()
            rf:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -pad, -y)
            y = y + math.max(lf:GetHeight(), rf:GetHeight()) + spacing
        else
            lf:SetPoint("TOP", hud, "TOP", 0, -y)
            y = y + lf:GetHeight() + spacing
        end
    end

    if count > 0 then
        hud:SetSize(width + pad * 2, (y - spacing) + pad)
        self:ApplyPanel()
        hud:Show()
    else
        hud:Hide()
    end
end
