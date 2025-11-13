# Code Generation Details

This chapter dives into how the Zig and TypeScript generators work internally. Understanding these details helps when extending or debugging wasmbind.

## Stage 1: Reflection (`types.zig`)

`types.zig` leverages `@typeInfo` to produce reusable metadata:

- `StructField` captures field names, original Zig types, and inferred TypeScript types.
- `FunctionSignature` contains parameter info, return type, and type-mapping data.
- `TsType` enum represents primitives, slices, structs, strings, and pointers.

These structs are pure comptime values, so the generators can iterate over them with `inline for`.

## Stage 2: Zig Generator (`codegen_zig.zig`)

Key routines:

- `generateExports` – orchestrates file emission and accumulates export names.
- `generateTypeExports` – writes per-struct declarations and loops over methods.
- `generateInitMethod` / `generateRegularMethod` – handle method-specific logic.
- `generateSliceReturnExports` – builds `_ptr` / `_len` helpers.
- `generateLifecycle` – emits `__wasmbind_init`, `__wasmbind_deinit`, `allocate`, `deallocate`.

The generator uses `std.ArrayListUnmanaged(u8)` for performance and prints via `writer`. Because it operates at comptime (the runner is compiled with the contract imported), type errors reference user code directly.

## Stage 3: TypeScript Generator (`codegen_ts.zig`)

`generateBindings` traverses the same `exports_decl` and emits:

1. File header and helper imports.
2. Interfaces for each extern struct (plain data objects).
3. Class definitions with constructor/methods/destroy.
4. Global helper `loadWasm`.

Important helpers:

- `writeTsType` – maps Zig types to TypeScript strings.
- `generateClass` – writes private fields, constructor, methods, and memory helpers.
- `generateMethod` – handles both regular and slice-returning functions.

Strings are built with `std.ArrayList(u8)` and converted to owned slices at the end.

## Stage 4: Runner

```
const wasm_contract = @import("wasm");
var result = try codegen_zig.generateExports(..., wasm_contract.exports, ...);
var ts_result = try codegen_ts.generateBindings(..., wasm_contract.exports, ...);
```

The runner writes both outputs, printing stats for debugging. Because it imports `wasm.zig`, the contract must compile for the host target. Keep platform-specific code behind `comptime if` guards.

## Testing the Generators

- `src/root.zig` includes unit tests that generate code and assert on substrings.
- Integration tests (future) will run the runner on sample contracts and compile the output end-to-end.

## Extending Codegen

1. Modify `TsType` or `StructField` to capture new metadata.
2. Update `writeZigType` / `writeTsType` to add new mappings.
3. Add unit tests to lock in behavior.
4. Run `zig build test` and `examples/chart-demo` builds to ensure no regressions.

This pipeline is intentionally straightforward: reflection → string builder → filesystem. Contributions typically touch one stage at a time.
