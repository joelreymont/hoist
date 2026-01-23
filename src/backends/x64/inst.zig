const std = @import("std");
const testing = std.testing;

const root = @import("root");
const reg_mod = root.reg;

pub const Reg = reg_mod.Reg;
pub const PReg = reg_mod.PReg;
pub const VReg = reg_mod.VReg;
pub const WritableReg = reg_mod.WritableReg;

/// x86-64 machine instruction.
/// Minimal bootstrap set - full x64 backend needs ~100+ variants.
pub const Inst = union(enum) {
    /// Move register to register.
    mov_rr: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Move immediate to register.
    mov_imm: struct {
        dst: WritableReg,
        imm: i64,
        size: OperandSize,
    },

    /// Add register to register.
    add_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Subtract register from register.
    sub_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Add immediate to register.
    add_imm: struct {
        dst: WritableReg, // Also source
        imm: i32,
        size: OperandSize,
    },

    /// Subtract immediate from register.
    sub_imm: struct {
        dst: WritableReg, // Also source
        imm: i32,
        size: OperandSize,
    },

    /// Bitwise AND register with register.
    and_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Bitwise AND immediate with register.
    and_imm: struct {
        dst: WritableReg, // Also source
        imm: i32,
        size: OperandSize,
    },

    /// Bitwise OR register with register.
    or_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Bitwise OR immediate with register.
    or_imm: struct {
        dst: WritableReg, // Also source
        imm: i32,
        size: OperandSize,
    },

    /// Bitwise XOR register with register.
    xor_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Bitwise XOR immediate with register.
    xor_imm: struct {
        dst: WritableReg, // Also source
        imm: i32,
        size: OperandSize,
    },

    /// Compare register with register (sets flags, doesn't store result).
    cmp_rr: struct {
        lhs: Reg,
        rhs: Reg,
        size: OperandSize,
    },

    /// Compare register with immediate.
    cmp_imm: struct {
        lhs: Reg,
        imm: i32,
        size: OperandSize,
    },

    /// Test register with register (bitwise AND, sets flags only).
    test_rr: struct {
        lhs: Reg,
        rhs: Reg,
        size: OperandSize,
    },

    /// Test register with immediate.
    test_imm: struct {
        lhs: Reg,
        imm: i32,
        size: OperandSize,
    },

    /// Shift left logical.
    shl_rr: struct {
        dst: WritableReg, // Also source
        count: Reg, // Must be CL
        size: OperandSize,
    },

    /// Shift left logical by immediate.
    shl_imm: struct {
        dst: WritableReg, // Also source
        count: u8,
        size: OperandSize,
    },

    /// Shift right logical.
    shr_rr: struct {
        dst: WritableReg, // Also source
        count: Reg, // Must be CL
        size: OperandSize,
    },

    /// Shift right logical by immediate.
    shr_imm: struct {
        dst: WritableReg, // Also source
        count: u8,
        size: OperandSize,
    },

    /// Shift right arithmetic.
    sar_rr: struct {
        dst: WritableReg, // Also source
        count: Reg, // Must be CL
        size: OperandSize,
    },

    /// Shift right arithmetic by immediate.
    sar_imm: struct {
        dst: WritableReg, // Also source
        count: u8,
        size: OperandSize,
    },

    /// Rotate left.
    rol_rr: struct {
        dst: WritableReg, // Also source
        count: Reg, // Must be CL
        size: OperandSize,
    },

    /// Rotate left by immediate.
    rol_imm: struct {
        dst: WritableReg, // Also source
        count: u8,
        size: OperandSize,
    },

    /// Rotate right.
    ror_rr: struct {
        dst: WritableReg, // Also source
        count: Reg, // Must be CL
        size: OperandSize,
    },

    /// Rotate right by immediate.
    ror_imm: struct {
        dst: WritableReg, // Also source
        count: u8,
        size: OperandSize,
    },

    /// Multiply (unsigned).
    imul_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Multiply by immediate.
    imul_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: i32,
        size: OperandSize,
    },

    /// Negate.
    neg: struct {
        dst: WritableReg, // Also source
        size: OperandSize,
    },

    /// Bitwise NOT.
    not: struct {
        dst: WritableReg, // Also source
        size: OperandSize,
    },

    /// Push register to stack.
    push_r: struct {
        src: Reg,
    },

    /// Pop from stack to register.
    pop_r: struct {
        dst: WritableReg,
    },

    /// Unconditional jump.
    jmp: struct {
        target: BranchTarget,
    },

    /// Conditional jump.
    jmp_cond: struct {
        cc: CondCode,
        target: BranchTarget,
    },

    /// Call function.
    call: struct {
        target: CallTarget,
    },

    /// Return from function.
    ret,

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
            .mov_imm => |i| try writer.print("mov.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .add_rr => |i| try writer.print("add.{} {}, {}", .{ i.size, i.dst, i.src }),
            .add_imm => |i| try writer.print("add.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .sub_rr => |i| try writer.print("sub.{} {}, {}", .{ i.size, i.dst, i.src }),
            .sub_imm => |i| try writer.print("sub.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .and_rr => |i| try writer.print("and.{} {}, {}", .{ i.size, i.dst, i.src }),
            .and_imm => |i| try writer.print("and.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .or_rr => |i| try writer.print("or.{} {}, {}", .{ i.size, i.dst, i.src }),
            .or_imm => |i| try writer.print("or.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .xor_rr => |i| try writer.print("xor.{} {}, {}", .{ i.size, i.dst, i.src }),
            .xor_imm => |i| try writer.print("xor.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .cmp_rr => |i| try writer.print("cmp.{} {}, {}", .{ i.size, i.lhs, i.rhs }),
            .cmp_imm => |i| try writer.print("cmp.{} {}, ${d}", .{ i.size, i.lhs, i.imm }),
            .test_rr => |i| try writer.print("test.{} {}, {}", .{ i.size, i.lhs, i.rhs }),
            .test_imm => |i| try writer.print("test.{} {}, ${d}", .{ i.size, i.lhs, i.imm }),
            .shl_rr => |i| try writer.print("shl.{} {}, {}", .{ i.size, i.dst, i.count }),
            .shl_imm => |i| try writer.print("shl.{} {}, ${d}", .{ i.size, i.dst, i.count }),
            .shr_rr => |i| try writer.print("shr.{} {}, {}", .{ i.size, i.dst, i.count }),
            .shr_imm => |i| try writer.print("shr.{} {}, ${d}", .{ i.size, i.dst, i.count }),
            .sar_rr => |i| try writer.print("sar.{} {}, {}", .{ i.size, i.dst, i.count }),
            .sar_imm => |i| try writer.print("sar.{} {}, ${d}", .{ i.size, i.dst, i.count }),
            .imul_rr => |i| try writer.print("imul.{} {}, {}", .{ i.size, i.dst, i.src }),
            .imul_imm => |i| try writer.print("imul.{} {}, {}, ${d}", .{ i.size, i.dst, i.src, i.imm }),
            .neg => |i| try writer.print("neg.{} {}", .{ i.size, i.dst }),
            .not => |i| try writer.print("not.{} {}", .{ i.size, i.dst }),
            .push_r => |i| try writer.print("push {}", .{i.src}),
            .pop_r => |i| try writer.print("pop {}", .{i.dst}),
            .jmp => |i| try writer.print("jmp {}", .{i.target}),
            .jmp_cond => |i| try writer.print("j{} {}", .{ i.cc, i.target }),
            .call => |i| try writer.print("call {}", .{i.target}),
            .ret => try writer.writeAll("ret"),
            .nop => try writer.writeAll("nop"),
        }
    }
};

/// Operand size for x64 instructions.
pub const OperandSize = enum {
    /// 8-bit (AL, BL, etc.)
    size8,
    /// 16-bit (AX, BX, etc.)
    size16,
    /// 32-bit (EAX, EBX, etc.)
    size32,
    /// 64-bit (RAX, RBX, etc.)
    size64,

    pub fn format(
        self: OperandSize,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const suffix = switch (self) {
            .size8 => "b",
            .size16 => "w",
            .size32 => "l",
            .size64 => "q",
        };
        try writer.writeAll(suffix);
    }

    pub fn bytes(self: OperandSize) u32 {
        return switch (self) {
            .size8 => 1,
            .size16 => 2,
            .size32 => 4,
            .size64 => 8,
        };
    }
};

/// Condition code for conditional jumps.
pub const CondCode = enum {
    /// Overflow.
    o,
    /// Not overflow.
    no,
    /// Below/Carry.
    b,
    /// Above or equal/Not carry.
    ae,
    /// Equal/Zero.
    e,
    /// Not equal/Not zero.
    ne,
    /// Below or equal.
    be,
    /// Above.
    a,
    /// Sign.
    s,
    /// Not sign.
    ns,
    /// Parity/Parity even.
    p,
    /// Not parity/Parity odd.
    np,
    /// Less than.
    l,
    /// Greater or equal.
    ge,
    /// Less or equal.
    le,
    /// Greater.
    g,

    pub fn format(
        self: CondCode,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const name = @tagName(self);
        try writer.writeAll(name);
    }

    /// Invert the condition code (e.g., e -> ne, l -> ge).
    pub fn invert(self: CondCode) CondCode {
        return switch (self) {
            .o => .no,
            .no => .o,
            .b => .ae,
            .ae => .b,
            .e => .ne,
            .ne => .e,
            .be => .a,
            .a => .be,
            .s => .ns,
            .ns => .s,
            .p => .np,
            .np => .p,
            .l => .ge,
            .ge => .l,
            .le => .g,
            .g => .le,
        };
    }
};

/// Branch target (label for jumps).
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

/// Call target (function name or address).
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
            .indirect => |reg| try writer.print("*{}", .{reg}),
        }
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
        .src = r1,
        .size = .size64,
    } };

    var buf: [64]u8 = undefined;
    const str = try std.fmt.bufPrint(&buf, "{}", .{inst});
    try testing.expect(std.mem.indexOf(u8, str, "add") != null);
}

test "CondCode invert" {
    try testing.expectEqual(CondCode.ne, CondCode.e.invert());
    try testing.expectEqual(CondCode.e, CondCode.ne.invert());
    try testing.expectEqual(CondCode.ge, CondCode.l.invert());
    try testing.expectEqual(CondCode.le, CondCode.g.invert());
}

test "OperandSize bytes" {
    try testing.expectEqual(@as(u32, 1), OperandSize.size8.bytes());
    try testing.expectEqual(@as(u32, 2), OperandSize.size16.bytes());
    try testing.expectEqual(@as(u32, 4), OperandSize.size32.bytes());
    try testing.expectEqual(@as(u32, 8), OperandSize.size64.bytes());
}

test "ALU instruction formatting" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    var buf: [64]u8 = undefined;

    // Test immediate forms
    const add_imm = Inst{ .add_imm = .{ .dst = wr0, .imm = 42, .size = .size64 } };
    const str1 = try std.fmt.bufPrint(&buf, "{}", .{add_imm});
    try testing.expect(std.mem.indexOf(u8, str1, "add") != null);
    try testing.expect(std.mem.indexOf(u8, str1, "$42") != null);

    // Test bitwise ops
    const and_rr = Inst{ .and_rr = .{ .dst = wr0, .src = r1, .size = .size32 } };
    const str2 = try std.fmt.bufPrint(&buf, "{}", .{and_rr});
    try testing.expect(std.mem.indexOf(u8, str2, "and") != null);

    const xor_imm = Inst{ .xor_imm = .{ .dst = wr0, .imm = -1, .size = .size64 } };
    const str3 = try std.fmt.bufPrint(&buf, "{}", .{xor_imm});
    try testing.expect(std.mem.indexOf(u8, str3, "xor") != null);

    // Test compare/test
    const cmp_rr = Inst{ .cmp_rr = .{ .lhs = r0, .rhs = r1, .size = .size64 } };
    const str4 = try std.fmt.bufPrint(&buf, "{}", .{cmp_rr});
    try testing.expect(std.mem.indexOf(u8, str4, "cmp") != null);

    const test_imm = Inst{ .test_imm = .{ .lhs = r0, .imm = 1, .size = .size8 } };
    const str5 = try std.fmt.bufPrint(&buf, "{}", .{test_imm});
    try testing.expect(std.mem.indexOf(u8, str5, "test") != null);

    // Test shifts
    const shl_imm = Inst{ .shl_imm = .{ .dst = wr0, .count = 3, .size = .size64 } };
    const str6 = try std.fmt.bufPrint(&buf, "{}", .{shl_imm});
    try testing.expect(std.mem.indexOf(u8, str6, "shl") != null);

    const sar_rr = Inst{ .sar_rr = .{ .dst = wr0, .count = r1, .size = .size32 } };
    const str7 = try std.fmt.bufPrint(&buf, "{}", .{sar_rr});
    try testing.expect(std.mem.indexOf(u8, str7, "sar") != null);

    // Test multiply
    const imul_rr = Inst{ .imul_rr = .{ .dst = wr0, .src = r1, .size = .size64 } };
    const str8 = try std.fmt.bufPrint(&buf, "{}", .{imul_rr});
    try testing.expect(std.mem.indexOf(u8, str8, "imul") != null);

    // Test unary
    const neg = Inst{ .neg = .{ .dst = wr0, .size = .size64 } };
    const str9 = try std.fmt.bufPrint(&buf, "{}", .{neg});
    try testing.expect(std.mem.indexOf(u8, str9, "neg") != null);

    const not = Inst{ .not = .{ .dst = wr0, .size = .size64 } };
    const str10 = try std.fmt.bufPrint(&buf, "{}", .{not});
    try testing.expect(std.mem.indexOf(u8, str10, "not") != null);
}
