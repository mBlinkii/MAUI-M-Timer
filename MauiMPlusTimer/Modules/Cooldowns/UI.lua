-- Modules/Cooldowns/UI.lua
-- HUD block for battle-rez charges/recharge and lust availability.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Cooldowns = Addon:GetModule("Cooldowns")

local UI = Addon:NewModuleUI()
Cooldowns.UI = UI

local DEFAULT_READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
local BREZ_FALLBACK = "Interface\\Icons\\Spell_Nature_Reincarnation"
local LUST_FALLBACK = "Interface\\Icons\\Spell_Nature_BloodLust"
local ICON_GAP = 4 -- between an icon and its text
local PART_GAP = 12 -- between the two parts, left or right aligned
local SEP_GAP = 8 -- around the "|" when centered

local function readyIcon()
    local s = Cooldowns:GetSettings()
    return Addon.Widgets:IconEscape(s.readyIcon, DEFAULT_READY, Addon.Widgets:IconSize(ns.E.cooldownsText), s.readyIconColor)
end

-- The spell icons are textures rather than text escapes: only a texture can be
-- desaturated, and an escape can only darken an unavailable spell. The fallback
-- matters outside an instance, where the lookup can fail.
local function paintIcon(icon, spellID, fallback, greyed, size)
    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    icon:SetTexture(tex or fallback)
    icon:SetSize(size, size)
    icon:SetDesaturated(greyed)
    icon:SetVertexColor(greyed and 0.7 or 1, greyed and 0.7 or 1, greyed and 0.7 or 1)
end

function UI:Build()
    if self.frame then return end
    local hud = Addon.MainWindow:Get()
    local block = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerCooldownsBlock")
    block:SetSize(Addon.MainWindow:GetWidth(), Addon.Widgets:LineHeight(ns.E.cooldownsText))

    local function icon()
        local t = block:CreateTexture(nil, "ARTWORK")
        -- Cuts off the rounded border baked into Blizzard icons; survives SetTexture.
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return t
    end
    self.frame = block
    self.brezIcon, self.lustIcon = icon(), icon()
    self.brezText = Addon.Widgets:CreateText(block, ns.E.cooldownsText)
    self.lustText = Addon.Widgets:CreateText(block, ns.E.cooldownsText)
    self.sepText = Addon.Widgets:CreateText(block, ns.E.cooldownsText)
    self.sepText:SetText("||")
    self.texts = { self.brezText, self.lustText, self.sepText }
    self.regions = { self.brezIcon, self.brezText, self.sepText, self.lustIcon, self.lustText }
    for _, fs in ipairs(self.texts) do fs:SetJustifyH("LEFT") end
    self.chain, self.chainW = {}, {}

    -- A split row changes the width after Update placed the chain.
    block:SetScript("OnSizeChanged", function() UI:PlaceChain() end)
    block:Hide()
    Addon.MainWindow:AddBlock("cooldowns", block, 70)
end

-- Laid out left to right from the widths Update measured; the whole chain is
-- then aligned like any other HUD text.
function UI:PlaceChain()
    local chain, widths = self.chain, self.chainW
    if not (chain and #chain > 0) then return end
    local total = 0
    for i = 1, #chain do total = total + widths[i] end

    local frameW = self.frame:GetWidth()
    local justify = Addon.MainWindow:GetJustifyH("Cooldowns")
    local ox, oy = Addon.Widgets:GetOffset(ns.E.cooldownsText)
    local x = 0
    if justify == "RIGHT" then
        x = frameW - total
    elseif justify == "CENTER" then
        x = (frameW - total) / 2
    end
    x = Addon.Widgets:Snap(self.frame, x + ox)

    for i = 1, #chain do
        local region = chain[i]
        region:ClearAllPoints()
        region:SetPoint("LEFT", self.frame, "LEFT", x, oy)
        region:Show()
        x = x + widths[i]
    end
end

-- Stable width, so the counting time does not shift the icons every refresh.
local function textWidth(fs, text)
    fs:SetText(text)
    local w = Addon.Widgets:StableTextWidth(ns.E.cooldownsText, text) or math.ceil(fs:GetStringWidth())
    fs:SetWidth(w)
    return w
end

function UI:Update(brezOn, charges, recharge, lustOn, lustCd)
    self:Build()
    -- Restyle rebuilds from this: the layout depends on the alignment.
    local last = self._last or {}
    self._last = last
    last.brezOn, last.charges, last.recharge, last.lustOn, last.lustCd = brezOn, charges, recharge, lustOn, lustCd

    local chain, widths = self.chain, self.chainW
    for i = #chain, 1, -1 do chain[i], widths[i] = nil, nil end
    for _, region in ipairs(self.regions) do region:Hide() end

    if not brezOn and not lustOn then
        self.frame:Hide()
        Addon.MainWindow:Layout()
        return
    end

    local center = Addon.MainWindow:GetJustifyH("Cooldowns") == "CENTER"
    local size = Addon.Widgets:IconSize(ns.E.cooldownsText)

    -- The charge count follows the base text color.
    local e = Addon:GetElementSetting(ns.E.cooldownsText)
    local rechHex = Addon.Utils.ColorHex(e.rechargeColor or { 0.60, 0.60, 0.60, 1 })
    local cdHex = Addon.Utils.ColorHex(e.cdColor or { 1, 0.38, 0.38, 1 })

    local function add(region, width)
        local n = #chain + 1
        chain[n], widths[n] = region, width
    end

    if brezOn then
        local text
        if charges == nil then
            text = "?"
        elseif recharge then
            text = string.format("|c%s%s|r - %d", rechHex, Addon.Utils.FormatTime(recharge), charges)
        else
            text = string.format("%d", charges)
        end
        paintIcon(self.brezIcon, Cooldowns.SPELL_REBIRTH, BREZ_FALLBACK, charges == 0, size)
        local w = textWidth(self.brezText, text)
        -- Mirrored around the separator when centered.
        if center then
            add(self.brezText, w + ICON_GAP)
            add(self.brezIcon, size)
        else
            add(self.brezIcon, size + ICON_GAP)
            add(self.brezText, w)
        end
    end

    if lustOn then
        if brezOn then
            if center then
                widths[#chain] = widths[#chain] + SEP_GAP
                add(self.sepText, math.ceil(self.sepText:GetStringWidth()) + SEP_GAP)
            else
                widths[#chain] = widths[#chain] + PART_GAP
            end
        end
        local text = lustCd and ("|c" .. cdHex .. Addon.Utils.FormatTime(lustCd) .. "|r") or readyIcon()
        paintIcon(self.lustIcon, Cooldowns.SPELL_BLOODLUST, LUST_FALLBACK, lustCd ~= nil, size)
        add(self.lustIcon, size + ICON_GAP)
        add(self.lustText, textWidth(self.lustText, text))
    end

    self:PlaceChain()
    self.frame:Show()
    Addon.MainWindow:Layout()
end

function UI:Restyle()
    if not self.frame then return end
    for _, fs in ipairs(self.texts) do
        Addon.Widgets:ApplyTextStyle(fs, ns.E.cooldownsText)
    end
    self.frame:SetHeight(Addon.Widgets:LineHeight(ns.E.cooldownsText))
    -- Full rebuild, because the mirrored layout depends on the alignment.
    local l = self._last
    if l then self:Update(l.brezOn, l.charges, l.recharge, l.lustOn, l.lustCd) end
end

-- Visibility is Update's decision (it depends on which features are on), so
-- this only builds and relayouts.
function UI:Show()
    self:Build()
    Addon.MainWindow:Layout()
end
