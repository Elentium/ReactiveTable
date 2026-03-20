# ReactiveTable V1

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue?style=flat-square" alt="License" /></a>
  <a href="https://wally.run/package/elentium/reactivetable"><img src="https://img.shields.io/badge/📦_Wally-elentium%2Freactivetable-00b4ab?style=flat-square" alt="Wally" /></a>
</p>

<p align="center">
  <strong>DX-oriented observable table implementation for Luau</strong>
</p>

ReactiveTable wraps normal Luau tables in a proxy that behaves like a table, but automatically broadcasts changes
It is designed to reduce the boilerplate of manual update calls while keeping the code ergonomic

## Features
- Table-like syntax via metatables (`t.key`, `t.key = value`, `for k, v in t do ... end`)
- Signals for reactivity:
  - `Changed` (fires on value updates)
  - `New` (fires on key additions)
  - `Removed` (fires on key removals)
- Automatic wrapping of nested tables into ReactiveTable objects
- 1-level ancestor notification (child writes bubble to direct parent only)
- Freeze controls:
  - freeze the table (rejects writes)
  - freeze signals (suppresses signal emissions)
- Utility methods: `Clone`, `Compare`, `Find`, `Sort`, `Insert`, `Remove`, `Clear`
- Supports self-referential tables during construction (no stack overflow)

## Installation
### Using Wally
Add ReactiveTable to your `wally.toml`:
```toml
[dependencies]
ReactiveTable = "elentium/reactivetable@0.1.1"
```

Then run:
```bash
wally install
```

### Roblox Studio Direct Installation
1. Install roblox/ReactiveTable.rbxm 
2. Insert it in your roblox studio project

## Quick Start
```luau
local ReactiveTable = require(path.to.module) -- see Installation notes

local reactive = ReactiveTable.new({ hello = "world" })

print(reactive.hello) -- "world"

reactive:BindToKeyChanged("hello", function(newValue: any)
	print(`key "hello" changed, new value: {newValue}`)
end)

reactive.hello = "goodbye" -- triggers the callback

-- listen for new keys
reactive.New:Connect(function(newKey: any, newValue: any)
	print(`New key added: {newKey}, value: {newValue}`)
end)

reactive.someNewKey = 123 -- triggers New
```

### Nested tables + ancestor bubbling (1-level)
```luau
local ReactiveTable = require(path.to.module)

local reactive = ReactiveTable.new({ a = { b = 10 } })

reactive.Changed:Connect(function(key: string, value: any)
	print(`changed {key} -> {value}`)
end)

-- This fires `Changed` on the `a` table (and also on `reactive`)
reactive.a.b = 11
```

## Signals
ReactiveTable exposes three signal objects:
- `reactive.Changed:Connect(function(key, value) ... end)`
- `reactive.New:Connect(function(key, value) ... end)`
- `reactive.Removed:Connect(function(key) ... end)`

`BindToKeyChanged(key, callback)` is a convenience wrapper for `Changed` that filters by a specific key.

Connections returned by `:Connect(...)` support `:Disconnect()`.

## API Reference
### `ReactiveTable.new(tbl?) -> ReactiveTable<T>`
Creates a ReactiveTable proxy.

- `tbl?` is an optional source table (defaults to `{}`).
- Nested tables inside `tbl` are automatically wrapped into ReactiveTable objects.
- If the same raw table is wrapped more than once, the same userdata wrapper is reused (per process lifetime).

### Introspection
- `reactive:GetSource() -> { [any]: any }`
- `reactive:GetSize() -> number`
- `reactive:IsFrozen() -> boolean`
- `reactive:AreSignalsFrozen() -> boolean`

### Lifecycle
- `reactive:Destroy()`
  - Disconnects all signal listeners
  - Removes internal registry entries

### Change broadcasting
- `reactive:BindToKeyChanged(key, callback) -> SignalConnection`
  - `callback(newValue)`
- `reactive:BroadcastChanges(changedKeys: { [any]: "Added" | "Removed" | "Changed" })`
  - Manually emits signals for multiple keys (useful for batch updates)

### Mutations
- `reactive:Insert(value: any, index?: number) -> ()`
  - Array-style insertion with `table.insert`
  - Emits `New` and bubbles `Changed` to direct ancestors
- `reactive:Remove(index?: number) -> any`
  - Array-style removal with `table.remove`
  - Emits `Removed` and bubbles `Changed` to direct ancestors
- `reactive:Find(needle: any, init?: number) -> number?`
  - Works with primitives and ReactiveTable userdata.
- `reactive:Sort(comparator) -> ()`
  - Sorts array contents via `table.sort`.
- `reactive:Clear() -> ()`
  - Clears an array-like ReactiveTable (sets numeric entries to nil)

### Utility
- `reactive:Clone(deepClone?: boolean) -> ReactiveTable<T>`
  - `deepClone == true` deep-copies nested tables (and clones nested reactive children)
  - `deepClone == nil/false` does a shallow copy: top-level is independent, nested tables are shared
- `reactive:Compare(other: any) -> boolean`
  - Deep-compares contents

### Freeze controls
- `reactive:Freeze() / reactive:Unfreeze()`
  - Rejects write operations when frozen
- `reactive:FreezeSignals() / reactive:UnfreezeSignals()`
  - Suppresses signal emissions for that specific object

## Notes / Limitations
- Luau autocomplete for nested tables:
- Autocomplete will show table contents, but will not show ReactiveTable API for nested objects unless you annotate types (see `src/init.luau` header docs).
- Ancestor notifications are limited to 1-level for performance and simplicity.

## Running Tests
The project includes a large test suite at `src/test/init.luau`.
Requiring it in a Roblox environment runs correctness + performance checks and prints results/optionally creates a UI.

## Contributing
Contributions are welcome. If you add features or fix edge cases, consider adding/adjusting tests in `src/test/init.luau`.

## License
Apache License 2.0. See `LICENSE` for details.

## Author
IAMNOTULTRA3 (a.k.a. Elite, Elentium)

## Credits
Signal batching implementation based on `stravant` (Signal) and modified by IAMNOTULTRA3.