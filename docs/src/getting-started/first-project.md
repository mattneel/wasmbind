# Your First Project

This chapter walks through building a production-ready WASM module that exposes a `Chart` API to browsers and Node.js. By the end you will have:

- A Zig library compiled to `wasm32-freestanding`
- Generated Zig exports + TypeScript bindings
- A TypeScript harness that renders into HTML

## 1. Project Skeleton

```bash
mkdir -p chart-app/src chart-app/www chart-app/js
cd chart-app
zig init-exe
```

Replace `src/main.zig` with your contract entry point:

```zig
// src/main.zig
pub usingnamespace @import("wasm.zig");
```

Create `src/chart.zig`:

```zig
const std = @import("std");

pub const Candle = extern struct {
    timestamp: i64,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

pub const Chart = extern struct {
    width: u32,
    height: u32,

    pub fn init(width: u32, height: u32) Chart {
        return .{ .width = width, .height = height };
    }

    pub fn resize(self: *Chart, width: u32, height: u32) void {
        self.width = width;
        self.height = height;
    }

    pub fn render(self: *const Chart) []const u8 {
        _ = self;
        return &.{0xFF, 0x00, 0x00, 0xFF};
    }
};
```

Define the exports:

```zig
// src/wasm.zig
const chart = @import("chart.zig");

pub const exports = .{
    .Chart = chart.Chart,
    .Candle = chart.Candle,
};
```

## 2. Build Integration

Edit `build.zig`:

```zig
const std = @import("std");
const wasmbind = @import("wasmbind");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const optimize = b.standardOptimizeOption(.{});

    const wasm = b.addExecutable(.{
        .name = "chart-app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    wasmbind.generate(b, wasm, .{
        .wasm_contract = b.path("src/wasm.zig"),
        .output_dir = "www/generated",
    });

    b.installArtifact(wasm);
}
```

Run:

```bash
zig build
```

Outputs:

```
zig-out/lib/chart-app.wasm
www/generated/exports.zig
www/generated/bindings.ts
```

## 3. TypeScript Harness

Initialize the web assets:

```bash
cd www
npm init -y
npm install typescript vite
npx tsc --init --target ES2020 --module ES2020
```

Create `www/app.ts`:

```ts
import { Chart, loadWasm } from './generated/bindings.js';

async function main() {
  const wasm = await loadWasm('../zig-out/lib/chart-app.wasm');
  const chart = new Chart(wasm, 800, 480);
  chart.resize(1024, 600);
  const pixels = chart.render();
  console.log('bytes', pixels.length);
  chart.destroy();
}

main();
```

Bundle with Vite or simply run `tsc` and serve the directory:

```bash
npm run build
python -m http.server 8000 -d .
```

Navigate to http://localhost:8000.

## 4. Hot Reload Loop

1. Edit Zig code
2. `zig build` (or `zig build test`)
3. `npm run build`
4. Refresh browser

Use `watchexec` or `entr` to automate:

```bash
ls src/*.zig | entr -r zig build
```

## 5. Production Checklist

- [ ] Run `zig build test -Doptimize=ReleaseSmall`
- [ ] Run `wasm-validate zig-out/lib/*.wasm`
- [ ] Check `wasm-objdump -x` to verify exports
- [ ] Bundle TypeScript and copy assets to CDN bucket
- [ ] Publish documentation updates

You now have a fully working project using wasmbind. Next, explore the [User Guide](../guide/concepts.md) to learn how the pieces fit together.
