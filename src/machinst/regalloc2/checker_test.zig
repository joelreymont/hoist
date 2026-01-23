const std = @import("std");
const testing = std.testing;
const checker = @import("checker.zig");
const types = @import("types.zig");
const api = @import("api.zig");
const Checker = checker.Checker;
const RegAllocAdapter = api.RegAllocAdapter;
const VReg = types.VReg;
const PhysReg = types.PhysReg;
const Allocation = types.Allocation;
const Operand = types.Operand;

test "Checker: init deinit" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    var chk = Checker.init(testing.allocator, &adapter);
    defer chk.deinit();
}

test "Checker: verify empty" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    var chk = Checker.init(testing.allocator, &adapter);
    defer chk.deinit();

    const ok = try chk.verify();
    try testing.expect(ok);
}

test "Checker: verify use without allocation" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const op = Operand.init(v0, .any_reg, .use);
    try adapter.addOperand(op);
    adapter.num_insts = 1;

    var chk = Checker.init(testing.allocator, &adapter);
    defer chk.deinit();

    const ok = try chk.verify();
    try testing.expect(!ok);
    try testing.expectEqual(@as(usize, 1), chk.errors.items.len);
}

test "Checker: verify def creates value" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const p0 = PhysReg.new(0);
    try adapter.setAllocation(v0, Allocation{ .reg = p0 });

    const op = Operand.init(v0, .any_reg, .def);
    try adapter.addOperand(op);
    adapter.num_insts = 1;

    var chk = Checker.init(testing.allocator, &adapter);
    defer chk.deinit();

    const ok = try chk.verify();
    try testing.expect(ok);
}

test "Checker: verify constraint fixed_reg" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    try adapter.setAllocation(v0, Allocation{ .stack = types.SpillSlot.new(0) });

    const op = Operand.init(v0, .fixed_reg, .use);
    try adapter.addOperand(op);
    adapter.num_insts = 1;

    var chk = Checker.init(testing.allocator, &adapter);
    defer chk.deinit();

    const ok = try chk.verify();
    try testing.expect(!ok);
    try testing.expectEqual(@as(usize, 2), chk.errors.items.len);
}

test "Checker: verify constraint stack" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const p0 = PhysReg.new(0);
    try adapter.setAllocation(v0, Allocation{ .reg = p0 });

    const op = Operand.init(v0, .stack, .use);
    try adapter.addOperand(op);
    adapter.num_insts = 1;

    var chk = Checker.init(testing.allocator, &adapter);
    defer chk.deinit();

    const ok = try chk.verify();
    try testing.expect(!ok);
    try testing.expectEqual(@as(usize, 2), chk.errors.items.len);
}

test "Checker: def then use" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    const v0 = adapter.newVReg();
    const p0 = PhysReg.new(0);
    try adapter.setAllocation(v0, Allocation{ .reg = p0 });

    try adapter.addOperand(Operand.init(v0, .any_reg, .def));
    adapter.num_insts = 2;
    try adapter.addOperand(Operand.init(v0, .any_reg, .use));

    var chk = Checker.init(testing.allocator, &adapter);
    defer chk.deinit();

    const ok = try chk.verify();
    try testing.expect(ok);
}
