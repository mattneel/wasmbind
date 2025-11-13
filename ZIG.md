# Ztorch Zig 0.15.x Quick Reference: DOs and DON'Ts

## Language Syntax

### ❌ DON'T use `usingnamespace`

```zig
// WRONG - Removed in 0.15.x
pub usingnamespace @import("other.zig");
```

### ✅ DO use explicit declarations or conditionals

```zig
// RIGHT
pub const foo = other.foo;
pub const bar = other.bar;

// OR for conditional inclusion:
pub const init = if (condition) initWindows else initLinux;
```

---

## I/O and Printing

### ❌ DON'T use old generic writer API

```zig
// WRONG
const stdout = std.io.getStdOut().writer();
try stdout.print("...", .{});
```

### ✅ DO provide explicit buffer to writer

```zig
// RIGHT
var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;

try stdout.print("...", .{});
try stdout.flush(); // Always flush!
```

---

## Format Strings

### ❌ DON'T use `{}` for custom types with format methods

```zig
// WRONG
std.debug.print("{}", .{my_custom_type});
```

### ✅ DO use `{f}` to call format methods explicitly

```zig
// RIGHT
std.debug.print("{f}", .{my_custom_type});
```

### ❌ DON'T pass format string to format() method

```zig
// WRONG
pub fn format(
    self: @This(),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void { ... }
```

### ✅ DO use new simplified format signature

```zig
// RIGHT
pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print("value: {d}", .{self.value});
}
```

---

## Casts

### ❌ DON'T pass the target type to the cast builtin

```zig
// WRONG
const counter: u64 = @intCast(u64, input);
const seconds: f64 = @floatFromInt(f64, nanoseconds);
```

### ✅ DO use `@as` with the dedicated cast routines

```zig
// RIGHT
const counter = @as(u64, @intCast(input));
const seconds = @as(f64, @floatFromInt(nanoseconds));
```

These casts are now single-argument functions in Zig 0.15.x; wrap the result with `@as` to bind the target type.

### ✅ DO remember that the helper returns the *source* type

The helper builtins (`@intCast`, `@floatCast`, `@floatFromInt`, …) now return a value whose type is inferred from the operand.
Use `@as` (or the inferred type via `var`) to coerce to the destination.

```zig
const src_f16: f16 = 1.5;
const dst_f32 = @as(f32, @floatCast(src_f16)); // ✅ explicit destination

const src_i16: i16 = 42;
var dst_i32: i32 = undefined;
dst_i32 = @as(i32, @intCast(src_i16));        // ✅ widening cast
```

Skips to `@floatCast(f32, src)` or `@intCast(i32, src)` will not compile anymore.

---

## ArrayList

### ❌ DON'T expect allocator field in ArrayList

```zig
// WRONG - ArrayList doesn't store allocator anymore
var list = std.ArrayList(u8).init(allocator);
try list.append(item); // No allocator stored!
```

### ✅ DO pass allocator to each operation

```zig
// RIGHT - Unmanaged by default
var list = std.ArrayList(u8){};
try list.append(allocator, item);
try list.appendSlice(allocator, items);
list.deinit(allocator);

// OR use Managed if you really want allocator field
var list = std.array_list.Managed(u8).init(allocator);
try list.append(item);
```

---

## File Operations

### ❌ DON'T use deprecated reader()/writer()

```zig
// WRONG
const file = try std.fs.cwd().openFile("file.txt", .{});
const reader = file.reader(); // Deprecated!
```

---

## Inline PTX Assembly (NVPTX Targets)

- Use `callconv(.kernel)` and `pub export` on kernel entry points so Zig marks them visible in emitted PTX (`.entry`).
- Inline PTX can be injected with Zig’s `asm` expression. Example (`examples/inline_ptx.zig`):

  ```zig
  pub export fn inlineAsmKernel(out: [*]u32, len: usize) callconv(.kernel) void {
      if (len == 0) return;
      const tid = asm volatile ("mov.u32 %0, %tid.x;"
          : [ret] "=r" (-> u32)
      );
      if (tid == 0) out[0] = 123;
  }
  ```

- The test suite compiles both `examples/hello_gpu.zig` and `examples/inline_ptx.zig` with:

  ```sh
  zig build-obj kernel.zig \
      -target nvptx64-cuda \
      -femit-llvm-ir=out/kernel.ll \
      -femit-llvm-bc=out/kernel.bc \
      -fno-emit-bin -fno-emit-asm
  llc -march=nvptx64 -mcpu=sm_89 -filetype=asm -o out/kernel.ptx out/kernel.ll
  ```

  and asserts that `.entry ...` plus inline instructions (`mov.u32`) appear in the generated PTX.

### ✅ DO use new buffer-aware API

```zig
// RIGHT
const file = try std.fs.cwd().openFile("file.txt", .{});
var buffer: [4096]u8 = undefined;
var file_reader = file.reader(&buffer);
const reader = &file_reader.interface;
```

---

## Inline Assembly Clobbers

### ❌ DON'T use string clobbers

```zig
// WRONG
asm volatile ("syscall"
    : [ret] "={rax}" (-> usize),
    : [num] "{rax}" (number),
    : "rcx", "r11"  // String clobbers!
);
```

### ✅ DO use typed clobbers

```zig
// RIGHT
asm volatile ("syscall"
    : [ret] "={rax}" (-> usize),
    : [num] "{rax}" (number),
    : .{ .rcx = true, .r11 = true }  // Typed!
);
```

Run `zig fmt` to auto-upgrade this!

---

## Compression (flate/zlib/gzip)

### ❌ DON'T use old compress API

```zig
// WRONG
var decompress = try std.compress.zlib.decompressor(reader);
```

### ✅ DO use new unified flate API

```zig
// RIGHT
var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
var decompress: std.compress.flate.Decompress = .init(reader, .zlib, &decompress_buffer);
const decompress_reader = &decompress.reader;
```

---

## Data Structures

### ❌ DON'T use BoundedArray

```zig
// WRONG - Removed
var stack = try std.BoundedArray(i32, 8).fromSlice(items);
```

### ✅ DO use ArrayList with stack buffer

```zig
// RIGHT
var buffer: [8]i32 = undefined;
var stack = std.ArrayListUnmanaged(i32).initBuffer(&buffer);
try stack.appendSliceBounded(items);
```

### ❌ DON'T use generic LinkedList

```zig
// WRONG
var list = std.DoublyLinkedList(MyType).init();
```

### ✅ DO use intrusive list with @fieldParentPtr

```zig
// RIGHT
const MyType = struct {
    node: std.DoublyLinkedList.Node = .{},
    data: i32,
};

var list: std.DoublyLinkedList = .{};
// Use @fieldParentPtr("node", node_ptr) to get back to MyType
```

---

## Error Handling in undefined

### ❌ DON'T do arithmetic on undefined

```zig
// WRONG - Compile error in 0.15.x
const a: u32 = 0;
const b: u32 = undefined;
const c = a + b; // ERROR: use of undefined causes illegal behavior
```

### ✅ DO avoid operations on undefined

```zig
// RIGHT - Don't use undefined in arithmetic
const a: u32 = 0;
const b: u32 = 0; // Use actual value or @import("std").mem.zeroes(u32)
const c = a + b;
```

---

## Pointers and Casting

### ✅ DO use @ptrCast for single-item to slice

```zig
// NEW in 0.15.x - This now works!
const val: u32 = 1;
const bytes: []const u8 = @ptrCast(&val);
// Returns slice of same byte size as operand
```

### ✅ DO use the new numeric casts

```zig
// ints -> floats
const items: usize = 42;
const weight: f32 = @as(f32, @floatFromInt(items));

// float width changes
const precise: f64 = 3.1415926535;
const pi_approx: f32 = @floatCast(precise);

// ints -> narrower ints (panics on overflow in Debug)
const index: usize = 128;
const idx_i32: i32 = @intCast(index);
```

### ❌ DON'T rely on implicit coercion

```zig
// WRONG: no more implicit float narrowing
const precise: f64 = 3.14;
const pi: f32 = precise; // Compile error
```

### ✅ DO use @as for explicit coercion

```zig
// RIGHT: @as documents intent and stays future proof
const precise: f64 = 3.14;
const pi: f32 = @floatCast(precise);
const total: usize = @as(usize, @intCast(@max(10, 5)));
```

---

## Switch on Non-Exhaustive Enums

### ✅ DO mix explicit tags with `_` prong

```zig
// NEW in 0.15.x - This is now allowed
switch (enum_val) {
    .special_case_1 => foo(),
    .special_case_2 => bar(),
    _, .special_case_3 => baz(),  // Mix unnamed (_) with named
}
```

---

## Build System

### ❌ DON'T use implicit root module fields

```zig
// WRONG - Removed in 0.15.x
const exe = b.addExecutable(.{
    .name = "zros",
    .root_source_file = b.path("src/main.zig"),  // WRONG!
    .target = target,
    .optimize = optimize,
});
```

### ✅ DO use explicit root_module

```zig
// RIGHT
const exe = b.addExecutable(.{
    .name = "zros",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
```

---

## Quick Migration Checklist

1. ✅ Remove all `usingnamespace` (use conditionals or explicit imports)
2. ✅ Update all I/O code to provide explicit buffers
3. ✅ Change `{}` to `{f}` for custom format methods
4. ✅ Remove format strings from format() method signatures
5. ✅ Update ArrayList usage (pass allocator to operations)
6. ✅ Run `zig fmt` to auto-fix inline assembly clobbers
7. ✅ Update build.zig to use root_module
8. ✅ Replace BoundedArray with ArrayList + stack buffer
9. ✅ Update compress/flate API usage
10. ✅ Always flush() writers explicitly

---

## For OS Development (Freestanding)

### ✅ These work in freestanding mode:

```zig
std.mem.*           // Memory operations
std.fmt.*           // Formatting (with your writer)
std.debug.*         // Assertions
std.math.*          // Math
std.ArrayList       // Data structures
std.HashMap         // Data structures
@memcpy, @memset    // Compiler builtins
```

### ❌ These DON'T work in freestanding:

```zig
std.fs.*            // No filesystem yet (you're building it!)
std.net.*           // No network yet (you're building it!)
std.os.*            // You ARE the OS
std.io.*            // Use std.Io.Reader/Writer with your own backend
```

---

## Kernel-Specific Tips

### ✅ DO use explicit buffer management

```zig
// Perfect for kernel - no hidden allocations!
var buffer: [1024]u8 = undefined;
var writer = myDevice.writer(&buffer);
const w = &writer.interface;
try w.print("Kernel message\n", .{});
try w.flush();
```

### ✅ DO use ArrayListUnmanaged for kernel data structures

```zig
// No hidden allocator field - perfect for kernel
var process_list = std.ArrayListUnmanaged(*Process){};
try process_list.append(my_allocator, new_process);
```

### ✅ DO use @memcpy and @memset (compiler builtins)

```zig
// Optimized by LLVM for your target
@memcpy(dest, src);
@memset(buffer, 0);
```

---

## Auto-Fix Tools

Run these to auto-migrate:

```bash
zig fmt           # Fixes inline assembly clobbers
# Manual fixes needed for everything else (sorry!)
```

---

## When in Doubt

1. Check compiler errors - they're usually clear in 0.15.x
2. Look at `lib/std/` source code for examples
3. The new APIs are often _simpler_ than old ones
4. Explicit is better than implicit (Zig philosophy)

---

**Remember:** Most breaking changes make kernel development _easier_ (explicit buffers, simpler APIs, faster compilation).
