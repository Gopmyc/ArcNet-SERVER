LIBRARY.ENTRY_POINT	= {
	SERVER	= "init.lua",
	CLIENT	= "init.lua",
}

function LIBRARY:ResolveFileSource(sFileSource, bIsSubFile)
	local bIsFile	= lovr.filesystem.isFile(sFileSource)
	local bIsDir	= lovr.filesystem.isDirectory(sFileSource)

	if not (bIsFile or bIsDir) then
		return MsgC(Color(241, 196, 15), "[WARNING][ENV-RESSOURCES] File or folder not found: " .. sFileSource)
	end

	if bIsFile then
		return sFileSource, bIsSubFile or false
	end

	sFileSource		= sFileSource:sub(-1) ~= "/" and sFileSource .. "/" or sFileSource
	if lovr.filesystem.isFile(sFileSource .. "init.lua") then
		return sFileSource .. "init.lua"
	end

	local sFallback	= sFileSource .. (SERVER and "server/" or "client/")
	MsgC(Color(241, 196, 15), "[WARNING][ENV-RESSOURCES] main file 'init.lua' not found, switch to : " .. sFallback)

	return self:ResolveFileSource(sFallback .. "init.lua", true)
end

function LIBRARY:LoadSubEnvironments(sBasePath, tBaseEnv, sAccessPoint, tFileArgs, tCapabilities, tNotLoadLibraries, tLibraries)
	tNotLoadLibraries	= IsTable(tNotLoadLibraries) and tNotLoadLibraries or {true, true}

	local fCheckLoadLib	= function(bNotLoadLib)
		if not (IsBool(bNotLoadLib) and bNotLoadLib ~= nil) then return true end
		return bNotLoadLib
	end

	local sClient		= sBasePath .. "client/" .. self.ENTRY_POINT.CLIENT
	local sServer		= sBasePath .. "server/" .. self.ENTRY_POINT.SERVER

	local tSandEnv	= table.Copy(tBaseEnv, true)
	if IsTable(tBaseEnv[sAccessPoint]) and IsTable(tBaseEnv[sAccessPoint].LIBRARIES) then
		tSandEnv[sAccessPoint].LIBRARIES.BUFFER	= tLibraries or tSandEnv[sAccessPoint].LIBRARIES.BUFFER
	end

	local tServerEnv	= SERVER and
		lovr.filesystem.isFile(sServer) and
		self:Load(sServer, tSandEnv, sAccessPoint, tFileArgs, false, tCapabilities, fCheckLoadLib(tNotLoadLibraries[1])) or
		nil

	local tClientEnv	= CLIENT and
		lovr.filesystem.isFile(sClient) and
		self:Load(sClient, tSandEnv, sAccessPoint, tFileArgs, false, tCapabilities, fCheckLoadLib(tNotLoadLibraries[2])) or
		nil

	return tServerEnv or tClientEnv or {}
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

function LIBRARY:MergeSubEnvironments(tMainEnv, ...)
	for iID, tSubEnv in pairs({...}) do
		if not IsTable(tSubEnv) then
			MsgC(Color(241, 196, 15), "[WARNING][ENV-RESSOURCES] Failed to merge sub-environment ID : '" .. iID .. "' : invalid table")
			goto continue
		end

		for sKey, vValue in pairs(tSubEnv or {}) do
			if sKey ~= "__PATH" and sKey ~= "__NAME" and sKey ~= "LIBRARIES" then
				tMainEnv[sKey] = vValue
			end
		end

		::continue::
	end
end

function LIBRARY:Load(sFileSource, tSandEnv, sAccessPoint, tFileArgs, bLoadSubFolders, tCapabilities, bNotLoadLibraries)
	assert(IsString(sFileSource),					"[ENV-RESSOURCES] FileSource must be a string (#1)")
	assert(IsTable(tSandEnv),						"[ENV-RESSOURCES] ENV must be a table (#2)")
	assert(IsString(sAccessPoint),					"[ENV-RESSOURCES] AccessPoint must be a string (#3)")
	assert(tFileArgs == nil or IsTable(tFileArgs),	"[ENV-RESSOURCES] FileArg must be a table or nil (#4)")

	local tEnvBuilder	= self:GetLibrary("ENV_BUILDER")
	if not IsTable(tEnvBuilder) then
		return MsgC(Color(241, 196, 15), "[WARNING] 'Load' method in loader library : 'ENV_LOADER', failed. 'ENV_BUILDER' library not found")
	end

	local sResolved		= self:ResolveFileSource(sFileSource)
	if not sResolved then
		return MsgC(Color(241, 196, 15), "[WARNING][ENV-RESSOURCES] Failed to resolve file source: " .. sFileSource)
	end

	local tSubEnv;
	local tEnv		= tEnvBuilder:BuildEnvironment(sResolved, tSandEnv, sAccessPoint, tFileArgs, tCapabilities, not bNotLoadLibraries)
	if bLoadSubFolders and sResolved:sub(-8) == "init.lua" then
		local sBasePath			= sResolved:match("^(.*[/\\])")
		tSubEnv					= self:LoadSubEnvironments(sBasePath, tSandEnv, sAccessPoint, tFileArgs, tCapabilities, {true, true}, tEnv[sAccessPoint].LIBRARIES and tEnv[sAccessPoint].LIBRARIES.BUFFER)
	end

	self:MergeSubEnvironments(tEnv[sAccessPoint], tSubEnv)
	self:ExecuteChunk(sResolved, tEnv)

	return assert(IsTable(tEnv[sAccessPoint]), "[ENV-RESSOURCES] Access point '" .. sAccessPoint .. "' unreachable") and tEnv[sAccessPoint]
end