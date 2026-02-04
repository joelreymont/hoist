const module_mod = @import("../module/module.zig");
const symbols_mod = @import("../module/symbols.zig");
const libcall_mod = @import("../ir/libcall.zig");
const known_sym_mod = @import("../ir/known_symbol.zig");

const FuncId = module_mod.FuncId;
const DataId = module_mod.DataId;
const Linkage = module_mod.Linkage;
const LibCall = libcall_mod.LibCall;
const KnownSymbol = known_sym_mod.KnownSymbol;
const RelocTarget = symbols_mod.RelocTarget;
const SymbolTable = symbols_mod.SymbolTable;

pub const SymKind = enum {
    func,
    data,
    tls,
    unknown,
};

pub const ResolvedTarget = struct {
    name: []const u8,
    kind: SymKind,
    linkage: Linkage,
    addend: i64,
};

pub fn resolveTarget(sym_table: *const SymbolTable, target: RelocTarget) !ResolvedTarget {
    return switch (target) {
        .user => |u| blk: {
            if (u.namespace == 0) {
                const func = sym_table.getFunc(FuncId.from(u.idx)) orelse return error.InvalidFuncId;
                const name = func.name orelse return error.MissingFuncName;
                break :blk .{
                    .name = name,
                    .kind = .func,
                    .linkage = func.linkage,
                    .addend = 0,
                };
            }
            const data = sym_table.getData(DataId.from(u.idx)) orelse return error.InvalidDataId;
            const name = data.name orelse return error.MissingDataName;
            break :blk .{
                .name = name,
                .kind = .data,
                .linkage = data.linkage,
                .addend = 0,
            };
        },
        .libcall => |lc| .{
            .name = libcallName(lc),
            .kind = .func,
            .linkage = .import,
            .addend = 0,
        },
        .known_sym => |ks| .{
            .name = knownSymbolName(ks),
            .kind = if (ks == .coff_tls_index) .tls else .data,
            .linkage = .import,
            .addend = 0,
        },
        .func_off => |fo| blk: {
            const func = sym_table.getFunc(fo.func) orelse return error.InvalidFuncId;
            const name = func.name orelse return error.MissingFuncName;
            break :blk .{
                .name = name,
                .kind = .func,
                .linkage = func.linkage,
                .addend = fo.off,
            };
        },
    };
}

fn libcallName(libcall: LibCall) []const u8 {
    return switch (libcall) {
        .probestack => "__probestack",
        .ceil_f32 => "ceilf",
        .ceil_f64 => "ceil",
        .floor_f32 => "floorf",
        .floor_f64 => "floor",
        .trunc_f32 => "truncf",
        .trunc_f64 => "trunc",
        .nearest_f32 => "nearbyintf",
        .nearest_f64 => "nearbyint",
        .fma_f32 => "fmaf",
        .fma_f64 => "fma",
        .memcpy => "memcpy",
        .memset => "memset",
        .memmove => "memmove",
        .memcmp => "memcmp",
        .elf_tls_get_addr => "__tls_get_addr",
        .elf_tls_get_offset => "__tls_get_offset",
        .x86_pshufb => "__cranelift_x86_pshufb",
        .f16_add => "__addhf3",
        .f16_sub => "__subhf3",
        .f16_mul => "__mulhf3",
        .f16_div => "__divhf3",
        .f16_to_f32 => "__extendhfsf2",
        .f32_to_f16 => "__truncsfhf2",
        .f16_to_f64 => "__extendhfdf2",
        .f64_to_f16 => "__truncdfhf2",
        .f128_add => "__addtf3",
        .f128_sub => "__subtf3",
        .f128_mul => "__multf3",
        .f128_div => "__divtf3",
        .f32_to_f128 => "__extendsftf2",
        .f64_to_f128 => "__extenddftf2",
        .f128_to_f32 => "__trunctfsf2",
        .f128_to_f64 => "__trunctfdf2",
        .f128_sqrt => "__sqrttf2",
        .f128_fma => "__fmatf4",
    };
}

fn knownSymbolName(sym: KnownSymbol) []const u8 {
    return switch (sym) {
        .elf_global_offset_table => "_GLOBAL_OFFSET_TABLE_",
        .coff_tls_index => "_tls_index",
    };
}
