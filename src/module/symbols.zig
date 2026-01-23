const std = @import("std");
const Allocator = std.mem.Allocator;

const module_mod = @import("module.zig");
const FuncId = module_mod.FuncId;
const DataId = module_mod.DataId;
const FuncOrDataId = module_mod.FuncOrDataId;

const types = @import("../ir/types.zig");
const ir = @import("../ir/ir.zig");

/// Relocation target for module symbols.
pub const RelocTarget = union(enum) {
    /// User-defined function or data.
    user: struct {
        namespace: u32,
        idx: u32,
    },
    /// Library call (e.g., memcpy, floor).
    libcall: ir.LibCall,
    /// Known linker symbol (e.g., __stack_chk_guard).
    known_sym: ir.KnownSymbol,
    /// Offset within a function.
    func_off: struct {
        func: FuncId,
        off: u32,
    },

    pub fn userDef(namespace: u32, idx: u32) RelocTarget {
        return .{ .user = .{ .namespace = namespace, .idx = idx } };
    }

    pub fn fromFuncId(func: FuncId) RelocTarget {
        return userDef(0, func.idx);
    }

    pub fn fromDataId(data: DataId) RelocTarget {
        return userDef(1, data.idx);
    }

    pub fn isFunction(self: RelocTarget) bool {
        return switch (self) {
            .user => |u| u.namespace == 0,
            .libcall, .known_sym, .func_off => true,
        };
    }
};

/// Module relocation entry.
pub const ModuleReloc = struct {
    /// Offset in code section.
    off: u32,
    /// Relocation kind (see machinst/reloc.zig).
    kind: RelocKind,
    /// Target symbol.
    target: RelocTarget,
    /// Addend.
    addend: i64,
};

/// Relocation kind.
pub const RelocKind = enum {
    abs64,
    abs32,
    pcrel32,
    got,
    plt,
};

/// Function declaration metadata.
pub const FuncDecl = struct {
    /// Optional name.
    name: ?[]const u8,
    /// Linkage type.
    linkage: module_mod.Linkage,
    /// Compiled code size.
    size: u32,
    /// Code offset in output buffer.
    off: u32,
    /// Relocations.
    relocs: std.ArrayList(ModuleReloc),

    pub fn init(allocator: Allocator, name: ?[]const u8, linkage: module_mod.Linkage) !FuncDecl {
        return .{
            .name = if (name) |n| try allocator.dupe(u8, n) else null,
            .linkage = linkage,
            .size = 0,
            .off = 0,
            .relocs = std.ArrayList(ModuleReloc).init(allocator),
        };
    }

    pub fn deinit(self: *FuncDecl, allocator: Allocator) void {
        if (self.name) |n| allocator.free(n);
        self.relocs.deinit();
    }
};

/// Data object declaration metadata.
pub const DataDecl = struct {
    /// Optional name.
    name: ?[]const u8,
    /// Linkage type.
    linkage: module_mod.Linkage,
    /// Data size.
    size: u32,
    /// Data offset in output buffer.
    off: u32,
    /// Relocations.
    relocs: std.ArrayList(ModuleReloc),

    pub fn init(allocator: Allocator, name: ?[]const u8, linkage: module_mod.Linkage) !DataDecl {
        return .{
            .name = if (name) |n| try allocator.dupe(u8, n) else null,
            .linkage = linkage,
            .size = 0,
            .off = 0,
            .relocs = std.ArrayList(ModuleReloc).init(allocator),
        };
    }

    pub fn deinit(self: *DataDecl, allocator: Allocator) void {
        if (self.name) |n| allocator.free(n);
        self.relocs.deinit();
    }
};

/// Symbol table for module linking.
pub const SymbolTable = struct {
    /// Function declarations indexed by FuncId.
    funcs: std.ArrayList(FuncDecl),
    /// Data declarations indexed by DataId.
    data: std.ArrayList(DataDecl),
    /// Name to FuncOrDataId map.
    names: std.StringHashMap(FuncOrDataId),
    allocator: Allocator,

    pub fn init(allocator: Allocator) SymbolTable {
        return .{
            .funcs = std.ArrayList(FuncDecl).init(allocator),
            .data = std.ArrayList(DataDecl).init(allocator),
            .names = std.StringHashMap(FuncOrDataId).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SymbolTable) void {
        for (self.funcs.items) |*f| f.deinit(self.allocator);
        for (self.data.items) |*d| d.deinit(self.allocator);
        self.funcs.deinit();
        self.data.deinit();
        var it = self.names.keyIterator();
        while (it.next()) |k| self.allocator.free(k.*);
        self.names.deinit();
    }

    /// Declare a function.
    pub fn declareFunc(
        self: *SymbolTable,
        name: ?[]const u8,
        linkage: module_mod.Linkage,
    ) !FuncId {
        const func = try FuncDecl.init(self.allocator, name, linkage);
        try self.funcs.append(func);
        const id = FuncId.from(@intCast(self.funcs.items.len - 1));

        if (name) |n| {
            const key = try self.allocator.dupe(u8, n);
            try self.names.put(key, .{ .func = id });
        }

        return id;
    }

    /// Declare a data object.
    pub fn declareData(
        self: *SymbolTable,
        name: ?[]const u8,
        linkage: module_mod.Linkage,
    ) !DataId {
        const data_decl = try DataDecl.init(self.allocator, name, linkage);
        try self.data.append(data_decl);
        const id = DataId.from(@intCast(self.data.items.len - 1));

        if (name) |n| {
            const key = try self.allocator.dupe(u8, n);
            try self.names.put(key, .{ .data = id });
        }

        return id;
    }

    /// Get function declaration.
    pub fn getFunc(self: *const SymbolTable, id: FuncId) ?*const FuncDecl {
        if (id.idx >= self.funcs.items.len) return null;
        return &self.funcs.items[id.idx];
    }

    /// Get data declaration.
    pub fn getData(self: *const SymbolTable, id: DataId) ?*const DataDecl {
        if (id.idx >= self.data.items.len) return null;
        return &self.data.items[id.idx];
    }

    /// Get function declaration mutably.
    pub fn getFuncMut(self: *SymbolTable, id: FuncId) ?*FuncDecl {
        if (id.idx >= self.funcs.items.len) return null;
        return &self.funcs.items[id.idx];
    }

    /// Get data declaration mutably.
    pub fn getDataMut(self: *SymbolTable, id: DataId) ?*DataDecl {
        if (id.idx >= self.data.items.len) return null;
        return &self.data.items[id.idx];
    }

    /// Lookup symbol by name.
    pub fn lookup(self: *const SymbolTable, name: []const u8) ?FuncOrDataId {
        return self.names.get(name);
    }
};

test "SymbolTable declare function" {
    const allocator = std.testing.allocator;
    var st = SymbolTable.init(allocator);
    defer st.deinit();

    const f0 = try st.declareFunc("foo", .@"export");
    try std.testing.expectEqual(@as(u32, 0), f0.idx);

    const f1 = try st.declareFunc(null, .local);
    try std.testing.expectEqual(@as(u32, 1), f1.idx);

    const found = st.lookup("foo");
    try std.testing.expect(found != null);
    try std.testing.expectEqual(f0.idx, found.?.func.idx);
}

test "SymbolTable declare data" {
    const allocator = std.testing.allocator;
    var st = SymbolTable.init(allocator);
    defer st.deinit();

    const d0 = try st.declareData("data", .@"export");
    try std.testing.expectEqual(@as(u32, 0), d0.idx);

    const found = st.lookup("data");
    try std.testing.expect(found != null);
    try std.testing.expectEqual(d0.idx, found.?.data.idx);
}
