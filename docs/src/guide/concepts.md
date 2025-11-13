# Core Concepts

wasmbind sits between three domains:

1. **Zig contract** – the canonical description of your API.
2. **Generated Zig exports** – glue code that manages instances, pointers, and lifecycle.
3. **TypeScript bindings** – ergonomic classes that hide WASM details.

Understanding how these layers interact makes debugging and extending wasmbind straightforward.

## Contract Declarations

You describe your public API using a simple struct literal in `wasm.zig`:

```zig
pub const exports = .{
    .Chart = Chart,
    .Candle = Candle,
    .format = format,
};
```

Each field must be either:

- `extern struct` (becomes a class in TypeScript)
- Function pointer (becomes a standalone function)

This convention mirrors the `exports` object in WIT/Wasm Component Model.

## Instance Management

Every exported struct gets a managed heap inside the generated code:

```zig
var Chart_instances: std.ArrayListUnmanaged(*Chart) = .{};
var Chart_next_id: u32 = 0;
```

The generated `Chart_init` allocates, stores, and returns a numeric handle. All subsequent calls accept the handle instead of a pointer, which keeps ABI stable and simplifies TypeScript interop.

## Slice Marshaling

Slices are represented as `{ ptr, len }` pairs. wasmbind converts between Zig slices and TypeScript `TypedArray` objects:

1. TypeScript allocates WASM memory via exported `allocate`.
2. Copies JS data into the WASM buffer.
3. Calls the exported method with pointer + length.
4. Generated Zig code reconstructs the slice and calls your method.

Return slices invert the flow with cached `_ptr` / `_len` helper exports.

## Lifecycle Hooks

Two functions are always emitted:

- `__wasmbind_init` – clears all instance arrays, resets counters.
- `__wasmbind_deinit` – calls `deinit` on every live instance and frees memory.

TypeScript bindings automatically call `__wasmbind_init` after instantiating the module, and provide `.destroy()` helpers that delegate to `deinit`.

## Memory Ownership

- Zig owns struct instances and raw memory.
- TypeScript borrows data through typed array views.
- Strings are copied on demand via UTF-8 encoding.

This strict ownership avoids use-after-free bugs and mirrors Rust’s `wasm-bindgen` approach.

## Build Integration

`wasmbind.generate` wires everything together:

1. Builds the user’s WASM artifact.
2. Compiles a host-side runner that imports `wasm.zig` and runs the code generator with real type info.
3. Writes `exports.zig` + `bindings.ts` to the configured output directory.
4. Adds the generated Zig file as the root module for the WASM build.

Because the runner is a normal Zig executable, it benefits from the same allocator, error handling, and logging infrastructure as your application.

## TypeScript Classes

Each extern struct becomes a class with:

- Constructor → calls `Type_init`
- Methods → call `Type_method`
- Automatic marshaling for parameters and return values
- `destroy()` → calls `Type_deinit`
- Private helpers for memory allocation, caching WASM exports, and managing the module instance

The bindings are tree-shakeable ES modules, so bundlers can eliminate unused exports.

## Summary Diagram

```
┌──────────┐      codegen       ┌──────────────┐      loader       ┌────────────┐
│ wasm.zig │ ─────────────────▶ │ exports.zig  │ ────────────────▶ │ chart-demo │
└──────────┘                    └──────────────┘                   └────────────┘
         ▲                              ▲                                   │
         │ introspection                │ import wasm_contract              │
         │                              │                                   ▼
   ┌────────────┐                 ┌──────────────┐                 ┌─────────────────┐
   │ codegen_ts │◀─────────────── │ bindings.ts  │ ◀────────────── │ browser / node  │
   └────────────┘  TypeScript     └──────────────┘                 └─────────────────┘
```

Understanding these building blocks sets the stage for the deep dives in subsequent chapters.
