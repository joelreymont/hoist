const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const Function = root.function.Function;
const StackSlot = root.entities.StackSlot;
const StackSlotData = root.ir.stack_slot_data.StackSlotData;
const StackSlotKind = root.ir.stack_slot_data.StackSlotKind;

/// Allocate a new stack slot.
pub fn createStackSlot(
    func: *Function,
    kind: StackSlotKind,
    size: u32,
    align_shift: u8,
) !StackSlot {
    const data = StackSlotData.init(kind, size, align_shift);
    const slot = StackSlot.new(func.stack_slots.elems.items.len);
    try func.stack_slots.set(func.allocator, slot, data);
    return slot;
}

/// Get stack slot data.
pub fn getStackSlot(func: *const Function, slot: StackSlot) ?StackSlotData {
    return func.stack_slots.get(slot);
}

/// Calculate total stack frame size.
pub fn calculateFrameSize(func: *const Function) u32 {
    var total: u32 = 0;
    for (func.stack_slots.elems.items) |slot_data| {
        const aligned = alignUp(total, slot_data.alignment());
        total = aligned + slot_data.size;
    }
    return total;
}

fn alignUp(value: u32, alignment: u32) u32 {
    const mask = alignment - 1;
    return (value + mask) & ~mask;
}

test "createStackSlot" {
    const sig = try @import("signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const slot = try createStackSlot(&func, .explicit_slot, 64, 3);
    const data = getStackSlot(&func, slot).?;

    try testing.expectEqual(StackSlotKind.explicit_slot, data.kind);
    try testing.expectEqual(@as(u32, 64), data.size);
    try testing.expectEqual(@as(u8, 3), data.align_shift);
}

test "calculateFrameSize" {
    const sig = try @import("signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    _ = try createStackSlot(&func, .explicit_slot, 16, 2); // 16 bytes, 4-byte aligned
    _ = try createStackSlot(&func, .explicit_slot, 8, 3); // 8 bytes, 8-byte aligned

    const frame_size = calculateFrameSize(&func);
    // First slot: 0..16 (aligned to 4)
    // Second slot: 16..24 (aligned to 8) -> 24..32
    try testing.expect(frame_size >= 24);
}

test "alignUp" {
    try testing.expectEqual(@as(u32, 0), alignUp(0, 4));
    try testing.expectEqual(@as(u32, 4), alignUp(1, 4));
    try testing.expectEqual(@as(u32, 4), alignUp(4, 4));
    try testing.expectEqual(@as(u32, 8), alignUp(5, 4));
    try testing.expectEqual(@as(u32, 8), alignUp(0, 8));
    try testing.expectEqual(@as(u32, 8), alignUp(1, 8));
    try testing.expectEqual(@as(u32, 16), alignUp(9, 8));
}

test "Stack slots with various sizes and alignments" {
    const sig = try @import("signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test_various_sizes", sig);
    defer func.deinit();

    // Test 1-byte slot (minimum)
    const slot1 = try createStackSlot(&func, .explicit_slot, 1, 0); // 1 byte, 1-byte aligned
    const data1 = getStackSlot(&func, slot1).?;
    try testing.expectEqual(@as(u32, 1), data1.size);
    try testing.expectEqual(@as(u32, 1), data1.alignment());

    // Test 8-byte slot (common for i64/f64)
    const slot2 = try createStackSlot(&func, .explicit_slot, 8, 3); // 8 bytes, 8-byte aligned
    const data2 = getStackSlot(&func, slot2).?;
    try testing.expectEqual(@as(u32, 8), data2.size);
    try testing.expectEqual(@as(u32, 8), data2.alignment());

    // Test 16-byte slot (SIMD/vector)
    const slot3 = try createStackSlot(&func, .explicit_slot, 16, 4); // 16 bytes, 16-byte aligned
    const data3 = getStackSlot(&func, slot3).?;
    try testing.expectEqual(@as(u32, 16), data3.size);
    try testing.expectEqual(@as(u32, 16), data3.alignment());

    // Test large slot (1KB)
    const slot4 = try createStackSlot(&func, .explicit_slot, 1024, 3); // 1KB, 8-byte aligned
    const data4 = getStackSlot(&func, slot4).?;
    try testing.expectEqual(@as(u32, 1024), data4.size);
    try testing.expectEqual(@as(u32, 8), data4.alignment());

    // Calculate frame size - should account for all slots with proper alignment
    const frame_size = calculateFrameSize(&func);
    try testing.expect(frame_size >= 1024 + 16 + 8 + 1);
}

test "Stack slot frame size with alignment padding" {
    const sig = try @import("signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test_alignment_padding", sig);
    defer func.deinit();

    // Create slots that require alignment padding
    _ = try createStackSlot(&func, .explicit_slot, 1, 0); // 1 byte, 1-byte aligned
    _ = try createStackSlot(&func, .explicit_slot, 8, 3); // 8 bytes, 8-byte aligned (needs padding)
    _ = try createStackSlot(&func, .explicit_slot, 1, 0); // 1 byte, 1-byte aligned
    _ = try createStackSlot(&func, .explicit_slot, 16, 4); // 16 bytes, 16-byte aligned (needs padding)

    const frame_size = calculateFrameSize(&func);
    
    // Frame layout should be:
    // 0-1: first 1-byte slot
    // 1-8: padding for alignment
    // 8-16: 8-byte slot
    // 16-17: second 1-byte slot
    // 17-32: padding for alignment
    // 32-48: 16-byte slot
    // Total: 48 bytes minimum
    try testing.expect(frame_size >= 48);
}

test "Multiple stack slots of same size" {
    const sig = try @import("signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test_same_size", sig);
    defer func.deinit();

    // Create 10 slots of 8 bytes each
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        _ = try createStackSlot(&func, .explicit_slot, 8, 3);
    }

    const frame_size = calculateFrameSize(&func);
    try testing.expectEqual(@as(u32, 80), frame_size); // 10 * 8 = 80 bytes
}

test "Dynamic stack slot" {
    const sig = try @import("signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test_dynamic", sig);
    defer func.deinit();

    const slot = try createStackSlot(&func, .explicit_dynamic_slot, 128, 4);
    const data = getStackSlot(&func, slot).?;
    
    try testing.expectEqual(StackSlotKind.explicit_dynamic_slot, data.kind);
    try testing.expectEqual(@as(u32, 128), data.size);
    try testing.expectEqual(@as(u32, 16), data.alignment());
}
