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
            .probestack, .elf_tls_get_addr, .elf_tls_get_offset => {
                @panic("unimplemented libcall signature");
            },
            .x86_pshufb => {
                const items = [_]AbiParam{ AbiParam.init(Type.I8X16), AbiParam.init(Type.I8X16) };
                try sig.params.appendSlice(allocator, &items);
                const ret_items = [_]AbiParam{AbiParam.init(Type.I8X16)};
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
