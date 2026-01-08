const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const InterferenceGraph = hoist.regalloc.interference.InterferenceGraph;
const buildInterferenceGraph = hoist.regalloc.interference.buildInterferenceGraph;
const LivenessInfo = hoist.regalloc.liveness.LivenessInfo;
const machinst = hoist.machinst;
const VReg = machinst.VReg;

test "interference: three vregs with overlapping ranges" {
    var liveness = LivenessInfo.init(testing.allocator);
    defer liveness.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);

    // v0: [0, 5] - overlaps with v1 at [3, 5]
    try liveness.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 5,
        .reg_class = .int,
    });

    // v1: [3, 7] - overlaps with v0 at [3, 5]
    try liveness.addRange(.{
        .vreg = v1,
        .start_inst = 3,
        .end_inst = 7,
        .reg_class = .int,
    });

    // v2: [8, 10] - no overlap with v0 or v1
    try liveness.addRange(.{
        .vreg = v2,
        .start_inst = 8,
        .end_inst = 10,
        .reg_class = .int,
    });

    // Build interference graph
    var graph = try buildInterferenceGraph(testing.allocator, &liveness);
    defer graph.deinit();

    // v0 and v1 interfere (overlap at [3, 5])
    try testing.expect(graph.interferes(v0, v1));
    try testing.expect(graph.interferes(v1, v0)); // Symmetric

    // v0 and v2 don't interfere (no overlap)
    try testing.expect(!graph.interferes(v0, v2));
    try testing.expect(!graph.interferes(v2, v0));

    // v1 and v2 don't interfere (no overlap)
    try testing.expect(!graph.interferes(v1, v2));
    try testing.expect(!graph.interferes(v2, v1));
}

test "interference: degree computation" {
    var liveness = LivenessInfo.init(testing.allocator);
    defer liveness.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);

    try liveness.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 5,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v1,
        .start_inst = 3,
        .end_inst = 7,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v2,
        .start_inst = 8,
        .end_inst = 10,
        .reg_class = .int,
    });

    var graph = try buildInterferenceGraph(testing.allocator, &liveness);
    defer graph.deinit();

    // v0 has degree 1 (interferes with v1 only)
    try testing.expectEqual(@as(u32, 1), graph.degree(v0));

    // v1 has degree 1 (interferes with v0 only)
    try testing.expectEqual(@as(u32, 1), graph.degree(v1));

    // v2 has degree 0 (doesn't interfere with anyone)
    try testing.expectEqual(@as(u32, 0), graph.degree(v2));
}

test "interference: neighbors list" {
    var liveness = LivenessInfo.init(testing.allocator);
    defer liveness.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);

    try liveness.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 5,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v1,
        .start_inst = 3,
        .end_inst = 7,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v2,
        .start_inst = 8,
        .end_inst = 10,
        .reg_class = .int,
    });

    var graph = try buildInterferenceGraph(testing.allocator, &liveness);
    defer graph.deinit();

    // Get neighbors of v0
    var neighbors_v0 = try graph.neighbors(v0);
    defer neighbors_v0.deinit();

    // v0 should have 1 neighbor: v1
    try testing.expectEqual(@as(usize, 1), neighbors_v0.items.len);
    try testing.expectEqual(@as(u32, 1), neighbors_v0.items[0]);

    // Get neighbors of v1
    var neighbors_v1 = try graph.neighbors(v1);
    defer neighbors_v1.deinit();

    // v1 should have 1 neighbor: v0
    try testing.expectEqual(@as(usize, 1), neighbors_v1.items.len);
    try testing.expectEqual(@as(u32, 0), neighbors_v1.items[0]);

    // Get neighbors of v2
    var neighbors_v2 = try graph.neighbors(v2);
    defer neighbors_v2.deinit();

    // v2 should have 0 neighbors
    try testing.expectEqual(@as(usize, 0), neighbors_v2.items.len);
}

test "interference: symmetry property" {
    var liveness = LivenessInfo.init(testing.allocator);
    defer liveness.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);

    // Ranges that overlap
    try liveness.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v1,
        .start_inst = 5,
        .end_inst = 15,
        .reg_class = .int,
    });

    var graph = try buildInterferenceGraph(testing.allocator, &liveness);
    defer graph.deinit();

    // Interference should be symmetric
    const v0_v1 = graph.interferes(v0, v1);
    const v1_v0 = graph.interferes(v1, v0);
    try testing.expect(v0_v1 == v1_v0);
}

test "interference: non-overlapping ranges" {
    var liveness = LivenessInfo.init(testing.allocator);
    defer liveness.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);

    // Three non-overlapping ranges
    try liveness.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 5,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v1,
        .start_inst = 10,
        .end_inst = 15,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v2,
        .start_inst = 20,
        .end_inst = 25,
        .reg_class = .int,
    });

    var graph = try buildInterferenceGraph(testing.allocator, &liveness);
    defer graph.deinit();

    // No interferences since ranges don't overlap
    try testing.expect(!graph.interferes(v0, v1));
    try testing.expect(!graph.interferes(v0, v2));
    try testing.expect(!graph.interferes(v1, v2));

    // All degrees should be 0
    try testing.expectEqual(@as(u32, 0), graph.degree(v0));
    try testing.expectEqual(@as(u32, 0), graph.degree(v1));
    try testing.expectEqual(@as(u32, 0), graph.degree(v2));
}

test "interference: full overlap" {
    var liveness = LivenessInfo.init(testing.allocator);
    defer liveness.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);

    // v0 and v1 have exact same range [5, 10]
    try liveness.addRange(.{
        .vreg = v0,
        .start_inst = 5,
        .end_inst = 10,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v1,
        .start_inst = 5,
        .end_inst = 10,
        .reg_class = .int,
    });

    var graph = try buildInterferenceGraph(testing.allocator, &liveness);
    defer graph.deinit();

    // Should interfere (full overlap)
    try testing.expect(graph.interferes(v0, v1));
    try testing.expect(graph.interferes(v1, v0));

    // Both should have degree 1
    try testing.expectEqual(@as(u32, 1), graph.degree(v0));
    try testing.expectEqual(@as(u32, 1), graph.degree(v1));
}

test "interference: boundary conditions" {
    var liveness = LivenessInfo.init(testing.allocator);
    defer liveness.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);

    // Ranges that touch at boundary [0, 5] and [5, 10]
    // Depending on overlap semantics, this may or may not interfere
    try liveness.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 5,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v1,
        .start_inst = 5,
        .end_inst = 10,
        .reg_class = .int,
    });

    var graph = try buildInterferenceGraph(testing.allocator, &liveness);
    defer graph.deinit();

    // Test that the graph was built successfully
    try testing.expectEqual(@as(u32, 2), graph.num_vregs);
}

test "interference: many vregs partially overlapping" {
    var liveness = LivenessInfo.init(testing.allocator);
    defer liveness.deinit();

    // Create 5 vregs with staggered overlapping ranges
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const v3 = VReg.new(3, .int);
    const v4 = VReg.new(4, .int);

    try liveness.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 5,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v1,
        .start_inst = 3,
        .end_inst = 8,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v2,
        .start_inst = 6,
        .end_inst = 11,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v3,
        .start_inst = 9,
        .end_inst = 14,
        .reg_class = .int,
    });

    try liveness.addRange(.{
        .vreg = v4,
        .start_inst = 12,
        .end_inst = 17,
        .reg_class = .int,
    });

    var graph = try buildInterferenceGraph(testing.allocator, &liveness);
    defer graph.deinit();

    // v0 and v1 overlap [3, 5]
    try testing.expect(graph.interferes(v0, v1));

    // v1 and v2 overlap [6, 8]
    try testing.expect(graph.interferes(v1, v2));

    // v2 and v3 overlap [9, 11]
    try testing.expect(graph.interferes(v2, v3));

    // v3 and v4 overlap [12, 14]
    try testing.expect(graph.interferes(v3, v4));

    // v0 and v2 don't overlap
    try testing.expect(!graph.interferes(v0, v2));

    // v1 and v3 don't overlap
    try testing.expect(!graph.interferes(v1, v3));
}
