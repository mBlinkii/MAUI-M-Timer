-- BlinkiiOptions/Window.lua
-- The settings window of one app: sidebar navigation over the option tree,
-- search in the title bar, and the selected group handed to the renderer.

local lib = BlinkiiOptions
if lib.__skip then return end

local OT = lib.OT
local Controls = lib.Controls
local Tree = lib.Tree
local L = lib.L

local Window = {}
Window.__index = Window
lib.Window = Window

local DEFAULT_W, DEFAULT_H = 980, 660
local MIN_W, MIN_H = 720, 480
local PAD = OT.space.lg
local SCROLLBAR_W = 4
local SEARCH_W = 210
local FOOTER_H = 34
local CHIP_PAD = 7

local plain = Controls.Plain
local isPage = Tree.IsPage

function Window.New(app)
    return setmetatable({ app = app, path = {}, filter = "", navRows = {}, navHeadings = {} }, Window)
end

-- Every write goes through the controls, and each window's footer shows its
-- own app's count; one hook serves all of them.
Controls.OnChange = function()
    for i = 1, #lib.appOrder do
        lib.appOrder[i].window:RefreshFooter()
    end
end

-- Kept for callers that walked the tree through the window.
Window.SubtreeHit = Tree.SubtreeHit
Window.ChildContext = Tree.ChildContext
Window.SortedArgs = Tree.SortedArgs

-- Walked with ChildContext so the search travels down the path. A handler on
-- a group (a profiles page, for one) is inherited by every entry below it.
function Window:Context()
    local context = self:RootContext()
    local group = self.options
    for i = 1, #self.path do
        local child = group.args and group.args[self.path[i]]
        if not child then break end
        context = Tree.ChildContext(context, self.path[i], child)
        group = child
    end
    return context, group
end

function Window:RootContext()
    return {
        options = self.options,
        appName = self.app.name,
        uiName = self.app.name,
        path = {},
        handler = self.options.handler,
        filter = (self.filter ~= "" and self.filter) or nil,
    }
end

-- Footer -------------------------------------------------------------------

-- What this session has changed, and the way back. No fill: the body gradient
-- has already reached "base" down here, and another layer would darken it.
local function buildFooter(window, parent)
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
    footer.version:SetText(window.app:Get("version") or "")
    return footer
end

-- Built once per window: the journal keys on the node, so a fresh table per
-- draw would count one press twice.
function Window:FooterNode()
    if not self.discardNode then
        local appName = self.app.name
        self.discardNode = {
            type = "execute",
            name = L["Discard"],
            desc = L["Put back the value every setting had before this session."],
            func = function() Controls:DiscardChanges(appName) end,
        }
    end
    return self.discardNode
end

function Window:RefreshFooter()
    local f = self.frame
    if not f then return end

    local footer = f.footer
    local count = Controls:ChangeCount(self.app.name)
    local changed = count > 0

    footer.chipText:SetText(format(L["%d changes this session"], count))
    footer.chipText:SetShown(changed)
    footer.chip:SetShown(changed)
    footer.dot:SetShown(changed)

    if not footer.discard or footer.discard.owner ~= footer then
        footer.discard = Controls:Acquire("Execute", footer)
        footer.discard:SetRowMode(false)
        footer.discard.frame:SetPoint("LEFT", footer.chip, "RIGHT", OT.space.sm, -2)
    end
    footer.discard:SetOption(self:FooterNode())
    footer.discard:SetWidth(footer.discard:NaturalWidth())
    footer.discard.frame:SetShown(changed)
end

-- Build --------------------------------------------------------------------

function Window:Build()
    local app = self.app
    local f = Controls:BuildWindow(self, {
        name = app:Get("frameName") or ("BlinkiiOptions_" .. app.name:gsub("%W", "")),
        title = app:Get("title") or app.name,
        logo = app:Get("logo"),
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
    hint:SetText(L["Search"])

    search:SetScript("OnTextChanged", function(s)
        local text = s:GetText()
        hint:SetShown(text == "")
        clear:SetShown(text ~= "")
        self.filter = text:lower()
        self:BuildNav()
        self:Draw()
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
    f.footer = buildFooter(self, f.body)
    self.frame = f
    return f
end

-- Navigation -------------------------------------------------------------

function Window:NavRow(index)
    self.navRows[index] = self.navRows[index] or Controls.ListRow(self.frame.list)
    return self.navRows[index]
end

function Window:NavHeading(index)
    self.navHeadings[index] = self.navHeadings[index] or Controls:ListHeading(self.frame.list)
    return self.navHeadings[index]
end

-- Account wide rather than per profile: folding is a way of looking at the window.
function Window:Collapsed(title)
    local store = self.app:Store()
    return store.collapsed ~= nil and store.collapsed[title] == true
end

function Window:ToggleSection(title)
    local store = self.app:Store()
    store.collapsed = store.collapsed or {}
    store.collapsed[title] = not store.collapsed[title] or nil
    self:BuildNav()
end

-- Pages with sub pages start folded, unlike the sections.
function Window:Expanded(key)
    local store = self.app:Store()
    return store.expanded ~= nil and store.expanded[key] == true
end

function Window:ToggleExpanded(key)
    local store = self.app:Store()
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

-- The app arranges the sidebar (see README); without a sections callback it is
-- one section holding every top-level page.
function Window:Sections()
    local sections = self.app:Get("sections", self)
    if type(sections) == "table" then return sections end
    local root = self:RootContext()
    return { { title = L["Settings"], entries = Tree.SortedArgs(self.options, isPage, root) } }
end

function Window:BuildNav()
    local f = self.frame
    local rowIndex, headingIndex, y = 0, 0, 0

    -- flat: the section lists children of parentKey side by side (a module list)
    -- rather than pages that unfold their own sub pages below them.
    local function addRow(entry, parentKey, flat)
        rowIndex = rowIndex + 1
        local row = self:NavRow(rowIndex)
        row:SetPoint("TOPLEFT", f.list, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", f.list, "TOPRIGHT", 0, -y)
        local indent = (parentKey and not flat) and OT.size.indent or 0
        row.icon:SetPoint("LEFT", OT.space.md + indent, 0)
        row.label:SetPoint("LEFT", OT.space.md + 22 + indent, 0)

        -- An entry with a dot shows it, hollow when switched off; other pages keep their icon.
        local dot = entry.dot
        Controls.SetIcon(row.icon, entry.node.icon)
        row.icon:SetShown(not dot and entry.node.icon ~= nil)
        row.dot:SetShown(dot ~= nil)
        if dot then
            row.dot:SetTexCoord(unpack(dot.on and OT.DOT_FILLED or OT.DOT_RING))
            local color = dot.color
            if dot.on and color then
                row.dot:SetVertexColor(color[1], color[2], color[3], 1)
            else
                row.dot:SetVertexColor(OT:Unpack("faint"))
            end
        end

        row.label:SetText(plain(entry.name))
        row.right:SetText((dot and not dot.on) and L["Off"] or "")

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
            local heading = self:NavHeading(headingIndex)
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
                        local context = Tree.ChildContext(self:RootContext(), entry.key, entry.node)
                        local children = Tree.SortedArgs(entry.node, isPage, context)
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

    for i = rowIndex + 1, #self.navRows do self.navRows[i]:Hide() end
    for i = headingIndex + 1, #self.navHeadings do self.navHeadings[i].frame:Hide() end
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
    local height = lib.Render:Draw(f.content, group, width, context)
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
        local context = Tree.ChildContext(self:RootContext(), key, node)
        local children = Tree.SortedArgs(node, isPage, context)
        if #children > 0
            and not next(Tree.SortedArgs(node, function(n) return not isPage(n) end, context)) then
            childKey = children[1].key
        end
    end
    self.path = childKey and { key, childKey } or { key }
    self:BuildNav()
    self:Draw()
end

-- Geometry ---------------------------------------------------------------

function Window:SaveGeometry()
    Controls.SaveGeometry(self.frame, self.app:Store())
end

function Window:RestoreGeometry()
    Controls.RestoreGeometry(self.frame, self.app:Store(), DEFAULT_W, DEFAULT_H)
end

function Window:ResetGeometry()
    Controls.ClearGeometry(self.app:Store())
    if self.frame then self:RestoreGeometry() end
end

-- Lifecycle --------------------------------------------------------------

-- The first page, unless the app names one.
function Window:DefaultPath()
    local path = self.app:Get("defaultPath")
    if type(path) == "table" and path[1] then return { path[1], path[2] } end
    local first = Tree.SortedArgs(self.options, isPage, self:RootContext())[1]
    return first and { first.key } or {}
end

function Window:Open(pathKey)
    local fresh = not self.frame
    if fresh then self:Build() end
    self.options = self.app:Get("options") or { type = "group", args = {} }
    if fresh then self.path = self:DefaultPath() end
    self:RestoreGeometry()
    if self.frame:IsShown() then
        self.frame:Raise()
        OT:Use(self.app)
    else
        self.frame:Show()
    end

    if pathKey then
        local path = self.app:Get("resolvePath", pathKey)
        if type(path) == "table" and path[1] then
            self.path = { path[1], path[2] }
        elseif self.options.args[pathKey] then
            self.path = { pathKey }
        end
    end
    if not self:CurrentGroup() then self.path = self:DefaultPath() end
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
    return self.frame ~= nil and self.frame:IsShown()
end
