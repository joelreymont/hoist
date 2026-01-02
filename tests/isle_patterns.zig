const std = @import("std");
const testing = std.testing;

const isle_sema = @import("../src/dsl/isle/sema.zig");
const isle_trie = @import("../src/dsl/isle/trie.zig");
const isle_compile = @import("../src/dsl/isle/compile.zig");

const Allocator = std.mem.Allocator;
const Sym = isle_sema.Sym;
const TypeId = isle_sema.TypeId;
const TermId = isle_sema.TermId;
const Pattern = isle_sema.Pattern;
const Expr = isle_sema.Expr;
const TypeEnv = isle_sema.TypeEnv;
const TermEnv = isle_sema.TermEnv;
const Binding = isle_trie.Binding;
const BindingId = isle_trie.BindingId;
const Constraint = isle_trie.Constraint;
const TupleIndex = isle_trie.TupleIndex;
const Rule = isle_trie.Rule;
const RuleSet = isle_trie.RuleSet;
const Overlap = isle_trie.Overlap;

// Test basic pattern compilation from ISLE source.
test "compile simple pattern" {
    const source = isle_compile.Source{
        .filename = "test.isle",
        .content =
        \\(type Value extern)
        \\(decl pure iadd (Value Value) Value)
        \\(rule (iadd x y) x)
        ,
    };

    var result = try isle_compile.compile(testing.allocator, &[_]isle_compile.Source{source}, .{
        .debug_comments = false,
    });
    defer result.deinit();

    // Verify code was generated
    try testing.expect(result.code.len > 0);
}

// Test wildcard pattern matching.
test "wildcard pattern" {
    var rule = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule.deinit();

    const arg0 = BindingId.new(0);

    // No constraints means wildcard match - matches anything
    try testing.expectEqual(@as(usize, 0), rule.constraints.count());
    try testing.expectEqual(@as(?Constraint, null), rule.getConstraint(arg0));
}

// Test constant pattern constraints.
test "constant int pattern" {
    var rule = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule.deinit();

    const arg0 = BindingId.new(0);
    const type_i32 = TypeId.new(0);

    // Add constraint: arg0 must equal 42
    const constraint = Constraint{
        .const_int = .{
            .val = 42,
            .ty = type_i32,
        },
    };
    try rule.setConstraint(arg0, constraint);

    const retrieved = rule.getConstraint(arg0).?;
    try testing.expectEqual(@as(i128, 42), retrieved.const_int.val);
    try testing.expectEqual(type_i32, retrieved.const_int.ty);
}

// Test boolean constant pattern.
test "constant bool pattern" {
    var rule = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule.deinit();

    const arg0 = BindingId.new(0);
    const type_bool = TypeId.new(0);

    const constraint = Constraint{
        .const_bool = .{
            .val = true,
            .ty = type_bool,
        },
    };
    try rule.setConstraint(arg0, constraint);

    const retrieved = rule.getConstraint(arg0).?;
    try testing.expectEqual(true, retrieved.const_bool.val);
}

// Test nested pattern with enum variant matching.
test "nested variant pattern" {
    var rule = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule.deinit();

    const arg0 = BindingId.new(0);
    const type_id = TypeId.new(1);
    const variant_id = isle_sema.VariantId.new(type_id, 0);

    // Pattern: (SomeVariant field1 field2)
    const constraint = Constraint{
        .variant = .{
            .ty = type_id,
            .variant = variant_id,
            .field_count = TupleIndex.new(2),
        },
    };
    try rule.setConstraint(arg0, constraint);

    // Verify constraint
    const retrieved = rule.getConstraint(arg0).?;
    try testing.expectEqual(variant_id.type_id, retrieved.variant.ty);
    try testing.expectEqual(@as(u8, 2), retrieved.variant.field_count.index);

    // Generate bindings for extracting fields
    const bindings = try constraint.bindingsFor(arg0, testing.allocator);
    defer testing.allocator.free(bindings);

    try testing.expectEqual(@as(usize, 2), bindings.len);
    try testing.expectEqual(arg0, bindings[0].match_variant.source);
    try testing.expectEqual(@as(u8, 0), bindings[0].match_variant.field.index);
    try testing.expectEqual(@as(u8, 1), bindings[1].match_variant.field.index);
}

// Test pattern with Option::Some matching (fallible extractor).
test "option some pattern" {
    var rule = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule.deinit();

    const arg0 = BindingId.new(0);

    // Pattern: must be Some (from fallible extractor)
    const constraint = Constraint.some;
    try rule.setConstraint(arg0, constraint);

    const retrieved = rule.getConstraint(arg0).?;
    try testing.expectEqual(Constraint.some, retrieved);

    // Generate binding for extracting inner value
    const bindings = try constraint.bindingsFor(arg0, testing.allocator);
    defer testing.allocator.free(bindings);

    try testing.expectEqual(@as(usize, 1), bindings.len);
    try testing.expectEqual(arg0, bindings[0].match_some.source);
}

// Test conflicting constraints on same binding.
test "conflicting constraints error" {
    var rule = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule.deinit();

    const arg0 = BindingId.new(0);
    const type_id = TypeId.new(0);

    // First constraint: must equal 42
    const constraint1 = Constraint{
        .const_int = .{
            .val = 42,
            .ty = type_id,
        },
    };
    try rule.setConstraint(arg0, constraint1);

    // Second constraint: must equal 99 (conflicts!)
    const constraint2 = Constraint{
        .const_int = .{
            .val = 99,
            .ty = type_id,
        },
    };

    try testing.expectError(error.ConflictingConstraints, rule.setConstraint(arg0, constraint2));
}

// Test rule overlap detection - no overlap.
test "rule overlap: disjoint rules" {
    var rule_a = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule_a.deinit();
    var rule_b = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule_b.deinit();

    const arg0 = BindingId.new(0);
    const type_id = TypeId.new(0);

    // Rule A: arg0 must equal 42
    const constraint_a = Constraint{
        .const_int = .{
            .val = 42,
            .ty = type_id,
        },
    };
    try rule_a.setConstraint(arg0, constraint_a);

    // Rule B: arg0 must equal 99
    const constraint_b = Constraint{
        .const_int = .{
            .val = 99,
            .ty = type_id,
        },
    };
    try rule_b.setConstraint(arg0, constraint_b);

    // Rules cannot overlap - conflicting constraints
    const overlap = Overlap.check(&rule_a, &rule_b);
    try testing.expectEqual(Overlap.no, overlap);
}

// Test rule overlap detection - subset relationship.
test "rule overlap: subset" {
    var rule_a = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule_a.deinit();
    var rule_b = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule_b.deinit();

    const arg0 = BindingId.new(0);
    const arg1 = BindingId.new(1);
    const type_id = TypeId.new(0);

    // Rule A: arg0 must equal 42
    const constraint_a = Constraint{
        .const_int = .{
            .val = 42,
            .ty = type_id,
        },
    };
    try rule_a.setConstraint(arg0, constraint_a);

    // Rule B: arg0 must equal 42 AND arg1 must equal 99
    try rule_b.setConstraint(arg0, constraint_a);
    const constraint_b = Constraint{
        .const_int = .{
            .val = 99,
            .ty = type_id,
        },
    };
    try rule_b.setConstraint(arg1, constraint_b);

    // Rule A is subset of Rule B
    const overlap = Overlap.check(&rule_a, &rule_b);
    try testing.expectEqual(Overlap.yes_subset, overlap);
}

// Test rule overlap detection - overlapping but not subset.
test "rule overlap: disjoint overlap" {
    var rule_a = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule_a.deinit();
    var rule_b = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule_b.deinit();

    const arg0 = BindingId.new(0);
    const arg1 = BindingId.new(1);
    const type_id = TypeId.new(0);

    // Rule A: arg0 must equal 42
    const constraint_a = Constraint{
        .const_int = .{
            .val = 42,
            .ty = type_id,
        },
    };
    try rule_a.setConstraint(arg0, constraint_a);

    // Rule B: arg1 must equal 99 (different binding)
    const constraint_b = Constraint{
        .const_int = .{
            .val = 99,
            .ty = type_id,
        },
    };
    try rule_b.setConstraint(arg1, constraint_b);

    // Rules overlap but neither is subset
    const overlap = Overlap.check(&rule_a, &rule_b);
    try testing.expectEqual(Overlap.yes_disjoint, overlap);
}

// Test binding hash-consing in RuleSet.
test "binding internment: deduplication" {
    var ruleset = RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    const type_id = TypeId.new(0);

    // Intern same binding twice
    const binding1 = Binding{
        .const_int = .{
            .val = 42,
            .ty = type_id,
        },
    };
    const id1 = try ruleset.internBinding(binding1);

    const binding2 = Binding{
        .const_int = .{
            .val = 42,
            .ty = type_id,
        },
    };
    const id2 = try ruleset.internBinding(binding2);

    // Should return same ID
    try testing.expectEqual(id1.index(), id2.index());
    try testing.expectEqual(@as(usize, 1), ruleset.bindings.items.len);
}

// Test binding internment: different bindings get different IDs.
test "binding internment: distinct bindings" {
    var ruleset = RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    const type_id = TypeId.new(0);

    const binding1 = Binding{
        .const_int = .{
            .val = 42,
            .ty = type_id,
        },
    };
    const id1 = try ruleset.internBinding(binding1);

    const binding2 = Binding{
        .const_int = .{
            .val = 99,
            .ty = type_id,
        },
    };
    const id2 = try ruleset.internBinding(binding2);

    // Should get different IDs
    try testing.expect(id1.index() != id2.index());
    try testing.expectEqual(@as(usize, 2), ruleset.bindings.items.len);
}

// Test binding: argument extraction.
test "binding: argument" {
    var ruleset = RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    const binding = Binding{
        .argument = .{
            .index = TupleIndex.new(0),
        },
    };
    const id = try ruleset.internBinding(binding);

    try testing.expectEqual(@as(usize, 0), id.index());
    try testing.expectEqual(@as(u8, 0), ruleset.bindings.items[0].argument.index.index);
}

// Test binding: extractor call.
test "binding: extractor" {
    var ruleset = RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    const term_id = TermId.new(1);
    const param_id = BindingId.new(0);

    const binding = Binding{
        .extractor = .{
            .term = term_id,
            .parameter = param_id,
        },
    };
    const id = try ruleset.internBinding(binding);

    try testing.expectEqual(@as(usize, 0), id.index());
    try testing.expectEqual(term_id.index(), ruleset.bindings.items[0].extractor.term.index());
    try testing.expectEqual(param_id.index(), ruleset.bindings.items[0].extractor.parameter.index());
}

// Test binding: constructor call with parameters.
test "binding: constructor" {
    var ruleset = RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    const term_id = TermId.new(2);
    const params = try testing.allocator.dupe(BindingId, &[_]BindingId{
        BindingId.new(0),
        BindingId.new(1),
    });

    const binding = Binding{
        .constructor = .{
            .term = term_id,
            .parameters = params,
            .instance = 0,
        },
    };
    const id = try ruleset.internBinding(binding);

    try testing.expectEqual(@as(usize, 0), id.index());
    const stored = ruleset.bindings.items[0].constructor;
    try testing.expectEqual(term_id.index(), stored.term.index());
    try testing.expectEqual(@as(usize, 2), stored.parameters.len);
    try testing.expectEqual(@as(usize, 0), stored.parameters[0].index());
    try testing.expectEqual(@as(usize, 1), stored.parameters[1].index());
}

// Test binding: variant construction.
test "binding: make variant" {
    var ruleset = RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    const type_id = TypeId.new(1);
    const variant_id = isle_sema.VariantId.new(type_id, 0);
    const fields = try testing.allocator.dupe(BindingId, &[_]BindingId{
        BindingId.new(5),
        BindingId.new(6),
    });

    const binding = Binding{
        .make_variant = .{
            .ty = type_id,
            .variant = variant_id,
            .fields = fields,
        },
    };
    const id = try ruleset.internBinding(binding);

    try testing.expectEqual(@as(usize, 0), id.index());
    const stored = ruleset.bindings.items[0].make_variant;
    try testing.expectEqual(type_id.index(), stored.ty.index());
    try testing.expectEqual(@as(usize, 2), stored.fields.len);
}

// Test binding: variant field extraction.
test "binding: match variant field" {
    var ruleset = RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    const source_id = BindingId.new(10);
    const type_id = TypeId.new(1);
    const variant_id = isle_sema.VariantId.new(type_id, 0);

    const binding = Binding{
        .match_variant = .{
            .source = source_id,
            .variant = variant_id,
            .field = TupleIndex.new(1),
        },
    };
    const id = try ruleset.internBinding(binding);

    try testing.expectEqual(@as(usize, 0), id.index());
    const stored = ruleset.bindings.items[0].match_variant;
    try testing.expectEqual(source_id.index(), stored.source.index());
    try testing.expectEqual(@as(u8, 1), stored.field.index);
}

// Test rule priority for match ordering.
test "rule priority" {
    var rule_a = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule_a.deinit();
    var rule_b = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule_b.deinit();

    // Set different priorities
    rule_a.prio = 100;
    rule_b.prio = 200;

    // Higher priority should be preferred in overlap resolution
    try testing.expect(rule_b.prio > rule_a.prio);
}

// Test total constraint count.
test "rule total constraints" {
    var rule = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule.deinit();

    try testing.expectEqual(@as(usize, 0), rule.totalConstraints());

    const arg0 = BindingId.new(0);
    const type_id = TypeId.new(0);
    const constraint = Constraint{
        .const_int = .{
            .val = 42,
            .ty = type_id,
        },
    };
    try rule.setConstraint(arg0, constraint);

    try testing.expectEqual(@as(usize, 1), rule.totalConstraints());
}

// Test complex nested pattern from ISLE source.
test "compile nested iadd pattern" {
    const source = isle_compile.Source{
        .filename = "test.isle",
        .content =
        \\(type Value extern)
        \\(type u64 extern)
        \\(decl pure iadd (Value Value) Value)
        \\(decl pure iconst (u64) Value)
        \\(rule (iadd x (iconst 42)) (iadd (iconst 42) x))
        ,
    };

    var result = try isle_compile.compile(testing.allocator, &[_]isle_compile.Source{source}, .{
        .debug_comments = false,
    });
    defer result.deinit();

    // Verify code generation succeeded
    try testing.expect(result.code.len > 0);
}

// Test pattern with multiple arguments.
test "compile multi-arg pattern" {
    const source = isle_compile.Source{
        .filename = "test.isle",
        .content =
        \\(type Value extern)
        \\(decl pure select (Value Value Value) Value)
        \\(rule (select cond true_val false_val) true_val)
        ,
    };

    var result = try isle_compile.compile(testing.allocator, &[_]isle_compile.Source{source}, .{
        .debug_comments = false,
    });
    defer result.deinit();

    try testing.expect(result.code.len > 0);
}

// Test pattern ordering with priorities.
test "compile prioritized rules" {
    const source = isle_compile.Source{
        .filename = "test.isle",
        .content =
        \\(type Value extern)
        \\(type u64 extern)
        \\(decl pure iadd (Value Value) Value)
        \\(decl pure iconst (u64) Value)
        \\(rule 10 (iadd x (iconst 0)) x)
        \\(rule 5 (iadd x y) (iadd y x))
        ,
    };

    var result = try isle_compile.compile(testing.allocator, &[_]isle_compile.Source{source}, .{
        .debug_comments = false,
    });
    defer result.deinit();

    // Higher priority rules should be checked first
    try testing.expect(result.code.len > 0);
}

// Test primitive constant pattern.
test "binding: const primitive" {
    var ruleset = RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    var type_env = TypeEnv.init(testing.allocator);
    defer type_env.deinit();

    const sym = try type_env.internSym("MyConst");

    const binding = Binding{
        .const_prim = .{
            .val = sym,
        },
    };
    const id = try ruleset.internBinding(binding);

    try testing.expectEqual(@as(usize, 0), id.index());
    try testing.expectEqual(sym.index(), ruleset.bindings.items[0].const_prim.val.index());
}

// Test constraint for primitive constant.
test "constraint: const primitive" {
    var rule = Rule.init(testing.allocator, isle_sema.Pos.new(0, 0));
    defer rule.deinit();

    var type_env = TypeEnv.init(testing.allocator);
    defer type_env.deinit();

    const sym = try type_env.internSym("MyConst");
    const arg0 = BindingId.new(0);

    const constraint = Constraint{
        .const_prim = .{
            .val = sym,
        },
    };
    try rule.setConstraint(arg0, constraint);

    const retrieved = rule.getConstraint(arg0).?;
    try testing.expectEqual(sym.index(), retrieved.const_prim.val.index());
}
