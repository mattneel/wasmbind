# Type Mappings

wasmbind automatically translates Zig types into equivalent TypeScript types. This table summarizes the mappings and the corresponding WASM representation.

| Zig | TypeScript | WASM | Notes |
| --- | ---------- | ---- | ----- |
| `u8/i8` | `number` | `i32` | Values are sign-extended when necessary. |
| `u16/i16` | `number` | `i32` | |
| `u32/i32` | `number` | `i32` | |
| `u64/i64` | `bigint` | `i64` | JS BigInts map directly to 64-bit ints. |
| `f32` | `number` | `f32` | |
| `f64` | `number` | `f64` | |
| `bool` | `boolean` | `i32` | 0 = false, non-zero = true. |
| `[]const u8` | `string` or `Uint8Array` | pair | Automatically UTF-8 encoded. |
| `[]const T` | `TypedArray` | pair | T must be primitive. |
| `extern struct` | `interface` + `class` | struct | Must be `extern` for stable layout. |
| `?T` | `T | null` | varies | Optionals map to nullable types. |

### Structs

Fields remain native Zig types. Example:

```zig
pub const Candle = extern struct {
    close: f64,
    volume: f64,
};
```

```ts
export interface Candle {
  close: number;
  volume: number;
}
```

### Enums

`enum(u8)` → `number` with generated union type. For richer enums use tagged unions and handle results manually (roadmap).

### Functions

Function parameters follow the same mapping rules. `self: *T` is stripped from the TypeScript signature and converted into the implicit `this.id` handle.

### Unsupported Types

- Function pointers (other than `self` methods)
- Arbitrary pointers (`*u8`)
- Non-extern structs
- `comptime` fields / generic functions

### Customizing

For edge cases, create wrapper types that expose a friendly ABI:

```zig
const Serializer = extern struct {
    pub fn encode(self: *Serializer, data: []const u8) []const u8 { ... }
};
```

Expose only `[]const u8` even if the internal representation uses more complex structures.

This conservative set keeps the ABI predictable and easy to reason about.
