type table = { [any]: any }

local function deepCopyValue(value: any, memo: table): any
	local valueType = type(value)
	if valueType == "table" then
		local existing = memo[value]
		if existing ~= nil then
			return existing
		end
		local copy: table = {}
		memo[value] = copy
		for key, inner in value do
			copy[key] = deepCopyValue(inner, memo)
		end
		return copy
	elseif valueType == "userdata" then
		local isReactive = getmetatable(value) == "ReactiveTable"
		if not isReactive then
			return value
		end
		local existing = memo[value]
		if existing ~= nil then
			return existing
		end
		local clone = value:Clone(true)
		memo[value] = clone
		return clone
	end
	return value
end

local function deepCopy(tbl: table): table
	return deepCopyValue(tbl, {})
end

return deepCopy
