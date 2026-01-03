/// Compute "magic numbers" for division-by-constants transformations.
///
/// Math helpers for division by (non-power-of-2) constants. This is based
/// on the presentation in "Hacker's Delight" by Henry Warren, 2003.
///
/// Ported from cranelift-codegen div_const.rs.
const std = @import("std");

/// Magic numbers for unsigned 32-bit division.
pub const MagicU32 = struct {
    /// Multiplier (magic constant).
    mul_by: u32,
    /// Whether to add dividend before shifting.
    do_add: bool,
    /// Post-multiply right shift amount.
    shift_by: i32,
};

/// Magic numbers for unsigned 64-bit division.
pub const MagicU64 = struct {
    /// Multiplier (magic constant).
    mul_by: u64,
    /// Whether to add dividend before shifting.
    do_add: bool,
    /// Post-multiply right shift amount.
    shift_by: i32,
};

/// Magic numbers for signed 32-bit division.
pub const MagicS32 = struct {
    /// Multiplier (magic constant).
    mul_by: i32,
    /// Post-multiply right shift amount.
    shift_by: i32,
};

/// Magic numbers for signed 64-bit division.
pub const MagicS64 = struct {
    /// Multiplier (magic constant).
    mul_by: i64,
    /// Post-multiply right shift amount.
    shift_by: i32,
};

/// Compute magic numbers for unsigned 32-bit division by constant.
///
/// Given a divisor `d`, computes a magic multiplier and shift amount such that:
/// `(n * mul_by) >> 32` followed by optional add and shift gives `n / d`.
///
/// Preconditions: d != 0 and d != 1 (d==1 generates out of range shifts).
pub fn magicU32(d: u32) MagicU32 {
    std.debug.assert(d != 0);
    std.debug.assert(d != 1);

    var do_add: bool = false;
    var p: i32 = 31;
    const nc: u32 = 0xFFFFFFFF -% (0 -% d) % d;
    var q1: u32 = 0x80000000 / nc;
    var r1: u32 = 0x80000000 - q1 * nc;
    var q2: u32 = 0x7FFFFFFF / d;
    var r2: u32 = 0x7FFFFFFF - q2 * d;

    while (true) {
        p = p + 1;
        if (r1 >= nc - r1) {
            q1 = (2 *% q1) +% 1;
            r1 = (2 *% r1) -% nc;
        } else {
            q1 = 2 *% q1;
            r1 = 2 * r1;
        }
        if (r2 + 1 >= d - r2) {
            if (q2 >= 0x7FFFFFFF) {
                do_add = true;
            }
            q2 = 2 * q2 + 1;
            r2 = ((2 *% r2) +% 1) -% d;
        } else {
            if (q2 >= 0x80000000) {
                do_add = true;
            }
            q2 = 2 *% q2;
            r2 = 2 * r2 + 1;
        }
        const delta: u32 = d - 1 - r2;
        if (!(p < 64 and (q1 < delta or (q1 == delta and r1 == 0)))) {
            break;
        }
    }

    return MagicU32{
        .mul_by = q2 + 1,
        .do_add = do_add,
        .shift_by = p - 32,
    };
}

/// Compute magic numbers for unsigned 64-bit division by constant.
///
/// Preconditions: d != 0 and d != 1 (d==1 generates out of range shifts).
pub fn magicU64(d: u64) MagicU64 {
    std.debug.assert(d != 0);
    std.debug.assert(d != 1);

    var do_add: bool = false;
    var p: i32 = 63;
    const nc: u64 = 0xFFFFFFFFFFFFFFFF -% (0 -% d) % d;
    var q1: u64 = 0x8000000000000000 / nc;
    var r1: u64 = 0x8000000000000000 - q1 * nc;
    var q2: u64 = 0x7FFFFFFFFFFFFFFF / d;
    var r2: u64 = 0x7FFFFFFFFFFFFFFF - q2 * d;

    while (true) {
        p = p + 1;
        if (r1 >= nc - r1) {
            q1 = (2 *% q1) +% 1;
            r1 = (2 *% r1) -% nc;
        } else {
            q1 = 2 *% q1;
            r1 = 2 * r1;
        }
        if (r2 + 1 >= d - r2) {
            if (q2 >= 0x7FFFFFFFFFFFFFFF) {
                do_add = true;
            }
            q2 = 2 * q2 + 1;
            r2 = ((2 *% r2) +% 1) -% d;
        } else {
            if (q2 >= 0x8000000000000000) {
                do_add = true;
            }
            q2 = 2 *% q2;
            r2 = 2 * r2 + 1;
        }
        const delta: u64 = d - 1 - r2;
        if (!(p < 128 and (q1 < delta or (q1 == delta and r1 == 0)))) {
            break;
        }
    }

    return MagicU64{
        .mul_by = q2 + 1,
        .do_add = do_add,
        .shift_by = p - 64,
    };
}

/// Compute magic numbers for signed 32-bit division by constant.
///
/// Preconditions: d != -1, d != 0, d != 1.
pub fn magicS32(d: i32) MagicS32 {
    std.debug.assert(d != -1);
    std.debug.assert(d != 0);
    std.debug.assert(d != 1);

    const two31: u32 = 0x80000000;
    var p: i32 = 31;
    const ad: u32 = @abs(d);
    const t: u32 = two31 + (@as(u32, @bitCast(d)) >> 31);
    const anc: u32 = (t - 1) -% (t % ad);
    var q1: u32 = two31 / anc;
    var r1: u32 = two31 - q1 * anc;
    var q2: u32 = two31 / ad;
    var r2: u32 = two31 - q2 * ad;

    while (true) {
        p = p + 1;
        q1 = 2 * q1;
        r1 = 2 * r1;
        if (r1 >= anc) {
            q1 = q1 + 1;
            r1 = r1 - anc;
        }
        q2 = 2 * q2;
        r2 = 2 * r2;
        if (r2 >= ad) {
            q2 = q2 + 1;
            r2 = r2 - ad;
        }
        const delta: u32 = ad - r2;
        if (!(q1 < delta or (q1 == delta and r1 == 0))) {
            break;
        }
    }

    return MagicS32{
        .mul_by = @bitCast(if (d < 0) -%@as(u32, q2 + 1) else q2 + 1),
        .shift_by = p - 32,
    };
}

/// Compute magic numbers for signed 64-bit division by constant.
///
/// Preconditions: d != -1, d != 0, d != 1.
pub fn magicS64(d: i64) MagicS64 {
    std.debug.assert(d != -1);
    std.debug.assert(d != 0);
    std.debug.assert(d != 1);

    const two63: u64 = 0x8000000000000000;
    var p: i32 = 63;
    const ad: u64 = @abs(d);
    const t: u64 = two63 + (@as(u64, @bitCast(d)) >> 63);
    const anc: u64 = (t - 1) -% (t % ad);
    var q1: u64 = two63 / anc;
    var r1: u64 = two63 - q1 * anc;
    var q2: u64 = two63 / ad;
    var r2: u64 = two63 - q2 * ad;

    while (true) {
        p = p + 1;
        q1 = 2 * q1;
        r1 = 2 * r1;
        if (r1 >= anc) {
            q1 = q1 + 1;
            r1 = r1 - anc;
        }
        q2 = 2 * q2;
        r2 = 2 * r2;
        if (r2 >= ad) {
            q2 = q2 + 1;
            r2 = r2 - ad;
        }
        const delta: u64 = ad - r2;
        if (!(q1 < delta or (q1 == delta and r1 == 0))) {
            break;
        }
    }

    return MagicS64{
        .mul_by = @bitCast(if (d < 0) -%@as(u64, q2 + 1) else q2 + 1),
        .shift_by = p - 64,
    };
}

// Tests (ported from Cranelift)
const testing = std.testing;

test "magicU32 comprehensive" {
    // Test vectors from Cranelift's div_const.rs test suite
    try testing.expectEqual(MagicU32{ .mul_by = 0x80000000, .do_add = false, .shift_by = 0 }, magicU32(2));
    try testing.expectEqual(MagicU32{ .mul_by = 0xaaaaaaab, .do_add = false, .shift_by = 1 }, magicU32(3));
    try testing.expectEqual(MagicU32{ .mul_by = 0x40000000, .do_add = false, .shift_by = 0 }, magicU32(4));
    try testing.expectEqual(MagicU32{ .mul_by = 0xcccccccd, .do_add = false, .shift_by = 2 }, magicU32(5));
    try testing.expectEqual(MagicU32{ .mul_by = 0xaaaaaaab, .do_add = false, .shift_by = 2 }, magicU32(6));
    try testing.expectEqual(MagicU32{ .mul_by = 0x24924925, .do_add = true, .shift_by = 3 }, magicU32(7));
    try testing.expectEqual(MagicU32{ .mul_by = 0x38e38e39, .do_add = false, .shift_by = 1 }, magicU32(9));
    try testing.expectEqual(MagicU32{ .mul_by = 0xcccccccd, .do_add = false, .shift_by = 3 }, magicU32(10));
    try testing.expectEqual(MagicU32{ .mul_by = 0xba2e8ba3, .do_add = false, .shift_by = 3 }, magicU32(11));
    try testing.expectEqual(MagicU32{ .mul_by = 0xaaaaaaab, .do_add = false, .shift_by = 3 }, magicU32(12));
    try testing.expectEqual(MagicU32{ .mul_by = 0x51eb851f, .do_add = false, .shift_by = 3 }, magicU32(25));
    try testing.expectEqual(MagicU32{ .mul_by = 0x10624dd3, .do_add = false, .shift_by = 3 }, magicU32(125));
    try testing.expectEqual(MagicU32{ .mul_by = 0xd1b71759, .do_add = false, .shift_by = 9 }, magicU32(625));
    try testing.expectEqual(MagicU32{ .mul_by = 0x88233b2b, .do_add = true, .shift_by = 11 }, magicU32(1337));
    try testing.expectEqual(MagicU32{ .mul_by = 0x80008001, .do_add = false, .shift_by = 15 }, magicU32(65535));
    try testing.expectEqual(MagicU32{ .mul_by = 0x00010000, .do_add = false, .shift_by = 0 }, magicU32(65536));
    try testing.expectEqual(MagicU32{ .mul_by = 0xffff0001, .do_add = false, .shift_by = 16 }, magicU32(65537));
    try testing.expectEqual(MagicU32{ .mul_by = 0x445b4553, .do_add = false, .shift_by = 23 }, magicU32(31415927));
    try testing.expectEqual(MagicU32{ .mul_by = 0x93275ab3, .do_add = false, .shift_by = 31 }, magicU32(0xdeadbeef));
    try testing.expectEqual(MagicU32{ .mul_by = 0x40000001, .do_add = false, .shift_by = 30 }, magicU32(0xfffffffd));
    try testing.expectEqual(MagicU32{ .mul_by = 0x00000003, .do_add = true, .shift_by = 32 }, magicU32(0xfffffffe));
    try testing.expectEqual(MagicU32{ .mul_by = 0x80000001, .do_add = false, .shift_by = 31 }, magicU32(0xffffffff));
}

test "magicU64 comprehensive" {
    // Test vectors from Cranelift's div_const.rs test suite
    try testing.expectEqual(MagicU64{ .mul_by = 0x8000000000000000, .do_add = false, .shift_by = 0 }, magicU64(2));
    try testing.expectEqual(MagicU64{ .mul_by = 0xaaaaaaaaaaaaaaab, .do_add = false, .shift_by = 1 }, magicU64(3));
    try testing.expectEqual(MagicU64{ .mul_by = 0x4000000000000000, .do_add = false, .shift_by = 0 }, magicU64(4));
    try testing.expectEqual(MagicU64{ .mul_by = 0xcccccccccccccccd, .do_add = false, .shift_by = 2 }, magicU64(5));
    try testing.expectEqual(MagicU64{ .mul_by = 0xaaaaaaaaaaaaaaab, .do_add = false, .shift_by = 2 }, magicU64(6));
    try testing.expectEqual(MagicU64{ .mul_by = 0x2492492492492493, .do_add = true, .shift_by = 3 }, magicU64(7));
    try testing.expectEqual(MagicU64{ .mul_by = 0xe38e38e38e38e38f, .do_add = false, .shift_by = 3 }, magicU64(9));
    try testing.expectEqual(MagicU64{ .mul_by = 0xcccccccccccccccd, .do_add = false, .shift_by = 3 }, magicU64(10));
    try testing.expectEqual(MagicU64{ .mul_by = 0x2e8ba2e8ba2e8ba3, .do_add = false, .shift_by = 1 }, magicU64(11));
    try testing.expectEqual(MagicU64{ .mul_by = 0xaaaaaaaaaaaaaaab, .do_add = false, .shift_by = 3 }, magicU64(12));
    try testing.expectEqual(MagicU64{ .mul_by = 0x47ae147ae147ae15, .do_add = true, .shift_by = 5 }, magicU64(25));
    try testing.expectEqual(MagicU64{ .mul_by = 0x0624dd2f1a9fbe77, .do_add = true, .shift_by = 7 }, magicU64(125));
    try testing.expectEqual(MagicU64{ .mul_by = 0x346dc5d63886594b, .do_add = false, .shift_by = 7 }, magicU64(625));
    try testing.expectEqual(MagicU64{ .mul_by = 0xc4119d952866a139, .do_add = false, .shift_by = 10 }, magicU64(1337));
    try testing.expectEqual(MagicU64{ .mul_by = 0x116d154b9c3d2f85, .do_add = true, .shift_by = 25 }, magicU64(31415927));
    try testing.expectEqual(MagicU64{ .mul_by = 0x93275ab2dfc9094b, .do_add = false, .shift_by = 31 }, magicU64(0x00000000deadbeef));
    try testing.expectEqual(MagicU64{ .mul_by = 0x8000000180000005, .do_add = false, .shift_by = 31 }, magicU64(0x00000000fffffffd));
    try testing.expectEqual(MagicU64{ .mul_by = 0x0000000200000005, .do_add = true, .shift_by = 32 }, magicU64(0x00000000fffffffe));
}

test "magicS32 comprehensive" {
    // Test a few key values (full test suite would use property testing)
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x55555556)), .shift_by = 0 }, magicS32(3));
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x66666667)), .shift_by = 1 }, magicS32(5));
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x2aaaaaab)), .shift_by = 0 }, magicS32(6));
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x92492493)), .shift_by = 2 }, magicS32(7));
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x38e38e39)), .shift_by = 1 }, magicS32(9));
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x66666667)), .shift_by = 2 }, magicS32(10));
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x2e8ba2e9)), .shift_by = 1 }, magicS32(11));
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x2aaaaaab)), .shift_by = 1 }, magicS32(12));
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x51eb851f)), .shift_by = 3 }, magicS32(25));
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x10624dd3)), .shift_by = 3 }, magicS32(125));
    // Computed values for larger divisors
    try testing.expectEqual(MagicS32{ .mul_by = @bitCast(@as(u32, 0x68db8bad)), .shift_by = 8 }, magicS32(625));
}

test "magicS64 comprehensive" {
    // Test a few key values (full test suite would use property testing)
    try testing.expectEqual(MagicS64{ .mul_by = @bitCast(@as(u64, 0x5555555555555556)), .shift_by = 0 }, magicS64(3));
    try testing.expectEqual(MagicS64{ .mul_by = @bitCast(@as(u64, 0x6666666666666667)), .shift_by = 1 }, magicS64(5));
    try testing.expectEqual(MagicS64{ .mul_by = @bitCast(@as(u64, 0x2aaaaaaaaaaaaaab)), .shift_by = 0 }, magicS64(6));
    try testing.expectEqual(MagicS64{ .mul_by = @bitCast(@as(u64, 0x4924924924924925)), .shift_by = 1 }, magicS64(7));
    try testing.expectEqual(MagicS64{ .mul_by = @bitCast(@as(u64, 0x1c71c71c71c71c72)), .shift_by = 0 }, magicS64(9));
    try testing.expectEqual(MagicS64{ .mul_by = @bitCast(@as(u64, 0x6666666666666667)), .shift_by = 2 }, magicS64(10));
    try testing.expectEqual(MagicS64{ .mul_by = @bitCast(@as(u64, 0x2e8ba2e8ba2e8ba3)), .shift_by = 1 }, magicS64(11));
    try testing.expectEqual(MagicS64{ .mul_by = @bitCast(@as(u64, 0x2aaaaaaaaaaaaaab)), .shift_by = 1 }, magicS64(12));
}
