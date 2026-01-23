const std = @import("std");
const Allocator = std.mem.Allocator;

const module_mod = @import("../module/module.zig");
const symbols_mod = @import("../module/symbols.zig");
const FuncId = module_mod.FuncId;
const DataId = module_mod.DataId;
const RelocTarget = symbols_mod.RelocTarget;
const ModuleReloc = symbols_mod.ModuleReloc;
const RelocKind = symbols_mod.RelocKind;

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
    }

    /// Add string to strtab and return offset.
    fn addString(self: *CoffWriter, str: []const u8) !u32 {
        const off: u32 = @intCast(self.strtab.items.len + 4); // +4 for size prefix
        try self.strtab.appendSlice(str);
        try self.strtab.append(0);
        return off;
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
        name: []const u8,
        code: []const u8,
        relocs: []const ModuleReloc,
    ) !void {
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

        // Add symbol
        var sym_name: [8]u8 = [_]u8{0} ** 8;
        if (name.len <= 8) {
            @memcpy(sym_name[0..name.len], name);
        } else {
            const str_off = try self.addString(name);
            std.mem.writeInt(u32, sym_name[4..8], str_off, .little);
        }

        try self.syms.append(.{
            .name = sym_name,
            .value = func_off,
            .section = @intCast(text_idx.? + 1),
            .typ = 0x20, // function
            .storage_class = 2, // external
            .n_aux = 0,
        });

        // Add relocations
        for (relocs) |reloc| {
            const rel = try self.makeRelocation(reloc, func_off);
            try sec.relocs.append(rel);
        }
    }

    /// Convert ModuleReloc to COFF relocation.
    fn makeRelocation(self: *CoffWriter, reloc: ModuleReloc, base_off: u32) !Relocation {
        _ = self;
        // TODO: resolve target symbol index
        const sym_idx: u32 = 0;
        const typ: u16 = switch (reloc.kind) {
            .abs64 => 1, // IMAGE_REL_AMD64_ADDR64 or IMAGE_REL_ARM64_ADDR64
            .abs32 => 2, // IMAGE_REL_AMD64_ADDR32
            .pcrel32 => 4, // IMAGE_REL_AMD64_REL32 or IMAGE_REL_ARM64_REL32
            .got => 4,
            .plt => 4,
        };

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

        // TODO: write sections, section headers, symbol table, string table
        _ = self;
    }
};

test "CoffWriter init" {
    const allocator = std.testing.allocator;
    var writer = CoffWriter.init(allocator, .x86_64);
    defer writer.deinit();
}
