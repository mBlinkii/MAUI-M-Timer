-- Modules/Cooldowns/UI.lua
-- Two independently placeable HUD blocks: battle-rez charges/recharge ("brez")
-- and lust availability ("bloodlust").

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Cooldowns = Addon:GetModule("Cooldowns")

local UI = Addon:NewModuleUI()
Cooldowns.UI = UI

local DEFAULT_READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
local BREZ_FALLBACK = "Interface\\Icons\\Spell_Nature_Reincarnation"
local LUST_FALLBACK = "Interface\\Icons\\Spell_Nature_BloodLust"
local ICON_GAP = 4 -- between an icon and its text

local function readyIcon()
    local s = Cooldowns:GetSettings()
    return Addon.Widgets:IconEscape(s.readyIcon, DEFAULT_READY, Addon.Widgets:IconSize(ns.E.lustText), s.readyIconColor)
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

local function newPart(hud, name, key, element)
    local block = Addon.Widgets:CreateContainer(hud, name)
    block:SetSize(Addon.MainWindow:GetWidth(), Addon.Widgets:LineHeight(element))
    local icon = block:CreateTexture(nil, "ARTWORK")
    -- Cuts off the rounded border baked into Blizzard icons; survives SetTexture.
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local text = Addon.Widgets:CreateText(block, element)
    text:SetJustifyH("LEFT")
    local part = { frame = block, icon = icon, text = text, key = key, element = element, textW = 0 }
    -- A split row changes the width after Update placed the part.
    block:SetScript("OnSizeChanged", function() UI:PlacePart(part) end)
    block:Hide()
    return part
end

function UI:Build()
    if self.brez then return end
    local hud = Addon.MainWindow:Get()
    self.brez = newPart(hud, "MauiMPlusTimerBrezBlock", "brez", ns.E.brezText)
    self.lust = newPart(hud, "MauiMPlusTimerBloodlustBlock", "bloodlust", ns.E.lustText)
    Addon.MainWindow:AddBlock("brez", self.brez.frame, 70)
    Addon.MainWindow:AddBlock("bloodlust", self.lust.frame, 71)
end

-- Icon then text, aligned as a whole like any other HUD text.
function UI:PlacePart(part)
    local size = Addon.Widgets:IconSize(part.element)
    local total = size + ICON_GAP + part.textW
    local frameW = part.frame:GetWidth()
    local justify = Addon.MainWindow:GetJustifyH("Cooldowns", part.key)
    local ox, oy = Addon.Widgets:GetOffset(part.element)
    local x = 0
    if justify == "RIGHT" then
        x = frameW - total
    elseif justify == "CENTER" then
        x = (frameW - total) / 2
    end
    x = Addon.Widgets:Snap(part.frame, x + ox)
    part.icon:ClearAllPoints()
    part.icon:SetPoint("LEFT", part.frame, "LEFT", x, oy)
    part.text:ClearAllPoints()
    part.text:SetPoint("LEFT", part.frame, "LEFT", x + size + ICON_GAP, oy)
end

-- Stable width, so the counting time does not shift the icon every refresh.
local function setText(part, text)
    part.text:SetText(text)
    local w = Addon.Widgets:StableTextWidth(part.element, text, part.text) or math.ceil(part.text:GetStringWidth())
    part.text:SetWidth(w)
    part.textW = w
end

function UI:Update(brezOn, charges, recharge, lustOn, lustCd)
    self:Build()
    -- Restyle rebuilds from this: the layout depends on the alignment.
    local last = self._last or {}
    self._last = last
    last.brezOn, last.charges, last.recharge, last.lustOn, last.lustCd = brezOn, charges, recharge, lustOn, lustCd

    if brezOn then
        local e = Addon:GetElementSetting(ns.E.brezText)
        local rechHex = Addon.Utils.ColorHex(e.rechargeColor or { 0.60, 0.60, 0.60, 1 })
        local text
        if charges == nil then
            text = "?"
        elseif recharge then
            text = string.format("|c%s%s|r - %d", rechHex, Addon.Utils.FormatTime(recharge), charges)
        else
            text = string.format("%d", charges)
        end
        paintIcon(self.brez.icon, Cooldowns.SPELL_REBIRTH, BREZ_FALLBACK, charges == 0, Addon.Widgets:IconSize(ns.E.brezText))
        setText(self.brez, text)
        self:PlacePart(self.brez)
    end
    self.brez.frame:SetShown(brezOn and true or false)

    if lustOn then
        local e = Addon:GetElementSetting(ns.E.lustText)
        local cdHex = Addon.Utils.ColorHex(e.cdColor or { 1, 0.38, 0.38, 1 })
        local text = lustCd and ("|c" .. cdHex .. Addon.Utils.FormatTime(lustCd) .. "|r") or readyIcon()
        paintIcon(self.lust.icon, Cooldowns.SPELL_BLOODLUST, LUST_FALLBACK, lustCd ~= nil, Addon.Widgets:IconSize(ns.E.lustText))
        setText(self.lust, text)
        self:PlacePart(self.lust)
    end
    self.lust.frame:SetShown(lustOn and true or false)

    Addon.MainWindow:Layout()
end

function UI:Restyle()
    if not self.brez then return end
    for _, part in ipairs({ self.brez, self.lust }) do
        Addon.Widgets:ApplyTextStyle(part.text, part.element)
        part.frame:SetHeight(Addon.Widgets:LineHeight(part.element))
    end
    local l = self._last
    if l then self:Update(l.brezOn, l.charges, l.recharge, l.lustOn, l.lustCd) end
end

-- Visibility is Update's decision (it depends on which parts are on), so this
-- only builds and relayouts.
function UI:Show()
    self:Build()
    Addon.MainWindow:Layout()
end

function UI:Hide()
    if self.brez then
        self.brez.frame:Hide()
        self.lust.frame:Hide()
    end
    Addon.MainWindow:Layout()
end
