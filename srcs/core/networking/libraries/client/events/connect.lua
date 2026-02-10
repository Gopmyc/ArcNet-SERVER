function LIBRARY:Call(tServer, tEvent)
	local sID			=	tostring(tEvent.udPeer:connect_id())
	
	MsgC(Color(52, 152, 219), "Connected to server [ID : " .. sID .. "] : " .. tostring(tEvent.peer))
end