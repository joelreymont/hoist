//! Register definitions for x64.
//!
//! We define 16 GPRs, with indices equal to the hardware encoding,
//! and 16 XMM registers.

const std = @import("std");
const Reg = @import("../../machinst/reg.zig").Reg;
const PReg = @import("../../machinst/reg.zig").PReg;
const RegClass = @import("../../machinst/reg.zig").RegClass;

// Hardware encodings for GPRs
pub const GPR = struct {
    pub const RAX: u8 = 0;
    pub const RCX: u8 = 1;
    pub const RDX: u8 = 2;
    pub const RBX: u8 = 3;
    pub const RSP: u8 = 4;
    pub const RBP: u8 = 5;
    pub const RSI: u8 = 6;
    pub const RDI: u8 = 7;
    pub const R8: u8 = 8;
    pub const R9: u8 = 9;
    pub const R10: u8 = 10;
    pub const R11: u8 = 11;
    pub const R12: u8 = 12;
    pub const R13: u8 = 13;
    pub const R14: u8 = 14;
    pub const R15: u8 = 15;
};

// Hardware encodings for XMM registers
pub const XMM = struct {
    pub const XMM0: u8 = 0;
    pub const XMM1: u8 = 1;
    pub const XMM2: u8 = 2;
    pub const XMM3: u8 = 3;
    pub const XMM4: u8 = 4;
    pub const XMM5: u8 = 5;
    pub const XMM6: u8 = 6;
    pub const XMM7: u8 = 7;
    pub const XMM8: u8 = 8;
    pub const XMM9: u8 = 9;
    pub const XMM10: u8 = 10;
    pub const XMM11: u8 = 11;
    pub const XMM12: u8 = 12;
    pub const XMM13: u8 = 13;
    pub const XMM14: u8 = 14;
    pub const XMM15: u8 = 15;
};

// Constructors for GPRs

pub fn gprPreg(enc: u8) PReg {
    return PReg.init(enc, .int);
}

pub fn gpr(enc: u8) Reg {
    const preg = gprPreg(enc);
    return Reg.fromVirtualReg(preg.index(), .int);
}

pub fn rax() Reg {
    return gpr(GPR.RAX);
}

pub fn rcx() Reg {
    return gpr(GPR.RCX);
}

pub fn rdx() Reg {
    return gpr(GPR.RDX);
}

pub fn rbx() Reg {
    return gpr(GPR.RBX);
}

pub fn rsp() Reg {
    return gpr(GPR.RSP);
}

pub fn rbp() Reg {
    return gpr(GPR.RBP);
}

pub fn rsi() Reg {
    return gpr(GPR.RSI);
}

pub fn rdi() Reg {
    return gpr(GPR.RDI);
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

/// The pinned register on this architecture.
/// It must be the same as Spidermonkey's HeapReg.
/// https://searchfox.org/mozilla-central/source/js/src/jit/x64/Assembler-x64.h#99
pub fn pinnedReg() Reg {
    return r15();
}

// Constructors for XMM registers

pub fn fprPreg(enc: u8) PReg {
    return PReg.init(enc, .float);
}

pub fn fpr(enc: u8) Reg {
    const preg = fprPreg(enc);
    return Reg.fromVirtualReg(preg.index(), .float);
}

pub fn xmm0() Reg {
    return fpr(XMM.XMM0);
}

pub fn xmm1() Reg {
    return fpr(XMM.XMM1);
}

pub fn xmm2() Reg {
    return fpr(XMM.XMM2);
}

pub fn xmm3() Reg {
    return fpr(XMM.XMM3);
}

pub fn xmm4() Reg {
    return fpr(XMM.XMM4);
}

pub fn xmm5() Reg {
    return fpr(XMM.XMM5);
}

pub fn xmm6() Reg {
    return fpr(XMM.XMM6);
}

pub fn xmm7() Reg {
    return fpr(XMM.XMM7);
}

pub fn xmm8() Reg {
    return fpr(XMM.XMM8);
}

pub fn xmm9() Reg {
    return fpr(XMM.XMM9);
}

pub fn xmm10() Reg {
    return fpr(XMM.XMM10);
}

pub fn xmm11() Reg {
    return fpr(XMM.XMM11);
}

pub fn xmm12() Reg {
    return fpr(XMM.XMM12);
}

pub fn xmm13() Reg {
    return fpr(XMM.XMM13);
}

pub fn xmm14() Reg {
    return fpr(XMM.XMM14);
}

pub fn xmm15() Reg {
    return fpr(XMM.XMM15);
}

// Register size for pretty-printing
pub const Size = enum(u8) {
    byte = 1,
    word = 2,
    dword = 4,
    qword = 8,
};

/// Pretty-print a register with a given size.
/// This is x64-specific and handles size suffixes for narrower widths.
pub fn prettyPrint(reg: Reg, size: Size, writer: anytype) !void {
    if (reg.toRealReg()) |rreg| {
        const enc = rreg.hwEnc();
        switch (rreg.class()) {
            .int => {
                const name = gprName(enc, size);
                try writer.writeAll(name);
            },
            .float => {
                try writer.print("xmm{}", .{enc});
            },
            .vector => unreachable,
        }
    } else {
        try writer.print("%v{}", .{reg.virtualReg()});
        // Add size suffixes to GPR virtual registers at narrower widths
        if (reg.class() == .int and size != .qword) {
            const suffix: []const u8 = switch (size) {
                .dword => "l",
                .word => "w",
                .byte => "b",
                .qword => unreachable,
            };
            try writer.writeAll(suffix);
        }
    }
}

fn gprName(enc: u8, size: Size) []const u8 {
    return switch (size) {
        .qword => switch (enc) {
            GPR.RAX => "rax",
            GPR.RCX => "rcx",
            GPR.RDX => "rdx",
            GPR.RBX => "rbx",
            GPR.RSP => "rsp",
            GPR.RBP => "rbp",
            GPR.RSI => "rsi",
            GPR.RDI => "rdi",
            GPR.R8 => "r8",
            GPR.R9 => "r9",
            GPR.R10 => "r10",
            GPR.R11 => "r11",
            GPR.R12 => "r12",
            GPR.R13 => "r13",
            GPR.R14 => "r14",
            GPR.R15 => "r15",
            else => unreachable,
        },
        .dword => switch (enc) {
            GPR.RAX => "eax",
            GPR.RCX => "ecx",
            GPR.RDX => "edx",
            GPR.RBX => "ebx",
            GPR.RSP => "esp",
            GPR.RBP => "ebp",
            GPR.RSI => "esi",
            GPR.RDI => "edi",
            GPR.R8 => "r8d",
            GPR.R9 => "r9d",
            GPR.R10 => "r10d",
            GPR.R11 => "r11d",
            GPR.R12 => "r12d",
            GPR.R13 => "r13d",
            GPR.R14 => "r14d",
            GPR.R15 => "r15d",
            else => unreachable,
        },
        .word => switch (enc) {
            GPR.RAX => "ax",
            GPR.RCX => "cx",
            GPR.RDX => "dx",
            GPR.RBX => "bx",
            GPR.RSP => "sp",
            GPR.RBP => "bp",
            GPR.RSI => "si",
            GPR.RDI => "di",
            GPR.R8 => "r8w",
            GPR.R9 => "r9w",
            GPR.R10 => "r10w",
            GPR.R11 => "r11w",
            GPR.R12 => "r12w",
            GPR.R13 => "r13w",
            GPR.R14 => "r14w",
            GPR.R15 => "r15w",
            else => unreachable,
        },
        .byte => switch (enc) {
            GPR.RAX => "al",
            GPR.RCX => "cl",
            GPR.RDX => "dl",
            GPR.RBX => "bl",
            GPR.RSP => "spl",
            GPR.RBP => "bpl",
            GPR.RSI => "sil",
            GPR.RDI => "dil",
            GPR.R8 => "r8b",
            GPR.R9 => "r9b",
            GPR.R10 => "r10b",
            GPR.R11 => "r11b",
            GPR.R12 => "r12b",
            GPR.R13 => "r13b",
            GPR.R14 => "r14b",
            GPR.R15 => "r15b",
            else => unreachable,
        },
    };
}
