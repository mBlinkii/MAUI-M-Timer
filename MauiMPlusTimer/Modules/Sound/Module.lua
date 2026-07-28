-- Modules/Sound/Module.lua
-- Optional cues on run events, off by default. Most come from the message bus;
-- Heroism is detected from the player's own aura, per the Midnight constraints.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Sound = Addon:NewMauiModule("Sound", "sound", false)

-- True while an exhaustion debuff blocks another Heroism.
local function lustActive()
    return Addon.Utils.GetLustDebuffRemaining() ~= nil
end

function Sound:OnEnable()
    self:RegisterMessage("MMT_DEATH_COUNT_CHANGED", "OnDeath")
    self:RegisterMessage("MMT_FORCES_UPDATED", "OnForces")
    self:RegisterMessage("MMT_CHECKPOINT_REACHED", "OnCheckpoint")
    self:RegisterMessage("MMT_RUN_TIMED_OUT", "OnTimeout")
    self:RegisterMessage("MMT_RUN_COMPLETED", "OnCompleted")
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")

    -- Enabled mid-key: OnRunStart will not fire retroactively.
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

-- Snapshots the current state first, so a debuff already running at the start
-- does not fire a cue.
function Sound:StartHeroismWatch()
    self._lustActive = lustActive()
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
end

function Sound:StopHeroismWatch()
    self:UnregisterEvent("UNIT_AURA")
    self._lustActive = nil
end

-- The absent -> present transition of the exhaustion debuff is the moment lust
-- was cast on the player.
function Sound:OnUnitAura(_, unit)
    if unit ~= "player" or not Addon.RunState:Get() then return end
    local active = lustActive()
    if active and not self._lustActive then
        self:Trigger("heroism")
    end
    self._lustActive = active
end

function Sound:Trigger(key)
    local triggers = self:GetSettings().triggers
    local t = triggers and triggers[key]
    if t and t.on then
        self.Data.Play(t.sound)
    end
end

function Sound:OnDeath()
    if Addon.RunState:Get() then self:Trigger("death") end
end

-- Once per run, on first reaching 100%.
function Sound:OnForces(_, _, current, total)
    if not Addon.RunState:Get() then return end
    if not self._forcesDone and total and total > 0 and current and current >= total then
        self._forcesDone = true
        self:Trigger("forces")
    end
end

function Sound:OnTimeout()
    self:Trigger("timeout")
end

function Sound:OnCompleted(_, onTime)
    if onTime ~= false then self:Trigger("completed") end -- unknown counts as in time
end

function Sound:OnCheckpoint()
    self:Trigger("checkpoint")
end
