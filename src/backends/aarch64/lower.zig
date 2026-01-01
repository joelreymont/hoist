const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const OperandSize = root.aarch64_inst.OperandSize;
const WritableReg = root.aarch64_inst.WritableReg;
const lower_mod = root.lower;
const LowerCtx = lower_mod.LowerCtx;

// Import ISLE-generated lowering code
const isle_lower = @import("../../generated/aarch64_lower_generated.zig");

/// Aarch64 lowering backend implementation.
/// This connects ISLE rules to actual instruction emission.
pub const Aarch64Lower = struct {
    /// Lower a single IR instruction.
    pub fn lowerInst(
        ctx: *LowerCtx(Inst),
        inst: lower_mod.Inst,
    ) !bool {
        // Try ISLE-generated lowering first
        const handled = try isle_lower.lower(ctx, inst);
        if (handled) return true;

        // Fallback for instructions not handled by ISLE
        // (none yet - ISLE compiler needs parser completion)
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

/// ISLE-generated lowering helpers.
/// Helper to convert IR type to aarch64 operand size.
pub fn typeToSize(ty: root.types.Type) OperandSize {
    // Map IR types to AArch64 operand sizes
    if (ty.eql(root.types.Type.I8) or ty.eql(root.types.Type.I16) or
        ty.eql(root.types.Type.I32) or ty.eql(root.types.Type.F32))
    {
        return .size32;
    } else if (ty.eql(root.types.Type.I64) or ty.eql(root.types.Type.F64)) {
        return .size64;
    } else {
        // Default to 64-bit for unknown types (vectors, etc.)
        return .size64;
    }
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

test "typeToSize maps IR types correctly" {
    // 32-bit types
    try testing.expectEqual(OperandSize.size32, typeToSize(root.types.Type.I8));
    try testing.expectEqual(OperandSize.size32, typeToSize(root.types.Type.I16));
    try testing.expectEqual(OperandSize.size32, typeToSize(root.types.Type.I32));
    try testing.expectEqual(OperandSize.size32, typeToSize(root.types.Type.F32));

    // 64-bit types
    try testing.expectEqual(OperandSize.size64, typeToSize(root.types.Type.I64));
    try testing.expectEqual(OperandSize.size64, typeToSize(root.types.Type.F64));

    // Larger types default to size64
    try testing.expectEqual(OperandSize.size64, typeToSize(root.types.Type.I128));
    try testing.expectEqual(OperandSize.size64, typeToSize(root.types.Type.F128));
}
