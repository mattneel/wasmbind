# wasmbind: Zero-Overhead Zig/WASM/TypeScript Bindings

**Version:** 0.1.0-dev  
**Philosophy:** Tiger Style - Safety, Performance, Developer Experience

## Overview

wasmbind is a Zig library that automatically generates WebAssembly bindings and TypeScript definitions using pure comptime introspection. No external IDL files, no manual marshaling, no runtime overhead.

**Core Principle:** Write idiomatic Zig. Define one convention file. Get optimal WASM + TypeScript automatically.

## Design Goals

### Safety
- **Zero configuration errors**: Convention over configuration eliminates setup mistakes
- **Type-safe boundaries**: Zig types map directly to TypeScript types, checked at compile time
- **Explicit memory contracts**: All allocations and ownership transfers are explicit
- **Fail-fast validation**: Invalid type mappings cause compile errors, not runtime failures

### Performance
- **Zero runtime overhead**: All binding code generated at compile time
- **Optimal memory layout**: Uses `extern struct` for C-compatible layouts
- **Minimal copies**: Direct memory access where possible, explicit copies when necessary
- **Small binary size**: No generic bloat, concrete types only

### Developer Experience
- **One convention file**: `src/wasm.zig` defines your entire WASM interface
- **Automatic generation**: TypeScript types and WASM exports generated from Zig code
- **Platform-agnostic logic**: Your core code has zero WASM knowledge
- **Instant feedback**: Compile errors for binding issues, not runtime surprises

## User-Facing API

### Project Setup

```bash
# Add wasmbind to your project
zig fetch --save https://github.com/yourname/wasmbind/archive/main.tar.gz
```

```zig
// build.zig.zon
.{
    .name = "my-charts",
    .version = "0.1.0",
    .dependencies = .{
        .wasmbind = .{
            .url = "https://github.com/yourname/wasmbind/archive/main.tar.gz",
            .hash = "...",
        },
    },
}
```

### Build Integration

```zig
// build.zig
const std = @import("std");
const wasmbind = @import("wasmbind");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    
    const wasm = b.addSharedLibrary(.{
        .name = "charts",
        .root_source_file = b.path("src/wasm.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    
    // One line to generate everything
    wasmbind.generate(b, wasm, .{
        .output_dir = "js/src/generated",
    });
    
    b.installArtifact(wasm);
}
```

## Convention: wasm.zig

The **only** file that knows about WASM. Defines the contract.

```zig
// src/wasm.zig
const Chart = @import("chart.zig").Chart;
const Candle = @import("candle.zig").Candle;

// This is the entire interface definition
pub const exports = .{
    .Chart = Chart,
    .Candle = Candle,
};
```

### Supported Export Types

```zig
pub const exports = .{
    // Structs with methods (most common)
    .MyType = MyStruct,
    
    // Standalone functions
    .utilityFunction = myFunction,
    
    // Constants (compile-time known)
    .VERSION = "1.0.0",
    .MAX_SIZE = 1024,
};
```

## Type System

### Primitive Mappings

| Zig Type | TypeScript Type | Notes |
|----------|----------------|-------|
| `u8`, `u16`, `u32` | `number` | Unsigned integers |
| `i8`, `i16`, `i32` | `number` | Signed integers |
| `u64`, `i64` | `bigint` | 64-bit integers |
| `f32`, `f64` | `number` | Floating point |
| `bool` | `boolean` | Boolean |
| `void` | `void` | No return value |

### Struct Requirements

```zig
// ✅ GOOD: extern struct with explicitly sized types
pub const Candle = extern struct {
    timestamp: i64,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
};

// ❌ BAD: regular struct with implicit padding
pub const Candle = struct {
    timestamp: i64,
    open: f64,
    // compiler may insert padding
};

// ❌ BAD: architecture-dependent types
pub const Candle = extern struct {
    timestamp: usize,  // size varies by platform
    value: f64,
};
```

**Rule:** Use `extern struct` with explicitly-sized types (`u32`, `i64`, `f64`, etc.) for all exported structs.

### Slices and Strings

```zig
// Slices become { ptr, len } pairs
pub fn processData(data: []const f64) void { }
// TypeScript: processData(data: Float64Array): void

// Strings are UTF-8 byte slices
pub fn setLabel(label: []const u8) void { }
// TypeScript: setLabel(label: string): void
```

### Pointers and Ownership

```zig
// Opaque handles for instances
pub const Chart = struct {
    width: u32,
    height: u32,
    
    // Creates new instance, returns handle
    pub fn init(width: u32, height: u32) Chart {
        return .{ .width = width, .height = height };
    }
    
    // Methods take pointer to instance
    pub fn render(self: *Chart) []const u8 {
        // implementation
    }
    
    // Cleanup if needed
    pub fn deinit(self: *Chart) void {
        // cleanup
    }
};
```

## Generated Outputs

### 1. Zig Export Wrappers (`generated/exports.zig`)

```zig
// Auto-generated by wasmbind
const std = @import("std");
const Chart = @import("../chart.zig").Chart;
const Candle = @import("../candle.zig").Candle;

// Global allocator for WASM
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Instance storage
var chart_instances: std.ArrayList(*Chart) = undefined;
var next_chart_id: u32 = 0;

// Lifecycle
export fn __wasmbind_init() void {
    chart_instances = std.ArrayList(*Chart).init(allocator);
}

export fn __wasmbind_deinit() void {
    for (chart_instances.items) |instance| {
        instance.deinit();
        allocator.destroy(instance);
    }
    chart_instances.deinit();
}

// Chart exports
export fn chart_init(width: u32, height: u32) u32 {
    const instance = allocator.create(Chart) catch unreachable;
    instance.* = Chart.init(width, height);
    chart_instances.append(instance) catch unreachable;
    const id = next_chart_id;
    next_chart_id += 1;
    return id;
}

export fn chart_render(id: u32, out_ptr: *usize, out_len: *usize) void {
    const instance = chart_instances.items[id];
    const data = instance.render();
    out_ptr.* = @intFromPtr(data.ptr);
    out_len.* = data.len;
}

export fn chart_deinit(id: u32) void {
    const instance = chart_instances.items[id];
    instance.deinit();
    allocator.destroy(instance);
}
```

### 2. TypeScript Bindings (`generated/bindings.ts`)

```typescript
// Auto-generated by wasmbind

export interface Candle {
  timestamp: bigint;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export class Chart {
  private wasm: WebAssembly.Instance;
  private memory: WebAssembly.Memory;
  private id: number;

  constructor(wasm: WebAssembly.Instance, width: number, height: number) {
    this.wasm = wasm;
    this.memory = wasm.exports.memory as WebAssembly.Memory;
    this.id = (wasm.exports.chart_init as Function)(width, height);
  }

  render(): Uint8Array {
    const ptrBuf = new BigUint64Array(1);
    const lenBuf = new BigUint64Array(1);
    
    (this.wasm.exports.chart_render as Function)(
      this.id,
      ptrBuf,
      lenBuf
    );
    
    const ptr = Number(ptrBuf[0]);
    const len = Number(lenBuf[0]);
    
    return new Uint8Array(this.memory.buffer, ptr, len);
  }

  destroy(): void {
    (this.wasm.exports.chart_deinit as Function)(this.id);
  }
}

export async function loadWasm(wasmPath: string) {
  const response = await fetch(wasmPath);
  const bytes = await response.arrayBuffer();
  const { instance } = await WebAssembly.instantiate(bytes);
  
  // Initialize wasmbind
  (instance.exports.__wasmbind_init as Function)();
  
  return instance;
}
```

## Memory Management

### Strategy: Explicit Ownership

1. **Zig owns all memory**: WASM module manages all allocations
2. **Handles not pointers**: TypeScript receives opaque IDs, not raw pointers
3. **Explicit lifetime**: Users must call `destroy()` or `deinit()`
4. **No shared memory**: Data is copied across the boundary when necessary

### Return Value Handling

```zig
// For structs: return by value (copied out)
pub fn getCandle(self: *Chart, index: u32) Candle {
    return self.candles[index];  // Copied to JS
}

// For large data: return slice (pointer + length)
pub fn render(self: *Chart) []const u8 {
    return self.pixel_buffer;  // JS reads from WASM memory
}
```

### Buffer Passing

```zig
// JS allocates, Zig reads
pub fn addCandles(self: *Chart, candles: []const Candle) void {
    // candles points into WASM linear memory
    // JS wrote data there before calling
}

// Zig allocates, JS reads
pub fn getCandles(self: *Chart) []const Candle {
    // Returns pointer into WASM memory
    // JS reads from there
}
```

## Error Handling

### Zig Side

```zig
// Methods that can fail return error unions
pub fn addCandle(self: *Chart, candle: Candle) !void {
    if (self.candles.items.len >= self.max_candles) {
        return error.TooManyCandles;
    }
    try self.candles.append(candle);
}
```

### Generated Wrapper

```zig
export fn chart_addCandle(id: u32, candle: Candle) i32 {
    const instance = chart_instances.items[id];
    instance.addCandle(candle) catch |err| {
        return -@intFromError(err);
    };
    return 0;  // Success
}
```

### TypeScript Side

```typescript
addCandle(candle: Candle): void {
  const result = (this.wasm.exports.chart_addCandle as Function)(
    this.id,
    candle
  );
  if (result < 0) {
    throw new Error(`addCandle failed with code ${result}`);
  }
}
```

## wasmbind Library Structure

```
wasmbind/
├── build.zig              # Library build
├── build.zig.zon          # Package manifest
├── SPEC.md                # This file
└── src/
    ├── wasmbind.zig       # Public API
    ├── introspect.zig     # Comptime type walking
    ├── codegen_zig.zig    # Generate exports.zig
    ├── codegen_ts.zig     # Generate bindings.ts
    └── types.zig          # Type mapping logic
```

## Implementation Phases

### Phase 1: Core Types (Week 1)
- [x] Primitive type mappings
- [x] `extern struct` support
- [x] Simple functions
- [ ] Generate exports.zig
- [ ] Generate bindings.ts

### Phase 2: Memory & Slices (Week 2)
- [ ] Slice handling (ptr + len)
- [ ] String support (UTF-8)
- [ ] Buffer allocation helpers
- [ ] Memory safety checks

### Phase 3: Instances & State (Week 3)
- [ ] Opaque handle system
- [ ] Instance lifecycle
- [ ] Method generation
- [ ] Cleanup/deinit

### Phase 4: Error Handling (Week 4)
- [ ] Error union support
- [ ] Error code generation
- [ ] TypeScript error wrapping

### Phase 5: Polish (Week 5)
- [ ] Documentation generation
- [ ] Example projects
- [ ] Performance testing
- [ ] API refinement

## Example: Full Stack

### Zig Code (Platform-Agnostic)

```zig
// src/chart.zig
const std = @import("std");
const Candle = @import("candle.zig").Candle;

pub const Chart = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    candles: std.ArrayList(Candle),

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Chart {
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .candles = std.ArrayList(Candle).init(allocator),
        };
    }

    pub fn addCandle(self: *Chart, candle: Candle) !void {
        try self.candles.append(candle);
    }

    pub fn render(self: *Chart) []const u8 {
        // Render to pixel buffer
        return &.{};  // Simplified
    }

    pub fn deinit(self: *Chart) void {
        self.candles.deinit();
    }
};

test "chart works" {
    var chart = try Chart.init(std.testing.allocator, 800, 600);
    defer chart.deinit();
    
    try chart.addCandle(.{
        .timestamp = 1234567890,
        .open = 100.0,
        .high = 105.0,
        .low = 99.0,
        .close = 103.0,
        .volume = 50000.0,
    });
    
    try std.testing.expect(chart.candles.items.len == 1);
}
```

### WASM Contract

```zig
// src/wasm.zig
pub const exports = .{
    .Chart = @import("chart.zig").Chart,
    .Candle = @import("candle.zig").Candle,
};
```

### TypeScript Usage

```typescript
// app.ts
import { Chart, Candle, loadWasm } from './generated/bindings.js';

const wasm = await loadWasm('charts.wasm');
const chart = new Chart(wasm, 800, 600);

chart.addCandle({
  timestamp: 1234567890n,
  open: 100.0,
  high: 105.0,
  low: 99.0,
  close: 103.0,
  volume: 50000.0,
});

const pixels = chart.render();
// pixels is Uint8Array pointing into WASM memory

chart.destroy();
```

## Design Rationale

### Why Not WIT/Component Model?
- **Overhead**: Component Model adds abstraction layers we don't need
- **Complexity**: WIT is another IDL to learn
- **Control**: Direct WASM gives us maximum performance control

### Why Convention Over Configuration?
- **Safety**: Fewer configuration options = fewer ways to misconfigure
- **Simplicity**: One file (`wasm.zig`) to understand
- **Ergonomics**: Less boilerplate, more signal

### Why Opaque Handles?
- **Safety**: Raw pointers in JS are dangerous
- **Control**: Zig manages memory, JS just holds IDs
- **Clear ownership**: Who owns what is always explicit

### Why Tiger Style?
- **Safety**: Explicit types, fail-fast, zero ambiguity
- **Performance**: Designed for performance from day one
- **DX**: Great names, clear structure, obvious organization

## Non-Goals

- ❌ **Not a generic bridge**: Optimized for Zig→WASM→TS, not all languages
- ❌ **Not bidirectional by default**: JS can't call into Zig callbacks (yet)
- ❌ **Not dynamic**: Everything determined at compile time
- ❌ **Not a Component Model replacement**: Direct WASM only

## Success Criteria

1. **Zero configuration**: Just write `wasm.zig`
2. **Type safety**: Compile errors for mismatches
3. **Performance**: Faster than hand-written bindings
4. **Simplicity**: Can explain in 5 minutes

## License

Apache-2.0

## Contributors

Autark (github.com/mattneel)

---

*This is a living document. As wasmbind evolves, so does this spec.*
```
