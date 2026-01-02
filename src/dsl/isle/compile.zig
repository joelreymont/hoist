const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const lexer_mod = @import("lexer.zig");
const parser_mod = @import("parser.zig");
const sema_mod = @import("sema.zig");
const codegen_mod = @import("codegen.zig");

pub const Lexer = lexer_mod.Lexer;
pub const Parser = parser_mod.Parser;
pub const Compiler = sema_mod.Compiler;
pub const Codegen = codegen_mod.Codegen;
pub const CodegenOptions = codegen_mod.CodegenOptions;

// Match tree generation module
pub const match = struct {
    const match_mod = @import("codegen/match.zig");
    pub const MatchCompiler = match_mod.MatchCompiler;
    pub const optimizeTree = match_mod.optimizeTree;
    pub const estimateCost = match_mod.estimateCost;
};

// Zig code emission module
pub const emit_zig = struct {
    const emit_mod = @import("codegen/emit_zig.zig");
    pub const ZigEmitter = emit_mod.ZigEmitter;
    pub const ZigCodegenOptions = emit_mod.ZigCodegenOptions;
};

/// Source input for compilation.
pub const Source = struct {
    /// Source file name (for error messages).
    filename: []const u8,
    /// Source code content.
    content: []const u8,
};

/// Compilation error with source location.
pub const CompileError = struct {
    /// Error message.
    message: []const u8,
    /// Source file name.
    filename: []const u8,
    /// Line number (1-based).
    line: u32,
    /// Column number (1-based).
    column: u32,

    pub fn format(
        self: CompileError,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("{s}:{}:{}: {s}", .{
            self.filename,
            self.line,
            self.column,
            self.message,
        });
    }
};

/// Compiled output.
pub const CompiledCode = struct {
    /// Generated Zig source code.
    code: []const u8,
    /// Allocator used for code (caller must free).
    allocator: Allocator,

    pub fn deinit(self: *CompiledCode) void {
        self.allocator.free(self.code);
    }
};

/// Compile ISLE source files to Zig code.
pub fn compile(
    allocator: Allocator,
    sources: []const Source,
    options: CodegenOptions,
) !CompiledCode {
    // For now, we only support single-file compilation
    if (sources.len == 0) {
        return error.NoSources;
    }

    const source = sources[0];

    // Phase 1: Lexical analysis
    var lexer = Lexer.init(allocator, 0, source.content);

    // Phase 2: Parsing
    var parser = try Parser.init(allocator, &lexer);
    const defs = parser.parseDefs() catch |err| {
        std.debug.print("Parse error in {s}: {}\n", .{ source.filename, err });
        return error.ParseError;
    };
    defer {
        // Clean up AST
        for (defs) |def| {
            cleanupDef(allocator, def);
        }
        allocator.free(defs);
    }

    // Phase 3: Semantic analysis
    var compiler = Compiler.init(allocator);
    defer compiler.deinit();

    compiler.compile(defs) catch |err| {
        std.debug.print("Semantic error in {s}: {}\n", .{ source.filename, err });
        return error.SemanticError;
    };

    // Phase 4: Code generation
    var codegen = Codegen.init(
        allocator,
        &compiler.type_env,
        &compiler.term_env,
        compiler.rules.items,
    );
    defer codegen.deinit();

    const code = try codegen.generate(options);

    // Return owned code
    return CompiledCode{
        .code = try allocator.dupe(u8, code),
        .allocator = allocator,
    };
}

/// Clean up AST definition (deallocate owned strings).
fn cleanupDef(allocator: Allocator, def: @import("ast.zig").Def) void {
    switch (def) {
        .type_def => |td| {
            allocator.free(td.name.name);
            switch (td.ty) {
                .primitive => |p| allocator.free(p.name),
                .enum_type => {}, // Simplified for now
            }
        },
        .decl => |d| {
            allocator.free(d.term.name);
            for (d.arg_tys) |arg| {
                allocator.free(arg.name);
            }
            allocator.free(d.arg_tys);
            allocator.free(d.ret_ty.name);
        },
        .rule => |r| {
            cleanupPattern(allocator, r.pattern);
            cleanupExpr(allocator, r.expr);
            allocator.free(r.iflets);
        },
        .extern_def => |e| {
            allocator.free(e.term.name);
            allocator.free(e.func.name);
        },
        .extractor => {}, // Not implemented yet
    }
}

fn cleanupPattern(allocator: Allocator, pattern: @import("ast.zig").Pattern) void {
    switch (pattern) {
        .var_pat => |v| {
            allocator.free(v.var_name.name);
        },
        .term => |t| {
            allocator.free(t.sym.name);
            for (t.args) |arg| {
                cleanupPattern(allocator, arg);
            }
            allocator.free(t.args);
        },
        else => {},
    }
}

fn cleanupExpr(allocator: Allocator, expr: @import("ast.zig").Expr) void {
    switch (expr) {
        .var_expr => |v| {
            allocator.free(v.name.name);
        },
        .term => |t| {
            allocator.free(t.sym.name);
            for (t.args) |arg| {
                cleanupExpr(allocator, arg);
            }
            allocator.free(t.args);
        },
        else => {},
    }
}

test "compile type definition" {
    const source = Source{
        .filename = "test.isle",
        .content = "(type MyType u32)",
    };

    var result = try compile(testing.allocator, &[_]Source{source}, .{});
    defer result.deinit();

    // Check that code was generated (even if empty for type-only input)
    try testing.expect(result.code.len > 0);
}

test "compile error handling" {
    const source = Source{
        .filename = "bad.isle",
        .content = "(invalid syntax",
    };

    const result = compile(testing.allocator, &[_]Source{source}, .{});
    try testing.expectError(error.ParseError, result);
}

test "match tree: basic compilation" {

    var typeenv = sema_mod.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema_mod.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    // Create a simple type and term for testing
    const i32_sym = try typeenv.internSym("i32");
    const i32_ty = try typeenv.addType(.{
        .primitive = .{
            .id = sema_mod.TypeId.new(0),
            .name = i32_sym,
            .pos = sema_mod.Pos.new(0, 0),
        },
    });

    // Create a simple rule: true => 1
    const rule = sema_mod.Rule{
        .pattern = .{
            .const_bool = .{
                .val = true,
                .pos = sema_mod.Pos.new(0, 0),
            },
        },
        .iflets = &.{},
        .expr = .{
            .const_int = .{
                .val = 1,
                .ty = i32_ty,
                .pos = sema_mod.Pos.new(0, 0),
            },
        },
        .prio = 0,
        .pos = sema_mod.Pos.new(0, 0),
    };

    var compiler = match.MatchCompiler.init(testing.allocator, &typeenv, &termenv);

    const rules = [_]sema_mod.Rule{rule};
    var ruleset = try compiler.buildRuleSet(&rules);
    defer ruleset.deinit();

    var tree = try compiler.compile(&ruleset);
    defer {
        tree.deinit(testing.allocator);
        testing.allocator.destroy(tree);
    }

    // Verify tree is not fail
    try testing.expect(tree.* != .fail);

    // Verify cost estimation works
    const cost = match.estimateCost(tree);
    try testing.expect(cost > 0);
}

test "emit_zig: basic code generation" {
    var typeenv = sema_mod.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema_mod.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    // Create a simple type
    const i32_sym = try typeenv.internSym("i32");
    const i32_ty = try typeenv.addType(.{ .primitive = .{
        .id = sema_mod.TypeId.new(0),
        .name = i32_sym,
        .pos = sema_mod.Pos.new(0, 0),
    } });

    // Create a term: iadd(i32, i32) -> i32
    const add_sym = try typeenv.internSym("iadd");
    const add_term = sema_mod.Term{
        .name = add_sym,
        .id = sema_mod.TermId.new(0),
        .kind = .{ .decl = .{
            .arg_tys = @constCast(&[_]sema_mod.TypeId{ i32_ty, i32_ty }),
            .ret_ty = i32_ty,
            .pure = true,
        } },
        .pos = sema_mod.Pos.new(0, 0),
    };
    const term_id = try termenv.addTerm(add_term);

    var ruleset = @import("trie.zig").RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    var emitter = emit_zig.ZigEmitter.init(testing.allocator, &typeenv, &termenv, &ruleset);
    defer emitter.deinit();

    const code = try emitter.generate(term_id, .{});

    // Verify basic structure
    try testing.expect(std.mem.indexOf(u8, code, "pub fn iadd") != null);
    try testing.expect(std.mem.indexOf(u8, code, "arg0: i32") != null);
    try testing.expect(std.mem.indexOf(u8, code, "arg1: i32") != null);
    try testing.expect(std.mem.indexOf(u8, code, "ctx: *Context") != null);
    try testing.expect(std.mem.indexOf(u8, code, "return error.NoMatch") != null);
}
