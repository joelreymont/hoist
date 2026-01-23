const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const sema = @import("../sema.zig");
const trie = @import("../trie.zig");

/// Extractor code generator - emits pattern matching extraction functions.
///
/// Extractors are functions that:
/// - Take an input value to decompose
/// - Take pattern arguments (if any)
/// - Return nullable result (null = match failed)
/// - Extract fields from the input based on the pattern template
pub const ExtractorCodegen = struct {
    typeenv: *const sema.TypeEnv,
    termenv: *const sema.TermEnv,
    output: std.ArrayList(u8),
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
            .output = std.ArrayList(u8){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit(self.allocator);
    }

    /// Generate extractor function for a single term.
    pub fn generateExtractor(
        self: *Self,
        term_id: sema.TermId,
    ) ![]const u8 {
        const term = self.termenv.getTerm(term_id);
        const term_name = self.typeenv.symName(term.name);

        const extractor = switch (term.kind) {
            .extractor => |e| e,
            else => return error.NotAnExtractor,
        };

        const writer = self.output.writer(self.allocator);

        // Function signature
        try writer.print(
            \\/// Extractor for {s}
            \\/// Returns null if pattern does not match
            \\pub fn extractor_{s}(
            \\    ctx: *Context,
            \\    input: {s}
        , .{
            term_name,
            term_name,
            try self.getTypeName(extractor.ret_ty),
        });

        // Extractor arguments (pattern parameters)
        for (extractor.arg_tys, 0..) |arg_ty, i| {
            try writer.print(
                \\,
                \\    arg{d}: {s}
            , .{ i, try self.getTypeName(arg_ty) });
        }

        // Return type is nullable
        try writer.print(
            \\,
            \\) ?{s} {{
            \\
        , .{try self.getTypeName(extractor.ret_ty)});

        // Emit pattern matching code from template
        try self.emitPatternMatch(extractor.template, "input", 4);

        // Extractor always returns the input on success
        try writer.writeAll(
            \\    return input;
            \\}
            \\
            \\
        );

        return self.output.items;
    }

    /// Emit pattern matching code for extractor template.
    fn emitPatternMatch(
        self: *Self,
        pattern: sema.Pattern,
        source_expr: []const u8,
        indent: usize,
    ) !void {
        const writer = self.output.writer(self.allocator);

        switch (pattern) {
            .var_pat => {
                // Variable patterns always match - no check needed
            },
            .wildcard => {
                // Wildcard always matches - no check needed
            },
            .const_bool => |c| {
                // Check boolean equality
                try self.emitIndent(indent);
                try writer.print("if ({s} != {}) return null;\n", .{ source_expr, c.val });
            },
            .const_int => |c| {
                // Check integer equality
                try self.emitIndent(indent);
                try writer.print("if ({s} != {d}) return null;\n", .{ source_expr, c.val });
            },
            .const_prim => |c| {
                // Check primitive constant equality
                const val_name = self.typeenv.symName(c.val);
                try self.emitIndent(indent);
                try writer.print("if (!std.meta.eql({s}, {s})) return null;\n", .{ source_expr, val_name });
            },
            .term => |t| {
                // Pattern match on term constructor/extractor
                const term = self.termenv.getTerm(t.term_id);
                const term_name = self.typeenv.symName(term.name);

                switch (term.kind) {
                    .decl => |decl| {
                        // Constructor pattern - match enum variant
                        const ret_ty = self.typeenv.getType(decl.ret_ty);
                        if (ret_ty == .enum_type) {
                            // Find which variant this is
                            const variant_id = self.findVariantForTerm(decl.ret_ty, t.term_id);
                            if (variant_id) |vid| {
                                try self.emitVariantMatch(source_expr, vid, t.args, indent);
                            }
                        } else {
                            // Primitive type - just match recursively
                            for (t.args, 0..) |arg, i| {
                                const field_expr = try std.fmt.allocPrint(
                                    self.allocator,
                                    "{s}.field{d}",
                                    .{ source_expr, i },
                                );
                                defer self.allocator.free(field_expr);
                                try self.emitPatternMatch(arg, field_expr, indent);
                            }
                        }
                    },
                    .extractor => |ext| {
                        // Nested extractor call - returns tuple of extracted values
                        const result_var = try std.fmt.allocPrint(
                            self.allocator,
                            "extracted_{d}",
                            .{@intFromPtr(&pattern)}, // unique ID from pattern addr
                        );
                        defer self.allocator.free(result_var);

                        try self.emitIndent(indent);
                        try writer.print("const {s} = extractor_{s}(ctx, {s}", .{ result_var, term_name, source_expr });

                        // Pass extractor arguments if any
                        for (0..t.args.len) |i| {
                            try writer.print(", arg{d}", .{i});
                        }

                        try writer.writeAll(") orelse return null;\n");

                        // Match nested patterns against extracted fields
                        for (t.args, 0..) |arg_pat, i| {
                            const field_expr = try std.fmt.allocPrint(
                                self.allocator,
                                "{s}[{d}]",
                                .{ result_var, i },
                            );
                            defer self.allocator.free(field_expr);
                            try self.emitPatternMatch(arg_pat, field_expr, indent);
                        }

                        _ = ext;
                    },
                    .extern_func => {
                        return error.ExternalFunctionInPattern;
                    },
                }
            },
            .bind_pattern => |b| {
                // Bind pattern - match subpattern and remember binding
                try self.emitPatternMatch(b.subpat.*, source_expr, indent);
                // TODO: Store binding for later use
            },
            .and_pat => |a| {
                // And pattern - all subpatterns must match
                for (a.subpats) |subpat| {
                    try self.emitPatternMatch(subpat, source_expr, indent);
                }
            },
        }
    }

    /// Emit variant pattern matching code.
    fn emitVariantMatch(
        self: *Self,
        source_expr: []const u8,
        variant_id: sema.VariantId,
        arg_patterns: []const sema.Pattern,
        indent: usize,
    ) !void {
        const writer = self.output.writer(self.allocator);
        const ty = self.typeenv.getType(variant_id.type_id);

        if (ty != .enum_type) return error.NotAnEnum;

        const enum_type = ty.enum_type;
        const variant = enum_type.variants[variant_id.variant_index];
        const variant_name = self.typeenv.symName(variant.name);
        const type_name = self.typeenv.symName(enum_type.name);

        // Emit variant match
        try self.emitIndent(indent);
        try writer.print("switch ({s}) {{\n", .{source_expr});
        try self.emitIndent(indent + 4);
        try writer.print(".{s} => |fields| {{\n", .{variant_name});

        // Match each field
        for (arg_patterns, 0..) |arg_pat, i| {
            const field = variant.fields[i];
            const field_name = self.typeenv.symName(field.name);
            const field_expr = try std.fmt.allocPrint(
                self.allocator,
                "fields.{s}",
                .{field_name},
            );
            defer self.allocator.free(field_expr);

            try self.emitPatternMatch(arg_pat, field_expr, indent + 8);
        }

        try self.emitIndent(indent + 4);
        try writer.writeAll("},\n");

        // Default case - match failed
        try self.emitIndent(indent + 4);
        try writer.writeAll("else => return null,\n");
        try self.emitIndent(indent);
        try writer.writeAll("}\n");

        _ = type_name; // Reserved for future use
    }

    /// Find the variant ID for a constructor term.
    fn findVariantForTerm(
        self: *const Self,
        type_id: sema.TypeId,
        term_id: sema.TermId,
    ) ?sema.VariantId {
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

    /// Get the Zig type name for a type ID.
    fn getTypeName(self: *const Self, type_id: sema.TypeId) ![]const u8 {
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

    /// Emit indentation.
    fn emitIndent(self: *Self, count: usize) !void {
        const writer = self.output.writer(self.allocator);
        var i: usize = 0;
        while (i < count) : (i += 1) {
            try writer.writeByte(' ');
        }
    }

    /// Generate all extractors for the given terms.
    pub fn generateAll(
        self: *Self,
        terms: []const sema.Term,
    ) ![]const u8 {
        // Clear output
        self.output.clearRetainingCapacity();

        const writer = self.output.writer(self.allocator);

        // Emit preamble
        try writer.writeAll(
            \\// Auto-generated extractor functions
            \\const std = @import("std");
            \\
            \\
        );

        // Generate each extractor
        for (terms) |term| {
            if (term.kind == .extractor) {
                // Save current output
                const saved = self.output.items.len;

                // Generate extractor
                _ = try self.generateExtractor(term.id);

                // Reset for next extractor (generateExtractor clears output)
                self.output.items.len = saved;

                // Re-generate to append
                const term_name = self.typeenv.symName(term.name);
                const extractor = term.kind.extractor;

                try writer.print(
                    \\/// Extractor for {s}
                    \\/// Returns null if pattern does not match
                    \\pub fn extractor_{s}(
                    \\    ctx: *Context,
                    \\    input: {s}
                , .{
                    term_name,
                    term_name,
                    try self.getTypeName(extractor.ret_ty),
                });

                for (extractor.arg_tys, 0..) |arg_ty, i| {
                    try writer.print(
                        \\,
                        \\    arg{d}: {s}
                    , .{ i, try self.getTypeName(arg_ty) });
                }

                try writer.print(
                    \\,
                    \\) ?{s} {{
                    \\
                , .{try self.getTypeName(extractor.ret_ty)});

                try self.emitPatternMatch(extractor.template, "input", 4);

                try writer.writeAll(
                    \\    return input;
                    \\}
                    \\
                    \\
                );
            }
        }

        return self.output.items;
    }
};

test "ExtractorCodegen: simple boolean extractor" {
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

test "ExtractorCodegen: integer constant extractor" {
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

test "ExtractorCodegen: wildcard extractor" {
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

test "ExtractorCodegen: generate all extractors" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    const bool_ty = try typeenv.addType(.{ .builtin = .bool });

    // Create two extractors
    const is_true_sym = try typeenv.internSym("is_true");
    const is_false_sym = try typeenv.internSym("is_false");

    const true_template = sema.Pattern{ .const_bool = .{
        .val = true,
        .pos = sema.Pos.new(0, 0),
    } };

    const false_template = sema.Pattern{ .const_bool = .{
        .val = false,
        .pos = sema.Pos.new(1, 0),
    } };

    const term1 = sema.Term{
        .name = is_true_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .extractor = .{
            .arg_tys = &.{},
            .ret_ty = bool_ty,
            .template = true_template,
        } },
        .pos = sema.Pos.new(0, 0),
    };

    const term2 = sema.Term{
        .name = is_false_sym,
        .id = sema.TermId.new(1),
        .kind = .{ .extractor = .{
            .arg_tys = &.{},
            .ret_ty = bool_ty,
            .template = false_template,
        } },
        .pos = sema.Pos.new(1, 0),
    };

    _ = try termenv.addTerm(term1);
    _ = try termenv.addTerm(term2);

    var codegen = ExtractorCodegen.init(testing.allocator, &typeenv, &termenv);
    defer codegen.deinit();

    const code = try codegen.generateAll(&.{ term1, term2 });

    try testing.expect(std.mem.indexOf(u8, code, "extractor_is_true") != null);
    try testing.expect(std.mem.indexOf(u8, code, "extractor_is_false") != null);
    try testing.expect(std.mem.indexOf(u8, code, "Auto-generated") != null);
}
