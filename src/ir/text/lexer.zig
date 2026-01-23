//! Hoist IR text format lexer.

const std = @import("std");

pub const TokenType = enum {
    lparen,
    rparen,
    lbrace,
    rbrace,
    comma,
    colon,
    equal,
    arrow,
    identifier,
    integer,
    string,
    comment,
    value,
    block,
    eof,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: u32,
    entity_id: ?u32 = null,
};

fn isIdentChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_';
}

pub const Lexer = struct {
    src: []const u8,
    pos: usize = 0,
    line: u32 = 1,

    pub fn init(src: []const u8) Lexer {
        return .{ .src = src };
    }

    fn peek(self: Lexer) ?u8 {
        return if (self.pos < self.src.len) self.src[self.pos] else null;
    }

    fn peekNext(self: Lexer) ?u8 {
        return if (self.pos + 1 < self.src.len) self.src[self.pos + 1] else null;
    }

    fn advance(self: *Lexer) ?u8 {
        if (self.pos < self.src.len) {
            const c = self.src[self.pos];
            self.pos += 1;
            if (c == '\n') self.line += 1;
            return c;
        }
        return null;
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.peek()) |c| {
            switch (c) {
                ' ', '\t', '\r', '\n' => _ = self.advance(),
                else => break,
            }
        }
    }

    fn readComment(self: *Lexer) Token {
        const start = self.pos;
        const line_num = self.line;
        _ = self.advance();
        _ = self.advance();
        while (self.peek()) |c| {
            if (c == '\n') break;
            _ = self.advance();
        }
        return Token{
            .type = .comment,
            .lexeme = self.src[start..self.pos],
            .line = line_num,
        };
    }

    fn readString(self: *Lexer) Token {
        const start = self.pos;
        const line_num = self.line;
        _ = self.advance();
        while (self.peek()) |c| {
            if (c == '"') {
                _ = self.advance();
                break;
            }
            if (c == '\\') {
                _ = self.advance();
                _ = self.advance();
            } else {
                _ = self.advance();
            }
        }
        return Token{
            .type = .string,
            .lexeme = self.src[start..self.pos],
            .line = line_num,
        };
    }

    fn readNumber(self: *Lexer) Token {
        const start = self.pos;
        const line_num = self.line;
        while (self.peek()) |c| {
            if (c >= '0' and c <= '9') {
                _ = self.advance();
            } else break;
        }
        return Token{
            .type = .integer,
            .lexeme = self.src[start..self.pos],
            .line = line_num,
        };
    }

    fn readIdentifierOrEntity(self: *Lexer) Token {
        const start = self.pos;
        const line_num = self.line;
        while (self.peek()) |c| {
            if (isIdentChar(c)) {
                _ = self.advance();
            } else break;
        }
        const lexeme = self.src[start..self.pos];

        if (lexeme.len > 1 and lexeme[0] == 'v') {
            if (std.fmt.parseInt(u32, lexeme[1..], 10)) |id| {
                return Token{ .type = .value, .lexeme = lexeme, .line = line_num, .entity_id = id };
            } else |_| {}
        }

        if (std.mem.startsWith(u8, lexeme, "block")) {
            const num_part = lexeme[5..];
            if (num_part.len > 0) {
                if (std.fmt.parseInt(u32, num_part, 10)) |id| {
                    return Token{ .type = .block, .lexeme = lexeme, .line = line_num, .entity_id = id };
                } else |_| {}
            }
        }

        return Token{ .type = .identifier, .lexeme = lexeme, .line = line_num };
    }

    pub fn nextToken(self: *Lexer) Token {
        self.skipWhitespace();
        const line_num = self.line;

        const c = self.peek() orelse return Token{ .type = .eof, .lexeme = "", .line = line_num };

        switch (c) {
            '(' => { _ = self.advance(); return Token{ .type = .lparen, .lexeme = "(", .line = line_num }; },
            ')' => { _ = self.advance(); return Token{ .type = .rparen, .lexeme = ")", .line = line_num }; },
            '{' => { _ = self.advance(); return Token{ .type = .lbrace, .lexeme = "{", .line = line_num }; },
            '}' => { _ = self.advance(); return Token{ .type = .rbrace, .lexeme = "}", .line = line_num }; },
            ',' => { _ = self.advance(); return Token{ .type = .comma, .lexeme = ",", .line = line_num }; },
            ':' => { _ = self.advance(); return Token{ .type = .colon, .lexeme = ":", .line = line_num }; },
            '=' => { _ = self.advance(); return Token{ .type = .equal, .lexeme = "=", .line = line_num }; },
            '-' => {
                if (self.peekNext() == '>') {
                    _ = self.advance();
                    _ = self.advance();
                    return Token{ .type = .arrow, .lexeme = "->", .line = line_num };
                } else {
                    _ = self.advance();
                    return Token{ .type = .identifier, .lexeme = "-", .line = line_num };
                }
            },
            '/' => {
                if (self.peekNext() == '/') {
                    return self.readComment();
                } else {
                    _ = self.advance();
                    return Token{ .type = .identifier, .lexeme = "/", .line = line_num };
                }
            },
            '"' => return self.readString(),
            '0'...'9' => return self.readNumber(),
            'a'...'z', 'A'...'Z', '_' => return self.readIdentifierOrEntity(),
            else => {
                _ = self.advance();
                return Token{ .type = .identifier, .lexeme = self.src[self.pos - 1 .. self.pos], .line = line_num };
            },
        }
    }
};

const testing = std.testing;

test "basic tokens" {
    var lexer = Lexer.init("( ) { } , : = ->");
    try testing.expectEqual(TokenType.lparen, lexer.nextToken().type);
    try testing.expectEqual(TokenType.rparen, lexer.nextToken().type);
    try testing.expectEqual(TokenType.lbrace, lexer.nextToken().type);
    try testing.expectEqual(TokenType.rbrace, lexer.nextToken().type);
    try testing.expectEqual(TokenType.comma, lexer.nextToken().type);
    try testing.expectEqual(TokenType.colon, lexer.nextToken().type);
    try testing.expectEqual(TokenType.equal, lexer.nextToken().type);
    try testing.expectEqual(TokenType.arrow, lexer.nextToken().type);
    try testing.expectEqual(TokenType.eof, lexer.nextToken().type);
}

test "identifiers" {
    var lexer = Lexer.init("function add iadd return");
    try testing.expectEqualSlices(u8, "function", lexer.nextToken().lexeme);
    try testing.expectEqualSlices(u8, "add", lexer.nextToken().lexeme);
    try testing.expectEqualSlices(u8, "iadd", lexer.nextToken().lexeme);
    try testing.expectEqualSlices(u8, "return", lexer.nextToken().lexeme);
}

test "integers" {
    var lexer = Lexer.init("0 42 12345 999");
    try testing.expectEqualSlices(u8, "0", lexer.nextToken().lexeme);
    try testing.expectEqualSlices(u8, "42", lexer.nextToken().lexeme);
    try testing.expectEqualSlices(u8, "12345", lexer.nextToken().lexeme);
    try testing.expectEqualSlices(u8, "999", lexer.nextToken().lexeme);
}

test "value entities" {
    var lexer = Lexer.init("v0 v1 v123 v999");
    try testing.expectEqual(@as(u32, 0), lexer.nextToken().entity_id.?);
    try testing.expectEqual(@as(u32, 1), lexer.nextToken().entity_id.?);
    try testing.expectEqual(@as(u32, 123), lexer.nextToken().entity_id.?);
    try testing.expectEqual(@as(u32, 999), lexer.nextToken().entity_id.?);
}

test "block entities" {
    var lexer = Lexer.init("block0 block1 block42");
    try testing.expectEqual(@as(u32, 0), lexer.nextToken().entity_id.?);
    try testing.expectEqual(@as(u32, 1), lexer.nextToken().entity_id.?);
    try testing.expectEqual(@as(u32, 42), lexer.nextToken().entity_id.?);
}

test "comments" {
    var lexer = Lexer.init("// comment\niadd");
    var tok = lexer.nextToken();
    try testing.expectEqual(TokenType.comment, tok.type);
    try testing.expectEqualSlices(u8, "// comment", tok.lexeme);
    tok = lexer.nextToken();
    try testing.expectEqualSlices(u8, "iadd", tok.lexeme);
    try testing.expectEqual(@as(u32, 2), tok.line);
}

test "strings" {
    var lexer = Lexer.init("\"add\" \"hello world\"");
    try testing.expectEqualSlices(u8, "\"add\"", lexer.nextToken().lexeme);
    try testing.expectEqualSlices(u8, "\"hello world\"", lexer.nextToken().lexeme);
}

test "IR function signature" {
    var lexer = Lexer.init("function \"add\" (i32, i32) -> i32 {");
    try testing.expectEqualSlices(u8, "function", lexer.nextToken().lexeme);
    try testing.expectEqual(TokenType.string, lexer.nextToken().type);
    try testing.expectEqual(TokenType.lparen, lexer.nextToken().type);
    try testing.expectEqualSlices(u8, "i32", lexer.nextToken().lexeme);
    try testing.expectEqual(TokenType.comma, lexer.nextToken().type);
    try testing.expectEqual(TokenType.identifier, lexer.nextToken().type);
    try testing.expectEqual(TokenType.rparen, lexer.nextToken().type);
    try testing.expectEqual(TokenType.arrow, lexer.nextToken().type);
    try testing.expectEqualSlices(u8, "i32", lexer.nextToken().lexeme);
    try testing.expectEqual(TokenType.lbrace, lexer.nextToken().type);
    try testing.expectEqual(TokenType.eof, lexer.nextToken().type);
}

test "block header with parameters" {
    var lexer = Lexer.init("block0(v0: i32, v1: i32):");
    try testing.expectEqual(TokenType.block, lexer.nextToken().type);
    try testing.expectEqual(TokenType.lparen, lexer.nextToken().type);
    try testing.expectEqual(@as(u32, 0), lexer.nextToken().entity_id.?);
    try testing.expectEqual(TokenType.colon, lexer.nextToken().type);
    try testing.expectEqual(TokenType.identifier, lexer.nextToken().type);
    try testing.expectEqual(TokenType.comma, lexer.nextToken().type);
    try testing.expectEqual(TokenType.value, lexer.nextToken().type);
    try testing.expectEqual(TokenType.colon, lexer.nextToken().type);
    try testing.expectEqual(TokenType.identifier, lexer.nextToken().type);
    try testing.expectEqual(TokenType.rparen, lexer.nextToken().type);
    try testing.expectEqual(TokenType.colon, lexer.nextToken().type);
}

test "instruction with multiple arguments" {
    var lexer = Lexer.init("v2 = iadd v0, v1");
    try testing.expectEqual(@as(u32, 2), lexer.nextToken().entity_id.?);
    try testing.expectEqual(TokenType.equal, lexer.nextToken().type);
    try testing.expectEqual(TokenType.identifier, lexer.nextToken().type);
    try testing.expectEqual(@as(u32, 0), lexer.nextToken().entity_id.?);
    try testing.expectEqual(TokenType.comma, lexer.nextToken().type);
    try testing.expectEqual(@as(u32, 1), lexer.nextToken().entity_id.?);
}

test "line number tracking" {
    var lexer = Lexer.init("line1\n// comment\nline3");
    try testing.expectEqual(@as(u32, 1), lexer.nextToken().line);
    try testing.expectEqual(@as(u32, 2), lexer.nextToken().line);
    try testing.expectEqual(@as(u32, 3), lexer.nextToken().line);
}

test "whitespace handling" {
    var lexer = Lexer.init("  \t  v0   \n  iadd  ");
    try testing.expectEqual(TokenType.value, lexer.nextToken().type);
    try testing.expectEqual(TokenType.identifier, lexer.nextToken().type);
    try testing.expectEqual(TokenType.eof, lexer.nextToken().type);
}
