local sys = require "luci.sys"
local m, s, o

m = Map("microsocks", translate("microsocks"),
	translate("SOCKS5 proxy settings."))

s = m:section(TypedSection, "microsocks", translate("Server"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("Enabled"))
o.rmempty = false

o = s:option(Value, "listenip", translate("Listen IP"))
o.datatype = "ipaddr"
o.placeholder = "::"

o = s:option(Value, "port", translate("Listen port"))
o.datatype = "port"
o.placeholder = "1080"

o = s:option(Value, "bindaddr", translate("Outgoing bind address"))
o.optional = true

o = s:option(Value, "user", translate("Username"))
o.optional = true

o = s:option(Value, "password", translate("Password"))
o.password = true
o.optional = true

o = s:option(Flag, "auth_once", translate("Authenticate once"))
o.rmempty = false

o = s:option(Flag, "internet_access", translate("Allow WAN access"))
o.rmempty = false

-- Handle init.d enable/start/restart on apply
m.on_after_commit = function(self)
	local enabled = self:get("config", "enabled")
	if enabled == "1" then
		sys.call("/etc/init.d/microsocks enable >/dev/null 2>&1")
		sys.call("/etc/init.d/microsocks restart >/dev/null 2>&1")
	else
		sys.call("/etc/init.d/microsocks stop >/dev/null 2>&1")
		sys.call("/etc/init.d/microsocks disable >/dev/null 2>&1")
	end
end

return m
