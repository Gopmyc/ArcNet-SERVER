function LIBRARY:Call(tClient, tEvent)
	local sID		= tostring(tEvent.udPeer:connect_id())
	local udPeer	= tClient:IsValidClient(sID)

	if not udPeer then
		return MsgC(Color(231, 76, 60), "Attempted to send message to unregister Client [ID : " .. sID .. "]  : " .. tostring(udPeer))
	end
		
	udPeer:send(tClient.CODEC:Encode(tEvent.Data), tEvent.iChannel, tEvent.sFlag)
end