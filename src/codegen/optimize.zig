//! Optimization passes driver.
//!
//! Manages registration, ordering, and execution of optimization passes
//! with timing statistics and error handling.

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("root");
const Function = @import("../ir/function.zig").Function;
const dce = @import("opts/dce.zig");

/// Pass execution statistics.
pub const PassStats = struct {
    /// Pass name.
    name: []const u8,
    /// Execution time in nanoseconds.
    time_ns: u64,
    /// Number of changes made.
    changes: u64,

    pub fn format(
        self: PassStats,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const time_ms = @as(f64, @floatFromInt(self.time_ns)) / 1_000_000.0;
        try writer.print("{s}: {d:.3}ms, {d} changes", .{ self.name, time_ms, self.changes });
    }
};

/// Pass manager for optimization passes.
pub const PassManager = struct {
    /// Allocator for pass manager data.
    allocator: Allocator,
    /// Statistics for each pass execution.
    stats: std.ArrayList(PassStats),
    /// Enable timing statistics.
    enable_stats: bool,

    pub fn init(allocator: Allocator) PassManager {
        return .{
            .allocator = allocator,
            .stats = std.ArrayList(PassStats){},
            .enable_stats = false,
        };
    }

    pub fn deinit(self: *PassManager) void {
        self.stats.deinit(self.allocator);
    }

    /// Run all optimization passes on the function.
    pub fn run(self: *PassManager, func: *Function) !void {
        self.stats.clearRetainingCapacity();

        // Run DCE pass
        try self.runPass(func, "DCE", runDCE);

        // Additional passes can be registered here
    }

    /// Run a single pass with timing and statistics.
    fn runPass(
        self: *PassManager,
        func: *Function,
        name: []const u8,
        pass_fn: *const fn (Allocator, *Function) anyerror!bool,
    ) !void {
        const start = if (self.enable_stats) std.time.nanoTimestamp() else 0;

        const changed = try pass_fn(self.allocator, func);

        if (self.enable_stats) {
            const end = std.time.nanoTimestamp();
            const elapsed: u64 = @intCast(end - start);
            try self.stats.append(self.allocator, .{
                .name = name,
                .time_ns = elapsed,
                .changes = if (changed) 1 else 0,
            });
        }
    }

    /// Get statistics for all executed passes.
    pub fn getStats(self: *const PassManager) []const PassStats {
        return self.stats.items;
    }

    /// Clear statistics.
    pub fn clearStats(self: *PassManager) void {
        self.stats.clearRetainingCapacity();
    }
};

/// Run DCE pass.
fn runDCE(allocator: Allocator, func: *Function) !bool {
    var pass = dce.DCE.init(allocator);
    defer pass.deinit();
    return try pass.run(func);
}

// Tests

const testing = std.testing;

test "PassManager: initialization" {
    var pm = PassManager.init(testing.allocator);
    defer pm.deinit();

    try testing.expectEqual(@as(usize, 0), pm.stats.items.len);
    try testing.expect(!pm.enable_stats);
}

test "PassManager: run passes" {
    const sig = @import("../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var pm = PassManager.init(testing.allocator);
    defer pm.deinit();

    try pm.run(&func);

    // Should complete without error
    try testing.expectEqual(@as(usize, 0), pm.stats.items.len);
}

test "PassManager: statistics collection" {
    const sig = @import("../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var pm = PassManager.init(testing.allocator);
    defer pm.deinit();
    pm.enable_stats = true;

    try pm.run(&func);

    // Should have stats for DCE pass
    const stats = pm.getStats();
    try testing.expect(stats.len > 0);
    try testing.expectEqualStrings("DCE", stats[0].name);
}

test "PassManager: clear statistics" {
    const sig = @import("../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var pm = PassManager.init(testing.allocator);
    defer pm.deinit();
    pm.enable_stats = true;

    try pm.run(&func);
    try testing.expect(pm.getStats().len > 0);

    pm.clearStats();
    try testing.expectEqual(@as(usize, 0), pm.getStats().len);
}
