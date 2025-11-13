# Quick Start

Build a working WASM module + TypeScript UI in minutes.

## 1. Scaffold Project

```bash
mkdir hello-wasmbind
cd hello-wasmbind
zig init-exe
```

## 2. Add wasmbind Dependency

Update `build.zig.zon` as described in [Installation](installation.md) and run `zig fetch --save wasmbind`.

## 3. Define Contract

```zig
// src/wasm.zig
const Counter = @import("counter.zig").Counter;

pub const exports = .{
    .Counter = Counter,
};
```

```zig
// src/counter.zig
pub const Counter = extern struct {
    value: i32,

    pub fn init(initial: i32) Counter {
        return .{ .value = initial };
    }

    pub fn increment(self: *Counter, step: i32) void {
        self.value += step;
    }

    pub fn get(self: *const Counter) i32 {
        return self.value;
    }
};
```

## 4. Configure Build

```zig
const std = @import("std");
const wasmbind = @import("wasmbind");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const wasm = b.addExecutable(.{
        .name = "counter",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/wasm.zig"), .target = target }),
    });

    wasmbind.generate(b, wasm, .{ .output_dir = "www/generated" });
    b.installArtifact(wasm);
}
```

## 5. Build

```bash
zig build
```

Results:

```
zig-out/lib/counter.wasm
www/generated/exports.zig
www/generated/bindings.ts
```

## 6. TypeScript Harness

```ts
// www/app.ts
import { Counter, loadWasm } from './generated/bindings.js';

async function main() {
  const wasm = await loadWasm('../zig-out/lib/counter.wasm');
  const counter = new Counter(wasm, 0);
  counter.increment(5);
  document.body.innerText = `Value: ${counter.get()}`;
  counter.destroy();
}

main();
```

Compile TS:

```bash
cd www
npm install typescript --save-dev
npx tsc --init --target ES2020 --module ES2020
npx tsc --project tsconfig.json
```

Serve:

```bash
python -m http.server 8000 -d .
```

Visit http://localhost:8000 to see the output.

## 7. Iterate

- Modify Zig logic → `zig build`
- Rebuild TypeScript → `npm run build`
- Refresh browser

You now have the minimal workflow running. Dive into [Your First Project](first-project.md) for a full-stack example.
