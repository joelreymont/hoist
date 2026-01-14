const std = @import("std");
const testing = std.testing;

const root = @import("root");
const abi = @import("../src/backends/aarch64/abi.zig");
const PReg = root.aarch64_inst.PReg;

// Test AAPCS64 integer argument registers
test "aapcs64 int arg registers" {
    const spec = abi.aapcs64();

    try testing.expectEqual(@as(usize, 8), spec.int_arg_regs.len);

    // X0-X7
    try testing.expectEqual(@as(u8, 0), spec.int_arg_regs[0].nr());
    try testing.expectEqual(@as(u8, 1), spec.int_arg_regs[1].nr());
    try testing.expectEqual(@as(u8, 7), spec.int_arg_regs[7].nr());
}

// Test AAPCS64 float argument registers
test "aapcs64 float arg registers" {
    const spec = abi.aapcs64();

    try testing.expectEqual(@as(usize, 8), spec.float_arg_regs.len);

    // V0-V7
    try testing.expectEqual(@as(u8, 0), spec.float_arg_regs[0].nr());
    try testing.expectEqual(@as(u8, 7), spec.float_arg_regs[7].nr());
}

// Test AAPCS64 callee-save registers
test "aapcs64 callee saves" {
    const spec = abi.aapcs64();

    try testing.expectEqual(@as(usize, 12), spec.callee_saves.len);

    // X19-X28, X29 (FP), X30 (LR)
    try testing.expectEqual(@as(u8, 19), spec.callee_saves[0].nr());
    try testing.expectEqual(@as(u8, 29), spec.callee_saves[10].nr()); // FP
    try testing.expectEqual(@as(u8, 30), spec.callee_saves[11].nr()); // LR
}

// Test AAPCS64 stack alignment requirement
test "aapcs64 stack alignment" {
    const spec = abi.aapcs64();

    try testing.expectEqual(@as(u64, 16), spec.stack_align);
}

// Test AAPCS64 return registers
test "aapcs64 return registers" {
    const spec = abi.aapcs64();

    try testing.expectEqual(@as(usize, 8), spec.int_ret_regs.len);
    try testing.expectEqual(@as(usize, 8), spec.float_ret_regs.len);

    try testing.expectEqual(@as(u8, 0), spec.int_ret_regs[0].nr());
    try testing.expectEqual(@as(u8, 0), spec.float_ret_regs[0].nr());
}
