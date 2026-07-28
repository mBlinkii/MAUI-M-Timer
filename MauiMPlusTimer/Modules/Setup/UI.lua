-- Modules/Setup/UI.lua
-- The three-step wizard window. Presentation only: applying a profile lives in
-- Core/Profiles.lua, checkpoint data in the Checkpoints module.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Setup = Addon:GetModule("Setup")

local AceGUI = LibStub("AceGUI-3.0")

local UI = {}
Setup.UI = UI

local WINDOW_WIDTH, WINDOW_HEIGHT = 560, 500
local SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT = 512, 160 -- native size of the presets
local PREVIEW_WIDTH = 160 -- width the preview is scaled to in the left column

-- Font pack the shipped presets reference.
local MEDIA_PACK_NAME  = "Blinkiis Media Pack"
local MEDIA_PACK_ADDON = "!mMT_MediaPack"
local MEDIA_PACK_URL   = "https://www.curseforge.com/wow/addons/mmt-media-pack"

local function mediaPackLoaded()
    return (C_AddOns and C_AddOns.IsAddOnLoaded
        and C_AddOns.IsAddOnLoaded(MEDIA_PACK_ADDON)) or false
end

function UI:Show()
    if self.frame then return end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("MAUI M+ Timer")
    frame:SetWidth(WINDOW_WIDTH)
    frame:SetHeight(WINDOW_HEIGHT)
    frame:SetLayout("Fill")
    frame:EnableResize(false)
    -- Closing counts as seen, so a fresh install is never nagged twice.
    frame:SetCallback("OnClose", function(widget)
        UI:HideNav()
        UI:RestoreCloseButton() -- must run before the frame is pooled
        Setup:MarkDone()
        AceGUI:Release(widget)
        UI.frame = nil
    end)

    self.frame = frame
    self._step = 1
    self:RenderStep()
end

function UI:Hide()
    if self.frame then
        self.frame:Hide() -- fires OnClose, which releases and marks done
    end
end

-- WoW cannot open browser links, so the URL sits in a focused, pre-highlighted
-- edit box. Registered lazily, so the locale is loaded by then.
function UI:ShowMediaPackPopup()
    local L = ns.L
    if not StaticPopupDialogs["MAUIMPT_MEDIAPACK"] then
        StaticPopupDialogs["MAUIMPT_MEDIAPACK"] = {
            text = L["Copy the link to download the media pack (%s), then open it in your web browser:"],
            button1 = OKAY,
            hasEditBox = true,
            editBoxWidth = 350,
            OnShow = function(popup)
                -- Retail's GameDialog renamed editBox to EditBox.
                local eb = popup.EditBox or popup.editBox
                if not eb then return end
                eb:SetText(MEDIA_PACK_URL)
                eb:HighlightText()
                eb:SetFocus()
            end,
            EditBoxOnTextChanged = function(eb)
                -- Effectively read-only.
                if eb:GetText() ~= MEDIA_PACK_URL then
                    eb:SetText(MEDIA_PACK_URL)
                    eb:HighlightText()
                end
            end,
            EditBoxOnEnterPressed = function(eb) eb:GetParent():Hide() end,
            EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3, -- avoid taint from the default StaticPopup index
        }
    end
    StaticPopup_Show("MAUIMPT_MEDIAPACK", MEDIA_PACK_NAME)
end

local function addHeading(container, text)
    local h = AceGUI:Create("Heading")
    h:SetText(text)
    h:SetFullWidth(true)
    container:AddChild(h)
end

local function addText(container, text, fontObject)
    local label = AceGUI:Create("Label")
    label:SetText(text .. "\n")
    label:SetFullWidth(true)
    if fontObject then label:SetFontObject(fontObject) end
    container:AddChild(label)
end

-- AceGUI has no right alignment, so a spacer pushes the button to the right
-- edge of a full-width flow row. widthFrac is the button's share of it.
local function addRightButton(container, text, onClick, widthFrac)
    widthFrac = widthFrac or 0.42

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    container:AddChild(row)

    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetRelativeWidth(1 - widthFrac - 0.02)
    row:AddChild(spacer)

    local btn = AceGUI:Create("Button")
    btn:SetText(text)
    btn:SetRelativeWidth(widthFrac)
    btn:SetCallback("OnClick", onClick)
    row:AddChild(btn)
    return btn
end

-- Wide enough for the longest label in every shipped locale; the close button
-- is widened to match (StyleCloseButton).
local NAV_BUTTON_WIDTH = 120
local NAV_GAP = 8
local NAV_Y = 17 -- the AceGUI close button's own row

local LOGO_TEXTURE = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\icon_big"
local LOGO_SIZE = 190

local STEP_ACTIVE_COLOR = "40c057"
local STEP_INACTIVE_COLOR = "808080"
local TOTAL_STEPS = 3

-- An AceGUI Button rather than a plain frame, so skins that hook AceGUI (ElvUI,
-- Masque) style it like the in-content ones. Positioned directly, not added to
-- a container.
local function ensureNavButton(field)
    local widget = UI[field]
    if not widget then
        widget = AceGUI:Create("Button")
        widget:SetWidth(NAV_BUTTON_WIDTH)
        widget:SetHeight(20)
        -- Guards against AceGUI recycling the host frame for another dialog.
        widget.frame:SetScript("OnShow", function(f)
            if not (UI.frame and UI.frame.frame == f:GetParent()) then f:Hide() end
        end)
        UI[field] = widget
    end

    local host = UI.frame.frame
    widget.frame:SetParent(host)
    widget.frame:SetFrameLevel(host:GetFrameLevel() + 10)
    return widget
end

-- Outside the scroll content, so they stay pinned while the step scrolls.
function UI:EnsureNavButtons()
    self.navLeft = ensureNavButton("navLeft")
    self.navNext = ensureNavButton("navNext")
    self:StyleCloseButton()
end

-- AceGUI keeps it as a local, so it has to be found by its CLOSE label.
function UI:GetCloseButton()
    for _, child in ipairs({ self.frame.frame:GetChildren() }) do
        if child.GetText and child:GetText() == CLOSE then
            return child
        end
    end
end

function UI:StyleCloseButton()
    local close = self:GetCloseButton()
    if close then close:SetWidth(NAV_BUTTON_WIDTH) end
end

-- Back to the AceGUI default of 100. OnAcquire does not reset the width, and
-- the frame pool is shared with every addon embedding the library, so without
-- this the widening leaks into the next dialog reusing the frame.
function UI:RestoreCloseButton()
    local close = self:GetCloseButton()
    if close then close:SetWidth(100) end
end

-- A nil text hides that button.
function UI:SetNav(leftText, leftFn, nextText, nextFn)
    self:EnsureNavButtons()
    local host = self.frame.frame

    local function configure(widget, text, fn)
        if text then
            widget:SetText(text)
            widget:SetCallback("OnClick", function() fn() end)
            widget.frame:Show()
        else
            widget.frame:Hide()
        end
    end

    configure(self.navLeft, leftText, leftFn)
    configure(self.navNext, nextText, nextFn)

    self.navLeft.frame:ClearAllPoints()
    self.navLeft.frame:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 27, NAV_Y)
    -- The widened close button's left edge sits at -147, so -155 leaves a gap.
    self.navNext.frame:ClearAllPoints()
    self.navNext.frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -155, NAV_Y)
end

-- Spans the gap between the two footer buttons, so it stays centered.
function UI:EnsureStepIndicator()
    if not self.stepFrame then
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetHeight(24)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetAllPoints(f)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        f:SetScript("OnShow", function(fr)
            if not (UI.frame and UI.frame.frame == fr:GetParent()) then fr:Hide() end
        end)
        self.stepFrame, self.stepText = f, fs
    end

    local host = self.frame.frame
    self.stepFrame:SetParent(host)
    self.stepFrame:SetFrameLevel(host:GetFrameLevel() + 10)
    self.stepFrame:ClearAllPoints()
    self.stepFrame:SetPoint("LEFT", self.navLeft.frame, "RIGHT", NAV_GAP, 0)
    self.stepFrame:SetPoint("RIGHT", self.navNext.frame, "LEFT", -NAV_GAP, 0)
    self.stepFrame:Show()
end

function UI:UpdateStepIndicator(current)
    self:EnsureStepIndicator()
    local parts = {}
    for i = 1, TOTAL_STEPS do
        local color = (i == current) and STEP_ACTIVE_COLOR or STEP_INACTIVE_COLOR
        parts[i] = "|cff" .. color .. i .. "|r"
    end
    local sep = " |cff" .. STEP_INACTIVE_COLOR .. "-|r "
    self.stepText:SetText(ns.L["Steps"] .. "  " .. table.concat(parts, sep))
end

function UI:EnsureLogo()
    if not self.logoFrame then
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(LOGO_SIZE, LOGO_SIZE)
        local tex = f:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(f)
        tex:SetTexture(LOGO_TEXTURE)
        f:SetScript("OnShow", function(fr)
            if not (UI.frame and UI.frame.frame == fr:GetParent()) then fr:Hide() end
        end)
        self.logoFrame = f
    end

    local host = self.frame.frame
    self.logoFrame:SetParent(host)
    self.logoFrame:SetFrameLevel(host:GetFrameLevel() + 5)
    self.logoFrame:ClearAllPoints()
    -- Below center, to clear the heading and description.
    self.logoFrame:SetPoint("CENTER", host, "CENTER", 0, -10)
end

function UI:SetLogoShown(shown)
    if shown then
        self:EnsureLogo()
        self.logoFrame:Show()
    elseif self.logoFrame then
        self.logoFrame:Hide()
    end
end

-- Detaches every pinned element back to UIParent, so the pooled frame carries
-- none of our controls into the next addon that reuses it.
function UI:HideNav()
    local function park(frame)
        frame:Hide()
        frame:SetParent(UIParent)
        frame:ClearAllPoints()
    end
    if self.navLeft then park(self.navLeft.frame) end
    if self.navNext then park(self.navNext.frame) end
    if self.stepFrame then park(self.stepFrame) end
    if self.logoFrame then park(self.logoFrame) end
end

function UI:RenderWelcome(container)
    local L = ns.L
    addHeading(container, L["Welcome to MAUI M+ Timer!"])
    addText(container, L["This quick setup gets you started: pick a starting profile and load the recommended checkpoint targets. Everything can be changed later in the options."])

    self:SetNav(
        L["Skip"],
        function()
            Setup:MarkDone()
            UI:Hide()
        end,
        L["Next"],
        function()
            UI._step = 2
            UI:RenderStep()
        end)
end

function UI:RenderProfiles(container)
    local L = ns.L
    addHeading(container, L["Choose a profile"])
    addText(container, L["Pick a starting look - every element (fonts, colors, bars, modules) can be fine-tuned later in the options."])

    for _, entry in ipairs(Setup.Data.profiles) do
        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(entry.name)
        group:SetFullWidth(true)
        group:SetLayout("List")
        container:AddChild(group)

        local top = AceGUI:Create("SimpleGroup")
        top:SetFullWidth(true)
        top:SetLayout("Flow")
        group:AddChild(top)

        if entry.screenshot then
            local previewCol = AceGUI:Create("SimpleGroup")
            previewCol:SetRelativeWidth(0.42)
            previewCol:SetLayout("List")
            top:AddChild(previewCol)

            local img = AceGUI:Create("Label")
            img:SetText(" ")
            img:SetFullWidth(true)
            img:SetImage(entry.screenshot)
            -- Scaled to the column width, keeping the aspect ratio.
            local size = entry.screenshotSize
            local nativeW = (size and size[1]) or SCREENSHOT_WIDTH
            local nativeH = (size and size[2]) or SCREENSHOT_HEIGHT
            img:SetImageSize(PREVIEW_WIDTH, PREVIEW_WIDTH * nativeH / nativeW)
            previewCol:AddChild(img)
        end

        local descCol = AceGUI:Create("SimpleGroup")
        descCol:SetRelativeWidth(0.56)
        descCol:SetLayout("List")
        top:AddChild(descCol)
        addText(descCol, L[entry.description])
        if entry.note then
            addText(descCol, "|cff888888" .. L[entry.note] .. "|r")
            local dl = AceGUI:Create("Button")
            dl:SetText(L["Download media pack"])
            dl:SetFullWidth(true)
            dl:SetCallback("OnClick", function() UI:ShowMediaPackPopup() end)
            descCol:AddChild(dl)
        end

        addText(group, " ")
        addRightButton(group, L["Use this profile"], function()
            Addon.Profiles:ApplyTable(entry.profile)
            UI._chosen = entry.key
            Addon:Info(L["Profile applied: %s"], entry.name)
            if entry.note and not mediaPackLoaded() then
                UI:ShowMediaPackPopup()
            end
        end)
    end

    -- AceGUI's ScrollFrame drops its bottom padding, so the last preset would
    -- otherwise never scroll fully into view.
    addText(container, "\n\n")

    self:SetNav(
        L["Back"],
        function()
            UI._step = 1
            UI:RenderStep()
        end,
        L["Next"],
        function()
            UI._step = 3
            UI:RenderStep()
        end)
end

function UI:RenderCheckpoints(container)
    local L = ns.L
    addHeading(container, L["Load default checkpoints"])

    local Checkpoints = Addon:GetModule("Checkpoints", true)
    if Checkpoints and Checkpoints.Data then
        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(L["Checkpoints"])
        group:SetFullWidth(true)
        group:SetLayout("List")
        container:AddChild(group)

        addText(group, L["Load the author's curated checkpoint targets. Matching dungeons will be overwritten."])
        addText(group, " ")
        addRightButton(group, L["Load default checkpoints"], function()
            local ok, count = Checkpoints.Data.ImportAuthorPreset()
            if ok then
                Addon:Info(L["Imported checkpoints for %d dungeon(s)."], count or 0)
            end
        end, 0.48)
    end

    self:SetNav(
        L["Back"],
        function()
            UI._step = 2
            UI:RenderStep()
        end,
        L["Finish"],
        function()
            Setup:MarkDone()
            Addon:Info(L["Setup complete! Open the options anytime with /mauimpt."])
            UI:Hide()
        end)
end

function UI:RenderStep()
    local frame = self.frame
    if not frame then return end
    frame:ReleaseChildren()

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    frame:AddChild(scroll)

    if self._step == 1 then
        self:RenderWelcome(scroll)
    elseif self._step == 2 then
        self:RenderProfiles(scroll)
    else
        self:RenderCheckpoints(scroll)
    end

    -- Pinned extras; they live outside the released scroll content.
    self:UpdateStepIndicator(self._step)
    self:SetLogoShown(self._step == 1)
end
