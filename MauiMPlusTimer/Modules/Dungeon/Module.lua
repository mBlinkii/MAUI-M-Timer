-- Modules/Dungeon/Module.lua
-- Dungeon name, map icon, keystone level and affixes. Read-only: derives everything from
-- RunState and the challenge-mode API.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Dungeon = Addon:NewMauiModule("Dungeon", "dungeon")
Dungeon.state = { demo = false }

-- The short names the community uses, keyed by challenge mapID.
local ABBREVIATIONS = {
    -- Midnight Season 1
    [161] = "SKY",  -- Skyreach
    [239] = "SEAT", -- Seat of the Triumvirate
    [402] = "AA",   -- Algeth'ar Academy
    [556] = "POS",  -- Pit of Saron
    [557] = "WS",   -- Windrunner Spire
    [558] = "MT",   -- Magisters' Terrace
    [559] = "NPX",  -- Nexus-Point Xenas
    [560] = "MC",   -- Maisara Caverns
    [583] = "SEAT", -- Seat of the Triumvirate
    -- Midnight Season 2
    [249] = "KR",   -- Kings' Rest
    [250] = "TOS",  -- Temple of Sethraliss
    [399] = "RLP",  -- Ruby Life Pools
    [584] = "BV",   -- The Blinding Vale
    [585] = "VA",   -- Voidscar Arena
    [586] = "DON",  -- Den of Nalorakk
    [587] = "MR",   -- Murder Row
    [588] = "AOF",  -- Altar of Fangs
}

-- Lowercase joining words that do not count for a generated abbreviation.
local SKIP_WORDS = { ["of"] = true, ["the"] = true, ["de"] = true, ["la"] = true, ["del"] = true, ["der"] = true, ["des"] = true, ["du"] = true }

-- Known dungeons use the table, others the initials of their name; names
-- without word breaks (e.g. Chinese) stay complete.
local function abbreviate(name, mapID)
    if mapID and ABBREVIATIONS[mapID] then return ABBREVIATIONS[mapID] end
    local initials = {}
    for word in name:gmatch("[^%s%-]+") do
        if not SKIP_WORDS[word] then
            initials[#initials + 1] = word:match("^[%z\1-\127\194-\244][\128-\191]*"):upper()
        end
    end
    if #initials < 2 then return name end
    return table.concat(initials)
end

local function displayName(name, mapID)
    if Dungeon:GetSettings().nameShort and name ~= "" then return abbreviate(name, mapID) end
    return name
end

-- Fortified, Tyrannical and Xal'atath's Guile for the demo icons; an ID the
-- client does not know shows a question mark.
local DEMO_AFFIXES = { 10, 9, 147 }

-- Falls back to the instance name while the challenge map is unavailable.
local function getDungeonName(run)
    local mapID = run and run.mapID
    if not mapID and C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        mapID = C_ChallengeMode.GetActiveChallengeMapID()
    end
    if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name and name ~= "" then return displayName(name, mapID) end
    end
    return displayName((GetInstanceInfo()) or "")
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

-- Comma-separated and localized ("" when none are known), plus the affix IDs
-- for the icon display.
local function getAffixes(run)
    local ids = run and run.affixes
    if (not ids or #ids == 0) and C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local _, active = C_ChallengeMode.GetActiveKeystoneInfo()
        ids = active
    end
    if not ids or #ids == 0 then return "", nil end

    local names = {}
    for _, id in ipairs(ids) do
        local name
        if C_ChallengeMode and C_ChallengeMode.GetAffixInfo then
            name = C_ChallengeMode.GetAffixInfo(id)
        end
        names[#names + 1] = name or tostring(id)
    end
    return table.concat(names, ", "), ids
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
    local affixText, affixIDs = getAffixes(run)
    self.UI:Update(getDungeonName(run), affixText, getDungeonIcon(run), getKeystoneLevel(run), affixIDs)
end

function Dungeon:SetDemo(state)
    self.state.demo = state
    if state then
        local L = ns.L
        self.UI:Build()
        self.UI:Show()
        self.UI:Update(displayName(L["Sample dungeon"]), L["Sample affixes"],
            "Interface\\ICONS\\Achievement_ChallengeMode_Gold", 18, DEMO_AFFIXES)
    elseif Addon.RunState:Get() then
        self.UI:Show()
        self:Refresh()
    else
        self.UI:Hide()
    end
end
