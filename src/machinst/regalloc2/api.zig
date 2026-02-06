const std = @import("std");
const types = @import("types.zig");
const Allocation = types.Allocation;
const PhysReg = types.PhysReg;
const VReg = types.VReg;
const RegClass = types.RegClass;
const Operand = types.Operand;
const InstRange = types.InstRange;
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Regalloc2 API adapter for machine instructions.
pub const RegAllocAdapter = struct {
    allocator: Allocator,
    num_vregs: u32,
    num_insts: u32,
    operands: std.ArrayList(Operand),
    inst_operands: std.AutoHashMap(u32, std.ArrayList(Operand)),
    allocations: std.AutoHashMap(VReg, Allocation),
    vreg_classes: std.AutoHashMap(VReg, RegClass),

    pub fn init(allocator: Allocator) RegAllocAdapter {
        return .{
            .allocator = allocator,
            .num_vregs = 0,
            .num_insts = 0,
            .operands = .{},
            .inst_operands = std.AutoHashMap(u32, std.ArrayList(Operand)).init(allocator),
            .allocations = std.AutoHashMap(VReg, Allocation).init(allocator),
            .vreg_classes = std.AutoHashMap(VReg, RegClass).init(allocator),
        };
    }

    pub fn deinit(self: *RegAllocAdapter) void {
        var it = self.inst_operands.valueIterator();
        while (it.next()) |ops| ops.deinit(self.allocator);
        self.inst_operands.deinit();
        self.operands.deinit(self.allocator);
        self.allocations.deinit();
        self.vreg_classes.deinit();
    }

    /// Allocate a new virtual register.
    pub fn newVReg(self: *RegAllocAdapter) VReg {
        const vreg = VReg.new(self.num_vregs);
        self.num_vregs += 1;
        return vreg;
    }

    /// Add an operand to the current instruction.
    pub fn addOperand(self: *RegAllocAdapter, operand: Operand) !void {
        try self.addOperandForInst(0, operand);
    }

    /// Add an operand for a specific instruction index.
    pub fn addOperandForInst(self: *RegAllocAdapter, inst: u32, operand: Operand) !void {
        const gop = try self.inst_operands.getOrPut(inst);
        if (!gop.found_existing) gop.value_ptr.* = .{};
        try gop.value_ptr.append(self.allocator, operand);
        try self.operands.append(self.allocator, operand);

        const next_vreg = operand.vreg.index + 1;
        if (next_vreg > self.num_vregs) self.num_vregs = next_vreg;
        if (inst + 1 > self.num_insts) self.num_insts = inst + 1;
    }

    /// Get operands for an instruction.
    pub fn getOperands(self: *const RegAllocAdapter, inst: u32) []const Operand {
        if (self.inst_operands.getPtr(inst)) |ops| return ops.items;
        return &[_]Operand{};
    }

    /// Set allocation result for a virtual register.
    pub fn setAllocation(self: *RegAllocAdapter, vreg_any: anytype, alloc: Allocation) !void {
        const vreg = normalizeVReg(vreg_any);
        try self.allocations.put(vreg, alloc);
    }

    /// Get allocation for a virtual register.
    pub fn getAllocation(self: *const RegAllocAdapter, vreg_any: anytype) ?Allocation {
        const vreg = normalizeVReg(vreg_any);
        return self.allocations.get(vreg);
    }

    /// Get physical register for a virtual register.
    pub fn getPhysReg(self: *const RegAllocAdapter, vreg_any: anytype) ?PhysReg {
        const vreg = normalizeVReg(vreg_any);
        const alloc = self.getAllocation(vreg) orelse return null;
        return if (alloc.isReg()) alloc.reg else null;
    }

    /// Record register class for a virtual register.
    pub fn setVRegClass(self: *RegAllocAdapter, vreg_any: anytype, reg_class: RegClass) !void {
        const vreg = normalizeVReg(vreg_any);
        if (self.vreg_classes.get(vreg)) |existing| {
            if (existing == reg_class) return;
            return error.VRegClassConflict;
        }
        try self.vreg_classes.put(vreg, reg_class);
    }

    /// Get register class for a virtual register; defaults to integer.
    pub fn getVRegClass(self: *const RegAllocAdapter, vreg_any: anytype) RegClass {
        const vreg = normalizeVReg(vreg_any);
        return self.vreg_classes.get(vreg) orelse .int;
    }

    fn normalizeVReg(vreg_any: anytype) VReg {
        const T = @TypeOf(vreg_any);
        if (T == VReg) return vreg_any;
        if (@hasField(T, "index")) {
            return VReg.new(@field(vreg_any, "index"));
        }
        if (@hasDecl(T, "index")) {
            return VReg.new(vreg_any.index());
        }
        @compileError("Unsupported vreg type");
    }
};

test "RegAllocAdapter newVReg" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const v1 = adapter.newVReg();

    try testing.expectEqual(@as(u32, 0), v0.index);
    try testing.expectEqual(@as(u32, 1), v1.index);
}

test "RegAllocAdapter addOperand" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const vreg = adapter.newVReg();
    const op = Operand.init(vreg, .any_reg, .use);
    try adapter.addOperand(op);

    const ops = adapter.getOperands(0);
    try testing.expectEqual(@as(usize, 1), ops.len);
    try testing.expectEqual(@as(u32, 1), adapter.num_vregs);
}

test "RegAllocAdapter addOperand tracks max vreg index" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const low = VReg.new(2);
    const high = VReg.new(37);
    try adapter.addOperand(Operand.init(low, .any_reg, .use));
    try adapter.addOperand(Operand.init(high, .any_reg, .def));

    try testing.expectEqual(@as(u32, 38), adapter.num_vregs);
}

test "RegAllocAdapter addOperandForInst keeps operands separated" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const v0 = VReg.new(0);
    const v1 = VReg.new(1);
    try adapter.addOperandForInst(0, Operand.init(v0, .any_reg, .use));
    try adapter.addOperandForInst(1, Operand.init(v1, .any_reg, .def));

    const ops0 = adapter.getOperands(0);
    const ops1 = adapter.getOperands(1);
    const ops2 = adapter.getOperands(2);

    try testing.expectEqual(@as(usize, 1), ops0.len);
    try testing.expectEqual(@as(usize, 1), ops1.len);
    try testing.expectEqual(@as(usize, 0), ops2.len);
    try testing.expectEqual(@as(u32, 2), adapter.num_insts);
}

test "RegAllocAdapter setAllocation" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const vreg = adapter.newVReg();
    const phys = PhysReg.new(5);
    const alloc = Allocation{ .reg = phys };

    try adapter.setAllocation(vreg, alloc);

    const result = adapter.getAllocation(vreg);
    try testing.expect(result != null);
    try testing.expect(result.?.isReg());
    try testing.expectEqual(@as(u8, 5), result.?.reg.index);
}

test "RegAllocAdapter tracks explicit vreg class" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const vreg = adapter.newVReg();
    try adapter.setVRegClass(vreg, .float);

    try testing.expectEqual(RegClass.float, adapter.getVRegClass(vreg));
}

test "RegAllocAdapter getPhysReg" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const vreg = adapter.newVReg();
    const phys = PhysReg.new(7);
    try adapter.setAllocation(vreg, Allocation{ .reg = phys });

    const result = adapter.getPhysReg(vreg);
    try testing.expect(result != null);
    try testing.expectEqual(@as(u8, 7), result.?.index);
}
