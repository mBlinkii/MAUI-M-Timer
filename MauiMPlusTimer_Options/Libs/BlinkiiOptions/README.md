# BlinkiiOptions

Settings windows for World of Warcraft addons by Blinkii. Embedded in each addon that uses it, no
dependencies: no Ace3, no LibStub, no CallbackHandler. LibSharedMedia is used only if it is installed
(to pick a font face).

Clients: Retail and the current Classic clients. Client differences live in `Compat.lua`.

## Embedding

1. Copy this folder to `<YourAddon>/Libs/BlinkiiOptions/`.
2. Load it before your own files: `<Include file="Libs\BlinkiiOptions\BlinkiiOptions.xml"/>`.
3. Register an app (below).

Several addons may embed different copies. The global `BlinkiiOptions` is shared; the copy with the highest
`MINOR` wins, older copies stop at their first line. Bump `MINOR` in `Core.lua` with every change.

## App

```lua
local app = BlinkiiOptions:NewApp("MyAddon", {
	-- required
	options = function() return myOptionTree end,            -- see "Option tree"
	mediaPath = "Interface\\AddOns\\MyAddon\\Libs\\BlinkiiOptions\\Assets\\", -- first app only

	-- window
	title = "My Addon", logo = "Interface\\AddOns\\MyAddon\\icon", version = "1.0",
	frameName = "MyAddonOptions",                           -- global frame name, Escape closes it
	defaultPath = { "general" },                            -- page shown on first open
	resolvePath = function(key) return { "modules", key } end, -- deep link keys for app:Open(key)
	sections = function(window) return sections end,        -- sidebar, see "Sidebar"

	-- storage (tables you persist, e.g. in SavedVariables)
	storage = function() return db.global.optionsWindow end,  -- geometry, folded sections
	panelStorage = function(id) return db.global.panels[id] end,
	profile = function() return currentProfileName end,       -- the change journal resets on a switch

	-- look
	accent = function() return r, g, b end,   -- nothing returned = the player's class colour
	windowAlpha = function() return 0.9 end,  -- 0.3 .. 1
	font = function() return "Expressway" end, -- LibSharedMedia font name
	slug = function() return true end,        -- Slug font rendering where the client has it
	progressColor = function(ahead) return { r, g, b } end, -- run bars in panels

	warn = function(message) end,             -- input validation messages
})
```

Every field may be a value or a function returning it.

| Method | |
|---|---|
| `app:Open(pathKey?)` / `app:Close()` / `app:Toggle()` / `app:IsShown()` | |
| `app:ResetGeometry()` | |
| `app:NotifyChange()` | call after a change that shows or hides options; the open page is laid out again |
| `app:NewPanel(id, config)` | a second window with its own list, see `Panel.lua` |
| `app.window` | the window object (`Window.lua`) |

`BlinkiiOptions.OT` holds the design tokens and `OT:FontChanged()`, `OT:AlphaChanged()`, `OT:AccentChanged()`
to call after the matching setting changed.

When windows of two apps are open at the same time, the one shown last decides accent, alpha and face.

## Option tree

Plain Lua tables in the shape of AceConfig option tables. No Ace code is involved; any table of this shape works.

| Field | Types / meaning |
|---|---|
| `type` | `group`, `toggle`, `range`, `select`, `color`, `input`, `execute`, `description`, `header`, `run` |
| `name`, `desc` | string or function(info) |
| `order` | number; nil = 100, negative sorts last |
| `args` | children of a group |
| `inline` | group drawn as a card on its parent page instead of a sidebar entry |
| `width` | flow layout units: number, `"half"`, `"double"`, `"full"` |
| `controlWidth` | `"xs"`, `"sm"`, `"md"`, `"lg"` for the widget in a labelled row, and the minimum width of an `execute` button (also read from `arg.controlWidth`) |
| `get`, `set` | function(info, ...) or the name of a method on `handler` |
| `handler` | object for string callbacks; inherited by the subtree |
| `hidden`, `disabled` | boolean or function(info) |
| `values`, `sorting` | select entries `{ key = label }` and optional key order |
| `min`, `max`, `step`, `isPercent` | range |
| `hasAlpha` | color |
| `multiline`, `validate`, `usage` | input |
| `func`, `confirm`, `confirmText` | execute |
| `icon` | sidebar icon (file path or file id) |
| `noJournal` | this option is not listed in "changes this session" |
| `arg` | passed through as `info.arg`; on a `description`, `{ preview = function(width) return frame, height end }` shows a frame the app draws itself (reused, re-parented on every redraw) |

`info` passed to callbacks: the path as array (`info[1]` .. `info[n]`), `info.options`, `info.appName`,
`info.uiName`, `info.uiType = "dialog"`, `info.handler`, `info.option`, `info.arg`, `info.type`.

An option with a `desc` is drawn as a labelled row (heading and explanation left, widget right); options
without one share the flow layout.

## Sidebar

Without `sections`, the sidebar is one section with every top-level page. A `sections(window)` callback
returns:

```lua
{
	{ title = "Display", entries = entries },                       -- top-level pages
	{ title = "Modules", entries = children, parentKey = "modules", count = "7 / 9" },
}
```

`entries` come from `BlinkiiOptions.Tree.SortedArgs(group, BlinkiiOptions.Tree.IsPage, context)`, with
`window:RootContext()` and `Tree.ChildContext(context, key, node)` for nested groups. An entry may carry
`dot = { on = true, color = { r, g, b } }`: a coloured dot instead of the icon, hollow and marked "Off"
when `on` is false.
