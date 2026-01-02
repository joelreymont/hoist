const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Relocation kind for external symbols.
pub const RelocKind = enum {
    /// Absolute address (64-bit).
    abs64,
    /// Absolute address (32-bit).
    abs32,
    /// PC-relative offset (32-bit).
    pcrel32,
    /// GOT entry offset.
    got,
    /// PLT entry offset.
    plt,
};

/// External symbol reference requiring relocation.
pub const ExternalSymbol = struct {
    /// Symbol name.
    name: []const u8,
    /// Offset in code where relocation is needed.
    offset: u32,
    /// Relocation kind.
    kind: RelocKind,
    /// Addend to add to symbol address.
    addend: i64,

    pub fn init(name: []const u8, offset: u32, kind: RelocKind, addend: i64) ExternalSymbol {
        return .{
            .name = name,
            .offset = offset,
            .kind = kind,
            .addend = addend,
        };
    }
};

/// Track external symbols and relocations.
pub const RelocTable = struct {
    /// List of external symbol relocations.
    relocs: std.ArrayList(ExternalSymbol),
    /// Map from symbol name to index for deduplication.
    symbol_map: std.StringHashMap(usize),
    allocator: Allocator,

    pub fn init(allocator: Allocator) RelocTable {
        return .{
            .relocs = std.ArrayList(ExternalSymbol).init(allocator),
            .symbol_map = std.StringHashMap(usize).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RelocTable) void {
        for (self.relocs.items) |reloc| {
            self.allocator.free(reloc.name);
        }
        self.relocs.deinit();
        self.symbol_map.deinit();
    }

    /// Add external symbol relocation.
    pub fn addReloc(
        self: *RelocTable,
        name: []const u8,
        offset: u32,
        kind: RelocKind,
        addend: i64,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const reloc = ExternalSymbol.init(name_copy, offset, kind, addend);
        try self.relocs.append(reloc);

        const idx = self.relocs.items.len - 1;
        try self.symbol_map.put(name_copy, idx);
    }

    /// Get all relocations.
    pub fn relocations(self: *const RelocTable) []const ExternalSymbol {
        return self.relocs.items;
    }

    /// Find relocation by symbol name.
    pub fn findSymbol(self: *const RelocTable, name: []const u8) ?ExternalSymbol {
        const idx = self.symbol_map.get(name) orelse return null;
        return self.relocs.items[idx];
    }
};

test "RelocTable basic" {
    var table = RelocTable.init(testing.allocator);
    defer table.deinit();

    try table.addReloc("malloc", 0x100, .plt, 0);
    try table.addReloc("printf", 0x200, .plt, 0);

    const relocs = table.relocations();
    try testing.expectEqual(@as(usize, 2), relocs.len);
    try testing.expectEqualStrings("malloc", relocs[0].name);
    try testing.expectEqual(@as(u32, 0x100), relocs[0].offset);
}

test "RelocTable findSymbol" {
    var table = RelocTable.init(testing.allocator);
    defer table.deinit();

    try table.addReloc("foo", 0x50, .pcrel32, -4);

    const sym = table.findSymbol("foo").?;
    try testing.expectEqualStrings("foo", sym.name);
    try testing.expectEqual(@as(u32, 0x50), sym.offset);
    try testing.expectEqual(RelocKind.pcrel32, sym.kind);
    try testing.expectEqual(@as(i64, -4), sym.addend);

    try testing.expect(table.findSymbol("bar") == null);
}

test "ExternalSymbol init" {
    const sym = ExternalSymbol.init("test", 100, .abs64, 0);
    try testing.expectEqualStrings("test", sym.name);
    try testing.expectEqual(@as(u32, 100), sym.offset);
    try testing.expectEqual(RelocKind.abs64, sym.kind);
    try testing.expectEqual(@as(i64, 0), sym.addend);
}
