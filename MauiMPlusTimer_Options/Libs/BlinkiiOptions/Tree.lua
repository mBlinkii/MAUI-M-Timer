-- BlinkiiOptions/Tree.lua
-- Walking the option tree: sorting, the search filter and the context every
-- callback is resolved against. Shared by the windows, the panels and the renderer.

local lib = BlinkiiOptions
if lib.__skip then return end

local Controls = lib.Controls

local Tree = {}
lib.Tree = Tree

local plain = Controls.Plain

-- AceConfig ordering: nil counts as 100, negatives sort after positives, ties
-- go alphabetically. Kept so a tree reads the same here as in an Ace dialog.
local function compare(a, b)
    local orderA = a.order or 100
    local orderB = b.order or 100
    if orderA == orderB then return plain(a.name) < plain(b.name) end
    if orderA < 0 then
        if orderB >= 0 then return false end
    elseif orderB < 0 then
        return true
    end
    return orderA < orderB
end

local function textHit(text, filter)
    return text ~= nil and plain(text):lower():find(filter, 1, true) ~= nil
end

-- Titles only: matching the explanations too makes half a page hit on a common word.
local function nodeHit(node, info, filter)
    return textHit(Controls.NameOf(node, info), filter)
end

-- A page is a hit when its own name matches or anything inside it does, so the
-- sidebar can offer a page for a setting buried three levels down.
function Tree.SubtreeHit(node, context, key, filter, depth)
    local info = Controls.MakeInfo(context, key, node)
    if nodeHit(node, info, filter) then return true end
    if node.type ~= "group" or (depth or 0) > 6 then return false end

    local childContext = Tree.ChildContext(context, key, node)
    for childKey, child in pairs(node.args or {}) do
        if type(child) == "table"
            and Tree.SubtreeHit(child, childContext, childKey, filter, (depth or 0) + 1) then
            return true
        end
    end
    return false
end

-- The context an option's callbacks are resolved against: its path in the tree
-- and the handler it inherits.
function Tree.ChildContext(context, key, node)
    -- A group that matched by its own name is the whole answer; filtering
    -- inside it would leave one lonely row.
    local filterOff = context and context.filterOff
    if context and context.filter and not filterOff
        and nodeHit(node, Controls.MakeInfo(context, key, node), context.filter) then
        filterOff = true
    end

    local path = {}
    if context and context.path then
        for i = 1, #context.path do path[i] = context.path[i] end
    end
    path[#path + 1] = key
    return {
        options = context and context.options,
        appName = context and context.appName,
        uiName = context and context.uiName,
        path = path,
        handler = node.handler or (context and context.handler),
        filter = context and context.filter,
        filterOff = filterOff,
    }
end

-- Sorted list of {key, node, name, order, info} for a group's args. `hidden`
-- may itself be a handler method, so it needs the info table like any callback.
function Tree.SortedArgs(group, keep, context)
    local out = {}
    -- The filter rides on the context, so the panels, which have no search, never see it.
    local filter = context and not context.filterOff and context.filter
    for key, node in pairs(group and group.args or {}) do
        if type(node) == "table" then
            local info = Controls.MakeInfo(context, key, node)
            local hit = not filter or Tree.SubtreeHit(node, context, key, filter)
            if hit and not Controls.IsHidden(node, info) and (not keep or keep(node)) then
                tinsert(out, { key = key, node = node, name = node.name,
                    order = node.order, info = info })
            end
        end
    end
    sort(out, compare)
    return out
end

-- A group that gets its own entry in the sidebar; inline groups are drawn as cards.
function Tree.IsPage(node)
    return node.type == "group" and not node.inline
end
