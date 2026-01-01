const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const lexer_mod = @import("lexer.zig");
const ast = @import("ast.zig");
const token_mod = @import("token.zig");

const Lexer = lexer_mod.Lexer;
const Token = token_mod.Token;
const Pos = token_mod.Pos;

pub const Parser = struct {
    lexer: *Lexer,
    allocator: Allocator,
    current: ?struct { Pos, Token },

    const Self = @This();

    pub fn init(allocator: Allocator, lexer: *Lexer) !Self {
        var self = Self{
            .lexer = lexer,
            .allocator = allocator,
            .current = null,
        };
        try self.advance();
        return self;
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

    fn parseExtractor(_: *Self, _: Pos) !ast.Extractor {
        return error.NotImplemented;
    }

    fn parseRule(self: *Self, start_pos: Pos) !ast.Rule {
        const pattern = try self.parsePattern();
        var iflets = std.ArrayList(ast.IfLet){};
        errdefer iflets.deinit(self.allocator);

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
