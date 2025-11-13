# Chart Demo

End-to-end sample showing how `wasmbind` turns a Zig contract into a fully typed WASM module plus TypeScript bindings.

## Requirements

- Zig 0.15.2 or newer
- Node.js (for compiling the small TypeScript helper)

## Workflow

```bash
cd examples/chart-demo

# 1. Run the native tests for the shared logic
zig build test

# 2. Build the WASM module and generate bindings
zig build

# 3. Compile the TypeScript harness (emits app.js + generated bindings)
npx tsc --project www/tsconfig.json

# 4. Serve the web app (any static server works)
python -m http.server 8000 -d www
# Visit http://localhost:8000
```

The generated Zig exports live in `www/generated/exports.zig` (consumed by the build),
while TypeScript bindings land in `www/generated/bindings.ts`. The TS compiler then
produces `bindings.js` alongside `app.js`, ready to be loaded by the demo.
