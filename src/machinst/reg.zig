const std = @import("std");
const testing = std.testing;

/// Register class - indicates register file.
pub const RegClass = enum(u8) {
    /// Integer/general-purpose register.
    int = 0,
    /// Floating-point register.
    float = 1,
    /// Vector register.
    vector = 2,

    pub const count = 3;

    pub fn index(self: RegClass) u8 {
        return @intFromEnum(self);
    }
};

/// Physical register - actual hardware register.
/// Encoded as: [class:2][hw_enc:6]
pub const PReg = struct {
    bits: u8,

    const CLASS_SHIFT = 6;
    const HW_ENC_MASK = 0x3F;

    pub fn new(reg_class: RegClass, hw_enc: u6) PReg {
        return .{
            .bits = (@as(u8, reg_class.index()) << CLASS_SHIFT) | hw_enc,
        };
    }

    pub fn class(self: PReg) RegClass {
        return @enumFromInt(self.bits >> CLASS_SHIFT);
    }

    pub fn hwEnc(self: PReg) u6 {
        return @intCast(self.bits & HW_ENC_MASK);
    }

    pub fn index(self: PReg) u8 {
        return self.bits;
    }

    pub fn format(self: PReg, writer: anytype) !void {
        try writer.print("p{d}(class={s},hw={d})", .{
            self.bits,
            @tagName(self.class()),
            self.hwEnc(),
        });
    }
};

/// Virtual register - SSA value before register allocation.
/// Encoded as: [class:2][index:30]
pub const VReg = struct {
    bits: u32,

    const CLASS_SHIFT = 30;
    const INDEX_MASK = 0x3FFF_FFFF;

    pub fn new(vreg_index: u32, reg_class: RegClass) VReg {
        std.debug.assert(vreg_index <= INDEX_MASK);
        return .{
            .bits = (@as(u32, reg_class.index()) << CLASS_SHIFT) | vreg_index,
        };
    }

    pub fn class(self: VReg) RegClass {
        return @enumFromInt(@as(u8, @intCast(self.bits >> CLASS_SHIFT)));
    }

    pub fn index(self: VReg) u32 {
        return self.bits & INDEX_MASK;
    }

    pub fn format(self: VReg, writer: anytype) !void {
        try writer.print("v{d}(class={s})", .{ self.index(), @tagName(self.class()) });
    }
};

/// Register - can be virtual or physical.
/// Post-regalloc, virtual registers are replaced with physical registers.
/// The first N virtual registers are "pinned" to physical registers.
pub const Reg = struct {
    bits: u32,

    const SPILLSLOT_BIT: u32 = 0x8000_0000;
    const SPILLSLOT_MASK: u32 = ~SPILLSLOT_BIT;
    pub const PINNED_VREGS: usize = 192; // 64 int, 64 float, 64 vec

    pub fn fromVReg(vreg: VReg) Reg {
        return .{ .bits = vreg.bits };
    }

    pub fn fromPReg(preg: PReg) Reg {
        // Physical registers are pinned to the first PINNED_VREGS virtual registers
        const vreg = VReg.new(@as(u32, preg.hwEnc()), preg.class());
        return .{ .bits = vreg.bits };
    }

    pub fn fromSpillSlot(slot: SpillSlot) Reg {
        return .{ .bits = SPILLSLOT_BIT | @as(u32, slot.index) };
    }

    pub fn toVReg(self: Reg) ?VReg {
        if (self.isSpillSlot()) return null;
        const vreg = VReg{ .bits = self.bits };
        if (self.toRealReg()) |_| return null; // Is physical
        return vreg;
    }

    pub fn toRealReg(self: Reg) ?PReg {
        if (self.isSpillSlot()) return null;
        const vreg = VReg{ .bits = self.bits };
        if (vreg.index() < PINNED_VREGS) {
            return PReg.new(vreg.class(), @intCast(vreg.index()));
        }
        return null;
    }

    pub fn toSpillSlot(self: Reg) ?SpillSlot {
        if (self.isSpillSlot()) {
            return SpillSlot{ .index = self.bits & SPILLSLOT_MASK };
        }
        return null;
    }

    pub fn isSpillSlot(self: Reg) bool {
        return (self.bits & SPILLSLOT_BIT) != 0;
    }

    pub fn isVirtual(self: Reg) bool {
        return self.toVReg() != null;
    }

    pub fn isReal(self: Reg) bool {
        return self.toRealReg() != null;
    }

    pub fn class(self: Reg) RegClass {
        std.debug.assert(!self.isSpillSlot());
        const vreg = VReg{ .bits = self.bits };
        return vreg.class();
    }

    pub fn format(self: Reg, writer: anytype) !void {
        if (self.toRealReg()) |preg| {
            try writer.print("r{f}", .{preg});
        } else if (self.toVReg()) |vreg| {
            try writer.print("r{f}", .{vreg});
        } else if (self.toSpillSlot()) |slot| {
            try writer.print("rslot{d}", .{slot.index});
        } else {
            try writer.writeAll("r?");
        }
    }
};

/// Writable register - newtype to distinguish defs from uses.
pub const WritableReg = struct {
    reg: Reg,

    pub fn fromReg(reg: Reg) WritableReg {
        return .{ .reg = reg };
    }

    pub fn fromVReg(vreg: VReg) WritableReg {
        return .{ .reg = Reg.fromVReg(vreg) };
    }

    pub fn toReg(self: WritableReg) Reg {
        return self.reg;
    }

    pub fn format(self: WritableReg, writer: anytype) !void {
        try self.reg.format(writer);
    }
};

/// Spill slot - stack location for spilled registers.
pub const SpillSlot = struct {
    index: u32,

    pub fn new(index: u32) SpillSlot {
        return .{ .index = index };
    }
};

/// Value register(s) - handles wide values that need 1-4 registers.
/// For example: i128 on 64-bit, or multi-return values.
pub const ValueRegs = union(enum) {
    /// Single register.
    one: Reg,
    /// Two registers for wide values (low, high).
    two: struct { low: Reg, high: Reg },
    /// Three registers for multi-return.
    three: struct { r0: Reg, r1: Reg, r2: Reg },
    /// Four registers for multi-return.
    four: struct { r0: Reg, r1: Reg, r2: Reg, r3: Reg },

    pub fn single(reg: Reg) ValueRegs {
        return .{ .one = reg };
    }

    pub fn pair(low: Reg, high: Reg) ValueRegs {
        return .{ .two = .{ .low = low, .high = high } };
    }

    pub fn triple(r0: Reg, r1: Reg, r2: Reg) ValueRegs {
        return .{ .three = .{ .r0 = r0, .r1 = r1, .r2 = r2 } };
    }

    pub fn quad(r0: Reg, r1: Reg, r2: Reg, r3: Reg) ValueRegs {
        return .{ .four = .{ .r0 = r0, .r1 = r1, .r2 = r2, .r3 = r3 } };
    }

    pub fn len(self: ValueRegs) usize {
        return switch (self) {
            .one => 1,
            .two => 2,
            .three => 3,
            .four => 4,
        };
    }

    pub fn get(self: ValueRegs, index: usize) ?Reg {
        return switch (self) {
            .one => |r| if (index == 0) r else null,
            .two => |p| switch (index) {
                0 => p.low,
                1 => p.high,
                else => null,
            },
            .three => |t| switch (index) {
                0 => t.r0,
                1 => t.r1,
                2 => t.r2,
                else => null,
            },
            .four => |q| switch (index) {
                0 => q.r0,
                1 => q.r1,
                2 => q.r2,
                3 => q.r3,
                else => null,
            },
        };
    }

    pub fn format(self: ValueRegs, writer: anytype) !void {
        switch (self) {
            .one => |r| try writer.print("{f}", .{r}),
            .two => |p| try writer.print("[{f},{f}]", .{ p.low, p.high }),
            .three => |t| try writer.print("[{f},{f},{f}]", .{ t.r0, t.r1, t.r2 }),
            .four => |q| try writer.print("[{f},{f},{f},{f}]", .{ q.r0, q.r1, q.r2, q.r3 }),
        }
    }
};

/// Writable value registers.
pub const WritableValueRegs = union(enum) {
    one: WritableReg,
    two: struct { low: WritableReg, high: WritableReg },
    three: struct { r0: WritableReg, r1: WritableReg, r2: WritableReg },
    four: struct { r0: WritableReg, r1: WritableReg, r2: WritableReg, r3: WritableReg },

    pub fn single(reg: WritableReg) WritableValueRegs {
        return .{ .one = reg };
    }

    pub fn pair(low: WritableReg, high: WritableReg) WritableValueRegs {
        return .{ .two = .{ .low = low, .high = high } };
    }

    pub fn triple(r0: WritableReg, r1: WritableReg, r2: WritableReg) WritableValueRegs {
        return .{ .three = .{ .r0 = r0, .r1 = r1, .r2 = r2 } };
    }

    pub fn quad(r0: WritableReg, r1: WritableReg, r2: WritableReg, r3: WritableReg) WritableValueRegs {
        return .{ .four = .{ .r0 = r0, .r1 = r1, .r2 = r2, .r3 = r3 } };
    }

    pub fn toValueRegs(self: WritableValueRegs) ValueRegs {
        return switch (self) {
            .one => |r| ValueRegs.single(r.toReg()),
            .two => |p| ValueRegs.pair(p.low.toReg(), p.high.toReg()),
            .three => |t| ValueRegs.triple(t.r0.toReg(), t.r1.toReg(), t.r2.toReg()),
            .four => |q| ValueRegs.quad(q.r0.toReg(), q.r1.toReg(), q.r2.toReg(), q.r3.toReg()),
        };
    }
};

test "PReg encoding" {
    const preg = PReg.new(.int, 5);
    try testing.expectEqual(RegClass.int, preg.class());
    try testing.expectEqual(@as(u6, 5), preg.hwEnc());
}

test "VReg encoding" {
    const vreg = VReg.new(42, .float);
    try testing.expectEqual(RegClass.float, vreg.class());
    try testing.expectEqual(@as(u32, 42), vreg.index());
}

test "Reg from PReg" {
    const preg = PReg.new(.int, 10);
    const reg = Reg.fromPReg(preg);

    try testing.expect(reg.isReal());
    try testing.expect(!reg.isVirtual());
    try testing.expect(reg.toRealReg() != null);
    try testing.expectEqual(preg.hwEnc(), reg.toRealReg().?.hwEnc());
}

test "Reg from VReg" {
    const vreg = VReg.new(Reg.PINNED_VREGS + 100, .float);
    const reg = Reg.fromVReg(vreg);

    try testing.expect(!reg.isReal());
    try testing.expect(reg.isVirtual());
    try testing.expect(reg.toVReg() != null);
    try testing.expectEqual(vreg.index(), reg.toVReg().?.index());
}

test "Reg from SpillSlot" {
    const slot = SpillSlot.new(5);
    const reg = Reg.fromSpillSlot(slot);

    try testing.expect(reg.isSpillSlot());
    try testing.expect(!reg.isReal());
    try testing.expect(!reg.isVirtual());
    try testing.expectEqual(@as(u32, 5), reg.toSpillSlot().?.index);
}

test "ValueRegs single" {
    const reg = Reg.fromVReg(VReg.new(42, .int));
    const vregs = ValueRegs.single(reg);

    try testing.expectEqual(@as(usize, 1), vregs.len());
    try testing.expectEqual(reg, vregs.get(0).?);
    try testing.expect(vregs.get(1) == null);
}

test "ValueRegs pair" {
    const low = Reg.fromVReg(VReg.new(42, .int));
    const high = Reg.fromVReg(VReg.new(43, .int));
    const vregs = ValueRegs.pair(low, high);

    try testing.expectEqual(@as(usize, 2), vregs.len());
    try testing.expectEqual(low, vregs.get(0).?);
    try testing.expectEqual(high, vregs.get(1).?);
    try testing.expect(vregs.get(2) == null);
}
