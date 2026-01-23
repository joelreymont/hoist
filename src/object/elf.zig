const std = @import("std");
const Allocator = std.mem.Allocator;

const module_mod = @import("../module/module.zig");
const symbols_mod = @import("../module/symbols.zig");
const FuncId = module_mod.FuncId;
const DataId = module_mod.DataId;
const RelocTarget = symbols_mod.RelocTarget;
const ModuleReloc = symbols_mod.ModuleReloc;
const RelocKind = symbols_mod.RelocKind;

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
    }

    /// Add string to strtab and return offset.
    fn addString(self: *ElfWriter, str: []const u8) !u32 {
        const off: u32 = @intCast(self.strtab.items.len);
        try self.strtab.appendSlice(str);
        try self.strtab.append(0);
        return off;
    }

    /// Add string to shstrtab and return offset.
    fn addSectionName(self: *ElfWriter, name: []const u8) !u32 {
        const off: u32 = @intCast(self.shstrtab.items.len);
        try self.shstrtab.appendSlice(name);
        try self.shstrtab.append(0);
        return off;
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
        name: []const u8,
        code: []const u8,
        relocs: []const ModuleReloc,
    ) !void {
        const name_off = try self.addString(name);
        const sym_idx: u32 = @intCast(self.syms.items.len);

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
        try self.syms.append(.{
            .name_off = name_off,
            .info = 0x12, // STB_GLOBAL | STT_FUNC
            .other = 0,
            .shndx = @intCast(text_idx.? + 1), // +1 for null section
            .value = func_off,
            .size = @intCast(code.len),
        });

        // Add relocations
        for (relocs) |reloc| {
            const rela = try self.makeRela(reloc, func_off);
            try sec.relocs.append(rela);
        }
    }

    /// Convert ModuleReloc to ELF RELA.
    fn makeRela(self: *ElfWriter, reloc: ModuleReloc, base_off: u64) !Rela {
        _ = self;
        // TODO: resolve target symbol index
        const sym_idx: u32 = 0;
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

    /// Write ELF object file to buffer.
    pub fn finish(self: *ElfWriter, buf: *std.ArrayList(u8)) !void {
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

        // TODO: write sections, section headers, symbol table, string tables
        _ = self;
    }
};

test "ElfWriter init" {
    const allocator = std.testing.allocator;
    var writer = ElfWriter.init(allocator, .x86_64);
    defer writer.deinit();
}
