//! Register definitions for RISC-V 64-bit.
//!
//! Defines 32 GPRs (x0-x31) and 32 FPRs (f0-f31) with standard ABI names.

const std = @import("std");
const Reg = @import("../../machinst/reg.zig").Reg;
const PReg = @import("../../machinst/reg.zig").PReg;
const RegClass = @import("../../machinst/reg.zig").RegClass;

// Hardware encodings for GPRs (x0-x31)
pub const GPR = struct {
    pub const ZERO: u8 = 0; // x0: hardwired zero
    pub const RA: u8 = 1; // x1: return address
    pub const SP: u8 = 2; // x2: stack pointer
    pub const GP: u8 = 3; // x3: global pointer
    pub const TP: u8 = 4; // x4: thread pointer
    pub const T0: u8 = 5; // x5: temp 0
    pub const T1: u8 = 6; // x6: temp 1
    pub const T2: u8 = 7; // x7: temp 2
    pub const S0: u8 = 8; // x8: saved / frame pointer
    pub const FP: u8 = 8; // x8: frame pointer alias
    pub const S1: u8 = 9; // x9: saved 1
    pub const A0: u8 = 10; // x10: arg/return 0
    pub const A1: u8 = 11; // x11: arg/return 1
    pub const A2: u8 = 12; // x12: arg 2
    pub const A3: u8 = 13; // x13: arg 3
    pub const A4: u8 = 14; // x14: arg 4
    pub const A5: u8 = 15; // x15: arg 5
    pub const A6: u8 = 16; // x16: arg 6
    pub const A7: u8 = 17; // x17: arg 7
    pub const S2: u8 = 18; // x18: saved 2
    pub const S3: u8 = 19; // x19: saved 3
    pub const S4: u8 = 20; // x20: saved 4
    pub const S5: u8 = 21; // x21: saved 5
    pub const S6: u8 = 22; // x22: saved 6
    pub const S7: u8 = 23; // x23: saved 7
    pub const S8: u8 = 24; // x24: saved 8
    pub const S9: u8 = 25; // x25: saved 9
    pub const S10: u8 = 26; // x26: saved 10
    pub const S11: u8 = 27; // x27: saved 11
    pub const T3: u8 = 28; // x28: temp 3
    pub const T4: u8 = 29; // x29: temp 4
    pub const T5: u8 = 30; // x30: temp 5
    pub const T6: u8 = 31; // x31: temp 6
};

// Hardware encodings for FPRs (f0-f31)
pub const FPR = struct {
    pub const FT0: u8 = 0; // f0: temp 0
    pub const FT1: u8 = 1; // f1: temp 1
    pub const FT2: u8 = 2; // f2: temp 2
    pub const FT3: u8 = 3; // f3: temp 3
    pub const FT4: u8 = 4; // f4: temp 4
    pub const FT5: u8 = 5; // f5: temp 5
    pub const FT6: u8 = 6; // f6: temp 6
    pub const FT7: u8 = 7; // f7: temp 7
    pub const FS0: u8 = 8; // f8: saved 0
    pub const FS1: u8 = 9; // f9: saved 1
    pub const FA0: u8 = 10; // f10: arg/return 0
    pub const FA1: u8 = 11; // f11: arg/return 1
    pub const FA2: u8 = 12; // f12: arg 2
    pub const FA3: u8 = 13; // f13: arg 3
    pub const FA4: u8 = 14; // f14: arg 4
    pub const FA5: u8 = 15; // f15: arg 5
    pub const FA6: u8 = 16; // f16: arg 6
    pub const FA7: u8 = 17; // f17: arg 7
    pub const FS2: u8 = 18; // f18: saved 2
    pub const FS3: u8 = 19; // f19: saved 3
    pub const FS4: u8 = 20; // f20: saved 4
    pub const FS5: u8 = 21; // f21: saved 5
    pub const FS6: u8 = 22; // f22: saved 6
    pub const FS7: u8 = 23; // f23: saved 7
    pub const FS8: u8 = 24; // f24: saved 8
    pub const FS9: u8 = 25; // f25: saved 9
    pub const FS10: u8 = 26; // f26: saved 10
    pub const FS11: u8 = 27; // f27: saved 11
    pub const FT8: u8 = 28; // f28: temp 8
    pub const FT9: u8 = 29; // f29: temp 9
    pub const FT10: u8 = 30; // f30: temp 10
    pub const FT11: u8 = 31; // f31: temp 11
};

// Constructors for GPRs

pub fn gprPreg(enc: u8) PReg {
    return PReg.new(.int, @intCast(enc));
}

pub fn gpr(enc: u8) Reg {
    const preg = gprPreg(enc);
    return Reg.fromPReg(preg);
}

pub fn zero() Reg {
    return gpr(GPR.ZERO);
}

pub fn ra() Reg {
    return gpr(GPR.RA);
}

pub fn sp() Reg {
    return gpr(GPR.SP);
}

pub fn gp() Reg {
    return gpr(GPR.GP);
}

pub fn tp() Reg {
    return gpr(GPR.TP);
}

pub fn t0() Reg {
    return gpr(GPR.T0);
}

pub fn t1() Reg {
    return gpr(GPR.T1);
}

pub fn t2() Reg {
    return gpr(GPR.T2);
}

pub fn s0() Reg {
    return gpr(GPR.S0);
}

pub fn fp() Reg {
    return gpr(GPR.FP);
}

pub fn s1() Reg {
    return gpr(GPR.S1);
}

pub fn a0() Reg {
    return gpr(GPR.A0);
}

pub fn a1() Reg {
    return gpr(GPR.A1);
}

pub fn a2() Reg {
    return gpr(GPR.A2);
}

pub fn a3() Reg {
    return gpr(GPR.A3);
}

pub fn a4() Reg {
    return gpr(GPR.A4);
}

pub fn a5() Reg {
    return gpr(GPR.A5);
}

pub fn a6() Reg {
    return gpr(GPR.A6);
}

pub fn a7() Reg {
    return gpr(GPR.A7);
}

pub fn s2() Reg {
    return gpr(GPR.S2);
}

pub fn s3() Reg {
    return gpr(GPR.S3);
}

pub fn s4() Reg {
    return gpr(GPR.S4);
}

pub fn s5() Reg {
    return gpr(GPR.S5);
}

pub fn s6() Reg {
    return gpr(GPR.S6);
}

pub fn s7() Reg {
    return gpr(GPR.S7);
}

pub fn s8() Reg {
    return gpr(GPR.S8);
}

pub fn s9() Reg {
    return gpr(GPR.S9);
}

pub fn s10() Reg {
    return gpr(GPR.S10);
}

pub fn s11() Reg {
    return gpr(GPR.S11);
}

pub fn t3() Reg {
    return gpr(GPR.T3);
}

pub fn t4() Reg {
    return gpr(GPR.T4);
}

pub fn t5() Reg {
    return gpr(GPR.T5);
}

pub fn t6() Reg {
    return gpr(GPR.T6);
}

// Constructors for FPRs

pub fn fprPreg(enc: u8) PReg {
    return PReg.init(enc, .float);
}

pub fn fpr(enc: u8) Reg {
    const preg = fprPreg(enc);
    return Reg.fromVirtualReg(preg.index(), .float);
}

pub fn ft0() Reg {
    return fpr(FPR.FT0);
}

pub fn ft1() Reg {
    return fpr(FPR.FT1);
}

pub fn ft2() Reg {
    return fpr(FPR.FT2);
}

pub fn ft3() Reg {
    return fpr(FPR.FT3);
}

pub fn ft4() Reg {
    return fpr(FPR.FT4);
}

pub fn ft5() Reg {
    return fpr(FPR.FT5);
}

pub fn ft6() Reg {
    return fpr(FPR.FT6);
}

pub fn ft7() Reg {
    return fpr(FPR.FT7);
}

pub fn fs0() Reg {
    return fpr(FPR.FS0);
}

pub fn fs1() Reg {
    return fpr(FPR.FS1);
}

pub fn fa0() Reg {
    return fpr(FPR.FA0);
}

pub fn fa1() Reg {
    return fpr(FPR.FA1);
}

pub fn fa2() Reg {
    return fpr(FPR.FA2);
}

pub fn fa3() Reg {
    return fpr(FPR.FA3);
}

pub fn fa4() Reg {
    return fpr(FPR.FA4);
}

pub fn fa5() Reg {
    return fpr(FPR.FA5);
}

pub fn fa6() Reg {
    return fpr(FPR.FA6);
}

pub fn fa7() Reg {
    return fpr(FPR.FA7);
}

pub fn fs2() Reg {
    return fpr(FPR.FS2);
}

pub fn fs3() Reg {
    return fpr(FPR.FS3);
}

pub fn fs4() Reg {
    return fpr(FPR.FS4);
}

pub fn fs5() Reg {
    return fpr(FPR.FS5);
}

pub fn fs6() Reg {
    return fpr(FPR.FS6);
}

pub fn fs7() Reg {
    return fpr(FPR.FS7);
}

pub fn fs8() Reg {
    return fpr(FPR.FS8);
}

pub fn fs9() Reg {
    return fpr(FPR.FS9);
}

pub fn fs10() Reg {
    return fpr(FPR.FS10);
}

pub fn fs11() Reg {
    return fpr(FPR.FS11);
}

pub fn ft8() Reg {
    return fpr(FPR.FT8);
}

pub fn ft9() Reg {
    return fpr(FPR.FT9);
}

pub fn ft10() Reg {
    return fpr(FPR.FT10);
}

pub fn ft11() Reg {
    return fpr(FPR.FT11);
}

/// Pretty-print a register.
pub fn prettyPrint(reg: Reg, writer: anytype) !void {
    if (reg.toRealReg()) |rreg| {
        const enc = rreg.hwEnc();
        switch (rreg.class()) {
            .int => {
                const name = gprName(enc);
                try writer.writeAll(name);
            },
            .float => {
                const name = fprName(enc);
                try writer.writeAll(name);
            },
            .vector => unreachable,
        }
    } else {
        try writer.print("%v{}", .{reg.virtualReg()});
    }
}

fn gprName(enc: u8) []const u8 {
    return switch (enc) {
        GPR.ZERO => "zero",
        GPR.RA => "ra",
        GPR.SP => "sp",
        GPR.GP => "gp",
        GPR.TP => "tp",
        GPR.T0 => "t0",
        GPR.T1 => "t1",
        GPR.T2 => "t2",
        GPR.S0 => "s0",
        GPR.S1 => "s1",
        GPR.A0 => "a0",
        GPR.A1 => "a1",
        GPR.A2 => "a2",
        GPR.A3 => "a3",
        GPR.A4 => "a4",
        GPR.A5 => "a5",
        GPR.A6 => "a6",
        GPR.A7 => "a7",
        GPR.S2 => "s2",
        GPR.S3 => "s3",
        GPR.S4 => "s4",
        GPR.S5 => "s5",
        GPR.S6 => "s6",
        GPR.S7 => "s7",
        GPR.S8 => "s8",
        GPR.S9 => "s9",
        GPR.S10 => "s10",
        GPR.S11 => "s11",
        GPR.T3 => "t3",
        GPR.T4 => "t4",
        GPR.T5 => "t5",
        GPR.T6 => "t6",
        else => unreachable,
    };
}

fn fprName(enc: u8) []const u8 {
    return switch (enc) {
        FPR.FT0 => "ft0",
        FPR.FT1 => "ft1",
        FPR.FT2 => "ft2",
        FPR.FT3 => "ft3",
        FPR.FT4 => "ft4",
        FPR.FT5 => "ft5",
        FPR.FT6 => "ft6",
        FPR.FT7 => "ft7",
        FPR.FS0 => "fs0",
        FPR.FS1 => "fs1",
        FPR.FA0 => "fa0",
        FPR.FA1 => "fa1",
        FPR.FA2 => "fa2",
        FPR.FA3 => "fa3",
        FPR.FA4 => "fa4",
        FPR.FA5 => "fa5",
        FPR.FA6 => "fa6",
        FPR.FA7 => "fa7",
        FPR.FS2 => "fs2",
        FPR.FS3 => "fs3",
        FPR.FS4 => "fs4",
        FPR.FS5 => "fs5",
        FPR.FS6 => "fs6",
        FPR.FS7 => "fs7",
        FPR.FS8 => "fs8",
        FPR.FS9 => "fs9",
        FPR.FS10 => "fs10",
        FPR.FS11 => "fs11",
        FPR.FT8 => "ft8",
        FPR.FT9 => "ft9",
        FPR.FT10 => "ft10",
        FPR.FT11 => "ft11",
        else => unreachable,
    };
}

test "gpr encoding" {
    const testing = std.testing;
    try testing.expectEqual(@as(u8, 0), GPR.ZERO);
    try testing.expectEqual(@as(u8, 1), GPR.RA);
    try testing.expectEqual(@as(u8, 2), GPR.SP);
    try testing.expectEqual(@as(u8, 10), GPR.A0);
    try testing.expectEqual(@as(u8, 31), GPR.T6);
}

test "fpr encoding" {
    const testing = std.testing;
    try testing.expectEqual(@as(u8, 0), FPR.FT0);
    try testing.expectEqual(@as(u8, 10), FPR.FA0);
    try testing.expectEqual(@as(u8, 31), FPR.FT11);
}

test "gpr construction" {
    const r = a0();
    try std.testing.expectEqual(RegClass.int, r.class());
}

test "fpr construction" {
    const r = fa0();
    try std.testing.expectEqual(RegClass.float, r.class());
}
