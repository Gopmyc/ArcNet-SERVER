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

	local tEnvBuilder	= self:GetLibrary("ENV_BUILDER")
	if not istable(tEnvBuilder) then
		return MsgC(Color(241, 196, 15), "[WARNING] 'Load' method in loader library : 'ENV_LOADER', failed. 'ENV_BUILDER' library not found")
	end

	local sResolved	= self:ResolveFileSource(sFileSource)
	if not sResolved then
		return nil
	end

	local tServerEnv, tClientEnv;
	if bLoadSubFolders and sResolved:sub(-8) == "init.lua" then
		local sBasePath = sResolved:match("^(.*[/\\])")
		tServerEnv, tClientEnv = self:LoadSubEnvironments(sBasePath, tSandEnv, sAccessPoint, tFileArgs)
	end

	local tEnv		= tEnvBuilder:BuildEnvironment(sResolved, tSandEnv, sAccessPoint, tFileArgs, tCapabilities)
	local tSubEnv	= (SERVER and tServerEnv) or (CLIENT and tClientEnv) or {}
	self:MergeSubEnvironment(tEnv[sAccessPoint], tSubEnv)

	self:ExecuteChunk(sResolved, tEnv)

	return assert(istable(tEnv[sAccessPoint]), "[ENV-RESSOURCES] Access point '" .. sAccessPoint .. "' unreachable") and tEnv[sAccessPoint]
end