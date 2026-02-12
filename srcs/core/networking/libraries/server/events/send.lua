function LIBRARY:Call(tServer, tEvent)
	local sID		= tostring(tEvent.udPeer:connect_id())
	local tPeer		= tServer:IsValidClient(sID)

	if not tPeer then
		return MsgC(Color(231, 76, 60), "Attempted to send message to unregister Client [ID : " .. sID .. "]  : " .. tostring(tPeer[1]))
	end

	tPeer[1]:send(tServer.CODEC:Encode(tEvent.Data), tEvent.iChannel, tEvent.sFlag)
end