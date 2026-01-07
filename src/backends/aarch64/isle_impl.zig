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
    _ = gv;
    _ = ctx;
    @panic("TODO: Implement global_value - needs global value data structure");
}

/// Constructor: br_table - branch table (jump table dispatch).
/// Emits bounds check + jump table lookup + indirect branch.
pub fn aarch64_br_table(
    ctx: *IsleContext,
    index: Value,
    jt: u32,
    default_target: Block,
) !void {
    _ = index;
    _ = jt;
    _ = default_target;
    _ = ctx;
    @panic("TODO: Implement br_table - needs jump table data structure and constant pool");
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
) !void {
    _ = sig_ref;
    _ = name;
    _ = args;
    _ = ctx;
    @panic("TODO: Implement return_call - needs epilogue + B instruction");
}

/// Constructor: return_call_indirect - indirect tail call.
/// Emits epilogue followed by indirect branch instead of call+return.
pub fn aarch64_return_call_indirect(
    ctx: *IsleContext,
    sig_ref: u32,
    ptr: Value,
    args: []const Value,
) !void {
    _ = sig_ref;
    _ = ptr;
    _ = args;
    _ = ctx;
    @panic("TODO: Implement return_call_indirect - needs epilogue + BR instruction");
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
