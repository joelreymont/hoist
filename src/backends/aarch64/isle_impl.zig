//! ISLE constructor implementation for aarch64.
//! This module provides the glue between ISLE-generated lowering rules
//! and VCode emission. ISLE constructors call these functions to create
//! machine instructions that are emitted into the VCode buffer.

const std = @import("std");
const root = @import("root");

const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const WritableReg = root.aarch64_inst.WritableReg;
const OperandSize = root.aarch64_inst.OperandSize;
const ExtendOp = root.aarch64_inst.ExtendOp;
const Imm12 = root.aarch64_inst.Imm12;
const ImmLogic = root.aarch64_inst.ImmLogic;
const ImmShift = root.aarch64_inst.ImmShift;

const lower_mod = root.lower;
const LowerCtx = lower_mod.LowerCtx;
const Value = lower_mod.Value;
const types = root.types;
const Type = types.Type;

/// ISLE context for aarch64 lowering.
/// This wraps LowerCtx with backend-specific state needed by ISLE constructors.
pub const IsleContext = struct {
    /// Lowering context shared across backends.
    lower_ctx: *LowerCtx(Inst),

    pub fn init(ctx: *LowerCtx(Inst)) IsleContext {
        return .{ .lower_ctx = ctx };
    }

    /// Emit an instruction to VCode.
    pub fn emit(self: *IsleContext, inst: Inst) !void {
        try self.lower_ctx.emit(inst);
    }

    /// Get register for a value, allocating a vreg if needed.
    pub fn getValueReg(self: *IsleContext, value: Value, class: lower_mod.RegClass) !Reg {
        const vreg = try self.lower_ctx.getValueReg(value, class);
        return Reg.fromVReg(vreg);
    }

    /// Allocate a fresh output register.
    pub fn allocOutputReg(self: *IsleContext, class: lower_mod.RegClass) WritableReg {
        const vreg = self.lower_ctx.allocVReg(class);
        return WritableReg.fromVReg(vreg);
    }

    /// Allocate a fresh input register.
    pub fn allocInputReg(self: *IsleContext, class: lower_mod.RegClass) Reg {
        const vreg = self.lower_ctx.allocVReg(class);
        return Reg.fromVReg(vreg);
    }

    /// Convert IR type to aarch64 operand size.
    pub fn typeToSize(self: *IsleContext, ty: Type) OperandSize {
        _ = self;
        return if (ty.bits() <= 32) .size32 else .size64;
    }
};

// ============================================================================
// ISLE Constructors - Integer Arithmetic
// ============================================================================

/// Constructor: ADD register-register (ADD Xd, Xn, Xm).
/// Emits: dst = src1 + src2
pub fn aarch64_add_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .add_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

/// Constructor: ADD with extended register (ADD Xd, Xn, Wm, extend).
/// Emits: dst = src1 + extend(src2)
pub fn aarch64_add_extended(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    extend: ExtendOp,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .add_extended = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .extend = extend,
        .size = size,
    } });

    return dst;
}

/// Constructor: ADD with shifted register (ADD Xd, Xn, Xm, shift #amount).
/// Emits: dst = x + (y << shift_amt)
pub fn aarch64_add_shifted(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    shift_op: ShiftOp,
    shift_amt: u6,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .add_shifted = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .shift_op = shift_op,
        .shift_amt = shift_amt,
        .size = size,
    } });

    return dst;
}

/// Constructor: ADD immediate (ADD Xd, Xn, #imm).
/// Emits: dst = src + imm
pub fn aarch64_add_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: u64,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm12 = Imm12.maybeFromU64(imm) orelse return error.ImmediateOutOfRange;

    try ctx.emit(.{ .add_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = @intCast(imm12.bits),
        .size = size,
    } });

    return dst;
}

/// Constructor: SUB register-register (SUB Xd, Xn, Xm).
/// Emits: dst = src1 - src2
pub fn aarch64_sub_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .sub_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

/// Constructor: SUB immediate (SUB Xd, Xn, #imm).
/// Emits: dst = src - imm
pub fn aarch64_sub_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: u64,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm12 = Imm12.maybeFromU64(imm) orelse return error.ImmediateOutOfRange;

    try ctx.emit(.{ .sub_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = @intCast(imm12.bits),
        .size = size,
    } });

    return dst;
}

/// Constructor: SUB with shifted register (SUB Xd, Xn, Xm, shift #amount).
/// Emits: dst = x - (y << shift_amt)
pub fn aarch64_sub_shifted(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    shift_op: ShiftOp,
    shift_amt: u6,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .sub_shifted = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .shift_op = shift_op,
        .shift_amt = shift_amt,
        .size = size,
    } });

    return dst;
}

/// Constructor: MUL register-register (MUL Xd, Xn, Xm).
/// Emits: dst = src1 * src2
pub fn aarch64_mul_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .mul_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

/// Constructor: MADD - multiply-add (MADD Xd, Xn, Xm, Xa).
/// Emits: dst = addend + (src1 * src2)
pub fn aarch64_madd(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    addend: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const reg_addend = try ctx.getValueReg(addend, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .madd = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .addend = reg_addend,
        .size = size,
    } });

    return dst;
}

/// Constructor: MSUB - multiply-subtract (MSUB Xd, Xn, Xm, Xa).
/// Emits: dst = minuend - (src1 * src2)
pub fn aarch64_msub(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    minuend: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const reg_minuend = try ctx.getValueReg(minuend, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .msub = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .minuend = reg_minuend,
        .size = size,
    } });

    return dst;
}

/// Constructor: SMULH - signed multiply high (SMULH Xd, Xn, Xm).
/// Emits: dst = (src1 * src2)[127:64] (signed)
pub fn aarch64_smulh(
    ctx: *IsleContext,
    x: Value,
    y: Value,
) !WritableReg {
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .smulh = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
    } });

    return dst;
}

/// Constructor: UMULH - unsigned multiply high (UMULH Xd, Xn, Xm).
/// Emits: dst = (src1 * src2)[127:64] (unsigned)
pub fn aarch64_umulh(
    ctx: *IsleContext,
    x: Value,
    y: Value,
) !WritableReg {
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .umulh = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
    } });

    return dst;
}

/// Constructor: SDIV - signed divide (SDIV Xd, Xn, Xm).
/// Emits: dst = src1 / src2 (signed)
pub fn aarch64_sdiv(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .sdiv = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

/// Constructor: UDIV - unsigned divide (UDIV Xd, Xn, Xm).
/// Emits: dst = src1 / src2 (unsigned)
pub fn aarch64_udiv(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .udiv = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

// ============================================================================
// ISLE Constructors - Bitwise Operations
// ============================================================================

/// Constructor: AND register-register (AND Xd, Xn, Xm).
/// Emits: dst = src1 & src2
pub fn aarch64_and_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .and_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

/// Constructor: AND with logical immediate (AND Xd, Xn, #imm).
/// Emits: dst = src & imm
pub fn aarch64_and_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: u64,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm_logic = ImmLogic.maybeFromU64(imm, size) orelse return error.InvalidLogicalImmediate;

    try ctx.emit(.{ .and_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = imm_logic,
    } });

    return dst;
}

/// Constructor: ORR register-register (ORR Xd, Xn, Xm).
/// Emits: dst = src1 | src2
pub fn aarch64_orr_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .orr_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

/// Constructor: ORR with logical immediate (ORR Xd, Xn, #imm).
/// Emits: dst = src | imm
pub fn aarch64_orr_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: u64,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm_logic = ImmLogic.maybeFromU64(imm, size) orelse return error.InvalidLogicalImmediate;

    try ctx.emit(.{ .orr_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = imm_logic,
    } });

    return dst;
}

/// Constructor: EOR register-register (EOR Xd, Xn, Xm).
/// Emits: dst = src1 ^ src2
pub fn aarch64_eor_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .eor_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

/// Constructor: EOR with logical immediate (EOR Xd, Xn, #imm).
/// Emits: dst = src ^ imm
pub fn aarch64_eor_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: u64,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm_logic = ImmLogic.maybeFromU64(imm, size) orelse return error.InvalidLogicalImmediate;

    try ctx.emit(.{ .eor_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = imm_logic,
    } });

    return dst;
}

// ============================================================================
// ISLE Constructors - Shift Operations
// ============================================================================

/// Constructor: LSL register-register (LSL Xd, Xn, Xm).
/// Emits: dst = src1 << src2
pub fn aarch64_lsl_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .lsl_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

/// Constructor: LSL immediate (LSL Xd, Xn, #imm).
/// Emits: dst = src << imm
pub fn aarch64_lsl_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    shift: u8,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .lsl_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = shift,
        .size = size,
    } });

    return dst;
}

/// Constructor: LSR register-register (LSR Xd, Xn, Xm).
/// Emits: dst = src1 >> src2 (logical)
pub fn aarch64_lsr_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .lsr_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

/// Constructor: LSR immediate (LSR Xd, Xn, #imm).
/// Emits: dst = src >> imm (logical)
pub fn aarch64_lsr_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    shift: u8,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .lsr_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = shift,
        .size = size,
    } });

    return dst;
}

/// Constructor: ASR register-register (ASR Xd, Xn, Xm).
/// Emits: dst = src1 >> src2 (arithmetic)
pub fn aarch64_asr_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .asr_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    return dst;
}

/// Constructor: ASR immediate (ASR Xd, Xn, #imm).
/// Emits: dst = src >> imm (arithmetic)
pub fn aarch64_asr_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    shift: u8,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .asr_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = shift,
        .size = size,
    } });

    return dst;
}

// ============================================================================
// ISLE Constructors - Move Operations
// ============================================================================

/// Constructor: MOV register (MOV Xd, Xn).
/// Emits: dst = src
pub fn aarch64_mov_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .mov_rr = .{
        .dst = dst,
        .src = reg_x,
        .size = size,
    } });

    return dst;
}

/// Constructor: MOV immediate (MOV Xd, #imm).
/// Emits: dst = imm
pub fn aarch64_mov_imm(
    ctx: *IsleContext,
    ty: Type,
    imm: u64,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .mov_imm = .{
        .dst = dst,
        .imm = imm,
        .size = size,
    } });

    return dst;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "IsleContext creation" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    const ctx = IsleContext.init(&lower_ctx);
    try testing.expect(@intFromPtr(ctx.lower_ctx) != 0);
}

test "aarch64_add_rr constructor" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    // Start a block to allow emission
    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);

    const dst = try aarch64_add_rr(&ctx, Type.I64, v1, v2);

    // Verify instruction was emitted
    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.add_rr, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(OperandSize.size64, vcode.insns.items[0].add_rr.size);

    // Verify dst is writable
    _ = dst.toReg();
}

test "aarch64_mul_rr constructor" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);

    const dst = try aarch64_mul_rr(&ctx, Type.I32, v1, v2);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.mul_rr, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(OperandSize.size32, vcode.insns.items[0].mul_rr.size);

    _ = dst.toReg();
}

test "aarch64_madd constructor - multiply-add fusion" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);
    const v3 = Value.new(2);

    // MADD: v3 + (v1 * v2)
    const dst = try aarch64_madd(&ctx, Type.I64, v1, v2, v3);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.madd, @as(std.meta.Tag(Inst), vcode.insns.items[0]));

    _ = dst.toReg();
}

test "aarch64_and_imm constructor with logical immediate" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);

    // AND with 0xFF (valid logical immediate)
    const dst = try aarch64_and_imm(&ctx, Type.I64, v1, 0xFF);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.and_imm, @as(std.meta.Tag(Inst), vcode.insns.items[0]));

    _ = dst.toReg();
}

test "aarch64_lsl_imm constructor" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);

    const dst = try aarch64_lsl_imm(&ctx, Type.I64, v1, 8);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.lsl_imm, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(@as(u8, 8), vcode.insns.items[0].lsl_imm.imm);

    _ = dst.toReg();
}

test "aarch64_smulh constructor for high multiply" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);

    const dst = try aarch64_smulh(&ctx, v1, v2);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.smulh, @as(std.meta.Tag(Inst), vcode.insns.items[0]));

    _ = dst.toReg();
}

test "typeToSize maps types correctly" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    var ctx = IsleContext.init(&lower_ctx);

    try testing.expectEqual(OperandSize.size32, ctx.typeToSize(Type.I8));
    try testing.expectEqual(OperandSize.size32, ctx.typeToSize(Type.I16));
    try testing.expectEqual(OperandSize.size32, ctx.typeToSize(Type.I32));
    try testing.expectEqual(OperandSize.size64, ctx.typeToSize(Type.I64));
}
