# Best Practices

A collection of guidelines distilled from building multiple WASM products with wasmbind.

## Keep Contracts Lean

- Only expose methods you expect to call from JavaScript.
- Keep exported structs small and prefer handles for referencing large internal state.
- Split read/write APIs when convenient (`getFoo`, `setFoo`).

## Validate Early

Use Zig’s `std.debug.assert` or `error` returns to validate inputs. Invalid handles or out-of-range parameters should fail immediately.

```zig
pub fn setIndex(self: *Chart, idx: usize) !void {
    if (idx >= self.points.len) return error.OutOfBounds;
    self.index = idx;
}
```

## Avoid Global State

Each WASM module instance should own its resources. Avoid global mutable state unless necessary; it complicates embedder behavior (multiple tabs/workers).

## Document ABI Expectations

When exposing structs to JavaScript, include documentation comments explaining units, range, and invariants. TypeScript will display the docstrings inside editors.

```zig
/// Width in pixels of the chart canvas
width: u32,
```

## Consistent Naming

- Zig exports → `PascalCase`
- Functions → `verbNoun`
- TypeScript classes mirror Zig names; keep them human-friendly.

## Deterministic Builds

- Pin Zig versions in CI.
- Track npm lockfiles for each example.
- Use `zig build test --summary all` locally before pushing.

## Benchmark Regularly

`zig build bench` should include microbenchmarks for hot paths (render loops, math kernels). Compare ReleaseFast vs ReleaseSmall to choose the right profile for deployment.

## Test Both Sides

- Zig unit tests validate core logic.
- TypeScript tests ensure bindings behave correctly (marshaling, error propagation).
- End-to-end tests spawn a headless browser (Playwright) and load the WASM module.

## Observe in Production

- Surface metrics such as WASM instantiation time, memory usage, and frame rates.
- Add feature flags to toggle new bindings without redeploying the entire app.

## Automate Everything

The provided GitHub Actions workflows run formatters, tests, WASM validation, docs builds, and release packaging. Keep pipelines green to maintain confidence in the toolchain.

Following these practices keeps your WASM surface area predictable, debuggable, and friendly for downstream consumers.
