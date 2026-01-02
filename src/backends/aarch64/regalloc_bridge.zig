const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const vcode_mod = @import("../../machinst/vcode.zig");
const reg_mod = @import("../../machinst/reg.zig");
const regalloc2_types = @import("../../machinst/regalloc2/types.zig");
const regalloc2_api = @import("../../machinst/regalloc2/api.zig");
const inst_mod = @import("inst.zig");

pub const VCode = vcode_mod.VCode;
pub const VReg = reg_mod.VReg;
pub const Reg = reg_mod.Reg;
pub const Inst = inst_mod.Inst;

pub const Operand = regalloc2_types.Operand;
pub const Constraint = regalloc2_types.Operand.Constraint;
pub const OperandPos = regalloc2_types.Operand.OperandPos;
pub const RegAllocAdapter = regalloc2_api.RegAllocAdapter;

/// Bridge between VCode and regalloc2.
///
/// Extracts register operands from VCode instructions and builds
/// regalloc2 data structures for register allocation.
pub const RegAllocBridge = struct {
    allocator: Allocator,
    adapter: RegAllocAdapter,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .adapter = RegAllocAdapter.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.adapter.deinit();
    }

    /// Convert VCode to regalloc2 representation.
    /// Extracts all register operands from instructions.
    pub fn convertVCode(self: *Self, vcode: *const VCode(Inst)) !void {
        for (vcode.insns.items, 0..) |inst, inst_idx| {
            try self.extractOperands(inst, @intCast(inst_idx));
        }
    }

    /// Extract register operands from a single instruction.
    fn extractOperands(self: *Self, inst: Inst, inst_idx: u32) !void {
        _ = inst_idx;

        switch (inst) {
            .mov_rr => |mov| {
                // dst = def, src = use
                const src_vreg = try self.getVReg(mov.src);
                const dst_vreg = try self.getVReg(mov.dst.toReg());

                try self.adapter.addOperand(Operand.init(src_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .mov_imm => |mov| {
                // dst = def (no source registers)
                const dst_vreg = try self.getVReg(mov.dst.toReg());
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .movz => |mov| {
                // dst = def (no source registers)
                const dst_vreg = try self.getVReg(mov.dst.toReg());
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .movk => |mov| {
                // dst = use_def (read-modify-write)
                const dst_vreg = try self.getVReg(mov.dst.toReg());
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .use_def));
            },

            .movn => |mov| {
                // dst = def
                const dst_vreg = try self.getVReg(mov.dst.toReg());
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .add_rr => |add| {
                // dst = def, src1 = use, src2 = use
                const src1_vreg = try self.getVReg(add.src1);
                const src2_vreg = try self.getVReg(add.src2);
                const dst_vreg = try self.getVReg(add.dst.toReg());

                try self.adapter.addOperand(Operand.init(src1_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(src2_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .add_imm => |add| {
                // dst = def, src = use
                const src_vreg = try self.getVReg(add.src);
                const dst_vreg = try self.getVReg(add.dst.toReg());

                try self.adapter.addOperand(Operand.init(src_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .add_extended => |add| {
                // dst = def, src1 = use, src2 = use
                const src1_vreg = try self.getVReg(add.src1);
                const src2_vreg = try self.getVReg(add.src2);
                const dst_vreg = try self.getVReg(add.dst.toReg());

                try self.adapter.addOperand(Operand.init(src1_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(src2_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .sub_rr => |sub| {
                // dst = def, src1 = use, src2 = use
                const src1_vreg = try self.getVReg(sub.src1);
                const src2_vreg = try self.getVReg(sub.src2);
                const dst_vreg = try self.getVReg(sub.dst.toReg());

                try self.adapter.addOperand(Operand.init(src1_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(src2_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .sub_imm => |sub| {
                // dst = def, src = use
                const src_vreg = try self.getVReg(sub.src);
                const dst_vreg = try self.getVReg(sub.dst.toReg());

                try self.adapter.addOperand(Operand.init(src_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .mul_rr => |mul| {
                // dst = def, src1 = use, src2 = use
                const src1_vreg = try self.getVReg(mul.src1);
                const src2_vreg = try self.getVReg(mul.src2);
                const dst_vreg = try self.getVReg(mul.dst.toReg());

                try self.adapter.addOperand(Operand.init(src1_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(src2_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .madd => |madd| {
                // dst = def, src1 = use, src2 = use, addend = use
                const src1_vreg = try self.getVReg(madd.src1);
                const src2_vreg = try self.getVReg(madd.src2);
                const addend_vreg = try self.getVReg(madd.addend);
                const dst_vreg = try self.getVReg(madd.dst.toReg());

                try self.adapter.addOperand(Operand.init(src1_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(src2_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(addend_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .msub => |msub| {
                // dst = def, src1 = use, src2 = use, minuend = use
                const src1_vreg = try self.getVReg(msub.src1);
                const src2_vreg = try self.getVReg(msub.src2);
                const minuend_vreg = try self.getVReg(msub.minuend);
                const dst_vreg = try self.getVReg(msub.dst.toReg());

                try self.adapter.addOperand(Operand.init(src1_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(src2_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(minuend_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .smulh => |mul| {
                // dst = def, src1 = use, src2 = use
                const src1_vreg = try self.getVReg(mul.src1);
                const src2_vreg = try self.getVReg(mul.src2);
                const dst_vreg = try self.getVReg(mul.dst.toReg());

                try self.adapter.addOperand(Operand.init(src1_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(src2_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .umulh => |mul| {
                // dst = def, src1 = use, src2 = use
                const src1_vreg = try self.getVReg(mul.src1);
                const src2_vreg = try self.getVReg(mul.src2);
                const dst_vreg = try self.getVReg(mul.dst.toReg());

                try self.adapter.addOperand(Operand.init(src1_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(src2_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .smull => |mul| {
                // dst = def, src1 = use, src2 = use
                const src1_vreg = try self.getVReg(mul.src1);
                const src2_vreg = try self.getVReg(mul.src2);
                const dst_vreg = try self.getVReg(mul.dst.toReg());

                try self.adapter.addOperand(Operand.init(src1_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(src2_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            .umull => |mul| {
                // dst = def, src1 = use, src2 = use
                const src1_vreg = try self.getVReg(mul.src1);
                const src2_vreg = try self.getVReg(mul.src2);
                const dst_vreg = try self.getVReg(mul.dst.toReg());

                try self.adapter.addOperand(Operand.init(src1_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(src2_vreg, .any_reg, .use));
                try self.adapter.addOperand(Operand.init(dst_vreg, .any_reg, .def));
            },

            // TODO: Add remaining instruction variants as they are implemented
            else => {
                // For now, unsupported instructions are silently skipped.
                // This allows partial implementation while backend is being built.
            },
        }
    }

    /// Convert Reg to VReg.
    /// Physical registers are represented as high-index vregs.
    fn getVReg(self: *Self, reg: Reg) !VReg {
        _ = self;
        return switch (reg) {
            .v => |vreg| vreg,
            .p => |_| {
                // Physical registers should not appear in VCode before allocation.
                // If they do, it indicates a fixed constraint (e.g., calling convention).
                // For now, return error - proper handling requires fixed_reg constraints.
                return error.UnexpectedPhysicalRegister;
            },
        };
    }
};

test "RegAllocBridge basic mov_rr" {
    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);

    _ = try vcode.startBlock(&.{});
    _ = try vcode.addInst(.{
        .mov_rr = .{
            .dst = reg_mod.WritableReg.init(Reg{ .v = v1 }),
            .src = Reg{ .v = v0 },
            .size = .size64,
        },
    });
    try vcode.finishBlock(0, &.{});

    var bridge = RegAllocBridge.init(testing.allocator);
    defer bridge.deinit();

    try bridge.convertVCode(&vcode);

    const ops = bridge.adapter.getOperands(0);
    try testing.expectEqual(@as(usize, 2), ops.len);

    // First operand: src (use)
    try testing.expectEqual(@as(u32, 0), ops[0].vreg.index);
    try testing.expectEqual(Constraint.any_reg, ops[0].constraint);
    try testing.expectEqual(OperandPos.use, ops[0].pos);

    // Second operand: dst (def)
    try testing.expectEqual(@as(u32, 1), ops[1].vreg.index);
    try testing.expectEqual(Constraint.any_reg, ops[1].constraint);
    try testing.expectEqual(OperandPos.def, ops[1].pos);
}

test "RegAllocBridge mov_imm" {
    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    const v0 = VReg.new(0, .int);

    _ = try vcode.startBlock(&.{});
    _ = try vcode.addInst(.{
        .mov_imm = .{
            .dst = reg_mod.WritableReg.init(Reg{ .v = v0 }),
            .imm = 42,
            .size = .size64,
        },
    });
    try vcode.finishBlock(0, &.{});

    var bridge = RegAllocBridge.init(testing.allocator);
    defer bridge.deinit();

    try bridge.convertVCode(&vcode);

    const ops = bridge.adapter.getOperands(0);
    try testing.expectEqual(@as(usize, 1), ops.len);

    // Only dst operand (def)
    try testing.expectEqual(@as(u32, 0), ops[0].vreg.index);
    try testing.expectEqual(Constraint.any_reg, ops[0].constraint);
    try testing.expectEqual(OperandPos.def, ops[0].pos);
}

test "RegAllocBridge add_rr" {
    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);

    _ = try vcode.startBlock(&.{});
    _ = try vcode.addInst(.{
        .add_rr = .{
            .dst = reg_mod.WritableReg.init(Reg{ .v = v2 }),
            .src1 = Reg{ .v = v0 },
            .src2 = Reg{ .v = v1 },
            .size = .size64,
        },
    });
    try vcode.finishBlock(0, &.{});

    var bridge = RegAllocBridge.init(testing.allocator);
    defer bridge.deinit();

    try bridge.convertVCode(&vcode);

    const ops = bridge.adapter.getOperands(0);
    try testing.expectEqual(@as(usize, 3), ops.len);

    // src1 (use)
    try testing.expectEqual(@as(u32, 0), ops[0].vreg.index);
    try testing.expectEqual(OperandPos.use, ops[0].pos);

    // src2 (use)
    try testing.expectEqual(@as(u32, 1), ops[1].vreg.index);
    try testing.expectEqual(OperandPos.use, ops[1].pos);

    // dst (def)
    try testing.expectEqual(@as(u32, 2), ops[2].vreg.index);
    try testing.expectEqual(OperandPos.def, ops[2].pos);
}

test "RegAllocBridge movk read-modify-write" {
    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    const v0 = VReg.new(0, .int);

    _ = try vcode.startBlock(&.{});
    _ = try vcode.addInst(.{
        .movk = .{
            .dst = reg_mod.WritableReg.init(Reg{ .v = v0 }),
            .imm = 0x1234,
            .shift = 16,
            .size = .size64,
        },
    });
    try vcode.finishBlock(0, &.{});

    var bridge = RegAllocBridge.init(testing.allocator);
    defer bridge.deinit();

    try bridge.convertVCode(&vcode);

    const ops = bridge.adapter.getOperands(0);
    try testing.expectEqual(@as(usize, 1), ops.len);

    // dst (use_def - read-modify-write)
    try testing.expectEqual(@as(u32, 0), ops[0].vreg.index);
    try testing.expectEqual(OperandPos.use_def, ops[0].pos);
}
