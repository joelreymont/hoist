const std = @import("std");
const testing = std.testing;

/// Kind of stack slot.
pub const StackSlotKind = enum {
    /// Explicit stack slot for stack_load/stack_store instructions.
    explicit_slot,
    /// Explicit stack slot for dynamic vector types.
    explicit_dynamic_slot,

    pub fn format(self: StackSlotKind, writer: anytype) !void {
        try writer.writeAll(@tagName(self));
    }
};

/// Stack slot data - describes a stack allocation.
pub const StackSlotData = struct {
    /// Kind of stack slot.
    kind: StackSlotKind,
    /// Size of stack slot in bytes.
    size: u32,
    /// Alignment as log2 shift (e.g., 3 means 8-byte alignment).
    align_shift: u8,

    pub fn init(kind: StackSlotKind, size: u32, align_shift: u8) StackSlotData {
        return .{
            .kind = kind,
            .size = size,
            .align_shift = align_shift,
        };
    }

    pub fn alignment(self: StackSlotData) u32 {
        return @as(u32, 1) << @intCast(self.align_shift);
    }

    pub fn format(self: StackSlotData, writer: anytype) !void {
        try writer.print("StackSlot{{ kind={}, size={}, align={} }}", .{
            self.kind,
            self.size,
            self.alignment(),
        });
    }
};

test "StackSlotKind" {
    const kind = StackSlotKind.explicit_slot;
    try testing.expectEqual(StackSlotKind.explicit_slot, kind);
}

test "StackSlotData init" {
    const data = StackSlotData.init(.explicit_slot, 64, 3);
    try testing.expectEqual(StackSlotKind.explicit_slot, data.kind);
    try testing.expectEqual(@as(u32, 64), data.size);
    try testing.expectEqual(@as(u8, 3), data.align_shift);
    try testing.expectEqual(@as(u32, 8), data.alignment());
}

test "StackSlotData alignment" {
    const data1 = StackSlotData.init(.explicit_slot, 16, 0);
    try testing.expectEqual(@as(u32, 1), data1.alignment());

    const data2 = StackSlotData.init(.explicit_slot, 32, 2);
    try testing.expectEqual(@as(u32, 4), data2.alignment());

    const data3 = StackSlotData.init(.explicit_slot, 128, 4);
    try testing.expectEqual(@as(u32, 16), data3.alignment());
}
