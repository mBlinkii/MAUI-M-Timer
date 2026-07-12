-- Modules/Setup/UI.lua
-- The setup wizard window (AceGUI): three steps - welcome, profile choice,
-- recommended checkpoints. Pure presentation: profile application lives in
-- Core/Profiles.lua, checkpoint data in the Checkpoints module.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Setup = Addon:GetModule("Setup")

local AceGUI = LibStub("AceGUI-3.0")

local UI = {}
Setup.UI = UI

local WINDOW_WIDTH, WINDOW_HEIGHT = 560, 470
local SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT = 512, 160 -- native size of the presets
local PREVIEW_WIDTH = 190 -- width the preview is scaled to in the left column

-- Open the wizard (or focus it when already open) and start at step 1.
function UI:Show()
    if self.frame then return end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("MAUI M+ Timer")
    frame:SetWidth(WINDOW_WIDTH)
    frame:SetHeight(WINDOW_HEIGHT)
    frame:SetLayout("Fill")
    frame:EnableResize(false)
    -- Closing the window (X button included) counts as "seen" so a fresh
    -- install is never nagged twice; /mauimpt setup reopens it anytime.
    frame:SetCallback("OnClose", function(widget)
        UI:HideNav()
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

-- Widget helpers --------------------------------------------------------------

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

-- Footer navigation ----------------------------------------------------------

-- Fixed width of the two footer buttons; wide enough for the longest label in
-- every shipped locale (e.g. German "Fertigstellen") while leaving room for the
-- step indicator between them and the built-in close button.
local NAV_BUTTON_WIDTH = 120
local NAV_GAP = 8 -- horizontal gap around the step indicator
-- The footer buttons share the AceGUI close button's row exactly: 20px tall at
-- y-offset 17. The close button is widened to NAV_BUTTON_WIDTH as well (see
-- UI:StyleCloseButton), so all three footer buttons look identical.
local NAV_Y = 17

-- Logo shown on the welcome step (extension-less path so WoW resolves the .tga).
local LOGO_TEXTURE = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\icon_big"
local LOGO_SIZE = 190

-- Step indicator colors (|c AARRGGBB without the alpha): the active step matches
-- the module-green used elsewhere, inactive steps and separators are grey.
local STEP_ACTIVE_COLOR = "40c057"
local STEP_INACTIVE_COLOR = "808080"
local TOTAL_STEPS = 3

-- Create one persistent footer button (an AceGUI "Button" widget so third-party
-- skins like ElvUI/Masque, which hook AceGUI's named buttons, style it just like
-- the in-content buttons) and reparent it to the current wizard window. Not
-- added to any container: the wizard positions and reuses it directly.
local function ensureNavButton(field)
    local widget = UI[field]
    if not widget then
        widget = AceGUI:Create("Button")
        widget:SetWidth(NAV_BUTTON_WIDTH)
        widget:SetHeight(20)
        -- Hide the button whenever its host frame is shown for anything that is
        -- not our own wizard window (AceGUI frame recycling).
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

-- Create/reparent the two persistent footer buttons (left = Skip/Back,
-- right = Next/Finish) on the bottom bar of the current wizard window. They live
-- outside the scroll content so they stay pinned while the step content scrolls.
function UI:EnsureNavButtons()
    self.navLeft = ensureNavButton("navLeft")
    self.navNext = ensureNavButton("navNext")
    self:StyleCloseButton()
end

-- Widen the AceGUI frame's built-in close button to NAV_BUTTON_WIDTH so it
-- matches the two footer buttons. AceGUI keeps the button local, so it is found
-- by its text (the global CLOSE label) among the frame's direct children.
function UI:StyleCloseButton()
    for _, child in ipairs({ self.frame.frame:GetChildren() }) do
        if child.GetText and child:GetText() == CLOSE then
            child:SetWidth(NAV_BUTTON_WIDTH)
            break
        end
    end
end

-- Point the two footer buttons at the current step. Pass nil for a text to hide
-- that button. Left button sits in the far-left corner (Skip on step 1, Back
-- afterwards); Next/Finish is pinned right, just left of the close button.
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
    -- The (widened) close button is 120 wide anchored at x -27, so its left edge
    -- sits at -147; -155 leaves an 8px gap before the Next/Finish button.
    self.navNext.frame:ClearAllPoints()
    self.navNext.frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -155, NAV_Y)
end

-- Create/reparent the "Steps 1 - 2 - 3" indicator, spanning the gap between the
-- two footer buttons so it stays centered between them.
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

-- Render the localized "Steps 1 - 2 - 3" line with the active step highlighted.
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

-- Create/reparent the welcome-step logo, centered in the content area.
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
    -- A touch below center to clear the heading and description at the top.
    self.logoFrame:SetPoint("CENTER", host, "CENTER", 0, -10)
end

-- Show the logo only on the welcome step.
function UI:SetLogoShown(shown)
    if shown then
        self:EnsureLogo()
        self.logoFrame:Show()
    elseif self.logoFrame then
        self.logoFrame:Hide()
    end
end

-- Hide every pinned footer element (on window close), so a pooled frame carries
-- no leftover wizard controls.
function UI:HideNav()
    if self.navLeft then self.navLeft.frame:Hide() end
    if self.navNext then self.navNext.frame:Hide() end
    if self.stepFrame then self.stepFrame:Hide() end
    if self.logoFrame then self.logoFrame:Hide() end
end

-- Steps ------------------------------------------------------------------------

-- Step 1: welcome text and the centered logo (added by RenderStep), plus the
-- Skip/Next footer buttons.
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

-- Step 2: one selectable block per preset profile from Setup.Data.profiles.
function UI:RenderProfiles(container)
    local L = ns.L
    addHeading(container, L["Choose a profile"])
    addText(container, L["Pick a starting look - every element (fonts, colors, bars, modules) can be fine-tuned later in the options."])

    for _, entry in ipairs(Setup.Data.profiles) do
        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(entry.name)
        group:SetFullWidth(true)
        group:SetLayout("Flow") -- two columns: preview | description + button
        container:AddChild(group)

        -- Left column: the preview image, scaled to the column width while
        -- keeping the preset screenshot's true aspect ratio.
        local left = AceGUI:Create("SimpleGroup")
        left:SetRelativeWidth(0.4)
        left:SetLayout("List")
        group:AddChild(left)

        if entry.screenshot then
            local img = AceGUI:Create("Label")
            img:SetText(" ")
            img:SetFullWidth(true)
            img:SetImage(entry.screenshot)
            local size = entry.screenshotSize
            local nativeW = (size and size[1]) or SCREENSHOT_WIDTH
            local nativeH = (size and size[2]) or SCREENSHOT_HEIGHT
            img:SetImageSize(PREVIEW_WIDTH, PREVIEW_WIDTH * nativeH / nativeW)
            left:AddChild(img)
        end

        -- Right column: description text and the apply button below it.
        local right = AceGUI:Create("SimpleGroup")
        right:SetRelativeWidth(0.6)
        right:SetLayout("List")
        group:AddChild(right)

        addText(right, L[entry.description])

        local use = AceGUI:Create("Button")
        use:SetText(L["Use this profile"])
        use:SetWidth(200)
        use:SetCallback("OnClick", function()
            Addon.Profiles:ApplyTable(entry.profile)
            UI._chosen = entry.key
            Addon:Info(L["Profile applied: %s"], entry.name)
        end)
        right:AddChild(use)
    end

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

-- Step 3: offer the curated checkpoint targets in a titled box, then finish.
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

        local load = AceGUI:Create("Button")
        load:SetText(L["Load default checkpoints"])
        load:SetWidth(220)
        load:SetCallback("OnClick", function()
            local ok, count = Checkpoints.Data.ImportAuthorPreset()
            if ok then
                Addon:Info(L["Imported checkpoints for %d dungeon(s)."], count or 0)
            end
        end)
        group:AddChild(load)
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

-- Clear the window and render the current step into a fresh scroll container.
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

    -- Pinned footer/content extras (live outside the released scroll content).
    self:UpdateStepIndicator(self._step)
    self:SetLogoShown(self._step == 1)
end
