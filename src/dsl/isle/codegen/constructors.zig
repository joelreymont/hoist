const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const sema = @import("../sema.zig");
const trie = @import("../trie.zig");

/// Constructor code generator for ISLE terms.
///
/// Generates Zig functions that construct values from components.
/// Constructors are the core of ISLE lowering - they take arguments
/// and produce typed results according to pattern-matching rules.
pub const ConstructorGen = struct {
    typeenv: *const sema.TypeEnv,
    termenv: *const sema.TermEnv,
    allocator: Allocator,
    output: std.ArrayList(u8),
    indent_level: usize,

    const Self = @This();

    pub fn init(
        allocator: Allocator,
        typeenv: *const sema.TypeEnv,
        termenv: *const sema.TermEnv,
    ) !Self {
        return .{
            .typeenv = typeenv,
            .termenv = termenv,
            .allocator = allocator,
            .output = std.ArrayList(u8){},
            .indent_level = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit();
    }

    /// Generate a constructor function for a term with its associated rules.
    pub fn genConstructor(
        self: *Self,
        term_id: sema.TermId,
        ruleset: *const trie.RuleSet,
    ) ![]const u8 {
        const term = self.termenv.getTerm(term_id);
        const term_name = self.typeenv.symName(term.name);

        const decl = switch (term.kind) {
            .decl => |d| d,
            else => return error.NotAConstructor,
        };

        const writer = self.output.writer();

        // Function signature
        try writer.print("\n/// Generated constructor for term `{s}`\n", .{term_name});
        try writer.print("pub fn constructor_{s}(\n", .{term_name});
        try self.indent(1);
        try writer.print("ctx: *Context,\n", .{});

        // Parameters
        for (decl.arg_tys, 0..) |arg_ty, i| {
            try self.indent(1);
            const ty_name = self.getTypeName(arg_ty);
            const is_ref = self.isRefType(arg_ty);
            if (is_ref) {
                try writer.print("arg{d}: *const {s},\n", .{ i, ty_name });
            } else {
                try writer.print("arg{d}: {s},\n", .{ i, ty_name });
            }
        }

        // Return type
        const ret_ty_name = self.getTypeName(decl.ret_ty);
        const is_partial = !decl.pure;

        try writer.print(") ", .{});
        if (is_partial) {
            try writer.print("?{s} {{\n", .{ret_ty_name});
        } else {
            try writer.print("{s} {{\n", .{ret_ty_name});
        }

        // Function body
        self.indent_level = 1;

        // Generate pattern matching logic from ruleset
        try self.emitRulesetBody(ruleset, decl.ret_ty, is_partial);

        // Closing brace
        try writer.writeAll("}\n");

        return self.output.items;
    }

    /// Emit the body of a constructor based on its ruleset.
    fn emitRulesetBody(
        self: *Self,
        ruleset: *const trie.RuleSet,
        ret_ty: sema.TypeId,
        is_partial: bool,
    ) !void {
        const writer = self.output.writer();

        // For now, emit a simple structure
        // TODO: Implement full decision tree traversal
        _ = ruleset;
        _ = ret_ty;

        // Temporary implementation
        try self.indent(self.indent_level);
        if (is_partial) {
            try writer.writeAll("// TODO: Implement pattern matching\n");
            try self.indent(self.indent_level);
            try writer.writeAll("return null;\n");
        } else {
            try writer.writeAll("// TODO: Implement pattern matching\n");
            try self.indent(self.indent_level);
            try writer.writeAll("unreachable; // Pure constructor must match\n");
        }
    }

    /// Generate constructor signature as a trait function declaration.
    pub fn genConstructorSig(
        self: *Self,
        term_id: sema.TermId,
    ) ![]const u8 {
        const term = self.termenv.getTerm(term_id);
        const term_name = self.typeenv.symName(term.name);

        const decl = switch (term.kind) {
            .decl => |d| d,
            else => return error.NotAConstructor,
        };

        const writer = self.output.writer();

        // Function signature for trait
        try writer.print("    fn constructor_{s}(\n", .{term_name});
        try writer.writeAll("        self: *@This(),\n");

        // Parameters
        for (decl.arg_tys, 0..) |arg_ty, i| {
            const ty_name = self.getTypeName(arg_ty);
            const is_ref = self.isRefType(arg_ty);
            if (is_ref) {
                try writer.print("        arg{d}: *const {s},\n", .{ i, ty_name });
            } else {
                try writer.print("        arg{d}: {s},\n", .{ i, ty_name });
            }
        }

        // Return type
        const ret_ty_name = self.getTypeName(decl.ret_ty);
        if (!decl.pure) {
            try writer.print("    ) ?{s};\n", .{ret_ty_name});
        } else {
            try writer.print("    ) {s};\n", .{ret_ty_name});
        }

        return self.output.items;
    }

    /// Generate argument validation logic.
    fn emitArgValidation(
        self: *Self,
        arg_tys: []const sema.TypeId,
    ) !void {
        const writer = self.output.writer();
        _ = arg_tys;

        // TODO: Add type checking and validation
        try self.indent(self.indent_level);
        try writer.writeAll("// Argument validation\n");
    }

    /// Generate return value construction.
    fn emitReturnConstruction(
        self: *Self,
        ret_ty: sema.TypeId,
        result_binding: trie.BindingId,
    ) !void {
        const writer = self.output.writer();
        _ = ret_ty;

        try self.indent(self.indent_level);
        try writer.print("return v{};\n", .{result_binding.index()});
    }

    /// Get Zig type name for a TypeId.
    fn getTypeName(self: *const Self, type_id: sema.TypeId) []const u8 {
        const ty = self.typeenv.types.items[type_id.index()];
        return switch (ty) {
            .primitive => |p| self.typeenv.symName(p.name),
            .enum_type => |e| self.typeenv.symName(e.name),
            .builtin => |b| switch (b) {
                .bool => "bool",
                .unit => "void",
            },
        };
    }

    /// Check if a type should be passed by reference.
    fn isRefType(self: *const Self, type_id: sema.TypeId) bool {
        const ty = self.typeenv.types.items[type_id.index()];
        return switch (ty) {
            .primitive => false,
            .enum_type => true,
            .builtin => false,
        };
    }

    /// Write indentation at current level.
    fn indent(self: *Self, level: usize) !void {
        const writer = self.output.writer();
        var i: usize = 0;
        while (i < level * 4) : (i += 1) {
            try writer.writeByte(' ');
        }
    }

    /// Generate constructor call expression.
    pub fn emitConstructorCall(
        self: *Self,
        term_id: sema.TermId,
        args: []const trie.BindingId,
    ) !void {
        const term = self.termenv.getTerm(term_id);
        const term_name = self.typeenv.symName(term.name);
        const writer = self.output.writer();

        try writer.print("constructor_{s}(ctx", .{term_name});
        for (args, 0..) |arg, i| {
            try writer.print(", v{d}", .{arg.index()});
            _ = i;
        }
        try writer.writeByte(')');
    }

    /// Generate integration with backend implementation functions.
    pub fn genBackendIntegration(
        self: *Self,
        term_id: sema.TermId,
    ) !void {
        const term = self.termenv.getTerm(term_id);
        const term_name = self.typeenv.symName(term.name);
        const writer = self.output.writer();

        const extern_sig = switch (term.kind) {
            .extern_func => |e| e,
            else => return,
        };

        // Generate wrapper that calls external backend function
        try writer.print("\n/// Backend integration for `{s}`\n", .{term_name});
        try writer.print("pub fn backend_{s}(\n", .{term_name});
        try writer.writeAll("    ctx: *Context,\n");

        for (extern_sig.arg_tys, 0..) |arg_ty, i| {
            const ty_name = self.getTypeName(arg_ty);
            try writer.print("    arg{d}: {s},\n", .{ i, ty_name });
        }

        const ret_ty_name = self.getTypeName(extern_sig.ret_ty);
        try writer.print(") {s} {{\n", .{ret_ty_name});
        try writer.print("    return ctx.backend.{s}(", .{term_name});
        for (extern_sig.arg_tys, 0..) |_, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("arg{d}", .{i});
        }
        try writer.writeAll(");\n");
        try writer.writeAll("}\n");
    }
};

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
