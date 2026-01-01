const std = @import("std");
const testing = std.testing;

/// Source position for error reporting.
pub const Pos = struct {
    /// File index.
    file: usize,
    /// Byte offset in file.
    offset: usize,

    pub fn new(file: usize, offset: usize) Pos {
        return .{ .file = file, .offset = offset };
    }

    pub fn format(self: Pos, writer: anytype) !void {
        try writer.print("{}:{}", .{ self.file, self.offset });
    }
};

/// Source span for error reporting.
pub const Span = struct {
    start: Pos,
    end: Pos,

    pub fn new(start: Pos, end: Pos) Span {
        return .{ .start = start, .end = end };
    }

    pub fn newSingle(pos: Pos) Span {
        return .{ .start = pos, .end = pos };
    }

    pub fn format(self: Span, writer: anytype) !void {
        try writer.print("{}:{}-{}:{}", .{
            self.start.file,
            self.start.offset,
            self.end.file,
            self.end.offset,
        });
    }
};

/// ISLE token.
pub const Token = union(enum) {
    /// Left parenthesis `(`.
    lparen,
    /// Right parenthesis `)`.
    rparen,
    /// Symbol/identifier.
    symbol: []const u8,
    /// Integer literal.
    int: i128,
    /// At sign `@`.
    at,
    /// Semicolon `;` (for comments).
    semicolon,

    pub fn format(self: Token, writer: anytype) !void {
        switch (self) {
            .lparen => try writer.writeAll("("),
            .rparen => try writer.writeAll(")"),
            .symbol => |s| try writer.print("symbol({s})", .{s}),
            .int => |i| try writer.print("int({})", .{i}),
            .at => try writer.writeAll("@"),
            .semicolon => try writer.writeAll(";"),
        }
    }
};

test "Pos" {
    const pos = Pos.new(0, 42);
    try testing.expectEqual(@as(usize, 0), pos.file);
    try testing.expectEqual(@as(usize, 42), pos.offset);
}

test "Span" {
    const start = Pos.new(0, 10);
    const end = Pos.new(0, 20);
    const span = Span.new(start, end);
    try testing.expectEqual(start, span.start);
    try testing.expectEqual(end, span.end);
}

test "Token" {
    const tok = Token{ .symbol = "foo" };
    try testing.expectEqualStrings("foo", tok.symbol);
}
