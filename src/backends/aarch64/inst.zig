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

    /// Load register from memory (LDR Xt, [Xn, #offset]).
    ldr: struct {
        dst: WritableReg,
        base: Reg,
        offset: i16,
        size: OperandSize,
    },

    /// Store register to memory (STR Xt, [Xn, #offset]).
    str: struct {
        src: Reg,
        base: Reg,
        offset: i16,
        size: OperandSize,
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

    /// No operation.
    nop,

    pub fn format(
        self: Inst,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .mov_rr => |i| try writer.print("mov.{} {}, {}", .{ i.size, i.dst, i.src }),
            .mov_imm => |i| try writer.print("mov.{} {}, #{d}", .{ i.size, i.dst, i.imm }),
            .add_rr => |i| try writer.print("add.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .add_imm => |i| try writer.print("add.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .sub_rr => |i| try writer.print("sub.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .sub_imm => |i| try writer.print("sub.{} {}, {}, #{d}", .{ i.size, i.dst, i.src, i.imm }),
            .mul_rr => |i| try writer.print("mul.{} {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2 }),
            .madd => |i| try writer.print("madd.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.addend }),
            .msub => |i| try writer.print("msub.{} {}, {}, {}, {}", .{ i.size, i.dst, i.src1, i.src2, i.subtrahend }),
            .smulh => |i| try writer.print("smulh {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .umulh => |i| try writer.print("umulh {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .smull => |i| try writer.print("smull {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .umull => |i| try writer.print("umull {}, {}, {}", .{ i.dst, i.src1, i.src2 }),
            .ldr => |i| try writer.print("ldr.{} {}, [{}, #{d}]", .{ i.size, i.dst, i.base, i.offset }),
            .str => |i| try writer.print("str.{} {}, [{}, #{d}]", .{ i.size, i.src, i.base, i.offset }),
            .stp => |i| try writer.print("stp.{} {}, {}, [{}, #{d}]", .{ i.size, i.src1, i.src2, i.base, i.offset }),
            .ldp => |i| try writer.print("ldp.{} {}, {}, [{}, #{d}]", .{ i.size, i.dst1, i.dst2, i.base, i.offset }),
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
            .nop => try writer.writeAll("nop"),
        }
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
        // TODO: Implement full logical immediate encoding algorithm
        // For now, return null (will be implemented in Phase 2)
        _ = val;
        _ = size;
        return null;
    }

    pub fn toU64(self: ImmLogic) u64 {
        return self.value;
    }
};

/// Shift operation and amount for shifted register operands.
pub const ShiftOpAndAmt = struct {
    op: ShiftOp,
    amt: u8,

    pub const ShiftOp = enum(u2) {
        lsl = 0b00,
        lsr = 0b01,
        asr = 0b10,
        ror = 0b11,
    };
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
