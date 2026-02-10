function LIBRARY:Call(tServer, tEvent)
	local sID	= tostring(tEvent.peer:connect_id())

	MsgC(Color(241, 196, 15), "Disconnected from server [ID : " .. sID .. "] : " .. tostring(tEvent.peer) .. "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "]")

	tServer.PEER:disconnect()
	tServer.PEER = nil
end