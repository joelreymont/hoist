const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const module_mod = @import("../module/module.zig");
const symbols_mod = @import("../module/symbols.zig");
const sig_mod = @import("../ir/signature.zig");

const FuncId = module_mod.FuncId;
const DataId = module_mod.DataId;
const Linkage = module_mod.Linkage;
const ModuleDeclarations = module_mod.ModuleDeclarations;

const elf = @import("elf.zig");
const macho = @import("macho.zig");
const coff = @import("coff.zig");

/// Target format for object files.
pub const Format = enum {
    elf,
    macho,
    coff,
};

/// Target architecture.
pub const Arch = enum {
    x86_64,
    aarch64,

    pub fn elfMachine(self: Arch) u16 {
        return switch (self) {
            .x86_64 => 62,
            .aarch64 => 183,
        };
    }
};

/// Object module for emitting relocatable object files.
pub const ObjectModule = struct {
    allocator: Allocator,
    format: Format,
    arch: Arch,
    decls: ModuleDeclarations,
    sym_table: symbols_mod.SymbolTable,
    writer: Writer,

    const Writer = union(enum) {
        elf: elf.ElfWriter,
        macho: macho.MachoWriter,
        coff: coff.CoffWriter,
    };

    pub fn init(allocator: Allocator, format: Format, arch: Arch) ObjectModule {
        const writer = switch (format) {
            .elf => Writer{ .elf = elf.ElfWriter.init(allocator, switch (arch) {
                .x86_64 => .x86_64,
                .aarch64 => .aarch64,
            }) },
            .macho => Writer{ .macho = macho.MachoWriter.init(allocator, switch (arch) {
                .x86_64 => .x86_64,
                .aarch64 => .aarch64,
            }) },
            .coff => Writer{ .coff = coff.CoffWriter.init(allocator, switch (arch) {
                .x86_64 => .x86_64,
                .aarch64 => .aarch64,
            }) },
        };

        return .{
            .allocator = allocator,
            .format = format,
            .arch = arch,
            .decls = ModuleDeclarations.init(allocator),
            .sym_table = symbols_mod.SymbolTable.init(allocator),
            .writer = writer,
        };
    }

    pub fn deinit(self: *ObjectModule) void {
        switch (self.writer) {
            .elf => |*w| w.deinit(),
            .macho => |*w| w.deinit(),
            .coff => |*w| w.deinit(),
        }
        self.sym_table.deinit();
        self.decls.deinit();
    }

    /// Declare a function.
    pub fn declareFunction(
        self: *ObjectModule,
        name: []const u8,
        linkage: Linkage,
        signature: sig_mod.Signature,
    ) !FuncId {
        _ = signature;
        return self.sym_table.declareFunc(name, linkage);
    }

    /// Define a function with compiled code.
    pub fn defineFunction(
        self: *ObjectModule,
        func: FuncId,
        code: []const u8,
    ) !void {
        const func_decl = self.sym_table.getFuncMut(func) orelse return error.InvalidFuncId;
        const name = func_decl.name orelse return error.MissingFuncName;

        switch (self.writer) {
            .elf => |*w| try w.addFunc(name, code, func_decl.relocs.items),
            .macho => |*w| try w.addFunc(name, code, func_decl.relocs.items),
            .coff => |*w| try w.addFunc(name, code, func_decl.relocs.items),
        }
    }

    /// Finalize the module and write to buffer.
    pub fn finalize(self: *ObjectModule, buf: *std.ArrayList(u8)) !void {
        switch (self.writer) {
            .elf => |*w| try w.finish(buf),
            .macho => |*w| try w.finish(buf),
            .coff => |*w| try w.finish(buf),
        }
    }

    /// Get declarations.
    pub fn declarations(self: *const ObjectModule) *const ModuleDeclarations {
        return &self.decls;
    }
};

test "ObjectModule ELF init" {
    const allocator = std.testing.allocator;
    var mod = ObjectModule.init(allocator, .elf, .x86_64);
    defer mod.deinit();
}

test "ObjectModule Mach-O init" {
    const allocator = std.testing.allocator;
    var mod = ObjectModule.init(allocator, .macho, .aarch64);
    defer mod.deinit();
}

test "ObjectModule COFF init" {
    const allocator = std.testing.allocator;
    var mod = ObjectModule.init(allocator, .coff, .x86_64);
    defer mod.deinit();
}
