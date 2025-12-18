function LIBRARY:ApplyConstants(tEnv, tPolicy)
	for sKey, vValue in pairs(tPolicy.constants or {}) do
		tEnv[sKey] = vValue
	end

	return tEnv
end

function LIBRARY:ApplyFunctions(tEnv, tPolicy)
	for sKey, bAllow in pairs(tPolicy.functions or {}) do
		if bAllow then
			tEnv[sKey] = _G[sKey]
		end
	end

	return tEnv
end

function LIBRARY:ApplyLibraries(tEnv, tPolicy)
	for sLib, vScope in pairs(tPolicy.libraries or {}) do
		if vScope == "full" then
			tEnv[sLib] = _G[sLib]
		elseif istable(vScope) then
			local tLib = {}
			for sFn, bAllow in pairs(vScope) do
				if bAllow and _G[sLib] then
					tLib[sFn] = _G[sLib][sFn]
				end
			end
			tEnv[sLib] = tLib
		end
	end

	return tEnv
end

function LIBRARY:ApplyNamespaces(tEnv, tPolicy)
	for sName, tCfg in pairs(tPolicy.namespaces or {}) do
		if tCfg.exposed then
			tEnv[sName]	= tEnv[sName] or {}
		end
	end

	return tEnv
end

function LIBRARY:ApplyFallback(tEnv, tPolicy)
	local tFallback = tPolicy.fallback
	if not tFallback then return end

	local tMt = getmetatable(tEnv)
	if not istable(tMt) then
		tMt = {}
	end

	if not tFallback.global then
		tMt.__index = function(_, sKey)
			if tFallback.error_on_missing then
				MsgC(Color(241, 196, 15), "[WARNING] Access denied: " .. tostring(sKey), 2)
			end
			return nil
		end
	else
		tMt.__index = _G
	end

	setmetatable(tEnv, tMt)

	return tEnv
end

function LIBRARY:InitAccessPoint(tEnv, sAccessPoint, sFileSource, tFileArgs, tCapabilities)
	tEnv[sAccessPoint]					= tEnv[sAccessPoint] or {}

	tEnv[sAccessPoint].GetConfig		= function()
		return tCapabilities
	end

	tEnv[sAccessPoint].GetDependence	= function(_, sKey)
		return tFileArgs and tFileArgs[sKey]
	end

	tEnv[sAccessPoint].__PATH			= sFileSource:match("^(.*[/\\])[^/\\]+%.lua$") or nil
	tEnv[sAccessPoint].__NAME			= sFileSource:match("([^/\\]+)%.lua$") or "compiled-chunk"

	return tEnv
end

function LIBRARY:LoadInternalLibraries(tEnv, sAccessPoint, sPath)
	local tLib		= tEnv[sAccessPoint].LIBRARIES
	if not (istable(tLib) and isstring(tLib.PATH) and isfunction(tLib.Load)) then
		MsgC(Color(241, 196, 15), "[WARNING][ENV-RESSOURCES] Cannot load internal libraries: invalid LIBRARIES access point")
		return tEnv
	end

	local sBasePath	= sPath or tEnv[sAccessPoint].__PATH or ""
	sBasePath		= (sBasePath:find("/server/$") or sBasePath:find("/client/$")) and sBasePath:match("^(.*[/\\])[^/\\]+[/\\]$") or sBasePath

	tLib:Load(sBasePath .. tLib.PATH)

	return tEnv
end


function LIBRARY:BuildEnvironment(sFileSource, tSandEnv, sAccessPoint, tFileArgs, tCapabilities, bLoadLibraries)
	local tEnv		= table.Copy(tSandEnv, true)
	local tPolicy	= self.SAFE_GLOBAL

	if not istable(tPolicy) then
		return MsgC(Color(241, 196, 15), "[WARNING] 'BuildEnvironement' fail for : '" .. sFileSource .. "', 'SAFE_GLOBAL' not set.")
	end

	self:ApplyConstants(tEnv, tPolicy)
	self:ApplyFunctions(tEnv, tPolicy)
	self:ApplyLibraries(tEnv, tPolicy)
	self:ApplyNamespaces(tEnv, tPolicy)
	self:ApplyFallback(tEnv, tPolicy)
	self:InitAccessPoint(tEnv, sAccessPoint, sFileSource, tFileArgs, tCapabilities)
	if bLoadLibraries then self:LoadInternalLibraries(tEnv, sAccessPoint) end

	return tEnv
end

function LIBRARY:SetEnvSpecification(tEnv)
	self.SAFE_GLOBAL	= tEnv
end