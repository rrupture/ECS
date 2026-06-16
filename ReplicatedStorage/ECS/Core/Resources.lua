local Resources = {}
Resources.__index = Resources

function Resources.new()
	local self = setmetatable({}, Resources)
	self._data = {}
	return self
end

-- store a global value by name
function Resources:Set(name, value)
	self._data[name] = value
end

-- get a global value by name
function Resources:Get(name)
	return self._data[name]
end

-- check if a resource exists
function Resources:Has(name)
	return self._data[name] ~= nil
end

-- remove a resource
function Resources:Delete(name)
	self._data[name] = nil
end

return Resources