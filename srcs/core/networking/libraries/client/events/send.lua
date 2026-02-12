function LIBRARY:Call(tClient, tEvent)
	local sID		= tostring(tEvent.udPeer:connect_id())
		
	tClient:GetPeer():send(tClient.CODEC:Encode(tEvent.Data), tEvent.iChannel, tEvent.sFlag)
end