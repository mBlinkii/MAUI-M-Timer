-- Modules/Cooldowns/Module.lua
-- Optional displays: available battle resurrections (charges + recharge timer)
-- and Heroism/Bloodlust availability (countdown of the exhaustion debuff).

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Cooldowns = Addon:NewMauiModule("Cooldowns", "cooldowns")
Cooldowns.state = { demo = false }

-- The shared combat-res pool is read via Rebirth's charges; Bloodlust is only
-- used for its icon.
Cooldowns.SPELL_REBIRTH   = 20484
Cooldowns.SPELL_BLOODLUST = 2825

-- Returns charges and seconds until the next one; either part may be nil.
local function getBrez()
    if not (C_Spell and C_Spell.GetSpellCharges) then return nil end
    local info = C_Spell.GetSpellCharges(Cooldowns.SPELL_REBIRTH)
    if not info then return nil end
    local charges = info.currentCharges or 0
    local recharge
    if charges < (info.maxCharges or 1) and info.cooldownStartTime and info.cooldownDuration then
        recharge = (info.cooldownStartTime + info.cooldownDuration) - GetTime()
        if recharge and recharge < 0 then recharge = nil end
    end
    return charges, recharge
end

-- Nil means lust is available now.
local function getLustCooldown()
    return Addon.Utils.GetLustDebuffRemaining()
end

function Cooldowns:OnEnable()
    self:RegisterMessage("MMT_RUN_STARTED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_RESTORED", "OnRunStart")
    self:RegisterMessage("MMT_RUN_ENDED", "OnRunEnd")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "LoadSettings")

    self.UI:Build()
    if Addon.Demo:IsActive() then
        self:SetDemo(true)
    elseif Addon.RunState:Get() then
        self:Start()
    end
end

function Cooldowns:OnDisable()
    self:UnregisterAllEvents()
    self:Stop()
    self.UI:Hide()
end

function Cooldowns:LoadSettings()
    if self.UI.Restyle then self.UI:Restyle() end
    if Addon.RunState:Get() and not self.state.demo then
        self:Start() -- re-evaluates visibility
    end
end

function Cooldowns:OnRunStart()
    self.state.demo = false
    self:Start()
end

function Cooldowns:OnRunEnd()
    if not self.state.demo then
        self:Stop()
        self.UI:Hide()
    end
end

function Cooldowns:AnyEnabled()
    local s = self:GetSettings()
    return (s.brez and s.brez.on) or (s.lust and s.lust.on)
end

function Cooldowns:Start()
    if not self:AnyEnabled() then
        self:Stop()
        self.UI:Hide()
        return
    end
    self.UI:Show()
    if not self.ticker then
        self.ticker = self:ScheduleRepeatingTimer("Refresh", 0.5)
    end
    self:Refresh()
end

function Cooldowns:Stop()
    if self.ticker then
        self:CancelTimer(self.ticker)
        self.ticker = nil
    end
end

function Cooldowns:Refresh()
    if self.state.demo then return end
    local s = self:GetSettings()
    local brezOn = s.brez and s.brez.on
    local lustOn = s.lust and s.lust.on

    local charges, recharge, lustCd
    if brezOn then charges, recharge = getBrez() end
    if lustOn then lustCd = getLustCooldown() end

    self.UI:Update(brezOn, charges, recharge, lustOn, lustCd)
end

function Cooldowns:SetDemo(state)
    self.state.demo = state
    if state then
        self.UI:Build()
        -- Only show what the per-feature toggles enabled.
        local s = self:GetSettings()
        local brezOn = s.brez and s.brez.on
        local lustOn = s.lust and s.lust.on
        self.UI:Update(brezOn, brezOn and 1 or nil, brezOn and 200 or nil, lustOn, lustOn and 360 or nil)
    elseif Addon.RunState:Get() then
        self:Start()
    else
        self.UI:Hide()
    end
end
