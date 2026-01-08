//! Mapping between register allocator spill slots and IR stack slots.
//!
//! The register allocator works with abstract SpillSlot offsets, while the
//! IR uses explicit StackSlot entities. This module provides the mapping
//! between the two representations.

const std = @import("std");
const Allocator = std.mem.Allocator;

const linear_scan_mod = @import("linear_scan.zig");
const SpillSlot = linear_scan_mod.SpillSlot;

const root = @import("../root.zig");
const Function = root.function.Function;
const StackSlot = root.entities.StackSlot;
const stackslots_mod = @import("../ir/stackslots.zig");
const StackSlotKind = root.ir.stack_slot_data.StackSlotKind;

/// Registry mapping SpillSlot offsets to IR StackSlot entities.
pub const SlotMapping = struct {
    /// Map from spill slot offset to IR stack slot entity.
    /// Key: spill slot offset (in bytes)
    /// Value: IR StackSlot entity
    offset_to_slot: std.AutoHashMap(u32, StackSlot),

    allocator: Allocator,

    pub fn init(allocator: Allocator) SlotMapping {
        return .{
            .offset_to_slot = std.AutoHashMap(u32, StackSlot).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SlotMapping) void {
        self.offset_to_slot.deinit();
    }

    /// Allocate a new IR StackSlot for a register allocator SpillSlot.
    /// Creates the mapping and returns the IR StackSlot entity.
    pub fn allocateStackSlot(
        self: *SlotMapping,
        func: *Function,
        spill_slot: SpillSlot,
        size: u32,
        align_shift: u8,
    ) !StackSlot {
        // Check if we already have a mapping for this offset
        if (self.offset_to_slot.get(spill_slot.offset)) |existing| {
            return existing;
        }

        // Create new IR stack slot for this spill
        const stack_slot = try stackslots_mod.createStackSlot(
            func,
            .explicit_slot,
            size,
            align_shift,
        );

        // Record the mapping
        try self.offset_to_slot.put(spill_slot.offset, stack_slot);

        return stack_slot;
    }

    /// Get the IR StackSlot for a given SpillSlot offset.
    /// Returns null if no mapping exists.
    pub fn getStackSlot(self: *const SlotMapping, spill_slot: SpillSlot) ?StackSlot {
        return self.offset_to_slot.get(spill_slot.offset);
    }

    /// Check if a mapping exists for the given spill slot offset.
    pub fn hasMapping(self: *const SlotMapping, spill_slot: SpillSlot) bool {
        return self.offset_to_slot.contains(spill_slot.offset);
    }

    /// Get the number of mapped slots.
    pub fn count(self: *const SlotMapping) usize {
        return self.offset_to_slot.count();
    }
};

// Tests

const testing = std.testing;
const signature_mod = @import("../ir/signature.zig");

test "SlotMapping init and deinit" {
    var mapping = SlotMapping.init(testing.allocator);
    defer mapping.deinit();

    try testing.expectEqual(@as(usize, 0), mapping.count());
}

test "SlotMapping allocate and lookup" {
    var mapping = SlotMapping.init(testing.allocator);
    defer mapping.deinit();

    const sig = try signature_mod.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    // Create a spill slot at offset 0
    const spill_slot = SpillSlot.init(0);

    // Allocate IR stack slot for it
    const stack_slot = try mapping.allocateStackSlot(&func, spill_slot, 8, 3);

    // Verify mapping was created
    try testing.expectEqual(@as(usize, 1), mapping.count());
    try testing.expect(mapping.hasMapping(spill_slot));

    // Lookup should return the same stack slot
    const retrieved = mapping.getStackSlot(spill_slot);
    try testing.expect(retrieved != null);
    try testing.expectEqual(stack_slot, retrieved.?);
}

test "SlotMapping multiple spill slots" {
    var mapping = SlotMapping.init(testing.allocator);
    defer mapping.deinit();

    const sig = try signature_mod.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    // Create multiple spill slots at different offsets
    const spill1 = SpillSlot.init(0);
    const spill2 = SpillSlot.init(8);
    const spill3 = SpillSlot.init(16);

    // Allocate stack slots for each
    const stack1 = try mapping.allocateStackSlot(&func, spill1, 8, 3);
    const stack2 = try mapping.allocateStackSlot(&func, spill2, 8, 3);
    const stack3 = try mapping.allocateStackSlot(&func, spill3, 8, 3);

    // Verify all mappings exist
    try testing.expectEqual(@as(usize, 3), mapping.count());
    try testing.expect(mapping.hasMapping(spill1));
    try testing.expect(mapping.hasMapping(spill2));
    try testing.expect(mapping.hasMapping(spill3));

    // Verify lookups return correct slots
    try testing.expectEqual(stack1, mapping.getStackSlot(spill1).?);
    try testing.expectEqual(stack2, mapping.getStackSlot(spill2).?);
    try testing.expectEqual(stack3, mapping.getStackSlot(spill3).?);
}

test "SlotMapping duplicate allocation returns same slot" {
    var mapping = SlotMapping.init(testing.allocator);
    defer mapping.deinit();

    const sig = try signature_mod.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const spill_slot = SpillSlot.init(0);

    // Allocate twice for the same spill slot
    const stack1 = try mapping.allocateStackSlot(&func, spill_slot, 8, 3);
    const stack2 = try mapping.allocateStackSlot(&func, spill_slot, 8, 3);

    // Should return the same stack slot
    try testing.expectEqual(stack1, stack2);
    // Should only have one mapping
    try testing.expectEqual(@as(usize, 1), mapping.count());
}

test "SlotMapping nonexistent slot returns null" {
    var mapping = SlotMapping.init(testing.allocator);
    defer mapping.deinit();

    const spill_slot = SpillSlot.init(999);

    // Lookup without allocation should return null
    try testing.expect(mapping.getStackSlot(spill_slot) == null);
    try testing.expect(!mapping.hasMapping(spill_slot));
}
