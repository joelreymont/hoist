const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const sema = @import("sema.zig");
const ast = @import("ast.zig");

const TypeId = sema.TypeId;
const TermId = sema.TermId;
const Sym = sema.Sym;
const Pattern = sema.Pattern;
const Expr = sema.Expr;
const TypeEnv = sema.TypeEnv;
const TermEnv = sema.TermEnv;
const Term = sema.Term;
const TermKind = sema.TermKind;
const BoundVar = sema.BoundVar;
const Pos = sema.Pos;

/// Binding environment for pattern variables during evaluation.
pub const BindingEnv = struct {
    /// Map from variable ID to bound value (generic).
    bindings: std.AutoHashMap(usize, BindingValue),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .bindings = std.AutoHashMap(usize, BindingValue).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.bindings.deinit();
    }

    /// Bind a variable to a value.
    pub fn bind(self: *Self, var_id: usize, value: BindingValue) !void {
        try self.bindings.put(var_id, value);
    }

    /// Lookup a variable binding.
    pub fn lookup(self: *const Self, var_id: usize) ?BindingValue {
        return self.bindings.get(var_id);
    }

    /// Check if variable is bound.
    pub fn isBound(self: *const Self, var_id: usize) bool {
        return self.bindings.contains(var_id);
    }

    /// Create a clone of this environment for nested matching.
    pub fn clone(self: *const Self) !Self {
        var new_env = Self.init(self.allocator);
        var it = self.bindings.iterator();
        while (it.next()) |entry| {
            try new_env.bindings.put(entry.key_ptr.*, entry.value_ptr.*);
        }
        return new_env;
    }
};

/// Generic value that can be bound to a pattern variable.
/// In real usage, this would be specialized to the actual value type (e.g., IR values).
pub const BindingValue = union(enum) {
    /// Generic value reference (placeholder).
    value_ref: usize,
    /// Integer constant.
    int: i128,
    /// Boolean constant.
    boolean: bool,
    /// Symbol/identifier.
    sym: Sym,

    pub fn eql(self: BindingValue, other: BindingValue) bool {
        return switch (self) {
            .value_ref => |v| if (other == .value_ref) v == other.value_ref else false,
            .int => |v| if (other == .int) v == other.int else false,
            .boolean => |v| if (other == .boolean) v == other.boolean else false,
            .sym => |v| if (other == .sym) v.index() == other.sym.index() else false,
        };
    }
};

/// Result of pattern evaluation - success with bindings or failure.
pub const MatchResult = union(enum) {
    success: void,
    failure: void,

    pub fn isSuccess(self: MatchResult) bool {
        return self == .success;
    }

    pub fn isFailure(self: MatchResult) bool {
        return self == .failure;
    }
};

/// Extractor evaluator - expands and evaluates extractor patterns.
pub const Evaluator = struct {
    type_env: *const TypeEnv,
    term_env: *const TermEnv,
    allocator: Allocator,

    const Self = @This();

    pub fn init(
        type_env: *const TypeEnv,
        term_env: *const TermEnv,
        allocator: Allocator,
    ) Self {
        return .{
            .type_env = type_env,
            .term_env = term_env,
            .allocator = allocator,
        };
    }

    /// Expand an extractor pattern by substituting arguments into its template.
    /// This is the core of extractor evaluation - when we encounter an extractor
    /// in a pattern, we substitute the actual argument patterns into the template.
    pub fn expandExtractor(
        self: *Self,
        term_id: TermId,
        arg_patterns: []const Pattern,
    ) !Pattern {
        const term = self.term_env.getTerm(term_id);

        return switch (term.kind) {
            .extractor => |ext| blk: {
                // Substitute argument patterns into the template
                const expanded = try self.substituteTemplate(
                    ext.template,
                    arg_patterns,
                );
                break :blk expanded;
            },
            else => error.NotAnExtractor,
        };
    }

    /// Recursively substitute macro arguments into a pattern template.
    /// This transforms a pattern like (Add $x $y) where $x and $y are macro args
    /// into the actual patterns provided as arguments.
    fn substituteTemplate(
        self: *Self,
        template: Pattern,
        args: []const Pattern,
    ) !Pattern {
        return switch (template) {
            .var_pat => |v| {
                // Check if this variable is a macro argument
                // For now, we use a simple index-based substitution
                // In a real implementation, we'd track which vars are macro args
                if (v.var_id < args.len) {
                    // This is a macro argument reference - substitute it
                    return args[v.var_id];
                } else {
                    // Regular variable binding - keep as is
                    return template;
                }
            },
            .bind_pattern => |b| {
                // Recursively substitute in subpattern
                const subpat = try self.allocator.create(Pattern);
                subpat.* = try self.substituteTemplate(b.subpat.*, args);

                return Pattern{
                    .bind_pattern = .{
                        .var_id = b.var_id,
                        .name = b.name,
                        .subpat = subpat,
                        .ty = b.ty,
                        .pos = b.pos,
                    },
                };
            },
            .term => |t| {
                // Recursively substitute in all argument patterns
                var substituted_args = std.ArrayList(Pattern){};
                defer substituted_args.deinit(self.allocator);

                for (t.args) |arg| {
                    const subst = try self.substituteTemplate(arg, args);
                    try substituted_args.append(self.allocator, subst);
                }

                return Pattern{
                    .term = .{
                        .term_id = t.term_id,
                        .args = try substituted_args.toOwnedSlice(self.allocator),
                        .ty = t.ty,
                        .pos = t.pos,
                    },
                };
            },
            .and_pat => |a| {
                // Recursively substitute in all subpatterns
                var substituted_subpats = std.ArrayList(Pattern){};
                defer substituted_subpats.deinit(self.allocator);

                for (a.subpats) |subpat| {
                    const subst = try self.substituteTemplate(subpat, args);
                    try substituted_subpats.append(self.allocator, subst);
                }

                return Pattern{
                    .and_pat = .{
                        .subpats = try substituted_subpats.toOwnedSlice(self.allocator),
                        .ty = a.ty,
                        .pos = a.pos,
                    },
                };
            },
            // Constants and wildcards don't need substitution
            .const_bool, .const_int, .const_prim, .wildcard => template,
        };
    }

    /// Match a pattern against a value, collecting bindings.
    /// This is a generic matcher that can be specialized for different value types.
    pub fn matchPattern(
        self: *Self,
        pattern: Pattern,
        value: BindingValue,
        env: *BindingEnv,
    ) !MatchResult {
        return switch (pattern) {
            .var_pat => |v| {
                // Variable pattern - either bind or check equality
                if (env.lookup(v.var_id)) |bound_value| {
                    // Variable already bound - check if values match
                    if (bound_value.eql(value)) {
                        return .success;
                    } else {
                        return .failure;
                    }
                } else {
                    // First binding of this variable
                    try env.bind(v.var_id, value);
                    return .success;
                }
            },
            .bind_pattern => |b| {
                // Bind the variable and match the subpattern
                try env.bind(b.var_id, value);
                return try self.matchPattern(b.subpat.*, value, env);
            },
            .const_bool => |c| {
                // Match boolean constant
                if (value == .boolean and value.boolean == c.val) {
                    return .success;
                } else {
                    return .failure;
                }
            },
            .const_int => |c| {
                // Match integer constant
                if (value == .int and value.int == c.val) {
                    return .success;
                } else {
                    return .failure;
                }
            },
            .const_prim => |c| {
                // Match primitive constant
                if (value == .sym and value.sym.index() == c.val.index()) {
                    return .success;
                } else {
                    return .failure;
                }
            },
            .term => |t| {
                // Term pattern - dispatch based on term kind
                const term = self.term_env.getTerm(t.term_id);

                return switch (term.kind) {
                    .extractor => blk: {
                        // Extractor needs to be expanded first
                        const expanded = try self.expandExtractor(t.term_id, t.args);
                        break :blk try self.matchPattern(expanded, value, env);
                    },
                    .decl => |d| {
                        // Constructor pattern - would extract fields from value
                        // For now, return success as this is a placeholder
                        _ = d;
                        return .success;
                    },
                    .extern_func => {
                        // External extractors delegate to external code
                        // For now, return success as this is a placeholder
                        return .success;
                    },
                };
            },
            .wildcard => {
                // Wildcard always matches
                return .success;
            },
            .and_pat => |a| {
                // And pattern - all subpatterns must match
                for (a.subpats) |subpat| {
                    const result = try self.matchPattern(subpat, value, env);
                    if (result.isFailure()) {
                        return .failure;
                    }
                }
                return .success;
            },
        };
    }

    /// Extract field from a composite value.
    /// This would be specialized for the actual value representation.
    pub fn extractField(
        self: *Self,
        value: BindingValue,
        field_index: usize,
    ) !BindingValue {
        _ = self;
        _ = value;
        _ = field_index;
        // Placeholder - would extract field from composite value
        return BindingValue{ .value_ref = 0 };
    }

    /// Check if a term is an extractor.
    pub fn isExtractor(self: *const Self, term_id: TermId) bool {
        const term = self.term_env.getTerm(term_id);
        return term.kind == .extractor;
    }

    /// Get extractor argument types.
    pub fn extractorArgTypes(self: *const Self, term_id: TermId) ![]const TypeId {
        const term = self.term_env.getTerm(term_id);
        return switch (term.kind) {
            .extractor => |ext| ext.arg_tys,
            else => error.NotAnExtractor,
        };
    }

    /// Get extractor return type.
    pub fn extractorReturnType(self: *const Self, term_id: TermId) !TypeId {
        const term = self.term_env.getTerm(term_id);
        return switch (term.kind) {
            .extractor => |ext| ext.ret_ty,
            else => error.NotAnExtractor,
        };
    }
};

// ========================================================================
// Tests
// ========================================================================

test "BindingEnv basic operations" {
    var env = BindingEnv.init(testing.allocator);
    defer env.deinit();

    const val1 = BindingValue{ .int = 42 };
    const val2 = BindingValue{ .boolean = true };

    try env.bind(0, val1);
    try env.bind(1, val2);

    const lookup1 = env.lookup(0);
    const lookup2 = env.lookup(1);
    const lookup3 = env.lookup(2);

    try testing.expect(lookup1 != null);
    try testing.expect(lookup2 != null);
    try testing.expect(lookup3 == null);

    try testing.expect(lookup1.?.eql(val1));
    try testing.expect(lookup2.?.eql(val2));
}

test "BindingValue equality" {
    const v1 = BindingValue{ .int = 42 };
    const v2 = BindingValue{ .int = 42 };
    const v3 = BindingValue{ .int = 43 };
    const v4 = BindingValue{ .boolean = true };

    try testing.expect(v1.eql(v2));
    try testing.expect(!v1.eql(v3));
    try testing.expect(!v1.eql(v4));
}

test "Evaluator match wildcard" {
    var type_env = TypeEnv.init(testing.allocator);
    defer type_env.deinit();

    var term_env = TermEnv.init(testing.allocator);
    defer term_env.deinit();

    var eval = Evaluator.init(&type_env, &term_env, testing.allocator);

    var env = BindingEnv.init(testing.allocator);
    defer env.deinit();

    const pattern = Pattern{
        .wildcard = .{
            .ty = TypeId.new(0),
            .pos = Pos.new(0, 0),
        },
    };

    const value = BindingValue{ .int = 42 };
    const result = try eval.matchPattern(pattern, value, &env);

    try testing.expect(result.isSuccess());
}

test "Evaluator match variable binding" {
    var type_env = TypeEnv.init(testing.allocator);
    defer type_env.deinit();

    var term_env = TermEnv.init(testing.allocator);
    defer term_env.deinit();

    var eval = Evaluator.init(&type_env, &term_env, testing.allocator);

    var env = BindingEnv.init(testing.allocator);
    defer env.deinit();

    const pattern = Pattern{
        .var_pat = .{
            .var_id = 0,
            .name = Sym.new(0),
            .ty = TypeId.new(0),
            .pos = Pos.new(0, 0),
        },
    };

    const value = BindingValue{ .int = 42 };
    const result = try eval.matchPattern(pattern, value, &env);

    try testing.expect(result.isSuccess());
    const bound = env.lookup(0);
    try testing.expect(bound != null);
    try testing.expect(bound.?.eql(value));
}

test "Evaluator match variable equality check" {
    var type_env = TypeEnv.init(testing.allocator);
    defer type_env.deinit();

    var term_env = TermEnv.init(testing.allocator);
    defer term_env.deinit();

    var eval = Evaluator.init(&type_env, &term_env, testing.allocator);

    var env = BindingEnv.init(testing.allocator);
    defer env.deinit();

    const pattern = Pattern{
        .var_pat = .{
            .var_id = 0,
            .name = Sym.new(0),
            .ty = TypeId.new(0),
            .pos = Pos.new(0, 0),
        },
    };

    // Bind variable to 42
    try env.bind(0, BindingValue{ .int = 42 });

    // Try to match against same value - should succeed
    const result1 = try eval.matchPattern(pattern, BindingValue{ .int = 42 }, &env);
    try testing.expect(result1.isSuccess());

    // Try to match against different value - should fail
    const result2 = try eval.matchPattern(pattern, BindingValue{ .int = 43 }, &env);
    try testing.expect(result2.isFailure());
}

test "Evaluator match const_bool" {
    var type_env = TypeEnv.init(testing.allocator);
    defer type_env.deinit();

    var term_env = TermEnv.init(testing.allocator);
    defer term_env.deinit();

    var eval = Evaluator.init(&type_env, &term_env, testing.allocator);

    var env = BindingEnv.init(testing.allocator);
    defer env.deinit();

    const pattern = Pattern{
        .const_bool = .{
            .val = true,
            .pos = Pos.new(0, 0),
        },
    };

    // Match against true - should succeed
    const result1 = try eval.matchPattern(pattern, BindingValue{ .boolean = true }, &env);
    try testing.expect(result1.isSuccess());

    // Match against false - should fail
    const result2 = try eval.matchPattern(pattern, BindingValue{ .boolean = false }, &env);
    try testing.expect(result2.isFailure());

    // Match against non-bool - should fail
    const result3 = try eval.matchPattern(pattern, BindingValue{ .int = 1 }, &env);
    try testing.expect(result3.isFailure());
}

test "Evaluator match const_int" {
    var type_env = TypeEnv.init(testing.allocator);
    defer type_env.deinit();

    var term_env = TermEnv.init(testing.allocator);
    defer term_env.deinit();

    var eval = Evaluator.init(&type_env, &term_env, testing.allocator);

    var env = BindingEnv.init(testing.allocator);
    defer env.deinit();

    const pattern = Pattern{
        .const_int = .{
            .val = 42,
            .ty = TypeId.new(0),
            .pos = Pos.new(0, 0),
        },
    };

    // Match against 42 - should succeed
    const result1 = try eval.matchPattern(pattern, BindingValue{ .int = 42 }, &env);
    try testing.expect(result1.isSuccess());

    // Match against 43 - should fail
    const result2 = try eval.matchPattern(pattern, BindingValue{ .int = 43 }, &env);
    try testing.expect(result2.isFailure());
}

test "Evaluator match and pattern" {
    var type_env = TypeEnv.init(testing.allocator);
    defer type_env.deinit();

    var term_env = TermEnv.init(testing.allocator);
    defer term_env.deinit();

    var eval = Evaluator.init(&type_env, &term_env, testing.allocator);

    var env = BindingEnv.init(testing.allocator);
    defer env.deinit();

    // Create an and pattern with two subpatterns: wildcard and const_int(42)
    const subpats = try testing.allocator.alloc(Pattern, 2);
    defer testing.allocator.free(subpats);

    subpats[0] = Pattern{
        .wildcard = .{
            .ty = TypeId.new(0),
            .pos = Pos.new(0, 0),
        },
    };
    subpats[1] = Pattern{
        .const_int = .{
            .val = 42,
            .ty = TypeId.new(0),
            .pos = Pos.new(0, 0),
        },
    };

    const pattern = Pattern{
        .and_pat = .{
            .subpats = subpats,
            .ty = TypeId.new(0),
            .pos = Pos.new(0, 0),
        },
    };

    // Match against 42 - should succeed (both subpatterns match)
    const result1 = try eval.matchPattern(pattern, BindingValue{ .int = 42 }, &env);
    try testing.expect(result1.isSuccess());

    // Match against 43 - should fail (second subpattern fails)
    const result2 = try eval.matchPattern(pattern, BindingValue{ .int = 43 }, &env);
    try testing.expect(result2.isFailure());
}

test "BindingEnv clone" {
    var env1 = BindingEnv.init(testing.allocator);
    defer env1.deinit();

    try env1.bind(0, BindingValue{ .int = 42 });
    try env1.bind(1, BindingValue{ .boolean = true });

    var env2 = try env1.clone();
    defer env2.deinit();

    // env2 should have same bindings
    const lookup1 = env2.lookup(0);
    const lookup2 = env2.lookup(1);

    try testing.expect(lookup1 != null);
    try testing.expect(lookup2 != null);
    try testing.expect(lookup1.?.eql(BindingValue{ .int = 42 }));
    try testing.expect(lookup2.?.eql(BindingValue{ .boolean = true }));

    // Modifying env2 should not affect env1
    try env2.bind(0, BindingValue{ .int = 100 });
    const original = env1.lookup(0);
    try testing.expect(original.?.eql(BindingValue{ .int = 42 }));
}
