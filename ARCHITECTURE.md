# MAUI M+ Timer – Architektur- & Umsetzungsplan

Status: **In Umsetzung / In-Game-Test** – Core + alle Module (Timer, Gegnerkräfte,
Ziele, Tode, Zwischenzeiten, Checkpoints, Cooldowns, Sound, Dungeon, Automatik)
sind implementiert, inklusive vollständigem GUI-Ausbau (Options-Seiten neu
gruppiert, eigene About-Seite) und Profil-Import/Export. Boss-Namen werden sauber
über das Encounter Journal aufgelöst; Bestzeiten sind zentral an das
Zwischenzeiten-Modul gekoppelt (Timer/Forces/Ziele blenden ihre Bestzeit aus, wenn
das Modul deaktiviert ist). Offen: weitere Themes, optionales Affix-Mini-Modul und
der laufende In-Game-Test auf der Midnight-Beta (siehe Abschnitt 13). Ziel laut
Projektregeln: strikt modulare, langlebige Codebasis für WoW Retail
(Midnight, 12.0.x), aufgebaut auf **Ace3**.

> Schnelleinstieg für Entwickler: siehe **Abschnitt 14 – Onboarding**.

---

## 1. Eckdaten

| Punkt | Festlegung |
|---|---|
| Anzeigename (.toc Title) | `MAUI M+ Timer` |
| Addon-/Ordnername | `MauiMPlusTimer` (= AddOns-Verzeichnis + .toc-Basis) |
| Repo-Root | `mplustimer` |
| Framework | **Ace3** (AceAddon/Event/DB/Config/GUI/Console/Locale/Timer) |
| Zielversion | Retail – Midnight (12.0.x) |
| Interface-Nr. | `120005` (live) bzw. `120007` ab 12.0.7; via `/dump select(4, GetBuildInfo())` final |
| Namespace | `local ADDON_NAME, ns = ...`; Addon-Objekt via `AceAddon:NewAddon(...)` – **keine** globalen Variablen |
| Globaler Zugriff | nur SavedVariables `MauiMPlusTimerDB` |
| Message-Präfix | `MMT_` (interner AceEvent-Message-Bus) |
| Slash-Command | `/mauimpt` (Default); Subcommands öffnen nur die GUI-Seite (z.B. `/mauimpt checkpoints`) |

MVP-Scope: **Timer + Schwellen**, **Enemy Forces (aggregat)**, **Death- &
Boss-Tracker**, **Splits/Best-Time- + Routen-Vergleich**, **Checkpoints
(Soll-% je Boss-Abschnitt UND je Zeitpunkt)**, **Cooldowns (Brez + Lust)**,
**Sound (optional)**, **Profilsystem mit Import/Export**, voll konfigurierbare GUI.

---

## 1a. Midnight-Konstriktionen (Secret Values / Combat Disarmament)

| Änderung | Folge für uns |
|---|---|
| `COMBAT_LOG_EVENT_UNFILTERED` **entfernt** | Keine CLEU-Auswertung. Heldentum-/Rez-/Death-Erkennung über Unit-Events, `UNIT_AURA` und Polling. |
| **Secret Values** (HP, Power, teils Auren) | Werte nur anzeigbar, nicht rechenbar. Vor Verarbeitung `issecretvalue()` prüfen. |
| **NPC-/Unit-IDs restricted** | **Per-Mob-Forces-Gewichte unmöglich.** Pull-Vorschau gestrichen — nur Gesamt-Forces. |
| Keine Addon-Addon-Comm / Rotations-/Interrupt-Logik in Instanzen | Betrifft uns nicht. |

**Erlaubt bleibt** (UI-/Objective-Daten, die Blizzard selbst anzeigt): M+-Timer,
Zeitlimit & Schwellen, **Gesamt**-Enemy-Forces, Boss-/Criteria-Status, Death-Count,
Battle-Rez-Ladungen, eigene Auren.

> **Früh in-game prüfen (12.0.x):** (a) `C_ScenarioInfo.GetCriteriaInfo`
> Forces-Quantity non-secret? (b) `UNIT_AURA`/`PLAYER_UNGHOST`-Pfade zuverlässig?
> Plan B in Abschnitt 13.

---

## 2. Dateistruktur

```
MauiMPlusTimer/
├── Libs/                       # Ace3 + Helfer (eingebettet)
│   ├── LibStub/                #   (Teil des Ace3-Embeds)
│   ├── CallbackHandler-1.0/
│   ├── AceAddon-3.0/           # Modulsystem + Lifecycle
│   ├── AceEvent-3.0/           # Events + Message-Bus
│   ├── AceDB-3.0/              # SavedVariables + Profile
│   ├── AceDBOptions-3.0/       # Standard-Profil-Optionsseite
│   ├── AceConsole-3.0/         # Slash-Commands
│   ├── AceConfig-3.0/          # Options-Tabellen → GUI (Registry/Dialog/Cmd)
│   ├── AceGUI-3.0/             # Custom-Widgets (Editoren)
│   ├── AceLocale-3.0/          # Lokalisierung
│   ├── AceTimer-3.0/           # Polling-Timer
│   ├── LibSharedMedia-3.0/     # Sounds/Fonts/Statusbars
│   ├── LibSerialize/           # Profil-Export
│   ├── LibDeflate/             # Kompression + Base64
│   ├── LibDataBroker-1.1/      # Minimap-/Broker-Button (optional)
│   └── LibDBIcon-1.0/
│
├── Core/
│   ├── Init.lua          # AceAddon-Objekt, Mixins, Modul-Registrierung, Lifecycle
│   ├── DB.lua            # AceDB-Setup: Defaults, Scopes, Versionsmigration
│   ├── Profiles.lua      # Import/Export (LibSerialize+LibDeflate) über AceDB-Profile
│   ├── Logger.lua        # Debug/Info/Warning/Error, zentral abschaltbar
│   ├── RunState.lua      # Live-Laufzustand, /rl-fest, Single Source of Truth
│   ├── Demo.lua          # Demo-Modus: synthetische Werte in alle Module
│   ├── Config.lua        # AceConfig-Options-Baum + Slash→Seiten-Deeplinks
│   └── Utilities.lua     # Zeit-/Farb-/Tabellen-Helfer (zustandslos)
│
├── Modules/
│   ├── ModuleTemplate.lua          # Vorlage (AceAddon-Modul mit Standardmethoden)
│   ├── Timer/        { Module.lua, UI.lua, Data.lua, Options.lua }
│   ├── EnemyForces/  { Module.lua, UI.lua, Data.lua, Options.lua }
│   ├── Objectives/   { Module.lua, UI.lua, Data.lua, Options.lua }
│   ├── Deaths/       { Module.lua, UI.lua, Options.lua }
│   ├── Splits/       { Module.lua, UI.lua, Manager.lua, Data.lua, Options.lua }
│   ├── Checkpoints/  { Module.lua, UI.lua, Editor.lua, Data.lua, Options.lua }
│   ├── Cooldowns/    { Module.lua, UI.lua, Options.lua }
│   └── Sound/        { Module.lua, Data.lua, Options.lua }
│
├── UI/
│   ├── MainWindow.lua    # Bewegbarer Anzeige-Container (HUD), Anker + Ausrichtung
│   ├── Widgets.lua       # Frame-/Bar-/Text-Factory + Frame-Pools (sparsam!)
│   └── Themes.lua        # Theme-Presets (Farben, Fonts, Backdrops)
│
├── Localization/
│   ├── enUS.lua          # AceLocale Default (true)
│   └── deDE.lua
│
├── Assets/               # eigene Sound-Dateien (.ogg) etc.
└── MauiMPlusTimer.toc
```

Jedes Modul hat eine eigene `Options.lua`, die seine **AceConfig-Optionsgruppe**
liefert. Komplexe Editoren (`Checkpoints/Editor.lua`, `Splits/Manager.lua`) sind
AceGUI-Seiten innerhalb derselben GUI. Der **HUD** (`UI/MainWindow.lua`) ist eine
eigene Anzeige und nicht Teil der Options-GUI.

---

## 3. Core-Verantwortung (keine Modul-Logik!)

- **Init.lua** – erzeugt das Addon via `AceAddon:NewAddon("MauiMPlusTimer",
  "AceEvent-3.0","AceConsole-3.0","AceTimer-3.0")`, registriert Module
  (`:NewModule`) und steuert den Lifecycle (`OnInitialize`→`OnEnable`).
- **DB.lua** – `AceDB:New("MauiMPlusTimerDB", defaults, true)`; Scopes
  `profile`/`char`/`global`; Defaults zentral, `db.global.version` für Migrationen.
- **Profiles.lua** – nutzt AceDB-Profile (Select/Copy/Reset/Delete via
  AceDBOptions) und ergänzt **Import/Export** als komprimierten Base64-String
  (LibSerialize+LibDeflate) inkl. Validierung gegen Defaults.
- **Logger.lua** – `Addon:Debug/Info/Warning/Error`; ein Flag schaltet Debug global.
- **RunState.lua** – hält den aktiven Lauf, schreibt `/rl`-fest nach `db.char`,
  stellt nach Login wieder her (siehe Abschnitt 7).
- **Demo.lua** – schaltet den Demo-Modus für alle Module an/aus und liefert
  synthetische Anzeigewerte.
- **Config.lua** – baut den AceConfig-Options-Baum (Root + je Modul eine Gruppe),
  registriert ihn (`AceConfigRegistry`), bindet ihn ins Blizzard-Einstellungsmenü
  ein und mappt Slash-Subcommands auf `AceConfigDialog:Open(app, "<Seite>")`.
- **Utilities.lua** – reine Funktionen (Zeitformat, Farbinterpolation, deepcopy).

Der Core enthält **keine** Modul-spezifische Logik; er stellt nur Infrastruktur.

---

## 4. Kommunikation – Entkopplung (AceEvent)

Module sind nie direkt gekoppelt. Über das AceEvent-Mixin:

```
self:RegisterMessage("MMT_DEATH_COUNT_CHANGED", "OnDeathCount")
self:SendMessage("MMT_DEATH_COUNT_CHANGED", count)
self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "OnComplete")
```

Beispiel: **Deaths** kennt **Timer** nicht; es sendet nur
`MMT_DEATH_COUNT_CHANGED`, der Timer rechnet die 5s-Strafe ein.

Geplante Messages: `MMT_RUN_STARTED`, `MMT_RUN_COMPLETED`, `MMT_RUN_TIMED_OUT`,
`MMT_FORCES_UPDATED`, `MMT_DEATH_COUNT_CHANGED`, `MMT_PLAYER_RESURRECTED`,
`MMT_HEROISM_DETECTED`, `MMT_OBJECTIVE_COMPLETED`, `MMT_PROFILE_CHANGED`,
`MMT_RUN_RESTORED`, `MMT_DEMO_CHANGED`.

---

## 5. Modul-Standardvertrag (AceAddon-Modul)

Jedes Modul wird über `Addon:NewModule(name, "AceEvent-3.0", ...)` erzeugt und
bekommt die Projekt-Standardmethoden (auf AceAddon-Lifecycle abgebildet):

```
Module:OnInitialize()      -- = Initialize(): Frames bauen, Options registrieren
Module:OnEnable()          -- = Enable():  Events/Messages + UI an
Module:OnDisable()         -- = Disable(): alles lösen, UI aus
Module:RegisterEvents() / :UnregisterEvents()
Module:LoadSettings()      -- aus db.profile (auch bei MMT_PROFILE_CHANGED)
Module:SaveSettings()
Module:SetDemo(state)      -- Demo-Werte ein/aus
Module:GetOptions()        -- liefert die AceConfig-Optionsgruppe (Options.lua)
```

AceAddon liefert `:Enable()/:Disable()` + persistenten Enable-State pro Modul →
unabhängig schaltbar, wie gefordert.

---

## 6. WoW-API-Oberfläche je Modul (Midnight-konform)

| Modul | Kern-API |
|---|---|
| Timer | `C_ChallengeMode.GetMapUIInfo` (Zeitlimit), `GetActiveKeystoneInfo`, Scenario-Timer, `GetCompletionInfo`; reine Anzeige, getrieben von den `MMT_RUN_*`-Messages (`MMT_RUN_TIMED_OUT` sendet Core/RunController, damit das Signal auch bei deaktiviertem Timer-Modul feuert) |
| EnemyForces | `C_ScenarioInfo.GetStepInfo`+`GetCriteriaInfo` (`isWeightedProgress`) → **nur Gesamtwert**; `SCENARIO_CRITERIA_UPDATE` |
| Objectives | `C_ScenarioInfo.GetStepInfo`+`GetCriteriaInfo` (Boss-Kriterien) |
| Deaths | `C_ChallengeMode.GetDeathCount` per AceTimer-**Polling** + `PLAYER_DEAD`; Death-Log mit Zeitstempel; Rez via `PLAYER_UNGHOST`/`PLAYER_ALIVE` |
| Splits | eigene `db.global`, gefüttert aus Run-/Forces-/Boss-Events |
| Checkpoints | konsumiert nur `MMT_FORCES_UPDATED` + `MMT_OBJECTIVE_COMPLETED` + Laufzeit; Definitionen aus `db.global` |
| Cooldowns | Battle-Rez: `C_Spell.GetSpellCharges` (Pool-Ladungen + Recharge-Timer); Lust-Verfügbarkeit: `UNIT_AURA`(player) → Erschöpfungs-Debuff (Sated 57724, Exhaustion 57723, Temporal Displacement 80354, Fatigued 264689 …) |
| Sound | `PlaySoundFile` + LibSharedMedia; Heldentum via `UNIT_AURA`(player)+`AuraUtil.FindAuraBySpellID` der Lust-IDs (Bloodlust 2825, Heroism 32182, Time Warp 80353, Primal Rage 264667, Fury of the Aspects 390386 …) |

**Enemy Forces – ohne Pull-Vorschau:** Wegen restricted NPC-IDs nur der
**Gesamt**-Fortschritt (Prozent + Restmenge). Keine Per-Mob-Berechnung.

**Checkpoints-Modul** (Soll-Forces-% je Dungeon — zwei Typen):
1. **Boss-Abschnitte** — Soll-% vor jedem Boss; Boss-Kill schaltet weiter.
2. **Zeit-Checkpoints** — Soll-% zu Zeitpunkt, z.B. *5min→10%*, *20min→88%*; lineare
   Interpolation dazwischen (abschaltbar).
Live-Vergleich Ist gegen Soll beider Achsen → Vor-/Rückstand („+3% / −5%").
`Editor.lua` (AceGUI): pro Dungeon Checkpoints beider Typen anlegen/bearbeiten.
Nur aggregat-Forces + Boss + Laufzeit → Midnight-sicher.

**Cooldowns-Modul** (beide Anzeigen einzeln optional, default aus):
- *Battle-Rez*: Ladungen + Recharge-Timer (legal in Midnight, vgl. BattleRezTracker).
- *Lust-Verfügbarkeit*: Countdown aus Restdauer des eigenen Erschöpfungs-Debuffs.

---

## 7. Daten / SavedVariables (AceDB-Scopes)

```
MauiMPlusTimerDB =
  profiles[<profileName>] = {            -- db.profile (AceDB verwaltet Auswahl)
    debug = false,
    modules = {
      Timer={enabled=true}, EnemyForces={enabled=true}, Objectives={enabled=true},
      Deaths={enabled=true},
      Splits={enabled=true, storeMode="best"},          -- "best" | "all"
      Checkpoints={enabled=true},
      Cooldowns={enabled=true, brez={on=false}, lust={on=false}},
      Sound={enabled=false, triggers={
        death={on=false,sound="None"}, resurrect={on=false,sound="None"},
        timeout={on=false,sound="None"}, completed={on=false,sound="None"},
        heroism={on=false,sound="None"} }},
    },
    ui = {
      point="CENTER", x=0, y=0, scale=1, theme="default",
      align="center",        -- "left" | "center" | "right"
      growth="down",         -- "up" | "down"
      locked=false, demo=false,
      elements = {           -- pro Element voll überschreibbar:
        -- [key]={ width,height, font,fontSize,fontFlags,
        --   textColor={r,g,b,a}, barColor={...}, bgColor={...},
        --   borderColor={...}, texture, shown=true, order=1 },
      },
    },
  }

  char[<Char-Realm>] = {                 -- db.char: laufender Dungeon, /rl-fest
    activeRun = {                        -- nil wenn kein Key läuft
      mapID, keyLevel, affixes={...}, startedAt=<wallclock>,
      forces={current,total}, bosses={ [i]={name,done,t} },
      deaths={ { t=<sek seit Start>, wall=<time()>, name="Spieler" }, ... },
    },
  }

  global = {                             -- db.global: account-weit, profilunabhängig
    version = 1,
    splits = { [mapID]={ [keyLevel]={ best={total,sections,date,deaths},
                                      history={...} } } },   -- history nur bei "all"
    routes = { [mapID]={ sections={...} } },
    checkpoints = { [mapID]={
      interpolate=true,
      bySection={ {label="vor Boss 1", bossIndex=1, targetPct=35}, ... },
      byTime   ={ {timeSec=300,targetPct=10}, {timeSec=1200,targetPct=88} },
    } },
  }
```

**Profile (AceDB):** mehrere benannte Profile, Auswahl pro Charakter; Standard-UI
zum Wechseln/Kopieren/Zurücksetzen via AceDBOptions. **Import/Export**
(`Core/Profiles.lua`): Profil → LibSerialize → LibDeflate → druckbarer Base64-String;
Import dekodiert, validiert gegen Defaults und legt neues Profil an (optional inkl.
`routes`/`checkpoints`).

**Laufzustand & Reload-Sicherheit (`Core/RunState.lua`):** Bei Key-Start wird
`db.char.activeRun` angelegt und bei **jeder** Änderung sofort fortgeschrieben
(`/rl` schreibt SavedVariables → nichts geht verloren). Beim `OnEnable`/Login prüft
RunState `C_ChallengeMode.IsChallengeModeActive()` und `mapID`/Keystone:
- **passt** → restaurieren (Death-Log inkl. Zeitstempel, Bosse, Forces),
  `MMT_RUN_RESTORED`; Timer rechnet die Zeit aus dem Scenario-Timer neu.
- **passt nicht** → `activeRun` verwerfen bzw. ins Splits-Archiv überführen.
Jeder Spielertod landet mit Zeitstempel im Death-Log und übersteht `/rl`.

**Speichermodus (Splits):** `"best"` (nur Bestzeit pro Dungeon+Stufe) oder `"all"`
(zusätzlich Verlauf). `Splits/Manager.lua` (AceGUI-Seite) zeigt/räumt gespeicherte
Zeiten (Dungeon→Stufe→Detail: Gesamtzeit, Abschnittszeiten, Tode, Datum).

---

## 8. UI

### 8.1 HUD (`UI/MainWindow.lua` + `UI/Widgets.lua` + `UI/Themes.lua`)
Der HUD ist die Live-Anzeige im Spiel (eigene Frames, nicht AceGUI). Widgets werden
mit einem `elementKey` erzeugt und ziehen ihren Style live aus
`db.profile.ui.elements[key]` → Config-Änderungen wirken sofort ohne `/rl`.
Strikte Trennung: HUD-Dateien ohne Datenlogik, Module ohne Frame-Styling.

### 8.2 Ausrichtung (links / rechts / mittig)
`align = left|center|right` steuert Text-Justify **und** die Anker-Kante, an der alle
Modul-Blöcke bündig wachsen → das Addon sitzt perfekt an der gewählten Seite.
`growth = up|down` für die Stapelrichtung.

### 8.3 Demo-Modus
`Core/Demo.lua` (`/mauimpt demo`) speist synthetische Werte in jedes Modul, friert
Live-Updates ein, blendet alles ein → Position/Größe/Ausrichtung/Style außerhalb
eines Keys einstellbar. Jedes Modul: `Module:SetDemo(state)`.

### 8.4 Konfiguration – komplett über die GUI
**Alles** ist über die zentrale Options-GUI (AceConfigDialog) bearbeitbar — kein
Konfigurieren per Chat. Aufbau: Root-Knoten `MAUI M+ Timer` mit Unterseiten pro
Modul (Timer, Enemy Forces, Objectives, Deaths, Splits, Checkpoints, Cooldowns,
Sound) plus *Anzeige/Ausrichtung*, *Demo*, *Profile*. Jede Modul-`Options.lua`
liefert ihre Optionsgruppe; komplexe Editoren (Checkpoints, Splits-Manager) sind
AceGUI-Seiten. Slash-Subcommands sind reine **Deeplinks**:
`/mauimpt checkpoints` → `AceConfigDialog:Open("MauiMPlusTimer","Checkpoints")`,
analog `/mauimpt splits`, `/mauimpt profile`, `/mauimpt` (Root).

### 8.5 Pro Element konfigurierbar
Jedes sichtbare Element (Timer-Text/-Balken, Forces-Balken, Boss-Liste, Death-
Anzeige, Split-Delta, Checkpoint-Status, Brez/Lust) ist einzeln einstellbar:
Größe/Skalierung, Schrift (LibSharedMedia, Größe, Outline), Farben (Text/Balken/
Hintergrund/Rahmen mit Alpha), Statusbar-Textur, Sichtbarkeit, Reihenfolge. Alles
in `db.profile.ui.elements[key]` → Teil von Profil-Import/-Export.

### 8.6 Frame-Budget – sparsam mit Frames umgehen
WoW hat ein begrenztes, von **allen** Addons geteiltes Frame-Budget; zu viele Frames
kosten Performance und können in Kombination mit anderen Addons an die Grenze stoßen.
Designregeln, an die wir uns halten:

- **Regionen statt Frames bevorzugen.** FontStrings, Textures und StatusBars sind
  *Regionen* auf einem Eltern-Frame und viel billiger als eigene Frames. Ein
  Modul-Block = **ein** Frame mit mehreren Regionen, nicht ein Frame pro Text.
- **Frame-Pools / Recycling.** Wiederkehrende Zeilen (Boss-Liste, Death-Log,
  Checkpoint-/Split-Tabellen) nutzen `CreateFramePool`/`CreateObjectPool`; nicht
  mehr sichtbare Einträge werden freigegeben und wiederverwendet, nicht neu erzeugt.
- **Lazy Creation.** Module bauen ihre Frames erst beim ersten `OnEnable` (bzw. im
  Demo-Modus) — nicht beim Laden. Module, die der User deaktiviert, erzeugen gar
  keine Frames.
- **Geteilte Container.** Alle Modul-Anzeigen hängen an **einem** HUD-Container
  (`MainWindow`); kein eigenes Top-Level-Frame pro Modul.
- **GUI on demand.** AceConfigDialog/AceGUI bauen die Options-Frames erst beim
  Öffnen und recyceln Widgets über ihren eigenen Pool — die Config kostet im
  Normalbetrieb keine Frames.
- **Ein Event-Frame.** AceEvent nutzt ein einziges verstecktes Frame für alle
  Module; wir legen keine zusätzlichen Event-Frames an.

`UI/Widgets.lua` kapselt das (Factory + Pools), sodass kein Modul versehentlich
Frames „von Hand" anlegt.

---

## 9. Lokalisierung (AceLocale)

`enUS.lua` ist Default (`AceLocale:NewLocale(..., true)`), `deDE.lua` überschreibt.
Kein Hardcode-String — nur `L["KEY"]`. Weitere Sprachen ohne Code-Änderung.

---

## 10. Baureihenfolge (modulweise)

| Phase | Inhalt | Ergebnis |
|---|---|---|
| 1 | .toc + Ace3-Embed + Core (Init/AceAddon, DB/AceDB, Logger, RunState, Demo, Config-Root, Utilities) + leeres MainWindow + ModuleTemplate + L-Gerüst | Lädt fehlerfrei, `/mauimpt` öffnet GUI-Root, Profil aktiv, RunState `/rl`-fest |
| 2 | **Timer** + Options.lua | Countdown + +1/+2/+3 |
| 3 | **Objectives** + **EnemyForces** (Gesamt-%) | Bosse + Forces-Balken |
| 4 | **Deaths** (Polling) + Strafen-Verdrahtung | Tode + Zeitverlust |
| 5 | **Splits** + **Manager**-Seite | Delta + Zeitenverwaltung |
| 6 | **Checkpoints** (Boss- + Zeit-Soll-%) + **Editor** | Vor-/Rückstand-Anzeige |
| 7 | **Cooldowns** (Brez + Lust) | Brez-/Lust-Anzeige |
| 8 | **Sound** (Midnight-sichere Erkennung) | Akustische Alerts |
| 9 | **GUI-Ausbau**: Ausrichtung, Demo, Element-Styling, alle Options-Seiten | Voll einstellbares UI |
| 10 | **Profile-Import/Export** | Profile teilen/laden |
| 11 | Themes, Lokalisierungs-Feinschliff | Polish |

Jede Phase ist lauffähig und testbar; zu jeder Phase liefere ich eine kurze
**In-Game-Testcheckliste** mit.

---

## 11. Sound-Trigger (alle einzeln optional, default aus)

| Trigger | Quelle (Midnight-konform) | Bus-Event |
|---|---|---|
| Spieler/Gruppe stirbt | `GetDeathCount`-Polling + `PLAYER_DEAD` | `MMT_DEATH_COUNT_CHANGED` |
| Wiederbelebung (eigener Char) | `PLAYER_UNGHOST` / `PLAYER_ALIVE` | `MMT_PLAYER_RESURRECTED` |
| **Zeit läuft mitten im Lauf ab** (Key depleted) | Core/RunController überwacht das Limit (1s-Watch), feuert **sofort** beim Überschreiten, nicht erst am Ende — unabhängig davon, ob das Timer-Modul aktiv ist | `MMT_RUN_TIMED_OUT` |
| Lauf erfolgreich | `CHALLENGE_MODE_COMPLETED` (in time) | `MMT_RUN_COMPLETED` |
| Heldentum/Lust (eigene Aura) | `UNIT_AURA`(player)+`FindAuraBySpellID` | `MMT_HEROISM_DETECTED` |

Sounds: eigene `.ogg` in `Assets/` **oder** beliebige via LibSharedMedia.

---

## 12. Entschieden

- **Framework**: Ace3 (deckt Modulsystem, Events/Messages, DB+Profile, GUI, Slash,
  Lokalisierung, Timer ab).
- **Name**: Anzeige `MAUI M+ Timer`, Ordner/Tabelle `MauiMPlusTimer`, Präfix `MMT_`.
- **Konfiguration**: **alles** über die GUI; Slash öffnet nur die jeweilige Seite.
- **Splits**: Bestzeit **und** Routen-Plan; pro Dungeon+Stufe; Modus `best`/`all`;
  Manager-Seite.
- **Checkpoints**: Soll-% je Boss-Abschnitt **und** je Zeitpunkt; eigene
  anleg-/bearbeitbar; Editor.
- **Cooldowns**: Battle-Rez (Ladungen+Timer) und Lust-Verfügbarkeit, je optional.
- **Sound**: eigene Dateien + LibSharedMedia; Rez/Heldentum nur eigener Char/Aura.
- **Profile**: AceDB + Import/Export (LibSerialize+LibDeflate).
- **Laufzustand**: persistenter `activeRun`, `/rl`-fest, Death-Log mit Zeitstempeln.
- **UI**: Ausrichtung links/rechts/mittig, Demo-Modus, jedes Element voll stylebar.
- **Frame-Budget**: bewusst sparsam — Regionen statt Frames, Frame-Pools, Lazy
  Creation, ein geteilter HUD-Container; Config-Frames nur on demand.
- **Pull-Vorschau**: gestrichen (Midnight: NPC-IDs restricted). Nur Gesamt-Forces.
- **Testchecklisten**: pro Phase.

## 13. Noch zu klären / Plan B

1. ~~**Forces-Quantity secret?**~~ **Erledigt (in-game getestet, Midnight):**
   `C_ScenarioInfo.GetCriteriaInfo` liefert die Forces-Werte **nicht** als Secret
   Value — `quantity`, `totalQuantity` und `quantityString` sind alle lesbar
   (`issecretvalue` = false beim weighted-progress-Kriterium). Die bestehende
   Forces-Logik (Parsen + Rechnen/Vergleichen) bleibt gültig; kein Plan B nötig.
2. **Affixe in 12.0.x**: Affix-Anzeige optional später ergänzen (eigenes Mini-Modul),
   sobald Scope dafür da ist.

---

## 14. Onboarding (Schnelleinstieg)

### Datenfluss

```
WoW-Events ──► Timer (Run-Erkennung) ──► RunState (persistenter Lauf, /rl-fest)
                                   │
                                   └─► Message-Bus (Addon:SendMessage)
                                          │
        ┌──────────────┬──────────────┬──┴───────────┬───────────────┐
        ▼              ▼              ▼               ▼               ▼
   EnemyForces     Objectives       Deaths         Splits        Checkpoints …
   (eigene Daten + Logik) ──► Module.UI:Update(...) ──► MainWindow (HUD-Layout)
```

Kurz: **Timer** besitzt die Run-Steuerung und schreibt nach `Core/RunState`. Alle
anderen Module sind über den Message-Bus entkoppelt (`MMT_RUN_STARTED`,
`MMT_FORCES_UPDATED`, …), lesen ihre eigenen Daten und schieben sie an ihre `UI`,
die Blöcke im gemeinsamen `MainWindow`-HUD anordnet. Einstellungen liegen in
`db.profile` und werden ausschließlich über AceConfig-Optionsseiten verändert.

### Wo liegt was?

- `Core/` – Init, DB/Defaults, Logger, RunState, Demo, Config (Options-Baum),
  Broker, Profiles (Import/Export), Utilities.
- `UI/` – `Widgets` (Frame-/Text-/Balken-Factory **+ UI-Basisklassen**), `MainWindow`
  (HUD-Container), `Themes`, `StyleOptions` (wiederverwendbare Style-/Farb-Optionen).
- `Modules/<Name>/` – `Module.lua` (Logik), `UI.lua` (Anzeige), `Options.lua`
  (Einstellungen), optional `Data.lua` und weitere.
- `Localization/` – alle Texte als `L["KEY"]` (de/en).

### Ein neues Anzeige-Modul hinzufügen

Als Vorlage eignet sich am besten ein einfaches Einzeltext-Modul wie
**`Modules/Deaths`**. Schritte:

1. **Module.lua**: `local M = Addon:NewMauiModule("MeinModul", "meinmodul")`. Damit
   kommen `OnInitialize` (Enabled-State + Options-Registrierung) und `LoadSettings`
   automatisch aus `ModuleBase`. In `OnEnable` nur die relevanten Messages/Events
   registrieren (inkl. `MMT_PROFILE_CHANGED → LoadSettings`) und `self.UI:Build()`.
   Eine `Refresh`/`SetDemo`-Funktion füllt die Anzeige.
2. **UI.lua**: Für eine einzelne Textzeile
   `local UI = Addon:NewTextBlockUI({ name = "MeinModul", element = "meinText", order = 55 })`
   – `Build`/`Restyle`/`Show`/`Hide` kommen aus der Basis, nur `UI:Update(...)`
   selbst schreiben. Für komplexere Anzeigen `Addon:NewModuleUI()` nutzen und
   `Build`/`Update`/`Restyle` selbst definieren (`Show`/`Hide` erbt man).
3. **Options.lua**: `function M:GetOptions()` liefert eine AceConfig-Gruppe. Für die
   Standardelemente gibt es Helfer: `Addon:ModuleEnableOption(self, 1)`,
   `Addon:ModuleAlignOption(self, 2)`, `Addon:ElementTextOptions(...)`,
   `Addon:ElementBarOptions(...)`, `Addon:ElementColorOption(self, key, field, name, order, default)`.
4. **Defaults**: in `Core/DB.lua` unter `profile.modules.MeinModul` ergänzen.
5. **.toc**: die neuen Dateien in der richtigen Reihenfolge eintragen
   (Module.lua vor UI.lua/Options.lua).
6. **Localization**: alle sichtbaren Texte als `L["..."]` in `enUS.lua` (Wert `true`)
   und Übersetzung in `deDE.lua`.

### Konventionen

- Keine globalen Variablen; alles über den `ns`-Namespace bzw. `Addon`.
- Alle Code-Kommentare/Doku auf Englisch; sichtbare Strings nur via `L[...]`.
- Styling läuft über Element-Keys aus der zentralen Registry `ns.E`
  (z. B. `ns.E.deathsText`) und die Resolve-Kette Theme → globale Schrift →
  `profile.ui.elements[key]`. Neue Elemente immer in `ns.E` (UI/Themes.lua)
  eintragen – ein Tippfehler ist dann ein nil-Fehler statt einer stillen Lücke.
- Debug-Ausgaben nur über `Addon:Debug(...)` (zentral abschaltbar).
