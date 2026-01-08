//! ISLE rule coverage tracking for testing and analysis.
//!
//! Tracks which ISLE lowering rules are invoked during compilation.
//! Used to:
//! - Verify all 645 ISLE rules are tested
//! - Detect unreachable/dead rules
//! - Identify priority conflicts
//! - Generate coverage reports

const std = @import("std");

/// Coverage tracker for ISLE rule invocations.
pub const IsleRuleCoverage = struct {
    /// Map: rule name → invocation count
    rule_counts: std.StringHashMap(u32),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) IsleRuleCoverage {
        return .{
            .rule_counts = std.StringHashMap(u32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *IsleRuleCoverage) void {
        // Free all string keys
        var it = self.rule_counts.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.rule_counts.deinit();
    }

    /// Record an ISLE rule invocation.
    pub fn record(self: *IsleRuleCoverage, rule_name: []const u8) !void {
        // Check if rule already tracked
        if (self.rule_counts.getPtr(rule_name)) |count_ptr| {
            count_ptr.* += 1;
            return;
        }

        // First invocation - allocate string and insert
        const owned_name = try self.allocator.dupe(u8, rule_name);
        errdefer self.allocator.free(owned_name);

        try self.rule_counts.put(owned_name, 1);
    }

    /// Get invocation count for a rule (0 if never invoked).
    pub fn getCount(self: *const IsleRuleCoverage, rule_name: []const u8) u32 {
        return self.rule_counts.get(rule_name) orelse 0;
    }

    /// Get total number of unique rules invoked.
    pub fn uniqueRulesInvoked(self: *const IsleRuleCoverage) usize {
        return self.rule_counts.count();
    }

    /// Get total number of rule invocations (sum of all counts).
    pub fn totalInvocations(self: *const IsleRuleCoverage) u64 {
        var total: u64 = 0;
        var it = self.rule_counts.valueIterator();
        while (it.next()) |count| {
            total += count.*;
        }
        return total;
    }

    /// Generate coverage report to writer.
    pub fn report(self: *const IsleRuleCoverage, writer: anytype) !void {
        try writer.print("=== ISLE Rule Coverage Report ===\n", .{});
        try writer.print("Unique rules invoked: {}\n", .{self.uniqueRulesInvoked()});
        try writer.print("Total invocations: {}\n\n", .{self.totalInvocations()});

        // Sort rules by name for consistent output
        var rules = std.ArrayList(struct { name: []const u8, count: u32 }){};
        defer rules.deinit(self.allocator);

        var it = self.rule_counts.iterator();
        while (it.next()) |entry| {
            try rules.append(self.allocator, .{ .name = entry.key_ptr.*, .count = entry.value_ptr.* });
        }

        // Sort by name
        std.mem.sort(@TypeOf(rules.items[0]), rules.items, {}, struct {
            fn lessThan(_: void, a: @TypeOf(rules.items[0]), b: @TypeOf(rules.items[0])) bool {
                return std.mem.lessThan(u8, a.name, b.name);
            }
        }.lessThan);

        // Print sorted rules
        try writer.print("Rule invocations:\n", .{});
        for (rules.items) |rule| {
            try writer.print("  {s:50} : {d:>8}\n", .{ rule.name, rule.count });
        }
    }
};

test "IsleRuleCoverage basic usage" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var coverage = IsleRuleCoverage.init(allocator);
    defer coverage.deinit();

    // Record some rule invocations
    try coverage.record("iadd_imm");
    try coverage.record("iadd_rr");
    try coverage.record("iadd_imm"); // Duplicate

    // Verify counts
    try testing.expectEqual(@as(u32, 2), coverage.getCount("iadd_imm"));
    try testing.expectEqual(@as(u32, 1), coverage.getCount("iadd_rr"));
    try testing.expectEqual(@as(u32, 0), coverage.getCount("never_called"));

    // Verify totals
    try testing.expectEqual(@as(usize, 2), coverage.uniqueRulesInvoked());
    try testing.expectEqual(@as(u64, 3), coverage.totalInvocations());
}

test "IsleRuleCoverage report generation" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var coverage = IsleRuleCoverage.init(allocator);
    defer coverage.deinit();

    try coverage.record("rule_a");
    try coverage.record("rule_b");
    try coverage.record("rule_a");

    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);

    try coverage.report(buf.writer(allocator));

    const output = buf.items;
    try testing.expect(std.mem.indexOf(u8, output, "Unique rules invoked: 2") != null);
    try testing.expect(std.mem.indexOf(u8, output, "Total invocations: 3") != null);
    try testing.expect(std.mem.indexOf(u8, output, "rule_a") != null);
    try testing.expect(std.mem.indexOf(u8, output, "rule_b") != null);
}
