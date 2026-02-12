function LIBRARY:Call(tClient, tEvent)
	local sID			=	tostring(tEvent.udPeer:connect_id())
	
	MsgC(Color(46, 204, 113), "Connected to server [ID : " .. sID .. "] : " .. tostring(tEvent.udPeer))

	tClient:AddHook("message-id-test", function(Data)
		print("Received from server :", Data, type(Data))
		tClient:SendToServer(tClient:BuildPacket("message-id-test", "Hello server friend !", true, true))
	end)
end