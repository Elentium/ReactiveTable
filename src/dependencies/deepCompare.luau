type table = { [any]: any }

local function DeepEquals(t1: table, t2: table): boolean
	local checkedKeys: { [any]: boolean } = {}
	for k, v in t1 do
		if type(v) == "table" then
			if not DeepEquals(t2[k], v) then
				return false
			end
		elseif t2[k] ~= v then
			return false
		end
		checkedKeys[k] = true
	end
	for k, v in t2 do
		if checkedKeys[k] then
			continue
		end
		if type(v) == "table" then
			if not DeepEquals(t1[k], v) then
				return false
			end
		elseif t1[k] ~= v then
			return false
		end
	end

	return true
end

return DeepEquals
