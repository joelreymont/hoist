const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const abi_mod = root.abi;
const lower_mod = root.lower;
const compile_mod = root.compile;

/// CPU feature flags for aarch64.
pub const Features = packed struct {
    /// Has Large System Extensions (FEAT_LSE) - atomic instructions
    has_lse: bool = false,
    /// Has Pointer Authentication (FEAT_PAuth)
    has_pauth: bool = false,
    /// Has Branch Target Identification (FEAT_BTI)
    has_bti: bool = false,
    /// Has half-precision floating point (FEAT_FP16)
    has_fp16: bool = false,
    /// Has Scalable Vector Extension (SVE)
    has_sve: bool = false,
    /// Has Scalable Matrix Extension (SME)
    has_sme: bool = false,
    /// Has Advanced SIMD and FP support
    has_neon: bool = true,
    /// Has cryptographic extensions
    has_crypto: bool = false,
    /// Reserved for future features
    _reserved: u24 = 0,

    pub fn init() Features {
        return .{};
    }

    pub fn detectNative() Features {
        // On macOS ARM64, most features are available
        if (@import("builtin").target.os.tag == .macos) {
            return .{
                .has_neon = true,
                .has_crypto = true,
                .has_fp16 = true,
                .has_lse = true,
                // Conservative defaults for other features
                .has_pauth = false,
                .has_bti = false,
                .has_sve = false,
                .has_sme = false,
            };
        }
        return init();
    }
};

/// Tuning flags for code generation.
pub const TuningFlags = struct {
    /// Sign return addresses for security (FEAT_PAuth)
    sign_return_address: bool = false,
    /// Use B key instead of A key for pointer auth
    sign_return_address_with_bkey: bool = false,
    /// Sign all function returns, not just stack-using functions
    sign_return_address_all: bool = false,
    /// Prefer LSE atomics over LL/SC when available
    prefer_lse_atomics: bool = true,
    /// Use BTI landing pads
    use_bti: bool = false,

    pub fn init() TuningFlags {
        return .{};
    }
};

/// ARM64 ISA descriptor.
/// This integrates all aarch64 backend components into a unified interface.
pub const Aarch64ISA = struct {
    /// ISA name.
    pub const name = "aarch64";

    /// Machine instruction type.
    pub const MachInst = Inst;

    /// CPU features detected or configured.
    features: Features = Features.init(),

    /// Code generation tuning flags.
    tuning: TuningFlags = TuningFlags.init(),

    /// ABI specification for this ISA.
    pub fn abi(call_conv: abi_mod.CallConv) abi_mod.ABIMachineSpec(u64) {
        return switch (call_conv) {
            .aapcs64 => @import("abi.zig").aapcs64(),
            .system_v, .windows_fastcall => unreachable,
        };
    }

    /// Lowering backend for instruction selection.
    pub fn lower() lower_mod.LowerBackend(Inst) {
        return @import("lower.zig").Aarch64Lower.backend();
    }

    /// Register information.
    pub const registers = struct {
        /// Number of general-purpose registers (X0-X30).
        pub const num_gpr: u8 = 31;
        /// Number of vector registers (V0-V31).
        pub const num_vec: u8 = 32;
        /// Stack pointer register.
        pub const sp_reg = 31; // SP (X31)
        /// Frame pointer register.
        pub const fp_reg = 29; // X29
        /// Link register.
        pub const lr_reg: ?u8 = 30; // X30
    };

    /// Compile a function to machine code using this ISA.
    pub fn compileFunction(
        ctx: compile_mod.CompileCtx,
        func: *const lower_mod.Function,
    ) !compile_mod.CompiledCode {
        return compile_mod.compile(
            Inst,
            ctx,
            func,
            lower(),
        );
    }
};

test "Aarch64ISA basic properties" {
    try testing.expectEqualStrings("aarch64", Aarch64ISA.name);
    try testing.expectEqual(@as(u8, 31), Aarch64ISA.registers.num_gpr);
    try testing.expectEqual(@as(u8, 32), Aarch64ISA.registers.num_vec);
    try testing.expectEqual(@as(u8, 31), Aarch64ISA.registers.sp_reg);
    try testing.expectEqual(@as(u8, 29), Aarch64ISA.registers.fp_reg);
    try testing.expectEqual(@as(u8, 30), Aarch64ISA.registers.lr_reg.?);
}

test "Aarch64ISA ABI selection" {
    const aapcs = Aarch64ISA.abi(.aapcs64);

    // AAPCS64 has 8 int arg regs (X0-X7)
    try testing.expectEqual(@as(usize, 8), aapcs.int_arg_regs.len);

    // AAPCS64 has 8 float arg regs (V0-V7)
    try testing.expectEqual(@as(usize, 8), aapcs.float_arg_regs.len);
}

test "Aarch64ISA lowering backend" {
    const backend = Aarch64ISA.lower();

    // Should have function pointers
    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);
}

test "Aarch64ISA compile function" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    const ctx = compile_mod.CompileCtx.init(testing.allocator, "aarch64");

    var code = try Aarch64ISA.compileFunction(ctx, &func);
    defer code.deinit();

    // Empty function produces minimal code
    try testing.expect(code.code.len == 0);
}

test "CPU Features initialization" {
    const features = Features.init();
    try testing.expect(!features.has_lse);
    try testing.expect(!features.has_pauth);
    try testing.expect(!features.has_sve);
    try testing.expect(!features.has_sme);
    try testing.expect(features.has_neon);
    try testing.expect(!features.has_crypto);
}

test "CPU Features native detection" {
    const features = Features.detectNative();
    try testing.expect(features.has_neon);
    // macOS ARM64 should have these
    if (@import("builtin").target.os.tag == .macos) {
        try testing.expect(features.has_lse);
        try testing.expect(features.has_fp16);
        try testing.expect(features.has_crypto);
    }
}

test "TuningFlags initialization" {
    const tuning = TuningFlags.init();
    try testing.expect(!tuning.sign_return_address);
    try testing.expect(tuning.prefer_lse_atomics);
    try testing.expect(!tuning.use_bti);
}

test "Aarch64ISA with features" {
    var isa = Aarch64ISA{
        .features = Features{
            .has_lse = true,
            .has_neon = true,
        },
    };
    try testing.expect(isa.features.has_lse);
    try testing.expect(isa.features.has_neon);
    try testing.expect(!isa.features.has_sve);
}
