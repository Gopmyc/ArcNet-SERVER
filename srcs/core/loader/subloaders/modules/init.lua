SUBLOADER.__ENV	= {
	ACCESS_POINT	= "MODULE",
	CONTENT			=
	{
		MODULE	= (function()
			local _			= {}
			
			_.__index		= _

			return _
		end)()
	},
}

function SUBLOADER:Initialize(tContent)
	assert(istable(tContent),			"[MODULES SUB-LOADER] Content must be a table")
	assert(isfunction(self.GetLoader),	"[MODULES SUB-LOADER] Loader access method is missing")

	self.__ENV.CONTENT.MODULE.__LIBRARIES	= self:GetLoader():GetLibrariesBase("libraries", self.__ENV.CONTENT.MODULE)
	self.__BUFFER							= {}

	for sID, tFile in ipairs(tContent) do
		if not (istable(tFile) and isstring(tFile.path) and istable(tFile.sides) and isstring(tFile.key) and istable(tFile.args)) then
			self:GetLoader():DebugPrint("Invalid file entry at index '" ..iID.. "' for " .. self:GetID(), "ERROR")
			goto continue
		end

		self.__BUFFER[tFile.key]	= self:LoadFile(tFile)
		::continue::
	end

	self.__Initialized						= true

	return self.__BUFFER
end

function SUBLOADER:LoadFile(tFile, fChunk)
	assert(istable(tFile),			"[MODULES SUB-LOADER] File entry must be a table")
	assert(isstring(tFile.path),	"[MODULES SUB-LOADER] File entry 'path' must be a string")
	assert(istable(tFile.sides),	"[MODULES SUB-LOADER] File entry 'sides' must be a table")
	assert(isstring(tFile.key),		"[MODULES SUB-LOADER] File entry 'key' must be a string")
	assert(istable(tFile.args),		"[MODULES SUB-LOADER] File entry 'args' must be a table")

	local bIsReload		= isfunction(fChunk)
	local bShared		= tFile.sides.client
	local tDependencies	= self:GetLoader():GetDependencies(tFile.args, tFile.sides, self)

	if not istable(tDependencies) and (#tFile.args > 0) then 
		return self:GetLoader():DebugPrint("The dependencies for the file '" ..tFile.key.. "' could not be resolved.", "ERROR")
	end

	local _				= self:GetLoader():IncludeFiles(bIsReload and fChunk or tFile.path, tFile.sides, tDependencies, self:GetEnv())

	self:GetLoader():DebugPrint("The file '" .. tFile.key .. "' was " .. (bIsReload and "reload" or "loaded") .." successfully", self:GetID())

	return _, bShared
end