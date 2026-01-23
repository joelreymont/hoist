const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = @import("inst.zig").Inst;
const Reg = @import("inst.zig").Reg;
const WritableReg = @import("inst.zig").WritableReg;
const lower_mod = @import("../../machinst/lower.zig");
const LowerCtx = lower_mod.LowerCtx;

pub const S390xLower = struct {
    pub fn lowerInst(
        ctx: *LowerCtx(Inst),
        inst: lower_mod.Inst,
    ) !bool {
        _ = ctx;
        _ = inst;
        return false;
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

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const inst = lower_mod.Inst.new(0);
    const handled = try backend.lowerInstFn(&ctx, inst);

    try testing.expectEqual(false, handled);
}
