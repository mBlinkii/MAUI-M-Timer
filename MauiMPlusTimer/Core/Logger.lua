-- Core/Logger.lua
-- Four log levels; Debug is gated centrally on profile.debug.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local PREFIX = "|cff33ff99MAUI M+|r "

-- Formats only with extra arguments, so a literal "%" prints verbatim.
local function build(msg, ...)
    if select("#", ...) > 0 then
        return tostring(msg):format(...)
    end
    return tostring(msg)
end

local function emit(color, label, msg, ...)
    print(PREFIX .. "|cff" .. color .. "[" .. label .. "]|r " .. build(msg, ...))
end

function Addon:Debug(msg, ...)
    if self.db and self.db.profile and self.db.profile.debug then
        emit("808080", "DEBUG", msg, ...)
    end
end

function Addon:Info(msg, ...)
    print(PREFIX .. build(msg, ...))
end

function Addon:Warning(msg, ...)
    emit("ffcc00", "WARN", msg, ...)
end

function Addon:Error(msg, ...)
    emit("ff4040", "ERROR", msg, ...)
end
