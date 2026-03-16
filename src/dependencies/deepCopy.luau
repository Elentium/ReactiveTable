local function DeepCopy(tbl: { [any]: any })
	local copy = {}
	for key, value in tbl do
		if type(value) == "table" then
			copy[key] = DeepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

return DeepCopy
