-- Core/Init.lua
-- Creates the addon object and exposes it through the private namespace.
-- This file must load first so that ns.Addon exists for every other file.

local ADDON_NAME, ns = ...

local AceAddon = LibStub("AceAddon-3.0")

-- The main addon object. Mixins provide the methods used across the codebase:
--   AceConsole-3.0 -> slash commands + Print
--   AceEvent-3.0   -> RegisterEvent / RegisterMessage / SendMessage (message bus)
--   AceTimer-3.0   -> ScheduleTimer / ScheduleRepeatingTimer (polling)
local Addon = AceAddon:NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- Publish the addon object and metadata so all other files can reach them.
ns.Addon = Addon
ns.ADDON_NAME = ADDON_NAME

-- Resolve the addon version from the .toc metadata (with a safe fallback).
Addon.version = (C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "0.1.0"

-- AceAddon lifecycle ---------------------------------------------------------

-- Runs once when SavedVariables are available (ADDON_LOADED). All toc files are
-- already loaded at this point, so Core services and modules are reachable.
function Addon:OnInitialize()
    -- Resolve the localization table now that all locale files are registered.
    -- silent = true: missing keys return the key itself instead of erroring
    -- (avoids crashes from untranslated strings or library probes like
    -- ToDebugString on the locale table).
    ns.L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)

    -- Create the database (Core/DB.lua).
    self:SetupDB()

    -- Build and register the options GUI + slash command (Core/Config.lua).
    self:SetupConfig()

    -- Broker data object + optional minimap button (Core/Broker.lua).
    self:SetupBroker()

    self:Debug("Initialized v%s", self.version)
end

-- Runs at PLAYER_LOGIN (or right after, if the addon is loaded on demand).
function Addon:OnEnable()
    -- Always-on run lifecycle detection (Core/RunController.lua). Registered here
    -- so run detection works regardless of which display modules are enabled.
    if self.RunController then
        self.RunController:Setup()
    end

    -- Restore an in-progress key after a /reload (Core/RunState.lua).
    if self.RunState then
        self.RunState:Restore()
    end
    self:Info("MAUI M+ Timer ready. Type /mauimpt to open options.")

    -- Debug confirmation. Emitted at PLAYER_LOGIN (chat is ready here, unlike
    -- OnInitialize which runs during the loading screen and can be missed).
    self:Debug("Enabled v%s (profile: %s)", self.version, self.db:GetCurrentProfile())
end

-- Runs when the addon is disabled. Modules tear down their own state.
function Addon:OnDisable()
end
