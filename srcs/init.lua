istable			= function(v) return type(v) == "table" end
isnumber		= function(v) return type(v) == "number" end
isstring		= function(v) return type(v) == "string" end
isbool			= function(v) return type(v) == "boolean" end
isfunction		= function(v) return type(v) == "function" end
isthread		= function(v) return type(v) == "thread" end
isuserdata		= function(v) return type(v) == "userdata" end

string.totable	= function(vInput)
	local tResult	= {}
	local sString	= tostring(vInput)

	for nIndex = 1, #sString do tResult[nIndex] = string.sub(sString, nIndex, nIndex) end

	return tResult
end

string.explode = function(sSeparator, sString, bWithPattern)
	if sSeparator == "" then return string.totable(sString) end
	if bWithPattern == nil then bWithPattern = false end

	local tResult			= {}
	local nCurrentPos		= 1

	for nIndex = 1, string.len(sString) do
		local nStartPos, nEndPos	= string.find(sString, sSeparator, nCurrentPos, not bWithPattern)

		if not nStartPos then break end
		tResult[nIndex]				= string.sub(sString, nCurrentPos, nStartPos - 1)
		nCurrentPos					= nEndPos + 1
	end

	tResult[#tResult + 1]	= string.sub(sString, nCurrentPos)

	return tResult
end

table.Copy = function(tTable, bDeep, tSeen)
	tSeen = (bDeep and tSeen) or nil
	if bDeep and istable(tSeen) and tSeen[tTable] then return tSeen[tTable] end

	local tCopy = {}
	if bDeep then
		tSeen			= tSeen or {}
		tSeen[tTable]	= tCopy
	end

	for kKey, vValue in pairs(tTable) do
		tCopy[kKey] = (bDeep and istable(vValue) and table.Copy(vValue, true, tSeen)) or vValue
	end

	return tCopy
end

Color			= function(iR, iG, iB)
	return {
		[1]		= iR,
		[2]		= iG,
		[3]		= iB,
		[4]		= 255,
		__hex	= string.format("#%02X%02X%02X", iR, iG, iB),
	}
end

MsgC			= function(...)
	local tArgs			= {...}
	local tCurrentColor	= {255,255,255}
	local sOutput		= ""

	for _, Arg in ipairs(tArgs) do
		if istable(Arg) then
			local iR, iG, iB	= Arg[1] or Arg.R or Arg.r, Arg[2] or Arg.G or Arg.g, Arg[3] or Arg.B or Arg.b
			if not (isnumber(iR) and isnumber(iG) and isnumber(iB)) then
				MsgC(Color(255, 0, 0), "[ERROR] Invalid color table passed to MsgC.")
				goto continue
			end
			if not isstring(Arg.__hex) then Arg=Color(iR, iG, iB); end

			tCurrentColor	= Arg
		else
			sOutput	= sOutput .. string.format(
				"\27[38;2;%d;%d;%dm%s\27[0m",
				tCurrentColor[1],
				tCurrentColor[2],
				tCurrentColor[3],
				tostring(Arg)
			)
		end

		::continue::
	end

	print(sOutput)
end

PrintTable			= function(tTable, sPrefix)
    sPrefix	= sPrefix or ""
    for Key, Value in pairs(tTable) do
        local sLine	= tostring(Key)
        if istable(Value) then
            MsgC(sPrefix .. "+--" .. sLine .. " : ")
            PrintTable(Value, sPrefix .. "|   ")
        else
            MsgC(sPrefix .. "+--" .. sLine .. " : " .. tostring(Value))
        end
    end
end

FilesFind		= function(sPath)
	local tFiles, tDirs = {}, {}

	for _, sItem in ipairs(lovr.filesystem.getDirectoryItems(sPath)) do
		local sFull = sPath .. "/" .. sItem

		table.insert(
			lovr.filesystem.isFile(sFull) and tFiles or
			lovr.filesystem.isDirectory(sFull) and tDirs
		, sItem)
	end

	return tFiles, tDirs
end

LoadFileInEnvironment	= function(sPath, tEnvironment)
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

local CONFIGURATION_PATH	= "configuration/"
local LIBRARIES				= {
	YAML		= require("libraries/yaml"),
	JSON		= require("libraries/json"),
	CHACHA20	= require("libraries/plc/chacha20"),
	POLY1305	= require("libraries/plc/poly1305"),
	LZW			= require("libraries/lzw"),
}

local LOADER    = require("srcs/core/loader/init"):Initialize(CONFIGURATION_PATH, LIBRARIES)

if SERVER then
	LOADER:Instanciate("networking", "server")
elseif CLIENT then
	LOADER:Instanciate("networking", "client", "localhost", 22122, 1, 200)
end


return LOADER