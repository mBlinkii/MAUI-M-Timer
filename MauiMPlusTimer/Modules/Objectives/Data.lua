-- Modules/Objectives/Data.lua
-- Reads the boss objectives from the scenario criteria (the non-weighted
-- criteria). criteriaType 165 = "Defeat DungeonEncounter".

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Objectives = Addon:GetModule("Objectives")

local Data = {}
Objectives.Data = Data

-- The criterion text carries a localized suffix ("<Boss> defeated"). Rather
-- than trimming that per language, resolve the clean name from the Encounter
-- Journal via dungeonEncounterID. Cached per instance for the whole run.

local ejInstanceID            -- EJ instance the current cache was built for
local ejByEncounter = {}      -- dungeonEncounterID -> clean boss name
local ejByIndex = {}          -- 1-based boss order -> clean boss name

-- Only reliable inside the instance, which is where boss names are needed.
local function currentEJInstance()
    local uiMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not uiMapID then return nil end
    local id = EJ_GetInstanceForMap and EJ_GetInstanceForMap(uiMapID)
    -- 0 means no journal instance; EJ_SelectInstance errors on an invalid id.
    if not id or id == 0 then return nil end
    return id
end

-- Needs the journal loaded and the instance selected, or
-- EJ_GetEncounterInfoByIndex returns nil. True when any name was found.
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

-- At most once per instance. If a plain query comes back empty the journal is
-- briefly opened to force it to populate; that touches a protected panel, so it
-- is skipped in combat (names normally resolve during the pre-run countdown).
local function ensureEJNames()
    -- Must be loaded before any lookup resolves, EJ_GetInstanceForMap included.
    if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_EncounterJournal") end
    if not (EJ_GetInstanceForMap and EJ_GetEncounterInfoByIndex) then return end

    local instanceID = currentEJInstance()
    if not instanceID then return end
    if instanceID == ejInstanceID and next(ejByIndex) then return end -- cached

    -- EJ_SelectInstance errors for an id outside the current journal tier; on
    -- any failure the raw criterion names are kept.
    pcall(function()
        if EJ_SelectInstance then EJ_SelectInstance(instanceID) end
        if not queryEJ(instanceID) and not InCombatLockdown() and EncounterJournal_OpenJournal then
            local wasShown = EncounterJournal and EncounterJournal:IsShown()
            EncounterJournal_OpenJournal(8, instanceID) -- 8 = Mythic Keystone
            if not wasShown and EncounterJournal and HideUIPanel then HideUIPanel(EncounterJournal) end
            queryEJ(instanceID)
        end
    end)

    if next(ejByIndex) then ejInstanceID = instanceID end
end

-- Prefers the journal name by encounter id, then by boss order, then the raw
-- criterion text.
local function bossName(description, order, encounterID)
    ensureEJNames()
    if encounterID and ejByEncounter[encounterID] then return ejByEncounter[encounterID] end
    if ejByIndex[order] then return ejByIndex[order] end
    return description
end

-- Ordered list of { name, done, encounterID, time }.
function Data.Read()
    local result = {}
    if not (C_Scenario and C_Scenario.GetStepInfo) then return result end
    local stepCount = select(3, C_Scenario.GetStepInfo())
    if not stepCount or stepCount <= 0 then return result end

    for i = 1, stepCount do
        local info = C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo(i)
        if info and not info.isWeightedProgress then
            local encounterID = info.criteriaType == 165 and info.assetID or nil
            -- Challenge elapsed minus the time since the criterion completed.
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
