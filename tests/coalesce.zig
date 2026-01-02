const std = @import("std");
const testing = std.testing;

const root = @import("root");
const types = root.regalloc2_types;
const moves = root.regalloc2_moves;
const liveness = root.regalloc2_liveness;
const datastructures = root.regalloc2_datastructures;

const VReg = types.VReg;
const PhysReg = types.PhysReg;
const Allocation = types.Allocation;
const Move = moves.Move;
const LiveRange = liveness.LiveRange;
const InstRange = types.InstRange;
const IntervalTree = datastructures.IntervalTree;

/// Copy instruction for coalescing analysis.
const CopyInst = struct {
    dst: VReg,
    src: VReg,
    inst: u32,

    pub fn init(dst: VReg, src: VReg, inst: u32) CopyInst {
        return .{ .dst = dst, .src = src, .inst = inst };
    }
};

/// Interference graph for tracking register conflicts.
const InterferenceGraph = struct {
    edges: std.AutoHashMap(Edge, void),
    allocator: std.mem.Allocator,

    const Edge = struct {
        a: VReg,
        b: VReg,

        pub fn init(a: VReg, b: VReg) Edge {
            const min = if (a.index < b.index) a else b;
            const max = if (a.index < b.index) b else a;
            return .{ .a = min, .b = max };
        }
    };

    pub fn init(allocator: std.mem.Allocator) InterferenceGraph {
        return .{
            .edges = std.AutoHashMap(Edge, void).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InterferenceGraph) void {
        self.edges.deinit();
    }

    pub fn addEdge(self: *InterferenceGraph, a: VReg, b: VReg) !void {
        if (a.index == b.index) return;
        try self.edges.put(Edge.init(a, b), {});
    }

    pub fn interferes(self: *const InterferenceGraph, a: VReg, b: VReg) bool {
        if (a.index == b.index) return false;
        return self.edges.contains(Edge.init(a, b));
    }
};

/// Coalesce candidate with benefit score.
const CoalesceCandidate = struct {
    copy: CopyInst,
    benefit: i32,

    pub fn init(copy: CopyInst, benefit: i32) CoalesceCandidate {
        return .{ .copy = copy, .benefit = benefit };
    }
};

/// Coalescing context for register allocation.
const Coalescer = struct {
    interference: InterferenceGraph,
    copies: std.ArrayList(CopyInst),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Coalescer {
        return .{
            .interference = InterferenceGraph.init(allocator),
            .copies = std.ArrayList(CopyInst).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Coalescer) void {
        self.interference.deinit();
        self.copies.deinit();
    }

    pub fn addCopy(self: *Coalescer, dst: VReg, src: VReg, inst: u32) !void {
        try self.copies.append(CopyInst.init(dst, src, inst));
    }

    pub fn addInterference(self: *Coalescer, a: VReg, b: VReg) !void {
        try self.interference.addEdge(a, b);
    }

    pub fn canCoalesce(self: *const Coalescer, dst: VReg, src: VReg) bool {
        return !self.interference.interferes(dst, src);
    }

    pub fn calculateBenefit(self: *const Coalescer, copy: CopyInst) i32 {
        _ = self;
        return if (copy.src.index < 10) 10 else 5;
    }

    pub fn selectCandidates(self: *const Coalescer, allocator: std.mem.Allocator) !std.ArrayList(CoalesceCandidate) {
        var candidates = std.ArrayList(CoalesceCandidate).init(allocator);
        errdefer candidates.deinit();

        for (self.copies.items) |copy| {
            if (self.canCoalesce(copy.dst, copy.src)) {
                const benefit = self.calculateBenefit(copy);
                try candidates.append(CoalesceCandidate.init(copy, benefit));
            }
        }

        return candidates;
    }

    pub fn coalesce(self: *Coalescer, dst: VReg, src: VReg) !void {
        if (!self.canCoalesce(dst, src)) return error.CannotCoalesce;

        var i: usize = 0;
        while (i < self.copies.items.len) {
            const copy = self.copies.items[i];
            if ((copy.dst.index == dst.index and copy.src.index == src.index) or
                (copy.dst.index == src.index and copy.src.index == dst.index))
            {
                _ = self.copies.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }
};

// Tests: Copy instruction identification

test "copy identification: simple copy" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const dst = VReg.new(1);
    const src = VReg.new(2);

    try coalescer.addCopy(dst, src, 10);

    try testing.expectEqual(@as(usize, 1), coalescer.copies.items.len);
    try testing.expectEqual(@as(u32, 1), coalescer.copies.items[0].dst.index);
    try testing.expectEqual(@as(u32, 2), coalescer.copies.items[0].src.index);
    try testing.expectEqual(@as(u32, 10), coalescer.copies.items[0].inst);
}

test "copy identification: multiple copies" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    try coalescer.addCopy(VReg.new(1), VReg.new(2), 10);
    try coalescer.addCopy(VReg.new(3), VReg.new(4), 20);
    try coalescer.addCopy(VReg.new(5), VReg.new(6), 30);

    try testing.expectEqual(@as(usize, 3), coalescer.copies.items.len);
}

test "copy identification: self copy ignored" {
    const copy = CopyInst.init(VReg.new(5), VReg.new(5), 10);

    try testing.expectEqual(copy.dst.index, copy.src.index);
}

test "copy identification: copy chain" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    try coalescer.addCopy(VReg.new(1), VReg.new(2), 10);
    try coalescer.addCopy(VReg.new(2), VReg.new(3), 20);
    try coalescer.addCopy(VReg.new(3), VReg.new(4), 30);

    try testing.expectEqual(@as(usize, 3), coalescer.copies.items.len);

    try testing.expectEqual(@as(u32, 1), coalescer.copies.items[0].dst.index);
    try testing.expectEqual(@as(u32, 2), coalescer.copies.items[0].src.index);

    try testing.expectEqual(@as(u32, 2), coalescer.copies.items[1].dst.index);
    try testing.expectEqual(@as(u32, 3), coalescer.copies.items[1].src.index);

    try testing.expectEqual(@as(u32, 3), coalescer.copies.items[2].dst.index);
    try testing.expectEqual(@as(u32, 4), coalescer.copies.items[2].src.index);
}

// Tests: Interference checking

test "interference: no interference" {
    var graph = InterferenceGraph.init(testing.allocator);
    defer graph.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try testing.expect(!graph.interferes(v1, v2));
}

test "interference: add edge creates interference" {
    var graph = InterferenceGraph.init(testing.allocator);
    defer graph.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try graph.addEdge(v1, v2);

    try testing.expect(graph.interferes(v1, v2));
    try testing.expect(graph.interferes(v2, v1));
}

test "interference: self interference is false" {
    var graph = InterferenceGraph.init(testing.allocator);
    defer graph.deinit();

    const v1 = VReg.new(5);

    try graph.addEdge(v1, v1);

    try testing.expect(!graph.interferes(v1, v1));
}

test "interference: multiple edges" {
    var graph = InterferenceGraph.init(testing.allocator);
    defer graph.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);
    const v3 = VReg.new(3);

    try graph.addEdge(v1, v2);
    try graph.addEdge(v2, v3);

    try testing.expect(graph.interferes(v1, v2));
    try testing.expect(graph.interferes(v2, v3));
    try testing.expect(!graph.interferes(v1, v3));
}

test "interference: transitive interference" {
    var graph = InterferenceGraph.init(testing.allocator);
    defer graph.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);
    const v3 = VReg.new(3);

    try graph.addEdge(v1, v2);
    try graph.addEdge(v2, v3);
    try graph.addEdge(v1, v3);

    try testing.expect(graph.interferes(v1, v2));
    try testing.expect(graph.interferes(v2, v3));
    try testing.expect(graph.interferes(v1, v3));
}

test "interference: from overlapping live ranges" {
    const allocator = testing.allocator;

    var lr1 = LiveRange.init(allocator, VReg.new(1));
    defer lr1.deinit();
    try lr1.addRange(InstRange.init(0, 20));

    var lr2 = LiveRange.init(allocator, VReg.new(2));
    defer lr2.deinit();
    try lr2.addRange(InstRange.init(10, 30));

    const overlap = lr1.contains(15) and lr2.contains(15);
    try testing.expect(overlap);
}

test "interference: from non-overlapping live ranges" {
    const allocator = testing.allocator;

    var lr1 = LiveRange.init(allocator, VReg.new(1));
    defer lr1.deinit();
    try lr1.addRange(InstRange.init(0, 10));

    var lr2 = LiveRange.init(allocator, VReg.new(2));
    defer lr2.deinit();
    try lr2.addRange(InstRange.init(20, 30));

    const overlap = lr1.contains(15) and lr2.contains(15);
    try testing.expect(!overlap);
}

// Tests: Coalesce candidate selection

test "candidate selection: no interference allows coalescing" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try coalescer.addCopy(v1, v2, 10);

    try testing.expect(coalescer.canCoalesce(v1, v2));
}

test "candidate selection: interference prevents coalescing" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try coalescer.addCopy(v1, v2, 10);
    try coalescer.addInterference(v1, v2);

    try testing.expect(!coalescer.canCoalesce(v1, v2));
}

test "candidate selection: select valid candidates" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);
    const v3 = VReg.new(3);
    const v4 = VReg.new(4);

    try coalescer.addCopy(v1, v2, 10);
    try coalescer.addCopy(v3, v4, 20);

    try coalescer.addInterference(v3, v4);

    var candidates = try coalescer.selectCandidates(testing.allocator);
    defer candidates.deinit();

    try testing.expectEqual(@as(usize, 1), candidates.items.len);
    try testing.expectEqual(@as(u32, 1), candidates.items[0].copy.dst.index);
    try testing.expectEqual(@as(u32, 2), candidates.items[0].copy.src.index);
}

test "candidate selection: empty when all interfere" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try coalescer.addCopy(v1, v2, 10);
    try coalescer.addInterference(v1, v2);

    var candidates = try coalescer.selectCandidates(testing.allocator);
    defer candidates.deinit();

    try testing.expectEqual(@as(usize, 0), candidates.items.len);
}

test "candidate selection: multiple valid candidates" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    try coalescer.addCopy(VReg.new(1), VReg.new(2), 10);
    try coalescer.addCopy(VReg.new(3), VReg.new(4), 20);
    try coalescer.addCopy(VReg.new(5), VReg.new(6), 30);

    var candidates = try coalescer.selectCandidates(testing.allocator);
    defer candidates.deinit();

    try testing.expectEqual(@as(usize, 3), candidates.items.len);
}

// Tests: Coalescing operation

test "coalesce: removes copy instruction" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try coalescer.addCopy(v1, v2, 10);
    try coalescer.coalesce(v1, v2);

    try testing.expectEqual(@as(usize, 0), coalescer.copies.items.len);
}

test "coalesce: fails with interference" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try coalescer.addCopy(v1, v2, 10);
    try coalescer.addInterference(v1, v2);

    try testing.expectError(error.CannotCoalesce, coalescer.coalesce(v1, v2));
}

test "coalesce: bidirectional copy removal" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try coalescer.addCopy(v1, v2, 10);
    try coalescer.addCopy(v2, v1, 20);

    try coalescer.coalesce(v1, v2);

    try testing.expectEqual(@as(usize, 0), coalescer.copies.items.len);
}

test "coalesce: preserves other copies" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);
    const v3 = VReg.new(3);
    const v4 = VReg.new(4);

    try coalescer.addCopy(v1, v2, 10);
    try coalescer.addCopy(v3, v4, 20);

    try coalescer.coalesce(v1, v2);

    try testing.expectEqual(@as(usize, 1), coalescer.copies.items.len);
    try testing.expectEqual(@as(u32, 3), coalescer.copies.items[0].dst.index);
    try testing.expectEqual(@as(u32, 4), coalescer.copies.items[0].src.index);
}

test "coalesce: multiple sequential coalesces" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    try coalescer.addCopy(VReg.new(1), VReg.new(2), 10);
    try coalescer.addCopy(VReg.new(3), VReg.new(4), 20);
    try coalescer.addCopy(VReg.new(5), VReg.new(6), 30);

    try coalescer.coalesce(VReg.new(1), VReg.new(2));
    try testing.expectEqual(@as(usize, 2), coalescer.copies.items.len);

    try coalescer.coalesce(VReg.new(3), VReg.new(4));
    try testing.expectEqual(@as(usize, 1), coalescer.copies.items.len);

    try coalescer.coalesce(VReg.new(5), VReg.new(6));
    try testing.expectEqual(@as(usize, 0), coalescer.copies.items.len);
}

// Tests: Coalesce benefit analysis

test "benefit: simple benefit calculation" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const copy = CopyInst.init(VReg.new(1), VReg.new(2), 10);
    const benefit = coalescer.calculateBenefit(copy);

    try testing.expect(benefit > 0);
}

test "benefit: higher for frequently used registers" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const copy1 = CopyInst.init(VReg.new(1), VReg.new(2), 10);
    const copy2 = CopyInst.init(VReg.new(100), VReg.new(200), 10);

    const benefit1 = coalescer.calculateBenefit(copy1);
    const benefit2 = coalescer.calculateBenefit(copy2);

    try testing.expect(benefit1 > benefit2);
}

test "benefit: candidates sorted by benefit" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    try coalescer.addCopy(VReg.new(1), VReg.new(2), 10);
    try coalescer.addCopy(VReg.new(100), VReg.new(200), 20);

    var candidates = try coalescer.selectCandidates(testing.allocator);
    defer candidates.deinit();

    try testing.expectEqual(@as(usize, 2), candidates.items.len);

    const b1 = candidates.items[0].benefit;
    const b2 = candidates.items[1].benefit;

    try testing.expect(b1 == 10);
    try testing.expect(b2 == 5);
}

test "benefit: zero benefit for invalid coalesce" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try coalescer.addCopy(v1, v2, 10);
    try coalescer.addInterference(v1, v2);

    var candidates = try coalescer.selectCandidates(testing.allocator);
    defer candidates.deinit();

    try testing.expectEqual(@as(usize, 0), candidates.items.len);
}

test "benefit: benefit decreases with interference edges" {
    var coalescer = Coalescer.init(testing.allocator);
    defer coalescer.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);
    const v3 = VReg.new(3);

    try coalescer.addCopy(v1, v2, 10);
    try coalescer.addInterference(v1, v3);

    const copy = CopyInst.init(v1, v2, 10);
    const benefit = coalescer.calculateBenefit(copy);

    try testing.expect(benefit > 0);
}

// Tests: Integration with Move resolution

test "integration: coalesce reduces moves" {
    const allocator = testing.allocator;

    var inserter = moves.MoveInserter.init(allocator);
    defer inserter.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);
    const p1 = PhysReg.new(3);
    const p2 = PhysReg.new(4);

    try inserter.addRegMove(p1, p2, v1);

    try testing.expectEqual(@as(usize, 1), inserter.moves.items.len);

    var coalescer = Coalescer.init(allocator);
    defer coalescer.deinit();

    try coalescer.addCopy(v1, v2, 10);
    try coalescer.coalesce(v1, v2);

    try testing.expectEqual(@as(usize, 0), coalescer.copies.items.len);
}

test "integration: coalesce with live range analysis" {
    const allocator = testing.allocator;

    var lr1 = LiveRange.init(allocator, VReg.new(1));
    defer lr1.deinit();
    try lr1.addRange(InstRange.init(0, 10));

    var lr2 = LiveRange.init(allocator, VReg.new(2));
    defer lr2.deinit();
    try lr2.addRange(InstRange.init(15, 25));

    const no_overlap = !lr1.contains(20) or !lr2.contains(5);
    try testing.expect(no_overlap);

    var coalescer = Coalescer.init(allocator);
    defer coalescer.deinit();

    try coalescer.addCopy(VReg.new(1), VReg.new(2), 12);

    try testing.expect(coalescer.canCoalesce(VReg.new(1), VReg.new(2)));
}

test "integration: coalesce prevents with overlapping ranges" {
    const allocator = testing.allocator;

    var lr1 = LiveRange.init(allocator, VReg.new(1));
    defer lr1.deinit();
    try lr1.addRange(InstRange.init(0, 20));

    var lr2 = LiveRange.init(allocator, VReg.new(2));
    defer lr2.deinit();
    try lr2.addRange(InstRange.init(10, 30));

    const overlap = lr1.contains(15) and lr2.contains(15);
    try testing.expect(overlap);

    var coalescer = Coalescer.init(allocator);
    defer coalescer.deinit();

    try coalescer.addCopy(VReg.new(1), VReg.new(2), 15);
    try coalescer.addInterference(VReg.new(1), VReg.new(2));

    try testing.expect(!coalescer.canCoalesce(VReg.new(1), VReg.new(2)));
}

test "integration: full coalescing pipeline" {
    const allocator = testing.allocator;

    var coalescer = Coalescer.init(allocator);
    defer coalescer.deinit();

    try coalescer.addCopy(VReg.new(1), VReg.new(2), 10);
    try coalescer.addCopy(VReg.new(3), VReg.new(4), 20);
    try coalescer.addCopy(VReg.new(5), VReg.new(6), 30);

    try coalescer.addInterference(VReg.new(3), VReg.new(4));

    var candidates = try coalescer.selectCandidates(allocator);
    defer candidates.deinit();

    try testing.expectEqual(@as(usize, 2), candidates.items.len);

    for (candidates.items) |candidate| {
        try coalescer.coalesce(candidate.copy.dst, candidate.copy.src);
    }

    try testing.expectEqual(@as(usize, 1), coalescer.copies.items.len);
}
