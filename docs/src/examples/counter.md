# Counter Component

A minimal example that demonstrates the full Zig → WASM → TypeScript pipeline.

## Zig Implementation

```zig
// src/counter.zig
pub const Counter = extern struct {
    value: i32,

    pub fn init(initial: i32) Counter {
        return .{ .value = initial };
    }

    pub fn increment(self: *Counter) void {
        self.value += 1;
    }

    pub fn get(self: *const Counter) i32 {
        return self.value;
    }
};
```

```zig
// src/wasm.zig
const Counter = @import("counter.zig").Counter;

pub const exports = .{
    .Counter = Counter,
};
```

## Build Script

```zig
const std = @import("std");
const wasmbind = @import("wasmbind");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const wasm = b.addExecutable(.{
        .name = "counter",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/wasm.zig"), .target = target }),
    });

    wasmbind.generate(b, wasm, .{
        .output_dir = "www/generated",
    });

    b.installArtifact(wasm);
}
```

## TypeScript Usage

```ts
import { Counter, loadWasm } from './generated/bindings.js';

const wasm = await loadWasm('../zig-out/lib/counter.wasm');
const counter = new Counter(wasm, 0);

document.querySelector('#inc')!.addEventListener('click', () => {
  counter.increment();
  document.querySelector('#value')!.textContent = counter.get().toString();
});
```

## HTML

```html
<button id="inc">Increment</button>
<p>Value: <span id="value">0</span></p>
```

This example is the best starting point for understanding class generation, handle management, and slice-free APIs.
