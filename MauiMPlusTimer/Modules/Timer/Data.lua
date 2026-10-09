-- Modules/Timer/Data.lua
-- Pure threshold math for the Mythic+ timer. No UI, no game state.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Timer = Addon:GetModule("Timer")

local Data = {}
Timer.Data = Data

-- Fractions of the base time limit, per the standard Mythic+ rules.
Data.PLUS3_FRACTION = 0.6
Data.PLUS2_FRACTION = 0.8

-- Bonus level still achievable: 3, 2, 1, or 0 for depleted.
function Data.GetBonusLevel(elapsed, timeLimit)
    if not timeLimit or timeLimit <= 0 then return 0 end
    if elapsed <= timeLimit * Data.PLUS3_FRACTION then return 3 end
    if elapsed <= timeLimit * Data.PLUS2_FRACTION then return 2 end
    if elapsed <= timeLimit then return 1 end
    return 0
end
