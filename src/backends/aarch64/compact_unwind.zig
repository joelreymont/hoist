//! Compact Unwind Info for macOS arm64
//!
//! Generates the __unwind_info section format used by macOS for
//! efficient stack unwinding. This is a compact alternative to
//! DWARF .eh_frame that provides faster unwinding for common cases.
//!
//! See: https://developer.apple.com/documentation/xcode/writing-arm64-code-for-apple-platforms
//! Apple Compact Unwind encoding for arm64

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Compact unwind encoding bits for arm64.
/// See mach-o/compact_unwind_encoding.h
pub const Encoding = struct {
    /// Mode bits in the high nibble.
    pub const MODE_MASK: u32 = 0x0F000000;

    /// Frame-based encoding (using x29/fp).
    pub const MODE_FRAME: u32 = 0x04000000;

    /// Frameless encoding (leaf or uses sp directly).
    pub const MODE_FRAMELESS: u32 = 0x02000000;

    /// DWARF encoding (fallback to .eh_frame).
    pub const MODE_DWARF: u32 = 0x03000000;

    /// Stack size in bytes (for frameless).
    /// Stored as (stack_size / 16) in bits 16-23.
    pub const FRAMELESS_STACK_SIZE_MASK: u32 = 0x00FFF000;
    pub const FRAMELESS_STACK_SIZE_SHIFT: u5 = 12;

    /// Saved registers for frame-based mode.
    /// Bits 0-14 indicate which callee-saved regs are saved.
    pub const FRAME_SAVED_REGS_MASK: u32 = 0x00007FFF;

    /// Register pairs saved (for frame mode).
    /// x19-x28 pairs encoded in bits 0-9.
    pub const FRAME_X19_X20: u32 = 1 << 0;
    pub const FRAME_X21_X22: u32 = 1 << 1;
    pub const FRAME_X23_X24: u32 = 1 << 2;
    pub const FRAME_X25_X26: u32 = 1 << 3;
    pub const FRAME_X27_X28: u32 = 1 << 4;

    /// FP/SIMD register pairs saved (d8-d15).
    pub const FRAME_D8_D9: u32 = 1 << 5;
    pub const FRAME_D10_D11: u32 = 1 << 6;
    pub const FRAME_D12_D13: u32 = 1 << 7;
    pub const FRAME_D14_D15: u32 = 1 << 8;
};

/// Unwind info for a single function.
pub const FunctionUnwind = struct {
    /// Function start offset (relative to section).
    start_offset: u32,
    /// Length of function in bytes.
    length: u32,
    /// Compact encoding.
    encoding: u32,
    /// Personality function index (0 = no personality).
    personality_idx: u8,
    /// LSDA offset (0 = no LSDA).
    lsda_offset: u32,
};

/// Builder for compact unwind info.
pub const CompactUnwindBuilder = struct {
    allocator: Allocator,
    /// Functions to generate unwind for.
    functions: std.ArrayList(FunctionUnwind),
    /// Personality functions (indexed by personality_idx - 1).
    personalities: std.ArrayList(u32),

    pub fn init(allocator: Allocator) CompactUnwindBuilder {
        return .{
            .allocator = allocator,
            .functions = std.ArrayList(FunctionUnwind).init(allocator),
            .personalities = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *CompactUnwindBuilder) void {
        self.functions.deinit();
        self.personalities.deinit();
    }

    /// Add a function with frame pointer.
    pub fn addFrameFunction(
        self: *CompactUnwindBuilder,
        start: u32,
        length: u32,
        saved_regs: SavedRegs,
    ) !void {
        var enc = Encoding.MODE_FRAME;
        enc |= saved_regs.encode();

        try self.functions.append(.{
            .start_offset = start,
            .length = length,
            .encoding = enc,
            .personality_idx = 0,
            .lsda_offset = 0,
        });
    }

    /// Add a frameless function.
    pub fn addFramelessFunction(
        self: *CompactUnwindBuilder,
        start: u32,
        length: u32,
        stack_size: u32,
    ) !void {
        // Stack size must be 16-byte aligned
        const aligned_size = (stack_size + 15) & ~@as(u32, 15);
        const encoded_size = @min(aligned_size / 16, 0xFFF);

        var enc = Encoding.MODE_FRAMELESS;
        enc |= encoded_size << Encoding.FRAMELESS_STACK_SIZE_SHIFT;

        try self.functions.append(.{
            .start_offset = start,
            .length = length,
            .encoding = enc,
            .personality_idx = 0,
            .lsda_offset = 0,
        });
    }

    /// Add a function that needs DWARF for unwinding.
    pub fn addDwarfFunction(
        self: *CompactUnwindBuilder,
        start: u32,
        length: u32,
        eh_frame_offset: u32,
    ) !void {
        try self.functions.append(.{
            .start_offset = start,
            .length = length,
            .encoding = Encoding.MODE_DWARF | eh_frame_offset,
            .personality_idx = 0,
            .lsda_offset = 0,
        });
    }

    /// Build the __unwind_info section data.
    pub fn build(self: *CompactUnwindBuilder, out: *std.ArrayList(u8)) !void {
        const writer = out.writer();

        // Sort functions by start address
        std.mem.sort(FunctionUnwind, self.functions.items, {}, struct {
            fn lessThan(_: void, a: FunctionUnwind, b: FunctionUnwind) bool {
                return a.start_offset < b.start_offset;
            }
        }.lessThan);

        // Write header
        try writer.writeInt(u32, 1, .little); // version
        try writer.writeInt(u32, 0, .little); // common encodings offset (not used)
        try writer.writeInt(u32, 0, .little); // common encodings count
        try writer.writeInt(u32, 0, .little); // personality array offset
        try writer.writeInt(u32, @intCast(self.personalities.items.len), .little);
        try writer.writeInt(u32, 28, .little); // first level index offset (after header)
        try writer.writeInt(u32, @intCast(self.functions.items.len), .little); // first level index count

        // Write first-level index entries (one per function for simplicity)
        // In practice, macOS groups these into pages
        for (self.functions.items) |func| {
            try writer.writeInt(u32, func.start_offset, .little); // function offset
            try writer.writeInt(u32, @intCast(out.items.len + 8), .little); // second level offset
            try writer.writeInt(u32, func.lsda_offset, .little); // LSDA offset
        }

        // Write second-level entries (regular format, not compressed)
        for (self.functions.items) |func| {
            try writer.writeInt(u32, func.start_offset, .little);
            try writer.writeInt(u32, func.encoding, .little);
        }
    }

    /// Get total number of functions.
    pub fn count(self: *const CompactUnwindBuilder) usize {
        return self.functions.items.len;
    }
};

/// Saved register set for frame-based encoding.
pub const SavedRegs = struct {
    x19_x20: bool = false,
    x21_x22: bool = false,
    x23_x24: bool = false,
    x25_x26: bool = false,
    x27_x28: bool = false,
    d8_d9: bool = false,
    d10_d11: bool = false,
    d12_d13: bool = false,
    d14_d15: bool = false,

    /// Encode saved registers into compact unwind bits.
    pub fn encode(self: SavedRegs) u32 {
        var bits: u32 = 0;
        if (self.x19_x20) bits |= Encoding.FRAME_X19_X20;
        if (self.x21_x22) bits |= Encoding.FRAME_X21_X22;
        if (self.x23_x24) bits |= Encoding.FRAME_X23_X24;
        if (self.x25_x26) bits |= Encoding.FRAME_X25_X26;
        if (self.x27_x28) bits |= Encoding.FRAME_X27_X28;
        if (self.d8_d9) bits |= Encoding.FRAME_D8_D9;
        if (self.d10_d11) bits |= Encoding.FRAME_D10_D11;
        if (self.d12_d13) bits |= Encoding.FRAME_D12_D13;
        if (self.d14_d15) bits |= Encoding.FRAME_D14_D15;
        return bits;
    }

    /// Decode saved registers from compact unwind bits.
    pub fn decode(bits: u32) SavedRegs {
        return .{
            .x19_x20 = (bits & Encoding.FRAME_X19_X20) != 0,
            .x21_x22 = (bits & Encoding.FRAME_X21_X22) != 0,
            .x23_x24 = (bits & Encoding.FRAME_X23_X24) != 0,
            .x25_x26 = (bits & Encoding.FRAME_X25_X26) != 0,
            .x27_x28 = (bits & Encoding.FRAME_X27_X28) != 0,
            .d8_d9 = (bits & Encoding.FRAME_D8_D9) != 0,
            .d10_d11 = (bits & Encoding.FRAME_D10_D11) != 0,
            .d12_d13 = (bits & Encoding.FRAME_D12_D13) != 0,
            .d14_d15 = (bits & Encoding.FRAME_D14_D15) != 0,
        };
    }
};

// Tests
test "Encoding constants" {
    const testing = std.testing;

    // Frame mode
    try testing.expectEqual(@as(u32, 0x04000000), Encoding.MODE_FRAME);
    try testing.expectEqual(@as(u32, 0x02000000), Encoding.MODE_FRAMELESS);
    try testing.expectEqual(@as(u32, 0x03000000), Encoding.MODE_DWARF);
}

test "SavedRegs encode/decode" {
    const testing = std.testing;

    const regs = SavedRegs{
        .x19_x20 = true,
        .x23_x24 = true,
        .d8_d9 = true,
    };

    const encoded = regs.encode();
    try testing.expect((encoded & Encoding.FRAME_X19_X20) != 0);
    try testing.expect((encoded & Encoding.FRAME_X21_X22) == 0);
    try testing.expect((encoded & Encoding.FRAME_X23_X24) != 0);
    try testing.expect((encoded & Encoding.FRAME_D8_D9) != 0);

    const decoded = SavedRegs.decode(encoded);
    try testing.expect(decoded.x19_x20);
    try testing.expect(!decoded.x21_x22);
    try testing.expect(decoded.x23_x24);
    try testing.expect(decoded.d8_d9);
}

test "CompactUnwindBuilder basic" {
    const testing = std.testing;
    var builder = CompactUnwindBuilder.init(testing.allocator);
    defer builder.deinit();

    // Add a frame-based function
    try builder.addFrameFunction(0, 100, .{ .x19_x20 = true, .x21_x22 = true });

    // Add a frameless function
    try builder.addFramelessFunction(100, 50, 32);

    try testing.expectEqual(@as(usize, 2), builder.count());
}

test "CompactUnwindBuilder build" {
    const testing = std.testing;
    var builder = CompactUnwindBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.addFrameFunction(0, 100, .{ .x19_x20 = true });

    var out = std.ArrayList(u8).init(testing.allocator);
    defer out.deinit();

    try builder.build(&out);
    try testing.expect(out.items.len > 0);

    // Check version
    const version = std.mem.readInt(u32, out.items[0..4], .little);
    try testing.expectEqual(@as(u32, 1), version);
}
