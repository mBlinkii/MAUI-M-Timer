-- Core/RunState.lua
-- Single source of truth for the active run. The record is rewritten on every
-- change in the char scope, so a /reload mid-key loses nothing.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local RunState = {}
Addon.RunState = RunState

-- Nil when no key is running.
function RunState:Get()
    local run = Addon.db.char.activeRun
    if run == false or run == nil then return nil end
    return run
end

function RunState:IsActive()
    return self:Get() ~= nil
end

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

-- Only for leaving or abandoning a key. Completing one is MMT_RUN_COMPLETED,
-- which keeps the record so the summary stays reviewable.
function RunState:Stop()
    Addon.db.char.activeRun = false
    Addon:SendMessage("MMT_RUN_ENDED")
    Addon:Debug("RunState: run stopped")
end

-- `elapsed` is seconds since the run start. Storage only: sending
-- MMT_DEATH_COUNT_CHANGED is the Deaths module's job.
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

function RunState:GetDeathCount()
    local run = self:Get()
    return run and #(run.deaths or {}) or 0
end

-- Restores an in-progress key after a /reload, or discards a stale record.
-- Keys on the instance type, not IsChallengeModeActive, which is already false
-- after completion -- a finished run stays reviewable across a reload.
function RunState:Restore()
    local run = self:Get()
    if not run then return end

    local _, instanceType, difficultyID = GetInstanceInfo()
    local inInstance = instanceType == "party" and difficultyID == 8

    if inInstance then
        Addon:Info("Active run restored after reload.")
        Addon:SendMessage("MMT_RUN_RESTORED")
    else
        self:Stop() -- no longer in the dungeon, drop the stale record

    end
end
