-- Modules/Sound/Data.lua
-- Sound selection list and playback: bundled assets, WoW sound kits and
-- LibSharedMedia entries. "None" plays nothing.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Sound = Addon:GetModule("Sound")

local Data = {}
Sound.Data = Data

-- Royalty-free SFX from Pixabay; authors are listed on the About page. The cue
-- defaults in Core/DB.lua point at the unsuffixed names.
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

    -- Run-start jingle, not wired to a cue.
    ["MAUI: Game Start"]         = SOUND_DIR .. "game-start.mp3",
}
Data.BUNDLED = BUNDLED

local BUILTIN = {
    ["Raid Warning"] = SOUNDKIT and SOUNDKIT.RAID_WARNING,
    ["Ready Check"]  = SOUNDKIT and SOUNDKIT.READY_CHECK,
    ["Alarm"]        = SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3,
}
Data.BUILTIN = BUILTIN

do
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for name, path in pairs(BUNDLED) do
            LSM:Register("sound", name, path)
        end
    end
end

-- { value = displayText } for the trigger dropdowns.
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

function Data.Play(name)
    if not name or name == "None" then return end

    -- Checked first, so the bundled cues work without LibSharedMedia.
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
