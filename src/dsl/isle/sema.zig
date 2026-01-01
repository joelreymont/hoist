const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const ast = @import("ast.zig");
const token_mod = @import("token.zig");

const Pos = token_mod.Pos;

/// Symbol ID - interned string identifier.
pub const Sym = enum(u32) {
    _,

    pub fn new(id: u32) Sym {
        return @enumFromInt(id);
    }

    pub fn index(self: Sym) u32 {
        return @intFromEnum(self);
    }
};

/// Type ID - reference to a type definition.
pub const TypeId = enum(u32) {
    _,

    pub fn new(id: u32) TypeId {
        return @enumFromInt(id);
    }

    pub fn index(self: TypeId) u32 {
        return @intFromEnum(self);
    }
};

/// Term ID - reference to a term declaration.
pub const TermId = enum(u32) {
    _,

    pub fn new(id: u32) TermId {
        return @enumFromInt(id);
    }

    pub fn index(self: TermId) u32 {
        return @intFromEnum(self);
    }
};

/// Built-in primitive types.
pub const BuiltinType = enum {
    bool,
    unit,
};

/// Type definition.
pub const Type = union(enum) {
    /// Built-in type (bool, unit).
    builtin: BuiltinType,
    /// Primitive external type.
    primitive: struct {
        id: TypeId,
        name: Sym,
        pos: Pos,
    },
    /// Sum type (enum with variants).
    enum_type: struct {
        name: Sym,
        id: TypeId,
        is_extern: bool,
        variants: []Variant,
        pos: Pos,
    },
};

/// Enum variant.
pub const Variant = struct {
    name: Sym,
    fields: []Field,
};

/// Variant field.
pub const Field = struct {
    name: Sym,
    ty: TypeId,
};

/// Term kind - constructor or extractor.
pub const TermKind = union(enum) {
    /// Decl - term that constructs or matches values.
    decl: struct {
        arg_tys: []TypeId,
        ret_ty: TypeId,
        pure: bool,
    },
    /// Extractor - macro that expands to a pattern.
    extractor: struct {
        arg_tys: []TypeId,
        ret_ty: TypeId,
        template: Pattern,
    },
    /// External function.
    extern_func: struct {
        arg_tys: []TypeId,
        ret_ty: TypeId,
    },
};

/// Term definition - constructor, extractor, or external.
pub const Term = struct {
    name: Sym,
    id: TermId,
    kind: TermKind,
    pos: Pos,
};

/// Bound variable in a pattern.
pub const BoundVar = struct {
    name: Sym,
    ty: TypeId,
    pos: Pos,
};

/// Validated if-let guard.
pub const IfLet = struct {
    pattern: Pattern,
    expr: Expr,
    pos: Pos,
};

/// Validated pattern with type information.
pub const Pattern = union(enum) {
    /// Variable binding.
    var_pat: struct {
        var_id: usize,
        name: Sym,
        ty: TypeId,
        pos: Pos,
    },
    /// Bind variable and match subpattern.
    bind_pattern: struct {
        var_id: usize,
        name: Sym,
        subpat: *Pattern,
        ty: TypeId,
        pos: Pos,
    },
    /// Boolean constant.
    const_bool: struct {
        val: bool,
        pos: Pos,
    },
    /// Integer constant.
    const_int: struct {
        val: i128,
        ty: TypeId,
        pos: Pos,
    },
    /// Constant primitive value.
    const_prim: struct {
        val: Sym,
        ty: TypeId,
        pos: Pos,
    },
    /// Term application (constructor or extractor match).
    term: struct {
        term_id: TermId,
        args: []Pattern,
        ty: TypeId,
        pos: Pos,
    },
    /// Wildcard - matches anything.
    wildcard: struct {
        ty: TypeId,
        pos: Pos,
    },
    /// And pattern - all subpatterns must match.
    and_pat: struct {
        subpats: []Pattern,
        ty: TypeId,
        pos: Pos,
    },
};

/// Validated expression with type information.
pub const Expr = union(enum) {
    /// Term construction.
    term: struct {
        term_id: TermId,
        args: []Expr,
        ty: TypeId,
        pos: Pos,
    },
    /// Variable reference.
    var_expr: struct {
        var_id: usize,
        name: Sym,
        ty: TypeId,
        pos: Pos,
    },
    /// Boolean constant.
    const_bool: struct {
        val: bool,
        pos: Pos,
    },
    /// Integer constant.
    const_int: struct {
        val: i128,
        ty: TypeId,
        pos: Pos,
    },
    /// Constant primitive value.
    const_prim: struct {
        val: Sym,
        ty: TypeId,
        pos: Pos,
    },
    /// Let binding.
    let_expr: struct {
        bindings: []LetBinding,
        body: *Expr,
        ty: TypeId,
        pos: Pos,
    },
};

/// Let binding in expression.
pub const LetBinding = struct {
    var_id: usize,
    name: Sym,
    ty: TypeId,
    val: Expr,
    pos: Pos,
};

/// Validated rule.
pub const Rule = struct {
    pattern: Pattern,
    iflets: []IfLet,
    expr: Expr,
    prio: i32,
    pos: Pos,
};

/// Type environment - symbol table and type definitions.
pub const TypeEnv = struct {
    /// Interned symbol strings.
    syms: std.ArrayList([]const u8),
    /// Map symbol string to Sym ID.
    sym_map: std.StringHashMap(Sym),
    /// Type definitions.
    types: std.ArrayList(Type),
    /// Map type name to TypeId.
    type_map: std.AutoHashMap(Sym, TypeId),
    /// Constant symbol types.
    const_types: std.AutoHashMap(Sym, TypeId),
    /// Allocator for owned data.
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .syms = std.ArrayList([]const u8){},
            .sym_map = std.StringHashMap(Sym).init(allocator),
            .types = std.ArrayList(Type){},
            .type_map = std.AutoHashMap(Sym, TypeId).init(allocator),
            .const_types = std.AutoHashMap(Sym, TypeId).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.syms.items) |sym| {
            self.allocator.free(sym);
        }
        self.syms.deinit(self.allocator);
        self.sym_map.deinit();
        self.types.deinit(self.allocator);
        self.type_map.deinit();
        self.const_types.deinit();
    }

    /// Intern a symbol string.
    pub fn internSym(self: *Self, name: []const u8) !Sym {
        if (self.sym_map.get(name)) |existing| {
            return existing;
        }

        const sym = Sym.new(@intCast(self.syms.items.len));
        const owned = try self.allocator.dupe(u8, name);
        try self.syms.append(self.allocator, owned);
        try self.sym_map.put(owned, sym);
        return sym;
    }

    /// Get symbol string.
    pub fn symName(self: *const Self, sym: Sym) []const u8 {
        return self.syms.items[sym.index()];
    }

    /// Add a type definition.
    pub fn addType(self: *Self, ty: Type) !TypeId {
        const type_id = TypeId.new(@intCast(self.types.items.len));
        try self.types.append(self.allocator, ty);

        const name_sym = switch (ty) {
            .builtin => return type_id,
            .primitive => |p| p.name,
            .enum_type => |e| e.name,
        };

        try self.type_map.put(name_sym, type_id);
        return type_id;
    }

    /// Lookup type by name.
    pub fn lookupType(self: *const Self, name: Sym) ?TypeId {
        return self.type_map.get(name);
    }

    /// Get type definition.
    pub fn getType(self: *const Self, id: TypeId) Type {
        return self.types.items[id.index()];
    }
};

/// Term environment - term declarations and extractors.
pub const TermEnv = struct {
    /// Term definitions.
    terms: std.ArrayList(Term),
    /// Map term name to TermId.
    term_map: std.AutoHashMap(Sym, TermId),
    /// Allocator.
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .terms = std.ArrayList(Term){},
            .term_map = std.AutoHashMap(Sym, TermId).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.terms.deinit(self.allocator);
        self.term_map.deinit();
    }

    /// Add a term definition.
    pub fn addTerm(self: *Self, term: Term) !TermId {
        const term_id = TermId.new(@intCast(self.terms.items.len));
        try self.terms.append(self.allocator, term);
        try self.term_map.put(term.name, term_id);
        return term_id;
    }

    /// Lookup term by name.
    pub fn lookupTerm(self: *const Self, name: Sym) ?TermId {
        return self.term_map.get(name);
    }

    /// Get term definition.
    pub fn getTerm(self: *const Self, id: TermId) Term {
        return self.terms.items[id.index()];
    }
};

test "TypeEnv symbol interning" {
    var env = TypeEnv.init(testing.allocator);
    defer env.deinit();

    const sym1 = try env.internSym("foo");
    const sym2 = try env.internSym("bar");
    const sym3 = try env.internSym("foo");

    try testing.expectEqual(sym1, sym3);
    try testing.expect(sym1.index() != sym2.index());
    try testing.expectEqualStrings("foo", env.symName(sym1));
    try testing.expectEqualStrings("bar", env.symName(sym2));
}

test "TypeEnv type registration" {
    var env = TypeEnv.init(testing.allocator);
    defer env.deinit();

    const name = try env.internSym("MyType");
    const ty = Type{ .primitive = .{
        .id = TypeId.new(0),
        .name = name,
        .pos = Pos.new(0, 0),
    } };

    const type_id = try env.addType(ty);
    const found = env.lookupType(name);

    try testing.expect(found != null);
    try testing.expectEqual(type_id, found.?);
}

test "TermEnv term registration" {
    var env = TermEnv.init(testing.allocator);
    defer env.deinit();

    const term = Term{
        .name = Sym.new(0),
        .id = TermId.new(0),
        .kind = .{ .decl = .{
            .arg_tys = &.{},
            .ret_ty = TypeId.new(0),
            .pure = true,
        } },
        .pos = Pos.new(0, 0),
    };

    const term_id = try env.addTerm(term);
    const found = env.lookupTerm(Sym.new(0));

    try testing.expect(found != null);
    try testing.expectEqual(term_id, found.?);
}
