-- UI/Options/Render.lua
-- Lays an option group out as controls. Reads the same tables the AceConfig
-- dialog reads and defines no option data of its own.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local OT = ns.OT
local Controls = ns.Controls

local EMPTY_NODE = {}

local Render = {}
ns.Render = Render
Addon.OptionRender = Render

-- Ace widths are multiples of one control column. Keeping that model means the
-- existing tables (width = 0.25, 1.0, "full") lay out as they were written; the
-- column count follows the window instead of stretching a slider across it.
local TARGET_COLUMN = 240
local MAX_COLUMNS = 4
local COL_GAP = OT.space.lg
local ROW_GAP = OT.space.sm
local GROUP_GAP = OT.space.md

-- A labelled row: heading and explanation on the left, the widget at a fixed
-- width on the right. Rows are separated by their own hairline, not by a gap.
-- What a field takes when it does not bring its own width. A node may name a
-- step instead: controlWidth = "sm". Not AceConfig's `width`, which is the
-- column count in the flow layout and means something else.
local function rowWidth(node, control, available)
    local step = node.controlWidth and OT.width[node.controlWidth]
    if step then return step end
    return control:NaturalWidth() or min(OT.width.lg, available * 0.45)
end
local ROW_PAD_Y = 7
local TEXT_GAP = 1

local CARD_PAD_X = 14
local CARD_PAD_Y = 9
local CARD_GAP = OT.space.md

local KINDS = {
    toggle      = "Toggle",
    range       = "Range",
    select      = "Select",
    color       = "Color",
    input       = "Input",
    execute     = "Execute",
    description = "Description",
    header      = "Header",
    run         = "Run",
}

-- Resolved late: Window.lua loads first but is not needed until a draw runs.
local function sorted(group, context)
    return ns.OptionsWindow.SortedArgs(group, nil, context)
end

local function unitsOf(node, columns)
    local width = node.width
    if width == "full" then return columns end
    if width == "double" then return 2 end
    if width == "half" then return 0.5 end
    if type(width) == "number" and width > 0 then return width end
    -- Prose, section titles and run cards run the full width unless told
    -- otherwise.
    if node.type == "description" or node.type == "header"
        or node.type == "run" then return columns end
    return 1
end

local function measure(state)
    state.columns = max(1, min(MAX_COLUMNS, floor(state.width / TARGET_COLUMN)))
    -- The gap lives inside the unit, so a full row of units spans exactly the
    -- content width.
    state.unit = (state.width + COL_GAP) / state.columns
end

local function newLayout(parent, width)
    local state = { parent = parent, left = 0, width = width, y = 0, used = 0,
        rowHeight = 0, pending = {} }
    measure(state)
    return state
end

-- A row is placed when it is finished, not while it fills: only then is it
-- known how much label height the tallest control in it wants above its
-- widget. Everything in the row is then dropped to that line, so a button
-- with no label stands level with the fields beside it instead of with their
-- captions.
local function flushRow(state)
    local pending = state.pending
    if #pending == 0 then return end

    local pad, height = 0, 0
    for i = 1, #pending do
        pad = max(pad, pending[i].pad)
    end
    for i = 1, #pending do
        local item = pending[i]
        item.control.frame:SetPoint("TOPLEFT", state.parent, "TOPLEFT",
            item.x, -(state.y + pad - item.pad))
        height = max(height, pad - item.pad + item.control:GetHeight())
    end
    state.rowHeight = max(state.rowHeight, height)

    for i = #pending, 1, -1 do pending[i] = nil end
end

local function newRow(state)
    flushRow(state)
    if state.used == 0 and state.rowHeight == 0 then return end
    state.y = state.y + state.rowHeight + ROW_GAP
    state.used, state.rowHeight = 0, 0
end

-- The height is only valid after SetWidth: a description measures its wrapped
-- text there, so reading it earlier collapses the row.
local function placeFlow(state, control, units)
    units = min(units, state.columns)
    if state.used > 0 and state.used + units > state.columns + 0.001 then
        newRow(state)
    end

    control:SetWidth(max(24, units * state.unit - COL_GAP))
    state.pending[#state.pending + 1] = {
        control = control,
        pad = control:TopPad(),
        x = state.left + state.used * state.unit,
    }
    state.used = state.used + units
    if state.used > state.columns - 0.001 then newRow(state) end
end

local function placeRow(state, control, label, desc)
    newRow(state)

    local rowText = Controls:AcquireRowText(state.parent)
    local controlWidth = rowWidth(control.node or EMPTY_NODE, control, state.width)
    local textWidth = max(60, state.width - controlWidth - OT.space.lg)

    rowText.rule:ClearAllPoints()
    rowText.rule:SetPoint("TOPLEFT", state.parent, "TOPLEFT", state.left, -state.y)
    rowText.rule:SetWidth(state.width)

    rowText.label:SetWidth(textWidth)
    rowText.label:SetText(label)
    local labelHeight = ceil(rowText.label:GetStringHeight())

    rowText.desc:SetShown(desc ~= nil)
    local descHeight = 0
    if desc then
        rowText.desc:SetWidth(textWidth)
        rowText.desc:SetText(desc)
        descHeight = TEXT_GAP + ceil(rowText.desc:GetStringHeight())
    end

    control:SetWidth(controlWidth)
    local controlHeight = control:GetHeight()
    local textHeight = labelHeight + descHeight
    local rowHeight = max(textHeight, controlHeight) + ROW_PAD_Y * 2

    local textTop = state.y + (rowHeight - textHeight) / 2
    rowText.label:ClearAllPoints()
    rowText.label:SetPoint("TOPLEFT", state.parent, "TOPLEFT", state.left, -textTop)
    rowText.desc:ClearAllPoints()
    rowText.desc:SetPoint("TOPLEFT", state.parent, "TOPLEFT", state.left,
        -(textTop + labelHeight + TEXT_GAP))

    control.frame:SetPoint("TOPLEFT", state.parent, "TOPLEFT",
        state.left + state.width - controlWidth,
        -(state.y + (rowHeight - controlHeight) / 2))

    state.y = state.y + rowHeight
end

-- A section becomes a card: the frame is drawn from regions once the contents
-- have been laid out, because only then is its height known.
function Render:Card(state, node, entry, context)
    newRow(state)

    local card = Controls:AcquireCard(state.parent)
    local outerLeft, outerWidth, top = state.left, state.width, state.y

    state.left = outerLeft + CARD_PAD_X
    state.width = outerWidth - CARD_PAD_X * 2
    state.y = top + CARD_PAD_Y
    measure(state)

    local header = Controls:Acquire("Header", state.parent)
    header:SetOption(node, entry.info)
    placeFlow(state, header, state.columns)
    newRow(state)

    self:Group(state, node, context, true)
    newRow(state)

    state.y = state.y + CARD_PAD_Y
    card.fill:ClearAllPoints()
    card.fill:SetPoint("TOPLEFT", state.parent, "TOPLEFT", outerLeft, -top)
    card.fill:SetSize(outerWidth, max(1, state.y - top))

    state.left, state.width = outerLeft, outerWidth
    state.y = state.y + CARD_GAP
    measure(state)
end

function Render:Group(state, group, context, inCard)
    for _, entry in ipairs(sorted(group, context)) do
        local node = entry.node
        if node.type == "group" then
            -- Nested pages belong in the sidebar; only inline groups are drawn.
            if node.inline then
                local childContext = ns.OptionsWindow.ChildContext(context, entry.key, node)
                if inCard then
                    newRow(state)
                    local header = Controls:Acquire("Header", state.parent)
                    header:SetOption(node, entry.info)
                    placeFlow(state, header, state.columns)
                    newRow(state)
                    self:Group(state, node, childContext, true)
                    newRow(state)
                    state.y = state.y + GROUP_GAP
                else
                    self:Card(state, node, entry, childContext)
                end
            end
        else
            local kind = KINDS[node.type]
            if kind then
                local control = Controls:Acquire(kind, state.parent)
                -- An option that explains itself earns a row; the rest keep the
                -- dense flow, which is what holds pages like the element order
                -- together.
                local desc = node.type ~= "description" and node.type ~= "header"
                    and node.type ~= "run"
                    and Controls.DescOf(node, entry.info) or nil
                if desc then
                    control:SetRowMode(true)
                    control:SetOption(node, entry.info)
                    placeRow(state, control, Controls.NameOf(node, entry.info), desc)
                else
                    control:SetRowMode(false)
                    control:SetOption(node, entry.info)
                    placeFlow(state, control, unitsOf(node, state.columns))
                end
            end
        end
    end
end

-- Returns the total height; the caller owns the release of the old controls.
function Render:Draw(parent, group, width, context)
    if not group or width <= 0 then return 0 end
    local state = newLayout(parent, width)
    self:Group(state, group, context)
    newRow(state)
    return max(0, state.y - ROW_GAP)
end
