local ArcNet = require("srcs")

function lovr.load() end
function lovr.update(iDeltaTime)
	ArcNet:Update(iDeltaTime)
end

function lovr.draw(Pass)
	ArcNet:Draw(Pass)
end