const std = @import("std");
const testing = std.testing;

const root = @import("root");
const reg_mod = root.reg;

pub const Reg = reg_mod.Reg;
pub const PReg = reg_mod.PReg;
pub const VReg = reg_mod.VReg;
pub const WritableReg = reg_mod.WritableReg;

/// RISC-V 64-bit machine instruction.
/// Covers RV64I base + M extension + F/D extensions (basic subset).
pub const Inst = union(enum) {
    // ============ RV64I Base Integer Instructions ============

    /// Add register to register.
    add: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Add immediate to register (12-bit signed immediate).
    addi: struct {
        dst: WritableReg,
        src: Reg,
        imm: i12,
    },

    /// Add word (32-bit add, sign-extend result).
    addw: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Add immediate word.
    addiw: struct {
        dst: WritableReg,
        src: Reg,
        imm: i12,
    },

    /// Subtract register from register.
    sub: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Subtract word.
    subw: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Shift left logical.
    sll: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Shift left logical immediate.
    slli: struct {
        dst: WritableReg,
        src: Reg,
        shamt: u6,
    },

    /// Shift left logical word.
    sllw: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Shift left logical immediate word.
    slliw: struct {
        dst: WritableReg,
        src: Reg,
        shamt: u5,
    },

    /// Shift right logical.
    srl: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Shift right logical immediate.
    srli: struct {
        dst: WritableReg,
        src: Reg,
        shamt: u6,
    },

    /// Shift right logical word.
    srlw: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Shift right logical immediate word.
    srliw: struct {
        dst: WritableReg,
        src: Reg,
        shamt: u5,
    },

    /// Shift right arithmetic.
    sra: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Shift right arithmetic immediate.
    srai: struct {
        dst: WritableReg,
        src: Reg,
        shamt: u6,
    },

    /// Shift right arithmetic word.
    sraw: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Shift right arithmetic immediate word.
    sraiw: struct {
        dst: WritableReg,
        src: Reg,
        shamt: u5,
    },

    /// Bitwise AND.
    @"and": struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Bitwise AND immediate.
    andi: struct {
        dst: WritableReg,
        src: Reg,
        imm: i12,
    },

    /// Bitwise OR.
    @"or": struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Bitwise OR immediate.
    ori: struct {
        dst: WritableReg,
        src: Reg,
        imm: i12,
    },

    /// Bitwise XOR.
    xor: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Bitwise XOR immediate.
    xori: struct {
        dst: WritableReg,
        src: Reg,
        imm: i12,
    },

    /// Set less than.
    slt: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Set less than immediate.
    slti: struct {
        dst: WritableReg,
        src: Reg,
        imm: i12,
    },

    /// Set less than unsigned.
    sltu: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Set less than unsigned immediate.
    sltiu: struct {
        dst: WritableReg,
        src: Reg,
        imm: i12,
    },

    /// Load upper immediate (20-bit immediate to upper bits).
    lui: struct {
        dst: WritableReg,
        imm: i32, // Actually i20, stored as i32
    },

    /// Add upper immediate to PC.
    auipc: struct {
        dst: WritableReg,
        imm: i32, // Actually i20, stored as i32
    },

    // ============ Load/Store Instructions ============

    /// Load byte (sign-extend).
    lb: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Load halfword (sign-extend).
    lh: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Load word (sign-extend).
    lw: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Load doubleword.
    ld: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Load byte unsigned (zero-extend).
    lbu: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Load halfword unsigned (zero-extend).
    lhu: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Load word unsigned (zero-extend).
    lwu: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Store byte.
    sb: struct {
        src: Reg,
        base: Reg,
        offset: i12,
    },

    /// Store halfword.
    sh: struct {
        src: Reg,
        base: Reg,
        offset: i12,
    },

    /// Store word.
    sw: struct {
        src: Reg,
        base: Reg,
        offset: i12,
    },

    /// Store doubleword.
    sd: struct {
        src: Reg,
        base: Reg,
        offset: i12,
    },

    // ============ Branch Instructions ============

    /// Branch if equal.
    beq: struct {
        src1: Reg,
        src2: Reg,
        offset: i13, // Actually 13-bit but shifted, stored as i13
    },

    /// Branch if not equal.
    bne: struct {
        src1: Reg,
        src2: Reg,
        offset: i13,
    },

    /// Branch if less than.
    blt: struct {
        src1: Reg,
        src2: Reg,
        offset: i13,
    },

    /// Branch if greater or equal.
    bge: struct {
        src1: Reg,
        src2: Reg,
        offset: i13,
    },

    /// Branch if less than unsigned.
    bltu: struct {
        src1: Reg,
        src2: Reg,
        offset: i13,
    },

    /// Branch if greater or equal unsigned.
    bgeu: struct {
        src1: Reg,
        src2: Reg,
        offset: i13,
    },

    // ============ Jump Instructions ============

    /// Jump and link (call).
    jal: struct {
        dst: WritableReg, // ra for call
        offset: i21, // Actually 21-bit but shifted
    },

    /// Jump and link register (indirect jump/return).
    jalr: struct {
        dst: WritableReg, // rd (x0 for pure jump)
        base: Reg, // rs1
        offset: i12,
    },

    // ============ RV64M Extension (Multiply/Divide) ============

    /// Multiply (lower 64 bits).
    mul: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Multiply high signed × signed.
    mulh: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Multiply high signed × unsigned.
    mulhsu: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Multiply high unsigned × unsigned.
    mulhu: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Multiply word (32-bit, sign-extend).
    mulw: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Divide signed.
    div: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Divide unsigned.
    divu: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Remainder signed.
    rem: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Remainder unsigned.
    remu: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Divide word signed.
    divw: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Divide word unsigned.
    divuw: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Remainder word signed.
    remw: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Remainder word unsigned.
    remuw: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    // ============ RV64F/D Extensions (Floating-Point) ============

    /// Load float word.
    flw: struct {
        dst: WritableReg, // FPR
        base: Reg, // GPR
        offset: i12,
    },

    /// Load float doubleword.
    fld: struct {
        dst: WritableReg, // FPR
        base: Reg, // GPR
        offset: i12,
    },

    /// Store float word.
    fsw: struct {
        src: Reg, // FPR
        base: Reg, // GPR
        offset: i12,
    },

    /// Store float doubleword.
    fsd: struct {
        src: Reg, // FPR
        base: Reg, // GPR
        offset: i12,
    },

    /// Floating-point add (single).
    fadd_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        rm: RoundingMode,
    },

    /// Floating-point add (double).
    fadd_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        rm: RoundingMode,
    },

    /// Floating-point subtract (single).
    fsub_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        rm: RoundingMode,
    },

    /// Floating-point subtract (double).
    fsub_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        rm: RoundingMode,
    },

    /// Floating-point multiply (single).
    fmul_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        rm: RoundingMode,
    },

    /// Floating-point multiply (double).
    fmul_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        rm: RoundingMode,
    },

    /// Floating-point divide (single).
    fdiv_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        rm: RoundingMode,
    },

    /// Floating-point divide (double).
    fdiv_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        rm: RoundingMode,
    },

    /// Floating-point square root (single).
    fsqrt_s: struct {
        dst: WritableReg,
        src: Reg,
        rm: RoundingMode,
    },

    /// Floating-point square root (double).
    fsqrt_d: struct {
        dst: WritableReg,
        src: Reg,
        rm: RoundingMode,
    },

    /// Floating-point min (single).
    fmin_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Floating-point min (double).
    fmin_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Floating-point max (single).
    fmax_s: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Floating-point max (double).
    fmax_d: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Floating-point equal (single).
    feq_s: struct {
        dst: WritableReg, // GPR
        src1: Reg, // FPR
        src2: Reg, // FPR
    },

    /// Floating-point equal (double).
    feq_d: struct {
        dst: WritableReg, // GPR
        src1: Reg, // FPR
        src2: Reg, // FPR
    },

    /// Floating-point less than (single).
    flt_s: struct {
        dst: WritableReg, // GPR
        src1: Reg, // FPR
        src2: Reg, // FPR
    },

    /// Floating-point less than (double).
    flt_d: struct {
        dst: WritableReg, // GPR
        src1: Reg, // FPR
        src2: Reg, // FPR
    },

    /// Floating-point less than or equal (single).
    fle_s: struct {
        dst: WritableReg, // GPR
        src1: Reg, // FPR
        src2: Reg, // FPR
    },

    /// Floating-point less than or equal (double).
    fle_d: struct {
        dst: WritableReg, // GPR
        src1: Reg, // FPR
        src2: Reg, // FPR
    },

    /// Move from float register to integer register (single).
    fmv_x_w: struct {
        dst: WritableReg, // GPR
        src: Reg, // FPR
    },

    /// Move from float register to integer register (double).
    fmv_x_d: struct {
        dst: WritableReg, // GPR
        src: Reg, // FPR
    },

    /// Move from integer register to float register (single).
    fmv_w_x: struct {
        dst: WritableReg, // FPR
        src: Reg, // GPR
    },

    /// Move from integer register to float register (double).
    fmv_d_x: struct {
        dst: WritableReg, // FPR
        src: Reg, // GPR
    },

    /// Convert float to signed integer (single to word).
    fcvt_w_s: struct {
        dst: WritableReg, // GPR
        src: Reg, // FPR
        rm: RoundingMode,
    },

    /// Convert float to signed integer (double to word).
    fcvt_w_d: struct {
        dst: WritableReg, // GPR
        src: Reg, // FPR
        rm: RoundingMode,
    },

    /// Convert float to unsigned integer (single to word).
    fcvt_wu_s: struct {
        dst: WritableReg, // GPR
        src: Reg, // FPR
        rm: RoundingMode,
    },

    /// Convert float to unsigned integer (double to word).
    fcvt_wu_d: struct {
        dst: WritableReg, // GPR
        src: Reg, // FPR
        rm: RoundingMode,
    },

    /// Convert float to signed long (single).
    fcvt_l_s: struct {
        dst: WritableReg, // GPR
        src: Reg, // FPR
        rm: RoundingMode,
    },

    /// Convert float to signed long (double).
    fcvt_l_d: struct {
        dst: WritableReg, // GPR
        src: Reg, // FPR
        rm: RoundingMode,
    },

    /// Convert float to unsigned long (single).
    fcvt_lu_s: struct {
        dst: WritableReg, // GPR
        src: Reg, // FPR
        rm: RoundingMode,
    },

    /// Convert float to unsigned long (double).
    fcvt_lu_d: struct {
        dst: WritableReg, // GPR
        src: Reg, // FPR
        rm: RoundingMode,
    },

    /// Convert signed integer to float (word to single).
    fcvt_s_w: struct {
        dst: WritableReg, // FPR
        src: Reg, // GPR
        rm: RoundingMode,
    },

    /// Convert signed integer to float (word to double).
    fcvt_d_w: struct {
        dst: WritableReg, // FPR
        src: Reg, // GPR
        rm: RoundingMode,
    },

    /// Convert unsigned integer to float (word to single).
    fcvt_s_wu: struct {
        dst: WritableReg, // FPR
        src: Reg, // GPR
        rm: RoundingMode,
    },

    /// Convert unsigned integer to float (word to double).
    fcvt_d_wu: struct {
        dst: WritableReg, // FPR
        src: Reg, // GPR
        rm: RoundingMode,
    },

    /// Convert signed long to float (single).
    fcvt_s_l: struct {
        dst: WritableReg, // FPR
        src: Reg, // GPR
        rm: RoundingMode,
    },

    /// Convert signed long to float (double).
    fcvt_d_l: struct {
        dst: WritableReg, // FPR
        src: Reg, // GPR
        rm: RoundingMode,
    },

    /// Convert unsigned long to float (single).
    fcvt_s_lu: struct {
        dst: WritableReg, // FPR
        src: Reg, // GPR
        rm: RoundingMode,
    },

    /// Convert unsigned long to float (double).
    fcvt_d_lu: struct {
        dst: WritableReg, // FPR
        src: Reg, // GPR
        rm: RoundingMode,
    },

    /// Convert single to double.
    fcvt_d_s: struct {
        dst: WritableReg, // FPR
        src: Reg, // FPR
        rm: RoundingMode,
    },

    /// Convert double to single.
    fcvt_s_d: struct {
        dst: WritableReg, // FPR
        src: Reg, // FPR
        rm: RoundingMode,
    },

    // ============ System Instructions ============

    /// Fence (memory ordering).
    fence: struct {
        pred: u4, // Predecessor set
        succ: u4, // Successor set
    },

    /// Fence instruction (synchronize instruction/data streams).
    fence_i,

    /// Environment call (system call).
    ecall,

    /// Environment break (debugger breakpoint).
    ebreak,

    /// Undefined/illegal instruction (trap).
    udf,

    // ============ RV64A Extension (Atomics) ============

    /// Load-reserved word.
    lr_w: struct {
        dst: WritableReg,
        addr: Reg,
        aq: bool, // Acquire
        rl: bool, // Release
    },

    /// Store-conditional word.
    sc_w: struct {
        dst: WritableReg, // Status (0 = success)
        src: Reg, // Value to store
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Load-reserved doubleword.
    lr_d: struct {
        dst: WritableReg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Store-conditional doubleword.
    sc_d: struct {
        dst: WritableReg, // Status
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic swap word.
    amoswap_w: struct {
        dst: WritableReg, // Old value
        src: Reg, // New value
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic add word.
    amoadd_w: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic XOR word.
    amoxor_w: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic AND word.
    amoand_w: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic OR word.
    amoor_w: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic min word (signed).
    amomin_w: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic max word (signed).
    amomax_w: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic min word (unsigned).
    amominu_w: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic max word (unsigned).
    amomaxu_w: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic swap doubleword.
    amoswap_d: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic add doubleword.
    amoadd_d: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic XOR doubleword.
    amoxor_d: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic AND doubleword.
    amoand_d: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic OR doubleword.
    amoor_d: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic min doubleword (signed).
    amomin_d: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic max doubleword (signed).
    amomax_d: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic min doubleword (unsigned).
    amominu_d: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    /// Atomic max doubleword (unsigned).
    amomaxu_d: struct {
        dst: WritableReg,
        src: Reg,
        addr: Reg,
        aq: bool,
        rl: bool,
    },

    // ============ Pseudo-instructions for codegen ============

    /// Move register (pseudo - implemented as addi rd, rs, 0).
    mv: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// Load immediate (pseudo - lui + addi for 32-bit constants).
    li: struct {
        dst: WritableReg,
        imm: i64,
    },

    /// Return from function (pseudo - jalr x0, ra, 0).
    ret,

    /// Call function (pseudo - jal ra, offset or auipc + jalr).
    call: struct {
        target: CallTarget,
    },

    /// No operation (pseudo - addi x0, x0, 0).
    nop,
};

/// Floating-point rounding mode.
pub const RoundingMode = enum(u3) {
    rne = 0b000, // Round to Nearest, ties to Even
    rtz = 0b001, // Round toward Zero
    rdn = 0b010, // Round Down
    rup = 0b011, // Round Up
    rmm = 0b100, // Round to Nearest, ties to Max Magnitude
    dyn = 0b111, // Dynamic (from fcsr)
};

/// Call target (for call pseudo-instruction).
pub const CallTarget = union(enum) {
    /// Direct call to PC-relative offset.
    direct: i32,
    /// Indirect call through register.
    indirect: Reg,
};

test "inst size" {
    // Ensure instruction union isn't too large
    const inst_size = @sizeOf(Inst);
    try testing.expect(inst_size <= 32);
}

test "rounding mode encoding" {
    try testing.expectEqual(@as(u3, 0b000), @intFromEnum(RoundingMode.rne));
    try testing.expectEqual(@as(u3, 0b111), @intFromEnum(RoundingMode.dyn));
}
