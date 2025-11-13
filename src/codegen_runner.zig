const std = @import("std");
const codegen_zig = @import("codegen_zig.zig");
const codegen_ts = @import("codegen_ts.zig");

const RunnerError = error{
    MissingOutputPaths,
    MissingExportsDeclaration,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} <zig_output> <ts_output>\n", .{args[0]});
        return RunnerError.MissingOutputPaths;
    }

    const exports_path = args[1];
    const ts_output = args[2];

    const wasm_contract = @import("wasm");
    if (!@hasDecl(wasm_contract, "exports")) {
        std.debug.print("wasmbind: wasm.zig must define `pub const exports = .{ ... }`\n", .{});
        return RunnerError.MissingExportsDeclaration;
    }

    var result = try codegen_zig.generateExports(
        allocator,
        wasm_contract.exports,
        .{ .debug = false },
    );
    defer result.deinit();

    if (std.fs.path.dirname(exports_path)) |dir| {
        std.fs.cwd().makePath(dir) catch |err| {
            std.debug.print("wasmbind: failed to create {s}: {s}\n", .{ dir, @errorName(err) });
            return err;
        };
    }

    const exports_file = try std.fs.cwd().createFile(exports_path, .{});
    defer exports_file.close();
    try exports_file.writeAll(result.source);

    var ts_result = try codegen_ts.generateBindings(
        allocator,
        wasm_contract.exports,
        .{},
    );
    defer ts_result.deinit();

    if (std.fs.path.dirname(ts_output)) |dir| {
        std.fs.cwd().makePath(dir) catch {};
    }

    const ts_file = try std.fs.cwd().createFile(ts_output, .{});
    defer ts_file.close();
    try ts_file.writeAll(ts_result.source);

    std.debug.print("[wasmbind] generated {d} exports\n", .{result.exports.len});
    std.debug.print("[wasmbind]   Zig: {s}\n", .{exports_path});
    std.debug.print("[wasmbind]   TS:  {s}\n", .{ts_output});
}
