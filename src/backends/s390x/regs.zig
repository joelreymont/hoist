//! Register definitions for s390x z/Architecture.
//!
//! Defines 16 GPRs (r0-r15), 16 FPRs (f0-f15), and 16 access/control regs.

const std = @import("std");
const Reg = @import("../../machinst/reg.zig").Reg;
const PReg = @import("../../machinst/reg.zig").PReg;
const RegClass = @import("../../machinst/reg.zig").RegClass;

// Hardware encodings for GPRs (r0-r15)
pub const GPR = struct {
    pub const R0: u8 = 0; // r0: general purpose
    pub const R1: u8 = 1; // r1: general purpose
    pub const R2: u8 = 2; // r2: arg/return 0
    pub const R3: u8 = 3; // r3: arg/return 1
    pub const R4: u8 = 4; // r4: arg 2
    pub const R5: u8 = 5; // r5: arg 3
    pub const R6: u8 = 6; // r6: arg 4 / saved
    pub const R7: u8 = 7; // r7: saved
    pub const R8: u8 = 8; // r8: saved
    pub const R9: u8 = 9; // r9: saved
    pub const R10: u8 = 10; // r10: saved
    pub const R11: u8 = 11; // r11: saved
    pub const R12: u8 = 12; // r12: saved
    pub const R13: u8 = 13; // r13: saved / GOT ptr
    pub const R14: u8 = 14; // r14: link register
    pub const R15: u8 = 15; // r15: stack pointer
};

// Hardware encodings for FPRs (f0-f15)
pub const FPR = struct {
    pub const F0: u8 = 0; // f0: arg/return 0
    pub const F1: u8 = 1; // f1: general purpose
    pub const F2: u8 = 2; // f2: arg/return 1
    pub const F3: u8 = 3; // f3: general purpose
    pub const F4: u8 = 4; // f4: arg 2
    pub const F5: u8 = 5; // f5: general purpose
    pub const F6: u8 = 6; // f6: arg 3
    pub const F7: u8 = 7; // f7: general purpose
    pub const F8: u8 = 8; // f8: saved
    pub const F9: u8 = 9; // f9: saved
    pub const F10: u8 = 10; // f10: saved
    pub const F11: u8 = 11; // f11: saved
    pub const F12: u8 = 12; // f12: saved
    pub const F13: u8 = 13; // f13: saved
    pub const F14: u8 = 14; // f14: saved
    pub const F15: u8 = 15; // f15: saved
};

// Constructors for GPRs

pub fn gprPreg(enc: u8) PReg {
    return PReg.new(.int, @intCast(enc));
}

pub fn gpr(enc: u8) Reg {
    const preg = gprPreg(enc);
    return Reg.fromPReg(preg);
}

pub fn r0() Reg {
    return gpr(GPR.R0);
}

pub fn r1() Reg {
    return gpr(GPR.R1);
}

pub fn r2() Reg {
    return gpr(GPR.R2);
}

pub fn r3() Reg {
    return gpr(GPR.R3);
}

pub fn r4() Reg {
    return gpr(GPR.R4);
}

pub fn r5() Reg {
    return gpr(GPR.R5);
}

pub fn r6() Reg {
    return gpr(GPR.R6);
}

pub fn r7() Reg {
    return gpr(GPR.R7);
}

pub fn r8() Reg {
    return gpr(GPR.R8);
}

pub fn r9() Reg {
    return gpr(GPR.R9);
}

pub fn r10() Reg {
    return gpr(GPR.R10);
}

pub fn r11() Reg {
    return gpr(GPR.R11);
}

pub fn r12() Reg {
    return gpr(GPR.R12);
}

pub fn r13() Reg {
    return gpr(GPR.R13);
}

pub fn r14() Reg {
    return gpr(GPR.R14);
}

pub fn r15() Reg {
    return gpr(GPR.R15);
}

pub fn sp() Reg {
    return r15();
}

pub fn lr() Reg {
    return r14();
}

// Constructors for FPRs

pub fn fprPreg(enc: u8) PReg {
    return PReg.init(enc, .float);
}

pub fn fpr(enc: u8) Reg {
    const preg = fprPreg(enc);
    return Reg.fromVirtualReg(preg.index(), .float);
}

pub fn f0() Reg {
    return fpr(FPR.F0);
}

pub fn f1() Reg {
    return fpr(FPR.F1);
}

pub fn f2() Reg {
    return fpr(FPR.F2);
}

pub fn f3() Reg {
    return fpr(FPR.F3);
}

pub fn f4() Reg {
    return fpr(FPR.F4);
}

pub fn f5() Reg {
    return fpr(FPR.F5);
}

pub fn f6() Reg {
    return fpr(FPR.F6);
}

pub fn f7() Reg {
    return fpr(FPR.F7);
}

pub fn f8() Reg {
    return fpr(FPR.F8);
}

pub fn f9() Reg {
    return fpr(FPR.F9);
}

pub fn f10() Reg {
    return fpr(FPR.F10);
}

pub fn f11() Reg {
    return fpr(FPR.F11);
}

pub fn f12() Reg {
    return fpr(FPR.F12);
}

pub fn f13() Reg {
    return fpr(FPR.F13);
}

pub fn f14() Reg {
    return fpr(FPR.F14);
}

pub fn f15() Reg {
    return fpr(FPR.F15);
}

/// Pretty-print a register.
pub fn prettyPrint(reg: Reg, writer: anytype) !void {
    if (reg.toRealReg()) |rreg| {
        const enc = rreg.hwEnc();
        switch (rreg.class()) {
            .int => {
                try writer.print("r{}", .{enc});
            },
            .float => {
                try writer.print("f{}", .{enc});
            },
            .vector => unreachable,
        }
    } else {
        try writer.print("%v{}", .{reg.virtualReg()});
    }
}

test "gpr encoding" {
    const testing = std.testing;
    try testing.expectEqual(@as(u8, 0), GPR.R0);
    try testing.expectEqual(@as(u8, 2), GPR.R2);
    try testing.expectEqual(@as(u8, 14), GPR.R14);
    try testing.expectEqual(@as(u8, 15), GPR.R15);
}

test "fpr encoding" {
    const testing = std.testing;
    try testing.expectEqual(@as(u8, 0), FPR.F0);
    try testing.expectEqual(@as(u8, 2), FPR.F2);
    try testing.expectEqual(@as(u8, 15), FPR.F15);
}

test "gpr construction" {
    const r = r2();
    try std.testing.expectEqual(RegClass.int, r.class());
}

test "fpr construction" {
    const f = f0();
    try std.testing.expectEqual(RegClass.float, f.class());
}
