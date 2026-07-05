-- UI/Media.lua
-- Registers the addon's bundled statusbar fill textures with LibSharedMedia, so
-- they show up in every per-element "Bar texture" dropdown (and become available
-- to other addons that read LibSharedMedia). Pure media registration: no data
-- logic and no UI. New bundled textures only need a line in STATUSBARS below.

-- Folder holding the bundled statusbar textures (uncompressed TGA, 256x32).
local TEXTURE_DIR = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Statusbars\\"

-- Display name -> texture path. The display name is what the user sees in the
-- dropdown; the path is what gets stored and applied via SetStatusBarTexture.
local STATUSBARS = {
    ["MAUI: Bar 1"] = TEXTURE_DIR .. "bar1.tga",
    ["MAUI: Bar 2"] = TEXTURE_DIR .. "bar2.tga",
    ["MAUI: Bar 3"] = TEXTURE_DIR .. "bar3.tga",
    ["MAUI: Bar 4"] = TEXTURE_DIR .. "bar4.tga",
}

-- LibSharedMedia is optional (silent fetch); without it the texture dropdown
-- only offers the WoW default, exactly as before.
local LSM = LibStub("LibSharedMedia-3.0", true)
if LSM then
    for name, path in pairs(STATUSBARS) do
        LSM:Register("statusbar", name, path)
    end
    -- Register a solid 1px border (WoW's WHITE8X8). LibSharedMedia's border set
    -- has no plain solid option, but the addon's presets use one for thin frames,
    -- so expose it under a stable name in the border dropdown.
    LSM:Register("border", "Solid", "Interface\\Buttons\\WHITE8X8")
end

