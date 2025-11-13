# Error Handling

wasmbind preserves Zig’s `error` semantics by converting them into idiomatic JavaScript exceptions.

## Zig Error Unions

Any exported function that returns `!T` is wrapped automatically:

```zig
pub fn load(self: *Chart, path: []const u8) !void {
    if (path.len == 0) return error.EmptyPath;
    // ...
}
```

Generated wrapper:

```zig
export fn Chart_load(id: u32, path_ptr: usize, path_len: usize) void {
    // ...
    _ = instance.load(path) catch |err| {
        @panic(@errorName(err));
    };
}
```

TypeScript wrapper catches the panic and throws an `Error` with the Zig error name:

```ts
load(path: string): void {
  try {
    this.callExport('Chart_load', path);
  } catch (err) {
    throw new Error(`Chart.load failed: ${err}`);
  }
}
```

> ✅  Future versions will surface rich error payloads by returning tagged unions.

## Result Values

If your Zig function returns `!T`, TypeScript receives `T` on success or an exception on failure. Prefer this pattern over returning sentinel values.

```zig
pub fn getConfig() !Config { ... }
```

```ts
const cfg = bindings.getConfig(); // throws on error
```

## Panics

Panics inside user code bubble up through the generated wrapper and manifest as thrown JavaScript errors. Include meaningful messages when calling `@panic`.

```zig
@panic("Renderer must be initialized via Chart.init()");
```

## Recoverable Errors

For high-frequency recoverable errors (e.g., validation failures) consider returning a status struct:

```zig
pub const Validation = extern struct {
    ok: bool,
    message: []const u8,
};
```

TypeScript receives a typed object and can respond without throwing.

## Logging

Use `std.log` inside Zig; the generated code does not intercept logging. Route logs to the browser console by providing an `env.log` import when instantiating the module.

## Testing Errors

```zig
test "load fails on empty path" {
    var chart = Chart.init(800, 600);
    try std.testing.expectError(error.EmptyPath, chart.load(""));
}
```

Complement with TypeScript tests using your favorite framework (Vitest, Jest, etc.) to ensure exceptions propagate correctly.

## Summary

- Use Zig error unions for exceptional behavior.
- wasmbind converts Zig errors into JS exceptions.
- Panics bubble up with full messages.
- Provide meaningful error names/messages for diagnostics.
