-- Modules/Dungeon/Module.lua
-- Displays the current Mythic+ dungeon name and, optionally, the active affixes
-- beneath it. Read-only: it derives everything from RunState and the challenge
-- mode API and owns no run logic of its own.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Dungeon = Addon:NewMauiModule("Dungeon", "dungeon")
Dungeon.state = { demo = false }

-- Resolve the dungeon name from the active keystone map, falling back to the
-- instance name when the challenge map is not (yet) available.
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

-- Resolve the active keystone level (from the run, or the active keystone).
local function getKeystoneLevel(run)
    local level = run and run.keyLevel
    if not level and C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        level = C_ChallengeMode.GetActiveKeystoneInfo()
    end
    return level
end

-- Resolve the dungeon's icon texture (fileID) from the active keystone map.
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

-- Build a comma-separated, localized affix list from the run's affix IDs (or the
-- active keystone's affixes as a fallback). Returns "" when none are known.
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

-- Lifecycle ------------------------------------------------------------------

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

-- Handlers -------------------------------------------------------------------

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

-- Re-read the dungeon name + affixes and update the display.
function Dungeon:Refresh()
    if self.state.demo then return end
    local run = Addon.RunState:Get()
    self.UI:Update(getDungeonName(run), getAffixText(run), getDungeonIcon(run), getKeystoneLevel(run))
end

-- Demo mode ------------------------------------------------------------------

function Dungeon:SetDemo(state)
    self.state.demo = state
    if state then
        local L = ns.L
        self.UI:Build()
        self.UI:Show()
        -- Sample icon + level so the options can be positioned/sized outside a key.
        self.UI:Update(L["Sample dungeon"], L["Sample affixes"],
            "Interface\\ICONS\\Achievement_ChallengeMode_Gold", 18)
    elseif Addon.RunState:Get() then
        self.UI:Show()
        self:Refresh()
    else
        self.UI:Hide()
    end
end
