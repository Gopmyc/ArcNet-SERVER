function LIBRARY:Call(tServer, tEvent)
	local sID			=	tostring(tEvent.tPeer:connect_id())
	local tPeer			=	tServer:IsValidClient(sID)
	local tData			=	tEvent.tData
	local sFlag			=	tData.flag

	if not tPeer then
		return MsgC(Color(231, 76, 60), "Attempted to send message to unregister Client [ID : " .. sID .. "]  : " .. tostring(tPeer))
	end

	if not istable(tData) then
		return MsgC(Color(231, 76, 60), "Attempt to send data type other than table"..type(tData))
	end
		
	tData	=	{tData.id, tData.packet}
				
	---- pcall all steps ----
	-- // TODO : Table data to JSON...
	-- // TODO : Crypt data...
	-- // TODO : Compress data..
		
	tPeer:send(tData, tEvent.iChannel, sFlag or "reliable")
end