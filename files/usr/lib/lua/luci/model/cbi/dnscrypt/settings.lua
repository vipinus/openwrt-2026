require("luci.sys")

local m = Map("dnscrypt", translate("DNSCrypt Proxy"), translate("Encrypted DNS proxy supporting DNSCrypt and DNS-over-HTTPS protocols."))

local s = m:section(TypedSection, "dnscrypt", "")
s.anonymous = true
s.addremove = false

local o = s:option(Flag, "enabled", translate("Enabled"))
o.default = "1"
o.rmempty = false

o = s:option(Value, "listen_addr", translate("Listen Address"))
o.default = "127.0.0.1"
o.datatype = "ipaddr"

o = s:option(Value, "listen_port", translate("Listen Port"))
o.default = "5353"
o.datatype = "port"

o = s:option(Flag, "ipv4_servers", translate("IPv4 Servers"))
o.default = "1"

o = s:option(Flag, "ipv6_servers", translate("IPv6 Servers"))
o.default = "0"

o = s:option(ListValue, "log_level", translate("Log Level"))
o:value("0", translate("Debug"))
o:value("1", translate("Info"))
o:value("2", translate("Warning"))
o:value("3", translate("Error"))
o.default = "2"

local s2 = m:section(TypedSection, "dnscrypt", translate("Actions"))
s2.anonymous = true

o = s2:option(Button, "_update", translate("Update Server List"))
o.inputtitle = translate("Update Now")
o.inputstyle = "apply"

function o.write(self, section)
    luci.sys.call("/etc/init.d/dnscrypt-proxy update_servers 2>/dev/null")
    luci.http.redirect(luci.dispatcher.build_url("admin/network/dnscrypt"))
end

o = s2:option(Button, "_restart", translate("Restart Service"))
o.inputtitle = translate("Restart")
o.inputstyle = "reload"

function o.write(self, section)
    luci.sys.call("/etc/init.d/dnscrypt-proxy restart 2>/dev/null")
    luci.http.redirect(luci.dispatcher.build_url("admin/network/dnscrypt"))
end

return m
