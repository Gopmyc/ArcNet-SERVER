function LIBRARY:Call(tServer, tEvent)
	local sID		= tostring(tEvent.udPeer:connect_id())
	local udPeer	= tServer:IsValidClient(sID)

	if not udPeer then
		return MsgC(Color(231, 76, 60), "Attempted to send message to unregister Client [ID : " .. sID .. "]  : " .. tostring(udPeer))
	end
		
	udPeer:send(tServer.CODEC:Encode(tEvent.Data), tEvent.iChannel, tEvent.sFlag)
end