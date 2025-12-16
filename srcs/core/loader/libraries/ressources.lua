LIBRARY.RESSOURCES	= {}

function LIBRARY:ResolveDependencies(tDependencies, tSides, tSubLoader)
	assert(istable(tDependencies),	"[RESSOURCES] The 'ResolveDependencies' method requires a table of dependencies")
	assert(istable(tSides),			"[RESSOURCES] The 'tSides' argument must be a table with 'client' and 'server' keys")

	local tDependenciesFinded	= {}

	local bShoulLoad			= (CLIENT and tSides.CLIENT) or (SERVER and tSides.SERVER)
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

function LIBRARY:IncludeFiles(FileSource, tSide, tFileArgs, tSandEnv, bIsBinary, bLoadSubFolders, tCapabilities)
	assert(isstring(FileSource) or isfunction(FileSource),	"[RESSOURCES] The 'IncludeFiles' method requires a valid file path as a string or a function [#1]")
	assert(istable(tSide),									"[RESSOURCES] The 'tSide' argument must be a table with 'client' and 'server' keys [#2]")
	assert((tFileArgs == nil) or istable(tFileArgs),		"[RESSOURCES] The 'tFileArgs' argument must be a table or nil [#3]")

	if (SERVER and tSide.CLIENT and isstring(FileSource)) and not lovr.filesystem.isDirectory(FileSource) then
		self:AddCSLuaFile(FileSource)
	end

	local bShouldLoad	= ((CLIENT and tSide.CLIENT) or (SERVER and tSide.SERVER))
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
				self:LoadInEnv(FileSource, tSandEnv.CONTENT, tSandEnv.ACCESS_POINT, tFileArgs, bLoadSubFolders, tCapabilities) -- FIX
			)
			or isfunction(FileSource) and
			(
				FileSource(tFileArgs)
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
	return SERVER
end

function LIBRARY:ResolveCapabilities(tConfig, tCapabilities)
	assert(istable(tConfig),		"tConfig must be a table")
	assert(istable(tCapabilities),	"tCapabilities must be a table")

	local tConfigBuffer	= {}

	for _, sCapability in ipairs(tCapabilities) do
		local tSource	= tConfig
		local tTarget	= tConfigBuffer
		local sLastKey	= nil

		for sKey in string.gmatch(sCapability, "[^%.]+") do
			local sUpperKey	= sKey:upper()
			if sKey ~= sUpperKey then
				MsgC(
					Color(255, 180, 0),
					"[CONFIG WARNING] key '" .. sKey .. "' is not uppercase, normalized to '" .. sUpperKey
				)
			end

			if sLastKey then
				tTarget[sLastKey]	= tTarget[sLastKey] or {}
				tTarget				= tTarget[sLastKey]
				tSource				= tSource and tSource[sLastKey] or nil
			end

			sLastKey	= sUpperKey
		end

		if sLastKey and tSource then
			tTarget[sLastKey]	= tSource[sLastKey]
		end
	end

	return setmetatable({},
		{
			__index		= tConfigBuffer,
			__metatable	= false,
			__newindex	= function()
				error("Configuration table is read-only", 2)
			end,
		}
	)
end