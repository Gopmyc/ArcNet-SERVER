return function(tTable, sPrefix)
    sPrefix	= sPrefix or ""
    for Key, Value in pairs(tTable) do
        local sLine	= tostring(Key)
        if IsTable(Value) then
            MsgC(sPrefix .. "+--" .. sLine .. " : ")
            PrintTable(Value, sPrefix .. "|   ")
        else
            MsgC(sPrefix .. "+--" .. sLine .. " : " .. tostring(Value))
        end
    end
end