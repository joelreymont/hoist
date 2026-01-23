const std = @import("std");
const testing = std.testing;

const root = @import("root");
const reg_mod = @import("../../machinst/reg.zig");

pub const Reg = reg_mod.Reg;
pub const PReg = reg_mod.PReg;
pub const VReg = reg_mod.VReg;
pub const WritableReg = reg_mod.WritableReg;

/// s390x z/Architecture machine instruction.
/// Covers base integer, floating-point, and branch instructions.
pub const Inst = union(enum) {
    // ============ 64-bit ALU Instructions ============

    /// Add 64-bit register to register.
    agr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Add 64-bit immediate to register.
    agfi: struct {
        dst: WritableReg,
        src: Reg,
        imm: i32,
    },

    /// Add 64-bit halfword immediate.
    aghi: struct {
        dst: WritableReg,
        src: Reg,
        imm: i16,
    },

    /// Subtract 64-bit register from register.
    sgr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Subtract 64-bit fullword register.
    sgfr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Multiply 64-bit register.
    msgr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Multiply 64-bit halfword immediate.
    mghi: struct {
        dst: WritableReg,
        src: Reg,
        imm: i16,
    },

    /// Divide 64-bit signed.
    dsgr: struct {
        dst: WritableReg,
        src: Reg,
    },

    /// Divide 64-bit unsigned.
    dlgr: struct {
        dst: WritableReg,
        src: Reg,
    },

    // ============ Logical Instructions ============

    /// AND 64-bit.
    ngr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// OR 64-bit.
    ogr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// XOR 64-bit.
    xgr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    // ============ Shift/Rotate Instructions ============

    /// Shift left logical 64-bit.
    sllg: struct {
        dst: WritableReg,
        src: Reg,
        imm: u6,
    },

    /// Shift right logical 64-bit.
    srlg: struct {
        dst: WritableReg,
        src: Reg,
        imm: u6,
    },

    /// Shift right arithmetic 64-bit.
    srag: struct {
        dst: WritableReg,
        src: Reg,
        imm: u6,
    },

    /// Rotate left 64-bit.
    rllg: struct {
        dst: WritableReg,
        src: Reg,
        imm: u6,
    },

    // ============ Load/Store Instructions ============

    /// Load 64-bit.
    lg: struct {
        dst: WritableReg,
        base: Reg,
        offset: i20,
    },

    /// Load 64-bit halfword immediate.
    lghi: struct {
        dst: WritableReg,
        imm: i16,
    },

    /// Load fullword.
    l: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Load halfword.
    lh: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Load byte.
    lb: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Store 64-bit.
    stg: struct {
        src: Reg,
        base: Reg,
        offset: i20,
    },

    /// Store fullword.
    st: struct {
        src: Reg,
        base: Reg,
        offset: i12,
    },

    /// Store halfword.
    sth: struct {
        src: Reg,
        base: Reg,
        offset: i12,
    },

    /// Store byte.
    stc: struct {
        src: Reg,
        base: Reg,
        offset: i12,
    },

    // ============ Branch Instructions ============

    /// Branch relative on condition.
    brc: struct {
        mask: u4,
        offset: i16,
    },

    /// Branch relative and save.
    brasl: struct {
        link: WritableReg,
        offset: i32,
    },

    /// Branch and save register.
    basr: struct {
        link: WritableReg,
        target: Reg,
    },

    /// Branch on count register.
    bcr: struct {
        mask: u4,
        target: Reg,
    },

    // ============ Floating-Point Instructions ============

    /// Add 64-bit FP.
    adbr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Add 32-bit FP.
    aebr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Subtract 64-bit FP.
    sdbr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Subtract 32-bit FP.
    sebr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Multiply 64-bit FP.
    mdbr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Multiply 32-bit FP.
    meebr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Divide 64-bit FP.
    ddbr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Divide 32-bit FP.
    debr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
    },

    /// Load FP 64-bit.
    ld: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Load FP 32-bit.
    le: struct {
        dst: WritableReg,
        base: Reg,
        offset: i12,
    },

    /// Store FP 64-bit.
    std: struct {
        src: Reg,
        base: Reg,
        offset: i12,
    },

    /// Store FP 32-bit.
    ste: struct {
        src: Reg,
        base: Reg,
        offset: i12,
    },

    // ============ Pseudo Instructions ============

    /// Ret (uses BCR to r14).
    ret,

    /// Get operands for register allocation.
    pub fn getOperands(inst: *const Inst, alloc: std.mem.Allocator) !struct {
        uses: []const Reg,
        defs: []const WritableReg,
    } {
        _ = alloc;
        _ = inst;
        return .{ .uses = &.{}, .defs = &.{} };
    }
};

test "inst size" {
    try testing.expect(@sizeOf(Inst) <= 32);
}
