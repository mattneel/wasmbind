const std = @import("std");
const chart = @import("chart.zig");

test "Chart smoke test" {
    var instance = chart.Chart.init(320, 240);
    try std.testing.expectEqual(@as(u32, 0), instance.candle_count);
    instance.addCandle(.{
        .timestamp = 42,
        .open = 1,
        .high = 2,
        .low = 0,
        .close = 1,
        .volume = 10,
    });
    try std.testing.expectEqual(@as(usize, 1), instance.getCandles().len);
}
