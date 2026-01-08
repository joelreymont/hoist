const std = @import("std");
const testing = std.testing;

const reg_mod = @import("../../machinst/reg.zig");
const entities = @import("../../ir/entities.zig");
const machinst = @import("../../machinst/machinst.zig");

pub const Reg = reg_mod.Reg;
pub const PReg = reg_mod.PReg;
pub const VReg = reg_mod.VReg;
pub const WritableReg = reg_mod.WritableReg;

// ARM64 physical register constants
pub const fp = PReg.new(.int, 29); // X29 - Frame Pointer
pub const lr = PReg.new(.int, 30); // X30 - Link Register
pub const sp = PReg.new(.int, 31); // SP - Stack Pointer

/// ARM64 machine instruction.
/// Minimal bootstrap set - full aarch64 backend needs ~100+ variants.
pub const Inst = union(enum) {
    /// Move register to register (MOV Xd, Xn).
    mov_rr: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Move immediate to register (MOV Xd, #imm).
    mov_imm: struct {
        dst: WritableReg,
        imm: u64,
        size: OperandSize,
    },

    /// MOVZ - Move wide with zero
    movz: struct {
        dst: WritableReg,
        imm: u16, // 16-bit immediate
        shift: u8, // shift amount (0, 16, 32, or 48)
        size: OperandSize,
    },

    /// MOVK - Move wide with keep
    movk: struct {
        dst: WritableReg,
        imm: u16,
        shift: u8,
        size: OperandSize,
    },

    /// MOVN - Move wide with NOT
    movn: struct {
        dst: WritableReg,
        imm: u16,
        shift: u8,
        size: OperandSize,
    },

    /// Add register to register (ADD Xd, Xn, Xm).
    add_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Add immediate to register (ADD Xd, Xn, #imm).
    add_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u16, // 12-bit unsigned immediate
        size: OperandSize,
    },

    /// Add with shifted register (ADD Xd, Xn, Xm, shift #amt).
    /// Emits: dst = src1 + (src2 << amt)
    add_shifted: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        shift_op: ShiftOp,
        shift_amt: u6,
        size: OperandSize,
    },

    /// Add with extended register (ADD Xd, Xn, Wm, extend).
    /// Emits: dst = src1 + extend(src2)
    add_extended: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        extend: ExtendOp,
        size: OperandSize,
    },

    /// Subtract register from register (SUB Xd, Xn, Xm).
    sub_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Subtract immediate from register (SUB Xd, Xn, #imm).
    sub_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u16,
        size: OperandSize,
    },

    /// Subtract with shifted register (SUB Xd, Xn, Xm, shift #amount).
    sub_shifted: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        shift_op: ShiftOp,
        shift_amt: u6,
        size: OperandSize,
    },

    /// Subtract with extended register (SUB Xd, Xn, Wm, extend).
    sub_extended: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        extend: ExtendOp,
        size: OperandSize,
    },

    /// Add register to register with flags (ADDS Xd, Xn, Xm).
    /// Sets condition flags (NZCV).
    adds_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Add immediate to register with flags (ADDS Xd, Xn, #imm).
    /// Sets condition flags (NZCV).
    adds_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u16,
        size: OperandSize,
    },

    /// Add with carry and set flags (ADCS Xd, Xn, Xm).
    /// Adds two registers plus carry flag, sets condition flags.
    /// Used for multi-word arithmetic.
    adcs: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Subtract register from register with flags (SUBS Xd, Xn, Xm).
    /// Sets condition flags (NZCV).
    subs_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Subtract immediate from register with flags (SUBS Xd, Xn, #imm).
    /// Sets condition flags (NZCV).
    subs_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: Imm12,
        size: OperandSize,
    },

    /// Subtract with carry and set flags (SBCS Xd, Xn, Xm).
    /// Subtracts src2 and borrow from src1, sets condition flags.
    /// Used for multi-word subtraction.
    sbcs: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Signed saturating add (SQADD Xd, Xn, Xm).
    /// Saturates to signed min/max on overflow.
    sqadd: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Signed saturating subtract (SQSUB Xd, Xn, Xm).
    /// Saturates to signed min/max on overflow.
    sqsub: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Unsigned saturating add (UQADD Xd, Xn, Xm).
    /// Saturates to 0 or unsigned max on overflow.
    uqadd: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Unsigned saturating subtract (UQSUB Xd, Xn, Xm).
    /// Saturates to 0 on underflow.
    uqsub: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Multiply register (MUL Xd, Xn, Xm).
    /// Computes Xd = Xn * Xm (lower bits only).
    mul_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Multiply-add (MADD Xd, Xn, Xm, Xa).
    /// Computes Xd = Xa + (Xn * Xm).
    madd: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        addend: Reg,
        size: OperandSize,
    },

    /// Multiply-subtract (MSUB Xd, Xn, Xm, Xa).
    /// Computes Xd = Xa - (Xn * Xm).
    msub: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        minuend: Reg,
        size: OperandSize,
    },

    /// Signed multiply high (SMULH Xd, Xn, Xm).
    /// Computes Xd = (Xn * Xm)[127:64] (signed).
    smulh: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Unsigned multiply high (UMULH Xd, Xn, Xm).
    /// Computes Xd = (Xn * Xm)[127:64] (unsigned).
    umulh: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Conditional compare register (CCMP Xn, Xm, #nzcv, cond).
    /// If condition holds, compare Xn with Xm and set flags.
    /// If condition fails, set flags to nzcv immediate.
    ccmp: struct {
        src1: Reg,
        src2: Reg,
        nzcv: u4, // flags to set if condition false
        cond: CondCode,
        size: OperandSize,
    },

    /// Conditional compare immediate (CCMP Xn, #imm, #nzcv, cond).
    /// Like ccmp but second operand is 5-bit immediate.
    ccmp_imm: struct {
        src: Reg,
        imm: u5,
        nzcv: u4,
        cond: CondCode,
        size: OperandSize,
    },

    /// Signed multiply long (SMULL Xd, Wn, Wm).
    /// Computes Xd = sign_extend(Wn) * sign_extend(Wm).
    smull: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Unsigned multiply long (UMULL Xd, Wn, Wm).
    /// Computes Xd = zero_extend(Wn) * zero_extend(Wm).
    umull: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Signed divide (SDIV Xd, Xn, Xm).
    sdiv: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Unsigned divide (UDIV Xd, Xn, Xm).
    udiv: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Bitwise AND register-register (AND Xd, Xn, Xm).
    and_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Bitwise AND with immediate (AND Xd, Xn, #imm).
    and_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: ImmLogic,
    },

    /// Bitwise OR register-register (ORR Xd, Xn, Xm).
    orr_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Bitwise OR with immediate (ORR Xd, Xn, #imm).
    orr_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: ImmLogic,
    },

    /// Bitwise XOR register-register (EOR Xd, Xn, Xm).
    eor_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Bitwise XOR with immediate (EOR Xd, Xn, #imm).
    eor_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: ImmLogic,
    },

    /// Bitwise AND with shifted register (AND Xd, Xn, Xm, shift #amt).
    /// Emits: dst = src1 & (src2 << amt)
    and_shifted: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        shift_op: ShiftOp,
        shift_amt: u6,
        size: OperandSize,
    },

    /// Bitwise OR with shifted register (ORR Xd, Xn, Xm, shift #amt).
    /// Emits: dst = src1 | (src2 << amt)
    orr_shifted: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        shift_op: ShiftOp,
        shift_amt: u6,
        size: OperandSize,
    },

    /// Bitwise XOR with shifted register (EOR Xd, Xn, Xm, shift #amt).
    /// Emits: dst = src1 ^ (src2 << amt)
    eor_shifted: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        shift_op: ShiftOp,
        shift_amt: u6,
        size: OperandSize,
    },

    /// Bit clear (BIC Xd, Xn, Xm).
    /// Computes Xd = Xn & ~Xm.
    bic_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Bitwise OR NOT (ORN Xd, Xn, Xm).
    /// Computes Xd = Xn OR (NOT Xm).
    orn_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Bitwise XOR NOT (EON Xd, Xn, Xm).
    /// Computes Xd = Xn XOR (NOT Xm).
    eon_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Bitwise NOT (MVN Xd, Xm).
    mvn_rr: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Negate (NEG Xd, Xm).
    neg: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Logical shift left register-register (LSL Xd, Xn, Xm).
    lsl_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Logical shift left immediate (LSL Xd, Xn, #imm).
    lsl_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u8,
        size: OperandSize,
    },

    /// Logical shift right register-register (LSR Xd, Xn, Xm).
    lsr_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Logical shift right immediate (LSR Xd, Xn, #imm).
    lsr_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u8,
        size: OperandSize,
    },

    /// Arithmetic shift right register-register (ASR Xd, Xn, Xm).
    asr_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Arithmetic shift right immediate (ASR Xd, Xn, #imm).
    asr_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u8,
        size: OperandSize,
    },

    /// Rotate right register-register (ROR Xd, Xn, Xm).
    ror_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Rotate right immediate (ROR Xd, Xn, #imm).
    ror_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u8,
        size: OperandSize,
    },

    /// Compare register (CMP Xn, Xm).
    /// Sets flags based on Xn - Xm.
    cmp_rr: struct {
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Compare immediate (CMP Xn, #imm).
    cmp_imm: struct {
        src: Reg,
        imm: Imm12,
        size: OperandSize,
    },

    /// Compare negative register (CMN Xn, Xm).
    /// Sets flags based on Xn + Xm.
    cmn_rr: struct {
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Test bits register (TST Xn, Xm).
    /// Sets flags based on Xn & Xm.
    tst_rr: struct {
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Test bits immediate (TST Xn, #imm).
    tst_imm: struct {
        src: Reg,
        imm: ImmLogic,
    },

    /// Conditional select (CSEL Xd, Xn, Xm, cond).
    /// Xd = (cond) ? Xn : Xm
    csel: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        cond: CondCode,
        size: OperandSize,
    },

    /// Conditional set (CSET Xd, cond).
    /// Xd = (cond) ? 1 : 0
    cset: struct {
        dst: WritableReg,
        cond: CondCode,
        size: OperandSize,
    },

    /// Conditional increment (CINC Xd, Xn, cond).
    /// Xd = (cond) ? Xn + 1 : Xn
    cinc: struct {
        dst: WritableReg,
        src: Reg,
        cond: CondCode,
        size: OperandSize,
    },

    /// Count leading zeros (CLZ Xd, Xn).
    clz: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Count leading sign bits (CLS).
    cls: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Count trailing zeros (CTZ variant using RBIT + CLZ).
    /// Not a real ARM instruction - implemented as RBIT Xd, Xn; CLZ Xd, Xd.
    ctz: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Reverse bits (RBIT Xd, Xn).
    rbit: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Byte reverse 16-bit (REV16 Xd, Xn).
    rev16: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Byte reverse 32-bit (REV32 Xd, Xn or REV Wd, Wn).
    rev32: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Byte reverse 64-bit (REV Xd, Xn).
    rev64: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// Population count (CNT).
    popcnt: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Load register from memory with immediate offset (LDR Xt, [Xn, #offset]).
    ldr: struct {
        dst: WritableReg,
        base: Reg,
        offset: i16,
        size: OperandSize,
    },

    /// Load register from memory with register offset (LDR Xt, [Xn, Xm]).
    ldr_reg: struct {
        dst: WritableReg,
        base: Reg,
        offset: Reg,
        size: OperandSize,
    },

    /// Load register from memory with extended register offset (LDR Xt, [Xn, Wm, SXTW]).
    ldr_ext: struct {
        dst: WritableReg,
        base: Reg,
        offset: Reg,
        extend: ExtendOp,
        size: OperandSize,
    },

    /// Load register from memory with shifted register offset (LDR Xt, [Xn, Xm, LSL #3]).
    /// Note: Only LSL is supported for load/store addressing in ARM64.
    ldr_shifted: struct {
        dst: WritableReg,
        base: Reg,
        offset: Reg,
        shift_op: ShiftOp,
        shift_amt: u8, // Shift amount: 0-3 (log2 of access size for LSL)
        size: OperandSize,
    },

    /// Load register from PC-relative literal pool (LDR Xt, label).
    /// Used for loading constants from constant pool.
    ldr_literal: struct {
        dst: WritableReg,
        label: machinst.MachLabel,
        size: OperandSize,
    },

    /// Store register to memory with immediate offset (STR Xt, [Xn, #offset]).
    str: struct {
        src: Reg,
        base: Reg,
        offset: i16,
        size: OperandSize,
    },

    /// Store register to memory with register offset (STR Xt, [Xn, Xm]).
    str_reg: struct {
        src: Reg,
        base: Reg,
        offset: Reg,
        size: OperandSize,
    },

    /// Store register to memory with extended register offset (STR Xt, [Xn, Wm, SXTW]).
    str_ext: struct {
        src: Reg,
        base: Reg,
        offset: Reg,
        extend: ExtendOp,
        size: OperandSize,
    },

    /// Store register to memory with shifted register offset (STR Xt, [Xn, Xm, LSL #3]).
    /// Note: Only LSL is supported for load/store addressing in ARM64.
    str_shifted: struct {
        src: Reg,
        base: Reg,
        offset: Reg,
        shift_op: ShiftOp,
        shift_amt: u8, // Shift amount: 0-3 (log2 of access size for LSL)
        size: OperandSize,
    },

    /// Load byte (unsigned, zero-extend) (LDRB Wt, [Xn, #offset]).
    ldrb: struct {
        dst: WritableReg,
        base: Reg,
        offset: i16,
        size: OperandSize, // destination size (32 or 64)
    },

    /// Load halfword (unsigned, zero-extend) (LDRH Wt, [Xn, #offset]).
    ldrh: struct {
        dst: WritableReg,
        base: Reg,
        offset: i16,
        size: OperandSize, // destination size (32 or 64)
    },

    /// Load signed byte (LDRSB Wt/Xt, [Xn, #offset]).
    ldrsb: struct {
        dst: WritableReg,
        base: Reg,
        offset: i16,
        size: OperandSize, // destination size (32 or 64)
    },

    /// Load signed halfword (LDRSH Wt/Xt, [Xn, #offset]).
    ldrsh: struct {
        dst: WritableReg,
        base: Reg,
        offset: i16,
        size: OperandSize, // destination size (32 or 64)
    },

    /// Load signed word (LDRSW Xt, [Xn, #offset]).
    ldrsw: struct {
        dst: WritableReg,
        base: Reg,
        offset: i16,
    },

    /// Store byte (STRB Wt, [Xn, #offset]).
    strb: struct {
        src: Reg,
        base: Reg,
        offset: i16,
    },

    /// Store halfword (STRH Wt, [Xn, #offset]).
    strh: struct {
        src: Reg,
        base: Reg,
        offset: i16,
    },

    /// Store pair of registers (STP Xt1, Xt2, [Xn, #offset]).
    stp: struct {
        src1: Reg,
        src2: Reg,
        base: Reg,
        offset: i16,
        size: OperandSize,
    },

    /// Load pair of registers (LDP Xt1, Xt2, [Xn, #offset]).
    ldp: struct {
        dst1: WritableReg,
        dst2: WritableReg,
        base: Reg,
        offset: i16,
        size: OperandSize,
    },

    /// Load register with pre-index (LDR Xt, [Xn, #offset]!).
    /// Updates base register before memory access: base = base + offset, then load from base.
    ldr_pre: struct {
        dst: WritableReg,
        base: WritableReg,
        offset: i16,
        size: OperandSize,
    },

    /// Load register with post-index (LDR Xt, [Xn], #offset).
    /// Updates base register after memory access: load from base, then base = base + offset.
    ldr_post: struct {
        dst: WritableReg,
        base: WritableReg,
        offset: i16,
        size: OperandSize,
    },

    /// Store register with pre-index (STR Xt, [Xn, #offset]!).
    /// Updates base register before memory access: base = base + offset, then store to base.
    str_pre: struct {
        src: Reg,
        base: WritableReg,
        offset: i16,
        size: OperandSize,
    },

    /// Store register with post-index (STR Xt, [Xn], #offset).
    /// Updates base register after memory access: store to base, then base = base + offset.
    str_post: struct {
        src: Reg,
        base: WritableReg,
        offset: i16,
        size: OperandSize,
    },

    /// Load-acquire byte (LDARB Wt, [Xn]).
    ldarb: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// Load-acquire halfword (LDARH Wt, [Xn]).
    ldarh: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// Load-acquire word (LDAR Wt, [Xn]).
    ldar_w: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// Load-acquire register (LDAR Xt, [Xn]).
    ldar: struct {
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Store-release byte (STLRB Wt, [Xn]).
    stlrb: struct {
        src: Reg,
        base: Reg,
    },

    /// Store-release halfword (STLRH Wt, [Xn]).
    stlrh: struct {
        src: Reg,
        base: Reg,
    },

    /// Store-release word (STLR Wt, [Xn]).
    stlr_w: struct {
        src: Reg,
        base: Reg,
    },

    /// Store-release register (STLR Xt, [Xn]).
    stlr: struct {
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// Load-exclusive byte (LDXRB Wt, [Xn]).
    ldxrb: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// Load-exclusive halfword (LDXRH Wt, [Xn]).
    ldxrh: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// Load-exclusive word (LDXR Wt, [Xn]).
    ldxr_w: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// Load-exclusive register (LDXR Xt, [Xn]).
    ldxr: struct {
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Store-exclusive byte (STXRB Ws, Wt, [Xn]).
    stxrb: struct {
        status: WritableReg,
        src: Reg,
        base: Reg,
    },

    /// Store-exclusive halfword (STXRH Ws, Wt, [Xn]).
    stxrh: struct {
        status: WritableReg,
        src: Reg,
        base: Reg,
    },

    /// Store-exclusive word (STXR Ws, Wt, [Xn]).
    stxr_w: struct {
        status: WritableReg,
        src: Reg,
        base: Reg,
    },

    /// Store-exclusive register (STXR Ws, Xt, [Xn]).
    stxr: struct {
        status: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// Load-acquire exclusive byte (LDAXRB Wt, [Xn]).
    ldaxrb: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// Load-acquire exclusive halfword (LDAXRH Wt, [Xn]).
    ldaxrh: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// Load-acquire exclusive word (LDAXR Wt, [Xn]).
    ldaxr_w: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// Load-acquire exclusive register (LDAXR Xt, [Xn]).
    ldaxr: struct {
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Store-release exclusive byte (STLXRB Ws, Wt, [Xn]).
    stlxrb: struct {
        status: WritableReg,
        src: Reg,
        base: Reg,
    },

    /// Store-release exclusive halfword (STLXRH Ws, Wt, [Xn]).
    stlxrh: struct {
        status: WritableReg,
        src: Reg,
        base: Reg,
    },

    /// Store-release exclusive word (STLXR Ws, Wt, [Xn]).
    stlxr_w: struct {
        status: WritableReg,
        src: Reg,
        base: Reg,
    },

    /// Store-release exclusive register (STLXR Ws, Xt, [Xn]).
    stlxr: struct {
        status: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic add (LDADD).
    ldadd: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic add with acquire (LDADDA).
    ldadda: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic add with release (LDADDL).
    ldaddl: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic add with acquire-release (LDADDAL).
    ldaddal: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic clear bits (LDCLR).
    ldclr: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic exclusive OR (LDEOR).
    ldeor: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic OR (LDSET).
    ldset: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic signed maximum (LDSMAX).
    ldsmax: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic signed minimum (LDSMIN).
    ldsmin: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic unsigned maximum (LDUMAX).
    ldumax: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic unsigned minimum (LDUMIN).
    ldumin: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Atomic swap (SWP).
    swp: struct {
        src: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Compare and swap (CAS) - no ordering.
    cas: struct {
        compare: Reg,
        swap: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Compare and swap acquire (CASA).
    casa: struct {
        compare: Reg,
        swap: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Compare and swap release (CASL).
    casl: struct {
        compare: Reg,
        swap: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Compare and swap acquire+release (CASAL).
    casal: struct {
        compare: Reg,
        swap: Reg,
        dst: WritableReg,
        base: Reg,
        size: OperandSize,
    },

    /// Compare and swap pair (CASP) - 128-bit atomic.
    casp: struct {
        compare_lo: Reg, // Must be even register (e.g., X0, X2, X4...)
        compare_hi: Reg, // Must be odd register (compare_lo + 1)
        swap_lo: Reg, // Must be even register
        swap_hi: Reg, // Must be odd register (swap_lo + 1)
        dst_lo: WritableReg,
        dst_hi: WritableReg,
        base: Reg,
    },

    /// Data memory barrier (DMB).
    dmb: struct {
        option: BarrierOp,
    },

    /// Data synchronization barrier (DSB).
    dsb: struct {
        option: BarrierOp,
    },

    /// Instruction synchronization barrier (ISB).
    isb: void,

    /// Unconditional branch (B label).
    b: struct {
        target: BranchTarget,
    },

    /// Branch with link (BL label).
    bl: struct {
        target: CallTarget,
    },

    /// Branch to register (BR Xn).
    br: struct {
        target: Reg,
    },

    /// Branch with link to register (BLR Xn).
    blr: struct {
        target: Reg,
    },

    /// Return from subroutine (RET).
    ret: void,

    /// Conditional branch (B.cond label).
    b_cond: struct {
        cond: CondCode,
        target: BranchTarget,
    },

    /// Compare and branch if zero (CBZ Xt, label).
    cbz: struct {
        reg: Reg,
        target: BranchTarget,
        size: OperandSize,
    },

    /// Compare and branch if non-zero (CBNZ Xt, label).
    cbnz: struct {
        reg: Reg,
        target: BranchTarget,
        size: OperandSize,
    },

    /// Test bit and branch if zero (TBZ Xt, #bit, label).
    tbz: struct {
        reg: Reg,
        bit: u8,
        target: BranchTarget,
    },

    /// Test bit and branch if non-zero (TBNZ Xt, #bit, label).
    tbnz: struct {
        reg: Reg,
        bit: u8,
        target: BranchTarget,
    },

    /// Address of label (ADR Xd, label).
    /// Loads PC-relative address into register.
    adr: struct {
        dst: WritableReg,
        label: i32,
    },

    /// Address of label, page-aligned (ADRP Xd, label).
    adrp: struct {
        dst: WritableReg,
        label: i32,
    },

    /// Load page address of global symbol (ADRP Xd, symbol).
    /// Used for first half of global address materialization.
    adrp_symbol: struct {
        dst: WritableReg,
        symbol: []const u8,
    },

    /// Add low 12 bits of global offset (ADD Xd, Xn, :lo12:symbol).
    /// Used for second half of global address materialization.
    add_symbol_lo12: struct {
        dst: WritableReg,
        src: Reg,
        symbol: []const u8,
    },

    /// Load external name via GOT (Global Offset Table).
    /// Emits: ADRP + LDR sequence for PIC (position-independent code).
    /// This is a pseudo-instruction expanded during emission to:
    ///   adrp rd, :got:symbol
    ///   ldr  rd, [rd, :got_lo12:symbol]
    load_ext_name_got: struct {
        dst: WritableReg,
        symbol: []const u8,
    },

    /// Jump table sequence for br_table lowering.
    /// This is a pseudo-instruction that expands during emission to:
    ///   adr table_base, .LJTI<N>
    ///   ldr target, [table_base, index]  // index already shifted
    ///   add target, table_base, target   // PC-relative offset
    ///   br target
    /// The targets array must be heap-allocated and will be freed by the instruction.
    jt_sequence: struct {
        index: Reg, // Byte offset (index * 4)
        targets: []const entities.Block, // Array of target blocks
        table_base: WritableReg,
        target: WritableReg,
    },

    /// No operation (NOP).
    nop: void,

    /// Conditional speculation barrier (CSDB).
    /// Prevents speculative execution across branch misprediction.
    /// Used for Spectre mitigation after conditional branches.
    csdb: void,

    /// BTI - Branch Target Identification (ARMv8.5-A)
    /// Marks valid indirect branch/call targets for CFI
    bti: struct {
        target: BtiTarget,
    },

    /// PACIASP - Sign LR with SP as modifier (ARMv8.3-A PAC)
    /// Used in function prologue for return address protection
    paciasp: void,

    /// AUTIASP - Authenticate LR with SP as modifier (ARMv8.3-A PAC)
    /// Used before RET to verify return address integrity
    autiasp: void,

    /// Breakpoint (BRK #imm).
    brk: struct {
        imm: u16,
    },

    /// Undefined instruction (UDF #imm).
    /// Used for traps/debugging.
    udf: struct {
        imm: u16,
    },

    /// Fence - synchronization point for reordering.
    /// Maps to appropriate barrier (DMB, DSB, ISB) based on semantic.
    fence: void,

    /// Load effective address.
    /// Pseudo-instruction: computes address without loading.
    /// Typically becomes ADD or ADRP+ADD.
    lea: struct {
        dst: WritableReg,
        addr: Amode,
    },

    /// Virtual register spill to stack slot.
    /// Pseudo-instruction for register allocation.
    virtual_sp_offset_adj: struct {
        offset: i64,
    },

    /// Inline constant data (e.g. jump tables, float constants).
    data: struct {
        bytes: []const u8,
    },

    /// Unwind information marker.
    unwind: struct {
        inst: UnwindInst,
    },

    /// Floating-point move (FMOV).
    fmov: struct {
        dst: WritableReg,
        src: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point load immediate (FMOV Vd, #imm).
    fmov_imm: struct {
        dst: WritableReg,
        imm: f64,
        size: FpuOperandSize,
    },

    /// Move general register to vector register (FMOV Vd, Xn).
    fmov_from_gpr: struct {
        dst: WritableReg,
        src: Reg,
        size: FpuOperandSize,
    },

    /// Move vector register to general register (FMOV Xd, Vn).
    fmov_to_gpr: struct {
        dst: WritableReg,
        src: Reg,
        size: FpuOperandSize,
    },

    /// Load FP constant from constant pool (LDR Vd, =imm).
    /// During emission, adds constant to pool and emits LDR literal.
    fpload_const: struct {
        dst: WritableReg,
        bits: u64,
        size: FpuOperandSize,
    },

    /// Floating-point add (FADD).
    fadd: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point subtract (FSUB).
    fsub: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point multiply (FMUL).
    fmul: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point divide (FDIV).
    fdiv: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point fused multiply-add (FMADD).
    /// Computes dst = addend + (src1 * src2).
    fmadd: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        addend: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point fused multiply-subtract (FMSUB).
    /// Computes dst = addend - (src1 * src2).
    fmsub: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        addend: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point negate (FNEG).
    fneg: struct {
        dst: WritableReg,
        src: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point absolute value (FABS).
    fabs: struct {
        dst: WritableReg,
        src: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point square root (FSQRT).
    fsqrt: struct {
        dst: WritableReg,
        src: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point round to nearest (FRINTN).
    frintn: struct {
        dst: WritableReg,
        src: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point round toward zero (FRINTZ).
    frintz: struct {
        dst: WritableReg,
        src: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point round toward +infinity (FRINTP).
    frintp: struct {
        dst: WritableReg,
        src: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point round toward -infinity (FRINTM).
    frintm: struct {
        dst: WritableReg,
        src: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point minimum (FMIN).
    fmin: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point maximum (FMAX).
    fmax: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point compare (FCMP).
    fcmp: struct {
        src1: Reg,
        src2: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point compare with zero (FCMP Vn, #0.0).
    fcmp_zero: struct {
        src: Reg,
        size: FpuOperandSize,
    },

    /// Floating-point conditional select (FCSEL).
    fcsel: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        cond: CondCode,
        size: FpuOperandSize,
    },

    /// Convert signed integer to float (SCVTF).
    scvtf: struct {
        dst: WritableReg,
        src: Reg,
        src_size: OperandSize,
        dst_size: FpuOperandSize,
    },

    /// Convert unsigned integer to float (UCVTF).
    ucvtf: struct {
        dst: WritableReg,
        src: Reg,
        src_size: OperandSize,
        dst_size: FpuOperandSize,
    },

    /// Convert float to signed integer, round toward zero (FCVTZS).
    fcvtzs: struct {
        dst: WritableReg,
        src: Reg,
        src_size: FpuOperandSize,
        dst_size: OperandSize,
    },

    /// Convert float to unsigned integer, round toward zero (FCVTZU).
    fcvtzu: struct {
        dst: WritableReg,
        src: Reg,
        src_size: FpuOperandSize,
        dst_size: OperandSize,
    },

    /// Convert float32 to float64 (FCVT Dd, Sn).
    fcvt_f32_to_f64: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// Convert float64 to float32 (FCVT Sd, Dn).
    fcvt_f64_to_f32: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// Load FP/SIMD register (LDR Vt, [Xn, #offset]).
    vldr: struct {
        dst: WritableReg,
        base: Reg,
        offset: i16,
        size: FpuOperandSize,
    },

    /// Store FP/SIMD register (STR Vt, [Xn, #offset]).
    vstr: struct {
        src: Reg,
        base: Reg,
        offset: i16,
        size: FpuOperandSize,
    },

    /// Load FP/SIMD pair (LDP Vt1, Vt2, [Xn, #offset]).
    vldp: struct {
        dst1: WritableReg,
        dst2: WritableReg,
        base: Reg,
        offset: i16,
        size: FpuOperandSize,
    },

    /// Load single element and replicate to all lanes (LD1R {Vt.<T>}, [Xn]).
    /// Loads a single element from memory and replicates it across all vector lanes.
    ld1r: struct {
        dst: WritableReg,
        base: Reg,
        size: VecElemSize,
    },

    /// Store FP/SIMD pair (STP Vt1, Vt2, [Xn, #offset]).
    vstp: struct {
        src1: Reg,
        src2: Reg,
        base: Reg,
        offset: i16,
        size: FpuOperandSize,
    },

    /// Vector bitwise AND (AND Vd, Vn, Vm).
    /// Computes dst = src1 & src2 (element-wise bitwise AND).
    vec_and: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: FpuOperandSize,
    },

    /// Vector bitwise OR (ORR Vd, Vn, Vm).
    /// Computes dst = src1 | src2 (element-wise bitwise OR).
    vec_orr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: FpuOperandSize,
    },

    /// Vector bitwise XOR (EOR Vd, Vn, Vm).
    /// Computes dst = src1 ^ src2 (element-wise bitwise XOR).
    vec_eor: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: FpuOperandSize,
    },

    /// Vector addition (ADD Vd, Vn, Vm).
    /// Computes dst = src1 + src2 (element-wise addition).
    vec_add: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector subtraction (SUB Vd, Vn, Vm).
    /// Computes dst = src1 - src2 (element-wise subtraction).
    vec_sub: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector multiplication (MUL Vd, Vn, Vm).
    /// Computes dst = src1 * src2 (element-wise multiplication).
    vec_mul: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector signed dot product (SDOT Vd.4S, Vn.16B, Vm.16B).
    /// Computes 4-way dot product: dst[i] += src1[4*i:4*i+3] · src2[4*i:4*i+3]
    /// Requires FEAT_DotProd. Each lane: accumulate dot product of 4 bytes.
    vec_sdot: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Vector unsigned dot product (UDOT Vd.4S, Vn.16B, Vm.16B).
    /// Computes 4-way unsigned dot product: dst[i] += src1[4*i:4*i+3] · src2[4*i:4*i+3]
    /// Requires FEAT_DotProd. Each lane: accumulate dot product of 4 bytes.
    vec_udot: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Vector floating-point addition (FADD Vd, Vn, Vm).
    /// Computes dst = src1 + src2 (element-wise FP addition).
    vec_fadd: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector floating-point subtraction (FSUB Vd, Vn, Vm).
    /// Computes dst = src1 - src2 (element-wise FP subtraction).
    vec_fsub: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector floating-point multiplication (FMUL Vd, Vn, Vm).
    /// Computes dst = src1 * src2 (element-wise FP multiplication).
    vec_fmul: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector floating-point division (FDIV Vd, Vn, Vm).
    /// Computes dst = src1 / src2 (element-wise FP division).
    vec_fdiv: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector signed minimum (SMIN Vd, Vn, Vm).
    /// Computes dst = min(src1, src2) element-wise (signed).
    vec_smin: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector signed maximum (SMAX Vd, Vn, Vm).
    /// Computes dst = max(src1, src2) element-wise (signed).
    vec_smax: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector unsigned minimum (UMIN Vd, Vn, Vm).
    /// Computes dst = min(src1, src2) element-wise (unsigned).
    vec_umin: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector unsigned maximum (UMAX Vd, Vn, Vm).
    /// Computes dst = max(src1, src2) element-wise (unsigned).
    vec_umax: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector floating-point minimum (FMIN Vd, Vn, Vm).
    /// Computes dst = min(src1, src2) element-wise (FP).
    vec_fmin: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector floating-point maximum (FMAX Vd, Vn, Vm).
    /// Computes dst = max(src1, src2) element-wise (FP).
    vec_fmax: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Vector add across lanes (ADDV).
    /// Reduces vector to scalar by adding all lanes: dst = sum(src[i]).
    vec_addv: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize,
    },

    /// Vector signed minimum across lanes (SMINV).
    /// Reduces vector to scalar by finding minimum: dst = min(src[i]).
    vec_sminv: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize,
    },

    /// Vector signed maximum across lanes (SMAXV).
    /// Reduces vector to scalar by finding maximum: dst = max(src[i]).
    vec_smaxv: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize,
    },

    /// Vector unsigned minimum across lanes (UMINV).
    /// Reduces vector to scalar by finding minimum: dst = min(src[i]).
    vec_uminv: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize,
    },

    /// Vector unsigned maximum across lanes (UMAXV).
    /// Reduces vector to scalar by finding maximum: dst = max(src[i]).
    vec_umaxv: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize,
    },

    /// Duplicate scalar to all lanes (DUP).
    /// Copies scalar into all vector lanes: dst[i] = src for all i.
    vec_dup: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize,
    },

    /// Duplicate vector element to all lanes (DUP Vd.T, Vn.T[lane]).
    /// Broadcasts a single lane from source vector to all lanes of destination.
    vec_dup_lane: struct {
        dst: WritableReg,
        src: Reg,
        lane: u8,
        size: VecElemSize,
    },

    /// Extract vector element to scalar (UMOV).
    /// Copies vector lane to scalar: dst = src[lane].
    vec_extract_lane: struct {
        dst: WritableReg,
        src: Reg,
        lane: u8,
        size: VecElemSize,
    },

    /// Insert scalar into vector lane (INS).
    /// Copies scalar into vector lane: dst[lane] = src.
    vec_insert_lane: struct {
        dst: WritableReg,
        vec: Reg,
        src: Reg,
        lane: u8,
        size: VecElemSize,
    },

    /// Table lookup (TBL).
    /// Lookup bytes in table using indices: dst[i] = table[indices[i]].
    /// If index >= table size, result byte is 0.
    tbl: struct {
        dst: WritableReg,
        table: Reg,
        indices: Reg,
        table_regs: u2, // 1-4 table registers (TBL can use 1-4 consecutive regs)
    },

    /// Table lookup extension (TBX).
    /// Like TBL but preserves destination bytes when index out of range.
    tbx: struct {
        dst: WritableReg,
        table: Reg,
        indices: Reg,
        table_regs: u2, // 1-4 table registers
    },

    /// Extract bytes and concatenate (EXT).
    /// Extract bytes from concatenated pair: dst = (src1:src2)[index..index+bytes].
    vec_ext: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        index: u8,
        size: VecElemSize,
    },

    /// Pairwise add (ADDP).
    /// Add adjacent element pairs: dst[i] = src1[2*i] + src1[2*i+1].
    vec_addp: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Unsigned maximum pairwise (UMAXP).
    /// Pairwise max: dst[i] = max(src1[2*i], src1[2*i+1]).
    vec_umaxp: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// Compare equal to zero (CMEQ - zero variant).
    /// Element-wise compare: dst[i] = (src[i] == 0) ? -1 : 0.
    vec_cmeq0: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize,
    },

    /// Signed shift-left-long (SSHLL/SSHLL2).
    /// Widen and shift lower/upper half: dst[i] = sign_extend(src[i]) << shift_amt.
    /// For low variant: operates on src[0..n/2], for high: src[n/2..n].
    vec_sshll: struct {
        dst: WritableReg,
        src: Reg,
        shift_amt: u8,
        size: VecElemSize, // Output size (16x8, 32x4, or 64x2)
        high: bool, // false = SSHLL (low half), true = SSHLL2 (high half)
    },

    /// Unsigned shift-left-long (USHLL/USHLL2).
    /// Widen and shift lower/upper half: dst[i] = zero_extend(src[i]) << shift_amt.
    /// For low variant: operates on src[0..n/2], for high: src[n/2..n].
    vec_ushll: struct {
        dst: WritableReg,
        src: Reg,
        shift_amt: u8,
        size: VecElemSize, // Output size (16x8, 32x4, or 64x2)
        high: bool, // false = USHLL (low half), true = USHLL2 (high half)
    },

    /// Signed saturating extract narrow (SQXTN/SQXTN2).
    /// Narrow signed integers to half width with saturation.
    vec_sqxtn: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize, // Output size (8x8, 16x4, or 32x2 for SQXTN; 8x16, 16x8, or 32x4 for SQXTN2)
        high: bool, // false = SQXTN (write to low half), true = SQXTN2 (write to high half)
    },

    /// Signed saturating extract unsigned narrow (SQXTUN/SQXTUN2).
    /// Narrow signed integers to unsigned half width with saturation.
    vec_sqxtun: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize, // Output size (8x8, 16x4, or 32x2 for SQXTUN; 8x16, 16x8, or 32x4 for SQXTUN2)
        high: bool, // false = SQXTUN (write to low half), true = SQXTUN2 (write to high half)
    },

    /// Unsigned saturating extract narrow (UQXTN/UQXTN2).
    /// Narrow unsigned integers to half width with saturation.
    vec_uqxtn: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize, // Output size (8x8, 16x4, or 32x2 for UQXTN; 8x16, 16x8, or 32x4 for UQXTN2)
        high: bool, // false = UQXTN (write to low half), true = UQXTN2 (write to high half)
    },

    /// FCVTL/FCVTL2 - Float convert to higher precision long.
    /// Widens F32 elements to F64 (low or high half of input vector).
    vec_fcvtl: struct {
        dst: WritableReg,
        src: Reg,
        high: bool, // false = FCVTL (low half), true = FCVTL2 (high half)
    },

    /// FCVTN/FCVTN2 - Float convert to lower precision narrow.
    /// Narrows F64 elements to F32.
    vec_fcvtn: struct {
        dst: WritableReg,
        src: Reg,
        high: bool, // false = FCVTN (write to low half), true = FCVTN2 (write to high half)
    },

    /// ZIP1 - Interleave low halves of two vectors.
    zip1: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// ZIP2 - Interleave high halves of two vectors.
    zip2: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// UZP1 - De-interleave even lanes from two vectors.
    uzp1: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// UZP2 - De-interleave odd lanes from two vectors.
    uzp2: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// TRN1 - Transpose low halves (interleave alternating lanes).
    trn1: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// TRN2 - Transpose high halves (interleave alternating lanes).
    trn2: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VecElemSize,
    },

    /// REV16 - Reverse bytes within 16-bit halfwords (vector).
    vec_rev16: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize,
    },

    /// REV32 - Reverse bytes within 32-bit words (vector).
    vec_rev32: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize,
    },

    /// REV64 - Reverse bytes within 64-bit doublewords (vector).
    vec_rev64: struct {
        dst: WritableReg,
        src: Reg,
        size: VecElemSize,
    },

    /// FMLA/FMLS - Vector fused multiply-add/subtract (3-register form).
    /// rd = ri + rn * rm (FMLA) or rd = ri - rn * rm (FMLS)
    vec_rrr_mod: struct {
        op: VecALUModOp,
        dst: WritableReg,
        ri: Reg, // Addend register (also destination)
        rn: Reg, // First multiplicand
        rm: Reg, // Second multiplicand
        size: VectorSize,
    },

    /// VecRRR - Vector binary operation (3 registers).
    /// rd = op(rn, rm)
    vec_rrr: struct {
        op: VecALUOp,
        dst: WritableReg,
        rn: Reg,
        rm: Reg,
        size: VectorSize,
    },

    /// VecMisc - Vector unary operation (2 registers).
    /// rd = op(rn)
    vec_misc: struct {
        op: VecMisc2,
        dst: WritableReg,
        rn: Reg,
        size: VectorSize,
    },

    /// VecShiftImm - Vector shift by immediate
    /// rd = op(rn, imm)
    vec_shift_imm: struct {
        op: VecShiftImmOp,
        dst: WritableReg,
        rn: Reg,
        size: VecElemSize,
        imm: u8,
    },

    /// FMLA/FMLS - Vector fused multiply-add/subtract (element-indexed form).
    /// rd = ri + rn * rm[idx] (FMLA) or rd = ri - rn * rm[idx] (FMLS)
    vec_fmla_elem: struct {
        op: VecALUModOp,
        dst: WritableReg,
        ri: Reg, // Addend register (also destination)
        rn: Reg, // First multiplicand vector
        rm: Reg, // Second multiplicand vector (element indexed)
        size: VectorSize,
        idx: u8, // Element index in rm
    },

    /// Call - saves return address to link register and jumps.
    /// Pseudo-instruction that becomes BL.
    call: struct {
        target: CallTarget,
    },

    /// Indirect call through register.
    /// Pseudo-instruction that becomes BLR.
    call_indirect: struct {
        target: Reg,
    },

    /// Return from call.
    /// Pseudo-instruction that becomes RET.
    ret_call: void,

    /// Extend byte to word, signed (SXTB).
    sxtb: struct {
        dst: WritableReg,
        src: Reg,
        dst_size: OperandSize,
    },

    /// Extend byte to word, unsigned (UXTB).
    uxtb: struct {
        dst: WritableReg,
        src: Reg,
        dst_size: OperandSize,
    },

    /// Extend halfword to word, signed (SXTH).
    sxth: struct {
        dst: WritableReg,
        src: Reg,
        dst_size: OperandSize,
    },

    /// Extend halfword to word, unsigned (UXTH).
    uxth: struct {
        dst: WritableReg,
        src: Reg,
        dst_size: OperandSize,
    },

    /// Extend word to doubleword, signed (SXTW).
    sxtw: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// Extend word to doubleword, unsigned (UXTW).
    /// Note: In ARM64, 32-bit operations zero-extend automatically.
    uxtw: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// Zero-extend 8-bit value.
    /// Implemented as AND with 0xFF mask.
    zext8: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Zero-extend 16-bit value.
    /// Implemented as AND with 0xFFFF mask.
    zext16: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Zero-extend 32-bit value to 64-bit.
    /// Implemented as MOV Wd, Ws (32-bit MOV zeros upper 32 bits).
    zext32: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// MRS - Move from System Register (read system register).
    /// Reads a system register into a general-purpose register.
    /// Example: MRS X0, TPIDR_EL0
    mrs: struct {
        dst: WritableReg,
        sysreg: SystemReg,
    },

    /// MSR - Move to System Register (write system register).
    /// Writes a general-purpose register to a system register.
    /// Example: MSR TPIDR_EL0, X0
    msr: struct {
        sysreg: SystemReg,
        src: Reg,
    },

    /// Epilogue placeholder - updated by prologue/epilogue insertion.
    epilogue_placeholder: void,

    pub fn format(self: Inst, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .mov_rr => |i| try writer.print("mov.{} {}, {}", .{ i.size, i.dst, i.src }),
            .mov_imm => |i| try writer.print("mov.{} {}, #0x{x}", .{ i.size, i.dst, i.imm }),
            .movz => |i| try writer.print("movz.{} {}, #0x{x}, lsl #{d}", .{ i.size, i.dst, i.imm, i.shift }),
            .movk => |i| try writer.print("movk.{} {}, #0x{x}, lsl #{d}", .{ i.size, i.dst, i.imm, i.shift }),
            .movn => |i| try writer.print("movn.{} {}, #0x{x}, lsl #{d}", .{ i.size, i.dst, i.imm, i.shift }),
            .add_rr => |i| try writer.print("add.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .add_imm => |i| try writer.print("add.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .sub_rr => |i| try writer.print("sub.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .sub_imm => |i| try writer.print("sub.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .adds_rr => |i| try writer.print("adds.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .adds_imm => |i| try writer.print("adds.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .subs_rr => |i| try writer.print("subs.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .subs_imm => |i| try writer.print("subs.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .sqadd => |i| try writer.print("sqadd.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .sqsub => |i| try writer.print("sqsub.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .uqadd => |i| try writer.print("uqadd.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .uqsub => |i| try writer.print("uqsub.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .mul_rr => |i| try writer.print("mul.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .madd => |i| try writer.print("madd.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.addend }),
            .msub => |i| try writer.print("msub.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.minuend }),
            .smulh => |i| try writer.print("smulh {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .umulh => |i| try writer.print("umulh {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .ccmp => |i| try writer.print("ccmp.{} {}, {}, #{d}, {}", .{ i.size, i.src1, i.src2, i.nzcv, i.cond }),
            .ccmp_imm => |i| try writer.print("ccmp.{} {}, #{d}, #{d}, {}", .{ i.size, i.src, i.imm, i.nzcv, i.cond }),
            .smull => |i| try writer.print("smull {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .umull => |i| try writer.print("umull {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .sdiv => |i| try writer.print("sdiv.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .udiv => |i| try writer.print("udiv.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .and_rr => |i| try writer.print("and.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .and_imm => |i| try writer.print("and.{} {}, {}, #0x{x}", .{ i.imm.size, i.dst, i.src, i.imm.value }),
            .orr_rr => |i| try writer.print("orr.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .orr_imm => |i| try writer.print("orr.{} {}, {}, #0x{x}", .{ i.imm.size, i.dst, i.src, i.imm.value }),
            .eor_rr => |i| try writer.print("eor.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .eor_imm => |i| try writer.print("eor.{} {}, {}, #0x{x}", .{ i.imm.size, i.dst, i.src, i.imm.value }),
            .bic_rr => |i| try writer.print("bic.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .orn_rr => |i| try writer.print("orn.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .eon_rr => |i| try writer.print("eon.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .mvn_rr => |i| try writer.print("mvn.{} {}, {}", .{ i.size, i.dst, i.src }),
            .lsl_rr => |i| try writer.print("lsl.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .lsl_imm => |i| try writer.print("lsl.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .lsr_rr => |i| try writer.print("lsr.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .lsr_imm => |i| try writer.print("lsr.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .asr_rr => |i| try writer.print("asr.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .asr_imm => |i| try writer.print("asr.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .ror_rr => |i| try writer.print("ror.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .ror_imm => |i| try writer.print("ror.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .cmp_rr => |i| try writer.print("cmp.{} {}, {}", .{ i.size, i.src1, i.src2 }),
            .cmp_imm => |i| try writer.print("cmp {}, #{d}", .{ i.src, i.imm.toU64() }),
            .cmn_rr => |i| try writer.print("cmn.{} {}, {}", .{ i.size, i.src1, i.src2 }),
            .tst_rr => |i| try writer.print("tst.{} {}, {}", .{ i.size, i.src1, i.src2 }),
            .tst_imm => |i| try writer.print("tst.{} {}, #0x{x}", .{ i.imm.size, i.src, i.imm.value }),
            .ldr => |i| try writer.print("ldr.{} {}, [{}, #{d}]", .{ i.size, i.dst, i.base, i.offset }),
            .ldr_reg => |i| try writer.print("ldr.{} {}, [{}, {}]", .{ i.size, i.dst, i.base, i.offset }),
            .ldr_ext => |i| try writer.print("ldr.{} {}, [{}, {}, {}]", .{ i.size, i.dst, i.base, i.offset, i.extend }),
            .ldr_shifted => |i| try writer.print("ldr.{} {}, [{}, {}, {} #{d}]", .{ i.size, i.dst, i.base, i.offset, i.shift_op, i.shift_amt }),
            .ldr_literal => |i| try writer.print("ldr.{} {}, label{}", .{ i.size, i.dst, i.label.index }),
            .str => |i| try writer.print("str.{} {}, [{}, #{d}]", .{ i.size, i.src, i.base, i.offset }),
            .str_reg => |i| try writer.print("str.{} {}, [{}, {}]", .{ i.size, i.src, i.base, i.offset }),
            .str_ext => |i| try writer.print("str.{} {}, [{}, {}, {}]", .{ i.size, i.src, i.base, i.offset, i.extend }),
            .str_shifted => |i| try writer.print("str.{} {}, [{}, {}, {} #{d}]", .{ i.size, i.src, i.base, i.offset, i.shift_op, i.shift_amt }),
            .ldrb => |i| try writer.print("ldrb.{} {}, [{}, #{d}]", .{ i.size, i.dst, i.base, i.offset }),
            .ldrh => |i| try writer.print("ldrh.{} {}, [{}, #{d}]", .{ i.size, i.dst, i.base, i.offset }),
            .ldrsb => |i| try writer.print("ldrsb.{} {}, [{}, #{d}]", .{ i.size, i.dst, i.base, i.offset }),
            .ldrsh => |i| try writer.print("ldrsh.{} {}, [{}, #{d}]", .{ i.size, i.dst, i.base, i.offset }),
            .ldrsw => |i| try writer.print("ldrsw {}, [{}, #{d}]", .{ i.dst, i.base, i.offset }),
            .strb => |i| try writer.print("strb {}, [{}, #{d}]", .{ i.src, i.base, i.offset }),
            .strh => |i| try writer.print("strh {}, [{}, #{d}]", .{ i.src, i.base, i.offset }),
            .stp => |i| try writer.print("stp.{} {}, {}, [{}, #{d}]", .{ i.size, i.src1, i.src2, i.base, i.offset }),
            .ldp => |i| try writer.print("ldp.{} {}, {}, [{}, #{d}]", .{ i.size, i.dst1, i.dst2, i.base, i.offset }),
            .ldr_pre => |i| try writer.print("ldr.{} {}, [{}, #{d}]!", .{ i.size, i.dst, i.base, i.offset }),
            .ldr_post => |i| try writer.print("ldr.{} {}, [{}], #{d}", .{ i.size, i.dst, i.base, i.offset }),
            .str_pre => |i| try writer.print("str.{} {}, [{}, #{d}]!", .{ i.size, i.src, i.base, i.offset }),
            .str_post => |i| try writer.print("str.{} {}, [{}], #{d}", .{ i.size, i.src, i.base, i.offset }),
            .ldarb => |i| try writer.print("ldarb {}, [{}]", .{ i.dst, i.base }),
            .ldarh => |i| try writer.print("ldarh {}, [{}]", .{ i.dst, i.base }),
            .ldar_w => |i| try writer.print("ldar {}, [{}]", .{ i.dst, i.base }),
            .ldar => |i| try writer.print("ldar.{} {}, [{}]", .{ i.size, i.dst, i.base }),
            .stlrb => |i| try writer.print("stlrb {}, [{}]", .{ i.src, i.base }),
            .stlrh => |i| try writer.print("stlrh {}, [{}]", .{ i.src, i.base }),
            .stlr_w => |i| try writer.print("stlr {}, [{}]", .{ i.src, i.base }),
            .stlr => |i| try writer.print("stlr.{} {}, [{}]", .{ i.size, i.src, i.base }),
            .ldxrb => |i| try writer.print("ldxrb {}, [{}]", .{ i.dst, i.base }),
            .ldxrh => |i| try writer.print("ldxrh {}, [{}]", .{ i.dst, i.base }),
            .ldxr_w => |i| try writer.print("ldxr {}, [{}]", .{ i.dst, i.base }),
            .ldxr => |i| try writer.print("ldxr.{} {}, [{}]", .{ i.size, i.dst, i.base }),
            .stxrb => |i| try writer.print("stxrb {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stxrh => |i| try writer.print("stxrh {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stxr_w => |i| try writer.print("stxr {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stxr => |i| try writer.print("stxr.{} {}, {}, [{}]", .{ i.size, i.status, i.src, i.base }),
            .ldaxrb => |i| try writer.print("ldaxrb {}, [{}]", .{ i.dst, i.base }),
            .ldaxrh => |i| try writer.print("ldaxrh {}, [{}]", .{ i.dst, i.base }),
            .ldaxr_w => |i| try writer.print("ldaxr {}, [{}]", .{ i.dst, i.base }),
            .ldaxr => |i| try writer.print("ldaxr.{} {}, [{}]", .{ i.size, i.dst, i.base }),
            .stlxrb => |i| try writer.print("stlxrb {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stlxrh => |i| try writer.print("stlxrh {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stlxr_w => |i| try writer.print("stlxr {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stlxr => |i| try writer.print("stlxr.{} {}, {}, [{}]", .{ i.size, i.status, i.src, i.base }),
            .ldadd => |i| try writer.print("ldadd.{} {}, {}, [{}]", .{ i.size, i.src, i.dst, i.base }),
            .ldclr => |i| try writer.print("ldclr.{} {}, {}, [{}]", .{ i.size, i.src, i.dst, i.base }),
            .ldeor => |i| try writer.print("ldeor.{} {}, {}, [{}]", .{ i.size, i.src, i.dst, i.base }),
            .ldset => |i| try writer.print("ldset.{} {}, {}, [{}]", .{ i.size, i.src, i.dst, i.base }),
            .ldsmax => |i| try writer.print("ldsmax.{} {}, {}, [{}]", .{ i.size, i.src, i.dst, i.base }),
            .ldsmin => |i| try writer.print("ldsmin.{} {}, {}, [{}]", .{ i.size, i.src, i.dst, i.base }),
            .ldumax => |i| try writer.print("ldumax.{} {}, {}, [{}]", .{ i.size, i.src, i.dst, i.base }),
            .ldumin => |i| try writer.print("ldumin.{} {}, {}, [{}]", .{ i.size, i.src, i.dst, i.base }),
            .swp => |i| try writer.print("swp.{} {}, {}, [{}]", .{ i.size, i.src, i.dst, i.base }),
            .cas => |i| try writer.print("cas.{} {}, {}, {}, [{}]", .{ i.size, i.compare, i.swap, i.dst, i.base }),
            .casa => |i| try writer.print("casa.{} {}, {}, {}, [{}]", .{ i.size, i.compare, i.swap, i.dst, i.base }),
            .casl => |i| try writer.print("casl.{} {}, {}, {}, [{}]", .{ i.size, i.compare, i.swap, i.dst, i.base }),
            .casal => |i| try writer.print("casal.{} {}, {}, {}, [{}]", .{ i.size, i.compare, i.swap, i.dst, i.base }),
            .casp => |i| try writer.print("casp {}, {}, {}, {}, [{}]", .{ i.compare_lo, i.compare_hi, i.swap_lo, i.swap_hi, i.base }),
            .dmb => |i| try writer.print("dmb {}", .{i.option}),
            .dsb => |i| try writer.print("dsb {}", .{i.option}),
            .isb => try writer.print("isb", .{}),
            .b => |i| try writer.print("b {}", .{i.target}),
            .bl => |i| try writer.print("bl {}", .{i.target}),
            .br => |i| try writer.print("br {}", .{i.target}),
            .blr => |i| try writer.print("blr {}", .{i.target}),
            .ret => try writer.print("ret", .{}),
            .b_cond => |i| try writer.print("b.{} {}", .{ i.cond, i.target }),
            .cbz => |i| try writer.print("cbz.{} {}, {}", .{ i.size, i.reg, i.target }),
            .cbnz => |i| try writer.print("cbnz.{} {}, {}", .{ i.size, i.reg, i.target }),
            .tbz => |i| try writer.print("tbz {}, #{}, {}", .{ i.reg, i.bit, i.target }),
            .tbnz => |i| try writer.print("tbnz {}, #{}, {}", .{ i.reg, i.bit, i.target }),
            .tbz => |i| try writer.print("tbz {}, #{d}, {}", .{ i.reg, i.bit, i.target }),
            .tbnz => |i| try writer.print("tbnz {}, #{d}, {}", .{ i.reg, i.bit, i.target }),
            .adr => |i| try writer.print("adr {}, label{d}", .{ i.dst, i.label }),
            .adrp => |i| try writer.print("adrp {}, label{d}", .{ i.dst, i.label }),
            .nop => try writer.print("nop", .{}),
            .brk => |i| try writer.print("brk #{d}", .{i.imm}),
            .udf => |i| try writer.print("udf #{d}", .{i.imm}),
            .fence => try writer.print("fence", .{}),
            .lea => |i| try writer.print("lea {}, {}", .{ i.dst, i.addr }),
            .virtual_sp_offset_adj => |i| try writer.print("virtual_sp_offset_adj #{d}", .{i.offset}),
            .data => |i| try writer.print("data [{}]", .{i.bytes.len}),
            .unwind => |i| try writer.print("unwind {}", .{i.inst}),
            .csel => |i| try writer.print("csel.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.cond }),
            .cset => |i| try writer.print("cset.{} {}, {}", .{ i.size, i.dst, i.cond }),
            .cinc => |i| try writer.print("cinc.{} {}, {}, {}", .{ i.size, i.dst, i.src, i.cond }),
            .clz => |i| try writer.print("clz.{} {}, {}", .{ i.size, i.dst, i.src }),
            .cls => |i| try writer.print("cls.{} {}, {}", .{ i.size, i.dst, i.src }),
            .ctz => |i| try writer.print("ctz.{} {}, {}", .{ i.size, i.dst, i.src }),
            .rbit => |i| try writer.print("rbit.{} {}, {}", .{ i.size, i.dst, i.src }),
            .rev16 => |i| try writer.print("rev16.{} {}, {}", .{ i.size, i.dst, i.src }),
            .rev32 => |i| try writer.print("rev32.{} {}, {}", .{ i.size, i.dst, i.src }),
            .rev64 => |i| try writer.print("rev64 {}, {}", .{ i.dst, i.src }),
            .popcnt => |i| try writer.print("popcnt.{} {}, {}", .{ i.size, i.dst, i.src }),
            .fmov => |i| try writer.print("fmov.{} {}, {}", .{ i.size, i.dst, i.src }),
            .fmov_imm => |i| try writer.print("fmov.{} {}, #{}", .{ i.size, i.dst, i.imm }),
            .fmov_from_gpr => |i| try writer.print("fmov.{} {}, {}", .{ i.size, i.dst, i.src }),
            .fmov_to_gpr => |i| try writer.print("fmov.{} {}, {}", .{ i.size, i.dst, i.src }),
            .fpload_const => |i| try writer.print("ldr.{} {}, =0x{x}", .{ i.size, i.dst, i.bits }),
            .fadd => |i| try writer.print("fadd.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .fsub => |i| try writer.print("fsub.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .fmul => |i| try writer.print("fmul.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .fdiv => |i| try writer.print("fdiv.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .fmadd => |i| try writer.print("fmadd.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.addend }),
            .fmsub => |i| try writer.print("fmsub.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.addend }),
            .fneg => |i| try writer.print("fneg.{} {}, {}", .{ i.size, i.dst, i.src }),
            .fabs => |i| try writer.print("fabs.{} {}, {}", .{ i.size, i.dst, i.src }),
            .fsqrt => |i| try writer.print("fsqrt.{} {}, {}", .{ i.size, i.dst, i.src }),
            .frintn => |i| try writer.print("frintn.{} {}, {}", .{ i.size, i.dst, i.src }),
            .frintz => |i| try writer.print("frintz.{} {}, {}", .{ i.size, i.dst, i.src }),
            .frintp => |i| try writer.print("frintp.{} {}, {}", .{ i.size, i.dst, i.src }),
            .frintm => |i| try writer.print("frintm.{} {}, {}", .{ i.size, i.dst, i.src }),
            .fmin => |i| try writer.print("fmin.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .fmax => |i| try writer.print("fmax.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .fcmp => |i| try writer.print("fcmp.{} {}, {}", .{ i.size, i.src1, i.src2 }),
            .fcmp_zero => |i| try writer.print("fcmp.{} {}, #0.0", .{ i.size, i.src }),
            .fcsel => |i| try writer.print("fcsel.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.cond }),
            .scvtf => |i| try writer.print("scvtf.{}.{} {}, {}", .{ i.src_size, i.dst_size, i.dst, i.src }),
            .ucvtf => |i| try writer.print("ucvtf.{}.{} {}, {}", .{ i.src_size, i.dst_size, i.dst, i.src }),
            .fcvtzs => |i| try writer.print("fcvtzs.{}.{} {}, {}", .{ i.src_size, i.dst_size, i.dst, i.src }),
            .fcvtzu => |i| try writer.print("fcvtzu.{}.{} {}, {}", .{ i.src_size, i.dst_size, i.dst, i.src }),
            .fcvt_f32_to_f64 => |i| try writer.print("fcvt.f32.f64 {}, {}", .{ i.dst, i.src }),
            .fcvt_f64_to_f32 => |i| try writer.print("fcvt.f64.f32 {}, {}", .{ i.dst, i.src }),
            .vldr => |i| try writer.print("vldr.{} {}, [{}, #{d}]", .{ i.size, i.dst, i.base, i.offset }),
            .vstr => |i| try writer.print("vstr.{} {}, [{}, #{d}]", .{ i.size, i.src, i.base, i.offset }),
            .vldp => |i| try writer.print("vldp.{} {}, {}, [{}, #{d}]", .{ i.size, i.dst1, i.dst2, i.base, i.offset }),
            .vstp => |i| try writer.print("vstp.{} {}, {}, [{}, #{d}]", .{ i.size, i.src1, i.src2, i.base, i.offset }),
            .ld1r => |i| try writer.print("ld1r.{} {}, [{}]", .{ i.size, i.dst, i.base }),
            .load_ext_name_got => |i| try writer.print("load_ext_name_got {}, {s}", .{ i.dst, i.symbol }),
            .jt_sequence => |i| try writer.print("jt_sequence {}, {} targets", .{ i.index, i.targets.len }),
            .vec_and => |i| try writer.print("vec_and.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_orr => |i| try writer.print("vec_orr.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_eor => |i| try writer.print("vec_eor.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_add => |i| try writer.print("vec_add.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_sub => |i| try writer.print("vec_sub.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_mul => |i| try writer.print("vec_mul.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_sdot => |i| try writer.print("vec_sdot.4s {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .vec_udot => |i| try writer.print("vec_udot.4s {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .vec_smin => |i| try writer.print("vec_smin.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_smax => |i| try writer.print("vec_smax.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_umin => |i| try writer.print("vec_umin.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_umax => |i| try writer.print("vec_umax.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_fmin => |i| try writer.print("vec_fmin.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_fmax => |i| try writer.print("vec_fmax.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_addv => |i| try writer.print("vec_addv.{} {}, {}", .{ i.size, i.dst, i.src }),
            .vec_sminv => |i| try writer.print("vec_sminv.{} {}, {}", .{ i.size, i.dst, i.src }),
            .vec_smaxv => |i| try writer.print("vec_smaxv.{} {}, {}", .{ i.size, i.dst, i.src }),
            .vec_uminv => |i| try writer.print("vec_uminv.{} {}, {}", .{ i.size, i.dst, i.src }),
            .vec_umaxv => |i| try writer.print("vec_umaxv.{} {}, {}", .{ i.size, i.dst, i.src }),
            .vec_dup => |i| try writer.print("vec_dup.{} {}, {}", .{ i.size, i.dst, i.src }),
            .vec_extract_lane => |i| try writer.print("vec_extract_lane.{} {}, {}[{}]", .{ i.size, i.dst, i.src, i.lane }),
            .vec_insert_lane => |i| try writer.print("vec_insert_lane.{} {}[{}], {}", .{ i.size, i.dst, i.lane, i.src }),
            .tbl => |i| try writer.print("tbl {}, {{{}}}, {}", .{ i.dst, i.table, i.indices }),
            .tbx => |i| try writer.print("tbx {}, {{{}}}, {}", .{ i.dst, i.table, i.indices }),
            .vec_ext => |i| try writer.print("vec_ext.{} {}, {}, {}, #{}", .{ i.size, i.dst, i.src1, i.src2, i.index }),
            .vec_addp => |i| try writer.print("vec_addp.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_umaxp => |i| try writer.print("vec_umaxp.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_cmeq0 => |i| try writer.print("vec_cmeq0.{} {}, {}", .{ i.size, i.dst, i.src }),
            .vec_sshll => |i| try writer.print("vec_sshll{s}.{} {}, {}, #{}", .{ if (i.high) "2" else "", i.size, i.dst, i.src, i.shift_amt }),
            .vec_ushll => |i| try writer.print("vec_ushll{s}.{} {}, {}, #{}", .{ if (i.high) "2" else "", i.size, i.dst, i.src, i.shift_amt }),
            .vec_sqxtn => |i| try writer.print("vec_sqxtn{s}.{} {}, {}", .{ if (i.high) "2" else "", i.size, i.dst, i.src }),
            .vec_sqxtun => |i| try writer.print("vec_sqxtun{s}.{} {}, {}", .{ if (i.high) "2" else "", i.size, i.dst, i.src }),
            .vec_uqxtn => |i| try writer.print("vec_uqxtn{s}.{} {}, {}", .{ if (i.high) "2" else "", i.size, i.dst, i.src }),
            .vec_fcvtl => |i| try writer.print("vec_fcvtl{s} {}, {}", .{ if (i.high) "2" else "", i.dst, i.src }),
            .vec_fcvtn => |i| try writer.print("vec_fcvtn{s} {}, {}", .{ if (i.high) "2" else "", i.dst, i.src }),
            .call => |i| try writer.print("call {}", .{i.target}),
            .call_indirect => |i| try writer.print("call {}", .{i.target}),
            .ret_call => try writer.print("ret", .{}),
            .sxtb => |i| try writer.print("sxtb.{} {}, {}", .{ i.dst_size, i.dst, i.src }),
            .uxtb => |i| try writer.print("uxtb.{} {}, {}", .{ i.dst_size, i.dst, i.src }),
            .sxth => |i| try writer.print("sxth.{} {}, {}", .{ i.dst_size, i.dst, i.src }),
            .uxth => |i| try writer.print("uxth.{} {}, {}", .{ i.dst_size, i.dst, i.src }),
            .sxtw => |i| try writer.print("sxtw {}, {}", .{ i.dst, i.src }),
            .uxtw => |i| try writer.print("uxtw {}, {}", .{ i.dst, i.src }),
            .zext8 => |i| try writer.print("zext8.{} {}, {}", .{ i.size, i.dst, i.src }),
            .zext16 => |i| try writer.print("zext16.{} {}, {}", .{ i.size, i.dst, i.src }),
            .zext32 => |i| try writer.print("zext32 {}, {}", .{ i.dst, i.src }),
            .mrs => |i| try writer.print("mrs {}, {}", .{ i.dst, i.sysreg }),
            .msr => |i| try writer.print("msr {}, {}", .{ i.sysreg, i.src }),
            .epilogue_placeholder => try writer.print("epilogue_placeholder", .{}),
        }
    }

    /// Collect operands for register allocation.
    /// Called by regalloc to understand register use/def constraints.
    pub fn getOperands(self: *Inst, collector: *OperandCollector) !void {
        switch (self.*) {
            .mov_imm => |*i| {
                try collector.regDef(i.dst);
            },
            .mov_rr => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .add_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .mul_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .add_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .sub_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .sub_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .and_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .and_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .orr_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .orr_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .eor_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .eor_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .lsl_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .lsl_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .lsr_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .lsr_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .asr_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .asr_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .cmp_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
            },
            .cmp_imm => |*i| {
                try collector.regUse(i.src);
            },
            .ccmp => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
            },
            .ccmp_imm => |*i| {
                try collector.regUse(i.src);
            },
            .add_shifted => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .sub_shifted => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .and_shifted => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .orr_shifted => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .eor_shifted => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .bic_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .mvn_rr => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .ror_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .ror_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fadd => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .fsub => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .fmul => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .fdiv => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .fmov => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fcmp => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
            },
            .vec_add => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_sub => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_mul => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_sdot => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_udot => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .ld1r => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .load_ext_name_got => |*i| {
                try collector.regDef(i.dst);
            },
            .jt_sequence => |*i| {
                try collector.regUse(i.index);
                try collector.regDef(i.table_base);
                try collector.regDef(i.target);
            },
            .vec_and => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_orr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_eor => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_fadd => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_fsub => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_fmul => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_fdiv => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_smin => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_smax => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_umin => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_umax => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_fmin => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_fmax => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_dup => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_dup_lane => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_extract_lane => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_insert_lane => |*i| {
                try collector.regUse(i.vec);
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .tbl => |*i| {
                try collector.regUse(i.table);
                try collector.regUse(i.indices);
                try collector.regDef(i.dst);
            },
            .tbx => |*i| {
                try collector.regUse(i.table);
                try collector.regUse(i.indices);
                try collector.regDef(i.dst);
            },
            .ldr => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldr_ext => |*i| {
                try collector.regUse(i.base);
                try collector.regUse(i.offset);
                try collector.regDef(i.dst);
            },
            .ldr_shifted => |*i| {
                try collector.regUse(i.base);
                try collector.regUse(i.offset);
                try collector.regDef(i.dst);
            },
            .ldr_literal => |*i| {
                try collector.regDef(i.dst);
            },
            .str => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .str_ext => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regUse(i.offset);
            },
            .str_shifted => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regUse(i.offset);
            },
            .ldrb => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldrh => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldrsb => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldrsh => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldrsw => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .strb => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .strh => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .stp => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regUse(i.base);
            },
            .ldp => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst1);
                try collector.regDef(i.dst2);
            },
            .ldr_pre => |*i| {
                try collector.regUse(i.base.toReg());
                try collector.regDef(i.dst);
                try collector.regDef(i.base); // base is modified
            },
            .ldr_post => |*i| {
                try collector.regUse(i.base.toReg());
                try collector.regDef(i.dst);
                try collector.regDef(i.base); // base is modified
            },
            .str_pre => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base.toReg());
                try collector.regDef(i.base); // base is modified
            },
            .str_post => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base.toReg());
                try collector.regDef(i.base); // base is modified
            },
            .ldarb => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldarh => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldar_w => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldar => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .stlrb => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .stlrh => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .stlr_w => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .stlr => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .ldxrb => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldxrh => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldxr_w => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldxr => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .stxrb => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.status);
            },
            .stxrh => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.status);
            },
            .stxr_w => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.status);
            },
            .stxr => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.status);
            },
            .ldaxrb => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldaxrh => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldaxr_w => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldaxr => |*i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .stlxrb => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.status);
            },
            .stlxrh => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.status);
            },
            .stlxr_w => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.status);
            },
            .stlxr => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.status);
            },
            .ldadd => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldclr => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldeor => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldset => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldsmax => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldsmin => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldumax => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .ldumin => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .swp => |*i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .cas => |*i| {
                try collector.regUse(i.compare);
                try collector.regUse(i.swap);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .casa => |*i| {
                try collector.regUse(i.compare);
                try collector.regUse(i.swap);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .casl => |*i| {
                try collector.regUse(i.compare);
                try collector.regUse(i.swap);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .casal => |*i| {
                try collector.regUse(i.compare);
                try collector.regUse(i.swap);
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .casp => |*i| {
                try collector.regUse(i.compare_lo);
                try collector.regUse(i.compare_hi);
                try collector.regUse(i.swap_lo);
                try collector.regUse(i.swap_hi);
                try collector.regUse(i.base);
                try collector.regDef(i.dst_lo);
                try collector.regDef(i.dst_hi);
            },
            .madd => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regUse(i.addend);
                try collector.regDef(i.dst);
            },
            .msub => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regUse(i.minuend);
                try collector.regDef(i.dst);
            },
            .smull => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .umull => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .sdiv => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .udiv => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .clz => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .rbit => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .rev16 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .rev32 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .rev64 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .csel => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .movz => |*i| {
                try collector.regDef(i.dst);
            },
            .movk => |*i| {
                try collector.regUse(i.dst.toReg());
                try collector.regDef(i.dst);
            },
            .movn => |*i| {
                try collector.regDef(i.dst);
            },
            .cbz => |*i| {
                try collector.regUse(i.reg);
            },
            .cbnz => |*i| {
                try collector.regUse(i.reg);
            },
            .tbz => |*i| {
                try collector.regUse(i.reg);
            },
            .tbnz => |*i| {
                try collector.regUse(i.reg);
            },
            .br => |*i| {
                try collector.regUse(i.target);
            },
            .bl => {
                // Call clobbers caller-saved registers per AAPCS64:
                // - X0-X18 (integer caller-saved)
                // - V0-V7, V16-V31 (FP/SIMD caller-saved)
                // Mark them as defs so register allocator knows they're clobbered

                // Integer caller-saved: X0-X18
                var i: u6 = 0;
                while (i <= 18) : (i += 1) {
                    const preg = PReg.new(.int, i);
                    try collector.regDef(WritableReg.fromReg(Reg.fromPReg(preg)));
                }

                // FP caller-saved: V0-V7
                i = 0;
                while (i <= 7) : (i += 1) {
                    const preg = PReg.new(.float, i);
                    try collector.regDef(WritableReg.fromReg(Reg.fromPReg(preg)));
                }

                // FP caller-saved: V16-V31
                i = 16;
                while (i <= 31) : (i += 1) {
                    const preg = PReg.new(.float, i);
                    try collector.regDef(WritableReg.fromReg(Reg.fromPReg(preg)));
                }
            },
            .blr => |*i| {
                try collector.regUse(i.target);

                // Call clobbers caller-saved registers per AAPCS64
                // Same as bl - mark all caller-saved registers as clobbered

                // Integer caller-saved: X0-X18
                var reg_i: u6 = 0;
                while (reg_i <= 18) : (reg_i += 1) {
                    const preg = PReg.new(.int, reg_i);
                    try collector.regDef(WritableReg.fromReg(Reg.fromPReg(preg)));
                }

                // FP caller-saved: V0-V7
                reg_i = 0;
                while (reg_i <= 7) : (reg_i += 1) {
                    const preg = PReg.new(.float, reg_i);
                    try collector.regDef(WritableReg.fromReg(Reg.fromPReg(preg)));
                }

                // FP caller-saved: V16-V31
                reg_i = 16;
                while (reg_i <= 31) : (reg_i += 1) {
                    const preg = PReg.new(.float, reg_i);
                    try collector.regDef(WritableReg.fromReg(Reg.fromPReg(preg)));
                }
            },
            .sxtb => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .sxth => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .sxtw => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .uxtb => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .uxth => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fneg => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fabs => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fsqrt => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .scvtf => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .ucvtf => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fcvtzs => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fcvtzu => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fcvt_f32_to_f64 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fcvt_f64_to_f32 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .adds_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .adds_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .adcs => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .subs_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .subs_imm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .sbcs => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .sqadd => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .sqsub => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .uqadd => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .uqsub => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .smulh => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .umulh => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .orn_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .tst_imm => |*i| {
                try collector.regUse(i.src);
            },
            .tst_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
            },
            .eon_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .cinc => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .cset => |*i| {
                try collector.regDef(i.dst);
            },
            .fmax => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .fmin => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .fcsel => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .fmov_imm => |*i| {
                try collector.regDef(i.dst);
            },
            .fmov_from_gpr => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fmov_to_gpr => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .fpload_const => |*i| {
                try collector.regDef(i.dst);
            },
            .frintm => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .frintn => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .frintp => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .frintz => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .adr => |*i| {
                try collector.regDef(i.dst);
            },
            .adrp => |*i| {
                try collector.regDef(i.dst);
            },
            .call_indirect => |*i| {
                try collector.regUse(i.target);
            },
            .fmadd => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regUse(i.addend);
                try collector.regDef(i.dst);
            },
            .fmsub => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regUse(i.addend);
                try collector.regDef(i.dst);
            },
            .fcmp_zero => |*i| {
                try collector.regUse(i.src);
            },
            .adrp_symbol => |*i| {
                try collector.regDef(i.dst);
            },
            .cmn_rr => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
            },
            .cls => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .ctz => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .neg => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .uxtw => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .popcnt => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .lea => |*i| {
                // Address mode may contain base/index registers
                // For now, conservatively mark dst as def only
                // TODO: Extract registers from Amode
                try collector.regDef(i.dst);
            },
            .mrs => |*i| {
                try collector.regDef(i.dst);
            },
            .msr => |*i| {
                try collector.regUse(i.src);
            },
            .vec_ext => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_addp => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_umaxp => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_cmeq0 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_sshll => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_ushll => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_sqxtn => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_sqxtun => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_uqxtn => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_fcvtl => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_fcvtn => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .zip1 => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .zip2 => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .uzp1 => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .uzp2 => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .trn1 => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .trn2 => |*i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .vec_rev16 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_rev32 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_rev64 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .vec_rrr_mod => |*i| {
                try collector.regUse(i.ri);
                try collector.regUse(i.rn);
                try collector.regUse(i.rm);
                try collector.regDef(i.dst);
            },
            .vec_rrr => |*i| {
                try collector.regUse(i.rn);
                try collector.regUse(i.rm);
                try collector.regDef(i.dst);
            },
            .vec_misc => |*i| {
                try collector.regUse(i.rn);
                try collector.regDef(i.dst);
            },
            .vec_shift_imm => |*i| {
                try collector.regUse(i.rn);
                try collector.regDef(i.dst);
            },
            .vec_fmla_elem => |*i| {
                try collector.regUse(i.ri);
                try collector.regUse(i.rn);
                try collector.regUse(i.rm);
                try collector.regDef(i.dst);
            },
            .zext32 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .add_symbol_lo12 => |*i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .ret => {
                // No operands to collect (implicit use of X30/LR handled by ABI)
            },
            .ret_call => {
                // No operands to collect (implicit use of X30/LR handled by ABI)
            },
            .call, .b, .b_cond, .nop, .dmb, .dsb, .fence, .epilogue_placeholder, .data, .brk, .udf, .bti, .csdb, .isb, .autiasp, .paciasp => {
                // No register operands (labels/immediates/special only)
            },
            else => {
                // TODO: Implement for all instruction variants
                // For now, emit no operands for unimplemented instructions
            },
        }
    }

    /// Is this instruction a register-to-register move?
    pub fn isMove(self: Inst) bool {
        return switch (self) {
            .mov_rr => true,
            else => false,
        };
    }

    /// Is this instruction a terminator?
    pub fn isTerm(self: Inst) bool {
        return switch (self) {
            .ret, .br, .br_cond, .br_table => true,
            else => false,
        };
    }

    /// Generate a register-to-register move instruction.
    pub fn genMove(dst: WritableReg, src: Reg, ty: @import("../../ir/types.zig").Type) Inst {
        return .{ .mov_rr = .{
            .dst = dst,
            .src = src,
            .size = if (ty.bits() == 64) .size64 else .size32,
        } };
    }

    /// Get defined (output) registers for this instruction.
    /// Returns a list of virtual registers written by this instruction.
    pub fn getDefs(self: *Inst, allocator: std.mem.Allocator) ![]VReg {
        var collector = OperandCollector.init(allocator);
        defer collector.deinit();

        try self.getOperands(&collector);

        // Convert WritableReg to VReg, filtering out physical registers
        var vregs = std.ArrayList(VReg).init(allocator);
        defer vregs.deinit();

        for (collector.defs.items) |writable_reg| {
            if (writable_reg.toReg().toVReg()) |vreg| {
                try vregs.append(vreg);
            }
        }

        return try vregs.toOwnedSlice();
    }

    /// Get used (input) registers for this instruction.
    /// Returns a list of virtual registers read by this instruction.
    pub fn getUses(self: *Inst, allocator: std.mem.Allocator) ![]VReg {
        var collector = OperandCollector.init(allocator);
        defer collector.deinit();

        try self.getOperands(&collector);

        // Convert Reg to VReg, filtering out physical registers
        var vregs = std.ArrayList(VReg).init(allocator);
        defer vregs.deinit();

        for (collector.uses.items) |reg| {
            if (reg.toVReg()) |vreg| {
                try vregs.append(vreg);
            }
        }

        return try vregs.toOwnedSlice();
    }
};

/// Operand size for integer operations.
pub const OperandSize = enum {
    size32,
    size64,

    pub fn bits(self: OperandSize) u32 {
        return switch (self) {
            .size32 => 32,
            .size64 => 64,
        };
    }

    pub fn bytes(self: OperandSize) u32 {
        return switch (self) {
            .size32 => 4,
            .size64 => 8,
        };
    }

    pub fn format(self: OperandSize, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .size32 => try writer.print("w", .{}),
            .size64 => try writer.print("x", .{}),
        }
    }
};

/// Operand size for FPU/SIMD operations.
pub const FpuOperandSize = enum {
    size32,
    size64,
    size128,

    pub fn bits(self: FpuOperandSize) u32 {
        return switch (self) {
            .size32 => 32,
            .size64 => 64,
            .size128 => 128,
        };
    }

    pub fn bytes(self: FpuOperandSize) u32 {
        return switch (self) {
            .size32 => 4,
            .size64 => 8,
            .size128 => 16,
        };
    }

    pub fn format(self: FpuOperandSize, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .size32 => try writer.print("s", .{}),
            .size64 => try writer.print("d", .{}),
            .size128 => try writer.print("q", .{}),
        }
    }
};

/// Vector element size for SIMD operations.
pub const VecElemSize = enum {
    size8x8,
    size8x16,
    size16x4,
    size16x8,
    size32x2,
    size32x4,
    size64x2,

    pub fn bits(self: VecElemSize) u32 {
        return switch (self) {
            .size8x8 => 64,
            .size8x16 => 128,
            .size16x4 => 64,
            .size16x8 => 128,
            .size32x2 => 64,
            .size32x4 => 128,
            .size64x2 => 128,
        };
    }

    pub fn elemBits(self: VecElemSize) u32 {
        return switch (self) {
            .size8x8, .size8x16 => 8,
            .size16x4, .size16x8 => 16,
            .size32x2, .size32x4 => 32,
            .size64x2 => 64,
        };
    }

    /// Returns log2 of element size in bits (for encoding)
    pub fn elemSizeLog2(self: VecElemSize) u32 {
        return switch (self) {
            .size8x8, .size8x16 => 0, // 8-bit = 2^0 bytes
            .size16x4, .size16x8 => 1, // 16-bit = 2^1 bytes
            .size32x2, .size32x4 => 2, // 32-bit = 2^2 bytes
            .size64x2 => 3, // 64-bit = 2^3 bytes
        };
    }

    pub fn laneCount(self: VecElemSize) u32 {
        return switch (self) {
            .size8x8 => 8,
            .size8x16 => 16,
            .size16x4 => 4,
            .size16x8 => 8,
            .size32x2 => 2,
            .size32x4 => 4,
            .size64x2 => 2,
        };
    }

    /// Returns the Q bit for vector encoding (0 = 64-bit, 1 = 128-bit)
    pub fn qBit(self: VecElemSize) u1 {
        return switch (self) {
            .size8x8, .size16x4, .size32x2 => 0,
            .size8x16, .size16x8, .size32x4, .size64x2 => 1,
        };
    }

    /// Returns the size field for vector encoding (element size in encoding)
    pub fn sizeBits(self: VecElemSize) u2 {
        return switch (self) {
            .size8x8, .size8x16 => 0b00,
            .size16x4, .size16x8 => 0b01,
            .size32x2, .size32x4 => 0b10,
            .size64x2 => 0b11,
        };
    }

    pub fn format(self: VecElemSize, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .size8x8 => try writer.print("8b", .{}),
            .size8x16 => try writer.print("16b", .{}),
            .size16x4 => try writer.print("4h", .{}),
            .size16x8 => try writer.print("8h", .{}),
            .size32x2 => try writer.print("2s", .{}),
            .size32x4 => try writer.print("4s", .{}),
            .size64x2 => try writer.print("2d", .{}),
        }
    }
};

/// Vector ALU modify operation (FMA/FMS variants).
pub const VecALUModOp = enum {
    Fmla, // Fused multiply-add
    Fmls, // Fused multiply-subtract
};

/// Vector ALU binary operations for ISLE integration.
pub const VecALUOp = enum {
    // Saturating arithmetic
    Sqadd, // Signed saturating add
    Uqadd, // Unsigned saturating add
    Sqsub, // Signed saturating subtract
    Uqsub, // Unsigned saturating subtract

    // Comparisons
    Cmeq, // Compare bitwise equal
    Cmge, // Compare signed greater than or equal
    Cmgt, // Compare signed greater than
    Cmhs, // Compare unsigned higher or same
    Cmhi, // Compare unsigned higher
    Fcmeq, // Floating-point compare equal
    Fcmgt, // Floating-point compare greater than
    Fcmge, // Floating-point compare greater than or equal

    // Bitwise
    And, // Bitwise and
    Bic, // Bitwise bit clear
    Orr, // Bitwise inclusive or
    Orn, // Bitwise inclusive or not
    Eor, // Bitwise exclusive or

    // Arithmetic
    Add, // Add
    Sub, // Subtract
    Mul, // Multiply

    // Shifts
    Sshl, // Signed shift left
    Ushl, // Unsigned shift left

    // Min/Max
    Umin, // Unsigned minimum
    Smin, // Signed minimum
    Umax, // Unsigned maximum
    Smax, // Signed maximum
    Umaxp, // Unsigned maximum pairwise
    Urhadd, // Unsigned rounding halving add

    // Float arithmetic
    Fadd, // Floating-point add
    Fsub, // Floating-point subtract
    Fdiv, // Floating-point divide
    Fmax, // Floating-point maximum
    Fmin, // Floating-point minimum
    Fmul, // Floating-point multiply

    // Pairwise/Zip
    Addp, // Add pairwise
    Zip1, // Zip vectors (primary/high halves)
    Zip2, // Zip vectors (secondary)
    Uzp1, // Unzip vectors (primary)
    Uzp2, // Unzip vectors (secondary)
    Trn1, // Transpose vectors (primary)
    Trn2, // Transpose vectors (secondary)

    // Special
    Sqrdmulh, // Signed saturating rounding doubling multiply returning high half
};

/// Vector miscellaneous unary operations for ISLE integration.
pub const VecMisc2 = enum {
    // Bitwise
    Not, // Bitwise NOT

    // Integer unary
    Neg, // Negate
    Abs, // Absolute value

    // Float unary
    Fabs, // Floating-point absolute value
    Fneg, // Floating-point negate
    Fsqrt, // Floating-point square root

    // Reversals
    Rev16, // Reverse elements in 16-bit lanes
    Rev32, // Reverse elements in 32-bit lanes
    Rev64, // Reverse elements in 64-bit doublewords

    // Float conversions
    Fcvtzs, // Floating-point convert to signed integer, rounding toward zero
    Fcvtzu, // Floating-point convert to unsigned integer, rounding toward zero
    Scvtf, // Signed integer convert to floating-point
    Ucvtf, // Unsigned integer convert to floating-point

    // Float rounding
    Frintn, // Floating point round to integral, rounding towards nearest
    Frintz, // Floating point round to integral, rounding towards zero
    Frintm, // Floating point round to integral, rounding towards minus infinity
    Frintp, // Floating point round to integral, rounding towards plus infinity

    // Special
    Cnt, // Population count per byte

    // Comparisons with zero
    Cmeq0, // Compare bitwise equal to 0
    Cmge0, // Compare signed greater than or equal to 0
    Cmgt0, // Compare signed greater than 0
    Cmle0, // Compare signed less than or equal to 0
    Cmlt0, // Compare signed less than 0
    Fcmeq0, // Floating point compare equal to 0
    Fcmge0, // Floating point compare greater than or equal to 0
    Fcmgt0, // Floating point compare greater than 0
    Fcmle0, // Floating point compare less than or equal to 0
    Fcmlt0, // Floating point compare less than 0
};

/// Vector shift immediate operations
pub const VecShiftImmOp = enum {
    Shl, // Unsigned shift left
    Ushr, // Unsigned shift right
    Sshr, // Signed shift right
    Ushll, // Unsigned shift left long (widens elements)
    Sshll, // Signed shift left long (widens elements)
};

/// Vector size for ISLE integration (maps to ISLE VectorSize enum).
pub const VectorSize = enum {
    V8B,
    V16B,
    V4H,
    V8H,
    V2S,
    V4S,
    V2D,
};

/// Condition code for conditional instructions.
pub const CondCode = enum(u4) {
    eq = 0b0000, // Equal
    ne = 0b0001, // Not equal
    cs = 0b0010, // Carry set (unsigned >=)
    cc = 0b0011, // Carry clear (unsigned <)
    mi = 0b0100, // Minus (negative)
    pl = 0b0101, // Plus (positive or zero)
    vs = 0b0110, // Overflow
    vc = 0b0111, // No overflow
    hi = 0b1000, // Unsigned higher
    ls = 0b1001, // Unsigned lower or same
    ge = 0b1010, // Signed greater or equal
    lt = 0b1011, // Signed less than
    gt = 0b1100, // Signed greater than
    le = 0b1101, // Signed less or equal
    al = 0b1110, // Always (unconditional)

    pub fn invert(self: CondCode) CondCode {
        return @enumFromInt(@intFromEnum(self) ^ 1);
    }

    pub fn format(self: CondCode, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const names = [_][]const u8{
            "eq", "ne", "cs", "cc", "mi", "pl", "vs", "vc",
            "hi", "ls", "ge", "lt", "gt", "le", "al", "nv",
        };
        try writer.print("{s}", .{names[@intFromEnum(self)]});
    }
};

/// Shift operations.
pub const ShiftOp = enum(u2) {
    lsl = 0b00, // Logical shift left
    lsr = 0b01, // Logical shift right
    asr = 0b10, // Arithmetic shift right
    ror = 0b11, // Rotate right

    pub fn format(self: ShiftOp, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .lsl => try writer.print("lsl", .{}),
            .lsr => try writer.print("lsr", .{}),
            .asr => try writer.print("asr", .{}),
            .ror => try writer.print("ror", .{}),
        }
    }
};

/// Extend operations for load/store addressing.
pub const ExtendOp = enum(u3) {
    uxtb = 0b000, // Unsigned extend byte
    uxth = 0b001, // Unsigned extend halfword
    uxtw = 0b010, // Unsigned extend word
    uxtx = 0b011, // Unsigned extend doubleword (LSL)
    sxtb = 0b100, // Signed extend byte
    sxth = 0b101, // Signed extend halfword
    sxtw = 0b110, // Signed extend word
    sxtx = 0b111, // Signed extend doubleword (LSL)

    pub fn format(self: ExtendOp, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .uxtb => try writer.print("uxtb", .{}),
            .uxth => try writer.print("uxth", .{}),
            .uxtw => try writer.print("uxtw", .{}),
            .uxtx => try writer.print("uxtx", .{}),
            .sxtb => try writer.print("sxtb", .{}),
            .sxth => try writer.print("sxth", .{}),
            .sxtw => try writer.print("sxtw", .{}),
            .sxtx => try writer.print("sxtx", .{}),
        }
    }
};

/// Memory barrier option.
pub const BarrierOp = enum(u4) {
    sy = 0b1111, // Full system
    st = 0b1110, // Store
    ld = 0b1101, // Load
    ish = 0b1011, // Inner shareable
    ishst = 0b1010, // Inner shareable store
    ishld = 0b1001, // Inner shareable load
    nsh = 0b0111, // Non-shareable
    nshst = 0b0110, // Non-shareable store
    nshld = 0b0101, // Non-shareable load
    osh = 0b0011, // Outer shareable
    oshst = 0b0010, // Outer shareable store
    oshld = 0b0001, // Outer shareable load

    pub fn format(self: BarrierOp, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .sy => try writer.print("sy", .{}),
            .st => try writer.print("st", .{}),
            .ld => try writer.print("ld", .{}),
            .ish => try writer.print("ish", .{}),
            .ishst => try writer.print("ishst", .{}),
            .ishld => try writer.print("ishld", .{}),
            .nsh => try writer.print("nsh", .{}),
            .nshst => try writer.print("nshst", .{}),
            .nshld => try writer.print("nshld", .{}),
            .osh => try writer.print("osh", .{}),
            .oshst => try writer.print("oshst", .{}),
            .oshld => try writer.print("oshld", .{}),
        }
    }
};

/// System registers accessible via MRS/MSR instructions.
pub const SystemReg = enum(u16) {
    /// NZCV - Condition flags (Negative, Zero, Carry, Overflow)
    nzcv = 0b11_011_0100_0010_000,
    /// FPCR - Floating-point Control Register
    fpcr = 0b11_011_0100_0100_000,
    /// FPSR - Floating-point Status Register
    fpsr = 0b11_011_0100_0100_001,
    /// TPIDR_EL0 - Thread Pointer/ID Register (User Read/Write)
    tpidr_el0 = 0b11_011_1101_0000_010,
    /// TPIDRRO_EL0 - Thread Pointer/ID Register (User Read-Only)
    tpidrro_el0 = 0b11_011_1101_0000_011,

    /// Get the encoding for MRS/MSR instructions.
    pub fn encoding(self: SystemReg) u15 {
        return @intCast(@intFromEnum(self));
    }

    pub fn format(self: SystemReg, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .nzcv => try writer.print("nzcv", .{}),
            .fpcr => try writer.print("fpcr", .{}),
            .fpsr => try writer.print("fpsr", .{}),
            .tpidr_el0 => try writer.print("tpidr_el0", .{}),
            .tpidrro_el0 => try writer.print("tpidrro_el0", .{}),
        }
    }
};

/// Branch target (label or offset).
pub const BranchTarget = union(enum) {
    label: u32,
    offset: i32,

    pub fn format(self: BranchTarget, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .label => |l| try writer.print("label{d}", .{l}),
            .offset => |o| try writer.print("offset{d}", .{o}),
        }
    }
};

/// Call target (external name or register).
pub const CallTarget = union(enum) {
    external_name: []const u8,
    label: u32,

    pub fn format(self: CallTarget, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .external_name => |n| try writer.print("{s}", .{n}),
            .label => |l| try writer.print("label{d}", .{l}),
        }
    }
};

/// Addressing mode for memory operations.
pub const Amode = union(enum) {
    /// Register + immediate offset: [Xn, #offset]
    reg_offset: struct {
        base: Reg,
        offset: i64,
    },

    /// Register + register offset: [Xn, Xm]
    reg_reg: struct {
        base: Reg,
        index: Reg,
    },

    /// Register + extended register: [Xn, Wm, SXTW]
    reg_extended: struct {
        base: Reg,
        index: Reg,
        extend: ExtendOp,
    },

    /// Register + scaled register: [Xn, Xm, LSL #scale]
    reg_scaled: struct {
        base: Reg,
        index: Reg,
        scale: u8,
    },

    /// Pre-indexed: [Xn, #offset]! (update base before access)
    pre_index: struct {
        base: Reg,
        offset: i64,
    },

    /// Post-indexed: [Xn], #offset (update base after access)
    post_index: struct {
        base: Reg,
        offset: i64,
    },

    /// PC-relative: label
    label: u32,

    pub fn format(self: Amode, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .reg_offset => |a| {
                if (a.offset == 0) {
                    try writer.print("[{}]", .{a.base});
                } else {
                    try writer.print("[{}, #{d}]", .{ a.base, a.offset });
                }
            },
            .reg_reg => |a| try writer.print("[{}, {}]", .{ a.base, a.index }),
            .reg_extended => |a| try writer.print("[{}, {}, {}]", .{ a.base, a.index, a.extend }),
            .reg_scaled => |a| {
                if (a.scale == 0) {
                    try writer.print("[{}, {}]", .{ a.base, a.index });
                } else {
                    try writer.print("[{}, {}, lsl #{d}]", .{ a.base, a.index, a.scale });
                }
            },
            .pre_index => |a| try writer.print("[{}, #{d}]!", .{ a.base, a.offset }),
            .post_index => |a| try writer.print("[{}], #{d}", .{ a.base, a.offset }),
            .label => |l| try writer.print("label{d}", .{l}),
        }
    }
};

/// Unwind instruction for exception handling.
pub const UnwindInst = union(enum) {
    push_frame_regs: void,
    pop_frame_regs: void,
    stack_alloc: u32,
    stack_dealloc: u32,

    pub fn format(self: UnwindInst, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .push_frame_regs => try writer.print("push_frame_regs", .{}),
            .pop_frame_regs => try writer.print("pop_frame_regs", .{}),
            .stack_alloc => |size| try writer.print("stack_alloc {d}", .{size}),
            .stack_dealloc => |size| try writer.print("stack_dealloc {d}", .{size}),
        }
    }
};

/// 12-bit immediate with optional shift (for ADD/SUB).
pub const Imm12 = struct {
    bits: u12,
    shift12: bool, // if true, value is bits << 12

    pub fn maybeFromU64(value: u64) ?Imm12 {
        // Try without shift
        if (value <= 0xFFF) {
            return .{ .bits = @intCast(value), .shift12 = false };
        }

        // Try with shift (value must be multiple of 4096)
        if (value <= 0xFFF000 and value & 0xFFF == 0) {
            return .{ .bits = @intCast(value >> 12), .shift12 = true };
        }

        return null;
    }

    pub fn toU64(self: Imm12) u64 {
        const val: u64 = self.bits;
        return if (self.shift12) val << 12 else val;
    }
};

/// Logical immediate encoding (for AND/ORR/EOR with immediate).
pub const ImmLogic = struct {
    value: u64,
    size: OperandSize,

    pub fn maybeFromU64(value: u64, size: OperandSize) ?ImmLogic {
        const encoding = @import("encoding.zig");
        const is_64bit = size == .size64;

        if (encoding.encodeLogicalImmediate(value, is_64bit)) |_| {
            return .{ .value = value, .size = size };
        }

        return null;
    }
};

/// Create addressing mode with register + immediate offset.
pub fn amode_reg_offset(base: Reg, offset: i64) Amode {
    return .{ .reg_offset = .{ .base = base, .offset = offset } };
}

/// Create addressing mode with register + register offset.
pub fn amode_reg_reg(base: Reg, index: Reg) Amode {
    return .{ .reg_reg = .{ .base = base, .index = index } };
}

/// Create addressing mode with register + extended register.
pub fn amode_reg_extended(base: Reg, index: Reg, extend: ExtendOp) Amode {
    return .{ .reg_extended = .{ .base = base, .index = index, .extend = extend } };
}

/// Create addressing mode with register + scaled register.
pub fn amode_reg_scaled(base: Reg, index: Reg, scale: u8) Amode {
    return .{ .reg_scaled = .{ .base = base, .index = index, .scale = scale } };
}

/// Create pre-indexed addressing mode.
pub fn amode_pre_index(base: Reg, offset: i64) Amode {
    return .{ .pre_index = .{ .base = base, .offset = offset } };
}

/// Create post-indexed addressing mode.
pub fn amode_post_index(base: Reg, offset: i64) Amode {
    return .{ .post_index = .{ .base = base, .offset = offset } };
}

/// Create logical shift left instruction: LSL dst, src, #imm
/// Computes dst = src << imm.
pub fn aarch64_lsl(dst: WritableReg, src: Reg, imm: u8, size: OperandSize) Inst {
    return .{ .lsl_imm = .{ .dst = dst, .src = src, .imm = imm, .size = size } };
}

/// Create logical shift right instruction: LSR dst, src, #imm
/// Computes dst = src >> imm (logical/unsigned).
pub fn aarch64_lsr(dst: WritableReg, src: Reg, imm: u8, size: OperandSize) Inst {
    return .{ .lsr_imm = .{ .dst = dst, .src = src, .imm = imm, .size = size } };
}

/// Create arithmetic shift right instruction: ASR dst, src, #imm
/// Computes dst = src >> imm (arithmetic/signed).
pub fn aarch64_asr(dst: WritableReg, src: Reg, imm: u8, size: OperandSize) Inst {
    return .{ .asr_imm = .{ .dst = dst, .src = src, .imm = imm, .size = size } };
}

/// Create rotate right instruction: ROR dst, src, #imm
/// Computes dst = rotate_right(src, imm).
pub fn aarch64_ror(dst: WritableReg, src: Reg, imm: u8, size: OperandSize) Inst {
    return .{ .ror_imm = .{ .dst = dst, .src = src, .imm = imm, .size = size } };
}

/// Check if value fits in 12-bit arithmetic immediate (optionally shifted by 12).
/// Valid values: 0-4095 or (0-4095)<<12.
pub fn isValidArithImm12(value: u64) bool {
    return Imm12.maybeFromU64(value) != null;
}

/// Check if value is valid as logical immediate for AND/ORR/EOR instructions.
/// Logical immediates encode repeating bit patterns.
/// Returns false for all-zeros and all-ones patterns (not encodable).
pub fn isValidLogicalImm(value: u64, is_64bit: bool) bool {
    const size: OperandSize = if (is_64bit) .size64 else .size32;
    return ImmLogic.maybeFromU64(value, size) != null;
}

/// Check if value is valid load/store offset for given access size.
/// Offsets must be aligned to access size and fit in 12-bit unsigned immediate.
/// size: access size in bytes (1, 2, 4, or 8).
pub fn isValidLoadStoreImm(value: i64, size: u32) bool {
    // Validate size is power of 2 and <= 8
    if (size == 0 or size > 8 or (size & (size - 1)) != 0) {
        return false;
    }

    // Check alignment
    const uval: u64 = @bitCast(value);
    if ((uval & (size - 1)) != 0) {
        return false;
    }

    // Check range (unsigned 12-bit scaled)
    const scale: u6 = @intCast(@ctz(size));
    const max_offset: u64 = @as(u64, 4095) << scale;

    if (value < 0) {
        return false;
    }

    return uval <= max_offset;
}

/// Create AND register-register instruction.
/// Computes dst = src1 & src2.
pub fn aarch64_and(dst: WritableReg, src1: Reg, src2: Reg, size: OperandSize) Inst {
    return .{ .and_rr = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Memory barrier options for DMB/DSB/ISB instructions.
pub const BarrierOption = enum(u4) {
    sy = 0xF, // Full system
    st = 0xE, // Store
    ld = 0xD, // Load
    ish = 0xB, // Inner shareable
    ishst = 0xA, // Inner shareable store
    ishld = 0x9, // Inner shareable load
    nsh = 0x7, // Non-shareable
    nshst = 0x6, // Non-shareable store
    nshld = 0x5, // Non-shareable load
    osh = 0x3, // Outer shareable
    oshst = 0x2, // Outer shareable store
    oshld = 0x1, // Outer shareable load
};

/// BTI target type for Branch Target Identification
pub const BtiTarget = enum(u2) {
    /// BTI c - Valid target for call instructions (BL, BLR)
    c = 0b00,
    /// BTI j - Valid target for jump instructions (BR)
    j = 0b01,
    /// BTI jc - Valid target for both call and jump
    jc = 0b10,
};

/// Create AND immediate instruction.
/// Computes dst = src & imm.
/// Returns null if immediate cannot be encoded as logical immediate.
pub fn aarch64_and_imm(dst: WritableReg, src: Reg, imm: u64, size: OperandSize) ?Inst {
    const imm_logic = ImmLogic.maybeFromU64(imm, size) orelse return null;
    return .{ .and_imm = .{
        .dst = dst,
        .src = src,
        .imm = imm_logic,
    } };
}

/// Create ORR register-register instruction.
/// Computes dst = src1 | src2.
pub fn aarch64_orr(dst: WritableReg, src1: Reg, src2: Reg, size: OperandSize) Inst {
    return .{ .orr_rr = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create ORR immediate instruction.
/// Computes dst = src | imm.
/// Returns null if immediate cannot be encoded as logical immediate.
pub fn aarch64_orr_imm(dst: WritableReg, src: Reg, imm: u64, size: OperandSize) ?Inst {
    const imm_logic = ImmLogic.maybeFromU64(imm, size) orelse return null;
    return .{ .orr_imm = .{
        .dst = dst,
        .src = src,
        .imm = imm_logic,
    } };
}

/// Create EOR register-register instruction.
/// Computes dst = src1 ^ src2.
pub fn aarch64_eor(dst: WritableReg, src1: Reg, src2: Reg, size: OperandSize) Inst {
    return .{ .eor_rr = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create EOR immediate instruction.
/// Computes dst = src ^ imm.
/// Returns null if immediate cannot be encoded as logical immediate.
pub fn aarch64_eor_imm(dst: WritableReg, src: Reg, imm: u64, size: OperandSize) ?Inst {
    const imm_logic = ImmLogic.maybeFromU64(imm, size) orelse return null;
    return .{ .eor_imm = .{
        .dst = dst,
        .src = src,
        .imm = imm_logic,
    } };
}

/// Create BIC register-register instruction.
/// Computes dst = src1 & ~src2 (bit clear).
pub fn aarch64_bic(dst: WritableReg, src1: Reg, src2: Reg, size: OperandSize) Inst {
    return .{ .bic_rr = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create store register with register offset instruction.
/// Stores register to memory: [base + offset].
pub fn aarch64_str_reg(src: Reg, base: Reg, offset: Reg, size: OperandSize) Inst {
    return .{ .str_reg = .{
        .src = src,
        .base = base,
        .offset = offset,
        .size = size,
    } };
}

/// Create store register with immediate offset instruction.
/// Stores register to memory: [base + offset].
pub fn aarch64_str_imm(src: Reg, base: Reg, offset: i16, size: OperandSize) Inst {
    return .{ .str = .{
        .src = src,
        .base = base,
        .offset = offset,
        .size = size,
    } };
}

/// Create store pair instruction.
/// Stores two registers to adjacent memory locations: [base + offset], [base + offset + size].
pub fn aarch64_str_pair(src1: Reg, src2: Reg, base: Reg, offset: i16, size: OperandSize) Inst {
    return .{ .stp = .{
        .src1 = src1,
        .src2 = src2,
        .base = base,
        .offset = offset,
        .size = size,
    } };
}

/// Create unconditional branch instruction: B label
/// Branches to a label or offset.
pub fn aarch64_b(target: BranchTarget) Inst {
    return .{ .b = .{ .target = target } };
}

/// Create branch to register instruction: BR Xn
/// Branches to the address in the specified register.
pub fn aarch64_br(target: Reg) Inst {
    return .{ .br = .{ .target = target } };
}

/// Create branch with link to register instruction: BLR Xn
/// Branches to the address in the specified register and stores return address in X30 (LR).
/// Used for function calls through register.
pub fn aarch64_blr(target: Reg) Inst {
    return .{ .blr = .{ .target = target } };
}

/// Create return instruction: RET
/// Returns from function using address in X30 (LR).
pub fn aarch64_ret() Inst {
    return .ret;
}

/// Create floating-point add instruction: FADD Vd, Vn, Vm
/// Computes dst = src1 + src2.
pub fn aarch64_fadd(dst: WritableReg, src1: Reg, src2: Reg, size: FpuOperandSize) Inst {
    return .{ .fadd = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create floating-point subtract instruction: FSUB Vd, Vn, Vm
/// Computes dst = src1 - src2.
pub fn aarch64_fsub(dst: WritableReg, src1: Reg, src2: Reg, size: FpuOperandSize) Inst {
    return .{ .fsub = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create floating-point multiply instruction: FMUL Vd, Vn, Vm
/// Computes dst = src1 * src2.
pub fn aarch64_fmul(dst: WritableReg, src1: Reg, src2: Reg, size: FpuOperandSize) Inst {
    return .{ .fmul = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create floating-point divide instruction: FDIV Vd, Vn, Vm
/// Computes dst = src1 / src2.
pub fn aarch64_fdiv(dst: WritableReg, src1: Reg, src2: Reg, size: FpuOperandSize) Inst {
    return .{ .fdiv = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create floating-point square root instruction: FSQRT Vd, Vn
/// Computes dst = sqrt(src).
pub fn aarch64_fsqrt(dst: WritableReg, src: Reg, size: FpuOperandSize) Inst {
    return .{ .fsqrt = .{
        .dst = dst,
        .src = src,
        .size = size,
    } };
}

/// Create floating-point absolute value instruction: FABS Vd, Vn
/// Computes dst = abs(src).
pub fn aarch64_fabs(dst: WritableReg, src: Reg, size: FpuOperandSize) Inst {
    return .{ .fabs = .{
        .dst = dst,
        .src = src,
        .size = size,
    } };
}

/// Create floating-point negate instruction: FNEG Vd, Vn
/// Computes dst = -src.
pub fn aarch64_fneg(dst: WritableReg, src: Reg, size: FpuOperandSize) Inst {
    return .{ .fneg = .{
        .dst = dst,
        .src = src,
        .size = size,
    } };
}

/// Create vector bitwise AND instruction: AND Vd, Vn, Vm
/// Computes dst = src1 & src2 (element-wise bitwise AND).
pub fn aarch64_vec_and(dst: WritableReg, src1: Reg, src2: Reg, size: FpuOperandSize) Inst {
    return .{ .vec_and = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create vector bitwise OR instruction: ORR Vd, Vn, Vm
/// Computes dst = src1 | src2 (element-wise bitwise OR).
pub fn aarch64_vec_orr(dst: WritableReg, src1: Reg, src2: Reg, size: FpuOperandSize) Inst {
    return .{ .vec_orr = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create vector bitwise XOR instruction: EOR Vd, Vn, Vm
/// Computes dst = src1 ^ src2 (element-wise bitwise XOR).
pub fn aarch64_vec_eor(dst: WritableReg, src1: Reg, src2: Reg, size: FpuOperandSize) Inst {
    return .{ .vec_eor = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create vector addition instruction: ADD Vd, Vn, Vm
/// Computes dst = src1 + src2 (element-wise addition on SIMD vectors).
pub fn aarch64_vec_add(dst: WritableReg, src1: Reg, src2: Reg, size: VecElemSize) Inst {
    return .{ .vec_add = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create vector subtraction instruction: SUB Vd, Vn, Vm
/// Computes dst = src1 - src2 (element-wise subtraction on SIMD vectors).
pub fn aarch64_vec_sub(dst: WritableReg, src1: Reg, src2: Reg, size: VecElemSize) Inst {
    return .{ .vec_sub = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create vector multiplication instruction: MUL Vd, Vn, Vm
/// Computes dst = src1 * src2 (element-wise multiplication on SIMD vectors).
pub fn aarch64_vec_mul(dst: WritableReg, src1: Reg, src2: Reg, size: VecElemSize) Inst {
    return .{ .vec_mul = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .size = size,
    } };
}

/// Create vector add across lanes instruction: ADDV
/// Reduces vector to scalar by adding all lanes: dst = sum(src[i]).
pub fn aarch64_addv(dst: WritableReg, src: Reg, size: VecElemSize) Inst {
    return .{ .vec_addv = .{
        .dst = dst,
        .src = src,
        .size = size,
    } };
}

/// Create vector signed minimum across lanes instruction: SMINV
/// Reduces vector to scalar by finding signed minimum: dst = min(src[i]).
pub fn aarch64_sminv(dst: WritableReg, src: Reg, size: VecElemSize) Inst {
    return .{ .vec_sminv = .{
        .dst = dst,
        .src = src,
        .size = size,
    } };
}

/// Create vector signed maximum across lanes instruction: SMAXV
/// Reduces vector to scalar by finding signed maximum: dst = max(src[i]).
pub fn aarch64_smaxv(dst: WritableReg, src: Reg, size: VecElemSize) Inst {
    return .{ .vec_smaxv = .{
        .dst = dst,
        .src = src,
        .size = size,
    } };
}

/// Create vector unsigned minimum across lanes instruction: UMINV
/// Reduces vector to scalar by finding unsigned minimum: dst = min(src[i]).
pub fn aarch64_uminv(dst: WritableReg, src: Reg, size: VecElemSize) Inst {
    return .{ .vec_uminv = .{
        .dst = dst,
        .src = src,
        .size = size,
    } };
}

/// Create vector unsigned maximum across lanes instruction: UMAXV
/// Reduces vector to scalar by finding unsigned maximum: dst = max(src[i]).
pub fn aarch64_umaxv(dst: WritableReg, src: Reg, size: VecElemSize) Inst {
    return .{ .vec_umaxv = .{
        .dst = dst,
        .src = src,
        .size = size,
    } };
}

/// MRS - Move from System Register
/// Read a system register value into a general-purpose register.
pub fn aarch64_mrs(dst: WritableReg, sysreg: SystemReg) Inst {
    return .{ .mrs = .{
        .dst = dst,
        .sysreg = sysreg,
    } };
}

/// MSR - Move to System Register
/// Write a general-purpose register value to a system register.
pub fn aarch64_msr(sysreg: SystemReg, src: Reg) Inst {
    return .{ .msr = .{
        .sysreg = sysreg,
        .src = src,
    } };
}

/// Operand collector for register allocation.
/// Mimics Cranelift's OperandVisitor pattern for collecting instruction operands.
pub const OperandCollector = struct {
    uses: std.ArrayList(Reg),
    defs: std.ArrayList(WritableReg),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) OperandCollector {
        return .{
            .uses = std.ArrayList(Reg){},
            .defs = std.ArrayList(WritableReg){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *OperandCollector) void {
        self.uses.deinit(self.allocator);
        self.defs.deinit(self.allocator);
    }

    /// Register use (input operand).
    pub fn regUse(self: *OperandCollector, reg: Reg) !void {
        try self.uses.append(self.allocator, reg);
    }

    /// Register def (output operand).
    pub fn regDef(self: *OperandCollector, reg: WritableReg) !void {
        try self.defs.append(self.allocator, reg);
    }

    /// Late def (written after uses are read).
    pub fn regLateDef(self: *OperandCollector, reg: WritableReg) !void {
        try self.defs.append(self.allocator, reg);
    }
};

test "Inst formatting" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst = Inst{ .add_rr = .{
        .dst = wr0,
        .src1 = r0,
        .src2 = r1,
        .size = .size64,
    } };

    var buf: [64]u8 = undefined;
    const str = try std.fmt.bufPrint(&buf, "{any}", .{inst});
    try testing.expect(std.mem.indexOf(u8, str, "add") != null);
}

test "CondCode invert" {
    try testing.expectEqual(CondCode.ne, CondCode.eq.invert());
    try testing.expectEqual(CondCode.eq, CondCode.ne.invert());
    try testing.expectEqual(CondCode.lt, CondCode.ge.invert());
    try testing.expectEqual(CondCode.le, CondCode.gt.invert());
}

test "OperandSize bytes" {
    try testing.expectEqual(@as(u32, 4), OperandSize.size32.bytes());
    try testing.expectEqual(@as(u32, 8), OperandSize.size64.bytes());
}

test "Imm12 encoding" {
    // 12-bit immediate without shift
    const imm1 = Imm12.maybeFromU64(42).?;
    try testing.expectEqual(@as(u12, 42), imm1.bits);
    try testing.expectEqual(false, imm1.shift12);
    try testing.expectEqual(@as(u64, 42), imm1.toU64());

    // 12-bit immediate with shift (12 << 12)
    const imm2 = Imm12.maybeFromU64(12 << 12).?;
    try testing.expectEqual(@as(u12, 12), imm2.bits);
    try testing.expectEqual(true, imm2.shift12);
    try testing.expectEqual(@as(u64, 12 << 12), imm2.toU64());

    // Max 12-bit value
    const imm3 = Imm12.maybeFromU64(0xfff).?;
    try testing.expectEqual(@as(u12, 0xfff), imm3.bits);

    // Invalid - too large
    try testing.expectEqual(@as(?Imm12, null), Imm12.maybeFromU64(0x1000));

    // Invalid - not aligned to either encoding
    try testing.expectEqual(@as(?Imm12, null), Imm12.maybeFromU64((12 << 12) + 1));
}

test "isValidArithImm12" {
    try testing.expect(isValidArithImm12(0));
    try testing.expect(isValidArithImm12(1));
    try testing.expect(isValidArithImm12(0xFFF));
    try testing.expect(isValidArithImm12(0x1000));
    try testing.expect(isValidArithImm12(0xFFF000));
    try testing.expect(!isValidArithImm12(0x1000000));
    try testing.expect(!isValidArithImm12(0x1001)); // Not aligned for shift
}

test "isValidLoadStoreImm" {
    // Valid 4-byte aligned offsets
    try testing.expect(isValidLoadStoreImm(0, 4));
    try testing.expect(isValidLoadStoreImm(4, 4));
    try testing.expect(isValidLoadStoreImm(16380, 4)); // 4095 * 4

    // Invalid - not aligned
    try testing.expect(!isValidLoadStoreImm(1, 4));
    try testing.expect(!isValidLoadStoreImm(2, 4));

    // Invalid - too large
    try testing.expect(!isValidLoadStoreImm(16384, 4));

    // Invalid - negative
    try testing.expect(!isValidLoadStoreImm(-4, 4));

    // Valid 8-byte aligned offsets
    try testing.expect(isValidLoadStoreImm(0, 8));
    try testing.expect(isValidLoadStoreImm(8, 8));
    try testing.expect(isValidLoadStoreImm(32760, 8)); // 4095 * 8

    // Invalid - not aligned
    try testing.expect(!isValidLoadStoreImm(4, 8));
}

test "Multiply instruction formatting" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const v3 = VReg.new(3, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const r3 = Reg.fromVReg(v3);
    const wr0 = WritableReg.fromReg(r0);

    var buf: [128]u8 = undefined;

    // MUL
    const mul_inst = Inst{ .mul_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    const mul_str = try std.fmt.bufPrint(&buf, "{any}", .{mul_inst});
    try testing.expect(std.mem.indexOf(u8, mul_str, "mul") != null);

    // MADD
    const madd_inst = Inst{ .madd = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .addend = r3,
        .size = .size64,
    } };
    const madd_str = try std.fmt.bufPrint(&buf, "{any}", .{madd_inst});
    try testing.expect(std.mem.indexOf(u8, madd_str, "madd") != null);

    // MSUB
    const msub_inst = Inst{ .msub = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .minuend = r3,
        .size = .size64,
    } };
    const msub_str = try std.fmt.bufPrint(&buf, "{any}", .{msub_inst});
    try testing.expect(std.mem.indexOf(u8, msub_str, "msub") != null);

    // SMULH
    const smulh_inst = Inst{ .smulh = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } };
    const smulh_str = try std.fmt.bufPrint(&buf, "{any}", .{smulh_inst});
    try testing.expect(std.mem.indexOf(u8, smulh_str, "smulh") != null);

    // UMULH
    const umulh_inst = Inst{ .umulh = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } };
    const umulh_str = try std.fmt.bufPrint(&buf, "{any}", .{umulh_inst});
    try testing.expect(std.mem.indexOf(u8, umulh_str, "umulh") != null);

    // SMULL
    const smull_inst = Inst{ .smull = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } };
    const smull_str = try std.fmt.bufPrint(&buf, "{any}", .{smull_inst});
    try testing.expect(std.mem.indexOf(u8, smull_str, "smull") != null);

    // UMULL
    const umull_inst = Inst{ .umull = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } };
    const umull_str = try std.fmt.bufPrint(&buf, "{any}", .{umull_inst});
    try testing.expect(std.mem.indexOf(u8, umull_str, "umull") != null);
}

test "Bitwise instruction formatting" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    var buf: [128]u8 = undefined;

    // AND register-register
    const and_rr = Inst{ .and_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    const and_str = try std.fmt.bufPrint(&buf, "{any}", .{and_rr});
    try testing.expect(std.mem.indexOf(u8, and_str, "and") != null);

    // ORR register-register
    const orr_rr = Inst{ .orr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    const orr_str = try std.fmt.bufPrint(&buf, "{any}", .{orr_rr});
    try testing.expect(std.mem.indexOf(u8, orr_str, "orr") != null);

    // EOR register-register
    const eor_rr = Inst{ .eor_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    const eor_str = try std.fmt.bufPrint(&buf, "{any}", .{eor_rr});
    try testing.expect(std.mem.indexOf(u8, eor_str, "eor") != null);

    // BIC register-register
    const bic_rr = Inst{ .bic_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    const bic_str = try std.fmt.bufPrint(&buf, "{any}", .{bic_rr});
    try testing.expect(std.mem.indexOf(u8, bic_str, "bic") != null);

    // MVN
    const mvn = Inst{ .mvn_rr = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } };
    const mvn_str = try std.fmt.bufPrint(&buf, "{any}", .{mvn});
    try testing.expect(std.mem.indexOf(u8, mvn_str, "mvn") != null);
}

test "Shift instruction formatting" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    var buf: [128]u8 = undefined;
    var str: []u8 = undefined;

    // LSL register-register (32-bit)
    const lsl_rr_32 = Inst{ .lsl_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{lsl_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "lsl") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // LSL register-register (64-bit)
    const lsl_rr_64 = Inst{ .lsl_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{lsl_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "lsl") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // LSL immediate (32-bit)
    const lsl_imm_32 = Inst{ .lsl_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{lsl_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "lsl") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#5") != null);

    // LSL immediate (64-bit)
    const lsl_imm_64 = Inst{ .lsl_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 42,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{lsl_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "lsl") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#42") != null);

    // LSR register-register (32-bit)
    const lsr_rr_32 = Inst{ .lsr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{lsr_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "lsr") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // LSR register-register (64-bit)
    const lsr_rr_64 = Inst{ .lsr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{lsr_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "lsr") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // LSR immediate (32-bit)
    const lsr_imm_32 = Inst{ .lsr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 13,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{lsr_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "lsr") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#13") != null);

    // LSR immediate (64-bit)
    const lsr_imm_64 = Inst{ .lsr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 57,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{lsr_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "lsr") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#57") != null);

    // ASR register-register (32-bit)
    const asr_rr_32 = Inst{ .asr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{asr_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "asr") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // ASR register-register (64-bit)
    const asr_rr_64 = Inst{ .asr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{asr_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "asr") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // ASR immediate (32-bit)
    const asr_imm_32 = Inst{ .asr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 7,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{asr_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "asr") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#7") != null);

    // ASR immediate (64-bit)
    const asr_imm_64 = Inst{ .asr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 61,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{asr_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "asr") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#61") != null);

    // ROR register-register (32-bit)
    const ror_rr_32 = Inst{ .ror_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{ror_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "ror") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // ROR register-register (64-bit)
    const ror_rr_64 = Inst{ .ror_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{ror_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "ror") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // ROR immediate (32-bit)
    const ror_imm_32 = Inst{ .ror_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 11,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{ror_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "ror") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#11") != null);

    // ROR immediate (64-bit)
    const ror_imm_64 = Inst{ .ror_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 59,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{any}", .{ror_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "ror") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#59") != null);
}

test "aarch64_lsl constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_lsl(wr0, r1, 5, .size32);
    try testing.expectEqual(Inst.lsl_imm, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.lsl_imm.dst);
    try testing.expectEqual(r1, inst_32.lsl_imm.src);
    try testing.expectEqual(@as(u8, 5), inst_32.lsl_imm.imm);
    try testing.expectEqual(OperandSize.size32, inst_32.lsl_imm.size);

    const inst_64 = aarch64_lsl(wr0, r1, 42, .size64);
    try testing.expectEqual(Inst.lsl_imm, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(@as(u8, 42), inst_64.lsl_imm.imm);
    try testing.expectEqual(OperandSize.size64, inst_64.lsl_imm.size);
}

test "aarch64_lsr constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_lsr(wr0, r1, 13, .size32);
    try testing.expectEqual(Inst.lsr_imm, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.lsr_imm.dst);
    try testing.expectEqual(r1, inst_32.lsr_imm.src);
    try testing.expectEqual(@as(u8, 13), inst_32.lsr_imm.imm);
    try testing.expectEqual(OperandSize.size32, inst_32.lsr_imm.size);

    const inst_64 = aarch64_lsr(wr0, r1, 57, .size64);
    try testing.expectEqual(Inst.lsr_imm, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(@as(u8, 57), inst_64.lsr_imm.imm);
    try testing.expectEqual(OperandSize.size64, inst_64.lsr_imm.size);
}

test "aarch64_asr constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_asr(wr0, r1, 7, .size32);
    try testing.expectEqual(Inst.asr_imm, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.asr_imm.dst);
    try testing.expectEqual(r1, inst_32.asr_imm.src);
    try testing.expectEqual(@as(u8, 7), inst_32.asr_imm.imm);
    try testing.expectEqual(OperandSize.size32, inst_32.asr_imm.size);

    const inst_64 = aarch64_asr(wr0, r1, 61, .size64);
    try testing.expectEqual(Inst.asr_imm, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(@as(u8, 61), inst_64.asr_imm.imm);
    try testing.expectEqual(OperandSize.size64, inst_64.asr_imm.size);
}

test "aarch64_ror constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_ror(wr0, r1, 24, .size32);
    try testing.expectEqual(Inst.ror_imm, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.ror_imm.dst);
    try testing.expectEqual(r1, inst_32.ror_imm.src);
    try testing.expectEqual(@as(u8, 24), inst_32.ror_imm.imm);
    try testing.expectEqual(OperandSize.size32, inst_32.ror_imm.size);

    const inst_64 = aarch64_ror(wr0, r1, 16, .size64);
    try testing.expectEqual(Inst.ror_imm, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(@as(u8, 16), inst_64.ror_imm.imm);
    try testing.expectEqual(OperandSize.size64, inst_64.ror_imm.size);
}

test "aarch64_str_reg constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    const inst_32 = aarch64_str_reg(r0, r1, r2, .size32);
    try testing.expectEqual(Inst.str_reg, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(r0, inst_32.str_reg.src);
    try testing.expectEqual(r1, inst_32.str_reg.base);
    try testing.expectEqual(r2, inst_32.str_reg.offset);
    try testing.expectEqual(OperandSize.size32, inst_32.str_reg.size);

    const inst_64 = aarch64_str_reg(r0, r1, r2, .size64);
    try testing.expectEqual(Inst.str_reg, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(OperandSize.size64, inst_64.str_reg.size);
}

test "aarch64_str_imm constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);

    const inst_32 = aarch64_str_imm(r0, r1, 16, .size32);
    try testing.expectEqual(Inst.str, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(r0, inst_32.str.src);
    try testing.expectEqual(r1, inst_32.str.base);
    try testing.expectEqual(@as(i16, 16), inst_32.str.offset);
    try testing.expectEqual(OperandSize.size32, inst_32.str.size);

    const inst_64 = aarch64_str_imm(r0, r1, -8, .size64);
    try testing.expectEqual(Inst.str, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(@as(i16, -8), inst_64.str.offset);
    try testing.expectEqual(OperandSize.size64, inst_64.str.size);
}

test "aarch64_str_pair constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    const inst_32 = aarch64_str_pair(r0, r1, r2, 8, .size32);
    try testing.expectEqual(Inst.stp, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(r0, inst_32.stp.src1);
    try testing.expectEqual(r1, inst_32.stp.src2);
    try testing.expectEqual(r2, inst_32.stp.base);
    try testing.expectEqual(@as(i16, 8), inst_32.stp.offset);
    try testing.expectEqual(OperandSize.size32, inst_32.stp.size);

    const inst_64 = aarch64_str_pair(r0, r1, r2, 16, .size64);
    try testing.expectEqual(Inst.stp, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(@as(i16, 16), inst_64.stp.offset);
    try testing.expectEqual(OperandSize.size64, inst_64.stp.size);
}

test "aarch64_b constructor" {
    const inst_label = aarch64_b(.{ .label = 42 });
    try testing.expectEqual(Inst.b, @as(std.meta.Tag(Inst), inst_label));
    try testing.expectEqual(BranchTarget.label, @as(std.meta.Tag(BranchTarget), inst_label.b.target));
    try testing.expectEqual(@as(u32, 42), inst_label.b.target.label);

    const inst_offset = aarch64_b(.{ .offset = -100 });
    try testing.expectEqual(Inst.b, @as(std.meta.Tag(Inst), inst_offset));
    try testing.expectEqual(BranchTarget.offset, @as(std.meta.Tag(BranchTarget), inst_offset.b.target));
    try testing.expectEqual(@as(i32, -100), inst_offset.b.target.offset);
}

test "aarch64_br constructor" {
    const v0 = VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);

    const inst = aarch64_br(r0);
    try testing.expectEqual(Inst.br, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(r0, inst.br.target);
}

test "aarch64_blr constructor" {
    const v0 = VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);

    const inst = aarch64_blr(r0);
    try testing.expectEqual(Inst.blr, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(r0, inst.blr.target);
}

test "aarch64_ret constructor" {
    const inst = aarch64_ret();
    try testing.expectEqual(Inst.ret, @as(std.meta.Tag(Inst), inst));
}

test "aarch64_fadd constructor" {
    const v0 = VReg.new(0, .float);
    const v1 = VReg.new(1, .float);
    const v2 = VReg.new(2, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_fadd(wr0, r1, r2, .size32);
    try testing.expectEqual(Inst.fadd, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.fadd.dst);
    try testing.expectEqual(r1, inst_32.fadd.src1);
    try testing.expectEqual(r2, inst_32.fadd.src2);
    try testing.expectEqual(FpuOperandSize.size32, inst_32.fadd.size);

    const inst_64 = aarch64_fadd(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.fadd, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(FpuOperandSize.size64, inst_64.fadd.size);
}

test "aarch64_fsub constructor" {
    const v0 = VReg.new(0, .float);
    const v1 = VReg.new(1, .float);
    const v2 = VReg.new(2, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_fsub(wr0, r1, r2, .size32);
    try testing.expectEqual(Inst.fsub, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.fsub.dst);
    try testing.expectEqual(r1, inst_32.fsub.src1);
    try testing.expectEqual(r2, inst_32.fsub.src2);
    try testing.expectEqual(FpuOperandSize.size32, inst_32.fsub.size);

    const inst_64 = aarch64_fsub(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.fsub, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(FpuOperandSize.size64, inst_64.fsub.size);
}

test "aarch64_fmul constructor" {
    const v0 = VReg.new(0, .float);
    const v1 = VReg.new(1, .float);
    const v2 = VReg.new(2, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_fmul(wr0, r1, r2, .size32);
    try testing.expectEqual(Inst.fmul, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.fmul.dst);
    try testing.expectEqual(r1, inst_32.fmul.src1);
    try testing.expectEqual(r2, inst_32.fmul.src2);
    try testing.expectEqual(FpuOperandSize.size32, inst_32.fmul.size);

    const inst_64 = aarch64_fmul(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.fmul, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(FpuOperandSize.size64, inst_64.fmul.size);
}

test "aarch64_fdiv constructor" {
    const v0 = VReg.new(0, .float);
    const v1 = VReg.new(1, .float);
    const v2 = VReg.new(2, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_fdiv(wr0, r1, r2, .size32);
    try testing.expectEqual(Inst.fdiv, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.fdiv.dst);
    try testing.expectEqual(r1, inst_32.fdiv.src1);
    try testing.expectEqual(r2, inst_32.fdiv.src2);
    try testing.expectEqual(FpuOperandSize.size32, inst_32.fdiv.size);

    const inst_64 = aarch64_fdiv(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.fdiv, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(FpuOperandSize.size64, inst_64.fdiv.size);
}

test "aarch64_fsqrt constructor" {
    const v0 = VReg.new(0, .float);
    const v1 = VReg.new(1, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_fsqrt(wr0, r1, .size32);
    try testing.expectEqual(Inst.fsqrt, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.fsqrt.dst);
    try testing.expectEqual(r1, inst_32.fsqrt.src);
    try testing.expectEqual(FpuOperandSize.size32, inst_32.fsqrt.size);

    const inst_64 = aarch64_fsqrt(wr0, r1, .size64);
    try testing.expectEqual(Inst.fsqrt, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(FpuOperandSize.size64, inst_64.fsqrt.size);
}

test "aarch64_fabs constructor" {
    const v0 = VReg.new(0, .float);
    const v1 = VReg.new(1, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_fabs(wr0, r1, .size32);
    try testing.expectEqual(Inst.fabs, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.fabs.dst);
    try testing.expectEqual(r1, inst_32.fabs.src);
    try testing.expectEqual(FpuOperandSize.size32, inst_32.fabs.size);

    const inst_64 = aarch64_fabs(wr0, r1, .size64);
    try testing.expectEqual(Inst.fabs, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(FpuOperandSize.size64, inst_64.fabs.size);
}

test "aarch64_fneg constructor" {
    const v0 = VReg.new(0, .float);
    const v1 = VReg.new(1, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_32 = aarch64_fneg(wr0, r1, .size32);
    try testing.expectEqual(Inst.fneg, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(wr0, inst_32.fneg.dst);
    try testing.expectEqual(r1, inst_32.fneg.src);
    try testing.expectEqual(FpuOperandSize.size32, inst_32.fneg.size);

    const inst_64 = aarch64_fneg(wr0, r1, .size64);
    try testing.expectEqual(Inst.fneg, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(FpuOperandSize.size64, inst_64.fneg.size);
}

test "aarch64_vec_and constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_64 = aarch64_vec_and(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.vec_and, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(wr0, inst_64.vec_and.dst);
    try testing.expectEqual(r1, inst_64.vec_and.src1);
    try testing.expectEqual(r2, inst_64.vec_and.src2);
    try testing.expectEqual(FpuOperandSize.size64, inst_64.vec_and.size);

    const inst_128 = aarch64_vec_and(wr0, r1, r2, .size128);
    try testing.expectEqual(Inst.vec_and, @as(std.meta.Tag(Inst), inst_128));
    try testing.expectEqual(FpuOperandSize.size128, inst_128.vec_and.size);
}

test "aarch64_vec_orr constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_64 = aarch64_vec_orr(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.vec_orr, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(wr0, inst_64.vec_orr.dst);
    try testing.expectEqual(r1, inst_64.vec_orr.src1);
    try testing.expectEqual(r2, inst_64.vec_orr.src2);
    try testing.expectEqual(FpuOperandSize.size64, inst_64.vec_orr.size);

    const inst_128 = aarch64_vec_orr(wr0, r1, r2, .size128);
    try testing.expectEqual(Inst.vec_orr, @as(std.meta.Tag(Inst), inst_128));
    try testing.expectEqual(FpuOperandSize.size128, inst_128.vec_orr.size);
}

test "aarch64_vec_eor constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_64 = aarch64_vec_eor(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.vec_eor, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(wr0, inst_64.vec_eor.dst);
    try testing.expectEqual(r1, inst_64.vec_eor.src1);
    try testing.expectEqual(r2, inst_64.vec_eor.src2);
    try testing.expectEqual(FpuOperandSize.size64, inst_64.vec_eor.size);

    const inst_128 = aarch64_vec_eor(wr0, r1, r2, .size128);
    try testing.expectEqual(Inst.vec_eor, @as(std.meta.Tag(Inst), inst_128));
    try testing.expectEqual(FpuOperandSize.size128, inst_128.vec_eor.size);
}

test "aarch64_vec_add constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_8x8 = aarch64_vec_add(wr0, r1, r2, .size8x8);
    try testing.expectEqual(Inst.vec_add, @as(std.meta.Tag(Inst), inst_8x8));
    try testing.expectEqual(wr0, inst_8x8.vec_add.dst);
    try testing.expectEqual(r1, inst_8x8.vec_add.src1);
    try testing.expectEqual(r2, inst_8x8.vec_add.src2);
    try testing.expectEqual(VecElemSize.size8x8, inst_8x8.vec_add.size);

    const inst_16x8 = aarch64_vec_add(wr0, r1, r2, .size16x8);
    try testing.expectEqual(Inst.vec_add, @as(std.meta.Tag(Inst), inst_16x8));
    try testing.expectEqual(VecElemSize.size16x8, inst_16x8.vec_add.size);

    const inst_32x4 = aarch64_vec_add(wr0, r1, r2, .size32x4);
    try testing.expectEqual(Inst.vec_add, @as(std.meta.Tag(Inst), inst_32x4));
    try testing.expectEqual(VecElemSize.size32x4, inst_32x4.vec_add.size);

    const inst_64x2 = aarch64_vec_add(wr0, r1, r2, .size64x2);
    try testing.expectEqual(Inst.vec_add, @as(std.meta.Tag(Inst), inst_64x2));
    try testing.expectEqual(VecElemSize.size64x2, inst_64x2.vec_add.size);
}

test "aarch64_vec_sub constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_8x16 = aarch64_vec_sub(wr0, r1, r2, .size8x16);
    try testing.expectEqual(Inst.vec_sub, @as(std.meta.Tag(Inst), inst_8x16));
    try testing.expectEqual(wr0, inst_8x16.vec_sub.dst);
    try testing.expectEqual(r1, inst_8x16.vec_sub.src1);
    try testing.expectEqual(r2, inst_8x16.vec_sub.src2);
    try testing.expectEqual(VecElemSize.size8x16, inst_8x16.vec_sub.size);

    const inst_32x2 = aarch64_vec_sub(wr0, r1, r2, .size32x2);
    try testing.expectEqual(Inst.vec_sub, @as(std.meta.Tag(Inst), inst_32x2));
    try testing.expectEqual(VecElemSize.size32x2, inst_32x2.vec_sub.size);
}

test "aarch64_vec_mul constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_16x4 = aarch64_vec_mul(wr0, r1, r2, .size16x4);
    try testing.expectEqual(Inst.vec_mul, @as(std.meta.Tag(Inst), inst_16x4));
    try testing.expectEqual(wr0, inst_16x4.vec_mul.dst);
    try testing.expectEqual(r1, inst_16x4.vec_mul.src1);
    try testing.expectEqual(r2, inst_16x4.vec_mul.src2);
    try testing.expectEqual(VecElemSize.size16x4, inst_16x4.vec_mul.size);

    const inst_32x4 = aarch64_vec_mul(wr0, r1, r2, .size32x4);
    try testing.expectEqual(Inst.vec_mul, @as(std.meta.Tag(Inst), inst_32x4));
    try testing.expectEqual(VecElemSize.size32x4, inst_32x4.vec_mul.size);
}

test "aarch64_addv constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_8x8 = aarch64_addv(wr0, r1, .size8x8);
    try testing.expectEqual(Inst.vec_addv, @as(std.meta.Tag(Inst), inst_8x8));
    try testing.expectEqual(wr0, inst_8x8.vec_addv.dst);
    try testing.expectEqual(r1, inst_8x8.vec_addv.src);
    try testing.expectEqual(VecElemSize.size8x8, inst_8x8.vec_addv.size);

    const inst_16x8 = aarch64_addv(wr0, r1, .size16x8);
    try testing.expectEqual(Inst.vec_addv, @as(std.meta.Tag(Inst), inst_16x8));
    try testing.expectEqual(VecElemSize.size16x8, inst_16x8.vec_addv.size);

    const inst_32x4 = aarch64_addv(wr0, r1, .size32x4);
    try testing.expectEqual(Inst.vec_addv, @as(std.meta.Tag(Inst), inst_32x4));
    try testing.expectEqual(VecElemSize.size32x4, inst_32x4.vec_addv.size);
}

test "aarch64_sminv constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_8x8 = aarch64_sminv(wr0, r1, .size8x8);
    try testing.expectEqual(Inst.vec_sminv, @as(std.meta.Tag(Inst), inst_8x8));
    try testing.expectEqual(wr0, inst_8x8.vec_sminv.dst);
    try testing.expectEqual(r1, inst_8x8.vec_sminv.src);
    try testing.expectEqual(VecElemSize.size8x8, inst_8x8.vec_sminv.size);

    const inst_16x4 = aarch64_sminv(wr0, r1, .size16x4);
    try testing.expectEqual(Inst.vec_sminv, @as(std.meta.Tag(Inst), inst_16x4));
    try testing.expectEqual(VecElemSize.size16x4, inst_16x4.vec_sminv.size);

    const inst_32x2 = aarch64_sminv(wr0, r1, .size32x2);
    try testing.expectEqual(Inst.vec_sminv, @as(std.meta.Tag(Inst), inst_32x2));
    try testing.expectEqual(VecElemSize.size32x2, inst_32x2.vec_sminv.size);
}

test "aarch64_smaxv constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_8x16 = aarch64_smaxv(wr0, r1, .size8x16);
    try testing.expectEqual(Inst.vec_smaxv, @as(std.meta.Tag(Inst), inst_8x16));
    try testing.expectEqual(wr0, inst_8x16.vec_smaxv.dst);
    try testing.expectEqual(r1, inst_8x16.vec_smaxv.src);
    try testing.expectEqual(VecElemSize.size8x16, inst_8x16.vec_smaxv.size);

    const inst_16x8 = aarch64_smaxv(wr0, r1, .size16x8);
    try testing.expectEqual(Inst.vec_smaxv, @as(std.meta.Tag(Inst), inst_16x8));
    try testing.expectEqual(VecElemSize.size16x8, inst_16x8.vec_smaxv.size);

    const inst_32x4 = aarch64_smaxv(wr0, r1, .size32x4);
    try testing.expectEqual(Inst.vec_smaxv, @as(std.meta.Tag(Inst), inst_32x4));
    try testing.expectEqual(VecElemSize.size32x4, inst_32x4.vec_smaxv.size);
}

test "aarch64_uminv constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_8x8 = aarch64_uminv(wr0, r1, .size8x8);
    try testing.expectEqual(Inst.vec_uminv, @as(std.meta.Tag(Inst), inst_8x8));
    try testing.expectEqual(wr0, inst_8x8.vec_uminv.dst);
    try testing.expectEqual(r1, inst_8x8.vec_uminv.src);
    try testing.expectEqual(VecElemSize.size8x8, inst_8x8.vec_uminv.size);

    const inst_16x4 = aarch64_uminv(wr0, r1, .size16x4);
    try testing.expectEqual(Inst.vec_uminv, @as(std.meta.Tag(Inst), inst_16x4));
    try testing.expectEqual(VecElemSize.size16x4, inst_16x4.vec_uminv.size);

    const inst_32x2 = aarch64_uminv(wr0, r1, .size32x2);
    try testing.expectEqual(Inst.vec_uminv, @as(std.meta.Tag(Inst), inst_32x2));
    try testing.expectEqual(VecElemSize.size32x2, inst_32x2.vec_uminv.size);
}

test "aarch64_umaxv constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_8x16 = aarch64_umaxv(wr0, r1, .size8x16);
    try testing.expectEqual(Inst.vec_umaxv, @as(std.meta.Tag(Inst), inst_8x16));
    try testing.expectEqual(wr0, inst_8x16.vec_umaxv.dst);
    try testing.expectEqual(r1, inst_8x16.vec_umaxv.src);
    try testing.expectEqual(VecElemSize.size8x16, inst_8x16.vec_umaxv.size);

    const inst_16x8 = aarch64_umaxv(wr0, r1, .size16x8);
    try testing.expectEqual(Inst.vec_umaxv, @as(std.meta.Tag(Inst), inst_16x8));
    try testing.expectEqual(VecElemSize.size16x8, inst_16x8.vec_umaxv.size);

    const inst_32x4 = aarch64_umaxv(wr0, r1, .size32x4);
    try testing.expectEqual(Inst.vec_umaxv, @as(std.meta.Tag(Inst), inst_32x4));
    try testing.expectEqual(VecElemSize.size32x4, inst_32x4.vec_umaxv.size);
}
