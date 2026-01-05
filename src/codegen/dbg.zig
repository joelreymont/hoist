//! Debug tracing helpers.
//!
//! Ported from cranelift-codegen dbg.rs.
//! Provides utilities for debug output and logging.

const std = @import("std");

/// Prefix added to the log file names, just before the thread name or id.
pub const LOG_FILENAME_PREFIX: []const u8 = "cranelift.dbg.";

/// Helper for printing lists.
pub fn DisplayList(comptime T: type) type {
    return struct {
        items: []const T,

        const Self = @This();

        pub fn init(items: []const T) Self {
            return .{ .items = items };
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            if (self.items.len == 0) {
                try writer.writeAll("[]");
                return;
            }

            try writer.print("[{any}", .{self.items[0]});
            for (self.items[1..]) |item| {
                try writer.print(", {any}", .{item});
            }
            try writer.writeAll("]");
        }
    };
}

const testing = std.testing;

test "DisplayList" {
    const items = [_]u32{ 1, 2, 3 };
    const list = DisplayList(u32).init(&items);

    var buf: [64]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{any}", .{list});
    try testing.expectEqualStrings("[1, 2, 3]", result);
}

test "DisplayList empty" {
    const items = [_]u32{};
    const list = DisplayList(u32).init(&items);

    var buf: [64]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{any}", .{list});
    try testing.expectEqualStrings("[]", result);
}
