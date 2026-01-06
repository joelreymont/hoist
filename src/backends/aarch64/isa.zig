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

    /// Insert spill and reload instructions for spilled virtual registers.
    ///
    /// For each spilled vreg:
    /// - Insert STR after its definition to save to stack
    /// - Insert LDR before each use to reload from stack
    fn insertSpillReloads(
        vcode: *lower_mod.VCode(Inst),
        result: *const @import("../../regalloc/linear_scan.zig").RegAllocResult,
        liveness_info: *const @import("../../regalloc/liveness.zig").LivenessInfo,
        allocator: std.mem.Allocator,
    ) !void {
        const linear_scan_mod = @import("../../regalloc/linear_scan.zig");
        const reg_mod = @import("../../machinst/reg.zig");

        // Collect all spilled vregs
        var spilled_vregs = std.ArrayList(struct {
            vreg: reg_mod.VReg,
            slot: linear_scan_mod.SpillSlot,
        }).init(allocator);
        defer spilled_vregs.deinit();

        // Iterate through all live ranges to find spilled vregs
        for (liveness_info.ranges.items) |range| {
            if (result.getSpillSlot(range.vreg)) |slot| {
                try spilled_vregs.append(.{
                    .vreg = range.vreg,
                    .slot = slot,
                });
            }
        }

        if (spilled_vregs.items.len == 0) return;

        // Build list of instruction insertions (spills and reloads)
        var insertions = std.ArrayList(struct {
            position: u32, // Instruction index to insert after/before
            insert_after: bool, // true = after, false = before
            inst: Inst,
        }).init(allocator);
        defer insertions.deinit();

        // For each spilled vreg, find def/use points and insert spill/reload
        for (spilled_vregs.items) |spill_info| {
            const vreg = spill_info.vreg;
            const slot_offset = spill_info.slot.offset;

            // Find def and use positions
            for (vcode.insns.items, 0..) |inst, idx| {
                var inst_copy = inst;
                const defs = try inst_copy.getDefs(allocator);
                defer allocator.free(defs);

                const uses = try inst_copy.getUses(allocator);
                defer allocator.free(uses);

                // Check if this instruction defines the spilled vreg
                for (defs) |def_vreg| {
                    if (def_vreg.index == vreg.index) {
                        // Insert spill store after this instruction
                        // STR Xn, [sp, #offset]
                        const preg = result.getPhysReg(vreg) orelse continue;

                        try insertions.append(.{
                            .position = @intCast(idx),
                            .insert_after = true,
                            .inst = .{
                                .str = .{
                                    .src = preg.toReg(),
                                    .base = reg_mod.Reg.fromPReg(reg_mod.PReg.new(.int, 31)), // SP
                                    .offset = @intCast(slot_offset),
                                    .size = .size64,
                                },
                            },
                        });
                    }
                }

                // Check if this instruction uses the spilled vreg
                for (uses) |use_vreg| {
                    if (use_vreg.index == vreg.index) {
                        // Insert reload before this instruction
                        // LDR Xn, [sp, #offset]
                        const preg = result.getPhysReg(vreg) orelse continue;

                        try insertions.append(.{
                            .position = @intCast(idx),
                            .insert_after = false,
                            .inst = .{
                                .ldr = .{
                                    .dst = reg_mod.WritableReg.init(preg.toReg()),
                                    .base = reg_mod.Reg.fromPReg(reg_mod.PReg.new(.int, 31)), // SP
                                    .offset = @intCast(slot_offset),
                                    .size = .size64,
                                },
                            },
                        });
                    }
                }
            }
        }

        // Sort insertions by position (descending) to insert from end to start
        // This preserves instruction indices
        std.mem.sort(@TypeOf(insertions.items[0]), insertions.items, {}, struct {
            fn lessThan(_: void, a: @TypeOf(insertions.items[0]), b: @TypeOf(insertions.items[0])) bool {
                if (a.position != b.position) return a.position > b.position;
                // Insert "after" operations before "before" operations at same position
                return a.insert_after and !b.insert_after;
            }
        }.lessThan);

        // Apply insertions
        for (insertions.items) |insertion| {
            const insert_idx = if (insertion.insert_after)
                insertion.position + 1
            else
                insertion.position;

            try vcode.insns.insert(allocator, insert_idx, insertion.inst);
        }
    }

    /// Apply register allocations to an instruction.
    /// Replaces virtual registers with allocated physical registers.
    fn applyAllocations(
        inst: *Inst,
        result: *const @import("../../regalloc/linear_scan.zig").RegAllocResult,
    ) !void {
        const reg_mod = @import("../../machinst/reg.zig");

        // Helper to replace a Reg if it's a virtual register
        const replaceReg = struct {
            fn apply(reg: reg_mod.Reg, alloc_result: *const @import("../../regalloc/linear_scan.zig").RegAllocResult) reg_mod.Reg {
                if (reg.toVReg()) |vreg| {
                    if (alloc_result.getPhysReg(vreg)) |preg| {
                        return preg.toReg();
                    }
                }
                return reg;
            }
        }.apply;

        // Helper to replace a WritableReg if it's a virtual register
        const replaceWritableReg = struct {
            fn apply(wreg: reg_mod.WritableReg, alloc_result: *const @import("../../regalloc/linear_scan.zig").RegAllocResult) reg_mod.WritableReg {
                const reg = wreg.toReg();
                if (reg.toVReg()) |vreg| {
                    if (alloc_result.getPhysReg(vreg)) |preg| {
                        return reg_mod.WritableReg.init(preg.toReg());
                    }
                }
                return wreg;
            }
        }.apply;

        // Apply allocations based on instruction type
        // This is a simplified version that handles common cases
        switch (inst.*) {
            .mov_rr => |*mov| {
                mov.src = replaceReg(mov.src, result);
                mov.dst = replaceWritableReg(mov.dst, result);
            },
            .mov_imm => |*mov| {
                mov.dst = replaceWritableReg(mov.dst, result);
            },
            .add_rr => |*add| {
                add.src1 = replaceReg(add.src1, result);
                add.src2 = replaceReg(add.src2, result);
                add.dst = replaceWritableReg(add.dst, result);
            },
            .mul_rr => |*mul| {
                mul.src1 = replaceReg(mul.src1, result);
                mul.src2 = replaceReg(mul.src2, result);
                mul.dst = replaceWritableReg(mul.dst, result);
            },
            .add_imm => |*add| {
                add.src = replaceReg(add.src, result);
                add.dst = replaceWritableReg(add.dst, result);
            },
            .sub_rr => |*sub| {
                sub.src1 = replaceReg(sub.src1, result);
                sub.src2 = replaceReg(sub.src2, result);
                sub.dst = replaceWritableReg(sub.dst, result);
            },
            .sub_imm => |*sub| {
                sub.src = replaceReg(sub.src, result);
                sub.dst = replaceWritableReg(sub.dst, result);
            },
            .and_rr => |*and_inst| {
                and_inst.src1 = replaceReg(and_inst.src1, result);
                and_inst.src2 = replaceReg(and_inst.src2, result);
                and_inst.dst = replaceWritableReg(and_inst.dst, result);
            },
            .and_imm => |*and_inst| {
                and_inst.src = replaceReg(and_inst.src, result);
                and_inst.dst = replaceWritableReg(and_inst.dst, result);
            },
            .orr_rr => |*orr| {
                orr.src1 = replaceReg(orr.src1, result);
                orr.src2 = replaceReg(orr.src2, result);
                orr.dst = replaceWritableReg(orr.dst, result);
            },
            .orr_imm => |*orr| {
                orr.src = replaceReg(orr.src, result);
                orr.dst = replaceWritableReg(orr.dst, result);
            },
            .eor_rr => |*eor| {
                eor.src1 = replaceReg(eor.src1, result);
                eor.src2 = replaceReg(eor.src2, result);
                eor.dst = replaceWritableReg(eor.dst, result);
            },
            .eor_imm => |*eor| {
                eor.src = replaceReg(eor.src, result);
                eor.dst = replaceWritableReg(eor.dst, result);
            },
            .lsl_rr => |*lsl| {
                lsl.src1 = replaceReg(lsl.src1, result);
                lsl.src2 = replaceReg(lsl.src2, result);
                lsl.dst = replaceWritableReg(lsl.dst, result);
            },
            .lsl_imm => |*lsl| {
                lsl.src = replaceReg(lsl.src, result);
                lsl.dst = replaceWritableReg(lsl.dst, result);
            },
            .lsr_rr => |*lsr| {
                lsr.src1 = replaceReg(lsr.src1, result);
                lsr.src2 = replaceReg(lsr.src2, result);
                lsr.dst = replaceWritableReg(lsr.dst, result);
            },
            .lsr_imm => |*lsr| {
                lsr.src = replaceReg(lsr.src, result);
                lsr.dst = replaceWritableReg(lsr.dst, result);
            },
            .asr_rr => |*asr| {
                asr.src1 = replaceReg(asr.src1, result);
                asr.src2 = replaceReg(asr.src2, result);
                asr.dst = replaceWritableReg(asr.dst, result);
            },
            .asr_imm => |*asr| {
                asr.src = replaceReg(asr.src, result);
                asr.dst = replaceWritableReg(asr.dst, result);
            },
            .cmp_rr => |*cmp| {
                cmp.src1 = replaceReg(cmp.src1, result);
                cmp.src2 = replaceReg(cmp.src2, result);
            },
            .cmp_imm => |*cmp| {
                cmp.src = replaceReg(cmp.src, result);
            },
            .add_shifted => |*add| {
                add.src1 = replaceReg(add.src1, result);
                add.src2 = replaceReg(add.src2, result);
                add.dst = replaceWritableReg(add.dst, result);
            },
            .sub_shifted => |*sub| {
                sub.src1 = replaceReg(sub.src1, result);
                sub.src2 = replaceReg(sub.src2, result);
                sub.dst = replaceWritableReg(sub.dst, result);
            },
            .bic_rr => |*bic| {
                bic.src1 = replaceReg(bic.src1, result);
                bic.src2 = replaceReg(bic.src2, result);
                bic.dst = replaceWritableReg(bic.dst, result);
            },
            .mvn_rr => |*mvn| {
                mvn.src = replaceReg(mvn.src, result);
                mvn.dst = replaceWritableReg(mvn.dst, result);
            },
            .ror_rr => |*ror| {
                ror.src1 = replaceReg(ror.src1, result);
                ror.src2 = replaceReg(ror.src2, result);
                ror.dst = replaceWritableReg(ror.dst, result);
            },
            .ror_imm => |*ror| {
                ror.src = replaceReg(ror.src, result);
                ror.dst = replaceWritableReg(ror.dst, result);
            },
            .fadd => |*fadd| {
                fadd.src1 = replaceReg(fadd.src1, result);
                fadd.src2 = replaceReg(fadd.src2, result);
                fadd.dst = replaceWritableReg(fadd.dst, result);
            },
            .fsub => |*fsub| {
                fsub.src1 = replaceReg(fsub.src1, result);
                fsub.src2 = replaceReg(fsub.src2, result);
                fsub.dst = replaceWritableReg(fsub.dst, result);
            },
            .fmul => |*fmul| {
                fmul.src1 = replaceReg(fmul.src1, result);
                fmul.src2 = replaceReg(fmul.src2, result);
                fmul.dst = replaceWritableReg(fmul.dst, result);
            },
            .fdiv => |*fdiv| {
                fdiv.src1 = replaceReg(fdiv.src1, result);
                fdiv.src2 = replaceReg(fdiv.src2, result);
                fdiv.dst = replaceWritableReg(fdiv.dst, result);
            },
            .fmov => |*fmov| {
                fmov.src = replaceReg(fmov.src, result);
                fmov.dst = replaceWritableReg(fmov.dst, result);
            },
            .fcmp => |*fcmp| {
                fcmp.src1 = replaceReg(fcmp.src1, result);
                fcmp.src2 = replaceReg(fcmp.src2, result);
            },
            .vec_add => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_sub => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_mul => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_and => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_orr => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_eor => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_fadd => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_fsub => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_fmul => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_fdiv => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_smin => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_smax => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_umin => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_umax => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_fmin => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_fmax => |*vec| {
                vec.src1 = replaceReg(vec.src1, result);
                vec.src2 = replaceReg(vec.src2, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_dup => |*vec| {
                vec.src = replaceReg(vec.src, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_dup_lane => |*vec| {
                vec.src = replaceReg(vec.src, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_extract_lane => |*vec| {
                vec.src = replaceReg(vec.src, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .vec_insert_lane => |*vec| {
                vec.vec = replaceReg(vec.vec, result);
                vec.src = replaceReg(vec.src, result);
                vec.dst = replaceWritableReg(vec.dst, result);
            },
            .ldr => |*ldr| {
                ldr.base = replaceReg(ldr.base, result);
                ldr.dst = replaceWritableReg(ldr.dst, result);
            },
            .ldr_ext => |*ldr| {
                ldr.base = replaceReg(ldr.base, result);
                ldr.offset = replaceReg(ldr.offset, result);
                ldr.dst = replaceWritableReg(ldr.dst, result);
            },
            .ldr_shifted => |*ldr| {
                ldr.base = replaceReg(ldr.base, result);
                ldr.offset = replaceReg(ldr.offset, result);
                ldr.dst = replaceWritableReg(ldr.dst, result);
            },
            .str => |*str| {
                str.src = replaceReg(str.src, result);
                str.base = replaceReg(str.base, result);
            },
            .str_ext => |*str| {
                str.src = replaceReg(str.src, result);
                str.base = replaceReg(str.base, result);
                str.offset = replaceReg(str.offset, result);
            },
            .str_shifted => |*str| {
                str.src = replaceReg(str.src, result);
                str.base = replaceReg(str.base, result);
                str.offset = replaceReg(str.offset, result);
            },
            .ldrb => |*ldrb| {
                ldrb.base = replaceReg(ldrb.base, result);
                ldrb.dst = replaceWritableReg(ldrb.dst, result);
            },
            .ldrh => |*ldrh| {
                ldrh.base = replaceReg(ldrh.base, result);
                ldrh.dst = replaceWritableReg(ldrh.dst, result);
            },
            .ldrsb => |*ldrsb| {
                ldrsb.base = replaceReg(ldrsb.base, result);
                ldrsb.dst = replaceWritableReg(ldrsb.dst, result);
            },
            .ldrsh => |*ldrsh| {
                ldrsh.base = replaceReg(ldrsh.base, result);
                ldrsh.dst = replaceWritableReg(ldrsh.dst, result);
            },
            .ldrsw => |*ldrsw| {
                ldrsw.base = replaceReg(ldrsw.base, result);
                ldrsw.dst = replaceWritableReg(ldrsw.dst, result);
            },
            .strb => |*strb| {
                strb.src = replaceReg(strb.src, result);
                strb.base = replaceReg(strb.base, result);
            },
            .strh => |*strh| {
                strh.src = replaceReg(strh.src, result);
                strh.base = replaceReg(strh.base, result);
            },
            .stp => |*stp| {
                stp.src1 = replaceReg(stp.src1, result);
                stp.src2 = replaceReg(stp.src2, result);
                stp.base = replaceReg(stp.base, result);
            },
            .ldp => |*ldp| {
                ldp.base = replaceReg(ldp.base, result);
                ldp.dst1 = replaceWritableReg(ldp.dst1, result);
                ldp.dst2 = replaceWritableReg(ldp.dst2, result);
            },
            .ldr_pre => |*ldr| {
                ldr.base = replaceReg(ldr.base, result);
                ldr.dst = replaceWritableReg(ldr.dst, result);
                ldr.base = replaceWritableReg(ldr.base, result);
            },
            .ldr_post => |*ldr| {
                ldr.base = replaceReg(ldr.base, result);
                ldr.dst = replaceWritableReg(ldr.dst, result);
                ldr.base = replaceWritableReg(ldr.base, result);
            },
            .str_pre => |*str| {
                str.src = replaceReg(str.src, result);
                str.base = replaceReg(str.base, result);
                str.base = replaceWritableReg(str.base, result);
            },
            .str_post => |*str| {
                str.src = replaceReg(str.src, result);
                str.base = replaceReg(str.base, result);
                str.base = replaceWritableReg(str.base, result);
            },
            .ldarb => |*ldarb| {
                ldarb.base = replaceReg(ldarb.base, result);
                ldarb.dst = replaceWritableReg(ldarb.dst, result);
            },
            .ldarh => |*ldarh| {
                ldarh.base = replaceReg(ldarh.base, result);
                ldarh.dst = replaceWritableReg(ldarh.dst, result);
            },
            .ldar_w => |*ldar| {
                ldar.base = replaceReg(ldar.base, result);
                ldar.dst = replaceWritableReg(ldar.dst, result);
            },
            .ldar => |*ldar| {
                ldar.base = replaceReg(ldar.base, result);
                ldar.dst = replaceWritableReg(ldar.dst, result);
            },
            .stlrb => |*stlrb| {
                stlrb.src = replaceReg(stlrb.src, result);
                stlrb.base = replaceReg(stlrb.base, result);
            },
            .stlrh => |*stlrh| {
                stlrh.src = replaceReg(stlrh.src, result);
                stlrh.base = replaceReg(stlrh.base, result);
            },
            .stlr_w => |*stlr| {
                stlr.src = replaceReg(stlr.src, result);
                stlr.base = replaceReg(stlr.base, result);
            },
            .stlr => |*stlr| {
                stlr.src = replaceReg(stlr.src, result);
                stlr.base = replaceReg(stlr.base, result);
            },
            .ldxrb => |*ldxrb| {
                ldxrb.base = replaceReg(ldxrb.base, result);
                ldxrb.dst = replaceWritableReg(ldxrb.dst, result);
            },
            .ldxrh => |*ldxrh| {
                ldxrh.base = replaceReg(ldxrh.base, result);
                ldxrh.dst = replaceWritableReg(ldxrh.dst, result);
            },
            .ldxr_w => |*ldxr| {
                ldxr.base = replaceReg(ldxr.base, result);
                ldxr.dst = replaceWritableReg(ldxr.dst, result);
            },
            .ldxr => |*ldxr| {
                ldxr.base = replaceReg(ldxr.base, result);
                ldxr.dst = replaceWritableReg(ldxr.dst, result);
            },
            .stxrb => |*stxrb| {
                stxrb.src = replaceReg(stxrb.src, result);
                stxrb.base = replaceReg(stxrb.base, result);
                stxrb.status = replaceWritableReg(stxrb.status, result);
            },
            .stxrh => |*stxrh| {
                stxrh.src = replaceReg(stxrh.src, result);
                stxrh.base = replaceReg(stxrh.base, result);
                stxrh.status = replaceWritableReg(stxrh.status, result);
            },
            .stxr_w => |*stxr| {
                stxr.src = replaceReg(stxr.src, result);
                stxr.base = replaceReg(stxr.base, result);
                stxr.status = replaceWritableReg(stxr.status, result);
            },
            .stxr => |*stxr| {
                stxr.src = replaceReg(stxr.src, result);
                stxr.base = replaceReg(stxr.base, result);
                stxr.status = replaceWritableReg(stxr.status, result);
            },
            .ldaxrb => |*ldaxrb| {
                ldaxrb.base = replaceReg(ldaxrb.base, result);
                ldaxrb.dst = replaceWritableReg(ldaxrb.dst, result);
            },
            .ldaxrh => |*ldaxrh| {
                ldaxrh.base = replaceReg(ldaxrh.base, result);
                ldaxrh.dst = replaceWritableReg(ldaxrh.dst, result);
            },
            .ldaxr_w => |*ldaxr| {
                ldaxr.base = replaceReg(ldaxr.base, result);
                ldaxr.dst = replaceWritableReg(ldaxr.dst, result);
            },
            .ldaxr => |*ldaxr| {
                ldaxr.base = replaceReg(ldaxr.base, result);
                ldaxr.dst = replaceWritableReg(ldaxr.dst, result);
            },
            .stlxrb => |*stlxrb| {
                stlxrb.src = replaceReg(stlxrb.src, result);
                stlxrb.base = replaceReg(stlxrb.base, result);
                stlxrb.status = replaceWritableReg(stlxrb.status, result);
            },
            .stlxrh => |*stlxrh| {
                stlxrh.src = replaceReg(stlxrh.src, result);
                stlxrh.base = replaceReg(stlxrh.base, result);
                stlxrh.status = replaceWritableReg(stlxrh.status, result);
            },
            .stlxr_w => |*stlxr| {
                stlxr.src = replaceReg(stlxr.src, result);
                stlxr.base = replaceReg(stlxr.base, result);
                stlxr.status = replaceWritableReg(stlxr.status, result);
            },
            .stlxr => |*stlxr| {
                stlxr.src = replaceReg(stlxr.src, result);
                stlxr.base = replaceReg(stlxr.base, result);
                stlxr.status = replaceWritableReg(stlxr.status, result);
            },
            .ldadd => |*ldadd| {
                ldadd.src = replaceReg(ldadd.src, result);
                ldadd.base = replaceReg(ldadd.base, result);
                ldadd.dst = replaceWritableReg(ldadd.dst, result);
            },
            .ldclr => |*ldclr| {
                ldclr.src = replaceReg(ldclr.src, result);
                ldclr.base = replaceReg(ldclr.base, result);
                ldclr.dst = replaceWritableReg(ldclr.dst, result);
            },
            .ldeor => |*ldeor| {
                ldeor.src = replaceReg(ldeor.src, result);
                ldeor.base = replaceReg(ldeor.base, result);
                ldeor.dst = replaceWritableReg(ldeor.dst, result);
            },
            .ldset => |*ldset| {
                ldset.src = replaceReg(ldset.src, result);
                ldset.base = replaceReg(ldset.base, result);
                ldset.dst = replaceWritableReg(ldset.dst, result);
            },
            .ldsmax => |*ldsmax| {
                ldsmax.src = replaceReg(ldsmax.src, result);
                ldsmax.base = replaceReg(ldsmax.base, result);
                ldsmax.dst = replaceWritableReg(ldsmax.dst, result);
            },
            .ldsmin => |*ldsmin| {
                ldsmin.src = replaceReg(ldsmin.src, result);
                ldsmin.base = replaceReg(ldsmin.base, result);
                ldsmin.dst = replaceWritableReg(ldsmin.dst, result);
            },
            .ldumax => |*ldumax| {
                ldumax.src = replaceReg(ldumax.src, result);
                ldumax.base = replaceReg(ldumax.base, result);
                ldumax.dst = replaceWritableReg(ldumax.dst, result);
            },
            .ldumin => |*ldumin| {
                ldumin.src = replaceReg(ldumin.src, result);
                ldumin.base = replaceReg(ldumin.base, result);
                ldumin.dst = replaceWritableReg(ldumin.dst, result);
            },
            .swp => |*swp| {
                swp.src = replaceReg(swp.src, result);
                swp.base = replaceReg(swp.base, result);
                swp.dst = replaceWritableReg(swp.dst, result);
            },
            .cas => |*cas| {
                cas.compare = replaceReg(cas.compare, result);
                cas.swap = replaceReg(cas.swap, result);
                cas.base = replaceReg(cas.base, result);
                cas.dst = replaceWritableReg(cas.dst, result);
            },
            .madd => |*madd| {
                madd.src1 = replaceReg(madd.src1, result);
                madd.src2 = replaceReg(madd.src2, result);
                madd.addend = replaceReg(madd.addend, result);
                madd.dst = replaceWritableReg(madd.dst, result);
            },
            .msub => |*msub| {
                msub.src1 = replaceReg(msub.src1, result);
                msub.src2 = replaceReg(msub.src2, result);
                msub.minuend = replaceReg(msub.minuend, result);
                msub.dst = replaceWritableReg(msub.dst, result);
            },
            .smull => |*smull| {
                smull.src1 = replaceReg(smull.src1, result);
                smull.src2 = replaceReg(smull.src2, result);
                smull.dst = replaceWritableReg(smull.dst, result);
            },
            .umull => |*umull| {
                umull.src1 = replaceReg(umull.src1, result);
                umull.src2 = replaceReg(umull.src2, result);
                umull.dst = replaceWritableReg(umull.dst, result);
            },
            .sdiv => |*sdiv| {
                sdiv.src1 = replaceReg(sdiv.src1, result);
                sdiv.src2 = replaceReg(sdiv.src2, result);
                sdiv.dst = replaceWritableReg(sdiv.dst, result);
            },
            .udiv => |*udiv| {
                udiv.src1 = replaceReg(udiv.src1, result);
                udiv.src2 = replaceReg(udiv.src2, result);
                udiv.dst = replaceWritableReg(udiv.dst, result);
            },
            .clz => |*clz| {
                clz.src = replaceReg(clz.src, result);
                clz.dst = replaceWritableReg(clz.dst, result);
            },
            .rbit => |*rbit| {
                rbit.src = replaceReg(rbit.src, result);
                rbit.dst = replaceWritableReg(rbit.dst, result);
            },
            .rev16 => |*rev| {
                rev.src = replaceReg(rev.src, result);
                rev.dst = replaceWritableReg(rev.dst, result);
            },
            .rev32 => |*rev| {
                rev.src = replaceReg(rev.src, result);
                rev.dst = replaceWritableReg(rev.dst, result);
            },
            .rev64 => |*rev| {
                rev.src = replaceReg(rev.src, result);
                rev.dst = replaceWritableReg(rev.dst, result);
            },
            .csel => |*csel| {
                csel.src1 = replaceReg(csel.src1, result);
                csel.src2 = replaceReg(csel.src2, result);
                csel.dst = replaceWritableReg(csel.dst, result);
            },
            .movz => |*movz| {
                movz.dst = replaceWritableReg(movz.dst, result);
            },
            .movk => |*movk| {
                movk.dst = replaceWritableReg(movk.dst, result);
            },
            .movn => |*movn| {
                movn.dst = replaceWritableReg(movn.dst, result);
            },
            .cbz => |*cbz| {
                cbz.reg = replaceReg(cbz.reg, result);
            },
            .cbnz => |*cbnz| {
                cbnz.reg = replaceReg(cbnz.reg, result);
            },
            .tbz => |*tbz| {
                tbz.reg = replaceReg(tbz.reg, result);
            },
            .tbnz => |*tbnz| {
                tbnz.reg = replaceReg(tbnz.reg, result);
            },
            .br => |*br| {
                br.target = replaceReg(br.target, result);
            },
            .blr => |*blr| {
                blr.target = replaceReg(blr.target, result);
            },
            .sxtb => |*sxtb| {
                sxtb.src = replaceReg(sxtb.src, result);
                sxtb.dst = replaceWritableReg(sxtb.dst, result);
            },
            .sxth => |*sxth| {
                sxth.src = replaceReg(sxth.src, result);
                sxth.dst = replaceWritableReg(sxth.dst, result);
            },
            .sxtw => |*sxtw| {
                sxtw.src = replaceReg(sxtw.src, result);
                sxtw.dst = replaceWritableReg(sxtw.dst, result);
            },
            .uxtb => |*uxtb| {
                uxtb.src = replaceReg(uxtb.src, result);
                uxtb.dst = replaceWritableReg(uxtb.dst, result);
            },
            .uxth => |*uxth| {
                uxth.src = replaceReg(uxth.src, result);
                uxth.dst = replaceWritableReg(uxth.dst, result);
            },
            .fneg => |*fneg| {
                fneg.src = replaceReg(fneg.src, result);
                fneg.dst = replaceWritableReg(fneg.dst, result);
            },
            .fabs => |*fabs| {
                fabs.src = replaceReg(fabs.src, result);
                fabs.dst = replaceWritableReg(fabs.dst, result);
            },
            .fsqrt => |*fsqrt| {
                fsqrt.src = replaceReg(fsqrt.src, result);
                fsqrt.dst = replaceWritableReg(fsqrt.dst, result);
            },
            .scvtf => |*scvtf| {
                scvtf.src = replaceReg(scvtf.src, result);
                scvtf.dst = replaceWritableReg(scvtf.dst, result);
            },
            .ucvtf => |*ucvtf| {
                ucvtf.src = replaceReg(ucvtf.src, result);
                ucvtf.dst = replaceWritableReg(ucvtf.dst, result);
            },
            .fcvtzs => |*fcvtzs| {
                fcvtzs.src = replaceReg(fcvtzs.src, result);
                fcvtzs.dst = replaceWritableReg(fcvtzs.dst, result);
            },
            .fcvtzu => |*fcvtzu| {
                fcvtzu.src = replaceReg(fcvtzu.src, result);
                fcvtzu.dst = replaceWritableReg(fcvtzu.dst, result);
            },
            .fcvt_f32_to_f64 => |*fcvt| {
                fcvt.src = replaceReg(fcvt.src, result);
                fcvt.dst = replaceWritableReg(fcvt.dst, result);
            },
            .fcvt_f64_to_f32 => |*fcvt| {
                fcvt.src = replaceReg(fcvt.src, result);
                fcvt.dst = replaceWritableReg(fcvt.dst, result);
            },
            .adds_rr => |*adds| {
                adds.src1 = replaceReg(adds.src1, result);
                adds.src2 = replaceReg(adds.src2, result);
                adds.dst = replaceWritableReg(adds.dst, result);
            },
            .adds_imm => |*adds| {
                adds.src = replaceReg(adds.src, result);
                adds.dst = replaceWritableReg(adds.dst, result);
            },
            .adcs => |*adcs| {
                adcs.src1 = replaceReg(adcs.src1, result);
                adcs.src2 = replaceReg(adcs.src2, result);
                adcs.dst = replaceWritableReg(adcs.dst, result);
            },
            .subs_rr => |*subs| {
                subs.src1 = replaceReg(subs.src1, result);
                subs.src2 = replaceReg(subs.src2, result);
                subs.dst = replaceWritableReg(subs.dst, result);
            },
            .subs_imm => |*subs| {
                subs.src = replaceReg(subs.src, result);
                subs.dst = replaceWritableReg(subs.dst, result);
            },
            .sbcs => |*sbcs| {
                sbcs.src1 = replaceReg(sbcs.src1, result);
                sbcs.src2 = replaceReg(sbcs.src2, result);
                sbcs.dst = replaceWritableReg(sbcs.dst, result);
            },
            .sqadd => |*sqadd| {
                sqadd.src1 = replaceReg(sqadd.src1, result);
                sqadd.src2 = replaceReg(sqadd.src2, result);
                sqadd.dst = replaceWritableReg(sqadd.dst, result);
            },
            .sqsub => |*sqsub| {
                sqsub.src1 = replaceReg(sqsub.src1, result);
                sqsub.src2 = replaceReg(sqsub.src2, result);
                sqsub.dst = replaceWritableReg(sqsub.dst, result);
            },
            .uqadd => |*uqadd| {
                uqadd.src1 = replaceReg(uqadd.src1, result);
                uqadd.src2 = replaceReg(uqadd.src2, result);
                uqadd.dst = replaceWritableReg(uqadd.dst, result);
            },
            .uqsub => |*uqsub| {
                uqsub.src1 = replaceReg(uqsub.src1, result);
                uqsub.src2 = replaceReg(uqsub.src2, result);
                uqsub.dst = replaceWritableReg(uqsub.dst, result);
            },
            .smulh => |*smulh| {
                smulh.src1 = replaceReg(smulh.src1, result);
                smulh.src2 = replaceReg(smulh.src2, result);
                smulh.dst = replaceWritableReg(smulh.dst, result);
            },
            .umulh => |*umulh| {
                umulh.src1 = replaceReg(umulh.src1, result);
                umulh.src2 = replaceReg(umulh.src2, result);
                umulh.dst = replaceWritableReg(umulh.dst, result);
            },
            .orn_rr => |*orn| {
                orn.src1 = replaceReg(orn.src1, result);
                orn.src2 = replaceReg(orn.src2, result);
                orn.dst = replaceWritableReg(orn.dst, result);
            },
            .tst_imm => |*tst| {
                tst.src = replaceReg(tst.src, result);
            },
            .tst_rr => |*tst| {
                tst.src1 = replaceReg(tst.src1, result);
                tst.src2 = replaceReg(tst.src2, result);
            },
            .eon_rr => |*eon| {
                eon.src1 = replaceReg(eon.src1, result);
                eon.src2 = replaceReg(eon.src2, result);
                eon.dst = replaceWritableReg(eon.dst, result);
            },
            .cinc => |*cinc| {
                cinc.src = replaceReg(cinc.src, result);
                cinc.dst = replaceWritableReg(cinc.dst, result);
            },
            .cset => |*cset| {
                cset.dst = replaceWritableReg(cset.dst, result);
            },
            .fmax => |*fmax| {
                fmax.src1 = replaceReg(fmax.src1, result);
                fmax.src2 = replaceReg(fmax.src2, result);
                fmax.dst = replaceWritableReg(fmax.dst, result);
            },
            .fmin => |*fmin| {
                fmin.src1 = replaceReg(fmin.src1, result);
                fmin.src2 = replaceReg(fmin.src2, result);
                fmin.dst = replaceWritableReg(fmin.dst, result);
            },
            .fcsel => |*fcsel| {
                fcsel.src1 = replaceReg(fcsel.src1, result);
                fcsel.src2 = replaceReg(fcsel.src2, result);
                fcsel.dst = replaceWritableReg(fcsel.dst, result);
            },
            .fmov_imm => |*fmov| {
                fmov.dst = replaceWritableReg(fmov.dst, result);
            },
            .fmov_from_gpr => |*fmov| {
                fmov.src = replaceReg(fmov.src, result);
                fmov.dst = replaceWritableReg(fmov.dst, result);
            },
            .fmov_to_gpr => |*fmov| {
                fmov.src = replaceReg(fmov.src, result);
                fmov.dst = replaceWritableReg(fmov.dst, result);
            },
            .frintm => |*frint| {
                frint.src = replaceReg(frint.src, result);
                frint.dst = replaceWritableReg(frint.dst, result);
            },
            .frintn => |*frint| {
                frint.src = replaceReg(frint.src, result);
                frint.dst = replaceWritableReg(frint.dst, result);
            },
            .frintp => |*frint| {
                frint.src = replaceReg(frint.src, result);
                frint.dst = replaceWritableReg(frint.dst, result);
            },
            .frintz => |*frint| {
                frint.src = replaceReg(frint.src, result);
                frint.dst = replaceWritableReg(frint.dst, result);
            },
            .adr => |*adr| {
                adr.dst = replaceWritableReg(adr.dst, result);
            },
            .adrp => |*adrp| {
                adrp.dst = replaceWritableReg(adrp.dst, result);
            },
            .call_indirect => |*call| {
                call.target = replaceReg(call.target, result);
            },
            .fmadd => |*fmadd| {
                fmadd.src1 = replaceReg(fmadd.src1, result);
                fmadd.src2 = replaceReg(fmadd.src2, result);
                fmadd.addend = replaceReg(fmadd.addend, result);
                fmadd.dst = replaceWritableReg(fmadd.dst, result);
            },
            .fmsub => |*fmsub| {
                fmsub.src1 = replaceReg(fmsub.src1, result);
                fmsub.src2 = replaceReg(fmsub.src2, result);
                fmsub.addend = replaceReg(fmsub.addend, result);
                fmsub.dst = replaceWritableReg(fmsub.dst, result);
            },
            .fcmp_zero => |*fcmp| {
                fcmp.src = replaceReg(fcmp.src, result);
            },
            .adrp_symbol => |*adrp| {
                adrp.dst = replaceWritableReg(adrp.dst, result);
            },
            .cmn_rr => |*cmn| {
                cmn.src1 = replaceReg(cmn.src1, result);
                cmn.src2 = replaceReg(cmn.src2, result);
            },
            .cls => |*cls| {
                cls.src = replaceReg(cls.src, result);
                cls.dst = replaceWritableReg(cls.dst, result);
            },
            .ctz => |*ctz| {
                ctz.src = replaceReg(ctz.src, result);
                ctz.dst = replaceWritableReg(ctz.dst, result);
            },
            .neg => |*neg| {
                neg.src = replaceReg(neg.src, result);
                neg.dst = replaceWritableReg(neg.dst, result);
            },
            .uxtw => |*uxtw| {
                uxtw.src = replaceReg(uxtw.src, result);
                uxtw.dst = replaceWritableReg(uxtw.dst, result);
            },
            .popcnt => |*popcnt| {
                popcnt.src = replaceReg(popcnt.src, result);
                popcnt.dst = replaceWritableReg(popcnt.dst, result);
            },
            .lea => |*lea| {
                lea.dst = replaceWritableReg(lea.dst, result);
                // TODO: Handle registers in Amode
            },
            .mrs => |*mrs| {
                mrs.dst = replaceWritableReg(mrs.dst, result);
            },
            .msr => |*msr| {
                msr.src = replaceReg(msr.src, result);
            },
            .vec_ext => |*vec_ext| {
                vec_ext.src1 = replaceReg(vec_ext.src1, result);
                vec_ext.src2 = replaceReg(vec_ext.src2, result);
                vec_ext.dst = replaceWritableReg(vec_ext.dst, result);
            },
            .vec_addp => |*vec_addp| {
                vec_addp.src1 = replaceReg(vec_addp.src1, result);
                vec_addp.src2 = replaceReg(vec_addp.src2, result);
                vec_addp.dst = replaceWritableReg(vec_addp.dst, result);
            },
            .vec_umaxp => |*vec_umaxp| {
                vec_umaxp.src1 = replaceReg(vec_umaxp.src1, result);
                vec_umaxp.src2 = replaceReg(vec_umaxp.src2, result);
                vec_umaxp.dst = replaceWritableReg(vec_umaxp.dst, result);
            },
            .vec_cmeq0 => |*vec_cmeq0| {
                vec_cmeq0.src = replaceReg(vec_cmeq0.src, result);
                vec_cmeq0.dst = replaceWritableReg(vec_cmeq0.dst, result);
            },
            .vec_sshll => |*vec_sshll| {
                vec_sshll.src = replaceReg(vec_sshll.src, result);
                vec_sshll.dst = replaceWritableReg(vec_sshll.dst, result);
            },
            .vec_ushll => |*vec_ushll| {
                vec_ushll.src = replaceReg(vec_ushll.src, result);
                vec_ushll.dst = replaceWritableReg(vec_ushll.dst, result);
            },
            .vec_sqxtn => |*vec_sqxtn| {
                vec_sqxtn.src = replaceReg(vec_sqxtn.src, result);
                vec_sqxtn.dst = replaceWritableReg(vec_sqxtn.dst, result);
            },
            .vec_sqxtun => |*vec_sqxtun| {
                vec_sqxtun.src = replaceReg(vec_sqxtun.src, result);
                vec_sqxtun.dst = replaceWritableReg(vec_sqxtun.dst, result);
            },
            .vec_uqxtn => |*vec_uqxtn| {
                vec_uqxtn.src = replaceReg(vec_uqxtn.src, result);
                vec_uqxtn.dst = replaceWritableReg(vec_uqxtn.dst, result);
            },
            .vec_fcvtl => |*vec_fcvtl| {
                vec_fcvtl.src = replaceReg(vec_fcvtl.src, result);
                vec_fcvtl.dst = replaceWritableReg(vec_fcvtl.dst, result);
            },
            .vec_fcvtn => |*vec_fcvtn| {
                vec_fcvtn.src = replaceReg(vec_fcvtn.src, result);
                vec_fcvtn.dst = replaceWritableReg(vec_fcvtn.dst, result);
            },
            .zip1 => |*zip1| {
                zip1.src1 = replaceReg(zip1.src1, result);
                zip1.src2 = replaceReg(zip1.src2, result);
                zip1.dst = replaceWritableReg(zip1.dst, result);
            },
            .zip2 => |*zip2| {
                zip2.src1 = replaceReg(zip2.src1, result);
                zip2.src2 = replaceReg(zip2.src2, result);
                zip2.dst = replaceWritableReg(zip2.dst, result);
            },
            .uzp1 => |*uzp1| {
                uzp1.src1 = replaceReg(uzp1.src1, result);
                uzp1.src2 = replaceReg(uzp1.src2, result);
                uzp1.dst = replaceWritableReg(uzp1.dst, result);
            },
            .uzp2 => |*uzp2| {
                uzp2.src1 = replaceReg(uzp2.src1, result);
                uzp2.src2 = replaceReg(uzp2.src2, result);
                uzp2.dst = replaceWritableReg(uzp2.dst, result);
            },
            .trn1 => |*trn1| {
                trn1.src1 = replaceReg(trn1.src1, result);
                trn1.src2 = replaceReg(trn1.src2, result);
                trn1.dst = replaceWritableReg(trn1.dst, result);
            },
            .trn2 => |*trn2| {
                trn2.src1 = replaceReg(trn2.src1, result);
                trn2.src2 = replaceReg(trn2.src2, result);
                trn2.dst = replaceWritableReg(trn2.dst, result);
            },
            .vec_rev16 => |*vec_rev16| {
                vec_rev16.src = replaceReg(vec_rev16.src, result);
                vec_rev16.dst = replaceWritableReg(vec_rev16.dst, result);
            },
            .vec_rev32 => |*vec_rev32| {
                vec_rev32.src = replaceReg(vec_rev32.src, result);
                vec_rev32.dst = replaceWritableReg(vec_rev32.dst, result);
            },
            .vec_rev64 => |*vec_rev64| {
                vec_rev64.src = replaceReg(vec_rev64.src, result);
                vec_rev64.dst = replaceWritableReg(vec_rev64.dst, result);
            },
            .vec_rrr_mod => |*vec_rrr_mod| {
                vec_rrr_mod.ri = replaceReg(vec_rrr_mod.ri, result);
                vec_rrr_mod.rn = replaceReg(vec_rrr_mod.rn, result);
                vec_rrr_mod.rm = replaceReg(vec_rrr_mod.rm, result);
                vec_rrr_mod.dst = replaceWritableReg(vec_rrr_mod.dst, result);
            },
            .vec_rrr => |*vec_rrr| {
                vec_rrr.rn = replaceReg(vec_rrr.rn, result);
                vec_rrr.rm = replaceReg(vec_rrr.rm, result);
                vec_rrr.dst = replaceWritableReg(vec_rrr.dst, result);
            },
            .vec_misc => |*vec_misc| {
                vec_misc.rn = replaceReg(vec_misc.rn, result);
                vec_misc.dst = replaceWritableReg(vec_misc.dst, result);
            },
            .vec_shift_imm => |*vec_shift_imm| {
                vec_shift_imm.rn = replaceReg(vec_shift_imm.rn, result);
                vec_shift_imm.dst = replaceWritableReg(vec_shift_imm.dst, result);
            },
            .vec_fmla_elem => |*vec_fmla_elem| {
                vec_fmla_elem.ri = replaceReg(vec_fmla_elem.ri, result);
                vec_fmla_elem.rn = replaceReg(vec_fmla_elem.rn, result);
                vec_fmla_elem.rm = replaceReg(vec_fmla_elem.rm, result);
                vec_fmla_elem.dst = replaceWritableReg(vec_fmla_elem.dst, result);
            },
            .zext32 => |*zext32| {
                zext32.src = replaceReg(zext32.src, result);
                zext32.dst = replaceWritableReg(zext32.dst, result);
            },
            .add_symbol_lo12 => |*add_symbol_lo12| {
                add_symbol_lo12.src = replaceReg(add_symbol_lo12.src, result);
                add_symbol_lo12.dst = replaceWritableReg(add_symbol_lo12.dst, result);
            },
            // TODO: Add more instruction types as needed
            else => {
                // For unimplemented instructions, do nothing
                // This is safe because getOperands() returns empty lists for them
            },
        }
    }

    /// Compile function using linear scan register allocation.
    fn compileWithLinearScan(
        ctx: compile_mod.CompileCtx,
        func: *const lower_mod.Function,
    ) !compile_mod.CompiledCode {
        const linear_scan_mod = @import("../../regalloc/linear_scan.zig");
        const buffer_mod = @import("../../machinst/buffer.zig");

        // Phase 1: Lower IR to VCode
        var vcode = try lower_mod.lowerFunction(
            Inst,
            ctx.allocator,
            func,
            lower(),
        );
        defer vcode.deinit();

        // Phase 2: Liveness analysis
        const liveness_mod = @import("../../regalloc/liveness.zig");
        var liveness_info = try liveness_mod.LivenessInfo.compute(Inst, ctx.allocator, &vcode);
        defer liveness_info.deinit();

        // Phase 3: Register allocation using linear scan
        const num_int_regs: u32 = 28; // X0-X27 (excluding X28=SP, X29=FP, X30=LR, X31=ZR)
        const num_float_regs: u32 = 32; // V0-V31
        const num_vector_regs: u32 = 32; // Same as float on AArch64

        var linear_scan = linear_scan_mod.LinearScanAllocator.init(
            ctx.allocator,
            num_int_regs,
            num_float_regs,
            num_vector_regs,
        );
        defer linear_scan.deinit();

        var result = try linear_scan.allocate(&liveness_info);
        defer result.deinit();

        // Phase 4: Insert spill/reload instructions
        try insertSpillReloads(&vcode, &result, &liveness_info, ctx.allocator);

        // Phase 5: Apply allocations to VCode
        for (vcode.insns.items) |*inst| {
            try applyAllocations(inst, &result);
        }

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

        // Stack frame size = spill slot size from allocator
        const stack_frame_size: u32 = linear_scan.next_spill_offset;

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
