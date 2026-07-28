-- Modules/Automation/Module.lua
-- Opt-in quality-of-life behaviours with no HUD element: hiding Blizzard's
-- objective tracker during a run, and auto-slotting the keystone.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Automation = Addon:NewMauiModule("Automation", "automation")

local KEYSTONE_ITEM_ID = 180653 -- Unified Mythic Keystone

-- Guarded: the global is stable on retail but absent on early-load paths.
local function tracker()
    return _G.ObjectiveTrackerFrame
end

local function challengeActive()
    return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()
end

function Automation:OnEnable()
    -- PLAYER_REGEN_ENABLED too, so the tracker can be re-hidden out of combat
    -- after Blizzard reshows it.
    self:RegisterEvent("CHALLENGE_MODE_START", "ApplyTracker")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "ApplyTracker")
    self:RegisterEvent("CHALLENGE_MODE_RESET", "ApplyTracker")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ApplyTracker")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "ApplyTracker")
    -- The Font of Power has no reliable event, so its OnShow is hooked instead.
    -- Blizzard_ChallengesUI is load-on-demand, hence ADDON_LOADED.
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "ApplyTracker")

    self:HookTracker()
    self:HookKeystoneFrame()
    self:ApplyTracker()
end

function Automation:OnAddonLoaded(_, name)
    if name == "Blizzard_ChallengesUI" then
        self:HookKeystoneFrame()
    end
end

function Automation:OnDisable()
    self:UnregisterAllEvents()
    self:RestoreTracker()
end

-- Outside a key the tracker is always left untouched.
function Automation:ShouldHideTracker()
    return self:IsEnabled() and self:GetSettings().hideTracker == true and challengeActive()
end

-- Hiding in combat is taint-free here: this only runs during an active key,
-- where the tracker shows the M+ scenario block and no secure item buttons.
function Automation:ApplyTracker()
    local f = tracker()
    if not f then return end
    if self:ShouldHideTracker() then
        -- Claim _hid only on an actual hide, so RestoreTracker never re-shows a
        -- tracker the user or another addon had already hidden.
        if f:IsShown() then
            f:Hide()
            self._hid = true
        end
    elseif self._hid then
        self:RestoreTracker()
    end
end

function Automation:RestoreTracker()
    local f = tracker()
    if f and self._hid and not f:IsShown() then
        f:Show()
    end
    self._hid = false
end

-- Blizzard reshows the tracker constantly on scenario and quest updates,
-- including mid-pull, so the hook undoes that at once. No combat guard for the
-- reason given on ApplyTracker; without it the tracker flickers during a pull.
function Automation:HookTracker()
    local f = tracker()
    if not f or self._hooked then return end
    self._hooked = true
    hooksecurefunc(f, "Show", function()
        if Automation:ShouldHideTracker() then
            f:Hide()
            Automation._hid = true
        end
    end)
end

-- Returns bag, slot or nil.
local function findKeystone()
    if not C_Container then return nil end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            if C_Container.GetContainerItemID(bag, slot) == KEYSTONE_ITEM_ID then
                return bag, slot
            end
        end
    end
    return nil
end

-- Safe to call repeatedly; only the first call installs the hook.
function Automation:HookKeystoneFrame()
    if self._keyHooked then return end
    local frame = _G.ChallengesKeystoneFrame
    if not frame then return end
    self._keyHooked = true
    frame:HookScript("OnShow", function() Automation:OnReceptacleOpen() end)
end

-- Skipped in combat: item pickup is protected.
function Automation:OnReceptacleOpen()
    if not self:IsEnabled() or self:GetSettings().autoSlotKeystone ~= true then return end
    if InCombatLockdown() then return end
    if C_ChallengeMode and C_ChallengeMode.HasSlottedKeystone and C_ChallengeMode.HasSlottedKeystone() then
        return
    end
    local bag, slot = findKeystone()
    if not bag then return end
    ClearCursor()
    C_Container.PickupContainerItem(bag, slot)
    if C_ChallengeMode and C_ChallengeMode.SlotKeystone then
        C_ChallengeMode.SlotKeystone()
    end
end
