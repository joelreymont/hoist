//! Frame layout unit tests using MockABI.
//!
//! Tests frame size calculation, alignment, and frame pointer requirements
//! without requiring the full compilation pipeline.

const std = @import("std");
const testing = std.testing;
const MockABICallee = @import("mock_abi.zig").MockABICallee;

test "frame layout: empty frame has zero size" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // No locals, no callee-saves -> just FP+LR = 16 bytes
    try testing.expectEqual(@as(u32, 16), mock.frame_size);
}

test "frame layout: locals with alignment" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 10 bytes locals -> FP+LR (16) + 10 = 26 -> align to 32
    mock.setLocalsSize(10);
    try testing.expectEqual(@as(u32, 32), mock.frame_size);

    // 100 bytes locals -> FP+LR (16) + 100 = 116 -> align to 128
    mock.setLocalsSize(100);
    try testing.expectEqual(@as(u32, 128), mock.frame_size);

    // 256 bytes locals (already aligned) -> FP+LR (16) + 256 = 272 -> align to 272
    mock.setLocalsSize(256);
    try testing.expectEqual(@as(u32, 272), mock.frame_size);
}

test "frame layout: callee-saves increase frame size" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 2 callee-saves = 1 pair (STP) = 16 bytes
    // FP+LR (16) + 1 pair (16) = 32
    mock.setNumCalleeSaves(2);
    try testing.expectEqual(@as(u32, 32), mock.frame_size);

    // 3 callee-saves = 2 pairs (odd count rounds up) = 32 bytes
    // FP+LR (16) + 2 pairs (32) = 48
    mock.setNumCalleeSaves(3);
    try testing.expectEqual(@as(u32, 48), mock.frame_size);

    // 6 callee-saves = 3 pairs = 48 bytes
    // FP+LR (16) + 3 pairs (48) = 64
    mock.setNumCalleeSaves(6);
    try testing.expectEqual(@as(u32, 64), mock.frame_size);
}

test "frame layout: callee-saves + locals combined" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 4 callee-saves = 2 pairs = 32 bytes
    // 100 bytes locals
    // FP+LR (16) + 2 pairs (32) + locals (100) = 148 -> align to 160
    mock.setNumCalleeSaves(4);
    mock.setLocalsSize(100);
    try testing.expectEqual(@as(u32, 160), mock.frame_size);
}

test "frame layout: large frame forces frame pointer" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // Small frame doesn't need FP
    mock.setLocalsSize(1000);
    try testing.expect(!mock.uses_frame_pointer);

    // Large frame (>4KB) requires FP
    mock.setLocalsSize(5000);
    try testing.expect(mock.uses_frame_pointer);

    // Exactly 4KB boundary
    mock.setLocalsSize(4096);
    try testing.expect(!mock.uses_frame_pointer);

    // Just over 4KB
    mock.setLocalsSize(4097);
    try testing.expect(mock.uses_frame_pointer);
}

test "frame layout: dynamic allocations force frame pointer" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    try testing.expect(!mock.uses_frame_pointer);
    try testing.expect(!mock.has_dynamic_alloc);

    mock.enableDynamicAlloc();

    try testing.expect(mock.uses_frame_pointer);
    try testing.expect(mock.has_dynamic_alloc);
}

test "frame layout: 16-byte alignment is enforced" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // Test various unaligned sizes
    const test_cases = [_]struct { locals: u32, expected: u32 }{
        .{ .locals = 1, .expected = 32 }, // 16 + 1 = 17 -> 32
        .{ .locals = 10, .expected = 32 }, // 16 + 10 = 26 -> 32
        .{ .locals = 17, .expected = 48 }, // 16 + 17 = 33 -> 48
        .{ .locals = 31, .expected = 48 }, // 16 + 31 = 47 -> 48
        .{ .locals = 32, .expected = 48 }, // 16 + 32 = 48 (aligned)
        .{ .locals = 48, .expected = 64 }, // 16 + 48 = 64 (aligned)
        .{ .locals = 100, .expected = 128 }, // 16 + 100 = 116 -> 128
    };

    for (test_cases) |tc| {
        mock.setLocalsSize(tc.locals);
        try testing.expectEqual(tc.expected, mock.frame_size);
        // Verify alignment
        try testing.expectEqual(@as(u32, 0), mock.frame_size % 16);
    }
}

test "frame layout: locals offset calculation" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // No callee-saves: locals start after FP+LR (16)
    try testing.expectEqual(@as(u32, 16), mock.getLocalsOffset());

    // 2 callee-saves (1 pair = 16): locals at 16 + 16 = 32
    mock.setNumCalleeSaves(2);
    try testing.expectEqual(@as(u32, 32), mock.getLocalsOffset());

    // 4 callee-saves (2 pairs = 32): locals at 16 + 32 = 48
    mock.setNumCalleeSaves(4);
    try testing.expectEqual(@as(u32, 48), mock.getLocalsOffset());

    // 5 callee-saves (3 pairs = 48, odd rounds up): locals at 16 + 48 = 64
    mock.setNumCalleeSaves(5);
    try testing.expectEqual(@as(u32, 64), mock.getLocalsOffset());
}
