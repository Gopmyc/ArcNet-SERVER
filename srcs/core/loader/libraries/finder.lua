function LIBRARY:GetLuaFiles(sFolderPath, tFilesShared)
	assert(isstring(sFolderPath), "[FINDER] GetLuaFiles requires a non-empty string path")

	tFilesShared		= istable(tFilesShared) and tFilesShared or {}
	local sCleanPath	= sFolderPath:sub(-1) == "/" and sFolderPath:sub(1, -2) or sFolderPath
	local bExists		= lovr.filesystem.isDirectory(sCleanPath)

	if not bExists then
		return tFilesShared, MsgC(Color(241, 196, 15),  string.format("[WARNING] Path : '%s' not found.\n", sCleanPath))
	end
		
	local tFiles, tDirs	= FilesFind(sCleanPath)

	for _, sFile in ipairs(tFiles) do
		local sPathFull = sCleanPath .. "/" .. sFile
		tFilesShared[#tFilesShared + 1] = sPathFull
	end
		
	for _, sDir in ipairs(tDirs) do 
		self:GetLuaFiles(sCleanPath .. "/" .. sDir, tFilesShared)
	end

	return tFilesShared
end