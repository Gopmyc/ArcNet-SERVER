local function fResolveField(tRoot, sPath)
	local tValue	= tRoot

	if sPath ~= "ROOT" then
		for sKey in string.gmatch(sPath, "[^%.]+") do
			if istable(tValue) then
				tValue	= tValue[sKey]
			else
				tValue	= nil
				break
			end
		end
	end

	return tValue
end

local function fGetConfigGroup(tConfig, sGroup)
	assert(istable(tConfig), "[SUBLOADER] Invalid argument: tConfig must be a table")
	assert(isstring(sGroup), "[SUBLOADER] Invalid argument: sGroup must be a string")

	local tGroup	= tConfig
	for _, sPart in ipairs(string.explode("/", sGroup)) do
		tGroup = tGroup and tGroup[sPart] or nil

		if not tGroup then
			MsgC(Color(231,76,60), "[SUBLOADER] Config segment not found: '"..sPart.."' in group '"..sGroup.." in configuration'")
			break
		end
	end

	return tGroup
end

local function fValidateGroup(sGroup, tGroup)
	if not istable(tGroup) then
		return false, "[SUBLOADER] Invalid config group '"..sGroup.."': expected table, got "..type(tGroup)
	end
	if not istable(tGroup.FILES) then
		return false, "[SUBLOADER] Missing 'FILES' table in group '"..sGroup.."'"
	end
	if not isstring(tGroup.FILES.SUBLOADER) then
		return false, "[SUBLOADER] Invalid 'FILES.SUBLOADER' in group '"..sGroup.."': expected string"
	end
	if not tGroup.FILES.CONTENT then
		return false, "[SUBLOADER] Missing 'FILES.CONTENT' in group '"..sGroup.."'"
	end
	return true
end

local function fValidateSubLoader(sGroup, tSubLoader)
	if not istable(tSubLoader) then
		return false, "[SUBLOADER] Sub-loader for group '"..sGroup.."' did not return a valid table"
	end
	if not (istable(tSubLoader[1]) and isfunction(tSubLoader[1].Initialize)) then
		return false, "[SUBLOADER] Sub-loader for group '"..sGroup.."' is missing a valid Initialize method"
	end
	return true
end

local SUBLOADER_BASE	= {}

function SUBLOADER_BASE:Initialize(tConfig, sBasePath, tLoader)
	local self	= setmetatable({
		INITIALIZED	= true,
		SUBLOADERS	= {},
		ATTRIBUTES	=
		{
			CONFIG		= tConfig,
			BASE_PATH	= sBasePath,
			LOADER		= tLoader,
		},
	}, {__index = SUBLOADER_BASE})

	return self
end

function SUBLOADER_BASE:InitializeGroup(sGroup)
	if not self.INITIALIZED then return MsgC(self:GetAttribute("LOADER"):GetConfig().DEBUG.COLORS.ERROR, "[LOADER] SubLoader base not initialize") end
	if not isstring(sGroup) then return MsgC(self:GetAttribute("LOADER"):GetConfig().DEBUG.COLORS.ERROR, "[LOADER] sGroup not a string : "..type(sGroup)) end

	local tConfig			= self:GetAttribute("CONFIG")
	local sBasePath			= self:GetAttribute("BASE_PATH")
	local tLoader			= self:GetAttribute("LOADER")
	local tGroup			= fGetConfigGroup(tConfig, sGroup)
	local bShouldLoad		= (tGroup.FILES.SHARED and CLIENT) or SERVER
	if not bShouldLoad then return end

	local bValid, sError	= fValidateGroup(sGroup, tGroup)
	if not bValid then
		return MsgC(tLoader:GetConfig().DEBUG.COLORS.ERROR, string.format("[LOADER] Group '%s' validation failed: %", sGroup, sError or "unknown"))
	end

	local sPath					= sBasePath .. tGroup.FILES.SUBLOADER
	local bSubOk, tSubLoader	= pcall(function() return tLoader:LoadSubLoader(sPath, tGroup.FILES.CONTENT, tGroup.FILES.SHARED, sGroup) end)
	if not bSubOk then
		return MsgC(tLoader:GetConfig().DEBUG.COLORS.ERROR, string.format("[LOADER] Failed to load SubLoader for '%s', sPath : '%s', ERROR : %s", sGroup, sPath, tSubLoader))
	end

	local bSubValid, sSubError = fValidateSubLoader(sGroup, tSubLoader)
	if not bSubValid then
		return MsgC(tLoader:GetConfig().DEBUG.COLORS.ERROR, string.format("[LOADER] SubLoader '%s' validation failed: %s", sGroup, sSubError or "unknown"))
	end

	MsgC(tLoader:GetConfig().DEBUG.COLORS.SUCCESS, "[LOADER] SubLoader for group '"..sGroup.."' loaded successfully !")

	local bInitOk, tInitialized = pcall(function() return tSubLoader[1]:Initialize(tSubLoader[2]) end)
	if not bInitOk then
		return MsgC(tLoader:GetConfig().DEBUG.COLORS.ERROR, string.format("[LOADER] SubLoader '%s' initialization failed ! ERROR : %s", sGroup, tInitialized))
	end

	self.SUBLOADERS[sGroup]	= tSubLoader

	return tSubLoader, tInitialized
end

function SUBLOADER_BASE:CheckFileStructureIntegrity(iID, tFile)
	for _, tRule in ipairs(self:GetAttribute("LOADER").RULES_FILES) do
		local sField	= tRule.FIELD
		local sType		= tRule.TYPE
		local fCheck	= _G["is" .. sType]

		if not isfunction(fCheck) then
			error("[OBJECTS SUB-LOADER] Unknown type checker 'is" .. sType .. "'")
		end

		if not fCheck(fResolveField(tFile, sField)) then
			return MsgC(
				self:GetAttribute("LOADER"):GetConfig().DEBUG.COLORS.ERROR,
				"[OBJECTS SUB-LOADER] Invalid field '" .. sField .. "' for ID : " .. iID
			)
		end
	end

	return true
end

function SUBLOADER_BASE:SetAttribute(sKey, Value)
	assert(isstring(sKey),	"[SUBLOADER_BASE] Key must be a string")
	assert(Value ~= nil,	"[SUBLOADER_BASE] Value cannot be nil")

	self.ATTRIBUTES[sKey] = Value
end

function SUBLOADER_BASE:GetAttribute(sKey)
	assert(isstring(sKey), 	"[SUBLOADER_BASE] Key must be a string")

	return self.ATTRIBUTES[sKey]
end

function SUBLOADER_BASE:GetSubLoaders()
	return self.SUBLOADERS
end

function SUBLOADER_BASE:GetSubLoader(sGroup)
	return self.SUBLOADERS[sGroup]
end	

return SUBLOADER_BASE