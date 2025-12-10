SUBLOADER.__ENV			= {
	ACCESS_POINT	= "CLASS",
	CONTENT			=
	{
		CLASS	= (function()
			local _			= {}
			
			_.__index		= _

			return _
		end)()
	},
}
SUBLOADER.tFileSides	= {client = true, server = true} -- > To avoid repetition and a little optimization

function SUBLOADER:Initialize(tContent)
	assert(istable(tContent),			"[CLASSES SUB-LOADER] Content must be a table")
	assert(isfunction(self.GetLoader),	"[CLASSES SUB-LOADER] Loader access method is missing")

	self.__ENV.CONTENT.CLASS.__LIBRARIES	= self:GetLoader():GetLibrariesBase("libraries", self.__ENV.CONTENT.CLASS)
	self.__BUFFER							= {}

	for iID, tFile in ipairs(tContent) do
		if not (istable(tFile) and isstring(tFile.path) and isstring(tFile.key)) then
			self:GetLoader():DebugPrint("Invalid file entry at index '" ..iID.. "' for " .. self:GetID(), "ERROR")
			goto continue
		end

		self.__BUFFER[tFile.key] = self:LoadFile(tFile)

		::continue::
	end

	self.__Initialized						= true

	return self.__BUFFER
end

function SUBLOADER:LoadFile(tFile, fChunk)
	assert(istable(tFile),			"[CLASSES SUB-LOADER] File entry must be a table")
	assert(isstring(tFile.path),	"[CLASSES SUB-LOADER] File entry 'path' must be a string")
	assert(isstring(tFile.key),		"[CLASSES SUB-LOADER] File entry 'key' must be a string")

	local bIsReload		= isfunction(fChunk)
	local bShared		= self.tFileSides.client
	local _				= self:GetLoader():IncludeFiles(bIsReload and fChunk or tFile.path, self.tFileSides, nil, self:GetEnv())

	self:GetLoader():DebugPrint("The file '" .. tFile.key .. "' was " .. (bIsReload and "reload" or "loaded") .." successfully", self:GetID())

	return _, bShared
end