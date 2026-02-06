const std = @import("std");
const testing = std.testing;

const root = @import("../../root.zig");
const Inst = @import("inst.zig").Inst;
const Reg = @import("inst.zig").Reg;
const WritableReg = @import("inst.zig").WritableReg;
const lower_mod = @import("../../machinst/lower.zig");
const LowerCtx = lower_mod.LowerCtx;
const Signature = root.signature.Signature;

pub const S390xLower = struct {
    pub fn lowerInst(
        ctx: *LowerCtx(Inst),
        inst: lower_mod.Inst,
    ) !bool {
        const data = ctx.func.dfg.insts.get(inst) orelse return false;
        switch (data.*) {
            .unary_imm => |uimm| {
                if (uimm.opcode != .iconst) return false;
                const result = ctx.func.dfg.firstResult(inst) orelse return false;
                const dst = WritableReg.fromVReg(try ctx.getValueReg(result, .int));
                const imm = uimm.imm.value;
                if (imm < std.math.minInt(i16) or imm > std.math.maxInt(i16)) return false;
                try ctx.emit(.{ .lghi = .{
                    .dst = dst,
                    .imm = @intCast(imm),
                } });
                return true;
            },
            .binary => |bin| {
                if (bin.opcode != .iadd) return false;
                const result = ctx.func.dfg.firstResult(inst) orelse return false;
                const lhs_vreg = try ctx.getValueReg(bin.args[0], .int);
                const lhs = Reg.fromVReg(lhs_vreg);
                const rhs = Reg.fromVReg(try ctx.getValueReg(bin.args[1], .int));

                // s390x add is 2-operand; reuse lhs for the result until move support lands.
                try ctx.value_to_reg.put(result, lhs_vreg);
                try ctx.emit(.{ .agr = .{
                    .dst = WritableReg.fromReg(lhs),
                    .src1 = lhs,
                    .src2 = rhs,
                } });
                return true;
            },
            .unary => |u| {
                if (u.opcode != .@"return") return false;
                try ctx.emit(.ret);
                return true;
            },
            .nullary => |n| {
                if (n.opcode != .@"return") return false;
                try ctx.emit(.ret);
                return true;
            },
            .@"return" => {
                try ctx.emit(.ret);
                return true;
            },
            else => return false,
        }
    }

    pub fn lowerBranch(
        ctx: *LowerCtx(Inst),
        inst: lower_mod.Inst,
    ) !bool {
        _ = ctx;
        _ = inst;
        return false;
    }

    pub fn backend() lower_mod.LowerBackend(Inst) {
        return .{
            .lowerInstFn = lowerInst,
            .lowerBranchFn = lowerBranch,
        };
    }
};

pub fn getValueReg(ctx: *LowerCtx(Inst), value: lower_mod.Value, class: lower_mod.RegClass) !Reg {
    const vreg = try ctx.getValueReg(value, class);
    return Reg.fromVReg(vreg);
}

pub fn allocOutputReg(ctx: *LowerCtx(Inst), class: lower_mod.RegClass) WritableReg {
    const vreg = ctx.allocVReg(class);
    return WritableReg.fromVReg(vreg);
}

pub fn allocInputReg(ctx: *LowerCtx(Inst), class: lower_mod.RegClass) Reg {
    const vreg = ctx.allocVReg(class);
    return Reg.fromVReg(vreg);
}

test "S390xLower backend creation" {
    const backend = S390xLower.backend();
    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);
}

test "S390xLower with stub function" {
    const backend = S390xLower.backend();

    const sig = Signature.init(testing.allocator, .system_v);
    var func = try lower_mod.Function.init(testing.allocator, "s390x_stub", sig);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const inst = lower_mod.Inst.new(0);
    const handled = try backend.lowerInstFn(&ctx, inst);

    try testing.expectEqual(false, handled);
}
