//! DWARF Line Number Information
//!
//! Generates .debug_line section for source-level debugging.
//! Maps machine code addresses to source file locations.
//!
//! Implements DWARF v4 line number program encoding.
//! See DWARF 4 specification section 6.2.

const std = @import("std");
const Allocator = std.mem.Allocator;

const unwind = @import("unwind.zig");
const Uleb128 = unwind.Uleb128;

/// Line number program header.
pub const Header = struct {
    /// Minimum instruction length (4 for aarch64).
    min_inst_len: u8 = 4,
    /// Maximum ops per instruction (1 for aarch64).
    max_ops_per_inst: u8 = 1,
    /// Default is_stmt value.
    default_is_stmt: bool = true,
    /// Line base for special opcodes.
    line_base: i8 = -5,
    /// Line range for special opcodes.
    line_range: u8 = 14,
    /// Opcode base (first special opcode).
    opcode_base: u8 = 13,
    /// Standard opcode lengths.
    std_opcode_lens: [12]u8 = .{ 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1 },
};

/// Standard opcodes.
pub const Opcode = enum(u8) {
    extended = 0,
    copy = 1,
    advance_pc = 2,
    advance_line = 3,
    set_file = 4,
    set_column = 5,
    negate_stmt = 6,
    set_basic_block = 7,
    const_add_pc = 8,
    fixed_advance_pc = 9,
    set_prologue_end = 10,
    set_epilogue_begin = 11,
    set_isa = 12,
};

/// Extended opcodes.
pub const ExtOpcode = enum(u8) {
    end_sequence = 1,
    set_address = 2,
    define_file = 3,
    set_discriminator = 4,
};

/// A source file entry.
pub const FileEntry = struct {
    name: []const u8,
    dir_index: u32,
    mod_time: u64 = 0,
    file_size: u64 = 0,
};

/// A directory entry.
pub const DirEntry = struct {
    path: []const u8,
};

/// Line number state machine.
pub const StateMachine = struct {
    /// Current address.
    address: u64 = 0,
    /// Current file index.
    file: u32 = 1,
    /// Current line number.
    line: u32 = 1,
    /// Current column number.
    column: u32 = 0,
    /// Is statement flag.
    is_stmt: bool = true,
    /// Basic block flag.
    basic_block: bool = false,
    /// End sequence flag.
    end_sequence: bool = false,
    /// Prologue end flag.
    prologue_end: bool = false,
    /// Epilogue begin flag.
    epilogue_begin: bool = false,
    /// ISA value.
    isa: u32 = 0,
    /// Discriminator.
    discriminator: u32 = 0,

    /// Reset to initial state.
    pub fn reset(self: *StateMachine, default_is_stmt: bool) void {
        self.* = .{ .is_stmt = default_is_stmt };
    }
};

/// Line info entry for a single location.
pub const LineEntry = struct {
    address: u64,
    file: u32,
    line: u32,
    column: u32,
    is_stmt: bool,
    prologue_end: bool,
    epilogue_begin: bool,
};

/// Line number program builder.
pub const LineProgram = struct {
    allocator: Allocator,
    header: Header,
    dirs: std.ArrayList(DirEntry),
    files: std.ArrayList(FileEntry),
    entries: std.ArrayList(LineEntry),

    pub fn init(allocator: Allocator) LineProgram {
        return .{
            .allocator = allocator,
            .header = .{},
            .dirs = std.ArrayList(DirEntry).init(allocator),
            .files = std.ArrayList(FileEntry).init(allocator),
            .entries = std.ArrayList(LineEntry).init(allocator),
        };
    }

    pub fn deinit(self: *LineProgram) void {
        self.dirs.deinit();
        self.files.deinit();
        self.entries.deinit();
    }

    /// Add a directory.
    pub fn addDir(self: *LineProgram, path: []const u8) !u32 {
        const idx = @as(u32, @intCast(self.dirs.items.len));
        try self.dirs.append(.{ .path = path });
        return idx;
    }

    /// Add a file.
    pub fn addFile(self: *LineProgram, name: []const u8, dir_index: u32) !u32 {
        const idx = @as(u32, @intCast(self.files.items.len)) + 1; // 1-indexed
        try self.files.append(.{ .name = name, .dir_index = dir_index });
        return idx;
    }

    /// Add a line entry.
    pub fn addEntry(self: *LineProgram, entry: LineEntry) !void {
        try self.entries.append(entry);
    }

    /// Encode the line program to bytes.
    pub fn encode(self: *LineProgram, out: *std.ArrayList(u8)) !void {
        const writer = out.writer();

        // Reserve space for unit length (filled in at end)
        const length_pos = out.items.len;
        try writer.writeInt(u32, 0, .little);

        // Version (DWARF 4)
        try writer.writeInt(u16, 4, .little);

        // Reserve space for header length
        const header_len_pos = out.items.len;
        try writer.writeInt(u32, 0, .little);

        const header_start = out.items.len;

        // Header fields
        try writer.writeByte(self.header.min_inst_len);
        try writer.writeByte(self.header.max_ops_per_inst);
        try writer.writeByte(if (self.header.default_is_stmt) 1 else 0);
        try writer.writeByte(@bitCast(self.header.line_base));
        try writer.writeByte(self.header.line_range);
        try writer.writeByte(self.header.opcode_base);
        try writer.writeAll(&self.header.std_opcode_lens);

        // Directory table
        for (self.dirs.items) |dir| {
            try writer.writeAll(dir.path);
            try writer.writeByte(0);
        }
        try writer.writeByte(0); // End of directories

        // File table
        for (self.files.items) |file| {
            try writer.writeAll(file.name);
            try writer.writeByte(0);
            var buf: [10]u8 = undefined;
            const dir_len = try Uleb128.encode(file.dir_index, &buf);
            try writer.writeAll(buf[0..dir_len]);
            const mod_len = try Uleb128.encode(@as(u32, @truncate(file.mod_time)), &buf);
            try writer.writeAll(buf[0..mod_len]);
            const size_len = try Uleb128.encode(@as(u32, @truncate(file.file_size)), &buf);
            try writer.writeAll(buf[0..size_len]);
        }
        try writer.writeByte(0); // End of files

        // Fill in header length
        const header_len = out.items.len - header_start;
        std.mem.writeInt(u32, out.items[header_len_pos..][0..4], @intCast(header_len), .little);

        // Encode line program
        try self.encodeProgram(out);

        // Fill in unit length
        const unit_len = out.items.len - length_pos - 4;
        std.mem.writeInt(u32, out.items[length_pos..][0..4], @intCast(unit_len), .little);
    }

    /// Encode the line number program opcodes.
    fn encodeProgram(self: *LineProgram, out: *std.ArrayList(u8)) !void {
        const writer = out.writer();

        var state = StateMachine{};
        state.is_stmt = self.header.default_is_stmt;

        // Sort entries by address
        std.mem.sort(LineEntry, self.entries.items, {}, struct {
            fn lessThan(_: void, a: LineEntry, b: LineEntry) bool {
                return a.address < b.address;
            }
        }.lessThan);

        for (self.entries.items) |entry| {
            // Set address if changed
            if (entry.address != state.address) {
                // Extended opcode: set_address
                try writer.writeByte(0); // Extended opcode marker
                try writer.writeByte(9); // Length (1 + 8)
                try writer.writeByte(@intFromEnum(ExtOpcode.set_address));
                try writer.writeInt(u64, entry.address, .little);
                state.address = entry.address;
            }

            // Set file if changed
            if (entry.file != state.file) {
                try writer.writeByte(@intFromEnum(Opcode.set_file));
                var buf: [10]u8 = undefined;
                const len = try Uleb128.encode(entry.file, &buf);
                try writer.writeAll(buf[0..len]);
                state.file = entry.file;
            }

            // Advance line if changed
            if (entry.line != state.line) {
                const line_diff = @as(i64, @intCast(entry.line)) - @as(i64, @intCast(state.line));
                try writer.writeByte(@intFromEnum(Opcode.advance_line));
                var buf: [10]u8 = undefined;
                const len = try Uleb128.encodeSigned(@intCast(line_diff), &buf);
                try writer.writeAll(buf[0..len]);
                state.line = entry.line;
            }

            // Set column if changed
            if (entry.column != state.column) {
                try writer.writeByte(@intFromEnum(Opcode.set_column));
                var buf: [10]u8 = undefined;
                const len = try Uleb128.encode(entry.column, &buf);
                try writer.writeAll(buf[0..len]);
                state.column = entry.column;
            }

            // Prologue end
            if (entry.prologue_end and !state.prologue_end) {
                try writer.writeByte(@intFromEnum(Opcode.set_prologue_end));
                state.prologue_end = true;
            }

            // Epilogue begin
            if (entry.epilogue_begin and !state.epilogue_begin) {
                try writer.writeByte(@intFromEnum(Opcode.set_epilogue_begin));
                state.epilogue_begin = true;
            }

            // Copy to emit row
            try writer.writeByte(@intFromEnum(Opcode.copy));
            state.basic_block = false;
            state.prologue_end = false;
            state.epilogue_begin = false;
            state.discriminator = 0;
        }

        // End sequence
        try writer.writeByte(0); // Extended opcode marker
        try writer.writeByte(1); // Length
        try writer.writeByte(@intFromEnum(ExtOpcode.end_sequence));
    }
};

// Tests
test "Header defaults" {
    const testing = std.testing;
    const header = Header{};

    try testing.expectEqual(@as(u8, 4), header.min_inst_len);
    try testing.expectEqual(@as(u8, 13), header.opcode_base);
}

test "LineProgram basic" {
    const testing = std.testing;
    var prog = LineProgram.init(testing.allocator);
    defer prog.deinit();

    const dir_idx = try prog.addDir("/src");
    const file_idx = try prog.addFile("main.zig", dir_idx);

    try prog.addEntry(.{
        .address = 0x1000,
        .file = file_idx,
        .line = 10,
        .column = 1,
        .is_stmt = true,
        .prologue_end = true,
        .epilogue_begin = false,
    });

    try prog.addEntry(.{
        .address = 0x1010,
        .file = file_idx,
        .line = 15,
        .column = 5,
        .is_stmt = true,
        .prologue_end = false,
        .epilogue_begin = false,
    });

    try testing.expectEqual(@as(usize, 2), prog.entries.items.len);
}

test "LineProgram encode" {
    const testing = std.testing;
    var prog = LineProgram.init(testing.allocator);
    defer prog.deinit();

    _ = try prog.addDir("/src");
    const file_idx = try prog.addFile("test.zig", 0);

    try prog.addEntry(.{
        .address = 0x1000,
        .file = file_idx,
        .line = 1,
        .column = 0,
        .is_stmt = true,
        .prologue_end = false,
        .epilogue_begin = false,
    });

    var out = std.ArrayList(u8).init(testing.allocator);
    defer out.deinit();

    try prog.encode(&out);
    try testing.expect(out.items.len > 0);

    // Check DWARF version
    const version = std.mem.readInt(u16, out.items[4..6], .little);
    try testing.expectEqual(@as(u16, 4), version);
}
