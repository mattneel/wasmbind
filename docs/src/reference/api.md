# API Overview

This reference focuses on the Zig API exposed by wasmbind. For TypeScript specifics see [Generated Code](generated-code.md).

## Module Layout

Import wasmbind in `build.zig`:

```zig
const wasmbind = @import("wasmbind");
```

Public symbols:

| Symbol | Description |
| ------ | ----------- |
| `GenerateOptions` | Options struct passed to `generate` |
| `generate` | Registers codegen runner in the build graph |
| `types` | Introspection helpers (for advanced users) |
| `codegen` | Access to the Zig code generator (for experiments) |
| `codegen_ts` | TypeScript generator (internal use) |

## wasmbind.generate

```zig
pub fn generate(
    b: *std.Build,
    wasm_lib: *std.Build.Step.Compile,
    options: GenerateOptions,
) void
```

### Parameters

- `b` – the build context.
- `wasm_lib` – the compile step returned by `b.addExecutable` targeting `wasm32`.
- `options`:
  - `output_dir` – relative path where generated files are written (e.g. `"www/generated"`).
  - `wasm_contract` – `std.Build.LazyPath` pointing to the Zig file that defines `pub const exports`. If omitted, `wasm_lib.root_module.root_source_file` is used.
  - `debug` – enable verbose logging.

### Behavior

1. Compiles the host-side `codegen_runner` executable.
2. Runs it, passing the contract and output paths.
3. Writes `exports.zig` and `bindings.ts`.
4. Reconfigures `wasm_lib` to use `exports.zig` as its root and adds the contract as an anonymous import.
5. Disables the entry point so the `.wasm` artifact exposes only the generated functions.

Call `generate` after wiring your WASM target but before installing artifacts.

## Introspection Helpers

The `wasmbind.types` module contains utilities for advanced metaprogramming:

- `inferTsType(T: type) TsType`
- `introspectStruct(T: type) []const StructField`
- `introspectFunction(func: anytype) FunctionSignature`

Most users never touch these; they power the code generator itself. Still, they can be useful if you want to extend wasmbind or build companion tooling.

## CLI Runner

The `codegen_runner.zig` executable is an implementation detail but doubles as a sample of how to consume the codegen APIs. It:

1. Imports the user’s `wasm.zig` via `addAnonymousImport`.
2. Calls `codegen.generateExports` and `codegen_ts.generateBindings`.
3. Writes the results to disk.

You can fork the runner to experiment with custom output formats.

## TypeScript API

Generated bindings expose:

- `async loadWasm(pathOrBuffer, imports?)` – helper that instantiates the module, calls `__wasmbind_init`, and returns the `WebAssembly.Instance`.
- Classes per exported struct with methods mirroring the Zig API.
- Standalone functions for exported Zig functions.
- Memory helpers (`allocate`, `deallocate`).

See [Generated Code](generated-code.md) for details.
