# Memory Management

wasmbind’s primary value proposition is memory safety across the Zig ↔ WASM ↔ TypeScript boundary. This chapter explains how objects, slices, and buffers are allocated and freed.

## Global Allocator

Every generated `exports.zig` file defines a single allocator:

```zig
const allocator = std.heap.wasm_allocator;
```

All allocations for instances, temporary buffers, and marshaled slices go through this allocator. Because `std.heap.wasm_allocator` grows linear memory lazily, it works on every host (browser, Deno, Node).

## Instance Storage

Each struct maintains an array of pointers:

```zig
var Chart_instances: std.ArrayListUnmanaged(*Chart) = .{};
```

- `Chart_init` allocates using `allocator.create` and stores the pointer.
- The returned `u32` handle indexes into the array.
- `Chart_deinit` calls the user’s `deinit` (if defined) then `allocator.destroy`.

Handles are monotonically increasing, eliminating reuse bugs. If you need object pooling, implement it inside your Zig type.

## Lifecycle Hooks

- `__wasmbind_init` resets every array and counter. Call it after module instantiation.
- `__wasmbind_deinit` walks each instance array, calls `deinit`, destroys the pointer, and frees backing storage.

JavaScript should invoke `__wasmbind_deinit` before tearing down the WASM module (e.g., when navigating away in a SPA or disposing workers).

## Slice Parameters

For each slice parameter the generator emits:

```zig
const payload_ptr_typed = @as([*]const u8, @ptrFromInt(payload_ptr));
const payload: []const u8 = payload_ptr_typed[0..payload_len];
```

On the TypeScript side:

1. The class encodes/allocates data via exported `allocate`.
2. Copies bytes into the WASM memory buffer (`Uint8Array` view).
3. Calls the exported function with pointer and length.
4. Frees the temporary buffer using exported `deallocate` in a `finally` block.

## Slice Returns

wasmbind implements the same strategy as wasm-bindgen:

- Actual method returns `[]const T`.
- Generated code caches `ptr` + `len` into globals.
- Exposes two exports: `_ptr` and `_len`.
- TypeScript reads both, creates a typed array view, and copies the data if necessary.

This avoids copying large buffers multiple times. When the returned data is immutable (e.g., `[]const u8`), JavaScript can create a view directly over WASM memory.

## Strings

Strings are treated as UTF-8 slices. TypeScript uses `TextEncoder`/`TextDecoder` to convert between JS strings and byte slices. The current implementation copies data in both directions; future versions may reuse shared memory to avoid allocations.

## Error Handling

Functions that return `!T` map to TypeScript methods that throw on error. Zig errors propagate through the generated wrapper and are converted into human-readable strings. See the [Error Handling](error-handling.md) chapter for details.

## Best Practices

- Call `.destroy()` on TypeScript instances to free Zig memory.
- Prefer returning slices/view instead of copying large arrays.
- For APIs that stream large data, expose iterators that chunk data explicitly.
- Use `std.ArrayList` or `std.heap.ArenaAllocator` inside Zig types for complex state.
- Avoid exposing raw pointers or manual `allocator` parameters; let wasmbind manage them.

## Debugging Leaks

1. Enable `zig build test -Dwasmbind-debug-leaks=true` (coming soon) to log allocations.
2. Instrument your TypeScript code to track constructor/destructor counts.
3. Use browser devtools to inspect WASM memory growth over time.

With these guidelines you can confidently manage memory across language boundaries.
