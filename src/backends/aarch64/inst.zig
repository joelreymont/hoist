const std = @import("std");
const testing = std.testing;

const root = @import("root");
const reg_mod = root.reg;

pub const Reg = reg_mod.Reg;
pub const PReg = reg_mod.PReg;
pub const VReg = reg_mod.VReg;
pub const WritableReg = reg_mod.WritableReg;

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
        subtrahend: Reg,
        size: OperandSize,
    },

    /// Signed multiply high (SMULH Xd, Xn, Xm).
    /// Computes upper 64 bits of signed 64x64→128 multiply.
    smulh: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Unsigned multiply high (UMULH Xd, Xn, Xm).
    /// Computes upper 64 bits of unsigned 64x64→128 multiply.
    umulh: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Signed multiply long (SMULL Xd, Wn, Wm).
    /// 32x32→64 signed multiply.
    smull: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Unsigned multiply long (UMULL Xd, Wn, Wm).
    /// 32x32→64 unsigned multiply.
    umull: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Signed divide (SDIV Xd, Xn, Xm).
    /// Computes Xd = Xn / Xm (signed, truncate toward zero).
    sdiv: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Unsigned divide (UDIV Xd, Xn, Xm).
    /// Computes Xd = Xn / Xm (unsigned).
    udiv: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Logical shift left register (LSL Xd, Xn, Xm).
    /// Computes Xd = Xn << Xm.
    lsl_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Logical shift left immediate (LSL Xd, Xn, #imm).
    /// Computes Xd = Xn << imm.
    lsl_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u8, // 0-63 for 64-bit, 0-31 for 32-bit
        size: OperandSize,
    },

    /// Logical shift right register (LSR Xd, Xn, Xm).
    /// Computes Xd = Xn >> Xm (logical/unsigned).
    lsr_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Logical shift right immediate (LSR Xd, Xn, #imm).
    /// Computes Xd = Xn >> imm (logical/unsigned).
    lsr_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u8, // 0-63 for 64-bit, 0-31 for 32-bit
        size: OperandSize,
    },

    /// Arithmetic shift right register (ASR Xd, Xn, Xm).
    /// Computes Xd = Xn >> Xm (arithmetic/signed).
    asr_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Arithmetic shift right immediate (ASR Xd, Xn, #imm).
    /// Computes Xd = Xn >> imm (arithmetic/signed).
    asr_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u8, // 0-63 for 64-bit, 0-31 for 32-bit
        size: OperandSize,
    },

    /// Rotate right register (ROR Xd, Xn, Xm).
    /// Computes Xd = rotate_right(Xn, Xm).
    ror_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Rotate right immediate (ROR Xd, Xn, #imm).
    /// Computes Xd = rotate_right(Xn, imm).
    ror_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u8, // 0-63 for 64-bit, 0-31 for 32-bit
        size: OperandSize,
    },

    /// Bitwise AND register (AND Xd, Xn, Xm).
    /// Computes Xd = Xn & Xm.
    and_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Bitwise AND immediate (AND Xd, Xn, #imm).
    /// Computes Xd = Xn & imm (using logical immediate encoding).
    and_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: ImmLogic,
    },

    /// Bitwise OR register (ORR Xd, Xn, Xm).
    /// Computes Xd = Xn | Xm.
    orr_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Bitwise OR immediate (ORR Xd, Xn, #imm).
    /// Computes Xd = Xn | imm (using logical immediate encoding).
    orr_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: ImmLogic,
    },

    /// Bitwise XOR register (EOR Xd, Xn, Xm).
    /// Computes Xd = Xn ^ Xm.
    eor_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Bitwise XOR immediate (EOR Xd, Xn, #imm).
    /// Computes Xd = Xn ^ imm (using logical immediate encoding).
    eor_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: ImmLogic,
    },

    /// Bitwise NOT (MVN Xd, Xm).
    /// Computes Xd = ~Xm. Implemented as ORN Xd, XZR, Xm.
    mvn_rr: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// BIC (bit clear): BIC Xd, Xn, Xm
    /// Bitwise AND NOT: Xd = Xn & ~Xm
    bic_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// ORN (OR NOT): ORN Xd, Xn, Xm
    /// Bitwise OR NOT: Xd = Xn | ~Xm
    orn_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// EON (XOR NOT): EON Xd, Xn, Xm
    /// Bitwise XOR NOT: Xd = Xn ^ ~Xm
    eon_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// NEG - Negate (implemented as SUB Xd, XZR, Xm)
    neg: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// ABS (absolute value): ABS Xd, Xn
    /// Computes absolute value of signed integer
    abs: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// NGC - Negate with carry (implemented as SBC Xd, XZR, Xm)
    ngc: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// SXTB - Sign extend byte (8-bit to 32/64-bit).
    /// Sign extends lowest 8 bits to destination size.
    sxtb: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// SXTH - Sign extend halfword (16-bit to 32/64-bit).
    /// Sign extends lowest 16 bits to destination size.
    sxth: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// SXTW - Sign extend word (32-bit to 64-bit).
    /// Sign extends lowest 32 bits to 64-bit. Only valid for 64-bit destination.
    sxtw: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// UXTB - Zero extend byte (8-bit to 32/64-bit).
    /// Zero extends lowest 8 bits to destination size.
    uxtb: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// UXTH - Zero extend halfword (16-bit to 32/64-bit).
    /// Zero extends lowest 16 bits to destination size.
    uxth: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Count leading zeros (CLZ Xd, Xn).
    /// Computes number of leading zero bits.
    clz: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Count leading sign bits (CLS Xd, Xn).
    /// Computes number of leading bits that match the sign bit.
    cls: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Reverse bits (RBIT Xd, Xn).
    /// Reverses the bit order of the source register.
    rbit: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// REV (reverse bytes): REV Xd, Xn
    /// Reverses byte order in register
    rev: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Conditional select (CSEL Xd, Xn, Xm, cond).
    /// Selects src1 if condition true, else src2.
    csel: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        cond: CondCode,
        size: OperandSize,
    },

    /// Conditional select increment (CSINC Xd, Xn, Xm, cond).
    /// Selects src1 if condition true, else src2+1.
    csinc: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        cond: CondCode,
        size: OperandSize,
    },

    /// Conditional select invert (CSINV Xd, Xn, Xm, cond).
    /// Selects src1 if condition true, else ~src2.
    csinv: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        cond: CondCode,
        size: OperandSize,
    },

    /// Conditional select negate (CSNEG Xd, Xn, Xm, cond).
    /// Selects src1 if condition true, else -src2.
    csneg: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        cond: CondCode,
        size: OperandSize,
    },

    /// ADDS - Add and set flags (ADDS Xd, Xn, Xm).
    adds_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// ADDS - Add immediate and set flags (ADDS Xd, Xn, #imm).
    adds_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u16, // 12-bit unsigned immediate
        size: OperandSize,
    },

    /// SUBS - Subtract and set flags (SUBS Xd, Xn, Xm).
    subs_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// SUBS - Subtract immediate and set flags (SUBS Xd, Xn, #imm).
    subs_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u16,
        size: OperandSize,
    },

    /// Compare register with register (CMP Xn, Xm).
    /// Alias for SUBS XZR, Xn, Xm. Sets condition flags for conditional branches.
    cmp_rr: struct {
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Compare register with immediate (CMP Xn, #imm).
    /// Alias for SUBS XZR, Xn, #imm. Sets condition flags for conditional branches.
    cmp_imm: struct {
        src: Reg,
        imm: u16,
        size: OperandSize,
    },

    /// Compare negative register with register (CMN Xn, Xm).
    /// Alias for ADDS XZR, Xn, Xm. Sets condition flags for conditional branches.
    cmn_rr: struct {
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Compare negative register with immediate (CMN Xn, #imm).
    /// Alias for ADDS XZR, Xn, #imm. Sets condition flags for conditional branches.
    cmn_imm: struct {
        src: Reg,
        imm: u16,
        size: OperandSize,
    },

    /// Test bits (TST Xn, Xm).
    /// Alias for ANDS XZR, Xn, Xm. Sets condition flags for conditional branches.
    tst_rr: struct {
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },

    /// Test bits immediate (TST Xn, #imm).
    /// Alias for ANDS XZR, Xn, #imm. Sets condition flags for conditional branches.
    tst_imm: struct {
        src: Reg,
        imm: ImmLogic,
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

    /// Load signed word (32→64 bit) (LDRSW Xt, [Xn, #offset]).
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

    /// Load register from literal pool (LDR Xt, label).
    /// PC-relative load from literal pool.
    ldr_literal: struct {
        dst: WritableReg,
        label: u32, // Label ID for literal pool entry
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

    /// LDARB - Load-Acquire Register Byte
    /// Load byte with acquire semantics, ensures no earlier loads/stores reordered after.
    ldarb: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// LDARH - Load-Acquire Register Halfword
    /// Load halfword with acquire semantics.
    ldarh: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// LDAR - Load-Acquire Register Word (32-bit)
    /// Load word with acquire semantics.
    ldar_w: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// LDAR - Load-Acquire Register Doubleword (64-bit)
    /// Load doubleword with acquire semantics.
    ldar_x: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// STLRB - Store-Release Register Byte
    /// Store byte with release semantics, ensures no later loads/stores reordered before.
    stlrb: struct {
        src: Reg,
        base: Reg,
    },

    /// STLRH - Store-Release Register Halfword
    /// Store halfword with release semantics.
    stlrh: struct {
        src: Reg,
        base: Reg,
    },

    /// STLR - Store-Release Register Word (32-bit)
    /// Store word with release semantics.
    stlr_w: struct {
        src: Reg,
        base: Reg,
    },

    /// STLR - Store-Release Register Doubleword (64-bit)
    /// Store doubleword with release semantics.
    stlr_x: struct {
        src: Reg,
        base: Reg,
    },

    // === Exclusive Access Instructions ===

    /// LDXR - Load Exclusive Register (32-bit)
    /// Load word with exclusive access, sets exclusive monitor.
    ldxr_w: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// LDXR - Load Exclusive Register (64-bit)
    /// Load doubleword with exclusive access, sets exclusive monitor.
    ldxr_x: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// LDXRB - Load Exclusive Register Byte
    /// Load byte with exclusive access, sets exclusive monitor.
    ldxrb: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// LDXRH - Load Exclusive Register Halfword
    /// Load halfword with exclusive access, sets exclusive monitor.
    ldxrh: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// STXR - Store Exclusive Register (32-bit)
    /// Store word with exclusive access. Sets status register to 0 on success, 1 on failure.
    stxr_w: struct {
        status: WritableReg, // Result register: 0=success, 1=failure
        src: Reg,
        base: Reg,
    },

    /// STXR - Store Exclusive Register (64-bit)
    /// Store doubleword with exclusive access. Sets status register to 0 on success, 1 on failure.
    stxr_x: struct {
        status: WritableReg, // Result register: 0=success, 1=failure
        src: Reg,
        base: Reg,
    },

    /// STXRB - Store Exclusive Register Byte
    /// Store byte with exclusive access. Sets status register to 0 on success, 1 on failure.
    stxrb: struct {
        status: WritableReg, // Result register: 0=success, 1=failure
        src: Reg,
        base: Reg,
    },

    /// STXRH - Store Exclusive Register Halfword
    /// Store halfword with exclusive access. Sets status register to 0 on success, 1 on failure.
    stxrh: struct {
        status: WritableReg, // Result register: 0=success, 1=failure
        src: Reg,
        base: Reg,
    },

    /// LDAXR - Load-Acquire Exclusive Register (32-bit)
    /// Load word with acquire-exclusive semantics.
    ldaxr_w: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// LDAXR - Load-Acquire Exclusive Register (64-bit)
    /// Load doubleword with acquire-exclusive semantics.
    ldaxr_x: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// LDAXRB - Load-Acquire Exclusive Register Byte
    /// Load byte with acquire-exclusive semantics.
    ldaxrb: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// LDAXRH - Load-Acquire Exclusive Register Halfword
    /// Load halfword with acquire-exclusive semantics.
    ldaxrh: struct {
        dst: WritableReg,
        base: Reg,
    },

    /// STLXR - Store-Release Exclusive Register (32-bit)
    /// Store word with release-exclusive semantics.
    stlxr_w: struct {
        status: WritableReg, // Result register: 0=success, 1=failure
        src: Reg,
        base: Reg,
    },

    /// STLXR - Store-Release Exclusive Register (64-bit)
    /// Store doubleword with release-exclusive semantics.
    stlxr_x: struct {
        status: WritableReg, // Result register: 0=success, 1=failure
        src: Reg,
        base: Reg,
    },

    /// STLXRB - Store-Release Exclusive Register Byte
    /// Store byte with release-exclusive semantics.
    stlxrb: struct {
        status: WritableReg, // Result register: 0=success, 1=failure
        src: Reg,
        base: Reg,
    },

    /// STLXRH - Store-Release Exclusive Register Halfword
    /// Store halfword with release-exclusive semantics.
    stlxrh: struct {
        status: WritableReg, // Result register: 0=success, 1=failure
        src: Reg,
        base: Reg,
    },

    // === Atomic Operations (ARMv8.1-A LSE) ===

    /// LDADD - Atomic add
    /// Atomically adds src to memory at [base], returns old value to dst.
    ldadd: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDADDA - Atomic add with acquire semantics
    ldadda: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDADDAL - Atomic add with acquire-release semantics
    ldaddal: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDADDL - Atomic add with release semantics
    ldaddl: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDCLR - Atomic bit clear
    /// Atomically clears bits (AND NOT) in memory, returns old value.
    ldclr: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDCLRA - Atomic bit clear with acquire semantics
    ldclra: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDCLRAL - Atomic bit clear with acquire-release semantics
    ldclral: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDCLRL - Atomic bit clear with release semantics
    ldclrl: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDSET - Atomic bit set
    /// Atomically sets bits (OR) in memory, returns old value.
    ldset: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDSETA - Atomic bit set with acquire semantics
    ldseta: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDSETAL - Atomic bit set with acquire-release semantics
    ldsetal: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDSETL - Atomic bit set with release semantics
    ldsetl: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDEOR - Atomic XOR
    /// Atomically XORs bits in memory, returns old value.
    ldeor: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDEORA - Atomic XOR with acquire semantics
    ldeora: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDEORAL - Atomic XOR with acquire-release semantics
    ldeoral: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// LDEORL - Atomic XOR with release semantics
    ldeorl: struct {
        dst: WritableReg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// CAS - Compare and Swap
    /// Atomically compares memory at [base] with compare value, swaps if equal.
    cas: struct {
        compare: Reg, // Compare value (also destination for loaded value)
        src: Reg, // New value to store
        base: Reg,
        size: OperandSize,
    },

    /// CASA - Compare and Swap with acquire semantics
    casa: struct {
        compare: Reg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// CASAL - Compare and Swap with acquire-release semantics
    casal: struct {
        compare: Reg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    /// CASL - Compare and Swap with release semantics
    casl: struct {
        compare: Reg,
        src: Reg,
        base: Reg,
        size: OperandSize,
    },

    // === Memory Barriers ===

    /// DMB - Data Memory Barrier
    /// Ensures ordering of memory accesses before/after the barrier.
    dmb: struct {
        option: BarrierOption,
    },

    /// DSB - Data Synchronization Barrier
    /// Ensures completion of memory accesses and context-synchronization.
    dsb: struct {
        option: BarrierOption,
    },

    /// ISB - Instruction Synchronization Barrier
    /// Flushes pipeline, ensures all previous instructions complete before fetching new ones.
    isb,

    /// Unconditional branch (B label).
    b: struct {
        target: BranchTarget,
    },

    /// Conditional branch (B.cond label).
    b_cond: struct {
        cond: CondCode,
        target: BranchTarget,
    },

    /// Branch and link (BL label).
    bl: struct {
        target: CallTarget,
    },

    /// Branch to register (BR Xn).
    br: struct {
        target: Reg,
    },

    /// Branch and link to register (BLR Xn).
    blr: struct {
        target: Reg,
    },

    /// Return from subroutine (RET [Xn]).
    ret: struct {
        /// Return address register (defaults to X30/LR).
        reg: ?Reg,
    },

    /// ADR - Form PC-relative address
    /// Computes Xd = PC + offset (±1MB range)
    adr: struct {
        dst: WritableReg,
        offset: i32, // signed 21-bit offset (±1MB range)
    },

    /// ADRP - Form PC-relative address to 4KB page
    /// Computes Xd = (PC & ~0xFFF) + (offset << 12) (±4GB range)
    adrp: struct {
        dst: WritableReg,
        offset: i32, // signed 21-bit page offset (±4GB range when shifted)
    },

    /// No operation.
    nop,

    // === Floating-Point Instructions ===

    /// FADD - Floating-point add (scalar)
    fadd_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    fadd_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// FSUB - Floating-point subtract (scalar)
    fsub_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    fsub_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// FMUL - Floating-point multiply (scalar)
    fmul_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    fmul_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// FDIV - Floating-point divide (scalar)
    fdiv_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    fdiv_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// FMOV - Floating-point move register to register
    fmov_rr_s: struct {
        dst: WritableReg,
        src: Reg,
    },

    fmov_rr_d: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// FMOV - Floating-point move immediate (supports immediate zero)
    fmov_imm_s: struct {
        dst: WritableReg,
        imm: f32,
    },

    fmov_imm_d: struct {
        dst: WritableReg,
        imm: f64,
    },

    /// FCMP - Floating-point compare
    fcmp_s: struct {
        src1: Reg,
        src2: Reg,
    },

    fcmp_d: struct {
        src1: Reg,
        src2: Reg,
    },

    /// FCVT - Floating-point convert precision
    fcvt_s_to_d: struct {
        dst: WritableReg,
        src: Reg,
    },

    fcvt_d_to_s: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// SCVTF - Signed integer convert to float
    scvtf_w_to_s: struct {
        dst: WritableReg,
        src: Reg,
    },

    scvtf_x_to_s: struct {
        dst: WritableReg,
        src: Reg,
    },

    scvtf_w_to_d: struct {
        dst: WritableReg,
        src: Reg,
    },

    scvtf_x_to_d: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// FCVTZS - Float convert to signed integer (toward zero)
    fcvtzs_s_to_w: struct {
        dst: WritableReg,
        src: Reg,
    },

    fcvtzs_s_to_x: struct {
        dst: WritableReg,
        src: Reg,
    },

    fcvtzs_d_to_w: struct {
        dst: WritableReg,
        src: Reg,
    },

    fcvtzs_d_to_x: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// FNEG - Floating-point negate
    fneg_s: struct {
        dst: WritableReg,
        src: Reg,
    },

    fneg_d: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// FABS - Floating-point absolute value
    fabs_s: struct {
        dst: WritableReg,
        src: Reg,
    },

    fabs_d: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// FMAX - Floating-point maximum
    fmax_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    fmax_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// FMIN - Floating-point minimum
    fmin_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    fmin_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// FRINTZ - Floating-point round toward zero (truncate)
    frintz_s: struct {
        dst: WritableReg,
        src: Reg,
    },

    frintz_d: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// FRINTP - Floating-point round toward +infinity (ceiling)
    frintp_s: struct {
        dst: WritableReg,
        src: Reg,
    },

    frintp_d: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// FRINTM - Floating-point round toward -infinity (floor)
    frintm_s: struct {
        dst: WritableReg,
        src: Reg,
    },

    frintm_d: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// FRINTA - Floating-point round to nearest, ties to away
    frinta_s: struct {
        dst: WritableReg,
        src: Reg,
    },

    frinta_d: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// FMADD - Floating-point fused multiply-add: d = a + (n * m)
    fmadd_s: struct {
        dst: WritableReg,
        src_n: Reg,
        src_m: Reg,
        src_a: Reg,
    },

    fmadd_d: struct {
        dst: WritableReg,
        src_n: Reg,
        src_m: Reg,
        src_a: Reg,
    },

    /// FMSUB - Floating-point fused multiply-subtract: d = a - (n * m)
    fmsub_s: struct {
        dst: WritableReg,
        src_n: Reg,
        src_m: Reg,
        src_a: Reg,
    },

    fmsub_d: struct {
        dst: WritableReg,
        src_n: Reg,
        src_m: Reg,
        src_a: Reg,
    },

    /// FNMADD - Floating-point fused negate multiply-add: d = -a - (n * m)
    fnmadd_s: struct {
        dst: WritableReg,
        src_n: Reg,
        src_m: Reg,
        src_a: Reg,
    },

    fnmadd_d: struct {
        dst: WritableReg,
        src_n: Reg,
        src_m: Reg,
        src_a: Reg,
    },

    /// FNMSUB - Floating-point fused negate multiply-subtract: d = -a + (n * m)
    fnmsub_s: struct {
        dst: WritableReg,
        src_n: Reg,
        src_m: Reg,
        src_a: Reg,
    },

    fnmsub_d: struct {
        dst: WritableReg,
        src_n: Reg,
        src_m: Reg,
        src_a: Reg,
    },

    /// Vector add (NEON): ADD Vd.T, Vn.T, Vm.T
    vec_add: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector subtract (NEON): SUB Vd.T, Vn.T, Vm.T
    vec_sub: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector multiply (NEON): MUL Vd.T, Vn.T, Vm.T
    vec_mul: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector compare equal (NEON): CMEQ Vd.T, Vn.T, Vm.T
    vec_cmeq: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector compare greater than (NEON): CMGT Vd.T, Vn.T, Vm.T
    vec_cmgt: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector compare greater or equal (NEON): CMGE Vd.T, Vn.T, Vm.T
    vec_cmge: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector AND (NEON): AND Vd.16B, Vn.16B, Vm.16B
    vec_and: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Vector ORR (NEON): ORR Vd.16B, Vn.16B, Vm.16B
    vec_orr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Vector EOR (NEON): EOR Vd.16B, Vn.16B, Vm.16B (XOR)
    vec_eor: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Vector floating-point add: FADD Vd.T, Vn.T, Vm.T (.2s/.4s/.2d only)
    vec_fadd: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize, // Must be .s2, .s4, or .d2
    },

    /// Vector floating-point subtract: FSUB Vd.T, Vn.T, Vm.T
    vec_fsub: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector floating-point multiply: FMUL Vd.T, Vn.T, Vm.T
    vec_fmul: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector floating-point divide: FDIV Vd.T, Vn.T, Vm.T
    vec_fdiv: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector SMIN (signed minimum element-wise): SMIN Vd.T, Vn.T, Vm.T
    vec_smin: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector SMAX (signed maximum element-wise): SMAX Vd.T, Vn.T, Vm.T
    vec_smax: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector UMIN (unsigned minimum element-wise): UMIN Vd.T, Vn.T, Vm.T
    vec_umin: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector UMAX (unsigned maximum element-wise): UMAX Vd.T, Vn.T, Vm.T
    vec_umax: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector ABS (absolute value): ABS Vd.T, Vn.T
    /// Computes absolute value of each signed element
    vec_abs: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize,
    },

    /// Vector NEG (negate): NEG Vd.T, Vn.T
    /// Negates each element
    vec_neg: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize,
    },

    /// Vector FP FCMEQ (compare equal): FCMEQ Vd.T, Vn.T, Vm.T
    vec_fcmeq: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize, // .2s, .4s, or .2d
    },

    /// Vector FP FCMGT (compare greater than): FCMGT Vd.T, Vn.T, Vm.T
    vec_fcmgt: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector FP FCMGE (compare greater or equal): FCMGE Vd.T, Vn.T, Vm.T
    vec_fcmge: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector FP FMIN (minimum): FMIN Vd.T, Vn.T, Vm.T
    vec_fmin: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector FP FMAX (maximum): FMAX Vd.T, Vn.T, Vm.T
    vec_fmax: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// Vector FP FABS (absolute value): FABS Vd.T, Vn.T
    vec_fabs: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize,
    },

    /// Vector FP FNEG (negate): FNEG Vd.T, Vn.T
    vec_fneg: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize,
    },

    /// Vector ADDV (add across vector): ADDV Vd, Vn.T
    /// Sums all lanes of src into dst (scalar result in lane 0)
    addv: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize, // .8b/.16b/.4h/.8h/.2s/.4s only (no .2d)
    },

    /// Vector SMINV (signed minimum across vector): SMINV Vd, Vn.T
    sminv: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize,
    },

    /// Vector SMAXV (signed maximum across vector): SMAXV Vd, Vn.T
    smaxv: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize,
    },

    /// Vector UMINV (unsigned minimum across vector): UMINV Vd, Vn.T
    uminv: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize,
    },

    /// Vector UMAXV (unsigned maximum across vector): UMAXV Vd, Vn.T
    umaxv: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize,
    },

    /// ZIP1 (zip vectors, primary): ZIP1 Vd.T, Vn.T, Vm.T
    /// Interleaves lower halves: d[0]=n[0], d[1]=m[0], d[2]=n[1], d[3]=m[1], ...
    zip1: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// ZIP2 (zip vectors, secondary): ZIP2 Vd.T, Vn.T, Vm.T
    /// Interleaves upper halves
    zip2: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// UZP1 (unzip vectors, primary): UZP1 Vd.T, Vn.T, Vm.T
    /// Deinterleaves even lanes: d[0]=n[0], d[1]=n[2], d[2]=m[0], d[3]=m[2], ...
    uzp1: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// UZP2 (unzip vectors, secondary): UZP2 Vd.T, Vn.T, Vm.T
    /// Deinterleaves odd lanes
    uzp2: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// TRN1 (transpose vectors, primary): TRN1 Vd.T, Vn.T, Vm.T
    /// Transposes even-numbered elements
    trn1: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// TRN2 (transpose vectors, secondary): TRN2 Vd.T, Vn.T, Vm.T
    /// Transposes odd-numbered elements
    trn2: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize,
    },

    /// LD1 (load single structure, one register): LD1 {Vt.T}, [Xn]
    /// Loads entire vector from memory
    ld1: struct {
        dst: WritableReg,
        addr: Reg,
        size: VectorSize,
    },

    /// ST1 (store single structure, one register): ST1 {Vt.T}, [Xn]
    /// Stores entire vector to memory
    st1: struct {
        src: Reg,
        addr: Reg,
        size: VectorSize,
    },

    /// INS (insert element from register): INS Vd.T[index], Vn.T[0]
    /// Inserts element from source lane 0 into destination lane
    ins: struct {
        dst: WritableReg,
        src: Reg,
        index: u4,
        size: VectorSize,
    },

    /// EXT (extract): EXT Vd.16B, Vn.16B, Vm.16B, #imm
    /// Extracts bytes from concatenated vectors
    ext: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        imm: u4,
    },

    /// DUP (duplicate element): DUP Vd.T, Vn.T[index]
    /// Duplicates element to all lanes
    dup_elem: struct {
        dst: WritableReg,
        src: Reg,
        index: u4,
        size: VectorSize,
    },

    /// DUP (duplicate general-purpose register to vector): DUP Vd.T, Xn
    /// Duplicates scalar register to all vector lanes
    dup_scalar: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize,
    },

    /// MOVI (move immediate to vector): MOVI Vd.T, #imm
    /// Moves immediate value to all vector lanes
    movi: struct {
        dst: WritableReg,
        imm: u8,
        size: VectorSize,
    },

    /// SXTL (signed extend long): SXTL Vd.T, Vn.Tb
    /// Extends lower half elements with sign extension
    sxtl: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize, // Result size (.8h, .4s, .2d)
    },

    /// UXTL (unsigned extend long): UXTL Vd.T, Vn.Tb
    /// Extends lower half elements with zero extension
    uxtl: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize, // Result size (.8h, .4s, .2d)
    },

    /// SADDL (signed add long): SADDL Vd.T, Vn.Tb, Vm.Tb
    /// Adds lower half elements with widening
    saddl: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize, // Result size (.8h, .4s, .2d)
    },

    /// UADDL (unsigned add long): UADDL Vd.T, Vn.Tb, Vm.Tb
    /// Adds lower half elements with widening
    uaddl: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: VectorSize, // Result size (.8h, .4s, .2d)
    },

    /// XTN (extract narrow): XTN Vd.Tb, Vn.T
    /// Narrows upper half of elements
    xtn: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize, // Source size (.8h, .4s, .2d)
    },

    /// SQXTN (signed saturating extract narrow): SQXTN Vd.Tb, Vn.T
    /// Narrows with signed saturation
    sqxtn: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize, // Source size (.8h, .4s, .2d)
    },

    /// UQXTN (unsigned saturating extract narrow): UQXTN Vd.Tb, Vn.T
    /// Narrows with unsigned saturation
    uqxtn: struct {
        dst: WritableReg,
        src: Reg,
        size: VectorSize, // Source size (.8h, .4s, .2d)
    },

    /// TBL (table lookup, 1 register): TBL Vd.16B, {Vn.16B}, Vm.16B
    /// Looks up bytes using single table register
    tbl: struct {
        dst: WritableReg,
        table: Reg,
        index: Reg,
    },

    /// TBL2 (table lookup, 2 registers): TBL Vd.16B, {Vn.16B, Vn+1.16B}, Vm.16B
    /// Looks up bytes using two consecutive table registers
    tbl2: struct {
        dst: WritableReg,
        table: Reg, // First of two consecutive registers
        index: Reg,
    },

    /// TBX (table extension): TBX Vd.16B, {Vn.16B}, Vm.16B
    /// Like TBL but leaves dst unchanged for out-of-range indices
    tbx: struct {
        dst: WritableReg,
        table: Reg,
        index: Reg,
    },

    pub fn format(
        self: Inst,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .mov_rr => |i| try writer.print("mov.{} {}, {}", .{ i.size, i.dst, i.src }),
            .mov_imm => |i| try writer.print("mov.{} {}, #{d}", .{ i.size, i.dst, i.imm }),
            .movz => |i| try writer.print("movz.{} {}, #{d}, lsl #{d}", .{ i.size, i.dst, i.imm, i.shift }),
            .movk => |i| try writer.print("movk.{} {}, #{d}, lsl #{d}", .{ i.size, i.dst, i.imm, i.shift }),
            .movn => |i| try writer.print("movn.{} {}, #{d}, lsl #{d}", .{ i.size, i.dst, i.imm, i.shift }),
            .add_rr => |i| try writer.print("add.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .add_imm => |i| try writer.print("add.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .add_shifted => |i| try writer.print("add.{} {}, {}, {}, {} #{d}", .{ i.size, i.dst, i.src1, i.src2, i.shift_op, i.shift_amt }),
            .sub_rr => |i| try writer.print("sub.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .sub_imm => |i| try writer.print("sub.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .mul_rr => |i| try writer.print("mul.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .madd => |i| try writer.print("madd.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.addend }),
            .msub => |i| try writer.print("msub.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.subtrahend }),
            .smulh => |i| try writer.print("smulh {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .umulh => |i| try writer.print("umulh {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .smull => |i| try writer.print("smull {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .umull => |i| try writer.print("umull {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .sdiv => |i| try writer.print("sdiv.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .udiv => |i| try writer.print("udiv.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .lsl_rr => |i| try writer.print("lsl.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .lsl_imm => |i| try writer.print("lsl.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .lsr_rr => |i| try writer.print("lsr.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .lsr_imm => |i| try writer.print("lsr.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .asr_rr => |i| try writer.print("asr.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .asr_imm => |i| try writer.print("asr.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .ror_rr => |i| try writer.print("ror.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .ror_imm => |i| try writer.print("ror.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .and_rr => |i| try writer.print("and.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .and_imm => |i| try writer.print("and.{} {}, {}, #0x{x}", .{ i.imm.size, i.dst, i.src, i.imm.value }),
            .orr_rr => |i| try writer.print("orr.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .orr_imm => |i| try writer.print("orr.{} {}, {}, #0x{x}", .{ i.imm.size, i.dst, i.src, i.imm.value }),
            .eor_rr => |i| try writer.print("eor.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .eor_imm => |i| try writer.print("eor.{} {}, {}, #0x{x}", .{ i.imm.size, i.dst, i.src, i.imm.value }),
            .mvn_rr => |i| try writer.print("mvn.{} {}, {}", .{ i.size, i.dst, i.src }),
            .bic_rr => |i| try writer.print("bic.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .orn_rr => |i| try writer.print("orn.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .eon_rr => |i| try writer.print("eon.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .neg => |i| try writer.print("neg.{} {}, {}", .{ i.size, i.dst, i.src }),
            .abs => |i| try writer.print("abs.{} {}, {}", .{ i.size, i.dst, i.src }),
            .ngc => |i| try writer.print("ngc.{} {}, {}", .{ i.size, i.dst, i.src }),
            .sxtb => |i| try writer.print("sxtb.{} {}, {}", .{ i.size, i.dst, i.src }),
            .sxth => |i| try writer.print("sxth.{} {}, {}", .{ i.size, i.dst, i.src }),
            .sxtw => |i| try writer.print("sxtw {}, {}", .{ i.dst, i.src }),
            .uxtb => |i| try writer.print("uxtb.{} {}, {}", .{ i.size, i.dst, i.src }),
            .uxth => |i| try writer.print("uxth.{} {}, {}", .{ i.size, i.dst, i.src }),
            .clz => |i| try writer.print("clz.{} {}, {}", .{ i.size, i.dst, i.src }),
            .cls => |i| try writer.print("cls.{} {}, {}", .{ i.size, i.dst, i.src }),
            .rbit => |i| try writer.print("rbit.{} {}, {}", .{ i.size, i.dst, i.src }),
            .rev => |i| try writer.print("rev.{} {}, {}", .{ i.size, i.dst, i.src }),
            .csel => |i| try writer.print("csel.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.cond }),
            .csinc => |i| try writer.print("csinc.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.cond }),
            .csinv => |i| try writer.print("csinv.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.cond }),
            .csneg => |i| try writer.print("csneg.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.cond }),
            .adds_rr => |i| try writer.print("adds.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .adds_imm => |i| try writer.print("adds.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .subs_rr => |i| try writer.print("subs.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .subs_imm => |i| try writer.print("subs.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .cmp_rr => |i| try writer.print("cmp.{} {}, {}", .{ i.size, i.src1, i.src2 }),
            .cmp_imm => |i| try writer.print("cmp.{} {}, #{d}", .{ i.size, i.src, i.imm }),
            .cmn_rr => |i| try writer.print("cmn.{} {}, {}", .{ i.size, i.src1, i.src2 }),
            .cmn_imm => |i| try writer.print("cmn.{} {}, #{d}", .{ i.size, i.src, i.imm }),
            .tst_rr => |i| try writer.print("tst.{} {}, {}", .{ i.size, i.src1, i.src2 }),
            .tst_imm => |i| try writer.print("tst.{} {}, #0x{x}", .{ i.imm.size, i.src, i.imm.value }),
            .ldr => |i| try writer.print("ldr.{} {}, [{}, #{d}]", .{ i.size, i.dst, i.base, i.offset }),
            .ldr_reg => |i| try writer.print("ldr.{} {}, [{}, {}]", .{ i.size, i.dst, i.base, i.offset }),
            .ldr_ext => |i| try writer.print("ldr.{} {}, [{}, {}, {}]", .{ i.size, i.dst, i.base, i.offset, i.extend }),
            .ldr_shifted => |i| try writer.print("ldr.{} {}, [{}, {}, {} #{d}]", .{ i.size, i.dst, i.base, i.offset, i.shift_op, i.shift_amt }),
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
            .ldr_literal => |i| try writer.print("ldr.{} {}, =label{d}", .{ i.size, i.dst, i.label }),
            .ldr_pre => |i| try writer.print("ldr.{} {}, [{}, #{d}]!", .{ i.size, i.dst, i.base, i.offset }),
            .ldr_post => |i| try writer.print("ldr.{} {}, [{}], #{d}", .{ i.size, i.dst, i.base, i.offset }),
            .str_pre => |i| try writer.print("str.{} {}, [{}, #{d}]!", .{ i.size, i.src, i.base, i.offset }),
            .str_post => |i| try writer.print("str.{} {}, [{}], #{d}", .{ i.size, i.src, i.base, i.offset }),
            .ldarb => |i| try writer.print("ldarb {}, [{}]", .{ i.dst, i.base }),
            .ldarh => |i| try writer.print("ldarh {}, [{}]", .{ i.dst, i.base }),
            .ldar_w => |i| try writer.print("ldar {}, [{}]", .{ i.dst, i.base }),
            .ldar_x => |i| try writer.print("ldar {}, [{}]", .{ i.dst, i.base }),
            .stlrb => |i| try writer.print("stlrb {}, [{}]", .{ i.src, i.base }),
            .stlrh => |i| try writer.print("stlrh {}, [{}]", .{ i.src, i.base }),
            .stlr_w => |i| try writer.print("stlr {}, [{}]", .{ i.src, i.base }),
            .stlr_x => |i| try writer.print("stlr {}, [{}]", .{ i.src, i.base }),
            .ldxr_w => |i| try writer.print("ldxr {}, [{}]", .{ i.dst, i.base }),
            .ldxr_x => |i| try writer.print("ldxr {}, [{}]", .{ i.dst, i.base }),
            .ldxrb => |i| try writer.print("ldxrb {}, [{}]", .{ i.dst, i.base }),
            .ldxrh => |i| try writer.print("ldxrh {}, [{}]", .{ i.dst, i.base }),
            .stxr_w => |i| try writer.print("stxr {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stxr_x => |i| try writer.print("stxr {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stxrb => |i| try writer.print("stxrb {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stxrh => |i| try writer.print("stxrh {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .ldaxr_w => |i| try writer.print("ldaxr {}, [{}]", .{ i.dst, i.base }),
            .ldaxr_x => |i| try writer.print("ldaxr {}, [{}]", .{ i.dst, i.base }),
            .ldaxrb => |i| try writer.print("ldaxrb {}, [{}]", .{ i.dst, i.base }),
            .ldaxrh => |i| try writer.print("ldaxrh {}, [{}]", .{ i.dst, i.base }),
            .stlxr_w => |i| try writer.print("stlxr {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stlxr_x => |i| try writer.print("stlxr {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stlxrb => |i| try writer.print("stlxrb {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .stlxrh => |i| try writer.print("stlxrh {}, {}, [{}]", .{ i.status, i.src, i.base }),
            .ldadd => |i| try writer.print("ldadd.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldadda => |i| try writer.print("ldadda.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldaddal => |i| try writer.print("ldaddal.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldaddl => |i| try writer.print("ldaddl.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldclr => |i| try writer.print("ldclr.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldclra => |i| try writer.print("ldclra.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldclral => |i| try writer.print("ldclral.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldclrl => |i| try writer.print("ldclrl.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldset => |i| try writer.print("ldset.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldseta => |i| try writer.print("ldseta.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldsetal => |i| try writer.print("ldsetal.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldsetl => |i| try writer.print("ldsetl.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldeor => |i| try writer.print("ldeor.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldeora => |i| try writer.print("ldeora.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldeoral => |i| try writer.print("ldeoral.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .ldeorl => |i| try writer.print("ldeorl.{} {}, {}, [{}]", .{ i.size, i.dst, i.src, i.base }),
            .cas => |i| try writer.print("cas.{} {}, {}, [{}]", .{ i.size, i.compare, i.src, i.base }),
            .casa => |i| try writer.print("casa.{} {}, {}, [{}]", .{ i.size, i.compare, i.src, i.base }),
            .casal => |i| try writer.print("casal.{} {}, {}, [{}]", .{ i.size, i.compare, i.src, i.base }),
            .casl => |i| try writer.print("casl.{} {}, {}, [{}]", .{ i.size, i.compare, i.src, i.base }),
            .dmb => |i| try writer.print("dmb {}", .{i.option}),
            .dsb => |i| try writer.print("dsb {}", .{i.option}),
            .isb => try writer.writeAll("isb"),
            .ldaxr => |i| try writer.print("ldaxr.{} {}, [{}]", .{ i.size, i.dst, i.addr }),
            .stlxr => |i| try writer.print("stlxr.{} {}, {}, [{}]", .{ i.size, i.status, i.src, i.addr }),
            .clrex => try writer.writeAll("clrex"),
            .asm_bytes => |i| try writer.print("asm <{d} bytes>", .{i.bytes.len}),
            .b => |i| try writer.print("b {}", .{i.target}),
            .b_cond => |i| try writer.print("b.{} {}", .{ i.cond, i.target }),
            .bl => |i| try writer.print("bl {}", .{i.target}),
            .br => |i| try writer.print("br {}", .{i.target}),
            .blr => |i| try writer.print("blr {}", .{i.target}),
            .ret => |i| {
                if (i.reg) |r| {
                    try writer.print("ret {}", .{r});
                } else {
                    try writer.writeAll("ret");
                }
            },
            .adr => |i| try writer.print("adr {}, #{d}", .{ i.dst, i.offset }),
            .adrp => |i| try writer.print("adrp {}, #{d}", .{ i.dst, i.offset }),
            .nop => try writer.writeAll("nop"),
            .fadd_s => |i| try writer.print("fadd.s {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fadd_d => |i| try writer.print("fadd.d {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fsub_s => |i| try writer.print("fsub.s {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fsub_d => |i| try writer.print("fsub.d {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fmul_s => |i| try writer.print("fmul.s {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fmul_d => |i| try writer.print("fmul.d {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fdiv_s => |i| try writer.print("fdiv.s {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fdiv_d => |i| try writer.print("fdiv.d {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fmov_rr_s => |i| try writer.print("fmov.s {}, {}", .{ i.dst, i.src }),
            .fmov_rr_d => |i| try writer.print("fmov.d {}, {}", .{ i.dst, i.src }),
            .fmov_imm_s => |i| try writer.print("fmov.s {}, #{d}", .{ i.dst, i.imm }),
            .fmov_imm_d => |i| try writer.print("fmov.d {}, #{d}", .{ i.dst, i.imm }),
            .fcmp_s => |i| try writer.print("fcmp.s {}, {}", .{ i.src1, i.src2 }),
            .fcmp_d => |i| try writer.print("fcmp.d {}, {}", .{ i.src1, i.src2 }),
            .fcvt_s_to_d => |i| try writer.print("fcvt.s_to_d {}, {}", .{ i.dst, i.src }),
            .fcvt_d_to_s => |i| try writer.print("fcvt.d_to_s {}, {}", .{ i.dst, i.src }),
            .scvtf_w_to_s => |i| try writer.print("scvtf.w_to_s {}, {}", .{ i.dst, i.src }),
            .scvtf_x_to_s => |i| try writer.print("scvtf.x_to_s {}, {}", .{ i.dst, i.src }),
            .scvtf_w_to_d => |i| try writer.print("scvtf.w_to_d {}, {}", .{ i.dst, i.src }),
            .scvtf_x_to_d => |i| try writer.print("scvtf.x_to_d {}, {}", .{ i.dst, i.src }),
            .fcvtzs_s_to_w => |i| try writer.print("fcvtzs.s_to_w {}, {}", .{ i.dst, i.src }),
            .fcvtzs_s_to_x => |i| try writer.print("fcvtzs.s_to_x {}, {}", .{ i.dst, i.src }),
            .fcvtzs_d_to_w => |i| try writer.print("fcvtzs.d_to_w {}, {}", .{ i.dst, i.src }),
            .fcvtzs_d_to_x => |i| try writer.print("fcvtzs.d_to_x {}, {}", .{ i.dst, i.src }),
            .fneg_s => |i| try writer.print("fneg.s {}, {}", .{ i.dst, i.src }),
            .fneg_d => |i| try writer.print("fneg.d {}, {}", .{ i.dst, i.src }),
            .fabs_s => |i| try writer.print("fabs.s {}, {}", .{ i.dst, i.src }),
            .fabs_d => |i| try writer.print("fabs.d {}, {}", .{ i.dst, i.src }),
            .fmax_s => |i| try writer.print("fmax.s {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fmax_d => |i| try writer.print("fmax.d {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fmin_s => |i| try writer.print("fmin.s {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .fmin_d => |i| try writer.print("fmin.d {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .frintz_s => |i| try writer.print("frintz.s {}, {}", .{ i.dst, i.src }),
            .frintz_d => |i| try writer.print("frintz.d {}, {}", .{ i.dst, i.src }),
            .frintp_s => |i| try writer.print("frintp.s {}, {}", .{ i.dst, i.src }),
            .frintp_d => |i| try writer.print("frintp.d {}, {}", .{ i.dst, i.src }),
            .frintm_s => |i| try writer.print("frintm.s {}, {}", .{ i.dst, i.src }),
            .frintm_d => |i| try writer.print("frintm.d {}, {}", .{ i.dst, i.src }),
            .frinta_s => |i| try writer.print("frinta.s {}, {}", .{ i.dst, i.src }),
            .frinta_d => |i| try writer.print("frinta.d {}, {}", .{ i.dst, i.src }),
            .fmadd_s => |i| try writer.print("fmadd.s {}, {}, {}, {}", .{ i.dst, i.src_n, i.src_m, i.src_a }),
            .fmadd_d => |i| try writer.print("fmadd.d {}, {}, {}, {}", .{ i.dst, i.src_n, i.src_m, i.src_a }),
            .fmsub_s => |i| try writer.print("fmsub.s {}, {}, {}, {}", .{ i.dst, i.src_n, i.src_m, i.src_a }),
            .fmsub_d => |i| try writer.print("fmsub.d {}, {}, {}, {}", .{ i.dst, i.src_n, i.src_m, i.src_a }),
            .fnmadd_s => |i| try writer.print("fnmadd.s {}, {}, {}, {}", .{ i.dst, i.src_n, i.src_m, i.src_a }),
            .fnmadd_d => |i| try writer.print("fnmadd.d {}, {}, {}, {}", .{ i.dst, i.src_n, i.src_m, i.src_a }),
            .fnmsub_s => |i| try writer.print("fnmsub.s {}, {}, {}, {}", .{ i.dst, i.src_n, i.src_m, i.src_a }),
            .fnmsub_d => |i| try writer.print("fnmsub.d {}, {}, {}, {}", .{ i.dst, i.src_n, i.src_m, i.src_a }),
            .vec_add => |i| try writer.print("add.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_sub => |i| try writer.print("sub.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_mul => |i| try writer.print("mul.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_cmeq => |i| try writer.print("cmeq.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_cmgt => |i| try writer.print("cmgt.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_cmge => |i| try writer.print("cmge.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_and => |i| try writer.print("and.16b {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .vec_orr => |i| try writer.print("orr.16b {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .vec_eor => |i| try writer.print("eor.16b {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .vec_fadd => |i| try writer.print("fadd.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_fsub => |i| try writer.print("fsub.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_fmul => |i| try writer.print("fmul.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_fdiv => |i| try writer.print("fdiv.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_smin => |i| try writer.print("smin.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_smax => |i| try writer.print("smax.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_umin => |i| try writer.print("umin.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_umax => |i| try writer.print("umax.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_abs => |i| try writer.print("abs.{} {}, {}", .{ i.size, i.dst, i.src }),
            .vec_neg => |i| try writer.print("neg.{} {}, {}", .{ i.size, i.dst, i.src }),
            .vec_fcmeq => |i| try writer.print("fcmeq.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_fcmgt => |i| try writer.print("fcmgt.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_fcmge => |i| try writer.print("fcmge.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_fmin => |i| try writer.print("fmin.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_fmax => |i| try writer.print("fmax.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .vec_fabs => |i| try writer.print("fabs.{} {}, {}", .{ i.size, i.dst, i.src }),
            .vec_fneg => |i| try writer.print("fneg.{} {}, {}", .{ i.size, i.dst, i.src }),
            .addv => |i| try writer.print("addv.{} {}, {}", .{ i.size, i.dst, i.src }),
            .sminv => |i| try writer.print("sminv.{} {}, {}", .{ i.size, i.dst, i.src }),
            .smaxv => |i| try writer.print("smaxv.{} {}, {}", .{ i.size, i.dst, i.src }),
            .uminv => |i| try writer.print("uminv.{} {}, {}", .{ i.size, i.dst, i.src }),
            .umaxv => |i| try writer.print("umaxv.{} {}, {}", .{ i.size, i.dst, i.src }),
            .zip1 => |i| try writer.print("zip1.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .zip2 => |i| try writer.print("zip2.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .uzp1 => |i| try writer.print("uzp1.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .uzp2 => |i| try writer.print("uzp2.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .trn1 => |i| try writer.print("trn1.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .trn2 => |i| try writer.print("trn2.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .ld1 => |i| try writer.print("ld1.{} {{{}}}, [{}]", .{ i.size, i.dst, i.addr }),
            .st1 => |i| try writer.print("st1.{} {{{}}}, [{}]", .{ i.size, i.src, i.addr }),
            .ins => |i| try writer.print("ins.{} {{}}[{d}], {{}}[0]", .{ i.size, i.dst, i.index, i.src }),
            .ext => |i| try writer.print("ext.16b {}, {}, {}, #{d}", .{ i.dst, i.src1, i.src2, i.imm }),
            .dup_elem => |i| try writer.print("dup.{} {}, {{}}[{d}]", .{ i.size, i.dst, i.src, i.index }),
            .dup_scalar => |i| try writer.print("dup.{} {}, {}", .{ i.size, i.dst, i.src }),
            .movi => |i| try writer.print("movi.{} {}, #{d}", .{ i.size, i.dst, i.imm }),
            .sxtl => |i| try writer.print("sxtl.{} {}, {}", .{ i.size, i.dst, i.src }),
            .uxtl => |i| try writer.print("uxtl.{} {}, {}", .{ i.size, i.dst, i.src }),
            .saddl => |i| try writer.print("saddl.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .uaddl => |i| try writer.print("uaddl.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .xtn => |i| try writer.print("xtn.{} {}, {}", .{ i.size, i.dst, i.src }),
            .sqxtn => |i| try writer.print("sqxtn.{} {}, {}", .{ i.size, i.dst, i.src }),
            .uqxtn => |i| try writer.print("uqxtn.{} {}, {}", .{ i.size, i.dst, i.src }),
            .tbl => |i| try writer.print("tbl.16b {}, {{{}}}, {}", .{ i.dst, i.table, i.index }),
            .tbl2 => |i| try writer.print("tbl.16b {}, {{{}, v{d}}}, {}", .{ i.dst, i.table, i.table.toVReg().nr() + 1, i.index }),
            .tbx => |i| try writer.print("tbx.16b {}, {{{}}}, {}", .{ i.dst, i.table, i.index }),
            .dmb => |i| try writer.print("dmb {}", .{i.option}),
            .dsb => |i| try writer.print("dsb {}", .{i.option}),
            .isb => try writer.writeAll("isb"),
            .ldaxr => |i| try writer.print("ldaxr.{} {}, [{}]", .{ i.size, i.dst, i.addr }),
            .stlxr => |i| try writer.print("stlxr.{} {}, {}, [{}]", .{ i.size, i.status, i.src, i.addr }),
            .clrex => try writer.writeAll("clrex"),
        }
    }
};

/// Vector size for NEON/SIMD instructions.
/// Encodes both vector width (64/128-bit) and element size.
pub const VectorSize = enum(u3) {
    /// 8 bytes × 8 bits = 64-bit vector (8B)
    b8 = 0,
    /// 16 bytes × 8 bits = 128-bit vector (16B)
    b16 = 1,
    /// 4 halfwords × 16 bits = 64-bit vector (4H)
    h4 = 2,
    /// 8 halfwords × 16 bits = 128-bit vector (8H)
    h8 = 3,
    /// 2 words × 32 bits = 64-bit vector (2S)
    s2 = 4,
    /// 4 words × 32 bits = 128-bit vector (4S)
    s4 = 5,
    /// 2 doublewords × 64 bits = 128-bit vector (2D)
    d2 = 6,

    /// Returns the Q bit (0 for 64-bit, 1 for 128-bit).
    pub fn qBit(self: VectorSize) u1 {
        return switch (self) {
            .b8, .h4, .s2 => 0,
            .b16, .h8, .s4, .d2 => 1,
        };
    }

    /// Returns the size field for instruction encoding.
    pub fn sizeBits(self: VectorSize) u2 {
        return switch (self) {
            .b8, .b16 => 0b00,
            .h4, .h8 => 0b01,
            .s2, .s4 => 0b10,
            .d2 => 0b11,
        };
    }

    pub fn format(
        self: VectorSize,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const suffix = switch (self) {
            .b8 => "8b",
            .b16 => "16b",
            .h4 => "4h",
            .h8 => "8h",
            .s2 => "2s",
            .s4 => "4s",
            .d2 => "2d",
        };
        try writer.writeAll(suffix);
    }
};

/// Operand size for aarch64 instructions.
pub const OperandSize = enum {
    /// 32-bit (W registers).
    size32,
    /// 64-bit (X registers).
    size64,

    pub fn format(
        self: OperandSize,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const suffix = switch (self) {
            .size32 => "w",
            .size64 => "x",
        };
        try writer.writeAll(suffix);
    }

    pub fn bytes(self: OperandSize) u32 {
        return switch (self) {
            .size32 => 4,
            .size64 => 8,
        };
    }
};

/// Condition code for conditional branches.
pub const CondCode = enum {
    /// Equal / zero.
    eq,
    /// Not equal / not zero.
    ne,
    /// Carry set / unsigned higher or same.
    hs,
    /// Carry clear / unsigned lower.
    lo,
    /// Minus / negative.
    mi,
    /// Plus / positive or zero.
    pl,
    /// Overflow set.
    vs,
    /// Overflow clear.
    vc,
    /// Unsigned higher.
    hi,
    /// Unsigned lower or same.
    ls,
    /// Signed greater than or equal.
    ge,
    /// Signed less than.
    lt,
    /// Signed greater than.
    gt,
    /// Signed less than or equal.
    le,
    /// Always (unconditional).
    al,

    pub fn format(
        self: CondCode,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const name = @tagName(self);
        try writer.writeAll(name);
    }

    /// Invert the condition code.
    pub fn invert(self: CondCode) CondCode {
        return switch (self) {
            .eq => .ne,
            .ne => .eq,
            .hs => .lo,
            .lo => .hs,
            .mi => .pl,
            .pl => .mi,
            .vs => .vc,
            .vc => .vs,
            .hi => .ls,
            .ls => .hi,
            .ge => .lt,
            .lt => .ge,
            .gt => .le,
            .le => .gt,
            .al => .al,
        };
    }

    /// Encode condition code to 4-bit value for instruction encoding.
    /// Maps to ARM condition field encoding per ARM ARM.
    pub fn bits(self: CondCode) u4 {
        return switch (self) {
            .eq => 0b0000, // Z == 1
            .ne => 0b0001, // Z == 0
            .hs => 0b0010, // C == 1 (unsigned >=)
            .lo => 0b0011, // C == 0 (unsigned <)
            .mi => 0b0100, // N == 1 (negative)
            .pl => 0b0101, // N == 0 (positive or zero)
            .vs => 0b0110, // V == 1 (overflow)
            .vc => 0b0111, // V == 0 (no overflow)
            .hi => 0b1000, // C == 1 and Z == 0 (unsigned >)
            .ls => 0b1001, // C == 0 or Z == 1 (unsigned <=)
            .ge => 0b1010, // N == V (signed >=)
            .lt => 0b1011, // N != V (signed <)
            .gt => 0b1100, // Z == 0 and N == V (signed >)
            .le => 0b1101, // Z == 1 or N != V (signed <=)
            .al => 0b1110, // Always (unconditional)
        };
    }
};

/// Branch target (label for branches).
pub const BranchTarget = struct {
    label: u32,

    pub fn new(label: u32) BranchTarget {
        return .{ .label = label };
    }

    pub fn format(
        self: BranchTarget,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(".L{d}", .{self.label});
    }
};

/// Call target (function name or register).
pub const CallTarget = union(enum) {
    /// Direct call to a named function.
    direct: []const u8,
    /// Indirect call through register.
    indirect: Reg,

    pub fn format(
        self: CallTarget,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .direct => |name| try writer.print("{s}", .{name}),
            .indirect => |reg| try writer.print("{}", .{reg}),
        }
    }
};

/// 12-bit unsigned immediate (optionally shifted left by 12).
/// Used for ADD/SUB immediate instructions.
pub const Imm12 = struct {
    /// 12-bit immediate value.
    bits: u16,
    /// Whether to shift left by 12 bits.
    shift12: bool,

    pub const ZERO: Imm12 = .{ .bits = 0, .shift12 = false };

    /// Create from u64 if it fits in 12-bit or 12-bit<<12 encoding.
    pub fn maybeFromU64(val: u64) ?Imm12 {
        if (val & ~@as(u64, 0xfff) == 0) {
            return .{ .bits = @intCast(val), .shift12 = false };
        } else if (val & ~@as(u64, 0xfff << 12) == 0) {
            return .{ .bits = @intCast(val >> 12), .shift12 = true };
        }
        return null;
    }

    /// Convert back to u64.
    pub fn toU64(self: Imm12) u64 {
        const val: u64 = self.bits;
        return if (self.shift12) val << 12 else val;
    }

    /// Get 2-bit shift field for encoding.
    pub fn shiftBits(self: Imm12) u2 {
        return if (self.shift12) 0b01 else 0b00;
    }
};

/// Immediate for shift instructions (0-63).
pub const ImmShift = struct {
    /// 6-bit shift amount.
    imm: u8,

    /// Create from u64 if it fits in 6 bits.
    pub fn maybeFromU64(val: u64) ?ImmShift {
        if (val < 64) {
            return .{ .imm = @intCast(val) };
        }
        return null;
    }

    pub fn toU64(self: ImmShift) u64 {
        return self.imm;
    }
};

/// Check if a shift amount is valid for the given register size.
/// Returns true if the shift amount is within valid range:
/// - 32-bit registers: 0-31
/// - 64-bit registers: 0-63
pub fn isValidShiftAmount(amount: u64, reg_size: OperandSize) bool {
    return switch (reg_size) {
        .size32 => amount < 32,
        .size64 => amount < 64,
    };
}

/// Normalize a shift amount to the valid range for the given register size.
/// For ARM64, shift amounts wrap modulo the register width:
/// - 32-bit registers: amount % 32
/// - 64-bit registers: amount % 64
pub fn normalizeShiftAmount(amount: u64, reg_size: OperandSize) u8 {
    return switch (reg_size) {
        .size32 => @intCast(amount % 32),
        .size64 => @intCast(amount % 64),
    };
}

/// Logical immediate encoding for AND/ORR/EOR instructions.
/// Encodes repeating patterns using N, R, S fields.
pub const ImmLogic = struct {
    /// Actual 64-bit value represented.
    value: u64,
    /// N flag (1 for 64-bit patterns).
    n: bool,
    /// R field: rotation amount.
    r: u8,
    /// S field: element size and set bits.
    s: u8,
    /// Operand size (32 or 64 bit).
    size: OperandSize,

    /// Create from u64 if encodable as logical immediate.
    /// This is complex - see ARM ARM for full algorithm.
    pub fn maybeFromU64(val: u64, size: OperandSize) ?ImmLogic {
        const original_value = val;

        const value = if (size == .size32) blk: {
            const v = val << 32;
            break :blk v | (v >> 32);
        } else val;

        const inverted = (value & 1) == 1;
        const value_adj = if (inverted) ~value else value;

        if (value_adj == 0) return null;

        const a = @as(u64, 1) << @intCast(@ctz(value_adj));
        const value_plus_a = value_adj +% a;
        const b = if (value_plus_a == 0) @as(u64, 0) else @as(u64, 1) << @intCast(@ctz(value_plus_a));
        const value_plus_a_minus_b = value_plus_a -% b;
        const c = if (value_plus_a_minus_b == 0) @as(u64, 0) else @as(u64, 1) << @intCast(@ctz(value_plus_a_minus_b));

        const clz_a = @clz(a);
        const d: u32 = if (c != 0) blk: {
            const clz_c = @clz(c);
            break :blk clz_a - clz_c;
        } else 64;

        const out_n: u8 = if (c != 0) 0 else 1;
        const mask = if (c != 0) (@as(u64, 1) << @intCast(d)) - 1 else std.math.maxInt(u64);

        if ((d & (d - 1)) != 0) return null;

        if (((b -% a) & ~mask) != 0) return null;

        const multipliers = [_]u64{
            0x0000000000000001,
            0x0000000100000001,
            0x0001000100010001,
            0x0101010101010101,
            0x1111111111111111,
            0x5555555555555555,
        };
        const multiplier = multipliers[@intCast(@as(u64, d).leading_zeros() - 57)];
        const candidate = (b -% a) *% multiplier;

        if (value_adj != candidate) return null;

        const clz_b = if (b == 0) std.math.maxInt(u32) else @clz(b);
        const s_bits = clz_a -% clz_b;

        const s_val: u32 = if (inverted) d - s_bits else s_bits;
        const r_val: u32 = if (inverted)
            (clz_b +% 1) & (d - 1)
        else
            (clz_a + 1) & (d - 1);

        const s = ((d * 2) *% (@as(u32, 0) -% 1) | (s_val -% 1)) & 0x3f;

        return ImmLogic{
            .value = original_value,
            .n = out_n != 0,
            .r = @intCast(r_val),
            .s = @intCast(s),
            .size = size,
        };
    }

    pub fn toU64(self: ImmLogic) u64 {
        return self.value;
    }
};

/// Shift operation for shifted register operands.
pub const ShiftOp = enum(u2) {
    lsl = 0b00,
    lsr = 0b01,
    asr = 0b10,
    ror = 0b11,

    pub fn format(
        self: ShiftOp,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const name = @tagName(self);
        try writer.writeAll(name);
    }
};

/// Shift operation and amount for shifted register operands.
pub const ShiftOpAndAmt = struct {
    op: ShiftOp,
    amt: u8,
};

/// Extend operation for extended register operands.
pub const ExtendOp = enum(u3) {
    uxtb = 0b000, // Zero-extend byte
    uxth = 0b001, // Zero-extend halfword
    uxtw = 0b010, // Zero-extend word (32→64)
    uxtx = 0b011, // Zero-extend doubleword (nop for 64-bit)
    sxtb = 0b100, // Sign-extend byte
    sxth = 0b101, // Sign-extend halfword
    sxtw = 0b110, // Sign-extend word (32→64)
    sxtx = 0b111, // Sign-extend doubleword (nop for 64-bit)

    pub fn format(
        self: ExtendOp,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const name = @tagName(self);
        try writer.writeAll(name);
    }
};

/// Barrier option for DMB/DSB instructions.
/// Specifies the shareability domain and access type for the barrier.
pub const BarrierOption = enum(u4) {
    /// Full system barrier (all operations)
    sy = 0b1111,
    /// Full system store barrier
    st = 0b1110,
    /// Full system load barrier
    ld = 0b1101,
    /// Inner shareable barrier (all operations)
    ish = 0b1011,
    /// Inner shareable store barrier
    ishst = 0b1010,
    /// Inner shareable load barrier
    ishld = 0b1001,
    /// Non-shareable barrier (all operations)
    nsh = 0b0111,
    /// Non-shareable store barrier
    nshst = 0b0110,
    /// Non-shareable load barrier
    nshld = 0b0101,
    /// Outer shareable barrier (all operations)
    osh = 0b0011,
    /// Outer shareable store barrier
    oshst = 0b0010,
    /// Outer shareable load barrier
    oshld = 0b0001,

    pub fn format(
        self: BarrierOption,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const name = @tagName(self);
        try writer.writeAll(name);
    }
};

/// Addressing mode for load/store instructions.
/// Encapsulates different ways to address memory on AArch64.
pub const AMode = union(enum) {
    /// Base register only: [Xn]
    base_only: struct {
        base: Reg,
    },

    /// Base + immediate offset: [Xn, #imm]
    base_offset: struct {
        base: Reg,
        offset: i16,
    },

    /// Base + index register: [Xn, Xm]
    base_index: struct {
        base: Reg,
        index: Reg,
    },

    /// Base + (index << shift): [Xn, Xm, LSL #shift]
    base_index_shift: struct {
        base: Reg,
        index: Reg,
        shift: u8,
    },

    /// Pre-indexed: [Xn, #imm]! (update base before access)
    pre_index: struct {
        base: WritableReg,
        offset: i16,
    },

    /// Post-indexed: [Xn], #imm (update base after access)
    post_index: struct {
        base: WritableReg,
        offset: i16,
    },
};

/// Create base-only addressing mode: [base]
pub fn baseOnly(base: Reg) AMode {
    return .{ .base_only = .{ .base = base } };
}

/// Create base+offset addressing mode: [base, #offset]
pub fn baseOffset(base: Reg, offset: i16) AMode {
    return .{ .base_offset = .{ .base = base, .offset = offset } };
}

/// Create base+index addressing mode: [base, index]
pub fn baseIndex(base: Reg, index: Reg) AMode {
    return .{ .base_index = .{ .base = base, .index = index } };
}

/// Create base+(index<<shift) addressing mode: [base, index, LSL #shift]
pub fn baseIndexShift(base: Reg, index: Reg, shift: u8) AMode {
    return .{ .base_index_shift = .{ .base = base, .index = index, .shift = shift } };
}

/// Create pre-indexed addressing mode: [base, #offset]!
/// Updates base register before memory access.
pub fn preIndex(base: WritableReg, offset: i16) AMode {
    return .{ .pre_index = .{ .base = base, .offset = offset } };
}

/// Create post-indexed addressing mode: [base], #offset
/// Updates base register after memory access.
pub fn postIndex(base: WritableReg, offset: i16) AMode {
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

/// Create conditional select instruction.
/// Selects src1 if condition is true, otherwise src2.
pub fn aarch64_csel(dst: WritableReg, src1: Reg, src2: Reg, cond: CondCode, size: OperandSize) Inst {
    return .{ .csel = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .cond = cond,
        .size = size,
    } };
}

/// Create conditional select increment instruction.
/// Selects src1 if condition is true, otherwise src2 + 1.
pub fn aarch64_csinc(dst: WritableReg, src1: Reg, src2: Reg, cond: CondCode, size: OperandSize) Inst {
    return .{ .csinc = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .cond = cond,
        .size = size,
    } };
}

/// Create conditional select invert instruction.
/// Selects src1 if condition is true, otherwise ~src2.
pub fn aarch64_csinv(dst: WritableReg, src1: Reg, src2: Reg, cond: CondCode, size: OperandSize) Inst {
    return .{ .csinv = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .cond = cond,
        .size = size,
    } };
}

/// Create conditional select negate instruction.
/// Selects src1 if condition is true, otherwise -src2.
pub fn aarch64_csneg(dst: WritableReg, src1: Reg, src2: Reg, cond: CondCode, size: OperandSize) Inst {
    return .{ .csneg = .{
        .dst = dst,
        .src1 = src1,
        .src2 = src2,
        .cond = cond,
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

/// Create LDR immediate instruction: LDR Xt, [Xn, #offset]
/// Load register from memory with immediate offset.
pub fn aarch64_ldr_imm(dst: WritableReg, base: Reg, offset: i16, size: OperandSize) Inst {
    return .{ .ldr = .{
        .dst = dst,
        .base = base,
        .offset = offset,
        .size = size,
    } };
}

/// Create LDR register instruction: LDR Xt, [Xn, Xm]
/// Load register from memory with register offset.
pub fn aarch64_ldr_reg(dst: WritableReg, base: Reg, offset: Reg, size: OperandSize) Inst {
    return .{ .ldr_reg = .{
        .dst = dst,
        .base = base,
        .offset = offset,
        .size = size,
    } };
}

/// Create LDP instruction: LDP Xt1, Xt2, [Xn, #offset]
/// Load pair of registers from memory.
pub fn aarch64_ldr_pair(dst1: WritableReg, dst2: WritableReg, base: Reg, offset: i16, size: OperandSize) Inst {
    return .{ .ldp = .{
        .dst1 = dst1,
        .dst2 = dst2,
        .base = base,
        .offset = offset,
        .size = size,
    } };
}

/// Create LDR literal instruction: LDR Xt, label
/// Load register from literal pool using PC-relative addressing.
pub fn aarch64_ldr_literal(dst: WritableReg, label: u32, size: OperandSize) Inst {
    return .{ .ldr_literal = .{
        .dst = dst,
        .label = label,
        .size = size,
    } };
}

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
    const str = try std.fmt.bufPrint(&buf, "{}", .{inst});
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
    try testing.expectEqual(@as(u16, 42), imm1.bits);
    try testing.expectEqual(false, imm1.shift12);
    try testing.expectEqual(@as(u64, 42), imm1.toU64());

    // 12-bit immediate with shift (12 << 12)
    const imm2 = Imm12.maybeFromU64(12 << 12).?;
    try testing.expectEqual(@as(u16, 12), imm2.bits);
    try testing.expectEqual(true, imm2.shift12);
    try testing.expectEqual(@as(u64, 12 << 12), imm2.toU64());

    // Max 12-bit value
    const imm3 = Imm12.maybeFromU64(0xfff).?;
    try testing.expectEqual(@as(u16, 0xfff), imm3.bits);

    // Invalid - too large
    try testing.expectEqual(@as(?Imm12, null), Imm12.maybeFromU64(0x1000));

    // Invalid - not aligned to either encoding
    try testing.expectEqual(@as(?Imm12, null), Imm12.maybeFromU64((12 << 12) + 1));
}

test "ImmShift encoding" {
    const sh1 = ImmShift.maybeFromU64(0).?;
    try testing.expectEqual(@as(u8, 0), sh1.imm);

    const sh2 = ImmShift.maybeFromU64(63).?;
    try testing.expectEqual(@as(u8, 63), sh2.imm);

    // Invalid - too large
    try testing.expectEqual(@as(?ImmShift, null), ImmShift.maybeFromU64(64));
    try testing.expectEqual(@as(?ImmShift, null), ImmShift.maybeFromU64(100));
}

test "shift amount validation 32-bit" {
    // Valid shift amounts for 32-bit registers
    try testing.expect(isValidShiftAmount(0, .size32));
    try testing.expect(isValidShiftAmount(1, .size32));
    try testing.expect(isValidShiftAmount(15, .size32));
    try testing.expect(isValidShiftAmount(31, .size32));

    // Invalid shift amounts for 32-bit registers
    try testing.expect(!isValidShiftAmount(32, .size32));
    try testing.expect(!isValidShiftAmount(33, .size32));
    try testing.expect(!isValidShiftAmount(63, .size32));
    try testing.expect(!isValidShiftAmount(64, .size32));
    try testing.expect(!isValidShiftAmount(100, .size32));
}

test "shift amount validation 64-bit" {
    // Valid shift amounts for 64-bit registers
    try testing.expect(isValidShiftAmount(0, .size64));
    try testing.expect(isValidShiftAmount(1, .size64));
    try testing.expect(isValidShiftAmount(31, .size64));
    try testing.expect(isValidShiftAmount(32, .size64));
    try testing.expect(isValidShiftAmount(63, .size64));

    // Invalid shift amounts for 64-bit registers
    try testing.expect(!isValidShiftAmount(64, .size64));
    try testing.expect(!isValidShiftAmount(65, .size64));
    try testing.expect(!isValidShiftAmount(100, .size64));
}

test "normalize shift amount 32-bit" {
    // In-range values remain unchanged
    try testing.expectEqual(@as(u8, 0), normalizeShiftAmount(0, .size32));
    try testing.expectEqual(@as(u8, 1), normalizeShiftAmount(1, .size32));
    try testing.expectEqual(@as(u8, 15), normalizeShiftAmount(15, .size32));
    try testing.expectEqual(@as(u8, 31), normalizeShiftAmount(31, .size32));

    // Out-of-range values wrap modulo 32
    try testing.expectEqual(@as(u8, 0), normalizeShiftAmount(32, .size32));
    try testing.expectEqual(@as(u8, 1), normalizeShiftAmount(33, .size32));
    try testing.expectEqual(@as(u8, 0), normalizeShiftAmount(64, .size32));
    try testing.expectEqual(@as(u8, 4), normalizeShiftAmount(100, .size32));
}

test "normalize shift amount 64-bit" {
    // In-range values remain unchanged
    try testing.expectEqual(@as(u8, 0), normalizeShiftAmount(0, .size64));
    try testing.expectEqual(@as(u8, 1), normalizeShiftAmount(1, .size64));
    try testing.expectEqual(@as(u8, 31), normalizeShiftAmount(31, .size64));
    try testing.expectEqual(@as(u8, 32), normalizeShiftAmount(32, .size64));
    try testing.expectEqual(@as(u8, 63), normalizeShiftAmount(63, .size64));

    // Out-of-range values wrap modulo 64
    try testing.expectEqual(@as(u8, 0), normalizeShiftAmount(64, .size64));
    try testing.expectEqual(@as(u8, 1), normalizeShiftAmount(65, .size64));
    try testing.expectEqual(@as(u8, 0), normalizeShiftAmount(128, .size64));
    try testing.expectEqual(@as(u8, 36), normalizeShiftAmount(100, .size64));
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

    // MUL
    const mul = Inst{ .mul_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    var buf: [64]u8 = undefined;
    var str = try std.fmt.bufPrint(&buf, "{}", .{mul});
    try testing.expect(std.mem.indexOf(u8, str, "mul") != null);

    // MADD
    const madd = Inst{ .madd = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .addend = r3,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{madd});
    try testing.expect(std.mem.indexOf(u8, str, "madd") != null);

    // MSUB
    const msub = Inst{ .msub = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .subtrahend = r3,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{msub});
    try testing.expect(std.mem.indexOf(u8, str, "msub") != null);

    // SMULH
    const smulh = Inst{ .smulh = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{smulh});
    try testing.expect(std.mem.indexOf(u8, str, "smulh") != null);

    // UMULH
    const umulh = Inst{ .umulh = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{umulh});
    try testing.expect(std.mem.indexOf(u8, str, "umulh") != null);

    // SMULL
    const smull = Inst{ .smull = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{smull});
    try testing.expect(std.mem.indexOf(u8, str, "smull") != null);

    // UMULL
    const umull = Inst{ .umull = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{umull});
    try testing.expect(std.mem.indexOf(u8, str, "umull") != null);
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
    var str: []u8 = undefined;

    // AND register-register (64-bit)
    const and_rr_64 = Inst{ .and_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{and_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "and") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // AND register-register (32-bit)
    const and_rr_32 = Inst{ .and_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{and_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "and") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // AND immediate
    const and_imm = Inst{ .and_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = .{ .value = 0xff, .n = false, .r = 0, .s = 7, .size = .size64 },
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{and_imm});
    try testing.expect(std.mem.indexOf(u8, str, "and") != null);
    try testing.expect(std.mem.indexOf(u8, str, "0xff") != null);

    // ORR register-register (64-bit)
    const orr_rr = Inst{ .orr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{orr_rr});
    try testing.expect(std.mem.indexOf(u8, str, "orr") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // ORR immediate
    const orr_imm = Inst{ .orr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = .{ .value = 0xf0f0, .n = false, .r = 0, .s = 15, .size = .size64 },
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{orr_imm});
    try testing.expect(std.mem.indexOf(u8, str, "orr") != null);
    try testing.expect(std.mem.indexOf(u8, str, "0xf0f0") != null);

    // EOR register-register (64-bit)
    const eor_rr = Inst{ .eor_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{eor_rr});
    try testing.expect(std.mem.indexOf(u8, str, "eor") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // EOR immediate
    const eor_imm = Inst{ .eor_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = .{ .value = 0xaaaa, .n = false, .r = 0, .s = 15, .size = .size32 },
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{eor_imm});
    try testing.expect(std.mem.indexOf(u8, str, "eor") != null);
    try testing.expect(std.mem.indexOf(u8, str, "0xaaaa") != null);

    // MVN (bitwise NOT) 64-bit
    const mvn_rr = Inst{ .mvn_rr = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{mvn_rr});
    try testing.expect(std.mem.indexOf(u8, str, "mvn") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);
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
    str = try std.fmt.bufPrint(&buf, "{}", .{lsl_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "lsl") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // LSL register-register (64-bit)
    const lsl_rr_64 = Inst{ .lsl_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{lsl_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "lsl") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // LSL immediate (32-bit)
    const lsl_imm_32 = Inst{ .lsl_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{lsl_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "lsl") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#5") != null);

    // LSL immediate (64-bit)
    const lsl_imm_64 = Inst{ .lsl_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 42,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{lsl_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "lsl") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#42") != null);

    // LSR register-register (32-bit)
    const lsr_rr_32 = Inst{ .lsr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{lsr_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "lsr") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // LSR register-register (64-bit)
    const lsr_rr_64 = Inst{ .lsr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{lsr_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "lsr") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // LSR immediate (32-bit)
    const lsr_imm_32 = Inst{ .lsr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 13,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{lsr_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "lsr") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#13") != null);

    // LSR immediate (64-bit)
    const lsr_imm_64 = Inst{ .lsr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 57,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{lsr_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "lsr") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#57") != null);

    // ASR register-register (32-bit)
    const asr_rr_32 = Inst{ .asr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{asr_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "asr") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // ASR register-register (64-bit)
    const asr_rr_64 = Inst{ .asr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{asr_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "asr") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // ASR immediate (32-bit)
    const asr_imm_32 = Inst{ .asr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 7,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{asr_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "asr") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#7") != null);

    // ASR immediate (64-bit)
    const asr_imm_64 = Inst{ .asr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 35,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{asr_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "asr") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#35") != null);

    // ROR register-register (32-bit)
    const ror_rr_32 = Inst{ .ror_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{ror_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "ror") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // ROR register-register (64-bit)
    const ror_rr_64 = Inst{ .ror_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{ror_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "ror") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // ROR immediate (32-bit)
    const ror_imm_32 = Inst{ .ror_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 24,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{ror_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "ror") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#24") != null);

    // ROR immediate (64-bit)
    const ror_imm_64 = Inst{ .ror_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 16,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{ror_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "ror") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#16") != null);
}

test "Comparison instruction formatting" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    var buf: [128]u8 = undefined;
    var str: []u8 = undefined;

    // CMP register-register (32-bit)
    const cmp_rr_32 = Inst{ .cmp_rr = .{
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{cmp_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "cmp") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // CMP register-register (64-bit)
    const cmp_rr_64 = Inst{ .cmp_rr = .{
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{cmp_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "cmp") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // CMP immediate (32-bit)
    const cmp_imm_32 = Inst{ .cmp_imm = .{
        .src = r1,
        .imm = 42,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{cmp_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "cmp") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#42") != null);

    // CMP immediate (64-bit)
    const cmp_imm_64 = Inst{ .cmp_imm = .{
        .src = r1,
        .imm = 100,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{cmp_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "cmp") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#100") != null);

    // CMN register-register (32-bit)
    const cmn_rr_32 = Inst{ .cmn_rr = .{
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{cmn_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "cmn") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // CMN register-register (64-bit)
    const cmn_rr_64 = Inst{ .cmn_rr = .{
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{cmn_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "cmn") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // CMN immediate (32-bit)
    const cmn_imm_32 = Inst{ .cmn_imm = .{
        .src = r1,
        .imm = 17,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{cmn_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "cmn") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#17") != null);

    // CMN immediate (64-bit)
    const cmn_imm_64 = Inst{ .cmn_imm = .{
        .src = r1,
        .imm = 255,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{cmn_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "cmn") != null);
    try testing.expect(std.mem.indexOf(u8, str, "#255") != null);

    // TST register-register (32-bit)
    const tst_rr_32 = Inst{ .tst_rr = .{
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{tst_rr_32});
    try testing.expect(std.mem.indexOf(u8, str, "tst") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // TST register-register (64-bit)
    const tst_rr_64 = Inst{ .tst_rr = .{
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{tst_rr_64});
    try testing.expect(std.mem.indexOf(u8, str, "tst") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // TST immediate (32-bit)
    const tst_imm_32 = Inst{ .tst_imm = .{
        .src = r1,
        .imm = .{ .value = 0xf, .n = false, .r = 0, .s = 3, .size = .size32 },
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{tst_imm_32});
    try testing.expect(std.mem.indexOf(u8, str, "tst") != null);
    try testing.expect(std.mem.indexOf(u8, str, "0xf") != null);

    // TST immediate (64-bit)
    const tst_imm_64 = Inst{ .tst_imm = .{
        .src = r0,
        .imm = .{ .value = 0xff00, .n = false, .r = 0, .s = 15, .size = .size64 },
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{tst_imm_64});
    try testing.expect(std.mem.indexOf(u8, str, "tst") != null);
    try testing.expect(std.mem.indexOf(u8, str, "0xff00") != null);
}

test "Extend instruction formatting" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    var buf: [128]u8 = undefined;
    var str: []u8 = undefined;

    // SXTB 32-bit
    const sxtb_32 = Inst{ .sxtb = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{sxtb_32});
    try testing.expect(std.mem.indexOf(u8, str, "sxtb") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // SXTB 64-bit
    const sxtb_64 = Inst{ .sxtb = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{sxtb_64});
    try testing.expect(std.mem.indexOf(u8, str, "sxtb") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // SXTH 32-bit
    const sxth_32 = Inst{ .sxth = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{sxth_32});
    try testing.expect(std.mem.indexOf(u8, str, "sxth") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // SXTH 64-bit
    const sxth_64 = Inst{ .sxth = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{sxth_64});
    try testing.expect(std.mem.indexOf(u8, str, "sxth") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // SXTW (always 64-bit)
    const sxtw = Inst{ .sxtw = .{
        .dst = wr0,
        .src = r1,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{sxtw});
    try testing.expect(std.mem.indexOf(u8, str, "sxtw") != null);

    // UXTB 32-bit
    const uxtb_32 = Inst{ .uxtb = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{uxtb_32});
    try testing.expect(std.mem.indexOf(u8, str, "uxtb") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // UXTB 64-bit
    const uxtb_64 = Inst{ .uxtb = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{uxtb_64});
    try testing.expect(std.mem.indexOf(u8, str, "uxtb") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);

    // UXTH 32-bit
    const uxth_32 = Inst{ .uxth = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{uxth_32});
    try testing.expect(std.mem.indexOf(u8, str, "uxth") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".w") != null);

    // UXTH 64-bit
    const uxth_64 = Inst{ .uxth = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } };
    str = try std.fmt.bufPrint(&buf, "{}", .{uxth_64});
    try testing.expect(std.mem.indexOf(u8, str, "uxth") != null);
    try testing.expect(std.mem.indexOf(u8, str, ".x") != null);
}

test "isValidArithImm12: valid immediates" {
    // Zero
    try testing.expect(isValidArithImm12(0));

    // Small values (0-4095)
    try testing.expect(isValidArithImm12(1));
    try testing.expect(isValidArithImm12(42));
    try testing.expect(isValidArithImm12(4095));

    // Values with shift (multiples of 4096, up to 4095<<12)
    try testing.expect(isValidArithImm12(4096));
    try testing.expect(isValidArithImm12(8192));
    try testing.expect(isValidArithImm12(0xFFF000));
}

test "isValidArithImm12: invalid immediates" {
    // Just above 12-bit range
    try testing.expect(!isValidArithImm12(4096 + 1));

    // Too large for shifted encoding
    try testing.expect(!isValidArithImm12(0x1000000));

    // Not aligned to shift boundary
    try testing.expect(!isValidArithImm12(0x123001));
}

test "isValidLogicalImm: valid patterns" {
    // Alternating bits (64-bit)
    try testing.expect(isValidLogicalImm(0xAAAAAAAAAAAAAAAA, true));

    // Alternating bytes (64-bit)
    try testing.expect(isValidLogicalImm(0x00FF00FF00FF00FF, true));

    // Low byte mask (32-bit)
    try testing.expect(isValidLogicalImm(0xFF, false));

    // Repeating pattern (64-bit)
    try testing.expect(isValidLogicalImm(0x0F0F0F0F0F0F0F0F, true));
}

test "isValidLogicalImm: invalid patterns" {
    // All zeros (not encodable)
    try testing.expect(!isValidLogicalImm(0, true));
    try testing.expect(!isValidLogicalImm(0, false));

    // All ones (not encodable)
    try testing.expect(!isValidLogicalImm(0xFFFFFFFFFFFFFFFF, true));
    try testing.expect(!isValidLogicalImm(0xFFFFFFFF, false));

    // Non-repeating pattern (not encodable)
    try testing.expect(!isValidLogicalImm(0x123456789ABCDEF0, true));
}

test "isValidLoadStoreImm: byte access (size=1)" {
    // Valid byte offsets (0-4095)
    try testing.expect(isValidLoadStoreImm(0, 1));
    try testing.expect(isValidLoadStoreImm(1, 1));
    try testing.expect(isValidLoadStoreImm(4095, 1));

    // Invalid: negative
    try testing.expect(!isValidLoadStoreImm(-1, 1));

    // Invalid: too large
    try testing.expect(!isValidLoadStoreImm(4096, 1));
}

test "isValidLoadStoreImm: halfword access (size=2)" {
    // Valid halfword offsets (0, 2, 4, ..., 8190)
    try testing.expect(isValidLoadStoreImm(0, 2));
    try testing.expect(isValidLoadStoreImm(2, 2));
    try testing.expect(isValidLoadStoreImm(8190, 2));

    // Invalid: misaligned
    try testing.expect(!isValidLoadStoreImm(1, 2));
    try testing.expect(!isValidLoadStoreImm(3, 2));

    // Invalid: too large
    try testing.expect(!isValidLoadStoreImm(8192, 2));
}

test "isValidLoadStoreImm: word access (size=4)" {
    // Valid word offsets (0, 4, 8, ..., 16380)
    try testing.expect(isValidLoadStoreImm(0, 4));
    try testing.expect(isValidLoadStoreImm(4, 4));
    try testing.expect(isValidLoadStoreImm(16380, 4));

    // Invalid: misaligned
    try testing.expect(!isValidLoadStoreImm(1, 4));
    try testing.expect(!isValidLoadStoreImm(2, 4));

    // Invalid: too large
    try testing.expect(!isValidLoadStoreImm(16384, 4));
}

test "isValidLoadStoreImm: doubleword access (size=8)" {
    // Valid doubleword offsets (0, 8, 16, ..., 32760)
    try testing.expect(isValidLoadStoreImm(0, 8));
    try testing.expect(isValidLoadStoreImm(8, 8));
    try testing.expect(isValidLoadStoreImm(32760, 8));

    // Invalid: misaligned
    try testing.expect(!isValidLoadStoreImm(4, 8));
    try testing.expect(!isValidLoadStoreImm(12, 8));

    // Invalid: too large
    try testing.expect(!isValidLoadStoreImm(32768, 8));
}

test "isValidLoadStoreImm: invalid size" {
    // Invalid size (not power of 2)
    try testing.expect(!isValidLoadStoreImm(0, 3));
    try testing.expect(!isValidLoadStoreImm(0, 5));

    // Invalid size (too large)
    try testing.expect(!isValidLoadStoreImm(0, 16));

    // Invalid size (zero)
    try testing.expect(!isValidLoadStoreImm(0, 0));
}

test "isValidShiftAmount: 32-bit operands" {
    // Valid range (0-31)
    try testing.expect(isValidShiftAmount(0, .size32));
    try testing.expect(isValidShiftAmount(15, .size32));
    try testing.expect(isValidShiftAmount(31, .size32));

    // Invalid: too large
    try testing.expect(!isValidShiftAmount(32, .size32));
    try testing.expect(!isValidShiftAmount(63, .size32));
}

test "isValidShiftAmount: 64-bit operands" {
    // Valid range (0-63)
    try testing.expect(isValidShiftAmount(0, .size64));
    try testing.expect(isValidShiftAmount(31, .size64));
    try testing.expect(isValidShiftAmount(63, .size64));

    // Invalid: too large
    try testing.expect(!isValidShiftAmount(64, .size64));
    try testing.expect(!isValidShiftAmount(100, .size64));
}

test "Addressing mode: baseOnly" {
    const v0 = VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);

    const amode = baseOnly(r0);
    try testing.expectEqual(AMode.base_only, @as(std.meta.Tag(AMode), amode));
    try testing.expectEqual(r0, amode.base_only.base);
}

test "Addressing mode: baseOffset" {
    const v1 = VReg.new(1, .int);
    const r1 = Reg.fromVReg(v1);

    const amode = baseOffset(r1, 16);
    try testing.expectEqual(AMode.base_offset, @as(std.meta.Tag(AMode), amode));
    try testing.expectEqual(r1, amode.base_offset.base);
    try testing.expectEqual(@as(i16, 16), amode.base_offset.offset);

    const amode_neg = baseOffset(r1, -8);
    try testing.expectEqual(@as(i16, -8), amode_neg.base_offset.offset);
}

test "Addressing mode: baseIndex" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);

    const amode = baseIndex(r0, r1);
    try testing.expectEqual(AMode.base_index, @as(std.meta.Tag(AMode), amode));
    try testing.expectEqual(r0, amode.base_index.base);
    try testing.expectEqual(r1, amode.base_index.index);
}

test "Addressing mode: baseIndexShift" {
    const v2 = VReg.new(2, .int);
    const v3 = VReg.new(3, .int);
    const r2 = Reg.fromVReg(v2);
    const r3 = Reg.fromVReg(v3);

    const amode = baseIndexShift(r2, r3, 3);
    try testing.expectEqual(AMode.base_index_shift, @as(std.meta.Tag(AMode), amode));
    try testing.expectEqual(r2, amode.base_index_shift.base);
    try testing.expectEqual(r3, amode.base_index_shift.index);
    try testing.expectEqual(@as(u8, 3), amode.base_index_shift.shift);

    const amode_zero_shift = baseIndexShift(r2, r3, 0);
    try testing.expectEqual(@as(u8, 0), amode_zero_shift.base_index_shift.shift);
}

test "Addressing mode: preIndex" {
    const v4 = VReg.new(4, .int);
    const r4 = Reg.fromVReg(v4);
    const wr4 = WritableReg.fromReg(r4);

    const amode = preIndex(wr4, 32);
    try testing.expectEqual(AMode.pre_index, @as(std.meta.Tag(AMode), amode));
    try testing.expectEqual(wr4, amode.pre_index.base);
    try testing.expectEqual(@as(i16, 32), amode.pre_index.offset);

    const amode_neg = preIndex(wr4, -16);
    try testing.expectEqual(@as(i16, -16), amode_neg.pre_index.offset);
}

test "Addressing mode: postIndex" {
    const v5 = VReg.new(5, .int);
    const r5 = Reg.fromVReg(v5);
    const wr5 = WritableReg.fromReg(r5);

    const amode = postIndex(wr5, 24);
    try testing.expectEqual(AMode.post_index, @as(std.meta.Tag(AMode), amode));
    try testing.expectEqual(wr5, amode.post_index.base);
    try testing.expectEqual(@as(i16, 24), amode.post_index.offset);

    const amode_neg = postIndex(wr5, -12);
    try testing.expectEqual(@as(i16, -12), amode_neg.post_index.offset);
}

test "aarch64_and: register-register" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst64 = aarch64_and(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.and_rr, @as(std.meta.Tag(Inst), inst64));
    try testing.expectEqual(wr0, inst64.and_rr.dst);
    try testing.expectEqual(r1, inst64.and_rr.src1);
    try testing.expectEqual(r2, inst64.and_rr.src2);
    try testing.expectEqual(OperandSize.size64, inst64.and_rr.size);

    const inst32 = aarch64_and(wr0, r1, r2, .size32);
    try testing.expectEqual(OperandSize.size32, inst32.and_rr.size);
}

test "aarch64_and_imm: valid immediate" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst = aarch64_and_imm(wr0, r1, 0xAAAAAAAAAAAAAAAA, .size64);
    try testing.expect(inst != null);
    try testing.expectEqual(Inst.and_imm, @as(std.meta.Tag(Inst), inst.?));
    try testing.expectEqual(wr0, inst.?.and_imm.dst);
    try testing.expectEqual(r1, inst.?.and_imm.src);
    try testing.expectEqual(@as(u64, 0xAAAAAAAAAAAAAAAA), inst.?.and_imm.imm.value);
}

test "aarch64_and_imm: invalid immediate" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst = aarch64_and_imm(wr0, r1, 0, .size64);
    try testing.expectEqual(@as(?Inst, null), inst);

    const inst2 = aarch64_and_imm(wr0, r1, 0xFFFFFFFFFFFFFFFF, .size64);
    try testing.expectEqual(@as(?Inst, null), inst2);
}

test "aarch64_orr: register-register" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst64 = aarch64_orr(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.orr_rr, @as(std.meta.Tag(Inst), inst64));
    try testing.expectEqual(wr0, inst64.orr_rr.dst);
    try testing.expectEqual(r1, inst64.orr_rr.src1);
    try testing.expectEqual(r2, inst64.orr_rr.src2);
    try testing.expectEqual(OperandSize.size64, inst64.orr_rr.size);

    const inst32 = aarch64_orr(wr0, r1, r2, .size32);
    try testing.expectEqual(OperandSize.size32, inst32.orr_rr.size);
}

test "aarch64_orr_imm: valid immediate" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst = aarch64_orr_imm(wr0, r1, 0x00FF00FF00FF00FF, .size64);
    try testing.expect(inst != null);
    try testing.expectEqual(Inst.orr_imm, @as(std.meta.Tag(Inst), inst.?));
    try testing.expectEqual(wr0, inst.?.orr_imm.dst);
    try testing.expectEqual(r1, inst.?.orr_imm.src);
    try testing.expectEqual(@as(u64, 0x00FF00FF00FF00FF), inst.?.orr_imm.imm.value);
}

test "aarch64_orr_imm: invalid immediate" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst = aarch64_orr_imm(wr0, r1, 0, .size64);
    try testing.expectEqual(@as(?Inst, null), inst);
}

test "aarch64_eor: register-register" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst64 = aarch64_eor(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.eor_rr, @as(std.meta.Tag(Inst), inst64));
    try testing.expectEqual(wr0, inst64.eor_rr.dst);
    try testing.expectEqual(r1, inst64.eor_rr.src1);
    try testing.expectEqual(r2, inst64.eor_rr.src2);
    try testing.expectEqual(OperandSize.size64, inst64.eor_rr.size);

    const inst32 = aarch64_eor(wr0, r1, r2, .size32);
    try testing.expectEqual(OperandSize.size32, inst32.eor_rr.size);
}

test "aarch64_eor_imm: valid immediate" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst = aarch64_eor_imm(wr0, r1, 0x0F0F0F0F0F0F0F0F, .size64);
    try testing.expect(inst != null);
    try testing.expectEqual(Inst.eor_imm, @as(std.meta.Tag(Inst), inst.?));
    try testing.expectEqual(wr0, inst.?.eor_imm.dst);
    try testing.expectEqual(r1, inst.?.eor_imm.src);
    try testing.expectEqual(@as(u64, 0x0F0F0F0F0F0F0F0F), inst.?.eor_imm.imm.value);
}

test "aarch64_eor_imm: invalid immediate" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst = aarch64_eor_imm(wr0, r1, 0xFFFFFFFFFFFFFFFF, .size64);
    try testing.expectEqual(@as(?Inst, null), inst);
}

test "aarch64_bic: register-register" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst64 = aarch64_bic(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.bic_rr, @as(std.meta.Tag(Inst), inst64));
    try testing.expectEqual(wr0, inst64.bic_rr.dst);
    try testing.expectEqual(r1, inst64.bic_rr.src1);
    try testing.expectEqual(r2, inst64.bic_rr.src2);
    try testing.expectEqual(OperandSize.size64, inst64.bic_rr.size);

    const inst32 = aarch64_bic(wr0, r1, r2, .size32);
    try testing.expectEqual(OperandSize.size32, inst32.bic_rr.size);
}

test "aarch64_csel constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst64 = aarch64_csel(wr0, r1, r2, .eq, .size64);
    try testing.expectEqual(Inst.csel, @as(std.meta.Tag(Inst), inst64));
    try testing.expectEqual(wr0, inst64.csel.dst);
    try testing.expectEqual(r1, inst64.csel.src1);
    try testing.expectEqual(r2, inst64.csel.src2);
    try testing.expectEqual(CondCode.eq, inst64.csel.cond);
    try testing.expectEqual(OperandSize.size64, inst64.csel.size);

    const inst32 = aarch64_csel(wr0, r1, r2, .ne, .size32);
    try testing.expectEqual(CondCode.ne, inst32.csel.cond);
    try testing.expectEqual(OperandSize.size32, inst32.csel.size);
}

test "aarch64_csinc constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst64 = aarch64_csinc(wr0, r1, r2, .hs, .size64);
    try testing.expectEqual(Inst.csinc, @as(std.meta.Tag(Inst), inst64));
    try testing.expectEqual(wr0, inst64.csinc.dst);
    try testing.expectEqual(r1, inst64.csinc.src1);
    try testing.expectEqual(r2, inst64.csinc.src2);
    try testing.expectEqual(CondCode.hs, inst64.csinc.cond);
    try testing.expectEqual(OperandSize.size64, inst64.csinc.size);

    const inst32 = aarch64_csinc(wr0, r1, r2, .lo, .size32);
    try testing.expectEqual(CondCode.lo, inst32.csinc.cond);
    try testing.expectEqual(OperandSize.size32, inst32.csinc.size);
}

test "aarch64_csinv constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst64 = aarch64_csinv(wr0, r1, r2, .mi, .size64);
    try testing.expectEqual(Inst.csinv, @as(std.meta.Tag(Inst), inst64));
    try testing.expectEqual(wr0, inst64.csinv.dst);
    try testing.expectEqual(r1, inst64.csinv.src1);
    try testing.expectEqual(r2, inst64.csinv.src2);
    try testing.expectEqual(CondCode.mi, inst64.csinv.cond);
    try testing.expectEqual(OperandSize.size64, inst64.csinv.size);

    const inst32 = aarch64_csinv(wr0, r1, r2, .pl, .size32);
    try testing.expectEqual(CondCode.pl, inst32.csinv.cond);
    try testing.expectEqual(OperandSize.size32, inst32.csinv.size);
}

test "aarch64_csneg constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst64 = aarch64_csneg(wr0, r1, r2, .vs, .size64);
    try testing.expectEqual(Inst.csneg, @as(std.meta.Tag(Inst), inst64));
    try testing.expectEqual(wr0, inst64.csneg.dst);
    try testing.expectEqual(r1, inst64.csneg.src1);
    try testing.expectEqual(r2, inst64.csneg.src2);
    try testing.expectEqual(CondCode.vs, inst64.csneg.cond);
    try testing.expectEqual(OperandSize.size64, inst64.csneg.size);

    const inst32 = aarch64_csneg(wr0, r1, r2, .vc, .size32);
    try testing.expectEqual(CondCode.vc, inst32.csneg.cond);
    try testing.expectEqual(OperandSize.size32, inst32.csneg.size);
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

    const inst_64 = aarch64_asr(wr0, r1, 35, .size64);
    try testing.expectEqual(Inst.asr_imm, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(@as(u8, 35), inst_64.asr_imm.imm);
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

test "aarch64_ldr_imm constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst_64 = aarch64_ldr_imm(wr0, r1, 16, .size64);
    try testing.expectEqual(Inst.ldr, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(wr0, inst_64.ldr.dst);
    try testing.expectEqual(r1, inst_64.ldr.base);
    try testing.expectEqual(@as(i16, 16), inst_64.ldr.offset);
    try testing.expectEqual(OperandSize.size64, inst_64.ldr.size);

    const inst_32 = aarch64_ldr_imm(wr0, r1, -8, .size32);
    try testing.expectEqual(Inst.ldr, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(@as(i16, -8), inst_32.ldr.offset);
    try testing.expectEqual(OperandSize.size32, inst_32.ldr.size);
}

test "aarch64_ldr_reg constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    const inst_64 = aarch64_ldr_reg(wr0, r1, r2, .size64);
    try testing.expectEqual(Inst.ldr_reg, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(wr0, inst_64.ldr_reg.dst);
    try testing.expectEqual(r1, inst_64.ldr_reg.base);
    try testing.expectEqual(r2, inst_64.ldr_reg.offset);
    try testing.expectEqual(OperandSize.size64, inst_64.ldr_reg.size);

    const inst_32 = aarch64_ldr_reg(wr0, r1, r2, .size32);
    try testing.expectEqual(Inst.ldr_reg, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(OperandSize.size32, inst_32.ldr_reg.size);
}

test "aarch64_ldr_pair constructor" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);
    const wr1 = WritableReg.fromReg(r1);

    const inst_64 = aarch64_ldr_pair(wr0, wr1, r2, 16, .size64);
    try testing.expectEqual(Inst.ldp, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(wr0, inst_64.ldp.dst1);
    try testing.expectEqual(wr1, inst_64.ldp.dst2);
    try testing.expectEqual(r2, inst_64.ldp.base);
    try testing.expectEqual(@as(i16, 16), inst_64.ldp.offset);
    try testing.expectEqual(OperandSize.size64, inst_64.ldp.size);

    const inst_32 = aarch64_ldr_pair(wr0, wr1, r2, -8, .size32);
    try testing.expectEqual(Inst.ldp, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(@as(i16, -8), inst_32.ldp.offset);
    try testing.expectEqual(OperandSize.size32, inst_32.ldp.size);
}

test "aarch64_ldr_literal constructor" {
    const v0 = VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = WritableReg.fromReg(r0);

    const inst_64 = aarch64_ldr_literal(wr0, 42, .size64);
    try testing.expectEqual(Inst.ldr_literal, @as(std.meta.Tag(Inst), inst_64));
    try testing.expectEqual(wr0, inst_64.ldr_literal.dst);
    try testing.expectEqual(@as(u32, 42), inst_64.ldr_literal.label);
    try testing.expectEqual(OperandSize.size64, inst_64.ldr_literal.size);

    const inst_32 = aarch64_ldr_literal(wr0, 123, .size32);
    try testing.expectEqual(Inst.ldr_literal, @as(std.meta.Tag(Inst), inst_32));
    try testing.expectEqual(@as(u32, 123), inst_32.ldr_literal.label);
    try testing.expectEqual(OperandSize.size32, inst_32.ldr_literal.size);
}
