return function(vInput)
	local tResult	= {}
	local sString	= tostring(vInput)

	for nIndex = 1, #sString do tResult[nIndex] = string.sub(sString, nIndex, nIndex) end

	return tResult
end