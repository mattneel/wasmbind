# Advanced Features

Beyond the core workflow, wasmbind exposes hooks for advanced scenarios.

## Custom Imports

Pass additional imports to `loadWasm`:

```ts
const wasm = await loadWasm('module.wasm', {
  env: {
    log(ptr: number, len: number) {
      console.log(readString(ptr, len));
    },
  },
});
```

Your Zig code can declare `extern fn log(ptr: [*]const u8, len: usize) void;` and call it from anywhere.

## Feature Flags

Use Zig build options to toggle behavior:

```zig
pub const enable_tracing = @import("std").builtin.mode == .Debug;

pub fn render(self: *Chart) void {
    if (enable_tracing) std.log.info("render", .{});
}
```

Expose them to TypeScript by generating different bindings per configuration (ReleaseSmall vs ReleaseFast) or bundling multiple `.wasm` variants.

## Multithreading

WASM threads are still experimental, but wasmbind places no additional restrictions. Spawn worker threads in JavaScript and instantiate the module per worker. Shared state should live in JS or an external service.

## Streaming Compilation

`loadWasm` accepts `Response` objects, so browsers can instantiate modules while downloading:

```ts
await loadWasm(await fetch('chart-demo.wasm'));
```

For Node.js, use `fs.promises.readFile` and pass the `ArrayBuffer`.

## Custom Memory Strategies

If you need a different allocator (arena, bump, etc.), modify the generated code or fork the codegen to inject your own. Ensure `allocate`/`deallocate` continue to behave as expected for TypeScript.

## Hot Reloading

Because wasmbind stores state in Zig and exposes handles, you can hot reload TypeScript without restarting Zig instances by keeping the WASM module alive and replacing the JS bindings. When reloading the WASM itself, call `__wasmbind_deinit` first to avoid leaks.

## Integration with Other Tooling

- **wit-bindgen / WIT** – Use wasmbind for Zig ↔ TS; use WIT for Component Model projects that need multi-language support.
- **wasm-opt** – Run `wasm-opt -Oz` on `zig-out/lib/*.wasm` to squeeze out extra bytes.
- **wizer** – Pre-initialize modules (e.g., instantiate global state) before shipping to browsers.

## Embedding in Native Hosts

wasmbind-generated WASM modules are just WASM binaries. You can embed them in Rust, Go, or C++ hosts using `wasmtime`, `wasmer`, or browser engines. Just remember to call `__wasmbind_init` after instantiation and `__wasmbind_deinit` before dropping the instance.

These advanced techniques allow you to tailor wasmbind to a wide variety of deployment targets.
