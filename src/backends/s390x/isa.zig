const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = @import("inst.zig").Inst;
const abi_mod = @import("../../machinst/abi.zig");
const lower_mod = @import("../../machinst/lower.zig");
const compile_mod = @import("../../machinst/compile.zig");

/// s390x ISA descriptor.
/// This integrates all s390x backend components into a unified interface.
pub const S390xISA = struct {
    /// ISA name.
    pub const name = "s390x";

    /// Machine instruction type.
    pub const MachInst = Inst;

    /// ABI specification for this ISA.
    pub fn abi(call_conv: abi_mod.CallConv) abi_mod.ABIMachineSpec(u64) {
        return switch (call_conv) {
            .system_v => @import("abi.zig").sysv(),
            .aapcs64, .windows_fastcall => unreachable,
        };
    }

    /// Lowering backend for instruction selection.
    pub fn lower() lower_mod.LowerBackend(Inst) {
        return @import("lower.zig").S390xLower.backend();
    }

    /// Register information.
    pub const registers = struct {
        /// Number of general-purpose registers (r0-r15).
        pub const num_gpr: u8 = 16;
        /// Number of floating-point registers (f0-f15).
        pub const num_vec: u8 = 16;
        /// Stack pointer register.
        pub const sp_reg = 15; // r15
        /// Frame pointer register.
        pub const fp_reg = 11; // r11
        /// Link register.
        pub const lr_reg: ?u8 = 14; // r14
    };

    /// Compile a function to machine code using this ISA.
    pub fn compileFunction(
        ctx: compile_mod.CompileCtx,
        func: *lower_mod.Function,
    ) !compile_mod.CompiledCode {
        return compileWithLinearScan(ctx, func);
    }

    fn compileWithLinearScan(
        ctx: compile_mod.CompileCtx,
        func: *lower_mod.Function,
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
        const num_int_regs: u32 = 16; // r0-r15
        const num_float_regs: u32 = 16; // f0-f15
        const num_vector_regs: u32 = 16;

        var linear_scan = try linear_scan_mod.LinearScanAllocator.init(
            ctx.allocator,
            num_int_regs,
            num_float_regs,
            num_vector_regs,
        );
        defer linear_scan.deinit();

        // Reserve dedicated scratch regs for spill insertion.
        const int_scratch_hw: u6 = 1; // r1
        const float_scratch_hw: u6 = 15; // f15
        const int_idx = linear_scan.int_reg_index[int_scratch_hw];
        if (int_idx != 0xFF) {
            linear_scan.free_int_regs.unset(int_idx);
        }
        const float_idx = linear_scan.float_reg_index[float_scratch_hw];
        if (float_idx != 0xFF) {
            linear_scan.free_float_regs.unset(float_idx);
        }
        const vec_idx = linear_scan.vector_reg_index[float_scratch_hw];
        if (vec_idx != 0xFF) {
            linear_scan.free_vector_regs.unset(vec_idx);
        }

        var result = try linear_scan.allocate(&liveness_info);
        defer result.deinit();

        // Phase 4: Insert spill/reload instructions
        try insertSpillReloads(&vcode, &result, &liveness_info, ctx.allocator);

        // Phase 5: Apply allocations to VCode
        for (vcode.insns.items) |*inst| {
            try applyAllocations(inst, &result);
        }

        // Phase 6: Emit machine code
        const emit_mod = @import("emit.zig");
        var buffer = buffer_mod.MachBuffer.init(ctx.allocator);
        defer buffer.deinit();

        // Emit each instruction
        for (vcode.insns.items) |inst| {
            try emit_mod.emit(inst, &buffer);
        }

        // Phase 7: Finalize and extract code
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
                .code = convertTrapCode(mtrap.code),
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

    fn convertRelocKind(kind: @import("../../machinst/buffer.zig").Reloc) compile_mod.RelocationKind {
        return switch (kind) {
            .abs8, .abs4, .aarch64_abs64 => .abs64,
            .x86_pc_rel_32, .aarch64_call26, .aarch64_jump26 => .pc_rel32,
            .aarch64_adr_prel_pg_hi21,
            .aarch64_add_abs_lo12_nc,
            .aarch64_ldst64_abs_lo12_nc,
            .aarch64_adr_got_page,
            .aarch64_ld64_got_lo12_nc,
            .aarch64_tlsle_add_tprel_hi12,
            .aarch64_tlsle_add_tprel_lo12_nc,
            .aarch64_tlsie_adr_gottprel_page21,
            .aarch64_tlsie_ld64_gottprel_lo12_nc,
            .aarch64_tlsdesc_adr_page21,
            .aarch64_tlsdesc_ld64_lo12,
            .aarch64_tlsdesc_add_lo12,
            .aarch64_tlsdesc_call,
            => .got_pc_rel32,
        };
    }

    fn convertTrapCode(code: @import("../../machinst/buffer.zig").TrapCode) compile_mod.TrapCode {
        return switch (code) {
            .stack_overflow => .stack_overflow,
            .heap_out_of_bounds => .heap_out_of_bounds,
            .int_div_by_zero => .integer_divide_by_zero,
            .unreachable_code_reached => .unreachable_code_reached,
        };
    }

    fn insertSpillReloads(
        vcode: anytype,
        result: anytype,
        liveness_info: anytype,
        allocator: std.mem.Allocator,
    ) !void {
        const linear_scan_mod = @import("../../regalloc/linear_scan.zig");
        const reg_mod = @import("../../machinst/reg.zig");

        var spilled_vregs = std.ArrayList(struct {
            vreg: reg_mod.VReg,
            slot: linear_scan_mod.SpillSlot,
        }){};
        defer spilled_vregs.deinit(allocator);

        for (liveness_info.ranges.items) |range| {
            if (result.getSpillSlot(range.vreg)) |slot| {
                try spilled_vregs.append(allocator, .{
                    .vreg = range.vreg,
                    .slot = slot,
                });
            }
        }

        if (spilled_vregs.items.len == 0) return;

        var insertions = std.ArrayList(struct {
            position: u32,
            insert_after: bool,
            inst: Inst,
        }){};
        defer insertions.deinit(allocator);

        var scratch_use = std.AutoHashMap(u64, u32).init(allocator);
        defer scratch_use.deinit();

        const Helpers = struct {
            fn spillOffsetI20(offset: u32) !i20 {
                if (offset > @as(u32, @intCast(std.math.maxInt(i20)))) {
                    return error.SpillOffsetOutOfRange;
                }
                return @intCast(offset);
            }

            fn spillOffsetI12(offset: u32) !i12 {
                if (offset > @as(u32, @intCast(std.math.maxInt(i12)))) {
                    return error.SpillOffsetOutOfRange;
                }
                return @intCast(offset);
            }

            fn scratchRegForClass(reg_class: reg_mod.RegClass) !reg_mod.Reg {
                return switch (reg_class) {
                    .int => reg_mod.Reg.fromPReg(reg_mod.PReg.new(.int, 1)), // r1
                    .float, .vector => reg_mod.Reg.fromPReg(reg_mod.PReg.new(.float, 15)), // f15
                    else => error.UnsupportedSpillRegClass,
                };
            }

            fn makeReload(class: reg_mod.RegClass, scratch: reg_mod.Reg, offset: u32) !Inst {
                return switch (class) {
                    .int => .{
                        .lg = .{
                            .dst = reg_mod.WritableReg.fromReg(scratch),
                            .base = reg_mod.Reg.fromPReg(reg_mod.PReg.new(.int, 15)),
                            .offset = try spillOffsetI20(offset),
                        },
                    },
                    .float, .vector => .{
                        .ld = .{
                            .dst = reg_mod.WritableReg.fromReg(scratch),
                            .base = reg_mod.Reg.fromPReg(reg_mod.PReg.new(.int, 15)),
                            .offset = try spillOffsetI12(offset),
                        },
                    },
                    else => error.UnsupportedSpillRegClass,
                };
            }

            fn makeSpill(class: reg_mod.RegClass, scratch: reg_mod.Reg, offset: u32) !Inst {
                return switch (class) {
                    .int => .{
                        .stg = .{
                            .src = scratch,
                            .base = reg_mod.Reg.fromPReg(reg_mod.PReg.new(.int, 15)),
                            .offset = try spillOffsetI20(offset),
                        },
                    },
                    .float, .vector => .{
                        .std = .{
                            .src = scratch,
                            .base = reg_mod.Reg.fromPReg(reg_mod.PReg.new(.int, 15)),
                            .offset = try spillOffsetI12(offset),
                        },
                    },
                    else => error.UnsupportedSpillRegClass,
                };
            }

            fn rewriteSpilledVReg(
                inst: *Inst,
                target_vreg: reg_mod.VReg,
                replacement: reg_mod.Reg,
            ) !void {
                const Rewriter = struct {
                    fn rewriteValue(value: anytype, vreg: reg_mod.VReg, repl: reg_mod.Reg) !void {
                        const T = @TypeOf(value.*);
                        switch (@typeInfo(T)) {
                            .@"struct" => |s| {
                                inline for (s.fields) |field| {
                                    const field_ptr = &@field(value, field.name);
                                    const FieldT = @TypeOf(field_ptr.*);
                                    if (FieldT == reg_mod.Reg) {
                                        if (field_ptr.*.toVReg()) |field_vreg| {
                                            if (field_vreg.index() == vreg.index()) {
                                                field_ptr.* = repl;
                                            }
                                        }
                                    } else if (FieldT == reg_mod.WritableReg) {
                                        if (field_ptr.*.toReg().toVReg()) |field_vreg| {
                                            if (field_vreg.index() == vreg.index()) {
                                                field_ptr.* = reg_mod.WritableReg.fromReg(repl);
                                            }
                                        }
                                    } else {
                                        switch (@typeInfo(FieldT)) {
                                            .@"struct", .@"union", .optional => try rewriteValue(field_ptr, vreg, repl),
                                            else => {},
                                        }
                                    }
                                }
                            },
                            .@"union" => {
                                switch (value.*) {
                                    inline else => |*payload| try rewriteValue(payload, vreg, repl),
                                }
                            },
                            .optional => {
                                if (value.*) |*some| {
                                    try rewriteValue(some, vreg, repl);
                                }
                            },
                            else => {},
                        }
                    }
                };

                try Rewriter.rewriteValue(inst, target_vreg, replacement);
            }
        };

        for (spilled_vregs.items) |spill_info| {
            const scratch = try Helpers.scratchRegForClass(spill_info.vreg.class());

            for (vcode.insns.items, 0..) |inst, idx| {
                var inst_copy = inst;
                const defs = try inst_copy.getDefs(allocator);
                defer allocator.free(defs);
                const uses = try inst_copy.getUses(allocator);
                defer allocator.free(uses);

                var has_def = false;
                for (defs) |def_vreg| {
                    if (def_vreg.index() == spill_info.vreg.index()) {
                        has_def = true;
                        break;
                    }
                }

                var has_use = false;
                for (uses) |use_vreg| {
                    if (use_vreg.index() == spill_info.vreg.index()) {
                        has_use = true;
                        break;
                    }
                }

                if (!has_def and !has_use) continue;

                const key: u64 = (@as(u64, @intCast(idx)) << 32) | @as(u64, scratch.bits);
                if (scratch_use.get(key)) |seen_vreg_idx| {
                    if (seen_vreg_idx != spill_info.vreg.index()) {
                        return error.MultipleSpillsPerInstruction;
                    }
                } else {
                    try scratch_use.put(key, spill_info.vreg.index());
                }

                try Helpers.rewriteSpilledVReg(&vcode.insns.items[idx], spill_info.vreg, scratch);

                if (has_use) {
                    try insertions.append(allocator, .{
                        .position = @intCast(idx),
                        .insert_after = false,
                        .inst = try Helpers.makeReload(spill_info.vreg.class(), scratch, spill_info.slot.offset),
                    });
                }
                if (has_def) {
                    try insertions.append(allocator, .{
                        .position = @intCast(idx),
                        .insert_after = true,
                        .inst = try Helpers.makeSpill(spill_info.vreg.class(), scratch, spill_info.slot.offset),
                    });
                }
            }
        }

        std.mem.sort(@TypeOf(insertions.items[0]), insertions.items, {}, struct {
            fn lessThan(_: void, a: @TypeOf(insertions.items[0]), b: @TypeOf(insertions.items[0])) bool {
                if (a.position != b.position) return a.position > b.position;
                return a.insert_after and !b.insert_after;
            }
        }.lessThan);

        for (insertions.items) |insertion| {
            const insert_idx = if (insertion.insert_after) insertion.position + 1 else insertion.position;
            try vcode.insns.insert(allocator, insert_idx, insertion.inst);
        }
    }

    fn applyAllocations(inst: *Inst, result: anytype) !void {
        const reg_mod = @import("../../machinst/reg.zig");

        const Rewriter = struct {
            fn mapReg(reg: reg_mod.Reg, alloc_result: anytype) !reg_mod.Reg {
                if (reg.toVReg()) |vreg| {
                    if (alloc_result.getPhysReg(vreg)) |preg| {
                        return reg_mod.Reg.fromPReg(preg);
                    }
                    if (alloc_result.getSpillSlot(vreg) != null) {
                        return error.SpilledVirtualRegister;
                    }
                    return error.UnallocatedVirtualRegister;
                }
                return reg;
            }

            fn mapWritableReg(wreg: reg_mod.WritableReg, alloc_result: anytype) !reg_mod.WritableReg {
                const mapped = try mapReg(wreg.toReg(), alloc_result);
                return reg_mod.WritableReg.fromReg(mapped);
            }

            fn rewrite(value: anytype, alloc_result: anytype) !void {
                const T = @TypeOf(value.*);
                switch (@typeInfo(T)) {
                    .@"struct" => |s| {
                        inline for (s.fields) |field| {
                            const field_ptr = &@field(value, field.name);
                            const FieldT = @TypeOf(field_ptr.*);
                            if (FieldT == reg_mod.Reg) {
                                field_ptr.* = try mapReg(field_ptr.*, alloc_result);
                            } else if (FieldT == reg_mod.WritableReg) {
                                field_ptr.* = try mapWritableReg(field_ptr.*, alloc_result);
                            } else {
                                switch (@typeInfo(FieldT)) {
                                    .@"struct", .@"union", .optional => try rewrite(field_ptr, alloc_result),
                                    else => {},
                                }
                            }
                        }
                    },
                    .@"union" => {
                        switch (value.*) {
                            inline else => |*payload| try rewrite(payload, alloc_result),
                        }
                    },
                    .optional => {
                        if (value.*) |*some| {
                            try rewrite(some, alloc_result);
                        }
                    },
                    else => {},
                }
            }
        };

        try Rewriter.rewrite(inst, result);
    }
};

test "S390xISA basic properties" {
    try testing.expectEqualStrings("s390x", S390xISA.name);
    try testing.expectEqual(@as(u8, 16), S390xISA.registers.num_gpr);
    try testing.expectEqual(@as(u8, 16), S390xISA.registers.num_vec);
    try testing.expectEqual(@as(u8, 15), S390xISA.registers.sp_reg);
    try testing.expectEqual(@as(u8, 11), S390xISA.registers.fp_reg);
    try testing.expectEqual(@as(u8, 14), S390xISA.registers.lr_reg.?);
}

test "S390xISA ABI selection" {
    const sysv_abi = S390xISA.abi(.system_v);

    // s390x has 5 int arg regs (r2-r6)
    try testing.expectEqual(@as(usize, 5), sysv_abi.int_arg_regs.len);

    // s390x has 4 float arg regs (f0,f2,f4,f6)
    try testing.expectEqual(@as(usize, 4), sysv_abi.float_arg_regs.len);
}

test "S390xISA lowering backend" {
    const backend = S390xISA.lower();

    // Should have function pointers
    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);
}

test "S390xISA compile function" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    const ctx = compile_mod.CompileCtx.init(testing.allocator, "s390x");

    var code = try S390xISA.compileFunction(ctx, &func);
    defer code.deinit();

    // Empty function produces minimal code
    try testing.expect(code.code.len == 0);
}

test "S390xISA applyAllocations rewrites vregs" {
    const linear_scan_mod = @import("../../regalloc/linear_scan.zig");
    const reg_mod = @import("../../machinst/reg.zig");

    const src_v = reg_mod.VReg.new(310, .int);
    const dst_v = reg_mod.VReg.new(311, .int);

    var inst = Inst{
        .agr = .{
            .dst = reg_mod.WritableReg.fromVReg(dst_v),
            .src1 = reg_mod.Reg.fromVReg(src_v),
            .src2 = reg_mod.Reg.fromVReg(src_v),
        },
    };

    var result = linear_scan_mod.RegAllocResult.init(testing.allocator);
    defer result.deinit();
    try result.assign(src_v, reg_mod.PReg.new(.int, 5));
    try result.assign(dst_v, reg_mod.PReg.new(.int, 6));

    try S390xISA.applyAllocations(&inst, &result);

    switch (inst) {
        .agr => |agr| {
            try testing.expect(agr.src1.toRealReg() != null);
            try testing.expect(agr.src2.toRealReg() != null);
            try testing.expect(agr.dst.toReg().toRealReg() != null);
        },
        else => return error.TestUnexpectedInstructionTag,
    }
}

test "S390xISA insertSpillReloads rewrites spilled regs" {
    const reg_mod = @import("../../machinst/reg.zig");
    const liveness_mod = @import("../../regalloc/liveness.zig");
    const linear_scan_mod = @import("../../regalloc/linear_scan.zig");

    const spilled_v = reg_mod.VReg.new(340, .int);
    const dst_v = reg_mod.VReg.new(341, .int);

    var vcode = lower_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    const bb = try vcode.startBlock(&.{});
    _ = try vcode.addInst(.{
        .agr = .{
            .dst = reg_mod.WritableReg.fromVReg(dst_v),
            .src1 = reg_mod.Reg.fromVReg(spilled_v),
            .src2 = reg_mod.Reg.fromVReg(spilled_v),
        },
    });
    try vcode.finishBlock(bb, &.{});

    var liveness = try liveness_mod.LivenessInfo.compute(Inst, testing.allocator, &vcode);
    defer liveness.deinit();

    var result = linear_scan_mod.RegAllocResult.init(testing.allocator);
    defer result.deinit();
    try result.assign(dst_v, reg_mod.PReg.new(.int, 5));
    try result.assignSpillSlot(spilled_v, .{ .offset = 16 });

    try S390xISA.insertSpillReloads(&vcode, &result, &liveness, testing.allocator);

    try testing.expectEqual(@as(usize, 3), vcode.insns.items.len);

    switch (vcode.insns.items[0]) {
        .lg => {},
        else => return error.TestExpectedLoadReload,
    }
    switch (vcode.insns.items[2]) {
        .stg => {},
        else => return error.TestExpectedStoreSpill,
    }
}
