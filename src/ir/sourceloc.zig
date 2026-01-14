const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Source location for error reporting and debugging.
pub const SourceLoc = struct {
    /// File path.
    file: []const u8,
    /// Line number (1-indexed).
    line: u32,
    /// Column number (1-indexed).
    column: u32,

    pub fn init(file: []const u8, line: u32, column: u32) SourceLoc {
        return .{
            .file = file,
            .line = line,
            .column = column,
        };
    }

    pub fn format(self: SourceLoc, writer: anytype) !void {
        try writer.print("{s}:{d}:{d}", .{ self.file, self.line, self.column });
    }
};

/// Source location tracker mapping IR entities to source positions.
pub const SourceLocTracker = struct {
    /// Map from instruction/value ID to source location.
    locs: std.AutoHashMap(u32, SourceLoc),
    /// Map from file paths to interned strings.
    files: std.StringHashMap([]const u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) SourceLocTracker {
        return .{
            .locs = std.AutoHashMap(u32, SourceLoc).init(allocator),
            .files = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SourceLocTracker) void {
        var file_iter = self.files.valueIterator();
        while (file_iter.next()) |file| {
            self.allocator.free(file.*);
        }
        self.files.deinit();
        self.locs.deinit();
    }

    /// Add source location for an entity.
    pub fn addLoc(self: *SourceLocTracker, id: u32, file: []const u8, line: u32, column: u32) !void {
        // Intern file path
        const interned_file = try self.internFile(file);
        const loc = SourceLoc.init(interned_file, line, column);
        try self.locs.put(id, loc);
    }

    /// Get source location for an entity.
    pub fn getLoc(self: *const SourceLocTracker, id: u32) ?SourceLoc {
        return self.locs.get(id);
    }

    /// Intern a file path to deduplicate strings.
    fn internFile(self: *SourceLocTracker, file: []const u8) ![]const u8 {
        if (self.files.get(file)) |interned| {
            return interned;
        }

        const owned = try self.allocator.dupe(u8, file);
        try self.files.put(owned, owned);
        return owned;
    }
};

test "SourceLoc format" {
    const loc = SourceLoc.init("test.zig", 42, 10);

    var buf: [128]u8 = undefined;
    const formatted = try std.fmt.bufPrint(&buf, "{f}", .{loc});

    try testing.expectEqualStrings("test.zig:42:10", formatted);
}

test "SourceLocTracker add and get" {
    var tracker = SourceLocTracker.init(testing.allocator);
    defer tracker.deinit();

    try tracker.addLoc(1, "foo.zig", 10, 5);
    try tracker.addLoc(2, "bar.zig", 20, 15);

    const loc1 = tracker.getLoc(1).?;
    try testing.expectEqualStrings("foo.zig", loc1.file);
    try testing.expectEqual(@as(u32, 10), loc1.line);
    try testing.expectEqual(@as(u32, 5), loc1.column);

    const loc2 = tracker.getLoc(2).?;
    try testing.expectEqualStrings("bar.zig", loc2.file);
    try testing.expectEqual(@as(u32, 20), loc2.line);

    try testing.expect(tracker.getLoc(999) == null);
}

test "SourceLocTracker file interning" {
    var tracker = SourceLocTracker.init(testing.allocator);
    defer tracker.deinit();

    try tracker.addLoc(1, "same.zig", 1, 1);
    try tracker.addLoc(2, "same.zig", 2, 2);

    const loc1 = tracker.getLoc(1).?;
    const loc2 = tracker.getLoc(2).?;

    // Should share same interned file string
    try testing.expect(loc1.file.ptr == loc2.file.ptr);
}
