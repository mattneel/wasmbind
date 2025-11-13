const std = @import("std");

pub const Candle = extern struct {
    timestamp: i64,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
};

pub const Chart = extern struct {
    width: u32,
    height: u32,
    candle_count: u32,
    title_len: u32,
    series_len: u32,
    store_index: u16,

    pub fn init(width: u32, height: u32) Chart {
        const idx = acquireStore();
        clearStore(idx);

        return .{
            .width = width,
            .height = height,
            .candle_count = 0,
            .title_len = 0,
            .series_len = 0,
            .store_index = @as(u16, @intCast(idx)),
        };
    }

    pub fn addCandle(self: *Chart, candle: Candle) void {
        if (self.candle_count >= max_candles_uint) return;
        const store = chartStore(self);
        store.candles[@as(usize, @intCast(self.candle_count))] = candle;
        self.candle_count += 1;
    }

    fn getCandles(self: *const Chart) []const Candle {
        const store = chartStoreConst(self);
        return store.candles[0..@as(usize, @intCast(self.candle_count))];
    }

    pub fn setSeries(self: *Chart, samples: []const f64) void {
        const len = @min(samples.len, series_capacity);
        const store = chartStore(self);
        std.mem.copyForwards(f64, store.series[0..len], samples[0..len]);
        self.series_len = @as(u32, @intCast(len));
    }

    pub fn getSeries(self: *const Chart) []const f64 {
        const store = chartStoreConst(self);
        return store.series[0..@as(usize, @intCast(self.series_len))];
    }

    pub fn setTitle(self: *Chart, title_slice: []const u8) void {
        const len = @min(title_slice.len, title_capacity);
        const store = chartStore(self);
        std.mem.copyForwards(u8, store.title[0..len], title_slice[0..len]);
        if (len < title_capacity) {
            @memset(store.title[len..], 0);
        }
        self.title_len = @as(u32, @intCast(len));
    }

    pub fn getTitle(self: *const Chart) []const u8 {
        const store = chartStoreConst(self);
        return store.title[0..@as(usize, @intCast(self.title_len))];
    }

    pub fn render(_: *const Chart) []const u8 {
        return RED_PIXEL[0..];
    }

    pub fn deinit(self: *Chart) void {
        releaseStore(self.store_index);
        self.* = .{
            .width = self.width,
            .height = self.height,
            .candle_count = 0,
            .title_len = 0,
            .series_len = 0,
            .store_index = invalid_store_index,
        };
    }
};

const max_candles: usize = 256;
const max_candles_uint: u32 = @as(u32, @intCast(max_candles));
const title_capacity: usize = 64;
const series_capacity: usize = 1024;
const max_charts: usize = 32;
const invalid_store_index: u16 = std.math.maxInt(u16);
const RED_PIXEL = [_]u8{ 0xFF, 0x2F, 0x56, 0xFF };

test "Chart initialization" {
    var chart = Chart.init(800, 600);
    try std.testing.expectEqual(@as(u32, 0), chart.candle_count);
    try std.testing.expectEqualSlices(u8, &.{}, chart.getTitle());
}

test "Chart adds single candle" {
    var chart = Chart.init(800, 600);
    chart.addCandle(.{
        .timestamp = 1,
        .open = 1,
        .high = 1,
        .low = 1,
        .close = 1,
        .volume = 1,
    });
    try std.testing.expectEqual(@as(usize, 1), chart.getCandles().len);
}

test "Chart sets title" {
    var chart = Chart.init(640, 480);
    chart.setTitle("Tiger Style Charts");
    try std.testing.expectEqualStrings("Tiger Style Charts", chart.getTitle());
}

test "Chart stores sample series" {
    var chart = Chart.init(640, 480);
    const samples = [_]f64{ 1.0, 2.0, 3.0, 4.0 };
    chart.setSeries(&samples);
    const stored = chart.getSeries();
    try std.testing.expectEqual(@as(usize, 4), stored.len);
    try std.testing.expectEqual(@as(f64, 4.0), stored[3]);
}

const Store = struct {
    candles: [max_candles]Candle,
    series: [series_capacity]f64,
    title: [title_capacity]u8,
};

var store_pool: [max_charts]Store = undefined;
var store_used: [max_charts]bool = [_]bool{false} ** max_charts;

fn acquireStore() usize {
    for (store_used, 0..) |used, idx| {
        if (!used) {
            store_used[idx] = true;
            return idx;
        }
    }
    @panic("chart store exhausted");
}

fn releaseStore(index: u16) void {
    if (index == invalid_store_index) return;
    const idx = @as(usize, @intCast(index));
    store_used[idx] = false;
    clearStore(idx);
}

fn clearStore(idx: usize) void {
    store_pool[idx].candles = std.mem.zeroes([max_candles]Candle);
    store_pool[idx].series = std.mem.zeroes([series_capacity]f64);
    store_pool[idx].title = [_]u8{0} ** title_capacity;
}

inline fn chartStore(self: *Chart) *Store {
    const idx = @as(usize, @intCast(self.store_index));
    return &store_pool[idx];
}

inline fn chartStoreConst(self: *const Chart) *const Store {
    const idx = @as(usize, @intCast(self.store_index));
    return &store_pool[idx];
}
