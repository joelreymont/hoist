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
    pub fn getOperands(self: *const Inst, collector: *OperandCollector) !void {
        switch (self.*) {
            // ALU instructions with 2 sources
            .agr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .sgr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .sgfr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .msgr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .ngr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .ogr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .xgr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            // ALU with immediate
            .agfi => |i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .aghi => |i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .mghi => |i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            // Divide (uses implicit register pair)
            .dsgr => |i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .dlgr => |i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            // Shifts/rotates
            .sllg => |i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .srlg => |i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .srag => |i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            .rllg => |i| {
                try collector.regUse(i.src);
                try collector.regDef(i.dst);
            },
            // Loads from memory
            .lg => |i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .l => |i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .lh => |i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .lb => |i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            // Load immediate
            .lghi => |i| {
                try collector.regDef(i.dst);
            },
            // Stores to memory
            .stg => |i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .st => |i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .sth => |i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .stc => |i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            // Branches
            .brc => {},
            .brasl => |i| {
                try collector.regDef(i.link);
            },
            .basr => |i| {
                try collector.regUse(i.target);
                try collector.regDef(i.link);
            },
            .bcr => |i| {
                try collector.regUse(i.target);
            },
            // FP ALU
            .adbr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .aebr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .sdbr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .sebr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .mdbr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .meebr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .ddbr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            .debr => |i| {
                try collector.regUse(i.src1);
                try collector.regUse(i.src2);
                try collector.regDef(i.dst);
            },
            // FP loads
            .ld => |i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            .le => |i| {
                try collector.regUse(i.base);
                try collector.regDef(i.dst);
            },
            // FP stores
            .std => |i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            .ste => |i| {
                try collector.regUse(i.src);
                try collector.regUse(i.base);
            },
            // Pseudo
            .ret => {},
        }
    }

    /// Check if this instruction is a call (clobbers caller-saved registers).
    pub fn isCall(self: *const Inst) bool {
        _ = self;
        return false; // TODO: add call detection for s390x
    }

    /// Get defined (output) registers for this instruction.
    pub fn getDefs(self: *const Inst, allocator: std.mem.Allocator) ![]VReg {
        var collector = OperandCollector.init(allocator);
        defer collector.deinit();

        try self.getOperands(&collector);

        var vregs = std.ArrayList(VReg){};
        defer vregs.deinit(allocator);

        for (collector.defs.items) |writable_reg| {
            if (writable_reg.toReg().toVReg()) |vreg| {
                try vregs.append(allocator, vreg);
            }
        }

        return try vregs.toOwnedSlice(allocator);
    }

    /// Get used (input) registers for this instruction.
    pub fn getUses(self: *const Inst, allocator: std.mem.Allocator) ![]VReg {
        var collector = OperandCollector.init(allocator);
        defer collector.deinit();

        try self.getOperands(&collector);

        var vregs = std.ArrayList(VReg){};
        defer vregs.deinit(allocator);

        for (collector.uses.items) |reg| {
            if (reg.toVReg()) |vreg| {
                try vregs.append(allocator, vreg);
            }
        }

        return try vregs.toOwnedSlice(allocator);
    }
};

/// Operand collector for s390x register allocation.
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

    pub fn regUse(self: *OperandCollector, reg: Reg) !void {
        try self.uses.append(self.allocator, reg);
    }

    pub fn regDef(self: *OperandCollector, reg: WritableReg) !void {
        try self.defs.append(self.allocator, reg);
    }
};

test "inst size" {
    try testing.expect(@sizeOf(Inst) <= 32);
}
