//! Algebraic rewrite rules for e-graph optimization.
//!
//! Rules are expressed as pattern → replacement pairs.
//! Applied during equality saturation to discover equivalent expressions.

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const egraph_mod = @import("egraph.zig");
const EGraph = egraph_mod.EGraph;
const EClassId = egraph_mod.EClassId;
const ENode = egraph_mod.ENode;
const opcodes = @import("opcodes.zig");
const Opcode = opcodes.Opcode;

/// Rewrite rule: pattern → replacement.
/// Pattern matches e-nodes, replacement creates new equivalent e-nodes.
pub const RewriteRule = struct {
    name: []const u8,
    pattern: Pattern,
    action: Action,

    /// Pattern to match in e-graph.
    pub const Pattern = union(enum) {
        /// Match specific opcode with variable children.
        /// Example: (iadd ?x ?y)
        op: struct {
            opcode: Opcode,
            vars: []const []const u8, // Variable names
        },

        /// Match specific constant.
        /// Example: (iconst 0)
        constant: struct {
            opcode: Opcode,
            value: i64,
        },

        /// Match any expression, bind to variable.
        /// Example: ?x
        var_: []const u8,
    };

    /// Action to perform when pattern matches.
    pub const Action = union(enum) {
        /// Replace with constant.
        /// Example: (iconst 0)
        constant: struct {
            opcode: Opcode,
            value: i64,
        },

        /// Replace with variable.
        /// Example: ?x
        var_: []const u8,

        /// Replace with operation on variables.
        /// Example: (iadd ?x ?y)
        op: struct {
            opcode: Opcode,
            args: []const []const u8,
        },
    };
};

/// Rule application context during equality saturation.
pub const RuleContext = struct {
    eg: *EGraph,
    allocator: Allocator,

    /// Apply single rewrite rule to e-graph.
    /// Returns true if any rewrites were performed.
    pub fn applyRule(self: *RuleContext, rule: RewriteRule) !bool {
        var changed = false;

        // Iterate over all e-classes
        var class_iter = self.eg.classes.iterator();
        while (class_iter.next()) |entry| {
            const eclass = entry.value_ptr;

            // Try to match pattern in this e-class
            for (eclass.nodes.items) |node| {
                if (try self.matchAndApply(rule, node, eclass.id)) {
                    changed = true;
                }
            }
        }

        return changed;
    }

    /// Match pattern and apply action if successful.
    fn matchAndApply(self: *RuleContext, rule: RewriteRule, node: ENode, eclass_id: EClassId) !bool {
        _ = self;
        _ = rule;
        _ = node;
        _ = eclass_id;
        // Pattern matching implementation TBD
        return false;
    }
};

/// Standard algebraic rewrite rules.
pub const StandardRules = struct {
    allocator: Allocator,
    rules: ArrayList(RewriteRule),

    pub fn init(allocator: Allocator) !StandardRules {
        var rules = ArrayList(RewriteRule){};

        // Identity rules
        try addIdentityRules(allocator, &rules);

        // Associativity rules
        try addAssociativityRules(allocator, &rules);

        // Commutativity rules
        try addCommutativityRules(allocator, &rules);

        // Strength reduction
        try addStrengthReductionRules(allocator, &rules);

        // Constant folding patterns
        try addConstantFoldingRules(allocator, &rules);

        return .{
            .allocator = allocator,
            .rules = rules,
        };
    }

    pub fn deinit(self: *StandardRules) void {
        self.rules.deinit(self.allocator);
    }

    /// Get all rules.
    pub fn getRules(self: *StandardRules) []const RewriteRule {
        return self.rules.items;
    }
};

/// Identity element rules: x op identity → x
fn addIdentityRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    // x + 0 → x
    try rules.append(allocator, .{
        .name = "iadd_zero_right",
        .pattern = .{ .op = .{ .opcode = .iadd, .vars = &.{ "x", "zero" } } },
        .action = .{ .var_ = "x" },
    });

    // 0 + x → x
    try rules.append(allocator, .{
        .name = "iadd_zero_left",
        .pattern = .{ .op = .{ .opcode = .iadd, .vars = &.{ "zero", "x" } } },
        .action = .{ .var_ = "x" },
    });

    // x * 1 → x
    try rules.append(allocator, .{
        .name = "imul_one_right",
        .pattern = .{ .op = .{ .opcode = .imul, .vars = &.{ "x", "one" } } },
        .action = .{ .var_ = "x" },
    });

    // 1 * x → x
    try rules.append(allocator, .{
        .name = "imul_one_left",
        .pattern = .{ .op = .{ .opcode = .imul, .vars = &.{ "one", "x" } } },
        .action = .{ .var_ = "x" },
    });

    // x - 0 → x
    try rules.append(allocator, .{
        .name = "isub_zero",
        .pattern = .{ .op = .{ .opcode = .isub, .vars = &.{ "x", "zero" } } },
        .action = .{ .var_ = "x" },
    });

    // x | 0 → x
    try rules.append(allocator, .{
        .name = "bor_zero",
        .pattern = .{ .op = .{ .opcode = .bor, .vars = &.{ "x", "zero" } } },
        .action = .{ .var_ = "x" },
    });

    // x & ~0 → x
    try rules.append(allocator, .{
        .name = "band_all_ones",
        .pattern = .{ .op = .{ .opcode = .band, .vars = &.{ "x", "all_ones" } } },
        .action = .{ .var_ = "x" },
    });

    // x ^ 0 → x
    try rules.append(allocator, .{
        .name = "bxor_zero",
        .pattern = .{ .op = .{ .opcode = .bxor, .vars = &.{ "x", "zero" } } },
        .action = .{ .var_ = "x" },
    });
}

/// Absorbing element rules: x op absorber → absorber
fn addAbsorbingRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    // x * 0 → 0
    try rules.append(allocator, .{
        .name = "imul_zero_right",
        .pattern = .{ .op = .{ .opcode = .imul, .vars = &.{ "x", "zero" } } },
        .action = .{ .constant = .{ .opcode = .iconst, .value = 0 } },
    });

    // 0 * x → 0
    try rules.append(allocator, .{
        .name = "imul_zero_left",
        .pattern = .{ .op = .{ .opcode = .imul, .vars = &.{ "zero", "x" } } },
        .action = .{ .constant = .{ .opcode = .iconst, .value = 0 } },
    });

    // x & 0 → 0
    try rules.append(allocator, .{
        .name = "band_zero",
        .pattern = .{ .op = .{ .opcode = .band, .vars = &.{ "x", "zero" } } },
        .action = .{ .constant = .{ .opcode = .iconst, .value = 0 } },
    });
}

/// Idempotence rules: x op x → x or constant
fn addIdempotenceRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    // x - x → 0
    try rules.append(allocator, .{
        .name = "isub_self",
        .pattern = .{ .op = .{ .opcode = .isub, .vars = &.{ "x", "x" } } },
        .action = .{ .constant = .{ .opcode = .iconst, .value = 0 } },
    });

    // x ^ x → 0
    try rules.append(allocator, .{
        .name = "bxor_self",
        .pattern = .{ .op = .{ .opcode = .bxor, .vars = &.{ "x", "x" } } },
        .action = .{ .constant = .{ .opcode = .iconst, .value = 0 } },
    });

    // x & x → x
    try rules.append(allocator, .{
        .name = "band_self",
        .pattern = .{ .op = .{ .opcode = .band, .vars = &.{ "x", "x" } } },
        .action = .{ .var_ = "x" },
    });

    // x | x → x
    try rules.append(allocator, .{
        .name = "bor_self",
        .pattern = .{ .op = .{ .opcode = .bor, .vars = &.{ "x", "x" } } },
        .action = .{ .var_ = "x" },
    });
}

/// Commutativity rules: x op y → y op x
fn addCommutativityRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    // x + y → y + x
    try rules.append(allocator, .{
        .name = "iadd_comm",
        .pattern = .{ .op = .{ .opcode = .iadd, .vars = &.{ "x", "y" } } },
        .action = .{ .op = .{ .opcode = .iadd, .args = &.{ "y", "x" } } },
    });

    // x * y → y * x
    try rules.append(allocator, .{
        .name = "imul_comm",
        .pattern = .{ .op = .{ .opcode = .imul, .vars = &.{ "x", "y" } } },
        .action = .{ .op = .{ .opcode = .imul, .args = &.{ "y", "x" } } },
    });

    // x & y → y & x
    try rules.append(allocator, .{
        .name = "band_comm",
        .pattern = .{ .op = .{ .opcode = .band, .vars = &.{ "x", "y" } } },
        .action = .{ .op = .{ .opcode = .band, .args = &.{ "y", "x" } } },
    });

    // x | y → y | x
    try rules.append(allocator, .{
        .name = "bor_comm",
        .pattern = .{ .op = .{ .opcode = .bor, .vars = &.{ "x", "y" } } },
        .action = .{ .op = .{ .opcode = .bor, .args = &.{ "y", "x" } } },
    });

    // x ^ y → y ^ x
    try rules.append(allocator, .{
        .name = "bxor_comm",
        .pattern = .{ .op = .{ .opcode = .bxor, .vars = &.{ "x", "y" } } },
        .action = .{ .op = .{ .opcode = .bxor, .args = &.{ "y", "x" } } },
    });
}

/// Associativity rules: (x op y) op z → x op (y op z)
fn addAssociativityRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    // (x + y) + z → x + (y + z)
    try rules.append(allocator, .{
        .name = "iadd_assoc",
        .pattern = .{ .op = .{ .opcode = .iadd, .vars = &.{ "xy", "z" } } },
        .action = .{ .op = .{ .opcode = .iadd, .args = &.{ "x", "yz" } } },
    });

    // (x * y) * z → x * (y * z)
    try rules.append(allocator, .{
        .name = "imul_assoc",
        .pattern = .{ .op = .{ .opcode = .imul, .vars = &.{ "xy", "z" } } },
        .action = .{ .op = .{ .opcode = .imul, .args = &.{ "x", "yz" } } },
    });

    // (x & y) & z → x & (y & z)
    try rules.append(allocator, .{
        .name = "band_assoc",
        .pattern = .{ .op = .{ .opcode = .band, .vars = &.{ "xy", "z" } } },
        .action = .{ .op = .{ .opcode = .band, .args = &.{ "x", "yz" } } },
    });

    // (x | y) | z → x | (y | z)
    try rules.append(allocator, .{
        .name = "bor_assoc",
        .pattern = .{ .op = .{ .opcode = .bor, .vars = &.{ "xy", "z" } } },
        .action = .{ .op = .{ .opcode = .bor, .args = &.{ "x", "yz" } } },
    });
}

/// Strength reduction: replace expensive ops with cheaper equivalents
fn addStrengthReductionRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    // x * 2 → x << 1
    try rules.append(allocator, .{
        .name = "imul_power_of_2",
        .pattern = .{ .op = .{ .opcode = .imul, .vars = &.{ "x", "two" } } },
        .action = .{ .op = .{ .opcode = .ishl, .args = &.{ "x", "one" } } },
    });

    // x / 2 → x >> 1 (unsigned)
    try rules.append(allocator, .{
        .name = "udiv_power_of_2",
        .pattern = .{ .op = .{ .opcode = .udiv, .vars = &.{ "x", "two" } } },
        .action = .{ .op = .{ .opcode = .ushr, .args = &.{ "x", "one" } } },
    });

    // x % 2 → x & 1 (unsigned)
    try rules.append(allocator, .{
        .name = "urem_power_of_2",
        .pattern = .{ .op = .{ .opcode = .urem, .vars = &.{ "x", "two" } } },
        .action = .{ .op = .{ .opcode = .band, .args = &.{ "x", "one" } } },
    });
}

/// Constant folding patterns (to be implemented with actual constant values)
fn addConstantFoldingRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    _ = allocator; // Constant folding requires runtime values, implemented during application
    _ = rules;
}

/// Distributivity rules: x * (y + z) → (x * y) + (x * z)
fn addDistributivityRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    // x * (y + z) → (x * y) + (x * z)
    try rules.append(allocator, .{
        .name = "imul_iadd_dist",
        .pattern = .{ .op = .{ .opcode = .imul, .vars = &.{ "x", "yz" } } },
        .action = .{ .op = .{ .opcode = .iadd, .args = &.{ "xy", "xz" } } },
    });
}

/// De Morgan's laws: !(x & y) → !x | !y
fn addDeMorganRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    // !(x & y) → !x | !y
    try rules.append(allocator, .{
        .name = "demorgan_and",
        .pattern = .{ .op = .{ .opcode = .bnot, .vars = &.{"xy"} } },
        .action = .{ .op = .{ .opcode = .bor, .args = &.{ "not_x", "not_y" } } },
    });

    // !(x | y) → !x & !y
    try rules.append(allocator, .{
        .name = "demorgan_or",
        .pattern = .{ .op = .{ .opcode = .bnot, .vars = &.{"xy"} } },
        .action = .{ .op = .{ .opcode = .band, .args = &.{ "not_x", "not_y" } } },
    });
}

/// Negation rules
fn addNegationRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    // -(-x) → x
    try rules.append(allocator, .{
        .name = "ineg_ineg",
        .pattern = .{ .op = .{ .opcode = .ineg, .vars = &.{"neg_x"} } },
        .action = .{ .var_ = "x" },
    });

    // ~(~x) → x
    try rules.append(allocator, .{
        .name = "bnot_bnot",
        .pattern = .{ .op = .{ .opcode = .bnot, .vars = &.{"not_x"} } },
        .action = .{ .var_ = "x" },
    });
}

/// Comparison simplification
fn addComparisonRules(allocator: Allocator, rules: *ArrayList(RewriteRule)) !void {
    // x == x → true
    try rules.append(allocator, .{
        .name = "icmp_eq_self",
        .pattern = .{ .op = .{ .opcode = .icmp, .vars = &.{ "x", "x" } } },
        .action = .{ .constant = .{ .opcode = .iconst, .value = 1 } },
    });

    // x != x → false
    try rules.append(allocator, .{
        .name = "icmp_ne_self",
        .pattern = .{ .op = .{ .opcode = .icmp, .vars = &.{ "x", "x" } } },
        .action = .{ .constant = .{ .opcode = .iconst, .value = 0 } },
    });

    // x < x → false
    try rules.append(allocator, .{
        .name = "icmp_lt_self",
        .pattern = .{ .op = .{ .opcode = .icmp, .vars = &.{ "x", "x" } } },
        .action = .{ .constant = .{ .opcode = .iconst, .value = 0 } },
    });
}

// Tests
const testing = std.testing;

test "StandardRules initialization" {
    var rules = try StandardRules.init(testing.allocator);
    defer rules.deinit();

    const rule_list = rules.getRules();
    try testing.expect(rule_list.len > 0);
}

test "Rule structure" {
    const rule = RewriteRule{
        .name = "test_rule",
        .pattern = .{ .op = .{ .opcode = .iadd, .vars = &.{ "x", "y" } } },
        .action = .{ .var_ = "x" },
    };

    try testing.expectEqualStrings("test_rule", rule.name);
}
