const std = @import("std");
const Allocator = std.mem.Allocator;

const module_mod = @import("../module/module.zig");
const symbols_mod = @import("../module/symbols.zig");
const FuncId = module_mod.FuncId;
const DataId = module_mod.DataId;
const RelocTarget = symbols_mod.RelocTarget;
const ModuleReloc = symbols_mod.ModuleReloc;
const RelocKind = symbols_mod.RelocKind;

const RelocKeyTag = enum(u8) {
    user,
    libcall,
    known_sym,
};

const RelocKey = struct {
    tag: RelocKeyTag,
    a: u32,
    b: u32,
};

fn relocKey(target: RelocTarget) RelocKey {
    return switch (target) {
        .user => |u| .{ .tag = .user, .a = u.namespace, .b = u.idx },
        .func_off => |f| .{ .tag = .user, .a = 0, .b = f.func.idx },
        .libcall => |lc| .{ .tag = .libcall, .a = @intFromEnum(lc), .b = 0 },
        .known_sym => |ks| .{ .tag = .known_sym, .a = @intFromEnum(ks), .b = 0 },
    };
}

/// ELF section header.
pub const SectionHeader = struct {
    name_off: u32,
    typ: u32,
    flags: u64,
    addr: u64,
    off: u64,
    size: u64,
    link: u32,
    info: u32,
    addralign: u64,
    entsize: u64,
};

/// ELF symbol table entry.
pub const Symbol = struct {
    name_off: u32,
    info: u8,
    other: u8,
    shndx: u16,
    value: u64,
    size: u64,
};

/// ELF relocation entry (RELA format).
pub const Rela = struct {
    off: u64,
    info: u64,
    addend: i64,
};

/// ELF section kinds.
pub const SectionKind = enum {
    null,
    text,
    data,
    rodata,
    bss,
    symtab,
    strtab,
    rela_text,
    shstrtab,
};

/// Section metadata.
const Section = struct {
    kind: SectionKind,
    data: std.ArrayList(u8),
    align_: u64,
    relocs: std.ArrayList(Rela),
};

/// ELF object file writer.
pub const ElfWriter = struct {
    allocator: Allocator,
    sections: std.ArrayList(Section),
    strtab: std.ArrayList(u8),
    shstrtab: std.ArrayList(u8),
    syms: std.ArrayList(Symbol),
    sym_map: std.AutoHashMap(RelocKey, u32),
    arch: Arch,

    pub const Arch = enum {
        x86_64,
        aarch64,
    };

    pub fn init(allocator: Allocator, arch: Arch) ElfWriter {
        return .{
            .allocator = allocator,
            .sections = std.ArrayList(Section).init(allocator),
            .strtab = std.ArrayList(u8).init(allocator),
            .shstrtab = std.ArrayList(u8).init(allocator),
            .syms = std.ArrayList(Symbol).init(allocator),
            .sym_map = std.AutoHashMap(RelocKey, u32).init(allocator),
            .arch = arch,
        };
    }

    pub fn deinit(self: *ElfWriter) void {
        for (self.sections.items) |*sec| {
            sec.data.deinit();
            sec.relocs.deinit();
        }
        self.sections.deinit();
        self.strtab.deinit();
        self.shstrtab.deinit();
        self.syms.deinit();
        self.sym_map.deinit();
    }

    /// Add string to strtab and return offset.
    fn addString(self: *ElfWriter, str: []const u8) !u32 {
        if (self.strtab.items.len == 0) {
            try self.strtab.append(0);
        }
        const off: u32 = @intCast(self.strtab.items.len);
        try self.strtab.appendSlice(str);
        try self.strtab.append(0);
        return off;
    }

    /// Add string to shstrtab and return offset.
    fn addSectionName(self: *ElfWriter, name: []const u8) !u32 {
        if (self.shstrtab.items.len == 0) {
            try self.shstrtab.append(0);
        }
        const off: u32 = @intCast(self.shstrtab.items.len);
        try self.shstrtab.appendSlice(name);
        try self.shstrtab.append(0);
        return off;
    }

    fn ensureSymtabInit(self: *ElfWriter) !void {
        if (self.syms.items.len != 0) return;
        try self.syms.append(.{
            .name_off = 0,
            .info = 0,
            .other = 0,
            .shndx = 0,
            .value = 0,
            .size = 0,
        });
    }

    fn symbolName(self: *ElfWriter, target: RelocTarget, sym_table: *const symbols_mod.SymbolTable) ![]const u8 {
        _ = self;
        return switch (target) {
            .user => |u| switch (u.namespace) {
                0 => blk: {
                    const func = sym_table.getFunc(FuncId.from(u.idx)) orelse return error.InvalidFuncId;
                    break :blk func.name orelse return error.MissingFuncName;
                },
                1 => blk: {
                    const data = sym_table.getData(DataId.from(u.idx)) orelse return error.InvalidDataId;
                    break :blk data.name orelse return error.MissingDataName;
                },
                else => error.InvalidNamespace,
            },
            .func_off => |f| blk: {
                const func = sym_table.getFunc(f.func) orelse return error.InvalidFuncId;
                break :blk func.name orelse return error.MissingFuncName;
            },
            .libcall => |lc| @tagName(lc),
            .known_sym => |ks| switch (ks) {
                .elf_global_offset_table => "_GLOBAL_OFFSET_TABLE_",
                .coff_tls_index => "__tls_index",
            },
        };
    }

    fn ensureSymbol(
        self: *ElfWriter,
        target: RelocTarget,
        sym_table: *const symbols_mod.SymbolTable,
    ) !u32 {
        const key = relocKey(target);
        if (self.sym_map.get(key)) |idx| return idx;

        try self.ensureSymtabInit();
        const name = try self.symbolName(target, sym_table);
        const name_off = try self.addString(name);
        const idx: u32 = @intCast(self.syms.items.len);
        try self.syms.append(.{
            .name_off = name_off,
            .info = 0x10, // STB_GLOBAL | STT_NOTYPE
            .other = 0,
            .shndx = 0,
            .value = 0,
            .size = 0,
        });
        try self.sym_map.put(key, idx);
        return idx;
    }

    /// Create a section.
    fn createSection(self: *ElfWriter, kind: SectionKind, align_: u64) !u32 {
        const sec = Section{
            .kind = kind,
            .data = std.ArrayList(u8).init(self.allocator),
            .align_ = align_,
            .relocs = std.ArrayList(Rela).init(self.allocator),
        };
        try self.sections.append(sec);
        return @intCast(self.sections.items.len - 1);
    }

    /// Add function code to .text section.
    pub fn addFunc(
        self: *ElfWriter,
        func: FuncId,
        name: []const u8,
        code: []const u8,
        relocs: []const ModuleReloc,
        sym_table: *const symbols_mod.SymbolTable,
    ) !void {
        const name_off = try self.addString(name);
        try self.ensureSymtabInit();
        const func_key = relocKey(RelocTarget.fromFuncId(func));

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
        const func_off: u64 = @intCast(sec.data.items.len);
        try sec.data.appendSlice(code);

        // Add symbol
        if (self.sym_map.get(func_key)) |idx| {
            self.syms.items[idx] = .{
                .name_off = name_off,
                .info = 0x12, // STB_GLOBAL | STT_FUNC
                .other = 0,
                .shndx = @intCast(text_idx.? + 1), // +1 for null section
                .value = func_off,
                .size = @intCast(code.len),
            };
        } else {
            try self.syms.append(.{
                .name_off = name_off,
                .info = 0x12, // STB_GLOBAL | STT_FUNC
                .other = 0,
                .shndx = @intCast(text_idx.? + 1), // +1 for null section
                .value = func_off,
                .size = @intCast(code.len),
            });
            try self.sym_map.put(func_key, @intCast(self.syms.items.len - 1));
        }

        // Add relocations
        for (relocs) |reloc| {
            const rela = try self.makeRela(reloc, func_off, sym_table);
            try sec.relocs.append(rela);
        }
    }

    /// Convert ModuleReloc to ELF RELA.
    fn makeRela(
        self: *ElfWriter,
        reloc: ModuleReloc,
        base_off: u64,
        sym_table: *const symbols_mod.SymbolTable,
    ) !Rela {
        const sym_idx = try self.ensureSymbol(reloc.target, sym_table);
        const typ: u32 = switch (reloc.kind) {
            .abs64 => 1, // R_X86_64_64 or R_AARCH64_ABS64
            .abs32 => 10, // R_X86_64_32
            .pcrel32 => 2, // R_X86_64_PC32 or R_AARCH64_PREL32
            .got => 3, // R_X86_64_GOT32
            .plt => 4, // R_X86_64_PLT32
        };

        return .{
            .off = base_off + reloc.off,
            .info = (@as(u64, sym_idx) << 32) | @as(u64, typ),
            .addend = reloc.addend,
        };
    }

    fn alignTo(off: u64, align_: u64) u64 {
        if (align_ == 0) return off;
        const mask = align_ - 1;
        return (off + mask) & ~mask;
    }

    fn padTo(buf: *std.ArrayList(u8), off: u64) !void {
        const cur: u64 = @intCast(buf.items.len);
        if (off <= cur) return;
        const pad_len: usize = @intCast(off - cur);
        try buf.ensureUnusedCapacity(pad_len);
        const start = buf.items.len;
        buf.items.len += pad_len;
        @memset(buf.items[start..], 0);
    }

    fn writeSectionHeader(buf: *std.ArrayList(u8), sh: SectionHeader) !void {
        try buf.appendSlice(&std.mem.toBytes(sh.name_off));
        try buf.appendSlice(&std.mem.toBytes(sh.typ));
        try buf.appendSlice(&std.mem.toBytes(sh.flags));
        try buf.appendSlice(&std.mem.toBytes(sh.addr));
        try buf.appendSlice(&std.mem.toBytes(sh.off));
        try buf.appendSlice(&std.mem.toBytes(sh.size));
        try buf.appendSlice(&std.mem.toBytes(sh.link));
        try buf.appendSlice(&std.mem.toBytes(sh.info));
        try buf.appendSlice(&std.mem.toBytes(sh.addralign));
        try buf.appendSlice(&std.mem.toBytes(sh.entsize));
    }

    fn writeSymbol(buf: *std.ArrayList(u8), sym: Symbol) !void {
        try buf.appendSlice(&std.mem.toBytes(sym.name_off));
        try buf.append(sym.info);
        try buf.append(sym.other);
        try buf.appendSlice(&std.mem.toBytes(sym.shndx));
        try buf.appendSlice(&std.mem.toBytes(sym.value));
        try buf.appendSlice(&std.mem.toBytes(sym.size));
    }

    fn writeRela(buf: *std.ArrayList(u8), rela: Rela) !void {
        try buf.appendSlice(&std.mem.toBytes(rela.off));
        try buf.appendSlice(&std.mem.toBytes(rela.info));
        try buf.appendSlice(&std.mem.toBytes(rela.addend));
    }

    fn sectionName(kind: SectionKind) []const u8 {
        return switch (kind) {
            .null => "",
            .text => ".text",
            .data => ".data",
            .rodata => ".rodata",
            .bss => ".bss",
            .symtab => ".symtab",
            .strtab => ".strtab",
            .rela_text => ".rela.text",
            .shstrtab => ".shstrtab",
        };
    }

    fn relaName(kind: SectionKind) []const u8 {
        return switch (kind) {
            .text => ".rela.text",
            .data => ".rela.data",
            .rodata => ".rela.rodata",
            .bss => ".rela.bss",
            else => ".rela.text",
        };
    }

    /// Write ELF object file to buffer.
    pub fn finish(self: *ElfWriter, buf: *std.ArrayList(u8)) !void {
        try self.ensureSymtabInit();
        if (self.strtab.items.len == 0) {
            try self.strtab.append(0);
        }

        // ELF header
        try buf.appendSlice(&[_]u8{
            0x7F, 'E', 'L', 'F', // magic
            2,                   // 64-bit
            1,                   // little-endian
            1,                   // ELF version
            0,                   // SysV ABI
        });
        try buf.appendSlice(&[_]u8{0} ** 8); // padding
        try buf.appendSlice(&std.mem.toBytes(@as(u16, 1))); // ET_REL
        try buf.appendSlice(&std.mem.toBytes(@as(u16, switch (self.arch) {
            .x86_64 => 62,
            .aarch64 => 183,
        })));
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 1))); // ELF version
        try buf.appendSlice(&std.mem.toBytes(@as(u64, 0))); // entry
        try buf.appendSlice(&std.mem.toBytes(@as(u64, 0))); // phoff
        try buf.appendSlice(&std.mem.toBytes(@as(u64, 64))); // shoff (updated later)
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 0))); // flags
        try buf.appendSlice(&std.mem.toBytes(@as(u16, 64))); // ehsize
        try buf.appendSlice(&std.mem.toBytes(@as(u16, 0))); // phentsize
        try buf.appendSlice(&std.mem.toBytes(@as(u16, 0))); // phnum
        try buf.appendSlice(&std.mem.toBytes(@as(u16, 64))); // shentsize
        try buf.appendSlice(&std.mem.toBytes(@as(u16, 0))); // shnum (updated later)
        try buf.appendSlice(&std.mem.toBytes(@as(u16, 0))); // shstrndx (updated later)

        const SHT_PROGBITS: u32 = 1;
        const SHT_SYMTAB: u32 = 2;
        const SHT_STRTAB: u32 = 3;
        const SHT_RELA: u32 = 4;
        const SHT_NOBITS: u32 = 8;
        const SHF_WRITE: u64 = 0x1;
        const SHF_ALLOC: u64 = 0x2;
        const SHF_EXECINSTR: u64 = 0x4;

        const SecOut = struct {
            name_off: u32,
            typ: u32,
            flags: u64,
            align_: u64,
            data: []const u8,
            size: u64,
            link: u32,
            info: u32,
            entsize: u64,
            is_nobits: bool,
            relocs: ?[]const Rela,
        };

        var out_sections = std.ArrayList(SecOut).init(self.allocator);
        defer out_sections.deinit();

        var rela_sections = std.ArrayList(struct {
            name_off: u32,
            relocs: []const Rela,
            info: u32,
        }).init(self.allocator);
        defer rela_sections.deinit();

        const data_count: u32 = @intCast(self.sections.items.len);
        var i: u32 = 0;
        while (i < data_count) : (i += 1) {
            const sec = self.sections.items[i];
            const name = sectionName(sec.kind);
            const name_off = try self.addSectionName(name);
            const sec_flags: u64 = switch (sec.kind) {
                .text => SHF_ALLOC | SHF_EXECINSTR,
                .data => SHF_ALLOC | SHF_WRITE,
                .rodata => SHF_ALLOC,
                .bss => SHF_ALLOC | SHF_WRITE,
                else => 0,
            };
            const typ: u32 = switch (sec.kind) {
                .bss => SHT_NOBITS,
                else => SHT_PROGBITS,
            };
            try out_sections.append(.{
                .name_off = name_off,
                .typ = typ,
                .flags = sec_flags,
                .align_ = sec.align_,
                .data = sec.data.items,
                .size = @intCast(sec.data.items.len),
                .link = 0,
                .info = 0,
                .entsize = 0,
                .is_nobits = sec.kind == .bss,
                .relocs = null,
            });

            if (sec.relocs.items.len != 0) {
                const rela_name = relaName(sec.kind);
                const rela_name_off = try self.addSectionName(rela_name);
                try rela_sections.append(.{
                    .name_off = rela_name_off,
                    .relocs = sec.relocs.items,
                    .info = i + 1, // target section index (null section = 0)
                });
            }
        }

        const rela_base: u32 = 1 + data_count;
        const symtab_idx: u32 = rela_base + @intCast(rela_sections.items.len);
        const strtab_idx: u32 = symtab_idx + 1;
        const shstrtab_idx: u32 = symtab_idx + 2;

        for (rela_sections.items) |rela_sec| {
            try out_sections.append(.{
                .name_off = rela_sec.name_off,
                .typ = SHT_RELA,
                .flags = 0,
                .align_ = 8,
                .data = &.{},
                .size = @intCast(rela_sec.relocs.len * @sizeOf(Rela)),
                .link = symtab_idx,
                .info = rela_sec.info,
                .entsize = @sizeOf(Rela),
                .is_nobits = false,
                .relocs = rela_sec.relocs,
            });
        }

        const symtab_name_off = try self.addSectionName(sectionName(.symtab));
        const strtab_name_off = try self.addSectionName(sectionName(.strtab));
        const shstrtab_name_off = try self.addSectionName(sectionName(.shstrtab));

        try out_sections.append(.{
            .name_off = symtab_name_off,
            .typ = SHT_SYMTAB,
            .flags = 0,
            .align_ = 8,
            .data = &.{},
            .size = @intCast(self.syms.items.len * @sizeOf(Symbol)),
            .link = strtab_idx,
            .info = 1,
            .entsize = @sizeOf(Symbol),
            .is_nobits = false,
            .relocs = null,
        });
        try out_sections.append(.{
            .name_off = strtab_name_off,
            .typ = SHT_STRTAB,
            .flags = 0,
            .align_ = 1,
            .data = self.strtab.items,
            .size = @intCast(self.strtab.items.len),
            .link = 0,
            .info = 0,
            .entsize = 0,
            .is_nobits = false,
            .relocs = null,
        });
        try out_sections.append(.{
            .name_off = shstrtab_name_off,
            .typ = SHT_STRTAB,
            .flags = 0,
            .align_ = 1,
            .data = self.shstrtab.items,
            .size = @intCast(self.shstrtab.items.len),
            .link = 0,
            .info = 0,
            .entsize = 0,
            .is_nobits = false,
            .relocs = null,
        });

        // Write section data
        var sec_offsets = std.ArrayList(u64).init(self.allocator);
        defer sec_offsets.deinit();

        var off: u64 = @intCast(buf.items.len);
        for (out_sections.items) |sec| {
            off = alignTo(off, sec.align_);
            try padTo(buf, off);
            try sec_offsets.append(off);

            if (sec.typ == SHT_SYMTAB) {
                for (self.syms.items) |sym| try writeSymbol(buf, sym);
                off += @intCast(self.syms.items.len * @sizeOf(Symbol));
                continue;
            }
            if (sec.relocs) |rels| {
                for (rels) |rel| try writeRela(buf, rel);
                off += @intCast(rels.len * @sizeOf(Rela));
                continue;
            }
            if (!sec.is_nobits and sec.data.len != 0) {
                try buf.appendSlice(sec.data);
                off += @intCast(sec.data.len);
            }
        }

        const shoff = alignTo(off, 8);
        try padTo(buf, shoff);

        // Section headers
        try writeSectionHeader(buf, .{
            .name_off = 0,
            .typ = 0,
            .flags = 0,
            .addr = 0,
            .off = 0,
            .size = 0,
            .link = 0,
            .info = 0,
            .addralign = 0,
            .entsize = 0,
        });
        for (out_sections.items, 0..) |sec, idx| {
            const sec_off = sec_offsets.items[idx];
            try writeSectionHeader(buf, .{
                .name_off = sec.name_off,
                .typ = sec.typ,
                .flags = sec.flags,
                .addr = 0,
                .off = sec_off,
                .size = sec.size,
                .link = sec.link,
                .info = sec.info,
                .addralign = sec.align_,
                .entsize = sec.entsize,
            });
        }

        const shnum: u16 = @intCast(out_sections.items.len + 1);
        const shstrndx: u16 = @intCast(shstrtab_idx);

        std.mem.writeInt(u64, buf.items[40..48], shoff, .little);
        std.mem.writeInt(u16, buf.items[58..60], shnum, .little);
        std.mem.writeInt(u16, buf.items[60..62], shstrndx, .little);
    }
};

test "ElfWriter init" {
    const allocator = std.testing.allocator;
    var writer = ElfWriter.init(allocator, .x86_64);
    defer writer.deinit();
}

test "ElfWriter resolves reloc target" {
    const allocator = std.testing.allocator;
    var symtab = symbols_mod.SymbolTable.init(allocator);
    defer symtab.deinit();
    const func = try symtab.declareFunc("foo", module_mod.Linkage.@"export");

    var writer = ElfWriter.init(allocator, .x86_64);
    defer writer.deinit();

    const relocs = [_]ModuleReloc{.{
        .off = 0,
        .kind = .abs64,
        .target = RelocTarget.fromFuncId(func),
        .addend = 0,
    }};
    try writer.addFunc(func, "foo", &[_]u8{0xC3}, &relocs, &symtab);

    const sec = &writer.sections.items[0];
    const sym_idx: u32 = @intCast(sec.relocs.items[0].info >> 32);
    try std.testing.expectEqual(@as(u32, 1), sym_idx);
}
