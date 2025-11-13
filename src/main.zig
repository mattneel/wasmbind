const std = @import("std");
const wasmbind = @import("root.zig");

pub fn main() !void {
    std.debug.print(
        "wasmbind: add `const wasmbind = @import(\"wasmbind\");` to your build and call wasmbind.generate().\n",
        .{},
    );
    // Touch the public API so the CLI binary verifies linkage.
    _ = wasmbind.GenerateOptions{
        .output_dir = "generated",
    };
}
