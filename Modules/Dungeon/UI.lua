-- Modules/Dungeon/UI.lua
-- HUD block showing the dungeon name with an optional affix line beneath it.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Dungeon = Addon:GetModule("Dungeon")

local UI = Addon:NewModuleUI()
Dungeon.UI = UI

local PANEL_PAD = 6 -- inner padding when the dungeon background/border is shown

-- Estimated line height for a text element (shared helper so the block grows
-- with the font and cannot overlap neighboring blocks).
local function lineHeight(elementKey, fallback)
    return Addon.Widgets:LineHeight(elementKey, fallback)
end

-- Build the "+<level>" tag via the shared helper, tinted with Blizzard's
-- keystone level rarity color when the module option is on.
local function levelTag(level)
    return Addon.Utils.KeystoneLevelTag(level, Dungeon:GetSettings().levelColor)
end

-- Inner padding when the optional background is enabled. The border only
-- exists together with the background, so the padding tracks bg.show alone.
local function panelPad()
    local bg = Dungeon:GetSettings().bg or {}
    return bg.show and PANEL_PAD or 0
end

-- Apply the optional background + border to the dungeon block via the shared
-- Widgets:ApplyPanel helper (border requires the background).
function UI:ApplyBackground()
    if not self.frame then return end
    Addon.Widgets:ApplyPanel(self.frame, Dungeon:GetSettings().bg)
end

function UI:Build()
    if self.frame then return end
    local hud = Addon.MainWindow:Get()
    local block = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerDungeonBlock")
    block:SetSize(Addon.MainWindow:GetWidth(), 16)

    self.frame = block
    self.nameText = Addon.Widgets:CreateText(block, ns.E.dungeonName)
    self.affixText = Addon.Widgets:CreateText(block, ns.E.dungeonAffixes)
    self.icon = block:CreateTexture(nil, "ARTWORK")
    self.icon:Hide()

    self:LayoutTexts()
    block:Hide()
    Addon.MainWindow:AddBlock("dungeon", block, 5)
end

-- Anchor the name at the top and the affix line beneath it, honoring per-element
-- offsets and the module alignment. The affix line and block height collapse
-- when the affix display is turned off.
function UI:LayoutTexts()
    if not self.frame then return end
    local s = Dungeon:GetSettings()
    local justify = Addon.MainWindow:GetJustifyH("Dungeon")
    local showAffixes = s.showAffixes ~= false
    local nameH = lineHeight(ns.E.dungeonName, 14)
    local affixH = lineHeight(ns.E.dungeonAffixes, 11)
    local pad = panelPad()

    -- Optional map icon on the left or right edge. The text is inset on the
    -- icon's side so it always sits next to (after) the icon.
    local showIcon = s.showIcon == true and self.iconTex ~= nil
    local iconSize = s.iconSize or 20
    local onRight = s.iconPos == "right"
    local GAP = 4
    local insetL, insetR = 0, 0
    if self.icon then
        if showIcon then
            self.icon:ClearAllPoints()
            self.icon:SetSize(iconSize, iconSize)
            if onRight then
                self.icon:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -pad, -pad)
                insetR = iconSize + GAP
            else
                self.icon:SetPoint("TOPLEFT", self.frame, "TOPLEFT", pad, -pad)
                insetL = iconSize + GAP
            end
            self.icon:Show()
        else
            self.icon:Hide()
        end
    end

    -- Anchor each line to a single point matching the alignment (like the timer
    -- text) so a direct left<->right switch repositions reliably; the icon inset
    -- keeps the text clear of the icon.
    local function anchorLine(fs, key, baseY)
        local ox, oy = Addon.Widgets:GetOffset(key)
        fs:ClearAllPoints()
        if justify == "LEFT" then
            fs:SetPoint("TOPLEFT", self.frame, "TOPLEFT", pad + insetL + ox, baseY + oy)
        elseif justify == "RIGHT" then
            fs:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -pad - insetR + ox, baseY + oy)
        else
            fs:SetPoint("TOP", self.frame, "TOP", (insetL - insetR) / 2 + ox, baseY + oy)
        end
        fs:SetJustifyH(justify)
    end
    anchorLine(self.nameText, ns.E.dungeonName, -pad)
    anchorLine(self.affixText, ns.E.dungeonAffixes, -pad - nameH)

    if showAffixes then self.affixText:Show() else self.affixText:Hide() end
    local textH = showAffixes and (nameH + affixH) or nameH
    self.frame:SetHeight(pad * 2 + math.max(textH, showIcon and iconSize or 0))

    self:ApplyBackground()
end

function UI:Update(name, affixes, icon, level)
    if not self.frame then return end
    self._last = { name = name, affixes = affixes, icon = icon, level = level }
    local nameStr = name or ""
    -- Place the keystone level left or right of the name when enabled, with an
    -- optional separator line ("|") between them ("||" renders as one "|").
    if level and Dungeon:GetSettings().showLevel ~= false then
        local sep = Dungeon:GetSettings().levelSep ~= false and " || " or " "
        if Dungeon:GetSettings().levelPos == "right" then
            nameStr = nameStr .. sep .. levelTag(level)
        else
            nameStr = levelTag(level) .. sep .. nameStr
        end
    end
    self.nameText:SetText(nameStr)
    self.affixText:SetText(affixes or "")
    self.iconTex = icon
    if self.icon and icon then self.icon:SetTexture(icon) end
    self:LayoutTexts()
end

function UI:Restyle()
    if not self.frame then return end
    Addon.Widgets:ApplyTextStyle(self.nameText, ns.E.dungeonName)
    Addon.Widgets:ApplyTextStyle(self.affixText, ns.E.dungeonAffixes)
    -- Rebuild from the last data so the keystone-level prefix toggles live.
    if self._last then
        self:Update(self._last.name, self._last.affixes, self._last.icon, self._last.level)
    else
        self:LayoutTexts()
    end
    Addon.MainWindow:Layout()
end

-- Show / Hide are provided by the shared UI base (Addon:NewModuleUI).
