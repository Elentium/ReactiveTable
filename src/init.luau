--!strict
--[[
	[BETA]
	ReactiveTable V0.1.1
	by IAMNOTULTRA3 (a.k.a Elite, Elentium)
	Apache 2.0 License
	
	DX-Oriented observable table implementation

	You can treat ReactiveTable objects the same as tables but with automatic reactivity, for example:
	```luau
		local ReactiveTable = require(path.to.module)

		local reactive = ReactiveTable.new({ hello = "world" })

		-- same read/write syntax as normal tables
		print(reactive.hello) -- output: "world"

		reactive.hello = "goodbye"

		-- while having TONS of features, example:
		reactive:BindToKeyChanged("hello", function(newValue: string): ()
			print(`key "hello" was changed, new value: {newValue}`)
		end)
		reactive.hello = "grr" -- triggers the function above

		reactive.New:Connect(function(NewKey: string, NewValue: any)
			print(`New key added: {NewKey}, new value: {NewValue}`)
		end)
		reactive.someNewKey = 11 -- triggers the function above

		reactive:Insert("gg") -- table.insert
		print(reactive:Find("gg")) -- table.find
		print(reactive:Remove()) -- table.remove
		
		local clone = reactive:Clone(true) -- true = deep copy, false = shallow copy

		-- and way more features!
	```

	This can be really useful for data replication wrappers, ui systems, etc.
	where you do not have to manually call the update function or do the painful Data:Set("SomeKey", SomeValue)
	ReactiveTable overhead compared to those 2 methods is relatively small and sometimes it is even faster

	To ensure ReactiveTable matches your expectations there is a sophisticated 2000+ lines test script(`src/test`) that you can require and it will run the tests

	Notes:
	- Due to LuaU limitations, accessing nested tables contents will not show the object API,
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
			reactive. <-- the autocomplete shows both object API and the table contents
			
			reactive.nested1. <-- the autocomplete only shows the table contents, but cannot show the object API
		```
        However you can make so that any nested reactive tables have autocomplete by annotating the type of the table.
		Example:
		```luau
			local ReactiveTable = require(path.to.module)
			
			local reactive = ReactiveTable.new({
				nested1 = {
					abc = "hello"
				},
				nested2 = {}
			})

			type ReactiveTable = ReactiveTable.ReactiveTable

			local nested1 = reactive.nested1 :: ReactiveTable<typeof(reactive.nested1)>
			nested1. <-- the autocomplete will show the API & the table contents
		```
		Additionally, you can simply create a ReactiveTable object before nesting it,
		Example:
		```luau
		local ReactiveTable = require(path.to.module)

		local nested1 = ReactiveTable.new({ abc = "hello" })
		local nested2 = ReactiveTable.new()

		local reactive = ReactiveTable.new({ nested1 = nested1, nested2 = nested2 })
		reactive.nested1. <-- shows both object API and the table contents
		```

	- This library prioritizes developer experience over pure performance
	- If there are any nested tables inside the ReactiveTable objects, they will be wrapped into ReactiveTable objects too
	- The library provides 1-level ancestor notification, for example:
		```luau
			local ReactiveTable = require(path.to.module)
			local reactive = ReactiveTable.new({ a = { b = 10 } })
			reactive.Changed:Connect(function(key: string, value: any)
				print(`{key}: {value}`)
			end)
			reactive.a.b = 10 -- this fires both the `a` ReactiveTable and it's ancestor `reactive`
		```
		however:
		```luau
			local ReactiveTable = require(path.to.module)
			local reactive = ReactiveTable.new({ a = { b = { c = 10 } } })
			reactive.Changed:Connect(function(key: string, value: any)
				print(`{key}: {value}`)
			end)
			reactive.a.b.c = 10 -- this fires both the `b` ReactiveTable and it's ancestor `a`, but it does not notify level 2 ancestor (reactive)
		```
		The reason it does only 1-level notification is for performance and personal view reasons

	Credits:
	Stravant for the Signal implementation

	Github:
	https://github.com/Elentium/ReactiveTable

	Wally:
	https://wally.run/package/elentium/reactivetable
	elentium/reactivetable@0.1.1
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
	-- <key>
	Removed: SignalPublic<any>,
} & { [string]: any } -- < defining indexer for strict type checker

export type ReactiveAPI<T> = {
	GetSource: (self: any) -> T,
	GetSize: (self: any) -> number,
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

export type ReactiveTable<T = {}> = T & Signals & ReactiveAPI<T>

type userdata = any

type registry = {
	[userdata]: {
		_table: { [any]: any },
		_frozen: boolean,
		_signalsFrozen: boolean,
		_signals: Signals,
		_ancestors: { [userdata]: { [any]: boolean } }, -- [ancestor]: { [key]: true }
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
local methods = {}
local meta: { [string]: any } = {}

local weakKey = { __mode = "k" }

local tableLookup: { [{ [any]: any }]: userdata } = setmetatable({}, weakKey) :: { [{ [any]: any }]: userdata }
local registry: registry = setmetatable({}, weakKey) :: registry

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

--[[
    Iterator function for the __iter metamethod

    @param tbl – The table to iterate through
    @param lastKey – The last key iterated through
    @returns The key and value
]]
local function iterator(tbl: { [any]: any }, lastKey: any?): (any, any)
	local key, value = next(tbl, lastKey)
	if type(value) == "table" then
		value = tableLookup[value]
	end
	return key, value
end

--[[
Removes a single key reference from a child table's ancestor entry

@param rawChild – The child table
@param ancestor – The ancestor of the child
@param key – The key to remove
]]
local function removeAncestorKey(rawChild: { [any]: any }, ancestor: userdata, key: any): ()
	local child = tableLookup[rawChild]
	if not child then
		return
	end
	local childReg = registry[child]
	if not childReg then
		return
	end
	local ancestorKeys = childReg._ancestors[ancestor]
	if not ancestorKeys then
		return
	end
	ancestorKeys[key] = nil
	if next(ancestorKeys) == nil then
		childReg._ancestors[ancestor] = nil
	end
end

--[[
Adds a single key reference to a child userdata's ancestor entry

@param child – The child userdata
@param ancestor – The ancestor of the child
@param key – The key to add
]]
local function addAncestorKey(child: userdata, ancestor: userdata, key: any): ()
	local childReg = registry[child]
	if not childReg then
		return
	end
	local ancestorKeys = childReg._ancestors[ancestor]
	if ancestorKeys then
		ancestorKeys[key] = true
	else
		childReg._ancestors[ancestor] = { [key] = true }
	end
end

--[[
Fires Changed on every ancestor that tracks @param self, for every key they track it under

@param self – The self userdata
@param ancestors – The ancestors of the self
]]
local function broadcastAncestorChanged(self: userdata, ancestors: { [userdata]: { [any]: boolean } }): ()
	for ancestor, ancestorKeys in ancestors do
		local ancestorReg = registry[ancestor]
		local changedSignal = ancestorReg._signals.Changed :: SignalPrivate<any, any>
		for key in ancestorKeys do
			changedSignal:Fire(key, self)
		end
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
local function new<T>(
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
			addAncestorKey(lookup, ancestor, ancestorKey)
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
		_ancestors = if ancestor then { [ancestor] = { [ancestorKey] = true } } else {},
	}
	registry[self] = reg :: any -- annoying type casts to silence strict type checker

	-- important: set the lookup value before the loop, since it could contain itself as a value
	tableLookup[tbl] = self

	for k, v in tbl do
		if type(v) == "table" then
			new(v, self, k)
		elseif type(v) == "userdata" then
			local childReg = registry[v]
			if childReg then
				(tbl :: { [any]: any })[k] = childReg._table
				addAncestorKey(v, self, k)
			end
		end
	end
	return self
end

--[[
    Public API for creating a ReactiveTable object

    @param tbl – The table which will be wrapped
    @returns The ReactiveTable object
]]
function ReactiveTable.new<T>(tbl: (({ [any]: any }) & T)?): ReactiveTable<T>
	return new(tbl)
end

--[[
    Destroys the ReactiveTable object
]]
function methods:Destroy(): ()
	local reg = registry[self]
	if not reg then
		error(`Invalid or already destroyed userdata`)
	end
	tableLookup[reg._table] = nil

	for _, signal in reg._signals do
		signal:DisconnectAll()
	end

	registry[self] = nil
end

--[[
    Inserts a value into the ReactiveTable object

    @param value – The value to insert
    @optional @param index – The index to insert the value at
]]
function methods:Insert(value: any, index: number?): ()
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
	local valueType = type(value)
	if valueType == "userdata" then
		-- unwrap to the raw table so _table always stores raw tables
		local valueReg = registry[value]
		if valueReg then
			value = valueReg._table
		end
	end
	if index then
		table.insert(_table, index, value)
		idx = index
	else
		table.insert(_table, value)
		idx = #_table
	end
	if valueType == "table" then
		wrap = new(value, self, idx)
	elseif valueType == "userdata" then
		-- value is still the userdata wrapper; register its ancestry
		addAncestorKey(wrap, self, idx)
	end
	if not reg._signalsFrozen then
		(_signals.New :: SignalPrivate<any, any>):Fire(idx, wrap)
		broadcastAncestorChanged(self, _ancestors)
	end
end

--[[
Removes a value from the ReactiveTable object

@optional @param index – The index to remove the value from
@returns The removed value
]]
function methods:Remove(index: number?): any
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
	-- function overloading
	if index then
		value = table.remove(_table, index)
		idx = index
	else
		idx = #_table
		value = table.remove(_table)
	end

	-- if the value is a table, we need to properly handle ancestry
	if type(value) == "table" then
		removeAncestorKey(value, self, idx)
	elseif type(value) == "userdata" then
		local valueReg = registry[value]
		if valueReg then
			removeAncestorKey(valueReg._table, self, idx)
		end
	end

	if not reg._signalsFrozen then
		(_signals.Removed :: SignalPrivate<any, any>):Fire(idx, value)
		broadcastAncestorChanged(self, _ancestors)
	end

	return value
end

--[[
Returns the amount of items in the ReactiveTable object

@returns The size of the object
]]
function methods:GetSize(): number
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	local count = 0
	for _ in reg._table do
		count += 1
	end
	return count
end

--[[
Manual change broadcasting to the ReactiveTable object, useful for batch updates

@param changedKeys – A dictionary of keys and their change types: "Added", "Removed", "Changed"
]]
function methods:BroadcastChanges(changedKeys: { [any]: "Added" | "Removed" | "Changed" }): ()
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
end

--[[
Clones the ReactiveTable object

@param deepClone – Whether to deep clone the object
@returns The cloned ReactiveTable object
]]
function methods:Clone(deepClone: boolean?): userdata
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	local _table: any = reg._table
	if deepClone then
		_table = deepCopy(_table)
	else
		_table = table.clone(_table)
	end

	return new(_table, nil, nil, reg._frozen, reg._signalsFrozen)
end

--[[
Freezes the ReactiveTable object
]]
function methods:Freeze(): ()
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	reg._frozen = true
end

--[[
Unfreezes the ReactiveTable object
]]
function methods:Unfreeze(): ()
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	reg._frozen = false
end

--[[
Freezes the signals of the ReactiveTable object
]]
function methods:FreezeSignals(): ()
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	reg._signalsFrozen = true
end

--[[
Unfreezes the signals of the ReactiveTable object
]]
function methods:UnfreezeSignals(): ()
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	reg._signalsFrozen = false
end

--[[
Finds the index of a value in the ReactiveTable object

@param needle – The value to find
@optional @param init – The index to start the search at
@returns The index of the value, or nil if not found
]]
function methods:Find(needle: any, init: number?): number?
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
end

--[[
Clears the ReactiveTable object (array cleanup, will not work for dictionaries)
]]
function methods:Clear(): ()
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
			removeAncestorKey(value, self, i)
			value = tableLookup[value]
		elseif type(value) == "userdata" then
			local valueReg = registry[value]
			if valueReg then
				removeAncestorKey(valueReg._table, self, i)
			end
		end
		if not _signalsFrozen then
			(_signals.Removed :: SignalPrivate<any, any>):Fire(i, value)
		end
		changed = true
	end
	if changed and not _signalsFrozen then
		broadcastAncestorChanged(self, _ancestors)
	end
end

--[[
Sorts the ReactiveTable object

@param comparator – The comparator function
]]
function methods:Sort(comparator: ((any, any) -> boolean)?): ()
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end
	if reg._frozen then
		error(`Attempt to modify frozen ReactiveTable`)
	end

	local _table = reg._table

	-- wrap values for the comparator so callers always receive ReactiveTable userdatas
	table.sort(
		_table,
		if comparator then 
			function(v0: any, v1: any): boolean
				return comparator(
					if type(v0) == "table" then tableLookup[v0] else v0,
					if type(v1) == "table" then tableLookup[v1] else v1
				)
			end
		else nil
	)

	-- collect {[childUserdata]: {[newIndex]: true}} for all reactive child slots
	local newKeys: { [userdata]: { [number]: boolean } } = {}
	for i = 1, #_table do
		local v = _table[i]
		local child: userdata? = nil
		local valueType = type(v)
		if valueType == "table" then
			child = tableLookup[v]
		elseif valueType == "userdata" and registry[v] then
			child = v
		end
		if child then
			local entry = newKeys[child]
			if entry then
				entry[i] = true
			else
				newKeys[child] = { [i] = true }
			end
		end
	end

	-- apply the rebuilt key-sets, replacing whatever indices were stored
	for child, indices in newKeys do
		local childReg = registry[child]
		if childReg then
			childReg._ancestors[self] = indices
		end
	end
end

--[[
Binds a callback to the Changed signal of a key in the ReactiveTable object

@param key – The key to bind the callback to
@param callback – The callback function
@returns A SignalConnection object
]]
function methods:BindToKeyChanged(key: any, callback: (value: any) -> ()): SignalConnection
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
end

--[[
Compares the ReactiveTable object to another object
(deep compare, does not compare tables/userdata references but rather their contents)

@param other – The object to compare to
@returns true if the objects are equal, otherwise false
]]
function methods:Compare(other: any): boolean
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
end

--[[
Gets the source table of the ReactiveTable object

@returns The source table
]]
function methods:GetSource(): { [any]: any }
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	return reg._table
end

--[[
Checks if the ReactiveTable object is frozen

@returns boolean indicating if the object is frozen
]]
function methods:IsFrozen(): boolean
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	return reg._frozen
end

--[[
Checks if the signals of the ReactiveTable object are frozen

@returns boolean indicating if the signals are frozen
]]
function methods:AreSignalsFrozen(): boolean
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	return reg._signalsFrozen
end

--------------------------------------------------------------------------------
-- METAMETHODS
--------------------------------------------------------------------------------
function meta:__index(key: any): any
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
end

function meta:__newindex(key: any, value: any): ()
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	if reg._frozen then
		error(`Attempt to modify a frozen ReactiveTable`)
	end

	local _table = reg._table
	local prev = _table[key]

	-- return if value is identical
	if prev == value then
		return
	end

	local _ancestors = reg._ancestors
	local _signalsFrozen = reg._signalsFrozen

	-- wrap incoming value and register ancestry
	local wrap = value
	local valueType = type(value)
	if valueType == "table" then
		wrap = new(value, self, key)
	elseif valueType == "userdata" then
		addAncestorKey(value, self, key)
	end

	-- clean up ancestry for an overwritten/removed child
	if type(prev) == "table" then
		removeAncestorKey(prev, self, key)
	elseif type(prev) == "userdata" then
		local prevReg = registry[prev]
		if prevReg then
			removeAncestorKey(prevReg._table, self, key)
		end
	end

	_table[key] = value

	if not _signalsFrozen then
		local _signals = reg._signals
		if prev == nil then
			-- new key
			(_signals.New :: SignalPrivate<any, any>):Fire(key, wrap)
		elseif value == nil then
			-- key removed
			(_signals.Removed :: SignalPrivate<any>):Fire(key)
		else
			-- key changed
			(_signals.Changed :: SignalPrivate<any, any>):Fire(key, wrap)
		end
		broadcastAncestorChanged(self, _ancestors)
	end
end

function meta:__iter(): ((any, any) -> (any?, any), { [any]: any }, any?)
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	local _table = reg._table

	return iterator, _table, nil
end

function meta:__tostring(): string
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
end

function meta:__len(): number
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end

	return #reg._table
end

meta.__metatable = "ReactiveTable"

return ReactiveTable
