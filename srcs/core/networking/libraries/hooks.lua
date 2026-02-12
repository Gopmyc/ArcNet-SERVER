function LIBRARY:Initialize()
	return setmetatable(
		{
			__HOOKS = setmetatable({}, {}),
		},
		{
			__index	= LIBRARY,
			__mode	= "kv",
		}
	)
end
	
function LIBRARY:AddHook(sID, fCallBack)
	assert(isstring(sID),			"[ERROR] 'AddHook' : hook ID must be a string")
	assert(isfunction(fCallBack),	"[ERROR] 'AddHook' : callback must be a function")
		
	self.__HOOKS[sID]						= self.__HOOKS[sID] or {}
	self.__HOOKS[sID][#self.__HOOKS[sID] + 1]	= fCallBack

	return #self.__HOOKS[sID]
end

function LIBRARY:CallHook(sID, Data)
	assert(isstring(sID),	"[ERROR] 'CallHook' : hook ID must be a string")
	assert(Data ~= nil,		"[ERROR] 'CallHook' : data must be provided")

	if not (istable(self.__HOOKS[sID]) and next(self.__HOOKS[sID])) then
		return MsgC(Color(255, 0, 0), "[ERROR] 'CallHook' : no hooks found for ID '" .. sID)
	end
		
	for iID, fCallBack in ipairs(self.__HOOKS[sID]) do
		if not isfunction(fCallBack) then goto continue end

		fCallBack(Data)

		::continue::
	end
end
	
function LIBRARY:RemoveHook(sID, iID)
	assert(isstring(sID), "[ERROR] 'RemoveHook' : hook ID must be a string")
		
	if isnumber(iID) then
		return table.remove(self.__HOOKS[sID], iID)
	end

	self.__HOOKS[sID]	= nil
end

function LIBRARY:Destroy()
	if not istable(self) then return end

	if istable(self.__HOOKS) then
		for sID, tList in pairs(self.__HOOKS) do
			if istable(tList) then
				for i = 1, #tList do
					tList[i] = nil
				end
			end
			self.__HOOKS[sID] = nil
		end
	end

	self.__HOOKS = nil

	setmetatable(self, nil)
end