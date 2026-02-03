// Generated ISLE lowering for riscv64
// TODO: Replace with actual ISLE-generated code when parser is complete

const std = @import("std");
const inst_mod = @import("../backends/riscv64/inst.zig");
const Inst = inst_mod.Inst;
const lower_mod = @import("../machinst/lower.zig");

// Manual lowering stub until ISLE-generated lowering is wired in.
pub fn lower(
    ctx: *lower_mod.LowerCtx(Inst),
    ir_inst: lower_mod.Inst,
) !bool {
    _ = ctx;
    _ = ir_inst;
    return false;
}

