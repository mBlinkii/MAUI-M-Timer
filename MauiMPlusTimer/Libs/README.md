# Libs

This folder holds the embedded third-party libraries that `embeds.xml` loads.
They are **not** checked into the repo; add them before running the addon.

## Required

- **Ace3** (provides: AceAddon-3.0, AceEvent-3.0, AceConsole-3.0, AceTimer-3.0,
  AceDB-3.0, AceDBOptions-3.0, AceGUI-3.0, AceConfig-3.0, AceLocale-3.0,
  plus LibStub and CallbackHandler-1.0) — https://www.curseforge.com/wow/addons/ace3
- **LibSharedMedia-3.0** — https://www.curseforge.com/wow/addons/libsharedmedia-3-0
- **LibSerialize** — https://github.com/rossnichols/LibSerialize
- **LibDeflate** — https://github.com/SafeteeWoW/LibDeflate

## How to populate

Option A — manual: download each library and extract so the folder layout matches
the paths in `embeds.xml` (e.g. `Libs/AceAddon-3.0/AceAddon-3.0.xml`).

Option B — packager: run the CurseForge/BigWigs packager against `.pkgmeta`,
which pulls every external automatically.
