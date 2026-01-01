const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const reg_mod = @import("reg.zig");

pub const Reg = reg_mod.Reg;
pub const WritableReg = reg_mod.WritableReg;
pub const PReg = reg_mod.PReg;
pub const VReg = reg_mod.VReg;
pub const RegClass = reg_mod.RegClass;

/// Classification of call instruction types.
pub const CallType = enum {
    /// Not a call instruction.
    none,
    /// Regular call that returns to the caller.
    regular,
    /// Tail call that doesn't return to the caller.
    tail_call,
};

/// Function classification based on call patterns.
pub const FunctionCalls = enum {
    /// Function makes no calls at all.
    none,
    /// Function only makes tail calls (no regular calls).
    tail_only,
    /// Function makes at least one regular call (may also have tail calls).
    regular,

    pub fn update(self: *FunctionCalls, call_type: CallType) void {
        self.* = switch (self.*) {
            .none => switch (call_type) {
                .none => .none,
                .regular => .regular,
                .tail_call => .tail_only,
            },
            .tail_only => switch (call_type) {
                .none => .tail_only,
                .regular => .regular,
                .tail_call => .tail_only,
            },
            .regular => .regular,
        };
    }
};

/// Describes a block terminator (not call) in the VCode.
pub const MachTerminator = enum {
    /// Not a terminator.
    none,
    /// A return instruction.
    ret,
    /// A tail call.
    ret_call,
    /// A branch.
    branch,
};

/// Operand constraint for register allocation.
pub const OperandConstraint = enum {
    /// Register can be any allocatable register.
    any,
    /// Register must be a specific physical register.
    fixed_reg,
    /// Register must be reused from another operand.
    reuse,
};

/// Operand kind - use, def, or modify.
pub const OperandKind = enum {
    /// Operand is read.
    use,
    /// Operand is written.
    def,
    /// Operand is read and written.
    modify,
};

/// Operand position - early (before) or late (after) instruction.
pub const OperandPos = enum {
    /// Operand is accessed at the start of the instruction.
    early,
    /// Operand is accessed at the end of the instruction.
    late,
};

/// Visitor trait for collecting operands from an instruction.
pub const OperandVisitor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        addOperand: *const fn (
            *anyopaque,
            *Reg,
            OperandConstraint,
            OperandKind,
            OperandPos,
        ) void,
        regClobbers: *const fn (*anyopaque, []const PReg) void,
    };

    pub fn addOperand(
        self: *OperandVisitor,
        reg: *Reg,
        constraint: OperandConstraint,
        kind: OperandKind,
        pos: OperandPos,
    ) void {
        self.vtable.addOperand(self.ptr, reg, constraint, kind, pos);
    }

    pub fn regClobbers(self: *OperandVisitor, regs: []const PReg) void {
        self.vtable.regClobbers(self.ptr, regs);
    }

    /// Helper: add a register use at early position.
    pub fn regUse(self: *OperandVisitor, reg: *Reg) void {
        self.addOperand(reg, .any, .use, .early);
    }

    /// Helper: add a register use at late position.
    pub fn regLateUse(self: *OperandVisitor, reg: *Reg) void {
        self.addOperand(reg, .any, .use, .late);
    }

    /// Helper: add a register def at late position.
    pub fn regDef(self: *OperandVisitor, reg: *WritableReg) void {
        var r = reg.toReg();
        self.addOperand(&r, .any, .def, .late);
    }

    /// Helper: add a register def at early position.
    pub fn regEarlyDef(self: *OperandVisitor, reg: *WritableReg) void {
        var r = reg.toReg();
        self.addOperand(&r, .any, .def, .early);
    }

    /// Helper: add a register modify (read-write).
    pub fn regModify(self: *OperandVisitor, reg: *Reg) void {
        self.addOperand(reg, .any, .modify, .early);
    }

    /// Helper: add a fixed physical register use.
    pub fn regFixedUse(self: *OperandVisitor, preg: PReg) void {
        var reg = Reg.fromPReg(preg);
        self.addOperand(&reg, .fixed_reg, .use, .early);
    }

    /// Helper: add a fixed physical register def.
    pub fn regFixedDef(self: *OperandVisitor, preg: PReg) void {
        var reg = Reg.fromPReg(preg);
        self.addOperand(&reg, .fixed_reg, .def, .late);
    }
};

/// Machine label for branches and control flow.
pub const MachLabel = struct {
    index: u32,

    pub fn new(index: u32) MachLabel {
        return .{ .index = index };
    }

    pub fn format(
        self: MachLabel,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("label{d}", .{self.index});
    }
};

test "FunctionCalls update" {
    var calls = FunctionCalls.none;

    calls.update(.tail_call);
    try testing.expectEqual(FunctionCalls.tail_only, calls);

    calls.update(.regular);
    try testing.expectEqual(FunctionCalls.regular, calls);

    calls.update(.tail_call);
    try testing.expectEqual(FunctionCalls.regular, calls);
}

test "OperandVisitor helpers" {
    const Operand = struct {
        reg: Reg,
        constraint: OperandConstraint,
        kind: OperandKind,
        pos: OperandPos,
    };

    const TestVisitor = struct {
        operands: std.ArrayList(Operand),

        fn init(_: Allocator) @This() {
            return .{
                .operands = std.ArrayList(Operand){},
            };
        }

        fn deinit(self: *@This(), allocator: Allocator) void {
            self.operands.deinit(allocator);
        }

        fn addOperandImpl(
            ptr: *anyopaque,
            reg: *Reg,
            constraint: OperandConstraint,
            kind: OperandKind,
            pos: OperandPos,
        ) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self.operands.append(std.testing.allocator, .{
                .reg = reg.*,
                .constraint = constraint,
                .kind = kind,
                .pos = pos,
            }) catch unreachable;
        }

        fn regClobbersImpl(_: *anyopaque, _: []const PReg) void {}

        fn visitor(self: *@This()) OperandVisitor {
            return .{
                .ptr = self,
                .vtable = &.{
                    .addOperand = addOperandImpl,
                    .regClobbers = regClobbersImpl,
                },
            };
        }
    };

    var test_vis = TestVisitor.init(testing.allocator);
    defer test_vis.deinit(testing.allocator);

    var visitor = test_vis.visitor();

    var reg1 = Reg.fromVReg(VReg.new(42, .int));
    visitor.regUse(&reg1);

    var reg2 = WritableReg.fromReg(Reg.fromVReg(VReg.new(43, .float)));
    visitor.regDef(&reg2);

    try testing.expectEqual(@as(usize, 2), test_vis.operands.items.len);
    try testing.expectEqual(OperandKind.use, test_vis.operands.items[0].kind);
    try testing.expectEqual(OperandPos.early, test_vis.operands.items[0].pos);
    try testing.expectEqual(OperandKind.def, test_vis.operands.items[1].kind);
    try testing.expectEqual(OperandPos.late, test_vis.operands.items[1].pos);
}
