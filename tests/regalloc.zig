const std = @import("std");
const testing = std.testing;

const root = @import("root");
const regalloc_mod = root.regalloc;
const LinearScanAllocator = regalloc_mod.LinearScanAllocator;
const Allocation = regalloc_mod.Allocation;
const PReg = root.reg.PReg;
const VReg = root.reg.VReg;
const SpillSlot = root.reg.SpillSlot;

// Test: Regalloc spilling - Test spill generation

test "spilling: out of registers triggers spill" {
    var alloc = LinearScanAllocator.init(testing.allocator);
    defer alloc.deinit();

    // Set up with only 2 available integer registers
    const int_regs = [_]PReg{
        PReg.new(.int, 0), // x0
        PReg.new(.int, 1), // x1
    };

    try alloc.initRegs(&int_regs, &.{}, &.{});

    // Allocate virtual registers - first two should succeed
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int); // This one needs to spill

    const p0 = try alloc.allocate(v0);
    const p1 = try alloc.allocate(v1);

    // Both should be allocated to different physical registers
    try testing.expect(!std.meta.eql(p0, p1));

    // Third allocation should fail (OutOfRegisters)
    const result = alloc.allocate(v2);
    try testing.expectError(error.OutOfRegisters, result);
}

test "spilling: allocation tracks spills separately" {
    var allocation = Allocation.init(testing.allocator);
    defer allocation.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);

    const p0 = PReg.new(.int, 0);
    const s1 = SpillSlot.new(0);
    const s2 = SpillSlot.new(1);

    // v0 allocated to register
    try allocation.addReg(v0, p0);

    // v1 and v2 spilled to stack
    try allocation.addSpill(v1, s1);
    try allocation.addSpill(v2, s2);

    // Verify correct lookups
    try testing.expectEqual(p0, allocation.getReg(v0).?);
    try testing.expect(allocation.getSpill(v0) == null);

    try testing.expect(allocation.getReg(v1) == null);
    try testing.expectEqual(s1, allocation.getSpill(v1).?);

    try testing.expect(allocation.getReg(v2) == null);
    try testing.expectEqual(s2, allocation.getSpill(v2).?);
}

test "spilling: different spill slots for each vreg" {
    var allocation = Allocation.init(testing.allocator);
    defer allocation.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);

    const s0 = SpillSlot.new(0);
    const s1 = SpillSlot.new(1);
    const s2 = SpillSlot.new(2);

    try allocation.addSpill(v0, s0);
    try allocation.addSpill(v1, s1);
    try allocation.addSpill(v2, s2);

    // Each vreg should have a unique spill slot
    const slot0 = allocation.getSpill(v0).?;
    const slot1 = allocation.getSpill(v1).?;
    const slot2 = allocation.getSpill(v2).?;

    try testing.expect(!std.meta.eql(slot0, slot1));
    try testing.expect(!std.meta.eql(slot1, slot2));
    try testing.expect(!std.meta.eql(slot0, slot2));
}

test "spilling: reload after free allows reuse" {
    var alloc = LinearScanAllocator.init(testing.allocator);
    defer alloc.deinit();

    const int_regs = [_]PReg{
        PReg.new(.int, 0),
    };

    try alloc.initRegs(&int_regs, &.{}, &.{});

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);

    // Allocate v0
    const p0 = try alloc.allocate(v0);

    // v1 cannot allocate (out of registers)
    try testing.expectError(error.OutOfRegisters, alloc.allocate(v1));

    // Free v0 (simulate end of live range)
    try alloc.free(v0);

    // Now v1 can allocate and should get the same physical register
    const p1 = try alloc.allocate(v1);
    try testing.expectEqual(p0, p1);
}

test "spilling: vector registers separate from int registers" {
    var alloc = LinearScanAllocator.init(testing.allocator);
    defer alloc.deinit();

    const int_regs = [_]PReg{PReg.new(.int, 0)};
    const vec_regs = [_]PReg{PReg.new(.vec, 0)};

    try alloc.initRegs(&int_regs, &.{}, &vec_regs);

    const v_int = VReg.new(0, .int);
    const v_vec = VReg.new(1, .vec);

    const p_int = try alloc.allocate(v_int);
    const p_vec = try alloc.allocate(v_vec);

    // Should allocate from different pools
    try testing.expectEqual(p_int.class(), .int);
    try testing.expectEqual(p_vec.class(), .vector);
}
