const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Literal pool entry for constants that don't fit in immediates.
pub const LiteralPoolEntry = struct {
    /// 64-bit constant value.
    value: u64,
    /// Offset in the literal pool.
    offset: u32,
    /// Label for PC-relative addressing.
    label: u32,

    pub fn init(value: u64, offset: u32, label: u32) LiteralPoolEntry {
        return .{
            .value = value,
            .offset = offset,
            .label = label,
        };
    }
};

/// Literal pool for storing large constants.
pub const LiteralPool = struct {
    /// Pool entries.
    entries: std.ArrayList(LiteralPoolEntry),
    /// Map from value to entry index for deduplication.
    value_map: std.AutoHashMap(u64, usize),
    /// Current offset in pool.
    current_offset: u32,
    /// Next label ID.
    next_label: u32,
    allocator: Allocator,

    pub fn init(allocator: Allocator) LiteralPool {
        return .{
            .entries = std.ArrayList(LiteralPoolEntry).init(allocator),
            .value_map = std.AutoHashMap(u64, usize).init(allocator),
            .current_offset = 0,
            .next_label = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LiteralPool) void {
        self.entries.deinit();
        self.value_map.deinit();
    }

    /// Add constant to pool, return label for PC-relative load.
    pub fn addConstant(self: *LiteralPool, value: u64) !u32 {
        // Check if already in pool
        if (self.value_map.get(value)) |idx| {
            return self.entries.items[idx].label;
        }

        // Add new entry
        const label = self.next_label;
        self.next_label += 1;

        const entry = LiteralPoolEntry.init(value, self.current_offset, label);
        try self.entries.append(entry);

        const idx = self.entries.items.len - 1;
        try self.value_map.put(value, idx);

        self.current_offset += 8; // 64-bit values

        return label;
    }

    /// Emit pool contents to buffer.
    pub fn emit(self: *const LiteralPool, buffer: *std.ArrayList(u8)) !void {
        for (self.entries.items) |entry| {
            // Emit 64-bit little-endian value
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &bytes, entry.value, .little);
            try buffer.appendSlice(&bytes);
        }
    }

    /// Get pool size in bytes.
    pub fn size(self: *const LiteralPool) u32 {
        return self.current_offset;
    }

    /// Get entry by label.
    pub fn getEntry(self: *const LiteralPool, label: u32) ?LiteralPoolEntry {
        for (self.entries.items) |entry| {
            if (entry.label == label) {
                return entry;
            }
        }
        return null;
    }
};

test "LiteralPool add and deduplicate" {
    var pool = LiteralPool.init(testing.allocator);
    defer pool.deinit();

    const label1 = try pool.addConstant(0x123456789ABCDEF0);
    const label2 = try pool.addConstant(0xFEDCBA9876543210);
    const label3 = try pool.addConstant(0x123456789ABCDEF0); // Duplicate

    try testing.expectEqual(label1, label3); // Same label for duplicate
    try testing.expect(label1 != label2);
    try testing.expectEqual(@as(usize, 2), pool.entries.items.len);
}

test "LiteralPool emit" {
    var pool = LiteralPool.init(testing.allocator);
    defer pool.deinit();

    _ = try pool.addConstant(0x1122334455667788);
    _ = try pool.addConstant(0xAABBCCDDEEFF0011);

    var buffer = std.ArrayList(u8).init(testing.allocator);
    defer buffer.deinit();

    try pool.emit(&buffer);

    try testing.expectEqual(@as(usize, 16), buffer.items.len); // 2 * 8 bytes

    // Check first value (little-endian)
    const val1 = std.mem.readInt(u64, buffer.items[0..8], .little);
    try testing.expectEqual(@as(u64, 0x1122334455667788), val1);
}

test "LiteralPool size" {
    var pool = LiteralPool.init(testing.allocator);
    defer pool.deinit();

    try testing.expectEqual(@as(u32, 0), pool.size());

    _ = try pool.addConstant(0x1111111111111111);
    try testing.expectEqual(@as(u32, 8), pool.size());

    _ = try pool.addConstant(0x2222222222222222);
    try testing.expectEqual(@as(u32, 16), pool.size());
}

test "LiteralPool getEntry" {
    var pool = LiteralPool.init(testing.allocator);
    defer pool.deinit();

    const label = try pool.addConstant(0xDEADBEEF12345678);
    const entry = pool.getEntry(label).?;

    try testing.expectEqual(@as(u64, 0xDEADBEEF12345678), entry.value);
    try testing.expectEqual(@as(u32, 0), entry.offset);
    try testing.expectEqual(label, entry.label);
}
