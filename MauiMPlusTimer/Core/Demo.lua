-- Core/Demo.lua
-- Feeds every module synthetic values so the UI can be styled outside a key.
-- Never touches the real run state.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Demo = {}
Addon.Demo = Demo

function Demo:IsActive()
    -- Single guard for all modules: a live run always wins, even when the demo
    -- preference was left on before the key began.
    if Addon.RunState and Addon.RunState:Get() then return false end
    return Addon.db.profile.ui.demo == true
end

-- No argument flips the current state.
function Demo:Toggle(state)
    if state == nil then
        state = not Addon.db.profile.ui.demo
    end
    Addon.db.profile.ui.demo = state

    -- Forced off during a run, so toggling demo on mid-key still shows real data.
    local effective = state and not (Addon.RunState and Addon.RunState:Get())
    for _, module in Addon:IterateModules() do
        if module.SetDemo and module:IsEnabled() then
            module:SetDemo(effective)
        end
    end

    Addon:SendMessage("MMT_DEMO_CHANGED", state)
    Addon:Info("Demo mode %s.", state and "enabled" or "disabled")
end

-- Re-push the samples after a settings change, without toggling demo off/on.
function Demo:Refresh()
    if not self:IsActive() then return end
    for _, module in Addon:IterateModules() do
        if module.SetDemo and module:IsEnabled() then
            module:SetDemo(true)
        end
    end
end

-- Pushes the active profile's demo state, including OFF -- used after a profile
-- switch so modules stop showing the old profile's samples.
function Demo:Apply()
    local effective = self:IsActive()
    for _, module in Addon:IterateModules() do
        if module.SetDemo and module:IsEnabled() then
            module:SetDemo(effective)
        end
    end
end
