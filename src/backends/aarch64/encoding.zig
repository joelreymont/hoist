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
            .entries = .{},
            .value_map = std.AutoHashMap(u64, usize).init(allocator),
            .current_offset = 0,
            .next_label = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LiteralPool) void {
        self.entries.deinit(self.allocator);
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
        try self.entries.append(self.allocator, entry);

        const idx = self.entries.items.len - 1;
        try self.value_map.put(value, idx);

        self.current_offset += 8; // 64-bit values

        return label;
    }

    /// Emit pool contents to buffer.
    pub fn emit(self: *const LiteralPool, buffer: *std.ArrayList(u8), allocator: Allocator) !void {
        for (self.entries.items) |entry| {
            // Emit 64-bit little-endian value
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &bytes, entry.value, .little);
            try buffer.appendSlice(allocator, &bytes);
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

    var buffer: std.ArrayList(u8) = .{};
    defer buffer.deinit(testing.allocator);

    try pool.emit(&buffer, testing.allocator);

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

/// Encode logical immediate (bitmask) for AND/ORR/EOR instructions.
/// Returns null if value cannot be encoded as logical immediate.
pub fn encodeLogicalImmediate(value: u64, is_64bit: bool) ?u13 {
    if (value == 0 or (is_64bit and value == std.math.maxInt(u64)) or (!is_64bit and value == std.math.maxInt(u32))) {
        return null; // All zeros or all ones cannot be encoded
    }

    const size: u7 = if (is_64bit) 64 else 32;
    var element_size: u7 = size;

    // Find smallest repeating element size
    while (element_size > 2) : (element_size /= 2) {
        // For element_size=64, we need all bits, so use special handling
        const mask: u64 = if (element_size == 64)
            std.math.maxInt(u64)
        else
            (@as(u64, 1) << @as(u6, @intCast(element_size))) - 1;

        const element = value & mask;

        var matches = true;
        var i: u7 = element_size;
        while (i < size) : (i += element_size) {
            const shifted_mask: u64 = if (i >= 64)
                0
            else if (element_size == 64)
                mask
            else
                mask << @as(u6, @intCast(i));

            const shifted_element: u64 = if (i >= 64)
                0
            else if (element_size == 64)
                element
            else
                element << @as(u6, @intCast(i));

            if ((value & shifted_mask) != shifted_element) {
                matches = false;
                break;
            }
        }

        if (matches) break;
    }

    const element: u64 = if (element_size == 64)
        value
    else
        value & ((@as(u64, 1) << @as(u6, @intCast(element_size))) - 1);

    // Count ones in element
    const ones = @popCount(element);
    if (ones == 0) return null;

    // Check if element is contiguous ones (possibly rotated)
    var rotation: u7 = 0;
    while (rotation < element_size) : (rotation += 1) {
        const rotated = std.math.rotr(u64, element, rotation) & ((@as(u64, 1) << element_shift) - 1);
        const ones_shift: u6 = @truncate(ones);
        const expected = (@as(u64, 1) << ones_shift) - 1;
        if (rotated == expected) break;
    } else {
        return null; // Not encodable
    }

    // Encode N:immr:imms
    // N = 1 for 64-bit, 0 for smaller elements
    const n: u1 = if (element_size == 64) 1 else 0;

    // immr = (element_size - rotation) mod element_size
    const immr: u6 = @intCast((element_size - rotation) % element_size);

    // imms encodes both element size and number of ones
    // Pattern: NOT(size_bits) : (ones - 1)
    // For element_size=16: imms = 0b110xxx (high 3 bits encode size via leading 1s)
    // For element_size=8:  imms = 0b1110xx (4 leading 1s when inverted gives size)
    const size_encoding: u6 = switch (element_size) {
        64 => @intCast(ones - 1),
        32 => @intCast((0b100000) | (ones - 1)),
        16 => @intCast((0b110000) | (ones - 1)),
        8 => @intCast((0b111000) | (ones - 1)),
        4 => @intCast((0b111100) | (ones - 1)),
        2 => @intCast((0b111110) | (ones - 1)),
        else => return null,
    };
    const imms: u6 = size_encoding;

    return (@as(u13, n) << 12) | (@as(u13, immr) << 6) | @as(u13, imms);
}

/// Encode arithmetic immediate (12-bit value, optionally shifted by 12).
/// Returns null if value cannot be encoded.
pub fn encodeArithmeticImmediate(value: u64) ?struct { imm12: u12, shift: u1 } {
    // Try without shift
    if (value <= 0xFFF) {
        return .{ .imm12 = @intCast(value), .shift = 0 };
    }

    // Try with shift (value must be multiple of 4096)
    if (value <= 0xFFF000 and value & 0xFFF == 0) {
        return .{ .imm12 = @intCast(value >> 12), .shift = 1 };
    }

    return null;
}

/// Encode shifted immediate (16-bit value with optional shift).
/// Returns null if value cannot be encoded.
pub fn encodeShiftedImmediate(value: u64) ?struct { imm16: u16, hw: u2 } {
    // Try each 16-bit position
    var hw: u32 = 0;
    while (hw < 4) : (hw += 1) {
        const shift = hw * 16;
        const mask = @as(u64, 0xFFFF) << @intCast(shift);

        if ((value & ~mask) == 0) {
            return .{
                .imm16 = @intCast((value >> @intCast(shift)) & 0xFFFF),
                .hw = @intCast(hw),
            };
        }
    }

    return null;
}

/// Encode floating-point immediate (8-bit encoding for common FP values).
/// Returns null if value cannot be encoded.
pub fn encodeFloatImmediate(value: f64) ?u8 {
    const bits = @as(u64, @bitCast(value));

    // Extract sign, exponent, fraction
    const sign = (bits >> 63) & 1;
    const exp = (bits >> 52) & 0x7FF;
    const frac = bits & 0xFFFFFFFFFFFFF;

    // Check if encodable: aBbbbbbb_bcdefgh0_00000000_00000000_00000000_00000000_00000000_00000000
    // where B is NOT(b)

    // Fraction must have exactly 4 significant bits (bits 51-48) and rest zeros
    if (frac & 0xFFFFFFFFFFFF != (frac & 0xF000000000000)) {
        return null;
    }

    const frac_bits = @as(u8, @intCast((frac >> 48) & 0xF));

    // Exponent must be 10XX XXXX (between 0x380 and 0x47F)
    const exp_bits = @as(u11, @intCast(exp));
    if ((exp_bits & 0x600) != 0x200 or (exp_bits & 0x180) == 0x180) {
        return null;
    }

    const exp_encoded = @as(u8, @intCast((exp >> 6) & 0x7));

    return (@as(u8, @intCast(sign)) << 7) | (exp_encoded << 4) | frac_bits;
}

test "encodeLogicalImmediate: simple patterns" {
    // 0x00FF00FF00FF00FF (alternating bytes)
    const enc1 = encodeLogicalImmediate(0x00FF00FF00FF00FF, true);
    try testing.expect(enc1 != null);

    // 0xAAAAAAAAAAAAAAAA (alternating bits)
    const enc2 = encodeLogicalImmediate(0xAAAAAAAAAAAAAAAA, true);
    try testing.expect(enc2 != null);
}

test "encodeLogicalImmediate: invalid values" {
    // All zeros
    try testing.expectEqual(@as(?u13, null), encodeLogicalImmediate(0, true));

    // All ones (64-bit)
    try testing.expectEqual(@as(?u13, null), encodeLogicalImmediate(std.math.maxInt(u64), true));

    // All ones (32-bit)
    try testing.expectEqual(@as(?u13, null), encodeLogicalImmediate(std.math.maxInt(u32), false));
}

test "encodeArithmeticImmediate: without shift" {
    const enc = encodeArithmeticImmediate(42);
    try testing.expect(enc != null);
    try testing.expectEqual(@as(u12, 42), enc.?.imm12);
    try testing.expectEqual(@as(u1, 0), enc.?.shift);
}

test "encodeArithmeticImmediate: with shift" {
    const enc = encodeArithmeticImmediate(0x123000);
    try testing.expect(enc != null);
    try testing.expectEqual(@as(u12, 0x123), enc.?.imm12);
    try testing.expectEqual(@as(u1, 1), enc.?.shift);
}

test "encodeArithmeticImmediate: invalid" {
    // Too large
    try testing.expectEqual(@as(@TypeOf(encodeArithmeticImmediate(0)), null), encodeArithmeticImmediate(0x1000000));

    // Not aligned for shift
    try testing.expectEqual(@as(@TypeOf(encodeArithmeticImmediate(0)), null), encodeArithmeticImmediate(0x123001));
}

test "encodeShiftedImmediate: hw=0" {
    const enc = encodeShiftedImmediate(0x1234);
    try testing.expect(enc != null);
    try testing.expectEqual(@as(u16, 0x1234), enc.?.imm16);
    try testing.expectEqual(@as(u2, 0), enc.?.hw);
}

test "encodeShiftedImmediate: hw=1" {
    const enc = encodeShiftedImmediate(0x56780000);
    try testing.expect(enc != null);
    try testing.expectEqual(@as(u16, 0x5678), enc.?.imm16);
    try testing.expectEqual(@as(u2, 1), enc.?.hw);
}

test "encodeShiftedImmediate: invalid" {
    // Value spans multiple 16-bit fields
    try testing.expectEqual(@as(@TypeOf(encodeShiftedImmediate(0)), null), encodeShiftedImmediate(0x12345678));
}

test "encodeFloatImmediate: 2.0" {
    const enc = encodeFloatImmediate(2.0);
    try testing.expect(enc != null);
}

test "encodeFloatImmediate: -0.5" {
    const enc = encodeFloatImmediate(-0.5);
    try testing.expect(enc != null);
}

test "encodeFloatImmediate: invalid" {
    // Value with too many fraction bits
    try testing.expectEqual(@as(?u8, null), encodeFloatImmediate(1.23456789));
}
