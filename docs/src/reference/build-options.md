# Build Options

`wasmbind.generate` accepts a `GenerateOptions` struct and respects standard Zig build flags. This page documents every option and how it affects the generated output.

## GenerateOptions

```zig
pub const GenerateOptions = struct {
    output_dir: []const u8,
    wasm_contract: ?std.Build.LazyPath = null,
    debug: bool = false,
};
```

### `output_dir`

Directory (relative to the project root) where `exports.zig` and `bindings.ts` are written. Example: `"www/generated"`.

### `wasm_contract`

Explicit path to the Zig file that declares `pub const exports`. Useful when your WASM build root differs from the contract location. Defaults to `wasm_lib.root_module.root_source_file`.

### `debug`

When `true`, prints helpful logs:

```
[wasmbind] wasm contract: src/wasm.zig
[wasmbind] exports path: www/generated/exports.zig
[wasmbind] ts bindings: www/generated/bindings.ts
```

## Standard Zig Flags

wasmbind honors these standard options:

| Flag | Description |
| ---- | ----------- |
| `-Doptimize` | Propagates ReleaseFast/ReleaseSmall to the WASM target. The generated Zig code contains no additional branching, so ReleaseSmall is often ideal. |
| `-Dtarget` | Set when invoking `b.addExecutable`; must be `wasm32-freestanding` for browser builds. |
| `-Dwasm-use-relocs` | Emerging flag for WASM relocation support (future). |

## Custom Build Steps

Add convenience steps to your build script:

```zig
const docs = b.addSystemCommand(&.{ "mdbook", "build" });
const docs_step = b.step("docs", "Build documentation");
docs_step.dependOn(&docs.step);
```

Chain them with wasmbind:

```zig
const wasm = buildWasm(...);
wasmbind.generate(b, wasm, .{ .output_dir = "www/generated" });
const build_step = b.step("bundle", "Build WASM + docs");
build_step.dependOn(&wasm.install_step.?.step);
build_step.dependOn(docs_step);
```

## Example Build Graph

```
┌───────────────┐
│ addExecutable │
└──────┬────────┘
       │
       ▼
┌───────────────┐
│ wasmbind.generate │
└──────┬────────┘
       │
       ▼
┌───────────────┐    ┌─────────────┐
│ zig-out/lib   │    │ www/generated │
└───────────────┘    └─────────────┘
```

Understanding these options ensures wasmbind integrates cleanly with complex build setups.
