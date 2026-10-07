-- BlinkiiOptions/Core.lua
-- Version guard, app registry and the lib's own strings. Embedded copies of the
-- lib share one global table; the newest MINOR wins, older copies stop here and
-- every later file of theirs returns at its first line.

local MAJOR, MINOR = "BlinkiiOptions-1", 2

local lib = _G.BlinkiiOptions
if lib and lib.MINOR and lib.MINOR >= MINOR then
    lib.__skip = true
    return
end

lib = lib or {}
lib.__skip = false
lib.MAJOR, lib.MINOR = MAJOR, MINOR
_G.BlinkiiOptions = lib

-- Apps outlive an upgrade: a newer copy takes the table over with them inside.
lib.apps = lib.apps or {}
lib.appOrder = lib.appOrder or {}

-- Strings ------------------------------------------------------------------

local STRINGS = {
    enUS = {},
    deDE = {
        ["Reset window size and position"] = "Fenstergröße und -position zurücksetzen",
        ["Discard"] = "Verwerfen",
        ["Put back the value every setting had before this session."] =
            "Setzt jede Einstellung auf den Wert zurück, den sie vor dieser Sitzung hatte.",
        ["%d changes this session"] = "%d Änderungen in dieser Sitzung",
        ["Search"] = "Suchen",
        ["Off"] = "Aus",
        ["Settings"] = "Einstellungen",
    },
    zhCN = {
        ["Reset window size and position"] = "重置窗口大小和位置",
        ["Discard"] = "放弃",
        ["Put back the value every setting had before this session."] = "将每项设置恢复为本次会话开始前的值。",
        ["%d changes this session"] = "本次会话修改了 %d 项",
        ["Search"] = "搜索",
        ["Off"] = "关闭",
        ["Settings"] = "设置",
    },
    zhTW = {
        ["Reset window size and position"] = "重設視窗大小與位置",
        ["Discard"] = "放棄",
        ["Put back the value every setting had before this session."] = "將每項設定回復為本次對話開始前的值。",
        ["%d changes this session"] = "本次對話修改了 %d 項",
        ["Search"] = "搜尋",
        ["Off"] = "關閉",
        ["Settings"] = "設定",
    },
}

-- A missing key is its own English text, so a new string never shows as nil.
lib.L = setmetatable(STRINGS[GetLocale()] or {}, {
    __index = function(_, key) return key end,
})

-- Apps ---------------------------------------------------------------------

local App = {}
App.__index = App
lib.App = App

-- Reads one config field: a function is called with the arguments, anything
-- else is returned as it is.
function App:Get(key, ...)
    local value = self.config[key]
    if type(value) == "function" then return value(...) end
    return value
end

-- The table the window keeps its geometry and folded sections in. Without a
-- storage callback it lives in memory only and is lost on reload.
function App:Store()
    local store = self:Get("storage")
    if type(store) ~= "table" then
        self.memoryStore = self.memoryStore or {}
        store = self.memoryStore
    end
    return store
end

function App:PanelStore(id)
    local store = self:Get("panelStorage", id)
    if type(store) == "table" then return store end
    local root = self:Store()
    root.panels = root.panels or {}
    root.panels[id] = root.panels[id] or {}
    return root.panels[id]
end

function App:Warn(message)
    if self.config.warn then
        self.config.warn(message)
    else
        print(message)
    end
end

function App:Open(pathKey) return self.window:Open(pathKey) end
function App:Close() return self.window:Close() end
function App:Toggle() return self.window:Toggle() end
function App:IsShown() return self.window:IsShown() end
function App:ResetGeometry() return self.window:ResetGeometry() end

-- The replacement for an options registry callback: options that show or hide
-- others call this so the open page is laid out again.
function App:NotifyChange()
    if self.window:IsShown() then self.window:Redraw() end
end

function App:NewPanel(id, config)
    return lib.Panel.New(self, id, config)
end

-- config fields, all optional except options:
--   options()            the option tree (AceConfig-shaped tables, see README)
--   title, logo, version, frameName, defaultPath ({ key, childKey })
--   resolvePath(key)     a deep link key to { key, childKey }
--   sections(window)     sidebar sections, see README
--   storage(), panelStorage(id), profile(), warn(message)
--   accent(), windowAlpha(), font(), slug(), progressColor(ahead)
--   mediaPath            folder of this lib's Assets, with a trailing backslash
function lib:NewApp(name, config)
    assert(type(name) == "string", "BlinkiiOptions:NewApp(name, config): name must be a string")
    assert(type(config) == "table", "BlinkiiOptions:NewApp(name, config): config must be a table")
    assert(not self.apps[name], "BlinkiiOptions: app already registered: " .. name)

    local app = setmetatable({ name = name, config = config }, App)
    self.apps[name] = app
    self.appOrder[#self.appOrder + 1] = app
    -- Every copy ships the same Assets, so the first known folder serves all apps.
    if config.mediaPath and not self.mediaPath then
        self.mediaPath = config.mediaPath
        self.OT:SetMediaPath(config.mediaPath)
    end
    assert(self.mediaPath, "BlinkiiOptions: the first app must pass config.mediaPath")
    app.window = self.Window.New(app)
    return app
end

function lib:GetApp(name)
    return self.apps[name]
end
