function LIBRARY:Initialize()
	return setmetatable({},
		{
			__mode	= "kv"
		}
	)
end
	
function LIBRARY:AddHook(sID, fCallBack)
	assert(isstring(sID),			"[ERROR] 'AddHook' : hook ID must be a string")
	assert(isfunction(fCallBack),	"[ERROR] 'AddHook' : callback must be a function")
		
	self._HOOKS[sID]						= self._HOOKS[sID] or {}
	self._HOOKS[sID][#self._HOOKS[sID] + 1]	= fCallBack

	return #self._HOOKS[sID]
end

function LIBRARY:CallHook(sID, tData)
	assert(isstring(sID),	"[ERROR] 'CallHook' : hook ID must be a string")
	assert(istable(tData),	"[ERROR] 'CallHook' : hook Data must be a table")

	if not (istable(self._HOOKS[sID]) and next(self._HOOKS[sID])) then
		return
	end
		
	for iID, fCallBack in ipairs(self._HOOKS[sID]) do
		if not isfunction(fCallBack) then goto continue end

		fCallBack(unpack(tData))

		::continue::
	end
end
	
function LIBRARY:RemoveHook(sID, iID)
	assert(isstring(sID), "[ERROR] 'RemoveHook' : hook ID must be a string")
		
	if isnumber(iID) then
		return table.remove(self._HOOKS[sID], iID)
	end

	self._HOOKS[sID]	= nil
end