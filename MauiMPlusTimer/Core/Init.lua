-- Core/Init.lua
-- Creates ns.Addon. Must load first; every other file depends on it.

local ADDON_NAME, ns = ...

local AceAddon = LibStub("AceAddon-3.0")

local Addon = AceAddon:NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

ns.Addon = Addon
ns.ADDON_NAME = ADDON_NAME

Addon.version = (C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "0.1.0"

-- ADDON_LOADED: SavedVariables are available and every .toc file is loaded.
function Addon:OnInitialize()
    -- silent = true: a missing key returns the key instead of erroring, so an
    -- untranslated string or a library probe cannot crash the addon.
    ns.L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)

    self:SetupDB()
    self:SetupConfig()
    self:SetupMinimapButton()

    self:Debug("Initialized v%s", self.version)
end

-- PLAYER_LOGIN.
function Addon:OnEnable()
    if self.RunController then
        self.RunController:Setup()
    end

    if self.RunState then
        self.RunState:Restore()
    end

    -- Warms the challenge map cache; GetMapTable stays empty without it.
    if C_ChallengeMode and C_ChallengeMode.RequestMapInfo then
        C_ChallengeMode.RequestMapInfo()
    end
    self:Info("MAUI M+ Timer ready. Type /mauimpt to open options.")

    -- Here rather than in OnInitialize: chat is only ready at PLAYER_LOGIN.
    self:Debug("Enabled v%s (profile: %s)", self.version, self.db:GetCurrentProfile())
end

-- Modules tear down their own state.
function Addon:OnDisable()
end
