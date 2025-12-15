SUBLOADER.__ENV	= {
	ACCESS_POINT	= "CORE",
	CONTENT			=
	{
		CORE	= (function()
			local _			= {}
			
			_.__index		= _

			return _
		end)()
	},
}

function SUBLOADER:Initialize(tContent)
	assert(istable(tContent),			"[OBJECTS SUB-LOADER] Content must be a table")
	assert(isfunction(self.GetLoader),	"[OBJECTS SUB-LOADER] Loader access method is missing")

	self.__ENV.CONTENT.CORE.__LIBRARIES	= self:GetLoader():GetLibrariesBase("libraries", self.__ENV.CONTENT.CORE)
	self.__BUFFER						= {}
		
	for iID, tFile in ipairs(tContent) do
		if not self:GetLoader():GetSubLoaderBase():CheckFileStructureIntegrity(iID, tFile) then goto continue end

		self.__BUFFER[tFile.KEY]	= self:LoadFile(tFile)

		::continue::
	end

	self.__Initialized					= true

	return self.__BUFFER
end

function SUBLOADER:LoadFile(tFile, fChunk)
	local bIsReload		= isfunction(fChunk)
	local bShared		= tFile.SIDES.CLIENT
	local tDependencies	= self:GetLoader():GetLibrary("RESSOURCES"):ResolveDependencies(tFile.ARGS, tFile.SIDES, self)
	local tCapabilities	= self:GetLoader():GetLibrary("RESSOURCES"):ResolveCapabilities(self:GetLoader():GetConfig(), tFile.CAPABILITIES)

	if not istable(tDependencies) and (#tFile.ARGS > 0) then 
		return MsgC(
			self:GetLoader():GetConfig().DEBUG.COLORS.ERROR,
			"[OBJECTS SUB-LOADER] The dependencies for the file '" ..tFile.KEY.. "' could not be resolved."
		)
	end

	local _				= self:GetLoader():GetLibrary("RESSOURCES"):IncludeFiles(
		bIsReload and fChunk or tFile.PATH,
		tFile.SIDES,
		tDependencies,
		self:GetEnv(),
		tFile.IS_BINARY,
		tFile.LOAD_SUBFOLDERS,
		tCapabilities
	)

	MsgC(
		self:GetLoader():GetConfig().DEBUG.COLORS[self:GetID()],
		"\tThe file '" .. tFile.KEY .. "' was " .. (bIsReload and "reload" or "loaded") .." successfully for " .. self:GetID()
	)

	return _, bShared
end