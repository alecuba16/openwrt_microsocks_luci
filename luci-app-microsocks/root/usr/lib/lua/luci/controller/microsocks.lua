module("luci.controller.microsocks", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/microsocks") then
		return
	end

	local page

	page = entry({"admin", "services", "microsocks"}, alias("admin", "services", "microsocks", "settings"), _("microsocks"), 95)
	page.dependent = true

	page = entry({"admin", "services", "microsocks", "settings"}, cbi("microsocks"), _("Settings"), 1)
	page.leaf = true
end
