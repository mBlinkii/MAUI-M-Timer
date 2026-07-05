-- Core/RunState.lua
-- Single source of truth for the active Mythic+ run. The record lives in the
-- per-character DB scope and is rewritten on every change, so a /reload mid-key
-- loses nothing. On login the record is restored if the key is still running.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local RunState = {}
Addon.RunState = RunState

-- Return the active run table, or nil when no key is running.
function RunState:Get()
    local run = Addon.db.char.activeRun
    if run == false or run == nil then return nil end
    return run
end

function RunState:IsActive()
    return self:Get() ~= nil
end

-- Begin a new run record. Called by Core/RunController on CHALLENGE_MODE_START.
function RunState:Start(info)
    info = info or {}
    Addon.db.char.activeRun = {
        mapID    = info.mapID,
        keyLevel = info.keyLevel,
        affixes  = info.affixes or {},
        startedAt = time(),
        forces   = { current = 0, total = 0 },
        bosses   = {},
        deaths   = {},
    }
    Addon:SendMessage("MMT_RUN_STARTED")
    Addon:Debug("RunState: run started (map %s, +%s)",
        tostring(info.mapID), tostring(info.keyLevel))
end

-- Clear the active run. Sent when the player actually leaves/abandons the key;
-- modules hide their displays on MMT_RUN_ENDED. Completion is a separate signal
-- (MMT_RUN_COMPLETED, sent by Core/RunController) so the summary can stay on
-- screen for review.
function RunState:Stop()
    Addon.db.char.activeRun = false
    Addon:SendMessage("MMT_RUN_ENDED")
    Addon:Debug("RunState: run stopped")
end

-- Record a death with timestamps. `elapsed` is seconds since the run start.
-- Pure data access: broadcasting MMT_DEATH_COUNT_CHANGED is the caller's job
-- (the Deaths module sends it once per count update, with the time penalty).
function RunState:AddDeath(name, elapsed)
    local run = self:Get()
    if not run then return end
    run.deaths = run.deaths or {}
    table.insert(run.deaths, {
        t    = elapsed or (time() - (run.startedAt or time())),
        wall = time(),
        name = name or "?",
    })
end

-- Number of recorded deaths for the active run.
function RunState:GetDeathCount()
    local run = self:Get()
    return run and #(run.deaths or {}) or 0
end

-- Restore an in-progress key after a /reload, or discard a stale record.
-- Uses the instance type rather than IsChallengeModeActive (which is false after
-- completion) so a finished run can still be reviewed after reloading.
function RunState:Restore()
    local run = self:Get()
    if not run then return end

    local _, instanceType, difficultyID = GetInstanceInfo()
    local inInstance = instanceType == "party" and difficultyID == 8

    if inInstance then
        Addon:Info("Active run restored after reload.")
        Addon:SendMessage("MMT_RUN_RESTORED")
    else
        -- We are no longer in the dungeon; drop the stale record.
        self:Stop()
    end
end
