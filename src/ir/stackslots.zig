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
    const sig = try @import("signature.zig").Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const slot = try createStackSlot(&func, .explicit_slot, 64, 3);
    const data = getStackSlot(&func, slot).?;

    try testing.expectEqual(StackSlotKind.explicit_slot, data.kind);
    try testing.expectEqual(@as(u32, 64), data.size);
    try testing.expectEqual(@as(u8, 3), data.align_shift);
}

test "calculateFrameSize" {
    const sig = try @import("signature.zig").Signature.init(testing.allocator);
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
