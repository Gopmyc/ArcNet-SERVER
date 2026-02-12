return function(sPath, tEnvironment)
	local sCode					= lovr.filesystem.read(sPath)
	if not sCode then
		return MsgC(Color(231, 76, 60), "[ENV-LOADER] Cannot read file: " .. sPath)
	end

	local fChunk, sCompileErr	= loadstring(sCode, sFileSource)
	if not fChunk then
		return MsgC(Color(231, 76, 60), "[ENV-LOADER] Compile error: " .. tostring(sCompileErr) .. " in file: " .. sPath)
	end

	setfenv(fChunk, tEnvironment)

	return fChunk
end