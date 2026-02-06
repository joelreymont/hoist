const std = @import("std");
const testing = std.testing;

const root = @import("../../root.zig");
const Inst = root.x64_inst.Inst;
const Reg = root.x64_inst.Reg;
const OperandSize = root.x64_inst.OperandSize;
const WritableReg = root.x64_inst.WritableReg;
const CondCode = root.x64_inst.CondCode;
const BranchTarget = root.x64_inst.BranchTarget;
const lower_mod = root.lower;
const LowerCtx = lower_mod.LowerCtx;
const Type = root.types.Type;
const Signature = root.signature.Signature;
const AbiParam = root.signature.AbiParam;
const InstructionData = root.instruction_data.InstructionData;
const IntCC = root.condcodes.IntCC;

/// X64 lowering backend implementation.
/// This connects ISLE rules to actual instruction emission.
pub const X64Lower = struct {
    /// Lower a single IR instruction.
    pub fn lowerInst(
        ctx: *LowerCtx(Inst),
        inst: lower_mod.Inst,
    ) !bool {
        const data = ctx.getInstData(inst);
        switch (data.*) {
            .unary_imm => |uimm| {
                if (uimm.opcode != .iconst) return false;
                const result = ctx.func.dfg.firstResult(inst) orelse return false;
                const ty = try ctx.getValueType(result);
                const dst = WritableReg.fromVReg(try ctx.getValueReg(result, .int));
                try ctx.emit(Inst{ .mov_imm = .{
                    .dst = dst,
                    .imm = @intCast(uimm.imm.value),
                    .size = typeToSize(ty),
                } });
                return true;
            },
            .binary => |bin| {
                const opcode = bin.opcode;
                if (opcode != .iadd and opcode != .isub and opcode != .imul and opcode != .band and opcode != .bor and opcode != .bxor) {
                    return false;
                }

                const result = ctx.func.dfg.firstResult(inst) orelse return false;
                const ty = try ctx.getValueType(result);
                const size = typeToSize(ty);
                const lhs = try getValueReg(ctx, bin.args[0]);
                const rhs = try getValueReg(ctx, bin.args[1]);
                const dst = WritableReg.fromVReg(try ctx.getValueReg(result, .int));

                // x64 ALU ops are two-operand; preserve SSA by copying lhs into dst first.
                try ctx.emit(Inst{ .mov_rr = .{
                    .dst = dst,
                    .src = lhs,
                    .size = size,
                } });

                switch (opcode) {
                    .iadd => try ctx.emit(Inst{ .add_rr = .{ .dst = dst, .src = rhs, .size = size } }),
                    .isub => try ctx.emit(Inst{ .sub_rr = .{ .dst = dst, .src = rhs, .size = size } }),
                    .imul => try ctx.emit(Inst{ .imul_rr = .{ .dst = dst, .src = rhs, .size = size } }),
                    .band => try ctx.emit(Inst{ .and_rr = .{ .dst = dst, .src = rhs, .size = size } }),
                    .bor => try ctx.emit(Inst{ .or_rr = .{ .dst = dst, .src = rhs, .size = size } }),
                    .bxor => try ctx.emit(Inst{ .xor_rr = .{ .dst = dst, .src = rhs, .size = size } }),
                    else => unreachable,
                }
                return true;
            },
            .binary_imm64 => |bimm| {
                if (bimm.opcode != .iadd_imm and bimm.opcode != .irsub_imm) return false;
                if (bimm.imm.value < std.math.minInt(i32) or bimm.imm.value > std.math.maxInt(i32)) return false;

                const result = ctx.func.dfg.firstResult(inst) orelse return false;
                const ty = try ctx.getValueType(result);
                const size = typeToSize(ty);
                const lhs = try getValueReg(ctx, bimm.arg);
                const dst = WritableReg.fromVReg(try ctx.getValueReg(result, .int));

                try ctx.emit(Inst{ .mov_rr = .{
                    .dst = dst,
                    .src = lhs,
                    .size = size,
                } });

                const imm: i32 = @intCast(bimm.imm.value);
                if (bimm.opcode == .iadd_imm) {
                    try ctx.emit(Inst{ .add_imm = .{
                        .dst = dst,
                        .imm = imm,
                        .size = size,
                    } });
                } else {
                    // irsub_imm computes (imm - arg).
                    try ctx.emit(Inst{ .neg = .{
                        .dst = dst,
                        .size = size,
                    } });
                    try ctx.emit(Inst{ .add_imm = .{
                        .dst = dst,
                        .imm = imm,
                        .size = size,
                    } });
                }
                return true;
            },
            .unary => |u| {
                if (u.opcode != .@"return") return false;
                try emitSingleReturn(ctx, u.arg);
                return true;
            },
            .nullary => |n| {
                if (n.opcode != .@"return") return false;
                try ctx.emit(Inst.ret);
                return true;
            },
            .@"return" => |r| {
                const args = ctx.func.dfg.value_lists.asSlice(r.args);
                if (args.len == 0) {
                    try ctx.emit(Inst.ret);
                    return true;
                }
                if (args.len == 1) {
                    try emitSingleReturn(ctx, args[0]);
                    return true;
                }
                return false;
            },
            // Terminators are emitted by lowerBranch.
            .jump, .branch, .branch_z, .branch_table => return true,
            else => return false,
        }
    }

    /// Lower a branch instruction.
    pub fn lowerBranch(
        ctx: *LowerCtx(Inst),
        inst: lower_mod.Inst,
    ) !bool {
        const data = ctx.getInstData(inst);
        switch (data.*) {
            .jump => |j| {
                const label = try ctx.getBlockLabel(j.destination);
                try ctx.emit(Inst{ .jmp = .{ .target = BranchTarget.new(label) } });
                return true;
            },
            .branch => |b| {
                const cond_reg = try getValueReg(ctx, b.condition);
                const cond_ty = try ctx.getValueType(b.condition);
                try ctx.emit(Inst{ .cmp_imm = .{
                    .lhs = cond_reg,
                    .imm = 0,
                    .size = typeToSize(cond_ty),
                } });

                if (b.then_dest) |then_block| {
                    const then_label = try ctx.getBlockLabel(then_block);
                    try ctx.emit(Inst{ .jmp_cond = .{
                        .cc = .ne,
                        .target = BranchTarget.new(then_label),
                    } });
                }
                if (b.else_dest) |else_block| {
                    const else_label = try ctx.getBlockLabel(else_block);
                    try ctx.emit(Inst{ .jmp = .{
                        .target = BranchTarget.new(else_label),
                    } });
                }
                return true;
            },
            .branch_z => |bz| {
                const cond_reg = try getValueReg(ctx, bz.condition);
                const cond_ty = try ctx.getValueType(bz.condition);
                const label = try ctx.getBlockLabel(bz.destination);
                try ctx.emit(Inst{ .cmp_imm = .{
                    .lhs = cond_reg,
                    .imm = 0,
                    .size = typeToSize(cond_ty),
                } });
                try ctx.emit(Inst{ .jmp_cond = .{
                    .cc = .e,
                    .target = BranchTarget.new(label),
                } });
                return true;
            },
            else => return false,
        }
    }

    /// Create backend trait for x64.
    pub fn backend() lower_mod.LowerBackend(Inst) {
        return .{
            .lowerInstFn = lowerInst,
            .lowerBranchFn = lowerBranch,
        };
    }
};

/// Helper to convert IR type to x64 operand size.
fn typeToSize(ty: Type) OperandSize {
    const bits = ty.bits();
    if (bits <= 8) return .size8;
    if (bits <= 16) return .size16;
    if (bits <= 32) return .size32;
    return .size64;
}

/// Helper to get register for IR value.
fn getValueReg(ctx: *LowerCtx(Inst), value: lower_mod.Value) !Reg {
    const vreg = try ctx.getValueReg(value, .int);
    return Reg.fromVReg(vreg);
}

fn mapIntCC(cc: IntCC) CondCode {
    return switch (cc) {
        .eq => .e,
        .ne => .ne,
        .slt => .l,
        .sge => .ge,
        .sgt => .g,
        .sle => .le,
        .ult => .b,
        .uge => .ae,
        .ugt => .a,
        .ule => .be,
    };
}

fn emitSingleReturn(ctx: *LowerCtx(Inst), value: lower_mod.Value) !void {
    const ty = try ctx.getValueType(value);
    if (ty.isStruct() or ty.isVector() or ty.isDynamicVector()) return error.UnhandledInstruction;
    const bits = ty.bits();
    const size = typeToSize(ty);
    if (ty.isFloat()) {
        const src = Reg.fromVReg(try ctx.getValueReg(value, .float));
        const dst = WritableReg.fromReg(Reg.fromPReg(root.x64_abi.systemV().float_ret_regs[0]));
        if (bits == 32) {
            try ctx.emit(Inst{ .movss_rr = .{ .dst = dst, .src = src } });
        } else {
            try ctx.emit(Inst{ .movsd_rr = .{ .dst = dst, .src = src } });
        }
    } else {
        const src = try getValueReg(ctx, value);
        const dst = WritableReg.fromReg(Reg.fromPReg(root.x64_abi.systemV().int_ret_regs[0]));
        try ctx.emit(Inst{ .mov_rr = .{
            .dst = dst,
            .src = src,
            .size = size,
        } });
    }
    try ctx.emit(Inst.ret);
}

test "X64Lower backend creation" {
    const backend = X64Lower.backend();

    // Should have function pointers set
    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);
}

test "X64Lower with stub function" {
    const backend = X64Lower.backend();

    const sig = Signature.init(testing.allocator, .system_v);
    var func = try lower_mod.Function.init(testing.allocator, "x64_stub", sig);
    defer func.deinit();

    const block = try func.dfg.makeBlock();
    try func.layout.appendBlock(block);
    const ret_inst = try func.dfg.makeInst(InstructionData{ .nullary = .{ .opcode = .@"return" } });
    try func.layout.appendInst(ret_inst, block);

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    _ = try ctx.startBlock(block);
    const inst = ret_inst;
    const handled = try backend.lowerInstFn(&ctx, inst);
    ctx.endBlock();

    try testing.expectEqual(true, handled);
}

test "X64Lower lowers integer ALU + return" {
    var sig = Signature.init(testing.allocator, .system_v);
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try lower_mod.Function.init(testing.allocator, "x64_lower_iadd", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const lhs = try func.dfg.appendBlockParam(block0, Type.I64);
    const rhs = try func.dfg.appendBlockParam(block0, Type.I64);

    const add_inst = try func.dfg.makeInst(InstructionData{ .binary = .{
        .opcode = .iadd,
        .args = .{ lhs, rhs },
    } });
    try func.layout.appendInst(add_inst, block0);
    const sum = try func.dfg.appendInstResult(add_inst, Type.I64);

    const ret_inst = try func.dfg.makeInst(InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = sum,
    } });
    try func.layout.appendInst(ret_inst, block0);

    var vcode = try lower_mod.lowerFunction(Inst, testing.allocator, &func, X64Lower.backend());
    defer vcode.deinit();

    var saw_add = false;
    var saw_ret = false;
    for (vcode.insns.items) |insn| switch (insn) {
        .add_rr => saw_add = true,
        .ret => saw_ret = true,
        else => {},
    };

    try testing.expect(saw_add);
    try testing.expect(saw_ret);
}

test "X64Lower lowers brif terminator" {
    var sig = Signature.init(testing.allocator, .system_v);
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try lower_mod.Function.init(testing.allocator, "x64_lower_brif", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    const then_block = try func.dfg.makeBlock();
    const else_block = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(then_block);
    try func.layout.appendBlock(else_block);

    const cond = try func.dfg.appendBlockParam(entry, Type.I64);
    const br_inst = try func.dfg.makeInst(InstructionData{ .branch = .{
        .opcode = .brif,
        .condition = cond,
        .then_dest = then_block,
        .else_dest = else_block,
    } });
    try func.layout.appendInst(br_inst, entry);

    const t_iconst = try func.dfg.makeInst(InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = .{ .value = 1 },
    } });
    try func.layout.appendInst(t_iconst, then_block);
    const t_val = try func.dfg.appendInstResult(t_iconst, Type.I64);
    const t_ret = try func.dfg.makeInst(InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = t_val,
    } });
    try func.layout.appendInst(t_ret, then_block);

    const e_iconst = try func.dfg.makeInst(InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = .{ .value = 0 },
    } });
    try func.layout.appendInst(e_iconst, else_block);
    const e_val = try func.dfg.appendInstResult(e_iconst, Type.I64);
    const e_ret = try func.dfg.makeInst(InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = e_val,
    } });
    try func.layout.appendInst(e_ret, else_block);

    var vcode = try lower_mod.lowerFunction(Inst, testing.allocator, &func, X64Lower.backend());
    defer vcode.deinit();

    var saw_cmp = false;
    var saw_jcc = false;
    var saw_jmp = false;
    for (vcode.insns.items) |insn| switch (insn) {
        .cmp_imm => saw_cmp = true,
        .jmp_cond => saw_jcc = true,
        .jmp => saw_jmp = true,
        else => {},
    };

    try testing.expect(saw_cmp);
    try testing.expect(saw_jcc);
    try testing.expect(saw_jmp);
}
