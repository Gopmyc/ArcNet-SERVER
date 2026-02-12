local CONFIGURATION	= require("configuration/nexum")

local function SetGlobalByPath(sPath, Value)
	if not bSuccess then
		return print(Value)
	end

	local Last;
	local t	= _G
	for sPart in sPath:gmatch("[^%.]+") do
		if Last then
			t[Last]	= (type(t[Last]) ~= "table") and {} or t[Last]
			t		= t[Last]
		end
		Last	= sPart
	end
	t[Last]	= Value
end


local bSuccess, Content;
for iID, tGlobal in ipairs(CONFIGURATION.ENVIRONMENT) do
	if tGlobal.KEY and tGlobal.PATH then
		bSuccess, Content	= pcall(require, tGlobal.PATH)
		SetGlobalByPath(bSuccess and tGlobal.KEY or false, bSuccess and Content)
	end
end

for sKey, sPath in pairs(CONFIGURATION.LIBRARIES) do
	bSuccess, CONFIGURATION.LIBRARIES[sKey]	= pcall(require, sPath)
end

local LOADER    = require("srcs/core/loader/init"):Initialize(CONFIGURATION.CONFIGURATION_PATH, CONFIGURATION.LIBRARIES)

--- TEMPORARY BLOCK ---
if SERVER then
	LOADER:Instanciate("networking", "server")
elseif CLIENT then
	LOADER:Instanciate("networking", "client")
end
------------------------


return LOADER