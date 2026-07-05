-- Modules/Sound/Data.lua
-- Sound selection list and playback. Includes the addon's own bundled sounds
-- (Assets/Sounds), a few built-in WoW sound kits, and any LibSharedMedia sounds.
-- "None" plays nothing.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Sound = Addon:GetModule("Sound")

local Data = {}
Sound.Data = Data

-- Bundled sounds shipped with the addon (royalty-free game SFX sourced from
-- Pixabay; see the About > Credits page for the authors). Several cues ship
-- multiple takes so the user can pick a favourite in the per-trigger sound
-- dropdown; the cue defaults (see Core/DB.lua) point at the unsuffixed name.
local SOUND_DIR = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Sounds\\"
local BUNDLED = {
    -- Death cues.
    ["MAUI: Death"]              = SOUND_DIR .. "death.mp3",
    ["MAUI: Death (Shock)"]      = SOUND_DIR .. "death-shock.mp3",
    ["MAUI: Death (Evil Laugh)"] = SOUND_DIR .. "death-laugh.mp3",
    ["MAUI: Death (Cackle)"]     = SOUND_DIR .. "death-cackle.mp3",

    -- Timeout / failed-run cues.
    ["MAUI: Timeout"]            = SOUND_DIR .. "timeout.mp3",
    ["MAUI: Timeout (Arcade)"]   = SOUND_DIR .. "timeout-arcade.mp3",
    ["MAUI: Timeout (Voice)"]    = SOUND_DIR .. "timeout-voice.mp3",
    ["MAUI: Timeout (Heartbeat)"] = SOUND_DIR .. "timeout-heartbeat.mp3",

    -- Success / completed cues.
    ["MAUI: Success"]            = SOUND_DIR .. "success.mp3",
    ["MAUI: Success (Winner)"]   = SOUND_DIR .. "success-winner.mp3",
    ["MAUI: Success (Chime)"]    = SOUND_DIR .. "success-chime.mp3",

    -- Checkpoint cues.
    ["MAUI: Checkpoint"]         = SOUND_DIR .. "checkpoint.mp3",
    ["MAUI: Checkpoint 2"]       = SOUND_DIR .. "checkpoint-2.mp3",
    ["MAUI: Checkpoint 3"]       = SOUND_DIR .. "checkpoint-3.mp3",
    ["MAUI: Checkpoint 4"]       = SOUND_DIR .. "checkpoint-4.mp3",
    ["MAUI: Checkpoint (Item)"]  = SOUND_DIR .. "checkpoint-item.mp3",
    ["MAUI: Checkpoint (UI)"]    = SOUND_DIR .. "checkpoint-ui.mp3",

    -- Enemy-forces cues.
    ["MAUI: Forces"]             = SOUND_DIR .. "forces.mp3",
    ["MAUI: Forces (Bonus)"]     = SOUND_DIR .. "forces-bonus.mp3",
    ["MAUI: Forces (Bonus 2)"]   = SOUND_DIR .. "forces-bonus2.mp3",
    ["MAUI: Forces (Special)"]   = SOUND_DIR .. "forces-special.mp3",

    -- Heroism / Bloodlust cues.
    ["MAUI: Heroism"]            = SOUND_DIR .. "heroism.mp3",
    ["MAUI: Heroism (Upgrade)"]  = SOUND_DIR .. "heroism-upgrade.mp3",

    -- Extra combo takes (selectable for any cue).
    ["MAUI: Combo 1"]            = SOUND_DIR .. "combo-1.mp3",
    ["MAUI: Combo 2"]            = SOUND_DIR .. "combo-2.mp3",
    ["MAUI: Combo 3"]            = SOUND_DIR .. "combo-3.mp3",

    -- Run-start jingle (not wired to a cue; selectable for any trigger).
    ["MAUI: Game Start"]         = SOUND_DIR .. "game-start.mp3",
}
Data.BUNDLED = BUNDLED

-- Built-in fallback sounds (stable SOUNDKIT entries).
local BUILTIN = {
    ["Raid Warning"] = SOUNDKIT and SOUNDKIT.RAID_WARNING,
    ["Ready Check"]  = SOUNDKIT and SOUNDKIT.READY_CHECK,
    ["Alarm"]        = SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3,
}
Data.BUILTIN = BUILTIN

-- Register the bundled sounds with LibSharedMedia so other addons see them too.
do
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for name, path in pairs(BUNDLED) do
            LSM:Register("sound", name, path)
        end
    end
end

-- Build the selectable sound list { value = displayText }.
function Data.GetSoundList()
    local list = { None = NONE or "None" }
    for name in pairs(BUNDLED) do list[name] = name end
    for name in pairs(BUILTIN) do list[name] = name end

    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for name in pairs(LSM:HashTable("sound")) do list[name] = name end
    end
    return list
end

-- Play the sound selected by name. "None" = silent.
function Data.Play(name)
    if not name or name == "None" then return end

    -- Our bundled sounds (also covers them if not via LSM).
    if BUNDLED[name] then
        PlaySoundFile(BUNDLED[name], "Master")
        return
    end

    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local file = LSM:Fetch("sound", name, true)
        if file then
            PlaySoundFile(file, "Master")
            return
        end
    end

    local kit = BUILTIN[name]
    if kit then
        PlaySound(kit, "Master")
    end
end
