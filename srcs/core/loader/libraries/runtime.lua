LIBRARY.INSTANCES			= {}
LIBRARY.UPDATE_PIPELINE		= {}
LIBRARY.DRAW_PIPELINE		= {}

LIBRARY._INSTANCE_NODES		= setmetatable({}, { __mode = "k" })

LIBRARY._IN_UPDATE			= false
LIBRARY._IN_DRAW			= false
LIBRARY._PENDING_DESTROY	= {}

function LIBRARY:SetRuntimeConfig(tRuntimeConfig)
	assert(istable(tRuntimeConfig), "Runtime configuration must be a table")
	self.RUNTIME_CONFIG = tRuntimeConfig
end

function LIBRARY:Instantiate(sFileName, tFileRuntimeConfig, tArgs)
	assert(isstring(sFileName), "FileName must be a string")
	assert(
		istable(tFileRuntimeConfig) and
		istable(tFileRuntimeConfig.UPDATE) and
		istable(tFileRuntimeConfig.DRAW) and
		isstring(tFileRuntimeConfig.ID),
		"Runtime configuration must be a valid configuration"
	)

	self.INSTANCES[sFileName] = self.INSTANCES[sFileName] or {}

	if istable(self.INSTANCES[sFileName][tFileRuntimeConfig.ID]) then
		return MsgC(Color(231, 76, 60), "ERROR : Instance with ID '" .. tFileRuntimeConfig.ID .. "' already exists")
	end

	local tLibRess	= assert(self:GetLibrary("RESSOURCES"), "'RESSOURCES' library is required")
	local tClass	= assert(tLibRess:GetScript(sFileName), "File '" .. sFileName .. "' not found in RESSOURCES")

	local bSuccess, tInstance = xpcall(
		function()
			return tClass:Initialize(unpack(tArgs or {}))
		end,
		function(sErr)
			return MsgC(Color(231, 76, 60), "[ERROR] ", sErr, "\n", debug.traceback())
		end
	)

	if not bSuccess or not istable(tInstance) then
		return MsgC(Color(231, 76, 60), "[ERROR] Failed to instantiate '", sFileName, "'\n")
	end

	if not isfunction(tInstance.Destroy) then
		return MsgC(Color(241, 196, 15), "[WARNING] Instance has no Destroy method : Registration refused\n")
	end

	self.INSTANCES[sFileName][tFileRuntimeConfig.ID] = tInstance

	self:RegisterInstance(
		tInstance,
		tFileRuntimeConfig.UPDATE,
		tFileRuntimeConfig.DRAW
	)

	return tInstance
end

function LIBRARY:RegisterInstance(tInstance, tUpdateStage, tDrawStage)
	assert(istable(tInstance), "Instance must be a table")
	assert(self.RUNTIME_CONFIG, "Runtime configuration not set")

	self._INSTANCE_NODES[tInstance] = {}

	if istable(tUpdateStage) then
		local tStages	= self.RUNTIME_CONFIG.UPDATE
		local nStage	= tStages[tUpdateStage.STAGE]
		assert(isnumber(nStage), "Invalid UPDATE stage")

		local nOrder	= isnumber(tUpdateStage.ORDER) and tUpdateStage.ORDER or 0
		local nPriority	= nStage * 1000 + nOrder

		local tNode = {
			tInstance	= tInstance,
			nPriority	= nPriority,
			bEnabled	= true
		}

		self.UPDATE_PIPELINE[#self.UPDATE_PIPELINE + 1] = tNode
		self._INSTANCE_NODES[tInstance][#self._INSTANCE_NODES[tInstance] + 1] = tNode
	end

	if istable(tDrawStage) then
		local tStages	= self.RUNTIME_CONFIG.DRAW
		local nStage	= tStages[tDrawStage.STAGE]
		assert(isnumber(nStage), "Invalid DRAW stage")

		local nOrder	= isnumber(tDrawStage.ORDER) and tDrawStage.ORDER or 0
		local nPriority	= nStage * 1000 + nOrder

		local tNode = {
			tInstance	= tInstance,
			nPriority	= nPriority,
			bEnabled	= true
		}

		self.DRAW_PIPELINE[#self.DRAW_PIPELINE + 1] = tNode
		self._INSTANCE_NODES[tInstance][#self._INSTANCE_NODES[tInstance] + 1] = tNode
	end

	table.sort(self.UPDATE_PIPELINE, function(a, b)
		return a.nPriority < b.nPriority
	end)

	table.sort(self.DRAW_PIPELINE, function(a, b)
		return a.nPriority < b.nPriority
	end)
end

function LIBRARY:_CleanupPipeline(tPipeline)
	local iWrite = 1

	for iRead = 1, #tPipeline do
		local tNode = tPipeline[iRead]
		if istable(tNode) and tNode.bEnabled then
			tPipeline[iWrite] = tNode
			iWrite = iWrite + 1
		end
	end

	for i = iWrite, #tPipeline do
		tPipeline[i] = nil
	end
end

function LIBRARY:DestroyInstance(tInstance)
	assert(istable(tInstance), "Instance must be a table")

	if self._IN_UPDATE or self._IN_DRAW then
		self._PENDING_DESTROY[tInstance] = true
		return
	end

	self:_DestroyNow(tInstance)
end

function LIBRARY:_DestroyNow(tInstance)
	local tNodes = self._INSTANCE_NODES[tInstance]
	if not istable(tNodes) then return end

	for i = 1, #tNodes do
		tNodes[i].bEnabled = false
	end

	self._INSTANCE_NODES[tInstance] = nil

	xpcall(
		function()
			tInstance:Destroy()
		end,
		function(sErr)
			MsgC(
				Color(231, 76, 60),
				"[RUNTIME][DESTROY][ERROR] ",
				tostring(tInstance),
				"\n",
				sErr,
				"\n",
				debug.traceback()
			)
		end
	)

	self:_CleanupPipeline(self.UPDATE_PIPELINE)
	self:_CleanupPipeline(self.DRAW_PIPELINE)
end

function LIBRARY:_CommitPendingDestroy()
	if next(self._PENDING_DESTROY) == nil then return end

	for tInstance in pairs(self._PENDING_DESTROY) do
		self:_DestroyNow(tInstance)
	end

	self._PENDING_DESTROY = {}
end

function LIBRARY:DestroyAllInstances()
	for _, tGroup in pairs(self.INSTANCES) do
		for _, tInstance in pairs(tGroup) do
			self:DestroyInstance(tInstance)
		end
	end

	self.INSTANCES = {}
end

function LIBRARY:Update(...)
	self._IN_UPDATE = true
	local tArgs = {...}

	for i = 1, #self.UPDATE_PIPELINE do
		local tNode = self.UPDATE_PIPELINE[i]

		if not (istable(tNode) and tNode.bEnabled) then goto continue end

		local tInst = tNode.tInstance
		if not isfunction(tInst.Update) then goto continue end

		local bSuccess = xpcall(
			function()
				return tInst:Update(unpack(tArgs))
			end,
			function(sErr)
				MsgC(
					Color(231, 76, 60),
					"[RUNTIME][UPDATE][FAILED] ",
					tostring(tInst),
					"\n",
					sErr,
					"\n",
					debug.traceback()
				)
			end
		)

		if not bSuccess then
			self:DestroyInstance(tInst)
		end

		::continue::
	end

	self._IN_UPDATE = false
	self:_CommitPendingDestroy()
end

function LIBRARY:Draw(...)
	self._IN_DRAW = true
	local tArgs = {...}

	for i = 1, #self.DRAW_PIPELINE do
		local tNode = self.DRAW_PIPELINE[i]

		if not (istable(tNode) and tNode.bEnabled) then goto continue end

		local tInst = tNode.tInstance
		if not isfunction(tInst.Draw) then goto continue end

		local bSuccess = xpcall(
			function()
				return tInst:Draw(unpack(tArgs))
			end,
			function(sErr)
				MsgC(
					Color(231, 76, 60),
					"[RUNTIME][DRAW][FAILED] ",
					tostring(tInst),
					"\n",
					sErr,
					"\n",
					debug.traceback()
				)
			end
		)

		if not bSuccess then
			self:DestroyInstance(tInst)
		end

		::continue::
	end

	self._IN_DRAW = false
	self:_CommitPendingDestroy()
end

function LIBRARY:GetInstanceByID(sGroupID, sID)
	assert(isstring(sGroupID), "Group ID must be a string")

	local tGroup = self.INSTANCES[sGroupID]
	if not istable(tGroup) then return nil end

	if isstring(sID) then
		return tGroup[sID]
	end

	for _, v in pairs(tGroup) do
		return v
	end

	return nil
end