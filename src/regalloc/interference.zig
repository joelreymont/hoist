//! Interference graph for register allocation.
//!
//! Tracks which virtual registers have overlapping live ranges and therefore
//! cannot be assigned to the same physical register.

const std = @import("std");
const machinst = @import("../machinst/machinst.zig");

/// Interference graph using an adjacency matrix representation.
///
/// The graph stores interference relationships between virtual registers.
/// Two vregs interfere if their live ranges overlap - they must be assigned
/// to different physical registers.
///
/// Uses a dense bit matrix representation (NxN bits) which is efficient for
/// graphs with many edges. For sparse graphs, a HashMap-based representation
/// would be more space-efficient.
pub const InterferenceGraph = struct {
    /// Number of virtual registers
    num_vregs: u32,

    /// Adjacency matrix stored as a flat bit array
    /// edges[i * num_vregs + j] indicates interference between vreg i and vreg j
    /// Symmetric: edges[i,j] == edges[j,i]
    edges: std.DynamicBitSet,

    allocator: std.mem.Allocator,

    /// Initialize an interference graph for the given number of virtual registers.
    pub fn init(allocator: std.mem.Allocator, num_vregs: u32) !InterferenceGraph {
        const num_bits = num_vregs * num_vregs;
        const edges = try std.DynamicBitSet.initEmpty(allocator, num_bits);

        return .{
            .num_vregs = num_vregs,
            .edges = edges,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InterferenceGraph) void {
        self.edges.deinit();
    }

    /// Add an interference edge between two virtual registers.
    /// The edge is bidirectional (symmetric).
    pub fn addEdge(self: *InterferenceGraph, v1: machinst.VReg, v2: machinst.VReg) void {
        if (v1.index >= self.num_vregs or v2.index >= self.num_vregs) return;
        if (v1.index == v2.index) return; // No self-edges

        // Set both directions (symmetric matrix)
        const idx1 = v1.index * self.num_vregs + v2.index;
        const idx2 = v2.index * self.num_vregs + v1.index;

        self.edges.set(idx1);
        self.edges.set(idx2);
    }

    /// Check if two virtual registers interfere.
    pub fn interferes(self: *const InterferenceGraph, v1: machinst.VReg, v2: machinst.VReg) bool {
        if (v1.index >= self.num_vregs or v2.index >= self.num_vregs) return false;
        if (v1.index == v2.index) return false;

        const idx = v1.index * self.num_vregs + v2.index;
        return self.edges.isSet(idx);
    }

    /// Get the degree (number of neighbors) of a virtual register.
    /// This is the count of vregs that interfere with the given vreg.
    pub fn degree(self: *const InterferenceGraph, v: machinst.VReg) u32 {
        if (v.index >= self.num_vregs) return 0;

        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.num_vregs) : (i += 1) {
            if (i == v.index) continue;
            const idx = v.index * self.num_vregs + i;
            if (self.edges.isSet(idx)) {
                count += 1;
            }
        }
        return count;
    }

    /// Get all neighbors (interfering vregs) of a virtual register.
    /// Returns an ArrayList of VReg indices that must be freed by caller.
    pub fn neighbors(self: *const InterferenceGraph, v: machinst.VReg) !std.ArrayList(u32) {
        var result = std.ArrayList(u32).init(self.allocator);
        errdefer result.deinit();

        if (v.index >= self.num_vregs) return result;

        var i: u32 = 0;
        while (i < self.num_vregs) : (i += 1) {
            if (i == v.index) continue;
            const idx = v.index * self.num_vregs + i;
            if (self.edges.isSet(idx)) {
                try result.append(self.allocator, i);
            }
        }

        return result;
    }
};

// Tests
const testing = std.testing;

test "InterferenceGraph init and deinit" {
    const allocator = testing.allocator;

    var graph = try InterferenceGraph.init(allocator, 10);
    defer graph.deinit();

    try testing.expectEqual(@as(u32, 10), graph.num_vregs);
}

test "InterferenceGraph add edge and interferes check" {
    const allocator = testing.allocator;

    var graph = try InterferenceGraph.init(allocator, 5);
    defer graph.deinit();

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);
    const v2 = machinst.VReg.new(2, .int);

    // Initially no interference
    try testing.expect(!graph.interferes(v0, v1));
    try testing.expect(!graph.interferes(v1, v0)); // Symmetric

    // Add edge v0 <-> v1
    graph.addEdge(v0, v1);

    // Now they interfere
    try testing.expect(graph.interferes(v0, v1));
    try testing.expect(graph.interferes(v1, v0)); // Symmetric

    // v0 and v2 still don't interfere
    try testing.expect(!graph.interferes(v0, v2));
    try testing.expect(!graph.interferes(v2, v0));
}

test "InterferenceGraph self-loops ignored" {
    const allocator = testing.allocator;

    var graph = try InterferenceGraph.init(allocator, 5);
    defer graph.deinit();

    const v0 = machinst.VReg.new(0, .int);

    // Try to add self-edge (should be ignored)
    graph.addEdge(v0, v0);

    // Should not interfere with itself
    try testing.expect(!graph.interferes(v0, v0));
}

test "InterferenceGraph degree calculation" {
    const allocator = testing.allocator;

    var graph = try InterferenceGraph.init(allocator, 5);
    defer graph.deinit();

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);
    const v2 = machinst.VReg.new(2, .int);
    const v3 = machinst.VReg.new(3, .int);

    // v0 interferes with v1, v2, v3
    graph.addEdge(v0, v1);
    graph.addEdge(v0, v2);
    graph.addEdge(v0, v3);

    // v0 should have degree 3
    try testing.expectEqual(@as(u32, 3), graph.degree(v0));

    // v1, v2, v3 should each have degree 1 (only v0)
    try testing.expectEqual(@as(u32, 1), graph.degree(v1));
    try testing.expectEqual(@as(u32, 1), graph.degree(v2));
    try testing.expectEqual(@as(u32, 1), graph.degree(v3));

    // v4 has no edges
    const v4 = machinst.VReg.new(4, .int);
    try testing.expectEqual(@as(u32, 0), graph.degree(v4));
}

test "InterferenceGraph neighbors list" {
    const allocator = testing.allocator;

    var graph = try InterferenceGraph.init(allocator, 5);
    defer graph.deinit();

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);
    const v2 = machinst.VReg.new(2, .int);
    const v3 = machinst.VReg.new(3, .int);

    // v0 interferes with v1, v2, v3
    graph.addEdge(v0, v1);
    graph.addEdge(v0, v2);
    graph.addEdge(v0, v3);

    var neighbors_v0 = try graph.neighbors(v0);
    defer neighbors_v0.deinit();

    // Should have 3 neighbors
    try testing.expectEqual(@as(usize, 3), neighbors_v0.items.len);

    // Should contain indices 1, 2, 3 (in any order)
    var has_1 = false;
    var has_2 = false;
    var has_3 = false;
    for (neighbors_v0.items) |idx| {
        if (idx == 1) has_1 = true;
        if (idx == 2) has_2 = true;
        if (idx == 3) has_3 = true;
    }
    try testing.expect(has_1 and has_2 and has_3);
}

test "InterferenceGraph out of bounds handling" {
    const allocator = testing.allocator;

    var graph = try InterferenceGraph.init(allocator, 3);
    defer graph.deinit();

    const v0 = machinst.VReg.new(0, .int);
    const v_invalid = machinst.VReg.new(10, .int); // Out of bounds

    // Operations with out-of-bounds vregs should be safe (no-op or false)
    graph.addEdge(v0, v_invalid); // Should be ignored
    try testing.expect(!graph.interferes(v0, v_invalid));
    try testing.expectEqual(@as(u32, 0), graph.degree(v_invalid));
}
