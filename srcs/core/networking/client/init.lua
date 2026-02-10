function CORE:Initialize(sAddr, iPort, iMaxChannels, iTimeout)
	local ENET		= assert(self:GetDependence("enet"),	"[CORE] 'ENET' library is required to initialize the networking core")

	sAddr			=	isstring(sAddr)				and sAddr			or self:GetConfig().NETWORK.IP
	iPort			=	isnumber(iPort)				and iPort			or self:GetConfig().NETWORK.PORT
	iMaxChannels	=	isnumber(iMaxChannels)		and iMaxChannels	or self:GetConfig().NETWORK.MAX_CHANNELS
	iTimeout		=	isnumber(iTimeout)			and iTimeout		or self:GetConfig().NETWORK.MESS_TIMEOUT

	local tNetwork	= setmetatable({}, {__index = CORE})

	tNetwork.HOST			= ENET.host_create()
	tNetwork.PEER			= tNetwork.HOST:connect(string.format("%s:%d", sAddr, iPort), iMaxChannels)
	tNetwork.MESS_TIMEOUT	= iTimeout
	tNetwork.HOOKS			= self:GetLibrary("HOOKS"):Initialize()
	tNetwork.EVENTS			= self:GetLibrary("EVENTS"):Initialize({
		connect		= self:GetLibrary("CLIENT/EVENTS/CONNECT"),
		disconnect	= self:GetLibrary("CLIENT/EVENTS/DISCONNECT"),
		receive		= self:GetLibrary("CLIENT/EVENTS/RECEIVE"),
		send		= self:GetLibrary("CLIENT/EVENTS/SEND"),
	})

	MsgC(Color(52, 152, 219), "[CORE] Connection attempt on " .. sAddr .. ":" .. iPort)

	return tNetwork
end

function CORE:Update(iDt)
	local tEvent	= self.HOST:service(self.MESS_TIMEOUT)

	while tEvent do
		xpcall(
			function()
				return self.EVENTS:Call(self, tEvent)
			end,
			function(sErr)
				return MsgC(Color(231, 76, 60), "[ERROR] Unhandled ENet event error: " .. tostring(sErr))
			end
		)

		tEvent	= self.HOST:service(self.MESS_TIMEOUT)
	end
end

function CORE:Send(sMessageID, tData, iChannel, sFlag)
	assert(isstring(sMessageID), "Send: sMessageID must be a string")

	if not self:IsConnected() then
		return MsgC(Color(241, 196, 15), "[WARNING] Cannot send: not connected")
	end

	iChannel	=	isnumber(iChannel)	and iChannel or 0
	sFlag		=	isstring(sFlag)		and sFlag or "reliable"
	tData		=	istable(tData)		and tData or {tData}
	tData		=	self:GetDependence("json").encode({sMessageID, tData}) -- TODO : Fix that

	-- // TODO : Encrypt data...
	
	self.PEER:send(tData, iChannel, sFlag)
end

function CORE:SendToServer(sMessageID, tData, iChannel, sFlag)
	assert(isstring(sMessageID), "Send: sMessageID must be a string")

	if not self:IsConnected() then
		return MsgC(Color(241, 196, 15), "[WARNING] Cannot send: not connected")
	end

	self.EVENTS:Call(self, self.EVENTS:BuildEvent("send", self.PEER, {
		id		=	sMessageID,
		packet	=	istable(tData)		and tData or {tData},
		flag	=	isstring(sFlag)		and sFlag or "reliable"
	}, isnumber(iChannel) and iChannel or 0))
end

function CORE:IsConnected()
	return self.PEER and (self._PEER:state() == "connected");
end

function CORE:AddHook(sID, fCallBack)
	return self.HOOKS:AddHook(sID, fCallBack);
end

function CORE:Destroy()
	if istable(self.HOOKS) and isfunction(self.HOOKS.Destroy) then
		pcall(function() self.HOOKS:Destroy() end)
	end
	self.HOOKS = nil

	if istable(self.EVENTS) and isfunction(self.EVENTS.Destroy) then
		pcall(function() self.EVENTS:Destroy() end)
	end
	self.EVENTS = nil

	if self.HOST then
		pcall(function()
			if self.PEER then
				self.PEER:disconnect()
				self.PEER	= nil
			end

			self.HOST:flush()
			self.HOST	= nil
		end)
	end

	setmetatable(self, nil)
end