-- Modules/Timer/Data.lua
-- Pure threshold math for the Mythic+ timer. No UI, no game state.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Timer = Addon:GetModule("Timer")

local Data = {}
Timer.Data = Data

-- The +2 / +3 thresholds are fractions of the base time limit.
-- Beating 80% earns +2, beating 60% earns +3 (standard Mythic+ rules).
Data.PLUS3_FRACTION = 0.6
Data.PLUS2_FRACTION = 0.8

-- Return the absolute threshold times (seconds) for a given time limit.
function Data.GetThresholds(timeLimit)
    timeLimit = timeLimit or 0
    return {
        plus3 = timeLimit * Data.PLUS3_FRACTION,
        plus2 = timeLimit * Data.PLUS2_FRACTION,
        plus1 = timeLimit,
    }
end

-- Map elapsed time to the bonus level still achievable (3, 2, 1, or 0 = depleted).
function Data.GetBonusLevel(elapsed, timeLimit)
    if not timeLimit or timeLimit <= 0 then return 0 end
    if elapsed <= timeLimit * Data.PLUS3_FRACTION then return 3 end
    if elapsed <= timeLimit * Data.PLUS2_FRACTION then return 2 end
    if elapsed <= timeLimit then return 1 end
    return 0
end
