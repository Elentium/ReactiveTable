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

	Test results (1000 iterations/test, scale ×1.0):
	────────────────────────────────────────────────────────────────────────
	Construction (ReactiveTable.new)           ValidityPass: true  PerformancePass: true
	  [PASS] new() with empty table                       avg   1.96 µs (budget  15.00 µs)
	  [PASS] new() with flat values                       avg   2.13 µs (budget  15.00 µs)
	  [PASS] new() wraps nested tables                    avg   4.23 µs (budget  20.00 µs)
	  [PASS] new() with same table returns same userdata  avg   2.01 µs (budget   7.00 µs)
	  [PASS] new() self-referential table (no overflow)   avg   2.49 µs (budget  20.00 µs)
	Index / NewIndex (__index __newindex)     ValidityPass: true  PerformancePass: true
	  [PASS] read primitive key                           avg   0.12 µs (budget   2.00 µs)
	  [PASS] write primitive key fires Changed            avg   2.28 µs (budget   5.00 µs)
	  [PASS] write new key fires New                       avg   1.41 µs (budget   5.00 µs)
	  [PASS] set key to nil fires Removed                 avg   1.37 µs (budget   5.00 µs)
	  [PASS] write same value is a no-op (no signal)      avg   0.10 µs (budget   3.00 µs)
	  [PASS] write table value wraps it                   avg   3.30 µs (budget   8.00 µs)
	  [PASS] write userdata registers ancestry and bubbles avg   0.09 µs (budget   8.00 µs)
	Introspection (GetSource GetSize IsFrozen AreSignalsFrozen)  ValidityPass: true  PerformancePass: true
	  [PASS] GetSource returns underlying table           avg   0.12 µs (budget   2.00 µs)
	  [PASS] GetSize counts all keys                      avg   0.16 µs (budget   3.00 µs)
	  [PASS] IsFrozen reflects freeze state               avg   0.13 µs (budget   2.00 µs)
	  [PASS] AreSignalsFrozen reflects freeze state       avg   0.13 µs (budget   2.00 µs)
	Freeze / Unfreeze                         ValidityPass: true  PerformancePass: true
	  [PASS] frozen table rejects writes                  avg   0.32 µs (budget   5.00 µs)
	  [PASS] frozen table rejects Insert                  avg   0.40 µs (budget   4.00 µs)
	  [PASS] unfreezing re-enables writes                  avg   0.34 µs (budget   4.00 µs)
	  [PASS] FreezeSignals suppresses all signals         avg   0.21 µs (budget   5.00 µs)
	  [PASS] UnfreezeSignals re-enables signals           avg   0.33 µs (budget   5.00 µs)
	Insert                                    ValidityPass: true  PerformancePass: true
	  [PASS] Insert appends to array                      avg   0.88 µs (budget   6.00 µs)
	  [PASS] Insert at index shifts elements              avg   0.58 µs (budget   6.00 µs)
	  [PASS] Insert fires New and ancestor Changed        avg   3.62 µs (budget   8.00 µs)
	  [PASS] Insert wraps nested table values             avg   2.45 µs (budget   8.00 µs)
	Remove                                    ValidityPass: true  PerformancePass: true
	  [PASS] Remove pops last element                     avg   0.55 µs (budget   4.00 µs)
	  [PASS] Remove at index shifts elements              avg   0.58 µs (budget   4.00 µs)
	  [PASS] Remove fires Removed and ancestor Changed    avg   3.60 µs (budget   8.00 µs)
	  [PASS] Remove cleans up child ancestry              avg   0.87 µs (budget   6.00 µs)
	Clear                                     ValidityPass: true  PerformancePass: true
	  [PASS] Clear empties array                          avg   0.16 µs (budget   5.00 µs)
	  [PASS] Clear fires Removed for each element         avg   3.73 µs (budget   8.00 µs)
	  [PASS] Clear fires ancestor Changed once            avg   5.74 µs (budget   8.00 µs)
	  [PASS] Clear cleans up child table ancestry         avg   0.93 µs (budget   8.00 µs)
	Sort                                      ValidityPass: true  PerformancePass: true
	  [PASS] Sort orders primitive array                  avg   2.08 µs (budget   8.00 µs)
	  [PASS] Sort updates ancestry keys for nested tables avg   2.28 µs (budget  10.00 µs)
	  [PASS] Sort with duplicate references updates all  avg   0.86 µs (budget  10.00 µs)
	Find                                      ValidityPass: true  PerformancePass: true
	  [PASS] Find returns correct index for primitive     avg   0.17 µs (budget   3.00 µs)
	  [PASS] Find with init skips earlier indices        avg   0.17 µs (budget   3.00 µs)
	  [PASS] Find accepts ReactiveTable userdata          avg   0.19 µs (budget   4.00 µs)
	  [PASS] Find returns nil when not found              avg   0.17 µs (budget   3.00 µs)
	Clone                                     ValidityPass: true  PerformancePass: true
	  [PASS] Clone shallow produces independent table     avg   3.43 µs (budget   6.00 µs)
	  [PASS] Clone deep copies nested table               avg   6.13 µs (budget  12.00 µs)
	  [PASS] Clone preserves frozen state                 avg   1.54 µs (budget   5.00 µs)
	  [PASS] Clone preserves signalsFrozen state          avg   1.79 µs (budget   5.00 µs)
	Compare                                   ValidityPass: true  PerformancePass: true
	  [PASS] Compare equal tables returns true            avg   0.57 µs (budget   5.00 µs)
	  [PASS] Compare different tables returns false      avg   0.22 µs (budget   3.00 µs)
	  [PASS] Compare with non-userdata returns false     avg   0.14 µs (budget   2.00 µs)
	BindToKeyChanged                          ValidityPass: true  PerformancePass: true
	  [PASS] fires only for the bound key                 avg   2.47 µs (budget   5.00 µs)
	  [PASS] connection Disconnect stops callbacks        avg   0.54 µs (budget   5.00 µs)
	BroadcastChanges                          ValidityPass: true  PerformancePass: true
	  [PASS] broadcasts Added signal for listed keys      avg   1.22 µs (budget   5.00 µs)
	  [PASS] broadcasts Removed signal for listed keys    avg   1.23 µs (budget   5.00 µs)
	  [PASS] broadcasts Changed signal for listed keys   avg   1.24 µs (budget   5.00 µs)
	Destroy                                   ValidityPass: true  PerformancePass: true
	  [PASS] Destroy removes registry entry               avg   1.99 µs (budget  12.00 µs)
	  [PASS] Destroy disconnects all signals              avg   2.22 µs (budget  10.00 µs)
	Metamethods (__iter __len __tostring)      ValidityPass: true  PerformancePass: true
	  [PASS] __iter yields key-value pairs                avg   0.34 µs (budget   5.00 µs)
	  [PASS] __iter unwraps nested table values           avg   0.20 µs (budget   5.00 µs)
	  [PASS] __len returns array length                   avg   0.08 µs (budget   3.00 µs)
	  [PASS] __tostring produces non-empty string         avg   0.37 µs (budget   3.00 µs)
	Ancestor sees children changes            ValidityPass: true  PerformancePass: true
	  [PASS] leaf change fires direct parent's Changed    avg   0.22 µs (budget   8.00 µs)
	  [PASS] direct parent fires, grandparent does not    avg   0.09 µs (budget   8.00 µs)
	  [PASS] child shared by two parents bubbles to both   avg   0.09 µs (budget   6.00 µs)
	  [PASS] child at multiple keys bubbles for each key   avg   0.09 µs (budget   6.00 µs)
	  [PASS] removing child from one parent stops bubble   avg   0.10 µs (budget   6.00 µs)
	  [PASS] inserting array of nested tables updates     avg   4.97 µs (budget   8.00 µs)
	Edge Cases                                ValidityPass: true  PerformancePass: true
	  [PASS] overwrite table child with primitive cleans  avg   2.65 µs (budget   8.00 µs)
	  [PASS] replace one child with another cleans old    avg   0.23 µs (budget   8.00 µs)
	  [PASS] Destroy on frozen table still succeeds       avg   1.96 µs (budget   8.00 µs)
	  [PASS] empty Clear is safe (no error, no Changed)    avg   0.27 µs (budget   4.00 µs)
	  [PASS] Sort on empty array is safe                  avg   0.24 µs (budget   3.00 µs)
	  [PASS] Sort after Remove keeps ancestry consistent  avg   2.44 µs (budget   6.00 µs)
	  [PASS] signal fires correct new value after write   avg   0.22 µs (budget   5.00 µs)
	  [PASS] Remove returns raw primitive, not wrapped    avg   0.57 µs (budget   4.00 µs)
	  [PASS] Clone(true) deep clone no shared ancestry     avg   6.57 µs (budget  10.00 µs)
	────────────────────────────────────────────────────────────────────────
	Score: 219 / 219  (100.0%)   Grade: S
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
Removes a single key reference from a child table's ancestor entry.

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
Adds a single key reference to a child userdata's ancestor entry.

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
Fires Changed on every ancestor that tracks @param self, for every key they track it under.

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
function ReactiveTable.new<T>(tbl: ({ [any]: any } & T)?): ReactiveTable<T>
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
function methods:Sort(comparator: (any, any) -> boolean): ()
	local reg = registry[self]
	if not reg then
		error(`Invalid/Destroyed userdata`)
	end
	if reg._frozen then
		error(`Attempt to modify frozen ReactiveTable`)
	end

	local _table = reg._table

	-- wrap values for the comparator so callers always receive ReactiveTable userdatas
	table.sort(_table, function(v0: any, v1: any): boolean
		return comparator(
			if type(v0) == "table" then tableLookup[v0] else v0,
			if type(v1) == "table" then tableLookup[v1] else v1
		)
	end)

	-- collect {[rawChild]: {[newIndex]: true}} for all table-valued slots
	local newKeys: { [{ [any]: any }]: { [number]: boolean } } = {}
	for i = 1, #_table do
		local v = _table[i]
		if type(v) == "table" then
			local entry = newKeys[v]
			if entry then
				entry[i] = true
			else
				newKeys[v] = { [i] = true }
			end
		end
	end

	-- apply the rebuilt key-sets, replacing whatever indices were stored
	for rawChild, indices in newKeys do
		local child = tableLookup[rawChild]
		if child then
			local childReg = registry[child]
			if childReg then
				childReg._ancestors[self] = indices
			end
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
