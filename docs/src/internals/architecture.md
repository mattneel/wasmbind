# Architecture

wasmbind is intentionally small but highly composable. The system consists of three main crates/modules:

1. **`src/types.zig`** – compile-time reflection helpers that analyze Zig types.
2. **`src/codegen_zig.zig`** – emits Zig source based on the reflection metadata.
3. **`src/codegen_ts.zig`** – emits TypeScript bindings.

A host-side runner ties them together at build time.

## Build Flow

```
Zig contract ──┐
               │
        (host) │ codegen_runner.zig
               ▼
        ┌────────────┐
        │ codegen    │
        ├────────────┤
        │ types      │
        ├────────────┤
        │ codegen_ts │
        └────────────┘
               │
               ├─→ exports.zig
               └─→ bindings.ts
```

- The runner is compiled for the host (not WASM) so it can load `wasm.zig` with full type info.
- Generated files are written to the user-specified output directory.
- The WASM compile step then imports `exports.zig` as its root module and disables the entry point.

## Contracts as Data

`pub const exports = .{ ... }` is treated as a pure data structure. `types.introspectStruct` walks each extern struct, capturing:

- Field names and types
- Function declarations and signatures
- Attributes (pub, extern, layout)

Because this happens at comptime, there’s zero runtime overhead.

## Zig Codegen

`codegen_zig.zig` builds a `std.ArrayList(u8)` and progressively writes:

1. File header + imports
2. Global allocator definitions
3. Instance storage per struct
4. Method wrappers (init, regular, slice returns)
5. Lifecycle + allocation exports

The generator is deterministic and produces formatted output, so you can diff regen results easily.

## TypeScript Codegen

`codegen_ts.zig` mirrors the Zig generator but outputs stringified TypeScript:

- Interfaces for extern structs
- Classes with constructors/methods
- Helper functions (`loadWasm`, `marshalArray`, etc.)

This design keeps the TypeScript runtime dependency-free; it’s pure ES2020 code.

## Runner

`codegen_runner.zig` is compiled and executed during `zig build`. It pulls in:

- `wasmbind` modules (codegen, types, TS)
- User contract via `addAnonymousImport("wasm", ...)`

Because it runs as part of the build graph, errors appear in `zig build` output with precise source locations.

## Future Directions

- **Components** – target the WebAssembly Component Model when Zig gains stable support.
- **Incremental builds** – hash the contract and skip regeneration when unchanged.
- **Pluggable generators** – expose hooks for generating Rust, Go, or Python bindings.

The current architecture provides a clean separation of concerns while remaining hackable for contributors.
