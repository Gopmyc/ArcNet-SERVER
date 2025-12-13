

local LOADER = {
	PATH			= "srcs/core/loader/",
}

function LOADER:Initialize(sConfigPath, tLibraries)
	assert(isstring(sConfigPath), "[LOADER] Configuration path must be a string")
	assert(istable(tLibraries), "[LOADER] Libraries must be a table")

	local tLoader					= self:CreateLoaderInstance(self:LoadConfiguration(sConfigPath, tLibraries))

	-- It's not clean, it needs to be changed later
	local fMsgC	= MsgC
	MsgC	= function(...)
		return (istable(tLoader.CONFIG.DEBUG) and tLoader.CONFIG.DEBUG.ENABLED) and fMsgC(...) or (not istable(tLoader.CONFIG.DEBUG) and fMsgC(...))
	end

	tLoader.SUBLOADER_BASE			= self:InitializeSubloaders(tLoader, tLoader.CONFIG)

	return tLoader
end

function LOADER:CreateLoaderInstance(tConfig)
	local tLoaderConfig	= tConfig.LOADER
	if not istable(tLoaderConfig) then return error("[CONFIG-LOADER] Missing 'LOADER' configuration table") end
	tConfig.LOADER				= nil

	local tLoader				= setmetatable(tLoaderConfig, {__index = LOADER})
	tLoader.CONFIG				= tConfig
	
	tLoader.LIBRARIES			= tLoader.LIBRARIES or {}
	tLoader.LIBRARIES.BUFFER	= {}
	for sName, sPath in pairs(tLoader.LIBRARIES or {}) do
		if sName == "BUFFER" then goto continue end
		-- TODO : Handling shared files
		local tEnv		= setmetatable({ LIBRARY = {} }, { __index = _G })
		local fChunk	= LoadFileInEnvironment(sPath, tEnv)

		local bOk, sRunErr = pcall(fChunk)
		if not bOk then
			MsgC(tLoader.CONFIG.DEBUG.COLORS.ERROR, "[ENV-LOADER] Runtime error: " .. tostring(sRunErr))
		end

		tLoader.LIBRARIES[sName]		= nil
		tLoader.LIBRARIES.BUFFER[sName]	= tEnv.LIBRARY

		::continue::
	end

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

function LOADER:LoadSubLoader(sPath, Content, bShared, sID)
	assert(isstring(sPath), "[SUB-LOADER] Path must be a string")
	assert(Content ~= nil, "[SUB-LOADER] Content must be a table")
	assert(isbool(bShared), "[SUB-LOADER] Shared flag must be a boolean")

	if bShared and SERVER then
		self:GetLibrary("RESSOURCES"):AddCSLuaFile(sPath)
	end

	local bShouldLoad	= (bShared and CLIENT) or SERVER
	if bShouldLoad then
		local tSubLoader	= self:GetLibrary("RESSOURCES"):LoadInEnv(sPath,
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
					local FileLoaded = self:GetLoader():GetLibrary("RESSOURCES"):GetScript(sName)

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

function LOADER:GetLibrariesBase(sBasePath, tParent)
	local function scan(p,t)t=t or{}for _,f in ipairs(FilesFind(p.."/*"))do t[#t+1]=p.."/"..f end for _,d in ipairs(select(2,FilesFind(p.."/*")))do scan(p.."/"..d,t) end return t end

	local tLibraries	= {}
	tLibraries.PATH		= isstring(sBasePath) and sBasePath or "libraries"
	tLibraries.BUFFER	= {}

	tLibraries.Load	= function(tLibraries, sPath)
		assert(isstring(sPath), "[LIBRARY {LOADER}] Path must be a string")

		local tBoth		= {
			["sh_"]	= function(sPath)
				return SERVER and (self:GetLibrary("RESSOURCES"):AddCSLuaFile(sPath) or true) or CLIENT
			end,
			["sv_"]	=	function(sPath)
				return SERVER
			end,
			["cl_"]	=	function(sPath)
				return SERVER and self:GetLibrary("RESSOURCES"):AddCSLuaFile(sPath) or CLIENT
			end,
		}
		tBoth["shared"]	= tBoth["sh_"]
		tBoth["server"]	= tBoth["sv_"]
		tBoth["client"]	= tBoth["cl_"]
		
		for iID, sFile in ipairs(self:GetLuaFiles(sPath)) do
			local sFileName															= sFile:match("([^/\\]+)%.lua$")
			local sLibFolder														= sFile:match("libraries/([^/\\]+)")
			local sPrefix															= sFileName:sub(1, 3)
			local fSide																= tBoth[sLibFolder] or tBoth[sPrefix] or tBoth["sh_"]

			if not fSide(sFile) then goto continue end
			tLibraries.BUFFER[string.upper(sFile:match("libraries/(.-)%.lua$"))]	= self:GetLibrary("RESSOURCES"):LoadInEnv(sFile, { LIBRARY = {} }, "LIBRARY", {}, false)

			::continue::
		end
	end

	if istable(tParent) then
		tParent.GetLibrary		= LOADER.GetLibrary
		tParent.PrintLibraries	= LOADER.PrintLibraries
	end

	return tLibraries
end

function LOADER:GetLibrary(sName)
	assert(isstring(sName) and #sName > 0, "[LIBRARY] Library name must be a non-empty string")
	return (self.LIBRARIES and self.LIBRARIES.BUFFER and self.LIBRARIES.BUFFER[sName])
		or MsgC(Color(231, 76, 60), "[LIBRARY] Library not found: " .. sName .. "\n")
end

function LOADER:PrintLibraries()
	if not istable(self.LIBRARIES) then
		return MsgC(self:GetConfig().DEBUG.COLORS.ERROR, "[LIBRARY] 'LIBRARIES' table not initialized.\n")
	end

	if not istable(self.LIBRARIES.BUFFER) or not next(self.LIBRARIES.BUFFER) then
		return MsgC(self:GetConfig().DEBUG.COLORS.ERROR, "[LIBRARY] No libraries loaded.\n")
	end
		
	for sID, _ in pairs(self.LIBRARIES.BUFFER) do
		MsgC(
			Color(52, 152, 219), "[LIBRARY] ",
			Color(46, 204, 113), "Loaded: ",
			Color(236, 240, 241), sID, "\n"
		)
	end
end

return LOADER