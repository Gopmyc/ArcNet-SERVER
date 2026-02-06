LIBRARY.INSTANCES		= {}
LIBRARY.UPDATE_PIPELINE	= {}
LIBRARY.DRAW_PIPELINE	= {}

function LIBRARY:SetRuntimeConfig(tRuntimeConfig)
	assert(istable(tRuntimeConfig), "Runtime configuration must be a table")
	self.RUNTIME_CONFIG = tRuntimeConfig
end

function LIBRARY:Instantiate(sFileName, tFileRuntimeConfig)
	assert(isstring(sFileName), "FileName must be a string")
	assert(istable(tFileRuntimeConfig) and istable(tFileRuntimeConfig.UPDATE) and istable(tFileRuntimeConfig.DRAW), "Runtime configuration must be a valid configuration")

	local tLibRess	= assert(self:GetLibrary("RESSOURCES"), "'RESSOURCES' library is required")
	local tClass	= assert(tLibRess:GetScript(sFileName), "File '" .. sFileName .. "' not found in RESSOURCES")

	local bSuccess, tInstance = xpcall(
		function()
			return tClass:Initialize()
		end,
		function(sErr)
			return MsgC(Color(231, 76, 60), "[ERROR] " .. sErr .. "\n" .. debug.traceback())
		end
	)

	if not bSuccess or not istable(tInstance) then
		return MsgC(Color(231, 76, 60), "[ERROR] Failed to instantiate '" .. sFileName .. "'\n")
	end

	self.INSTANCES[#self.INSTANCES + 1] = tInstance

	tInstance.STAGE_UPDATE				= tFileRuntimeConfig.UPDATE
	tInstance.STAGE_DRAW				= tFileRuntimeConfig.DRAW

	self:RegisterInstance(tInstance)

	return tInstance
end

function LIBRARY:RegisterInstance(tInstance)
	assert(istable(tInstance),	"Instance must be a table")
	assert(self.RUNTIME_CONFIG,	"Runtime configuration not set")

	if istable(tInstance.STAGE_UPDATE) then
		assert(isstring(tInstance.STAGE_UPDATE.STAGE),	"STAGE_UPDATE.STAGE must be a string")
		assert(isnumber(tInstance.STAGE_UPDATE.ORDER),	"STAGE_UPDATE.ORDER must be a number or nil")

		local tStages	= self.RUNTIME_CONFIG.UPDATE
		local nStage	= tStages[tInstance.STAGE_UPDATE.STAGE]

		assert(isnumber(nStage), "Invalid UPDATE stage '" .. tInstance.STAGE_UPDATE.STAGE .. "'")

		local nOrder	= isnumber(tInstance.STAGE_UPDATE.ORDER) and tInstance.STAGE_UPDATE.ORDER or 0
		local nPriority	= nStage * 1000 + nOrder

		self.UPDATE_PIPELINE[#self.UPDATE_PIPELINE + 1] = {
			tInstance	= tInstance,
			nPriority	= nPriority,
			bEnabled	= true,
		}
	end

	if istable(tInstance.STAGE_DRAW) then
		assert(isstring(tInstance.STAGE_DRAW.STAGE),	"STAGE_DRAW.STAGE must be a string")
		assert(isnumber(tInstance.STAGE_DRAW.ORDER),	"STAGE_DRAW.ORDER must be a number or nil")

		local tStages	= self.RUNTIME_CONFIG.DRAW
		local nStage	= tStages[tInstance.STAGE_DRAW.STAGE]

		assert(isnumber(nStage), "Invalid DRAW stage '" .. tInstance.STAGE_DRAW.STAGE .. "'")

		local nOrder	= isnumber(tInstance.STAGE_DRAW.ORDER) and tInstance.STAGE_DRAW.ORDER or 0
		local nPriority	= nStage * 1000 + nOrder

		self.DRAW_PIPELINE[#self.DRAW_PIPELINE + 1] = {
			tInstance	= tInstance,
			nPriority	= nPriority,
			bEnabled	= true,
		}
	end

	table.sort(self.UPDATE_PIPELINE, function(a, b)
		return a.nPriority < b.nPriority
	end)

	table.sort(self.DRAW_PIPELINE, function(a, b)
		return a.nPriority < b.nPriority
	end)
end

function LIBRARY:Update(...)
	local tArgs	= {...}

	for i = 1, #self.UPDATE_PIPELINE do
		local tNode	= self.UPDATE_PIPELINE[i]

		if not tNode.bEnabled then goto continue end

		local tInst		= tNode.tInstance
		if not isfunction(tInst.Update) then goto continue end

		local bSuccess	= xpcall(
			function()
				return tInst:Update(unpack(tArgs))
			end,
			function(sErr)
				MsgC(
					Color(231, 76, 60),
					"[RUNTIME][UPDATE][DISABLED] ",
					tostring(tInst),
					"\n",
					sErr,
					"\n",
					debug.traceback()
				)
			end
		)

		if not bSuccess then tNode.bEnabled=false; end

		::continue::
	end
end

function LIBRARY:Draw(...)
	local tArgs	= {...}
	
	for i = 1, #self.DRAW_PIPELINE do
		local tNode	= self.DRAW_PIPELINE[i]

		if not tNode.bEnabled then goto continue end
		
		local tInst		= tNode.tInstance
		if not isfunction(tInst.Draw) then goto continue end

		local bSuccess	= xpcall(
			function()
				return tInst:Draw(unpack(tArgs))
			end,
			function(sErr)
				MsgC(
					Color(231, 76, 60),
					"[RUNTIME][DRAW][DISABLED] ",
					tostring(tInst),
					"\n",
					sErr,
					"\n",
					debug.traceback()
				)
			end
		)

		if not bSuccess then tNode.bEnabled=false; end

		::continue::
	end
end