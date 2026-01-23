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
			__mode		= "kv",
		}
	)
end

function LIBRARY:Call(tServer, tEvent)
	return xpcall(
		function()
			return self.__EVENTS[tEvent.sType]:Call(tServer, tEvent)
		end,
		function(sErr)
			MsgC(Color(255, 0, 0), "[ERROR] Event error : " .. tostring(sErr))
		end
	)
end
	
function LIBRARY:BuildEvent(sType, tPeer, Data, iChannel)
	assert(isstring(sType),	"BuildEvent : Type event must be a string")
	assert(istable(tPeer),	"BuildEvent : Peer event must be a table")
		
	return {
		sType		= sType,
		tPeer		= tPeer,
		tData		= Data,
		iChannel	= iChannel,
	}
end