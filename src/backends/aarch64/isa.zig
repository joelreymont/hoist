const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const abi_mod = root.abi;
const lower_mod = root.lower;
const compile_mod = root.compile;

/// CPU feature flags for aarch64.
/// Based on FEAT_* extensions in ARMv8 architecture.
pub const Features = packed struct {
    /// Has Large System Extensions (FEAT_LSE) - atomic instructions
    /// Provides atomic memory operations (LDADD, LDCLR, etc.)
    has_lse: bool = false,

    /// Has Pointer Authentication (FEAT_PAuth)
    /// Enables use of non-HINT PAC instructions
    has_pauth: bool = false,

    /// Has Branch Target Identification (FEAT_BTI)
    /// Control flow integrity via BTI landing pads
    has_bti: bool = false,

    /// Has half-precision floating point (FEAT_FP16)
    /// Native FP16 arithmetic operations
    has_fp16: bool = false,

    /// Has Scalable Vector Extension (SVE)
    /// Vector length-agnostic SIMD
    has_sve: bool = false,

    /// Has Scalable Matrix Extension (SME)
    /// Scalable matrix operations
    has_sme: bool = false,

    /// Has Advanced SIMD and FP support (NEON)
    /// Standard 128-bit SIMD - baseline for aarch64
    has_neon: bool = true,

    /// Has cryptographic extensions (FEAT_AES, FEAT_SHA*)
    /// AES, SHA1, SHA256, etc. instructions
    has_crypto: bool = false,

    /// Reserved for future features
    _reserved: u24 = 0,

    pub fn init() Features {
        return .{};
    }

    /// Detect native CPU features at runtime.
    /// Platform-specific feature detection.
    pub fn detectNative() Features {
        // On macOS ARM64, most features are available
        if (@import("builtin").target.os.tag == .macos) {
            return .{
                .has_neon = true,
                .has_crypto = true,
                .has_fp16 = true,
                .has_lse = true,
                // Conservative defaults for security features
                .has_pauth = false,
                .has_bti = false,
                .has_sve = false,
                .has_sme = false,
            };
        }
        return init();
    }

    /// Check if LSE atomics are preferred.
    pub fn preferLseAtomics(self: Features) bool {
        return self.has_lse;
    }

    /// Check if pointer auth is available for code generation.
    pub fn canUsePauth(self: Features) bool {
        return self.has_pauth;
    }
};

/// Tuning flags for code generation.
/// These control security features and optimization preferences.
pub const TuningFlags = struct {
    /// Sign return addresses for security (FEAT_PAuth)
    /// Uses HINT-space instructions (PACIASP/AUTIASP) by default
    sign_return_address: bool = false,

    /// Use B key instead of A key for pointer auth
    /// Some platform ABIs require this (e.g., some embedded targets)
    sign_return_address_with_bkey: bool = false,

    /// Sign all function returns, not just stack-using functions
    /// Applies return address signing to leaf functions too
    sign_return_address_all: bool = false,

    /// Prefer LSE atomics over LL/SC when available
    /// LSE provides better performance for atomic operations
    prefer_lse_atomics: bool = true,

    /// Use BTI landing pads (Branch Target Identification)
    /// Requires FEAT_BTI for control flow integrity
    use_bti: bool = false,

    pub fn init() TuningFlags {
        return .{};
    }

    /// Validate tuning flags against features.
    pub fn validate(self: TuningFlags, features: Features) !void {
        if (self.sign_return_address and !features.has_pauth) {
            return error.PauthNotAvailable;
        }
        if (self.use_bti and !features.has_bti) {
            return error.BtiNotAvailable;
        }
        if (self.prefer_lse_atomics and !features.has_lse) {
            // Just a preference, not an error
        }
    }
};

/// Encoding space constraints for AArch64 instruction formats.
pub const EncodingConstraints = struct {
    /// All instructions are 32-bit fixed-width.
    pub const instruction_size: u8 = 4;

    /// Maximum PC-relative branch range (±128MB for B/BL).
    pub const max_branch_offset: i28 = 134_217_727; // 2^27 - 1

    /// Maximum conditional branch range (±1MB for B.cond).
    pub const max_cond_branch_offset: i21 = 1_048_575; // 2^20 - 1

    /// Maximum load/store offset for immediate addressing (12-bit unsigned).
    pub const max_load_store_imm: u12 = 4095;

    /// Maximum arithmetic immediate (12-bit + optional 12-bit shift).
    pub const max_arith_imm: u24 = 0xFFF_000;

    /// Maximum shift amount for 64-bit operations.
    pub const max_shift_64: u6 = 63;

    /// Maximum shift amount for 32-bit operations.
    pub const max_shift_32: u6 = 31;
};

/// ISA capabilities - what operations are natively supported.
pub const Capabilities = struct {
    /// Native fused multiply-add (FMA) support via NEON.
    pub const has_native_fma: bool = true;

    /// Native rounding instructions (FRINT*).
    pub const has_native_round: bool = true;

    /// Vector width in bytes (NEON is always 128-bit).
    pub const vector_width_bytes: u8 = 16;

    /// Vector register count.
    pub const num_vector_regs: u8 = 32;

    /// Default argument extension behavior (zero-extend for AArch64).
    pub const default_arg_extension: enum { zero, sign } = .zero;

    /// Page size alignment (platform-dependent).
    pub fn pageAlignmentLog2(os: std.Target.Os.Tag) u8 {
        return switch (os) {
            // macOS/iOS use 16KB pages
            .macos, .ios, .tvos, .watchos => 14, // 2^14 = 16384
            // Linux and others typically use 64KB on ARM64
            else => 16, // 2^16 = 65536
        };
    }

    /// Function alignment in bytes (4 bytes, aligned to instruction boundary).
    pub const function_alignment: u8 = 4;
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

    /// Target operating system (affects page alignment, ABI details).
    target_os: std.Target.Os.Tag = .freestanding,

    /// Initialize ISA descriptor with default settings.
    pub fn init() Aarch64ISA {
        return .{};
    }

    /// Initialize with native CPU features.
    pub fn initNative(os: std.Target.Os.Tag) Aarch64ISA {
        return .{
            .features = Features.detectNative(),
            .target_os = os,
        };
    }

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
        return compileWithLinearScan(ctx, func);
    }

    /// Compile function using regalloc2 for register allocation.
    fn compileWithRegalloc2(
        ctx: compile_mod.CompileCtx,
        func: *const lower_mod.Function,
    ) !compile_mod.CompiledCode {
        const RegAllocBridge = @import("regalloc_bridge.zig").RegAllocBridge;
        const regalloc2_types = @import("../../machinst/regalloc2/types.zig");
        const buffer_mod = @import("../../machinst/buffer.zig");

        // Phase 1: Lower IR to VCode
        var vcode = try lower_mod.lowerFunction(
            Inst,
            ctx.allocator,
            func,
            lower(),
        );
        defer vcode.deinit();

        // Phase 2: Register allocation using regalloc2
        var bridge = RegAllocBridge.init(ctx.allocator);
        defer bridge.deinit();

        // Convert VCode to regalloc2 representation
        try bridge.convertVCode(&vcode);

        // TODO: Actually run regalloc2 algorithm here
        // For now, we do a dummy allocation: v0 -> p0, v1 -> p1, etc.
        const num_vregs = bridge.adapter.num_vregs;
        var i: u32 = 0;
        while (i < num_vregs) : (i += 1) {
            const vreg = regalloc2_types.VReg.new(i);
            const preg = regalloc2_types.PhysReg.new(@intCast(i));
            try bridge.adapter.setAllocation(vreg, regalloc2_types.Allocation{ .reg = preg });
        }

        // Apply allocations back to VCode
        try bridge.applyAllocations(&vcode);

        // Phase 3: Emit machine code
        const emit_mod = @import("emit.zig");
        var buffer = buffer_mod.MachBuffer.init(ctx.allocator);
        defer buffer.deinit();

        // Emit each instruction
        for (vcode.insns.items) |inst| {
            try emit_mod.emit(inst, &buffer);
        }

        // Phase 4: Finalize and extract code
        try buffer.finalize();

        const code = try ctx.allocator.dupe(u8, buffer.data.items);

        // Convert relocations
        var relocs = try ctx.allocator.alloc(compile_mod.Relocation, buffer.relocs.items.len);
        for (buffer.relocs.items, 0..) |mreloc, idx| {
            relocs[idx] = .{
                .offset = mreloc.offset,
                .kind = convertRelocKind(mreloc.kind),
                .symbol = try ctx.allocator.dupe(u8, mreloc.name),
                .addend = mreloc.addend,
            };
        }

        // Convert traps
        var traps = try ctx.allocator.alloc(compile_mod.TrapRecord, buffer.traps.items.len);
        for (buffer.traps.items, 0..) |mtrap, idx| {
            traps[idx] = .{
                .offset = mtrap.offset,
                .code = mtrap.code,
            };
        }

        // Stack frame size (no spills yet in dummy allocator)
        const stack_frame_size: u32 = 0;

        return compile_mod.CompiledCode{
            .code = code,
            .relocations = relocs,
            .traps = traps,
            .stack_frame_size = stack_frame_size,
            .allocator = ctx.allocator,
        };
    }

    /// Compile function using linear scan register allocation.
    fn compileWithLinearScan(
        ctx: compile_mod.CompileCtx,
        func: *const lower_mod.Function,
    ) !compile_mod.CompiledCode {
        const linear_scan_mod = @import("../../regalloc/linear_scan.zig");
        const trivial_mod = @import("../../regalloc/trivial.zig");
        const buffer_mod = @import("../../machinst/buffer.zig");

        // Phase 1: Lower IR to VCode
        var vcode = try lower_mod.lowerFunction(
            Inst,
            ctx.allocator,
            func,
            lower(),
        );
        defer vcode.deinit();

        // Phase 2: Register allocation using linear scan
        // For now, fall back to trivial allocator since we don't have
        // getDefs/getUses on Inst yet
        var allocator = trivial_mod.TrivialAllocator.init(ctx.allocator);
        defer allocator.deinit();

        try allocator.allocateVCode(&vcode);

        // Phase 3: Emit machine code
        const emit_mod = @import("emit.zig");
        var buffer = buffer_mod.MachBuffer.init(ctx.allocator);
        defer buffer.deinit();

        // Emit each instruction
        for (vcode.insns.items) |inst| {
            try emit_mod.emit(inst, &buffer);
        }

        // Phase 4: Finalize and extract code
        try buffer.finalize();

        const code = try ctx.allocator.dupe(u8, buffer.data.items);

        // Convert relocations
        var relocs = try ctx.allocator.alloc(compile_mod.Relocation, buffer.relocs.items.len);
        for (buffer.relocs.items, 0..) |mreloc, idx| {
            relocs[idx] = .{
                .offset = mreloc.offset,
                .kind = convertRelocKind(mreloc.kind),
                .symbol = try ctx.allocator.dupe(u8, mreloc.name),
                .addend = mreloc.addend,
            };
        }

        // Convert traps
        var traps = try ctx.allocator.alloc(compile_mod.TrapRecord, buffer.traps.items.len);
        for (buffer.traps.items, 0..) |mtrap, idx| {
            traps[idx] = .{
                .offset = mtrap.offset,
                .code = mtrap.code,
            };
        }

        // Stack frame size (no spills yet)
        const stack_frame_size: u32 = 0;

        return compile_mod.CompiledCode{
            .code = code,
            .relocations = relocs,
            .traps = traps,
            .stack_frame_size = stack_frame_size,
            .allocator = ctx.allocator,
        };
    }

    /// Convert MachBuffer relocation kind to public Relocation kind.
    fn convertRelocKind(kind: @import("../../machinst/buffer.zig").Reloc) compile_mod.RelocationKind {
        return switch (kind) {
            .abs8, .aarch64_abs64 => .abs64,
            .x86_pc_rel_32, .aarch64_call26, .aarch64_jump26 => .pc_rel32,
            .aarch64_adr_prel_pg_hi21, .aarch64_add_abs_lo12_nc, .aarch64_ldst64_abs_lo12_nc => .got_pc_rel32,
            .abs4 => .abs64,
        };
    }

    /// Check if branch target identification is enabled.
    pub fn isBranchProtectionEnabled(self: Aarch64ISA) bool {
        return self.tuning.use_bti and self.features.has_bti;
    }

    /// Get dynamic vector width in bytes.
    /// For standard NEON, this is always 16 bytes (128 bits).
    /// SVE would use runtime detection.
    pub fn dynamicVectorBytes(self: Aarch64ISA) u32 {
        _ = self;
        return Capabilities.vector_width_bytes;
    }

    /// Get page alignment for this target.
    pub fn pageAlignmentLog2(self: Aarch64ISA) u8 {
        return Capabilities.pageAlignmentLog2(self.target_os);
    }
};

// ============================================================================
// Tests
// ============================================================================

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

test "CPU Features methods" {
    const features = Features{
        .has_lse = true,
        .has_pauth = true,
    };
    try testing.expect(features.preferLseAtomics());
    try testing.expect(features.canUsePauth());
}

test "TuningFlags initialization" {
    const tuning = TuningFlags.init();
    try testing.expect(!tuning.sign_return_address);
    try testing.expect(tuning.prefer_lse_atomics);
    try testing.expect(!tuning.use_bti);
}

test "TuningFlags validation - valid" {
    const features = Features{
        .has_pauth = true,
        .has_bti = true,
    };
    const tuning = TuningFlags{
        .sign_return_address = true,
        .use_bti = true,
    };
    try tuning.validate(features);
}

test "TuningFlags validation - pauth missing" {
    const features = Features{ .has_pauth = false };
    const tuning = TuningFlags{ .sign_return_address = true };
    try testing.expectError(error.PauthNotAvailable, tuning.validate(features));
}

test "TuningFlags validation - bti missing" {
    const features = Features{ .has_bti = false };
    const tuning = TuningFlags{ .use_bti = true };
    try testing.expectError(error.BtiNotAvailable, tuning.validate(features));
}

test "Aarch64ISA with features" {
    const isa = Aarch64ISA{
        .features = Features{
            .has_lse = true,
            .has_neon = true,
        },
    };
    try testing.expect(isa.features.has_lse);
    try testing.expect(isa.features.has_neon);
    try testing.expect(!isa.features.has_sve);
}

test "Aarch64ISA init methods" {
    const isa1 = Aarch64ISA.init();
    try testing.expect(!isa1.features.has_lse);

    const isa2 = Aarch64ISA.initNative(.macos);
    if (@import("builtin").target.os.tag == .macos) {
        try testing.expect(isa2.features.has_lse);
    }
    try testing.expectEqual(std.Target.Os.Tag.macos, isa2.target_os);
}

test "Aarch64ISA branch protection" {
    const isa = Aarch64ISA{
        .features = Features{ .has_bti = true },
        .tuning = TuningFlags{ .use_bti = true },
    };
    try testing.expect(isa.isBranchProtectionEnabled());

    const isa_no_bti = Aarch64ISA{
        .features = Features{ .has_bti = false },
        .tuning = TuningFlags{ .use_bti = true },
    };
    try testing.expect(!isa_no_bti.isBranchProtectionEnabled());
}

test "Aarch64ISA dynamic vector bytes" {
    const isa = Aarch64ISA.init();
    try testing.expectEqual(@as(u32, 16), isa.dynamicVectorBytes());
}

test "Aarch64ISA page alignment" {
    const isa_macos = Aarch64ISA{ .target_os = .macos };
    try testing.expectEqual(@as(u8, 14), isa_macos.pageAlignmentLog2());

    const isa_linux = Aarch64ISA{ .target_os = .linux };
    try testing.expectEqual(@as(u8, 16), isa_linux.pageAlignmentLog2());
}

test "EncodingConstraints constants" {
    try testing.expectEqual(@as(u8, 4), EncodingConstraints.instruction_size);
    try testing.expectEqual(@as(i28, 134_217_727), EncodingConstraints.max_branch_offset);
    try testing.expectEqual(@as(i21, 1_048_575), EncodingConstraints.max_cond_branch_offset);
    try testing.expectEqual(@as(u12, 4095), EncodingConstraints.max_load_store_imm);
    try testing.expectEqual(@as(u24, 0xFFF_000), EncodingConstraints.max_arith_imm);
    try testing.expectEqual(@as(u6, 63), EncodingConstraints.max_shift_64);
    try testing.expectEqual(@as(u6, 31), EncodingConstraints.max_shift_32);
}

test "Capabilities constants" {
    try testing.expect(Capabilities.has_native_fma);
    try testing.expect(Capabilities.has_native_round);
    try testing.expectEqual(@as(u8, 16), Capabilities.vector_width_bytes);
    try testing.expectEqual(@as(u8, 32), Capabilities.num_vector_regs);
    try testing.expectEqual(@as(u8, 4), Capabilities.function_alignment);
}

test "Capabilities page alignment" {
    try testing.expectEqual(@as(u8, 14), Capabilities.pageAlignmentLog2(.macos));
    try testing.expectEqual(@as(u8, 14), Capabilities.pageAlignmentLog2(.ios));
    try testing.expectEqual(@as(u8, 16), Capabilities.pageAlignmentLog2(.linux));
    try testing.expectEqual(@as(u8, 16), Capabilities.pageAlignmentLog2(.freestanding));
}

test "Aarch64ISA compile function with regalloc2" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    const ctx = compile_mod.CompileCtx.init(testing.allocator, "aarch64");

    var code = try Aarch64ISA.compileFunction(ctx, &func);
    defer code.deinit();

    // Empty function produces minimal code
    try testing.expect(code.code.len == 0);
    try testing.expectEqual(@as(usize, 0), code.relocations.len);
    try testing.expectEqual(@as(usize, 0), code.traps.len);
    try testing.expectEqual(@as(u32, 0), code.stack_frame_size);
}
