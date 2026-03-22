--[[
ViPiN Status - CBI Model
Provides status page for ViPiN firmware
]]--

require("luci.model.uci")

m = Map("system", translate("System"), translate("System configuration"))

s = m:section(NamedSection, "system", "system", translate("ViPiN Firmware"))

local o
o = s:option(DummyValue, "_version", translate("Version"))
o.value = "v1.0"

o = s:option(DummyValue, "_model", translate("Model"))
o.value = luci.model.uci:get("system", "@system[0]", "hostname") or "Unknown"

return m
