-- Modules/Automation/Module.lua
-- Quality-of-life automation that has no HUD element of its own:
--   * hide Blizzard's objective tracker while a Mythic+ run is active
--   * auto-slot the player's keystone when the Font of Power is opened
-- Both behaviours are opt-in; the module is enabled by default but does nothing
-- until one of its toggles is turned on.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local Automation = Addon:NewMauiModule("Automation", "automation")

-- Unified Mythic Keystone item (stable item id since Shadowlands). Kept as a
-- named constant so it is easy to extend should the id ever change.
local KEYSTONE_ITEM_ID = 180653

-- Blizzard's objective tracker frame (guarded; the global name is stable on
-- retail, but absent on some early-load paths).
local function tracker()
    return _G.ObjectiveTrackerFrame
end

-- True while a Mythic+ run is in progress.
local function challengeActive()
    return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()
end

-- Lifecycle ------------------------------------------------------------------

function Automation:OnEnable()
    -- Tracker visibility tracks the run lifecycle (and combat end, so it can be
    -- re-hidden out of combat after Blizzard reshows it).
    self:RegisterEvent("CHALLENGE_MODE_START", "ApplyTracker")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "ApplyTracker")
    self:RegisterEvent("CHALLENGE_MODE_RESET", "ApplyTracker")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ApplyTracker")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "ApplyTracker")
    -- The keystone receptacle (Font of Power) has no reliable event, so we hook
    -- the Blizzard frame's OnShow instead. Its addon is load-on-demand, so wait
    -- for it to load (and also try now in case it is already present).
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    self:RegisterMessage("MMT_PROFILE_CHANGED", "ApplyTracker")

    self:HookTracker()
    self:HookKeystoneFrame()
    self:ApplyTracker()
end

-- Hook the Font of Power frame once the Blizzard challenges UI is available.
function Automation:OnAddonLoaded(_, name)
    if name == "Blizzard_ChallengesUI" then
        self:HookKeystoneFrame()
    end
end

function Automation:OnDisable()
    self:UnregisterAllEvents()
    -- Always restore the tracker if we were the one hiding it.
    self:RestoreTracker()
end

-- Objective tracker ----------------------------------------------------------

--- Whether the tracker should currently be hidden: the option is on AND a run
--- is active. Outside a key the tracker is always left untouched.
function Automation:ShouldHideTracker()
    return self:IsEnabled() and self:GetSettings().hideTracker == true and challengeActive()
end

--- Apply the desired tracker visibility. Only re-shows the tracker when this
--- module was the one that hid it, so it never fights the user or other addons.
--- Safe to hide in combat: this only runs during an active key, where the
--- tracker shows the M+ scenario block (no secure quest-item buttons), so there
--- is no taint -- the same reasoning lets the OnShow hook re-hide mid-pull.
function Automation:ApplyTracker()
    local f = tracker()
    if not f then return end
    if self:ShouldHideTracker() then
        -- Only claim responsibility (_hid) when we actually hide the tracker.
        -- If it is already hidden (by the user or another addon), leave the flag
        -- alone so RestoreTracker never re-shows a tracker we did not hide.
        if f:IsShown() then
            f:Hide()
            self._hid = true
        end
    elseif self._hid then
        self:RestoreTracker()
    end
end

--- Unconditionally re-show the tracker if this module hid it.
function Automation:RestoreTracker()
    local f = tracker()
    if f and self._hid and not f:IsShown() then
        f:Show()
    end
    self._hid = false
end

--- Hook the tracker's Show so Blizzard reshowing it mid-run -- which happens
--- constantly on scenario/quest updates, including in combat -- is undone at
--- once. Like WarpDeplete, this hides on every Show with no combat guard: it
--- only fires during an active key (M+ scenario block, no secure item buttons),
--- so hiding in combat is taint-free and stops the mid-pull flicker.
function Automation:HookTracker()
    local f = tracker()
    if not f or self._hooked then return end
    self._hooked = true
    hooksecurefunc(f, "Show", function()
        if Automation:ShouldHideTracker() then
            f:Hide()
            -- The hook hid it, so this module is responsible for restoring it.
            Automation._hid = true
        end
    end)
end

-- Keystone auto-slot ---------------------------------------------------------

-- Locate the player's keystone in their bags. Returns bag, slot or nil.
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

-- Hook the Font of Power frame's OnShow once, so opening it auto-slots the
-- keystone. Safe to call repeatedly; only the first call installs the hook.
function Automation:HookKeystoneFrame()
    if self._keyHooked then return end
    local frame = _G.ChallengesKeystoneFrame
    if not frame then return end
    self._keyHooked = true
    frame:HookScript("OnShow", function() Automation:OnReceptacleOpen() end)
end

--- The Font of Power was opened: place the keystone automatically when enabled
--- and nothing is slotted yet. Skipped in combat (item pickup is protected).
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
