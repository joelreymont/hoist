//! Optimization passes driver.
//!
//! Manages registration, ordering, and execution of optimization passes
//! with timing statistics and error handling.

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("root");
const Function = @import("../ir/function.zig").Function;
const dce = @import("opts/dce.zig");
const gvn = @import("opts/gvn.zig");
const instcombine = @import("opts/instcombine.zig");
const strength = @import("opts/strength.zig");
const peephole = @import("opts/peephole.zig");
const copyprop = @import("opts/copyprop.zig");
const licm = @import("opts/licm.zig");
const simplifybranch = @import("opts/simplifybranch.zig");
const sccp = @import("opts/sccp.zig");

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

        // Run optimization passes
        try self.runPass(func, "SCCP", runSCCP); // Sparse conditional constant propagation (early)
        try self.runPass(func, "SimplifyBranch", runSimplifyBranch);
        try self.runPass(func, "InstCombine", runInstCombine);
        try self.runPass(func, "GVN", runGVN);
        try self.runPass(func, "CopyProp", runCopyProp);
        try self.runPass(func, "Strength", runStrength);
        try self.runPass(func, "LICM", runLICM);
        try self.runPass(func, "Peephole", runPeephole);
        try self.runPass(func, "DCE", runDCE);
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

/// Run GVN pass.
fn runGVN(allocator: Allocator, func: *Function) !bool {
    var pass = gvn.GVN.init(allocator);
    defer pass.deinit();
    return try pass.run(func);
}

/// Run InstCombine pass.
fn runInstCombine(allocator: Allocator, func: *Function) !bool {
    var pass = instcombine.InstCombine.init(allocator);
    defer pass.deinit();
    return try pass.run(func);
}

/// Run Strength Reduction pass.
fn runStrength(allocator: Allocator, func: *Function) !bool {
    var pass = strength.StrengthReduction.init(allocator);
    defer pass.deinit();
    return try pass.run(func);
}

/// Run Peephole pass.
fn runPeephole(allocator: Allocator, func: *Function) !bool {
    var pass = peephole.Peephole.init(allocator);
    defer pass.deinit();
    return try pass.run(func);
}

/// Run Copy Propagation pass.
fn runCopyProp(allocator: Allocator, func: *Function) !bool {
    var pass = copyprop.CopyProp.init(allocator);
    defer pass.deinit();
    return try pass.run(func);
}

/// Run LICM pass.
fn runLICM(allocator: Allocator, func: *Function) !bool {
    var pass = licm.LICM.init(allocator);
    defer pass.deinit();
    return try pass.run(func);
}

/// Run SimplifyBranch pass.
fn runSimplifyBranch(allocator: Allocator, func: *Function) !bool {
    var pass = simplifybranch.SimplifyBranch.init(allocator);
    defer pass.deinit();
    return try pass.run(func);
}

/// Run SCCP pass.
fn runSCCP(allocator: Allocator, func: *Function) !bool {
    var pass = sccp.SCCP.init(allocator);
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

    // Should have stats for all passes
    const stats = pm.getStats();
    try testing.expectEqual(@as(usize, 9), stats.len);
    try testing.expectEqualStrings("SCCP", stats[0].name);
    try testing.expectEqualStrings("SimplifyBranch", stats[1].name);
    try testing.expectEqualStrings("InstCombine", stats[2].name);
    try testing.expectEqualStrings("GVN", stats[3].name);
    try testing.expectEqualStrings("CopyProp", stats[4].name);
    try testing.expectEqualStrings("Strength", stats[5].name);
    try testing.expectEqualStrings("LICM", stats[6].name);
    try testing.expectEqualStrings("Peephole", stats[7].name);
    try testing.expectEqualStrings("DCE", stats[8].name);
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
