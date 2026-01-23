//! ISLE constructor implementation for aarch64.
//! This module provides the glue between ISLE-generated lowering rules
//! and VCode emission. ISLE constructors call these functions to create
//! machine instructions that are emitted into the VCode buffer.

const std = @import("std");
const root = @import("root");

const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const PReg = root.aarch64_inst.PReg;
const WritableReg = root.aarch64_inst.WritableReg;
const OperandSize = root.aarch64_inst.OperandSize;
const CondCode = root.aarch64_inst.CondCode;
const ExtendOp = root.aarch64_inst.ExtendOp;
const ShiftOp = root.aarch64_inst.ShiftOp;
const Imm12 = root.aarch64_inst.Imm12;
const ImmLogic = root.aarch64_inst.ImmLogic;
const ImmShift = root.aarch64_inst.ImmShift;

const lower_mod = root.lower;
const LowerCtx = lower_mod.LowerCtx;
const Value = lower_mod.Value;
const Block = lower_mod.Block;
const StackSlot = lower_mod.StackSlot;
const types = root.types;
const entities = root.entities;
const Type = types.Type;
const condcodes = root.condcodes;
const IntCC = condcodes.IntCC;
const isle_helpers = root.aarch64_isle_helpers;

/// Determine register class from IR type.
fn regClassForType(ty: Type) lower_mod.RegClass {
    return if (ty.isFloat()) .float else .int;
}

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

/// Constructor: SUB with extended operand (SUB Xd, Xn, Xm, extend).
/// Emits: dst = src1 - extended(src2)
pub fn aarch64_sub_extended(
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

    try ctx.emit(.{ .sub_extended = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .extend = extend,
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

/// Constructor: AND with shifted register (AND Xd, Xn, Xm, shift #amt).
/// Emits: dst = src1 & (src2 << shift_amt)
pub fn aarch64_and_shifted(
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

    try ctx.emit(.{ .and_shifted = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .shift_op = shift_op,
        .shift_amt = shift_amt,
        .size = size,
    } });

    return dst;
}

/// Constructor: ORR with shifted register (ORR Xd, Xn, Xm, shift #amt).
/// Emits: dst = src1 | (src2 << shift_amt)
pub fn aarch64_orr_shifted(
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

    try ctx.emit(.{ .orr_shifted = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .shift_op = shift_op,
        .shift_amt = shift_amt,
        .size = size,
    } });

    return dst;
}

/// Constructor: EOR with shifted register (EOR Xd, Xn, Xm, shift #amt).
/// Emits: dst = src1 ^ (src2 << shift_amt)
pub fn aarch64_eor_shifted(
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

    try ctx.emit(.{ .eor_shifted = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .shift_op = shift_op,
        .shift_amt = shift_amt,
        .size = size,
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

/// Convert IntCC to AArch64 CondCode.
fn intccToCondCode(cc: IntCC) CondCode {
    return switch (cc) {
        .eq => .eq,
        .ne => .ne,
        .slt => .lt,
        .sge => .ge,
        .sgt => .gt,
        .sle => .le,
        .ult => .cc,
        .uge => .cs,
        .ugt => .hi,
        .ule => .ls,
    };
}

/// Constructor: CMP+branch fusion (CMP x, y; B.cond target).
/// Emits CMP instruction followed by conditional branch.
/// Avoids materializing comparison result in a register.
pub fn aarch64_cmp_and_branch(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    cc: IntCC,
    target: Block,
) !void {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const cond = intccToCondCode(cc);

    // Emit CMP instruction
    try ctx.emit(.{ .cmp_rr = .{
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    // Emit conditional branch
    try ctx.emit(.{ .b_cond = .{
        .cond = cond,
        .target = target,
    } });
}

/// Constructor: CBZ - Compare and branch if zero.
/// Emits a CBZ instruction that branches to target if x == 0.
pub fn aarch64_cbz(
    ctx: *IsleContext,
    x: Value,
    target: Block,
) !void {
    const ty = ctx.valueType(x);
    const size = ctx.typeToSize(ty);
    const reg = try ctx.getValueReg(x, .int);

    try ctx.emit(.{ .cbz = .{
        .reg = reg,
        .target = target,
        .size = size,
    } });
}

/// Constructor: CBNZ - Compare and branch if non-zero.
/// Emits a CBNZ instruction that branches to target if x != 0.
pub fn aarch64_cbnz(
    ctx: *IsleContext,
    x: Value,
    target: Block,
) !void {
    const ty = ctx.valueType(x);
    const size = ctx.typeToSize(ty);
    const reg = try ctx.getValueReg(x, .int);

    try ctx.emit(.{ .cbnz = .{
        .reg = reg,
        .target = target,
        .size = size,
    } });
}

/// Constructor: TBZ - Test bit and branch if zero.
/// Emits a TBZ instruction that branches to target if bit N of x is zero.
pub fn aarch64_tbz(
    ctx: *IsleContext,
    x: Value,
    bit: u8,
    target: Block,
) !void {
    const reg = try ctx.getValueReg(x, .int);

    try ctx.emit(.{ .tbz = .{
        .reg = reg,
        .bit = bit,
        .target = target,
    } });
}

/// Constructor: TBNZ - Test bit and branch if non-zero.
/// Emits a TBNZ instruction that branches to target if bit N of x is non-zero.
pub fn aarch64_tbnz(
    ctx: *IsleContext,
    x: Value,
    bit: u8,
    target: Block,
) !void {
    const reg = try ctx.getValueReg(x, .int);

    try ctx.emit(.{ .tbnz = .{
        .reg = reg,
        .bit = bit,
        .target = target,
    } });
}

/// Constructor: stack_addr - compute address of stack slot.
/// Returns SP/FP + offset for accessing stack-allocated data.
pub fn aarch64_stack_addr(
    ctx: *IsleContext,
    stack_slot: u32,
    offset: i32,
) !WritableReg {
    const slot = StackSlot.new(stack_slot);

    // Get the frame offset for this stack slot
    const frame_offset = try ctx.lower_ctx.getStackSlotOffset(slot);

    // Add user-provided offset
    const total_offset = frame_offset + offset;

    // Allocate output register for the address
    const dst = ctx.allocOutputReg(.int);

    // Generate: ADD dst, SP, #total_offset
    // Use SP (x31) as base register
    const sp = Reg.gpr(31);

    try ctx.emit(Inst{ .add_imm = .{
        .dst = dst,
        .src = sp,
        .imm = @intCast(total_offset),
    } });

    return dst;
}

/// Constructor: stack_load - load from stack slot.
/// Emits LDR with SP/FP-relative addressing.
pub fn aarch64_stack_load(
    ctx: *IsleContext,
    ty: Type,
    stack_slot: u32,
    offset: i32,
) !WritableReg {
    const slot = StackSlot.new(stack_slot);

    // Get address of stack slot
    const addr_inst = try isle_helpers.aarch64_stack_addr(slot, offset, ctx.lower_ctx);
    try ctx.emit(addr_inst);
    const addr_reg = addr_inst.getWritableDst().?;

    // Allocate destination register
    const dst = WritableReg.allocReg(regClassForType(ty), ctx.lower_ctx);

    // Emit LDR instruction based on type size
    const size_bits = ty.bits();
    const load_inst = if (ty.isInt() or ty.isBool()) blk: {
        if (size_bits == 64) {
            break :blk Inst{ .ldr = .{
                .dst = dst,
                .base = addr_reg.toReg(),
                .offset = 0,
                .size = .size64,
            } };
        } else if (size_bits == 32) {
            break :blk Inst{ .ldr = .{
                .dst = dst,
                .base = addr_reg.toReg(),
                .offset = 0,
                .size = .size32,
            } };
        } else if (size_bits == 16) {
            break :blk Inst{ .ldrh = .{
                .dst = dst,
                .base = addr_reg.toReg(),
                .offset = 0,
            } };
        } else if (size_bits == 8) {
            break :blk Inst{ .ldrb = .{
                .dst = dst,
                .base = addr_reg.toReg(),
                .offset = 0,
            } };
        } else {
            return error.UnsupportedIntegerSize;
        }
    } else if (ty.isFloat()) blk: {
        if (size_bits == 64) {
            break :blk Inst{ .fp_load = .{
                .dst = dst,
                .base = addr_reg.toReg(),
                .offset = 0,
                .size = .size64,
            } };
        } else if (size_bits == 32) {
            break :blk Inst{ .fp_load = .{
                .dst = dst,
                .base = addr_reg.toReg(),
                .offset = 0,
                .size = .size32,
            } };
        } else {
            return error.UnsupportedFloatSize;
        }
    } else {
        return error.UnsupportedType;
    };

    try ctx.emit(load_inst);
    return dst;
}

/// Constructor: stack_store - store to stack slot.
/// Emits STR with SP/FP-relative addressing.
pub fn aarch64_stack_store(
    ctx: *IsleContext,
    ty: Type,
    value: Value,
    stack_slot: u32,
    offset: i32,
) !void {
    const slot = StackSlot.new(stack_slot);

    // Get address of stack slot
    const addr_inst = try isle_helpers.aarch64_stack_addr(slot, offset, ctx.lower_ctx);
    try ctx.emit(addr_inst);
    const addr_reg = addr_inst.getWritableDst().?;

    // Get value register
    const val_reg = try ctx.lower_ctx.getValueReg(value, regClassForType(ty));

    // Emit STR instruction based on type size
    const size_bits = ty.bits();
    const store_inst = if (ty.isInt() or ty.isBool()) blk: {
        if (size_bits == 64) {
            break :blk Inst{ .str = .{
                .src = val_reg,
                .base = addr_reg.toReg(),
                .offset = 0,
                .size = .size64,
            } };
        } else if (size_bits == 32) {
            break :blk Inst{ .str = .{
                .src = val_reg,
                .base = addr_reg.toReg(),
                .offset = 0,
                .size = .size32,
            } };
        } else if (size_bits == 16) {
            break :blk Inst{ .strh = .{
                .src = val_reg,
                .base = addr_reg.toReg(),
                .offset = 0,
            } };
        } else if (size_bits == 8) {
            break :blk Inst{ .strb = .{
                .src = val_reg,
                .base = addr_reg.toReg(),
                .offset = 0,
            } };
        } else {
            return error.UnsupportedIntegerSize;
        }
    } else if (ty.isFloat()) blk: {
        if (size_bits == 64) {
            break :blk Inst{ .fp_store = .{
                .src = val_reg,
                .base = addr_reg.toReg(),
                .offset = 0,
                .size = .size64,
            } };
        } else if (size_bits == 32) {
            break :blk Inst{ .fp_store = .{
                .src = val_reg,
                .base = addr_reg.toReg(),
                .offset = 0,
                .size = .size32,
            } };
        } else {
            return error.UnsupportedFloatSize;
        }
    } else {
        return error.UnsupportedType;
    };

    try ctx.emit(store_inst);
}

/// Constructor: global_value - load address of global value.
/// Emits ADRP+ADD sequence for PC-relative global addressing.
pub fn aarch64_global_value(
    ctx: *IsleContext,
    gv: u32,
) !WritableReg {
    // Get global value data from function
    const gv_entity = entities.GlobalValue.new(gv);
    const gv_data = &ctx.lower_ctx.func.global_values.elems.items[gv_entity.toIndex()];

    const dst = ctx.allocOutputReg(.int);

    switch (gv_data.*) {
        .vmctx => {
            // VM context is passed in a register (typically x0 or similar)
            // For now, assume it's in a specific register
            // TODO: Get vmctx register from ABI
            try ctx.emit(Inst{
                .mov_rr = .{
                    .dst = dst,
                    .src = Reg.fromPReg(PReg.x0), // Placeholder - should come from ABI
                    .size = .size64,
                },
            });
        },
        .symbol => |sym_data| {
            // Load symbol address using ADRP + ADD
            const symbol_name = try ctx.lower_ctx.func.dfg.ext_funcs.getName(sym_data.name);

            try ctx.emit(Inst{
                .adrp_symbol = .{
                    .dst = dst,
                    .symbol = symbol_name,
                },
            });
            try ctx.emit(Inst{
                .add_symbol_lo12 = .{
                    .dst = dst,
                    .src = dst.toReg(),
                    .symbol = symbol_name,
                },
            });
        },
        .iadd_imm => |add_data| {
            // Load base global value, then add offset
            const base_reg = try aarch64_global_value(ctx, add_data.base.toRaw());
            const offset: i64 = add_data.offset.value;

            if (Imm12.fromI64(offset)) |imm| {
                try ctx.emit(Inst{
                    .add_imm = .{
                        .dst = dst,
                        .src = base_reg.toReg(),
                        .imm = imm,
                        .size = .size64,
                    },
                });
            } else {
                // Offset too large for immediate, materialize in register
                const offset_reg = ctx.allocInputReg(.int);
                try ctx.emit(Inst{
                    .mov_imm = .{
                        .dst = WritableReg.fromReg(offset_reg),
                        .imm = @bitCast(offset),
                        .size = .size64,
                    },
                });
                try ctx.emit(Inst{
                    .add_rr = .{
                        .dst = dst,
                        .src1 = base_reg.toReg(),
                        .src2 = offset_reg,
                        .size = .size64,
                    },
                });
            }
        },
        .load => |load_data| {
            // Load from base global value + offset
            const base_reg = try aarch64_global_value(ctx, load_data.base.toRaw());
            const offset: i32 = load_data.offset.value;

            try ctx.emit(Inst{
                .ldr = .{
                    .dst = dst,
                    .base = base_reg.toReg(),
                    .offset = offset,
                    .size = .size64,
                },
            });
        },
        .dyn_scale_target_const => {
            // Dynamic scale for scalable vectors
            // TODO: Implement proper scalable vector support
            @panic("TODO: Implement dyn_scale_target_const for scalable vectors");
        },
    }

    return dst;
}

/// Constructor: br_table - branch table (jump table dispatch).
/// Emits bounds check + jump table lookup + indirect branch.
pub fn aarch64_br_table(
    ctx: *IsleContext,
    index: Value,
    jt: entities.JumpTable,
    default_target: Block,
) !Inst {
    // Get the jump table from function data
    const jt_data = &ctx.lower_ctx.func.jump_tables.elems.items[jt.toIndex()];
    const table_size: u32 = @intCast(jt_data.len());

    // Get index register (should be i32 or i64)
    const index_reg = try ctx.lower_ctx.getValueReg(index, .int);

    // Allocate temporary registers
    const table_base = try ctx.lower_ctx.allocVReg(.int);
    const offset_reg = try ctx.lower_ctx.allocVReg(.int);
    const target_reg = try ctx.lower_ctx.allocVReg(.int);

    // 1. Bounds check: if (index >= table_size) goto default
    try ctx.emit(Inst{
        .cmp_imm = .{
            .src = index_reg,
            .imm = Imm12.fromU32(table_size) orelse {
                // If immediate too large, use register compare
                const size_reg = try ctx.lower_ctx.allocVReg(.int);
                try ctx.emit(Inst{
                    .mov_imm = .{
                        .dst = WritableReg.fromVReg(size_reg),
                        .imm = table_size,
                        .size = .size32,
                    },
                });
                try ctx.emit(Inst{
                    .cmp_rr = .{
                        .src1 = index_reg,
                        .src2 = Reg.fromVReg(size_reg),
                        .size = .size32,
                    },
                });
                return Inst{ .nop = {} }; // Early return after compare
            },
            .size = .size32,
        },
    });

    // Branch to default if index >= size (unsigned HS = higher or same)
    try ctx.emit(Inst{
        .b_cond = .{
            .cond = .hs, // Higher or Same (unsigned >=)
            .target = default_target,
        },
    });

    // 2. Compute byte offset: offset = index * 4 (for 32-bit PC-relative entries)
    try ctx.emit(Inst{
        .lsl_imm = .{
            .dst = WritableReg.fromVReg(offset_reg),
            .src = index_reg,
            .shift = 2, // Multiply by 4
            .size = .size32,
        },
    });

    // 3. Build target list for jt_sequence instruction
    // Extract blocks from jump table
    var targets = std.ArrayList(Block).init(ctx.lower_ctx.vcode.allocator);
    defer targets.deinit();
    for (jt_data.asSlice()) |block_call| {
        try targets.append(ctx.lower_ctx.vcode.allocator, block_call.block);
    }

    // 4. Emit jt_sequence: Load table address, load offset, compute target, branch
    return Inst{
        .jt_sequence = .{
            .index = Reg.fromVReg(offset_reg),
            .targets = try targets.toOwnedSlice(ctx.lower_ctx.vcode.allocator),
            .table_base = WritableReg.fromVReg(table_base),
            .target = WritableReg.fromVReg(target_reg),
        },
    };
}

/// Constructor: uadd_overflow_cin - unsigned add with carry-in and overflow.
/// Returns ValueRegs.two(result, overflow_out).
pub fn aarch64_uadd_overflow_cin(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    cin: Value,
) !lower_mod.ValueRegs {
    const a_reg = try ctx.lower_ctx.getValueReg(a, .int);
    const b_reg = try ctx.lower_ctx.getValueReg(b, .int);
    const cin_reg = try ctx.lower_ctx.getValueReg(cin, .int);
    const is_64 = ty.bits() == 64;

    const size: OperandSize = if (is_64) .size64 else .size32;

    // Set carry flag from carry-in value: CMP cin, #0 (sets carry if cin != 0)
    // Actually, we need: SUBS XZR, cin, #1 (sets carry if cin >= 1, i.e., cin == 1)
    try ctx.emit(Inst{
        .subs_imm = .{
            .dst = WritableReg.fromReg(Reg.gpr(31)), // XZR (discard result)
            .rn = cin_reg,
            .imm = 1,
            .size = size,
        },
    });

    // ADCS: Add with carry and set flags
    const dst = WritableReg.allocReg(.int, ctx.lower_ctx);
    try ctx.emit(Inst{ .adcs = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = size,
    } });

    // CSET: Extract carry flag as overflow
    const overflow_reg = WritableReg.allocReg(.int, ctx.lower_ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .hs, // HS = carry set (unsigned overflow)
        },
    });

    return lower_mod.ValueRegs.two(dst.toReg(), overflow_reg.toReg());
}

/// Constructor: sadd_overflow_cin - signed add with carry-in and overflow.
/// Returns ValueRegs.two(result, overflow_out).
pub fn aarch64_sadd_overflow_cin(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    cin: Value,
) !lower_mod.ValueRegs {
    const a_reg = try ctx.lower_ctx.getValueReg(a, .int);
    const b_reg = try ctx.lower_ctx.getValueReg(b, .int);
    const cin_reg = try ctx.lower_ctx.getValueReg(cin, .int);
    const is_64 = ty.bits() == 64;

    const size: OperandSize = if (is_64) .size64 else .size32;

    // Set carry flag from carry-in value: SUBS XZR, cin, #1
    try ctx.emit(Inst{
        .subs_imm = .{
            .dst = WritableReg.fromReg(Reg.gpr(31)), // XZR
            .rn = cin_reg,
            .imm = 1,
            .size = size,
        },
    });

    // ADCS: Add with carry and set flags
    const dst = WritableReg.allocReg(.int, ctx.lower_ctx);
    try ctx.emit(Inst{ .adcs = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = size,
    } });

    // CSET: Extract overflow flag (V flag for signed overflow)
    const overflow_reg = WritableReg.allocReg(.int, ctx.lower_ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .vs, // VS = overflow set (signed overflow)
        },
    });

    return lower_mod.ValueRegs.two(dst.toReg(), overflow_reg.toReg());
}

/// Constructor: usub_overflow_cin - unsigned subtract with carry-in and overflow detection.
/// Returns (result, overflow) where overflow is 1 if borrow occurred.
/// Uses SBCS for subtract with carry, CSET to extract borrow flag.
pub fn aarch64_usub_overflow_cin(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    cin: Value,
) !lower_mod.ValueRegs {
    const size = ctx.typeToSize(ty);
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const cin_reg = try ctx.getValueReg(cin, .int);
    const dst = ctx.allocOutputReg(.int);
    const overflow_reg = ctx.allocOutputReg(.int);

    // Set carry flag from carry-in (borrow): SUBS XZR, cin, #1
    // If cin=0 (borrow in), carry flag=0 (borrow propagates)
    // If cin=1 (no borrow), carry flag=1 (no borrow)
    try ctx.emit(Inst{
        .subs_imm = .{
            .dst = WritableReg.fromReg(Reg.gpr(31)), // XZR (discard result)
            .rn = cin_reg,
            .imm = 1,
            .size = size,
        },
    });

    // SBCS: Subtract with carry - dst = a - b - !carry
    try ctx.emit(Inst{ .sbcs = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = size,
    } });

    // CSET: Extract borrow flag (LO = borrow occurred)
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .lo, // LO = borrow (unsigned underflow)
        },
    });

    return lower_mod.ValueRegs.two(dst.toReg(), overflow_reg.toReg());
}

/// Constructor: uadd_overflow_trap - unsigned add with overflow trap.
/// Emits ADDS to set carry flag, B.CC to skip trap, UDF to trap on overflow.
pub fn aarch64_uadd_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: u32,
) !void {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    // ADDS dst, a, b (sets carry flag on unsigned overflow)
    try ctx.emit(.{ .adds_rr = .{
        .dst = dst,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } });

    // Allocate skip label
    const skip_label = ctx.lower_ctx.allocLabel();

    // B.CC skip (branch if no carry - no overflow)
    try ctx.emit(.{
        .b_cond = .{
            .cond = .lo, // LO = no carry (inverse of CS/HS)
            .target = .{ .label = skip_label },
        },
    });

    // UDF (trap on overflow)
    try ctx.emit(.{ .udf = .{
        .imm = @intCast(code),
    } });

    // Bind skip label
    ctx.lower_ctx.bindLabel(skip_label);
}

/// Constructor: usub_overflow_trap - unsigned subtract with overflow trap.
/// Emits SUBS to set carry flag, B.CS to skip trap, UDF to trap on borrow.
pub fn aarch64_usub_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: u32,
) !void {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    // SUBS dst, a, b (sets carry flag on unsigned underflow/borrow)
    try ctx.emit(.{ .subs_rr = .{
        .dst = dst,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } });

    // Allocate skip label
    const skip_label = ctx.lower_ctx.allocLabel();

    // B.CS skip (branch if carry set - no borrow)
    try ctx.emit(.{
        .b_cond = .{
            .cond = .hs, // HS = carry set (no borrow)
            .target = .{ .label = skip_label },
        },
    });

    // UDF (trap on underflow)
    try ctx.emit(.{ .udf = .{
        .imm = @intCast(code),
    } });

    // Bind skip label
    ctx.lower_ctx.bindLabel(skip_label);
}

/// Constructor: umul_overflow_trap - unsigned multiply with overflow trap.
/// Uses UMULH to get high bits, checks if non-zero for overflow.
pub fn aarch64_umul_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: u32,
) !void {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);
    const high = WritableReg.allocReg(.int, ctx.lower_ctx);

    // MUL dst, a, b (compute low bits)
    try ctx.emit(.{ .mul = .{
        .dst = dst,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } });

    // UMULH high, a, b (compute high bits)
    try ctx.emit(.{ .umulh = .{
        .dst = high,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } });

    // Allocate skip label
    const skip_label = ctx.lower_ctx.allocLabel();

    // CMP high, #0 (check if high bits are zero)
    try ctx.emit(.{ .cmp_imm = .{
        .rn = high.toReg(),
        .imm = 0,
        .size = size,
    } });

    // B.EQ skip (branch if high bits are zero - no overflow)
    try ctx.emit(.{
        .b_cond = .{
            .cond = .eq,
            .target = .{ .label = skip_label },
        },
    });

    // UDF (trap on overflow)
    try ctx.emit(.{ .udf = .{
        .imm = @intCast(code),
    } });

    // Bind skip label
    ctx.lower_ctx.bindLabel(skip_label);
}

/// Constructor: sadd_overflow_trap - signed add with overflow trap.
/// Emits ADDS to set overflow flag, B.VC to skip trap, UDF to trap on overflow.
pub fn aarch64_sadd_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: u32,
) !void {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    // ADDS dst, a, b (sets overflow flag on signed overflow)
    try ctx.emit(.{ .adds_rr = .{
        .dst = dst,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } });

    // Allocate skip label
    const skip_label = ctx.lower_ctx.allocLabel();

    // B.VC skip (branch if no overflow)
    try ctx.emit(.{
        .b_cond = .{
            .cond = .vc, // VC = no overflow
            .target = .{ .label = skip_label },
        },
    });

    // UDF (trap on overflow)
    try ctx.emit(.{ .udf = .{
        .imm = @intCast(code),
    } });

    // Bind skip label
    ctx.lower_ctx.bindLabel(skip_label);
}

/// Constructor: ssub_overflow_trap - signed subtract with overflow trap.
/// Emits SUBS to set overflow flag, B.VC to skip trap, UDF to trap on overflow.
pub fn aarch64_ssub_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: u32,
) !void {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    // SUBS dst, a, b (sets overflow flag on signed overflow)
    try ctx.emit(.{ .subs_rr = .{
        .dst = dst,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } });

    // Allocate skip label
    const skip_label = ctx.lower_ctx.allocLabel();

    // B.VC skip (branch if no overflow)
    try ctx.emit(.{
        .b_cond = .{
            .cond = .vc, // VC = no overflow
            .target = .{ .label = skip_label },
        },
    });

    // UDF (trap on overflow)
    try ctx.emit(.{ .udf = .{
        .imm = @intCast(code),
    } });

    // Bind skip label
    ctx.lower_ctx.bindLabel(skip_label);
}

/// Constructor: smul_overflow_trap - signed multiply with overflow trap.
/// Uses SMULH to get high bits, checks if they match sign extension of low bits.
pub fn aarch64_smul_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: u32,
) !void {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);
    const high = WritableReg.allocReg(.int, ctx.lower_ctx);
    const sign_ext = WritableReg.allocReg(.int, ctx.lower_ctx);

    // MUL dst, a, b (compute low bits)
    try ctx.emit(.{ .mul = .{
        .dst = dst,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } });

    // SMULH high, a, b (compute high bits)
    try ctx.emit(.{ .smulh = .{
        .dst = high,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } });

    // ASR sign_ext, dst, #63 or #31 (sign extend low bits to get expected high bits)
    const shift = if (size == .size64) 63 else 31;
    try ctx.emit(.{ .asr_imm = .{
        .dst = sign_ext,
        .src = dst.toReg(),
        .shift = shift,
        .size = size,
    } });

    // Allocate skip label
    const skip_label = ctx.lower_ctx.allocLabel();

    // CMP high, sign_ext (check if high bits match sign extension)
    try ctx.emit(.{ .cmp_rr = .{
        .rn = high.toReg(),
        .rm = sign_ext.toReg(),
        .size = size,
    } });

    // B.EQ skip (branch if they match - no overflow)
    try ctx.emit(.{
        .b_cond = .{
            .cond = .eq,
            .target = .{ .label = skip_label },
        },
    });

    // UDF (trap on overflow)
    try ctx.emit(.{ .udf = .{
        .imm = @intCast(code),
    } });

    // Bind skip label
    ctx.lower_ctx.bindLabel(skip_label);
}

/// Constructor: sqadd_8 - signed saturating add for I8.
pub fn aarch64_sqadd_8(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .sqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size8,
    } });
}

/// Constructor: sqadd_16 - signed saturating add for I16.
pub fn aarch64_sqadd_16(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .sqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size16,
    } });
}

/// Constructor: sqadd_32 - signed saturating add for I32.
pub fn aarch64_sqadd_32(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .sqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size32,
    } });
}

/// Constructor: sqadd_64 - signed saturating add for I64.
pub fn aarch64_sqadd_64(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .sqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size64,
    } });
}

/// Constructor: sqsub_8 - signed saturating subtract for I8.
pub fn aarch64_sqsub_8(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .sqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size8,
    } });
}

/// Constructor: sqsub_16 - signed saturating subtract for I16.
pub fn aarch64_sqsub_16(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .sqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size16,
    } });
}

/// Constructor: sqsub_32 - signed saturating subtract for I32.
pub fn aarch64_sqsub_32(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .sqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size32,
    } });
}

/// Constructor: sqsub_64 - signed saturating subtract for I64.
pub fn aarch64_sqsub_64(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .sqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size64,
    } });
}

/// Constructor: uqadd_8 - unsigned saturating add for I8.
pub fn aarch64_uqadd_8(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .uqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size8,
    } });
}

/// Constructor: uqadd_16 - unsigned saturating add for I16.
pub fn aarch64_uqadd_16(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .uqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size16,
    } });
}

/// Constructor: uqadd_32 - unsigned saturating add for I32.
pub fn aarch64_uqadd_32(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .uqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size32,
    } });
}

/// Constructor: uqadd_64 - unsigned saturating add for I64.
pub fn aarch64_uqadd_64(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .uqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size64,
    } });
}

/// Constructor: uqsub_8 - unsigned saturating subtract for I8.
pub fn aarch64_uqsub_8(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .uqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size8,
    } });
}

/// Constructor: uqsub_16 - unsigned saturating subtract for I16.
pub fn aarch64_uqsub_16(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .uqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size16,
    } });
}

/// Constructor: uqsub_32 - unsigned saturating subtract for I32.
pub fn aarch64_uqsub_32(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .uqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size32,
    } });
}

/// Constructor: uqsub_64 - unsigned saturating subtract for I64.
pub fn aarch64_uqsub_64(ctx: *IsleContext, a: Value, b: Value) !void {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .uqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size64,
    } });
}

/// Constructor: casal - compare-and-swap with acquire-release semantics.
/// Used for seq_cst atomic operations.
pub fn aarch64_casal(
    ctx: *IsleContext,
    addr: Value,
    expected: Value,
    new_val: Value,
) !void {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const expected_reg = try ctx.getValueReg(expected, .int);
    const new_val_reg = try ctx.getValueReg(new_val, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .casal = .{
        .compare = expected_reg,
        .swap = new_val_reg,
        .dst = dst,
        .base = addr_reg,
        .size = .size64,
    } });
}

/// Constructor: return_call - direct tail call.
/// Emits epilogue followed by direct branch instead of call+return.
pub fn aarch64_return_call(
    ctx: *IsleContext,
    sig_ref: u32,
    name: u32,
    args: []const Value,
) !Inst {
    _ = sig_ref;
    _ = args;

    // Tail call optimization: restore stack and branch (not call)
    // Arguments are already marshaled by caller

    // Get frame size from ABI context
    const frame_size: u32 = if (ctx.lower_ctx.abi) |abi|
        @intCast(abi.frame_size)
    else
        16; // Minimal frame for FP/LR

    // Restore FP/LR from stack (at top of frame)
    const fp_lr_offset: i32 = @intCast(frame_size - 16);
    try ctx.emit(Inst{
        .ldp = .{
            .dst1 = WritableReg.fromPReg(PReg.fp),
            .dst2 = WritableReg.fromPReg(PReg.lr),
            .base = Reg.fromPReg(PReg.sp),
            .offset = fp_lr_offset,
            .size = .size64,
        },
    });

    // Deallocate stack frame
    if (frame_size > 0) {
        if (Imm12.fromU32(frame_size)) |imm| {
            try ctx.emit(Inst{
                .add_imm = .{
                    .dst = WritableReg.fromPReg(PReg.sp),
                    .src = Reg.fromPReg(PReg.sp),
                    .imm = imm,
                    .size = .size64,
                },
            });
        } else {
            // Large frame: use immediate move + add
            const tmp = ctx.lower_ctx.allocVReg(.int);
            try ctx.emit(Inst{ .movz = .{
                .dst = WritableReg.fromVReg(tmp),
                .imm = @intCast(frame_size & 0xFFFF),
                .shift = 0,
                .size = .size64,
            }});
            if (frame_size > 0xFFFF) {
                try ctx.emit(Inst{ .movk = .{
                    .dst = WritableReg.fromVReg(tmp),
                    .imm = @intCast((frame_size >> 16) & 0xFFFF),
                    .shift = 16,
                    .size = .size64,
                }});
            }
            try ctx.emit(Inst{
                .add = .{
                    .dst = WritableReg.fromPReg(PReg.sp),
                    .src1 = Reg.fromPReg(PReg.sp),
                    .src2 = Reg.fromVReg(tmp),
                    .size = .size64,
                },
            });
        }
    }

    // Branch to target (not BL - this is a tail call)
    return Inst{ .b = .{ .target = .{ .label = name } } };
}

/// Constructor: return_call_indirect - indirect tail call.
/// Emits epilogue followed by indirect branch instead of call+return.
pub fn aarch64_return_call_indirect(
    ctx: *IsleContext,
    sig_ref: u32,
    ptr: Value,
    args: []const Value,
) !Inst {
    _ = sig_ref;
    _ = args;

    // Get function pointer
    const ptr_reg = try ctx.getValueReg(ptr, .int);

    // Get frame size from ABI context
    const frame_size: u32 = if (ctx.lower_ctx.abi) |abi|
        @intCast(abi.frame_size)
    else
        16;

    // Restore FP/LR from stack
    const fp_lr_offset: i32 = @intCast(frame_size - 16);
    try ctx.emit(Inst{
        .ldp = .{
            .dst1 = WritableReg.fromPReg(PReg.fp),
            .dst2 = WritableReg.fromPReg(PReg.lr),
            .base = Reg.fromPReg(PReg.sp),
            .offset = fp_lr_offset,
            .size = .size64,
        },
    });

    // Deallocate stack frame
    if (frame_size > 0) {
        if (Imm12.fromU32(frame_size)) |imm| {
            try ctx.emit(Inst{
                .add_imm = .{
                    .dst = WritableReg.fromPReg(PReg.sp),
                    .src = Reg.fromPReg(PReg.sp),
                    .imm = imm,
                    .size = .size64,
                },
            });
        } else {
            const tmp = ctx.lower_ctx.allocVReg(.int);
            try ctx.emit(Inst{ .movz = .{
                .dst = WritableReg.fromVReg(tmp),
                .imm = @intCast(frame_size & 0xFFFF),
                .shift = 0,
                .size = .size64,
            }});
            if (frame_size > 0xFFFF) {
                try ctx.emit(Inst{ .movk = .{
                    .dst = WritableReg.fromVReg(tmp),
                    .imm = @intCast((frame_size >> 16) & 0xFFFF),
                    .shift = 16,
                    .size = .size64,
                }});
            }
            try ctx.emit(Inst{
                .add = .{
                    .dst = WritableReg.fromPReg(PReg.sp),
                    .src1 = Reg.fromPReg(PReg.sp),
                    .src2 = Reg.fromVReg(tmp),
                    .size = .size64,
                },
            });
        }
    }

    // Branch to function pointer
    return Inst{ .br = .{ .target = ptr_reg } };
}

/// Constructor: ldadd - atomic add (LSE).
/// Constructor: ldadd - atomic add using LL/SC fallback.
/// Emits LDXR/ADD/STXR loop for atomicity.
pub fn aarch64_ldadd(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    // Allocate retry label
    const retry_label = ctx.lower_ctx.allocLabel();

    // Bind retry label
    ctx.lower_ctx.bindLabel(retry_label);

    // LDXR old, [addr]
    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // ADD new, old, val
    try ctx.emit(.{ .add_rr = .{
        .dst = WritableReg.fromReg(new),
        .src1 = old.toReg(),
        .src2 = val_reg,
        .size = .size64,
    } });

    // STXR status, new, [addr]
    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    // CBNZ status, retry
    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldclr - atomic clear using LL/SC fallback.
/// Emits LDXR/BIC/STXR loop. val is already inverted by caller.
pub fn aarch64_ldclr(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // BIC new, old, val (clear bits)
    try ctx.emit(.{ .bic_rr = .{
        .dst = WritableReg.fromReg(new),
        .src1 = old.toReg(),
        .src2 = val_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldset - atomic set using LL/SC fallback.
/// Emits LDXR/ORR/STXR loop.
pub fn aarch64_ldset(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .orr_rr = .{
        .dst = WritableReg.fromReg(new),
        .src1 = old.toReg(),
        .src2 = val_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldeor - atomic XOR using LL/SC fallback.
/// Emits LDXR/EOR/STXR loop.
pub fn aarch64_ldeor(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .eor_rr = .{
        .dst = WritableReg.fromReg(new),
        .src1 = old.toReg(),
        .src2 = val_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: swpal - atomic exchange using LL/SC fallback.
/// Emits LDXR/STXR loop with no operation (just exchange).
pub fn aarch64_swpal(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = val_reg,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldsmax - atomic signed max using LL/SC fallback.
/// Emits LDXR/CMP/CSEL/STXR loop.
pub fn aarch64_ldsmax(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // CMP old, val
    try ctx.emit(.{ .cmp_rr = .{
        .rn = old.toReg(),
        .rm = val_reg,
        .size = .size64,
    } });

    // CSEL new, old, val, GT (if old > val, keep old, else use val)
    try ctx.emit(.{ .csel = .{
        .dst = WritableReg.fromReg(new),
        .true_reg = old.toReg(),
        .false_reg = val_reg,
        .cond = .gt,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldsmin - atomic signed min using LL/SC fallback.
/// Emits LDXR/CMP/CSEL/STXR loop.
pub fn aarch64_ldsmin(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // CMP old, val
    try ctx.emit(.{ .cmp_rr = .{
        .rn = old.toReg(),
        .rm = val_reg,
        .size = .size64,
    } });

    // CSEL new, old, val, LT (if old < val, keep old, else use val)
    try ctx.emit(.{ .csel = .{
        .dst = WritableReg.fromReg(new),
        .true_reg = old.toReg(),
        .false_reg = val_reg,
        .cond = .lt,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldumax - atomic unsigned max using LL/SC fallback.
/// Emits LDXR/CMP/CSEL/STXR loop.
pub fn aarch64_ldumax(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // CMP old, val
    try ctx.emit(.{ .cmp_rr = .{
        .rn = old.toReg(),
        .rm = val_reg,
        .size = .size64,
    } });

    // CSEL new, old, val, HI (unsigned >)
    try ctx.emit(.{ .csel = .{
        .dst = WritableReg.fromReg(new),
        .true_reg = old.toReg(),
        .false_reg = val_reg,
        .cond = .hi,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldumin - atomic unsigned min using LL/SC fallback.
/// Emits LDXR/CMP/CSEL/STXR loop.
pub fn aarch64_ldumin(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // CMP old, val
    try ctx.emit(.{ .cmp_rr = .{
        .rn = old.toReg(),
        .rm = val_reg,
        .size = .size64,
    } });

    // CSEL new, old, val, LO (unsigned <)
    try ctx.emit(.{ .csel = .{
        .dst = WritableReg.fromReg(new),
        .true_reg = old.toReg(),
        .false_reg = val_reg,
        .cond = .lo,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: aarch64_istore8 - Store 8-bit value (STRB).
pub fn aarch64_istore8(
    ctx: *IsleContext,
    val: Value,
    addr: Value,
) !Inst {
    const val_reg = ctx.getValueReg(val);
    const addr_reg = ctx.getValueReg(addr);

    return Inst{ .strb = .{
        .src = val_reg,
        .base = addr_reg,
        .offset = 0,
    } };
}

/// Constructor: aarch64_istore16 - Store 16-bit value (STRH).
pub fn aarch64_istore16(
    ctx: *IsleContext,
    val: Value,
    addr: Value,
) !Inst {
    const val_reg = ctx.getValueReg(val);
    const addr_reg = ctx.getValueReg(addr);

    return Inst{ .strh = .{
        .src = val_reg,
        .base = addr_reg,
        .offset = 0,
    } };
}

/// Constructor: aarch64_istore32 - Store 32-bit value (STR Wd).
pub fn aarch64_istore32(
    ctx: *IsleContext,
    val: Value,
    addr: Value,
) !Inst {
    const val_reg = ctx.getValueReg(val);
    const addr_reg = ctx.getValueReg(addr);

    return Inst{ .str_w = .{
        .src = val_reg,
        .base = addr_reg,
        .offset = 0,
    } };
}

/// Constructor: aarch64_vstr - Store vector value (STR Qt/Dt).
pub fn aarch64_vstr(
    ctx: *IsleContext,
    val: Value,
    addr: Value,
) !Inst {
    const val_reg = ctx.getValueReg(val);
    const addr_reg = ctx.getValueReg(addr);

    return Inst{ .str_q = .{
        .src = val_reg,
        .base = addr_reg,
        .offset = 0,
    } };
}

/// Constructor: aarch64_snarrow - Signed saturating narrow (SQXTN).
/// Narrows wider elements to narrower with signed saturation.
pub fn aarch64_snarrow(
    ctx: *IsleContext,
    size: isle_helpers.VectorSize,
    src: Value,
) !Inst {
    const src_reg = ctx.getValueReg(src);
    const dst = try ctx.allocOutputReg(.float);

    // Map VectorSize to VecElemSize for output
    const elem_size: Inst.VecElemSize = switch (size) {
        .V8B => .size8x8, // 16x8b -> 8x8b
        .V16B => .size8x16, // 16x8b -> 8x16b (SQXTN2)
        .V4H => .size16x4, // 8x16b -> 4x16b
        .V8H => .size16x8, // 8x16b -> 8x16b (SQXTN2)
        .V2S => .size32x2, // 4x32b -> 2x32b
        .V4S => .size32x4, // 4x32b -> 4x32b (SQXTN2)
        .V2D => unreachable, // No 64->32 narrow with 2D output
    };

    const high = switch (size) {
        .V16B, .V8H, .V4S => true, // SQXTN2 (write high half)
        .V8B, .V4H, .V2S => false, // SQXTN (write low half)
        .V2D => unreachable,
    };

    return Inst{ .vec_sqxtn = .{
        .dst = dst,
        .src = src_reg,
        .size = elem_size,
        .high = high,
    } };
}

/// Constructor: aarch64_unarrow - Signed to unsigned saturating narrow (SQXTUN).
/// Narrows signed wider elements to unsigned narrower with saturation.
pub fn aarch64_unarrow(
    ctx: *IsleContext,
    size: isle_helpers.VectorSize,
    src: Value,
) !Inst {
    const src_reg = ctx.getValueReg(src);
    const dst = try ctx.allocOutputReg(.float);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V8B => .size8x8,
        .V16B => .size8x16,
        .V4H => .size16x4,
        .V8H => .size16x8,
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => unreachable,
    };

    const high = switch (size) {
        .V16B, .V8H, .V4S => true,
        .V8B, .V4H, .V2S => false,
        .V2D => unreachable,
    };

    return Inst{ .vec_sqxtun = .{
        .dst = dst,
        .src = src_reg,
        .size = elem_size,
        .high = high,
    } };
}

/// Constructor: aarch64_uunarrow - Unsigned saturating narrow (UQXTN).
/// Narrows unsigned wider elements to unsigned narrower with saturation.
pub fn aarch64_uunarrow(
    ctx: *IsleContext,
    size: isle_helpers.VectorSize,
    src: Value,
) !Inst {
    const src_reg = ctx.getValueReg(src);
    const dst = try ctx.allocOutputReg(.float);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V8B => .size8x8,
        .V16B => .size8x16,
        .V4H => .size16x4,
        .V8H => .size16x8,
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => unreachable,
    };

    const high = switch (size) {
        .V16B, .V8H, .V4S => true,
        .V8B, .V4H, .V2S => false,
        .V2D => unreachable,
    };

    return Inst{ .vec_uqxtn = .{
        .dst = dst,
        .src = src_reg,
        .size = elem_size,
        .high = high,
    } };
}

/// Constructor: aarch64_vldr - Load vector (LDR Qt/Dt).
pub fn aarch64_vldr(
    ctx: *IsleContext,
    ty: Type,
    addr: Value,
) !Inst {
    const addr_reg = ctx.getValueReg(addr);
    const dst = try ctx.allocOutputReg(.float);

    // Determine size from type
    const bits = ty.bits();
    if (bits == 128) {
        return Inst{ .ldr_q = .{
            .dst = dst,
            .base = addr_reg,
            .offset = 0,
        } };
    } else if (bits == 64) {
        return Inst{ .ldr_d = .{
            .dst = dst,
            .base = addr_reg,
            .offset = 0,
        } };
    } else if (bits == 32) {
        return Inst{ .ldr_s = .{
            .dst = dst,
            .base = addr_reg,
            .offset = 0,
        } };
    } else {
        return error.UnsupportedVectorSize;
    }
}

/// Constructor: aarch64_get_frame_pointer - Get frame pointer (X29/FP).
pub fn aarch64_get_frame_pointer(
    ctx: *IsleContext,
) !Inst {
    const dst = try ctx.allocOutputReg(.int);
    const fp = Reg.gpr(29); // X29 is the frame pointer

    return Inst{ .mov = .{
        .dst = dst,
        .src = fp,
    } };
}

/// Constructor: aarch64_get_stack_pointer - Get stack pointer (SP).
pub fn aarch64_get_stack_pointer(
    ctx: *IsleContext,
) !Inst {
    const dst = try ctx.allocOutputReg(.int);
    const sp = Reg.gpr(31); // X31/SP is the stack pointer

    return Inst{ .mov = .{
        .dst = dst,
        .src = sp,
    } };
}

/// Constructor: aarch64_get_return_address - Get return address (X30/LR).
pub fn aarch64_get_return_address(
    ctx: *IsleContext,
) !Inst {
    const dst = try ctx.allocOutputReg(.int);
    const lr = Reg.gpr(30); // X30 is the link register

    return Inst{ .mov = .{
        .dst = dst,
        .src = lr,
    } };
}

/// Constructor: aarch64_get_pinned_reg - Get platform pinned register.
/// X18 on Darwin (reserved by Apple), X28 elsewhere.
pub fn aarch64_get_pinned_reg(
    ctx: *IsleContext,
) !Inst {
    const dst = try ctx.allocOutputReg(.int);
    // TODO: Platform detection - for now use X28
    const pinned = Reg.gpr(28);

    return Inst{ .mov = .{
        .dst = dst,
        .src = pinned,
    } };
}

/// Constructor: aarch64_set_pinned_reg - Set platform pinned register.
pub fn aarch64_set_pinned_reg(
    ctx: *IsleContext,
    val: Value,
) !Inst {
    const val_reg = ctx.getValueReg(val);
    // TODO: Platform detection - for now use X28
    const pinned = Reg.gpr(28);

    return Inst{ .mov = .{
        .dst = WritableReg.fromReg(pinned),
        .src = val_reg,
    } };
}

/// Constructor: aarch64_landingpad - Read exception value from X0.
pub fn aarch64_landingpad(
    ctx: *IsleContext,
) !Inst {
    const dst = try ctx.allocOutputReg(.int);
    // Exception pointer in X0 per AAPCS64 ABI
    return Inst{ .mov = .{
        .dst = dst,
        .src = Reg.gpr(0),
    } };
}

/// Constructor: aarch64_debugtrap - Emit debug trap (BRK).
pub fn aarch64_debugtrap(
    ctx: *IsleContext,
) !Inst {
    _ = ctx;
    return Inst{ .brk = .{ .imm = 0 } };
}

/// Emit Spectre mitigation fence (ISB instruction).
/// ISB (Instruction Synchronization Barrier) prevents speculative execution
/// across security boundaries, mitigating Spectre-style attacks.
pub fn aarch64_spectre_fence(
    ctx: *IsleContext,
) !Inst {
    _ = ctx;
    return Inst{ .isb = {} };
}
