const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const lexer_mod = @import("lexer.zig");
const ast = @import("ast.zig");
const token_mod = @import("token.zig");

const Lexer = lexer_mod.Lexer;
const Token = token_mod.Token;
const Pos = token_mod.Pos;

pub const ParseError = struct {
    message: []const u8,
    pos: Pos,
};

pub const Parser = struct {
    lexer: *Lexer,
    allocator: Allocator,
    current: ?struct { Pos, Token },
    errors: std.ArrayList(ParseError),

    const Self = @This();

    pub fn init(allocator: Allocator, lexer: *Lexer) !Self {
        var self = Self{
            .lexer = lexer,
            .allocator = allocator,
            .current = null,
            .errors = std.ArrayList(ParseError).init(allocator),
        };
        try self.advance();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.errors.deinit();
    }

    fn reportError(self: *Self, message: []const u8, pos: Pos) !void {
        try self.errors.append(.{ .message = message, .pos = pos });
    }

    fn synchronize(self: *Self) !void {
        // Skip tokens until we find a sync point (top-level lparen or EOF)
        while (self.current) |_| {
            const tok = self.peek() orelse break;
            if (tok == .lparen) break;
            try self.advance();
        }
    }

    fn advance(self: *Self) !void {
        self.current = try self.lexer.next();
    }

    fn peek(self: *const Self) ?Token {
        if (self.current) |tok| return tok[1];
        return null;
    }

    fn peekPos(self: *const Self) ?Pos {
        if (self.current) |tok| return tok[0];
        return null;
    }

    fn expect(self: *Self, expected: Token) !Pos {
        const tok = self.current orelse return error.UnexpectedEof;
        const pos = tok[0];
        const found = tok[1];

        const matches = switch (expected) {
            .lparen => found == .lparen,
            .rparen => found == .rparen,
            .at => found == .at,
            else => false,
        };

        if (!matches) return error.UnexpectedToken;
        try self.advance();
        return pos;
    }

    fn expectSymbol(self: *Self) !ast.Ident {
        const tok = self.current orelse return error.UnexpectedEof;
        const pos = tok[0];
        const found = tok[1];

        if (found != .symbol) return error.ExpectedSymbol;
        const name = found.symbol;
        try self.advance();
        return ast.Ident.init(name, pos);
    }

    fn expectInt(self: *Self) !struct { i128, Pos } {
        const tok = self.current orelse return error.UnexpectedEof;
        const pos = tok[0];
        const found = tok[1];

        if (found != .int) return error.ExpectedInt;
        const val = found.int;
        try self.advance();
        return .{ val, pos };
    }

    pub fn parseDefs(self: *Self) ![]ast.Def {
        var defs = std.ArrayList(ast.Def){};
        errdefer defs.deinit(self.allocator);

        while (self.peek() != null) {
            const def = try self.parseDef();
            try defs.append(self.allocator, def);
        }

        return defs.toOwnedSlice(self.allocator);
    }

    fn parseDef(self: *Self) !ast.Def {
        const start_pos = try self.expect(.lparen);
        const kw = try self.expectSymbol();
        const keyword = kw.name;

        if (std.mem.eql(u8, keyword, "type")) {
            return ast.Def{ .type_def = try self.parseTypeDef(start_pos) };
        } else if (std.mem.eql(u8, keyword, "decl")) {
            return ast.Def{ .decl = try self.parseDecl(start_pos) };
        } else if (std.mem.eql(u8, keyword, "rule")) {
            return ast.Def{ .rule = try self.parseRule(start_pos) };
        } else {
            return error.UnknownDefinition;
        }
    }

    fn parseTypeDef(self: *Self, start_pos: Pos) !ast.TypeDef {
        const name = try self.expectSymbol();
        const ty = try self.parseTypeValue();
        _ = try self.expect(.rparen);

        return ast.TypeDef{
            .name = name,
            .is_extern = false,
            .ty = ty,
            .pos = start_pos,
        };
    }

    fn parseTypeValue(self: *Self) !ast.TypeValue {
        // Check if this is an enum type: (variant1 variant2 ...)
        if (self.peek()) |tok| {
            if (tok == .lparen) {
                // Parse enum variants
                try self.advance(); // consume lparen

                var variants = std.ArrayList(ast.Variant){};
                errdefer {
                    for (variants.items) |*v| {
                        self.allocator.free(v.fields);
                    }
                    variants.deinit();
                }

                while (true) {
                    const peek_tok = self.peek() orelse break;
                    if (peek_tok == .rparen) break;

                    // Each variant is either:
                    // - A symbol (variant name with no fields)
                    // - (variant_name (field_name field_type) ...)
                    if (peek_tok == .lparen) {
                        try self.advance(); // consume lparen
                        const var_name = try self.expectSymbol();

                        var fields = std.ArrayList(ast.Field){};
                        errdefer fields.deinit();

                        // Parse fields: (field_name field_type)
                        while (true) {
                            const field_tok = self.peek() orelse break;
                            if (field_tok == .rparen) break;

                            if (field_tok == .lparen) {
                                try self.advance(); // consume lparen
                                const field_name = try self.expectSymbol();
                                const field_type = try self.expectSymbol();
                                _ = try self.expect(.rparen);

                                try fields.append(ast.Field{
                                    .name = field_name,
                                    .ty = field_type,
                                    .pos = field_name.pos,
                                });
                            } else {
                                return error.ExpectedFieldDefinition;
                            }
                        }

                        _ = try self.expect(.rparen); // close variant

                        try variants.append(ast.Variant{
                            .name = var_name,
                            .fields = try fields.toOwnedSlice(),
                            .pos = var_name.pos,
                        });
                    } else if (peek_tok == .symbol) {
                        // Simple variant with no fields
                        const var_name = try self.expectSymbol();
                        try variants.append(ast.Variant{
                            .name = var_name,
                            .fields = &[_]ast.Field{},
                            .pos = var_name.pos,
                        });
                    } else {
                        return error.UnexpectedToken;
                    }
                }

                _ = try self.expect(.rparen); // close enum variants list

                return ast.TypeValue{ .enum_type = try variants.toOwnedSlice() };
            }
        }

        // Otherwise, it's a primitive type
        const prim = try self.expectSymbol();
        return ast.TypeValue{ .primitive = prim };
    }

    fn parseDecl(self: *Self, start_pos: Pos) !ast.Decl {
        const term = try self.expectSymbol();

        var arg_tys = std.ArrayList(ast.Ident){};
        errdefer arg_tys.deinit(self.allocator);

        while (true) {
            const tok = self.peek() orelse break;
            if (tok == .rparen) break;
            if (tok == .symbol and std.mem.eql(u8, tok.symbol, "pure")) break;
            try arg_tys.append(self.allocator, try self.expectSymbol());
        }

        if (arg_tys.items.len == 0) return error.MissingReturnType;
        const ret_ty = arg_tys.pop() orelse return error.MissingReturnType;

        var pure = false;
        if (self.peek()) |tok| {
            if (tok == .symbol and std.mem.eql(u8, tok.symbol, "pure")) {
                try self.advance();
                pure = true;
            }
        }

        _ = try self.expect(.rparen);

        return ast.Decl{
            .term = term,
            .arg_tys = try arg_tys.toOwnedSlice(self.allocator),
            .ret_ty = ret_ty,
            .pure = pure,
            .pos = start_pos,
        };
    }

    fn parseExternDef(self: *Self, start_pos: Pos) !ast.ExternDef {
        const term = try self.expectSymbol();
        const func = try self.expectSymbol();
        _ = try self.expect(.rparen);

        return ast.ExternDef{
            .term = term,
            .func = func,
            .pos = start_pos,
        };
    }

    fn parseExtractor(self: *Self, start_pos: Pos) !ast.Extractor {
        // Parse: (extractor name (arg1 arg2) template_pattern)
        const name = try self.expectSymbol();

        // Parse argument list: (arg1 arg2 ...)
        _ = try self.expect(.lparen);
        var args = std.ArrayList(ast.Ident){};
        errdefer args.deinit(self.allocator);

        while (true) {
            const tok = self.peek() orelse break;
            if (tok == .rparen) break;
            try args.append(self.allocator, try self.expectSymbol());
        }

        _ = try self.expect(.rparen);

        // Parse template pattern
        const template = try self.parsePattern();

        _ = try self.expect(.rparen);

        return ast.Extractor{
            .term = name,
            .args = try args.toOwnedSlice(self.allocator),
            .template = template,
            .pos = start_pos,
        };
    }

    fn parseRule(self: *Self, start_pos: Pos) !ast.Rule {
        const pattern = try self.parsePattern();
        var iflets = std.ArrayList(ast.IfLet){};
        errdefer iflets.deinit(self.allocator);

        // Parse optional if-let guards: (if-let pattern expr)
        while (true) {
            const tok = self.peek() orelse break;
            if (tok != .lparen) break;

            // Peek ahead to see if this is an if-let
            const saved_current = self.current;
            _ = try self.expect(.lparen);

            const is_iflet = blk: {
                if (self.peek()) |next_tok| {
                    if (next_tok == .symbol) {
                        const sym = next_tok.symbol;
                        if (std.mem.eql(u8, sym, "if-let")) {
                            break :blk true;
                        }
                    }
                }
                break :blk false;
            };

            if (!is_iflet) {
                // Not an if-let, restore and break
                self.current = saved_current;
                break;
            }

            // Consume "if-let" symbol
            _ = try self.expectSymbol();

            const iflet_pos = self.peekPos().?;
            const iflet_pattern = try self.parsePattern();
            const iflet_expr = try self.parseExpr();
            _ = try self.expect(.rparen);

            try iflets.append(self.allocator, ast.IfLet{
                .pattern = iflet_pattern,
                .expr = iflet_expr,
                .pos = iflet_pos,
            });
        }

        const expr = try self.parseExpr();
        _ = try self.expect(.rparen);

        return ast.Rule{
            .pattern = pattern,
            .iflets = try iflets.toOwnedSlice(self.allocator),
            .expr = expr,
            .prio = null,
            .name = null,
            .pos = start_pos,
        };
    }

    fn parsePattern(self: *Self) !ast.Pattern {
        const tok = self.peek() orelse return error.UnexpectedEof;
        const pos = self.peekPos().?;

        switch (tok) {
            .lparen => {
                _ = try self.expect(.lparen);
                const sym = try self.expectSymbol();
                var args = std.ArrayList(ast.Pattern){};
                errdefer args.deinit(self.allocator);

                while (true) {
                    const next_tok = self.peek() orelse break;
                    if (next_tok == .rparen) break;
                    try args.append(self.allocator, try self.parsePattern());
                }
                _ = try self.expect(.rparen);

                return ast.Pattern{ .term = .{
                    .sym = sym,
                    .args = try args.toOwnedSlice(self.allocator),
                    .pos = pos,
                } };
            },
            .symbol => {
                const sym = try self.expectSymbol();
                return ast.Pattern{ .var_pat = .{ .var_name = sym, .pos = pos } };
            },
            else => return error.InvalidPattern,
        }
    }

    fn parseExpr(self: *Self) !ast.Expr {
        const tok = self.peek() orelse return error.UnexpectedEof;
        const pos = self.peekPos().?;

        switch (tok) {
            .lparen => {
                _ = try self.expect(.lparen);
                const sym = try self.expectSymbol();
                var args = std.ArrayList(ast.Expr){};
                errdefer args.deinit(self.allocator);

                while (true) {
                    const next_tok = self.peek() orelse break;
                    if (next_tok == .rparen) break;
                    try args.append(self.allocator, try self.parseExpr());
                }
                _ = try self.expect(.rparen);

                return ast.Expr{ .term = .{
                    .sym = sym,
                    .args = try args.toOwnedSlice(self.allocator),
                    .pos = pos,
                } };
            },
            .symbol => {
                const sym = try self.expectSymbol();
                return ast.Expr{ .var_expr = .{ .name = sym, .pos = pos } };
            },
            else => return error.InvalidExpression,
        }
    }
};

test "Parser type definition" {
    const src = "(type MyType u32)";
    var lexer = Lexer.init(testing.allocator, 0, src);
    var parser = try Parser.init(testing.allocator, &lexer);

    const defs = try parser.parseDefs();
    defer {
        for (defs) |def| {
            testing.allocator.free(def.type_def.name.name);
        }
        testing.allocator.free(defs);
    }

    try testing.expectEqual(@as(usize, 1), defs.len);
    try testing.expectEqualStrings("MyType", defs[0].type_def.name.name);
}

test "Parser decl" {
    const src = "(decl iadd (i32 i32) i32 pure)";
    var lexer = Lexer.init(testing.allocator, 0, src);
    var parser = try Parser.init(testing.allocator, &lexer);

    const defs = try parser.parseDefs();
    defer {
        testing.allocator.free(defs[0].decl.term.name);
        for (defs[0].decl.arg_tys) |arg| {
            testing.allocator.free(arg.name);
        }
        testing.allocator.free(defs[0].decl.arg_tys);
        testing.allocator.free(defs[0].decl.ret_ty.name);
        testing.allocator.free(defs);
    }

    try testing.expectEqual(@as(usize, 1), defs.len);
    const decl = defs[0].decl;
    try testing.expectEqualStrings("iadd", decl.term.name);
    try testing.expectEqual(@as(usize, 2), decl.arg_tys.len);
    try testing.expectEqualStrings("i32", decl.ret_ty.name);
    try testing.expect(decl.pure);
}

test "Parser simple rule" {
    const src = "(rule (iadd x y) (iadd y x))";
    var lexer = Lexer.init(testing.allocator, 0, src);
    var parser = try Parser.init(testing.allocator, &lexer);

    const defs = try parser.parseDefs();
    defer {
        testing.allocator.free(defs[0].rule.pattern.term.sym.name);
        for (defs[0].rule.pattern.term.args) |arg| {
            testing.allocator.free(arg.var_pat.var_name.name);
        }
        testing.allocator.free(defs[0].rule.pattern.term.args);

        testing.allocator.free(defs[0].rule.expr.term.sym.name);
        for (defs[0].rule.expr.term.args) |arg| {
            testing.allocator.free(arg.var_expr.name.name);
        }
        testing.allocator.free(defs[0].rule.expr.term.args);

        testing.allocator.free(defs[0].rule.iflets);
        testing.allocator.free(defs);
    }

    try testing.expectEqual(@as(usize, 1), defs.len);
    const rule = defs[0].rule;
    try testing.expectEqualStrings("iadd", rule.pattern.term.sym.name);
    try testing.expectEqualStrings("iadd", rule.expr.term.sym.name);
}
