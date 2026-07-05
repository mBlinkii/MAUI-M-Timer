-- Modules/Objectives/Data.lua
-- Reads the boss objectives from the scenario criteria (the non-weighted
-- criteria). criteriaType 165 = "Defeat DungeonEncounter".

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Objectives = Addon:GetModule("Objectives")

local Data = {}
Objectives.Data = Data

-- Encounter Journal name resolution ------------------------------------------
-- The scenario criterion text carries a localized suffix (e.g. "<Boss> defeated"
-- / "<Boss> besiegt"). Instead of trimming that per language, we resolve the
-- canonical boss name from the Encounter Journal via the criterion's
-- dungeonEncounterID, which Blizzard supplies clean and already localized in the
-- client's language. Names are cached per dungeon instance for the whole run.

local ejInstanceID            -- EJ instance the current cache was built for
local ejByEncounter = {}      -- dungeonEncounterID -> clean boss name
local ejByIndex = {}          -- 1-based boss order -> clean boss name

-- Encounter Journal instance id for the dungeon the player is currently in.
-- Reliable inside the instance (where boss names are needed); nil otherwise.
local function currentEJInstance()
    local uiMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not uiMapID then return nil end
    local id = EJ_GetInstanceForMap and EJ_GetInstanceForMap(uiMapID)
    -- 0 means "no journal instance for this map"; treat it as unavailable so we
    -- never pass it to EJ_SelectInstance (which errors on an invalid id).
    if not id or id == 0 then return nil end
    return id
end

-- Read every encounter of an instance into the caches. Returns true if any name
-- was found. Requires the Encounter Journal addon loaded and the instance
-- selected first (EJ_GetEncounterInfoByIndex otherwise returns nil).
local function queryEJ(instanceID)
    wipe(ejByEncounter)
    wipe(ejByIndex)
    for i = 1, 20 do -- well above the boss count of any dungeon
        local name, _, _, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(i, instanceID)
        if name then
            ejByIndex[i] = name
            if dungeonEncounterID then ejByEncounter[dungeonEncounterID] = name end
        end
    end
    return next(ejByIndex) ~= nil
end

-- Populate the name caches for the current dungeon, at most once per instance.
-- A plain query usually suffices; if it returns nothing we briefly open (and
-- re-hide) the journal to force it to populate. That open touches a protected
-- panel, so it is skipped in combat -- names are normally resolved during the
-- pre-run countdown (out of combat), so this is not a practical limitation.
local function ensureEJNames()
    -- The Encounter Journal must be loaded before its lookups return data and
    -- before EJ_GetInstanceForMap resolves, so load it up front.
    if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_EncounterJournal") end
    if not (EJ_GetInstanceForMap and EJ_GetEncounterInfoByIndex) then return end

    local instanceID = currentEJInstance()
    if not instanceID then return end
    if instanceID == ejInstanceID and next(ejByIndex) then return end -- cached

    -- EJ_SelectInstance can error for an instance id outside the current journal
    -- tier, so guard the whole resolution; on any failure we keep the raw names.
    pcall(function()
        if EJ_SelectInstance then EJ_SelectInstance(instanceID) end
        if not queryEJ(instanceID) and not InCombatLockdown() and EncounterJournal_OpenJournal then
            local wasShown = EncounterJournal and EncounterJournal:IsShown()
            EncounterJournal_OpenJournal(8, instanceID) -- difficulty 8 = Mythic Keystone
            if not wasShown and EncounterJournal and HideUIPanel then HideUIPanel(EncounterJournal) end
            queryEJ(instanceID)
        end
    end)

    if next(ejByIndex) then ejInstanceID = instanceID end
end

-- Clean display name for a boss: prefer the Encounter Journal name (by
-- dungeonEncounterID, else by boss order), falling back to the raw criterion text.
local function bossName(description, order, encounterID)
    ensureEJNames()
    if encounterID and ejByEncounter[encounterID] then return ejByEncounter[encounterID] end
    if ejByIndex[order] then return ejByIndex[order] end
    return description
end

-- Return an ordered list of { name, done, encounterID } for the dungeon bosses.
function Data.Read()
    local result = {}
    if not (C_Scenario and C_Scenario.GetStepInfo) then return result end
    local stepCount = select(3, C_Scenario.GetStepInfo())
    if not stepCount or stepCount <= 0 then return result end

    for i = 1, stepCount do
        local info = C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo(i)
        if info and not info.isWeightedProgress then
            local encounterID = info.criteriaType == 165 and info.assetID or nil
            -- Completion time = challenge elapsed minus the time since the
            -- criterion completed.
            local time
            if info.completed and GetWorldElapsedTime then
                local _, elapsed = GetWorldElapsedTime(1)
                time = (elapsed or 0) - (info.elapsed or 0)
            end
            result[#result + 1] = {
                name = bossName(info.description, #result + 1, encounterID) or ("Boss " .. i),
                done = info.completed and true or false,
                encounterID = encounterID,
                time = time,
            }
        end
    end
    return result
end
