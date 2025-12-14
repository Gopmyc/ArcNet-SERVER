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
		if not self:GetLoader():GetSubLoaderBase():CheckFileStructureIntegrity(iID, tFile) then goto continue end

		self.__BUFFER[tFile.KEY] = self:LoadFile(tFile)

		::continue::
	end

	self.__Initialized						= true

	return self.__BUFFER
end

function SUBLOADER:LoadFile(tFile, fChunk)
	local bIsReload		= isfunction(fChunk)
	local bShared		= self.tFileSides.client
	local _				= self:GetLoader():GetLibrary("RESSOURCES"):IncludeFiles(bIsReload and fChunk or tFile.PATH, self.tFileSides, nil, self:GetEnv())

	MsgC(self:GetLoader():GetConfig().DEBUG.COLORS[self:GetID()], "\tThe file '" .. tFile.KEY .. "' was " .. (bIsReload and "reload" or "loaded") .." successfully for " .. self:GetID())

	return _, bShared
end