const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const token = @import("token.zig");

pub const Pos = token.Pos;

/// Identifier - variable, term symbol, or type name.
pub const Ident = struct {
    name: []const u8,
    pos: Pos,

    pub fn init(name: []const u8, pos: Pos) Ident {
        return .{ .name = name, .pos = pos };
    }
};

/// Top-level definition.
pub const Def = union(enum) {
    type_def: TypeDef,
    decl: Decl,
    rule: Rule,
    extractor: Extractor,
    extern_def: ExternDef,

    pub fn pos(self: Def) Pos {
        return switch (self) {
            .type_def => |t| t.pos,
            .decl => |d| d.pos,
            .rule => |r| r.pos,
            .extractor => |e| e.pos,
            .extern_def => |e| e.pos,
        };
    }
};

/// Type definition.
pub const TypeDef = struct {
    name: Ident,
    is_extern: bool,
    ty: TypeValue,
    pos: Pos,
};

/// Type value - primitive or enum.
pub const TypeValue = union(enum) {
    primitive: Ident,
    enum_type: []Variant,
};

/// Enum variant.
pub const Variant = struct {
    name: Ident,
    fields: []Field,
    pos: Pos,
};

/// Variant field.
pub const Field = struct {
    name: Ident,
    ty: Ident,
    pos: Pos,
};

/// Term declaration.
pub const Decl = struct {
    term: Ident,
    arg_tys: []Ident,
    ret_tys: []Ident,
    pure: bool,
    partial: bool,
    pos: Pos,
};

/// Extractor macro.
pub const Extractor = struct {
    term: Ident,
    args: []Ident,
    template: Pattern,
    pos: Pos,
};

/// External declaration kind.
pub const ExternKind = enum {
    constructor,
    extractor,
};

/// External declaration.
pub const ExternDef = struct {
    kind: ExternKind,
    term: Ident,
    func: Ident,
    pos: Pos,
};

/// Rewrite rule.
pub const Rule = struct {
    pattern: Pattern,
    iflets: []IfLet,
    expr: Expr,
    prio: ?i64,
    name: ?Ident,
    pos: Pos,
};

/// If-let guard in rule.
pub const IfLet = struct {
    pattern: Pattern,
    expr: Expr,
    pos: Pos,
};

/// Pattern - left-hand side of rule.
pub const Pattern = union(enum) {
    /// Variable binding/match.
    var_pat: struct { var_name: Ident, pos: Pos },
    /// Bind variable to subterm.
    bind_pattern: struct { var_name: Ident, subpat: *Pattern, pos: Pos },
    /// Constant boolean.
    const_bool: struct { val: bool, pos: Pos },
    /// Constant integer.
    const_int: struct { val: i128, pos: Pos },
    /// Constant primitive.
    const_prim: struct { val: Ident, pos: Pos },
    /// Term application.
    term: struct { sym: Ident, args: []Pattern, pos: Pos },
    /// Wildcard.
    wildcard: struct { pos: Pos },
    /// And pattern.
    and_pat: struct { subpats: []Pattern, pos: Pos },

    pub fn getPos(self: Pattern) Pos {
        return switch (self) {
            .var_pat => |v| v.pos,
            .bind_pattern => |b| b.pos,
            .const_bool => |c| c.pos,
            .const_int => |c| c.pos,
            .const_prim => |c| c.pos,
            .term => |t| t.pos,
            .wildcard => |w| w.pos,
            .and_pat => |a| a.pos,
        };
    }
};

/// Expression - right-hand side of rule.
pub const Expr = union(enum) {
    /// Term construction.
    term: struct { sym: Ident, args: []Expr, pos: Pos },
    /// Variable use.
    var_expr: struct { name: Ident, pos: Pos },
    /// Constant boolean.
    const_bool: struct { val: bool, pos: Pos },
    /// Constant integer.
    const_int: struct { val: i128, pos: Pos },
    /// Constant primitive.
    const_prim: struct { val: Ident, pos: Pos },
    /// Let binding.
    let_expr: struct { defs: []LetDef, body: *Expr, pos: Pos },

    pub fn getPos(self: Expr) Pos {
        return switch (self) {
            .term => |t| t.pos,
            .var_expr => |v| v.pos,
            .const_bool => |c| c.pos,
            .const_int => |c| c.pos,
            .const_prim => |c| c.pos,
            .let_expr => |l| l.pos,
        };
    }
};

/// Let definition.
pub const LetDef = struct {
    var_name: Ident,
    ty: Ident,
    val: Expr,
    pos: Pos,
};

pub fn cleanupDef(allocator: Allocator, def: Def) void {
    switch (def) {
        .type_def => |td| {
            allocator.free(td.name.name);
            switch (td.ty) {
                .primitive => |p| allocator.free(p.name),
                .enum_type => |variants| {
                    for (variants) |variant| {
                        allocator.free(variant.name.name);
                        for (variant.fields) |field| {
                            allocator.free(field.name.name);
                            allocator.free(field.ty.name);
                        }
                        allocator.free(variant.fields);
                    }
                    allocator.free(variants);
                },
            }
        },
        .decl => |d| {
            allocator.free(d.term.name);
            for (d.arg_tys) |arg| {
                allocator.free(arg.name);
            }
            allocator.free(d.arg_tys);
            for (d.ret_tys) |ret_ty| {
                allocator.free(ret_ty.name);
            }
            allocator.free(d.ret_tys);
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
        .extractor => |e| {
            allocator.free(e.term.name);
            for (e.args) |arg| {
                allocator.free(arg.name);
            }
            allocator.free(e.args);
            cleanupPattern(allocator, e.template);
        },
    }
}

pub fn cleanupPattern(allocator: Allocator, pattern: Pattern) void {
    switch (pattern) {
        .var_pat => |v| allocator.free(v.var_name.name),
        .bind_pattern => |b| {
            allocator.free(b.var_name.name);
            cleanupPattern(allocator, b.subpat.*);
            allocator.destroy(b.subpat);
        },
        .term => |t| {
            allocator.free(t.sym.name);
            for (t.args) |arg| {
                cleanupPattern(allocator, arg);
            }
            allocator.free(t.args);
        },
        .const_prim => |c| allocator.free(c.val.name),
        .and_pat => |a| {
            for (a.subpats) |sub| {
                cleanupPattern(allocator, sub);
            }
            allocator.free(a.subpats);
        },
        else => {},
    }
}

pub fn cleanupExpr(allocator: Allocator, expr: Expr) void {
    switch (expr) {
        .var_expr => |v| allocator.free(v.name.name),
        .term => |t| {
            allocator.free(t.sym.name);
            for (t.args) |arg| {
                cleanupExpr(allocator, arg);
            }
            allocator.free(t.args);
        },
        .const_prim => |c| allocator.free(c.val.name),
        .let_expr => |l| {
            for (l.defs) |def| {
                allocator.free(def.var_name.name);
                allocator.free(def.ty.name);
                cleanupExpr(allocator, def.val);
            }
            allocator.free(l.defs);
            cleanupExpr(allocator, l.body.*);
            allocator.destroy(l.body);
        },
        else => {},
    }
}

test "Ident" {
    const id = Ident.init("foo", Pos.new(0, 0));
    try testing.expectEqualStrings("foo", id.name);
}

test "Pattern wildcard" {
    const pat = Pattern{ .wildcard = .{ .pos = Pos.new(0, 0) } };
    try testing.expectEqual(Pos.new(0, 0), pat.getPos());
}

test "Expr var" {
    const expr = Expr{ .var_expr = .{ .name = Ident.init("x", Pos.new(0, 0)), .pos = Pos.new(0, 0) } };
    try testing.expectEqual(Pos.new(0, 0), expr.getPos());
}
