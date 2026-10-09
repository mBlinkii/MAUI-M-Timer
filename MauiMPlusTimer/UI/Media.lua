-- UI/Media.lua
-- Registers the bundled statusbar textures and fonts with LibSharedMedia.

-- Uncompressed TGA, 256x32.
local TEXTURE_DIR = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Statusbars\\"

-- Display name -> path; the name is what gets stored in the profile.
local STATUSBARS = {
    ["MAUI: Bar 1"] = TEXTURE_DIR .. "bar1.tga",
    ["MAUI: Bar 2"] = TEXTURE_DIR .. "bar2.tga",
    ["MAUI: Bar 3"] = TEXTURE_DIR .. "bar3.tga",
    ["MAUI: Bar 4"] = TEXTURE_DIR .. "bar4.tga",
}

-- Bundled under the SIL Open Font License 1.1; see OFL.txt next to each font.
local FONT_DIR = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Fonts\\"
local FONTS = {
    ["MAUI: Barlow Condensed"]          = FONT_DIR .. "BarlowCondensed\\BarlowCondensed-Regular.ttf",
    ["MAUI: Barlow Condensed SemiBold"] = FONT_DIR .. "BarlowCondensed\\BarlowCondensed-SemiBold.ttf",
    ["MAUI: Barlow Condensed Bold"]     = FONT_DIR .. "BarlowCondensed\\BarlowCondensed-Bold.ttf",
    ["MAUI: Rajdhani Medium"]           = FONT_DIR .. "Rajdhani\\Rajdhani-Medium.ttf",
    ["MAUI: Rajdhani SemiBold"]         = FONT_DIR .. "Rajdhani\\Rajdhani-SemiBold.ttf",
    ["MAUI: Rajdhani Bold"]             = FONT_DIR .. "Rajdhani\\Rajdhani-Bold.ttf",
}

-- Optional; without it the dropdowns only offer the WoW default.
local LSM = LibStub("LibSharedMedia-3.0", true)
if LSM then
    for name, path in pairs(STATUSBARS) do
        LSM:Register("statusbar", name, path)
    end
    -- Latin only; Russian and Asian clients keep their own faces.
    for name, path in pairs(FONTS) do
        LSM:Register("font", name, path, LSM.LOCALE_BIT_western)
    end
    -- LibSharedMedia's border set has no plain solid option, but the presets
    -- need one for thin frames.
    LSM:Register("border", "Solid", "Interface\\Buttons\\WHITE8X8")
end

