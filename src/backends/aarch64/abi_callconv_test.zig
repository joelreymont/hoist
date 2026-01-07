//! Calling convention ABI tests.
//!
//! Tests different calling conventions: Fast, PreserveAll, Cold.
//! Also tests platform-specific behavior (Darwin X18, red zone).

const std = @import("std");
const testing = std.testing;
const abi_mod = @import("abi.zig");
const aapcs64 = abi_mod.aapcs64;
const fast = abi_mod.fast;
const preserveAll = abi_mod.preserveAll;
const PReg = @import("../../machinst/reg.zig").PReg;

test "fast calling convention: extended int arg registers" {
    const fast_abi = fast();
    const standard_abi = aapcs64();

    // Fast has X0-X17 (18 regs) vs standard X0-X7 (8 regs)
    try testing.expectEqual(@as(usize, 18), fast_abi.int_arg_regs.len);
    try testing.expectEqual(@as(usize, 8), standard_abi.int_arg_regs.len);

    // Verify 9th arg (index 8) is in register in fast convention
    try testing.expectEqual(PReg.new(.int, 8), fast_abi.int_arg_regs[8]);

    // Verify 18th arg (index 17) is in register in fast convention
    try testing.expectEqual(PReg.new(.int, 17), fast_abi.int_arg_regs[17]);
}

test "fast calling convention: extended float arg registers" {
    const fast_abi = fast();
    const standard_abi = aapcs64();

    // Fast has V0-V15 (16 regs) vs standard V0-V7 (8 regs)
    try testing.expectEqual(@as(usize, 16), fast_abi.float_arg_regs.len);
    try testing.expectEqual(@as(usize, 8), standard_abi.float_arg_regs.len);

    // Verify 9th float arg (index 8) is in register in fast convention
    try testing.expectEqual(PReg.new(.float, 8), fast_abi.float_arg_regs[8]);

    // Verify 16th float arg (index 15) is in register in fast convention
    try testing.expectEqual(PReg.new(.float, 15), fast_abi.float_arg_regs[15]);
}

test "preserveAll calling convention: all GPRs saved except args" {
    const preserve_abi = preserveAll();
    const standard_abi = aapcs64();

    // Standard saves X19-X30 (12 regs)
    // PreserveAll saves X8-X30 (23 regs) - all except X0-X7 args and X31 (SP)
    const standard_gpr_saves = 12;
    const preserve_gpr_saves = 23;

    // Count GPRs in callee_saves
    var standard_gprs: usize = 0;
    for (standard_abi.callee_saves) |reg| {
        if (reg.class() == .int) standard_gprs += 1;
    }

    var preserve_gprs: usize = 0;
    for (preserve_abi.callee_saves) |reg| {
        if (reg.class() == .int) preserve_gprs += 1;
    }

    try testing.expectEqual(standard_gpr_saves, standard_gprs);
    try testing.expectEqual(preserve_gpr_saves, preserve_gprs);

    // Verify X8 is saved (caller-saved in standard, callee-saved in PreserveAll)
    try testing.expectEqual(PReg.new(.int, 8), preserve_abi.callee_saves[0]);
}

test "preserveAll calling convention: all FPRs saved except args" {
    const preserve_abi = preserveAll();
    const standard_abi = aapcs64();

    // Standard saves V8-V15 (8 regs)
    // PreserveAll saves V8-V31 (24 regs) - all except V0-V7 args
    const standard_fpr_saves = 8;
    const preserve_fpr_saves = 24;

    // Count FPRs in callee_saves
    var standard_fprs: usize = 0;
    for (standard_abi.callee_saves) |reg| {
        if (reg.class() == .float) standard_fprs += 1;
    }

    var preserve_fprs: usize = 0;
    for (preserve_abi.callee_saves) |reg| {
        if (reg.class() == .float) preserve_fprs += 1;
    }

    try testing.expectEqual(standard_fpr_saves, standard_fprs);
    try testing.expectEqual(preserve_fpr_saves, preserve_fprs);

    // Verify V16 is saved (caller-saved in standard, callee-saved in PreserveAll)
    // V16 is after 23 GPRs and 8 FPRs (V8-V15) = index 31
    try testing.expectEqual(PReg.new(.float, 16), preserve_abi.callee_saves[31]);
}

test "cold calling convention: same ABI as standard" {
    const root = @import("root");
    const abi_api = root.abi;

    var sig = abi_api.ABISignature.init(testing.allocator, .cold);
    defer sig.deinit();

    const callee = abi_mod.Aarch64ABICallee.init(testing.allocator, sig);

    // Cold uses standard AAPCS64 register allocation
    try testing.expectEqual(@as(usize, 8), callee.abi.int_arg_regs.len);
    try testing.expectEqual(@as(usize, 8), callee.abi.float_arg_regs.len);

    // But is_cold flag is set for metadata
    try testing.expect(callee.is_cold);
}

test "darwin platform: X18 never allocated" {
    const CallerSavedTracker = abi_mod.CallerSavedTracker;

    // On Darwin, X18 is platform-reserved and never marked as caller-saved
    var darwin_tracker = CallerSavedTracker.init(.darwin);
    darwin_tracker.markIntReg(PReg.new(.int, 18));
    try testing.expect(!darwin_tracker.int_regs.isSet(18));

    // On Linux, X18 is allocatable
    var linux_tracker = CallerSavedTracker.init(.linux);
    linux_tracker.markIntReg(PReg.new(.int, 18));
    try testing.expect(linux_tracker.int_regs.isSet(18));
}

test "darwin platform: red zone disabled" {
    const root = @import("root");
    const abi_api = root.abi;

    // Create a signature for Darwin
    var sig = abi_api.ABISignature.init(testing.allocator, .aapcs64);
    defer sig.deinit();

    // Note: This test runs on the current platform, so we can't directly test
    // Darwin-specific behavior unless we're on Darwin. The actual platform
    // detection happens at runtime in Aarch64ABICallee.init().
    // The red_zone_allowed field is set based on Platform.detect().

    // On Darwin (macOS/iOS), red_zone_allowed would be false
    // On Linux, red_zone_allowed would be true
    // We can only test the current platform behavior
    const callee = abi_mod.Aarch64ABICallee.init(testing.allocator, sig);

    const expected_platform = abi_mod.Platform.detect();
    try testing.expectEqual(expected_platform, callee.platform);

    if (expected_platform == .darwin) {
        try testing.expect(!callee.red_zone_allowed);
    } else {
        try testing.expect(callee.red_zone_allowed);
    }
}

test "calling convention: return registers same across conventions" {
    const standard = aapcs64();
    const fast_cc = fast();
    const preserve = preserveAll();

    // All conventions use same return registers: X0-X7, V0-V7
    try testing.expectEqual(@as(usize, 8), standard.int_ret_regs.len);
    try testing.expectEqual(@as(usize, 8), fast_cc.int_ret_regs.len);
    try testing.expectEqual(@as(usize, 8), preserve.int_ret_regs.len);

    try testing.expectEqual(@as(usize, 8), standard.float_ret_regs.len);
    try testing.expectEqual(@as(usize, 8), fast_cc.float_ret_regs.len);
    try testing.expectEqual(@as(usize, 8), preserve.float_ret_regs.len);

    // X0 is first return register in all conventions
    try testing.expectEqual(PReg.new(.int, 0), standard.int_ret_regs[0]);
    try testing.expectEqual(PReg.new(.int, 0), fast_cc.int_ret_regs[0]);
    try testing.expectEqual(PReg.new(.int, 0), preserve.int_ret_regs[0]);
}
