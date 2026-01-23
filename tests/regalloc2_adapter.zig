const std = @import("std");
const testing = std.testing;

const root = @import("root");
const RegAllocAdapter = root.machinst.regalloc2.api.RegAllocAdapter;
const Allocation = root.machinst.regalloc2.types.Allocation;
const PhysReg = root.machinst.regalloc2.types.PhysReg;
const VReg = root.machinst.regalloc2.types.VReg;

test "adapter: vreg allocation sequence" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const v1 = adapter.newVReg();
    const v2 = adapter.newVReg();

    try testing.expectEqual(@as(u32, 0), v0.index);
    try testing.expectEqual(@as(u32, 1), v1.index);
    try testing.expectEqual(@as(u32, 2), v2.index);
}

test "adapter: allocation uniqueness" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const v1 = adapter.newVReg();

    const p0 = PhysReg.new(5);
    const p1 = PhysReg.new(7);

    try adapter.setAllocation(v0, Allocation{ .reg = p0 });
    try adapter.setAllocation(v1, Allocation{ .reg = p1 });

    const a0 = adapter.getPhysReg(v0).?;
    const a1 = adapter.getPhysReg(v1).?;

    try testing.expectEqual(@as(u8, 5), a0.index);
    try testing.expectEqual(@as(u8, 7), a1.index);
}

test "adapter: missing allocation returns null" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const result = adapter.getPhysReg(v0);
    try testing.expect(result == null);
}

test "adapter: allocation overwrite" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();

    const p0 = PhysReg.new(3);
    const p1 = PhysReg.new(9);

    try adapter.setAllocation(v0, Allocation{ .reg = p0 });
    const a0 = adapter.getPhysReg(v0).?;
    try testing.expectEqual(@as(u8, 3), a0.index);

    try adapter.setAllocation(v0, Allocation{ .reg = p1 });
    const a1 = adapter.getPhysReg(v0).?;
    try testing.expectEqual(@as(u8, 9), a1.index);
}

test "adapter: multiple vregs same preg" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const v1 = adapter.newVReg();
    const p0 = PhysReg.new(5);

    try adapter.setAllocation(v0, Allocation{ .reg = p0 });
    try adapter.setAllocation(v1, Allocation{ .reg = p0 });

    const a0 = adapter.getPhysReg(v0).?;
    const a1 = adapter.getPhysReg(v1).?;

    try testing.expectEqual(a0.index, a1.index);
}

test "adapter: large vreg count" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    var vregs: [100]VReg = undefined;
    for (0..100) |i| {
        vregs[i] = adapter.newVReg();
        try testing.expectEqual(@as(u32, @intCast(i)), vregs[i].index);
    }
}

test "adapter: getAllocation returns full allocation" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const p0 = PhysReg.new(12);
    const alloc = Allocation{ .reg = p0 };

    try adapter.setAllocation(v0, alloc);

    const result = adapter.getAllocation(v0).?;
    try testing.expect(result.isReg());
    try testing.expectEqual(@as(u8, 12), result.reg.index);
}
