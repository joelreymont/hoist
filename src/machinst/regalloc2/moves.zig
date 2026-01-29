const std = @import("std");
const types = @import("types.zig");
const Allocation = types.Allocation;
const PhysReg = types.PhysReg;
const VReg = types.VReg;
const SpillSlot = types.SpillSlot;
const parallel_copy = @import("../parallel_copy.zig");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// A move instruction inserted during register allocation.
pub const Move = struct {
    /// Source allocation (register or stack slot).
    src: Allocation,
    /// Destination allocation (register or stack slot).
    dst: Allocation,
    /// Virtual register being moved.
    vreg: VReg,

    pub fn init(src: Allocation, dst: Allocation, vreg: VReg) Move {
        return .{ .src = src, .dst = dst, .vreg = vreg };
    }
};

/// Move insertion context for parallel copy resolution.
pub const MoveInserter = struct {
    moves: std.ArrayList(Move),
    allocator: Allocator,

    pub fn init(allocator: Allocator) MoveInserter {
        return .{
            .moves = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MoveInserter) void {
        self.moves.deinit(self.allocator);
    }

    /// Add a register-to-register move.
    pub fn addRegMove(self: *MoveInserter, src: PhysReg, dst: PhysReg, vreg: VReg) !void {
        const move = Move.init(
            Allocation{ .reg = src },
            Allocation{ .reg = dst },
            vreg,
        );
        try self.moves.append(self.allocator, move);
    }

    /// Add a spill (register to stack).
    pub fn addSpill(self: *MoveInserter, src: PhysReg, dst: SpillSlot, vreg: VReg) !void {
        const move = Move.init(
            Allocation{ .reg = src },
            Allocation{ .stack = dst },
            vreg,
        );
        try self.moves.append(self.allocator, move);
    }

    /// Add a reload (stack to register).
    pub fn addReload(self: *MoveInserter, src: SpillSlot, dst: PhysReg, vreg: VReg) !void {
        const move = Move.init(
            Allocation{ .stack = src },
            Allocation{ .reg = dst },
            vreg,
        );
        try self.moves.append(self.allocator, move);
    }

    /// Resolve parallel copy by ordering moves to avoid conflicts.
    pub fn resolveParallelCopy(
        allocator: Allocator,
        moves: []const Move,
        temp: ?Allocation,
    ) parallel_copy.ResolveError!std.ArrayList(Move) {
        var pc_moves: std.ArrayList(parallel_copy.Move) = .{};
        defer pc_moves.deinit(allocator);
        try pc_moves.ensureTotalCapacity(allocator, moves.len);

        for (moves, 0..) |move, idx| {
            const src = allocToLoc(move.src);
            const dst = allocToLoc(move.dst);
            pc_moves.appendAssumeCapacity(.{ .src = src, .dst = dst, .origin = idx });
        }

        const pc_temp = if (temp) |t| allocToLoc(t) else null;
        var resolved = try parallel_copy.resolve(allocator, pc_moves.items, pc_temp);
        defer resolved.deinit(allocator);

        var result: std.ArrayList(Move) = .{};
        errdefer result.deinit(allocator);
        try result.ensureTotalCapacity(allocator, resolved.items.len);

        for (resolved.items) |move| {
            const base = moves[move.origin];
            result.appendAssumeCapacity(.{
                .src = locToAlloc(move.src),
                .dst = locToAlloc(move.dst),
                .vreg = base.vreg,
            });
        }

        return result;
    }
};

fn allocToLoc(alloc: Allocation) parallel_copy.Location {
    return switch (alloc) {
        .reg => |r| .{ .reg = r.index },
        .stack => |s| .{ .stack = @intCast(s.index) },
        .none => unreachable,
    };
}

fn locToAlloc(loc: parallel_copy.Location) Allocation {
    return switch (loc) {
        .reg => |r| .{ .reg = PhysReg.new(r) },
        .stack => |s| .{ .stack = SpillSlot.new(@intCast(s)) },
    };
}

test "MoveInserter addRegMove" {
    const allocator = testing.allocator;
    var inserter = MoveInserter.init(allocator);
    defer inserter.deinit();

    const src = PhysReg.new(3);
    const dst = PhysReg.new(5);
    const vreg = VReg.new(42);

    try inserter.addRegMove(src, dst, vreg);

    try testing.expectEqual(@as(usize, 1), inserter.moves.items.len);
    const move = inserter.moves.items[0];
    try testing.expect(move.src.isReg());
    try testing.expect(move.dst.isReg());
    try testing.expectEqual(@as(u8, 3), move.src.reg.index);
    try testing.expectEqual(@as(u8, 5), move.dst.reg.index);
}

test "MoveInserter addSpill" {
    const allocator = testing.allocator;
    var inserter = MoveInserter.init(allocator);
    defer inserter.deinit();

    const src = PhysReg.new(7);
    const dst = SpillSlot.new(2);
    const vreg = VReg.new(99);

    try inserter.addSpill(src, dst, vreg);

    try testing.expectEqual(@as(usize, 1), inserter.moves.items.len);
    const move = inserter.moves.items[0];
    try testing.expect(move.src.isReg());
    try testing.expect(move.dst.isStack());
}

test "MoveInserter addReload" {
    const allocator = testing.allocator;
    var inserter = MoveInserter.init(allocator);
    defer inserter.deinit();

    const src = SpillSlot.new(1);
    const dst = PhysReg.new(4);
    const vreg = VReg.new(55);

    try inserter.addReload(src, dst, vreg);

    try testing.expectEqual(@as(usize, 1), inserter.moves.items.len);
    const move = inserter.moves.items[0];
    try testing.expect(move.src.isStack());
    try testing.expect(move.dst.isReg());
}

test "resolveParallelCopy simple" {
    const allocator = testing.allocator;

    const moves = [_]Move{
        Move.init(
            Allocation{ .reg = PhysReg.new(1) },
            Allocation{ .reg = PhysReg.new(2) },
            VReg.new(10),
        ),
        Move.init(
            Allocation{ .reg = PhysReg.new(3) },
            Allocation{ .reg = PhysReg.new(4) },
            VReg.new(11),
        ),
    };

    var result = try MoveInserter.resolveParallelCopy(allocator, &moves, null);
    defer result.deinit(allocator);

    try testing.expectEqual(@as(usize, 2), result.items.len);
}

test "resolveParallelCopy with dependency" {
    const allocator = testing.allocator;

    // r1 -> r2, r2 -> r3
    const moves = [_]Move{
        Move.init(
            Allocation{ .reg = PhysReg.new(1) },
            Allocation{ .reg = PhysReg.new(2) },
            VReg.new(10),
        ),
        Move.init(
            Allocation{ .reg = PhysReg.new(2) },
            Allocation{ .reg = PhysReg.new(3) },
            VReg.new(11),
        ),
    };

    var result = try MoveInserter.resolveParallelCopy(allocator, &moves, null);
    defer result.deinit(allocator);

    try testing.expectEqual(@as(usize, 2), result.items.len);
    // r2 -> r3 should come first.
    try testing.expectEqual(@as(u8, 2), result.items[0].src.reg.index);
    try testing.expectEqual(@as(u8, 3), result.items[0].dst.reg.index);
}

test "resolveParallelCopy cycle with temp" {
    const allocator = testing.allocator;

    const moves = [_]Move{
        Move.init(
            Allocation{ .reg = PhysReg.new(1) },
            Allocation{ .reg = PhysReg.new(2) },
            VReg.new(10),
        ),
        Move.init(
            Allocation{ .reg = PhysReg.new(2) },
            Allocation{ .reg = PhysReg.new(1) },
            VReg.new(11),
        ),
    };

    var result = try MoveInserter.resolveParallelCopy(allocator, &moves, Allocation{ .reg = PhysReg.new(3) });
    defer result.deinit(allocator);

    try testing.expectEqual(@as(usize, 3), result.items.len);
    try testing.expectEqual(@as(u8, 1), result.items[0].src.reg.index);
    try testing.expectEqual(@as(u8, 3), result.items[0].dst.reg.index);
}
