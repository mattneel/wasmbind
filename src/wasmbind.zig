const std = @import("std");

pub const types = @import("types.zig");
pub const codegen = @import("codegen_zig.zig");

pub fn generate(
    b: *std.Build,
    wasm_lib: *std.Build.Step.Compile,
    options: GenerateOptions,
) void {
    const wasm_contract = options.wasm_contract orelse
        wasm_lib.root_module.root_source_file orelse
        @panic("wasmbind.generate requires either options.wasm_contract or wasm_lib.root_module.root_source_file");

    const wasmbind_dep = b.dependency("wasmbind", .{});
    const runner = b.addExecutable(.{
        .name = "wasmbind-codegen",
        .root_module = b.createModule(.{
            .root_source_file = wasmbind_dep.path("src/codegen_runner.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });

    runner.root_module.addAnonymousImport("wasm", .{
        .root_source_file = wasm_contract,
    });

    const output_dir = b.pathJoin(&.{ options.output_dir });
    const exports_path = b.pathJoin(&.{ output_dir, "exports.zig" });
    const ts_path = b.pathJoin(&.{ output_dir, "bindings.ts" });

    std.fs.cwd().makePath(output_dir) catch {};

    const run_codegen = b.addRunArtifact(runner);
    run_codegen.addArg(exports_path);
    run_codegen.addArg(ts_path);

    wasm_lib.step.dependOn(&run_codegen.step);

    wasm_lib.root_module.root_source_file = .{ .cwd_relative = exports_path };
    wasm_lib.root_module.addAnonymousImport("wasm_contract", .{
        .root_source_file = wasm_contract,
    });
    wasm_lib.entry = .disabled;

    if (options.debug) {
        std.debug.print("[wasmbind] wasm contract: {s}\n", .{wasm_contract.getPath(b)});
        std.debug.print("[wasmbind] exports path: {s}\n", .{exports_path});
        std.debug.print("[wasmbind] ts bindings: {s}\n", .{ts_path});
    }
}

pub const GenerateOptions = struct {
    output_dir: []const u8,
    wasm_contract: ?std.Build.LazyPath = null,
    debug: bool = false,
};
