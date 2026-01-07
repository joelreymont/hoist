//! Argument classification unit tests using MockABI.
//!
//! Tests AAPCS64 argument passing conventions: register assignment,
//! stack overflow, and special cases like HFAs and large structs.

const std = @import("std");
const testing = std.testing;
const MockABICallee = @import("mock_abi.zig").MockABICallee;
const PReg = @import("../../machinst/reg.zig").PReg;

test "arg classification: integer args in X0-X7" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 4 int args -> all in registers (X0-X3)
    mock.setNumIntArgs(4);
    try testing.expectEqual(@as(u32, 4), mock.register_args);
    try testing.expectEqual(@as(u32, 0), mock.stack_args);
}

test "arg classification: integer args overflow to stack" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 10 int args -> X0-X7 (8 in regs), then 2 on stack
    mock.setNumIntArgs(10);
    try testing.expectEqual(@as(u32, 8), mock.register_args);
    try testing.expectEqual(@as(u32, 2), mock.stack_args);

    // Verify first 8 in registers
    for (0..8) |i| {
        try testing.expect(mock.getIntArgReg(@intCast(i)) != null);
    }

    // Verify 9th and 10th on stack
    try testing.expectEqual(@as(?PReg, null), mock.getIntArgReg(8));
    try testing.expectEqual(@as(?PReg, null), mock.getIntArgReg(9));
}

test "arg classification: float args in V0-V7" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 4 float args -> all in registers (V0-V3)
    mock.setNumFloatArgs(4);
    try testing.expectEqual(@as(u32, 4), mock.register_args);
    try testing.expectEqual(@as(u32, 0), mock.stack_args);
}

test "arg classification: float args overflow to stack" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 10 float args -> V0-V7 (8 in regs), then 2 on stack
    mock.setNumFloatArgs(10);
    try testing.expectEqual(@as(u32, 8), mock.register_args);
    try testing.expectEqual(@as(u32, 2), mock.stack_args);

    // Verify first 8 in registers
    for (0..8) |i| {
        try testing.expect(mock.getFloatArgReg(@intCast(i)) != null);
    }

    // Verify 9th and 10th on stack
    try testing.expectEqual(@as(?PReg, null), mock.getFloatArgReg(8));
    try testing.expectEqual(@as(?PReg, null), mock.getFloatArgReg(9));
}

test "arg classification: mixed int and float args" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 6 int + 6 float -> all in registers
    mock.setNumIntArgs(6);
    mock.setNumFloatArgs(6);
    try testing.expectEqual(@as(u32, 12), mock.register_args);
    try testing.expectEqual(@as(u32, 0), mock.stack_args);
}

test "arg classification: mixed args with overflow" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 10 int + 10 float -> 8 int regs + 8 float regs + 4 stack (2 int + 2 float)
    mock.setNumIntArgs(10);
    mock.setNumFloatArgs(10);
    try testing.expectEqual(@as(u32, 16), mock.register_args); // 8 int + 8 float
    try testing.expectEqual(@as(u32, 4), mock.stack_args); // 2 int + 2 float
}

test "arg classification: all args on stack" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 20 int args -> 8 in regs, 12 on stack
    mock.setNumIntArgs(20);
    try testing.expectEqual(@as(u32, 8), mock.register_args);
    try testing.expectEqual(@as(u32, 12), mock.stack_args);
}

test "arg classification: stack arg offsets are correct" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // Stack args at SP+0, SP+8, SP+16, SP+24, ...
    try testing.expectEqual(@as(u32, 0), mock.getStackArgOffset(0));
    try testing.expectEqual(@as(u32, 8), mock.getStackArgOffset(1));
    try testing.expectEqual(@as(u32, 16), mock.getStackArgOffset(2));
    try testing.expectEqual(@as(u32, 24), mock.getStackArgOffset(3));
    try testing.expectEqual(@as(u32, 64), mock.getStackArgOffset(8));
}

test "arg classification: int arg register mapping" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // X0-X7 mapping
    try testing.expectEqual(PReg.new(.int, 0), mock.getIntArgReg(0).?);
    try testing.expectEqual(PReg.new(.int, 1), mock.getIntArgReg(1).?);
    try testing.expectEqual(PReg.new(.int, 2), mock.getIntArgReg(2).?);
    try testing.expectEqual(PReg.new(.int, 7), mock.getIntArgReg(7).?);

    // X8+ on stack
    try testing.expectEqual(@as(?PReg, null), mock.getIntArgReg(8));
}

test "arg classification: float arg register mapping" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // V0-V7 mapping
    try testing.expectEqual(PReg.new(.float, 0), mock.getFloatArgReg(0).?);
    try testing.expectEqual(PReg.new(.float, 1), mock.getFloatArgReg(1).?);
    try testing.expectEqual(PReg.new(.float, 2), mock.getFloatArgReg(2).?);
    try testing.expectEqual(PReg.new(.float, 7), mock.getFloatArgReg(7).?);

    // V8+ on stack
    try testing.expectEqual(@as(?PReg, null), mock.getFloatArgReg(8));
}

test "arg classification: boundary case - exactly 8 int args" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // Exactly 8 int args -> all in registers, none on stack
    mock.setNumIntArgs(8);
    try testing.expectEqual(@as(u32, 8), mock.register_args);
    try testing.expectEqual(@as(u32, 0), mock.stack_args);
}

test "arg classification: boundary case - exactly 8 float args" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // Exactly 8 float args -> all in registers, none on stack
    mock.setNumFloatArgs(8);
    try testing.expectEqual(@as(u32, 8), mock.register_args);
    try testing.expectEqual(@as(u32, 0), mock.stack_args);
}

test "arg classification: no args" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // No args -> no registers, no stack
    try testing.expectEqual(@as(u32, 0), mock.register_args);
    try testing.expectEqual(@as(u32, 0), mock.stack_args);
}

test "arg classification: single int arg" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 1 int arg -> X0
    mock.setNumIntArgs(1);
    try testing.expectEqual(@as(u32, 1), mock.register_args);
    try testing.expectEqual(@as(u32, 0), mock.stack_args);

    try testing.expectEqual(PReg.new(.int, 0), mock.getIntArgReg(0).?);
}

test "arg classification: single float arg" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 1 float arg -> V0
    mock.setNumFloatArgs(1);
    try testing.expectEqual(@as(u32, 1), mock.register_args);
    try testing.expectEqual(@as(u32, 0), mock.stack_args);

    try testing.expectEqual(PReg.new(.float, 0), mock.getFloatArgReg(0).?);
}
