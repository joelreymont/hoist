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
            .errors = .{},
        };
        try self.advance();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.errors.deinit(self.allocator);
    }

    fn reportError(self: *Self, message: []const u8, pos: Pos) !void {
        try self.errors.append(self.allocator, .{ .message = message, .pos = pos });
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
        defer self.allocator.free(kw.name);
        const keyword = kw.name;

        if (std.mem.eql(u8, keyword, "type")) {
            return ast.Def{ .type_def = try self.parseTypeDef(start_pos) };
        } else if (std.mem.eql(u8, keyword, "decl")) {
            return ast.Def{ .decl = try self.parseDecl(start_pos) };
        } else if (std.mem.eql(u8, keyword, "extractor")) {
            return ast.Def{ .extractor = try self.parseExtractor(start_pos) };
        } else if (std.mem.eql(u8, keyword, "extern")) {
            return ast.Def{ .extern_def = try self.parseExternDef(start_pos) };
        } else if (std.mem.eql(u8, keyword, "rule")) {
            return ast.Def{ .rule = try self.parseRule(start_pos) };
        } else {
            return error.UnknownDefinition;
        }
    }

    fn parseTypeDef(self: *Self, start_pos: Pos) !ast.TypeDef {
        const name = try self.expectSymbol();
        var is_extern = false;
        if (self.peek()) |tok| {
            if (tok == .symbol and std.mem.eql(u8, tok.symbol, "extern")) {
                const kw = try self.expectSymbol();
                self.allocator.free(kw.name);
                is_extern = true;
            }
        }

        const ty = try self.parseTypeValue();
        _ = try self.expect(.rparen);

        return ast.TypeDef{
            .name = name,
            .is_extern = is_extern,
            .ty = ty,
            .pos = start_pos,
        };
    }

    fn parseTypeValue(self: *Self) !ast.TypeValue {
        const tok = self.peek() orelse return error.UnexpectedEof;
        if (tok == .lparen) {
            _ = try self.expect(.lparen);
            const kind = try self.expectSymbol();
            defer self.allocator.free(kind.name);

            if (std.mem.eql(u8, kind.name, "primitive")) {
                const prim = try self.expectSymbol();
                _ = try self.expect(.rparen);
                return ast.TypeValue{ .primitive = prim };
            }

            if (std.mem.eql(u8, kind.name, "enum")) {
                var variants = std.ArrayList(ast.Variant){};
                errdefer {
                    for (variants.items) |*v| {
                        self.allocator.free(v.fields);
                    }
                    variants.deinit(self.allocator);
                }

                while (true) {
                    const peek_tok = self.peek() orelse break;
                    if (peek_tok == .rparen) break;

                    if (peek_tok == .lparen) {
                        _ = try self.expect(.lparen);
                        const var_name = try self.expectSymbol();

                        var fields = std.ArrayList(ast.Field){};
                        errdefer fields.deinit(self.allocator);

                        while (true) {
                            const field_tok = self.peek() orelse break;
                            if (field_tok == .rparen) break;
                            if (field_tok != .lparen) return error.ExpectedFieldDefinition;

                            _ = try self.expect(.lparen);
                            const field_name = try self.expectSymbol();
                            const field_type = try self.expectSymbol();
                            _ = try self.expect(.rparen);

                            try fields.append(self.allocator, ast.Field{
                                .name = field_name,
                                .ty = field_type,
                                .pos = field_name.pos,
                            });
                        }

                        _ = try self.expect(.rparen);

                        try variants.append(self.allocator, ast.Variant{
                            .name = var_name,
                            .fields = try fields.toOwnedSlice(self.allocator),
                            .pos = var_name.pos,
                        });
                    } else if (peek_tok == .symbol) {
                        const var_name = try self.expectSymbol();
                        try variants.append(self.allocator, ast.Variant{
                            .name = var_name,
                            .fields = &[_]ast.Field{},
                            .pos = var_name.pos,
                        });
                    } else {
                        return error.UnexpectedToken;
                    }
                }

                _ = try self.expect(.rparen);
                return ast.TypeValue{ .enum_type = try variants.toOwnedSlice(self.allocator) };
            }

            return error.UnknownTypeValue;
        }

        const prim = try self.expectSymbol();
        return ast.TypeValue{ .primitive = prim };
    }

    fn parseDecl(self: *Self, start_pos: Pos) !ast.Decl {
        var pure = false;
        var partial = false;
        var term = try self.expectSymbol();
        while (true) {
            if (std.mem.eql(u8, term.name, "pure")) {
                self.allocator.free(term.name);
                pure = true;
                term = try self.expectSymbol();
                continue;
            }
            if (std.mem.eql(u8, term.name, "partial")) {
                self.allocator.free(term.name);
                partial = true;
                term = try self.expectSymbol();
                continue;
            }
            break;
        }

        const arg_tys = try self.parseIdentList();
        errdefer self.allocator.free(arg_tys);

        const ret_tys = try self.parseRetList();
        errdefer self.allocator.free(ret_tys);
        if (ret_tys.len == 0) return error.MissingReturnType;

        while (self.peek()) |tok| {
            if (tok != .symbol) break;
            if (std.mem.eql(u8, tok.symbol, "pure")) {
                const kw = try self.expectSymbol();
                self.allocator.free(kw.name);
                pure = true;
                continue;
            }
            if (std.mem.eql(u8, tok.symbol, "partial")) {
                const kw = try self.expectSymbol();
                self.allocator.free(kw.name);
                partial = true;
                continue;
            }
            break;
        }

        _ = try self.expect(.rparen);

        return ast.Decl{
            .term = term,
            .arg_tys = arg_tys,
            .ret_tys = ret_tys,
            .pure = pure,
            .partial = partial,
            .pos = start_pos,
        };
    }

    fn parseExternDef(self: *Self, start_pos: Pos) !ast.ExternDef {
        const kind_sym = try self.expectSymbol();
        const kind = if (std.mem.eql(u8, kind_sym.name, "constructor"))
            ast.ExternKind.constructor
        else if (std.mem.eql(u8, kind_sym.name, "extractor"))
            ast.ExternKind.extractor
        else
            return error.UnknownExternKind;
        self.allocator.free(kind_sym.name);

        const term = try self.expectSymbol();
        const func = try self.expectSymbol();
        _ = try self.expect(.rparen);

        return ast.ExternDef{
            .kind = kind,
            .term = term,
            .func = func,
            .pos = start_pos,
        };
    }

    fn parseExtractor(self: *Self, start_pos: Pos) !ast.Extractor {
        // Parse: (extractor (name arg1 arg2) template_pattern)
        _ = try self.expect(.lparen);
        const name = try self.expectSymbol();

        var args = std.ArrayList(ast.Ident){};
        errdefer args.deinit(self.allocator);

        while (true) {
            const tok = self.peek() orelse break;
            if (tok == .rparen) break;
            try args.append(self.allocator, try self.expectSymbol());
        }
        _ = try self.expect(.rparen);

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
        var prio: ?i64 = null;
        if (self.peek()) |tok| {
            if (tok == .int) {
                const int_tok = try self.expectInt();
                prio = @intCast(int_tok[0]);
            }
        }

        const pattern = try self.parsePattern();
        var iflets = std.ArrayList(ast.IfLet){};
        errdefer iflets.deinit(self.allocator);

        // Parse optional if-let/if guards: (if-let pattern expr) or (if expr)
        while (true) {
            const tok = self.peek() orelse break;
            if (tok != .lparen) break;

            // Peek ahead to see if this is an if-let
            const saved_current = self.current;
            _ = try self.expect(.lparen);

            const guard_kind: enum { none, if_let, if_guard } = blk: {
                if (self.peek()) |next_tok| {
                    if (next_tok == .symbol) {
                        const sym = next_tok.symbol;
                        if (std.mem.eql(u8, sym, "if-let")) {
                            break :blk .if_let;
                        }
                        if (std.mem.eql(u8, sym, "if")) {
                            break :blk .if_guard;
                        }
                    }
                }
                break :blk .none;
            };

            if (guard_kind == .none) {
                // Not an if-let, restore and break
                self.current = saved_current;
                break;
            }

            const iflet_pos = self.peekPos().?;
            const guard_kw = try self.expectSymbol();
            defer self.allocator.free(guard_kw.name);

            if (guard_kind == .if_let) {
                const iflet_pattern = try self.parsePattern();
                const iflet_expr = try self.parseExpr();
                _ = try self.expect(.rparen);

                try iflets.append(self.allocator, ast.IfLet{
                    .pattern = iflet_pattern,
                    .expr = iflet_expr,
                    .pos = iflet_pos,
                });
                continue;
            }

            const if_expr = try self.parseExpr();
            _ = try self.expect(.rparen);

            try iflets.append(self.allocator, ast.IfLet{
                .pattern = .{ .const_bool = .{ .val = true, .pos = iflet_pos } },
                .expr = if_expr,
                .pos = iflet_pos,
            });

        }

        const expr = try self.parseExpr();
        _ = try self.expect(.rparen);

        return ast.Rule{
            .pattern = pattern,
            .iflets = try iflets.toOwnedSlice(self.allocator),
            .expr = expr,
            .prio = prio,
            .name = null,
            .pos = start_pos,
        };
    }

    fn parsePattern(self: *Self) !ast.Pattern {
        var pat = try self.parsePatternAtom();
        if (self.peek()) |tok| {
            if (tok == .at) {
                _ = try self.expect(.at);
                const subpat = try self.parsePattern();
                if (pat != .var_pat) return error.InvalidBindPattern;
                const subpat_ptr = try self.allocator.create(ast.Pattern);
                subpat_ptr.* = subpat;
                return ast.Pattern{ .bind_pattern = .{
                    .var_name = pat.var_pat.var_name,
                    .subpat = subpat_ptr,
                    .pos = pat.getPos(),
                } };
            }
        }
        return pat;
    }

    fn parsePatternAtom(self: *Self) !ast.Pattern {
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
            .int => {
                const int_tok = try self.expectInt();
                return ast.Pattern{ .const_int = .{ .val = int_tok[0], .pos = int_tok[1] } };
            },
            .symbol => {
                const sym = try self.expectSymbol();
                if (std.mem.eql(u8, sym.name, "_")) {
                    self.allocator.free(sym.name);
                    return ast.Pattern{ .wildcard = .{ .pos = pos } };
                }
                if (std.mem.eql(u8, sym.name, "true") or std.mem.eql(u8, sym.name, "false")) {
                    const val = std.mem.eql(u8, sym.name, "true");
                    self.allocator.free(sym.name);
                    return ast.Pattern{ .const_bool = .{ .val = val, .pos = pos } };
                }
                if (sym.name.len > 0 and sym.name[0] == '$') {
                    try self.stripConstPrefix(&sym);
                    if (std.mem.eql(u8, sym.name, "true") or std.mem.eql(u8, sym.name, "false")) {
                        const val = std.mem.eql(u8, sym.name, "true");
                        self.allocator.free(sym.name);
                        return ast.Pattern{ .const_bool = .{ .val = val, .pos = pos } };
                    }
                    return ast.Pattern{ .const_prim = .{ .val = sym, .pos = pos } };
                }
                if (std.mem.indexOfScalar(u8, sym.name, '.')) |_| {
                    return ast.Pattern{ .const_prim = .{ .val = sym, .pos = pos } };
                }
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
                if (std.mem.eql(u8, sym.name, "let")) {
                    self.allocator.free(sym.name);
                    const defs = try self.parseLetDefs();
                    errdefer self.allocator.free(defs);
                    const body = try self.parseExpr();
                    _ = try self.expect(.rparen);
                    const body_ptr = try self.allocator.create(ast.Expr);
                    body_ptr.* = body;
                    return ast.Expr{ .let_expr = .{
                        .defs = defs,
                        .body = body_ptr,
                        .pos = pos,
                    } };
                }
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
            .int => {
                const int_tok = try self.expectInt();
                return ast.Expr{ .const_int = .{ .val = int_tok[0], .pos = int_tok[1] } };
            },
            .symbol => {
                const sym = try self.expectSymbol();
                if (std.mem.eql(u8, sym.name, "true") or std.mem.eql(u8, sym.name, "false")) {
                    const val = std.mem.eql(u8, sym.name, "true");
                    self.allocator.free(sym.name);
                    return ast.Expr{ .const_bool = .{ .val = val, .pos = pos } };
                }
                if (sym.name.len > 0 and sym.name[0] == '$') {
                    try self.stripConstPrefix(&sym);
                    if (std.mem.eql(u8, sym.name, "true") or std.mem.eql(u8, sym.name, "false")) {
                        const val = std.mem.eql(u8, sym.name, "true");
                        self.allocator.free(sym.name);
                        return ast.Expr{ .const_bool = .{ .val = val, .pos = pos } };
                    }
                    return ast.Expr{ .const_prim = .{ .val = sym, .pos = pos } };
                }
                if (std.mem.indexOfScalar(u8, sym.name, '.')) |_| {
                    return ast.Expr{ .const_prim = .{ .val = sym, .pos = pos } };
                }
                return ast.Expr{ .var_expr = .{ .name = sym, .pos = pos } };
            },
            else => return error.InvalidExpression,
        }
    }

    fn parseIdentList(self: *Self) ![]ast.Ident {
        _ = try self.expect(.lparen);
        var items = std.ArrayList(ast.Ident){};
        errdefer items.deinit(self.allocator);

        while (true) {
            const tok = self.peek() orelse break;
            if (tok == .rparen) break;
            try items.append(self.allocator, try self.expectSymbol());
        }

        _ = try self.expect(.rparen);
        return items.toOwnedSlice(self.allocator);
    }

    fn parseRetList(self: *Self) ![]ast.Ident {
        if (self.peek()) |tok| {
            if (tok == .lparen) {
                return self.parseIdentList();
            }
        }
        var list = std.ArrayList(ast.Ident){};
        errdefer list.deinit(self.allocator);
        try list.append(self.allocator, try self.expectSymbol());
        return list.toOwnedSlice(self.allocator);
    }

    fn parseLetDefs(self: *Self) ![]ast.LetDef {
        _ = try self.expect(.lparen);
        var defs = std.ArrayList(ast.LetDef){};
        errdefer defs.deinit(self.allocator);

        while (true) {
            const tok = self.peek() orelse break;
            if (tok == .rparen) break;
            _ = try self.expect(.lparen);
            const name = try self.expectSymbol();
            const ty = try self.expectSymbol();
            const val = try self.parseExpr();
            _ = try self.expect(.rparen);
            try defs.append(self.allocator, .{
                .var_name = name,
                .ty = ty,
                .val = val,
                .pos = name.pos,
            });
        }

        _ = try self.expect(.rparen);
        return defs.toOwnedSlice(self.allocator);
    }

    fn stripConstPrefix(self: *Self, ident: *ast.Ident) !void {
        if (ident.name.len == 0 or ident.name[0] != '$') return;
        const raw = ident.name[1..];
        const dup = try self.allocator.dupe(u8, raw);
        self.allocator.free(ident.name);
        ident.name = dup;
    }
};

test "Parser type definition" {
    const src = "(type MyType u32)";
    var lexer = Lexer.init(testing.allocator, 0, src);
    var parser = try Parser.init(testing.allocator, &lexer);

    const defs = try parser.parseDefs();
    defer {
        for (defs) |def| {
            ast.cleanupDef(testing.allocator, def);
        }
        testing.allocator.free(defs);
    }

    try testing.expectEqual(@as(usize, 1), defs.len);
    try testing.expectEqualStrings("MyType", defs[0].type_def.name.name);
}

test "Parser decl" {
    const src = "(decl pure iadd (i32 i32) i32 partial)";
    var lexer = Lexer.init(testing.allocator, 0, src);
    var parser = try Parser.init(testing.allocator, &lexer);

    const defs = try parser.parseDefs();
    defer {
        for (defs) |def| {
            ast.cleanupDef(testing.allocator, def);
        }
        testing.allocator.free(defs);
    }

    try testing.expectEqual(@as(usize, 1), defs.len);
    const decl = defs[0].decl;
    try testing.expectEqualStrings("iadd", decl.term.name);
    try testing.expectEqual(@as(usize, 2), decl.arg_tys.len);
    try testing.expectEqual(@as(usize, 1), decl.ret_tys.len);
    try testing.expectEqualStrings("i32", decl.ret_tys[0].name);
    try testing.expect(decl.pure);
    try testing.expect(decl.partial);
}

test "Parser simple rule" {
    const src = "(rule (iadd x y) (iadd y x))";
    var lexer = Lexer.init(testing.allocator, 0, src);
    var parser = try Parser.init(testing.allocator, &lexer);

    const defs = try parser.parseDefs();
    defer {
        for (defs) |def| {
            ast.cleanupDef(testing.allocator, def);
        }
        testing.allocator.free(defs);
    }

    try testing.expectEqual(@as(usize, 1), defs.len);
    const rule = defs[0].rule;
    try testing.expectEqualStrings("iadd", rule.pattern.term.sym.name);
    try testing.expectEqualStrings("iadd", rule.expr.term.sym.name);
}

test "Parser extern extractor" {
    const src = "(extern extractor foo foo_impl)";
    var lexer = Lexer.init(testing.allocator, 0, src);
    var parser = try Parser.init(testing.allocator, &lexer);

    const defs = try parser.parseDefs();
    defer {
        for (defs) |def| {
            ast.cleanupDef(testing.allocator, def);
        }
        testing.allocator.free(defs);
    }

    try testing.expectEqual(@as(usize, 1), defs.len);
    const ext = defs[0].extern_def;
    try testing.expect(ext.kind == .extractor);
    try testing.expectEqualStrings("foo", ext.term.name);
    try testing.expectEqualStrings("foo_impl", ext.func.name);
}

test "Parser rule guards and let" {
    const src = "(rule 2 (foo x) (if-let y x) (if (bar x)) (let ((z Type x)) z))";
    var lexer = Lexer.init(testing.allocator, 0, src);
    var parser = try Parser.init(testing.allocator, &lexer);

    const defs = try parser.parseDefs();
    defer {
        for (defs) |def| {
            ast.cleanupDef(testing.allocator, def);
        }
        testing.allocator.free(defs);
    }

    try testing.expectEqual(@as(usize, 1), defs.len);
    const rule = defs[0].rule;
    try testing.expectEqual(@as(i64, 2), rule.prio.?);
    try testing.expectEqual(@as(usize, 2), rule.iflets.len);
    try testing.expect(rule.iflets[0].pattern == .var_pat);
    try testing.expect(rule.iflets[1].pattern == .const_bool);
    try testing.expect(rule.expr == .let_expr);
    try testing.expectEqual(@as(usize, 1), rule.expr.let_expr.defs.len);
}

test "Parser bind pattern" {
    const src = "(rule (foo x @ (bar _ 1)) x)";
    var lexer = Lexer.init(testing.allocator, 0, src);
    var parser = try Parser.init(testing.allocator, &lexer);

    const defs = try parser.parseDefs();
    defer {
        for (defs) |def| {
            ast.cleanupDef(testing.allocator, def);
        }
        testing.allocator.free(defs);
    }

    try testing.expectEqual(@as(usize, 1), defs.len);
    const rule = defs[0].rule;
    try testing.expect(rule.pattern.term.args[0] == .bind_pattern);
}
