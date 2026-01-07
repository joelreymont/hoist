//! Property-based tests for AArch64 ABI frame layout.

const std = @import("std");
const testing = std.testing;
const abi_mod = @import("../../abi.zig");
const aarch64_abi = @import("abi.zig");

test "prop: frame_size always 16-byte aligned" {
    const allocator = testing.allocator;
    var prng = std.Random.DefaultPrng.init(0x12345678);
    const random = prng.random();

    for (0..100) |_| {
        const locals_size = random.intRangeAtMost(u32, 0, 10240);
        const callee_saves_count = random.intRangeAtMost(u32, 0, 10);

        var sig = abi_mod.ABISignature.init(allocator, .aapcs64);
        defer sig.deinit();

        var callee = aarch64_abi.Aarch64ABICallee.init(allocator, sig);
        defer callee.deinit();

        for (0..callee_saves_count) |i| {
            const reg_class: @import("../../machinst/machinst.zig").RegClass =
                if (i % 2 == 0) .int else .float;
            try callee.clobbered_callee_saves.append(
                allocator,
                @import("../../machinst/machinst.zig").PReg.new(reg_class, @intCast(i))
            );
        }

        callee.setLocalsSize(locals_size);

        // Property: frame_size must be 16-byte aligned
        try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);
    }
}

test "prop: large frames require frame pointer" {
    const allocator = testing.allocator;
    var prng = std.Random.DefaultPrng.init(0xABCDEF01);
    const random = prng.random();

    const fp_threshold = 4096;

    for (0..100) |_| {
        var sig = abi_mod.ABISignature.init(allocator, .aapcs64);
        defer sig.deinit();

        var callee = aarch64_abi.Aarch64ABICallee.init(allocator, sig);
        defer callee.deinit();

        const locals_size = random.intRangeAtMost(u32, 0, 8192);
        callee.setLocalsSize(locals_size);

        // Property: frames >4KB require FP
        if (callee.frame_size > fp_threshold) {
            try testing.expect(callee.uses_frame_pointer);
        }
    }
}

test "prop: dynamic allocations require frame pointer and X19" {
    const allocator = testing.allocator;

    var sig = abi_mod.ABISignature.init(allocator, .aapcs64);
    defer sig.deinit();

    var callee = aarch64_abi.Aarch64ABICallee.init(allocator, sig);
    defer callee.deinit();

    callee.enableDynamicAlloc();

    // Properties: dynamic alloc requires FP and uses X19
    try testing.expect(callee.uses_frame_pointer);
    try testing.expect(callee.has_dynamic_alloc);
    
    const dyn_sp = callee.getDynStackPointer().?;
    try testing.expectEqual(@as(u32, 19), dyn_sp.index);
}
