const std = @import("std");
const Allocator = std.mem.Allocator;

const module_mod = @import("../module/module.zig");
const symbols_mod = @import("../module/symbols.zig");
const obj_reloc = @import("reloc.zig");
const FuncId = module_mod.FuncId;
const ModuleReloc = symbols_mod.ModuleReloc;
const RelocKind = symbols_mod.RelocKind;
const SymKind = obj_reloc.SymKind;

/// COFF section header.
pub const SectionHeader = struct {
    name: [8]u8,
    virt_size: u32,
    virt_addr: u32,
    raw_size: u32,
    raw_off: u32,
    reloc_off: u32,
    line_off: u32,
    n_reloc: u16,
    n_line: u16,
    flags: u32,
};

/// COFF symbol table entry.
pub const Symbol = struct {
    name: [8]u8,
    value: u32,
    section: i16,
    typ: u16,
    storage_class: u8,
    n_aux: u8,
};

/// COFF relocation entry.
pub const Relocation = struct {
    virt_addr: u32,
    sym_idx: u32,
    typ: u16,
};

/// COFF section kinds.
pub const SectionKind = enum {
    text,
    data,
    bss,
};

/// Section metadata.
const Section = struct {
    kind: SectionKind,
    data: std.ArrayList(u8),
    align_: u32,
    relocs: std.ArrayList(Relocation),
};

/// COFF object file writer.
pub const CoffWriter = struct {
    allocator: Allocator,
    sections: std.ArrayList(Section),
    strtab: std.ArrayList(u8),
    syms: std.ArrayList(Symbol),
    sym_map: std.StringHashMap(u32),
    arch: Arch,

    pub const Arch = enum {
        x86_64,
        aarch64,
    };

    pub fn init(allocator: Allocator, arch: Arch) CoffWriter {
        return .{
            .allocator = allocator,
            .sections = std.ArrayList(Section).init(allocator),
            .strtab = std.ArrayList(u8).init(allocator),
            .syms = std.ArrayList(Symbol).init(allocator),
            .sym_map = std.StringHashMap(u32).init(allocator),
            .arch = arch,
        };
    }

    pub fn deinit(self: *CoffWriter) void {
        for (self.sections.items) |*sec| {
            sec.data.deinit();
            sec.relocs.deinit();
        }
        self.sections.deinit();
        self.strtab.deinit();
        self.syms.deinit();
        var it = self.sym_map.keyIterator();
        while (it.next()) |key| self.allocator.free(key.*);
        self.sym_map.deinit();
    }

    /// Add string to strtab and return offset.
    fn addString(self: *CoffWriter, str: []const u8) !u32 {
        const off: u32 = @intCast(self.strtab.items.len + 4); // +4 for size prefix
        try self.strtab.appendSlice(str);
        try self.strtab.append(0);
        return off;
    }

    fn buildSymName(self: *CoffWriter, name: []const u8) ![8]u8 {
        var sym_name: [8]u8 = [_]u8{0} ** 8;
        if (name.len <= 8) {
            @memcpy(sym_name[0..name.len], name);
        } else {
            const str_off = try self.addString(name);
            std.mem.writeInt(u32, sym_name[4..8], str_off, .little);
        }
        return sym_name;
    }

    fn sectionName(kind: SectionKind) []const u8 {
        return switch (kind) {
            .text => ".text",
            .data => ".data",
            .bss => ".bss",
        };
    }

    fn sectionNameBytes(kind: SectionKind) [8]u8 {
        var name_buf: [8]u8 = [_]u8{0} ** 8;
        const name = sectionName(kind);
        @memcpy(name_buf[0..name.len], name);
        return name_buf;
    }

    fn alignFlag(align_: u32) u32 {
        return switch (align_) {
            0, 1 => 0x00100000, // IMAGE_SCN_ALIGN_1BYTES
            2 => 0x00200000,
            4 => 0x00300000,
            8 => 0x00400000,
            16 => 0x00500000,
            32 => 0x00600000,
            64 => 0x00700000,
            128 => 0x00800000,
            256 => 0x00900000,
            512 => 0x00A00000,
            1024 => 0x00B00000,
            2048 => 0x00C00000,
            4096 => 0x00D00000,
            8192 => 0x00E00000,
            else => 0,
        };
    }

    fn sectionFlags(kind: SectionKind, align_: u32) u32 {
        const base: u32 = switch (kind) {
            .text => 0x00000020 | 0x20000000 | 0x40000000, // CNT_CODE | MEM_EXECUTE | MEM_READ
            .data => 0x00000040 | 0x40000000 | 0x80000000, // CNT_INITIALIZED_DATA | MEM_READ | MEM_WRITE
            .bss => 0x00000080 | 0x40000000 | 0x80000000, // CNT_UNINITIALIZED_DATA | MEM_READ | MEM_WRITE
        };
        return base | alignFlag(align_);
    }

    fn alignTo(off: u32, align_: u32) u32 {
        if (align_ <= 1) return off;
        const mask = align_ - 1;
        return (off + mask) & ~mask;
    }

    fn padTo(buf: *std.ArrayList(u8), off: u32) !void {
        const cur: u32 = @intCast(buf.items.len);
        if (off <= cur) return;
        const pad_len: usize = @intCast(off - cur);
        try buf.ensureUnusedCapacity(pad_len);
        const start = buf.items.len;
        buf.items.len += pad_len;
        @memset(buf.items[start..], 0);
    }

    fn writeSectionHeader(buf: *std.ArrayList(u8), sh: SectionHeader) !void {
        try buf.appendSlice(&sh.name);
        try buf.appendSlice(&std.mem.toBytes(sh.virt_size));
        try buf.appendSlice(&std.mem.toBytes(sh.virt_addr));
        try buf.appendSlice(&std.mem.toBytes(sh.raw_size));
        try buf.appendSlice(&std.mem.toBytes(sh.raw_off));
        try buf.appendSlice(&std.mem.toBytes(sh.reloc_off));
        try buf.appendSlice(&std.mem.toBytes(sh.line_off));
        try buf.appendSlice(&std.mem.toBytes(sh.n_reloc));
        try buf.appendSlice(&std.mem.toBytes(sh.n_line));
        try buf.appendSlice(&std.mem.toBytes(sh.flags));
    }

    fn writeRelocation(buf: *std.ArrayList(u8), rel: Relocation) !void {
        try buf.appendSlice(&std.mem.toBytes(rel.virt_addr));
        try buf.appendSlice(&std.mem.toBytes(rel.sym_idx));
        try buf.appendSlice(&std.mem.toBytes(rel.typ));
    }

    fn writeSymbol(buf: *std.ArrayList(u8), sym: Symbol) !void {
        try buf.appendSlice(&sym.name);
        try buf.appendSlice(&std.mem.toBytes(sym.value));
        try buf.appendSlice(&std.mem.toBytes(sym.section));
        try buf.appendSlice(&std.mem.toBytes(sym.typ));
        try buf.append(sym.storage_class);
        try buf.append(sym.n_aux);
    }

    fn storageClass(linkage: module_mod.Linkage) u8 {
        return switch (linkage) {
            .local => 3, // IMAGE_SYM_CLASS_STATIC
            .@"export", .import => 2, // IMAGE_SYM_CLASS_EXTERNAL
        };
    }

    fn symType(kind: SymKind) u16 {
        return switch (kind) {
            .func => 0x20,
            .data, .tls, .unknown => 0,
        };
    }

    fn defineSymbol(
        self: *CoffWriter,
        name: []const u8,
        kind: SymKind,
        linkage: module_mod.Linkage,
        section: i16,
        value: u32,
    ) !u32 {
        if (self.sym_map.get(name)) |idx| {
            const sym_name = self.syms.items[idx].name;
            self.syms.items[idx] = .{
                .name = sym_name,
                .value = value,
                .section = section,
                .typ = symType(kind),
                .storage_class = storageClass(linkage),
                .n_aux = 0,
            };
            return idx;
        }

        const sym_name = try self.buildSymName(name);
        const idx: u32 = @intCast(self.syms.items.len);
        try self.syms.append(.{
            .name = sym_name,
            .value = value,
            .section = section,
            .typ = symType(kind),
            .storage_class = storageClass(linkage),
            .n_aux = 0,
        });
        const key = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key);
        try self.sym_map.put(key, idx);
        return idx;
    }

    fn ensureSymbol(
        self: *CoffWriter,
        name: []const u8,
        kind: SymKind,
        linkage: module_mod.Linkage,
    ) !u32 {
        if (self.sym_map.get(name)) |idx| return idx;
        const sym_name = try self.buildSymName(name);
        const idx: u32 = @intCast(self.syms.items.len);
        try self.syms.append(.{
            .name = sym_name,
            .value = 0,
            .section = 0, // undefined
            .typ = symType(kind),
            .storage_class = storageClass(linkage),
            .n_aux = 0,
        });
        const key = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key);
        try self.sym_map.put(key, idx);
        return idx;
    }

    fn applyAddend(self: *CoffWriter, data: []u8, off: u32, kind: RelocKind, addend: i64) !void {
        _ = self;
        if (addend == 0) return;
        const offset: usize = @intCast(off);
        const size: usize = switch (kind) {
            .abs64 => 8,
            .abs32, .pcrel32, .got, .plt => 4,
        };
        if (offset + size > data.len) return error.RelocOutOfBounds;
        if (size == 8) {
            const base = std.mem.readInt(u64, data[offset .. offset + 8], .little);
            const sum: i128 = @as(i128, @intCast(base)) + addend;
            if (sum < std.math.minInt(i64) or sum > std.math.maxInt(i64)) return error.RelocAddendOverflow;
            const bits: u64 = @bitCast(@as(i64, @intCast(sum)));
            std.mem.writeInt(u64, data[offset .. offset + 8], bits, .little);
            return;
        }
        const base32 = std.mem.readInt(u32, data[offset .. offset + 4], .little);
        const sum32: i128 = @as(i128, @intCast(base32)) + addend;
        if (sum32 < std.math.minInt(i32) or sum32 > std.math.maxInt(i32)) return error.RelocAddendOverflow;
        const bits32: u32 = @bitCast(@as(i32, @intCast(sum32)));
        std.mem.writeInt(u32, data[offset .. offset + 4], bits32, .little);
    }

    fn relocType(self: *CoffWriter, kind: RelocKind) !u16 {
        return switch (self.arch) {
            .x86_64 => switch (kind) {
                .abs64 => 1, // IMAGE_REL_AMD64_ADDR64
                .abs32 => 2, // IMAGE_REL_AMD64_ADDR32
                .pcrel32, .got, .plt => 4, // IMAGE_REL_AMD64_REL32
            },
            .aarch64 => switch (kind) {
                .abs64 => 1, // IMAGE_REL_ARM64_ADDR64
                .abs32 => 2, // IMAGE_REL_ARM64_ADDR32
                .pcrel32, .got, .plt => return error.UnsupportedRelocation,
            },
        };
    }

    /// Create a section.
    fn createSection(self: *CoffWriter, kind: SectionKind, align_: u32) !u32 {
        const sec = Section{
            .kind = kind,
            .data = std.ArrayList(u8).init(self.allocator),
            .align_ = align_,
            .relocs = std.ArrayList(Relocation).init(self.allocator),
        };
        try self.sections.append(sec);
        return @intCast(self.sections.items.len - 1);
    }

    /// Add function code to .text section.
    pub fn addFunc(
        self: *CoffWriter,
        func: FuncId,
        name: []const u8,
        code: []const u8,
        relocs: []const ModuleReloc,
        sym_table: *const symbols_mod.SymbolTable,
    ) !void {
        const func_decl = sym_table.getFunc(func) orelse return error.InvalidFuncId;
        const linkage = func_decl.linkage;
        // Find or create .text section
        var text_idx: ?u32 = null;
        for (self.sections.items, 0..) |*sec, i| {
            if (sec.kind == .text) {
                text_idx = @intCast(i);
                break;
            }
        }
        if (text_idx == null) {
            text_idx = try self.createSection(.text, 16);
        }

        var sec = &self.sections.items[text_idx.?];
        const func_off: u32 = @intCast(sec.data.items.len);
        try sec.data.appendSlice(code);

        _ = try self.defineSymbol(
            name,
            .func,
            linkage,
            @intCast(text_idx.? + 1),
            func_off,
        );

        // Add relocations
        for (relocs) |reloc| {
            const rel = try self.makeRelocation(reloc, func_off, sym_table, sec.data.items);
            try sec.relocs.append(rel);
        }
    }

    /// Convert ModuleReloc to COFF relocation.
    fn makeRelocation(
        self: *CoffWriter,
        reloc: ModuleReloc,
        base_off: u32,
        sym_table: *const symbols_mod.SymbolTable,
        data: []u8,
    ) !Relocation {
        const target = try obj_reloc.resolveTarget(sym_table, reloc.target);
        const sym_idx = try self.ensureSymbol(target.name, target.kind, target.linkage);
        const addend = reloc.addend + target.addend;
        try self.applyAddend(data, base_off + reloc.off, reloc.kind, addend);
        const typ = try self.relocType(reloc.kind);

        return .{
            .virt_addr = base_off + reloc.off,
            .sym_idx = sym_idx,
            .typ = typ,
        };
    }

    /// Write COFF object file to buffer.
    pub fn finish(self: *CoffWriter, buf: *std.ArrayList(u8)) !void {
        // COFF header
        try buf.appendSlice(&std.mem.toBytes(@as(u16, switch (self.arch) {
            .x86_64 => 0x8664, // IMAGE_FILE_MACHINE_AMD64
            .aarch64 => 0xAA64, // IMAGE_FILE_MACHINE_ARM64
        })));
        try buf.appendSlice(&std.mem.toBytes(@as(u16, 0))); // n_sections (updated later)
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 0))); // timestamp
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 0))); // symtab_off (updated later)
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 0))); // n_syms (updated later)
        try buf.appendSlice(&std.mem.toBytes(@as(u16, 0))); // opt_hdr_size
        try buf.appendSlice(&std.mem.toBytes(@as(u16, 0))); // flags

        const header_size: u32 = 20;
        const sec_hdr_size: u32 = 40;
        const n_sections: u16 = @intCast(self.sections.items.len);

        var headers = std.ArrayList(SectionHeader).init(self.allocator);
        defer headers.deinit();

        var off: u32 = header_size + @as(u32, n_sections) * sec_hdr_size;
        for (self.sections.items) |sec| {
            off = alignTo(off, sec.align_);
            const raw_off: u32 = if (sec.kind == .bss) 0 else off;
            const raw_size: u32 = if (sec.kind == .bss) 0 else @intCast(sec.data.items.len);
            if (sec.kind != .bss) {
                off += raw_size;
            }
            try headers.append(.{
                .name = sectionNameBytes(sec.kind),
                .virt_size = raw_size,
                .virt_addr = 0,
                .raw_size = raw_size,
                .raw_off = raw_off,
                .reloc_off = 0,
                .line_off = 0,
                .n_reloc = 0,
                .n_line = 0,
                .flags = sectionFlags(sec.kind, sec.align_),
            });
        }

        var reloc_off: u32 = off;
        for (self.sections.items, 0..) |sec, i| {
            if (sec.relocs.items.len == 0) continue;
            reloc_off = alignTo(reloc_off, 4);
            headers.items[i].reloc_off = reloc_off;
            headers.items[i].n_reloc = @intCast(sec.relocs.items.len);
            reloc_off += @intCast(sec.relocs.items.len * 10);
        }

        const symtab_off: u32 = reloc_off;
        const n_syms: u32 = @intCast(self.syms.items.len);
        const symtab_size: u32 = n_syms * 18;
        const strtab_off: u32 = symtab_off + symtab_size;
        const strtab_size: u32 = @intCast(self.strtab.items.len + 4);

        // Section headers
        for (headers.items) |sh| {
            try writeSectionHeader(buf, sh);
        }

        // Section data
        for (self.sections.items, 0..) |sec, i| {
            if (headers.items[i].raw_off == 0) continue;
            try padTo(buf, headers.items[i].raw_off);
            if (sec.data.items.len != 0) {
                try buf.appendSlice(sec.data.items);
            }
        }

        // Relocations
        for (self.sections.items, 0..) |sec, i| {
            if (headers.items[i].n_reloc == 0) continue;
            try padTo(buf, headers.items[i].reloc_off);
            for (sec.relocs.items) |rel| try writeRelocation(buf, rel);
        }

        // Symbol table
        try padTo(buf, symtab_off);
        for (self.syms.items) |sym| try writeSymbol(buf, sym);

        // String table
        try padTo(buf, strtab_off);
        try buf.appendSlice(&std.mem.toBytes(strtab_size));
        if (self.strtab.items.len != 0) {
            try buf.appendSlice(self.strtab.items);
        }

        std.mem.writeInt(u16, buf.items[2..4], n_sections, .little);
        std.mem.writeInt(u32, buf.items[8..12], symtab_off, .little);
        std.mem.writeInt(u32, buf.items[12..16], n_syms, .little);
    }
};

test "CoffWriter init" {
    const allocator = std.testing.allocator;
    var writer = CoffWriter.init(allocator, .x86_64);
    defer writer.deinit();
}

test "CoffWriter resolves reloc target" {
    const allocator = std.testing.allocator;
    var symtab = symbols_mod.SymbolTable.init(allocator);
    defer symtab.deinit();
    const func = try symtab.declareFunc("foo", module_mod.Linkage.@"export");

    var writer = CoffWriter.init(allocator, .x86_64);
    defer writer.deinit();

    const relocs = [_]ModuleReloc{.{
        .off = 0,
        .kind = .abs64,
        .target = symbols_mod.RelocTarget.fromFuncId(func),
        .addend = 0,
    }};
    try writer.addFunc(func, "foo", &[_]u8{0xC3}, &relocs, &symtab);

    const sec = &writer.sections.items[0];
    try std.testing.expectEqual(@as(u32, 0), sec.relocs.items[0].sym_idx);
}

test "CoffWriter finish basic" {
    const allocator = std.testing.allocator;
    var symtab = symbols_mod.SymbolTable.init(allocator);
    defer symtab.deinit();
    const func = try symtab.declareFunc("foo", module_mod.Linkage.@"export");

    var writer = CoffWriter.init(allocator, .x86_64);
    defer writer.deinit();

    try writer.addFunc(func, "foo", &[_]u8{0xC3}, &[_]ModuleReloc{}, &symtab);

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try writer.finish(&buf);

    const n_sections = std.mem.readInt(u16, buf.items[2..4], .little);
    const symtab_off = std.mem.readInt(u32, buf.items[8..12], .little);
    const n_syms = std.mem.readInt(u32, buf.items[12..16], .little);
    try std.testing.expect(n_sections > 0);
    try std.testing.expect(n_syms > 0);
    try std.testing.expect(@as(usize, symtab_off) < buf.items.len);
}
