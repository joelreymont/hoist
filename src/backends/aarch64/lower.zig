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
/// Maps an SSA value to a virtual register, allocating if needed.
pub fn getValueReg(ctx: *LowerCtx(Inst), value: lower_mod.Value, class: lower_mod.RegClass) !Reg {
    const vreg = try ctx.getValueReg(value, class);
    return Reg.fromVReg(vreg);
}

/// Helper to allocate fresh output register.
/// Allocates a new virtual register for an instruction result.
pub fn allocOutputReg(ctx: *LowerCtx(Inst), class: lower_mod.RegClass) WritableReg {
    const vreg = ctx.allocVReg(class);
    return WritableReg.fromVReg(vreg);
}

/// Helper to allocate fresh input register.
/// Variant of allocOutputReg that returns a readable register.
pub fn allocInputReg(ctx: *LowerCtx(Inst), class: lower_mod.RegClass) Reg {
    const vreg = ctx.allocVReg(class);
    return Reg.fromVReg(vreg);
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

test "getValueReg maps SSA values to registers" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Map two different values
    const v1 = lower_mod.Value.new(0);
    const v2 = lower_mod.Value.new(1);

    const r1 = try getValueReg(&ctx, v1, .int);
    const r2 = try getValueReg(&ctx, v2, .int);

    // Should get different registers
    try testing.expect(!std.meta.eql(r1, r2));

    // Requesting same value again should return same register
    const r1_again = try getValueReg(&ctx, v1, .int);
    try testing.expectEqual(r1, r1_again);
}

test "allocOutputReg allocates fresh registers" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Allocate multiple output registers
    const out1 = allocOutputReg(&ctx, .int);
    const out2 = allocOutputReg(&ctx, .int);
    const out3 = allocOutputReg(&ctx, .float);

    // Should all be different
    try testing.expect(!std.meta.eql(out1, out2));
    try testing.expect(!std.meta.eql(out1, out3));
    try testing.expect(!std.meta.eql(out2, out3));

    // Should be writable
    const r1 = out1.toReg();
    const r2 = out2.toReg();
    try testing.expect(!std.meta.eql(r1, r2));
}

test "allocInputReg allocates fresh registers" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Allocate multiple input registers
    const in1 = allocInputReg(&ctx, .int);
    const in2 = allocInputReg(&ctx, .vector);

    // Should be different
    try testing.expect(!std.meta.eql(in1, in2));
}
