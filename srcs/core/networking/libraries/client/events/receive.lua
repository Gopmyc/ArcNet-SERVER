function LIBRARY:Call(tClient, tEvent)
	local sID					= tostring(tEvent.udPeer:connect_id())
	local sPacketID, Content	= tClient.CODEC:Decode(tEvent.Data)

	return tClient.HOOKS:CallHook(sPacketID, Content)
end