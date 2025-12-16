--
-- ┌─────────────┐
-- │ ENV BUILDER │
-- └─────────────┘
--

LIBRARY.ENV_BUILDER		= {}

function LIBRARY.ENV_BUILDER:ApplyConstants(tEnv, tPolicy)
	for sKey, vValue in pairs(tPolicy.constants or {}) do
		tEnv[sKey] = vValue
	end
end

function LIBRARY.ENV_BUILDER:ApplyFunctions(tEnv, tPolicy)
	for sKey, bAllow in pairs(tPolicy.functions or {}) do
		bAllow and (tEnv[sKey] = _G[sKey])
	end
end

function LIBRARY.ENV_BUILDER:ApplyLibraries(tEnv, tPolicy)
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
end

function LIBRARY.ENV_BUILDER:ApplyNamespaces(tEnv, tPolicy)
	for sName, tCfg in pairs(tPolicy.namespaces or {}) do
		if tCfg.exposed then
			tEnv[sName]	= tEnv[sName] or {}
		end
	end
end

function LIBRARY.ENV_BUILDER:ApplyFallback(tEnv, tPolicy)
	local tFallback = tPolicy.fallback
	if not tFallback then return end

	if not tFallback.global then
		setmetatable(tEnv, {
			__index = function(_, sKey)
				if tFallback.error_on_missing then
					error("Access denied: " .. tostring(sKey), 2)
				end
				return nil
			end
		})
	else
		setmetatable(tEnv, { __index = _G })
	end
end

function LIBRARY.ENV_BUILDER:InitAccessPoint(tEnv, sAccessPoint, sFileSource, tFileArgs, tCapabilities)
	tEnv[sAccessPoint]					= tEnv[sAccessPoint] or {}

	tEnv[sAccessPoint].GetConfig		= function()
		return tCapabilities
	end

	tEnv[sAccessPoint].GetDependence	= function(_, sKey)
		return tFileArgs and tFileArgs[sKey]
	end

	tEnv[sAccessPoint].__PATH			= sFileSource:match("^(.*[/\\])[^/\\]+%.lua$") or nil
	tEnv[sAccessPoint].__NAME			= sFileSource:match("([^/\\]+)%.lua$") or "compiled-chunk"
end

function LIBRARY.ENV_BUILDER:LoadInternalLibraries(tEnv, sAccessPoint)
	local tLib = tEnv[sAccessPoint].LIBRARIES
	if istable(tLib) and isstring(tLib.PATH) and isfunction(tLib.Load) then
		tLib:Load((tEnv[sAccessPoint].__PATH or "") .. tLib.PATH)
	end
end

-- ────────────────
-- ────────────────

function LIBRARY:SetEnvSpecification(tEnv)
	self.SAFE_GLOBALS	= tEnv
end

function LIBRARY:ResolveFileSource(sFileSource)
	local bIsFile	= lovr.filesystem.isFile(sFileSource)
	local bIsDir	= lovr.filesystem.isDirectory(sFileSource)

	if not (bIsFile or bIsDir) then
		return MsgC(Color(241, 196, 15), "[WARNING][ENV-RESSOURCES] File or folder not found: " .. sFileSource)
	end

	if bIsFile then
		return sFileSource
	end

	sFileSource		= sFileSource:sub(-1) ~= "/" and sFileSource .. "/" or sFileSource
	if lovr.filesystem.isFile(sFileSource .. "init.lua") then
		return sFileSource .. "init.lua"
	end

	local sFallback	= sFileSource .. (SERVER and "server/" or "client/")
	MsgC(Color(241, 196, 15), "[WARNING][ENV-RESSOURCES] maint 'init.lua' not found, switch to : " .. sFallback)

	return self:ResolveFileSource(sFallback .. "init.lua")
end

function LIBRARY:LoadSubEnvironments(sBasePath, tSandEnv, sAccessPoint, tFileArgs)
	local sClient		= sBasePath .. "client/cl_init.lua"
	local sServer		= sBasePath .. "server/sv_init.lua"

	local tServerEnv	= SERVER and
		lovr.filesystem.isFile(sServer) and
		self:Load(sServer, tSandEnv, sAccessPoint, tFileArgs) or
		nil

	local tClientEnv	= CLIENT and
		lovr.filesystem.isFile(sClient) and
		self:Load(sClient, tSandEnv, sAccessPoint, tFileArgs) or
		nil

	return tServerEnv, tClientEnv
end

function LIBRARY:BuildEnvironment(sFileSource, tSandEnv, sAccessPoint, tFileArgs, tCapabilities)
	local tEnv		= table.Copy(tSandEnv, true)
	local tPolicy	= self.SAFE_GLOBAL
	local tBuilder	= self.ENV_BUILDER

	tBuilder:ApplyConstants(tEnv, tPolicy)
	tBuilder:ApplyFunctions(tEnv, tPolicy)
	tBuilder:ApplyLibraries(tEnv, tPolicy)
	tBuilder:ApplyNamespaces(tEnv, tPolicy)
	tBuilder:ApplyFallback(tEnv, tPolicy)
	tBuilder:InitAccessPoint(tEnv, sAccessPoint, sFileSource, tFileArgs, tCapabilities)
	tBuilder:LoadInternalLibraries(tEnv, sAccessPoint)

	return tEnv
end

function LIBRARY:ExecuteChunk(sFileSource, tEnv)
	local fChunk	= LoadFileInEnvironment(sFileSource, tEnv)
	if not fChunk then
		return false
	end

	local bOk, sErr	= pcall(fChunk)
	if not bOk then
		MsgC(Color(255, 0, 0), "[ENV-RESSOURCES] Runtime error: " .. tostring(sErr))
	end

	return true
end

function LIBRARY:MergeSubEnvironment(tMainEnv, tSubEnv)
	for sKey, vValue in pairs(tSubEnv or {}) do
		if sKey ~= "__PATH" and sKey ~= "__NAME" and sKey ~= "LIBRARIES" then
			tMainEnv[sKey] = vValue
		end
	end
end

-- TODO : Improve to overload .../client/libraries/ or .../server/libraries/ in .../libraries/ and give acces to sub part (client/ or server/) at .../libraries/
function LIBRARY:Load(sFileSource, tSandEnv, sAccessPoint, tFileArgs, bLoadSubFolders, tCapabilities)
	assert(isstring(sFileSource),					"[ENV-RESSOURCES] FileSource must be a string (#1)")
	assert(istable(tSandEnv),						"[ENV-RESSOURCES] ENV must be a table (#2)")
	assert(isstring(sAccessPoint),					"[ENV-RESSOURCES] AccessPoint must be a string (#3)")
	assert(tFileArgs == nil or istable(tFileArgs),	"[ENV-RESSOURCES] FileArg must be a table or nil (#4)")

	local sResolved	= self:ResolveFileSource(sFileSource)
	if not sResolved then
		return nil
	end

	local tServerEnv, tClientEnv;
	if bLoadSubFolders and sResolved:sub(-8) == "init.lua" then
		local sBasePath = sResolved:match("^(.*[/\\])")
		tServerEnv, tClientEnv = self:LoadSubEnvironments(sBasePath, tSandEnv, sAccessPoint, tFileArgs)
	end

	local tEnv = self:BuildEnvironment(sResolved, tSandEnv, sAccessPoint, tFileArgs, tCapabilities)

	self:ExecuteChunk(sResolved, tEnv)

	assert(istable(tEnv[sAccessPoint]), "[ENV-RESSOURCES] Access point '" .. sAccessPoint .. "' is not a table or unreachable")

	local tSubEnv = (SERVER and tServerEnv) or (CLIENT and tClientEnv) or {}
	self:MergeSubEnvironment(tEnv[sAccessPoint], tSubEnv)

	return tEnv[sAccessPoint]
end
