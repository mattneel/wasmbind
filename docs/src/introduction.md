# Introduction

**wasmbind** is a zero-overhead binding generator for Zig → WASM → TypeScript.

Think of it as `wasm-bindgen` for Zig: define your API once in Zig, and wasmbind automatically generates:
- Zig export wrappers
- TypeScript type definitions
- Memory management glue
- Serialization/deserialization code

## Why wasmbind?

When building WASM modules with Zig, you typically need to:

1. Write Zig code
2. Manually write `extern` exports
3. Write TypeScript declarations
4. Handle memory marshaling
5. Manage instance lifecycle

**wasmbind does all of this automatically** by analyzing your Zig types at compile time.

## Philosophy

wasmbind follows three principles:

1. **Zero Runtime Overhead** - All code generation happens at compile time
2. **Type Safety** - Compile-time type checking across language boundaries
3. **Convention Over Configuration** - Minimal boilerplate, maximum productivity

## How It Works

```zig
// 1. Define your contract
pub const exports = .{
    .Chart = Chart,
};

// 2. Build with wasmbind
wasmbind.generate(b, wasm, .{});

// 3. Use in TypeScript
const chart = new Chart(wasm, 800, 600);
chart.resize(1024, 768);
chart.destroy();
```

That's it! wasmbind handles everything else.

## Quick Comparison

| Feature | Manual | wasm-bindgen | wasmbind |
|---------|--------|--------------|----------|
| Language | Zig | Rust | Zig |
| Type Safety | ❌ | ✅ | ✅ |
| Zero-Cost | ✅ | ✅ | ✅ |
| Compile-time | ⚠️ | ❌ | ✅ |
| Memory Safety | Manual | Auto | Auto |
| Setup Time | Hours | Minutes | Seconds |

## Next Steps

- [Installation](getting-started/installation.md) - Get wasmbind installed
- [Quick Start](getting-started/quick-start.md) - 5-minute tutorial
- [First Project](getting-started/first-project.md) - Build a complete app
