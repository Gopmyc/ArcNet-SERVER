function LIBRARY:Initialize(tEvents)
	local tEvents = tEvents or {}

	if not next(tEvents) then
		MsgC(Color(241, 196, 15), "[WARNING] No events provided to initialize EVENTS library")
	end
	
	return setmetatable(
		{
			__EVENTS = setmetatable(
				{},
				{
					__index = function(_, kKey)
						return tEvents[kKey]
					end,
					__newindex = function()
						error("__EVENTS is read-only", 2)
					end,
					__pairs = function()
						return pairs(tEvents)
					end,
					__len = function()
						local iCount = 0
						for _, _ in pairs(tEvents) do
							iCount = iCount + 1
						end
						return iCount
					end
				}
			),
		},
		{
			__index		= LIBRARY,
			__mode		= "kv",
		}
	)
end

function LIBRARY:Call(tServer, tEvent)
	return xpcall(
		function()
			PrintTable(tEvent)
			return self.__EVENTS[tEvent.type]:Call(tServer, self:BuildEvent(tEvent.type, tEvent.peer, tEvent.data, tEvent.channel))
		end,
		function(sErr)
			MsgC(Color(255, 0, 0), "[ERROR] Event error : " .. tostring(sErr))
		end
	)
end
	
function LIBRARY:BuildEvent(sType, udPeer, Data, iChannel)
	assert(isstring(sType),	"BuildEvent : Type event must be a string")
	assert(isuserdata(udPeer),	"BuildEvent : Peer event must be a userdata")
		
	return {
		sType		= sType,
		udPeer		= udPeer,
		tData		= Data,
		iChannel	= iChannel,
	}
end

function LIBRARY:Destroy()
	if not istable(self) then return end

	local tEvents = rawget(self, "__EVENTS")
	if istable(tEvents) then
		setmetatable(tEvents, nil)

		for kKey in pairs(tEvents) do
			tEvents[kKey] = nil
		end
	end

	self.__EVENTS = nil

	setmetatable(self, nil)
end