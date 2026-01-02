const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const token = @import("token.zig");

pub const Pos = token.Pos;
pub const Span = token.Span;
pub const Token = token.Token;

/// ISLE lexer - tokenizes S-expression source.
pub const Lexer = struct {
    src: []const u8,
    pos: Pos,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, file: usize, src: []const u8) Self {
        return .{
            .src = src,
            .pos = Pos.new(file, 0),
            .allocator = allocator,
        };
    }

    fn peekByte(self: *const Self) ?u8 {
        if (self.pos.offset >= self.src.len) return null;
        return self.src[self.pos.offset];
    }

    fn lookaheadByte(self: *const Self, n: usize) ?u8 {
        const offset = self.pos.offset + n;
        if (offset >= self.src.len) return null;
        return self.src[offset];
    }

    fn advancePos(self: *Self) void {
        if (self.peekByte()) |byte| {
            self.pos.advanceByte(byte);
        }
    }

    fn advanceBy(self: *Self, n: usize) void {
        for (0..n) |_| {
            self.advancePos();
        }
    }

    fn isSymFirstChar(c: u8) bool {
        return switch (c) {
            '-', '0'...'9', '(', ')', ';', ' ', '\t', '\n', '\r' => false,
            else => true,
        };
    }

    fn isSymOtherChar(c: u8) bool {
        return switch (c) {
            '(', ')', ';', '@', ' ', '\t', '\n', '\r' => false,
            else => true,
        };
    }

    fn skipWhitespace(self: *Self) !void {
        while (self.peekByte()) |c| {
            switch (c) {
                ' ', '\t', '\n', '\r' => self.advancePos(),
                ';' => {
                    // Line comment
                    while (self.peekByte()) |ch| {
                        switch (ch) {
                            '\n', '\r' => break,
                            else => self.advancePos(),
                        }
                    }
                },
                '(' => {
                    // Block comment (;...;)
                    if (self.lookaheadByte(1) == ';') {
                        var depth: usize = 1;
                        while (true) {
                            const ch = self.peekByte() orelse return error.UnterminatedBlockComment;
                            if (ch == '(' and self.lookaheadByte(1) == ';') {
                                self.advanceBy(2);
                                depth += 1;
                            } else if (ch == ';' and self.lookaheadByte(1) == ')') {
                                self.advanceBy(2);
                                depth -= 1;
                                if (depth == 0) break;
                            } else {
                                self.advancePos();
                            }
                        }
                    } else {
                        break;
                    }
                },
                else => break,
            }
        }
    }

    pub fn next(self: *Self) !?struct { Pos, Token } {
        try self.skipWhitespace();

        const c = self.peekByte() orelse return null;
        const char_pos = self.pos;

        switch (c) {
            '(' => {
                self.advancePos();
                return .{ char_pos, .lparen };
            },
            ')' => {
                self.advancePos();
                return .{ char_pos, .rparen };
            },
            '@' => {
                self.advancePos();
                return .{ char_pos, .at };
            },
            '0'...'9', '-' => {
                return try self.lexInt(char_pos);
            },
            else => {
                if (isSymFirstChar(c)) {
                    return try self.lexSymbol(char_pos);
                }
                return error.InvalidCharacter;
            },
        }
    }

    fn lexSymbol(self: *Self, start_pos: Pos) !struct { Pos, Token } {
        const start = self.pos.offset;
        while (self.peekByte()) |c| {
            if (isSymOtherChar(c)) {
                self.advancePos();
            } else {
                break;
            }
        }
        const end = self.pos.offset;
        const s = self.src[start..end];

        // Allocate and copy symbol
        const sym = try self.allocator.dupe(u8, s);
        return .{ start_pos, Token{ .symbol = sym } };
    }

    fn lexInt(self: *Self, start_pos: Pos) !struct { Pos, Token } {
        var neg = false;
        if (self.peekByte() == '-') {
            self.advancePos();
            neg = true;
        }

        var radix: u8 = 10;

        // Check for radix prefix
        if (self.peekByte() == '0') {
            const next_byte = self.lookaheadByte(1);
            if (next_byte == 'x' or next_byte == 'X') {
                self.advanceBy(2);
                radix = 16;
            } else if (next_byte == 'o' or next_byte == 'O') {
                self.advanceBy(2);
                radix = 8;
            } else if (next_byte == 'b' or next_byte == 'B') {
                self.advanceBy(2);
                radix = 2;
            }
        }

        const start = self.pos.offset;
        while (self.peekByte()) |c| {
            switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F', '_' => self.advancePos(),
                else => break,
            }
        }
        const end = self.pos.offset;
        var s = self.src[start..end];

        // Remove underscores
        var buf: [128]u8 = undefined;
        if (std.mem.indexOf(u8, s, "_")) |_| {
            var i: usize = 0;
            for (s) |c| {
                if (c != '_') {
                    buf[i] = c;
                    i += 1;
                }
            }
            s = buf[0..i];
        }

        const num = std.fmt.parseInt(u128, s, radix) catch return error.InvalidInteger;
        const result: i128 = if (neg) -@as(i128, @intCast(num)) else @intCast(num);

        return .{ start_pos, Token{ .int = result } };
    }
};

test "Lexer basic tokens" {
    const src = "( ) @";
    var lexer = Lexer.init(testing.allocator, 0, src);

    const tok1 = (try lexer.next()).?;
    try testing.expectEqual(Token.lparen, tok1[1]);

    const tok2 = (try lexer.next()).?;
    try testing.expectEqual(Token.rparen, tok2[1]);

    const tok3 = (try lexer.next()).?;
    try testing.expectEqual(Token.at, tok3[1]);

    try testing.expect((try lexer.next()) == null);
}

test "Lexer symbol" {
    const src = "hello-world";
    var lexer = Lexer.init(testing.allocator, 0, src);

    const tok = (try lexer.next()).?;
    try testing.expectEqualStrings("hello-world", tok[1].symbol);
    testing.allocator.free(tok[1].symbol);
}

test "Lexer integer" {
    const src = "42 -10 0x1F 0b1010";
    var lexer = Lexer.init(testing.allocator, 0, src);

    const tok1 = (try lexer.next()).?;
    try testing.expectEqual(@as(i128, 42), tok1[1].int);

    const tok2 = (try lexer.next()).?;
    try testing.expectEqual(@as(i128, -10), tok2[1].int);

    const tok3 = (try lexer.next()).?;
    try testing.expectEqual(@as(i128, 31), tok3[1].int);

    const tok4 = (try lexer.next()).?;
    try testing.expectEqual(@as(i128, 10), tok4[1].int);
}

test "Lexer S-expression" {
    const src = "(rule (iadd x y))";
    var lexer = Lexer.init(testing.allocator, 0, src);

    const tok1 = (try lexer.next()).?;
    try testing.expectEqual(Token.lparen, tok1[1]);

    const tok2 = (try lexer.next()).?;
    try testing.expectEqualStrings("rule", tok2[1].symbol);
    testing.allocator.free(tok2[1].symbol);

    const tok3 = (try lexer.next()).?;
    try testing.expectEqual(Token.lparen, tok3[1]);

    // Cleanup remaining tokens
    while (try lexer.next()) |tok| {
        if (tok[1] == .symbol) testing.allocator.free(tok[1].symbol);
    }
}
