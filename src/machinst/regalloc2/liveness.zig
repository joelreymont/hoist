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
