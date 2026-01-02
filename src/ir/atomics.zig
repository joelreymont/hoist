const std = @import("std");
const testing = std.testing;

/// Atomic memory ordering for atomic operations.
/// Corresponds to LLVM atomic orderings and C++11 memory_order.
pub const AtomicOrdering = enum(u8) {
    /// Unordered - no ordering constraints, just atomicity.
    unordered = 0,

    /// Monotonic - no synchronization, just atomic modification.
    /// Prevents tearing but allows reordering with other operations.
    monotonic = 1,

    /// Acquire - synchronizes with release stores.
    /// Prevents hoisting loads/stores after this operation.
    acquire = 2,

    /// Release - synchronizes with acquire loads.
    /// Prevents sinking loads/stores before this operation.
    release = 3,

    /// AcquireRelease - combines acquire and release semantics.
    /// For read-modify-write operations.
    acq_rel = 4,

    /// SequentiallyConsistent - total global ordering.
    /// Strongest ordering, prevents all reordering.
    seq_cst = 5,

    /// Check if ordering has acquire semantics.
    pub fn isAcquire(self: AtomicOrdering) bool {
        return switch (self) {
            .acquire, .acq_rel, .seq_cst => true,
            else => false,
        };
    }

    /// Check if ordering has release semantics.
    pub fn isRelease(self: AtomicOrdering) bool {
        return switch (self) {
            .release, .acq_rel, .seq_cst => true,
            else => false,
        };
    }

    /// Check if ordering is sequentially consistent.
    pub fn isSeqCst(self: AtomicOrdering) bool {
        return self == .seq_cst;
    }

    /// Get the minimum ordering that provides both this and other's guarantees.
    pub fn merge(self: AtomicOrdering, other: AtomicOrdering) AtomicOrdering {
        const a = @intFromEnum(self);
        const b = @intFromEnum(other);
        return @enumFromInt(@max(a, b));
    }
};

/// Atomic read-modify-write operation.
pub const AtomicRmwOp = enum {
    /// Exchange - swap value.
    xchg,
    /// Add.
    add,
    /// Subtract.
    sub,
    /// Bitwise AND.
    @"and",
    /// Bitwise NAND.
    nand,
    /// Bitwise OR.
    @"or",
    /// Bitwise XOR.
    xor,
    /// Maximum (signed).
    max,
    /// Minimum (signed).
    min,
    /// Maximum (unsigned).
    umax,
    /// Minimum (unsigned).
    umin,
};

test "AtomicOrdering isAcquire" {
    try testing.expect(!AtomicOrdering.unordered.isAcquire());
    try testing.expect(!AtomicOrdering.monotonic.isAcquire());
    try testing.expect(AtomicOrdering.acquire.isAcquire());
    try testing.expect(!AtomicOrdering.release.isAcquire());
    try testing.expect(AtomicOrdering.acq_rel.isAcquire());
    try testing.expect(AtomicOrdering.seq_cst.isAcquire());
}

test "AtomicOrdering isRelease" {
    try testing.expect(!AtomicOrdering.unordered.isRelease());
    try testing.expect(!AtomicOrdering.monotonic.isRelease());
    try testing.expect(!AtomicOrdering.acquire.isRelease());
    try testing.expect(AtomicOrdering.release.isRelease());
    try testing.expect(AtomicOrdering.acq_rel.isRelease());
    try testing.expect(AtomicOrdering.seq_cst.isRelease());
}

test "AtomicOrdering merge" {
    try testing.expectEqual(AtomicOrdering.monotonic, AtomicOrdering.unordered.merge(.monotonic));
    try testing.expectEqual(AtomicOrdering.acquire, AtomicOrdering.monotonic.merge(.acquire));
    try testing.expectEqual(AtomicOrdering.seq_cst, AtomicOrdering.release.merge(.seq_cst));
    try testing.expectEqual(AtomicOrdering.acq_rel, AtomicOrdering.acquire.merge(.release));
}
