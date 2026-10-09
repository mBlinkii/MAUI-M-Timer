-- Modules/Dungeon/UI.lua
-- Four independently placeable HUD blocks: dungeon name, map icon, keystone
-- level and affixes.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Dungeon = Addon:GetModule("Dungeon")

local UI = Addon:NewModuleUI()
Dungeon.UI = UI

local function justify(blockKey)
    return Addon.MainWindow:GetJustifyH("Dungeon", blockKey)
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
    self.levelBadge = self.levelFrame:CreateTexture(nil, "BACKGROUND")
    self.levelBadge:Hide()

    self.iconFrame = Addon.Widgets:CreateContainer(hud, "MauiMPlusTimerDungeonIconBlock")
    self.iconFrame:SetSize(Addon.MainWindow:GetWidth(), 20)
    self.icon = self.iconFrame:CreateTexture(nil, "ARTWORK")
    -- Trims the border baked into Blizzard icon textures; survives SetTexture.
    self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.iconFrame:Hide()

    self:LayoutBlocks()
    -- A split row narrows the blocks after LayoutBlocks ran.
    self.frame:SetScript("OnSizeChanged", function() UI:FitTexts() end)
    self.affixFrame:SetScript("OnSizeChanged", function()
        UI:FitTexts()
        UI:LayoutAffixes()
    end)
    self.levelFrame:SetScript("OnSizeChanged", function() UI:LayoutLevel() end)
    Addon.MainWindow:AddBlock("dungeon", self.frame, 5)
    Addon.MainWindow:AddBlock("dungeonicon", self.iconFrame, 4)
    Addon.MainWindow:AddBlock("level", self.levelFrame, 6)
    Addon.MainWindow:AddBlock("affixes", self.affixFrame, 7)
end

-- A long name ends in "..." instead of running past its block.
function UI:FitTexts()
    if not self.frame then return end
    self.nameText:SetWidth(math.max(20, self.frame:GetWidth()))
    self.affixText:SetWidth(math.max(20, self.affixFrame:GetWidth()))
end

function UI:LayoutBlocks()
    if not self.frame then return end
    Addon.Widgets:LayoutText(self.nameText, self.frame, ns.E.dungeonName, justify("dungeon"))
    self.frame:SetHeight(Addon.Widgets:LineHeight(ns.E.dungeonName, 14))

    Addon.Widgets:LayoutText(self.affixText, self.affixFrame, ns.E.dungeonAffixes, justify("affixes"))
    self:LayoutAffixes()
    self:LayoutLevel()

    local size = Dungeon:GetSettings().iconSize or 20
    local ij = justify("dungeonicon")
    self.icon:ClearAllPoints()
    self.icon:SetSize(size, size)
    self.icon:SetPoint(ij, self.iconFrame, ij, 0, 0)
    Addon.Widgets:ApplyIconMask(self.icon, Dungeon:GetSettings().iconMask)
    self.iconFrame:SetHeight(size)

    self:FitTexts()
end

local AFFIX_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- The affixes as text, or compactly as one icon per affix in a row aligned
-- like any HUD text.
function UI:LayoutAffixes()
    local s = Dungeon:GetSettings()
    local ids = self._last and self._last.affixIDs
    local icons = self.affixIcons or {}
    self.affixIcons = icons
    local count = (s.affixStyle == "icons" and ids) and #ids or 0
    if count == 0 then
        for _, tex in ipairs(icons) do tex:Hide() end
        self.affixText:Show()
        self.affixFrame:SetHeight(Addon.Widgets:LineHeight(ns.E.dungeonAffixes, 11))
        return
    end
    self.affixText:Hide()

    local size, gap = s.affixIconSize or 20, s.affixIconGap or 4
    local total = count * size + (count - 1) * gap
    local frameW = self.affixFrame:GetWidth() or 0
    local j = justify("affixes")
    local x = 0
    if j == "RIGHT" then
        x = frameW - total
    elseif j == "CENTER" then
        x = (frameW - total) / 2
    end
    local ox, oy = Addon.Widgets:GetOffset(ns.E.dungeonAffixes)
    x = Addon.Widgets:Snap(self.affixFrame, x + ox)
    for i = 1, count do
        local tex = icons[i]
        if not tex then
            tex = self.affixFrame:CreateTexture(nil, "ARTWORK")
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icons[i] = tex
        end
        local _, _, file = C_ChallengeMode.GetAffixInfo(ids[i])
        tex:SetTexture(file or AFFIX_FALLBACK)
        tex:SetSize(size, size)
        Addon.Widgets:ApplyIconMask(tex, s.affixIconMask)
        tex:ClearAllPoints()
        tex:SetPoint("LEFT", self.affixFrame, "LEFT", x + (i - 1) * (size + gap), oy)
        tex:Show()
    end
    for i = count + 1, #icons do icons[i]:Hide() end
    self.affixFrame:SetHeight(size)
end

-- Badge shapes: radius as a share of the badge height (nil = fixed radius).
local BADGE_RADIUS = { square = 0, pill = 0.5, circle = 0.5 }

-- The keystone level, optionally on a badge whose color follows the level's
-- rarity, the player's class or a fixed one. The badge sits where the text would, so the column
-- alignment holds.
function UI:LayoutLevel()
    local s = Dungeon:GetSettings()
    local fs, frame, badge = self.levelText, self.levelFrame, self.levelBadge
    local shape = s.levelBg or "none"
    local lineH = Addon.Widgets:LineHeight(ns.E.dungeonLevel, 14)
    local j = justify("level")
    local ox, oy = Addon.Widgets:GetOffset(ns.E.dungeonLevel)

    if shape == "none" then
        badge:Hide()
        fs:SetWidth(math.max(20, frame:GetWidth()))
        Addon.Widgets:LayoutText(fs, frame, ns.E.dungeonLevel, j)
        frame:SetHeight(lineH)
        return
    end

    local padX, padY = s.levelBgPadX or 6, s.levelBgPadY or 2
    local textW = math.ceil(fs:GetUnboundedStringWidth() or 0)
    local bw, bh = textW + padX * 2, lineH + padY * 2
    if shape == "circle" then
        bw = math.max(bw, bh)
        bh = bw
    end
    local cx = bw / 2
    if j == "RIGHT" then
        cx = frame:GetWidth() - bw / 2
    elseif j == "CENTER" then
        cx = frame:GetWidth() / 2
    end
    cx = Addon.Widgets:Snap(frame, cx + ox)

    badge:ClearAllPoints()
    badge:SetPoint("CENTER", frame, "TOPLEFT", cx, -bh / 2 + oy)
    badge:SetSize(bw, bh)
    local share = BADGE_RADIUS[shape]
    Addon.Widgets:PaintRounded(badge, share and bh * share or (s.levelBgRadius or 4), bh)
    local c = s.levelBgColor or { 1, 0.5, 0, 1 }
    local r, g, b, a = c[1], c[2], c[3], c[4] or 1
    local by = s.levelBgColorBy or "rarity"
    local level = self._last and self._last.level
    if by == "class" then
        local _, class = UnitClass("player")
        local cc = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        if cc then r, g, b = cc.r, cc.g, cc.b end
    elseif by == "rarity" and level and C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor then
        local rc = C_ChallengeMode.GetKeystoneLevelRarityColor(level)
        if rc then r, g, b = rc.r, rc.g, rc.b end
    end
    badge:SetVertexColor(r, g, b, a)
    badge:Show()

    fs:SetWidth(textW + 2)
    fs:SetJustifyH("CENTER")
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", badge, "CENTER", 0, 0)
    frame:SetHeight(bh)
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

function UI:Update(name, affixes, icon, level, affixIDs)
    if not self.frame then return end
    self._last = { name = name, affixes = affixes, icon = icon, level = level, affixIDs = affixIDs }
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
        local l = self._last
        self:Update(l.name, l.affixes, l.icon, l.level, l.affixIDs)
    else
        self:LayoutBlocks()
    end
    Addon.MainWindow:Layout()
end
