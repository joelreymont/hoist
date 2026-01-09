//! Memory flags and alias regions for load/store instructions.
//!
//! These flags enable alias analysis and memory-related optimizations.

const std = @import("std");

/// Memory alias region - identifies which category of memory an access belongs to.
///
/// Memory accesses to different regions are guaranteed not to alias.
/// This property must be ensured by the frontend during IR generation.
pub const AliasRegion = enum(u8) {
    /// Stack slots (stack_load/stack_store).
    /// Stack accesses never alias with heap or global memory.
    stack,

    /// Heap memory (load/store with dynamically computed addresses).
    /// General heap allocations and dynamically addressed memory.
    heap,

    /// Global values (global_value accesses).
    /// Read-only globals, function addresses, etc.
    global,

    /// Unknown or mixed memory.
    /// Conservative fallback when region cannot be determined.
    unknown,
};

/// Memory access flags.
///
/// Provides information about memory accesses to enable optimizations
/// while maintaining correctness.
pub const MemFlags = struct {
    /// Which alias region this access belongs to.
    alias_region: AliasRegion = .unknown,

    /// Whether this is a volatile access.
    /// Volatile accesses cannot be reordered, eliminated, or optimized.
    is_volatile: bool = false,

    /// Whether this access is properly aligned.
    /// Can enable faster code generation on some architectures.
    aligned: bool = false,

    /// Create default memory flags (unknown region, non-volatile, unaligned).
    pub fn default() MemFlags {
        return .{
            .alias_region = .unknown,
            .is_volatile = false,
            .aligned = false,
        };
    }

    /// Create memory flags for a stack access.
    pub fn stack() MemFlags {
        return .{
            .alias_region = .stack,
            .is_volatile = false,
            .aligned = true, // Stack is typically aligned
        };
    }

    /// Create memory flags for a heap access.
    pub fn heap() MemFlags {
        return .{
            .alias_region = .heap,
            .is_volatile = false,
            .aligned = false,
        };
    }

    /// Create memory flags for a global access.
    pub fn global() MemFlags {
        return .{
            .alias_region = .global,
            .is_volatile = false,
            .aligned = true, // Globals are typically aligned
        };
    }

    /// Returns true if this access may alias with another.
    pub fn mayAlias(self: MemFlags, other: MemFlags) bool {
        // Volatile accesses are always considered to alias
        if (self.is_volatile or other.is_volatile) return true;

        // Unknown region is conservative - may alias with anything
        if (self.alias_region == .unknown or other.alias_region == .unknown) {
            return true;
        }

        // Different non-unknown regions never alias
        if (self.alias_region != other.alias_region) return false;

        // Same non-unknown region - may alias
        return true;
    }
};

// Tests
const testing = std.testing;

test "MemFlags.default" {
    const flags = MemFlags.default();
    try testing.expectEqual(AliasRegion.unknown, flags.alias_region);
    try testing.expectEqual(false, flags.is_volatile);
    try testing.expectEqual(false, flags.aligned);
}

test "MemFlags.stack" {
    const flags = MemFlags.stack();
    try testing.expectEqual(AliasRegion.stack, flags.alias_region);
    try testing.expectEqual(true, flags.aligned);
}

test "MemFlags.mayAlias - different regions" {
    const stack = MemFlags.stack();
    const heap = MemFlags.heap();
    try testing.expectEqual(false, stack.mayAlias(heap));
}

test "MemFlags.mayAlias - same region" {
    const heap1 = MemFlags.heap();
    const heap2 = MemFlags.heap();
    try testing.expectEqual(true, heap1.mayAlias(heap2));
}

test "MemFlags.mayAlias - volatile always aliases" {
    var stack = MemFlags.stack();
    const heap = MemFlags.heap();
    stack.is_volatile = true;
    try testing.expectEqual(true, stack.mayAlias(heap));
}

test "MemFlags.mayAlias - unknown is conservative" {
    const unknown = MemFlags.default();
    const stack = MemFlags.stack();
    try testing.expectEqual(true, unknown.mayAlias(stack));
}
