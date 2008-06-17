
--[[
=head1 NAME

jive.slim.Player - Squeezebox/Transporter player.

=head1 DESCRIPTION

TODO

=head1 SYNOPSIS

Notifications:

 playerConnected:
 playerNewName:
 playerDisconnected:
 playerPower:
 playerNew (performed by SlimServer)
 playerDelete (performed by SlimServer)
 playerTrackChange
 playerModeChange
 playerPlaylistChange
 playerPlaylistSize
 playerNeedsUpgrade

=head1 FUNCTIONS

=cut
--]]


-- stuff we need
local _assert, assert, setmetatable, tonumber, tostring, pairs, type = _assert, assert, setmetatable, tonumber, tostring, pairs, type

local os             = require("os")
local math           = require("math")
local string         = require("string")
local table          = require("table")

local oo             = require("loop.base")

local SocketHttp     = require("jive.net.SocketHttp")
local RequestHttp    = require("jive.net.RequestHttp")
local RequestJsonRpc = require("jive.net.RequestJsonRpc")
local Framework      = require("jive.ui.Framework")
local Popup          = require("jive.ui.Popup")
local Icon           = require("jive.ui.Icon")
local Label          = require("jive.ui.Label")
local Textarea       = require("jive.ui.Textarea")
local Window         = require("jive.ui.Window")
local Group          = require("jive.ui.Group")

local Udap           = require("jive.net.Udap")

local debug          = require("jive.utils.debug")
local strings        = require("jive.utils.strings")
local log            = require("jive.utils.log").logger("player")

local EVENT_KEY_ALL    = jive.ui.EVENT_KEY_ALL
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME

local iconbar        = iconbar


local fmt = string.format

local MIN_KEY_INT    = 150  -- sending key rate limit in ms

-- jive.slim.Player is a base class
module(..., oo.class)


local DEVICE_IDS = {
	[4] = "squeezebox2",
	[5] = "transporter",
	[7] = "receiver",
}


-- list of players index by id. this weak table is used to enforce
-- object equality with the server name.
local playerIds = {}
setmetatable(playerIds, { __mode = 'v' })

-- list of player that are active
local playerList = {}


-- class function to iterate over all players
function iterate(class)
	return pairs(playerList)
end


-- _getSink
-- returns a sink with a closure to self
-- cmd is passed in so we know what process function to call
-- this sink receives all the data from our Comet interface
local function _getSink(self, cmd)
	return function(chunk, err)
	
		if err then
			log:warn("########### ", err)
			
		elseif chunk then
			local proc = "_process_" .. cmd[1]
			if cmd[1] == 'status' then
				log:debug('stored playlist timestamp: ', self.playlist_timestamp)
				log:debug('   new playlist timestamp: ', chunk.data.playlist_timestamp)
			end
			if self[proc] then
				self[proc](self, chunk)
			end
		end
	end
end


local function _formatShowBrieflyText(msg)
	log:debug("_formatShowBrieflyText")

	-- showBrieflyText needs to deal with both \n instructions within a string 
	-- and also adding newlines between table elements

	-- first compress the table elements into a single string with newlines
	local text = table.concat(msg, "\n")
	-- then split the new string on \n instructions within the concatenated string, and into a table
	local split = strings:split('\\n', text)
	-- then compress the new table into a string with all newlines as needed
	local text2 = table.concat(split, "\n")

	return text2
end


-- _whatsPlaying(obj)
-- returns the track_id from a playerstatus structure
local function _whatsPlaying(obj)
	local whatsPlaying = nil
	if obj.item_loop then
		if obj.item_loop[1].params then
			if obj.item_loop[1].params.track_id and not obj.remote then
				whatsPlaying = obj.item_loop[1].params.track_id
			elseif obj.item_loop[1].text and obj.remote and type(obj.current_title) == 'string' then
				whatsPlaying = obj.item_loop[1].text .. "\n" .. obj.current_title
			elseif obj.item_loop[1].text then
				whatsPlaying = obj.item_loop[1].text
			end
		end
	end
	return whatsPlaying
end


--[[

=head2 jive.slim.Player(server, jnt, playerId)

Create a Player object with playerId.

=cut
--]]
function __init(self, jnt, playerId)
	log:debug("Player:__init(", playerId, ")")

	-- Only create one player object per id. This avoids duplicates
	-- when moving between servers

	if playerIds[playerId] then
		return playerIds[playerId]
	end

	local obj = oo.rawnew(self,{
		jnt = jnt,

		id = playerId,

		uuid = false,
		slimServer = false,
		config = false,
		lastSeen = 0,

		-- player info from SC
		info = {},

		-- player state from SC
		state = {},

		isOnStage = false,

		-- current song info
		currentSong = {}
	})

	playerIds[obj.id] = obj

	return obj
end


--[[

=head2 jive.slim.Player:updatePlayerInfo(squeezeCenter, playerInfo)

Updates the player with fresh data from SS.

=cut
--]]
function updatePlayerInfo(self, slimServer, playerInfo)

	-- ignore updates from a different server if the player
	-- is not connected to it
	if self.slimServer ~= slimServer 
		and playerInfo.connected ~= 1 then
		return
	end

	-- Save old player info
	local oldInfo = self.info
	self.info = {}

	-- Update player info, cast to fix perl bugs :)
	self.config = true
	self.info.uuid = tostring(playerInfo.uuid)
	self.info.name = tostring(playerInfo.name)
	self.info.model = tostring(playerInfo.model)
	self.info.connected = tonumber(playerInfo.connected) == 1
	self.info.power = tonumber(playerInfo.power) == 1
	self.info.needsUpgrade = tonumber(playerInfo.player_needs_upgrade) == 1
	self.info.isUpgrading = tonumber(playerInfo.player_is_upgrading) == 1
	self.info.pin = tostring(playerInfo.pin)

	self.lastSeen = Framework:getTicks()

	-- PIN is removed from serverstatus after a player is linked
	if self.info.pin and not playerInfo.pin then
		self.info.pin = nil
	end

	-- Check have we changed SqueezeCenter
	if self.slimServer ~= slimServer then
		-- delete from old server
		if self.slimServer then
			self:free(self.slimServer)
		end

		-- modify the old state, as the player was not connected
		-- to new SqueezeCenter. this makes sure the playerConnected
		-- callback happens.
		oldInfo.connected = false

		-- player is now available
		playerList[self.id] = self

		-- add to new server
		log:info(self, " new for ", slimServer)
		self.slimServer = slimServer
		self.slimServer:_addPlayer(self)

		self.jnt:notify('playerNew', self)
	end

	-- Check for player firmware upgrades
	if oldInfo.needsUpgrade ~= self.info.needsUpgrade or oldInfo.isUpgrading ~= self.info.isUpgrading then
		self.jnt:notify('playerNeedsUpgrade', self, self:isNeedsUpgrade(), self:isUpgrading())
	end

	-- Check if the player name has changed
	if oldInfo.playerName ~= self.state.playerName then
		self.jnt:notify('playerNewName', self, self.info.playerName)
	end

	-- Check if the player power status has changed
	if oldInfo.power ~= self.info.power then
		self.jnt:notify('playerPower', self, self.info.power)
	end

	-- use tostring to handle nil case (in either)
	if oldInfo.connected ~= self.info.connected then
		if self.info.connected then
			self.jnt:notify('playerConnected', self)
		else
			self.jnt:notify('playerDisconnected', self)
		end
	end
end


-- Update player state from a UDAP packet
function updateUdap(self, udap)

	self.config = "needsServer"
	if udap.ucp.name == "" then
		self.info.name = nil
	else
		self.info.name = tostring(udap.ucp.name)
	end
	self.info.model = DEVICE_IDS[tonumber(udap.ucp.device_id)]
	self.info.connected = false

	self.lastSeen = Framework:getTicks()

	-- The player is no longer connected to SqueezeCenter
	if self.slimServer then
		self:free(self.slimServer)
	end

	-- player is now available
	playerList[self.id] = self

	self.jnt:notify('playerNew', self)
end


-- return the Squeezebox mac address from the ssid, or nil if the ssid is
-- not from a Squeezebox in setup mode.
function ssidIsSqueezebox(self, ssid)
	local hasEthernet, mac = string.match(ssid, "logitech([%-%+])squeezebox[%-%+](%x+)")

	if mac then
		mac = string.gsub(mac, "(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)", "%1:%2:%3:%4:%5:%6")
	end

	return mac, hasEthernet
end


-- Update player state from an SSID
function updateSSID(self, ssid, lastScan)
	local mac = ssidIsSqueezebox(self, ssid)

	assert(self.id, mac)

	-- stale wlan scan results?
	if lastScan < self.lastSeen then
		return
	end

	self.config = "needsNetwork"
	self.configSSID = ssid
	self.info.connected = false

	self.lastSeen = lastScan

	-- The player is no longer connected to SqueezeCenter
	if self.slimServer then
		self:free(self.slimServer)
	end

	-- player is now available
	playerList[self.id] = self

	self.jnt:notify('playerNew', self)
end


--[[

=head2 jive.slim.Player:free(slimServer)

Deletes the player, if connect to the given slimServer

=cut
--]]
function free(self, slimServer)
	if self.slimServer ~= slimServer then
		-- ignore, we are not connected to this server
		return
	end

	log:info(self, " delete for ", self.slimServer)

	-- player is no longer active
	playerList[self.id] = nil

	self.jnt:notify('playerDelete', self)

	if self.slimServer then
		self.slimServer:_deletePlayer(self)
		self:offStage()
		self.slimServer = false
	end

	-- The global players table uses weak values, it will be removed
	-- when all references are freed.
end


-- Subscribe to events for this player
function subscribe(self, ...)
	if not self.slimServer then
		return
	end

	self.slimServer.comet:subscribe(...)
end


-- Unsubscribe to events for this player
function unsubscribe(self, ...)
	if not self.slimServer then
		return
	end

	self.slimServer.comet:unsubscribe(...)
end


--[[

=head2 jive.slim.Player:getTrackElapsed()

Returns the amount of time elapsed on the current track, and the track
duration (if known). eg:

  local elapsed, duration = player:getTrackElapsed()
  local remaining
  if duration then
	  remaining = duration - elapsed
  end

=cut
--]]
function getTrackElapsed(self)
	if not self.trackTime then
		return nil
	end

	if self.state.mode == "play" then
		local now = Framework:getTicks() / 1000

		-- multiply by rate to allow for trick modes
		self.trackCorrection = self.rate * (now - self.trackSeen)
	end

	if self.trackCorrection <= 0 then
		return self.trackTime, self.trackDuration
	else
		local trackElapsed = self.trackTime + self.trackCorrection
		return trackElapsed, self.trackDuration
	end
	
end

--[[

=head2 jive.slim.Player:getPlaylistTimestamp()

returns the playlist timestamp for a given player object
the timestamp is an indicator of the last time the playlist changed
it serves as a good check to see whether playlist items should be refreshed

=cut
--]]
function getPlaylistTimestamp(self)
	return self.playlist_timestamp
end


--[[

=head2 jive.slim.Player:getPlaylistSize()

returns the playlist size for a given player object

=cut
--]]
function getPlaylistSize(self)
	return self.playlistSize
end


--[[

=head2 jive.slim.Player:getPlayerMode()

returns the playerMode for a given player object

=cut
--]]
function getPlayerMode(self)
	return self.state.mode
end


--[[

=head2 jive.slim.Player:getPlayerStatus()

returns the playerStatus information for a given player object

=cut
--]]
function getPlayerStatus(self)
	return self.state
end


--[[

=head2 tostring(aPlayer)

if I<aPlayer> is a L<jive.slim.Player>, prints
 Player {name}

=cut
--]]
function __tostring(self)
	return "Player {" .. self:getName() .. "}"
end


--[[

=head2 jive.slim.Player:getName()

Returns the player name

=cut
--]]
function getName(self)
	if self.info.name then
		return self.info.name
	else
		return "Squeezebox " .. string.gsub(string.sub(self.id, 10), ":", "")
	end
end


--[[

=head2 jive.slim.Player:isPowerOn()

Returns true if the player is powered on

=cut
--]]
function isPowerOn(self)
	return self.info.power
end


--[[

=head2 jive.slim.Player:getId()

Returns the player id (in general the MAC address)

=cut
--]]
function getId(self)
	return self.id
end


-- Returns the player ssid if in setup mode, or nil
function getSSID(self)
	if self.config == 'needsNetwork' then
		return self.configSSID
	else
		return nil
	end
end


--[[

=head2 jive.slim.Player:getUuid()

Returns the player uuid.

=cut
--]]
function getUuid(self)
	return self.info.uuid
end


--[[

=head2 jive.slim.Player:getMacAddress()

Returns the player mac address, or nil for http players.

=cut
--]]
function getMacAddress(self)
	if self.info.model == "squeezebox2"
		or self.info.model == "receiver"
		or self.info.model == "transporter" then

		return string.gsub(self.id, "[^%x]", "")
	end

	return nil
end


--[[

=head2 jive.slim.Player:getPin()

Returns the SqueezeNetwork PIN for this player, if it needs to be registered

=cut
--]]
function getPin(self)
	return self.info.pin
end


-- Clear the SN pin when the player is linked
function clearPin(self)
	self.info.pin = nil
end


--[[

=head2 jive.slim.Player:getSlimServer()

Returns the player SlimServer (a L<jive.slim.SlimServer>).

=cut
--]]
function getSlimServer(self)
	return self.slimServer
end


-- call
-- sends a command
function call(self, cmd)
	log:debug("Player:call():")
--	log:debug(cmd)

	local reqid = self.slimServer.comet:request(
		_getSink(self, cmd),
		self.id,
		cmd
	)

	return reqid
end


-- send
-- sends a command but does not look for a response
function send(self, cmd)
	log:debug("Player:send():")
--	log:debug(cmd)

	self.slimServer.comet:request(
		nil,
		self.id,
		cmd
	)
end


-- onStage
-- we're being browsed!
function onStage(self)
	log:debug("Player:onStage()")

	self.isOnStage = true
	
	-- Batch these queries together
	self.slimServer.comet:startBatch()
	
	-- subscribe to player status updates
	local cmd = { 'status', '-', 10, 'menu:menu', 'subscribe:30' }
	self.slimServer.comet:subscribe(
		'/slim/playerstatus/' .. self.id,
		_getSink(self, cmd),
		self.id,
		cmd
	)

	-- subscribe to displaystatus
	cmd = { 'displaystatus', 'subscribe:showbriefly' }
	self.slimServer.comet:subscribe(
		'/slim/displaystatus/' .. self.id,
		_getSink(self, cmd),
		self.id,
		cmd
	)
	
	self.slimServer.comet:endBatch()

	-- create window to display current song info
	self.currentSong.window = Popup("currentsong")
	self.currentSong.window:setAllowScreensaver(true)
	self.currentSong.window:setAlwaysOnTop(true)
	self.currentSong.artIcon = Icon("icon")
	self.currentSong.text = Label("text", "")
	self.currentSong.textarea = Textarea('popupplay', '')

	local group = Group("popupToast", {
			text = self.currentSong.text,
			textarea = self.currentSong.textarea,
			icon = self.currentSong.artIcon
	      })

	self.currentSong.window:addWidget(group)
	self.currentSong.window:addListener(EVENT_KEY_ALL | EVENT_SCROLL,
		function(event)
			local prev = self.currentSong.window:getLowerWindow()
			if prev then
				Framework:dispatchEvent(prev, event)
			end
			return EVENT_CONSUME
		end)
	self.currentSong.window.brieflyHandler = 1
end


-- offStage
-- go back to the shadows...
function offStage(self)
	log:debug("Player:offStage()")

	self.isOnStage = false
	
	iconbar:setPlaymode(nil)
	iconbar:setRepeat(nil)
	iconbar:setShuffle(nil)
	
	-- unsubscribe from playerstatus and displaystatus events
	self.slimServer.comet:startBatch()
	self.slimServer.comet:unsubscribe('/slim/playerstatus/' .. self.id)
	self.slimServer.comet:unsubscribe('/slim/displaystatus/' .. self.id)
	self.slimServer.comet:endBatch()

	self.currentSong = {}
end


-- updateIconbar
function updateIconbar(self)
	log:debug("Player:updateIconbar()")
	
	if self.isOnStage and self.state then
		-- set the playmode (nil, stop, play, pause)
		iconbar:setPlaymode(self.state["mode"])
		
		-- set the repeat (nil, 0=off, 1=track, 2=playlist)
		iconbar:setRepeat(self.state["playlist repeat"])
	
		-- set the shuffle (nil, 0=off, 1=by song, 2=by album)
		iconbar:setShuffle(self.state["playlist shuffle"])
	end
end


-- _process_status
-- processes the playerstatus data and calls associated functions for notification
function _process_status(self, event)
	log:debug("Player:_process_playerstatus()")

	if event.data.error then
		-- ignore player status sent with an error
		return
	end

	-- update our state in one go
	local oldState = self.state
	self.state = event.data

	-- used for calculating getTrackElapsed(), getTrackRemaining()
	self.rate = tonumber(event.data.rate)
	self.trackSeen = Framework:getTicks() / 1000
	self.trackCorrection = 0
	self.trackTime = tonumber(event.data.time)
	self.trackDuration = tonumber(event.data.duration)
	self.playlistSize = tonumber(event.data.playlist_tracks)

	-- update our player state, and send notifications
	-- create a playerInfo table, to allow code reuse
	local playerInfo = {}
	playerInfo.uuid = self.info.uuid
	playerInfo.name = event.data.player_name
	playerInfo.model = self.info.model
	playerInfo.connected = event.data.player_connected
	playerInfo.power = event.data.power
	playerInfo.player_needs_upgrade = event.data.player_needs_upgrade
	playerInfo.player_is_upgrading = event.data.player_is_upgrading
	playerInfo.pin = self.info.pin

	self:updatePlayerInfo(self.slimServer, playerInfo)

	-- update track list
	local nowPlaying = _whatsPlaying(event.data)

	if self.state.mode ~= oldState.mode then
		self.jnt:notify('playerModeChange', self, self.state.mode)
	end

	if self.nowPlaying ~= nowPlaying then
		self.nowPlaying = nowPlaying
		self.jnt:notify('playerTrackChange', self, nowPlaying)
	end

	if self.playlist_timestamp ~= timestamp then
		self.playlist_timestamp = timestamp
		self.jnt:notify('playerPlaylistChange', self)
	end

	-- update iconbar
	self:updateIconbar()
end


-- _process_displaystatus
-- receives the display status data
function _process_displaystatus(self, event)
	log:debug("Player:_process_displaystatus()")
	
	local data = event.data

	if data.display then
		local display = data.display
		local type    = display["type"] or 'text'

		local s = self.currentSong

		local textValue = _formatShowBrieflyText(display['text'])
		if type == 'song' then
			s.textarea:setValue("")
			s.text:setValue(textValue)
			s.artIcon:setStyle("icon")
			if display['icon'] then
				self.slimServer:fetchArtworkURL(display['icon'], s.artIcon, 56)
			else
				self.slimServer:fetchArtworkThumb(display["icon-id"], s.artIcon, 56, 'png')
			end
		else
			s.text:setValue('')
			s.artIcon:setStyle("noimage")
			s.artIcon:setValue(nil)
			s.textarea:setValue(textValue)
		end
		s.window:showBriefly(3000, nil, Window.transitionPushPopupUp, Window.transitionPushPopupDown)
	end
end


-- togglePause
--
function togglePause(self)

	if not self.state then return end
	
	local paused = self.state["mode"]
	log:debug("Player:togglePause(", paused, ")")

	if paused == 'stop' or paused == 'pause' then
		-- reset the elapsed time epoch
		self.trackSeen = Framework:getTicks() / 1000

		self:call({'pause', '0'})
		self.state["mode"] = 'play'
	elseif paused == 'play' then
		self:call({'pause', '1'})
		self.state["mode"] = 'pause'
	end
	self:updateIconbar()
end	


-- isPaused
--
function isPaused(self)
	if self.state then
		return self.state.mode == 'pause'
	end
end


-- getPlayMode returns nil|stop|play|pause
--
function getPlayMode(self)
	if self.state then
		return self.state.mode
	end
end

-- isCurrent
--
function isCurrent(self, index)
	if self.state then
		return self.state.playlist_cur_index == index - 1
	end
end


function isNeedsUpgrade(self)
	return self.info.needsUpgrade
end

function isUpgrading(self)
	return self.info.isUpgrading
end

-- play
-- 
function play(self)
	log:debug("Player:play()")

	if self.state.mode ~= 'play' then
		-- reset the elapsed time epoch
		self.trackSeen = Framework:getTicks()
	end

	self:call({'mode', 'play'})
	self.state.mode = 'play'
	self:updateIconbar()
end


-- stop
-- 
function stop(self)
	log:debug("Player:stop()")
	self:call({'mode', 'stop'})
	self.state.mode = 'stop'
	self:updateIconbar()
end


-- playlistJumpIndex
--
function playlistJumpIndex(self, index)
	log:debug("Player:playlistJumpIndex(", index, ")")
	if index < 1 then return end
	self:call({'playlist', 'index', index - 1})
end


-- playlistDeleteIndex(self, index)
--
function playlistDeleteIndex(self, index)
	log:debug("Player:playlistDeleteIndex(", index, ")")
	if index < 1 then return end
	self:call({'playlist', 'delete', index - 1})
end


-- playlistZapIndex(self, index)
--
function playlistZapIndex(self, index)
	log:debug("Player:playlistZapIndex(", index, ")")
	if index < 1 then return end
	self:call({'playlist', 'zap', index - 1})
end



-- _process_button
--
function _process_button(self, event)
	log:debug("_process_button()")
	self.buttonTo = nil
end


-- button
-- 
function button(self, buttonName)
	local now = Framework:getTicks()
	if self.buttonTo == nil or self.buttonTo < now then
		log:debug("Sending button: ", buttonName)
		self:call({'button', buttonName })
		self.buttonTo = now + MIN_KEY_INT
	else
		log:debug("Suppressing button: ", buttonName)
	end
end

-- scan_rew
-- what to do for the rew button when held
-- use button so that the reverse scan mode is triggered.
function scan_rew(self)
	self:button('scan_rew')
end

-- scan_fwd
-- what to do for the fwd button when held
-- use button so that the forward scan mode is triggered.
function scan_fwd(self)
	self:button('scan_fwd')
end

-- rew
-- what to do for the rew button
-- use button so that the logic of SS (skip to start of current or previous song) is used
function rew(self)
	log:debug("Player:rew()")
	self:button('jump_rew')
end

-- fwd
-- what to do for the fwd button
-- use button so that the logic of SS (skip to start of current or previous song) is used
function fwd(self)
	log:debug("Player:fwd()")
	self:button('jump_fwd')
end


-- volume
-- send new volume value to SS, returns a negitive value if the player is muted
function volume(self, vol, send)
	local now = Framework:getTicks()
	if self.mixerTo == nil or self.mixerTo < now or send then
		log:debug("Sending player:volume(", vol, ")")
		self:send({'mixer', 'volume', vol })
		self.mixerTo = now + MIN_KEY_INT
		self.state["mixer volume"] = vol
		return vol
	else
		log:debug("Suppressing player:volume(", vol, ")")
		return nil
	end
end

-- gototime
-- jump to new time in song
function gototime(self, time)
	self.trackSeen = Framework:getTicks() / 1000
	self.trackTime = time
	log:debug("Sending player:time(", time, ")")
	self:send({'time', time })
	return nil
end

-- isTrackSeekable
-- Try to work out if SC can seek in this track - only really a guess
function isTrackSeekable(self)
	return self.trackDuration and self.state["can_seek"]
end

-- isRemote
function isRemote(self)
	return self.state.remote
end

-- mute
-- mutes or ummutes the player, returns a negitive value if the player is muted
function mute(self, mute)
	local vol = self.state["mixer volume"]
	if mute and vol >= 0 then
		-- mute
		self:send({'mixer', 'muting'})
		vol = -math.abs(vol)

	elseif vol < 0 then
		-- unmute
		self:send({'mixer', 'muting'})
		vol = math.abs(vol)
	end

	self.state["mixer volume"] = vol
	return vol
end


-- getVolume
-- returns current volume (from last status update)
function getVolume(self)
	if self.state then
		return self.state["mixer volume"] or 0
	end
end


-- returns true if this player supports udap setup
function canUdap(self)
	return self.info.model == "receiver"
end


-- returns true if this player can connect to another server
function canConnectToServer(self)
	return self.info.model == "squeezebox2"
		or self.info.model == "receiver"
		or self.info.model == "transporter"
end


-- tell the player to connect to another server
function connectToServer(self, server)

	if self.config == "needsServer" then
		_udapConnect(self, server)
		return

	elseif self.slimServer then
		local ip, port = server:getIpPort()
		self:send({'connect', ip})
		return true

	else
		log:warn("No method to connect ", self, " to ", server)
		return false
	end
end


function parseip(str)
	local ip = 0
	for w in string.gmatch(str, "%d+") do
		ip = ip << 8
		ip = ip | tonumber(w)
	end
	return ip
end


function _udapConnect(self, server)
	local data = {}

	if server:isSqueezeNetwork() then
		local sn_hostname = jnt:getSNHostname()

		if sn_hostname == "www.squeezenetwork.com" then
			data.server_address = Udap.packNumber(1, 4)
		elseif sn_hostname == "www.beta.squeezenetwork.com" then
			data.server_address = Udap.packNumber(1, 4)
			-- XXX the above should be this when "serv 2" in all firmware:
			-- data.server_address = Udap.packNumber(2, 4)
		else
			-- for locally edited values (SN developers)
			local ip = socket.dns.toip(sn_hostname)
			data.server_address = Udap.packNumber(parseip(ip), 4)
		end

		log:info("SN server_address=", data.server_address)

		-- set slimserver address to 0.0.0.1 to workaround a bug in
		-- squeezebox firmware
		data.slimserver_address = Udap.packNumber(parseip("0.0.0.1"), 4)
	else
		local serverip = server:getIpPort()

		log:info("SC slimserver_address=", serverip)

		data.server_address = Udap.packNumber(0, 4)
		data.slimserver_address = Udap.packNumber(parseip(serverip), 4)
	end

	udap = Udap(self.jnt)

	-- configure squeezebox network
	-- XXXX move seqno management into Udap class
	local seqno = 1
	local packet = udap.createSetData(self.id, seqno, data)

	-- send three udp packets in case the wireless network drops them
	-- XXXX make udap class retry packets until ackd
	udap:send(function() return packet end, "255.255.255.255")
	udap:send(function() return packet end, "255.255.255.255")
	udap:send(function() return packet end, "255.255.255.255")
end


function getLastSeen(self)
	return self.lastSeen
end


function isConnected(self)
	return self.slimServer and self.slimServer:isConnected() and self.info.connected
end


-- return true if the player is available, that is when it is connected
-- to SqueezeCenter, or in configuration mode (udap or wlan adhoc)
function isAvailable(self)
	return self.config ~= false
end


function needsNetworkConfig(self)
	return self.config == "needsNetwork"
end


function needsMusicSource(self)
	return self.config == "needsServer"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

