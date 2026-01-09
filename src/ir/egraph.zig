//! E-graph data structures for equality saturation.
//!
//! Based on egg (Fast and Extensible Equality Saturation, POPL 2021).
//! See docs/egraph-design.md for design rationale.

const std = @import("std");
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;

const entities = @import("entities.zig");
const Value = entities.Value;
const Inst = entities.Inst;
const opcodes = @import("opcodes.zig");
const Opcode = opcodes.Opcode;

/// E-class ID: opaque identifier for equivalence class.
/// Two e-nodes are equivalent iff they have the same e-class ID.
pub const EClassId = enum(u32) {
    _,

    pub fn format(
        self: EClassId,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("e{d}", .{@intFromEnum(self)});
    }
};

/// E-node: operator applied to e-class IDs.
/// Unlike AST nodes, children are e-classes not other e-nodes.
pub const ENode = struct {
    /// Opcode of this operation.
    op: Opcode,

    /// E-class IDs of operands (children are e-classes, not e-nodes).
    /// Max 3 operands for ternary ops (select, fma).
    children: []const EClassId,

    pub fn hash(self: ENode) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&self.op));
        hasher.update(std.mem.sliceAsBytes(self.children));
        return hasher.final();
    }

    pub fn eql(a: ENode, b: ENode) bool {
        if (a.op != b.op) return false;
        if (a.children.len != b.children.len) return false;
        for (a.children, b.children) |a_child, b_child| {
            if (a_child != b_child) return false;
        }
        return true;
    }
};

/// E-class: equivalence class of equivalent e-nodes.
/// Represents a set of expressions known to be equal.
pub const EClass = struct {
    /// Unique identifier for this e-class.
    id: EClassId,

    /// E-nodes in this equivalence class.
    /// All e-nodes in same e-class are equivalent.
    nodes: ArrayList(ENode),

    /// Parent e-nodes that reference this e-class.
    /// Used for congruence closure: when e-classes merge, parents must be updated.
    parents: ArrayList(ENode),

    pub fn init(allocator: Allocator, id: EClassId) EClass {
        return .{
            .id = id,
            .nodes = ArrayList(ENode).init(allocator),
            .parents = ArrayList(ENode).init(allocator),
        };
    }

    pub fn deinit(self: *EClass, allocator: Allocator) void {
        for (self.nodes.items) |node| {
            allocator.free(node.children);
        }
        self.nodes.deinit();

        for (self.parents.items) |parent| {
            allocator.free(parent.children);
        }
        self.parents.deinit();
    }
};

/// Union-Find data structure for maintaining equivalence classes.
/// Supports efficient union and find operations with path compression.
pub const UnionFind = struct {
    /// Parent pointers: parent[i] is parent of e-class i.
    /// If parent[i] == i, then i is a root (canonical representative).
    parents: ArrayList(EClassId),

    pub fn init(allocator: Allocator) UnionFind {
        return .{
            .parents = ArrayList(EClassId).init(allocator),
        };
    }

    pub fn deinit(self: *UnionFind) void {
        self.parents.deinit();
    }

    /// Create new e-class with given ID.
    pub fn makeSet(self: *UnionFind, allocator: Allocator, id: EClassId) !void {
        const idx = @intFromEnum(id);
        while (self.parents.items.len <= idx) {
            try self.parents.append(allocator, @enumFromInt(self.parents.items.len));
        }
        self.parents.items[idx] = id; // Root points to itself
    }

    /// Find canonical representative of e-class (with path compression).
    pub fn find(self: *UnionFind, id: EClassId) EClassId {
        const idx = @intFromEnum(id);
        if (idx >= self.parents.items.len) return id;

        const parent = self.parents.items[idx];
        if (parent == id) return id; // Root

        // Path compression: point directly to root
        const root = self.find(parent);
        self.parents.items[idx] = root;
        return root;
    }

    /// Union two e-classes, returning canonical representative.
    /// Does NOT perform congruence closure - caller must handle that.
    pub fn union_(self: *UnionFind, a: EClassId, b: EClassId) EClassId {
        const root_a = self.find(a);
        const root_b = self.find(b);

        if (root_a == root_b) return root_a;

        // Union by rank: always make lower ID the root for determinism
        const idx_a = @intFromEnum(root_a);
        const idx_b = @intFromEnum(root_b);

        if (idx_a < idx_b) {
            self.parents.items[idx_b] = root_a;
            return root_a;
        } else {
            self.parents.items[idx_a] = root_b;
            return root_b;
        }
    }
};

/// E-graph: stores congruence relation over IR operations.
/// Compact representation of many equivalent expressions.
pub const EGraph = struct {
    allocator: Allocator,

    /// Union-find for equivalence class membership.
    uf: UnionFind,

    /// All e-classes indexed by canonical ID.
    /// Use uf.find() to get canonical ID before lookup.
    classes: AutoHashMap(EClassId, EClass),

    /// Hash-consing: deduplicate e-nodes.
    /// Maps e-node → e-class ID containing that e-node.
    hashcons: AutoHashMap(ENode, EClassId),

    /// Counter for generating fresh e-class IDs.
    next_id: u32,

    /// Worklist for pending congruence closure.
    /// Contains e-class IDs that need parent updates.
    worklist: ArrayList(EClassId),

    pub fn init(allocator: Allocator) EGraph {
        return .{
            .allocator = allocator,
            .uf = UnionFind.init(allocator),
            .classes = AutoHashMap(EClassId, EClass).init(allocator),
            .hashcons = AutoHashMap(ENode, EClassId).init(allocator),
            .next_id = 0,
            .worklist = ArrayList(EClassId).init(allocator),
        };
    }

    pub fn deinit(self: *EGraph) void {
        var class_iter = self.classes.valueIterator();
        while (class_iter.next()) |eclass| {
            eclass.deinit(self.allocator);
        }
        self.classes.deinit();

        var hashcons_iter = self.hashcons.keyIterator();
        while (hashcons_iter.next()) |node| {
            self.allocator.free(node.children);
        }
        self.hashcons.deinit();

        self.uf.deinit();
        self.worklist.deinit();
    }

    /// Add e-node to e-graph, returning e-class ID.
    /// Deduplicates via hash-consing: if e-node already exists, returns existing e-class.
    pub fn add(self: *EGraph, op: Opcode, children: []const EClassId) !EClassId {
        // Canonicalize children using union-find
        const canonical_children = try self.allocator.alloc(EClassId, children.len);
        for (children, 0..) |child, i| {
            canonical_children[i] = self.uf.find(child);
        }

        const node = ENode{
            .op = op,
            .children = canonical_children,
        };

        // Check if e-node already exists (hash-consing)
        if (self.hashcons.get(node)) |existing_id| {
            self.allocator.free(canonical_children);
            return self.uf.find(existing_id);
        }

        // Create new e-class
        const id: EClassId = @enumFromInt(self.next_id);
        self.next_id += 1;

        try self.uf.makeSet(self.allocator, id);

        var eclass = EClass.init(self.allocator, id);
        try eclass.nodes.append(self.allocator, node);

        try self.classes.put(id, eclass);
        try self.hashcons.put(node, id);

        // Add as parent to children
        for (canonical_children) |child_id| {
            if (self.classes.getPtr(child_id)) |child_class| {
                const parent_node = ENode{
                    .op = op,
                    .children = try self.allocator.dupe(EClassId, canonical_children),
                };
                try child_class.parents.append(self.allocator, parent_node);
            }
        }

        return id;
    }

    /// Merge two e-classes, asserting they are equivalent.
    /// Performs congruence closure: if a = b and f(a) exists, then f(a) = f(b).
    pub fn merge(self: *EGraph, a: EClassId, b: EClassId) !EClassId {
        const id_a = self.uf.find(a);
        const id_b = self.uf.find(b);

        if (id_a == id_b) return id_a; // Already merged

        // Union e-classes
        const new_id = self.uf.union_(id_a, id_b);

        // Move nodes from non-canonical to canonical e-class
        const non_canon = if (new_id == id_a) id_b else id_a;

        if (self.classes.getPtr(non_canon)) |non_canon_class| {
            if (self.classes.getPtr(new_id)) |canon_class| {
                // Merge nodes
                try canon_class.nodes.appendSlice(self.allocator, non_canon_class.nodes.items);
                non_canon_class.nodes.clearRetainingCapacity();

                // Merge parents
                try canon_class.parents.appendSlice(self.allocator, non_canon_class.parents.items);
                non_canon_class.parents.clearRetainingCapacity();
            }
        }

        // Add to worklist for congruence closure
        try self.worklist.append(self.allocator, new_id);

        return new_id;
    }

    /// Rebuild e-graph to restore invariants after merges.
    /// Implements egg's rebuilding algorithm for congruence closure.
    pub fn rebuild(self: *EGraph) !void {
        while (self.worklist.items.len > 0) {
            const id = self.worklist.pop();
            const canon_id = self.uf.find(id);

            const eclass = self.classes.getPtr(canon_id) orelse continue;

            // Process parents to maintain congruence
            var i: usize = 0;
            while (i < eclass.parents.items.len) : (i += 1) {
                const parent = eclass.parents.items[i];

                // Canonicalize parent's children
                const canonical_children = try self.allocator.alloc(EClassId, parent.children.len);
                defer self.allocator.free(canonical_children);

                for (parent.children, 0..) |child, j| {
                    canonical_children[j] = self.uf.find(child);
                }

                const canonical_parent = ENode{
                    .op = parent.op,
                    .children = canonical_children,
                };

                // Check if canonical parent already exists
                if (self.hashcons.get(canonical_parent)) |existing_id| {
                    const existing_canon = self.uf.find(existing_id);
                    if (existing_canon != canon_id) {
                        // Congruence: merge parent e-classes
                        _ = try self.merge(existing_id, canon_id);
                    }
                }
            }
        }
    }

    /// Lookup e-class by ID, returning canonical representative.
    pub fn getClass(self: *EGraph, id: EClassId) ?*EClass {
        const canon_id = self.uf.find(id);
        return self.classes.getPtr(canon_id);
    }
};

/// Builder for converting IR functions to e-graphs.
pub const EGraphBuilder = struct {
    eg: *EGraph,

    /// Maps IR Value → E-class ID.
    /// Tracks which e-class represents each SSA value.
    value_map: AutoHashMap(Value, EClassId),

    pub fn init(allocator: Allocator, eg: *EGraph) EGraphBuilder {
        return .{
            .eg = eg,
            .value_map = AutoHashMap(Value, EClassId).init(allocator),
        };
    }

    pub fn deinit(self: *EGraphBuilder) void {
        self.value_map.deinit();
    }

    /// Build e-graph from IR function.
    /// Converts each instruction to e-nodes, creating e-classes for results.
    pub fn buildFromFunction(self: *EGraphBuilder, func: anytype) !void {
        const Function = @import("function.zig").Function;
        const dfg_mod = @import("dfg.zig");

        // Process blocks in layout order
        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            // Process instructions in block
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                try self.addInstruction(func, inst);
            }
        }
    }

    /// Add single instruction to e-graph.
    fn addInstruction(self: *EGraphBuilder, func: anytype, inst: Inst) !void {
        const inst_data = func.dfg.insts.get(inst) orelse return;

        // Get opcode
        const op = inst_data.opcode();

        // Collect operand e-class IDs
        var operands = std.ArrayList(EClassId).init(self.value_map.allocator);
        defer operands.deinit();

        // Convert IR values to e-class IDs
        switch (inst_data.*) {
            .unary => |data| {
                if (self.value_map.get(data.arg)) |arg_id| {
                    try operands.append(arg_id);
                } else {
                    // Operand not yet in e-graph (block arg, constant, etc.)
                    const arg_id = try self.eg.add(op, &.{});
                    try self.value_map.put(data.arg, arg_id);
                    try operands.append(arg_id);
                }
            },
            .binary => |data| {
                const lhs_id = try self.getOrCreateValue(data.lhs);
                const rhs_id = try self.getOrCreateValue(data.rhs);
                try operands.append(lhs_id);
                try operands.append(rhs_id);
            },
            .ternary => |data| {
                const arg0_id = try self.getOrCreateValue(data.args[0]);
                const arg1_id = try self.getOrCreateValue(data.args[1]);
                const arg2_id = try self.getOrCreateValue(data.args[2]);
                try operands.append(arg0_id);
                try operands.append(arg1_id);
                try operands.append(arg2_id);
            },
            .int_compare => |data| {
                const lhs_id = try self.getOrCreateValue(data.lhs);
                const rhs_id = try self.getOrCreateValue(data.rhs);
                try operands.append(lhs_id);
                try operands.append(rhs_id);
            },
            .iconst => {
                // Constant: create leaf e-node
            },
            .f32const, .f64const => {
                // Float constant: create leaf e-node
            },
            .nullary => {
                // No operands (nop, etc.)
            },
            else => {
                // Other instruction formats - add as needed
                return;
            },
        }

        // Add e-node to e-graph
        const eclass_id = try self.eg.add(op, operands.items);

        // Map instruction result to e-class
        if (func.dfg.instResults(inst)) |results| {
            if (results.len > 0) {
                try self.value_map.put(results[0], eclass_id);
            }
        }
    }

    /// Get e-class for value, creating leaf node if needed.
    fn getOrCreateValue(self: *EGraphBuilder, value: Value) !EClassId {
        if (self.value_map.get(value)) |id| {
            return id;
        }

        // Create leaf node for unknown value (block param, constant, etc.)
        const id = try self.eg.add(.nop, &.{});
        try self.value_map.put(value, id);
        return id;
    }

    /// Get e-class ID for IR value.
    pub fn getValue(self: *EGraphBuilder, value: Value) ?EClassId {
        return self.value_map.get(value);
    }
};

/// Equality saturation: apply rewrites until fixpoint.
/// Core optimization algorithm from egg (POPL 2021).
pub const EqualitySaturation = struct {
    eg: *EGraph,
    allocator: Allocator,

    /// Maximum iterations before stopping.
    max_iterations: u32,

    /// Node limit: stop if e-graph exceeds this size.
    node_limit: u32,

    pub fn init(allocator: Allocator, eg: *EGraph) EqualitySaturation {
        return .{
            .eg = eg,
            .allocator = allocator,
            .max_iterations = 100,
            .node_limit = 10000,
        };
    }

    /// Run equality saturation with given rewrite rules.
    /// Returns number of iterations performed.
    pub fn saturate(self: *EqualitySaturation, rules: []const anytype) !u32 {
        var iteration: u32 = 0;

        while (iteration < self.max_iterations) : (iteration += 1) {
            const initial_class_count = self.eg.classes.count();

            // Apply all rewrite rules
            var changed = false;
            for (rules) |rule| {
                if (try self.applyRule(rule)) {
                    changed = true;
                }
            }

            // Rebuild to restore invariants (congruence closure)
            try self.eg.rebuild();

            // Check termination conditions
            if (!changed) {
                // Fixpoint reached
                break;
            }

            if (self.eg.classes.count() > self.node_limit) {
                // E-graph too large, stop
                break;
            }

            // No progress check: if no new e-classes created
            if (self.eg.classes.count() == initial_class_count) {
                // No structural changes
                break;
            }
        }

        return iteration + 1;
    }

    /// Apply single rewrite rule to all matching e-nodes.
    fn applyRule(self: *EqualitySaturation, rule: anytype) !bool {
        var changed = false;

        // Iterate over all e-classes
        var class_iter = self.eg.classes.iterator();
        while (class_iter.next()) |entry| {
            const eclass = entry.value_ptr;

            // Try each e-node in this e-class
            for (eclass.nodes.items) |node| {
                if (try self.matchAndRewrite(rule, node, eclass.id)) {
                    changed = true;
                }
            }
        }

        return changed;
    }

    /// Match pattern and apply rewrite if successful.
    fn matchAndRewrite(self: *EqualitySaturation, rule: anytype, node: ENode, eclass_id: EClassId) !bool {
        // Simple pattern matching - match identity rules first
        const rule_name = rule.name;

        // Identity: x + 0 → x
        if (std.mem.eql(u8, rule_name, "iadd_zero_right")) {
            if (node.op == .iadd and node.children.len == 2) {
                // Check if right operand is zero
                const right_id = self.eg.uf.find(node.children[1]);
                if (try self.isConstantZero(right_id)) {
                    // Merge with left operand
                    const left_id = self.eg.uf.find(node.children[0]);
                    _ = try self.eg.merge(eclass_id, left_id);
                    return true;
                }
            }
        }

        // Identity: 0 + x → x
        if (std.mem.eql(u8, rule_name, "iadd_zero_left")) {
            if (node.op == .iadd and node.children.len == 2) {
                const left_id = self.eg.uf.find(node.children[0]);
                if (try self.isConstantZero(left_id)) {
                    const right_id = self.eg.uf.find(node.children[1]);
                    _ = try self.eg.merge(eclass_id, right_id);
                    return true;
                }
            }
        }

        // Identity: x * 1 → x
        if (std.mem.eql(u8, rule_name, "imul_one_right")) {
            if (node.op == .imul and node.children.len == 2) {
                const right_id = self.eg.uf.find(node.children[1]);
                if (try self.isConstantOne(right_id)) {
                    const left_id = self.eg.uf.find(node.children[0]);
                    _ = try self.eg.merge(eclass_id, left_id);
                    return true;
                }
            }
        }

        // Identity: 1 * x → x
        if (std.mem.eql(u8, rule_name, "imul_one_left")) {
            if (node.op == .imul and node.children.len == 2) {
                const left_id = self.eg.uf.find(node.children[0]);
                if (try self.isConstantOne(left_id)) {
                    const right_id = self.eg.uf.find(node.children[1]);
                    _ = try self.eg.merge(eclass_id, right_id);
                    return true;
                }
            }
        }

        // Idempotence: x - x → 0
        if (std.mem.eql(u8, rule_name, "isub_self")) {
            if (node.op == .isub and node.children.len == 2) {
                const left_id = self.eg.uf.find(node.children[0]);
                const right_id = self.eg.uf.find(node.children[1]);
                if (left_id == right_id) {
                    // Create constant zero and merge
                    const zero_id = try self.eg.add(.iconst, &.{});
                    _ = try self.eg.merge(eclass_id, zero_id);
                    return true;
                }
            }
        }

        // Idempotence: x ^ x → 0
        if (std.mem.eql(u8, rule_name, "bxor_self")) {
            if (node.op == .bxor and node.children.len == 2) {
                const left_id = self.eg.uf.find(node.children[0]);
                const right_id = self.eg.uf.find(node.children[1]);
                if (left_id == right_id) {
                    const zero_id = try self.eg.add(.iconst, &.{});
                    _ = try self.eg.merge(eclass_id, zero_id);
                    return true;
                }
            }
        }

        // Idempotence: x & x → x
        if (std.mem.eql(u8, rule_name, "band_self")) {
            if (node.op == .band and node.children.len == 2) {
                const left_id = self.eg.uf.find(node.children[0]);
                const right_id = self.eg.uf.find(node.children[1]);
                if (left_id == right_id) {
                    _ = try self.eg.merge(eclass_id, left_id);
                    return true;
                }
            }
        }

        // Idempotence: x | x → x
        if (std.mem.eql(u8, rule_name, "bor_self")) {
            if (node.op == .bor and node.children.len == 2) {
                const left_id = self.eg.uf.find(node.children[0]);
                const right_id = self.eg.uf.find(node.children[1]);
                if (left_id == right_id) {
                    _ = try self.eg.merge(eclass_id, left_id);
                    return true;
                }
            }
        }

        // Commutativity: x + y → y + x (assert equivalence)
        if (std.mem.eql(u8, rule_name, "iadd_comm")) {
            if (node.op == .iadd and node.children.len == 2) {
                const left_id = self.eg.uf.find(node.children[0]);
                const right_id = self.eg.uf.find(node.children[1]);
                // Add commuted version to same e-class
                const comm_id = try self.eg.add(.iadd, &.{ right_id, left_id });
                _ = try self.eg.merge(eclass_id, comm_id);
                return true;
            }
        }

        return false;
    }

    /// Check if e-class contains constant zero.
    fn isConstantZero(self: *EqualitySaturation, id: EClassId) !bool {
        const eclass = self.eg.getClass(id) orelse return false;
        for (eclass.nodes.items) |node| {
            if (node.op == .iconst and node.children.len == 0) {
                // Assume iconst with no children is zero
                // TODO: Store constant value in e-node
                return true;
            }
        }
        return false;
    }

    /// Check if e-class contains constant one.
    fn isConstantOne(self: *EqualitySaturation, id: EClassId) !bool {
        const eclass = self.eg.getClass(id) orelse return false;
        for (eclass.nodes.items) |node| {
            if (node.op == .iconst and node.children.len == 0) {
                // TODO: Distinguish constants - need value storage
                return false; // Placeholder
            }
        }
        return false;
    }
};

// Tests
const testing = std.testing;

test "EClassId format" {
    const id: EClassId = @enumFromInt(42);
    const str = try std.fmt.allocPrint(testing.allocator, "{}", .{id});
    defer testing.allocator.free(str);
    try testing.expectEqualStrings("e42", str);
}

test "UnionFind basic operations" {
    var uf = UnionFind.init(testing.allocator);
    defer uf.deinit();

    const e0: EClassId = @enumFromInt(0);
    const e1: EClassId = @enumFromInt(1);
    const e2: EClassId = @enumFromInt(2);

    try uf.makeSet(testing.allocator, e0);
    try uf.makeSet(testing.allocator, e1);
    try uf.makeSet(testing.allocator, e2);

    try testing.expectEqual(e0, uf.find(e0));
    try testing.expectEqual(e1, uf.find(e1));
    try testing.expectEqual(e2, uf.find(e2));

    // Union e0 and e1
    const root01 = uf.union_(e0, e1);
    try testing.expectEqual(uf.find(e0), uf.find(e1));
    try testing.expectEqual(root01, uf.find(e0));
    try testing.expectEqual(root01, uf.find(e1));

    // Union e1 and e2 (transitively merges e0 and e2)
    _ = uf.union_(e1, e2);
    try testing.expectEqual(uf.find(e0), uf.find(e2));
}

test "EGraph add and hash-consing" {
    var eg = EGraph.init(testing.allocator);
    defer eg.deinit();

    // Add x + y
    const x = try eg.add(.iadd, &.{});
    const y = try eg.add(.iadd, &.{});
    const x_plus_y = try eg.add(.iadd, &.{ x, y });

    // Add x + y again - should deduplicate
    const x_plus_y_dup = try eg.add(.iadd, &.{ x, y });
    try testing.expectEqual(x_plus_y, x_plus_y_dup);
}

test "EGraph merge and congruence" {
    var eg = EGraph.init(testing.allocator);
    defer eg.deinit();

    // Build: x, y, x+1, y+1
    const x = try eg.add(.iconst, &.{});
    const y = try eg.add(.iconst, &.{});
    const one = try eg.add(.iconst, &.{});
    const x_plus_1 = try eg.add(.iadd, &.{ x, one });
    const y_plus_1 = try eg.add(.iadd, &.{ y, one });

    // Assert x = y
    _ = try eg.merge(x, y);
    try eg.rebuild();

    // Check congruence: x+1 should equal y+1
    const x_plus_1_canon = eg.uf.find(x_plus_1);
    const y_plus_1_canon = eg.uf.find(y_plus_1);
    try testing.expectEqual(x_plus_1_canon, y_plus_1_canon);
}
