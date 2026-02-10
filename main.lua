function lovr.load(tArgs)
	assert((tArgs[1] == "SERVER") or (tArgs[1] == "CLIENT"), "error: First argument must be either 'SERVER' or 'CLIENT', use : ./ArcNet-SERVER.exe 'SERVER' or : ./ArcNet-SERVER.exe 'CLIENT'")
	SERVER	= (tArgs[1] == "SERVER")
	CLIENT	= (tArgs[1] == "CLIENT")

	ArcNet = require("srcs")
end

function lovr.update(iDeltaTime)
	ArcNet:Update(iDeltaTime)
end

function lovr.draw(Pass)
	ArcNet:Draw(Pass)
end