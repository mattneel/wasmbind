const std = @import("std");
const impl = @import("wasmbind.zig");
const types_mod = @import("types.zig");
const codegen_mod = @import("codegen_zig.zig");
const codegen_ts_mod = @import("codegen_ts.zig");

pub const GenerateOptions = impl.GenerateOptions;
pub const generate = impl.generate;
pub const types = types_mod;
pub const codegen = codegen_mod;
pub const codegen_ts = codegen_ts_mod;

const TypeTestError = error{
    TestExpectedSlice,
    TestExpectedString,
    TestExpectedStruct,
    TestExpectedPrimitive,
};

test "primitive type mapping covers core Zig scalars" {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(types.TsPrimitive.number, types.inferPrimitiveTsType(u8));
    try expectEqual(types.TsPrimitive.number, types.inferPrimitiveTsType(i32));
    try expectEqual(types.TsPrimitive.bigint, types.inferPrimitiveTsType(u64));
    try expectEqual(types.TsPrimitive.bigint, types.inferPrimitiveTsType(i64));
    try expectEqual(types.TsPrimitive.number, types.inferPrimitiveTsType(f64));
    try expectEqual(types.TsPrimitive.number, types.inferPrimitiveTsType(f32));
    try expectEqual(types.TsPrimitive.boolean, types.inferPrimitiveTsType(bool));
    try expectEqual(types.TsPrimitive.void, types.inferPrimitiveTsType(void));
}

test "string type is special case of const u8 slice" {
    const ts_type = comptime types.inferTsType([]const u8);
    switch (ts_type) {
        .string => {},
        else => return TypeTestError.TestExpectedString,
    }
    try std.testing.expectEqualStrings("string", types.toTsString(ts_type));
}

test "numeric slices map to TypeScript arrays" {
    const ts_type = comptime types.inferTsType([]const f64);
    switch (ts_type) {
        .slice => |info| {
            try std.testing.expectEqual(types.TsPrimitive.number, info.child);
            try std.testing.expect(info.is_const);
            try std.testing.expectEqual(@as(u16, 64), info.bits);
            try std.testing.expectEqual(types.TsType.SliceScalarKind.float, info.scalar_kind);
            try std.testing.expectEqualStrings("Float64Array", types.toTsString(ts_type));
        },
        else => return TypeTestError.TestExpectedSlice,
    }
}

test "u64 slice maps to BigInt array semantics" {
    const ts_type = comptime types.inferTsType([]const u64);
    switch (ts_type) {
        .slice => |info| {
            try std.testing.expectEqual(types.TsPrimitive.bigint, info.child);
            try std.testing.expectEqual(@as(u16, 64), info.bits);
            try std.testing.expectEqualStrings("BigUint64Array", types.toTsString(ts_type));
        },
        else => return TypeTestError.TestExpectedSlice,
    }
}

test "i8 slice maps to Int8Array" {
    const ts_type = comptime types.inferTsType([]const i8);
    switch (ts_type) {
        .slice => |info| {
            try std.testing.expectEqualStrings("Int8Array", types.toTsString(ts_type));
            try std.testing.expectEqual(types.TsType.SliceScalarKind.integer, info.scalar_kind);
        },
        else => return TypeTestError.TestExpectedSlice,
    }
}

test "mutable u8 slice maps to Uint8Array" {
    const ts_type = comptime types.inferTsType([]u8);
    switch (ts_type) {
        .slice => |info| {
            try std.testing.expect(!info.is_const);
            try std.testing.expectEqualStrings("Uint8Array", types.toTsString(ts_type));
        },
        else => return TypeTestError.TestExpectedSlice,
    }
}

test "i16 slice maps to Int16Array" {
    const ts_type = comptime types.inferTsType([]const i16);
    switch (ts_type) {
        .slice => |info| {
            try std.testing.expectEqual(@as(u16, 16), info.bits);
            try std.testing.expectEqualStrings("Int16Array", types.toTsString(ts_type));
        },
        else => return TypeTestError.TestExpectedSlice,
    }
}

test "u32 slice maps to Uint32Array" {
    const ts_type = comptime types.inferTsType([]const u32);
    switch (ts_type) {
        .slice => |info| {
            try std.testing.expectEqual(@as(u16, 32), info.bits);
            try std.testing.expectEqualStrings("Uint32Array", types.toTsString(ts_type));
        },
        else => return TypeTestError.TestExpectedSlice,
    }
}

test "f32 slice maps to Float32Array" {
    const ts_type = comptime types.inferTsType([]const f32);
    switch (ts_type) {
        .slice => |info| {
            try std.testing.expectEqual(types.TsType.SliceScalarKind.float, info.scalar_kind);
            try std.testing.expectEqualStrings("Float32Array", types.toTsString(ts_type));
        },
        else => return TypeTestError.TestExpectedSlice,
    }
}

test "i64 slice maps to BigInt64Array" {
    const ts_type = comptime types.inferTsType([]const i64);
    switch (ts_type) {
        .slice => |info| {
            try std.testing.expectEqual(@as(u16, 64), info.bits);
            try std.testing.expectEqualStrings("BigInt64Array", types.toTsString(ts_type));
        },
        else => return TypeTestError.TestExpectedSlice,
    }
}

test "extern struct is recognized" {
    const Candle = extern struct {
        timestamp: i64,
        open: f64,
        high: f64,
        low: f64,
        close: f64,
        volume: f64,
    };

    const ts_type = comptime types.inferTsType(Candle);
    switch (ts_type) {
        .@"struct" => |info| {
            try std.testing.expect(info.is_extern);
            try std.testing.expect(std.mem.indexOf(u8, info.name, "Candle") != null);
            try std.testing.expectEqualStrings(@typeName(Candle), types.toTsString(ts_type));
        },
        else => return TypeTestError.TestExpectedStruct,
    }
}

test "introspect extern struct fields" {
    const Candle = extern struct {
        timestamp: i64,
        open: f64,
        volume: f64,
    };

    const fields = types.introspectStruct(Candle);
    try std.testing.expectEqual(@as(usize, 3), fields.len);
    try std.testing.expectEqualStrings("timestamp", fields[0].name);
    switch (fields[0].ts_type) {
        .primitive => |prim| try std.testing.expectEqual(types.TsPrimitive.bigint, prim),
        else => return TypeTestError.TestExpectedPrimitive,
    }
    try std.testing.expectEqualStrings("open", fields[1].name);
    switch (fields[1].ts_type) {
        .primitive => |prim| try std.testing.expectEqual(types.TsPrimitive.number, prim),
        else => return TypeTestError.TestExpectedPrimitive,
    }
}

test "introspect struct with mixed types" {
    const Mixed = extern struct {
        id: u32,
        label_ptr: [*]const u8,
        label_len: usize,
        score: f64,
        active: bool,
    };

    const fields = types.introspectStruct(Mixed);
    try std.testing.expectEqual(@as(usize, 5), fields.len);
    try std.testing.expectEqualStrings("id", fields[0].name);
    try std.testing.expectEqualStrings("active", fields[4].name);
}

test "introspect simple function signature" {
    const sig = types.introspectFunction(testAddFn);
    try std.testing.expectEqual(@as(usize, 2), sig.params.len);
    switch (sig.params[0].ts_type) {
        .primitive => |prim| try std.testing.expectEqual(types.TsPrimitive.number, prim),
        else => return TypeTestError.TestExpectedPrimitive,
    }
    switch (sig.return_type) {
        .primitive => |prim| try std.testing.expectEqual(types.TsPrimitive.number, prim),
        else => return TypeTestError.TestExpectedPrimitive,
    }
}

test "introspect function with slice parameter" {
    const sig = types.introspectFunction(testProcessData);
    try std.testing.expectEqual(@as(usize, 2), sig.params.len);
    switch (sig.params[0].ts_type) {
        .slice => |info| {
            try std.testing.expectEqual(types.TsPrimitive.number, info.child);
            try std.testing.expect(info.is_const);
        },
        else => return TypeTestError.TestExpectedSlice,
    }
    switch (sig.return_type) {
        .primitive => |prim| try std.testing.expectEqual(types.TsPrimitive.boolean, prim),
        else => return TypeTestError.TestExpectedPrimitive,
    }
}

test "introspect void return function" {
    const sig = types.introspectFunction(testNoReturn);
    try std.testing.expectEqual(@as(usize, 1), sig.params.len);
    switch (sig.return_type) {
        .primitive => |prim| try std.testing.expectEqual(types.TsPrimitive.void, prim),
        else => return TypeTestError.TestExpectedPrimitive,
    }
}

test "codegen generates exports for simple struct" {
    const TestStruct = extern struct {
        value: u32,

        pub fn init(val: u32) @This() {
            return .{ .value = val };
        }

        pub fn getValue(self: *const @This()) u32 {
            return self.value;
        }
    };

    const exports_decl = .{ .TestStruct = TestStruct };

    var result = try codegen.generateExports(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(result.exports.len >= 3);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "TestStruct_init") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "TestStruct_getValue") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "__wasmbind_init") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "std.ArrayListUnmanaged(*TestStruct_Type)") != null);
}

test "lifecycle functions initialize instance storage" {
    const TestType = extern struct {
        value: u32,

        pub fn init(value: u32) @This() {
            return .{ .value = value };
        }

        pub fn deinit(self: *@This()) void {
            _ = self;
        }
    };

    const exports_decl = .{ .TestType = TestType };

    var result = try codegen.generateExports(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "TestType_instances = .{};") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "TestType_instances.deinit(allocator)") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "instance.deinit();") != null);
}

test "init method returns instance ID" {
    const Chart = extern struct {
        width: u32,

        pub fn init(width: u32) @This() {
            return .{ .width = width };
        }

        pub fn getWidth(self: *const @This()) u32 {
            return self.width;
        }
    };

    const exports_decl = .{ .Chart = Chart };

    var result = try codegen.generateExports(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "export fn Chart_init(arg0: u32) u32") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "allocator.create(Chart_Type)") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "Chart_instances.append(allocator, instance)") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "export fn Chart_getWidth(id: u32)") != null);
}

test "multiple types get separate instance storage" {
    const TypeA = extern struct {
        pub fn init() @This() {
            return .{};
        }
    };

    const TypeB = extern struct {
        pub fn init() @This() {
            return .{};
        }
    };

    const exports_decl = .{
        .TypeA = TypeA,
        .TypeB = TypeB,
    };

    var result = try codegen.generateExports(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "TypeA_instances") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "TypeB_instances") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "TypeA_instances = .{};") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "TypeB_instances = .{};") != null);
}

test "codegen generates exports for standalone function" {
    const test_module = struct {
        fn add(a: u32, b: u32) u32 {
            return a + b;
        }
    };

    const exports_decl = .{ .add = test_module.add };

    var result = try codegen.generateExports(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "export fn add") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "arg0: u32, arg1: u32") != null);
}

test "codegen result deinit releases buffers" {
    const exports_decl = .{};
    var result = try codegen.generateExports(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    result.deinit();
}

test "full pipeline introspection to codegen" {
    const Candle = extern struct {
        timestamp: i64,
        open: f64,
        high: f64,
        low: f64,
        close: f64,
        volume: f64,
    };

    const Chart = extern struct {
        width: u32,
        height: u32,

        pub fn init(width: u32, height: u32) @This() {
            return .{ .width = width, .height = height };
        }

        pub fn addCandle(self: *@This(), candle: Candle) void {
            _ = self;
            _ = candle;
        }

        pub fn render(self: *@This()) []const u8 {
            _ = self;
            return &.{};
        }
    };

    const exports_decl = .{
        .Chart = Chart,
        .Candle = Candle,
    };

    var result = try codegen.generateExports(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "Chart_init") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "Chart_addCandle") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "Chart_render") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "Chart_instances") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "__wasmbind_deinit") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "Invalid Chart instance ID") != null);
}

test "Zig codegen handles slice parameters" {
    const Processor = extern struct {
        pub fn init() @This() {
            return .{};
        }

        pub fn ingest(self: *@This(), payload: []const u8) void {
            _ = self;
            _ = payload;
        }
    };

    const exports_decl = .{ .Processor = Processor };

    var result = try codegen.generateExports(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "_ptr: usize") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "@as([*]") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "_ptr_typed[0..") != null);
}

test "Zig codegen handles slice returns" {
    const Renderer = extern struct {
        pub fn init() @This() {
            return .{};
        }

        pub fn render(self: *@This()) []const u8 {
            _ = self;
            return &.{};
        }
    };

    const exports_decl = .{ .Renderer = Renderer };

    var result = try codegen.generateExports(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "Renderer_render_ptr") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "Renderer_render_len") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "Renderer_render_last_ptr") != null);
}

test "TypeScript interface generation" {
    const Candle = extern struct {
        timestamp: i64,
        open: f64,
        close: f64,
    };

    const exports_decl = .{ .Candle = Candle };

    var result = try codegen_ts.generateBindings(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "export interface Candle {") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "timestamp: bigint;") != null);
}

test "TypeScript class generation" {
    const Chart = extern struct {
        width: u32,

        pub fn init(width: u32) @This() {
            return .{ .width = width };
        }

        pub fn render(self: *@This()) []const u8 {
            _ = self;
            return &.{};
        }
    };

    const exports_decl = .{ .Chart = Chart };

    var result = try codegen_ts.generateBindings(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "export class Chart {") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "constructor(wasm: WebAssembly.Instance") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "render(") != null);
}

test "TypeScript load helper is emitted" {
    const exports_decl = .{};

    var result = try codegen_ts.generateBindings(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "export async function loadWasm") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "__wasmbind_init") != null);
}

test "TypeScript marshals string slice parameters" {
    const Chart = extern struct {
        pub fn init() @This() {
            return .{};
        }

        pub fn setLabel(self: *@This(), label: []const u8) void {
            _ = self;
            _ = label;
        }
    };

    const exports_decl = .{ .Chart = Chart };

    var result = try codegen_ts.generateBindings(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "private marshalString(") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "private marshalString(") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "this.marshalString(") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "this.freeBuffer(") != null);
}

test "TypeScript marshals typed array parameters" {
    const Chart = extern struct {
        pub fn init() @This() {
            return .{};
        }

        pub fn addData(self: *@This(), data: []const f64) void {
            _ = self;
            _ = data;
        }
    };

    const exports_decl = .{ .Chart = Chart };

    var result = try codegen_ts.generateBindings(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "private marshalTypedArray(") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "this.marshalTypedArray(") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "this.freeBuffer(") != null);
}

test "TypeScript handles slice returns" {
    const Chart = extern struct {
        pub fn init() @This() {
            return .{};
        }

        pub fn render(self: *@This()) []const u8 {
            _ = self;
            return &.{};
        }
    };

    const exports_decl = .{ .Chart = Chart };

    var result = try codegen_ts.generateBindings(
        std.testing.allocator,
        exports_decl,
        .{},
    );
    defer result.deinit();

    try std.testing.expect(std.mem.indexOf(u8, result.source, "this.wasm.exports.Chart_render_ptr") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.source, "wasmbindTextDecoder.decode") != null);
}

fn testAddFn(a: u32, b: u32) u32 {
    return a + b;
}

fn testProcessData(data: []const f64, threshold: f64) bool {
    _ = data;
    return threshold > 0;
}

fn testNoReturn(value: i32) void {
    _ = value;
}
