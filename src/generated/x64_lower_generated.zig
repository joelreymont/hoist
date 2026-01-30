// Generated ISLE lowering for x64
// TODO: Replace with actual ISLE-generated code when parser is complete

const std = @import("std");
const root = @import("root");
const inst_mod = @import("../backends/x64/inst.zig");
const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const WritableReg = inst_mod.WritableReg;
const PReg = inst_mod.PReg;
const OperandSize = inst_mod.OperandSize;
const lower_mod = @import("../machinst/lower.zig");
const x64_abi = root.x64_abi;

const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;
const Type = root.types.Type;

// Manual lowering function until ISLE compiler is fully functional
pub fn lower(
    ctx: *lower_mod.LowerCtx(Inst),
    ir_inst: lower_mod.Inst,
) !bool {
    const inst_data = ctx.getInstData(ir_inst);

    switch (inst_data.*) {
        .unary_imm => |data| {
            if (data.opcode == .iconst) {
                const imm = data.imm.value;
                const result_value = ctx.func.dfg.firstResult(ir_inst) orelse return false;
                const ty = ctx.getValueType(result_value);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;
                const dst_vreg = try ctx.getValueReg(result_value, .int);
                const dst = WritableReg.fromVReg(dst_vreg);

                try ctx.emit(Inst{ .mov_imm = .{
                    .dst = dst,
                    .imm = imm,
                    .size = size,
                } });

                return true;
            }
            return false;
        },
        .binary => |data| {
            const lhs = data.args[0];
            const rhs = data.args[1];
            const result_value = ctx.func.dfg.firstResult(ir_inst) orelse return false;
            const ty = ctx.getValueType(result_value);
            const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

            const lhs_reg = try ctx.getValueReg(lhs, .int);
            const rhs_reg = try ctx.getValueReg(rhs, .int);
            const dst_vreg = try ctx.getValueReg(result_value, .int);
            const dst = WritableReg.fromVReg(dst_vreg);

            // x64 ALU instructions modify first operand, so copy lhs to dst first
            try ctx.emit(Inst{ .mov_rr = .{
                .dst = dst,
                .src = Reg.fromVReg(lhs_reg),
                .size = size,
            } });

            switch (data.opcode) {
                .iadd => {
                    try ctx.emit(Inst{ .add_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                .isub => {
                    try ctx.emit(Inst{ .sub_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                .band => {
                    try ctx.emit(Inst{ .and_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                .bor => {
                    try ctx.emit(Inst{ .or_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                .bxor => {
                    try ctx.emit(Inst{ .xor_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                .imul => {
                    try ctx.emit(Inst{ .imul_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                else => return false,
            }
        },
        .binary_imm64 => |data| {
            const lhs = data.arg;
            const imm = data.imm.value;
            const result_value = ctx.func.dfg.firstResult(ir_inst) orelse return false;
            const ty = ctx.getValueType(result_value);
            const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

            const lhs_reg = try ctx.getValueReg(lhs, .int);
            const dst_vreg = try ctx.getValueReg(result_value, .int);
            const dst = WritableReg.fromVReg(dst_vreg);

            // Copy lhs to dst
            try ctx.emit(Inst{ .mov_rr = .{
                .dst = dst,
                .src = Reg.fromVReg(lhs_reg),
                .size = size,
            } });

            // Check if immediate fits in i32
            if (imm >= std.math.minInt(i32) and imm <= std.math.maxInt(i32)) {
                const imm32: i32 = @intCast(imm);

                switch (data.opcode) {
                    .iadd_imm => {
                        try ctx.emit(Inst{ .add_imm = .{
                            .dst = dst,
                            .imm = imm32,
                            .size = size,
                        } });
                        return true;
                    },
                    .isub_imm => {
                        try ctx.emit(Inst{ .sub_imm = .{
                            .dst = dst,
                            .imm = imm32,
                            .size = size,
                        } });
                        return true;
                    },
                    else => return false,
                }
            }

            return false;
        },
        .@"return" => |data| {
            const args = ctx.func.dfg.value_lists.asSlice(data.args);
            const sig_rets = ctx.func.sig.returns.items;
            if (args.len != sig_rets.len) return false;
            if (args.len == 0) {
                try ctx.emit(Inst.ret);
                return true;
            }

            const abi = switch (ctx.func.sig.call_conv) {
                .system_v => x64_abi.systemV(),
                .windows_fastcall => x64_abi.windowsFastcall(),
                else => return false,
            };

            var int_idx: usize = 0;
            var float_idx: usize = 0;

            for (args, 0..) |ret_val, i| {
                const ty = ctx.getValueType(ret_val);
                if (!ty.eql(sig_rets[i].value_type)) return false;
                if (ty.isStruct() or ty.isVector() or ty.isDynamicVector()) return false;

                if (ty.isFloat()) {
                    const bits = ty.bits();
                    if (bits != 32 and bits != 64) return false;
                    if (float_idx >= abi.float_ret_regs.len) return false;

                    const src = Reg.fromVReg(try ctx.getValueReg(ret_val, .float));
                    const dst_reg = Reg.fromPReg(abi.float_ret_regs[float_idx]);
                    const dst = WritableReg.fromReg(dst_reg);

                    if (bits == 32) {
                        try ctx.emit(Inst{ .movss_rr = .{
                            .dst = dst,
                            .src = src,
                        } });
                    } else {
                        try ctx.emit(Inst{ .movsd_rr = .{
                            .dst = dst,
                            .src = src,
                        } });
                    }

                    float_idx += 1;
                } else {
                    const bits = ty.bits();
                    if (bits == 128) return false;
                    if (int_idx >= abi.int_ret_regs.len) return false;

                    const size: OperandSize = if (bits != 0 and bits <= 32) .size32 else .size64;
                    const src = Reg.fromVReg(try ctx.getValueReg(ret_val, .int));
                    const dst_reg = Reg.fromPReg(abi.int_ret_regs[int_idx]);
                    const dst = WritableReg.fromReg(dst_reg);
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = dst,
                        .src = src,
                        .size = size,
                    } });
                    int_idx += 1;
                }
            }

            try ctx.emit(Inst.ret);
            return true;
        },
        .nullary => |data| {
            if (data.opcode == .@"return") {
                try ctx.emit(Inst.ret);
                return true;
            }
            return false;
        },
        else => return false,
    }
}

test "x64 lower multi-return i64 pair" {
    const testing = std.testing;

    var sig = root.signature.Signature.init(testing.allocator, .system_v);
    try sig.params.append(testing.allocator, root.signature.AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, root.signature.AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, root.signature.AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, root.signature.AbiParam.new(Type.I64));

    var func = try root.function.Function.init(testing.allocator, "ret_pair", sig);
    defer func.deinit();

    var builder = try root.builder.FunctionBuilder.init(testing.allocator, &func);
    defer builder.deinit();

    const block = try builder.createBlock();
    const p0 = try builder.appendBlockParam(block, Type.I64);
    const p1 = try builder.appendBlockParam(block, Type.I64);
    builder.switchToBlock(block);
    try builder.retValues(&.{ p0, p1 });
    try builder.sealBlock(block);

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const params = func.dfg.blockParams(block);
    for (params) |param| {
        _ = try ctx.getValueReg(param, .int);
    }

    _ = try ctx.startBlock(block);
    var inst_iter = func.layout.blockInsts(block);
    while (inst_iter.next()) |ir_inst| {
        const handled = try lower(&ctx, ir_inst);
        try testing.expect(handled);
    }
    ctx.endBlock();

    const rax = Reg.fromPReg(PReg.new(.int, 0));
    const rdx = Reg.fromPReg(PReg.new(.int, 2));
    var saw_rax = false;
    var saw_rdx = false;
    var saw_ret = false;

    for (vcode.insns.items) |inst| {
        switch (inst) {
            .mov_rr => |mov| {
                if (mov.dst.toReg().bits == rax.bits) saw_rax = true;
                if (mov.dst.toReg().bits == rdx.bits) saw_rdx = true;
            },
            .ret => saw_ret = true,
            else => {},
        }
    }

    try testing.expect(saw_rax);
    try testing.expect(saw_rdx);
    try testing.expect(saw_ret);
}

test "x64 lower return uses value vreg" {
    const testing = std.testing;

    var sig = root.signature.Signature.init(testing.allocator, .system_v);
    try sig.returns.append(testing.allocator, root.signature.AbiParam.new(Type.I64));

    var func = try root.function.Function.init(testing.allocator, "ret_single", sig);
    defer func.deinit();

    var builder = try root.builder.FunctionBuilder.init(testing.allocator, &func);
    defer builder.deinit();

    const block = try builder.createBlock();
    builder.switchToBlock(block);
    const val = try builder.iconst(Type.I64, 7);
    try builder.retValues(&.{val});
    try builder.sealBlock(block);

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    _ = try ctx.startBlock(block);
    var inst_iter = func.layout.blockInsts(block);
    while (inst_iter.next()) |ir_inst| {
        const handled = try lower(&ctx, ir_inst);
        try testing.expect(handled);
    }
    ctx.endBlock();

    const rax = Reg.fromPReg(PReg.new(.int, 0));
    var mov_imm_dst: ?Reg = null;
    var mov_ret_src: ?Reg = null;

    for (vcode.insns.items) |inst| {
        switch (inst) {
            .mov_imm => |mov| mov_imm_dst = mov.dst.toReg(),
            .mov_rr => |mov| {
                if (mov.dst.toReg().bits == rax.bits) {
                    mov_ret_src = mov.src;
                }
            },
            else => {},
        }
    }

    try testing.expect(mov_imm_dst != null);
    try testing.expect(mov_ret_src != null);
    try testing.expectEqual(mov_imm_dst.?.bits, mov_ret_src.?.bits);
}
