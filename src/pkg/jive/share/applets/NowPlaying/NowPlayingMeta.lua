local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 0.1, 0.1
end

function defaultSettings(self)
	return {
	}
end

function registerApplet(self)
	local ssMgr = appletManager:loadApplet("ScreenSavers")
	if ssMgr ~= nil then
		ssMgr:addScreenSaver(
			self:string("SCREENSAVER_NOWPLAYING"), 
			"NowPlaying", 
			"openScreensaver" --[[,
			self:string("SCREENSAVER_NOWPLAYING_SETTINGS"), 
			"openSettings" ]]--
		)

		jiveMain:loadSkin("NowPlaying", "skin")
	end
end

