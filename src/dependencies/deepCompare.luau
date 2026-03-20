type table = { [any]: any }

type pairMemo = { [any]: { [any]: boolean } }

local function normalizeValue(value: any): (string, any)
	local valueType = type(value)
	if valueType == "userdata" and getmetatable(value) == "ReactiveTable" then
		local ok, source = pcall(function()
			return value:GetSource()
		end)
		if ok and type(source) == "table" then
			return "reactive", source
		end
	end
	return valueType, value
end

local function deepCompareValue(v1: any, v2: any, visitedPairs: pairMemo): boolean
	local t1, n1 = normalizeValue(v1)
	local t2, n2 = normalizeValue(v2)
	if t1 ~= t2 then
		return false
	end
	if t1 ~= "table" and t1 ~= "reactive" then
		return n1 == n2
	end

	local row = visitedPairs[n1]
	if row and row[n2] then
		return true
	end
	if row then
		row[n2] = true
	else
		visitedPairs[n1] = { [n2] = true }
	end

	for k, value1 in n1 do
		if not deepCompareValue(value1, n2[k], visitedPairs) then
			return false
		end
	end
	for k, _ in n2 do
		if n1[k] == nil then
			return false
		end
	end

	return true
end

local function deepCompare(t1: table, t2: table): boolean
	return deepCompareValue(t1, t2, {})
end

return deepCompare
