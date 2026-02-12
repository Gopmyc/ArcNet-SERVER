function CORE:Initialize(sAddr, iPort, iMaxChannels, iTimeout, sKey)
	local ENET		= assert(self:GetDependence("enet"),	"[CORE] 'ENET' library is required to initialize the networking core")

	sAddr			=	isstring(sAddr)				and sAddr			or self:GetConfig().NETWORK.IP
	iPort			=	isnumber(iPort)				and iPort			or self:GetConfig().NETWORK.PORT
	iMaxChannels	=	isnumber(iMaxChannels)		and iMaxChannels	or self:GetConfig().NETWORK.MAX_CHANNELS
	iTimeout		=	isnumber(iTimeout)			and iTimeout		or self:GetConfig().NETWORK.MESS_TIMEOUT
	sKey			=	isstring(sKey)				and sKey			or self:GetConfig().NETWORK.ENCRYPTION_KEY

	local tNetwork	= setmetatable({}, {__index = CORE})

	tNetwork.HOST			= ENET.host_create()
	tNetwork.PEER			= tNetwork.HOST:connect(string.format("%s:%d", sAddr, iPort), iMaxChannels)
	tNetwork.MESS_TIMEOUT	= iTimeout
	tNetwork.HOOKS			= self:GetLibrary("HOOKS"):Initialize()
	tNetwork.CODEC			= self:GetLibrary("CODEC"):Initialize(
		self:GetDependence("JSON"),
		self:GetDependence("CHACHA20"),
		self:GetDependence("POLY1305"),
		self:GetDependence("LZW"),
		self:GetDependence("BASE64"),
		sKey
	)
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

function CORE:SendToServer(tPacket, iChannel, sFlag)
	assert(istable(tPacket),		"[CLIENT] Invalid argument: tPacket must be a table")

	sFlag	= ((sFlag == "unsequenced") or (sFlag == "unreliable") or (sFlag == "reliable")) and sFlag or "reliable"

	self.EVENTS:Call(self, {
		type	= "send",
		peer	= self.PEER,
		data	= tPacket,
		channel	= iChannel or 0,
		flag	= sFlag,
	})
end

function CORE:BuildPacket(sMessageID, Content, bCrypt, bCompress)
	assert(isstring(sMessageID),	"[SERVER] Invalid argument: sMessageID must be a string")
	assert(Content ~= nil,			"[SERVER] Invalid argument: Content must not be nil")

	bCrypt		= (bCrypt == true)		and true or false 
	bCompress	= (bCompress == true)	and true or false

	return {
		ID			= sMessageID,
		CONTENT		= Content,
		ENCRYPTED	= bCrypt,
		COMPRESSED	= bCompress,
	}
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

function CORE:GetPeer()
	return self.PEER
end