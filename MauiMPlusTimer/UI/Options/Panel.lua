-- UI/Options/Panel.lua
-- A second window of the same make as the settings one, with its own list on
-- the left instead of the option tree. A page is an AceConfig group table,
-- drawn by the same renderer.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local OT = ns.OT
local Controls = ns.Controls

local Panel = {}
ns.Panel = Panel
Addon.Panel = Panel

local PAD = OT.space.lg
local SCROLLBAR_W = 4
local MIN_W, MIN_H = 620, 420
local BANNER_H = 66
local ACTION_MIN_H = 52

local plain = Controls.Plain

-- Geometry and folded sections per panel, beside the settings window's own.
local function store(id)
    local global = Addon.db.global
    global.panels = global.panels or {}
    global.panels[id] = global.panels[id] or {}
    return global.panels[id]
end

-- List ---------------------------------------------------------------------

local function listRow(panel, index)
    panel.rows[index] = panel.rows[index] or Controls.ListRow(panel.list)
    return panel.rows[index]
end

local function listHeading(panel, index)
    panel.headings[index] = panel.headings[index] or Controls:ListHeading(panel.list)
    return panel.headings[index]
end

-- config.collapsible = false turns folding off for the whole list.
function Panel:Collapsed(title)
    if self.config.collapsible == false then return false end
    local folded = store(self.id).collapsed
    return folded ~= nil and folded[title] == true
end

function Panel:ToggleSection(title)
    local kept = store(self.id)
    kept.collapsed = kept.collapsed or {}
    kept.collapsed[title] = not kept.collapsed[title] or nil
    self:BuildList()
end

function Panel:BuildList()
    local entries = self.config.BuildList(self) or {}
    self.entries = entries

    -- Every section says how much is in it, folded or not, so counting comes first.
    local counts, current = {}, nil
    for _, entry in ipairs(entries) do
        if entry.header then
            current = plain(entry.text)
            counts[current] = 0
        elseif current then
            counts[current] = counts[current] + 1
        end
    end

    local rowIndex, headingIndex, y = 0, 0, 0
    local folded = false
    for _, entry in ipairs(entries) do
        if entry.header then
            y = y + (headingIndex > 0 and OT.space.md or 0)
            headingIndex = headingIndex + 1

            local title = plain(entry.text)
            folded = self:Collapsed(title)
            local heading = listHeading(self, headingIndex)
            heading.frame:ClearAllPoints()
            heading.frame:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
            heading.frame:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -y)
            heading.label:SetText(strupper(title))
            heading.right:SetText(entry.right or tostring(counts[title] or ""))
            heading.chevron:SetDirection(folded and "right" or "down")
            heading.chevron:SetShown(self.config.collapsible ~= false)
            heading.frame:SetScript("OnClick", function()
                if self.config.collapsible == false then return end
                self:ToggleSection(title)
            end)
            heading.frame:Show()
            y = y + Controls.HEADING_H
        elseif not folded then
            rowIndex = rowIndex + 1
            local row = listRow(self, rowIndex)
            row:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -y)

            Controls.SetIcon(row.icon, entry.icon)
            row.icon:SetShown(entry.icon ~= nil and entry.color == nil)
            row.dot:SetShown(entry.color ~= nil)
            if entry.color then
                row.dot:SetTexCoord(unpack(entry.dim and OT.DOT_RING or OT.DOT_FILLED))
                row.dot:SetVertexColor(entry.color[1], entry.color[2], entry.color[3], 1)
            end

            row.label:SetText(plain(entry.text))
            row.label:SetTextColor(OT:Unpack(entry.dim and "muted" or "text"))
            row.right:SetText(entry.right or "")
            row.selected:SetShown(self.selected == entry.key)

            local key = entry.key
            row:SetScript("OnClick", function() self:Select(key) end)
            row:Show()
            y = y + OT.size.row
        end
    end

    for i = rowIndex + 1, #self.rows do self.rows[i]:Hide() end
    for i = headingIndex + 1, #self.headings do self.headings[i].frame:Hide() end
    self.list:SetSize(self.listScroll:GetWidth(), max(1, y))
end

-- Banner -------------------------------------------------------------------

-- The strip above the page: the dungeon, its headline figure and a bar.
function Panel:BuildBanner(parent)
    local banner = CreateFrame("Frame", nil, parent)
    banner:SetHeight(BANNER_H)
    banner:EnableMouse(false)
    OT:Fill(banner, "card")
    OT:Outline(banner, "line")

    banner.title = OT:Text(banner, "heading", "text")
    banner.title:SetPoint("TOPLEFT", OT.space.md, -OT.space.sm)
    banner.title:SetJustifyH("LEFT")

    banner.tag = OT:Text(banner, "normal", "accent")
    banner.tag:SetPoint("LEFT", banner.title, "RIGHT", OT.space.sm, 0)

    banner.sub = OT:Text(banner, "small", "muted")
    banner.sub:SetPoint("TOPLEFT", banner.title, "BOTTOMLEFT", 0, -3)
    banner.sub:SetJustifyH("LEFT")

    banner.big = OT:Text(banner, "title", "text")
    banner.big:SetPoint("TOPRIGHT", -OT.space.md, -OT.space.sm)
    banner.big:SetJustifyH("RIGHT")

    banner.bigSub = OT:Text(banner, "small", "muted")
    banner.bigSub:SetPoint("TOPRIGHT", banner.big, "BOTTOMRIGHT", 0, -2)
    banner.bigSub:SetJustifyH("RIGHT")

    banner.track = banner:CreateTexture(nil, "ARTWORK")
    banner.track:SetHeight(4)
    banner.track:SetPoint("BOTTOMLEFT", OT.space.md, OT.space.sm)
    banner.track:SetPoint("BOTTOMRIGHT", -OT.space.md, OT.space.sm)
    OT:Tint(banner.track, "lineStrong")

    -- Coloured from the progress in DrawBanner, not tinted with the accent.
    banner.fill = banner:CreateTexture(nil, "OVERLAY")
    banner.fill:SetHeight(4)
    banner.fill:SetPoint("BOTTOMLEFT", banner.track, "BOTTOMLEFT")
    return banner
end

function Panel:DrawBanner(width)
    local banner = self.banner
    local data = self.config.BuildBanner and self.config.BuildBanner(self, self.selected)
    if not data then
        banner:Hide()
        return false
    end

    banner:SetWidth(width)
    banner.title:SetText(data.title or "")
    banner.tag:SetText(data.tag or "")
    banner.sub:SetText(data.sub or "")
    banner.big:SetText(data.big or "")
    banner.big:SetTextColor(OT:Unpack(data.bigColor or "text"))
    banner.bigSub:SetText(data.bigSub or "")

    local progress = data.progress
    banner.track:SetShown(progress ~= nil)
    banner.fill:SetShown(progress ~= nil)
    if progress then
        -- The track is anchored, so its width is not settled in this frame.
        local trackWidth = max(1, width - OT.space.md * 2)
        banner.fill:SetWidth(max(0.001, trackWidth * min(1, max(0, progress))))
        OT:PaintProgress(banner.fill, progress)
    end

    banner:Show()
    return true
end

-- Action bar ---------------------------------------------------------------

-- The page's one destructive action, pinned to the bottom so a long list of
-- runs cannot push it out of sight. No fill, same as the settings footer.
function Panel:BuildActionBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(ACTION_MIN_H)
    bar:SetPoint("BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    OT:Line(bar, "TOP", "line")

    bar.title = OT:Text(bar, "normal", "text")
    bar.title:SetPoint("TOPLEFT", PAD, -OT.space.sm)
    bar.title:SetJustifyH("LEFT")

    bar.desc = OT:Text(bar, "small", "muted")
    bar.desc:SetPoint("TOPLEFT", bar.title, "BOTTOMLEFT", 0, -2)
    bar.desc:SetJustifyH("LEFT")
    return bar
end

function Panel:DrawAction()
    local bar = self.action
    local node = self.config.BuildAction and self.config.BuildAction(self, self.selected)
    if not node then
        if self.actionButton and self.actionButton.owner == bar then
            Controls:Release(self.actionButton)
            self.actionButton = nil
        end
        bar:Hide()
        return false
    end

    if not self.actionButton or self.actionButton.owner ~= bar then
        self.actionButton = Controls:Acquire("Execute", bar)
        self.actionButton.frame:SetPoint("RIGHT", bar, "RIGHT", -PAD, 0)
    end
    self.actionButton:SetOption(node)
    local buttonWidth = self.actionButton:NaturalWidth()
    self.actionButton:SetWidth(buttonWidth)

    local textWidth = max(60, self.body:GetWidth() - PAD * 2 - buttonWidth - OT.space.lg)
    bar.title:SetWidth(textWidth)
    bar.title:SetText(Controls.NameOf(node))
    bar.desc:SetWidth(textWidth)
    bar.desc:SetText(Controls.DescOf(node) or "")

    bar:SetHeight(max(ACTION_MIN_H, OT.space.sm * 2
        + ceil(bar.title:GetStringHeight()) + 2 + ceil(bar.desc:GetStringHeight())))
    bar:Show()
    return true
end

-- Page ---------------------------------------------------------------------

function Panel:Draw(verifying)
    local group = self.config.BuildPage(self, self.selected)
    self.crumb:SetText(group and plain(group.name) or "")
    Controls.PaintChrome(self.frame)

    Controls:ReleaseAll(self.content)
    local width = self.body:GetWidth() - PAD * 2 - SCROLLBAR_W - OT.space.sm
    local hasBanner = self:DrawBanner(width)
    local hasAction = self:DrawAction()

    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", self.banner, hasBanner and "BOTTOMLEFT" or "TOPLEFT",
        0, hasBanner and -OT.space.md or 0)
    if hasAction then
        self.scroll:SetPoint("BOTTOMRIGHT", self.action, "TOPRIGHT",
            -(PAD + SCROLLBAR_W + OT.space.sm), OT.space.sm)
    else
        self.scroll:SetPoint("BOTTOMRIGHT", self.body, "BOTTOMRIGHT",
            -(PAD + SCROLLBAR_W + OT.space.sm), PAD)
    end
    self.content:SetWidth(width)

    local height = 0
    if group then
        height = ns.Render:Draw(self.content, group, width, {
            options = group,
            appName = ADDON_NAME,
            uiName = ADDON_NAME,
            path = {},
        })
    end
    self.content:SetHeight(max(1, height))

    Controls.Settle(self, self.scroll, height, verifying)
    self.layoutThumb()
end

function Panel:Select(key)
    self.selected = key
    self:BuildList()
    self:Draw()
end

-- After the data changed: the list may have gained or lost entries.
function Panel:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self:BuildList()
    self:Draw()
end

-- Build --------------------------------------------------------------------

function Panel:Build()
    local config = self.config
    local f = Controls:BuildWindow(self, {
        name = config.globalName,
        -- A function, because ns.L does not exist while the files load.
        title = type(config.title) == "function" and config.title() or config.title,
        width = config.width or 900,
        height = config.height or 600,
        minWidth = MIN_W,
        minHeight = MIN_H,
        sidebarWidth = config.listWidth,
    })
    self.frame = f
    self.crumb, self.list, self.listScroll = f.crumb, f.list, f.listScroll
    self.body, self.scroll, self.content = f.body, f.scroll, f.content
    self.layoutThumb = f.layoutThumb

    self.banner = self:BuildBanner(f.body)
    self.banner:SetPoint("TOPLEFT", PAD, -PAD)
    self.action = self:BuildActionBar(f.body)
end

-- Geometry -----------------------------------------------------------------

function Panel:SaveGeometry()
    Controls.SaveGeometry(self.frame, store(self.id))
end

function Panel:RestoreGeometry()
    Controls.RestoreGeometry(self.frame, store(self.id), self.config.width or 900, self.config.height or 600)
end

function Panel:ResetGeometry()
    Controls.ClearGeometry(store(self.id))
    self:RestoreGeometry()
end

-- Lifecycle ----------------------------------------------------------------

function Panel:Open()
    -- These panels are as large as the settings window and would bury it.
    local settings = Addon.OptionsWindow
    if settings and settings:IsShown() then
        self.restoreSettings = true
        settings:Close()
    end

    if not self.frame then self:Build() end
    self:RestoreGeometry()
    self.frame:Show()

    if self.selected == nil and self.config.Default then
        self.selected = self.config.Default(self)
    end
    self:BuildList()
    if self.selected == nil and self.entries then
        for _, entry in ipairs(self.entries) do
            if not entry.header then
                self.selected = entry.key
                break
            end
        end
        self:BuildList()
    end
    self:Draw()
end

function Panel:Close()
    if self.frame then self.frame:Hide() end
end

function Panel:OnClosed()
    Controls:CloseList()
    Controls:ReleaseAll(self.content)
    self:SaveGeometry()

    if self.restoreSettings then
        self.restoreSettings = nil
        Addon.OptionsWindow:Open()
    end
end

function Panel:Toggle()
    if self:IsShown() then self:Close() else self:Open() end
end

function Panel:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

-- config: title (string or function), globalName, width, height, listWidth,
-- BuildList, BuildPage, Default, and optional BuildBanner and BuildAction.
-- BuildPage returns an AceConfig group; BuildBanner nil or
-- { title, tag, sub, big, bigColor, bigSub, progress }; BuildAction nil or an
-- execute node for the bar pinned to the bottom.
function Panel.New(id, config)
    return setmetatable({ id = id, config = config, rows = {}, headings = {} },
        { __index = Panel })
end
