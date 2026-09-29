-- UI/Options/Controls.lua
-- Widget factory for the settings window: one constructor per AceConfig node
-- type. UI/Widgets.lua stays HUD-only; every settings frame is created here.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local OT = ns.OT

local Controls = {}
ns.Controls = Controls
Addon.OptionControls = Controls

local EMPTY = {}

local LABEL_H = 16
local GAP = 4
local SCROLLBAR_W = 4

-- AceConfig's contract for every callback field: a plain value, a function
-- taking the info table, or the name of a method on the nearest handler. This
-- addon's own pages only ever use functions, but AceDBOptions drives the whole
-- profiles page through handler methods, so the full rule has to hold.
local function member(node, key, info, ...)
    local field = node and node[key]
    if type(field) == "function" then
        return field(info, ...)
    end
    local handler = info and info.handler
    if type(field) == "string" and handler and handler[field] then
        return handler[field](handler, info, ...)
    end
    return field
end
Controls.Member = member

-- The info table every callback receives: the path to this option, the handler
-- inherited from the closest group that declares one, and the option itself.
function Controls.MakeInfo(context, key, node)
    local info = {}
    local path = context and context.path
    if path then
        for i = 1, #path do info[i] = path[i] end
    end
    info[#info + 1] = key
    info.options = context and context.options
    info.appName = context and context.appName
    info.uiName = context and context.uiName
    info.uiType = "dialog"
    info.handler = node.handler or (context and context.handler)
    info.option = node
    info.arg = node.arg
    info.type = node.type
    return info
end

local function nodeName(node, info) return member(node, "name", info) or "" end
local function nodeDesc(node, info) return member(node, "desc", info) end
local function nodeDisabled(node, info) return member(node, "disabled", info) == true end

function Controls.NameOf(node, info)
    return nodeName(node, info)
end

function Controls.DescOf(node, info)
    local desc = nodeDesc(node, info)
    if type(desc) ~= "string" or not desc:match("%S") then return nil end
    return desc
end

function Controls.IsHidden(node, info)
    return member(node, "hidden", info) == true
end

local function nodeGet(node, info)
    return member(node, "get", info)
end

-- The change journal ----------------------------------------------------

-- Every write goes through nodeSet, so this is the only place that can say
-- what a session changed. Keyed by the node, so twenty nudges of one slider
-- stay one change and the value kept is the one from before the first of them.
local journal = { list = {}, index = {} }

-- The profiles page writes through AceDBOptions and switches the whole store;
-- putting that in a list that offers to undo it would be a lie.
local SKIP_ROOT = { profiles = true }

local function pack(...)
    return { n = select("#", ...), ... }
end

local function currentProfile()
    local db = Addon.db
    return db and db.GetCurrentProfile and db:GetCurrentProfile() or nil
end

function Controls:ClearChanges()
    journal.list, journal.index = {}, {}
    journal.profile = currentProfile()
end

function Controls:ChangeCount()
    return #journal.list
end

local function record(node, info)
    if node.noJournal or SKIP_ROOT[info and info[1]] then return end

    -- A profile switch makes every stored "before" value meaningless.
    local profile = currentProfile()
    if profile ~= journal.profile then Controls:ClearChanges() end

    if journal.index[node] then return end
    local entry = { node = node, info = info, old = pack(nodeGet(node, info)) }
    journal.index[node] = entry
    journal.list[#journal.list + 1] = entry
end

-- Newest first: a later change can depend on an earlier one.
function Controls:DiscardChanges()
    for i = #journal.list, 1, -1 do
        local e = journal.list[i]
        member(e.node, "set", e.info, unpack(e.old, 1, e.old.n))
    end
    self:ClearChanges()
    self:Refresh()
    if self.OnChange then self:OnChange() end
end

-- Every write re-pulls the whole visible page: this is what replaces
-- AceConfigRegistry:NotifyChange, which drove the old dialog's refresh.
local function nodeSet(node, info, ...)
    if node.set == nil then return end
    record(node, info)
    member(node, "set", info, ...)
    Controls:Refresh()
    if Controls.OnChange then Controls:OnChange() end
end

local function tooltip(frame, control)
    frame:HookScript("OnEnter", function(s)
        local node = control.node
        local desc = node and nodeDesc(node, control.info)
        if not desc or desc == "" then return end
        local r, g, b = OT:Unpack("muted")
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(nodeName(node, control.info), OT:Unpack("text"))
        GameTooltip:AddLine(desc, r, g, b, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Shared base -----------------------------------------------------------

local Base = {}

-- In a row the heading and its explanation are drawn by the renderer, so the
-- control shows only its widget and reports how much width that needs.
function Base:SetRowMode(on)
    self.rowMode = on and true or nil
end

function Base:NaturalWidth()
    return nil
end

function Base:SetOption(node, info)
    self.node = node
    self.info = info
    self:Refresh()
end

function Base:SetWidth(width)
    self.frame:SetWidth(width)
    if self.OnWidth then self:OnWidth(width) end
end

function Base:GetHeight()
    return self.height or OT.size.row
end

-- How far below the frame's top the widget itself sits: the height of the
-- label above it, or nothing. The renderer lines a row up on the widgets, not
-- on the frames, or a button lands level with the labels beside it.
function Base:TopPad()
    return self.labelPad or 0
end

function Base:Refresh() end

local function proto()
    local p = setmetatable({}, { __index = Base })
    p.__index = p
    return p
end

local Toggle, Range, Select, Color = proto(), proto(), proto(), proto()
local Input, Execute, Description, Header = proto(), proto(), proto(), proto()
local Run = proto()

-- Pooling ---------------------------------------------------------------

local pools, active = {}, {}

function Controls:Acquire(kind, parent)
    local list = pools[kind]
    local control = list and tremove(list)
    if not control then
        control = self["Create" .. kind](self, parent)
        control.kind = kind
    end
    control.frame:SetParent(parent)
    control.frame:ClearAllPoints()
    control.frame:Show()
    control.owner = parent
    active[control] = true
    return control
end

function Controls:Release(control)
    active[control] = nil
    control.node, control.info, control.rowMode, control.owner = nil, nil, nil, nil
    control.frame:Hide()
    control.frame:ClearAllPoints()
    control.frame:SetParent(UIParent)
    pools[control.kind] = pools[control.kind] or {}
    tinsert(pools[control.kind], control)
end

-- Scoped to one page frame: with two windows open, redrawing one must not
-- clear the other's controls. No owner releases everything.
function Controls:ReleaseAll(owner)
    for control in pairs(active) do
        if not owner or control.owner == owner then
            self:Release(control)
        end
    end
    self:ReleaseRegions(owner)
end

-- How many controls a page currently holds. Used by the checks to prove that
-- redrawing one window leaves another one's page alone.
function Controls:ActiveCount(owner)
    local count = 0
    for control in pairs(active) do
        if not owner or control.owner == owner then count = count + 1 end
    end
    return count
end

-- The live controls, for the checks: `active` is a file local otherwise.
function Controls:Active()
    return active
end

function Controls:Refresh()
    for control in pairs(active) do
        if control.node then control:Refresh() end
    end
end

-- Scrolling --------------------------------------------------------------

-- Flat scrollbar: a track that only shows while there is something to scroll,
-- with a draggable thumb. Blizzard's template would drag the old look back in.
-- Lives here because the settings window is not the only window that needs it.
function Controls:AttachScrollbar(scroll, content)
    -- Beside the scroll frame, not on top of it: anchored to its own right
    -- edge the bar covered the last pixels of every page, which is what a
    -- button at the right edge of a row ran into.
    local bar = CreateFrame("Frame", nil, scroll:GetParent())
    bar:SetWidth(SCROLLBAR_W)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", OT.space.sm, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", OT.space.sm, 0)
    OT:Fill(bar, "line")
    bar:Hide()

    local thumb = CreateFrame("Button", nil, bar)
    thumb:SetWidth(SCROLLBAR_W)
    thumb:SetPoint("TOP")
    OT:Fill(thumb, "lineStrong")

    local function range()
        return max(0, content:GetHeight() - scroll:GetHeight())
    end

    local function layoutThumb()
        local span = range()
        if span <= 0 then
            bar:Hide()
            return
        end
        bar:Show()
        local track = bar:GetHeight()
        local ratio = scroll:GetHeight() / max(1, content:GetHeight())
        local height = max(24, track * ratio)
        thumb:SetHeight(height)
        thumb:SetPoint("TOP", bar, "TOP", 0, -(track - height) * (scroll:GetVerticalScroll() / span))
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(s, delta)
        s:SetVerticalScroll(min(range(), max(0, s:GetVerticalScroll() - delta * 40)))
        layoutThumb()
    end)

    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function() thumb.dragging = true end)
    thumb:SetScript("OnDragStop", function() thumb.dragging = nil end)
    thumb:SetScript("OnUpdate", function()
        if not thumb.dragging then return end
        local _, cursorY = GetCursorPosition()
        local scale = bar:GetEffectiveScale()
        local top = bar:GetTop()
        local track = max(1, bar:GetHeight() - thumb:GetHeight())
        local pct = (top - cursorY / scale - thumb:GetHeight() / 2) / track
        scroll:SetVerticalScroll(range() * min(1, max(0, pct)))
        layoutThumb()
    end)

    return layoutThumb, bar
end

-- Row text and cards ----------------------------------------------------

-- Both are pure regions, kept per page frame and handed out in order. A row's
-- heading or a card's frame would otherwise each cost a Frame whose only job is
-- to be something to anchor to; this way a page of twenty rows costs none.
local regionPools = {}

local function regionPool(parent, kind, build)
    local pools = regionPools[parent]
    if not pools then
        pools = {}
        regionPools[parent] = pools
    end
    local pool = pools[kind]
    if not pool then
        pool = { list = {}, used = 0 }
        pools[kind] = pool
    end
    pool.used = pool.used + 1
    local item = pool.list[pool.used]
    if not item then
        item = build(parent)
        pool.list[pool.used] = item
    end
    for i = 1, #item.regions do item.regions[i]:Show() end
    return item
end

-- Hides what this page did not use and rewinds the counters.
function Controls:ReleaseRegions(owner)
    for parent, pools in pairs(regionPools) do
      if not owner or parent == owner then
        for _, pool in pairs(pools) do
            for i = pool.used + 1, #pool.list do
                local item = pool.list[i]
                for r = 1, #item.regions do item.regions[r]:Hide() end
            end
            pool.used = 0
        end
      end
    end
end

local function buildRowText(parent)
    local rule = parent:CreateTexture(nil, "BORDER")
    rule:SetHeight(OT:Pixel())
    OT:Tint(rule, "line")

    local label = OT:Text(parent, "normal", "text")
    label:SetJustifyH("LEFT")

    local desc = OT:Text(parent, "small", "muted")
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)

    return { rule = rule, label = label, desc = desc, regions = { rule, label, desc } }
end

function Controls:AcquireRowText(parent)
    return regionPool(parent, "rowText", buildRowText)
end

local function buildCard(parent)
    local fill = parent:CreateTexture(nil, "BACKGROUND")
    OT:Tint(fill, "card")
    local lines = OT:OutlineRegion(parent, fill, "line")
    local regions = { fill }
    for i = 1, #lines do regions[#regions + 1] = lines[i] end
    return { fill = fill, lines = lines, regions = regions }
end

function Controls:AcquireCard(parent)
    return regionPool(parent, "card", buildCard)
end

-- Chevron ---------------------------------------------------------------

local CHEVRON = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Options\\chevron"

-- Tex coords for the quad corners (UL, LL, UR, LR). The stored glyph points
-- down; turning the coordinates a quarter turn counter-clockwise points it
-- right. SetRotation is no help here -- it rotates the texture coordinates,
-- which changes nothing visible on a flat-coloured quad.
local CHEVRON_DOWN  = { 0, 0, 0, 1, 1, 0, 1, 1 }
local CHEVRON_RIGHT = { 1, 0, 0, 0, 1, 1, 0, 1 }

-- The game font has no chevron glyph -- it renders as an empty box -- so the
-- marker is a texture whose shape lives in the alpha channel and gets tinted at
-- runtime, the same way the HUD icons work.
function Controls:Chevron(parent, size)
    size = size or 9
    local glyph = parent:CreateTexture(nil, "ARTWORK")
    glyph:SetSize(size, size)
    glyph:SetTexture(CHEVRON)

    -- Declared without an implicit self so the closures do not shadow the
    -- factory's own self.
    local chevron = { glyph = glyph }

    chevron.SetColor = function(_, key)
        OT:TintVertex(glyph, key)
    end

    chevron.SetDirection = function(_, dir)
        glyph:SetTexCoord(unpack(dir == "right" and CHEVRON_RIGHT or CHEVRON_DOWN))
    end

    chevron.SetShown = function(_, shown)
        glyph:SetShown(shown)
    end

    chevron.SetPoint = function(_, ...)
        glyph:SetPoint(...)
    end

    chevron:SetColor("muted")
    chevron:SetDirection("down")
    return chevron
end

-- Toggle ----------------------------------------------------------------

local SWITCH_W, SWITCH_H, KNOB = 34, 18, 14
local GLOW_PAD = 3

function Controls:CreateToggle(parent)
    local c = setmetatable({}, Toggle)
    local f = CreateFrame("Button", nil, parent)
    f:SetHeight(OT.size.row)
    c.frame, c.height = f, OT.size.row

    -- A switch rather than a check box: at a glance a filled track says "on"
    -- from further away than a tick does.
    local track = f:CreateTexture(nil, "BACKGROUND")
    track:SetSize(SWITCH_W, SWITCH_H)
    track:SetPoint("LEFT")
    track:SetTexture(OT.SWITCH)
    c.track = track

    -- The highlight is the switch's own shape, a little larger and behind it,
    -- so what lights up is a halo around the pill. A rectangle across the whole
    -- control looked like a patch stuck over it.
    local glow = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    glow:SetTexture(OT.SWITCH)
    glow:SetPoint("TOPLEFT", track, "TOPLEFT", -GLOW_PAD, GLOW_PAD)
    glow:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", GLOW_PAD, -GLOW_PAD)
    OT:TintVertex(glow, "selected")
    glow:Hide()
    c.hover = glow

    local knob = f:CreateTexture(nil, "ARTWORK", nil, 1)
    knob:SetSize(KNOB, KNOB)
    knob:SetTexture(OT.DOT)
    knob:SetTexCoord(unpack(OT.DOT_FILLED))
    c.knob = knob

    -- The knob stays white on every accent; this soft rim keeps it readable on
    -- the pale ones, down to a Priest's white.
    local rim = f:CreateTexture(nil, "ARTWORK")
    rim:SetSize(KNOB + 2, KNOB + 2)
    rim:SetPoint("CENTER", knob, "CENTER")
    rim:SetTexture(OT.DOT)
    rim:SetTexCoord(unpack(OT.DOT_FILLED))
    rim:SetVertexColor(0, 0, 0, 0.35)
    c.rim = rim

    c.label = OT:Text(f, "normal", "text")
    c.label:SetPoint("LEFT", track, "RIGHT", OT.space.sm, 0)
    c.label:SetPoint("RIGHT", f, "RIGHT")
    c.label:SetJustifyH("LEFT")

    f:SetScript("OnEnter", function()
        -- A disabled switch still gets the mouse, but nothing lights up.
        if c.node and not nodeDisabled(c.node, c.info) then c.hover:Show() end
    end)
    f:SetScript("OnLeave", function() c.hover:Hide() end)
    f:SetScript("OnClick", function()
        if not c.node then return end
        nodeSet(c.node, c.info, not nodeGet(c.node, c.info))
    end)
    tooltip(f, c)
    return c
end

function Toggle:NaturalWidth()
    return OT.width.xs
end

function Toggle:Refresh()
    local node, info = self.node, self.info
    local disabled = nodeDisabled(node, info)
    local on = nodeGet(node, info) and true or false

    -- In a row the switch sits at the right edge, where every other control's
    -- widget ends, and the heading belongs to the renderer.
    self.track:ClearAllPoints()
    self.track:SetPoint(self.rowMode and "RIGHT" or "LEFT")
    self.label:SetShown(not self.rowMode)
    if disabled then self.hover:Hide() end

    self.label:SetText(nodeName(node, info))
    self.label:SetTextColor(OT:Unpack(disabled and "faint" or "text"))

    OT:TintVertex(self.track, (on and not disabled) and "accent" or "switchOff")
    self.knob:ClearAllPoints()
    self.knob:SetPoint(on and "RIGHT" or "LEFT", self.track, on and "RIGHT" or "LEFT",
        on and -2 or 2, 0)
    if disabled then
        self.knob:SetVertexColor(OT:Unpack("faint"))
    elseif on then
        self.knob:SetVertexColor(1, 1, 1, 1)
    else
        self.knob:SetVertexColor(OT:Unpack("muted"))
    end

    self.frame:SetEnabled(not disabled)
end

-- Range -----------------------------------------------------------------

local VALUE_BOX_W = 56

-- Derived from the step so a 0.1 slider does not print six decimals.
local function rangeFormat(node, v)
    v = v or 0
    if node.isPercent then return format("%d%%", v * 100 + 0.5) end
    local step = node.step or 1
    if step >= 1 then return format("%d", v + (v >= 0 and 0.5 or -0.5)) end
    if step >= 0.1 then return format("%.1f", v) end
    return format("%.2f", v)
end

-- Accepts everything the box itself prints, plus a comma as decimal mark.
local function rangeParse(node, text)
    text = tostring(text or ""):gsub("%%", ""):gsub(",", "."):gsub("%s", "")
    local v = tonumber(text)
    if not v then return nil end
    if node.isPercent then v = v / 100 end
    local minV = node.softMin or node.min or 0
    local maxV = node.softMax or node.max or 100
    local step = node.step
    if step and step > 0 then
        v = minV + floor((v - minV) / step + 0.5) * step
    end
    return min(maxV, max(minV, v))
end

function Controls:CreateRange(parent)
    local c = setmetatable({}, Range)
    local height = LABEL_H + GAP + OT.size.control
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)
    c.frame, c.height = f, height

    c.label = OT:Text(f, "small", "muted")
    c.label:SetPoint("TOPLEFT")
    c.label:SetJustifyH("LEFT")

    -- An edit box rather than a label: dragging cannot hit an exact number,
    -- and several of these ranges run from 8 to 64.
    local valueBox = CreateFrame("EditBox", nil, f)
    valueBox:SetSize(VALUE_BOX_W, LABEL_H)
    valueBox:SetPoint("TOPRIGHT")
    OT:ApplyFont(valueBox, "small")
    valueBox:SetTextColor(OT:Unpack("text"))
    valueBox:SetJustifyH("RIGHT")
    valueBox:SetAutoFocus(false)
    c.valueBox = valueBox

    local underline = valueBox:CreateTexture(nil, "ARTWORK")
    underline:SetHeight(OT:Pixel())
    underline:SetPoint("BOTTOMLEFT", 0, -2)
    underline:SetPoint("BOTTOMRIGHT", 0, -2)
    underline:SetColorTexture(OT:Unpack("lineStrong"))
    underline:Hide()
    c.underline = underline

    local slider = CreateFrame("Slider", nil, f)
    slider:SetHeight(OT.size.control)
    slider:SetPoint("BOTTOMLEFT")
    slider:SetPoint("BOTTOMRIGHT")
    slider:SetOrientation("HORIZONTAL")
    slider:SetObeyStepOnDrag(true)
    -- Deliberately no mouse wheel: the page scrolls under the cursor, and a
    -- wheel that also moved the slider changed values by accident.
    c.slider = slider

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetHeight(2)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetColorTexture(OT:Unpack("lineStrong"))
    c.track = track

    local fill = slider:CreateTexture(nil, "BORDER")
    fill:SetHeight(2)
    fill:SetPoint("LEFT", track, "LEFT")
    OT:Tint(fill, "accent")
    c.fill = fill

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(4, 14)
    thumb:SetColorTexture(OT:Unpack("text"))
    slider:SetThumbTexture(thumb)
    c.thumb = thumb

    slider:SetScript("OnValueChanged", function(_, v)
        c:UpdateFill(v)
        if c.silent or not c.node then return end
        nodeSet(c.node, c.info, v)
    end)
    valueBox:SetScript("OnEnter", function()
        if c.node and not nodeDisabled(c.node, c.info) then underline:Show() end
    end)
    valueBox:SetScript("OnLeave", function(s)
        if not s:HasFocus() then underline:Hide() end
    end)
    valueBox:SetScript("OnEditFocusGained", function() underline:Show() end)
    valueBox:SetScript("OnEditFocusLost", function()
        underline:Hide()
        c:Commit()
    end)
    valueBox:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    valueBox:SetScript("OnEscapePressed", function(s)
        s:ClearFocus()
        c:Refresh()
    end)

    tooltip(slider, c)
    return c
end

-- Typed input goes through the same clamp and step rounding as the slider;
-- unparsable text simply reverts.
function Range:Commit()
    local node = self.node
    if not node then return end
    local v = rangeParse(node, self.valueBox:GetText())
    if not v or v == self.slider:GetValue() then
        return self:Refresh()
    end
    nodeSet(node, self.info, v)
end

-- The fill runs from the track's left edge to the thumb, so it has to be
-- recomputed on every value and width change.
function Range:UpdateFill(v)
    local node = self.node
    if not node then return end
    local minV = node.softMin or node.min or 0
    local maxV = node.softMax or node.max or 100
    local span = maxV - minV
    local pct = span > 0 and ((v or minV) - minV) / span or 0
    -- The track is anchored, so its width is not resolved in the frame the row
    -- was laid out in and the fill would stay invisible until an interaction
    -- forced a repaint. The width handed to OnWidth is known right away.
    local track = self.trackWidth or self.track:GetWidth()
    self.fill:SetWidth(max(0.001, track * min(1, max(0, pct))))
    -- Never overwrite what the user is currently typing.
    if not self.valueBox:HasFocus() then
        self.valueBox:SetText(rangeFormat(node, v))
    end
end

function Range:OnWidth(width)
    self.trackWidth = self.rowMode
        and max(1, width - VALUE_BOX_W - OT.space.sm)
        or width
    self:UpdateFill(self.slider:GetValue())
end

function Range:Refresh()
    local node, info = self.node, self.info
    local disabled = nodeDisabled(node, info)
    local name = nodeName(node, info)
    local labelled = name ~= "" and not self.rowMode
    self.label:SetText(name)
    self.label:SetShown(labelled)

    -- Stacked the value sits above the slider; in a row the two share one line,
    -- slider first and the number field flush right.
    self.valueBox:ClearAllPoints()
    self.slider:ClearAllPoints()
    self.labelPad = labelled and (LABEL_H + GAP) or 0
    if self.rowMode then
        self.height = OT.size.control
        self.valueBox:SetPoint("RIGHT")
        self.slider:SetPoint("LEFT")
        self.slider:SetPoint("RIGHT", self.valueBox, "LEFT", -OT.space.sm, 0)
    else
        self.height = LABEL_H + GAP + OT.size.control
        self.valueBox:SetPoint("TOPRIGHT")
        self.slider:SetPoint("BOTTOMLEFT")
        self.slider:SetPoint("BOTTOMRIGHT")
    end
    self.frame:SetHeight(self.height)

    local minV = node.softMin or node.min or 0
    local maxV = node.softMax or node.max or 100
    self.silent = true
    self.slider:SetMinMaxValues(minV, maxV)
    self.slider:SetValueStep(node.step or 1)
    self.slider:SetValue(min(maxV, max(minV, tonumber(nodeGet(node, info)) or minV)))
    self.silent = nil

    if disabled then self.slider:Disable() else self.slider:Enable() end
    if disabled then self.valueBox:Disable() else self.valueBox:Enable() end
    OT:Tint(self.fill, disabled and "faint" or "accent")
    self.thumb:SetColorTexture(OT:Unpack(disabled and "faint" or "text"))
    self.label:SetTextColor(OT:Unpack(disabled and "faint" or "muted"))
    self.valueBox:SetTextColor(OT:Unpack(disabled and "faint" or "text"))
    self:UpdateFill(self.slider:GetValue())
end

-- Select ----------------------------------------------------------------

-- Ace sorts by display name unless the node carries an explicit order.
local function sortedValues(node, info)
    local values = member(node, "values", info) or EMPTY
    local keys = {}
    local order = node.sorting and member(node, "sorting", info)
    if order then
        for i = 1, #order do keys[i] = order[i] end
    else
        for k in pairs(values) do tinsert(keys, k) end
        sort(keys, function(a, b)
            return tostring(values[a]):lower() < tostring(values[b]):lower()
        end)
    end
    return keys, values
end

local list, listRows

-- One shared popup for every dropdown; only one can be open at a time.
local function getList()
    if list then return list end

    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetAllPoints(UIParent)
    closer:SetFrameStrata("FULLSCREEN_DIALOG")
    closer:Hide()
    closer:SetScript("OnClick", function() Controls:CloseList() end)

    list = CreateFrame("Frame", nil, UIParent)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetFrameLevel(closer:GetFrameLevel() + 10)
    list:Hide()
    OT:Fill(list, "raised")
    -- Same grain as the window's panels, so the list is cut from the same
    -- material; a hairline rather than the strong edge the page uses nowhere
    -- else.
    list.noise = OT:Noise(list)
    OT:Outline(list, "line")
    list.closer = closer

    local scroll = CreateFrame("ScrollFrame", nil, list)
    scroll:SetPoint("TOPLEFT", 0, -OT.space.xs)
    scroll:SetPoint("BOTTOMRIGHT", 0, OT.space.xs)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(s, delta)
        local range = max(0, content:GetHeight() - s:GetHeight())
        s:SetVerticalScroll(min(range, max(0, s:GetVerticalScroll() - delta * OT.size.listRow)))
    end)
    list.scroll, list.content = scroll, content
    listRows = {}
    return list
end

local function listRow(index)
    local row = listRows[index]
    if row then return row end

    row = CreateFrame("Button", nil, list.content)
    row:SetHeight(OT.size.listRow)
    row.hover = OT:Fill(row, "hoverStrong")
    row.hover:Hide()
    row.check = row:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(3, OT.size.listRow - 8)
    row.check:SetPoint("LEFT", OT.space.xs, 0)
    OT:Tint(row.check, "accent")
    row.label = OT:Text(row, "normal", "text")
    row.label:SetPoint("LEFT", OT.space.md, 0)
    row.label:SetPoint("RIGHT", -OT.space.sm, 0)
    row.label:SetJustifyH("LEFT")
    row:SetScript("OnEnter", function(s) s.hover:Show() end)
    row:SetScript("OnLeave", function(s) s.hover:Hide() end)
    listRows[index] = row
    return row
end

-- The shared popup, for the checks: it is a file local otherwise.
function Controls:List()
    return list
end

function Controls:CloseList()
    if not list then return end
    list:Hide()
    list.closer:Hide()
    list.owner = nil
end

function Controls:OpenList(control)
    local node = control.node
    if not node then return end
    if list and list:IsShown() and list.owner == control then
        return self:CloseList()
    end

    getList()
    local info = control.info
    local keys, values = sortedValues(node, info)
    local current = nodeGet(node, info)
    local width = max(160, control.button:GetWidth())

    for i = 1, #keys do
        local row = listRow(i)
        local key = keys[i]
        row:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -(i - 1) * OT.size.listRow)
        row:SetWidth(width)
        row.label:SetText(tostring(values[key] or key))
        row.check:SetShown(key == current)
        row:SetScript("OnClick", function()
            Controls:CloseList()
            nodeSet(node, info, key)
        end)
        row:Show()
    end
    for i = #keys + 1, #listRows do
        listRows[i]:Hide()
    end

    local shown = min(#keys, OT.size.listMax)
    list.content:SetSize(width, max(1, #keys * OT.size.listRow))
    list.scroll:SetVerticalScroll(0)
    list:SetSize(width, shown * OT.size.listRow + OT.space.sm)
    -- The grain repeats, so it has to be told the size it repeats over, the
    -- same as the window's panels.
    OT:TileNoise(list.noise, width, shown * OT.size.listRow + OT.space.sm)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", control.button, "BOTTOMLEFT", 0, -2)
    list.owner = control
    list.closer:Show()
    list:Show()
end

function Controls:CreateSelect(parent)
    local c = setmetatable({}, Select)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(LABEL_H + GAP + OT.size.control)
    c.frame = f

    c.label = OT:Text(f, "small", "muted")
    c.label:SetPoint("TOPLEFT")
    c.label:SetJustifyH("LEFT")

    local button = CreateFrame("Button", nil, f)
    button:SetHeight(OT.size.control)
    button:SetPoint("BOTTOMLEFT")
    button:SetPoint("BOTTOMRIGHT")
    c.face = OT:Fill(button, "input")
    -- One line under the field instead of a ring around it: a field is a place
    -- to read a value out of, a button is a thing to press, and the two should
    -- not look alike. The slider's value box already does it this way.
    c.buttonLines = { OT:Line(button, "BOTTOM", "lineStrong") }
    c.button = button

    c.hover = OT:Fill(button, "hover", "BORDER")
    c.hover:Hide()

    c.chevron = self:Chevron(button, 8)
    c.chevron:SetPoint("RIGHT", button, "RIGHT", -OT.space.sm, 0)

    c.valueText = OT:Text(button, "normal", "text")
    c.valueText:SetPoint("LEFT", OT.space.sm, 0)
    c.valueText:SetPoint("RIGHT", c.chevron.glyph, "LEFT", -OT.space.xs, 0)
    c.valueText:SetJustifyH("LEFT")

    button:SetScript("OnEnter", function()
        c.hover:Show()
        c.hovered = true
        c:PaintEdge()
    end)
    button:SetScript("OnLeave", function()
        c.hover:Hide()
        c.hovered = nil
        c:PaintEdge()
    end)
    button:SetScript("OnClick", function() Controls:OpenList(c) end)
    tooltip(button, c)
    return c
end

function Select:Refresh()
    local node, info = self.node, self.info
    local disabled = nodeDisabled(node, info)
    local name = nodeName(node, info)
    local labelled = name ~= "" and not self.rowMode
    self.label:SetText(name)
    self.label:SetShown(labelled)
    self.labelPad = labelled and (LABEL_H + GAP) or 0
    self.height = labelled and (LABEL_H + GAP + OT.size.control) or OT.size.control
    self.frame:SetHeight(self.height)

    local values = member(node, "values", info) or EMPTY
    local current = nodeGet(node, info)
    local text = current ~= nil and values[current] or nil
    self.valueText:SetText(text and tostring(text) or NONE)

    self.button:SetEnabled(not disabled)
    self.label:SetTextColor(OT:Unpack(disabled and "faint" or "muted"))
    self.valueText:SetTextColor(OT:Unpack(disabled and "faint" or "text"))
    self.chevron:SetColor(disabled and "faint" or "muted")
    self:PaintEdge()
    if list and list.owner == self and disabled then
        Controls:CloseList()
    end
end

function Select:PaintEdge()
    local disabled = self.node and nodeDisabled(self.node, self.info)
    OT:Recolor(self.buttonLines,
        (disabled and "line") or (self.hovered and "accent") or "lineStrong")
end

-- Color -----------------------------------------------------------------

function Controls:CreateColor(parent)
    local c = setmetatable({}, Color)
    local f = CreateFrame("Button", nil, parent)
    f:SetHeight(OT.size.row)
    c.frame, c.height = f, OT.size.row

    c.hover = OT:Fill(f, "hover")
    c.hover:Hide()

    local frame = f:CreateTexture(nil, "BACKGROUND")
    frame:SetSize(OT.size.swatch, OT.size.swatch)
    frame:SetPoint("LEFT")
    OT:Tint(frame, "input")
    c.swatchBox = frame
    c.swatchLines = OT:OutlineRegion(f, frame, "lineStrong")
    c.swatch = f:CreateTexture(nil, "ARTWORK")
    c.swatch:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    c.swatch:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    c.label = OT:Text(f, "normal", "text")
    c.label:SetPoint("LEFT", frame, "RIGHT", OT.space.sm, 0)
    c.label:SetPoint("RIGHT", f, "RIGHT")
    c.label:SetJustifyH("LEFT")

    f:SetScript("OnEnter", function() c.hover:Show() end)
    f:SetScript("OnLeave", function() c.hover:Hide() end)
    f:SetScript("OnClick", function() c:OpenPicker() end)
    tooltip(f, c)
    return c
end

-- The node is captured: a refresh may rebind this control while the picker
-- is still open, and cancel has to restore the original value either way.
function Color:OpenPicker()
    local node, info = self.node, self.info
    if not node or nodeDisabled(node, info) then return end

    local r, g, b, a = nodeGet(node, info)
    r, g, b, a = r or 1, g or 1, b or 1, a or 1
    local hasAlpha = node.hasAlpha and true or false

    local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = hasAlpha and ColorPickerFrame:GetColorAlpha() or 1
        nodeSet(node, info, nr, ng, nb, na)
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b,
        hasOpacity = hasAlpha, opacity = a,
        swatchFunc = apply,
        opacityFunc = apply,
        cancelFunc = function() nodeSet(node, info, r, g, b, a) end,
    })
end

function Color:NaturalWidth()
    return OT.width.xs
end

function Color:Refresh()
    local node, info = self.node, self.info
    local disabled = nodeDisabled(node, info)

    self.swatchBox:ClearAllPoints()
    self.swatchBox:SetPoint(self.rowMode and "RIGHT" or "LEFT")
    self.label:SetShown(not self.rowMode)

    self.label:SetText(nodeName(node, info))
    self.label:SetTextColor(OT:Unpack(disabled and "faint" or "text"))

    local r, g, b, a = nodeGet(node, info)
    self.swatch:SetColorTexture(r or 1, g or 1, b or 1, node.hasAlpha and (a or 1) or 1)
    self.swatch:SetDesaturated(disabled)
    OT:Recolor(self.swatchLines, disabled and "line" or "lineStrong")
    self.frame:SetEnabled(not disabled)
end

-- Confirm ---------------------------------------------------------------

local CONFIRM_POPUP = "MAUIMPT_OPTION_CONFIRM"

StaticPopupDialogs[CONFIRM_POPUP] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(self)
        if self.data then self.data() end
        Controls:Refresh()
    end,
}

-- AceConfig's confirm: a string is the question, true asks with confirmText or the name.
local function confirmed(node, info, run, ...)
    local confirm = member(node, "confirm", info, ...)
    if not confirm then return run() end
    local text = type(confirm) == "string" and confirm
        or member(node, "confirmText", info) or nodeName(node, info)
    local popup = StaticPopup_Show(CONFIRM_POPUP, text)
    if popup then popup.data = run end
end

-- Input -----------------------------------------------------------------

local MULTILINE_H = 90
local ACCEPT_W = 96

local function buildEdit(c, parent)
    local edit = CreateFrame("EditBox", nil, parent)
    OT:ApplyFont(edit, "normal")
    edit:SetTextColor(OT:Unpack("text"))
    edit:SetAutoFocus(false)
    edit:SetScript("OnEditFocusGained", function(s)
        c.focused = true
        c:PaintEdge()
        -- These hold a whole string: one click selects it for copying, and a paste replaces it.
        local mode = c.node and c.node.arg
        if mode == "readOnly" or mode == "live" then s:HighlightText() end
    end)
    edit:SetScript("OnTextChanged", function(_, userInput)
        if userInput then c:OnTyped() end
    end)
    tooltip(edit, c)
    return edit
end

-- Keeps clicks off the lines scrolled out of view.
local function clipMemo(memo, scroll)
    if scroll:GetVerticalScrollRange() == 0 then
        memo:SetHitRectInsets(0, 0, 0, 0)
        return
    end
    local offset = scroll:GetVerticalScroll()
    memo:SetHitRectInsets(0, 0, offset, max(0, memo:GetHeight() - offset - scroll:GetHeight()))
end

function Controls:CreateInput(parent)
    local c = setmetatable({}, Input)
    local f = CreateFrame("Frame", nil, parent)
    c.frame = f

    c.label = OT:Text(f, "small", "muted")
    c.label:SetPoint("TOPLEFT")
    c.label:SetJustifyH("LEFT")

    local box = f:CreateTexture(nil, "BACKGROUND")
    OT:Tint(box, "input")
    -- One line under the field, like the dropdown and the slider's value box.
    local underline = f:CreateTexture(nil, "BORDER")
    underline:SetHeight(OT:Pixel())
    underline:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT")
    underline:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
    OT:Tint(underline, "lineStrong")
    c.boxLines = { underline }
    c.box = box

    local edit = buildEdit(c, f)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", OT.space.sm, -OT.space.xs)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -OT.space.sm, OT.space.xs)
    edit:SetScript("OnEditFocusLost", function()
        c.focused = nil
        c:PaintEdge()
        if c.dirty then c:Commit() end
    end)
    edit:SetScript("OnEnterPressed", function() c:Commit() end)
    edit:SetScript("OnEscapePressed", function(s)
        c:SetDirty(false)
        s:ClearFocus()
        c:Refresh()
    end)
    c.edit = edit

    -- Multi-line text is pasted rather than typed, so it is stored on Accept
    -- only, the way AceGUI's MultiLineEditBox does it.
    local memoScroll = CreateFrame("ScrollFrame", nil, f)
    memoScroll:SetPoint("TOPLEFT", box, "TOPLEFT", OT.space.sm, -OT.space.xs)
    memoScroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -(OT.space.sm * 2 + SCROLLBAR_W), OT.space.xs)
    memoScroll:EnableMouse(true)
    c.memoScroll = memoScroll

    local memo = buildEdit(c, memoScroll)
    memo:SetMultiLine(true)
    memo:SetCountInvisibleLetters(false)
    memo:SetPoint("TOPLEFT")
    memoScroll:SetScrollChild(memo)
    c.memo = memo
    c.layoutMemo, c.memoBar = self:AttachScrollbar(memoScroll, memo)

    memoScroll:SetScript("OnSizeChanged", function(_, width) memo:SetWidth(width) end)
    memoScroll:SetScript("OnMouseUp", function()
        memo:SetFocus()
        memo:SetCursorPosition(memo:GetNumLetters())
    end)
    memoScroll:HookScript("OnVerticalScroll", function(s)
        clipMemo(memo, s)
        c.layoutMemo()
    end)
    memoScroll:HookScript("OnScrollRangeChanged", function(s)
        clipMemo(memo, s)
        c.layoutMemo()
    end)
    memo:SetScript("OnCursorChanged", function(_, _, y, _, cursorHeight)
        y = -y
        local offset = memoScroll:GetVerticalScroll()
        if y < offset then
            memoScroll:SetVerticalScroll(y)
        else
            y = y + cursorHeight - memoScroll:GetHeight()
            if y > offset then memoScroll:SetVerticalScroll(y) end
        end
    end)
    memo:SetScript("OnEditFocusLost", function(s)
        c.focused = nil
        c:PaintEdge()
        s:HighlightText(0, 0)
    end)
    memo:SetScript("OnEscapePressed", memo.ClearFocus)

    local accept = CreateFrame("Button", nil, f)
    accept:SetSize(ACCEPT_W, OT.size.control)
    accept:SetPoint("BOTTOMRIGHT")
    OT:Fill(accept, "card")
    c.acceptLines = OT:Outline(accept, "lineStrong")
    c.acceptLabel = OT:Text(accept, "normal", "text")
    c.acceptLabel:SetPoint("CENTER")
    c.acceptLabel:SetText(ACCEPT)
    accept:SetScript("OnEnter", function()
        c.acceptHover = true
        c:SetDirty(c.dirty)
    end)
    accept:SetScript("OnLeave", function()
        c.acceptHover = nil
        c:SetDirty(c.dirty)
    end)
    accept:SetScript("OnClick", function() c:Commit() end)
    c.accept = accept
    return c
end

function Input:SetOption(node, info)
    self.dirty = nil
    Base.SetOption(self, node, info)
end

-- arg carries the renderer's own input modes, since AceConfig rejects unknown
-- keys: "readOnly" can be selected and copied but not changed, "live" is
-- stored on every change instead of on Accept.
function Input:OnTyped()
    local node, info = self.node, self.info
    if not node then return end
    if node.arg == "readOnly" then
        self.active:SetText(tostring(nodeGet(node, info) or ""))
    elseif node.arg == "live" then
        nodeSet(node, info, self.active:GetText())
    else
        self:SetDirty(true)
    end
end

function Input:SetDirty(on)
    self.dirty = on and true or nil
    local live = (self.dirty and self.node and not nodeDisabled(self.node, self.info)) and true or false
    self.accept:SetEnabled(live)
    self.acceptLabel:SetTextColor(OT:Unpack(live and "text" or "faint"))
    OT:Recolor(self.acceptLines, (not live and "line") or (self.acceptHover and "accent") or "lineStrong")
end

-- Ace lets an input reject what was typed; false or a message means the value
-- is not accepted. A single line falls back to what is stored, pasted text
-- stays for another try.
function Input:Commit()
    local node, info = self.node, self.info
    if not node or nodeDisabled(node, info) then return end
    local edit = self.active
    local text = edit:GetText()
    if node.validate ~= nil then
        local ok = member(node, "validate", info, text)
        if ok == false or type(ok) == "string" then
            local message = type(ok) == "string" and ok or member(node, "usage", info)
            if message then Addon:Warning("%s", message) end
            if not node.multiline then
                self:SetDirty(false)
                edit:ClearFocus()
                self:Refresh()
            end
            return
        end
    end
    -- Cleared before ClearFocus, whose focus-lost handler would commit again.
    if not node.multiline then self:SetDirty(false) end
    edit:ClearFocus()
    confirmed(node, info, function()
        if self.node == node then self:SetDirty(false) end
        nodeSet(node, info, text)
    end, text)
end

function Input:Refresh()
    local node, info = self.node, self.info
    local disabled = nodeDisabled(node, info)
    local multiline = node.multiline and true or false

    local name = nodeName(node, info)
    local labelled = name ~= "" and not self.rowMode
    self.label:SetText(name)
    self.label:SetShown(labelled)
    self.label:SetTextColor(OT:Unpack(disabled and "faint" or "muted"))

    local boxHeight = multiline and MULTILINE_H or OT.size.control
    local withAccept = multiline and node.arg ~= "readOnly" and node.arg ~= "live"
    local acceptHeight = withAccept and (GAP + OT.size.control) or 0
    self.box:SetHeight(boxHeight)
    self.box:ClearAllPoints()
    self.box:SetPoint("BOTTOMLEFT", 0, acceptHeight)
    self.box:SetPoint("BOTTOMRIGHT", 0, acceptHeight)
    self.labelPad = labelled and (LABEL_H + GAP) or 0
    self.height = self.labelPad + boxHeight + acceptHeight
    self.frame:SetHeight(self.height)

    self.edit:SetShown(not multiline)
    self.memoScroll:SetShown(multiline)
    self.accept:SetShown(withAccept)
    if not multiline then self.memoBar:Hide() end
    self.active = multiline and self.memo or self.edit

    -- Every write anywhere refreshes the page; it must not wipe what is being
    -- typed, nor move the cursor of a live field that already holds this text.
    local stored = tostring(nodeGet(node, info) or "")
    if not self.dirty and self.active:GetText() ~= stored then
        self.active:SetText(stored)
        self.active:SetCursorPosition(0)
        if multiline then self.memoScroll:SetVerticalScroll(0) end
        -- A fresh export arrives selected, ready for Ctrl+C.
        if node.arg == "readOnly" and stored ~= "" and not disabled then
            self.active:SetFocus()
            self.active:HighlightText()
        end
    end
    if disabled then self.active:Disable() else self.active:Enable() end
    self.active:SetTextColor(OT:Unpack(disabled and "faint" or "text"))
    self:SetDirty(self.dirty)
    self:PaintEdge()
    if multiline then self.layoutMemo() end
end

-- The line under the field carries the state, and the accent marks the field
-- being typed in.
function Input:PaintEdge()
    local disabled = self.node and nodeDisabled(self.node, self.info)
    OT:Recolor(self.boxLines, (disabled and "line") or (self.focused and "accent") or "lineStrong")
end

-- Execute ---------------------------------------------------------------

local EXECUTE_PAD = 24

function Controls:CreateExecute(parent)
    local c = setmetatable({}, Execute)
    local height = OT.size.control + GAP
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)
    c.frame, c.height = f, height

    local button = CreateFrame("Button", nil, f)
    button:SetHeight(OT.size.control)
    button:SetPoint("TOPLEFT")
    -- The same faint wash the cards use instead of a solid fill: a button is
    -- not more material than the surface it sits on, and an opaque one reads
    -- as a plate cut out of a translucent window.
    c.face = OT:Fill(button, "card")
    c.buttonLines = OT:Outline(button, "lineStrong")
    c.button = button

    c.hover = OT:Fill(button, "hover", "BORDER")
    c.hover:Hide()

    c.label = OT:Text(button, "normal", "text")
    c.label:SetPoint("CENTER")

    button:SetScript("OnEnter", function()
        c.hover:Show()
        c.hovered = true
        c:PaintEdge()
    end)
    button:SetScript("OnLeave", function()
        c.hover:Hide()
        c.hovered = nil
        c:PaintEdge()
    end)
    button:SetScript("OnClick", function() c:Run() end)
    tooltip(button, c)
    return c
end

function Execute:Run()
    local node, info = self.node, self.info
    if not node or node.func == nil or nodeDisabled(node, info) then return end
    confirmed(node, info, function()
        member(node, "func", info)
        Controls:Refresh()
    end)
end

function Execute:NaturalWidth()
    return self.button:GetWidth()
end

-- The outline is the button, so it carries the state: quiet when disabled,
-- accent under the cursor, which is the same hue the switches use.
function Execute:PaintEdge()
    local disabled = self.node and nodeDisabled(self.node, self.info)
    OT:Recolor(self.buttonLines,
        (disabled and "line") or (self.hovered and "accent") or "lineStrong")
end

function Execute:Refresh()
    local node, info = self.node, self.info
    local disabled = nodeDisabled(node, info)
    self.button:ClearAllPoints()
    self.button:SetPoint(self.rowMode and "TOPRIGHT" or "TOPLEFT")
    self.label:SetText(nodeName(node, info))
    self.label:SetTextColor(OT:Unpack(disabled and "faint" or "text"))
    self.button:SetWidth(OT:SnapWidth(self.label:GetStringWidth() + EXECUTE_PAD * 2))
    self.button:SetEnabled(not disabled)
    self:PaintEdge()
end

-- Description -----------------------------------------------------------

local DESC_SIZE = { small = "small", medium = "normal", large = "heading" }

function Controls:CreateDescription(parent)
    local c = setmetatable({}, Description)
    local f = CreateFrame("Frame", nil, parent)
    c.frame = f

    c.image = f:CreateTexture(nil, "ARTWORK")
    c.image:SetPoint("TOPLEFT")
    c.image:Hide()

    c.text = OT:Text(f, "normal", "muted")
    c.text:SetJustifyH("LEFT")
    c.text:SetWordWrap(true)
    return c
end

-- The height only exists once the width is known, so the renderer has to read
-- GetHeight again after SetWidth.
function Description:Measure()
    local node = self.node
    if not node then return end
    local imageH = 0
    if self.image:IsShown() then
        imageH = self.image:GetHeight() + OT.space.sm
    end
    -- A FontString set to an empty string reports nil, not "".
    local text = self.text:GetText() or ""
    local textH = text:match("%S") and ceil(self.text:GetStringHeight()) or 0
    self.height = imageH + textH
    self.frame:SetHeight(max(1, self.height))
end

-- An explicit width is what makes GetStringHeight report the wrapped height.
-- Derived from anchors it is not necessarily settled in the same frame, which
-- is why the text stayed on one line until something forced a repaint.
function Description:OnWidth(width)
    self.text:SetWidth(width)
    self:Measure()
end

function Description:Refresh()
    local node, info = self.node, self.info
    local size = DESC_SIZE[member(node, "fontSize", info) or "medium"] or "normal"
    OT:ApplyFont(self.text, size)

    local image = member(node, "image", info)
    local top = 0
    if image then
        self.image:SetTexture(image)
        self.image:SetSize(node.imageWidth or 32, node.imageHeight or 32)
        self.image:Show()
        top = -(self.image:GetHeight() + OT.space.sm)
    else
        self.image:Hide()
    end

    -- One anchor only, with the width set explicitly in OnWidth: a second
    -- corner would fight that width. TOPLEFT together with RIGHT was the
    -- original mistake, since RIGHT pins the vertical centre as well and a
    -- fixed height truncates the text to a single line.
    self.text:ClearAllPoints()
    self.text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, top)

    self.text:SetText(nodeName(node, info))
    self:Measure()
end

-- Run -------------------------------------------------------------------

-- A stored run, laid out like the banner over the page: the key level and the
-- run's particulars on the left, the total on the right, and a bar for the
-- time against the dungeon's limit. One Button, everything else a region, so a
-- list of twenty runs costs twenty frames rather than forty.

local RUN_H = 62
local RUN_PAD = 12
local RUN_BAR = 4
local RUN_CROSS = 28
local RUN_GLYPH = 18

function Controls:CreateRun(parent)
    local c = setmetatable({}, Run)
    -- Not a Button: only the cross deletes, so the card itself takes no click.
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(RUN_H)
    f:EnableMouse(true)
    c.frame, c.height = f, RUN_H

    OT:Fill(f, "card")
    c.lines = OT:Outline(f, "line")
    c.hover = OT:Fill(f, "hover", "BORDER")
    c.hover:Hide()

    c.tag = OT:Text(f, "heading", "text")
    c.tag:SetPoint("TOPLEFT", RUN_PAD, -OT.space.sm)

    c.badge = OT:Text(f, "small", "warn")
    c.badge:SetPoint("LEFT", c.tag, "RIGHT", OT.space.sm, 0)

    c.meta = OT:Text(f, "small", "muted")
    c.meta:SetPoint("TOPLEFT", c.tag, "BOTTOMLEFT", 0, -2)
    c.meta:SetJustifyH("LEFT")

    c.splits = OT:Text(f, "small", "faint")
    c.splits:SetPoint("TOPLEFT", c.meta, "BOTTOMLEFT", 0, -2)
    c.splits:SetJustifyH("LEFT")

    c.total = OT:Text(f, "title", "text")
    c.total:SetPoint("TOPRIGHT", -(RUN_PAD + RUN_CROSS + OT.space.sm), -OT.space.sm)
    c.total:SetJustifyH("RIGHT")

    c.delta = OT:Text(f, "small", "muted")
    c.delta:SetPoint("TOPRIGHT", c.total, "BOTTOMRIGHT", 0, -1)
    c.delta:SetJustifyH("RIGHT")

    c.track = f:CreateTexture(nil, "ARTWORK")
    c.track:SetHeight(RUN_BAR)
    c.track:SetPoint("BOTTOMLEFT", RUN_PAD, OT.space.sm)
    c.track:SetPoint("BOTTOMRIGHT", -RUN_PAD, OT.space.sm)
    OT:Tint(c.track, "lineStrong")

    -- Coloured per run in Paint, not tinted with the accent.
    c.fill = f:CreateTexture(nil, "OVERLAY")
    c.fill:SetHeight(RUN_BAR)
    c.fill:SetPoint("BOTTOMLEFT", c.track, "BOTTOMLEFT")

    -- The one thing on the card that takes a click. No border and no plate: the
    -- bin is the button, the way the switch is its own pill.
    local del = CreateFrame("Button", nil, f)
    del:SetSize(RUN_CROSS, RUN_CROSS)
    del:SetPoint("TOPRIGHT", -OT.space.xs, -OT.space.xs)
    c.delete = del

    -- No highlight behind it: the glyph turns red under the cursor, which says
    -- both that it is live and what it will do. A halo would say it again.
    c.cross = del:CreateTexture(nil, "ARTWORK")
    c.cross:SetSize(RUN_GLYPH, RUN_GLYPH)
    c.cross:SetPoint("CENTER")
    c.cross:SetTexture(OT.TRASH)
    OT:TintVertex(c.cross, "faint")

    f:SetScript("OnEnter", function()
        c.hover:Show()
        OT:Recolor(c.lines, "lineStrong")
        c.cross:SetVertexColor(OT:Unpack("muted"))
    end)
    f:SetScript("OnLeave", function()
        c.hover:Hide()
        OT:Recolor(c.lines, "line")
        c.cross:SetVertexColor(OT:Unpack("faint"))
    end)

    del:SetScript("OnEnter", function()
        c.cross:SetVertexColor(OT:Unpack("danger"))
    end)
    del:SetScript("OnLeave", function()
        c.cross:SetVertexColor(OT:Unpack("faint"))
    end)
    del:SetScript("OnClick", function() c:Run() end)
    tooltip(del, c)
    return c
end

Run.Run = Execute.Run

function Run:OnWidth(width)
    self.barWidth = max(1, width - RUN_PAD * 2)
    self:Paint()
end

-- The track is anchored to both sides, so its width is not settled in the
-- frame it was anchored in; the bar is drawn from the width the layout passed.
function Run:Paint()
    local node = self.node
    if not node then return end
    local progress = member(node, "progress", self.info)
    self.track:SetShown(progress ~= nil)
    self.fill:SetShown(progress ~= nil)
    if progress then
        self.fill:SetWidth(max(0.001,
            (self.barWidth or 1) * min(1, max(0, progress))))
        OT:PaintProgress(self.fill, progress)
    end
end

function Run:Refresh()
    local node, info = self.node, self.info

    self.tag:SetText(member(node, "tag", info) or "")
    self.badge:SetText(member(node, "badge", info) or "")
    self.meta:SetText(member(node, "meta", info) or "")
    self.splits:SetText(member(node, "splits", info) or "")
    self.total:SetText(member(node, "total", info) or "")
    self.total:SetTextColor(OT:Unpack(member(node, "totalColor", info) or "text"))
    self.delta:SetText(member(node, "delta", info) or "")
    self:Paint()
end

-- Header ----------------------------------------------------------------

-- Section title for an inline group: uppercase label plus a rule that runs to
-- the right edge, the same small-caps tier the HUD labels use.
function Controls:CreateHeader(parent)
    local c = setmetatable({}, Header)
    local height = OT.size.row
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)
    c.frame, c.height = f, height

    c.label = OT:Text(f, "small", "muted")
    c.label:SetPoint("BOTTOMLEFT")
    c.label:SetJustifyH("LEFT")

    c.rule = f:CreateTexture(nil, "ARTWORK")
    c.rule:SetHeight(OT:Pixel())
    c.rule:SetPoint("LEFT", c.label, "RIGHT", OT.space.sm, 1)
    c.rule:SetPoint("RIGHT", f, "RIGHT")
    c.rule:SetColorTexture(OT:Unpack("line"))
    return c
end

-- strupper would turn a texture escape's closing "|t" into "|T", which the
-- client no longer recognises: the whole escape then renders as its own path.
-- So only the words between the escapes are raised.
local function upperOutsideEscapes(text)
    local out, last = {}, 1
    while true do
        local from, to = text:find("|T.-|t", last)
        if not from then break end
        out[#out + 1] = strupper(text:sub(last, from - 1))
        out[#out + 1] = text:sub(from, to)
        last = to + 1
    end
    out[#out + 1] = strupper(text:sub(last))
    return table.concat(out)
end
Controls.UpperOutsideEscapes = upperOutsideEscapes

function Header:Refresh()
    self.label:SetText(upperOutsideEscapes(Controls.Plain(nodeName(self.node, self.info))))
end

-- Window chrome ---------------------------------------------------------

-- The settings window and the panels share one make: title bar, a list on the
-- left, a scrolling page on the right. The owner supplies Draw(verifying),
-- Close, OnClosed, SaveGeometry and ResetGeometry.

local WINDOW_PAD = OT.space.lg
local VERIFY_MAX = 3
local HEADING_H = 22

function Controls.Plain(text)
    return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function Controls.SaveGeometry(frame, store)
    store.width, store.height = frame:GetWidth(), frame:GetHeight()
    store.left, store.top = frame:GetLeft(), frame:GetTop()
end

function Controls.RestoreGeometry(frame, store, width, height)
    frame:SetSize(store.width or width, store.height or height)
    frame:ClearAllPoints()
    if store.left and store.top then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", store.left, store.top)
    else
        frame:SetPoint("CENTER")
    end
end

-- The store also holds the folded list sections, so only the geometry goes.
function Controls.ClearGeometry(store)
    store.width, store.height, store.left, store.top = nil, nil, nil, nil
end

local function headerButton(header, icon, size, tip, hot, onClick)
    local button = CreateFrame("Button", nil, header)
    button:SetSize(32, 32)
    local glyph = button:CreateTexture(nil, "ARTWORK")
    glyph:SetSize(size, size)
    glyph:SetPoint("CENTER")
    glyph:SetTexture(icon)
    OT:TintVertex(glyph, "muted")
    button:SetScript("OnEnter", function(s)
        glyph:SetVertexColor(OT:Unpack(hot or "text"))
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(tip, OT:Unpack("text"))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        glyph:SetVertexColor(OT:Unpack("muted"))
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", onClick)
    return button
end

-- spec: name, title, logo, width, height, minWidth, minHeight, sidebarWidth.
function Controls:BuildWindow(owner, spec)
    local f = CreateFrame("Frame", spec.name, UIParent)
    f:SetSize(spec.width, spec.height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(spec.minWidth, spec.minHeight) end
    f:EnableMouse(true)
    f:Hide()

    local header = CreateFrame("Frame", nil, f)
    header:SetHeight(OT.size.header)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        owner:SaveGeometry()
    end)
    OT:Gradient(header, "headerTop", "header")
    header.backdrop = OT:Backdrop(header)
    header.noise = OT:Noise(header)
    OT:Wash(header, "accent", 0.12, 360)

    -- Solid across the full width on purpose: a fade reads as a shadow, not as a division.
    local rule = header:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(OT:Pixel())
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    OT:Tint(rule, "accent")

    local title = OT:Text(header, "heading", "text")
    if spec.logo then
        local logo = header:CreateTexture(nil, "ARTWORK")
        logo:SetSize(20, 20)
        logo:SetPoint("LEFT", WINDOW_PAD, 0)
        logo:SetTexture(spec.logo)
        title:SetPoint("LEFT", logo, "RIGHT", OT.space.sm, 0)
    else
        title:SetPoint("LEFT", WINDOW_PAD, 0)
    end
    title:SetText(spec.title)

    local divider = header:CreateTexture(nil, "ARTWORK")
    divider:SetSize(OT:Pixel(), 18)
    divider:SetPoint("LEFT", title, "RIGHT", OT.space.md, 0)
    OT:Tint(divider, "lineStrong")

    local crumb = OT:Text(header, "normal", "muted")
    crumb:SetPoint("LEFT", divider, "RIGHT", OT.space.md, 0)
    crumb:SetJustifyH("LEFT")

    local close = headerButton(header, OT.CLOSE, 24, CLOSE, "danger", function() owner:Close() end)
    close:SetPoint("RIGHT", -OT.space.sm, 0)
    local reset = headerButton(header, OT.RESET, 21, ns.L["Reset window size and position"], nil,
        function() owner:ResetGeometry() end)
    reset:SetPoint("RIGHT", close, "LEFT", -OT.space.xs, 0)
    crumb:SetPoint("RIGHT", reset, "LEFT", -OT.space.md, 0)

    local sidebarWidth = spec.sidebarWidth or OT.size.sidebar
    local sidebar = CreateFrame("Frame", nil, f)
    sidebar:SetWidth(sidebarWidth)
    sidebar:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    sidebar:SetPoint("BOTTOMLEFT")
    OT:Gradient(sidebar, "sidebarTop", "sidebar")
    sidebar.backdrop = OT:Backdrop(sidebar)
    sidebar.noise = OT:Noise(sidebar)
    OT:Line(sidebar, "RIGHT", "line")

    local listScroll = CreateFrame("ScrollFrame", nil, sidebar)
    listScroll:SetPoint("TOPLEFT", 0, -OT.space.sm)
    listScroll:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, OT.space.sm)
    local list = CreateFrame("Frame", nil, listScroll)
    list:SetSize(1, 1)
    listScroll:SetScrollChild(list)
    listScroll:EnableMouseWheel(true)
    listScroll:SetScript("OnMouseWheel", function(s, delta)
        local span = max(0, list:GetHeight() - s:GetHeight())
        s:SetVerticalScroll(min(span, max(0, s:GetVerticalScroll() - delta * OT.size.row)))
    end)

    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", sidebar, "TOPRIGHT")
    body:SetPoint("BOTTOMRIGHT")
    OT:Gradient(body, "baseTop", "base")
    body.backdrop = OT:Backdrop(body)
    body.noise = OT:Noise(body)

    local scroll = CreateFrame("ScrollFrame", nil, body)
    scroll:SetPoint("TOPLEFT", WINDOW_PAD, -WINDOW_PAD)
    scroll:SetPoint("BOTTOMRIGHT", -(WINDOW_PAD + SCROLLBAR_W + OT.space.sm), WINDOW_PAD)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    -- The body panel covers this corner, so the grip sits above it to keep its clicks.
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT")
    grip:SetFrameLevel(f:GetFrameLevel() + 5)
    for i = 1, 2 do
        local line = grip:CreateTexture(nil, "ARTWORK")
        OT:Tint(line, "lineStrong")
        line:SetSize(10 - i * 3, OT:Pixel())
        line:SetPoint("BOTTOMRIGHT", -3, 3 + i * 3)
    end
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        owner:SaveGeometry()
        owner:Draw()
    end)

    -- A child frame draws over its parent's regions, so the border needs its own frame on top.
    local edge = CreateFrame("Frame", nil, f)
    edge:SetAllPoints()
    edge:SetFrameLevel(f:GetFrameLevel() + 8)
    edge:EnableMouse(false)
    OT:Outline(edge, "lineStrong")

    -- A redraw per size event would rebuild the page per pixel; OnUpdate coalesces them.
    f:SetScript("OnSizeChanged", function() owner.dirty = true end)
    f:SetScript("OnUpdate", function(_, elapsed)
        if owner.verify then
            owner.verify = nil
            owner:Draw(true)
            return
        end
        if not owner.dirty then return end
        owner.since = (owner.since or 0) + elapsed
        if owner.since < 0.05 then return end
        owner.since, owner.dirty = 0, nil
        owner:Draw()
    end)
    -- ESC hides through UISpecialFrames without calling Close. Hiding UIParent
    -- (Alt+Z) fires this too while the frame stays shown; that is no close.
    f:SetScript("OnHide", function(s)
        if not s:IsShown() then owner:OnClosed() end
    end)
    if spec.name then tinsert(UISpecialFrames, spec.name) end

    f.header, f.crumb, f.resetButton = header, crumb, reset
    f.sidebarWidth, f.list, f.listScroll = sidebarWidth, list, listScroll
    f.body, f.scroll, f.content = body, scroll, content
    f.layoutThumb, f.scrollbar = self:AttachScrollbar(scroll, content)
    f.panels = { header, sidebar, body }
    return f
end

-- The grain repeats per panel; the backdrop is one picture each panel shows its
-- slice of, taken from the layout because GetLeft/GetTop are nil before placement.
function Controls.PaintChrome(f)
    local width, height = max(1, f:GetWidth()), max(1, f:GetHeight())
    for _, panel in ipairs(f.panels) do
        OT:TileNoise(panel.noise, panel:GetWidth(), panel:GetHeight())
    end
    local headerCut = min(1, OT.size.header / height)
    local sideCut = min(1, f.sidebarWidth / width)
    local header, sidebar, body = f.panels[1], f.panels[2], f.panels[3]
    OT:PlaceBackdrop(header.backdrop, 0, 1, 0, headerCut)
    OT:PlaceBackdrop(sidebar.backdrop, 0, sideCut, headerCut, 1)
    OT:PlaceBackdrop(body.backdrop, sideCut, 1, headerCut, 1)
end

-- A wrapped FontString does not report its height in the frame it was filled
-- in, and a long block can settle a line at a time: redraw until the height
-- stops moving, at most VERIFY_MAX times. A verifying pass keeps the scroll.
function Controls.Settle(owner, scroll, height, verifying)
    if verifying then
        if height ~= owner.lastHeight and (owner.verifyLeft or 0) > 0 then
            owner.verifyLeft = owner.verifyLeft - 1
            owner.verify = true
        end
    else
        scroll:SetVerticalScroll(0)
        owner.verifyLeft = VERIFY_MAX
        owner.verify = true
    end
    owner.lastHeight = height
end

-- Blizzard icons (file IDs, Interface\Icons) carry a rounded border that is cut
-- off; the addon's own glyphs are drawn edge to edge and stay whole.
function Controls.SetIcon(texture, icon)
    texture:SetTexture(icon)
    local blizzard = type(icon) == "number"
        or (type(icon) == "string" and icon:lower():find("^interface[\\/]icons[\\/]") ~= nil)
    if blizzard then
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

function Controls.ListRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(OT.size.row)
    row.hover = OT:Fill(row, "hoverStrong")
    row.hover:Hide()
    row.selected = OT:Fill(row, "selected", "BORDER")
    row.selected:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", OT.space.md, 0)

    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(8, 8)
    row.dot:SetTexture(OT.DOT)
    row.dot:SetPoint("LEFT", OT.space.md + 4, 0)

    row.right = OT:Text(row, "small", "faint")
    row.right:SetPoint("RIGHT", -OT.space.sm, 0)
    row.right:SetJustifyH("RIGHT")

    row.label = OT:Text(row, "normal", "text")
    row.label:SetPoint("LEFT", OT.space.md + 22, 0)
    row.label:SetPoint("RIGHT", row.right, "LEFT", -OT.space.xs, 0)
    row.label:SetJustifyH("LEFT")

    row:SetScript("OnEnter", function(s) s.hover:Show() end)
    row:SetScript("OnLeave", function(s) s.hover:Hide() end)
    return row
end

-- A section caption is also its switch, so it is one frame; the rest are regions.
function Controls:ListHeading(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(HEADING_H)
    local heading = {
        frame = button,
        label = OT:Text(button, "small", "muted"),
        right = OT:Text(button, "small", "faint"),
        rule = button:CreateTexture(nil, "BORDER"),
        chevron = self:Chevron(button, 7),
    }
    heading.label:SetJustifyH("LEFT")
    heading.right:SetJustifyH("RIGHT")
    heading.rule:SetHeight(OT:Pixel())
    OT:Tint(heading.rule, "line")

    heading.chevron:SetPoint("LEFT", OT.space.md, 0)
    heading.label:SetPoint("LEFT", heading.chevron.glyph, "RIGHT", OT.space.xs, 0)
    heading.right:SetPoint("RIGHT", -OT.space.sm, 0)
    heading.rule:SetPoint("LEFT", heading.label, "RIGHT", OT.space.sm, -1)
    heading.rule:SetPoint("RIGHT", heading.right, "LEFT", -OT.space.sm, -1)

    button:SetScript("OnEnter", function()
        heading.label:SetTextColor(OT:Unpack("text"))
        heading.chevron:SetColor("text")
    end)
    button:SetScript("OnLeave", function()
        heading.label:SetTextColor(OT:Unpack("muted"))
        heading.chevron:SetColor("muted")
    end)
    return heading
end

Controls.HEADING_H = HEADING_H
