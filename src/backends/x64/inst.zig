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
            .sub_rr => |i| try writer.print("sub.{} {}, {}", .{ i.size, i.dst, i.src }),
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
