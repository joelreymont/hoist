const std = @import("std");
const testing = std.testing;

// Import regalloc2 infrastructure
const types = @import("types.zig");
const api = @import("api.zig");
const liveness = @import("liveness.zig");
const datastructures = @import("datastructures.zig");

const Allocation = types.Allocation;
const PhysReg = types.PhysReg;
const VReg = types.VReg;
const SpillSlot = types.SpillSlot;
const Operand = types.Operand;
const InstRange = types.InstRange;
const RegAllocAdapter = api.RegAllocAdapter;
const LiveRange = liveness.LiveRange;
const LivenessInfo = liveness.LivenessInfo;
const UsePositions = liveness.UsePositions;
const BitSet = datastructures.BitSet;

// Test: Basic register allocation for single vreg
test "register assignment: allocate single vreg to physical register" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const vreg = adapter.newVReg();
    const phys = PhysReg.new(0);
    const alloc = Allocation{ .reg = phys };

    try adapter.setAllocation(vreg, alloc);

    const result = adapter.getAllocation(vreg);
    try testing.expect(result != null);
    try testing.expect(result.?.isReg());
    try testing.expectEqual(@as(u8, 0), result.?.reg.index);
}

// Test: Multiple vregs to different physical registers
test "register assignment: allocate multiple vregs to different registers" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const v1 = adapter.newVReg();
    const v2 = adapter.newVReg();

    try adapter.setAllocation(v0, Allocation{ .reg = PhysReg.new(0) });
    try adapter.setAllocation(v1, Allocation{ .reg = PhysReg.new(1) });
    try adapter.setAllocation(v2, Allocation{ .reg = PhysReg.new(2) });

    const r0 = adapter.getPhysReg(v0);
    const r1 = adapter.getPhysReg(v1);
    const r2 = adapter.getPhysReg(v2);

    try testing.expect(r0 != null);
    try testing.expect(r1 != null);
    try testing.expect(r2 != null);

    // All should be different
    try testing.expect(r0.?.index != r1.?.index);
    try testing.expect(r1.?.index != r2.?.index);
    try testing.expect(r0.?.index != r2.?.index);
}

// Test: Spill slot assignment when out of registers
test "register assignment: assign spill slot when registers exhausted" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const v1 = adapter.newVReg();

    // v0 gets register
    try adapter.setAllocation(v0, Allocation{ .reg = PhysReg.new(0) });

    // v1 must spill
    try adapter.setAllocation(v1, Allocation{ .stack = SpillSlot.new(0) });

    const alloc0 = adapter.getAllocation(v0);
    const alloc1 = adapter.getAllocation(v1);

    try testing.expect(alloc0 != null);
    try testing.expect(alloc0.?.isReg());

    try testing.expect(alloc1 != null);
    try testing.expect(alloc1.?.isStack());
    try testing.expectEqual(@as(u32, 0), alloc1.?.stack.index);
}

// Test: Multiple spill slots for different vregs
test "register assignment: assign unique spill slots" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const v1 = adapter.newVReg();
    const v2 = adapter.newVReg();

    // All spilled to unique slots
    try adapter.setAllocation(v0, Allocation{ .stack = SpillSlot.new(0) });
    try adapter.setAllocation(v1, Allocation{ .stack = SpillSlot.new(1) });
    try adapter.setAllocation(v2, Allocation{ .stack = SpillSlot.new(2) });

    const a0 = adapter.getAllocation(v0).?;
    const a1 = adapter.getAllocation(v1).?;
    const a2 = adapter.getAllocation(v2).?;

    try testing.expect(a0.isStack());
    try testing.expect(a1.isStack());
    try testing.expect(a2.isStack());

    try testing.expectEqual(@as(u32, 0), a0.stack.index);
    try testing.expectEqual(@as(u32, 1), a1.stack.index);
    try testing.expectEqual(@as(u32, 2), a2.stack.index);
}

// Test: Fixed register constraint
test "register assignment: fixed register constraint honored" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const vreg = adapter.newVReg();
    const fixed_reg = PhysReg.new(7); // Must use r7

    // Operand with fixed register constraint
    const op = Operand.init(vreg, .fixed_reg, .use);
    try adapter.addOperand(op);

    // Allocate to the fixed register
    try adapter.setAllocation(vreg, Allocation{ .reg = fixed_reg });

    const result = adapter.getPhysReg(vreg);
    try testing.expect(result != null);
    try testing.expectEqual(@as(u8, 7), result.?.index);
}

// Test: Register reuse constraint (same vreg as another operand)
test "register assignment: reuse constraint assigns same register" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const v_src = adapter.newVReg();
    const v_dst = adapter.newVReg();

    // v_src gets a register
    const phys = PhysReg.new(3);
    try adapter.setAllocation(v_src, Allocation{ .reg = phys });

    // v_dst reuses the same register (simulating reuse constraint)
    try adapter.setAllocation(v_dst, Allocation{ .reg = phys });

    const r_src = adapter.getPhysReg(v_src);
    const r_dst = adapter.getPhysReg(v_dst);

    try testing.expect(r_src != null);
    try testing.expect(r_dst != null);
    try testing.expectEqual(r_src.?.index, r_dst.?.index);
}

// Test: Any register constraint satisfied
test "register assignment: any register constraint satisfied" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const vreg = adapter.newVReg();
    const op = Operand.init(vreg, .any_reg, .def);
    try adapter.addOperand(op);

    // Can allocate any available register
    try adapter.setAllocation(vreg, Allocation{ .reg = PhysReg.new(5) });

    const result = adapter.getPhysReg(vreg);
    try testing.expect(result != null);
    try testing.expectEqual(@as(u8, 5), result.?.index);
}

// Test: Live range allocation
test "register assignment: allocate for entire live range" {
    const allocator = testing.allocator;
    var lr = LiveRange.init(allocator, VReg.new(0));
    defer lr.deinit();

    // Live range from instruction 10 to 50
    try lr.addRange(InstRange.init(10, 50));

    // Verify vreg is live throughout the range
    try testing.expect(lr.contains(10));
    try testing.expect(lr.contains(30));
    try testing.expect(lr.contains(49));
    try testing.expect(!lr.contains(9));
    try testing.expect(!lr.contains(50));
}

// Test: Non-overlapping live ranges can share register
test "register assignment: non-overlapping live ranges share register" {
    const allocator = testing.allocator;

    var lr1 = LiveRange.init(allocator, VReg.new(0));
    defer lr1.deinit();
    try lr1.addRange(InstRange.init(0, 10));

    var lr2 = LiveRange.init(allocator, VReg.new(1));
    defer lr2.deinit();
    try lr2.addRange(InstRange.init(20, 30));

    // These ranges don't overlap, so can share a physical register
    try testing.expect(!lr1.contains(25));
    try testing.expect(!lr2.contains(5));

    // Both can be assigned to same physical register
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const shared_reg = PhysReg.new(0);
    try adapter.setAllocation(lr1.vreg, Allocation{ .reg = shared_reg });
    try adapter.setAllocation(lr2.vreg, Allocation{ .reg = shared_reg });

    const r1 = adapter.getPhysReg(lr1.vreg);
    const r2 = adapter.getPhysReg(lr2.vreg);

    try testing.expectEqual(r1.?.index, r2.?.index);
}

// Test: Overlapping live ranges need different registers
test "register assignment: overlapping live ranges need different registers" {
    const allocator = testing.allocator;

    var lr1 = LiveRange.init(allocator, VReg.new(0));
    defer lr1.deinit();
    try lr1.addRange(InstRange.init(0, 20));

    var lr2 = LiveRange.init(allocator, VReg.new(1));
    defer lr2.deinit();
    try lr2.addRange(InstRange.init(10, 30));

    // These ranges overlap at [10, 20), need different registers
    try testing.expect(lr1.contains(15));
    try testing.expect(lr2.contains(15));

    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    try adapter.setAllocation(lr1.vreg, Allocation{ .reg = PhysReg.new(0) });
    try adapter.setAllocation(lr2.vreg, Allocation{ .reg = PhysReg.new(1) });

    const r1 = adapter.getPhysReg(lr1.vreg);
    const r2 = adapter.getPhysReg(lr2.vreg);

    try testing.expect(r1.?.index != r2.?.index);
}

// Test: Register pressure tracking
test "register assignment: track register pressure" {
    const allocator = testing.allocator;
    const num_regs = 8;

    var available = try BitSet.init(allocator, num_regs);
    defer available.deinit();

    // Initially all registers available
    available.setAll();
    for (0..num_regs) |i| {
        try testing.expect(available.isSet(i));
    }

    // Allocate some registers
    available.unset(0);
    available.unset(3);
    available.unset(7);

    // Check pressure: 3 allocated, 5 available
    var allocated: usize = 0;
    for (0..num_regs) |i| {
        if (!available.isSet(i)) allocated += 1;
    }

    try testing.expectEqual(@as(usize, 3), allocated);
}

// Test: Register pressure with spilling
test "register assignment: spill when pressure exceeds capacity" {
    const allocator = testing.allocator;

    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    // Allocate more vregs than available registers
    const vregs = [_]VReg{
        adapter.newVReg(),
        adapter.newVReg(),
        adapter.newVReg(),
        adapter.newVReg(),
        adapter.newVReg(), // This one must spill
        adapter.newVReg(), // This one must spill
    };

    // First 4 get registers
    try adapter.setAllocation(vregs[0], Allocation{ .reg = PhysReg.new(0) });
    try adapter.setAllocation(vregs[1], Allocation{ .reg = PhysReg.new(1) });
    try adapter.setAllocation(vregs[2], Allocation{ .reg = PhysReg.new(2) });
    try adapter.setAllocation(vregs[3], Allocation{ .reg = PhysReg.new(3) });

    // Last 2 must spill
    try adapter.setAllocation(vregs[4], Allocation{ .stack = SpillSlot.new(0) });
    try adapter.setAllocation(vregs[5], Allocation{ .stack = SpillSlot.new(1) });

    // Verify allocations
    for (vregs[0..4]) |vreg| {
        const alloc = adapter.getAllocation(vreg);
        try testing.expect(alloc != null);
        try testing.expect(alloc.?.isReg());
    }

    for (vregs[4..6]) |vreg| {
        const alloc = adapter.getAllocation(vreg);
        try testing.expect(alloc != null);
        try testing.expect(alloc.?.isStack());
    }
}

// Test: Use-def chain with register assignment
test "register assignment: use-def chain maintains allocation" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const vreg = adapter.newVReg();

    // Add use and def operands
    const use_op = Operand.init(vreg, .any_reg, .use);
    const def_op = Operand.init(vreg, .any_reg, .def);

    try adapter.addOperand(use_op);
    try adapter.addOperand(def_op);

    // Allocate register
    const phys = PhysReg.new(4);
    try adapter.setAllocation(vreg, Allocation{ .reg = phys });

    // Allocation should be consistent for all uses and defs
    const result = adapter.getPhysReg(vreg);
    try testing.expect(result != null);
    try testing.expectEqual(@as(u8, 4), result.?.index);
}

// Test: Stack constraint honored
test "register assignment: stack constraint forces spill" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const vreg = adapter.newVReg();
    const stack_op = Operand.init(vreg, .stack, .def);
    try adapter.addOperand(stack_op);

    // Must allocate to stack even if registers available
    try adapter.setAllocation(vreg, Allocation{ .stack = SpillSlot.new(5) });

    const alloc = adapter.getAllocation(vreg);
    try testing.expect(alloc != null);
    try testing.expect(alloc.?.isStack());
    try testing.expectEqual(@as(u32, 5), alloc.?.stack.index);
}

// Test: Live range splitting
test "register assignment: split live range at spill point" {
    const allocator = testing.allocator;
    var lr = LiveRange.init(allocator, VReg.new(10));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 50));

    // Split at instruction 25
    var after = try lr.split(allocator, 25);
    defer if (after) |*a| a.deinit();

    // First part: [0, 25)
    try testing.expectEqual(@as(usize, 1), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 25), lr.ranges.items[0].end);

    // Second part: [25, 50)
    try testing.expect(after != null);
    try testing.expectEqual(@as(usize, 1), after.?.ranges.items.len);
    try testing.expectEqual(@as(u32, 25), after.?.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 50), after.?.ranges.items[0].end);
}

// Test: Multiple live range segments for same vreg
test "register assignment: handle multiple live range segments" {
    const allocator = testing.allocator;
    var lr = LiveRange.init(allocator, VReg.new(5));
    defer lr.deinit();

    // Add non-contiguous ranges
    try lr.addRange(InstRange.init(0, 10));
    try lr.addRange(InstRange.init(20, 30));
    try lr.addRange(InstRange.init(40, 50));

    try testing.expectEqual(@as(usize, 3), lr.ranges.items.len);

    // Check containment
    try testing.expect(lr.contains(5));
    try testing.expect(!lr.contains(15));
    try testing.expect(lr.contains(25));
    try testing.expect(!lr.contains(35));
    try testing.expect(lr.contains(45));
}

// Test: Merge overlapping live ranges
test "register assignment: merge overlapping live ranges" {
    const allocator = testing.allocator;
    var lr = LiveRange.init(allocator, VReg.new(8));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 15));
    try lr.addRange(InstRange.init(10, 25));
    try lr.addRange(InstRange.init(20, 30));

    lr.merge();

    // Should merge into single range [0, 30)
    try testing.expectEqual(@as(usize, 1), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 30), lr.ranges.items[0].end);
}

// Test: Register assignment with use positions
test "register assignment: track use positions for allocation decisions" {
    const allocator = testing.allocator;
    var up = UsePositions.init(allocator, VReg.new(3));
    defer up.deinit();

    try up.addDef(5);
    try up.addUse(10);
    try up.addUse(20);
    try up.addUseDef(30);
    try up.addUse(40);

    try testing.expectEqual(@as(usize, 5), up.positions.items.len);

    // Find next use after instruction 15
    const next = up.nextUseAfter(15);
    try testing.expect(next != null);
    try testing.expectEqual(@as(u32, 20), next.?.inst);
}

// Test: None allocation for constants
test "register assignment: none allocation for constants" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const vreg = adapter.newVReg();

    // Constants don't need allocation
    try adapter.setAllocation(vreg, Allocation.none);

    const alloc = adapter.getAllocation(vreg);
    try testing.expect(alloc != null);
    try testing.expect(!alloc.?.isReg());
    try testing.expect(!alloc.?.isStack());
}

// Test: High register pressure scenario
test "register assignment: complex scenario with high pressure" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    // Simulate 10 vregs with only 4 physical registers
    const num_vregs = 10;
    const num_phys_regs = 4;

    var vregs: [num_vregs]VReg = undefined;
    for (0..num_vregs) |i| {
        vregs[i] = adapter.newVReg();
    }

    // First 4 get registers
    for (0..num_phys_regs) |i| {
        try adapter.setAllocation(vregs[i], Allocation{ .reg = PhysReg.new(@intCast(i)) });
    }

    // Rest must spill
    for (num_phys_regs..num_vregs) |i| {
        try adapter.setAllocation(
            vregs[i],
            Allocation{ .stack = SpillSlot.new(@intCast(i - num_phys_regs)) },
        );
    }

    // Verify counts
    var reg_count: usize = 0;
    var spill_count: usize = 0;

    for (vregs) |vreg| {
        const alloc = adapter.getAllocation(vreg).?;
        if (alloc.isReg()) {
            reg_count += 1;
        } else if (alloc.isStack()) {
            spill_count += 1;
        }
    }

    try testing.expectEqual(@as(usize, 4), reg_count);
    try testing.expectEqual(@as(usize, 6), spill_count);
}

// Test: Fixed register with overlapping live ranges
test "register assignment: fixed register constraints with interference" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const v1 = adapter.newVReg();

    // Both need fixed register 2
    const fixed = PhysReg.new(2);

    // Only one can have it (non-overlapping required)
    try adapter.setAllocation(v0, Allocation{ .reg = fixed });

    // v1 cannot use same fixed register if live ranges overlap
    // Must use different register or spill
    try adapter.setAllocation(v1, Allocation{ .stack = SpillSlot.new(0) });

    const a0 = adapter.getAllocation(v0).?;
    const a1 = adapter.getAllocation(v1).?;

    try testing.expect(a0.isReg());
    try testing.expectEqual(@as(u8, 2), a0.reg.index);
    try testing.expect(a1.isStack());
}

// Test: Allocation metadata tracking
test "register assignment: track allocation metadata" {
    const allocator = testing.allocator;
    var adapter = RegAllocAdapter.init(allocator);
    defer adapter.deinit();

    // Create several vregs and track their allocations
    const v0 = adapter.newVReg();
    const v1 = adapter.newVReg();
    const v2 = adapter.newVReg();

    try adapter.setAllocation(v0, Allocation{ .reg = PhysReg.new(0) });
    try adapter.setAllocation(v1, Allocation{ .reg = PhysReg.new(1) });
    try adapter.setAllocation(v2, Allocation{ .stack = SpillSlot.new(0) });

    // Verify all allocations are tracked
    try testing.expect(adapter.getAllocation(v0) != null);
    try testing.expect(adapter.getAllocation(v1) != null);
    try testing.expect(adapter.getAllocation(v2) != null);

    // Verify correct types
    try testing.expect(adapter.getAllocation(v0).?.isReg());
    try testing.expect(adapter.getAllocation(v1).?.isReg());
    try testing.expect(adapter.getAllocation(v2).?.isStack());
}
