const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const sema = @import("../sema.zig");
const trie = @import("../trie.zig");

/// Match tree compiler - converts ISLE patterns into efficient decision trees.
///
/// The match tree construction follows these principles:
/// 1. Test discriminants (constructors, constants) before wildcards
/// 2. Prioritize constraints that eliminate the most rules
/// 3. Avoid redundant tests by tracking what's already known
/// 4. Order tests to minimize total comparisons
pub const MatchCompiler = struct {
    /// Type environment for looking up types.
    typeenv: *const sema.TypeEnv,
    /// Term environment for looking up terms.
    termenv: *const sema.TermEnv,
    /// Allocator for temporary data structures.
    allocator: Allocator,

    const Self = @This();

    pub fn init(
        allocator: Allocator,
        typeenv: *const sema.TypeEnv,
        termenv: *const sema.TermEnv,
    ) Self {
        return .{
            .typeenv = typeenv,
            .termenv = termenv,
            .allocator = allocator,
        };
    }

    /// Compile a set of rules into a decision tree.
    /// Rules are assumed to be sorted by priority (highest first).
    pub fn compile(self: *Self, ruleset: *const trie.RuleSet) !*trie.DecisionTree {
        return try trie.buildDecisionTree(ruleset, self.allocator);
    }

    /// Build a rule set from semantic rules.
    pub fn buildRuleSet(self: *Self, rules: []const sema.Rule) !trie.RuleSet {
        var ruleset = trie.RuleSet.init(self.allocator);
        errdefer ruleset.deinit();

        for (rules) |sem_rule| {
            var rule = try self.compileRule(sem_rule);
            errdefer rule.deinit();
            try ruleset.addRule(rule);
        }

        return ruleset;
    }

    /// Compile a single semantic rule into the trie representation.
    fn compileRule(self: *Self, sem_rule: sema.Rule) !trie.Rule {
        var rule = trie.Rule.init(self.allocator, sem_rule.pos);
        errdefer rule.deinit();

        rule.prio = sem_rule.prio;

        // Create a temporary ruleset for interning bindings
        var temp_ruleset = trie.RuleSet.init(self.allocator);
        defer temp_ruleset.deinit();

        // Compile the pattern - this adds constraints to the rule
        const pattern_binding = try self.compilePattern(
            &temp_ruleset,
            &rule,
            sem_rule.pattern,
        );
        _ = pattern_binding;

        // Compile if-let guards
        for (sem_rule.iflets) |iflet| {
            _ = try self.compileIfLet(&temp_ruleset, &rule, iflet);
        }

        // Compile the result expression
        rule.result = try self.compileExpr(&temp_ruleset, sem_rule.expr);

        return rule;
    }

    /// Compile a pattern into bindings and constraints.
    fn compilePattern(
        self: *Self,
        ruleset: *trie.RuleSet,
        rule: *trie.Rule,
        pattern: sema.Pattern,
    ) error{ OutOfMemory, ConflictingConstraints }!trie.BindingId {
        return switch (pattern) {
            .var_pat => |v| {
                // Variable pattern - no constraint, just bind
                // For root patterns, this should be the argument
                const binding = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(0) },
                };
                _ = v;
                return try ruleset.internBinding(binding);
            },
            .term => |t| {
                // Term pattern - extract constructor/extractor and recursively compile args
                const term = self.termenv.getTerm(t.term_id);

                switch (term.kind) {
                    .decl => |decl| {
                        // For constructor patterns, we need to:
                        // 1. Create a binding for the matched value
                        // 2. Add constraint that it matches this constructor
                        // 3. Recursively compile argument patterns

                        var arg_bindings = std.ArrayList(trie.BindingId){};
                        defer arg_bindings.deinit(self.allocator);

                        for (t.args) |arg_pat| {
                            const arg_binding = try self.compilePattern(ruleset, rule, arg_pat);
                            try arg_bindings.append(self.allocator, arg_binding);
                        }

                        // The source binding is the value being matched
                        const source = trie.Binding{
                            .argument = .{ .index = trie.TupleIndex.new(0) },
                        };
                        const source_id = try ruleset.internBinding(source);

                        // For enum variants, add a variant constraint
                        const ret_ty = self.typeenv.getType(decl.ret_ty);
                        if (ret_ty == .enum_type) {
                            // Find which variant this constructor corresponds to
                            const variant_id = self.findVariantForTerm(decl.ret_ty, t.term_id);
                            if (variant_id) |vid| {
                                const field_count = self.getVariantFieldCount(vid);
                                const constraint = trie.Constraint{
                                    .variant = .{
                                        .ty = decl.ret_ty,
                                        .variant = vid,
                                        .field_count = trie.TupleIndex.new(@intCast(field_count)),
                                    },
                                };
                                try rule.setConstraint(source_id, constraint);
                            }
                        }

                        return source_id;
                    },
                    .extractor => {
                        // Extractor pattern - similar to constructor but generates MatchVariant bindings
                        const source = trie.Binding{
                            .argument = .{ .index = trie.TupleIndex.new(0) },
                        };
                        return try ruleset.internBinding(source);
                    },
                    .extern_func => {
                        return error.OutOfMemory; // External functions can't be patterns
                    },
                }
            },
            .const_bool => |c| {
                const binding = trie.Binding{
                    .const_bool = .{ .val = c.val, .ty = sema.TypeId.new(0) },
                };
                const binding_id = try ruleset.internBinding(binding);

                // Add constraint that the source must equal this constant
                const source = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(0) },
                };
                const source_id = try ruleset.internBinding(source);
                const constraint = trie.Constraint{
                    .const_bool = .{ .val = c.val, .ty = sema.TypeId.new(0) },
                };
                try rule.setConstraint(source_id, constraint);

                return binding_id;
            },
            .const_int => |c| {
                const binding = trie.Binding{
                    .const_int = .{ .val = c.val, .ty = c.ty },
                };
                const binding_id = try ruleset.internBinding(binding);

                const source = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(0) },
                };
                const source_id = try ruleset.internBinding(source);
                const constraint = trie.Constraint{
                    .const_int = .{ .val = c.val, .ty = c.ty },
                };
                try rule.setConstraint(source_id, constraint);

                return binding_id;
            },
            .const_prim => |c| {
                const binding = trie.Binding{ .const_prim = .{ .val = c.val } };
                const binding_id = try ruleset.internBinding(binding);

                const source = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(0) },
                };
                const source_id = try ruleset.internBinding(source);
                const constraint = trie.Constraint{ .const_prim = .{ .val = c.val } };
                try rule.setConstraint(source_id, constraint);

                return binding_id;
            },
            .wildcard => {
                // Wildcard - matches anything, no constraint
                const binding = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(0) },
                };
                return try ruleset.internBinding(binding);
            },
            .bind_pattern => |b| {
                // Bind pattern - compile subpattern and remember binding
                return try self.compilePattern(ruleset, rule, b.subpat.*);
            },
            .and_pat => |a| {
                // And pattern - all subpatterns must match
                // Compile all subpatterns and merge their constraints
                var last_binding: ?trie.BindingId = null;
                for (a.subpats) |subpat| {
                    const binding = try self.compilePattern(ruleset, rule, subpat);
                    last_binding = binding;
                }
                return last_binding orelse trie.BindingId.new(0);
            },
        };
    }

    /// Compile an if-let guard into constraints.
    fn compileIfLet(
        self: *Self,
        ruleset: *trie.RuleSet,
        rule: *trie.Rule,
        iflet: sema.IfLet,
    ) !trie.BindingId {
        // Evaluate the RHS expression to get a binding
        const expr_binding = try self.compileExpr(ruleset, iflet.expr);

        // Match the LHS pattern against the expression binding
        // This adds constraints that must succeed for the guard to pass
        return try self.compilePatternWithSource(ruleset, rule, iflet.pattern, expr_binding);
    }

    /// Compile a pattern against a specific source binding (for if-let).
    fn compilePatternWithSource(
        self: *Self,
        ruleset: *trie.RuleSet,
        rule: *trie.Rule,
        pattern: sema.Pattern,
        source_id: trie.BindingId,
    ) error{ OutOfMemory, ConflictingConstraints }!trie.BindingId {
        return switch (pattern) {
            .var_pat => source_id,
            .wildcard => source_id,
            .const_bool => |c| {
                const constraint = trie.Constraint{
                    .const_bool = .{ .val = c.val, .ty = sema.TypeId.new(0) },
                };
                try rule.setConstraint(source_id, constraint);
                return source_id;
            },
            .const_int => |c| {
                const constraint = trie.Constraint{
                    .const_int = .{ .val = c.val, .ty = c.ty },
                };
                try rule.setConstraint(source_id, constraint);
                return source_id;
            },
            .const_prim => |c| {
                const constraint = trie.Constraint{
                    .const_prim = .{ .val = c.val },
                };
                try rule.setConstraint(source_id, constraint);
                return source_id;
            },
            .bind_pattern => |b| {
                return try self.compilePatternWithSource(ruleset, rule, b.subpat.*, source_id);
            },
            .and_pat => |a| {
                var last: trie.BindingId = source_id;
                for (a.subpats) |subpat| {
                    last = try self.compilePatternWithSource(ruleset, rule, subpat, source_id);
                }
                return last;
            },
            .term => |t| {
                const term = self.termenv.getTerm(t.term_id);
                switch (term.kind) {
                    .decl => |decl| {
                        // Constructor pattern - add variant constraint
                        const ret_ty = self.typeenv.getType(decl.ret_ty);
                        if (ret_ty == .enum_type) {
                            const variant_id = self.findVariantForTerm(decl.ret_ty, t.term_id);
                            if (variant_id) |vid| {
                                const field_count = self.getVariantFieldCount(vid);
                                const constraint = trie.Constraint{
                                    .variant = .{
                                        .ty = decl.ret_ty,
                                        .variant = vid,
                                        .field_count = trie.TupleIndex.new(@intCast(field_count)),
                                    },
                                };
                                try rule.setConstraint(source_id, constraint);
                            }
                        }
                        // TODO: Compile field patterns recursively
                        return source_id;
                    },
                    .extractor => {
                        // TODO: Handle extractor patterns
                        return source_id;
                    },
                    .extern_func => return error.OutOfMemory,
                }
            },
        };
    }

    /// Compile an expression into a binding.
    fn compileExpr(
        self: *Self,
        ruleset: *trie.RuleSet,
        expr: sema.Expr,
    ) !trie.BindingId {
        return switch (expr) {
            .var_expr => |v| {
                // Variable reference - look up existing binding
                const binding = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(@intCast(v.var_id)) },
                };
                return try ruleset.internBinding(binding);
            },
            .term => |t| {
                // Term construction - compile arguments and create constructor binding
                var arg_bindings = std.ArrayList(trie.BindingId){};
                defer arg_bindings.deinit(self.allocator);

                for (t.args) |arg| {
                    const binding = try self.compileExpr(ruleset, arg);
                    try arg_bindings.append(self.allocator, binding);
                }

                const term = self.termenv.getTerm(t.term_id);
                const is_pure = switch (term.kind) {
                    .decl => |d| d.pure,
                    else => false,
                };

                const binding = trie.Binding{
                    .constructor = .{
                        .term = t.term_id,
                        .parameters = try arg_bindings.toOwnedSlice(self.allocator),
                        .instance = if (is_pure) 0 else 1,
                    },
                };
                return try ruleset.internBinding(binding);
            },
            .const_bool => |c| {
                const binding = trie.Binding{
                    .const_bool = .{ .val = c.val, .ty = sema.TypeId.new(0) },
                };
                return try ruleset.internBinding(binding);
            },
            .const_int => |c| {
                const binding = trie.Binding{
                    .const_int = .{ .val = c.val, .ty = c.ty },
                };
                return try ruleset.internBinding(binding);
            },
            .const_prim => |c| {
                const binding = trie.Binding{ .const_prim = .{ .val = c.val } };
                return try ruleset.internBinding(binding);
            },
            .let_expr => |l| {
                // Let expression - compile bindings and body
                for (l.bindings) |let_binding| {
                    _ = try self.compileExpr(ruleset, let_binding.val);
                }
                return try self.compileExpr(ruleset, l.body.*);
            },
        };
    }

    /// Find the variant ID for a constructor term.
    fn findVariantForTerm(self: *const Self, type_id: sema.TypeId, term_id: sema.TermId) ?sema.VariantId {
        const ty = self.typeenv.getType(type_id);
        if (ty != .enum_type) return null;

        const term = self.termenv.getTerm(term_id);
        const term_name = term.name;

        for (ty.enum_type.variants, 0..) |variant, i| {
            if (variant.name.index() == term_name.index()) {
                return sema.VariantId.new(type_id, @intCast(i));
            }
        }

        return null;
    }

    /// Get the number of fields in a variant.
    fn getVariantFieldCount(self: *const Self, variant_id: sema.VariantId) usize {
        const ty = self.typeenv.getType(variant_id.type_id);
        if (ty != .enum_type) return 0;

        const variant = ty.enum_type.variants[variant_id.variant_index];
        return variant.fields.len;
    }
};

/// Optimize a decision tree by eliminating redundant tests.
pub fn optimizeTree(tree: *trie.DecisionTree, allocator: Allocator) !void {
    var ctx = OptCtx{
        .allocator = allocator,
        .seen = std.AutoHashMap(*const trie.DecisionTree, *trie.DecisionTree).init(allocator),
    };
    defer ctx.seen.deinit();
    _ = try optimizeNode(tree, &ctx);
}

const OptCtx = struct {
    allocator: Allocator,
    seen: std.AutoHashMap(*const trie.DecisionTree, *trie.DecisionTree),
};

/// Optimize a single node and its children.
fn optimizeNode(tree: *trie.DecisionTree, ctx: *OptCtx) error{OutOfMemory}!*trie.DecisionTree {
    // Check for previously seen identical subtree (DAG sharing)
    if (ctx.seen.get(tree)) |cached| {
        return cached;
    }

    switch (tree.*) {
        .leaf, .fail => return tree,
        .switch_constraint => |*s| {
            // Optimize all cases
            var it = s.cases.iterator();
            while (it.next()) |entry| {
                const optimized = try optimizeNode(entry.value_ptr.*, ctx);
                entry.value_ptr.* = optimized;
            }

            if (s.default) |def| {
                s.default = try optimizeNode(def, ctx);
            }

            // Remove unreachable cases: if default is .fail and no cases exist
            if (s.cases.count() == 0 and s.default != null and s.default.?.* == .fail) {
                return s.default.?;
            }

            // If only default exists, inline it
            if (s.cases.count() == 0 and s.default != null) {
                return s.default.?;
            }

            // Merge identical cases with default
            if (s.default) |def| {
                var to_remove = std.ArrayList(trie.Constraint){};
                defer to_remove.deinit(ctx.allocator);

                var case_it = s.cases.iterator();
                while (case_it.next()) |entry| {
                    if (treesEqual(entry.value_ptr.*, def)) {
                        try to_remove.append(ctx.allocator, entry.key_ptr.*);
                    }
                }

                for (to_remove.items) |constraint| {
                    _ = s.cases.remove(constraint);
                }
            }

            try ctx.seen.put(tree, tree);
            return tree;
        },
        .test_equal => |*t| {
            t.on_equal = try optimizeNode(t.on_equal, ctx);
            t.on_not_equal = try optimizeNode(t.on_not_equal, ctx);

            // If both branches are identical, eliminate the test
            if (treesEqual(t.on_equal, t.on_not_equal)) {
                return t.on_equal;
            }

            try ctx.seen.put(tree, tree);
            return tree;
        },
    }
}

/// Check if two trees are structurally identical.
fn treesEqual(a: *const trie.DecisionTree, b: *const trie.DecisionTree) bool {
    if (@as(std.meta.Tag(trie.DecisionTree), a.*) != @as(std.meta.Tag(trie.DecisionTree), b.*)) {
        return false;
    }

    return switch (a.*) {
        .leaf => |al| std.meta.eql(al.rule_index, b.leaf.rule_index),
        .fail => true,
        .switch_constraint => |*as| blk: {
            const bs = &b.switch_constraint;
            if (!std.meta.eql(as.binding, bs.binding)) break :blk false;
            if (as.cases.count() != bs.cases.count()) break :blk false;

            // Check all cases match
            var it = as.cases.iterator();
            while (it.next()) |entry| {
                const b_tree = bs.cases.get(entry.key_ptr.*) orelse break :blk false;
                if (!treesEqual(entry.value_ptr.*, b_tree)) break :blk false;
            }

            // Check defaults
            if (as.default == null and bs.default == null) break :blk true;
            if (as.default == null or bs.default == null) break :blk false;
            break :blk treesEqual(as.default.?, bs.default.?);
        },
        .test_equal => |*at| blk: {
            const bt = &b.test_equal;
            if (!std.meta.eql(at.a, bt.a) or !std.meta.eql(at.b, bt.b)) break :blk false;
            if (!treesEqual(at.on_equal, bt.on_equal)) break :blk false;
            break :blk treesEqual(at.on_not_equal, bt.on_not_equal);
        },
    };
}

/// Estimate the cost of evaluating a decision tree.
/// Lower cost is better.
pub fn estimateCost(tree: *const trie.DecisionTree) usize {
    return switch (tree.*) {
        .leaf => 1,
        .fail => 0,
        .switch_constraint => |*s| blk: {
            var total: usize = 1; // Cost of the switch itself
            var it = s.cases.valueIterator();
            while (it.next()) |subtree| {
                total += estimateCost(subtree.*);
            }
            if (s.default) |def| {
                total += estimateCost(def);
            }
            break :blk total;
        },
        .test_equal => |*t| {
            return 1 + estimateCost(t.on_equal) + estimateCost(t.on_not_equal);
        },
    };
}

test "MatchCompiler initialization" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    const compiler = MatchCompiler.init(testing.allocator, &typeenv, &termenv);
    _ = compiler;
}

test "MatchCompiler: simple constant pattern" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    var compiler = MatchCompiler.init(testing.allocator, &typeenv, &termenv);

    // Create a simple rule: (pattern: true) => true
    const pattern = sema.Pattern{
        .const_bool = .{ .val = true, .pos = sema.Pos.new(0, 0) },
    };

    const expr = sema.Expr{
        .const_bool = .{ .val = true, .pos = sema.Pos.new(0, 0) },
    };

    const sem_rule = sema.Rule{
        .pattern = pattern,
        .iflets = &.{},
        .expr = expr,
        .prio = 0,
        .pos = sema.Pos.new(0, 0),
    };

    var rule = try compiler.compileRule(sem_rule);
    defer rule.deinit();

    // Verify the rule has a constraint
    try testing.expect(rule.totalConstraints() > 0);
}

test "MatchCompiler: build decision tree" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    var compiler = MatchCompiler.init(testing.allocator, &typeenv, &termenv);

    // Create two rules with different constants
    const rule1 = sema.Rule{
        .pattern = .{ .const_bool = .{ .val = true, .pos = sema.Pos.new(0, 0) } },
        .iflets = &.{},
        .expr = .{ .const_int = .{ .val = 1, .ty = sema.TypeId.new(0), .pos = sema.Pos.new(0, 0) } },
        .prio = 0,
        .pos = sema.Pos.new(0, 0),
    };

    const rule2 = sema.Rule{
        .pattern = .{ .const_bool = .{ .val = false, .pos = sema.Pos.new(1, 0) } },
        .iflets = &.{},
        .expr = .{ .const_int = .{ .val = 2, .ty = sema.TypeId.new(0), .pos = sema.Pos.new(1, 0) } },
        .prio = 0,
        .pos = sema.Pos.new(1, 0),
    };

    const rules = [_]sema.Rule{ rule1, rule2 };
    var ruleset = try compiler.buildRuleSet(&rules);
    defer ruleset.deinit();

    var tree = try compiler.compile(&ruleset);
    defer {
        tree.deinit(testing.allocator);
        testing.allocator.destroy(tree);
    }

    // Verify we got a non-trivial decision tree
    try testing.expect(tree.* != .fail);
}

test "Decision tree cost estimation" {
    var tree_leaf = trie.DecisionTree{ .leaf = .{ .rule_index = 0 } };
    try testing.expectEqual(@as(usize, 1), estimateCost(&tree_leaf));

    var tree_fail: trie.DecisionTree = .fail;
    try testing.expectEqual(@as(usize, 0), estimateCost(&tree_fail));
}

test "MatchCompiler: wildcard pattern" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    var compiler = MatchCompiler.init(testing.allocator, &typeenv, &termenv);

    const pattern = sema.Pattern{
        .wildcard = .{ .ty = sema.TypeId.new(0), .pos = sema.Pos.new(0, 0) },
    };

    const expr = sema.Expr{
        .const_bool = .{ .val = true, .pos = sema.Pos.new(0, 0) },
    };

    const sem_rule = sema.Rule{
        .pattern = pattern,
        .iflets = &.{},
        .expr = expr,
        .prio = 0,
        .pos = sema.Pos.new(0, 0),
    };

    var rule = try compiler.compileRule(sem_rule);
    defer rule.deinit();

    // Wildcard should have no constraints
    try testing.expectEqual(@as(usize, 0), rule.totalConstraints());
}
