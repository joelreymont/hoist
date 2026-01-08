//! ISLE rule coverage tracking for testing and analysis.
//!
//! Tracks which ISLE lowering rules are invoked during compilation.
//! Used to:
//! - Verify all 645 ISLE rules are tested
//! - Detect unreachable/dead rules
//! - Identify priority conflicts
//! - Generate coverage reports

const std = @import("std");

/// All known ISLE rule constructors (aarch64_* functions).
/// Generated from isle_helpers.zig - 164 total constructors.
pub const ALL_ISLE_RULES = [_][]const u8{
    "aarch64_and_imm",
    "aarch64_atomic_load_acquire",
    "aarch64_atomic_store_release",
    "aarch64_bitcast_noop",
    "aarch64_bitselect",
    "aarch64_bswap_16",
    "aarch64_bswap_32",
    "aarch64_bswap_64",
    "aarch64_call",
    "aarch64_call_indirect",
    "aarch64_ccmp_imm",
    "aarch64_ccmp_rr",
    "aarch64_ceil",
    "aarch64_clz_32",
    "aarch64_clz_64",
    "aarch64_cmn_imm",
    "aarch64_cmn_rr",
    "aarch64_cmp_imm",
    "aarch64_cmp_rr",
    "aarch64_csel",
    "aarch64_ctz_32",
    "aarch64_ctz_64",
    "aarch64_debugtrap",
    "aarch64_eor_imm",
    "aarch64_extractlane",
    "aarch64_f32const",
    "aarch64_f64const",
    "aarch64_fadd",
    "aarch64_fcopysign_32",
    "aarch64_fcvtl",
    "aarch64_fcvtn_combined",
    "aarch64_fcvtzs_32_to_32",
    "aarch64_fcvtzs_32_to_64",
    "aarch64_fcvtzs_32_trap",
    "aarch64_fcvtzs_64_to_32",
    "aarch64_fcvtzs_64_to_64",
    "aarch64_fcvtzu_32_to_32",
    "aarch64_fcvtzu_32_to_64",
    "aarch64_fcvtzu_64_to_32",
    "aarch64_fcvtzu_64_to_64",
    "aarch64_fdemote",
    "aarch64_fdiv",
    "aarch64_fence",
    "aarch64_floor",
    "aarch64_fmax",
    "aarch64_fmin",
    "aarch64_fmov_from_gpr",
    "aarch64_fmov_to_gpr",
    "aarch64_fmul",
    "aarch64_fpromote",
    "aarch64_fsub",
    "aarch64_func_addr",
    "aarch64_get_frame_pointer",
    "aarch64_get_pinned_reg",
    "aarch64_get_return_address",
    "aarch64_get_stack_pointer",
    "aarch64_iabs",
    "aarch64_insertlane",
    "aarch64_ireduce",
    "aarch64_isplit",
    "aarch64_istore16",
    "aarch64_istore32",
    "aarch64_istore8",
    "aarch64_ld1r",
    "aarch64_ldr",
    "aarch64_ldr_ext",
    "aarch64_ldr_imm",
    "aarch64_ldr_post",
    "aarch64_ldr_pre",
    "aarch64_ldr_reg",
    "aarch64_ldr_shifted",
    "aarch64_mul_rr",
    "aarch64_nearest",
    "aarch64_orr_imm",
    "aarch64_rbit_32",
    "aarch64_rbit_64",
    "aarch64_return_call",
    "aarch64_return_call_indirect",
    "aarch64_rotl_rr",
    "aarch64_sadd_overflow",
    "aarch64_scvtf",
    "aarch64_set_pinned_reg",
    "aarch64_shuffle_tbl",
    "aarch64_sload16",
    "aarch64_sload16x4",
    "aarch64_sload32",
    "aarch64_sload32x2",
    "aarch64_sload8",
    "aarch64_sload8x8",
    "aarch64_smax",
    "aarch64_smin",
    "aarch64_smul_overflow_i16",
    "aarch64_smul_overflow_i32",
    "aarch64_smul_overflow_i64",
    "aarch64_snarrow",
    "aarch64_splat",
    "aarch64_sqxtn_combined",
    "aarch64_sqxtun_combined",
    "aarch64_sshll",
    "aarch64_ssub_overflow",
    "aarch64_stack_addr",
    "aarch64_stack_switch",
    "aarch64_str",
    "aarch64_str_ext",
    "aarch64_str_imm",
    "aarch64_str_post",
    "aarch64_str_pre",
    "aarch64_str_reg",
    "aarch64_str_shifted",
    "aarch64_sxtb",
    "aarch64_sxth",
    "aarch64_sxtw",
    "aarch64_symbol_value",
    "aarch64_trap",
    "aarch64_trapnz",
    "aarch64_trapz",
    "aarch64_trunc",
    "aarch64_try_call",
    "aarch64_try_call_indirect",
    "aarch64_tst_imm",
    "aarch64_tst_rr",
    "aarch64_uadd_overflow",
    "aarch64_ucvtf",
    "aarch64_uload16",
    "aarch64_uload16x4",
    "aarch64_uload32",
    "aarch64_uload32x2",
    "aarch64_uload64",
    "aarch64_uload8",
    "aarch64_uload8x8",
    "aarch64_umax",
    "aarch64_umin",
    "aarch64_umul_overflow_i16",
    "aarch64_umul_overflow_i32",
    "aarch64_umul_overflow_i64",
    "aarch64_unarrow",
    "aarch64_uqxtn_combined",
    "aarch64_ushll",
    "aarch64_usub_overflow",
    "aarch64_uunarrow",
    "aarch64_uxtb",
    "aarch64_uxth",
    "aarch64_uxtw",
    "aarch64_vall_true",
    "aarch64_vany_true",
    "aarch64_vec_add",
    "aarch64_vec_fadd",
    "aarch64_vec_fdiv",
    "aarch64_vec_fmax",
    "aarch64_vec_fmin",
    "aarch64_vec_fmul",
    "aarch64_vec_fsub",
    "aarch64_vec_mul",
    "aarch64_vec_sdot",
    "aarch64_vec_shift_imm",
    "aarch64_vec_smax",
    "aarch64_vec_smin",
    "aarch64_vec_sub",
    "aarch64_vec_udot",
    "aarch64_vec_umax",
    "aarch64_vec_umin",
    "aarch64_vhigh_bits",
    "aarch64_vldr",
    "aarch64_vstr",
};

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

    /// Generate full coverage report comparing against known ISLE rules.
    pub fn reportWithUnused(self: *const IsleRuleCoverage, writer: anytype, all_rules: []const []const u8) !void {
        try writer.print("=== ISLE Rule Coverage Report (Full) ===\n", .{});
        try writer.print("Total known rules: {}\n", .{all_rules.len});
        try writer.print("Unique rules invoked: {}\n", .{self.uniqueRulesInvoked()});
        try writer.print("Total invocations: {}\n", .{self.totalInvocations()});

        const coverage_pct = if (all_rules.len > 0)
            (@as(f64, @floatFromInt(self.uniqueRulesInvoked())) / @as(f64, @floatFromInt(all_rules.len))) * 100.0
        else
            0.0;
        try writer.print("Coverage: {d:.1}%\n\n", .{coverage_pct});

        // Categorize rules
        var used = std.ArrayList([]const u8){};
        defer used.deinit(self.allocator);
        var unused = std.ArrayList([]const u8){};
        defer unused.deinit(self.allocator);

        for (all_rules) |rule| {
            if (self.getCount(rule) > 0) {
                try used.append(self.allocator, rule);
            } else {
                try unused.append(self.allocator, rule);
            }
        }

        // Print unused rules
        if (unused.items.len > 0) {
            try writer.print("Unused rules ({}):\n", .{unused.items.len});
            for (unused.items) |rule| {
                try writer.print("  {s}\n", .{rule});
            }
            try writer.print("\n", .{});
        }

        // Print used rules with counts
        try writer.print("Used rules ({}):\n", .{used.items.len});
        for (used.items) |rule| {
            const count = self.getCount(rule);
            try writer.print("  {s:50} : {d:>8}\n", .{ rule, count });
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
