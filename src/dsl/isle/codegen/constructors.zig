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
    arg_tys: ?[]const sema.TypeId,
    prebound: std.AutoHashMap(usize, void),
    emitted: std.AutoHashMap(usize, void),

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
            .arg_tys = null,
            .prebound = std.AutoHashMap(usize, void).init(allocator),
            .emitted = std.AutoHashMap(usize, void).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit();
        self.prebound.deinit();
        self.emitted.deinit();
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
        const is_partial = decl.partial;

        try writer.print(") ", .{});
        if (is_partial) {
            try writer.print("!?{s} {{\n", .{ret_ty_name});
        } else {
            try writer.print("!{s} {{\n", .{ret_ty_name});
        }

        // Function body
        self.indent_level = 1;
        self.arg_tys = decl.arg_tys;
        self.prebound.clearRetainingCapacity();
        self.emitted.clearRetainingCapacity();
        defer self.arg_tys = null;

        // Generate pattern matching logic from ruleset
        try self.emitArgValidation(ruleset, decl.arg_tys);
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
        // Build decision tree for pattern matching
        const tree = trie.buildDecisionTree(ruleset, self.allocator) catch {
            // Fallback if tree building fails
            return self.emitFallback(is_partial);
        };
        defer tree.deinit(self.allocator);

        // Emit code from decision tree
        try self.emitDecisionTree(tree, ruleset, ret_ty, is_partial);
    }

    /// Emit fallback for empty or failed rulesets.
    fn emitFallback(self: *Self, is_partial: bool) !void {
        const writer = self.output.writer();
        try self.indent(self.indent_level);
        if (is_partial) {
            try writer.writeAll("return null;\n");
        } else {
            try writer.writeAll("unreachable;\n");
        }
    }

    /// Emit code from a decision tree node.
    fn emitDecisionTree(
        self: *Self,
        tree: *const trie.DecisionTree,
        ruleset: *const trie.RuleSet,
        ret_ty: sema.TypeId,
        is_partial: bool,
    ) !void {
        var scope_emitted = std.ArrayList(usize){};
        defer {
            for (scope_emitted.items) |id| {
                _ = self.emitted.remove(id);
            }
            scope_emitted.deinit(self.allocator);
        }
        const writer = self.output.writer();

        switch (tree.*) {
            .fail => {
                try self.indent(self.indent_level);
                if (is_partial) {
                    try writer.writeAll("return null;\n");
                } else {
                    try writer.writeAll("unreachable; // No rule matched\n");
                }
            },
            .leaf => |leaf| {
                const rule = &ruleset.rules.items[leaf.rule_index];
                try self.emitRuleBody(rule, ruleset);
            },
            .switch_constraint => |sw| {
                if (sw.binding.index() < ruleset.bindings.items.len) {
                    const binding = &ruleset.bindings.items[sw.binding.index()];
                    try self.emitBindingRecursive(ruleset, sw.binding, binding, &scope_emitted);
                }
                if (sw.cases.count() == 1) {
                    var case_it = sw.cases.iterator();
                    if (case_it.next()) |entry| {
                        if (entry.key_ptr.* == .some) {
                            const subtree = entry.value_ptr.*;
                            try self.indent(self.indent_level);
                            try writer.print("if (v{d} != null) {{\n", .{sw.binding.index()});
                            self.indent_level += 1;
                            try self.emitDecisionTree(subtree, ruleset, ret_ty, is_partial);
                            self.indent_level -= 1;
                            try self.indent(self.indent_level);
                            try writer.writeAll("} else {\n");
                            self.indent_level += 1;
                            if (sw.default) |def| {
                                try self.emitDecisionTree(def, ruleset, ret_ty, is_partial);
                            } else if (is_partial) {
                                try self.indent(self.indent_level);
                                try writer.writeAll("return null;\n");
                            } else {
                                try self.indent(self.indent_level);
                                try writer.writeAll("unreachable;\n");
                            }
                            self.indent_level -= 1;
                            try self.indent(self.indent_level);
                            try writer.writeAll("}\n");
                            return;
                        }
                    }
                }
                try self.indent(self.indent_level);
                try writer.print("switch (v{d}) {{\n", .{sw.binding.index()});
                self.indent_level += 1;

                var it = sw.cases.iterator();
                while (it.next()) |entry| {
                    const constraint = entry.key_ptr.*;
                    const subtree = entry.value_ptr.*;

                    try self.indent(self.indent_level);
                    try self.emitConstraintPattern(constraint);
                    try writer.writeAll(" => {\n");
                    self.indent_level += 1;
                    try self.emitDecisionTree(subtree, ruleset, ret_ty, is_partial);
                    self.indent_level -= 1;
                    try self.indent(self.indent_level);
                    try writer.writeAll("},\n");
                }

                // Default case
                if (sw.default) |def| {
                    try self.indent(self.indent_level);
                    try writer.writeAll("else => {\n");
                    self.indent_level += 1;
                    try self.emitDecisionTree(def, ruleset, ret_ty, is_partial);
                    self.indent_level -= 1;
                    try self.indent(self.indent_level);
                    try writer.writeAll("},\n");
                } else {
                    try self.indent(self.indent_level);
                    try writer.writeAll("else => ");
                    if (is_partial) {
                        try writer.writeAll("return null,\n");
                    } else {
                        try writer.writeAll("unreachable,\n");
                    }
                }

                self.indent_level -= 1;
                try self.indent(self.indent_level);
                try writer.writeAll("}\n");
            },
            .test_equal => |eq| {
                if (eq.a.index() < ruleset.bindings.items.len) {
                    const binding = &ruleset.bindings.items[eq.a.index()];
                    try self.emitBindingRecursive(ruleset, eq.a, binding, &scope_emitted);
                }
                if (eq.b.index() < ruleset.bindings.items.len) {
                    const binding = &ruleset.bindings.items[eq.b.index()];
                    try self.emitBindingRecursive(ruleset, eq.b, binding, &scope_emitted);
                }
                try self.indent(self.indent_level);
                try writer.print("if (v{d} == v{d}) {{\n", .{ eq.a.index(), eq.b.index() });
                self.indent_level += 1;
                try self.emitDecisionTree(eq.on_equal, ruleset, ret_ty, is_partial);
                self.indent_level -= 1;
                try self.indent(self.indent_level);
                try writer.writeAll("} else {\n");
                self.indent_level += 1;
                try self.emitDecisionTree(eq.on_not_equal, ruleset, ret_ty, is_partial);
                self.indent_level -= 1;
                try self.indent(self.indent_level);
                try writer.writeAll("}\n");
            },
        }
    }

    /// Emit constraint pattern for switch arm.
    fn emitConstraintPattern(self: *Self, constraint: trie.Constraint) !void {
        const writer = self.output.writer();
        switch (constraint) {
            .const_bool => |b| try writer.print("{}", .{b.val}),
            .const_int => |i| try writer.print("{d}", .{i.val}),
            .const_prim => |p| try writer.print(".{s}", .{self.typeenv.symName(p.val)}),
            .variant => |v| {
                const ty = self.typeenv.types.items[v.ty.index()];
                switch (ty) {
                    .enum_type => |e| {
                        const variant = e.variants[v.variant.index()];
                        try writer.print(".{s}", .{self.typeenv.symName(variant.name)});
                    },
                    else => try writer.writeAll("_"),
                }
            },
            .some => try writer.writeAll(".some"),
        }
    }

    /// Emit body of a matched rule.
    fn emitRuleBody(self: *Self, rule: *const trie.Rule, ruleset: *const trie.RuleSet) !void {
        const writer = self.output.writer();
        var scope_emitted = std.ArrayList(usize){};
        defer {
            for (scope_emitted.items) |id| {
                _ = self.emitted.remove(id);
            }
            scope_emitted.deinit(self.allocator);
        }

        // Emit impure bindings (side effects)
        for (rule.impure.items) |bind_id| {
            if (bind_id.index() < ruleset.bindings.items.len) {
                const binding = &ruleset.bindings.items[bind_id.index()];
                try self.emitBindingRecursive(ruleset, bind_id, binding, &scope_emitted);
            }
        }

        // Emit result binding if needed
        if (rule.result.index() < ruleset.bindings.items.len) {
            const result_binding = &ruleset.bindings.items[rule.result.index()];
            try self.emitBindingRecursive(ruleset, rule.result, result_binding, &scope_emitted);
        }

        // Emit return expression
        try self.indent(self.indent_level);
        try writer.print("return v{d};\n", .{rule.result.index()});
    }

    /// Emit a single binding.
    fn emitBinding(self: *Self, id: trie.BindingId, binding: *const trie.Binding) !void {
        const writer = self.output.writer();
        if (binding.* == .argument and self.prebound.contains(id.index())) {
            return;
        }
        try self.indent(self.indent_level);
        try writer.print("const v{d} = ", .{id.index()});

        switch (binding.*) {
            .const_bool => |b| try writer.print("{}", .{b.val}),
            .const_int => |i| try writer.print("{d}", .{i.val}),
            .const_prim => |p| try writer.print(".{s}", .{self.typeenv.symName(p.val)}),
            .argument => |a| {
                if (self.argType(a.index.value())) |arg_ty| {
                    try self.emitArgExpr(writer, a.index.value(), arg_ty);
                } else {
                    try writer.print("arg{d}", .{a.index.value()});
                }
            },
            .extractor => |e| {
                const term = self.termenv.getTerm(e.term);
                const name = self.typeenv.symName(term.name);
                try writer.print("try extractor_{s}(ctx", .{name});
                for (e.parameters) |param| {
                    try writer.writeAll(", ");
                    try writer.print("v{d}", .{param.index()});
                }
                try writer.writeAll(")");
            },
            .constructor => |c| {
                const term = self.termenv.getTerm(c.term);
                const name = self.typeenv.symName(term.name);
                const is_partial = term.kind == .decl and term.kind.decl.partial;
                if (is_partial) {
                    try writer.print("(try constructor_{s}(ctx", .{name});
                } else {
                    try writer.print("try constructor_{s}(ctx", .{name});
                }
                for (c.parameters) |param| {
                    try writer.writeAll(", ");
                    try writer.print("v{d}", .{param.index()});
                }
                if (is_partial) {
                    try writer.writeAll(")) orelse return null");
                } else {
                    try writer.writeAll(")");
                }
            },
            .iterator => |it| try writer.print("v{d}.next()", .{it.source.index()}),
            .make_variant => |v| {
                const ty = self.typeenv.types.items[v.ty.index()];
                switch (ty) {
                    .enum_type => |e| {
                        const variant = e.variants[v.variant.index()];
                        try writer.print(".{{ .{s} = .{{ ", .{self.typeenv.symName(variant.name)});
                        for (v.fields, 0..) |f, i| {
                            if (i > 0) try writer.writeAll(", ");
                            try writer.print("v{d}", .{f.index()});
                        }
                        try writer.writeAll(" } }");
                    },
                    else => try writer.writeAll("undefined"),
                }
            },
            .match_variant => |m| {
                const ty = self.typeenv.getType(m.variant.type_id);
                if (ty == .enum_type) {
                    const variant = ty.enum_type.variants[m.variant.variant_index];
                    if (m.field.value() < variant.fields.len) {
                        const field = variant.fields[m.field.value()];
                        try writer.print(
                            "v{d}.{s}.{s}",
                            .{
                                m.source.index(),
                                self.typeenv.symName(variant.name),
                                self.typeenv.symName(field.name),
                            },
                        );
                    } else {
                        try writer.writeAll("undefined");
                    }
                } else {
                    try writer.writeAll("undefined");
                }
            },
            .make_some => |s| try writer.print("v{d}", .{s.inner.index()}),
            .match_some => |m| try writer.print("v{d}.?", .{m.source.index()}),
            .match_tuple => |t| try writer.print("v{d}.field{d}", .{ t.source.index(), t.field.value() }),
        }

        try writer.writeAll(";\n");
    }

    fn emitBindingRecursive(
        self: *Self,
        ruleset: *const trie.RuleSet,
        id: trie.BindingId,
        binding: *const trie.Binding,
        scope_emitted: *std.ArrayList(usize),
    ) !void {
        if (self.emitted.contains(id.index())) return;
        if (binding.* == .argument and self.prebound.contains(id.index())) {
            try self.emitted.put(id.index(), {});
            try scope_emitted.append(self.allocator, id.index());
            return;
        }

        switch (binding.*) {
            .constructor => |c| {
                for (c.parameters) |param| {
                    const param_binding = &ruleset.bindings.items[param.index()];
                    try self.emitBindingRecursive(ruleset, param, param_binding, scope_emitted);
                }
            },
            .extractor => |e| {
                for (e.parameters) |param| {
                    const param_binding = &ruleset.bindings.items[param.index()];
                    try self.emitBindingRecursive(ruleset, param, param_binding, scope_emitted);
                }
            },
            .iterator => |it| {
                const source_binding = &ruleset.bindings.items[it.source.index()];
                try self.emitBindingRecursive(ruleset, it.source, source_binding, scope_emitted);
            },
            .make_variant => |v| {
                for (v.fields) |field| {
                    const field_binding = &ruleset.bindings.items[field.index()];
                    try self.emitBindingRecursive(ruleset, field, field_binding, scope_emitted);
                }
            },
            .match_variant => |m| {
                const source_binding = &ruleset.bindings.items[m.source.index()];
                try self.emitBindingRecursive(ruleset, m.source, source_binding, scope_emitted);
            },
            .make_some => |s| {
                const inner_binding = &ruleset.bindings.items[s.inner.index()];
                try self.emitBindingRecursive(ruleset, s.inner, inner_binding, scope_emitted);
            },
            .match_some => |m| {
                const source_binding = &ruleset.bindings.items[m.source.index()];
                try self.emitBindingRecursive(ruleset, m.source, source_binding, scope_emitted);
            },
            .match_tuple => |t| {
                const source_binding = &ruleset.bindings.items[t.source.index()];
                try self.emitBindingRecursive(ruleset, t.source, source_binding, scope_emitted);
            },
            else => {},
        }

        try self.emitBinding(id, binding);
        try self.emitted.put(id.index(), {});
        try scope_emitted.append(self.allocator, id.index());
    }

    fn emitArgExpr(self: *Self, writer: anytype, index: usize, arg_ty: sema.TypeId) !void {
        if (self.isRefType(arg_ty)) {
            try writer.print("arg{d}.*", .{index});
        } else {
            try writer.print("arg{d}", .{index});
        }
    }

    fn argType(self: *const Self, index: usize) ?sema.TypeId {
        if (self.arg_tys) |arg_tys| {
            if (index < arg_tys.len) return arg_tys[index];
        }
        return null;
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
        if (decl.partial) {
            try writer.print("    ) !?{s};\n", .{ret_ty_name});
        } else {
            try writer.print("    ) !{s};\n", .{ret_ty_name});
        }

        return self.output.items;
    }

    /// Generate argument validation logic.
    fn emitArgValidation(
        self: *Self,
        ruleset: *const trie.RuleSet,
        arg_tys: []const sema.TypeId,
    ) !void {
        const writer = self.output.writer();
        for (arg_tys, 0..) |arg_ty, i| {
            const binding = trie.Binding{
                .argument = .{ .index = trie.TupleIndex.new(@intCast(i)) },
            };
            const binding_id = ruleset.findBinding(&binding) orelse continue;

            try self.indent(self.indent_level);
            try writer.print("const v{d} = ", .{binding_id.index()});
            try self.emitArgExpr(writer, i, arg_ty);
            try writer.writeAll(";\n");
            try self.prebound.put(binding_id.index(), {});
        }
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
            .tuple => |t| self.typeenv.symName(t.name),
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
            .tuple => false,
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
            .partial = false,
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
    try testing.expect(std.mem.indexOf(u8, sig, ") !i32;") != null);
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
        .kind = .{
            .decl = .{
                .arg_tys = arg_tys,
                .ret_ty = i32_ty,
                .pure = false,
                .partial = true,
            },
        },
        .pos = sema.Pos.new(0, 0),
    };
    _ = try termenv.addTerm(partial_term);

    var gen = try ConstructorGen.init(testing.allocator, &typeenv, &termenv);
    defer gen.deinit();

    const sig = try gen.genConstructorSig(sema.TermId.new(0));

    // Partial constructors return optional
    try testing.expect(std.mem.indexOf(u8, sig, ") !?i32;") != null);
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
            .partial = false,
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
            .partial = true,
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
    try testing.expect(std.mem.indexOf(u8, code, "!?i32") != null);
}

test "ConstructorGen: match_variant field access" {
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

    const variant_sym = try typeenv.internSym("Pair");
    const field_a = try typeenv.internSym("a");
    const field_b = try typeenv.internSym("b");

    const fields = try testing.allocator.dupe(sema.Field, &[_]sema.Field{
        .{ .name = field_a, .ty = i32_ty },
        .{ .name = field_b, .ty = i32_ty },
    });
    defer testing.allocator.free(fields);

    const variants = try testing.allocator.dupe(sema.Variant, &[_]sema.Variant{
        .{ .name = variant_sym, .fields = fields },
    });
    defer testing.allocator.free(variants);

    const enum_ty = try typeenv.addType(.{ .enum_type = .{
        .name = variant_sym,
        .id = sema.TypeId.new(1),
        .is_extern = false,
        .variants = variants,
        .pos = sema.Pos.new(0, 0),
    } });

    var gen = try ConstructorGen.init(testing.allocator, &typeenv, &termenv);
    defer gen.deinit();

    const binding = trie.Binding{
        .match_variant = .{
            .source = trie.BindingId.new(0),
            .variant = sema.VariantId.new(enum_ty, 0),
            .field = trie.TupleIndex.new(1),
        },
    };

    try gen.emitBinding(trie.BindingId.new(1), &binding);

    try testing.expect(std.mem.indexOf(u8, gen.output.items, "v0.Pair.b") != null);
}

test "ConstructorGen: match_tuple field access" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

    var gen = try ConstructorGen.init(testing.allocator, &typeenv, &termenv);
    defer gen.deinit();
    gen.output.clearRetainingCapacity();

    const binding = trie.Binding{
        .match_tuple = .{
            .source = trie.BindingId.new(0),
            .field = trie.TupleIndex.new(1),
        },
    };

    try gen.emitBinding(trie.BindingId.new(1), &binding);

    try testing.expect(std.mem.indexOf(u8, gen.output.items, ".field1") != null);
}

test "ConstructorGen: argument validation for ref types" {
    var typeenv = sema.TypeEnv.init(testing.allocator);
    defer typeenv.deinit();

    var termenv = sema.TermEnv.init(testing.allocator);
    defer termenv.deinit();

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

    const term_sym = try typeenv.internSym("id_enum");
    const arg_tys = try testing.allocator.alloc(sema.TypeId, 1);
    defer testing.allocator.free(arg_tys);
    arg_tys[0] = enum_ty;

    const term = sema.Term{
        .name = term_sym,
        .id = sema.TermId.new(0),
        .kind = .{ .decl = .{
            .arg_tys = arg_tys,
            .ret_ty = enum_ty,
            .pure = false,
            .partial = false,
        } },
        .pos = sema.Pos.new(0, 0),
    };
    _ = try termenv.addTerm(term);

    var ruleset = trie.RuleSet.init(testing.allocator);
    defer ruleset.deinit();

    const arg_binding = trie.Binding{
        .argument = .{ .index = trie.TupleIndex.new(0) },
    };
    const arg_id = try ruleset.internBinding(arg_binding);

    var rule = trie.Rule.init(testing.allocator, sema.Pos.new(0, 0));
    defer rule.deinit();
    rule.result = arg_id;
    try ruleset.addRule(rule);

    var gen = try ConstructorGen.init(testing.allocator, &typeenv, &termenv);
    defer gen.deinit();

    const code = try gen.genConstructor(sema.TermId.new(0), &ruleset);

    try testing.expect(std.mem.indexOf(u8, code, "const v0 = arg0.*;") != null);
}
