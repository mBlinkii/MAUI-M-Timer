-- Modules/Setup/UI.lua
-- The three-step wizard, a panel of the same make as the settings window:
-- the steps on the left, the step's page on the right, the way on at the
-- bottom. Presentation only: applying a profile lives in Profiles.lua,
-- checkpoint data in the Checkpoints module.

local _, ns = ...
local Addon = ns.Addon
local Setup = Addon:GetModule("Setup")

local UI = {}
Setup.UI = UI

local SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT = 512, 160 -- native size of the presets
local PREVIEW_WIDTH = 240 -- width a preset screenshot is scaled to

local LOGO_TEXTURE = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\icon_big"
local LOGO_SIZE = 160

local STEPS = { "welcome", "profile", "checkpoints" }

-- Font pack the shipped presets reference.
local MEDIA_PACK_NAME  = "Blinkiis Media Pack"
local MEDIA_PACK_ADDON = "!mMT_MediaPack"
local MEDIA_PACK_URL   = "https://www.curseforge.com/wow/addons/mmt-media-pack"

local function mediaPackLoaded()
    return (C_AddOns and C_AddOns.IsAddOnLoaded
        and C_AddOns.IsAddOnLoaded(MEDIA_PACK_ADDON)) or false
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

local function stepName(key)
    local L = ns.L
    if key == "welcome" then return L["Welcome"] end
    if key == "profile" then return L["Profile"] end
    return L["Checkpoints"]
end

local function stepIndex(key)
    for i, k in ipairs(STEPS) do
        if k == key then return i end
    end
    return 1
end

-- Centered logo above the welcome text; reused across redraws.
local logo
local function logoPreview(width)
    if not logo then
        logo = CreateFrame("Frame")
        logo.tex = logo:CreateTexture(nil, "ARTWORK")
        logo.tex:SetTexture(LOGO_TEXTURE)
        logo.tex:SetSize(LOGO_SIZE, LOGO_SIZE)
        logo.tex:SetPoint("TOP")
    end
    logo:SetSize(math.max(1, width), LOGO_SIZE)
    return logo, LOGO_SIZE
end

local function text(order, value, fontSize)
    return { type = "description", order = order, name = value, fontSize = fontSize or "medium" }
end

local function welcomePage()
    local L = ns.L
    return {
        type = "group", name = L["Welcome to MAUI M+ Timer!"],
        args = {
            logo = { type = "description", order = 1, name = "", arg = { preview = logoPreview } },
            intro = text(2, L["This quick setup gets you started: pick a starting profile and load the recommended checkpoint targets. Everything can be changed later in the options."]),
        },
    }
end

local function profileCard(entry, order)
    local L = ns.L
    local args = {}
    if entry.screenshot then
        local size = entry.screenshotSize
        local nativeW = (size and size[1]) or SCREENSHOT_WIDTH
        local nativeH = (size and size[2]) or SCREENSHOT_HEIGHT
        args.shot = {
            type = "description", order = 1, name = "",
            image = entry.screenshot,
            imageWidth = PREVIEW_WIDTH, imageHeight = PREVIEW_WIDTH * nativeH / nativeW,
        }
    end
    args.desc = text(2, L[entry.description])
    if entry.note then
        args.note = text(3, L[entry.note], "small")
        args.download = {
            type = "execute", order = 4, name = L["Download media pack"],
            func = function() UI:ShowMediaPackPopup() end,
        }
    end
    args.use = {
        type = "execute", order = 5, name = L["Use this profile"], controlWidth = "md",
        func = function()
            Addon.Profiles:ApplyTable(Addon.Utils.DropBundledFonts(entry.profile))
            UI.chosen = entry.name
            Addon:Info(L["Profile applied: %s"], entry.name)
            if entry.note and not mediaPackLoaded() then
                UI:ShowMediaPackPopup()
            end
            UI.panel:Refresh()
        end,
    }
    return { type = "group", inline = true, order = order, name = entry.name, args = args }
end

local function profilePage()
    local L = ns.L
    local args = {
        intro = text(0, L["Pick a starting look - every element (fonts, colors, bars, modules) can be fine-tuned later in the options."]),
    }
    for i, entry in ipairs(Setup.Data.Profiles()) do
        args[entry.key] = profileCard(entry, i)
    end
    return { type = "group", name = L["Choose a profile"], args = args }
end

local function checkpointsPage()
    local L = ns.L
    local args = {}
    local Checkpoints = Addon:GetModule("Checkpoints", true)
    if Checkpoints and Checkpoints.Data then
        args.card = {
            type = "group", inline = true, order = 1, name = L["Checkpoints"],
            args = {
                desc = text(1, L["Load the author's curated checkpoint targets. Matching dungeons will be overwritten."]),
                load = {
                    type = "execute", order = 2, name = L["Load default checkpoints"],
                    func = function()
                        local ok, count = Checkpoints.Data.ImportAuthorPreset()
                        if ok then
                            Addon:Info(L["Imported checkpoints for %d dungeon(s)."], count or 0)
                        end
                    end,
                },
            },
        }
    end
    return { type = "group", name = L["Load default checkpoints"], args = args }
end

-- The way on: the next step, or finishing on the last one.
local function stepAction(key)
    local L = ns.L
    local i = stepIndex(key)
    local last = i == #STEPS
    return {
        type = "execute", controlWidth = "md",
        name = last and L["Finish"] or L["Next"],
        arg = { title = string.format(L["Step %d of %d"], i, #STEPS) },
        desc = not last and stepName(STEPS[i + 1]) or nil,
        func = function()
            if last then
                Addon:Info(L["Setup complete! Open the options anytime with /mauimpt."])
                UI:Hide()
            else
                UI.panel:Select(STEPS[i + 1])
            end
        end,
    }
end

local function buildList()
    local list = { { header = true, text = ns.L["Setup"], right = "" } }
    for i, key in ipairs(STEPS) do
        list[#list + 1] = {
            key = key,
            text = i .. ".  " .. stepName(key),
            -- The chosen profile, so the step shows what it settled.
            right = key == "profile" and UI.chosen or nil,
        }
    end
    return list
end

local function getPanel()
    if UI.panel then return UI.panel end
    local panel = ns.Panel.New("setup", {
        title = function() return "MAUI M+ Timer \226\128\148 " .. ns.L["Setup"] end,
        globalName = "MauiMPlusTimerSetupPanel",
        width = 760, height = 560,
        collapsible = false,
        BuildList = buildList,
        Default = function() return "welcome" end,
        BuildPage = function(_, key)
            if key == "profile" then return profilePage() end
            if key == "checkpoints" then return checkpointsPage() end
            return welcomePage()
        end,
        BuildAction = function(_, key) return stepAction(key) end,
    })
    -- Closing counts as seen, so a fresh install is never nagged twice.
    local baseClosed = panel.OnClosed
    function panel:OnClosed()
        baseClosed(self)
        Setup:MarkDone()
    end
    UI.panel = panel
    return panel
end

function UI:Show()
    local panel = getPanel()
    if panel:IsShown() then return end
    panel.selected = "welcome"
    panel:Open()
end

function UI:Hide()
    if self.panel then self.panel:Close() end
end
