-- Modules/Cooldowns/UI.lua
-- HUD block for battle-rez charges/recharge and lust availability.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Cooldowns = Addon:GetModule("Cooldowns")

local UI = Addon:NewModuleUI()
Cooldowns.UI = UI

local DEFAULT_READY = "Interface\\RaidFrame\\ReadyCheck-Ready"

-- The "Heroism ready" check icon texture and tint are configurable (see Options).
local function readyIcon()
    local s = Cooldowns:GetSettings()
    return Addon.Widgets:IconEscape(s.readyIcon, DEFAULT_READY, 12, s.readyIconColor)
end

-- Resolve a spell's icon (fileID) with a guaranteed fallback texture, so an icon
-- always shows even outside an instance where some lookups may be unavailable.
-- When greyed is true the icon is dimmed via a grey vertex color (used to show
-- an unavailable state: no charges left / on cooldown).
local function spellIcon(spellID, fallback, greyed)
    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    tex = tex or fallback
    if greyed then
        -- |Tpath:h:w:offX:offY:texW:texH:l:r:t:b:rColor:gColor:bColor|t (0-255).
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
    -- Remember the last values so a style/alignment change can rebuild the (text
    -- layout depends on the alignment) display live via Restyle.
    self._last = { brezOn = brezOn, charges = charges, recharge = recharge,
                   lustOn = lustOn, lustCd = lustCd }
    if not brezOn and not lustOn then
        self.frame:Hide()
        Addon.MainWindow:Layout()
        return
    end

    local center = Addon.MainWindow:GetJustifyH("Cooldowns") == "CENTER"

    -- Configurable colors: the recharge "(mm:ss)" and the lust cooldown each have
    -- their own color; the charge count follows the base text color.
    local e = Addon:GetElementSetting(ns.E.cooldownsText)
    local rechHex = Addon.Utils.ColorHex(e.rechargeColor or { 0.60, 0.60, 0.60, 1 })
    local cdHex = Addon.Utils.ColorHex(e.cdColor or { 1, 0.38, 0.38, 1 })

    -- Brez text: recharge time FIRST, then the charge count (without icon).
    local brezText
    if charges == nil then
        brezText = "?"
    elseif recharge then
        brezText = string.format("|c%s%s|r - %d", rechHex, Addon.Utils.FormatTime(recharge), charges)
    else
        brezText = string.format("%d", charges)
    end
    -- Lust text: remaining cooldown (own color) or the ready icon.
    local lustText = lustCd and ("|c" .. cdHex .. Addon.Utils.FormatTime(lustCd) .. "|r") or readyIcon()

    -- Dimmed icons signal an unavailable state: brez when no charges remain,
    -- lust while it is still on cooldown.
    local brezGrey = (charges == 0)
    local lustGrey = (lustCd ~= nil)

    local brezPart, lustPart
    if center then
        -- Mirrored: brez text - brez icon  ||  lust icon - lust text.
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
    -- Reserve a per-tick-stable width so the counting cooldown/recharge time does
    -- not shift the text (and icons) every refresh. When centered, left-justify
    -- inside the box so the content's left edge stays put instead of re-centering.
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
        -- Rebuild the text with the current values so alignment-dependent content
        -- (mirrored layout, separators) and the colors update immediately.
        local l = self._last
        if l then self:Update(l.brezOn, l.charges, l.recharge, l.lustOn, l.lustCd) end
    end
end

-- Custom Show: actual visibility is decided by Update (depends on which features
-- are on), so this only ensures the block exists and relayouts. Hide comes from
-- the shared UI base.
function UI:Show()
    self:Build()
    Addon.MainWindow:Layout()
end
