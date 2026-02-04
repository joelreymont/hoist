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
    sym_map: std.AutoHashMap(RelocKey, u32),
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
            .sym_map = std.AutoHashMap(RelocKey, u32).init(allocator),
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

    fn symbolName(self: *MachoWriter, target: RelocTarget, sym_table: *const symbols_mod.SymbolTable) ![]const u8 {
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
        self: *MachoWriter,
        target: RelocTarget,
        sym_table: *const symbols_mod.SymbolTable,
    ) !u32 {
        const key = relocKey(target);
        if (self.sym_map.get(key)) |idx| return idx;

        const name = try self.symbolName(target, sym_table);
        const name_off = try self.addString(name);
        const idx: u32 = @intCast(self.syms.items.len);
        try self.syms.append(.{
            .n_strx = name_off,
            .n_type = 0x01, // N_EXT
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        });
        try self.sym_map.put(key, idx);
        return idx;
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
        const name_off = try self.addString(name);
        const func_key = relocKey(RelocTarget.fromFuncId(func));

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
        if (self.sym_map.get(func_key)) |idx| {
            self.syms.items[idx] = .{
                .n_strx = name_off,
                .n_type = 0x0F, // N_SECT | N_EXT
                .n_sect = @intCast(text_idx.? + 1),
                .n_desc = 0,
                .n_value = func_off,
            };
        } else {
            try self.syms.append(.{
                .n_strx = name_off,
                .n_type = 0x0F, // N_SECT | N_EXT
                .n_sect = @intCast(text_idx.? + 1),
                .n_desc = 0,
                .n_value = func_off,
            });
            try self.sym_map.put(func_key, @intCast(self.syms.items.len - 1));
        }

        // Add relocations
        for (relocs) |reloc| {
            const rinfo = try self.makeRelocInfo(reloc, func_off, sym_table);
            try sec.relocs.append(rinfo);
        }
    }

    /// Convert ModuleReloc to Mach-O relocation.
    fn makeRelocInfo(
        self: *MachoWriter,
        reloc: ModuleReloc,
        base_off: u64,
        sym_table: *const symbols_mod.SymbolTable,
    ) !RelocInfo {
        const sym_idx = try self.ensureSymbol(reloc.target, sym_table);
        const r_type: u8 = switch (reloc.kind) {
            .abs64 => 0, // X86_64_RELOC_UNSIGNED or ARM64_RELOC_UNSIGNED
            .abs32 => 0,
            .pcrel32 => 1, // X86_64_RELOC_BRANCH or ARM64_RELOC_BRANCH26
            .got => 4, // X86_64_RELOC_GOT_LOAD
            .plt => 1,
        };

        return .{
            .r_address = @intCast(base_off + reloc.off),
            .r_symbolnum = sym_idx,
            .r_pcrel = reloc.kind == .pcrel32 or reloc.kind == .plt,
            .r_length = if (reloc.kind == .abs64) 3 else 2, // log2(size)
            .r_extern = true,
            .r_type = r_type,
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

        // TODO: write load commands, sections, symbol table, string table
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
        .target = RelocTarget.fromFuncId(func),
        .addend = 0,
    }};
    try writer.addFunc(func, "foo", &[_]u8{0xC3}, &relocs, &symtab);

    const sec = &writer.sections.items[0];
    try std.testing.expectEqual(@as(u32, 0), sec.relocs.items[0].r_symbolnum);
}
