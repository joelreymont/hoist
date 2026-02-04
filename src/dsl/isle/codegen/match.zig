const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const sema = @import("../sema.zig");
const trie = @import("../trie.zig");

const TermPattern = std.meta.TagPayload(sema.Pattern, .term);
const VarMap = std.AutoHashMap(usize, trie.BindingId);

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
    /// Unique instance counter for impure constructors.
    next_impure_instance: u32,

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
            .next_impure_instance = 1,
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
            var rule = try self.compileRule(&ruleset, sem_rule);
            errdefer rule.deinit();
            try ruleset.addRule(rule);
        }

        return ruleset;
    }

    /// Build a rule set for a specific term.
    ///
    /// Rules in ISLE are written as `(rule (term arg0 arg1 ...) rhs)`. For codegen of
    /// `constructor_term`, the outer `term` is already known, so this compiles patterns
    /// against the term's arguments (bindings `.argument{0..}`), not against a synthetic
    /// "argument 0 is the whole term application".
    pub fn buildRuleSetForTerm(
        self: *Self,
        term_id: sema.TermId,
        rules: []const sema.Rule,
    ) !trie.RuleSet {
        var ruleset = trie.RuleSet.init(self.allocator);
        errdefer ruleset.deinit();

        const term = self.termenv.getTerm(term_id);
        const decl = switch (term.kind) {
            .decl => |d| d,
            else => return error.UnsupportedRuleTerm,
        };

        for (rules) |sem_rule| {
            var rule = trie.Rule.init(self.allocator, sem_rule.pos);
            errdefer rule.deinit();

            rule.prio = sem_rule.prio;

            var vars = VarMap.init(self.allocator);
            defer vars.deinit();

            const pat = switch (sem_rule.pattern) {
                .term => |t| t,
                else => return error.ExpectedTermPattern,
            };
            if (pat.term_id != term_id) return error.ExpectedTermPattern;
            if (pat.args.len != decl.arg_tys.len) return error.ArityMismatch;

            for (pat.args, 0..) |arg_pat, i| {
                const arg_binding = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(@intCast(i)) },
                };
                const arg_id = try ruleset.internBinding(arg_binding);
                _ = try self.compilePatternWithSource(&ruleset, &rule, &vars, arg_pat, arg_id);
            }

            for (sem_rule.iflets) |iflet| {
                _ = try self.compileIfLet(&ruleset, &rule, &vars, iflet);
            }

            rule.result = try self.compileExpr(&ruleset, &vars, sem_rule.expr);
            try ruleset.addRule(rule);
        }

        return ruleset;
    }

    /// Compile a single semantic rule into the trie representation.
    fn compileRule(self: *Self, ruleset: *trie.RuleSet, sem_rule: sema.Rule) !trie.Rule {
        var rule = trie.Rule.init(self.allocator, sem_rule.pos);
        errdefer rule.deinit();

        rule.prio = sem_rule.prio;

        var vars = VarMap.init(self.allocator);
        defer vars.deinit();

        // Compile the pattern - this adds constraints to the rule
        const pattern_binding = try self.compilePattern(
            ruleset,
            &rule,
            &vars,
            sem_rule.pattern,
        );
        _ = pattern_binding;

        // Compile if-let guards
        for (sem_rule.iflets) |iflet| {
            _ = try self.compileIfLet(ruleset, &rule, &vars, iflet);
        }

        // Compile the result expression
        rule.result = try self.compileExpr(ruleset, &vars, sem_rule.expr);

        return rule;
    }

    fn bindVar(self: *Self, rule: *trie.Rule, vars: *VarMap, var_id: usize, id: trie.BindingId) !void {
        _ = self;
        const entry = try vars.getOrPut(var_id);
        if (entry.found_existing) {
            try rule.equals.merge(entry.value_ptr.*, id);
        } else {
            entry.value_ptr.* = id;
        }
    }

    /// Compile a pattern into bindings and constraints.
    fn compilePattern(
        self: *Self,
        ruleset: *trie.RuleSet,
        rule: *trie.Rule,
        vars: *VarMap,
        pattern: sema.Pattern,
    ) error{ OutOfMemory, ConflictingConstraints, UnsupportedExtractorPattern }!trie.BindingId {
        return switch (pattern) {
            .var_pat => |v| {
                // Variable pattern - no constraint, just bind
                // For root patterns, this should be the argument
                const binding = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(0) },
                };
                const source_id = try ruleset.internBinding(binding);
                try self.bindVar(rule, vars, v.var_id, source_id);
                return source_id;
            },
            .term => |t| {
                const source = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(0) },
                };
                const source_id = try ruleset.internBinding(source);
                return try self.compileTermPatternWithSource(ruleset, rule, vars, t, source_id);
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
                const binding = trie.Binding{ .const_prim = .{ .val = c.val, .ty = c.ty } };
                const binding_id = try ruleset.internBinding(binding);

                const source = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(0) },
                };
                const source_id = try ruleset.internBinding(source);
                const constraint = trie.Constraint{ .const_prim = .{ .val = c.val, .ty = c.ty } };
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
                const source = trie.Binding{
                    .argument = .{ .index = trie.TupleIndex.new(0) },
                };
                const source_id = try ruleset.internBinding(source);
                try self.bindVar(rule, vars, b.var_id, source_id);
                return try self.compilePatternWithSource(ruleset, rule, vars, b.subpat.*, source_id);
            },
            .and_pat => |a| {
                // And pattern - all subpatterns must match
                // Compile all subpatterns and merge their constraints
                var last_binding: ?trie.BindingId = null;
                for (a.subpats) |subpat| {
                    const binding = try self.compilePattern(ruleset, rule, vars, subpat);
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
        vars: *VarMap,
        iflet: sema.IfLet,
    ) !trie.BindingId {
        // Evaluate the RHS expression to get a binding
        const expr_binding = try self.compileExpr(ruleset, vars, iflet.expr);

        // Match the LHS pattern against the expression binding
        // This adds constraints that must succeed for the guard to pass
        return try self.compilePatternWithSource(ruleset, rule, vars, iflet.pattern, expr_binding);
    }

    /// Compile a pattern against a specific source binding (for if-let).
    fn compilePatternWithSource(
        self: *Self,
        ruleset: *trie.RuleSet,
        rule: *trie.Rule,
        vars: *VarMap,
        pattern: sema.Pattern,
        source_id: trie.BindingId,
    ) error{ OutOfMemory, ConflictingConstraints, UnsupportedExtractorPattern }!trie.BindingId {
        return self.compilePatternWithSourceArgs(ruleset, rule, vars, pattern, source_id, null);
    }

    fn compilePatternWithSourceArgs(
        self: *Self,
        ruleset: *trie.RuleSet,
        rule: *trie.Rule,
        vars: *VarMap,
        pattern: sema.Pattern,
        source_id: trie.BindingId,
        args: ?[]const sema.Pattern,
    ) error{ OutOfMemory, ConflictingConstraints, UnsupportedExtractorPattern }!trie.BindingId {
        return switch (pattern) {
            .var_pat => |v| {
                if (args) |arg_patterns| {
                    if (v.var_id < arg_patterns.len) {
                        return self.compilePatternWithSourceArgs(
                            ruleset,
                            rule,
                            vars,
                            arg_patterns[v.var_id],
                            source_id,
                            null,
                        );
                    }
                }
                try self.bindVar(rule, vars, v.var_id, source_id);
                return source_id;
            },
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
                    .const_prim = .{ .val = c.val, .ty = c.ty },
                };
                try rule.setConstraint(source_id, constraint);
                return source_id;
            },
            .bind_pattern => |b| {
                try self.bindVar(rule, vars, b.var_id, source_id);
                return try self.compilePatternWithSourceArgs(ruleset, rule, vars, b.subpat.*, source_id, args);
            },
            .and_pat => |a| {
                var last: trie.BindingId = source_id;
                for (a.subpats) |subpat| {
                    last = try self.compilePatternWithSourceArgs(ruleset, rule, vars, subpat, source_id, args);
                }
                return last;
            },
            .term => |t| {
                return try self.compileTermPatternWithSource(ruleset, rule, vars, t, source_id);
            },
        };
    }

    fn compileTermPatternWithSource(
        self: *Self,
        ruleset: *trie.RuleSet,
        rule: *trie.Rule,
        vars: *VarMap,
        term_pat: TermPattern,
        source_id: trie.BindingId,
    ) error{ OutOfMemory, ConflictingConstraints, UnsupportedExtractorPattern }!trie.BindingId {
        const term = self.termenv.getTerm(term_pat.term_id);
        if (self.termenv.getExtern(term_pat.term_id)) |ext| {
            if (ext.extractor != null) {
                return try self.compileExternExtractorPattern(ruleset, rule, vars, term_pat, source_id);
            }
        }

        switch (term.kind) {
            .decl => |decl| {
                const ret_ty = self.typeenv.getType(decl.ret_ty);
                if (ret_ty == .enum_type) {
                    const variant_id = self.findVariantForTerm(decl.ret_ty, term_pat.term_id);
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
                        if (term_pat.args.len != field_count) return error.ConflictingConstraints;

                        for (term_pat.args, 0..) |arg_pat, i| {
                            const field_binding = trie.Binding{
                                .match_variant = .{
                                    .source = source_id,
                                    .variant = vid,
                                    .field = trie.TupleIndex.new(@intCast(i)),
                                },
                            };
                            const field_id = try ruleset.internBinding(field_binding);
                            _ = try self.compilePatternWithSource(ruleset, rule, vars, arg_pat, field_id);
                        }
                    }
                }
                return source_id;
            },
            .extractor => |ext| {
                _ = try self.compilePatternWithSourceArgs(
                    ruleset,
                    rule,
                    vars,
                    ext.template,
                    source_id,
                    term_pat.args,
                );
                return source_id;
            },
            .extern_func => return error.UnsupportedExtractorPattern,
        }
    }

    fn compileExternExtractorPattern(
        self: *Self,
        ruleset: *trie.RuleSet,
        rule: *trie.Rule,
        vars: *VarMap,
        term_pat: TermPattern,
        source_id: trie.BindingId,
    ) error{ OutOfMemory, ConflictingConstraints, UnsupportedExtractorPattern }!trie.BindingId {
        const term = self.termenv.getTerm(term_pat.term_id);
        const decl = switch (term.kind) {
            .decl => |d| d,
            else => return error.UnsupportedExtractorPattern,
        };

        const params = try self.allocator.alloc(trie.BindingId, 1);
        params[0] = source_id;
        const binding = trie.Binding{
            .extractor = .{
                .term = term_pat.term_id,
                .parameters = params,
            },
        };
        const pre_len = ruleset.bindings.items.len;
        const extract_id = try ruleset.internBinding(binding);
        if (ruleset.bindings.items.len == pre_len) {
            self.allocator.free(params);
        }

        try rule.setConstraint(extract_id, .some);
        const some_binding = trie.Binding{
            .match_some = .{ .source = extract_id },
        };
        const some_id = try ruleset.internBinding(some_binding);

        if (term_pat.args.len == 0) {
            return some_id;
        }
        if (term_pat.args.len != decl.arg_tys.len) return error.ConflictingConstraints;
        if (decl.arg_tys.len == 1) {
            _ = try self.compilePatternWithSource(ruleset, rule, vars, term_pat.args[0], some_id);
            return some_id;
        }

        for (term_pat.args, 0..) |arg_pat, i| {
            const field_binding = trie.Binding{
                .match_extractor = .{
                    .source = some_id,
                    .field = trie.TupleIndex.new(@intCast(i)),
                },
            };
            const field_id = try ruleset.internBinding(field_binding);
            _ = try self.compilePatternWithSource(ruleset, rule, vars, arg_pat, field_id);
        }

        return some_id;
    }

    /// Compile an expression into a binding.
    fn compileExpr(
        self: *Self,
        ruleset: *trie.RuleSet,
        vars: *VarMap,
        expr: sema.Expr,
    ) !trie.BindingId {
        return switch (expr) {
            .var_expr => |v| {
                return vars.get(v.var_id) orelse return error.UnboundVariable;
            },
            .term => |t| {
                // Term construction - compile arguments and create constructor binding
                var arg_bindings = std.ArrayList(trie.BindingId){};
                defer arg_bindings.deinit(self.allocator);

                for (t.args) |arg| {
                    const binding = try self.compileExpr(ruleset, vars, arg);
                    try arg_bindings.append(self.allocator, binding);
                }

                // Enum variant construction: emit a make_variant binding instead of a
                // constructor call, so codegen can build the value directly.
                const term = self.termenv.getTerm(t.term_id);
                switch (term.kind) {
                    .decl => |decl| {
                        if (self.typeenv.getType(decl.ret_ty) == .enum_type) {
                            if (self.findVariantForTerm(decl.ret_ty, t.term_id)) |vid| {
                                const fields = try arg_bindings.toOwnedSlice(self.allocator);
                                const binding = trie.Binding{
                                    .make_variant = .{
                                        .ty = decl.ret_ty,
                                        .variant = vid,
                                        .fields = fields,
                                    },
                                };
                                const pre_len = ruleset.bindings.items.len;
                                const binding_id = try ruleset.internBinding(binding);
                                if (ruleset.bindings.items.len == pre_len) {
                                    self.allocator.free(fields);
                                }
                                return binding_id;
                            }
                        }
                    },
                    else => {},
                }

                const is_pure = switch (term.kind) {
                    .decl => |d| d.pure,
                    else => false,
                };

                const params = try arg_bindings.toOwnedSlice(self.allocator);
                const binding = trie.Binding{
                    .constructor = .{
                        .term = t.term_id,
                        .parameters = params,
                        .instance = if (is_pure) 0 else blk: {
                            const instance = self.next_impure_instance;
                            self.next_impure_instance += 1;
                            break :blk instance;
                        },
                    },
                };
                const pre_len = ruleset.bindings.items.len;
                const binding_id = try ruleset.internBinding(binding);
                if (ruleset.bindings.items.len == pre_len) {
                    self.allocator.free(params);
                }
                return binding_id;
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
                const binding = trie.Binding{ .const_prim = .{ .val = c.val, .ty = c.ty } };
                return try ruleset.internBinding(binding);
            },
            .let_expr => |l| {
                // Let expression - compile bindings and body
                var scoped = VarMap.init(self.allocator);
                defer scoped.deinit();

                var it = vars.iterator();
                while (it.next()) |entry| {
                    try scoped.put(entry.key_ptr.*, entry.value_ptr.*);
                }

                for (l.bindings) |let_binding| {
                    const binding_id = try self.compileExpr(ruleset, &scoped, let_binding.val);
                    try scoped.put(let_binding.var_id, binding_id);
                }

                return try self.compileExpr(ruleset, &scoped, l.body.*);
            },
        };
    }

    /// Find the variant ID for a constructor term.
    fn findVariantForTerm(self: *const Self, type_id: sema.TypeId, term_id: sema.TermId) ?sema.VariantId {
        const ty = self.typeenv.getType(type_id);
        if (ty != .enum_type) return null;

        const term = self.termenv.getTerm(term_id);
        const term_name = term.name;

        // Fast path: qualified variant constructor terms (Type.Variant).
        if (self.typeenv.const_variants.get(term_name)) |vid| {
            if (vid.type_id.index() == type_id.index()) return vid;
        }

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
    var typeenv = try sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    const compiler = MatchCompiler.init(testing.allocator, &typeenv, &termenv);
    _ = compiler;
}

test "MatchCompiler: simple constant pattern" {
    var typeenv = try sema.TypeEnv.init(testing.allocator);
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

    var ruleset = trie.RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    var rule = try compiler.compileRule(&ruleset, sem_rule);
    defer rule.deinit();

    // Verify the rule has a constraint
    try testing.expect(rule.totalConstraints() > 0);
}

test "MatchCompiler: variant field patterns" {
    var typeenv = try sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    var compiler = MatchCompiler.init(testing.allocator, &typeenv, &termenv);

    const i32_sym = try typeenv.internSym("i32");
    const i32_ty = typeenv.lookupType(i32_sym) orelse return error.UndefinedType;

    const pair_sym = try typeenv.internSym("Pair");
    const field_a = try typeenv.internSym("a");
    const field_b = try typeenv.internSym("b");

    const fields = try testing.allocator.dupe(sema.Field, &[_]sema.Field{
        .{ .name = field_a, .ty = i32_ty },
        .{ .name = field_b, .ty = i32_ty },
    });
    defer testing.allocator.free(fields);

    const variants = try testing.allocator.dupe(sema.Variant, &[_]sema.Variant{
        .{ .name = pair_sym, .fields = fields },
    });
    defer testing.allocator.free(variants);

    const enum_ty = try typeenv.addType(.{ .enum_type = .{
        .name = pair_sym,
        .id = sema.TypeId.new(1),
        .is_extern = false,
        .variants = variants,
        .pos = sema.Pos.new(0, 0),
    } });

    const term = sema.Term{
        .name = pair_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .decl = .{
            .arg_tys = @constCast(&[_]sema.TypeId{ i32_ty, i32_ty }),
            .ret_ty = enum_ty,
            .pure = true,
            .partial = false,
        } },
        .pos = sema.Pos.new(0, 0),
    };
    const term_id = try termenv.addTerm(term);

    const pattern = sema.Pattern{
        .term = .{
            .term_id = term_id,
            .args = @constCast(&[_]sema.Pattern{
                .{ .const_int = .{ .val = 1, .ty = i32_ty, .pos = sema.Pos.new(0, 0) } },
                .{ .const_int = .{ .val = 2, .ty = i32_ty, .pos = sema.Pos.new(0, 0) } },
            }),
            .ty = enum_ty,
            .pos = sema.Pos.new(0, 0),
        },
    };

    var ruleset = trie.RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    var rule = trie.Rule.init(testing.allocator, sema.Pos.new(0, 0));
    defer rule.deinit();

    const source_id = try compiler.compilePattern(&ruleset, &rule, pattern);
    const variant_id = sema.VariantId.new(enum_ty, 0);

    if (rule.getConstraint(source_id)) |source_constraint| {
        switch (source_constraint) {
            .variant => |v| {
                try testing.expectEqual(variant_id.variant_index, v.variant.variant_index);
                try testing.expectEqual(@intFromEnum(enum_ty), @intFromEnum(v.variant.type_id));
                try testing.expectEqual(@as(usize, 2), v.field_count.value());
            },
            else => try testing.expect(false),
        }
    } else {
        try testing.expect(false);
    }

    const field0_id = ruleset.findBinding(&.{
        .match_variant = .{
            .source = source_id,
            .variant = variant_id,
            .field = trie.TupleIndex.new(0),
        },
    }) orelse {
        try testing.expect(false);
        return;
    };
    const field1_id = ruleset.findBinding(&.{
        .match_variant = .{
            .source = source_id,
            .variant = variant_id,
            .field = trie.TupleIndex.new(1),
        },
    }) orelse {
        try testing.expect(false);
        return;
    };

    if (rule.getConstraint(field0_id)) |field0_constraint| {
        switch (field0_constraint) {
            .const_int => |c| try testing.expectEqual(@as(i128, 1), c.val),
            else => try testing.expect(false),
        }
    } else {
        try testing.expect(false);
    }
    if (rule.getConstraint(field1_id)) |field1_constraint| {
        switch (field1_constraint) {
            .const_int => |c| try testing.expectEqual(@as(i128, 2), c.val),
            else => try testing.expect(false),
        }
    } else {
        try testing.expect(false);
    }
}

test "MatchCompiler: extractor patterns" {
    var typeenv = try sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    var compiler = MatchCompiler.init(testing.allocator, &typeenv, &termenv);

    const i32_sym = try typeenv.internSym("i32");
    const i32_ty = typeenv.lookupType(i32_sym) orelse return error.UndefinedType;

    const ext_sym = try typeenv.internSym("Id");
    const arg_sym = try typeenv.internSym("x");

    const template = sema.Pattern{
        .var_pat = .{
            .var_id = 0,
            .name = arg_sym,
            .ty = i32_ty,
            .pos = sema.Pos.new(0, 0),
        },
    };

    const term = sema.Term{
        .name = ext_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .extractor = .{
            .arg_tys = @constCast(&[_]sema.TypeId{ i32_ty }),
            .ret_ty = i32_ty,
            .template = template,
        } },
        .pos = sema.Pos.new(0, 0),
    };
    const term_id = try termenv.addTerm(term);

    const pattern = sema.Pattern{
        .term = .{
            .term_id = term_id,
            .args = @constCast(&[_]sema.Pattern{
                .{ .const_int = .{ .val = 7, .ty = i32_ty, .pos = sema.Pos.new(0, 0) } },
            }),
            .ty = i32_ty,
            .pos = sema.Pos.new(0, 0),
        },
    };

    var ruleset = trie.RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    var rule = trie.Rule.init(testing.allocator, sema.Pos.new(0, 0));
    defer rule.deinit();

    const source_id = try compiler.compilePattern(&ruleset, &rule, pattern);

    if (rule.getConstraint(source_id)) |source_constraint| {
        switch (source_constraint) {
            .const_int => |c| try testing.expectEqual(@as(i128, 7), c.val),
            else => try testing.expect(false),
        }
    } else {
        try testing.expect(false);
    }
}

test "MatchCompiler: build decision tree" {
    var typeenv = try sema.TypeEnv.init(testing.allocator);
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
    var typeenv = try sema.TypeEnv.init(testing.allocator);
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

    var ruleset = trie.RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    var rule = try compiler.compileRule(&ruleset, sem_rule);
    defer rule.deinit();

    // Wildcard should have no constraints
    try testing.expectEqual(@as(usize, 0), rule.totalConstraints());
}

test "MatchCompiler: impure constructor instances are unique" {
    var typeenv = try sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    const i32_sym = try typeenv.internSym("i32");
    const i32_ty = typeenv.lookupType(i32_sym) orelse return error.UndefinedType;

    const term_sym = try typeenv.internSym("impure_term");
    const arg_tys = try testing.allocator.alloc(sema.TypeId, 0);
    defer testing.allocator.free(arg_tys);

    const term = sema.Term{
        .name = term_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .decl = .{
            .arg_tys = arg_tys,
            .ret_ty = i32_ty,
            .pure = false,
            .partial = false,
        } },
        .pos = sema.Pos.new(0, 0),
    };
    _ = try termenv.addTerm(term);

    var compiler = MatchCompiler.init(testing.allocator, &typeenv, &termenv);
    compiler.next_impure_instance = 1;

    var ruleset = trie.RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    const expr = sema.Expr{ .term = .{
        .term_id = sema.TermId.new(0),
        .args = &.{},
        .ty = i32_ty,
        .pos = sema.Pos.new(0, 0),
    } };

    const id1 = try compiler.compileExpr(&ruleset, expr);
    const id2 = try compiler.compileExpr(&ruleset, expr);
    try testing.expect(!std.meta.eql(id1, id2));
}
