LIBRARY.RESSOURCES	= {}

function LIBRARY:LoadInEnv(sFileSource, tSandEnv, sAccessPoint, tFileArgs, bLoadSubFolders)
	assert(isstring(sFileSource),					"[ENV-RESSOURCES] FileSource must be a string (#1)")
	assert(istable(tSandEnv),						"[ENV-RESSOURCES] ENV must be a table (#2)")
	assert(isstring(sAccessPoint),					"[ENV-RESSOURCES] AccessPoint must be a string (#3)")
	assert(tFileArgs == nil or istable(tFileArgs),	"[ENV-RESSOURCES] FileArg must be a table or nil (#4)")

	local tServerEnv, tClientEnv

	local bIsFile = lovr.filesystem.isFile(sFileSource)
	local bIsDir = lovr.filesystem.isDirectory(sFileSource)

	if not (bIsFile or bIsDir) then
		return MsgC(Color(241, 196, 15), "[WARNING][ENV-RESSOURCES] File or folder not found: " .. sFileSource)
	end

	if bIsDir then
		sFileSource = sFileSource:sub(-1) ~= "/" and sFileSource .. "/" or sFileSource

		if bLoadSubFolders then
			local sClient = sFileSource .. "client/cl_init.lua"
			local sServer = sFileSource .. "server/sv_init.lua"

			tServerEnv = SERVER and lovr.filesystem.isFile(sServer)
				and self:LoadInEnv(sServer, tSandEnv, sAccessPoint, tFileArgs)
				or nil

			tClientEnv = CLIENT and lovr.filesystem.isFile(sClient)
				and self:LoadInEnv(sClient, tSandEnv, sAccessPoint, tFileArgs)
				or nil
		end

		sFileSource = sFileSource .. "init.lua"
	end

	local tEnv							= setmetatable(table.Copy(tSandEnv, true), { __index = _G })

	tEnv[sAccessPoint].GetDependence	= function(_, sKey) return tFileArgs and tFileArgs[sKey] end
	tEnv[sAccessPoint].__PATH			= sFileSource:match("^(.*[/\\])[^/\\]+%.lua$") or nil
	tEnv[sAccessPoint].__NAME			= sFileSource:match("([^/\\]+)%.lua$") or "compiled-chunk"

	local tLib							= tEnv[sAccessPoint].__LIBRARIES
	if istable(tLib) and isstring(tLib.__PATH) and isfunction(tLib.__Load) then
		tLib.__BUFFER = tLib.__Load((tEnv[sAccessPoint].__PATH or "") .. tLib.__PATH)
	end

	local fChunk						= LoadFileInEnvironment(sFileSource, tEnv)
	if not fChunk then return nil end

	local bOk, sRunErr					= pcall(fChunk)
	if not bOk then
		MsgC(Color(255, 0, 0), "[ENV-RESSOURCES] Runtime error: " .. tostring(sRunErr))
	end

	assert(istable(tEnv[sAccessPoint]), "[ENV-RESSOURCES] Access point '" .. sAccessPoint .. "' is not a table or unreachable")

	local tSubEnv = (SERVER and tServerEnv) or (CLIENT and tClientEnv) or {}
	for sKey, vValue in pairs(tSubEnv) do
		if sKey ~= "__PATH" and sKey ~= "__NAME" and sKey ~= "__LIBRARIES" then
			tEnv[sAccessPoint][sKey] = vValue
		end
	end

	return tEnv[sAccessPoint]
end

function LIBRARY:GetDependencies(tDependencies, tSides, tSubLoader)
	assert(istable(tDependencies),	"[RESSOURCES] The 'getDependencies' method requires a table of dependencies")
	assert(istable(tSides),			"[RESSOURCES] The 'tSides' argument must be a table with 'client' and 'server' keys")

	local tDependenciesFinded	= {}

	local bShoulLoad			= (CLIENT and tSides.client) or (SERVER and tSides.server)
	if not bShoulLoad then return tDependenciesFinded end

	local tScopeSearch			= (istable(tSubLoader) and isfunction(tSubLoader.GetScript)) and tSubLoader or self
	for iID, sDependence in ipairs(tDependencies) do
		if not isstring(sDependence) then
			MsgC(Color(241, 196, 15), "[WARNING][RESSOURCES] Invalid dependency at index '"..iID.."': expected string, got "..type(sDependence))
			goto continue
		end

		tDependenciesFinded[sDependence]	= tScopeSearch:GetScript(sDependence)

		if tDependenciesFinded[sDependence] == nil then
			MsgC(Color(241, 196, 15), "[WARNING][RESSOURCES] The dependency '" .. sDependence .. "' was not found.") 
		end

		::continue::
	end

	return tDependenciesFinded
end

function LIBRARY:GetScript(sName)
	assert(isstring(sName), "[RESSOURCES] The 'GetScript' method only accepts a string as an argument")

	for sGroupKey, tGroup in pairs(self.RESSOURCES) do
		if istable(tGroup) and tGroup[sName] then
			return tGroup[sName]
		end
	end

	return nil
end

function LIBRARY:IncludeFiles(FileSource, tSide, tFileArgs, tSandEnv, bIsBinary)
	assert(isstring(FileSource) or isfunction(FileSource),	"[RESSOURCES] The 'IncludeFiles' method requires a valid file path as a string or a function [#1]")
	assert(istable(tSide),									"[RESSOURCES] The 'tSide' argument must be a table with 'client' and 'server' keys [#2]")
	assert((tFileArgs == nil) or istable(tFileArgs),		"[RESSOURCES] The 'tFileArgs' argument must be a table or nil [#3]")

	if (SERVER and tSide.client and isstring(FileSource)) and not lovr.filesystem.isDirectory(FileSource) then
		self:GetLibrary("RESSOURCES"):AddCSLuaFile(FileSource)
	end

	local bShouldLoad	= ((CLIENT and tSide.client) or (SERVER and tSide.server))
	if not bShouldLoad then return nil end

	local bIsEnvLoad	= (istable(tSandEnv) and isstring(tSandEnv.ACCESS_POINT) and istable(tSandEnv.CONTENT))
	local bIsLuaFile	= (isstring(FileSource) and string.find(FileSource, "%.lua$"))

	return
	(
		bShouldLoad and
		(
			bIsBinary and
			(
				self:IncludeBinaryFile(FileSource)
			)
			or bIsEnvLoad and
			(
				self:LoadInEnv(FileSource, tSandEnv.CONTENT, tSandEnv.ACCESS_POINT, tFileArgs)
			)
			or isfunction(FileSource) and
			(
				FileSource(tFileArgs)
			)
			or bIsLuaFile and
			(
				require(FileSource)(tFileArgs)
			)
			or
				MsgC(Color(255, 0, 0), "[RESSOURCES] Failed to include file: ", tostring(FileSource))
		)
	)
	or
		nil
end

function LIBRARY:IncludeBinaryFile(sFilePath) -- <-- Useful for a decoupled logic
	return require(sFilePath)
end

function LIBRARY:AddCSLuaFile(sPath)
	-- TODO : Shared file handling
end