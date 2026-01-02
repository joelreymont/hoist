const std = @import("std");
const types = @import("types.zig");
const VReg = types.VReg;
const InstRange = types.InstRange;
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Live-in and live-out sets for basic blocks.
pub const LivenessInfo = struct {
    live_in: std.AutoHashMap(u32, std.AutoHashMap(VReg, void)),
    live_out: std.AutoHashMap(u32, std.AutoHashMap(VReg, void)),
    allocator: Allocator,

    pub fn init(allocator: Allocator) LivenessInfo {
        return .{
            .live_in = std.AutoHashMap(u32, std.AutoHashMap(VReg, void)).init(allocator),
            .live_out = std.AutoHashMap(u32, std.AutoHashMap(VReg, void)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LivenessInfo) void {
        var it_in = self.live_in.valueIterator();
        while (it_in.next()) |set| {
            set.deinit();
        }
        self.live_in.deinit();

        var it_out = self.live_out.valueIterator();
        while (it_out.next()) |set| {
            set.deinit();
        }
        self.live_out.deinit();
    }

    /// Calculate live-in set for a block.
    pub fn calculateLiveIn(self: *LivenessInfo, block: u32, uses: []const VReg, defs: []const VReg) !void {
        var set = std.AutoHashMap(VReg, void).init(self.allocator);
        errdefer set.deinit();

        // live_in = use ∪ (live_out - def)
        const live_out_set = self.live_out.get(block);
        if (live_out_set) |out_set| {
            var it = out_set.keyIterator();
            while (it.next()) |vreg| {
                var is_def = false;
                for (defs) |def| {
                    if (def.index == vreg.index) {
                        is_def = true;
                        break;
                    }
                }
                if (!is_def) {
                    try set.put(vreg.*, {});
                }
            }
        }

        // Add uses
        for (uses) |use| {
            try set.put(use, {});
        }

        try self.live_in.put(block, set);
    }

    /// Get live-in set for a block.
    pub fn getLiveIn(self: *const LivenessInfo, block: u32) ?*const std.AutoHashMap(VReg, void) {
        return if (self.live_in.getPtr(block)) |ptr| ptr else null;
    }

    /// Check if a virtual register is live-in at a block.
    pub fn isLiveIn(self: *const LivenessInfo, block: u32, vreg: VReg) bool {
        const set = self.live_in.get(block) orelse return false;
        return set.contains(vreg);
    }

    /// Calculate live-out set for a block.
    pub fn calculateLiveOut(self: *LivenessInfo, block: u32, successors: []const u32) !void {
        var set = std.AutoHashMap(VReg, void).init(self.allocator);
        errdefer set.deinit();

        // live_out = ∪(live_in of all successors)
        for (successors) |succ| {
            const succ_live_in = self.live_in.get(succ);
            if (succ_live_in) |in_set| {
                var it = in_set.keyIterator();
                while (it.next()) |vreg| {
                    try set.put(vreg.*, {});
                }
            }
        }

        try self.live_out.put(block, set);
    }

    /// Get live-out set for a block.
    pub fn getLiveOut(self: *const LivenessInfo, block: u32) ?*const std.AutoHashMap(VReg, void) {
        return if (self.live_out.getPtr(block)) |ptr| ptr else null;
    }

    /// Check if a virtual register is live-out at a block.
    pub fn isLiveOut(self: *const LivenessInfo, block: u32, vreg: VReg) bool {
        const set = self.live_out.get(block) orelse return false;
        return set.contains(vreg);
    }
};

/// Live range for a virtual register.
pub const LiveRange = struct {
    vreg: VReg,
    ranges: std.ArrayList(InstRange),
    allocator: Allocator,

    pub fn init(allocator: Allocator, vreg: VReg) LiveRange {
        return .{
            .vreg = vreg,
            .ranges = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LiveRange) void {
        self.ranges.deinit(self.allocator);
    }

    /// Add an instruction range to this live range.
    pub fn addRange(self: *LiveRange, range: InstRange) !void {
        try self.ranges.append(self.allocator, range);
    }

    /// Check if an instruction is in this live range.
    pub fn contains(self: *const LiveRange, inst: u32) bool {
        for (self.ranges.items) |range| {
            if (range.contains(inst)) return true;
        }
        return false;
    }

    /// Merge overlapping ranges.
    pub fn merge(self: *LiveRange) void {
        if (self.ranges.items.len <= 1) return;

        // Sort ranges by start position
        std.mem.sort(InstRange, self.ranges.items, {}, struct {
            fn lessThan(_: void, a: InstRange, b: InstRange) bool {
                return a.start < b.start;
            }
        }.lessThan);

        var i: usize = 0;
        while (i + 1 < self.ranges.items.len) {
            const curr = self.ranges.items[i];
            const next = self.ranges.items[i + 1];

            // Merge if overlapping or adjacent
            if (curr.end >= next.start) {
                self.ranges.items[i].end = @max(curr.end, next.end);
                _ = self.ranges.orderedRemove(i + 1);
            } else {
                i += 1;
            }
        }
    }

    /// Split live range at a given instruction position.
    pub fn split(self: *LiveRange, allocator: Allocator, at: u32) !?LiveRange {
        var before = LiveRange.init(allocator, self.vreg);
        errdefer before.deinit();

        var after = LiveRange.init(allocator, self.vreg);
        errdefer after.deinit();

        for (self.ranges.items) |range| {
            if (range.end <= at) {
                // Entirely before split point
                try before.addRange(range);
            } else if (range.start >= at) {
                // Entirely after split point
                try after.addRange(range);
            } else {
                // Spans split point - split it
                try before.addRange(InstRange.init(range.start, at));
                try after.addRange(InstRange.init(at, range.end));
            }
        }

        // Replace self with before ranges
        self.ranges.deinit(self.allocator);
        self.ranges = before.ranges;
        before.ranges = .{};

        // Return after ranges if non-empty
        if (after.ranges.items.len > 0) {
            return after;
        } else {
            after.deinit();
            return null;
        }
    }
};

/// Use position for register allocation.
pub const UsePosition = struct {
    inst: u32,
    kind: Kind,

    pub const Kind = enum {
        use,
        def,
        use_def,
    };

    pub fn init(inst: u32, kind: Kind) UsePosition {
        return .{ .inst = inst, .kind = kind };
    }
};

/// Use position tracker for a virtual register.
pub const UsePositions = struct {
    vreg: VReg,
    positions: std.ArrayList(UsePosition),
    allocator: Allocator,

    pub fn init(allocator: Allocator, vreg: VReg) UsePositions {
        return .{
            .vreg = vreg,
            .positions = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *UsePositions) void {
        self.positions.deinit(self.allocator);
    }

    /// Add a use position.
    pub fn addUse(self: *UsePositions, inst: u32) !void {
        try self.positions.append(self.allocator, UsePosition.init(inst, .use));
    }

    /// Add a def position.
    pub fn addDef(self: *UsePositions, inst: u32) !void {
        try self.positions.append(self.allocator, UsePosition.init(inst, .def));
    }

    /// Add a use-def position.
    pub fn addUseDef(self: *UsePositions, inst: u32) !void {
        try self.positions.append(self.allocator, UsePosition.init(inst, .use_def));
    }

    /// Sort positions by instruction number.
    pub fn sort(self: *UsePositions) void {
        std.mem.sort(UsePosition, self.positions.items, {}, struct {
            fn lessThan(_: void, a: UsePosition, b: UsePosition) bool {
                return a.inst < b.inst;
            }
        }.lessThan);
    }

    /// Find next use after given instruction.
    pub fn nextUseAfter(self: *const UsePositions, inst: u32) ?UsePosition {
        for (self.positions.items) |pos| {
            if (pos.inst > inst and (pos.kind == .use or pos.kind == .use_def)) {
                return pos;
            }
        }
        return null;
    }
};

test "LivenessInfo calculateLiveIn" {
    const allocator = testing.allocator;
    var info = LivenessInfo.init(allocator);
    defer info.deinit();

    const uses = [_]VReg{ VReg.new(1), VReg.new(2) };
    const defs = [_]VReg{VReg.new(3)};

    try info.calculateLiveIn(0, &uses, &defs);

    const live_in = info.getLiveIn(0);
    try testing.expect(live_in != null);
    try testing.expect(live_in.?.contains(VReg.new(1)));
    try testing.expect(live_in.?.contains(VReg.new(2)));
    try testing.expect(!live_in.?.contains(VReg.new(3)));
}

test "LivenessInfo isLiveIn" {
    const allocator = testing.allocator;
    var info = LivenessInfo.init(allocator);
    defer info.deinit();

    const uses = [_]VReg{VReg.new(5)};
    const defs = [_]VReg{};

    try info.calculateLiveIn(1, &uses, &defs);

    try testing.expect(info.isLiveIn(1, VReg.new(5)));
    try testing.expect(!info.isLiveIn(1, VReg.new(99)));
    try testing.expect(!info.isLiveIn(999, VReg.new(5)));
}

test "LivenessInfo calculateLiveOut" {
    const allocator = testing.allocator;
    var info = LivenessInfo.init(allocator);
    defer info.deinit();

    // Block 1 has v1 live-in
    const uses1 = [_]VReg{VReg.new(1)};
    const defs1 = [_]VReg{};
    try info.calculateLiveIn(1, &uses1, &defs1);

    // Block 2 has v2 live-in
    const uses2 = [_]VReg{VReg.new(2)};
    const defs2 = [_]VReg{};
    try info.calculateLiveIn(2, &uses2, &defs2);

    // Block 0 has successors 1 and 2
    const successors = [_]u32{ 1, 2 };
    try info.calculateLiveOut(0, &successors);

    const live_out = info.getLiveOut(0);
    try testing.expect(live_out != null);
    try testing.expect(live_out.?.contains(VReg.new(1)));
    try testing.expect(live_out.?.contains(VReg.new(2)));
}

test "LivenessInfo isLiveOut" {
    const allocator = testing.allocator;
    var info = LivenessInfo.init(allocator);
    defer info.deinit();

    const uses = [_]VReg{VReg.new(7)};
    const defs = [_]VReg{};
    try info.calculateLiveIn(5, &uses, &defs);

    const successors = [_]u32{5};
    try info.calculateLiveOut(4, &successors);

    try testing.expect(info.isLiveOut(4, VReg.new(7)));
    try testing.expect(!info.isLiveOut(4, VReg.new(99)));
}

test "LiveRange addRange" {
    const allocator = testing.allocator;
    var lr = LiveRange.init(allocator, VReg.new(10));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 10));
    try lr.addRange(InstRange.init(20, 30));

    try testing.expectEqual(@as(usize, 2), lr.ranges.items.len);
    try testing.expect(lr.contains(5));
    try testing.expect(lr.contains(25));
    try testing.expect(!lr.contains(15));
}

test "LiveRange merge" {
    const allocator = testing.allocator;
    var lr = LiveRange.init(allocator, VReg.new(15));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 10));
    try lr.addRange(InstRange.init(5, 15));
    try lr.addRange(InstRange.init(20, 30));

    lr.merge();

    try testing.expectEqual(@as(usize, 2), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 15), lr.ranges.items[0].end);
    try testing.expectEqual(@as(u32, 20), lr.ranges.items[1].start);
    try testing.expectEqual(@as(u32, 30), lr.ranges.items[1].end);
}

test "LiveRange split" {
    const allocator = testing.allocator;
    var lr = LiveRange.init(allocator, VReg.new(20));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 20));
    try lr.addRange(InstRange.init(30, 40));

    var after = try lr.split(allocator, 15);
    defer if (after) |*a| a.deinit();

    // Before should have [0, 15) and no part of [30, 40)
    try testing.expectEqual(@as(usize, 1), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 15), lr.ranges.items[0].end);

    // After should have [15, 20) and [30, 40)
    try testing.expect(after != null);
    try testing.expectEqual(@as(usize, 2), after.?.ranges.items.len);
    try testing.expectEqual(@as(u32, 15), after.?.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 20), after.?.ranges.items[0].end);
    try testing.expectEqual(@as(u32, 30), after.?.ranges.items[1].start);
    try testing.expectEqual(@as(u32, 40), after.?.ranges.items[1].end);
}

test "UsePositions addUse" {
    const allocator = testing.allocator;
    var up = UsePositions.init(allocator, VReg.new(5));
    defer up.deinit();

    try up.addUse(10);
    try up.addDef(20);
    try up.addUseDef(30);

    try testing.expectEqual(@as(usize, 3), up.positions.items.len);
    try testing.expectEqual(@as(u32, 10), up.positions.items[0].inst);
    try testing.expectEqual(UsePosition.Kind.use, up.positions.items[0].kind);
    try testing.expectEqual(@as(u32, 20), up.positions.items[1].inst);
    try testing.expectEqual(UsePosition.Kind.def, up.positions.items[1].kind);
}

test "UsePositions nextUseAfter" {
    const allocator = testing.allocator;
    var up = UsePositions.init(allocator, VReg.new(7));
    defer up.deinit();

    try up.addDef(5);
    try up.addUse(10);
    try up.addUse(20);
    try up.addDef(25);

    const next = up.nextUseAfter(12);
    try testing.expect(next != null);
    try testing.expectEqual(@as(u32, 20), next.?.inst);

    const none = up.nextUseAfter(25);
    try testing.expect(none == null);
}
