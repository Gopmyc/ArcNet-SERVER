SERVER			= true

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

MsgC			= function(...)
	local tArgs			= {...}
	local tCurrentColor	= {255,255,255}
	local sOutput		= ""

	for _, Arg in ipairs(tArgs) do
		if istable(Arg) and #Arg >= 3 then
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

Color			= function(iR, iG, iB)
	return {iR, iG, iB}
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

local CONFIGURATION_PATH	= "configuration/"
local LIBRARIES				= {
	YAML	= require("libraries/yaml"),
}

local LOADER    = require("srcs/core/loader/init"):Initialize(CONFIGURATION_PATH, LIBRARIES)