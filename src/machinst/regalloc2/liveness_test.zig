const std = @import("std");
const testing = std.testing;

const liveness_mod = @import("liveness.zig");
const types_mod = @import("types.zig");

const LivenessInfo = liveness_mod.LivenessInfo;
const LiveRange = liveness_mod.LiveRange;
const UsePositions = liveness_mod.UsePositions;
const UsePosition = liveness_mod.UsePosition;
const VReg = types_mod.VReg;
const InstRange = types_mod.InstRange;

// ===== LivenessInfo Tests =====

test "LivenessInfo: init and deinit" {
    var info = LivenessInfo.init(testing.allocator);
    defer info.deinit();

    try testing.expectEqual(@as(usize, 0), info.live_in.count());
    try testing.expectEqual(@as(usize, 0), info.live_out.count());
}

test "LivenessInfo: calculateLiveIn basic" {
    var info = LivenessInfo.init(testing.allocator);
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

test "LivenessInfo: calculateLiveIn empty" {
    var info = LivenessInfo.init(testing.allocator);
    defer info.deinit();

    const uses = [_]VReg{};
    const defs = [_]VReg{};

    try info.calculateLiveIn(0, &uses, &defs);

    const live_in = info.getLiveIn(0);
    try testing.expect(live_in != null);
    try testing.expectEqual(@as(usize, 0), live_in.?.count());
}

test "LivenessInfo: calculateLiveIn with live-out" {
    var info = LivenessInfo.init(testing.allocator);
    defer info.deinit();

    // First set up live-out for block 0
    const succ_uses = [_]VReg{ VReg.new(1), VReg.new(2) };
    const succ_defs = [_]VReg{};
    try info.calculateLiveIn(1, &succ_uses, &succ_defs);

    const successors = [_]u32{1};
    try info.calculateLiveOut(0, &successors);

    // Now calculate live-in: use v3, def v2
    // live_in = {v3} ∪ ({v1, v2} - {v2}) = {v3, v1}
    const uses = [_]VReg{VReg.new(3)};
    const defs = [_]VReg{VReg.new(2)};
    try info.calculateLiveIn(0, &uses, &defs);

    const live_in = info.getLiveIn(0);
    try testing.expect(live_in != null);
    try testing.expect(live_in.?.contains(VReg.new(1)));
    try testing.expect(!live_in.?.contains(VReg.new(2))); // Defined, so not in live-in
    try testing.expect(live_in.?.contains(VReg.new(3)));
}

test "LivenessInfo: isLiveIn" {
    var info = LivenessInfo.init(testing.allocator);
    defer info.deinit();

    const uses = [_]VReg{VReg.new(5)};
    const defs = [_]VReg{};

    try info.calculateLiveIn(1, &uses, &defs);

    try testing.expect(info.isLiveIn(1, VReg.new(5)));
    try testing.expect(!info.isLiveIn(1, VReg.new(99)));
    try testing.expect(!info.isLiveIn(999, VReg.new(5)));
}

test "LivenessInfo: getLiveIn nonexistent block" {
    var info = LivenessInfo.init(testing.allocator);
    defer info.deinit();

    const live_in = info.getLiveIn(999);
    try testing.expect(live_in == null);
}

test "LivenessInfo: calculateLiveOut basic" {
    var info = LivenessInfo.init(testing.allocator);
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

test "LivenessInfo: calculateLiveOut empty successors" {
    var info = LivenessInfo.init(testing.allocator);
    defer info.deinit();

    const successors = [_]u32{};
    try info.calculateLiveOut(0, &successors);

    const live_out = info.getLiveOut(0);
    try testing.expect(live_out != null);
    try testing.expectEqual(@as(usize, 0), live_out.?.count());
}

test "LivenessInfo: calculateLiveOut multiple occurrences" {
    var info = LivenessInfo.init(testing.allocator);
    defer info.deinit();

    // Both successors have v1 live-in
    const uses = [_]VReg{VReg.new(1)};
    const defs = [_]VReg{};
    try info.calculateLiveIn(1, &uses, &defs);
    try info.calculateLiveIn(2, &uses, &defs);

    const successors = [_]u32{ 1, 2 };
    try info.calculateLiveOut(0, &successors);

    const live_out = info.getLiveOut(0);
    try testing.expect(live_out != null);
    // v1 should appear once even though it's in both successors
    try testing.expectEqual(@as(usize, 1), live_out.?.count());
    try testing.expect(live_out.?.contains(VReg.new(1)));
}

test "LivenessInfo: isLiveOut" {
    var info = LivenessInfo.init(testing.allocator);
    defer info.deinit();

    const uses = [_]VReg{VReg.new(7)};
    const defs = [_]VReg{};
    try info.calculateLiveIn(5, &uses, &defs);

    const successors = [_]u32{5};
    try info.calculateLiveOut(4, &successors);

    try testing.expect(info.isLiveOut(4, VReg.new(7)));
    try testing.expect(!info.isLiveOut(4, VReg.new(99)));
    try testing.expect(!info.isLiveOut(999, VReg.new(7)));
}

test "LivenessInfo: getLiveOut nonexistent block" {
    var info = LivenessInfo.init(testing.allocator);
    defer info.deinit();

    const live_out = info.getLiveOut(999);
    try testing.expect(live_out == null);
}

// ===== LiveRange Tests =====

test "LiveRange: init and deinit" {
    var lr = LiveRange.init(testing.allocator, VReg.new(10));
    defer lr.deinit();

    try testing.expectEqual(@as(u32, 10), lr.vreg.index);
    try testing.expectEqual(@as(usize, 0), lr.ranges.items.len);
}

test "LiveRange: addRange single" {
    var lr = LiveRange.init(testing.allocator, VReg.new(10));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 10));

    try testing.expectEqual(@as(usize, 1), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 10), lr.ranges.items[0].end);
}

test "LiveRange: addRange multiple" {
    var lr = LiveRange.init(testing.allocator, VReg.new(10));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 10));
    try lr.addRange(InstRange.init(20, 30));
    try lr.addRange(InstRange.init(40, 50));

    try testing.expectEqual(@as(usize, 3), lr.ranges.items.len);
}

test "LiveRange: contains basic" {
    var lr = LiveRange.init(testing.allocator, VReg.new(10));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 10));
    try lr.addRange(InstRange.init(20, 30));

    try testing.expect(lr.contains(5));
    try testing.expect(lr.contains(25));
    try testing.expect(!lr.contains(15));
    try testing.expect(!lr.contains(35));
}

test "LiveRange: contains empty" {
    var lr = LiveRange.init(testing.allocator, VReg.new(10));
    defer lr.deinit();

    try testing.expect(!lr.contains(0));
    try testing.expect(!lr.contains(100));
}

test "LiveRange: contains boundary" {
    var lr = LiveRange.init(testing.allocator, VReg.new(10));
    defer lr.deinit();

    try lr.addRange(InstRange.init(10, 20));

    try testing.expect(!lr.contains(9));
    try testing.expect(lr.contains(10)); // Inclusive start
    try testing.expect(lr.contains(19));
    try testing.expect(!lr.contains(20)); // Exclusive end
}

test "LiveRange: merge empty" {
    var lr = LiveRange.init(testing.allocator, VReg.new(15));
    defer lr.deinit();

    lr.merge();
    try testing.expectEqual(@as(usize, 0), lr.ranges.items.len);
}

test "LiveRange: merge single" {
    var lr = LiveRange.init(testing.allocator, VReg.new(15));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 10));
    lr.merge();

    try testing.expectEqual(@as(usize, 1), lr.ranges.items.len);
}

test "LiveRange: merge overlapping" {
    var lr = LiveRange.init(testing.allocator, VReg.new(15));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 10));
    try lr.addRange(InstRange.init(5, 15));

    lr.merge();

    try testing.expectEqual(@as(usize, 1), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 15), lr.ranges.items[0].end);
}

test "LiveRange: merge adjacent" {
    var lr = LiveRange.init(testing.allocator, VReg.new(15));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 10));
    try lr.addRange(InstRange.init(10, 20));

    lr.merge();

    try testing.expectEqual(@as(usize, 1), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 20), lr.ranges.items[0].end);
}

test "LiveRange: merge separate" {
    var lr = LiveRange.init(testing.allocator, VReg.new(15));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 10));
    try lr.addRange(InstRange.init(20, 30));

    lr.merge();

    try testing.expectEqual(@as(usize, 2), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 10), lr.ranges.items[0].end);
    try testing.expectEqual(@as(u32, 20), lr.ranges.items[1].start);
    try testing.expectEqual(@as(u32, 30), lr.ranges.items[1].end);
}

test "LiveRange: merge complex" {
    var lr = LiveRange.init(testing.allocator, VReg.new(15));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 10));
    try lr.addRange(InstRange.init(5, 15));
    try lr.addRange(InstRange.init(20, 30));
    try lr.addRange(InstRange.init(25, 35));
    try lr.addRange(InstRange.init(40, 50));

    lr.merge();

    try testing.expectEqual(@as(usize, 3), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 15), lr.ranges.items[0].end);
    try testing.expectEqual(@as(u32, 20), lr.ranges.items[1].start);
    try testing.expectEqual(@as(u32, 35), lr.ranges.items[1].end);
    try testing.expectEqual(@as(u32, 40), lr.ranges.items[2].start);
    try testing.expectEqual(@as(u32, 50), lr.ranges.items[2].end);
}

test "LiveRange: merge unsorted" {
    var lr = LiveRange.init(testing.allocator, VReg.new(15));
    defer lr.deinit();

    // Add ranges in non-sorted order
    try lr.addRange(InstRange.init(20, 30));
    try lr.addRange(InstRange.init(0, 10));
    try lr.addRange(InstRange.init(5, 15));

    lr.merge();

    try testing.expectEqual(@as(usize, 2), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 15), lr.ranges.items[0].end);
    try testing.expectEqual(@as(u32, 20), lr.ranges.items[1].start);
    try testing.expectEqual(@as(u32, 30), lr.ranges.items[1].end);
}

test "LiveRange: split basic" {
    var lr = LiveRange.init(testing.allocator, VReg.new(20));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 20));

    var after = try lr.split(testing.allocator, 10);
    defer if (after) |*a| a.deinit();

    try testing.expect(after != null);

    // Before should have [0, 10)
    try testing.expectEqual(@as(usize, 1), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 10), lr.ranges.items[0].end);

    // After should have [10, 20)
    try testing.expectEqual(@as(usize, 1), after.?.ranges.items.len);
    try testing.expectEqual(@as(u32, 10), after.?.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 20), after.?.ranges.items[0].end);
}

test "LiveRange: split multiple ranges" {
    var lr = LiveRange.init(testing.allocator, VReg.new(20));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 20));
    try lr.addRange(InstRange.init(30, 40));

    var after = try lr.split(testing.allocator, 15);
    defer if (after) |*a| a.deinit();

    // Before should have [0, 15) and nothing from [30, 40)
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

test "LiveRange: split at start" {
    var lr = LiveRange.init(testing.allocator, VReg.new(20));
    defer lr.deinit();

    try lr.addRange(InstRange.init(10, 20));

    var after = try lr.split(testing.allocator, 10);
    defer if (after) |*a| a.deinit();

    // Before should be empty
    try testing.expectEqual(@as(usize, 0), lr.ranges.items.len);

    // After should have [10, 20)
    try testing.expect(after != null);
    try testing.expectEqual(@as(usize, 1), after.?.ranges.items.len);
    try testing.expectEqual(@as(u32, 10), after.?.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 20), after.?.ranges.items[0].end);
}

test "LiveRange: split at end" {
    var lr = LiveRange.init(testing.allocator, VReg.new(20));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 20));

    var after = try lr.split(testing.allocator, 20);
    defer if (after) |*a| a.deinit();

    // Before should have [0, 20)
    try testing.expectEqual(@as(usize, 1), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 20), lr.ranges.items[0].end);

    // After should be null (no ranges after split point)
    try testing.expect(after == null);
}

test "LiveRange: split beyond end" {
    var lr = LiveRange.init(testing.allocator, VReg.new(20));
    defer lr.deinit();

    try lr.addRange(InstRange.init(0, 20));

    var after = try lr.split(testing.allocator, 30);
    defer if (after) |*a| a.deinit();

    // Before should have [0, 20)
    try testing.expectEqual(@as(usize, 1), lr.ranges.items.len);
    try testing.expectEqual(@as(u32, 0), lr.ranges.items[0].start);
    try testing.expectEqual(@as(u32, 20), lr.ranges.items[0].end);

    // After should be null
    try testing.expect(after == null);
}

test "LiveRange: split before start" {
    var lr = LiveRange.init(testing.allocator, VReg.new(20));
    defer lr.deinit();

    try lr.addRange(InstRange.init(10, 20));

    var after = try lr.split(testing.allocator, 5);
    defer if (after) |*a| a.deinit();

    // Before should be empty
    try testing.expectEqual(@as(usize, 0), lr.ranges.items.len);

    // After should have [10, 20)
    try testing.expect(after != null);
    try testing.expectEqual(@as(usize, 1), after.?.ranges.items.len);
}

// ===== UsePositions Tests =====

test "UsePositions: init and deinit" {
    var up = UsePositions.init(testing.allocator, VReg.new(5));
    defer up.deinit();

    try testing.expectEqual(@as(u32, 5), up.vreg.index);
    try testing.expectEqual(@as(usize, 0), up.positions.items.len);
}

test "UsePositions: addUse" {
    var up = UsePositions.init(testing.allocator, VReg.new(5));
    defer up.deinit();

    try up.addUse(10);
    try up.addUse(20);

    try testing.expectEqual(@as(usize, 2), up.positions.items.len);
    try testing.expectEqual(@as(u32, 10), up.positions.items[0].inst);
    try testing.expectEqual(UsePosition.Kind.use, up.positions.items[0].kind);
    try testing.expectEqual(@as(u32, 20), up.positions.items[1].inst);
    try testing.expectEqual(UsePosition.Kind.use, up.positions.items[1].kind);
}

test "UsePositions: addDef" {
    var up = UsePositions.init(testing.allocator, VReg.new(5));
    defer up.deinit();

    try up.addDef(15);
    try up.addDef(25);

    try testing.expectEqual(@as(usize, 2), up.positions.items.len);
    try testing.expectEqual(@as(u32, 15), up.positions.items[0].inst);
    try testing.expectEqual(UsePosition.Kind.def, up.positions.items[0].kind);
    try testing.expectEqual(@as(u32, 25), up.positions.items[1].inst);
    try testing.expectEqual(UsePosition.Kind.def, up.positions.items[1].kind);
}

test "UsePositions: addUseDef" {
    var up = UsePositions.init(testing.allocator, VReg.new(5));
    defer up.deinit();

    try up.addUseDef(30);

    try testing.expectEqual(@as(usize, 1), up.positions.items.len);
    try testing.expectEqual(@as(u32, 30), up.positions.items[0].inst);
    try testing.expectEqual(UsePosition.Kind.use_def, up.positions.items[0].kind);
}

test "UsePositions: mixed positions" {
    var up = UsePositions.init(testing.allocator, VReg.new(5));
    defer up.deinit();

    try up.addUse(10);
    try up.addDef(20);
    try up.addUseDef(30);
    try up.addUse(40);

    try testing.expectEqual(@as(usize, 4), up.positions.items.len);
    try testing.expectEqual(UsePosition.Kind.use, up.positions.items[0].kind);
    try testing.expectEqual(UsePosition.Kind.def, up.positions.items[1].kind);
    try testing.expectEqual(UsePosition.Kind.use_def, up.positions.items[2].kind);
    try testing.expectEqual(UsePosition.Kind.use, up.positions.items[3].kind);
}

test "UsePositions: sort" {
    var up = UsePositions.init(testing.allocator, VReg.new(7));
    defer up.deinit();

    // Add in unsorted order
    try up.addUse(30);
    try up.addDef(10);
    try up.addUse(20);
    try up.addUseDef(5);

    up.sort();

    try testing.expectEqual(@as(usize, 4), up.positions.items.len);
    try testing.expectEqual(@as(u32, 5), up.positions.items[0].inst);
    try testing.expectEqual(@as(u32, 10), up.positions.items[1].inst);
    try testing.expectEqual(@as(u32, 20), up.positions.items[2].inst);
    try testing.expectEqual(@as(u32, 30), up.positions.items[3].inst);
}

test "UsePositions: sort already sorted" {
    var up = UsePositions.init(testing.allocator, VReg.new(7));
    defer up.deinit();

    try up.addUse(10);
    try up.addUse(20);
    try up.addUse(30);

    up.sort();

    try testing.expectEqual(@as(u32, 10), up.positions.items[0].inst);
    try testing.expectEqual(@as(u32, 20), up.positions.items[1].inst);
    try testing.expectEqual(@as(u32, 30), up.positions.items[2].inst);
}

test "UsePositions: sort empty" {
    var up = UsePositions.init(testing.allocator, VReg.new(7));
    defer up.deinit();

    up.sort();

    try testing.expectEqual(@as(usize, 0), up.positions.items.len);
}

test "UsePositions: nextUseAfter basic" {
    var up = UsePositions.init(testing.allocator, VReg.new(7));
    defer up.deinit();

    try up.addDef(5);
    try up.addUse(10);
    try up.addUse(20);
    try up.addDef(25);

    const next = up.nextUseAfter(12);
    try testing.expect(next != null);
    try testing.expectEqual(@as(u32, 20), next.?.inst);
    try testing.expectEqual(UsePosition.Kind.use, next.?.kind);
}

test "UsePositions: nextUseAfter exact match" {
    var up = UsePositions.init(testing.allocator, VReg.new(7));
    defer up.deinit();

    try up.addUse(10);
    try up.addUse(20);

    const next = up.nextUseAfter(10);
    try testing.expect(next != null);
    try testing.expectEqual(@as(u32, 20), next.?.inst);
}

test "UsePositions: nextUseAfter no next use" {
    var up = UsePositions.init(testing.allocator, VReg.new(7));
    defer up.deinit();

    try up.addUse(10);
    try up.addUse(20);

    const none = up.nextUseAfter(25);
    try testing.expect(none == null);
}

test "UsePositions: nextUseAfter only defs" {
    var up = UsePositions.init(testing.allocator, VReg.new(7));
    defer up.deinit();

    try up.addDef(10);
    try up.addDef(20);
    try up.addDef(30);

    const none = up.nextUseAfter(5);
    try testing.expect(none == null);
}

test "UsePositions: nextUseAfter use_def counts as use" {
    var up = UsePositions.init(testing.allocator, VReg.new(7));
    defer up.deinit();

    try up.addDef(10);
    try up.addUseDef(20);
    try up.addDef(30);

    const next = up.nextUseAfter(15);
    try testing.expect(next != null);
    try testing.expectEqual(@as(u32, 20), next.?.inst);
    try testing.expectEqual(UsePosition.Kind.use_def, next.?.kind);
}

test "UsePositions: nextUseAfter empty" {
    var up = UsePositions.init(testing.allocator, VReg.new(7));
    defer up.deinit();

    const none = up.nextUseAfter(0);
    try testing.expect(none == null);
}

test "UsePositions: nextUseAfter first is use" {
    var up = UsePositions.init(testing.allocator, VReg.new(7));
    defer up.deinit();

    try up.addUse(10);
    try up.addUse(20);

    const next = up.nextUseAfter(5);
    try testing.expect(next != null);
    try testing.expectEqual(@as(u32, 10), next.?.inst);
}
