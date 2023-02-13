--!strict

-- // Package

-- // Variables

-- // Functions

local function optionalParam<a>(param: a?, defaultValue: a): a
	if param == nil and defaultValue ~= nil then
		return defaultValue
	elseif param ~= nil then
		return param
	end
	return defaultValue
end

return optionalParam
