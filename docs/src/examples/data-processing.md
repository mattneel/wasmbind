# Data Processing Pipeline

This conceptual example illustrates how to use wasmbind for compute-heavy tasks such as data normalization, compression, or analytics.

## Scenario

You receive large batches of telemetry data in the browser and need to:

1. Parse records
2. Normalize values
3. Aggregate statistics
4. Return results to JavaScript

## Zig API

```zig
pub const Stats = extern struct {
    count: u64,
    min: f64,
    max: f64,
    mean: f64,
};

pub const Processor = extern struct {
    pub fn init() Processor {
        return .{};
    }

    pub fn process(self: *Processor, samples: []const f64) Stats {
        _ = self;
        if (samples.len == 0) return .{ .count = 0, .min = 0, .max = 0, .mean = 0 };
        var min = samples[0];
        var max = samples[0];
        var sum: f64 = 0;
        for (samples) |value| {
            if (value < min) min = value;
            if (value > max) max = value;
            sum += value;
        }
        return .{
            .count = samples.len,
            .min = min,
            .max = max,
            .mean = sum / @as(f64, @floatFromInt(samples.len)),
        };
    }
};
```

## TypeScript Usage

```ts
const wasm = await loadWasm('processor.wasm');
const processor = new Processor(wasm);

const batch = new Float64Array(10_000);
// fill batch ...
const stats = processor.process(batch);
console.log(stats.mean);
```

No manual marshaling is required—wasmbind handles the TypedArray ↔ slice conversion.

## Performance Tips

- Preallocate TypedArrays and reuse them to avoid GC overhead.
- Use `ReleaseFast` builds for compute-heavy modules.
- Run `wasm-opt -O3` on the final `.wasm` to squeeze out extra performance.
- Benchmark both Zig and JavaScript implementations to validate gains.

Data processing is a perfect match for wasmbind because it benefits from Zig’s low-level control while keeping the JS API ergonomic.
