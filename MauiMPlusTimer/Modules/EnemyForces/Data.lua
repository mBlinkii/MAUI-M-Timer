-- Modules/EnemyForces/Data.lua
-- Reads the aggregate Enemy Forces progress from the scenario criteria.
-- Midnight-safe: only the total weighted-progress value is used, never per-mob

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Forces = Addon:GetModule("EnemyForces")

local Data = {}
Forces.Data = Data

-- Return current, total (absolute counts) for the Enemy Forces criterion, or
-- nil when it is not present (e.g. outside a key or before it loads).
function Data.Read()
    if not (C_Scenario and C_Scenario.GetStepInfo) then return nil end
    local stepCount = select(3, C_Scenario.GetStepInfo())
    if not stepCount or stepCount <= 0 then return nil end

    for i = 1, stepCount do
        local info = C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo(i)
        if info and info.isWeightedProgress and info.totalQuantity and info.totalQuantity > 0 then
            -- quantityString is an absolute value that still carries a '%' sign,
            -- so we extract the leading number (decimals included, should the
            -- client ever report fractional progress).
            local current = info.quantityString and tonumber(info.quantityString:match("%d+%.?%d*")) or 0
            return current, info.totalQuantity
        end
    end
    return nil
end
