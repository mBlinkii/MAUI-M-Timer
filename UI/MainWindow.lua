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
local orderedScratch = {}
local function byOrder(a, b) return a.order < b.order end

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
function MainWindow:AddBlock(key, frame, order)
    self.blocks = self.blocks or {}
    self.blocks[key] = { frame = frame, order = order or 100 }
    self:Layout()
end

-- Change a registered block's stacking order and restack (e.g. moving the Enemy
-- Forces bar above or below the objectives).
function MainWindow:SetBlockOrder(key, order)
    if self.blocks and self.blocks[key] then
        self.blocks[key].order = order
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

-- Sync the separator blocks with profile.ui.separators: style each line, show it
-- only while its anchor module is visible, and order its block right after that
-- anchor (x.1 / x.2 so it never collides with the integer module orders). Called
-- from Layout BEFORE the stack is built; it never calls Layout itself.
function MainWindow:UpdateSeparators()
    local cfgs = Addon.db.profile.ui.separators
    self.separators = self.separators or {}
    for i = 1, 2 do
        local cfg = cfgs and cfgs[i]
        local key = "__separator" .. i
        local anchor = cfg and cfg.after and self.blocks and self.blocks[cfg.after]
        local visible = cfg and cfg.enabled and anchor and anchor.frame:IsShown()
        local sep = self.separators[i]
        if visible then
            sep = sep or self:CreateSeparator(i)
            self.separators[i] = sep
            local h = math.max(1, cfg.height or 2)
            local w = math.max(1, cfg.width or 180)
            local c = cfg.color or { 1, 1, 1, 0.5 }
            sep.frame:SetWidth(self:GetWidth())
            sep.frame:SetHeight(h)
            sep.line:SetSize(w, h)
            sep.line:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
            sep.frame:Show()
            self.blocks[key] = self.blocks[key] or {}
            self.blocks[key].frame = sep.frame
            self.blocks[key].order = anchor.order + 0.1 * i
        elseif sep then
            sep.frame:Hide()
        end
    end
end

-- Stack all currently shown blocks vertically, resize the container to fit and
-- show/hide the container depending on whether anything is visible.
function MainWindow:Layout()
    if not self.blocks then return end
    local hud = self:Get()

    self:UpdateSeparators()

    local ordered = orderedScratch
    wipe(ordered)
    for _, b in pairs(self.blocks) do ordered[#ordered + 1] = b end
    table.sort(ordered, byOrder)

    local pad = self:PanelInsets()
    local spacing = Addon.db.profile.ui.spacing or 2

    -- Skip when the resulting stack is identical to the last one. Modules call
    -- Layout very frequently while a key runs (timer, forces, cooldowns), almost
    -- always with unchanged block sizes/visibility. Re-anchoring and resizing the
    -- HUD on every one of those calls is what made the whole display jitter, so
    -- we no-op unless something structural (shown blocks, their rounded sizes,
    -- order or the panel padding) actually changed.
    local sig = tostring(pad) .. "/" .. tostring(spacing)
    for _, b in ipairs(ordered) do
        if b.frame:IsShown() then
            sig = sig .. "|" .. tostring(b.order)
                .. ":" .. math.floor((b.frame:GetWidth() or 0) + 0.5)
                .. "x" .. math.floor((b.frame:GetHeight() or 0) + 0.5)
        end
    end
    if sig == self._layoutSig then return end
    self._layoutSig = sig

    local topInset = pad
    local prev, width, height, count = nil, 0, 0, 0

    for _, b in ipairs(ordered) do
        local f = b.frame
        if f:IsShown() then
            f:ClearAllPoints()
            if not prev then
                f:SetPoint("TOP", hud, "TOP", 0, -topInset)
            else
                f:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
            end
            prev = f
            count = count + 1
            width = math.max(width, f:GetWidth())
            height = height + f:GetHeight()
        end
    end

    if count > 0 then
        local contentH = height + spacing * (count - 1)
        hud:SetSize(width + pad * 2, contentH + topInset + pad)
        self:ApplyPanel()
        hud:Show()
    else
        hud:Hide()
    end
end
