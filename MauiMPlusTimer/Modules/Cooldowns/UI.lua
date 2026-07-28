-- Modules/Cooldowns/UI.lua
-- HUD block for battle-rez charges/recharge and lust availability.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Cooldowns = Addon:GetModule("Cooldowns")

local UI = Addon:NewModuleUI()
Cooldowns.UI = UI

local DEFAULT_READY = "Interface\\RaidFrame\\ReadyCheck-Ready"

local function readyIcon()
    local s = Cooldowns:GetSettings()
    return Addon.Widgets:IconEscape(s.readyIcon, DEFAULT_READY, 12, s.readyIconColor)
end

-- The fallback matters outside an instance, where the lookup can fail. `greyed`
-- dims the icon to signal an unavailable state.
local function spellIcon(spellID, fallback, greyed)
    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    tex = tex or fallback
    if greyed then
        -- |Tpath:h:w:offX:offY:texW:texH:l:r:t:b:rC:gC:bC|t, RGB 0-255.
        return string.format("|T%s:14:14:0:0:64:64:0:64:0:64:80:80:80|t", tex)
    end
    return "|T" .. tex .. ":14|t"
end

local function brezIcon(greyed)
    return spellIcon(Cooldowns.SPELL_REBIRTH, "Interface\\Icons\\Spell_Nature_Reincarnation", greyed)
end

local function lustIcon(greyed)
    return spellIcon(Cooldowns.SPELL_BLOODLUST, "Interface\\Icons\\Spell_Nature_BloodLust", greyed)
end

function UI:Build()
    if self.frame then return end
    local hud = Addon.MainWindow:Get()
    local block = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerCooldownsBlock")
    block:SetSize(Addon.MainWindow:GetWidth(), Addon.Widgets:LineHeight(ns.E.cooldownsText))

    local text = Addon.Widgets:CreateText(block, ns.E.cooldownsText)
    self.frame, self.text = block, text
    Addon.Widgets:LayoutText(text, block, ns.E.cooldownsText, Addon.MainWindow:GetJustifyH("Cooldowns"))
    block:Hide()
    Addon.MainWindow:AddBlock("cooldowns", block, 70)
end

function UI:Update(brezOn, charges, recharge, lustOn, lustCd)
    self:Build()
    -- Restyle rebuilds from this: the layout depends on the alignment.
    self._last = { brezOn = brezOn, charges = charges, recharge = recharge,
                   lustOn = lustOn, lustCd = lustCd }
    if not brezOn and not lustOn then
        self.frame:Hide()
        Addon.MainWindow:Layout()
        return
    end

    local center = Addon.MainWindow:GetJustifyH("Cooldowns") == "CENTER"

    -- The charge count follows the base text color.
    local e = Addon:GetElementSetting(ns.E.cooldownsText)
    local rechHex = Addon.Utils.ColorHex(e.rechargeColor or { 0.60, 0.60, 0.60, 1 })
    local cdHex = Addon.Utils.ColorHex(e.cdColor or { 1, 0.38, 0.38, 1 })

    local brezText
    if charges == nil then
        brezText = "?"
    elseif recharge then
        brezText = string.format("|c%s%s|r - %d", rechHex, Addon.Utils.FormatTime(recharge), charges)
    else
        brezText = string.format("%d", charges)
    end
    local lustText = lustCd and ("|c" .. cdHex .. Addon.Utils.FormatTime(lustCd) .. "|r") or readyIcon()

    local brezGrey = (charges == 0)
    local lustGrey = (lustCd ~= nil)

    local brezPart, lustPart
    if center then
        -- Mirrored around the separator.
        brezPart = brezText .. " " .. brezIcon(brezGrey)
        lustPart = lustIcon(lustGrey) .. " " .. lustText
    else
        brezPart = brezIcon(brezGrey) .. " " .. brezText
        lustPart = lustIcon(lustGrey) .. " " .. lustText
    end

    local parts = {}
    if brezOn then parts[#parts + 1] = brezPart end
    if lustOn then parts[#parts + 1] = lustPart end

    local text = table.concat(parts, center and "  ||  " or "   ")
    self.text:SetText(text)
    -- Stable width plus LEFT inside the box, or the counting time shifts the
    -- icons on every refresh.
    local w = Addon.Widgets:StableTextWidth(ns.E.cooldownsText, text)
    if w then self.text:SetWidth(w) end
    if center then self.text:SetJustifyH("LEFT") end
    self.frame:Show()
    Addon.MainWindow:Layout()
end

function UI:Restyle()
    if self.frame and self.text then
        Addon.Widgets:ApplyTextStyle(self.text, ns.E.cooldownsText)
        self.frame:SetHeight(Addon.Widgets:LineHeight(ns.E.cooldownsText))
        Addon.Widgets:LayoutText(self.text, self.frame, ns.E.cooldownsText, Addon.MainWindow:GetJustifyH("Cooldowns"))
        -- Full rebuild, because the mirrored layout depends on the alignment.
        local l = self._last
        if l then self:Update(l.brezOn, l.charges, l.recharge, l.lustOn, l.lustCd) end
    end
end

-- Visibility is Update's decision (it depends on which features are on), so
-- this only builds and relayouts.
function UI:Show()
    self:Build()
    Addon.MainWindow:Layout()
end
