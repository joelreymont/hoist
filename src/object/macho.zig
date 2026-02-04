const std = @import("std");
const Allocator = std.mem.Allocator;

const module_mod = @import("../module/module.zig");
const symbols_mod = @import("../module/symbols.zig");
const obj_reloc = @import("reloc.zig");
const FuncId = module_mod.FuncId;
const ModuleReloc = symbols_mod.ModuleReloc;
const RelocKind = symbols_mod.RelocKind;

/// Mach-O section header (64-bit).
pub const Section64 = struct {
    sectname: [16]u8,
    segname: [16]u8,
    addr: u64,
    size: u64,
    off: u32,
    align_: u32,
    reloff: u32,
    nreloc: u32,
    flags: u32,
    reserved1: u32,
    reserved2: u32,
    reserved3: u32,
};

/// Mach-O symbol table entry (64-bit).
pub const Nlist64 = struct {
    n_strx: u32,
    n_type: u8,
    n_sect: u8,
    n_desc: u16,
    n_value: u64,
};

/// Mach-O relocation entry.
pub const RelocInfo = struct {
    r_address: i32,
    r_symbolnum: u32,
    r_pcrel: bool,
    r_length: u8,
    r_extern: bool,
    r_type: u8,
};

/// Mach-O section kinds.
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
    relocs: std.ArrayList(RelocInfo),
};

/// Mach-O object file writer.
pub const MachoWriter = struct {
    allocator: Allocator,
    sections: std.ArrayList(Section),
    strtab: std.ArrayList(u8),
    syms: std.ArrayList(Nlist64),
    sym_map: std.StringHashMap(u32),
    arch: Arch,

    pub const Arch = enum {
        x86_64,
        aarch64,
    };

    pub fn init(allocator: Allocator, arch: Arch) MachoWriter {
        return .{
            .allocator = allocator,
            .sections = std.ArrayList(Section).init(allocator),
            .strtab = std.ArrayList(u8).init(allocator),
            .syms = std.ArrayList(Nlist64).init(allocator),
            .sym_map = std.StringHashMap(u32).init(allocator),
            .arch = arch,
        };
    }

    pub fn deinit(self: *MachoWriter) void {
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
    fn addString(self: *MachoWriter, str: []const u8) !u32 {
        if (self.strtab.items.len == 0) {
            try self.strtab.append(0);
        }
        const off: u32 = @intCast(self.strtab.items.len);
        try self.strtab.appendSlice(str);
        try self.strtab.append(0);
        return off;
    }

    fn nType(linkage: module_mod.Linkage, defined: bool) u8 {
        if (defined) {
            return if (linkage == .local) 0x0E else 0x0F; // N_SECT | N_EXT
        }
        return if (linkage == .local) 0x00 else 0x01; // N_UNDF | N_EXT
    }

    fn defineSymbol(
        self: *MachoWriter,
        name: []const u8,
        linkage: module_mod.Linkage,
        n_sect: u8,
        n_value: u64,
    ) !u32 {
        if (self.sym_map.get(name)) |idx| {
            const name_off = self.syms.items[idx].n_strx;
            self.syms.items[idx] = .{
                .n_strx = name_off,
                .n_type = nType(linkage, true),
                .n_sect = n_sect,
                .n_desc = 0,
                .n_value = n_value,
            };
            return idx;
        }

        const name_off = try self.addString(name);
        const idx: u32 = @intCast(self.syms.items.len);
        try self.syms.append(.{
            .n_strx = name_off,
            .n_type = nType(linkage, true),
            .n_sect = n_sect,
            .n_desc = 0,
            .n_value = n_value,
        });
        const key = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key);
        try self.sym_map.put(key, idx);
        return idx;
    }

    fn ensureSymbol(
        self: *MachoWriter,
        name: []const u8,
        linkage: module_mod.Linkage,
    ) !u32 {
        if (self.sym_map.get(name)) |idx| return idx;
        const name_off = try self.addString(name);
        const idx: u32 = @intCast(self.syms.items.len);
        try self.syms.append(.{
            .n_strx = name_off,
            .n_type = nType(linkage, false),
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        });
        const key = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key);
        try self.sym_map.put(key, idx);
        return idx;
    }

    fn applyAddend(self: *MachoWriter, data: []u8, off: u32, kind: RelocKind, addend: i64) !void {
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

    fn relocInfo(self: *MachoWriter, kind: RelocKind) !struct {
        r_pcrel: bool,
        r_length: u8,
        r_type: u8,
    } {
        return switch (self.arch) {
            .x86_64 => switch (kind) {
                .abs64 => .{ .r_pcrel = false, .r_length = 3, .r_type = 0 }, // X86_64_RELOC_UNSIGNED
                .abs32 => .{ .r_pcrel = false, .r_length = 2, .r_type = 0 },
                .pcrel32 => .{ .r_pcrel = true, .r_length = 2, .r_type = 1 }, // X86_64_RELOC_SIGNED
                .got => .{ .r_pcrel = true, .r_length = 2, .r_type = 4 }, // X86_64_RELOC_GOT
                .plt => .{ .r_pcrel = true, .r_length = 2, .r_type = 2 }, // X86_64_RELOC_BRANCH
            },
            .aarch64 => switch (kind) {
                .abs64 => .{ .r_pcrel = false, .r_length = 3, .r_type = 0 }, // ARM64_RELOC_UNSIGNED
                .abs32 => .{ .r_pcrel = false, .r_length = 2, .r_type = 0 },
                .pcrel32 => .{ .r_pcrel = true, .r_length = 2, .r_type = 0 },
                .plt => .{ .r_pcrel = true, .r_length = 2, .r_type = 2 }, // ARM64_RELOC_BRANCH26
                .got => return error.UnsupportedRelocation,
            },
        };
    }

    fn alignPow(align_: u32) !u32 {
        if (align_ <= 1) return 0;
        if (!std.math.isPowerOfTwo(align_)) return error.InvalidAlignment;
        return std.math.log2_int(u32, align_);
    }

    fn alignTo(off: u32, align_pow: u32) u32 {
        const align_: u32 = @as(u32, 1) << @intCast(align_pow);
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

    fn writeSection(buf: *std.ArrayList(u8), sec: Section64) !void {
        try buf.appendSlice(&sec.sectname);
        try buf.appendSlice(&sec.segname);
        try buf.appendSlice(&std.mem.toBytes(sec.addr));
        try buf.appendSlice(&std.mem.toBytes(sec.size));
        try buf.appendSlice(&std.mem.toBytes(sec.off));
        try buf.appendSlice(&std.mem.toBytes(sec.align_));
        try buf.appendSlice(&std.mem.toBytes(sec.reloff));
        try buf.appendSlice(&std.mem.toBytes(sec.nreloc));
        try buf.appendSlice(&std.mem.toBytes(sec.flags));
        try buf.appendSlice(&std.mem.toBytes(sec.reserved1));
        try buf.appendSlice(&std.mem.toBytes(sec.reserved2));
        try buf.appendSlice(&std.mem.toBytes(sec.reserved3));
    }

    fn writeNlist(buf: *std.ArrayList(u8), sym: Nlist64) !void {
        try buf.appendSlice(&std.mem.toBytes(sym.n_strx));
        try buf.append(sym.n_type);
        try buf.append(sym.n_sect);
        try buf.appendSlice(&std.mem.toBytes(sym.n_desc));
        try buf.appendSlice(&std.mem.toBytes(sym.n_value));
    }

    fn writeRelocInfo(buf: *std.ArrayList(u8), rel: RelocInfo) !void {
        try buf.appendSlice(&std.mem.toBytes(rel.r_address));
        var info: u32 = rel.r_symbolnum & 0x00FFFFFF;
        if (rel.r_pcrel) info |= 1 << 24;
        info |= (@as(u32, rel.r_length) & 0x3) << 25;
        if (rel.r_extern) info |= 1 << 27;
        info |= (@as(u32, rel.r_type) & 0xF) << 28;
        try buf.appendSlice(&std.mem.toBytes(info));
    }

    fn segName(kind: SectionKind) []const u8 {
        return switch (kind) {
            .text => "__TEXT",
            .data, .bss => "__DATA",
        };
    }

    fn sectName(kind: SectionKind) []const u8 {
        return switch (kind) {
            .text => "__text",
            .data => "__data",
            .bss => "__bss",
        };
    }

    fn name16(name: []const u8) [16]u8 {
        var out: [16]u8 = [_]u8{0} ** 16;
        @memcpy(out[0..name.len], name);
        return out;
    }

    /// Create a section.
    fn createSection(self: *MachoWriter, kind: SectionKind, align_: u32) !u32 {
        const sec = Section{
            .kind = kind,
            .data = std.ArrayList(u8).init(self.allocator),
            .align_ = align_,
            .relocs = std.ArrayList(RelocInfo).init(self.allocator),
        };
        try self.sections.append(sec);
        return @intCast(self.sections.items.len - 1);
    }

    /// Add function code to __text section.
    pub fn addFunc(
        self: *MachoWriter,
        func: FuncId,
        name: []const u8,
        code: []const u8,
        relocs: []const ModuleReloc,
        sym_table: *const symbols_mod.SymbolTable,
    ) !void {
        const func_decl = sym_table.getFunc(func) orelse return error.InvalidFuncId;
        const linkage = func_decl.linkage;

        // Find or create __text section
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
        _ = try self.defineSymbol(name, linkage, @intCast(text_idx.? + 1), func_off);

        // Add relocations
        for (relocs) |reloc| {
            const rinfo = try self.makeRelocInfo(reloc, func_off, sym_table, sec.data.items);
            try sec.relocs.append(rinfo);
        }
    }

    /// Convert ModuleReloc to Mach-O relocation.
    fn makeRelocInfo(
        self: *MachoWriter,
        reloc: ModuleReloc,
        base_off: u64,
        sym_table: *const symbols_mod.SymbolTable,
        data: []u8,
    ) !RelocInfo {
        const target = try obj_reloc.resolveTarget(sym_table, reloc.target);
        const sym_idx = try self.ensureSymbol(target.name, target.linkage);
        const addend = reloc.addend + target.addend;
        try self.applyAddend(data, @intCast(base_off + reloc.off), reloc.kind, addend);
        const info = try self.relocInfo(reloc.kind);

        return .{
            .r_address = @intCast(base_off + reloc.off),
            .r_symbolnum = sym_idx,
            .r_pcrel = info.r_pcrel,
            .r_length = info.r_length,
            .r_extern = true,
            .r_type = info.r_type,
        };
    }

    /// Write Mach-O object file to buffer.
    pub fn finish(self: *MachoWriter, buf: *std.ArrayList(u8)) !void {
        // Mach-O header (64-bit)
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 0xFEEDFACF))); // MH_MAGIC_64
        try buf.appendSlice(&std.mem.toBytes(@as(u32, switch (self.arch) {
            .x86_64 => 0x01000007, // CPU_TYPE_X86_64
            .aarch64 => 0x0100000C, // CPU_TYPE_ARM64
        })));
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 0))); // cpusubtype
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 1))); // MH_OBJECT
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 0))); // ncmds (updated later)
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 0))); // sizeofcmds (updated later)
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 0))); // flags
        try buf.appendSlice(&std.mem.toBytes(@as(u32, 0))); // reserved

        if (self.strtab.items.len == 0) {
            try self.strtab.append(0);
        }

        const header_size: u32 = 32;
        const LC_SEGMENT_64: u32 = 0x19;
        const LC_SYMTAB: u32 = 0x2;
        const seg_cmd_size: u32 = 72;
        const sect_size: u32 = 80;
        const symtab_cmd_size: u32 = 24;

        const SecOut = struct {
            orig_idx: u32,
            kind: SectionKind,
            data: []const u8,
            align_pow: u32,
            off: u32,
            size: u64,
            reloff: u32,
            nreloc: u32,
            flags: u32,
            sectname: [16]u8,
            segname: [16]u8,
            relocs: []const RelocInfo,
        };

        var out_secs = std.ArrayList(SecOut).init(self.allocator);
        defer out_secs.deinit();

        var i: u32 = 0;
        while (i < self.sections.items.len) : (i += 1) {
            const sec = self.sections.items[i];
            const align_pow = try alignPow(sec.align_);
            const flags: u32 = switch (sec.kind) {
                .text => 0x80000400, // S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS
                .data => 0x00000000, // S_REGULAR
                .bss => 0x00000001, // S_ZEROFILL
            };
            try out_secs.append(.{
                .orig_idx = i,
                .kind = sec.kind,
                .data = sec.data.items,
                .align_pow = align_pow,
                .off = 0,
                .size = @intCast(sec.data.items.len),
                .reloff = 0,
                .nreloc = @intCast(sec.relocs.items.len),
                .flags = flags,
                .sectname = name16(sectName(sec.kind)),
                .segname = name16(segName(sec.kind)),
                .relocs = sec.relocs.items,
            });
        }

        // Sort output order: text first, then data/bss
        var sorted = std.ArrayList(SecOut).init(self.allocator);
        defer sorted.deinit();
        for (out_secs.items) |sec| {
            if (sec.kind == .text) try sorted.append(sec);
        }
        for (out_secs.items) |sec| {
            if (sec.kind != .text) try sorted.append(sec);
        }

        var text_secs: u32 = 0;
        var data_secs: u32 = 0;
        for (sorted.items) |sec| {
            if (sec.kind == .text) {
                text_secs += 1;
            } else {
                data_secs += 1;
            }
        }

        const nseg: u32 = @intFromBool(text_secs > 0) + @intFromBool(data_secs > 0);
        const ncmds: u32 = nseg + 1;
        const sizeofcmds: u32 = nseg * seg_cmd_size + (text_secs + data_secs) * sect_size + symtab_cmd_size;

        var file_off: u32 = header_size + sizeofcmds;
        for (sorted.items) |*sec| {
            if (sec.kind == .bss) {
                sec.off = 0;
                continue;
            }
            file_off = alignTo(file_off, sec.align_pow);
            sec.off = file_off;
            file_off += @intCast(sec.data.len);
        }

        var rel_off: u32 = file_off;
        for (sorted.items) |*sec| {
            if (sec.nreloc == 0) continue;
            rel_off = alignTo(rel_off, 2); // 4-byte align
            sec.reloff = rel_off;
            rel_off += sec.nreloc * 8;
        }

        const symoff: u32 = rel_off;
        const nsyms: u32 = @intCast(self.syms.items.len);
        const stroff: u32 = symoff + nsyms * 16;
        const strsize: u32 = @intCast(self.strtab.items.len);

        // Patch symbol section indices after reordering.
        if (self.sections.items.len != 0) {
            const map = try self.allocator.alloc(u8, self.sections.items.len);
            defer self.allocator.free(map);
            for (sorted.items, 0..) |sec, idx| {
                map[sec.orig_idx] = @intCast(idx + 1);
            }
            for (self.syms.items) |*sym| {
                if ((sym.n_type & 0x0E) == 0x0E and sym.n_sect != 0) {
                    const internal: usize = sym.n_sect - 1;
                    if (internal >= map.len) return error.InvalidSectionIndex;
                    sym.n_sect = map[internal];
                }
            }
        }

        // Load commands
        if (text_secs > 0) {
            const cmdsize: u32 = seg_cmd_size + text_secs * sect_size;
            try buf.appendSlice(&std.mem.toBytes(LC_SEGMENT_64));
            try buf.appendSlice(&std.mem.toBytes(cmdsize));
            try buf.appendSlice(&name16("__TEXT"));
            try buf.appendSlice(&std.mem.toBytes(@as(u64, 0)));
            try buf.appendSlice(&std.mem.toBytes(@as(u64, 0)));
            const text_fileoff: u64 = if (sorted.items.len == 0) 0 else @as(u64, sorted.items[0].off);
            var text_filesize: u64 = 0;
            if (text_secs > 0) {
                for (sorted.items) |sec| {
                    if (sec.kind != .text) break;
                    if (sec.off != 0) {
                        const end = @as(u64, sec.off) + sec.size;
                        if (end > text_filesize) text_filesize = end;
                    }
                }
                if (text_filesize > text_fileoff) text_filesize -= text_fileoff;
            }
            try buf.appendSlice(&std.mem.toBytes(text_fileoff));
            try buf.appendSlice(&std.mem.toBytes(text_filesize));
            try buf.appendSlice(&std.mem.toBytes(@as(u32, 7))); // maxprot
            try buf.appendSlice(&std.mem.toBytes(@as(u32, 5))); // initprot
            try buf.appendSlice(&std.mem.toBytes(text_secs));
            try buf.appendSlice(&std.mem.toBytes(@as(u32, 0)));

            var count: u32 = 0;
            for (sorted.items) |sec| {
                if (sec.kind != .text) break;
                try writeSection(buf, .{
                    .sectname = sec.sectname,
                    .segname = sec.segname,
                    .addr = 0,
                    .size = sec.size,
                    .off = sec.off,
                    .align_ = sec.align_pow,
                    .reloff = sec.reloff,
                    .nreloc = sec.nreloc,
                    .flags = sec.flags,
                    .reserved1 = 0,
                    .reserved2 = 0,
                    .reserved3 = 0,
                });
                count += 1;
            }
        }

        if (data_secs > 0) {
            const cmdsize: u32 = seg_cmd_size + data_secs * sect_size;
            try buf.appendSlice(&std.mem.toBytes(LC_SEGMENT_64));
            try buf.appendSlice(&std.mem.toBytes(cmdsize));
            try buf.appendSlice(&name16("__DATA"));
            try buf.appendSlice(&std.mem.toBytes(@as(u64, 0)));
            try buf.appendSlice(&std.mem.toBytes(@as(u64, 0)));
            var data_fileoff: u64 = 0;
            var data_filesize: u64 = 0;
            for (sorted.items) |sec| {
                if (sec.kind == .text) continue;
                if (sec.off != 0) {
                    if (data_fileoff == 0) data_fileoff = sec.off;
                    const end = @as(u64, sec.off) + sec.size;
                    if (end > data_filesize) data_filesize = end;
                }
            }
            if (data_filesize > data_fileoff) data_filesize -= data_fileoff;
            try buf.appendSlice(&std.mem.toBytes(data_fileoff));
            try buf.appendSlice(&std.mem.toBytes(data_filesize));
            try buf.appendSlice(&std.mem.toBytes(@as(u32, 7))); // maxprot
            try buf.appendSlice(&std.mem.toBytes(@as(u32, 3))); // initprot
            try buf.appendSlice(&std.mem.toBytes(data_secs));
            try buf.appendSlice(&std.mem.toBytes(@as(u32, 0)));

            for (sorted.items) |sec| {
                if (sec.kind == .text) continue;
                try writeSection(buf, .{
                    .sectname = sec.sectname,
                    .segname = sec.segname,
                    .addr = 0,
                    .size = sec.size,
                    .off = sec.off,
                    .align_ = sec.align_pow,
                    .reloff = sec.reloff,
                    .nreloc = sec.nreloc,
                    .flags = sec.flags,
                    .reserved1 = 0,
                    .reserved2 = 0,
                    .reserved3 = 0,
                });
            }
        }

        // symtab command
        try buf.appendSlice(&std.mem.toBytes(LC_SYMTAB));
        try buf.appendSlice(&std.mem.toBytes(symtab_cmd_size));
        try buf.appendSlice(&std.mem.toBytes(symoff));
        try buf.appendSlice(&std.mem.toBytes(nsyms));
        try buf.appendSlice(&std.mem.toBytes(stroff));
        try buf.appendSlice(&std.mem.toBytes(strsize));

        // Section data
        for (sorted.items) |sec| {
            if (sec.off == 0) continue;
            try padTo(buf, sec.off);
            if (sec.data.len != 0) try buf.appendSlice(sec.data);
        }

        // Relocations
        for (sorted.items) |sec| {
            if (sec.nreloc == 0) continue;
            try padTo(buf, sec.reloff);
            for (sec.relocs) |rel| try writeRelocInfo(buf, rel);
        }

        // Symbol table
        try padTo(buf, symoff);
        for (self.syms.items) |sym| try writeNlist(buf, sym);

        // String table
        try padTo(buf, stroff);
        try buf.appendSlice(self.strtab.items);

        std.mem.writeInt(u32, buf.items[16..20], ncmds, .little);
        std.mem.writeInt(u32, buf.items[20..24], sizeofcmds, .little);
    }
};

test "MachoWriter init" {
    const allocator = std.testing.allocator;
    var writer = MachoWriter.init(allocator, .x86_64);
    defer writer.deinit();
}

test "MachoWriter resolves reloc target" {
    const allocator = std.testing.allocator;
    var symtab = symbols_mod.SymbolTable.init(allocator);
    defer symtab.deinit();
    const func = try symtab.declareFunc("foo", module_mod.Linkage.@"export");

    var writer = MachoWriter.init(allocator, .x86_64);
    defer writer.deinit();

    const relocs = [_]ModuleReloc{.{
        .off = 0,
        .kind = .abs64,
        .target = symbols_mod.RelocTarget.fromFuncId(func),
        .addend = 0,
    }};
    try writer.addFunc(func, "foo", &[_]u8{0xC3}, &relocs, &symtab);

    const sec = &writer.sections.items[0];
    try std.testing.expectEqual(@as(u32, 0), sec.relocs.items[0].r_symbolnum);
}

test "MachoWriter finish basic" {
    const allocator = std.testing.allocator;
    var symtab = symbols_mod.SymbolTable.init(allocator);
    defer symtab.deinit();
    const func = try symtab.declareFunc("foo", module_mod.Linkage.@"export");

    var writer = MachoWriter.init(allocator, .x86_64);
    defer writer.deinit();

    try writer.addFunc(func, "foo", &[_]u8{0xC3}, &[_]ModuleReloc{}, &symtab);

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try writer.finish(&buf);

    const magic = std.mem.readInt(u32, buf.items[0..4], .little);
    const ncmds = std.mem.readInt(u32, buf.items[16..20], .little);
    const sizeofcmds = std.mem.readInt(u32, buf.items[20..24], .little);
    try std.testing.expectEqual(@as(u32, 0xFEEDFACF), magic);
    try std.testing.expect(ncmds > 0);
    try std.testing.expect(sizeofcmds > 0);
    try std.testing.expect(buf.items.len >= 32 + sizeofcmds);
}
