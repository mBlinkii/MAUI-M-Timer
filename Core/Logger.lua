-- Core/Logger.lua
-- Central logging with four levels. Debug output is globally switchable via
-- the profile's `debug` flag, so modules never gate their own debug prints.

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local PREFIX = "|cff33ff99MAUI M+|r "

-- Apply string.format only when extra arguments were supplied, so plain
-- messages containing a literal "%" are printed verbatim.
local function build(msg, ...)
    if select("#", ...) > 0 then
        return tostring(msg):format(...)
    end
    return tostring(msg)
end

local function emit(color, label, msg, ...)
    print(PREFIX .. "|cff" .. color .. "[" .. label .. "]|r " .. build(msg, ...))
end

-- Debug: only shown when profile.debug is enabled.
function Addon:Debug(msg, ...)
    if self.db and self.db.profile and self.db.profile.debug then
        emit("808080", "DEBUG", msg, ...)
    end
end

-- Info: general user-facing status output.
function Addon:Info(msg, ...)
    print(PREFIX .. build(msg, ...))
end

-- Warning: recoverable problem the user should be aware of.
function Addon:Warning(msg, ...)
    emit("ffcc00", "WARN", msg, ...)
end

-- Error: something went wrong that needs attention.
function Addon:Error(msg, ...)
    emit("ff4040", "ERROR", msg, ...)
end
