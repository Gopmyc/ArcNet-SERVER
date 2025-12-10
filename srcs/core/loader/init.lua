local LOADER = {}

function LOADER:Initialize(sConfigPath, tLibraries)
	assert(isstring(sConfigPath), "[LOADER] Configuration path must be a string")
	assert(istable(tLibraries), "[LOADER] Libraries must be a table")

	local tConfig			= self:LoadConfiguration(sConfigPath, tLibraries)
	local tLoader			= self:CreateLoaderInstance(tConfig)
	tLoader.SUBLOADER_BASE	= self:InitializeSubloaders(tLoader, tConfig)

	-- It's not clean, it needs to be changed later
	local fMsgC	= MsgC
	MsgC	= function(...)
		return (istable(tLoader.CONFIG.DEBUG) and tLoader.CONFIG.DEBUG.ENABLED) and fMsgC(...) or (not istable(tLoader.CONFIG.DEBUG) and fMsgC(...))
	end

	return tLoader
end

function LOADER:CreateLoaderInstance(tConfig)
	local tLoaderConfig	= tConfig.LOADER
	if not istable(tLoaderConfig) then return error("[CONFIG-LOADER] Missing 'LOADER' configuration table") end
	tConfig.LOADER		= nil

	local tLoader		= setmetatable(tLoaderConfig, {__index = LOADER})
	tLoader.CONFIG		= tConfig
	return tLoader
end

function LOADER:InitializeSubloaders(tLoader, tConfig)
	local tSubloaderBase = require(tLoader.SUBLOADERS_PATH):Initialize(tConfig, tLoader.SUBLOADERS_PATH, tLoader)

	if istable(tLoader.CONFIG.DEBUG) and tLoader.CONFIG.DEBUG.ENABLED then
		tLoader.LOAD_PRIORITY[#tLoader.LOAD_PRIORITY + 1]	= "HOT_RELOAD"
	end

	for _, sGroup in ipairs(tLoader.LOAD_PRIORITY) do
		local tSubLoader, tInitialized = tSubloaderBase:InitializeGroup(sGroup)
		if istable(tSubLoader) then
			tLoader.RESSOURCES[tSubLoader[1]:GetID()] = tInitialized
		end
	end

	return tSubloaderBase
end

function LOADER:LoadConfiguration(sPath, tLibraries, tTable)
	assert(isstring(sPath), "[CONFIG-LOADER] Path must be a string")
	assert(istable(tLibraries), "[CONFIG-LOADER] Libraries must be a table")

	local tFiles, tDirs	= FilesFind(sPath)
	tTable				= istable(tTable) and tTable or {}
	for _, sFile in ipairs(tFiles) do
		if sFile:sub(-5) == ".yaml" then
			local sData = lovr.filesystem.read(sPath .. "/" .. sFile)
			local tParsed = sData and tLibraries.YAML.eval(sData) or nil
			tTable[string.upper(sFile:sub(1, -6))] = istable(tParsed) and tParsed or nil
		end
	end

	for _, sDir in ipairs(tDirs) do
		local sKey		= string.upper(sDir)
		tTable[sKey]	= {}
		self:LoadConfiguration(sPath .. "/" .. sDir, tLibraries, tTable[sKey])
	end

	return tTable
end

function LOADER:GetSubLoaderBase()
	return self.SUBLOADER_BASE
end

function LOADER:DeepRawCopy(tTable, tSeen)
    tSeen			= tSeen or {}
    if tSeen[tTable] then return tSeen[tTable] end

    local tCopy		= {}
    tSeen[tTable]	= tCopy

    for Key, Value in pairs(tTable) do
    	if istable(Value) then
    		tCopy[Key] = self:DeepRawCopy(Value, tSeen)
    	else
    		tCopy[Key] = Value
    	end
    end

    return tCopy
end

function LOADER:LoadInEnv(sFileSource, tSandEnv, sAccessPoint, tFileArgs)
	assert(isstring(sFileSource), "[ENV-LOADER] FileSource must be a string (#1)")
	assert(istable(tSandEnv), "[ENV-LOADER] ENV must be a table (#2)")
	assert(isstring(sAccessPoint), "[ENV-LOADER] AccessPoint must be a string (#3)")
	assert(tFileArgs == nil or istable(tFileArgs), "[ENV-LOADER] FileArg must be a table or nil (#4)")

	local tServerEnv, tClientEnv

	local bIsFile = lovr.filesystem.isFile(sFileSource)
	local bIsDir  = lovr.filesystem.isDirectory(sFileSource)

	if not (bIsFile or bIsDir) then
		MsgC(Color(241, 196, 15), "[WARNING][ENV-LOADER] File or folder not found: " .. sFileSource)
		return nil
	end

	if bIsDir then
		sFileSource = sFileSource:sub(-1) ~= "/" and sFileSource .. "/" or sFileSource

		local sClient = sFileSource .. "client/cl_init.lua"
		local sServer = sFileSource .. "server/sv_init.lua"

		tServerEnv = SERVER and lovr.filesystem.isFile(sServer) and self:LoadInEnv(sServer, tSandEnv, sAccessPoint, tFileArgs) or nil
		tClientEnv = CLIENT and lovr.filesystem.isFile(sClient) and self:LoadInEnv(sClient, tSandEnv, sAccessPoint, tFileArgs) or nil
		
		sFileSource = sFileSource .. "init.lua"
	end

	local sCode = lovr.filesystem.read(sFileSource)
	if not sCode then
		MsgC(Color(255, 0, 0), "[ENV-LOADER] Cannot read file: " .. sFileSource)
		return nil
	end

	local fChunk, sCompileErr = loadstring(sCode, sFileSource)
	if not fChunk then
		MsgC(Color(255, 0, 0), "[ENV-LOADER] Compile error: " .. tostring(sCompileErr))
		return nil
	end

	local tEnv = setmetatable(self:DeepRawCopy(tSandEnv), { __index = _G })

	tEnv[sAccessPoint].GetDependence = function(_, sKey) return tFileArgs and tFileArgs[sKey] end
	tEnv[sAccessPoint].__PATH = sFileSource:match("^(.*[/\\])[^/\\]+%.lua$") or nil
	tEnv[sAccessPoint].__NAME = sFileSource:match("([^/\\]+)%.lua$") or "compiled-chunk"

	local tLib = tEnv[sAccessPoint].__LIBRARIES
	if istable(tLib) and isstring(tLib.__PATH) and isfunction(tLib.__Load) then
		tLib.__BUFFER = tLib.__Load((tEnv[sAccessPoint].__PATH or "") .. tLib.__PATH)
	end

	setfenv(fChunk, tEnv)

	local bOk, sRunErr = pcall(fChunk)
	if not bOk then
		MsgC(Color(255, 0, 0), "[ENV-LOADER] Runtime error: " .. tostring(sRunErr))
	end

	assert(istable(tEnv[sAccessPoint]), "[ENV-LOADER] Access point '" .. sAccessPoint .. "' is not a table or unreachable")

	local tSubEnv = (SERVER and tServerEnv) or (CLIENT and tClientEnv) or {}
	for sKey, vValue in pairs(tSubEnv) do
		if sKey ~= "__PATH" and sKey ~= "__NAME" and sKey ~= "__LIBRARIES" then
			tEnv[sAccessPoint][sKey] = vValue
		end
	end

	return tEnv[sAccessPoint]
end

function LOADER:LoadSubLoader(sPath, Content, bShared, sID)
	assert(isstring(sPath), "[SUB-LOADER] Path must be a string")
	assert(Content ~= nil, "[SUB-LOADER] Content must be a table")
	assert(isbool(bShared), "[SUB-LOADER] Shared flag must be a boolean")

	if bShared and SERVER then
		-- AddCSLuaFile(sPath)
	end

	local bShouldLoad	= (bShared and CLIENT) or SERVER
	if bShouldLoad then
		local tSubLoader	= self:LoadInEnv(sPath,
		{
			SUBLOADER = (function()
				local _			= {}
				_.__index		= _

				_.__LIBRARIES	= self:GetLibrariesBase("libraries", _)

				function _:GetLoader()
					return rawget(self, "__PARENT")
				end

				function _:GetID()
					return self.__ID
				end

				function _:IsInitialized()
					return self.__Initialized == true
				end

				function _:GetBuffer()
					return self.__BUFFER
				end

				function _:GetEnv()
					return self.__ENV
				end

				function _:GetScript(sName)
					local FileLoaded = self:GetLoader():GetScript(sName)

					if FileLoaded == nil then
						for sFileKey, tFile in pairs(self:GetBuffer()) do
							if sFileKey == sName then return tFile end
						end
					end

					return FileLoaded
				end

				return _
			end)(),
		},
		"SUBLOADER", nil)

		tSubLoader.__PARENT	= self
		tSubLoader.__ID		= isstring(sID) and sID or "UNKNOWN_SUBLOADER"

		if not (istable(tSubLoader) and isstring(tSubLoader.__ID)) then
			return MsgC(Color(255, 0, 0), "[SUB-LOADER] The sub-loader at path '"..sPath.."' did not return a valid table with an '__ID' string.")
		end

		return {tSubLoader, Content}
	end
end

function LOADER:GetConfig()
	return self.CONFIG
end

function LOADER:GetScript(sName, bDebug)
	assert(isstring(sName), "[LOADER] The 'GetScript' method only accepts a string as an argument")

	if not bDebug then
		for sGroupKey, tGroup in pairs(self.RESSOURCES) do
			if istable(tGroup) and tGroup[sName] then
				return tGroup[sName]
			end
		end
		return nil
	end

	MsgC(Color(52,152,219), "\n[LOADER] --- Begin Script Search ---\n")

	local bFound	= false
	for sGroupKey, tGroup in pairs(self.RESSOURCES) do
		if not (isstring(sGroupKey) and istable(tGroup)) then
			MsgC(Color(231,76,60), string.format("  [!] Invalid group: key=%s (type=%s)\n", tostring(sGroupKey), type(tGroup)))
			goto continue
		end

		local iCount = table.Count(tGroup)
		MsgC(Color(52,152,219), string.format("\n[GROUP] %s  (%d scripts)\n", sGroupKey, iCount))

		local bCompact = iCount > 20
		local bGroupFound = false

		for sFileKey, fFileLoaded in pairs(tGroup) do
			local bIsMatch = (sFileKey == sName)

			if not bCompact then
				if bIsMatch then
					MsgC(Color(46,204,113), string.format("    ✔ %s (found)\n", sFileKey))
				else
					MsgC(Color(127,140,141), string.format("    • %s\n", sFileKey))
				end
			end

			if bIsMatch then
				bFound = true
				bGroupFound = true
				MsgC(Color(46,204,113), string.format("\n[LOADER] Script '%s' successfully located.\n", sName))
				MsgC(Color(52,152,219), "[LOADER] --- End Script Search ---\n\n")
				return fFileLoaded
			end
		end

		if not bGroupFound and not bCompact then
			MsgC(Color(149,165,166), "    (no match)\n")
		end

		::continue::
	end

	MsgC(Color(231,76,60), string.format("\n[LOADER] Script '%s' not found in any group.\n", sName))
	MsgC(Color(52,152,219), "[LOADER] --- End Script Search ---\n\n")
	return nil
end

function LOADER:DebugPrint(sMsg, sMsgType)
	assert(isstring(sMsg) or istable(sMsg),	"[DEBUG-PRINT] Message must be a string or a table")
	assert(isstring(sMsgType),				"[DEBUG-PRINT] Message type must be a string")

	local tConfig	= self:GetConfig().DEBUG
	local sPrefix	= "["..sMsgType.."]"
	local tColor	= tConfig.COLORS[sMsgType] or tConfig.COLORS.DEFAULT

	local tColorServer	= Color(156, 241, 255, 200)
	local tColorClient	= Color(255, 241, 122, 200)

	if istable(sMsg) then sMsg=util.TableToJSON(sMsg, true); end

    return MsgC(
		tConfig.COLORS.DEFAULT,
		tConfig.PREFIX_DEFAULT,
        tColor,
		sPrefix,
        tConfig.COLORS.WHITE,
		" " .. string.format("%-60s", sMsg),
        SERVER and tColorServer or CLIENT and tColorClient,
        " STATE : " .. (SERVER and "SERVER" or "CLIENT").."\n",
        tConfig.COLORS.WHITE
    )
end

function LOADER:IncludeFiles(FileSource, tSide, tFileArgs, tSandEnv, bIsBinary)
	assert(isstring(FileSource) or isfunction(FileSource),				"[LOADER] The 'IncludeFiles' method requires a valid file path as a string or a function [#1]")
	assert(istable(tSide),												"[LOADER] The 'tSide' argument must be a table with 'client' and 'server' keys [#2]")
	assert((tFileArgs == nil) or istable(tFileArgs),					"[LOADER] The 'tFileArgs' argument must be a table or nil [#3]")

	if (SERVER and tSide.client and isstring(FileSource)) and not lovr.filesystem.isDirectory(FileSource) then
		-- AddCSLuaFile(FileSource)
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
				MsgC(Color(255, 0, 0), "[LOADER] Failed to include file: ", tostring(FileSource), "\n")
		)
	)
	or
		nil
end

function LOADER:GetDependencies(tDependencies, tSides, tSubLoader)
	assert(istable(tDependencies), "[LOADER] The 'getDependencies' method requires a table of dependencies")
	assert(istable(tSides), "[LOADER] The 'tSides' argument must be a table with 'client' and 'server' keys")

	local tDependenciesFinded	= {}

	local bShoulLoad			= (CLIENT and tSides.client) or (SERVER and tSides.server)
	if not bShoulLoad then return tDependenciesFinded end

	local tScopeSearch			= (istable(tSubLoader) and isfunction(tSubLoader.GetScript)) and tSubLoader or self
	for iID, sDependence in ipairs(tDependencies) do
		if not isstring(sDependence) then
			self:DebugPrint("[LOADER] Invalid dependency at index '"..iID.."': expected string, got "..type(sDependence), "WARNING")
			goto continue
		end

		tDependenciesFinded[sDependence]	= tScopeSearch:GetScript(sDependence)

		if tDependenciesFinded[sDependence] == nil then
			self:DebugPrint("[LOADER] The dependency '" .. sDependence .. "' was not found.", "WARNING") 
		end

		::continue::
	end

	return tDependenciesFinded
end

function LOADER:IncludeBinaryFile(sFilePath)
	require(sFilePath)
	local sModuleName		= string.match(sFilePath, "([^/\\]+)$")

	return self:DeepRawCopy(_G[sModuleName]) -- or use table.Copy ?
end

function LOADER:GetLuaFiles(sFolderPath, tFilesShared)
	if CLIENT then return end

	assert(isstring(sFolderPath), "[LOADER] GetLuaFiles requires a non-empty string path")

	tFilesShared		= istable(tFilesShared) and tFilesShared or {}
	local sCleanPath	= sFolderPath:sub(-1) == "/" and sFolderPath:sub(1, -2) or sFolderPath
	local bExists		= lovr.filesystem.isFile(sCleanPath)

	if not bExists then return self:DebugPrint("Path not found: " .. sCleanPath, "WARNING") end
		
	local tFiles, tDirs	= FilesFind(sCleanPath .. "/*", "LUA")

	for _, sFile in ipairs(tFiles) do
		local sPathFull = sCleanPath .. "/" .. sFile
		tFilesShared[#tFilesShared + 1] = sPathFull
	end
		
	for _, sDir in ipairs(tDirs) do 
		self:GetLuaFiles(sCleanPath .. "/" .. sDir, tFilesShared)
	end

	return tFilesShared
end

function LOADER:GetLibrariesBase(sBasePath, tParent)
	local function scan(p,t)t=t or{}for _,f in ipairs(FilesFind(p.."/*","LUA"))do t[#t+1]=p.."/"..f end for _,d in ipairs(select(2,FilesFind(p.."/*","LUA")))do scan(p.."/"..d,t) end return t end
	local function LoadInEnv(sPath) assert(isstring(sPath), "[LIBRARIES-LOADER] Path must be a string"); assert(lovr.filesystem.isFile(sPath, "LUA"), "[LIBRARIES-LOADER] File not found: " .. sPath); local bOk, fFunction = pcall(CompileFile, sPath); assert(bOk, "[LIBRARIES-LOADER] Compile error: " .. tostring(fFunction)); local tEnv	= setmetatable({ LIBRARY = {} }, { __index = _G }); local bOk, sErr = pcall(function() setfenv(fFunction, tEnv)() end); assert(bOk, "[LIBRARIES-LOADER] Compile error: " .. tostring(sErr)); return tEnv.LIBRARY end

	local tLibraries	= {}
	tLibraries.__PATH	= isstring(sBasePath) and sBasePath or "libraries"
	tLibraries.__BUFFER	= {}

	tLibraries.__Load		= function(sPath)
		local tBuffer	= {}
		local tBoth		= {
			["sh_"]	= function(sPath)
				-- return SERVER and (AddCSLuaFile(sPath) or true) or CLIENT
			end,
			["sv_"]	=	function(sPath)
				return SERVER
			end,
			["cl_"]	=	function(sPath)
				-- return SERVER and AddCSLuaFile(sPath) or CLIENT
			end,
		}
		tBoth["shared"]	= tBoth["sh_"]
		tBoth["server"]	= tBoth["sv_"]
		tBoth["client"]	= tBoth["cl_"]
		
		for iID, sFile in ipairs(scan(sPath)) do
			local sFileName									= sFile:match("([^/\\]+)%.lua$")
			local sLibFolder								= sFile:match("libraries/([^/\\]+)")
			local sPrefix									= sFileName:sub(1, 3)
			local fSide										= tBoth[sLibFolder] or tBoth[sPrefix] or tBoth["sh_"]

			if not fSide(sFile) then goto continue end
			tBuffer[sFile:match("libraries/(.-)%.lua$")]	= LoadInEnv(sFile)

			::continue::
		end

		return tBuffer
	end

	if istable(tParent) then
		tParent.GetLibrary	= function(self, sName)
			assert(isstring(sName) and #sName > 0, "[MODULE {LOADER}] Name must be a non-empty string")
			return self.__LIBRARIES.__BUFFER[sName]
		end

		tParent.PrintLibraries = function(self)
			if not istable(self.__LIBRARIES.__BUFFER) then
				return MsgC(Color(231, 76, 60), "[LIBRARY] No libraries loaded.\n")
			end
		
			for sID, _ in pairs(self.__LIBRARIES.__BUFFER) do
				MsgC(
					Color(52, 152, 219), "[LIBRARY] ",
					Color(46, 204, 113), "Loaded: ",
					Color(236, 240, 241), sID, "\n"
				)
			end
		end
	end

	return tLibraries
end

return LOADER