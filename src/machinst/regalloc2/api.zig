const std = @import("std");
const types = @import("types.zig");
const Allocation = types.Allocation;
const PhysReg = types.PhysReg;
const VReg = types.VReg;
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
    allocations: std.AutoHashMap(VReg, Allocation),

    pub fn init(allocator: Allocator) RegAllocAdapter {
        return .{
            .allocator = allocator,
            .num_vregs = 0,
            .num_insts = 0,
            .operands = .{},
            .allocations = std.AutoHashMap(VReg, Allocation).init(allocator),
        };
    }

    pub fn deinit(self: *RegAllocAdapter) void {
        self.operands.deinit(self.allocator);
        self.allocations.deinit();
    }

    /// Allocate a new virtual register.
    pub fn newVReg(self: *RegAllocAdapter) VReg {
        const vreg = VReg.new(self.num_vregs);
        self.num_vregs += 1;
        return vreg;
    }

    /// Add an operand to the current instruction.
    pub fn addOperand(self: *RegAllocAdapter, operand: Operand) !void {
        try self.operands.append(self.allocator, operand);
    }

    /// Get operands for an instruction.
    pub fn getOperands(self: *const RegAllocAdapter, inst: u32) []const Operand {
        _ = inst;
        return self.operands.items;
    }

    /// Set allocation result for a virtual register.
    pub fn setAllocation(self: *RegAllocAdapter, vreg: VReg, alloc: Allocation) !void {
        try self.allocations.put(vreg, alloc);
    }

    /// Get allocation for a virtual register.
    pub fn getAllocation(self: *const RegAllocAdapter, vreg: VReg) ?Allocation {
        return self.allocations.get(vreg);
    }

    /// Get physical register for a virtual register.
    pub fn getPhysReg(self: *const RegAllocAdapter, vreg: VReg) ?PhysReg {
        const alloc = self.getAllocation(vreg) orelse return null;
        return if (alloc.isReg()) alloc.reg else null;
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
