const std = @import("std");
const testing = std.testing;

const root = @import("../../root.zig");
const Inst = @import("inst.zig").Inst;
const Reg = @import("inst.zig").Reg;
const WritableReg = @import("inst.zig").WritableReg;
const lower_mod = @import("../../machinst/lower.zig");
const LowerCtx = lower_mod.LowerCtx;
const isle_impl = root.riscv64_isle_impl;

// Import ISLE-generated lowering code
const isle_lower = @import("../../generated/isle/riscv64_lower_generated.zig");

pub const Riscv64Lower = struct {
    pub fn lowerInst(
        ctx: *LowerCtx(Inst),
        inst: lower_mod.Inst,
    ) !bool {
        var isle_ctx = isle_impl.IsleCtx.init(ctx);
        const value = ctx.func.dfg.firstResult(inst) orelse try ctx.func.dfg.appendInstResult(inst, root.types.Type.INVALID);
        _ = isle_lower.lower(&isle_ctx, value) catch |err| {
            if (err == error.NoMatch) return false;
            return err;
        };
        return true;
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

test "Riscv64Lower backend creation" {
    const backend = Riscv64Lower.backend();
    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);
}
