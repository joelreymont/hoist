//! Register Coalescing for Register Allocation
//!
//! Coalescing merges virtual registers that are connected by moves,
//! reducing the number of move instructions and improving performance.
//!
//! Two types of coalescing:
//! 1. Copy coalescing: merge src and dst of a copy instruction
//! 2. Phi coalescing: merge phi operands with the phi result
//!
//! Coalescing is constrained by:
//! - Interference: can't coalesce if live ranges overlap
//! - Register constraints: fixed registers can't be coalesced
//! - Calling convention: some moves are required by ABI

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir_mod = @import("../ir.zig");
const Inst = ir_mod.Inst;
const Value = ir_mod.Value;
const Block = ir_mod.Block;
const Function = ir_mod.Function;
const Opcode = @import("../ir/opcodes.zig").Opcode;

/// A coalescing candidate.
pub const CoalesceCandidate = struct {
    /// Source virtual register.
    src: Value,
    /// Destination virtual register.
    dst: Value,
    /// Instruction that would be eliminated.
    move_inst: Inst,
    /// Priority (higher = coalesce first).
    priority: i32,
    /// Whether this is a phi coalesce.
    is_phi: bool,
};

/// Result of a coalesce attempt.
pub const CoalesceResult = enum {
    /// Successfully coalesced.
    success,
    /// Cannot coalesce - live ranges interfere.
    interferes,
    /// Cannot coalesce - register constraint.
    constrained,
    /// Cannot coalesce - would create too much pressure.
    pressure,
    /// Already coalesced.
    already_coalesced,
};

/// Union-find structure for tracking coalesced registers.
pub const CoalesceSet = struct {
    allocator: Allocator,
    /// Parent pointers (value -> representative).
    parent: std.AutoHashMap(Value, Value),
    /// Rank for union by rank.
    rank: std.AutoHashMap(Value, u32),

    pub fn init(allocator: Allocator) CoalesceSet {
        return .{
            .allocator = allocator,
            .parent = std.AutoHashMap(Value, Value).init(allocator),
            .rank = std.AutoHashMap(Value, u32).init(allocator),
        };
    }

    pub fn deinit(self: *CoalesceSet) void {
        self.parent.deinit();
        self.rank.deinit();
    }

    /// Find representative for a value.
    pub fn find(self: *CoalesceSet, value: Value) Value {
        const parent = self.parent.get(value) orelse return value;
        if (parent.asU32() == value.asU32()) return value;

        // Path compression
        const root = self.find(parent);
        self.parent.put(value, root) catch {};
        return root;
    }

    /// Union two values into the same set.
    pub fn unite(self: *CoalesceSet, a: Value, b: Value) !void {
        const root_a = self.find(a);
        const root_b = self.find(b);

        if (root_a.asU32() == root_b.asU32()) return;

        const rank_a = self.rank.get(root_a) orelse 0;
        const rank_b = self.rank.get(root_b) orelse 0;

        // Union by rank
        if (rank_a < rank_b) {
            try self.parent.put(root_a, root_b);
        } else if (rank_a > rank_b) {
            try self.parent.put(root_b, root_a);
        } else {
            try self.parent.put(root_b, root_a);
            try self.rank.put(root_a, rank_a + 1);
        }
    }

    /// Check if two values are in the same set.
    pub fn sameSet(self: *CoalesceSet, a: Value, b: Value) bool {
        return self.find(a).asU32() == self.find(b).asU32();
    }
};

/// Register coalescing pass.
pub const Coalescer = struct {
    allocator: Allocator,
    /// Candidates for coalescing.
    candidates: std.ArrayList(CoalesceCandidate),
    /// Coalesced register sets.
    coalesced: CoalesceSet,
    /// Statistics.
    stats: Stats,

    pub fn init(allocator: Allocator) Coalescer {
        return .{
            .allocator = allocator,
            .candidates = std.ArrayList(CoalesceCandidate).init(allocator),
            .coalesced = CoalesceSet.init(allocator),
            .stats = .{},
        };
    }

    pub fn deinit(self: *Coalescer) void {
        self.candidates.deinit();
        self.coalesced.deinit();
    }

    /// Collect coalescing candidates from a function.
    pub fn collectCandidates(self: *Coalescer, func: *const Function) !void {
        self.candidates.clearRetainingCapacity();

        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = func.dfg.insts.get(inst) orelse continue;
                const opcode = inst_data.opcode();

                switch (opcode) {
                    // Copy/move instructions
                    .copy, .bitcast => {
                        const src = switch (inst_data) {
                            .unary => |u| u.arg,
                            else => continue,
                        };
                        const results = func.dfg.instResults(inst);
                        if (results.len == 0) continue;
                        const dst = results[0];

                        try self.candidates.append(.{
                            .src = src,
                            .dst = dst,
                            .move_inst = inst,
                            .priority = computePriority(func, inst, block),
                            .is_phi = false,
                        });
                        self.stats.copies_found += 1;
                    },

                    // Phi instructions
                    .phi => {
                        const results = func.dfg.instResults(inst);
                        if (results.len == 0) continue;
                        const dst = results[0];

                        // Get phi operands
                        const operands = switch (inst_data) {
                            .phi => |p| func.dfg.value_lists.asSlice(p.args),
                            else => continue,
                        };

                        for (operands) |src| {
                            try self.candidates.append(.{
                                .src = src,
                                .dst = dst,
                                .move_inst = inst,
                                .priority = computePriority(func, inst, block) + 10,
                                .is_phi = true,
                            });
                        }
                        self.stats.phis_found += 1;
                    },

                    else => {},
                }
            }
        }

        // Sort by priority (higher first)
        std.mem.sort(CoalesceCandidate, self.candidates.items, {}, struct {
            fn lessThan(_: void, a: CoalesceCandidate, b: CoalesceCandidate) bool {
                return a.priority > b.priority;
            }
        }.lessThan);
    }

    /// Try to coalesce a candidate.
    pub fn tryCoalesce(
        self: *Coalescer,
        candidate: CoalesceCandidate,
        interferes_fn: *const fn (Value, Value) bool,
    ) !CoalesceResult {
        // Check if already coalesced
        if (self.coalesced.sameSet(candidate.src, candidate.dst)) {
            return .already_coalesced;
        }

        // Check for interference
        if (interferes_fn(candidate.src, candidate.dst)) {
            self.stats.interferes += 1;
            return .interferes;
        }

        // Perform coalescing
        try self.coalesced.unite(candidate.src, candidate.dst);
        self.stats.coalesced += 1;

        return .success;
    }

    /// Run coalescing pass.
    pub fn run(
        self: *Coalescer,
        func: *const Function,
        interferes_fn: *const fn (Value, Value) bool,
    ) !u32 {
        try self.collectCandidates(func);

        var coalesced_count: u32 = 0;
        for (self.candidates.items) |candidate| {
            const result = try self.tryCoalesce(candidate, interferes_fn);
            if (result == .success) {
                coalesced_count += 1;
            }
        }

        return coalesced_count;
    }

    /// Get the representative for a value.
    pub fn getRepresentative(self: *Coalescer, value: Value) Value {
        return self.coalesced.find(value);
    }

    /// Get statistics.
    pub fn getStats(self: *const Coalescer) Stats {
        return self.stats;
    }
};

/// Compute priority for a coalescing candidate.
fn computePriority(func: *const Function, inst: Inst, block: Block) i32 {
    _ = func;
    _ = inst;

    // Higher priority for loop headers (estimated by block position)
    // In a real implementation, use loop analysis
    return -@as(i32, @intCast(block.asU32()));
}

/// Coalescing statistics.
pub const Stats = struct {
    copies_found: u32 = 0,
    phis_found: u32 = 0,
    coalesced: u32 = 0,
    interferes: u32 = 0,
    constrained: u32 = 0,
};

// Tests
test "CoalesceSet basic" {
    const testing = std.testing;

    var set = CoalesceSet.init(testing.allocator);
    defer set.deinit();

    const v1 = Value.fromU32(1);
    const v2 = Value.fromU32(2);
    const v3 = Value.fromU32(3);

    // Initially separate
    try testing.expect(!set.sameSet(v1, v2));

    // Unite v1 and v2
    try set.unite(v1, v2);
    try testing.expect(set.sameSet(v1, v2));
    try testing.expect(!set.sameSet(v1, v3));

    // Unite v2 and v3 (transitively unites v1 and v3)
    try set.unite(v2, v3);
    try testing.expect(set.sameSet(v1, v3));
}

test "CoalesceResult enum" {
    const testing = std.testing;

    const r: CoalesceResult = .success;
    try testing.expect(r == .success);
}

test "Coalescer init" {
    const testing = std.testing;

    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    try testing.expectEqual(@as(u32, 0), coalescer.stats.coalesced);
}

test "Coalescer propagates OOM from unite" {
    const testing = std.testing;

    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    var coalescer = Coalescer.init(failing.allocator());
    defer coalescer.deinit();

    const candidate = CoalesceCandidate{
        .src = Value.fromU32(1),
        .dst = Value.fromU32(2),
        .move_inst = Inst.new(0),
        .priority = 0,
        .is_phi = false,
    };

    const no_interfere = struct {
        fn f(_: Value, _: Value) bool {
            return false;
        }
    }.f;

    try testing.expectError(error.OutOfMemory, coalescer.tryCoalesce(candidate, no_interfere));
}
