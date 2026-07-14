-- Core/Demo.lua
-- Coordinates the demo mode. When enabled it asks every module to display
-- synthetic values so the user can position and style the UI outside a key.
-- It never touches the real run state.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Demo = {}
Addon.Demo = Demo

function Demo:IsActive()
    -- A live run always wins: synthetic demo values must never overlay real run
    -- data, even when the demo preference was left enabled before the key began.
    -- Every caller that decides whether to push demo values goes through here, so
    -- this single guard suppresses demo across all modules during a run.
    if Addon.RunState and Addon.RunState:Get() then return false end
    return Addon.db.profile.ui.demo == true
end

-- Toggle demo mode. With no argument it flips the current state.
function Demo:Toggle(state)
    if state == nil then
        state = not Addon.db.profile.ui.demo
    end
    Addon.db.profile.ui.demo = state

    -- Notify every enabled module; each implements SetDemo(state). Disabled
    -- modules are skipped so they stay hidden even in demo mode. While a real run
    -- is active the effective state is forced off, so toggling demo on mid-run
    -- shows real data (e.g. the Run-vs-best delta) instead of the samples.
    local effective = state and not (Addon.RunState and Addon.RunState:Get())
    for _, module in Addon:IterateModules() do
        if module.SetDemo and module:IsEnabled() then
            module:SetDemo(effective)
        end
    end

    Addon:SendMessage("MMT_DEMO_CHANGED", state)
    Addon:Info("Demo mode %s.", state and "enabled" or "disabled")
end

-- Re-push the synthetic values to every enabled module. Call this after any
-- settings change so demo mode reflects it live, without toggling demo off/on.
function Demo:Refresh()
    if not self:IsActive() then return end
    for _, module in Addon:IterateModules() do
        if module.SetDemo and module:IsEnabled() then
            module:SetDemo(true)
        end
    end
end

-- Push the CURRENT demo state (from the active profile, suppressed during a run)
-- to every enabled module - including turning it OFF. Used after a profile
-- switch so modules that were showing demo values in the old profile update to
-- the new profile's demo setting without a reload.
function Demo:Apply()
    local effective = self:IsActive()
    for _, module in Addon:IterateModules() do
        if module.SetDemo and module:IsEnabled() then
            module:SetDemo(effective)
        end
    end
end
