-- Modules/Dungeon/UI.lua
-- Four independently placeable HUD blocks: dungeon name, map icon, keystone
-- level and affixes.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Dungeon = Addon:GetModule("Dungeon")

local UI = Addon:NewModuleUI()
Dungeon.UI = UI

local PANEL_PAD = 6

local function justify(blockKey)
    return Addon.MainWindow:GetJustifyH("Dungeon", blockKey)
end

-- The border only exists together with the background, so bg.show alone
-- decides the padding.
local function panelPad()
    local bg = Dungeon:GetSettings().bg or {}
    return bg.show and PANEL_PAD or 0
end

local function textBlock(hud, name, element)
    local block = Addon.Widgets:CreateContainer(hud, name)
    block:SetSize(Addon.MainWindow:GetWidth(), Addon.Widgets:LineHeight(element))
    local fs = Addon.Widgets:CreateText(block, element)
    fs:SetWordWrap(false)
    block:Hide()
    return block, fs
end

function UI:Build()
    if self.frame then return end
    local hud = Addon.MainWindow:Get()

    self.frame, self.nameText = textBlock(hud, "MauiMPlusTimerDungeonBlock", ns.E.dungeonName)
    self.affixFrame, self.affixText = textBlock(hud, "MauiMPlusTimerAffixesBlock", ns.E.dungeonAffixes)
    self.levelFrame, self.levelText = textBlock(hud, "MauiMPlusTimerLevelBlock", ns.E.dungeonLevel)

    self.iconFrame = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerDungeonIconBlock")
    self.iconFrame:SetSize(Addon.MainWindow:GetWidth(), 20)
    self.icon = self.iconFrame:CreateTexture(nil, "ARTWORK")
    -- Trims the border baked into Blizzard icon textures; survives SetTexture.
    self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.iconFrame:Hide()

    self:LayoutBlocks()
    -- A split row narrows the blocks after LayoutBlocks ran.
    for _, f in ipairs({ self.frame, self.affixFrame, self.levelFrame }) do
        f:SetScript("OnSizeChanged", function() UI:FitTexts() end)
    end
    Addon.MainWindow:AddBlock("dungeon", self.frame, 5)
    Addon.MainWindow:AddBlock("dungeonicon", self.iconFrame, 4)
    Addon.MainWindow:AddBlock("level", self.levelFrame, 6)
    Addon.MainWindow:AddBlock("affixes", self.affixFrame, 7)
end

-- A long name ends in "..." instead of running past its block.
function UI:FitTexts()
    if not self.frame then return end
    local pad = panelPad()
    self.nameText:SetWidth(math.max(20, self.frame:GetWidth() - pad * 2))
    self.affixText:SetWidth(math.max(20, self.affixFrame:GetWidth()))
    self.levelText:SetWidth(math.max(20, self.levelFrame:GetWidth()))
end

function UI:LayoutBlocks()
    if not self.frame then return end
    local pad = panelPad()

    -- Single-point anchors, or a direct left<->right switch does not reposition.
    local j = justify("dungeon")
    local ox, oy = Addon.Widgets:GetOffset(ns.E.dungeonName)
    self.nameText:ClearAllPoints()
    if j == "LEFT" then
        self.nameText:SetPoint("TOPLEFT", self.frame, "TOPLEFT", pad + ox, -pad + oy)
    elseif j == "RIGHT" then
        self.nameText:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -pad + ox, -pad + oy)
    else
        self.nameText:SetPoint("TOP", self.frame, "TOP", ox, -pad + oy)
    end
    self.nameText:SetJustifyH(j)
    self.frame:SetHeight(pad * 2 + Addon.Widgets:LineHeight(ns.E.dungeonName, 14))

    Addon.Widgets:LayoutText(self.affixText, self.affixFrame, ns.E.dungeonAffixes, justify("affixes"))
    self.affixFrame:SetHeight(Addon.Widgets:LineHeight(ns.E.dungeonAffixes, 11))
    Addon.Widgets:LayoutText(self.levelText, self.levelFrame, ns.E.dungeonLevel, justify("level"))
    self.levelFrame:SetHeight(Addon.Widgets:LineHeight(ns.E.dungeonLevel, 14))

    local size = Dungeon:GetSettings().iconSize or 20
    local ij = justify("dungeonicon")
    self.icon:ClearAllPoints()
    self.icon:SetSize(size, size)
    self.icon:SetPoint(ij, self.iconFrame, ij, 0, 0)
    self.iconFrame:SetHeight(size)

    self:FitTexts()
    Addon.Widgets:ApplyPanel(self.frame, Dungeon:GetSettings().bg)
end

-- Each block follows its own flag while the dungeon is shown.
function UI:ApplyBlocksShown()
    if not self.frame then return end
    local s = Dungeon:GetSettings()
    local on = self.visible == true
    self.frame:SetShown(on and s.showName ~= false)
    self.affixFrame:SetShown(on and s.showAffixes ~= false)
    self.levelFrame:SetShown(on and s.showLevel ~= false and self.levelText:GetText() ~= nil)
    self.iconFrame:SetShown(on and s.showIcon == true and self.iconTex ~= nil)
end

function Dungeon:ApplyBlocksShown()
    self.UI:ApplyBlocksShown()
    Addon.MainWindow:Layout()
end

function UI:Show()
    self:Build()
    self.visible = true
    self:ApplyBlocksShown()
    Addon.MainWindow:Layout()
end

function UI:Hide()
    self.visible = false
    if self.frame then
        self.frame:Hide()
        self.affixFrame:Hide()
        self.levelFrame:Hide()
        self.iconFrame:Hide()
    end
    Addon.MainWindow:Layout()
end

function UI:Update(name, affixes, icon, level)
    if not self.frame then return end
    self._last = { name = name, affixes = affixes, icon = icon, level = level }
    self.nameText:SetText(name or "")
    self.affixText:SetText(affixes or "")
    self.levelText:SetText(level and Addon.Utils.KeystoneLevelTag(level, Dungeon:GetSettings().levelColor) or nil)
    self.iconTex = icon
    if icon then self.icon:SetTexture(icon) end
    self:LayoutBlocks()
    self:ApplyBlocksShown()
    Addon.MainWindow:Layout()
end

function UI:Restyle()
    if not self.frame then return end
    Addon.Widgets:ApplyTextStyle(self.nameText, ns.E.dungeonName)
    Addon.Widgets:ApplyTextStyle(self.affixText, ns.E.dungeonAffixes)
    Addon.Widgets:ApplyTextStyle(self.levelText, ns.E.dungeonLevel)
    -- Rebuild from the last data so the level color toggles live.
    if self._last then
        self:Update(self._last.name, self._last.affixes, self._last.icon, self._last.level)
    else
        self:LayoutBlocks()
    end
    Addon.MainWindow:Layout()
end
