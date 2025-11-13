# Chart Demo

`examples/chart-demo` is the canonical showcase shipped with wasmbind. It demonstrates:

- Complex structs with internal storage
- Slice parameters/returns
- TypeScript UI that drives a canvas
- Integration with npm + Vite

## Repository Layout

```
examples/chart-demo/
├── build.zig
├── build.zig.zon
├── src/
│   ├── chart.zig
│   ├── wasm.zig
│   └── root.zig (tests)
└── www/
    ├── app.ts
    ├── index.html
    ├── tsconfig.json
    └── generated/.gitkeep
```

## Zig Highlights

`chart.zig` maintains a pool of chart instances backed by a simple arena. It exercises:

- Fixed-size arrays in exported structs
- Internal heap allocations via `std.heap.wasm_allocator`
- Methods returning typed arrays, strings, and primitive values

`root.zig` contains unit tests verifying initialization and slice behavior.

## TypeScript Highlights

`www/app.ts` uses the generated bindings to:

- Load the WASM module with `loadWasm`
- Construct/destroy chart instances
- Push random candlestick data via `addCandle` and `setSeries`
- Render pixels and draw them onto a `<canvas>` element

The UI is intentionally minimal to keep the WASM/JS boundary front-and-center.

## Running the Demo

```bash
cd examples/chart-demo
zig build test   # run Zig unit tests
zig build        # build WASM + bindings
cd www
npm install
npm run build
python -m http.server 8000 -d .
```

Open http://localhost:8000 to interact with the demo.

## Takeaways

- The generated Zig exports can be treated as your `main.zig` – no manual glue required.
- TypeScript bindings provide a familiar class-based API with automatic memory management.
- The build graph installs the `.wasm` artifact to `zig-out/lib`, enabling deployment to any static host.
