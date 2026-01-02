const std = @import("std");
const testing = std.testing;
const hoist = @import("hoist");

const sema = hoist.dsl.isle.sema;
const ExtractorCodegen = hoist.dsl.isle.codegen.extractors.ExtractorCodegen;

test "ISLE extractor codegen: simple boolean extractor" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    // Create bool type
    const bool_ty = try typeenv.addType(.{ .builtin = .bool });

    // Create extractor: is_true(input) checks if input == true
    const is_true_sym = try typeenv.internSym("is_true");
    const template = sema.Pattern{ .const_bool = .{
        .val = true,
        .pos = sema.Pos.new(0, 0),
    } };

    const extractor_term = sema.Term{
        .name = is_true_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .extractor = .{
            .arg_tys = &.{},
            .ret_ty = bool_ty,
            .template = template,
        } },
        .pos = sema.Pos.new(0, 0),
    };

    _ = try termenv.addTerm(extractor_term);

    var codegen = ExtractorCodegen.init(testing.allocator, &typeenv, &termenv);
    defer codegen.deinit();

    const code = try codegen.generateExtractor(sema.TermId.new(0));

    // Verify the generated code contains key parts
    try testing.expect(std.mem.indexOf(u8, code, "pub fn extractor_is_true") != null);
    try testing.expect(std.mem.indexOf(u8, code, "input: bool") != null);
    try testing.expect(std.mem.indexOf(u8, code, "?bool") != null);
    try testing.expect(std.mem.indexOf(u8, code, "if (input != true) return null;") != null);
    try testing.expect(std.mem.indexOf(u8, code, "return input;") != null);
}

test "ISLE extractor codegen: integer constant extractor" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    // Create i64 type
    const i64_sym = try typeenv.internSym("i64");
    const i64_ty = try typeenv.addType(.{ .primitive = .{
        .id = sema.TypeId.new(0),
        .name = i64_sym,
        .pos = sema.Pos.new(0, 0),
    } });

    // Create extractor: is_zero(input) checks if input == 0
    const is_zero_sym = try typeenv.internSym("is_zero");
    const template = sema.Pattern{ .const_int = .{
        .val = 0,
        .ty = i64_ty,
        .pos = sema.Pos.new(0, 0),
    } };

    const extractor_term = sema.Term{
        .name = is_zero_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .extractor = .{
            .arg_tys = &.{},
            .ret_ty = i64_ty,
            .template = template,
        } },
        .pos = sema.Pos.new(0, 0),
    };

    _ = try termenv.addTerm(extractor_term);

    var codegen = ExtractorCodegen.init(testing.allocator, &typeenv, &termenv);
    defer codegen.deinit();

    const code = try codegen.generateExtractor(sema.TermId.new(0));

    try testing.expect(std.mem.indexOf(u8, code, "pub fn extractor_is_zero") != null);
    try testing.expect(std.mem.indexOf(u8, code, "if (input != 0) return null;") != null);
}

test "ISLE extractor codegen: wildcard extractor always matches" {
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

    // Wildcard extractor always matches
    const any_sym = try typeenv.internSym("any");
    const template = sema.Pattern{ .wildcard = .{
        .ty = i32_ty,
        .pos = sema.Pos.new(0, 0),
    } };

    const extractor_term = sema.Term{
        .name = any_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .extractor = .{
            .arg_tys = &.{},
            .ret_ty = i32_ty,
            .template = template,
        } },
        .pos = sema.Pos.new(0, 0),
    };

    _ = try termenv.addTerm(extractor_term);

    var codegen = ExtractorCodegen.init(testing.allocator, &typeenv, &termenv);
    defer codegen.deinit();

    const code = try codegen.generateExtractor(sema.TermId.new(0));

    try testing.expect(std.mem.indexOf(u8, code, "pub fn extractor_any") != null);
    try testing.expect(std.mem.indexOf(u8, code, "return input;") != null);
    // Wildcard should not generate any match checks
    try testing.expect(std.mem.indexOf(u8, code, "if (") == null);
}
