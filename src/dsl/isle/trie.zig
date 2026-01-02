const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const sema = @import("sema.zig");

/// A field index in a tuple or enum variant.
pub const TupleIndex = struct {
    index: u8,

    pub fn new(idx: u8) TupleIndex {
        return .{ .index = idx };
    }

    pub fn value(self: TupleIndex) usize {
        return self.index;
    }
};

/// Hash-consed identifier for a binding in a compiled rule.
pub const BindingId = struct {
    id: u16,

    pub fn new(idx: u16) BindingId {
        return .{ .id = idx };
    }

    pub fn index(self: BindingId) usize {
        return self.id;
    }
};

/// A binding represents a value in the pattern matching process.
/// This is the normalized IR for code generation.
pub const Binding = union(enum) {
    /// A constant boolean literal.
    const_bool: struct {
        val: bool,
        ty: sema.TypeId,
    },
    /// A constant integer literal.
    const_int: struct {
        val: i128,
        ty: sema.TypeId,
    },
    /// A primitive constant value (symbol name).
    const_prim: struct {
        val: sema.Sym,
    },
    /// One of the function arguments.
    argument: struct {
        index: TupleIndex,
    },
    /// Result of calling an external extractor.
    extractor: struct {
        term: sema.TermId,
        parameter: BindingId,
    },
    /// Result of calling a constructor.
    constructor: struct {
        term: sema.TermId,
        parameters: []const BindingId,
        /// For impure constructors, unique instance number.
        instance: u32,
    },
    /// Result of iterator from multi-constructor.
    iterator: struct {
        source: BindingId,
    },
    /// Construct an enum variant.
    make_variant: struct {
        ty: sema.TypeId,
        variant: sema.VariantId,
        fields: []const BindingId,
    },
    /// Pattern-match and extract field from enum variant.
    match_variant: struct {
        source: BindingId,
        variant: sema.VariantId,
        field: TupleIndex,
    },
    /// Construct an Option::Some.
    make_some: struct {
        inner: BindingId,
    },
    /// Pattern-match Option::Some.
    match_some: struct {
        source: BindingId,
    },
    /// Pattern-match tuple field (irrefutable).
    match_tuple: struct {
        source: BindingId,
        field: TupleIndex,
    },
};

/// Pattern matching constraints that can fail.
pub const Constraint = union(enum) {
    /// Must match this enum variant.
    variant: struct {
        ty: sema.TypeId,
        variant: sema.VariantId,
        field_count: TupleIndex,
    },
    /// Must equal this boolean literal.
    const_bool: struct {
        val: bool,
        ty: sema.TypeId,
    },
    /// Must equal this integer literal.
    const_int: struct {
        val: i128,
        ty: sema.TypeId,
    },
    /// Must equal this primitive value.
    const_prim: struct {
        val: sema.Sym,
    },
    /// Must be Option::Some (from fallible extractor).
    some,

    /// Returns the bindings created by matching this constraint.
    pub fn bindingsFor(self: Constraint, source: BindingId, allocator: Allocator) ![]Binding {
        return switch (self) {
            .const_bool, .const_int, .const_prim => &[_]Binding{},
            .some => &[_]Binding{.{ .match_some = .{ .source = source } }},
            .variant => |v| blk: {
                var bindings = std.ArrayList(Binding){};
                var i: u8 = 0;
                while (i < v.field_count.index) : (i += 1) {
                    try bindings.append(allocator, .{ .match_variant = .{
                        .source = source,
                        .variant = v.variant,
                        .field = TupleIndex.new(i),
                    } });
                }
                break :blk try bindings.toOwnedSlice(allocator);
            },
        };
    }
};

/// Disjoint sets for tracking equality constraints.
const DisjointSets = struct {
    parent: std.ArrayList(BindingId),
    allocator: Allocator,

    pub fn init(allocator: Allocator) DisjointSets {
        return .{
            .parent = std.ArrayList(BindingId){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DisjointSets) void {
        self.parent.deinit(self.allocator);
    }

    pub fn ensure(self: *DisjointSets, id: BindingId) !void {
        while (self.parent.items.len <= id.index()) {
            const idx = self.parent.items.len;
            try self.parent.append(self.allocator, BindingId.new(@intCast(idx)));
        }
    }

    pub fn find(self: *DisjointSets, id: BindingId) BindingId {
        if (id.index() >= self.parent.items.len) return id;
        var current = id;
        while (!std.meta.eql(self.parent.items[current.index()], current)) {
            current = self.parent.items[current.index()];
        }
        return current;
    }

    pub fn merge(self: *DisjointSets, a: BindingId, b: BindingId) !void {
        try self.ensure(a);
        try self.ensure(b);
        const root_a = self.find(a);
        const root_b = self.find(b);
        if (!std.meta.eql(root_a, root_b)) {
            self.parent.items[root_b.index()] = root_a;
        }
    }

    pub fn isEmpty(self: *const DisjointSets) bool {
        return self.parent.items.len == 0;
    }

    pub fn len(self: *const DisjointSets) usize {
        // Count non-trivial equivalence classes
        var count: usize = 0;
        for (self.parent.items, 0..) |parent, i| {
            if (parent.index() != i) {
                count += 1;
            }
        }
        return count;
    }
};

/// A compiled pattern matching rule.
pub const Rule = struct {
    /// Source position for error messages.
    pos: sema.Pos,
    /// Constraints that must be satisfied.
    constraints: std.AutoHashMap(BindingId, Constraint),
    /// Equality constraints between bindings.
    equals: DisjointSets,
    /// Multi-term iterators that need evaluation.
    iterators: std.ArrayList(BindingId),
    /// Rule priority for overlap resolution.
    prio: i64,
    /// Side effects (impure bindings) to evaluate.
    impure: std.ArrayList(BindingId),
    /// Result expression.
    result: BindingId,
    /// Allocator.
    allocator: Allocator,

    pub fn init(allocator: Allocator, pos: sema.Pos) Rule {
        return .{
            .pos = pos,
            .constraints = std.AutoHashMap(BindingId, Constraint).init(allocator),
            .equals = DisjointSets.init(allocator),
            .iterators = std.ArrayList(BindingId){},
            .prio = 0,
            .impure = std.ArrayList(BindingId){},
            .result = BindingId.new(0),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Rule) void {
        self.constraints.deinit();
        self.equals.deinit();
        self.iterators.deinit(self.allocator);
        self.impure.deinit(self.allocator);
    }

    /// Get the constraint for a binding, if any.
    pub fn getConstraint(self: *const Rule, id: BindingId) ?Constraint {
        return self.constraints.get(id);
    }

    /// Add or check a constraint for a binding.
    pub fn setConstraint(self: *Rule, id: BindingId, constraint: Constraint) !void {
        const entry = try self.constraints.getOrPut(id);
        if (entry.found_existing) {
            // Check if constraints match
            if (!std.meta.eql(entry.value_ptr.*, constraint)) {
                return error.ConflictingConstraints;
            }
        } else {
            entry.value_ptr.* = constraint;
        }
    }

    /// Total number of constraints (concrete + equality).
    pub fn totalConstraints(self: *const Rule) usize {
        return self.constraints.count() + self.equals.len();
    }
};

/// Records whether two rules can overlap.
pub const Overlap = enum {
    /// Rules cannot both match any input.
    no,
    /// Rules can match some common input.
    yes_disjoint,
    /// One rule is a subset of the other.
    yes_subset,

    /// Check if two rules may overlap.
    pub fn check(a: *const Rule, b: *const Rule) Overlap {
        // Pick smaller rule for efficiency
        const small = if (a.constraints.count() <= b.constraints.count()) a else b;
        const big = if (a.constraints.count() <= b.constraints.count()) b else a;

        // Check if subset (all constraints in small are in big)
        var subset = small.equals.isEmpty() and big.equals.isEmpty();

        var it = small.constraints.iterator();
        while (it.next()) |entry| {
            const binding = entry.key_ptr.*;
            const constraint_a = entry.value_ptr.*;

            if (big.constraints.get(binding)) |constraint_b| {
                if (!std.meta.eql(constraint_a, constraint_b)) {
                    // Conflicting constraints - can't overlap
                    return .no;
                }
            } else {
                // Big doesn't constrain this binding
                subset = false;
            }
        }

        return if (subset) .yes_subset else .yes_disjoint;
    }
};

/// Compare two bindings for structural equality.
fn bindingsEqual(a: *const Binding, b: *const Binding) bool {
    if (@as(std.meta.Tag(Binding), a.*) != @as(std.meta.Tag(Binding), b.*)) {
        return false;
    }

    return switch (a.*) {
        .const_bool => |ab| std.meta.eql(ab, b.const_bool),
        .const_int => |ai| std.meta.eql(ai, b.const_int),
        .const_prim => |ap| std.meta.eql(ap, b.const_prim),
        .argument => |aa| std.meta.eql(aa, b.argument),
        .extractor => |ae| std.meta.eql(ae, b.extractor),
        .constructor => |ac| blk: {
            const bc = b.constructor;
            if (!std.meta.eql(ac.term, bc.term) or !std.meta.eql(ac.instance, bc.instance)) {
                break :blk false;
            }
            if (ac.parameters.len != bc.parameters.len) {
                break :blk false;
            }
            for (ac.parameters, bc.parameters) |ap, bp| {
                if (!std.meta.eql(ap, bp)) {
                    break :blk false;
                }
            }
            break :blk true;
        },
        .iterator => |ai| std.meta.eql(ai, b.iterator),
        .make_variant => |av| blk: {
            const bv = b.make_variant;
            if (!std.meta.eql(av.ty, bv.ty) or !std.meta.eql(av.variant, bv.variant)) {
                break :blk false;
            }
            if (av.fields.len != bv.fields.len) {
                break :blk false;
            }
            for (av.fields, bv.fields) |af, bf| {
                if (!std.meta.eql(af, bf)) {
                    break :blk false;
                }
            }
            break :blk true;
        },
        .match_variant => |av| std.meta.eql(av, b.match_variant),
        .make_some => |as| std.meta.eql(as, b.make_some),
        .match_some => |as| std.meta.eql(as, b.match_some),
        .match_tuple => |at| std.meta.eql(at, b.match_tuple),
    };
}

/// Collection of compiled rules with hash-consed bindings.
pub const RuleSet = struct {
    /// Compiled rules for a term.
    rules: std.ArrayList(Rule),
    /// Hash-consed bindings (linear search for now - contains slices so can't auto-hash).
    bindings: std.ArrayList(Binding),
    /// Allocator.
    allocator: Allocator,

    pub fn init(allocator: Allocator) RuleSet {
        return .{
            .rules = std.ArrayList(Rule){},
            .bindings = std.ArrayList(Binding){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RuleSet) void {
        for (self.rules.items) |*rule| {
            rule.deinit();
        }
        self.rules.deinit(self.allocator);

        // Free binding slices
        for (self.bindings.items) |binding| {
            switch (binding) {
                .constructor => |c| self.allocator.free(c.parameters),
                .make_variant => |v| self.allocator.free(v.fields),
                else => {},
            }
        }
        self.bindings.deinit(self.allocator);
    }

    /// Find or create a binding ID for the given binding.
    pub fn internBinding(self: *RuleSet, binding: Binding) !BindingId {
        // Linear search for existing binding (TODO: implement custom hash function)
        for (self.bindings.items, 0..) |*existing, i| {
            if (bindingsEqual(existing, &binding)) {
                return BindingId.new(@intCast(i));
            }
        }

        // Not found, add new binding
        const id = BindingId.new(@intCast(self.bindings.items.len));
        try self.bindings.append(self.allocator, binding);
        return id;
    }

    /// Find an existing binding ID, if it exists.
    pub fn findBinding(self: *const RuleSet, binding: *const Binding) ?BindingId {
        for (self.bindings.items, 0..) |*existing, i| {
            if (bindingsEqual(existing, binding)) {
                return BindingId.new(@intCast(i));
            }
        }
        return null;
    }

    /// Add a compiled rule to this set.
    pub fn addRule(self: *RuleSet, rule: Rule) !void {
        try self.rules.append(self.allocator, rule);
    }
};

/// Decision tree node for efficient pattern matching.
pub const DecisionTree = union(enum) {
    /// Leaf: no more patterns to match, return this rule.
    leaf: struct {
        rule_index: usize,
    },
    /// Switch on a constraint.
    switch_constraint: struct {
        binding: BindingId,
        /// Map from constraint to subtree.
        cases: std.AutoHashMap(Constraint, *DecisionTree),
        /// Default case (wildcard).
        default: ?*DecisionTree,
    },
    /// Test equality between bindings.
    test_equal: struct {
        a: BindingId,
        b: BindingId,
        on_equal: *DecisionTree,
        on_not_equal: *DecisionTree,
    },
    /// Fail: no rule matches.
    fail,

    pub fn deinit(self: *DecisionTree, allocator: Allocator) void {
        switch (self.*) {
            .leaf, .fail => {},
            .switch_constraint => |*s| {
                var it = s.cases.valueIterator();
                while (it.next()) |subtree| {
                    subtree.*.deinit(allocator);
                    allocator.destroy(subtree.*);
                }
                s.cases.deinit();
                if (s.default) |def| {
                    def.deinit(allocator);
                    allocator.destroy(def);
                }
            },
            .test_equal => |*t| {
                t.on_equal.deinit(allocator);
                allocator.destroy(t.on_equal);
                t.on_not_equal.deinit(allocator);
                allocator.destroy(t.on_not_equal);
            },
        }
    }
};

/// Working set of rules still being matched.
const RuleSubset = struct {
    indices: std.ArrayList(usize),
    allocator: Allocator,

    pub fn init(allocator: Allocator) RuleSubset {
        return .{ .indices = std.ArrayList(usize).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *RuleSubset) void {
        self.indices.deinit();
    }

    pub fn clone(self: *const RuleSubset) !RuleSubset {
        var new = RuleSubset.init(self.allocator);
        try new.indices.appendSlice(self.indices.items);
        return new;
    }

    pub fn isEmpty(self: *const RuleSubset) bool {
        return self.indices.items.len == 0;
    }

    pub fn single(self: *const RuleSubset) ?usize {
        if (self.indices.items.len == 1) {
            return self.indices.items[0];
        }
        return null;
    }
};

/// Score for selecting the best constraint to test.
const SplitScore = struct {
    /// Number of rules eliminated by this constraint.
    eliminated: usize,
    /// Total constraints in remaining rules.
    total_constraints: usize,
    /// Binding being tested.
    binding: BindingId,
    /// Constraint being tested.
    constraint: Constraint,

    pub fn lessThan(_: void, a: SplitScore, b: SplitScore) bool {
        // Prefer splits that eliminate more rules
        if (a.eliminated != b.eliminated) {
            return a.eliminated > b.eliminated;
        }
        // Break ties by total constraint complexity
        return a.total_constraints < b.total_constraints;
    }
};

/// Build a decision tree from a rule set.
pub fn buildDecisionTree(
    ruleset: *const RuleSet,
    allocator: Allocator,
) !*DecisionTree {
    if (ruleset.rules.items.len == 0) {
        const tree = try allocator.create(DecisionTree);
        tree.* = .fail;
        return tree;
    }

    // Initialize with all rules
    var initial = RuleSubset.init(allocator);
    defer initial.deinit();
    for (0..ruleset.rules.items.len) |i| {
        try initial.indices.append(i);
    }

    return try buildSubtree(ruleset, &initial, allocator);
}

/// Recursively build decision tree for a subset of rules.
fn buildSubtree(
    ruleset: *const RuleSet,
    subset: *const RuleSubset,
    allocator: Allocator,
) error{OutOfMemory}!*DecisionTree {
    // Base case: no rules match
    if (subset.isEmpty()) {
        const tree = try allocator.create(DecisionTree);
        tree.* = .fail;
        return tree;
    }

    // Base case: single rule
    if (subset.single()) |rule_idx| {
        const tree = try allocator.create(DecisionTree);
        tree.* = .{ .leaf = .{ .rule_index = rule_idx } };
        return tree;
    }

    // Find the best constraint to test
    const best_split = try findBestSplit(ruleset, subset, allocator);

    if (best_split) |split| {
        // Build switch on this constraint
        const tree = try allocator.create(DecisionTree);
        tree.* = .{ .switch_constraint = .{
            .binding = split.binding,
            .cases = std.AutoHashMap(Constraint, *DecisionTree).init(allocator),
            .default = null,
        } };

        // Partition rules based on this constraint
        var matches = RuleSubset.init(allocator);
        defer matches.deinit();
        var non_matches = RuleSubset.init(allocator);
        defer non_matches.deinit();

        for (subset.indices.items) |rule_idx| {
            const rule = &ruleset.rules.items[rule_idx];
            if (rule.getConstraint(split.binding)) |constraint| {
                if (std.meta.eql(constraint, split.constraint)) {
                    try matches.indices.append(rule_idx);
                } else {
                    try non_matches.indices.append(rule_idx);
                }
            } else {
                try non_matches.indices.append(rule_idx);
            }
        }

        // Recursively build subtrees
        const match_tree = try buildSubtree(ruleset, &matches, allocator);
        try tree.switch_constraint.cases.put(split.constraint, match_tree);

        if (!non_matches.isEmpty()) {
            tree.switch_constraint.default = try buildSubtree(ruleset, &non_matches, allocator);
        }

        return tree;
    } else {
        // No good split found, try equality constraints
        const best_eq = try findBestEquality(ruleset, subset, allocator);

        if (best_eq) |eq| {
            const tree = try allocator.create(DecisionTree);
            tree.* = .{ .test_equal = .{
                .a = eq.a,
                .b = eq.b,
                .on_equal = undefined,
                .on_not_equal = undefined,
            } };

            // Partition rules
            var equal = RuleSubset.init(allocator);
            defer equal.deinit();
            var not_equal = RuleSubset.init(allocator);
            defer not_equal.deinit();

            for (subset.indices.items) |rule_idx| {
                const rule = &ruleset.rules.items[rule_idx];
                const canonical_a = rule.equals.find(eq.a);
                const canonical_b = rule.equals.find(eq.b);

                if (std.meta.eql(canonical_a, canonical_b)) {
                    try equal.indices.append(rule_idx);
                } else {
                    try not_equal.indices.append(rule_idx);
                }
            }

            tree.test_equal.on_equal = try buildSubtree(ruleset, &equal, allocator);
            tree.test_equal.on_not_equal = try buildSubtree(ruleset, &not_equal, allocator);

            return tree;
        } else {
            // No splits possible - return first rule by priority
            const tree = try allocator.create(DecisionTree);
            tree.* = .{ .leaf = .{ .rule_index = subset.indices.items[0] } };
            return tree;
        }
    }
}

/// Find the best constraint to test for splitting rules.
fn findBestSplit(
    ruleset: *const RuleSet,
    subset: *const RuleSubset,
    allocator: Allocator,
) !?SplitScore {
    var candidates = std.ArrayList(SplitScore).init(allocator);
    defer candidates.deinit();

    // Collect all constraints from rules in subset
    for (subset.indices.items) |rule_idx| {
        const rule = &ruleset.rules.items[rule_idx];
        var it = rule.constraints.iterator();
        while (it.next()) |entry| {
            const binding = entry.key_ptr.*;
            const constraint = entry.value_ptr.*;

            // Count how many rules this would eliminate
            var eliminated: usize = 0;
            var total_constraints: usize = 0;

            for (subset.indices.items) |other_idx| {
                const other = &ruleset.rules.items[other_idx];
                total_constraints += other.totalConstraints();

                if (other.getConstraint(binding)) |other_constraint| {
                    if (!std.meta.eql(constraint, other_constraint)) {
                        eliminated += 1;
                    }
                } else {
                    eliminated += 1;
                }
            }

            if (eliminated > 0) {
                try candidates.append(.{
                    .eliminated = eliminated,
                    .total_constraints = total_constraints,
                    .binding = binding,
                    .constraint = constraint,
                });
            }
        }
    }

    if (candidates.items.len == 0) {
        return null;
    }

    // Sort and pick best
    std.mem.sort(SplitScore, candidates.items, {}, SplitScore.lessThan);
    return candidates.items[0];
}

/// Find the best equality constraint to test.
fn findBestEquality(
    ruleset: *const RuleSet,
    subset: *const RuleSubset,
    allocator: Allocator,
) !?struct { a: BindingId, b: BindingId } {
    _ = ruleset;
    _ = subset;
    _ = allocator;
    // TODO: Implement equality constraint selection
    return null;
}

test "Binding hash-consing" {
    var ruleset = RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    const b1 = try ruleset.internBinding(.{ .const_bool = .{
        .val = true,
        .ty = sema.TypeId.new(0),
    } });

    const b2 = try ruleset.internBinding(.{ .const_bool = .{
        .val = true,
        .ty = sema.TypeId.new(0),
    } });

    // Same binding should be deduplicated
    try testing.expectEqual(b1, b2);

    const b3 = try ruleset.internBinding(.{ .const_bool = .{
        .val = false,
        .ty = sema.TypeId.new(0),
    } });

    // Different binding should get different ID
    try testing.expect(!std.meta.eql(b1, b3));
}

test "Rule constraints" {
    var rule = Rule.init(testing.allocator, sema.Pos.new(0, 0));
    defer rule.deinit();

    const b1 = BindingId.new(0);
    const c1 = Constraint{ .const_bool = .{
        .val = true,
        .ty = sema.TypeId.new(0),
    } };

    try rule.setConstraint(b1, c1);
    try testing.expect(rule.getConstraint(b1) != null);
    try testing.expectEqual(c1, rule.getConstraint(b1).?);

    // Same constraint should succeed
    try rule.setConstraint(b1, c1);

    // Different constraint should fail
    const c2 = Constraint{ .const_bool = .{
        .val = false,
        .ty = sema.TypeId.new(0),
    } };
    try testing.expectError(error.ConflictingConstraints, rule.setConstraint(b1, c2));
}

test "Overlap detection" {
    var r1 = Rule.init(testing.allocator, sema.Pos.new(0, 0));
    defer r1.deinit();
    var r2 = Rule.init(testing.allocator, sema.Pos.new(0, 0));
    defer r2.deinit();

    const b1 = BindingId.new(0);

    // Same constraints - should overlap
    try r1.setConstraint(b1, .{ .const_bool = .{
        .val = true,
        .ty = sema.TypeId.new(0),
    } });
    try r2.setConstraint(b1, .{ .const_bool = .{
        .val = true,
        .ty = sema.TypeId.new(0),
    } });

    try testing.expectEqual(Overlap.yes_subset, Overlap.check(&r1, &r2));

    // Different constraints - should not overlap
    var r3 = Rule.init(testing.allocator, sema.Pos.new(0, 0));
    defer r3.deinit();
    try r3.setConstraint(b1, .{ .const_bool = .{
        .val = false,
        .ty = sema.TypeId.new(0),
    } });

    try testing.expectEqual(Overlap.no, Overlap.check(&r1, &r3));
}

test "DisjointSets" {
    var ds = DisjointSets.init(testing.allocator);
    defer ds.deinit();

    const a = BindingId.new(0);
    const b = BindingId.new(1);
    const c = BindingId.new(2);

    try ds.merge(a, b);
    try testing.expectEqual(ds.find(a), ds.find(b));
    try testing.expect(!std.meta.eql(ds.find(a), ds.find(c)));

    try ds.merge(b, c);
    try testing.expectEqual(ds.find(a), ds.find(c));
}
