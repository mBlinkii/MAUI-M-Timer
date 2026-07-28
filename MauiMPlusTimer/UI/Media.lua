-- UI/Media.lua
-- Registers the bundled statusbar textures with LibSharedMedia.

-- Uncompressed TGA, 256x32.
local TEXTURE_DIR = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Statusbars\\"

-- Display name -> path; the name is what gets stored in the profile.
local STATUSBARS = {
    ["MAUI: Bar 1"] = TEXTURE_DIR .. "bar1.tga",
    ["MAUI: Bar 2"] = TEXTURE_DIR .. "bar2.tga",
    ["MAUI: Bar 3"] = TEXTURE_DIR .. "bar3.tga",
    ["MAUI: Bar 4"] = TEXTURE_DIR .. "bar4.tga",
}

-- Optional; without it the dropdowns only offer the WoW default.
local LSM = LibStub("LibSharedMedia-3.0", true)
if LSM then
    for name, path in pairs(STATUSBARS) do
        LSM:Register("statusbar", name, path)
    end
    -- LibSharedMedia's border set has no plain solid option, but the presets
    -- need one for thin frames.
    LSM:Register("border", "Solid", "Interface\\Buttons\\WHITE8X8")
end

