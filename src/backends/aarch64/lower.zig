const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const OperandSize = root.aarch64_inst.OperandSize;
const WritableReg = root.aarch64_inst.WritableReg;
const lower_mod = root.lower;
const LowerCtx = lower_mod.LowerCtx;

/// Aarch64 lowering backend implementation.
/// This connects ISLE rules to actual instruction emission.
pub const Aarch64Lower = struct {
    /// Lower a single IR instruction.
    pub fn lowerInst(
        ctx: *LowerCtx(Inst),
        inst: lower_mod.Inst,
    ) !bool {
        _ = ctx;
        _ = inst;

        // In full implementation:
        // 1. Get instruction data from IR
        // 2. Match against ISLE rules
        // 3. Emit aarch64 instructions via ctx.emit()

        // For now, stub - ISLE integration pending
        return false;
    }

    /// Lower a branch instruction.
    pub fn lowerBranch(
        ctx: *LowerCtx(Inst),
        inst: lower_mod.Inst,
    ) !bool {
        _ = ctx;
        _ = inst;

        // In full implementation:
        // 1. Determine branch type (B vs B.cond)
        // 2. Generate comparison if needed (CMP/TST)
        // 3. Emit branch instruction

        return false;
    }

    /// Create backend trait for aarch64.
    pub fn backend() lower_mod.LowerBackend(Inst) {
        return .{
            .lowerInstFn = lowerInst,
            .lowerBranchFn = lowerBranch,
        };
    }
};

/// ISLE-generated lowering helpers (stubs for now).
/// In full implementation, these would be generated from lower.isle.
/// Helper to convert IR type to aarch64 operand size.
fn typeToSize(ty: anytype) OperandSize {
    _ = ty;
    return .size64; // Default to 64-bit
}

/// Helper to get register for IR value.
fn getValueReg(ctx: *LowerCtx(Inst), value: lower_mod.Value) !Reg {
    const vreg = try ctx.getValueReg(value, .int);
    return Reg.fromVReg(vreg);
}

/// Helper to allocate output register.
fn allocOutputReg(ctx: *LowerCtx(Inst)) !WritableReg {
    const vreg = ctx.allocVReg(.int);
    return WritableReg.fromVReg(vreg);
}

test "Aarch64Lower backend creation" {
    const backend = Aarch64Lower.backend();

    // Should have function pointers set
    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);
}

test "Aarch64Lower with stub function" {
    const backend = Aarch64Lower.backend();

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const inst = lower_mod.Inst.new(0);
    const handled = try backend.lowerInstFn(&ctx, inst);

    // Stub returns false (not handled)
    try testing.expectEqual(false, handled);
}
