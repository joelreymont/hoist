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
const Opcode = @import("../../ir/opcodes.zig").Opcode;
const Type = ir.Type;
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

/// A key that uniquely identifies a memory location.
///
/// For a load to be equivalent to another load or store, we need:
/// 1. Same "version" of memory (same last store to the alias region)
/// 2. Same address (same SSA value)
/// 3. Same type being accessed
/// 4. Same extending opcode (for extending loads like uload8, sload16)
pub const MemoryLoc = struct {
    /// Last store that affected this alias region
    last_store: ?Inst,

    /// Address SSA value
    address: Value,

    /// Type being accessed
    ty: Type,

    /// Extending opcode for loads like uload8, sload16, etc.
    /// None for regular loads and stores.
    extending_opcode: ?Opcode,

    /// Create a MemoryLoc for a regular load or store.
    pub fn init(last_store: ?Inst, address: Value, ty: Type) MemoryLoc {
        return .{
            .last_store = last_store,
            .address = address,
            .ty = ty,
            .extending_opcode = null,
        };
    }

    /// Create a MemoryLoc for an extending load (uload8, sload16, etc.).
    pub fn initExtending(last_store: ?Inst, address: Value, ty: Type, opcode: Opcode) MemoryLoc {
        return .{
            .last_store = last_store,
            .address = address,
            .ty = ty,
            .extending_opcode = opcode,
        };
    }

    /// Hash function for use in HashMap.
    pub fn hash(self: MemoryLoc) u64 {
        var hasher = std.hash.Wyhash.init(0);

        // Hash last_store
        if (self.last_store) |ls| {
            hasher.update(std.mem.asBytes(&ls.asU32()));
        } else {
            hasher.update(&[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF });
        }

        // Hash address
        hasher.update(std.mem.asBytes(&self.address.asU32()));

        // Hash type
        hasher.update(std.mem.asBytes(&self.ty.raw));

        // Hash extending opcode
        if (self.extending_opcode) |opcode| {
            hasher.update(std.mem.asBytes(&@intFromEnum(opcode)));
        } else {
            hasher.update(&[_]u8{ 0xFF, 0xFF });
        }

        return hasher.final();
    }

    /// Equality function for use in HashMap.
    pub fn eql(a: MemoryLoc, b: MemoryLoc) bool {
        if (a.last_store != b.last_store) return false;
        if (a.address.asU32() != b.address.asU32()) return false;
        if (a.ty.raw != b.ty.raw) return false;
        if (a.extending_opcode != b.extending_opcode) return false;
        return true;
    }

    /// Context for HashMap.
    pub const HashContext = struct {
        pub fn hash(_: HashContext, key: MemoryLoc) u64 {
            return key.hash();
        }

        pub fn eql(_: HashContext, a: MemoryLoc, b: MemoryLoc) bool {
            return MemoryLoc.eql(a, b);
        }
    };
};

/// Value information stored in the memory-values table.
pub const MemoryValue = struct {
    /// Instruction that defined this value (load or store)
    defining_inst: Inst,
    /// The SSA value (result of load, or data of store)
    value: Value,
};

/// Alias analysis optimization pass.
///
/// Performs forward dataflow analysis to track memory locations and their values,
/// enabling redundant load elimination and store-to-load forwarding.
pub const AliasAnalysis = struct {
    allocator: Allocator,
    /// Dominance tree (borrowed from Function analysis)
    domtree: *const DominatorTree,
    /// Input last-store state for each block
    block_input: std.AutoHashMap(Block, LastStores),
    /// Memory location → value mapping for current program point
    mem_values: std.HashMap(MemoryLoc, MemoryValue, MemoryLoc.HashContext, std.hash_map.default_max_load_percentage),

    /// Initialize the alias analysis pass.
    pub fn init(allocator: Allocator, domtree: *const DominatorTree) AliasAnalysis {
        return .{
            .allocator = allocator,
            .domtree = domtree,
            .block_input = std.AutoHashMap(Block, LastStores).init(allocator),
            .mem_values = std.HashMap(MemoryLoc, MemoryValue, MemoryLoc.HashContext, std.hash_map.default_max_load_percentage).init(allocator),
        };
    }

    /// Deinitialize the alias analysis pass.
    pub fn deinit(self: *AliasAnalysis) void {
        self.block_input.deinit();
        self.mem_values.deinit();
    }

    /// Run the alias analysis pass on a function.
    ///
    /// Returns true if any optimizations were applied.
    pub fn run(self: *AliasAnalysis, func: *Function) !bool {
        var changed = false;

        // Iterate blocks in layout order (approximates RPO)
        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            // Get or initialize last-stores for this block
            var last_stores = LastStores{};

            // Iterate instructions in this block
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = func.dfg.insts.get(inst) orelse continue;

                // Handle loads
                if (isLoadOpcode(inst_data)) {
                    if (try self.handleLoad(func, inst, inst_data, &last_stores)) {
                        changed = true;
                    }
                }
                // Handle stores
                else if (isStoreOpcode(inst_data)) {
                    try self.handleStore(func, inst, inst_data, &last_stores);
                }
                // Handle memory fences
                else if (hasMemoryFenceSemantics(inst_data.*.opcode())) {
                    last_stores.update(inst, inst_data.*.opcode(), null);
                    self.mem_values.clearRetainingCapacity();
                }
            }
        }

        return changed;
    }

    /// Check if an instruction is a load.
    fn isLoadOpcode(inst_data: *const ir.InstructionData) bool {
        return switch (inst_data.*) {
            .load, .stack_load, .uload8, .sload8, .uload16, .sload16, .uload32, .sload32 => true,
            else => false,
        };
    }

    /// Check if an instruction is a store.
    fn isStoreOpcode(inst_data: *const ir.InstructionData) bool {
        return switch (inst_data.*) {
            .store, .stack_store => true,
            else => false,
        };
    }

    /// Handle a load instruction (RLE or store-to-load forwarding).
    fn handleLoad(
        self: *AliasAnalysis,
        func: *Function,
        inst: Inst,
        inst_data: *const ir.InstructionData,
        last_stores: *LastStores,
    ) !bool {
        _ = func;
        _ = inst;
        _ = inst_data;
        _ = last_stores;
        // TODO: Implement load handling
        return false;
    }

    /// Handle a store instruction.
    fn handleStore(
        self: *AliasAnalysis,
        func: *Function,
        inst: Inst,
        inst_data: *const ir.InstructionData,
        last_stores: *LastStores,
    ) !void {
        _ = func;
        _ = inst;
        _ = inst_data;
        _ = last_stores;
        // TODO: Implement store handling
    }
};

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

test "MemoryLoc.init" {
    const last_store = Inst.fromU32(10);
    const address = Value.fromU32(100);
    const ty = Type.I32;

    const loc = MemoryLoc.init(last_store, address, ty);

    try testing.expectEqual(last_store, loc.last_store.?);
    try testing.expectEqual(address.asU32(), loc.address.asU32());
    try testing.expectEqual(ty.raw, loc.ty.raw);
    try testing.expectEqual(@as(?Opcode, null), loc.extending_opcode);
}

test "MemoryLoc.initExtending" {
    const last_store = Inst.fromU32(10);
    const address = Value.fromU32(100);
    const ty = Type.I32;

    const loc = MemoryLoc.initExtending(last_store, address, ty, .uload8);

    try testing.expectEqual(last_store, loc.last_store.?);
    try testing.expectEqual(Opcode.uload8, loc.extending_opcode.?);
}

test "MemoryLoc.eql - same locations" {
    const last_store = Inst.fromU32(10);
    const address = Value.fromU32(100);
    const ty = Type.I32;

    const loc1 = MemoryLoc.init(last_store, address, ty);
    const loc2 = MemoryLoc.init(last_store, address, ty);

    try testing.expectEqual(true, MemoryLoc.eql(loc1, loc2));
}

test "MemoryLoc.eql - different addresses" {
    const last_store = Inst.fromU32(10);
    const ty = Type.I32;

    const loc1 = MemoryLoc.init(last_store, Value.fromU32(100), ty);
    const loc2 = MemoryLoc.init(last_store, Value.fromU32(200), ty);

    try testing.expectEqual(false, MemoryLoc.eql(loc1, loc2));
}

test "MemoryLoc.eql - different types" {
    const last_store = Inst.fromU32(10);
    const address = Value.fromU32(100);

    const loc1 = MemoryLoc.init(last_store, address, Type.I32);
    const loc2 = MemoryLoc.init(last_store, address, Type.I64);

    try testing.expectEqual(false, MemoryLoc.eql(loc1, loc2));
}

test "MemoryLoc.hash - different for different locations" {
    const last_store = Inst.fromU32(10);
    const address = Value.fromU32(100);

    const loc1 = MemoryLoc.init(last_store, address, Type.I32);
    const loc2 = MemoryLoc.init(last_store, address, Type.I64);

    // Different types should have different hashes (not guaranteed but very likely)
    try testing.expect(loc1.hash() != loc2.hash());
}

test "MemoryLoc.HashContext - can be used in HashMap" {
    const last_store = Inst.fromU32(10);
    const address = Value.fromU32(100);
    const ty = Type.I32;

    const loc = MemoryLoc.init(last_store, address, ty);

    const ctx = MemoryLoc.HashContext{};
    const hash1 = ctx.hash(loc);
    const hash2 = ctx.hash(loc);

    // Same location should hash to same value
    try testing.expectEqual(hash1, hash2);

    // Should be equal to itself
    try testing.expectEqual(true, ctx.eql(loc, loc));
}
