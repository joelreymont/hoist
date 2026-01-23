const std = @import("std");

pub const Location = struct {
    line: usize,

    pub fn init(line: usize) Location {
        return .{ .line = line };
    }
};

pub const LexError = error{
    InvalidChar,
};

pub const LocatedError = struct {
    err: LexError,
    loc: Location,
};

pub const Token = union(enum) {
    // Structural
    lparen,
    rparen,
    lbrace,
    rbrace,
    lbracket,
    rbracket,

    // Operators
    minus,
    plus,
    multiply,
    comma,
    dot,
    colon,
    equal,
    bang,
    arrow, // ->

    // Literals
    integer: []const u8,
    float: []const u8,
    string: []const u8,
    name: []const u8, // %identifier
    hex_seq: []const u8, // #hexdigits

    // Identifiers & Keywords
    identifier: []const u8,

    // Entity names (v#, block#, ss#, etc.)
    value: u32,
    block: u32,
    stack_slot: u32,
    global_value: u32,
    func_ref: u32,
    sig_ref: u32,
    heap: u32,
    table: u32,
    constant: u32,

    // Source location
    srcloc: u32, // @####

    // Comments
    comment: []const u8,

    // End of stream
    eof,

    pub fn format(self: Token, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .lparen => try writer.writeAll("("),
            .rparen => try writer.writeAll(")"),
            .lbrace => try writer.writeAll("{"),
            .rbrace => try writer.writeAll("}"),
            .lbracket => try writer.writeAll("["),
            .rbracket => try writer.writeAll("]"),
            .minus => try writer.writeAll("-"),
            .plus => try writer.writeAll("+"),
            .multiply => try writer.writeAll("*"),
            .comma => try writer.writeAll(","),
            .dot => try writer.writeAll("."),
            .colon => try writer.writeAll(":"),
            .equal => try writer.writeAll("="),
            .bang => try writer.writeAll("!"),
            .arrow => try writer.writeAll("->"),
            .integer => |s| try writer.print("{s}", .{s}),
            .float => |s| try writer.print("{s}", .{s}),
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .name => |s| try writer.print("%{s}", .{s}),
            .hex_seq => |s| try writer.print("#{s}", .{s}),
            .identifier => |s| try writer.writeAll(s),
            .value => |n| try writer.print("v{d}", .{n}),
            .block => |n| try writer.print("block{d}", .{n}),
            .stack_slot => |n| try writer.print("ss{d}", .{n}),
            .global_value => |n| try writer.print("gv{d}", .{n}),
            .func_ref => |n| try writer.print("fn{d}", .{n}),
            .sig_ref => |n| try writer.print("sig{d}", .{n}),
            .heap => |n| try writer.print("heap{d}", .{n}),
            .table => |n| try writer.print("table{d}", .{n}),
            .constant => |n| try writer.print("const{d}", .{n}),
            .srcloc => |n| try writer.print("@{d:0>4}", .{n}),
            .comment => |s| try writer.print("; {s}", .{s}),
            .eof => try writer.writeAll("EOF"),
        }
    }
};

pub const LocatedToken = struct {
    tok: Token,
    loc: Location,
};

pub const Lexer = struct {
    src: []const u8,
    pos: usize,
    line: usize,
    lookahead: ?u8,

    pub fn init(src: []const u8) Lexer {
        var lex = Lexer{
            .src = src,
            .pos = 0,
            .line = 1,
            .lookahead = null,
        };
        lex.lookahead = lex.nextChar();
        return lex;
    }

    fn nextChar(self: *Lexer) ?u8 {
        if (self.pos >= self.src.len) return null;
        const c = self.src[self.pos];
        self.pos += 1;
        return c;
    }

    fn peekChar(self: *Lexer) ?u8 {
        return self.lookahead;
    }

    fn consume(self: *Lexer) void {
        self.lookahead = self.nextChar();
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.lookahead) |c| {
            switch (c) {
                ' ', '\t', '\r' => self.consume(),
                '\n' => {
                    self.consume();
                    self.line += 1;
                },
                else => break,
            }
        }
    }

    fn scanComment(self: *Lexer) []const u8 {
        const start = self.pos - 1; // Already consumed ';'
        while (self.lookahead) |c| {
            if (c == '\n') break;
            self.consume();
        }
        return self.src[start..self.pos];
    }

    fn scanIdentifier(self: *Lexer) []const u8 {
        const start = self.pos - 1;
        while (self.lookahead) |c| {
            if (isIdentChar(c)) {
                self.consume();
            } else break;
        }
        return self.src[start..self.pos];
    }

    fn scanNumber(self: *Lexer) []const u8 {
        const start = self.pos - 1;
        while (self.lookahead) |c| {
            switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F', 'x', 'X', 'b', 'B', '_', '.', '+', '-', 'e', 'E', 'p', 'P' => self.consume(),
                else => break,
            }
        }
        return self.src[start..self.pos];
    }
        const start = self.pos;
        while (self.lookahead) |c| {
            if (c == '"') {
                const str = self.src[start .. self.pos - 1];
                self.consume();
                return str;
            }
            if (c == '\n') return error.InvalidChar;
            self.consume();
        }
        return error.InvalidChar;
    }

    fn scanHexSeq(self: *Lexer) []const u8 {
        const start = self.pos;
        while (self.lookahead) |c| {
            switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F' => self.consume(),
                else => break,
            }
        }
        return self.src[start..self.pos];
    }

    fn tryEntityName(ident: []const u8) ?Token {
        if (ident.len < 2) return null;

        var prefix_end: usize = 0;
        while (prefix_end < ident.len) : (prefix_end += 1) {
            if (ident[prefix_end] >= '0' and ident[prefix_end] <= '9') break;
        }
        if (prefix_end == ident.len) return null;

        const prefix = ident[0..prefix_end];
        const num_str = ident[prefix_end..];
        const num = std.fmt.parseInt(u32, num_str, 10) catch return null;

        if (std.mem.eql(u8, prefix, "v")) return .{ .value = num };
        if (std.mem.eql(u8, prefix, "block")) return .{ .block = num };
        if (std.mem.eql(u8, prefix, "ss")) return .{ .stack_slot = num };
        if (std.mem.eql(u8, prefix, "gv")) return .{ .global_value = num };
        if (std.mem.eql(u8, prefix, "fn")) return .{ .func_ref = num };
        if (std.mem.eql(u8, prefix, "sig")) return .{ .sig_ref = num };
        if (std.mem.eql(u8, prefix, "heap")) return .{ .heap = num };
        if (std.mem.eql(u8, prefix, "table")) return .{ .table = num };
        if (std.mem.eql(u8, prefix, "const")) return .{ .constant = num };

        return null;
    }

    fn isIdentChar(c: u8) bool {
        return switch (c) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => true,
            else => false,
        };
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    pub fn next(self: *Lexer) !LocatedToken {
        self.skipWhitespace();

        const loc = Location.init(self.line);
        const c = self.peekChar() orelse return LocatedToken{ .tok = .eof, .loc = loc };

        switch (c) {
            '(' => {
                self.consume();
                return LocatedToken{ .tok = .lparen, .loc = loc };
            },
            ')' => {
                self.consume();
                return LocatedToken{ .tok = .rparen, .loc = loc };
            },
            '{' => {
                self.consume();
                return LocatedToken{ .tok = .lbrace, .loc = loc };
            },
            '}' => {
                self.consume();
                return LocatedToken{ .tok = .rbrace, .loc = loc };
            },
            '[' => {
                self.consume();
                return LocatedToken{ .tok = .lbracket, .loc = loc };
            },
            ']' => {
                self.consume();
                return LocatedToken{ .tok = .rbracket, .loc = loc };
            },
            '+' => {
                self.consume();
                return LocatedToken{ .tok = .plus, .loc = loc };
            },
            '*' => {
                self.consume();
                return LocatedToken{ .tok = .multiply, .loc = loc };
            },
            ',' => {
                self.consume();
                return LocatedToken{ .tok = .comma, .loc = loc };
            },
            '.' => {
                self.consume();
                return LocatedToken{ .tok = .dot, .loc = loc };
            },
            ':' => {
                self.consume();
                return LocatedToken{ .tok = .colon, .loc = loc };
            },
            '=' => {
                self.consume();
                return LocatedToken{ .tok = .equal, .loc = loc };
            },
            '!' => {
                self.consume();
                return LocatedToken{ .tok = .bang, .loc = loc };
            },
            '-' => {
                self.consume();
                if (self.peekChar()) |ch| {
                    if (ch == '>') {
                        self.consume();
                        return LocatedToken{ .tok = .arrow, .loc = loc };
                    }
                    if (isDigit(ch)) {
                        const num = self.scanNumber();
                        return LocatedToken{ .tok = .{ .integer = num }, .loc = loc };
                    }
                }
                return LocatedToken{ .tok = .minus, .loc = loc };
            },
            ';' => {
                self.consume();
                const cmt = self.scanComment();
                return LocatedToken{ .tok = .{ .comment = cmt }, .loc = loc };
            },
            '"' => {
                self.consume();
                const str = try self.scanString();
                return LocatedToken{ .tok = .{ .string = str }, .loc = loc };
            },
            '%' => {
                self.consume();
                const name = self.scanIdentifier();
                return LocatedToken{ .tok = .{ .name = name }, .loc = loc };
            },
            '#' => {
                self.consume();
                const hex = self.scanHexSeq();
                return LocatedToken{ .tok = .{ .hex_seq = hex }, .loc = loc };
            },
            '@' => {
                self.consume();
                const num_str = self.scanNumber();
                const num = try std.fmt.parseInt(u32, num_str, 10);
                return LocatedToken{ .tok = .{ .srcloc = num }, .loc = loc };
            },
            '0'...'9' => {
                self.consume();
                const num = self.scanNumber();
                // Check for float vs int
                for (num) |ch| {
                    if (ch == '.' or ch == 'e' or ch == 'E' or ch == 'p' or ch == 'P') {
                        return LocatedToken{ .tok = .{ .float = num }, .loc = loc };
                    }
                }
                return LocatedToken{ .tok = .{ .integer = num }, .loc = loc };
            },
            'a'...'z', 'A'...'Z', '_' => {
                self.consume();
                const ident = self.scanIdentifier();

                // Try entity name
                if (tryEntityName(ident)) |tok| {
                    return LocatedToken{ .tok = tok, .loc = loc };
                }

                return LocatedToken{ .tok = .{ .identifier = ident }, .loc = loc };
            },
            else => return error.InvalidChar,
        }
    }
};

test "lexer basic tokens" {
    var lex = Lexer.init("( ) { } [ ]");

    const t1 = try lex.next();
    try std.testing.expectEqual(Token.lparen, t1.tok);

    const t2 = try lex.next();
    try std.testing.expectEqual(Token.rparen, t2.tok);

    const t3 = try lex.next();
    try std.testing.expectEqual(Token.lbrace, t3.tok);

    const t4 = try lex.next();
    try std.testing.expectEqual(Token.rbrace, t4.tok);

    const t5 = try lex.next();
    try std.testing.expectEqual(Token.lbracket, t5.tok);

    const t6 = try lex.next();
    try std.testing.expectEqual(Token.rbracket, t6.tok);

    const t7 = try lex.next();
    try std.testing.expectEqual(Token.eof, t7.tok);
}

test "lexer operators" {
    var lex = Lexer.init("+ - * , . : = ! ->");

    const tokens = [_]Token{
        .plus,
        .minus,
        .multiply,
        .comma,
        .dot,
        .colon,
        .equal,
        .bang,
        .arrow,
    };

    for (tokens) |expected| {
        const tok = try lex.next();
        try std.testing.expectEqual(expected, tok.tok);
    }
}

test "lexer integers" {
    var lex = Lexer.init("42 -123 0x1f 0b1010");

    const t1 = try lex.next();
    try std.testing.expect(t1.tok == .integer);
    try std.testing.expectEqualStrings("42", t1.tok.integer);

    const t2 = try lex.next();
    try std.testing.expect(t2.tok == .integer);
    try std.testing.expectEqualStrings("-123", t2.tok.integer);

    const t3 = try lex.next();
    try std.testing.expect(t3.tok == .integer);
    try std.testing.expectEqualStrings("0x1f", t3.tok.integer);

    const t4 = try lex.next();
    try std.testing.expect(t4.tok == .integer);
    try std.testing.expectEqualStrings("0b1010", t4.tok.integer);
}

test "lexer floats" {
    var lex = Lexer.init("3.14 -2.5 1e10 0x1.5p3");

    const t1 = try lex.next();
    try std.testing.expect(t1.tok == .float);
    try std.testing.expectEqualStrings("3.14", t1.tok.float);

    const t2 = try lex.next();
    try std.testing.expect(t2.tok == .float);
    try std.testing.expectEqualStrings("-2.5", t2.tok.float);

    const t3 = try lex.next();
    try std.testing.expect(t3.tok == .float);
    try std.testing.expectEqualStrings("1e10", t3.tok.float);

    const t4 = try lex.next();
    try std.testing.expect(t4.tok == .float);
    try std.testing.expectEqualStrings("0x1.5p3", t4.tok.float);
}

test "lexer entity names" {
    var lex = Lexer.init("v0 v123 block5 ss42 gv1 fn99");

    const t1 = try lex.next();
    try std.testing.expectEqual(@as(u32, 0), t1.tok.value);

    const t2 = try lex.next();
    try std.testing.expectEqual(@as(u32, 123), t2.tok.value);

    const t3 = try lex.next();
    try std.testing.expectEqual(@as(u32, 5), t3.tok.block);

    const t4 = try lex.next();
    try std.testing.expectEqual(@as(u32, 42), t4.tok.stack_slot);

    const t5 = try lex.next();
    try std.testing.expectEqual(@as(u32, 1), t5.tok.global_value);

    const t6 = try lex.next();
    try std.testing.expectEqual(@as(u32, 99), t6.tok.func_ref);
}

test "lexer identifiers" {
    var lex = Lexer.init("iadd function return");

    const t1 = try lex.next();
    try std.testing.expectEqualStrings("iadd", t1.tok.identifier);

    const t2 = try lex.next();
    try std.testing.expectEqualStrings("function", t2.tok.identifier);

    const t3 = try lex.next();
    try std.testing.expectEqualStrings("return", t3.tok.identifier);
}

test "lexer special tokens" {
    var lex = Lexer.init("%name \"string\" #deadbeef @0042");

    const t1 = try lex.next();
    try std.testing.expectEqualStrings("name", t1.tok.name);

    const t2 = try lex.next();
    try std.testing.expectEqualStrings("string", t2.tok.string);

    const t3 = try lex.next();
    try std.testing.expectEqualStrings("deadbeef", t3.tok.hex_seq);

    const t4 = try lex.next();
    try std.testing.expectEqual(@as(u32, 42), t4.tok.srcloc);
}

test "lexer comments" {
    var lex = Lexer.init("; this is a comment\nv0");

    const t1 = try lex.next();
    try std.testing.expect(t1.tok == .comment);

    const t2 = try lex.next();
    try std.testing.expectEqual(@as(u32, 0), t2.tok.value);
    try std.testing.expectEqual(@as(usize, 2), t2.loc.line);
}

test "lexer complete function" {
    const src =
        \\function "add" (i32, i32) -> i32 {
        \\  block0(v0: i32, v1: i32):
        \\    v2 = iadd v0, v1
        \\    return v2
        \\}
    ;

    var lex = Lexer.init(src);

    const t1 = try lex.next();
    try std.testing.expectEqualStrings("function", t1.tok.identifier);

    const t2 = try lex.next();
    try std.testing.expectEqualStrings("add", t2.tok.string);

    const t3 = try lex.next();
    try std.testing.expectEqual(Token.lparen, t3.tok);

    const t4 = try lex.next();
    try std.testing.expectEqualStrings("i32", t4.tok.identifier);

    const t5 = try lex.next();
    try std.testing.expectEqual(Token.comma, t5.tok);

    const t6 = try lex.next();
    try std.testing.expectEqualStrings("i32", t6.tok.identifier);

    const t7 = try lex.next();
    try std.testing.expectEqual(Token.rparen, t7.tok);

    const t8 = try lex.next();
    try std.testing.expectEqual(Token.arrow, t8.tok);

    const t9 = try lex.next();
    try std.testing.expectEqualStrings("i32", t9.tok.identifier);
}
