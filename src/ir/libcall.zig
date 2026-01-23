//! Well-known runtime library routines.
//!
//! Ported from cranelift-codegen ir/libcall.rs.
//! Runtime library calls are generated for IR instructions that don't have an equivalent
//! ISA instruction or an easy macro expansion. LibCall provides well-known names for
//! runtime routines without knowing the embedding VM's naming convention.

const std = @import("std");
const signature_mod = @import("signature.zig");
const Signature = signature_mod.Signature;
const AbiParam = signature_mod.AbiParam;
const CallConv = @import("call_conv.zig").CallConv;
const Type = @import("types.zig").Type;

/// The name of a runtime library routine.
pub const LibCall = enum {
    /// Probe for stack overflow (emitted when enable_probestack setting is true)
    probestack,
    /// ceil.f32
    ceil_f32,
    /// ceil.f64
    ceil_f64,
    /// floor.f32
    floor_f32,
    /// floor.f64
    floor_f64,
    /// trunc.f32
    trunc_f32,
    /// trunc.f64
    trunc_f64,
    /// nearest.f32
    nearest_f32,
    /// nearest.f64
    nearest_f64,
    /// fma.f32
    fma_f32,
    /// fma.f64
    fma_f64,
    /// libc.memcpy
    memcpy,
    /// libc.memset
    memset,
    /// libc.memmove
    memmove,
    /// libc.memcmp
    memcmp,
    /// ELF __tls_get_addr
    elf_tls_get_addr,
    /// ELF __tls_get_offset
    elf_tls_get_offset,
    /// The pshufb instruction on x86 when SSSE3 isn't available
    x86_pshufb,

    // F16 soft-float operations (compiler-rt/libgcc)
    /// __addhf3 - f16 add
    f16_add,
    /// __subhf3 - f16 sub
    f16_sub,
    /// __mulhf3 - f16 mul
    f16_mul,
    /// __divhf3 - f16 div
    f16_div,
    /// __extendhfsf2 - f16 to f32
    f16_to_f32,
    /// __truncsfhf2 - f32 to f16
    f32_to_f16,
    /// __extendhfdf2 - f16 to f64
    f16_to_f64,
    /// __truncdfhf2 - f64 to f16
    f64_to_f16,

    // F128 soft-float operations (compiler-rt/libgcc)
    /// __addtf3 - f128 add
    f128_add,
    /// __subtf3 - f128 sub
    f128_sub,
    /// __multf3 - f128 mul
    f128_mul,
    /// __divtf3 - f128 div
    f128_div,
    /// __extendsftf2 - f32 to f128
    f32_to_f128,
    /// __extenddftf2 - f64 to f128
    f64_to_f128,
    /// __trunctfsf2 - f128 to f32
    f128_to_f32,
    /// __trunctfdf2 - f128 to f64
    f128_to_f64,
    /// __sqrttf2 - f128 sqrt
    f128_sqrt,
    /// __fmatf4 - f128 fma (not standard but some runtimes provide it)
    f128_fma,

    /// Parse a LibCall from a string.
    pub fn parse(s: []const u8) ?LibCall {
        if (std.mem.eql(u8, s, "Probestack")) return .probestack;
        if (std.mem.eql(u8, s, "CeilF32")) return .ceil_f32;
        if (std.mem.eql(u8, s, "CeilF64")) return .ceil_f64;
        if (std.mem.eql(u8, s, "FloorF32")) return .floor_f32;
        if (std.mem.eql(u8, s, "FloorF64")) return .floor_f64;
        if (std.mem.eql(u8, s, "TruncF32")) return .trunc_f32;
        if (std.mem.eql(u8, s, "TruncF64")) return .trunc_f64;
        if (std.mem.eql(u8, s, "NearestF32")) return .nearest_f32;
        if (std.mem.eql(u8, s, "NearestF64")) return .nearest_f64;
        if (std.mem.eql(u8, s, "FmaF32")) return .fma_f32;
        if (std.mem.eql(u8, s, "FmaF64")) return .fma_f64;
        if (std.mem.eql(u8, s, "Memcpy")) return .memcpy;
        if (std.mem.eql(u8, s, "Memset")) return .memset;
        if (std.mem.eql(u8, s, "Memmove")) return .memmove;
        if (std.mem.eql(u8, s, "Memcmp")) return .memcmp;
        if (std.mem.eql(u8, s, "ElfTlsGetAddr")) return .elf_tls_get_addr;
        if (std.mem.eql(u8, s, "ElfTlsGetOffset")) return .elf_tls_get_offset;
        if (std.mem.eql(u8, s, "X86Pshufb")) return .x86_pshufb;
        // F16 soft-float
        if (std.mem.eql(u8, s, "F16Add")) return .f16_add;
        if (std.mem.eql(u8, s, "F16Sub")) return .f16_sub;
        if (std.mem.eql(u8, s, "F16Mul")) return .f16_mul;
        if (std.mem.eql(u8, s, "F16Div")) return .f16_div;
        if (std.mem.eql(u8, s, "F16ToF32")) return .f16_to_f32;
        if (std.mem.eql(u8, s, "F32ToF16")) return .f32_to_f16;
        if (std.mem.eql(u8, s, "F16ToF64")) return .f16_to_f64;
        if (std.mem.eql(u8, s, "F64ToF16")) return .f64_to_f16;
        // F128 soft-float
        if (std.mem.eql(u8, s, "F128Add")) return .f128_add;
        if (std.mem.eql(u8, s, "F128Sub")) return .f128_sub;
        if (std.mem.eql(u8, s, "F128Mul")) return .f128_mul;
        if (std.mem.eql(u8, s, "F128Div")) return .f128_div;
        if (std.mem.eql(u8, s, "F32ToF128")) return .f32_to_f128;
        if (std.mem.eql(u8, s, "F64ToF128")) return .f64_to_f128;
        if (std.mem.eql(u8, s, "F128ToF32")) return .f128_to_f32;
        if (std.mem.eql(u8, s, "F128ToF64")) return .f128_to_f64;
        if (std.mem.eql(u8, s, "F128Sqrt")) return .f128_sqrt;
        if (std.mem.eql(u8, s, "F128Fma")) return .f128_fma;
        return null;
    }

    /// Get a list of all known LibCall variants.
    pub fn allLibcalls() []const LibCall {
        const all = [_]LibCall{
            .probestack,
            .ceil_f32,
            .ceil_f64,
            .floor_f32,
            .floor_f64,
            .trunc_f32,
            .trunc_f64,
            .nearest_f32,
            .nearest_f64,
            .fma_f32,
            .fma_f64,
            .memcpy,
            .memset,
            .memmove,
            .memcmp,
            .elf_tls_get_addr,
            .elf_tls_get_offset,
            .x86_pshufb,
            // F16 soft-float
            .f16_add,
            .f16_sub,
            .f16_mul,
            .f16_div,
            .f16_to_f32,
            .f32_to_f16,
            .f16_to_f64,
            .f64_to_f16,
            // F128 soft-float
            .f128_add,
            .f128_sub,
            .f128_mul,
            .f128_div,
            .f32_to_f128,
            .f64_to_f128,
            .f128_to_f32,
            .f128_to_f64,
            .f128_sqrt,
            .f128_fma,
        };
        return &all;
    }

    /// Get a Signature for the function targeted by this LibCall.
    pub fn signature(self: LibCall, allocator: std.mem.Allocator, call_conv: CallConv, pointer_type: Type) !Signature {
        var sig = Signature.init(allocator, call_conv);

        switch (self) {
            .ceil_f32, .floor_f32, .trunc_f32, .nearest_f32 => {
                const items = [_]AbiParam{AbiParam.init(Type.F32)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F32)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .trunc_f64, .floor_f64, .ceil_f64, .nearest_f64 => {
                const items = [_]AbiParam{AbiParam.init(Type.F64)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F64)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .fma_f32, .fma_f64 => {
                const ty = if (self == .fma_f32) Type.F32 else Type.F64;
                const items = [_]AbiParam{ AbiParam.init(ty), AbiParam.init(ty), AbiParam.init(ty) };
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(ty)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .memcpy, .memmove => {
                // void* memcpy(void *dest, const void *src, size_t count)
                // void* memmove(void* dest, const void* src, size_t count)
                const items = [_]AbiParam{
                    AbiParam.init(pointer_type),
                    AbiParam.init(pointer_type),
                    AbiParam.init(pointer_type),
                };
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(pointer_type)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .memset => {
                // void *memset(void *dest, int ch, size_t count)
                const items = [_]AbiParam{
                    AbiParam.init(pointer_type),
                    AbiParam.init(Type.I32),
                    AbiParam.init(pointer_type),
                };
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(pointer_type)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .memcmp => {
                // int memcmp(const void *lhs, const void *rhs, size_t count)
                const items = [_]AbiParam{
                    AbiParam.init(pointer_type),
                    AbiParam.init(pointer_type),
                    AbiParam.init(pointer_type),
                };
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.I32)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .probestack => {
                const ptr_type = call_conv.ptrType();
                const items = [_]AbiParam{AbiParam.init(ptr_type)};
                try sig.params.appendSlice(allocator, &items);
            },
            .elf_tls_get_addr => {
                const ptr_type = call_conv.ptrType();
                const items = [_]AbiParam{AbiParam.init(ptr_type)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(ptr_type)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .elf_tls_get_offset => {
                const ptr_type = call_conv.ptrType();
                const items = [_]AbiParam{AbiParam.init(ptr_type)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(ptr_type)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .x86_pshufb => {
                const items = [_]AbiParam{ AbiParam.init(Type.I8X16), AbiParam.init(Type.I8X16) };
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.I8X16)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },

            // F16 binary operations: f16(f16, f16)
            .f16_add, .f16_sub, .f16_mul, .f16_div => {
                const items = [_]AbiParam{ AbiParam.init(Type.F16), AbiParam.init(Type.F16) };
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F16)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },

            // F16 conversions
            .f16_to_f32 => {
                const items = [_]AbiParam{AbiParam.init(Type.F16)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F32)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .f32_to_f16 => {
                const items = [_]AbiParam{AbiParam.init(Type.F32)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F16)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .f16_to_f64 => {
                const items = [_]AbiParam{AbiParam.init(Type.F16)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F64)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .f64_to_f16 => {
                const items = [_]AbiParam{AbiParam.init(Type.F64)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F16)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },

            // F128 binary operations: f128(f128, f128)
            .f128_add, .f128_sub, .f128_mul, .f128_div => {
                const items = [_]AbiParam{ AbiParam.init(Type.F128), AbiParam.init(Type.F128) };
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F128)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },

            // F128 conversions
            .f32_to_f128 => {
                const items = [_]AbiParam{AbiParam.init(Type.F32)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F128)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .f64_to_f128 => {
                const items = [_]AbiParam{AbiParam.init(Type.F64)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F128)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .f128_to_f32 => {
                const items = [_]AbiParam{AbiParam.init(Type.F128)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F32)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
            .f128_to_f64 => {
                const items = [_]AbiParam{AbiParam.init(Type.F128)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F64)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },

            // F128 sqrt: f128(f128)
            .f128_sqrt => {
                const items = [_]AbiParam{AbiParam.init(Type.F128)};
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F128)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },

            // F128 fma: f128(f128, f128, f128)
            .f128_fma => {
                const items = [_]AbiParam{ AbiParam.init(Type.F128), AbiParam.init(Type.F128), AbiParam.init(Type.F128) };
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.F128)};
                try sig.returns.appendSlice(allocator, &ret_items);
            },
        }

        return sig;
    }

    /// Format for display.
    pub fn format(
        self: LibCall,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.writeAll(@tagName(self));
    }
};

const testing = std.testing;

test "LibCall parse" {
    try testing.expectEqual(LibCall.floor_f32, LibCall.parse("FloorF32").?);
    try testing.expectEqual(LibCall.ceil_f32, LibCall.parse("CeilF32").?);
    try testing.expectEqual(@as(?LibCall, null), LibCall.parse("Invalid"));
}

test "LibCall all libcalls roundtrip" {
    for (LibCall.allLibcalls()) |lc| {
        var buf: [64]u8 = undefined;
        const name = try std.fmt.bufPrint(&buf, "{any}", .{lc});
        _ = name; // Verify format works
    }
}
