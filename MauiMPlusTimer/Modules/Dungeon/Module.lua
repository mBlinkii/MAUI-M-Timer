-- Modules/Dungeon/Module.lua
-- Dungeon name, keystone level and affixes. Read-only: derives everything from
-- RunState and the challenge-mode API.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Dungeon = Addon:NewMauiModule("Dungeon", "dungeon")
Dungeon.state = { demo = false }

-- Falls back to the instance name while the challenge map is unavailable.
local function getDungeonName(run)
    local mapID = run and run.mapID
    if not mapID and C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        mapID = C_ChallengeMode.GetActiveChallengeMapID()
    end
    if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name and name ~= "" then return name end
    end
    return (GetInstanceInfo()) or ""
end

local function getKeystoneLevel(run)
    local level = run and run.keyLevel
    if not level and C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        level = C_ChallengeMode.GetActiveKeystoneInfo()
    end
    return level
end

local function getDungeonIcon(run)
    local mapID = run and run.mapID
    if not mapID and C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        mapID = C_ChallengeMode.GetActiveChallengeMapID()
    end
    if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        -- GetMapUIInfo -> name, id, timeLimit, texture, backgroundTexture
        local _, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
        return texture
    end
    return nil
end

-- Comma-separated and localized; "" when no affixes are known.
local function getAffixText(run)
    local ids = run and run.affixes
    if (not ids or #ids == 0) and C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local _, active = C_ChallengeMode.GetActiveKeystoneInfo()
        ids = active
    end
    if not ids or #ids == 0 then return "" end

    local names = {}
    for _, id in ipairs(ids) do
        local name
        if C_ChallengeMode and C_ChallengeMode.GetAffixInfo then
            name = C_ChallengeMode.GetAffixInfo(id)
        end
        names[#names + 1] = name or tostring(id)
    end
    return table.concat(names, ", ")
end

function Dungeon:OnEnable()
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "LoadSettings")

    self.UI:Build()
    if Addon.Demo:IsActive() then
        self:SetDemo(true)
    elseif Addon.RunState:Get() then
        self.UI:Show()
        self:Refresh()
    end
end

function Dungeon:OnDisable()
    self:UnregisterAllEvents()
    self.UI:Hide()
end

function Dungeon:OnRunStart()
    self.state.demo = false
    self.UI:Show()
    self:Refresh()
end

function Dungeon:OnRunEnd()
    if not self.state.demo then
        self.UI:Hide()
    end
end

function Dungeon:Refresh()
    if self.state.demo then return end
    local run = Addon.RunState:Get()
    self.UI:Update(getDungeonName(run), getAffixText(run), getDungeonIcon(run), getKeystoneLevel(run))
end

function Dungeon:SetDemo(state)
    self.state.demo = state
    if state then
        local L = ns.L
        self.UI:Build()
        self.UI:Show()
        self.UI:Update(L["Sample dungeon"], L["Sample affixes"],
            "Interface\\ICONS\\Achievement_ChallengeMode_Gold", 18)
    elseif Addon.RunState:Get() then
        self.UI:Show()
        self:Refresh()
    else
        self.UI:Hide()
    end
end
