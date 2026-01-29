const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub const Location = union(enum) {
    reg: u8,
    stack: i64,
};

pub const Move = struct {
    src: Location,
    dst: Location,
    origin: usize,
};

pub const ResolveError = error{
    TempRequired,
    TempConflict,
    DuplicateDestination,
    OutOfMemory,
};

fn locKey(loc: Location) u128 {
    return switch (loc) {
        .reg => |r| (@as(u128, 1) << 64) | r,
        .stack => |s| (@as(u128, 2) << 64) | @as(u64, @bitCast(s)),
    };
}

fn locEql(a: Location, b: Location) bool {
    return switch (a) {
        .reg => |ra| switch (b) {
            .reg => |rb| ra == rb,
            .stack => false,
        },
        .stack => |sa| switch (b) {
            .reg => false,
            .stack => |sb| sa == sb,
        },
    };
}

pub fn resolve(allocator: Allocator, moves: []const Move, temp: ?Location) ResolveError!std.ArrayList(Move) {
    var result: std.ArrayList(Move) = .{};
    errdefer result.deinit(allocator);

    var pending: std.ArrayList(Move) = .{};
    defer pending.deinit(allocator);

    var dst_set = std.AutoHashMap(u128, void).init(allocator);
    defer dst_set.deinit();

    for (moves) |move| {
        if (locEql(move.src, move.dst)) continue;
        const dst_key = locKey(move.dst);
        if (dst_set.contains(dst_key)) return error.DuplicateDestination;
        try dst_set.put(dst_key, {});
        try pending.append(allocator, move);
    }

    if (pending.items.len == 0) return result;

    if (temp) |tmp| {
        const tkey = locKey(tmp);
        for (pending.items) |move| {
            if (locKey(move.src) == tkey or locKey(move.dst) == tkey) {
                return error.TempConflict;
            }
        }
    }

    while (pending.items.len > 0) {
        var src_set = std.AutoHashMap(u128, void).init(allocator);
        defer src_set.deinit();

        for (pending.items) |move| {
            try src_set.put(locKey(move.src), {});
        }

        var emitted = false;
        var i: usize = 0;
        while (i < pending.items.len) : (i += 1) {
            const move = pending.items[i];
            if (!src_set.contains(locKey(move.dst))) {
                const out = pending.swapRemove(i);
                try result.append(allocator, out);
                emitted = true;
                break;
            }
        }

        if (emitted) continue;

        const tmp = temp orelse return error.TempRequired;
        const cycle_src = pending.items[0].src;
        const cycle_origin = pending.items[0].origin;

        try result.append(allocator, .{ .src = cycle_src, .dst = tmp, .origin = cycle_origin });

        for (pending.items) |*move| {
            if (locEql(move.src, cycle_src)) {
                move.src = tmp;
            }
        }
    }

    return result;
}

test "resolve simple ordering" {
    const allocator = testing.allocator;

    const moves = [_]Move{
        .{ .src = .{ .reg = 1 }, .dst = .{ .reg = 1 }, .origin = 0 },
        .{ .src = .{ .reg = 1 }, .dst = .{ .reg = 2 }, .origin = 1 },
        .{ .src = .{ .reg = 2 }, .dst = .{ .reg = 3 }, .origin = 2 },
    };

    var result = try resolve(allocator, &moves, null);
    defer result.deinit(allocator);

    try testing.expectEqual(@as(usize, 2), result.items.len);
    try testing.expectEqual(@as(u8, 2), result.items[0].src.reg);
    try testing.expectEqual(@as(u8, 3), result.items[0].dst.reg);
    try testing.expectEqual(@as(u8, 1), result.items[1].src.reg);
    try testing.expectEqual(@as(u8, 2), result.items[1].dst.reg);
}

test "resolve cycle with temp" {
    const allocator = testing.allocator;

    const moves = [_]Move{
        .{ .src = .{ .reg = 1 }, .dst = .{ .reg = 2 }, .origin = 0 },
        .{ .src = .{ .reg = 2 }, .dst = .{ .reg = 1 }, .origin = 1 },
    };

    var result = try resolve(allocator, &moves, .{ .reg = 3 });
    defer result.deinit(allocator);

    try testing.expectEqual(@as(usize, 3), result.items.len);
    try testing.expectEqual(@as(u8, 1), result.items[0].src.reg);
    try testing.expectEqual(@as(u8, 3), result.items[0].dst.reg);
    try testing.expectEqual(@as(u8, 2), result.items[1].src.reg);
    try testing.expectEqual(@as(u8, 1), result.items[1].dst.reg);
    try testing.expectEqual(@as(u8, 3), result.items[2].src.reg);
    try testing.expectEqual(@as(u8, 2), result.items[2].dst.reg);
}

test "resolve temp conflict" {
    const allocator = testing.allocator;

    const moves = [_]Move{
        .{ .src = .{ .reg = 1 }, .dst = .{ .reg = 2 }, .origin = 0 },
    };

    try testing.expectError(error.TempConflict, resolve(allocator, &moves, .{ .reg = 1 }));
}

test "resolve temp required" {
    const allocator = testing.allocator;

    const moves = [_]Move{
        .{ .src = .{ .reg = 1 }, .dst = .{ .reg = 2 }, .origin = 0 },
        .{ .src = .{ .reg = 2 }, .dst = .{ .reg = 1 }, .origin = 1 },
    };

    try testing.expectError(error.TempRequired, resolve(allocator, &moves, null));
}

test "resolve duplicate destination" {
    const allocator = testing.allocator;

    const moves = [_]Move{
        .{ .src = .{ .reg = 1 }, .dst = .{ .reg = 3 }, .origin = 0 },
        .{ .src = .{ .reg = 2 }, .dst = .{ .reg = 3 }, .origin = 1 },
    };

    try testing.expectError(error.DuplicateDestination, resolve(allocator, &moves, null));
}
