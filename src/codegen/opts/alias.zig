//! Alias analysis optimization pass.
//!
//! Implements memory alias analysis to enable:
//! - Redundant load elimination (RLE)
//! - Store-to-load forwarding
//! - Foundation for LICM load hoisting
//!
//! Based on Cranelift's alias analysis approach but simplified for Hoist's needs.

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir = @import("../../ir.zig");
const Block = ir.Block;
const Inst = ir.Inst;
const Value = ir.Value;
const Opcode = ir.Opcode;
const Type = ir.types.Type;
const Function = ir.Function;
const DominatorTree = ir.DominatorTree;

const memflags = @import("../../ir/memflags.zig");
const AliasRegion = memflags.AliasRegion;
const MemFlags = memflags.MemFlags;

/// Tracks the last store instruction for each alias region at a program point.
///
/// This is used to partition the analysis: stores to different regions are
/// guaranteed not to alias, so we track them separately.
pub const LastStores = struct {
    /// Last store to stack memory (stack_load/stack_store)
    stack: ?Inst = null,

    /// Last store to heap memory (general load/store)
    heap: ?Inst = null,

    /// Last store to global memory (global_value)
    global: ?Inst = null,

    /// Last store to unknown/mixed memory
    unknown: ?Inst = null,

    /// Update last stores based on an instruction.
    ///
    /// If the instruction is a store or has memory fence semantics (like a call),
    /// update the appropriate last-store slots.
    pub fn update(self: *LastStores, inst: Inst, opcode: Opcode, flags: ?MemFlags) void {
        // Memory fences (calls, etc.) invalidate all tracked stores conservatively
        if (hasMemoryFenceSemantics(opcode)) {
            self.stack = inst;
            self.heap = inst;
            self.global = inst;
            self.unknown = inst;
            return;
        }

        // Only stores update the last-store tracking
        if (!opcode.can_store()) return;

        // Update the appropriate slot based on alias region
        if (flags) |f| {
            switch (f.alias_region) {
                .stack => self.stack = inst,
                .heap => self.heap = inst,
                .global => self.global = inst,
                .unknown => self.unknown = inst,
            }
        } else {
            // No flags means unknown region - conservatively update all
            self.stack = inst;
            self.heap = inst;
            self.global = inst;
            self.unknown = inst;
        }
    }

    /// Get the last store for a given memory access.
    pub fn getLastStore(self: *const LastStores, flags: ?MemFlags) ?Inst {
        if (flags) |f| {
            return switch (f.alias_region) {
                .stack => self.stack,
                .heap => self.heap,
                .global => self.global,
                .unknown => self.unknown,
            };
        }
        // No flags means unknown - return unknown last store
        return self.unknown;
    }

    /// Merge last stores from multiple predecessors at a control flow join point.
    ///
    /// The merge operation is conservative: if different predecessors have
    /// different last stores, we use the join point instruction as a conservative
    /// approximation.
    pub fn meet(self: *LastStores, other: *const LastStores, meet_point: Inst) void {
        self.stack = meetSlot(self.stack, other.stack, meet_point);
        self.heap = meetSlot(self.heap, other.heap, meet_point);
        self.global = meetSlot(self.global, other.global, meet_point);
        self.unknown = meetSlot(self.unknown, other.unknown, meet_point);
    }

    /// Meet operation for a single slot.
    fn meetSlot(a: ?Inst, b: ?Inst, meet_point: Inst) ?Inst {
        // If both are null, result is null
        if (a == null and b == null) return null;

        // If one is null, take the non-null one
        if (a == null) return b;
        if (b == null) return a;

        // If both are the same, keep it
        if (a.? == b.?) return a;

        // Different non-null stores: use meet point as conservative approximation
        return meet_point;
    }
};

/// Returns true if an opcode has memory fence semantics.
///
/// Instructions with fence semantics conservatively invalidate all
/// tracked memory state.
fn hasMemoryFenceSemantics(opcode: Opcode) bool {
    return switch (opcode) {
        // Calls can access any memory
        .call, .call_indirect, .return_call, .return_call_indirect => true,
        .try_call, .try_call_indirect => true,

        // Atomic operations have fence semantics
        .atomic_load, .atomic_store, .atomic_rmw, .atomic_cas, .fence => true,

        // Everything else does not have fence semantics
        else => false,
    };
}

// Tests
const testing = std.testing;

test "LastStores.update - store to stack" {
    var ls = LastStores{};
    const inst = Inst.fromU32(42);
    const flags = MemFlags.stack();

    ls.update(inst, .store, flags);

    try testing.expectEqual(inst, ls.stack.?);
    try testing.expectEqual(@as(?Inst, null), ls.heap);
    try testing.expectEqual(@as(?Inst, null), ls.global);
}

test "LastStores.update - store to heap" {
    var ls = LastStores{};
    const inst = Inst.fromU32(42);
    const flags = MemFlags.heap();

    ls.update(inst, .store, flags);

    try testing.expectEqual(@as(?Inst, null), ls.stack);
    try testing.expectEqual(inst, ls.heap.?);
    try testing.expectEqual(@as(?Inst, null), ls.global);
}

test "LastStores.update - memory fence invalidates all" {
    var ls = LastStores{};
    ls.stack = Inst.fromU32(10);
    ls.heap = Inst.fromU32(20);
    ls.global = Inst.fromU32(30);

    const fence_inst = Inst.fromU32(99);
    ls.update(fence_inst, .call, null);

    try testing.expectEqual(fence_inst, ls.stack.?);
    try testing.expectEqual(fence_inst, ls.heap.?);
    try testing.expectEqual(fence_inst, ls.global.?);
    try testing.expectEqual(fence_inst, ls.unknown.?);
}

test "LastStores.getLastStore" {
    var ls = LastStores{};
    const stack_inst = Inst.fromU32(10);
    const heap_inst = Inst.fromU32(20);

    ls.stack = stack_inst;
    ls.heap = heap_inst;

    const stack_flags = MemFlags.stack();
    const heap_flags = MemFlags.heap();

    try testing.expectEqual(stack_inst, ls.getLastStore(stack_flags).?);
    try testing.expectEqual(heap_inst, ls.getLastStore(heap_flags).?);
}

test "LastStores.meet - same stores" {
    var ls1 = LastStores{};
    const ls2 = LastStores{};
    const inst = Inst.fromU32(42);

    ls1.stack = inst;
    ls1.heap = inst;

    const meet_point = Inst.fromU32(100);
    ls1.meet(&ls2, meet_point);

    // One side has inst, other has null -> keep inst
    try testing.expectEqual(inst, ls1.stack.?);
    try testing.expectEqual(inst, ls1.heap.?);
}

test "LastStores.meet - different stores" {
    var ls1 = LastStores{};
    var ls2 = LastStores{};

    ls1.stack = Inst.fromU32(10);
    ls2.stack = Inst.fromU32(20);

    const meet_point = Inst.fromU32(100);
    ls1.meet(&ls2, meet_point);

    // Different stores -> use meet point
    try testing.expectEqual(meet_point, ls1.stack.?);
}

test "hasMemoryFenceSemantics" {
    try testing.expectEqual(true, hasMemoryFenceSemantics(.call));
    try testing.expectEqual(true, hasMemoryFenceSemantics(.atomic_load));
    try testing.expectEqual(false, hasMemoryFenceSemantics(.store));
    try testing.expectEqual(false, hasMemoryFenceSemantics(.load));
}
