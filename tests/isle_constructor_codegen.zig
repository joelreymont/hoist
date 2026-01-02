const std = @import("std");
const testing = std.testing;
const hoist = @import("hoist");

const sema = hoist.dsl.isle.sema;
const trie = hoist.dsl.isle.trie;
const ConstructorGen = hoist.dsl.isle.codegen.constructors.ConstructorGen;

test "ConstructorGen: basic initialization" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    var gen = try ConstructorGen.init(testing.allocator, &typeenv, &termenv);
    defer gen.deinit();
}

test "ConstructorGen: simple constructor signature" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    // Create a simple type
    const i32_sym = try typeenv.internSym("i32");
    const i32_ty = try typeenv.addType(.{ .primitive = .{
        .id = sema.TypeId.new(0),
        .name = i32_sym,
        .pos = sema.Pos.new(0, 0),
    } });

    // Create a term: iadd(i32, i32) -> i32
    const iadd_sym = try typeenv.internSym("iadd");
    const arg_tys = try testing.allocator.alloc(sema.TypeId, 2);
    defer testing.allocator.free(arg_tys);
    arg_tys[0] = i32_ty;
    arg_tys[1] = i32_ty;

    const iadd_term = sema.Term{
        .name = iadd_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .decl = .{
            .arg_tys = arg_tys,
            .ret_ty = i32_ty,
            .pure = true,
        } },
        .pos = sema.Pos.new(0, 0),
    };
    _ = try termenv.addTerm(iadd_term);

    var gen = try ConstructorGen.init(testing.allocator, &typeenv, &termenv);
    defer gen.deinit();

    const sig = try gen.genConstructorSig(sema.TermId.new(0));

    // Verify signature contains expected components
    try testing.expect(std.mem.indexOf(u8, sig, "fn constructor_iadd") != null);
    try testing.expect(std.mem.indexOf(u8, sig, "arg0: i32") != null);
    try testing.expect(std.mem.indexOf(u8, sig, "arg1: i32") != null);
    try testing.expect(std.mem.indexOf(u8, sig, ") i32;") != null);
}

test "ConstructorGen: partial constructor" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    const i32_sym = try typeenv.internSym("i32");
    const i32_ty = try typeenv.addType(.{ .primitive = .{
        .id = sema.TypeId.new(0),
        .name = i32_sym,
        .pos = sema.Pos.new(0, 0),
    } });

    const partial_sym = try typeenv.internSym("partial_op");
    const arg_tys = try testing.allocator.alloc(sema.TypeId, 1);
    defer testing.allocator.free(arg_tys);
    arg_tys[0] = i32_ty;

    const partial_term = sema.Term{
        .name = partial_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .decl = .{
            .arg_tys = arg_tys,
            .ret_ty = i32_ty,
            .pure = false, // Partial constructor
        } },
        .pos = sema.Pos.new(0, 0),
    };
    _ = try termenv.addTerm(partial_term);

    var gen = try ConstructorGen.init(testing.allocator, &typeenv, &termenv);
    defer gen.deinit();

    const sig = try gen.genConstructorSig(sema.TermId.new(0));

    // Partial constructors return optional
    try testing.expect(std.mem.indexOf(u8, sig, ") ?i32;") != null);
}

test "ConstructorGen: reference type handling" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    // Create an enum type (should be passed by reference)
    const enum_sym = try typeenv.internSym("MyEnum");
    const variants = try testing.allocator.alloc(sema.Variant, 1);
    defer testing.allocator.free(variants);
    variants[0] = .{ .name = try typeenv.internSym("A"), .fields = &.{} };

    const enum_ty = try typeenv.addType(.{ .enum_type = .{
        .name = enum_sym,
        .id = sema.TypeId.new(0),
        .is_extern = false,
        .variants = variants,
        .pos = sema.Pos.new(0, 0),
    } });

    const term_sym = try typeenv.internSym("use_enum");
    const arg_tys = try testing.allocator.alloc(sema.TypeId, 1);
    defer testing.allocator.free(arg_tys);
    arg_tys[0] = enum_ty;

    const term = sema.Term{
        .name = term_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .decl = .{
            .arg_tys = arg_tys,
            .ret_ty = enum_ty,
            .pure = true,
        } },
        .pos = sema.Pos.new(0, 0),
    };
    _ = try termenv.addTerm(term);

    var gen = try ConstructorGen.init(testing.allocator, &typeenv, &termenv);
    defer gen.deinit();

    const sig = try gen.genConstructorSig(sema.TermId.new(0));

    // Enum types should be passed by reference
    try testing.expect(std.mem.indexOf(u8, sig, "*const MyEnum") != null);
}

test "ConstructorGen: constructor body generation" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    const i32_sym = try typeenv.internSym("i32");
    const i32_ty = try typeenv.addType(.{ .primitive = .{
        .id = sema.TypeId.new(0),
        .name = i32_sym,
        .pos = sema.Pos.new(0, 0),
    } });

    const term_sym = try typeenv.internSym("test_term");
    const arg_tys = try testing.allocator.alloc(sema.TypeId, 1);
    defer testing.allocator.free(arg_tys);
    arg_tys[0] = i32_ty;

    const term = sema.Term{
        .name = term_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .decl = .{
            .arg_tys = arg_tys,
            .ret_ty = i32_ty,
            .pure = false,
        } },
        .pos = sema.Pos.new(0, 0),
    };
    _ = try termenv.addTerm(term);

    // Create empty ruleset
    var ruleset = trie.RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    var gen = try ConstructorGen.init(testing.allocator, &typeenv, &termenv);
    defer gen.deinit();

    const code = try gen.genConstructor(sema.TermId.new(0), &ruleset);

    // Verify the generated code has basic structure
    try testing.expect(std.mem.indexOf(u8, code, "pub fn constructor_test_term") != null);
    try testing.expect(std.mem.indexOf(u8, code, "ctx: *Context") != null);
    try testing.expect(std.mem.indexOf(u8, code, "arg0: i32") != null);
    try testing.expect(std.mem.indexOf(u8, code, "?i32") != null);
}
