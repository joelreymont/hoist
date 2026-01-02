const std = @import("std");
const testing = std.testing;

/// Physical register allocation.
pub const Allocation = union(enum) {
    /// Value is in a physical register.
    reg: PhysReg,
    /// Value is spilled to stack slot.
    stack: SpillSlot,
    /// Value is known constant (no allocation needed).
    none,

    pub fn isReg(self: Allocation) bool {
        return self == .reg;
    }

    pub fn isStack(self: Allocation) bool {
        return self == .stack;
    }
};

/// Physical register identifier.
pub const PhysReg = struct {
    index: u8,

    pub fn new(index: u8) PhysReg {
        return .{ .index = index };
    }

    pub fn encode(self: PhysReg) u8 {
        return self.index;
    }
};

/// Operand constraint for an instruction.
pub const Operand = struct {
    /// Virtual register.
    vreg: VReg,
    /// Constraint kind.
    constraint: Constraint,
    /// Position in instruction (for def/use tracking).
    pos: OperandPos,

    pub const Constraint = enum {
        /// Any register.
        any_reg,
        /// Fixed physical register.
        fixed_reg,
        /// Same register as another operand.
        reuse,
        /// Stack slot only.
        stack,
    };

    pub const OperandPos = enum {
        /// Operand is used (read).
        use,
        /// Operand is defined (written).
        def,
        /// Operand is used then redefined (read-modify-write).
        use_def,
    };

    pub fn init(vreg: VReg, constraint: Constraint, pos: OperandPos) Operand {
        return .{
            .vreg = vreg,
            .constraint = constraint,
            .pos = pos,
        };
    }
};

/// Virtual register identifier.
pub const VReg = struct {
    index: u32,

    pub fn new(index: u32) VReg {
        return .{ .index = index };
    }

    pub fn invalid() VReg {
        return .{ .index = std.math.maxInt(u32) };
    }

    pub fn isValid(self: VReg) bool {
        return self.index != std.math.maxInt(u32);
    }
};

/// Instruction range for liveness analysis.
pub const InstRange = struct {
    /// Start instruction (inclusive).
    start: u32,
    /// End instruction (exclusive).
    end: u32,

    pub fn init(start: u32, end: u32) InstRange {
        return .{ .start = start, .end = end };
    }

    pub fn contains(self: InstRange, inst: u32) bool {
        return inst >= self.start and inst < self.end;
    }

    pub fn isEmpty(self: InstRange) bool {
        return self.start >= self.end;
    }
};

/// Spill slot on the stack.
pub const SpillSlot = struct {
    index: u32,

    pub fn new(index: u32) SpillSlot {
        return .{ .index = index };
    }
};

test "Allocation isReg" {
    const alloc_reg = Allocation{ .reg = PhysReg.new(5) };
    const alloc_stack = Allocation{ .stack = SpillSlot.new(0) };

    try testing.expect(alloc_reg.isReg());
    try testing.expect(!alloc_stack.isReg());
}

test "Allocation isStack" {
    const alloc_reg = Allocation{ .reg = PhysReg.new(5) };
    const alloc_stack = Allocation{ .stack = SpillSlot.new(0) };

    try testing.expect(!alloc_reg.isStack());
    try testing.expect(alloc_stack.isStack());
}

test "PhysReg encode" {
    const reg = PhysReg.new(7);
    try testing.expectEqual(@as(u8, 7), reg.encode());
}

test "VReg validity" {
    const valid = VReg.new(42);
    const invalid = VReg.invalid();

    try testing.expect(valid.isValid());
    try testing.expect(!invalid.isValid());
}

test "InstRange contains" {
    const range = InstRange.init(10, 20);

    try testing.expect(!range.contains(9));
    try testing.expect(range.contains(10));
    try testing.expect(range.contains(15));
    try testing.expect(range.contains(19));
    try testing.expect(!range.contains(20));
}

test "InstRange isEmpty" {
    const empty = InstRange.init(10, 10);
    const nonempty = InstRange.init(10, 20);

    try testing.expect(empty.isEmpty());
    try testing.expect(!nonempty.isEmpty());
}

test "Operand init" {
    const vreg = VReg.new(5);
    const op = Operand.init(vreg, .any_reg, .use);

    try testing.expectEqual(@as(u32, 5), op.vreg.index);
    try testing.expectEqual(Operand.Constraint.any_reg, op.constraint);
    try testing.expectEqual(Operand.OperandPos.use, op.pos);
}
