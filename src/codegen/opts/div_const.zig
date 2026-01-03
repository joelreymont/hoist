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

// Tests (port from Cranelift)
const testing = std.testing;

test "magicU32 basic" {
    const m = magicU32(7);
    try testing.expect(m.mul_by != 0);
    try testing.expect(m.shift_by >= 0);
}

test "magicU64 basic" {
    const m = magicU64(7);
    try testing.expect(m.mul_by != 0);
    try testing.expect(m.shift_by >= 0);
}

test "magicS32 basic" {
    const m = magicS32(7);
    try testing.expect(m.mul_by != 0);
    try testing.expect(m.shift_by >= 0);
}

test "magicS64 basic" {
    const m = magicS64(7);
    try testing.expect(m.mul_by != 0);
    try testing.expect(m.shift_by >= 0);
}
