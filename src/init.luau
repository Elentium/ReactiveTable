--!strict
--[[
	[UNRELEASED] [BETA]
	ReactiveTable V0.1.0
	by IAMNOTULTRA3 (a.k.a Elite, Elentium)
	Apache 2.0 License
	
	DX-Oriented convenient table implementation
	
	Warnings:
	- Due to LuaU limitations, nested tables do not have ReactiveTable `Signals` autocomplete,
		Example:
		```luau
			local ReactiveTable = require(path.to.module)
			
			local reactive = ReactiveTable.new({
				nested1 = {
					abc = "hello"
				},
				nested2 = {}
			})
			
			-- attempt to access value
			reactive. <-- the autocomplete shows both Signals and the attributes
			
			reactive.nested1. <-- the autocomplete only shows the attributes, but cannot show the Signals
		```
	- This library prioritizes developer experience over pure performance
	Credits:
	Stravant for the Signal implementation
]]
--------------------------------------------------------------------------------
-- TYPE DEFINITIONS
--------------------------------------------------------------------------------
export type SignalConnection = {
	Connected: boolean,

	Disconnect: (self: SignalConnection) -> (),
}
export type SignalPublic<T... = ()> = {
	Connect: (self: any, (T...) -> ()) -> SignalConnection,
	Wait: (self: any) -> T...,
	Once: (self: any, (T...) -> ()) -> SignalConnection,
}

export type SignalPrivate<T... = ()> = SignalPublic<T...> & {
	Fire: (self: any, T...) -> (),
}

export type Signals = {
	-- <key, value>
	Changed: SignalPublic<any, any>,
	New: SignalPublic<any, any>,
	Removed: SignalPublic<any>,
} & { [string]: any }

export type ReactiveTable<T = {}> = T & Signals & {
	GetSource: (self: any) -> T,
	IsFrozen: (self: any) -> boolean,
	AreSignalsFrozen: (self: any) -> boolean,

	Destroy: (self: any) -> (),
	Clone: (self: any, deepClone: boolean?) -> ReactiveTable<T>,

	Insert: (self: any, value: any) -> () & (self: any, index: number, value: any) -> (),
	Remove: ((self: any) -> any) & (self: any, index: number) -> any,
	Find: (self: any, needle: any, init: number?) -> number?,
	Sort: (self: any, comp: ((any, any) -> boolean)?) -> (),
	Clear: (self: any) -> (),

	Compare: (self: any, other: any) -> boolean,
	BindToKeyChanged: (self: any, key: any, callback: (newValue: any) -> ()) -> SignalConnection,
	BroadcastChanges: (self: any, changedKeys: { any }) -> (),

	FreezeSignals: (self: any) -> (),
	UnfreezeSignals: (self: any) -> (),

	Freeze: (self: any) -> (),
	Unfreeze: (self: any) -> (),
}

type userdata = any

type registry = {
	[userdata]: {
		_table: { [any]: any },
		_frozen: boolean,
		_signalsFrozen: boolean,
		_signals: Signals,
		_ancestors: { [userdata]: any }, -- [ancestor]: key
	},
}
--------------------------------------------------------------------------------
-- DEPENDENCIES
--------------------------------------------------------------------------------
local deepCopy = require("@self/dependencies/deepCopy")
local deepCompare = require("@self/dependencies/deepCompare")
local signal = require("@self/dependencies/signal")

--------------------------------------------------------------------------------
-- VARIABLES
--------------------------------------------------------------------------------
local ReactiveTable = {}

local new: any
local weakKey = { __mode = "k" }

local tableLookup: { [{ [any]: any }]: userdata } = setmetatable({}, weakKey) :: { [{ [any]: any }]: userdata }
local registry: registry = setmetatable({}, weakKey) :: registry

--------------------------------------------------------------------------------
-- METHODS & METAMETHODS
--------------------------------------------------------------------------------
local methods = {
	--[[
    Destroys the ReactiveTable object

    @param self – The ReactiveTable object
    ]]
	Destroy = function(self: userdata): ()
		local reg = registry[self]
		if not reg then
			error(`Invalid or already destroyed userdata`)
		end
		tableLookup[reg._table] = nil

		for _, signal in reg._signals do
			signal:DisconnectAll()
		end

		registry[self] = nil
	end,

	--[[
    Inserts a value into the ReactiveTable object

    @param self – The ReactiveTable object
    @param value – The value to insert
    @optional @param index – The index to insert the value at
    ]]
	Insert = function(self: userdata, value: any, index: number?): ()
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end
		if reg._frozen then
			error(`Attempt to modify frozen ReactiveTable`)
		end

		local _table = reg._table
		local _signals = reg._signals
		local _ancestors = reg._ancestors

		local wrap = value
		local idx: number
		if index then
			table.insert(_table, index, value)
			idx = index
		else
			table.insert(_table, value)
			idx = #_table
		end
		if type(value) == "table" then
			wrap = new(value, self, idx)
		end
		if not reg._signalsFrozen then
			(_signals.New :: SignalPrivate<any, any>):Fire(idx, wrap)
			for _ancestor, _ancestorKey in _ancestors do
				local ancestorRegistry = registry[_ancestor];
				(ancestorRegistry._signals.Changed :: SignalPrivate<any, any>):Fire(_ancestorKey, self)
			end
		end
	end,

	--[[
    Removes a value from the ReactiveTable object

    @param self – The ReactiveTable object
    @optional @param index – The index to remove the value from
    @returns The removed value
    ]]
	Remove = function(self: userdata, index: number?): any
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end
		if reg._frozen then
			error(`Attempt to modify frozen ReactiveTable`)
		end

		local _table = reg._table
		local _signals = reg._signals
		local _ancestors = reg._ancestors

		local value
		local idx: number
		if index then
			value = table.remove(_table, index)
			idx = index
		else
			idx = #_table
			value = table.remove(_table)
		end

		if type(value) == "table" then
			local referencesExist = false
			for k, v in _table do
				if k ~= idx and v == value then
					referencesExist = true
					break
				end
			end
			if not referencesExist then
				local prevRegistry = registry[tableLookup[value]]
				if prevRegistry then
					prevRegistry._ancestors[self] = nil
				end
			end
		end

		if not reg._signalsFrozen then
			(_signals.Removed :: SignalPrivate<any, any>):Fire(idx, value)
			for _ancestor, _ancestorKey in _ancestors do
				local ancestorRegistry = registry[_ancestor];
				(ancestorRegistry._signals.Changed :: SignalPrivate<any, any>):Fire(_ancestorKey, self)
			end
		end

		return value
	end,

	--[[
    Finds the index of a value in the ReactiveTable object

    @param self – The ReactiveTable object
    @param needle – The value to find
    @optional @param init – The index to start the search at
    @returns The index of the value, or nil if not found
    ]]
	Find = function(self: userdata, needle: any, init: number?): number?
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		local _table = reg._table
		local wrap = needle
		if type(needle) == "userdata" then
			local needleRegistry = registry[needle]
			if needleRegistry then
				wrap = needleRegistry._table
			end
		end
		return table.find(_table, wrap, init)
	end,

	--[[
    Clears the ReactiveTable object (array cleanup, will not work for dictionaries)

    @param self – The ReactiveTable object
    ]]
	Clear = function(self: userdata): ()
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end
		if reg._frozen then
			error(`Attempt to modify frozen ReactiveTable`)
		end

		local _table = reg._table
		local _signals = reg._signals
		local _signalsFrozen = reg._signalsFrozen
		local _ancestors = reg._ancestors

		local changed = false
		for i = #_table, 1, -1 do
			local value = _table[i]
			_table[i] = nil
			if type(value) == "table" then
				local referencesExist = false
				for k, v in _table do
					if v == value then
						referencesExist = true
						break
					end
				end
				if not referencesExist then
					local prevRegistry = registry[tableLookup[value]]
					if prevRegistry then
						prevRegistry._ancestors[self] = nil
					end
				end
				value = tableLookup[value]
			end
			if not _signalsFrozen then
				(_signals.Removed :: SignalPrivate<any, any>):Fire(i, value)
			end
			changed = true
		end
		if changed and not _signalsFrozen then
			for _ancestor, _ancestorKey in _ancestors do
				local ancestorRegistry = registry[_ancestor];
				(ancestorRegistry._signals.Changed :: SignalPrivate<any, any>):Fire(_ancestorKey, self)
			end
		end
	end,

	--[[
    Sorts the ReactiveTable object

    @param self – The ReactiveTable object
    @param comparator – The comparator function
    ]]
	Sort = function(self: userdata, comparator: (any, any) -> boolean): ()
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end
		if reg._frozen then
			error(`Attempt to modify frozen ReactiveTable`)
		end

		local _table = reg._table
		table.sort(_table, comparator)
	end,

	--[[
    Binds a callback to the Changed signal of a key in the ReactiveTable object

    @param self – The ReactiveTable object
    @param key – The key to bind the callback to
    @param callback – The callback function
    @returns A SignalConnection object
    ]]
	BindToKeyChanged = function(self: userdata, key: any, callback: (value: any) -> ()): SignalConnection
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		local _table = reg._table
		local _signals = reg._signals

		return _signals.Changed:Connect(function(changedKey: any, newValue: any): ()
			if key == changedKey then
				callback(newValue)
			end
		end)
	end,

	--[[
    Compares the ReactiveTable object to another object

    @param self – The ReactiveTable object
    @param other – The object to compare to
    @returns true if the objects are equal, otherwise false
    ]]
	Compare = function(self: userdata, other: any): boolean
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		if type(other) ~= "userdata" then
			return false
		end

		local otherRegistry = registry[other]
		if not otherRegistry then
			return false
		end

		return deepCompare(reg._table, otherRegistry._table)
	end,

	--[[
    Gets the source table of the ReactiveTable object

    @param self – The ReactiveTable object
    @returns The source table
    ]]
	GetSource = function(self: userdata): { [any]: any }
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		return reg._table
	end,

	--[[
    Checks if the ReactiveTable object is frozen

    @param self – The ReactiveTable object
    @returns boolean indicating if the object is frozen
    ]]
	IsFrozen = function(self: userdata): boolean
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		return reg._frozen
	end,

	--[[
    Checks if the signals of the ReactiveTable object are frozen

    @param self – The ReactiveTable object
    @returns boolean indicating if the signals are frozen
    ]]
	AreSignalsFrozen = function(self: userdata): boolean
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		return reg._signalsFrozen
	end,

	--[[
    Freezes the ReactiveTable object

    @param self – The ReactiveTable object
    ]]
	Freeze = function(self: userdata): ()
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		reg._frozen = true
	end,

	--[[
    Unfreezes the ReactiveTable object

    @param self – The ReactiveTable object
    ]]
	Unfreeze = function(self: userdata): ()
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		reg._frozen = false
	end,

	--[[
    Freezes the signals of the ReactiveTable object

    @param self – The ReactiveTable object
    ]]
	FreezeSignals = function(self: userdata): ()
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		reg._signalsFrozen = true
	end,

	--[[
    Unfreezes the signals of the ReactiveTable object

    @param self – The ReactiveTable object
    ]]
	UnfreezeSignals = function(self: userdata): ()
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		reg._signalsFrozen = false
	end,

	--[[
    Clones the ReactiveTable object

    @param self – The ReactiveTable object
    @param deepClone – Whether to deep clone the object
    @returns The cloned ReactiveTable object
    ]]
	Clone = function(self: userdata, deepClone: boolean?): userdata
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		local _table = reg._table
		if deepClone then
			_table = deepCopy(_table)
		else
			_table = table.clone(_table)
		end

		return new(_table, nil, nil, reg._frozen, reg._signalsFrozen)
	end,

	--[[
    Manual change broadcasting to the ReactiveTable object, useful for batch updates

    @param self – The ReactiveTable object
    @param changedKeys – A dictionary of keys and their change types: "Added", "Removed", "Changed"
    ]]
	BroadcastChanges = function(self: userdata, changedKeys: { [any]: "Added" | "Removed" | "Changed" }): ()
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		local _signals = reg._signals
		local _table = reg._table
		local changedSignal = _signals.Changed :: SignalPrivate<any, any>
		local addedSignal = _signals.New :: SignalPrivate<any, any>
		local removedSignal = _signals.Removed :: SignalPrivate<any>
		for key, type in changedKeys do
			local value = self[key]
			if type == "Added" then
				addedSignal:Fire(key, value)
			elseif type == "Removed" then
				removedSignal:Fire(key)
			elseif type == "Changed" then
				changedSignal:Fire(key, value)
			end
		end
	end,
}

local meta: { [string]: any } = {
	__index = function(self: userdata, key: any): any
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		local _table = reg._table
		local _signals = reg._signals

		local method = methods[key]
		if method then
			return method
		end

		local signal = _signals[key]
		if signal then
			return signal
		end

		local value = _table[key]
		if type(value) == "table" then
			return tableLookup[value]
		end
		return value
	end,

	__newindex = function(self: userdata, key: any, value: any): ()
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		if reg._frozen then
			error(`Attempt to modify a frozen ReactiveTable`)
		end

		local _table = reg._table
		local _signals = reg._signals
		local _ancestors = reg._ancestors
		local _signalsFrozen = reg._signalsFrozen

		if _table[key] == value then
			return
		end

		local wrap = value
		local prev = _table[key]
		if type(value) == "table" then
			wrap = new(value, self, key)
		end
		if prev == nil then
			if value ~= nil and not _signalsFrozen then
				(_signals.New :: SignalPrivate<any, any>):Fire(key, wrap)
			end
		else
			if value == nil then
				if not _signalsFrozen then
					(_signals.Removed :: SignalPrivate<any>):Fire(key)
				end
			elseif not _signalsFrozen then
				(_signals.Changed :: SignalPrivate<any, any>):Fire(key, wrap)
			end

			-- overwrite/removal handling
			if type(prev) == "table" then
				local referencesExist = false
				for k, v in _table do
					if k ~= key and v == prev then
						referencesExist = true
						break
					end
				end
				if not referencesExist then
					local prevRegistry = registry[tableLookup[prev]]
					if prevRegistry then
						prevRegistry._ancestors[self] = nil
					end
				end
			end
		end
		_table[key] = value
		if not _signalsFrozen then
			for _ancestor, _ancestorKey in _ancestors do
				local ancestorRegistry = registry[_ancestor];
				(ancestorRegistry._signals.Changed :: SignalPrivate<any, any>):Fire(_ancestorKey, self)
			end
		end
	end,

	__iter = function(self: userdata)
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		local _table = reg._table

		return next, _table, nil
	end,

	__tostring = function(self: userdata): string
		local reg = registry[self]
		if not reg then
			error(`Invalid/Destroyed userdata`)
		end

		local str = "{ "
		for k, v in reg._table do
			str ..= `{k} = {v}, `
		end
		if #str ~= 2 then
			str = str:sub(1, #str - 2)
		end
		str ..= " }"
		return str
	end,

	__len = function(self: userdata): number
		local reg = registry[self]
		if not registry then
			error(`Invalid/Destroyed userdata`)
		end

		return #reg._table
	end,

	__metatable = "ReactiveTable",
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------
--[[
    Copies the metamethods from @variable meta to @param dst

    @param dst – The destination
]]
local function metaCopy(dst: { [any]: any }): ()
	for k, v in meta do
		dst[k] = v
	end
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------
--[[
    Creates a ReactiveTable object

    @param tbl – The table which will be wrapped
    @internal @optional @param ancestor – The ancestor of the object
    @internal @optional @param ancestorKey – The key of where the object is located in the ancestor
    @internal @optional @param frozen – Whether the object is frozen
    @internal @optional @param signalsFrozen – Whether the signals are frozen
    @returns The ReactiveTable object
]]
new = function<T>(
	tbl: ({ [any]: any } & T)?,
	ancestor: userdata?,
	ancestorKey: any?,
	frozen: boolean?,
	signalsFrozen: boolean?
): ReactiveTable<T>
	tbl = tbl or {}

	-- if the table is already wrapped – return the existing object, this prevents infinite recursion and simply optimizes memory usage
	local lookup: userdata? = tableLookup[tbl]
	if lookup then
		if ancestor then
			-- if the object is nested – add the ancestor to the registry
			local reg = registry[lookup]
			if reg then
				reg._ancestors[ancestor] = ancestorKey
			end
		end
		return lookup
	end

	-- otherwise create a new object
	local self: userdata = newproxy(true)
	local mt = getmetatable(self)
	metaCopy(mt)
	local reg = {
		_table = tbl,
		_frozen = frozen == true,
		_signalsFrozen = signalsFrozen == true,
		_signals = {
			Changed = signal.new(),
			New = signal.new(),
			Removed = signal.new(),
		},
		_ancestors = if ancestor then { [ancestor] = ancestorKey } else {},
	}
	registry[self] = reg :: any -- annoying type casts to silence strict type checker

	-- loop through the table and wrap any nested tables
	-- important: set the lookup value before the loop, since it could contain itself as a value
	tableLookup[tbl] = self
	for k, v in tbl do
		if type(v) == "table" then
			new(v, self, k)
		end
	end
	return self
end

--[[
    Public API for creating a ReactiveTable object

    @param tbl – The table which will be wrapped
    @returns The ReactiveTable object
]]
function ReactiveTable.new<T>(tbl: ({ [any]: any } & T)?): ReactiveTable<T>
	return new(tbl)
end

return ReactiveTable
