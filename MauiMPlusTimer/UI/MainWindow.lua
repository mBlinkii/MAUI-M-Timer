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
        -- Movable when unlocked, or always while demo mode is active so the
        -- HUD can be positioned even with the default lock on.
        if not Addon.db.profile.ui.locked or Addon.Demo:IsActive() then
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
        if module.UI and module.UI.Restyle then
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
    self:Layout()
end

-- Block rows -------------------------------------------------------------------
-- The HUD is a stack of user-configurable ROWS (options: General -> Element
-- order). Each row holds one block at full width or two blocks side by side
-- (left/right half); rows without visible content collapse. Separator lines
-- take part as normal entries ("separator1"/"separator2") while enabled and
-- always occupy a full row. profile.ui.blockRows stores
-- { left = key, right = key } per row.

-- User-orderable module blocks in default top-to-bottom order.
local MODULE_BLOCKS = {
    "dungeon", "timer", "forces", "objectives",
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

-- Whether `key` names a separator entry.
function MainWindow:IsSeparatorKey(key)
    return key == "separator1" or key == "separator2"
end

-- Whether separator line i (1 or 2) is enabled in the profile.
function MainWindow:IsSeparatorEnabled(i)
    local cfgs = Addon.db.profile.ui.separators
    return (cfgs and cfgs[i] and cfgs[i].enabled == true) or false
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
        if key and ORDERABLE[key] and not seen[key] then
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

    for _, key in ipairs(MODULE_BLOCKS) do place(key) end
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

-- Reset the row layout to the factory default (one block per row, forces bar
-- below the objectives; matches the factory preset in Core/DB.lua) and
-- restack. Enabled separators re-place themselves on the lowest free rows.
function MainWindow:ResetBlockRows()
    Addon.db.profile.ui.blockRows = {
        { left = "dungeon" },
        { left = "timer" },
        { left = "objectives" },
        { left = "forces" },
        { left = "deaths" },
        { left = "splits" },
        { left = "checkpoints" },
        { left = "cooldowns" },
    }
    self:InvalidateRows()
    self:Layout()
end

-- Assign `key` (or nil to clear) to one side of a row, persist and restack.
-- The key is removed from any other slot first (each block exists exactly
-- once); a separator always occupies a full row, so it claims the left half
-- and clears the right one.
function MainWindow:SetBlockSlot(rowIndex, side, key)
    local rows = self:GetBlockRows()
    local row = rows[rowIndex]
    if not row then return end
    if key then
        for _, r in ipairs(rows) do
            if r.left == key then r.left = nil end
            if r.right == key then r.right = nil end
        end
    end
    if key and self:IsSeparatorKey(key) then
        side = "left"
        row.right = nil
    end
    row[side] = key
    Addon.db.profile.ui.blockRows = rows
    self:InvalidateRows()
    self:Layout()
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
    for i = 1, 2 do
        local cfg = cfgs and cfgs[i]
        local sep = self.separators[i]
        if cfg and cfg.enabled then
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
