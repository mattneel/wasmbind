const std = @import("std");
const builtin = std.builtin;

pub const TsPrimitive = enum {
    number,
    bigint,
    boolean,
    void,
};

pub const TsType = union(enum) {
    primitive: TsPrimitive,
    slice: SliceInfo,
    string: void,
    @"struct": StructInfo,
    pointer: PointerInfo,

    pub const SliceScalarKind = enum {
        integer,
        float,
        boolean,
    };

    pub const SliceInfo = struct {
        child: TsPrimitive,
        is_const: bool,
        bits: u16,
        signedness: builtin.Signedness,
        scalar_kind: SliceScalarKind,
    };

    pub const StructInfo = struct {
        name: []const u8,
        is_extern: bool,
    };

    pub const PointerInfo = struct {
        child_type: type,
        is_const: bool,
        size: builtin.Type.Pointer.Size,
    };
};

pub const StructField = struct {
    name: []const u8,
    ts_type: TsType,
    original_type: type,
};

pub const FunctionParam = struct {
    name: []const u8,
    ts_type: TsType,
    original_type: type,
};

pub const FunctionSignature = struct {
    name: []const u8,
    params: []const FunctionParam,
    return_type: TsType,
    return_type_original: type,
};

pub fn inferTsType(comptime T: type) TsType {
    return switch (@typeInfo(T)) {
        .int, .float, .bool, .void => .{ .primitive = inferPrimitiveTsType(T) },
        .comptime_int, .comptime_float => .{ .primitive = inferPrimitiveTsType(T) },
        .pointer => |ptr_info| inferPointerType(ptr_info),
        .@"struct" => |struct_info| inferStructType(T, struct_info),
        else => @compileError("unsupported type in TypeScript surface: " ++ @typeName(T)),
    };
}

pub fn toTsString(comptime ts_type: TsType) []const u8 {
    return switch (ts_type) {
        .primitive => |prim| primitiveToString(prim),
        .string => "string",
        .slice => |info| sliceToString(info),
        .@"struct" => |info| info.name,
        .pointer => @compileError("pointer printing not implemented"),
    };
}

pub fn inferPrimitiveTsType(comptime T: type) TsPrimitive {
    return switch (@typeInfo(T)) {
        .int => |int_info| bitsToTsPrimitive(int_info.bits),
        .float => .number,
        .bool => .boolean,
        .void => .void,
        .comptime_int => .number,
        .comptime_float => .number,
        else => @compileError("type cannot be expressed as a TypeScript primitive: " ++ @typeName(T)),
    };
}

pub fn introspectStruct(comptime T: type) []const StructField {
    const struct_info = switch (@typeInfo(T)) {
        .@"struct" => |info| info,
        else => @compileError("introspectStruct expects a struct type, got " ++ @typeName(T)),
    };

    if (struct_info.layout != .@"extern") {
        @compileError("struct " ++ @typeName(T) ++ " must be marked extern for WASM exports");
    }

    comptime var fields: [struct_info.fields.len]StructField = undefined;
    inline for (struct_info.fields, 0..) |field, idx| {
        fields[idx] = .{
            .name = std.mem.sliceTo(field.name, 0),
            .ts_type = inferTsType(field.type),
            .original_type = field.type,
        };
    }
    return fields[0..];
}

pub fn introspectFunction(comptime func: anytype) FunctionSignature {
    const fn_type = @TypeOf(func);
    const fn_info = switch (@typeInfo(fn_type)) {
        .@"fn" => |info| info,
        else => @compileError("expected function type, got " ++ @typeName(fn_type)),
    };

    if (fn_info.is_var_args) {
        @compileError("variadic functions are not supported by wasmbind introspection");
    }

    comptime var params: [fn_info.params.len]FunctionParam = undefined;
    inline for (fn_info.params, 0..) |param, idx| {
        if (param.is_generic) {
            @compileError("generic parameters are not supported for exported functions");
        }
        const param_type = param.type orelse @compileError("function parameters must have a concrete type");
        params[idx] = .{
            .name = std.fmt.comptimePrint("arg{d}", .{idx}),
            .ts_type = inferTsType(param_type),
            .original_type = param_type,
        };
    }

    const return_type: type = fn_info.return_type orelse void;

    return .{
        .name = @typeName(fn_type),
        .params = params[0..],
        .return_type = inferTsType(return_type),
        .return_type_original = return_type,
    };
}

inline fn inferPointerType(comptime ptr_info: builtin.Type.Pointer) TsType {
    if (ptr_info.size == .slice) {
        if (ptr_info.child == u8 and ptr_info.is_const) {
            return .string;
        }

        const child_type_info = @typeInfo(ptr_info.child);
        const child_primitive = inferPrimitiveTsType(ptr_info.child);
        const scalar_kind = switch (child_type_info) {
            .int => TsType.SliceScalarKind.integer,
            .float => TsType.SliceScalarKind.float,
            .bool => TsType.SliceScalarKind.boolean,
            .comptime_int, .comptime_float => @compileError("comptime-only slice elements are not supported"),
            else => @compileError("slice element must be a primitive scalar"),
        };

        const bits: u16 = switch (child_type_info) {
            .int => |int_info| int_info.bits,
            .float => |float_info| float_info.bits,
            .bool => 1,
            else => 0,
        };

        const signedness: builtin.Signedness = switch (child_type_info) {
            .int => |int_info| int_info.signedness,
            else => .unsigned,
        };

        return .{ .slice = .{
            .child = child_primitive,
            .is_const = ptr_info.is_const,
            .bits = bits,
            .signedness = signedness,
            .scalar_kind = scalar_kind,
        } };
    }

    return .{ .pointer = .{
        .child_type = ptr_info.child,
        .is_const = ptr_info.is_const,
        .size = ptr_info.size,
    } };
}

inline fn inferStructType(comptime T: type, struct_info: builtin.Type.Struct) TsType {
    if (struct_info.layout != .@"extern") {
        @compileError("struct " ++ @typeName(T) ++ " must be marked extern for WASM exports");
    }

    return .{ .@"struct" = .{
        .name = @typeName(T),
        .is_extern = true,
    } };
}

inline fn primitiveToString(prim: TsPrimitive) []const u8 {
    return switch (prim) {
        .number => "number",
        .bigint => "bigint",
        .boolean => "boolean",
        .void => "void",
    };
}

inline fn sliceToString(info: TsType.SliceInfo) []const u8 {
    return switch (info.scalar_kind) {
        .boolean => "boolean[]",
        .float => switch (info.bits) {
            32 => "Float32Array",
            64 => "Float64Array",
            else => @compileError("unsupported float bit width for TypedArray"),
        },
        .integer => switch (info.child) {
            .bigint => switch (info.signedness) {
                .signed => "BigInt64Array",
                .unsigned => "BigUint64Array",
            },
            .number => switch (info.bits) {
                8 => if (info.signedness == .signed) "Int8Array" else "Uint8Array",
                16 => if (info.signedness == .signed) "Int16Array" else "Uint16Array",
                32 => if (info.signedness == .signed) "Int32Array" else "Uint32Array",
                else => @compileError("unsupported integer bit width for TypedArray"),
            },
            else => @compileError("integer slice must map to number or bigint"),
        },
    };
}

inline fn bitsToTsPrimitive(bits: u16) TsPrimitive {
    if (bits <= 32) return .number;
    if (bits <= 64) return .bigint;
    @compileError("integer width not supported for TypeScript primitives");
}
