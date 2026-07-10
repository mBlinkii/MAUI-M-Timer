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
local SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT = 512, 160 -- preview size in the wizard

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

-- Bottom navigation row with up to two explicit buttons (left, right).
-- Pass nil for a text to skip that button.
local function addNav(container, leftText, leftFn, rightText, rightFn)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    container:AddChild(group)

    if leftText then
        local left = AceGUI:Create("Button")
        left:SetText(leftText)
        left:SetWidth(140)
        left:SetCallback("OnClick", leftFn)
        group:AddChild(left)
    end
    if rightText then
        local right = AceGUI:Create("Button")
        right:SetText(rightText)
        right:SetWidth(140)
        right:SetCallback("OnClick", rightFn)
        group:AddChild(right)
    end
end

-- Steps ------------------------------------------------------------------------

-- Step 1: welcome text plus Next/Skip.
function UI:RenderWelcome(container)
    local L = ns.L
    addHeading(container, L["Welcome to MAUI M+ Timer!"])
    addText(container, L["This quick setup gets you started: pick a starting profile and load the recommended checkpoint targets. Everything can be changed later in the options."])

    addNav(container,
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
        group:SetLayout("List")
        container:AddChild(group)

        if entry.screenshot then
            local img = AceGUI:Create("Label")
            img:SetText(" ")
            img:SetFullWidth(true)
            img:SetImage(entry.screenshot)
            -- Display at the preset's original pixel size so a stretched
            -- power-of-two texture gets its true aspect ratio back.
            local size = entry.screenshotSize
            img:SetImageSize(size and size[1] or SCREENSHOT_WIDTH,
                size and size[2] or SCREENSHOT_HEIGHT)
            group:AddChild(img)
        end

        addText(group, L[entry.description])

        local use = AceGUI:Create("Button")
        use:SetText(L["Use this profile"])
        use:SetWidth(200)
        use:SetCallback("OnClick", function()
            Addon.Profiles:ApplyTable(entry.profile)
            UI._chosen = entry.key
            Addon:Info(L["Profile applied: %s"], entry.name)
        end)
        group:AddChild(use)
    end

    addNav(container,
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

-- Step 3: offer the curated checkpoint targets, then finish.
function UI:RenderCheckpoints(container)
    local L = ns.L
    addHeading(container, L["Load default checkpoints"])
    addText(container, L["Load the author's curated checkpoint targets. Matching dungeons will be overwritten."])

    local Checkpoints = Addon:GetModule("Checkpoints", true)
    if Checkpoints and Checkpoints.Data then
        local load = AceGUI:Create("Button")
        load:SetText(L["Load default checkpoints"])
        load:SetWidth(220)
        load:SetCallback("OnClick", function()
            local ok, count = Checkpoints.Data.ImportAuthorPreset()
            if ok then
                Addon:Info(L["Imported checkpoints for %d dungeon(s)."], count or 0)
            end
        end)
        container:AddChild(load)
        addText(container, " ")
    end

    addNav(container,
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
end
