const std = @import("std");
const wasmbind = @import("wasmbind");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const host_target = b.standardTargetOptions(.{});

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const chart_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/chart.zig"),
            .target = host_target,
            .optimize = optimize,
        }),
    });
    const run_chart_tests = b.addRunArtifact(chart_tests);

    const test_step = b.step("test", "Run chart logic tests");
    test_step.dependOn(&run_chart_tests.step);

    const wasm = b.addExecutable(.{
        .name = "chart-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = wasm_target,
            .optimize = optimize,
        }),
    });

    wasmbind.generate(b, wasm, .{
        .output_dir = "www/generated",
        .wasm_contract = b.path("src/wasm.zig"),
        .debug = true,
    });

    b.installArtifact(wasm);
}
