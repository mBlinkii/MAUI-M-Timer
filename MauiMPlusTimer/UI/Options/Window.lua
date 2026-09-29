-- UI/Options/Window.lua
-- The settings window: sidebar navigation over the option tree, search in the
-- title bar, and the selected group handed to ns.Render.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local OT = ns.OT
local Controls = ns.Controls

local Window = {}
ns.OptionsWindow = Window
Addon.OptionsWindow = Window

local FRAME_NAME = "MauiMPlusTimerOptions"
local DEFAULT_W, DEFAULT_H = 980, 660
local MIN_W, MIN_H = 720, 480
local PAD = OT.space.lg
local SCROLLBAR_W = 4
local SEARCH_W = 210
local FOOTER_H = 34
local CHIP_PAD = 7
local LOGO = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\icon_small"

local plain = Controls.Plain

-- AceConfig ordering: nil counts as 100, negatives sort after positives, ties
-- go alphabetically. Reproduced so both renderers show the same sequence.
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

-- Search --------------------------------------------------------------------

local function textHit(text, filter)
    return text ~= nil and plain(text):lower():find(filter, 1, true) ~= nil
end

-- Titles only: matching the explanations too makes half a page hit on a common word.
local function nodeHit(node, info, filter)
    return textHit(Controls.NameOf(node, info), filter)
end

-- A page is a hit when its own name matches or anything inside it does, so the
-- sidebar can offer a page for a setting buried three levels down.
local function subtreeHit(node, context, key, filter, depth)
    local info = Controls.MakeInfo(context, key, node)
    if nodeHit(node, info, filter) then return true end
    if node.type ~= "group" or (depth or 0) > 6 then return false end

    local childContext = Window.ChildContext(context, key, node)
    for childKey, child in pairs(node.args or {}) do
        if type(child) == "table"
            and subtreeHit(child, childContext, childKey, filter, (depth or 0) + 1) then
            return true
        end
    end
    return false
end

Window.SubtreeHit = subtreeHit

-- The context an option's callbacks are resolved against: its path in the tree
-- and the handler it inherits.
function Window.ChildContext(context, key, node)
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
function Window.SortedArgs(group, keep, context)
    local out = {}
    -- The filter rides on the context, so the panels, which have no search, never see it.
    local filter = context and not context.filterOff and context.filter
    for key, node in pairs(group and group.args or {}) do
        if type(node) == "table" then
            local info = Controls.MakeInfo(context, key, node)
            local hit = not filter or subtreeHit(node, context, key, filter)
            if hit and not Controls.IsHidden(node, info) and (not keep or keep(node)) then
                tinsert(out, { key = key, node = node, name = node.name,
                    order = node.order, info = info })
            end
        end
    end
    sort(out, compare)
    return out
end

-- Walked with ChildContext so the search travels down the path. AceDBOptions
-- puts its handler on the profiles group and every entry below reads through it.
function Window:Context()
    local context = self:RootContext()
    local group = self.options
    for i = 1, #self.path do
        local child = group.args and group.args[self.path[i]]
        if not child then break end
        context = self.ChildContext(context, self.path[i], child)
        group = child
    end
    return context, group
end

function Window:RootContext()
    return {
        options = self.options,
        appName = ADDON_NAME,
        uiName = "MauiMPlusTimer",
        path = {},
        handler = self.options.handler,
        filter = (self.filter ~= "" and self.filter) or nil,
    }
end

local function isPage(node)
    return node.type == "group" and not node.inline
end

-- A page is keyed by the module's optionsKey ("enemyForces"), the module by its
-- name ("EnemyForces"). Built once; modules register long before a window opens.
local moduleByKey

local function moduleFor(key)
    if not moduleByKey then
        moduleByKey = {}
        for _, module in Addon:IterateModules() do
            if module.optionsKey then moduleByKey[module.optionsKey] = module end
        end
    end
    return moduleByKey[key]
end

-- A page with no module behind it counts as on, so the ratio never reads as broken.
local function enabledCount(children)
    local on = 0
    for i = 1, #children do
        local module = moduleFor(children[i].key)
        if not module or module:IsEnabled() then on = on + 1 end
    end
    return format("%d / %d", on, #children)
end

-- Footer -------------------------------------------------------------------

-- What this session has changed, and the way back. No fill: the body gradient
-- has already reached "base" down here, and another layer would darken it.
local function buildFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetPoint("BOTTOMRIGHT")
    OT:Line(footer, "TOP", "line")

    footer.dot = footer:CreateTexture(nil, "ARTWORK")
    footer.dot:SetSize(6, 6)
    footer.dot:SetTexture(OT.DOT)
    footer.dot:SetTexCoord(unpack(OT.DOT_FILLED))
    footer.dot:SetPoint("LEFT", PAD + CHIP_PAD, 0)
    OT:TintVertex(footer.dot, "accent")

    footer.chipText = OT:Text(footer, "normal", "text")
    footer.chipText:SetPoint("LEFT", footer.dot, "RIGHT", CHIP_PAD, 0)

    footer.chip = footer:CreateTexture(nil, "BACKGROUND")
    footer.chip:SetHeight(OT.size.control)
    footer.chip:SetPoint("LEFT", footer.dot, "LEFT", -CHIP_PAD, 0)
    footer.chip:SetPoint("RIGHT", footer.chipText, "RIGHT", CHIP_PAD, 0)
    OT:Tint(footer.chip, "card")

    footer.version = OT:Text(footer, "small", "faint")
    footer.version:SetPoint("RIGHT", -PAD, 0)
    footer.version:SetText(Addon.version or "")
    return footer
end

-- Built once: the journal keys on the node, so a fresh table per draw would
-- count one press twice.
local discardNode

local function footerNode()
    if not discardNode then
        discardNode = {
            type = "execute",
            name = ns.L["Discard"],
            desc = ns.L["Put back the value every setting had before this session."],
            func = function() Controls:DiscardChanges() end,
        }
    end
    return discardNode
end

function Window:RefreshFooter()
    local f = self.frame
    if not f then return end

    local footer = f.footer
    local count = Controls:ChangeCount()
    local changed = count > 0

    footer.chipText:SetText(format(ns.L["%d changes this session"], count))
    footer.chipText:SetShown(changed)
    footer.chip:SetShown(changed)
    footer.dot:SetShown(changed)

    if not footer.discard or footer.discard.owner ~= footer then
        footer.discard = Controls:Acquire("Execute", footer)
        footer.discard:SetRowMode(false)
        footer.discard.frame:SetPoint("LEFT", footer.chip, "RIGHT", OT.space.sm, -2)
    end
    footer.discard:SetOption(footerNode())
    footer.discard:SetWidth(footer.discard:NaturalWidth())
    footer.discard.frame:SetShown(changed)
end

-- Build --------------------------------------------------------------------

local function buildFrame()
    local f = Controls:BuildWindow(Window, {
        name = FRAME_NAME,
        title = "MAUI M+ Timer",
        logo = LOGO,
        width = DEFAULT_W,
        height = DEFAULT_H,
        minWidth = MIN_W,
        minHeight = MIN_H,
    })
    local header = f.header

    -- Search lives in the title bar, not in the sidebar: it looks through every page.
    local searchBox = header:CreateTexture(nil, "BACKGROUND")
    searchBox:SetSize(SEARCH_W, OT.size.control)
    searchBox:SetPoint("RIGHT", f.resetButton, "LEFT", -OT.space.sm, 0)
    OT:Tint(searchBox, "input")
    OT:OutlineRegion(header, searchBox, "line")
    f.crumb:SetPoint("RIGHT", searchBox, "LEFT", -OT.space.md, 0)

    local clear = CreateFrame("Button", nil, header)
    clear:SetSize(OT.size.control, OT.size.control)
    clear:SetPoint("RIGHT", searchBox, "RIGHT", 0, 0)
    clear:Hide()
    local clearGlyph = clear:CreateTexture(nil, "ARTWORK")
    clearGlyph:SetSize(14, 14)
    clearGlyph:SetPoint("CENTER")
    clearGlyph:SetTexture(OT.CLOSE)
    OT:TintVertex(clearGlyph, "faint")
    clear:SetScript("OnEnter", function() clearGlyph:SetVertexColor(OT:Unpack("text")) end)
    clear:SetScript("OnLeave", function() clearGlyph:SetVertexColor(OT:Unpack("faint")) end)

    local search = CreateFrame("EditBox", nil, header)
    search:SetPoint("TOPLEFT", searchBox, "TOPLEFT", OT.space.sm, 0)
    search:SetPoint("BOTTOMRIGHT", clear, "BOTTOMLEFT", 0, 0)
    OT:ApplyFont(search, "normal")
    search:SetTextColor(OT:Unpack("text"))
    search:SetAutoFocus(false)

    local hint = OT:Text(search, "normal", "faint")
    hint:SetPoint("LEFT")
    hint:SetText(ns.L["Search"])

    search:SetScript("OnTextChanged", function(s)
        local text = s:GetText()
        hint:SetShown(text == "")
        clear:SetShown(text ~= "")
        Window.filter = text:lower()
        Window:BuildNav()
        Window:Draw()
    end)
    search:SetScript("OnEscapePressed", function(s)
        s:SetText("")
        s:ClearFocus()
    end)
    clear:SetScript("OnClick", function()
        search:SetText("")
        search:ClearFocus()
    end)

    f.search = search
    f.footer = buildFooter(f.body)

    -- Every write goes through the controls, and the footer is what shows it.
    Controls.OnChange = function() Window:RefreshFooter() end

    -- Options that show or hide others call NotifyChange; a refresh cannot add
    -- a control that was hidden, so the page is laid out again.
    LibStub("AceConfigRegistry-3.0").RegisterCallback(Window, "ConfigTableChange", function(_, appName)
        if appName == ADDON_NAME and Window:IsShown() then Window:Redraw() end
    end)

    Window.frame = f
    return f
end

-- Navigation -------------------------------------------------------------

local navRows, navHeadings = {}, {}

local function navRow(index)
    navRows[index] = navRows[index] or Controls.ListRow(Window.frame.list)
    return navRows[index]
end

local function navHeading(index)
    navHeadings[index] = navHeadings[index] or Controls:ListHeading(Window.frame.list)
    return navHeadings[index]
end

-- Global rather than per profile: folding is a way of looking at the window.
function Window:Collapsed(title)
    local store = Addon.db.global.optionsWindow
    return store.collapsed ~= nil and store.collapsed[title] == true
end

function Window:ToggleSection(title)
    local store = Addon.db.global.optionsWindow
    store.collapsed = store.collapsed or {}
    store.collapsed[title] = not store.collapsed[title] or nil
    self:BuildNav()
end

-- Pages with sub pages start folded, unlike the sections.
function Window:Expanded(key)
    local store = Addon.db.global.optionsWindow
    return store.expanded ~= nil and store.expanded[key] == true
end

function Window:ToggleExpanded(key)
    local store = Addon.db.global.optionsWindow
    store.expanded = store.expanded or {}
    store.expanded[key] = not store.expanded[key] or nil
    self:BuildNav()
end

-- Its own button, so folding a page does not also open it.
local function rowToggle(row)
    if row.toggle then return row.toggle end
    local toggle = CreateFrame("Button", nil, row)
    toggle:SetSize(OT.size.row, OT.size.row)
    toggle:SetPoint("RIGHT", -OT.space.xs, 0)
    toggle.chevron = Controls:Chevron(toggle, 7)
    toggle.chevron:SetPoint("CENTER")
    toggle:SetScript("OnEnter", function() toggle.chevron:SetColor("text") end)
    toggle:SetScript("OnLeave", function() toggle.chevron:SetColor("muted") end)
    row.toggle = toggle
    return toggle
end

-- Display pages, modules, system pages. Anything new lands under Display unless
-- it is a module or named here, so the list cannot silently lose a page.
local SYSTEM_KEYS = { profiles = true, changelog = true, about = true }

function Window:Sections()
    local root = self:RootContext()
    local display, system, modules = {}, {}, nil

    for _, entry in ipairs(self.SortedArgs(self.options, isPage, root)) do
        if entry.key == "modules" then
            modules = entry
        elseif SYSTEM_KEYS[entry.key] then
            system[#system + 1] = entry
        else
            display[#display + 1] = entry
        end
    end

    local list = { { title = ns.L["Display"], entries = display } }
    if modules then
        local children = self.SortedArgs(modules.node, isPage,
            self.ChildContext(root, modules.key, modules.node))
        list[#list + 1] = {
            title = ns.L["Modules"], entries = children,
            parentKey = modules.key, count = enabledCount(children),
        }
    end
    list[#list + 1] = { title = ns.L["System"], entries = system }
    return list
end

function Window:BuildNav()
    local f = self.frame
    local rowIndex, headingIndex, y = 0, 0, 0

    local function addRow(entry, parentKey, isModule)
        rowIndex = rowIndex + 1
        local row = navRow(rowIndex)
        row:SetPoint("TOPLEFT", f.list, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", f.list, "TOPRIGHT", 0, -y)
        local indent = (parentKey and not isModule) and OT.size.indent or 0
        row.icon:SetPoint("LEFT", OT.space.md + indent, 0)
        row.label:SetPoint("LEFT", OT.space.md + 22 + indent, 0)

        -- A module shows its colour as a dot, hollow when switched off; other pages keep their icon.
        local module = isModule and moduleFor(entry.key)
        local on = not module or module:IsEnabled()

        row.icon:SetTexture(entry.node.icon)
        row.icon:SetShown(not isModule and entry.node.icon ~= nil)
        row.dot:SetShown(isModule)
        if isModule then
            row.dot:SetTexCoord(unpack(on and OT.DOT_FILLED or OT.DOT_RING))
            local color = OT.moduleColor[module and module:GetName() or entry.key]
            if on and color then
                row.dot:SetVertexColor(color[1], color[2], color[3], 1)
            else
                row.dot:SetVertexColor(OT:Unpack("faint"))
            end
        end

        -- BuildOptions colours top-level names for the Ace tree; here the dot does that job.
        row.label:SetText(plain(entry.name))
        row.right:SetText((isModule and not on) and ns.L["Off"] or "")

        local active
        if parentKey then
            active = self.path[1] == parentKey and self.path[2] == entry.key
        else
            active = self.path[1] == entry.key and self.path[2] == nil
        end
        row.selected:SetShown(active)

        row:SetScript("OnClick", function()
            if parentKey then
                self:Select(parentKey, entry.key)
            else
                self:Select(entry.key)
            end
        end)
        if row.toggle then row.toggle:Hide() end
        row:Show()
        y = y + OT.size.row
        return row
    end

    -- Sections already asked the search, of whole pages rather than titles.
    for _, section in ipairs(self:Sections()) do
        local shown = section.entries

        if #shown > 0 then
            y = y + (headingIndex > 0 and OT.space.md or 0)
            headingIndex = headingIndex + 1

            local title = section.title
            local folded = self:Collapsed(title)
            local heading = navHeading(headingIndex)
            heading.frame:ClearAllPoints()
            heading.frame:SetPoint("TOPLEFT", f.list, "TOPLEFT", 0, -y)
            heading.frame:SetPoint("TOPRIGHT", f.list, "TOPRIGHT", 0, -y)
            heading.label:SetText(strupper(title))
            heading.right:SetText(section.count or tostring(#shown))
            heading.chevron:SetDirection(folded and "right" or "down")
            heading.frame:SetScript("OnClick", function()
                self:ToggleSection(title)
            end)
            heading.frame:Show()

            y = y + Controls.HEADING_H
            if not folded then
                for _, entry in ipairs(shown) do
                    local row = addRow(entry, section.parentKey, section.parentKey ~= nil)
                    -- The renderer draws inline groups only, so a page nested in
                    -- a page (Profiles > Import / Export) needs its own row.
                    if not section.parentKey then
                        local context = self.ChildContext(self:RootContext(), entry.key, entry.node)
                        local children = self.SortedArgs(entry.node, isPage, context)
                        if #children > 0 then
                            -- A search or a selected child must not end up folded away.
                            local open = self:Expanded(entry.key) or (self.filter or "") ~= ""
                                or (self.path[1] == entry.key and self.path[2] ~= nil)
                            local toggle = rowToggle(row)
                            toggle.chevron:SetDirection(open and "down" or "right")
                            toggle:SetScript("OnClick", function() self:ToggleExpanded(entry.key) end)
                            toggle:Show()
                            if open then
                                for _, child in ipairs(children) do
                                    addRow(child, entry.key, false)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for i = rowIndex + 1, #navRows do navRows[i]:Hide() end
    for i = headingIndex + 1, #navHeadings do navHeadings[i].frame:Hide() end
    f.list:SetSize(f.listScroll:GetWidth(), max(1, y))
end

-- Content ----------------------------------------------------------------

function Window:CurrentGroup()
    local group = self.options
    for i = 1, #self.path do
        group = group and group.args and group.args[self.path[i]]
    end
    return group
end

-- "Modules > Splits": the page itself reads as the place you are.
function Window:Trail(group)
    if not group then return "" end
    local page = plain(group.name)
    if #self.path < 2 then return page end
    local parent = self.options.args[self.path[1]]
    if not parent then return page end
    return format("%s  >  %s", plain(parent.name), page)
end

function Window:Draw(verifying)
    local f = self.frame
    local context, group = self:Context()
    f.crumb:SetText(self:Trail(group))
    Controls.PaintChrome(f)

    Controls:ReleaseAll(f.content)
    local width = f.body:GetWidth() - PAD * 2 - SCROLLBAR_W - OT.space.sm

    f.scroll:ClearAllPoints()
    f.scroll:SetPoint("TOPLEFT", PAD, -PAD)
    f.scroll:SetPoint("BOTTOMRIGHT", f.footer, "TOPRIGHT",
        -(PAD + SCROLLBAR_W + OT.space.sm), OT.space.sm)
    f.content:SetWidth(width)
    local height = ns.Render:Draw(f.content, group, width, context)
    f.content:SetHeight(max(1, height))

    Controls.Settle(self, f.scroll, height, verifying)
    self:RefreshFooter()
    f.layoutThumb()
end

-- Draw, but staying where the reader is on the page.
function Window:Redraw()
    local offset = self.frame.scroll:GetVerticalScroll()
    self:BuildNav()
    self:Draw()
    local range = max(0, self.frame.content:GetHeight() - self.frame.scroll:GetHeight())
    self.frame.scroll:SetVerticalScroll(min(offset, range))
    self.frame.layoutThumb()
end

function Window:Select(key, childKey)
    -- Clicking a parent that only holds pages jumps to its first child.
    local node = self.options.args[key]
    if not childKey and node then
        local context = self.ChildContext(self:RootContext(), key, node)
        local children = self.SortedArgs(node, isPage, context)
        if #children > 0
            and not next(self.SortedArgs(node, function(n) return not isPage(n) end, context)) then
            childKey = children[1].key
        end
    end
    self.path = childKey and { key, childKey } or { key }
    self:BuildNav()
    self:Draw()
end

-- Geometry ---------------------------------------------------------------

-- Shares the keys AceGUI writes, so the window keeps its place across the renderer switch.
function Window:SaveGeometry()
    Controls.SaveGeometry(self.frame, Addon.db.global.optionsWindow)
end

function Window:RestoreGeometry()
    Controls.RestoreGeometry(self.frame, Addon.db.global.optionsWindow, DEFAULT_W, DEFAULT_H)
end

function Window:ResetGeometry()
    Controls.ClearGeometry(Addon.db.global.optionsWindow)
    if self.frame then self:RestoreGeometry() end
end

-- Lifecycle --------------------------------------------------------------

function Window:Open(pathKey)
    if not self.frame then
        buildFrame()
        self.path = { "general" }
    end
    self.options = Addon:BuildOptions()
    self:RestoreGeometry()
    self.frame:Show()

    if pathKey then
        local path = Addon._optionPath and Addon._optionPath[pathKey]
        if path then
            self.path = { path[1], path[2] }
        elseif self.options.args[pathKey] then
            self.path = { pathKey }
        end
    end
    if not self:CurrentGroup() then self.path = { "general" } end
    self:BuildNav()
    self:Draw()
end

function Window:Close()
    if self.frame then self.frame:Hide() end
end

function Window:OnClosed()
    Controls:CloseList()
    Controls:ReleaseAll(self.frame.content)
    self:SaveGeometry()
end

function Window:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Close()
    else
        self:Open()
    end
end

function Window:IsShown()
    return self.frame and self.frame:IsShown()
end
