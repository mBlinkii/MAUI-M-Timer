-- MauiMPlusTimer_Options/Bootstrap.lua
-- Every file here reads and writes the main addon's namespace, as if it were
-- part of it: this addon's own table forwards both ways.

local _, ns = ...
local main = LibStub("AceAddon-3.0"):GetAddon("MauiMPlusTimer").ns

setmetatable(ns, { __index = main, __newindex = main })
