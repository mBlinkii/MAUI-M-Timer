-- Modules/Sound/Module.lua
-- Plays optional sounds on run events. Disabled by default (no sounds unless the
-- user enables the module and individual triggers). Death, forces-complete,
-- timeout and completed come from the message bus; Heroism is detected here via
-- the player's own aura (per the Midnight constraints).

local ADDON_NAME, ns = ...
local Addon = ns.Addon

-- Off by default (enabledByDefault = false); OnInitialize comes from ModuleBase.
local Sound = Addon:NewMauiModule("Sound", "sound", false)

-- True while a lust/heroism exhaustion debuff sits on the player (i.e. another
-- Heroism is NOT yet available). The debuff list + aura scan is shared with the
-- Cooldowns module via Utils, so both stay independently enable/disable-able.
local function lustActive()
    return Addon.Utils.GetLustDebuffRemaining() ~= nil
end

-- Lifecycle ------------------------------------------------------------------

function Sound:OnEnable()
    self:RegisterMessage("MMT_DEATH_COUNT_CHANGED", "OnDeath")
    self:RegisterMessage("MMT_FORCES_UPDATED", "OnForces")
    self:RegisterMessage("MMT_CHECKPOINT_REACHED", "OnCheckpoint")
    self:RegisterMessage("MMT_RUN_TIMED_OUT", "OnTimeout")
    self:RegisterMessage("MMT_RUN_COMPLETED", "OnCompleted")
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")

    -- If the module is enabled while a key is already in progress, start the
    -- Heroism watch immediately (OnRunStart will not fire retroactively).
    if Addon.RunState:Get() then self:StartHeroismWatch() end
end

function Sound:OnDisable()
    self:UnregisterAllEvents()
end

function Sound:OnRunStart()
    self._forcesDone = false
    self:StartHeroismWatch()
end

function Sound:OnRunEnd()
    self:StopHeroismWatch()
end

-- Heroism activation ---------------------------------------------------------

-- Begin watching the player's auras so we can fire the Heroism cue the moment
-- Heroism/Bloodlust becomes active on the player during a run. Snapshots the
-- current state so a debuff already running at start does not trigger a cue.
function Sound:StartHeroismWatch()
    self._lustActive = lustActive()
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
end

-- Stop the aura watch (run ended or module disabled).
function Sound:StopHeroismWatch()
    self:UnregisterEvent("UNIT_AURA")
    self._lustActive = nil
end

-- Fire the Heroism cue on the absent -> present transition of the exhaustion
-- debuff, i.e. the moment Heroism/Bloodlust is cast on the player, during a run.
function Sound:OnUnitAura(_, unit)
    if unit ~= "player" or not Addon.RunState:Get() then return end
    local active = lustActive()
    if active and not self._lustActive then
        self:Trigger("heroism")
    end
    self._lustActive = active
end

-- Play the configured sound for a trigger, if that trigger is enabled.
function Sound:Trigger(key)
    local triggers = self:GetSettings().triggers
    local t = triggers and triggers[key]
    if t and t.on then
        self.Data.Play(t.sound)
    end
end

-- Handlers -------------------------------------------------------------------

function Sound:OnDeath()
    if Addon.RunState:Get() then self:Trigger("death") end
end

-- Play once when enemy forces first reach 100%.
function Sound:OnForces(_, _, current, total)
    if not Addon.RunState:Get() then return end -- never outside an active M+ run
    if not self._forcesDone and total and total > 0 and current and current >= total then
        self._forcesDone = true
        self:Trigger("forces")
    end
end

function Sound:OnTimeout()
    self:Trigger("timeout")
end

function Sound:OnCompleted(_, onTime)
    -- Play on a successful (in-time) completion; if the flag is unknown, play.
    if onTime ~= false then self:Trigger("completed") end
end

-- A checkpoint's forces target was reached (sent by the Checkpoints module).
function Sound:OnCheckpoint()
    self:Trigger("checkpoint")
end
