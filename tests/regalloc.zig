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

// Test: Register pressure - Test high register use

test "pressure: allocating all available registers" {
    var alloc = LinearScanAllocator.init(testing.allocator);
    defer alloc.deinit();

    // Set up with 8 integer registers (typical available for allocation)
    const int_regs = [_]PReg{
        PReg.new(.int, 0),
        PReg.new(.int, 1),
        PReg.new(.int, 2),
        PReg.new(.int, 3),
        PReg.new(.int, 4),
        PReg.new(.int, 5),
        PReg.new(.int, 6),
        PReg.new(.int, 7),
    };

    try alloc.initRegs(&int_regs, &.{}, &.{});

    // Allocate all 8 registers
    var vregs: [8]VReg = undefined;
    var pregs: [8]PReg = undefined;

    for (0..8) |i| {
        vregs[i] = VReg.new(@intCast(i), .int);
        pregs[i] = try alloc.allocate(vregs[i]);
    }

    // All 8 should be allocated and unique
    for (0..8) |i| {
        for (i + 1..8) |j| {
            try testing.expect(!std.meta.eql(pregs[i], pregs[j]));
        }
    }

    // 9th allocation should fail
    const v9 = VReg.new(9, .int);
    try testing.expectError(error.OutOfRegisters, alloc.allocate(v9));
}

test "pressure: high register pressure with reuse" {
    var alloc = LinearScanAllocator.init(testing.allocator);
    defer alloc.deinit();

    const int_regs = [_]PReg{
        PReg.new(.int, 0),
        PReg.new(.int, 1),
        PReg.new(.int, 2),
    };

    try alloc.initRegs(&int_regs, &.{}, &.{});

    // Simulate live ranges: allocate, use, free, allocate new
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const v3 = VReg.new(3, .int);
    const v4 = VReg.new(4, .int);

    // Allocate first 3
    _ = try alloc.allocate(v0);
    _ = try alloc.allocate(v1);
    _ = try alloc.allocate(v2);

    // At capacity
    try testing.expectError(error.OutOfRegisters, alloc.allocate(v3));

    // Free v0 (end of live range)
    try alloc.free(v0);

    // Now v3 can allocate
    _ = try alloc.allocate(v3);

    // Still at capacity
    try testing.expectError(error.OutOfRegisters, alloc.allocate(v4));

    // Free v1
    try alloc.free(v1);

    // Now v4 can allocate
    _ = try alloc.allocate(v4);
}

test "pressure: mixed register classes under pressure" {
    var alloc = LinearScanAllocator.init(testing.allocator);
    defer alloc.deinit();

    const int_regs = [_]PReg{ PReg.new(.int, 0), PReg.new(.int, 1) };
    const vec_regs = [_]PReg{ PReg.new(.vec, 0), PReg.new(.vec, 1) };

    try alloc.initRegs(&int_regs, &.{}, &vec_regs);

    // Allocate all int registers
    const v_int0 = VReg.new(0, .int);
    const v_int1 = VReg.new(1, .int);
    const v_int2 = VReg.new(2, .int);

    _ = try alloc.allocate(v_int0);
    _ = try alloc.allocate(v_int1);

    // Int registers full
    try testing.expectError(error.OutOfRegisters, alloc.allocate(v_int2));

    // But vector registers still available
    const v_vec0 = VReg.new(3, .vec);
    const v_vec1 = VReg.new(4, .vec);
    const v_vec2 = VReg.new(5, .vec);

    _ = try alloc.allocate(v_vec0);
    _ = try alloc.allocate(v_vec1);

    // Vector registers full
    try testing.expectError(error.OutOfRegisters, alloc.allocate(v_vec2));
}

test "pressure: sequential allocation and deallocation" {
    var alloc = LinearScanAllocator.init(testing.allocator);
    defer alloc.deinit();

    const int_regs = [_]PReg{PReg.new(.int, 0)};
    try alloc.initRegs(&int_regs, &.{}, &.{});

    // Simulate many sequential live ranges in a tight loop
    for (0..100) |i| {
        const v = VReg.new(@intCast(i), .int);
        const p = try alloc.allocate(v);

        // Should always get the same physical register
        try testing.expectEqual(PReg.new(.int, 0), p);

        // Free immediately (end of live range)
        try alloc.free(v);
    }
}

test "pressure: maximum vregs with minimal pregs" {
    var alloc = LinearScanAllocator.init(testing.allocator);
    defer alloc.deinit();

    const int_regs = [_]PReg{PReg.new(.int, 0)};
    try alloc.initRegs(&int_regs, &.{}, &.{});

    // Allocate one vreg
    const v0 = VReg.new(0, .int);
    const p0 = try alloc.allocate(v0);

    // Create many more vregs that can't be allocated
    for (1..20) |i| {
        const v = VReg.new(@intCast(i), .int);
        try testing.expectError(error.OutOfRegisters, alloc.allocate(v));
    }

    // Original allocation still valid
    try testing.expectEqual(p0, alloc.getAllocation(v0).?);
}
