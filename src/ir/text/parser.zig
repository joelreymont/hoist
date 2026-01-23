const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const lexer_mod = @import("lexer.zig");
const builder_mod = @import("../builder.zig");
const function_mod = @import("../function.zig");
const types_mod = @import("../types.zig");
const entities_mod = @import("../entities.zig");
const signature_mod = @import("../signature.zig");
const condcodes_mod = @import("../condcodes.zig");
const dfg_mod = @import("../dfg.zig");
const instruction_data_mod = @import("../instruction_data.zig");

const Lexer = lexer_mod.Lexer;
const Token = lexer_mod.Token;
const TokenType = lexer_mod.TokenType;
const FunctionBuilder = builder_mod.FunctionBuilder;
const Function = function_mod.Function;
const Type = types_mod.Type;
const Value = entities_mod.Value;
const Block = entities_mod.Block;
const FuncRef = entities_mod.FuncRef;
const Signature = signature_mod.Signature;
const AbiParam = signature_mod.AbiParam;
const IntCC = condcodes_mod.IntCC;

pub const ParseError = error{
    UnexpectedToken,
    UnexpectedEof,
    InvalidType,
    InvalidValue,
    InvalidBlock,
    InvalidOpcode,
    InvalidCondCode,
    OutOfMemory,
    NoCurrentBlock,
};

pub const Parser = struct {
    lexer: Lexer,
    alloc: Allocator,
    current: Token,
    value_map: std.AutoHashMap(u32, Value),
    block_map: std.AutoHashMap(u32, Block),

    pub fn init(alloc: Allocator, src: []const u8) !Parser {
        var lex = Lexer.init(src);
        const tok = lex.nextToken();
        return .{
            .lexer = lex,
            .alloc = alloc,
            .current = tok,
            .value_map = std.AutoHashMap(u32, Value).init(alloc),
            .block_map = std.AutoHashMap(u32, Block).init(alloc),
        };
    }

    pub fn deinit(self: *Parser) void {
        self.value_map.deinit();
        self.block_map.deinit();
    }

    fn advance(self: *Parser) void {
        self.current = self.lexer.nextToken();
        while (self.current.type == .comment) {
            self.current = self.lexer.nextToken();
        }
    }

    fn expect(self: *Parser, tt: TokenType) ParseError!Token {
        if (self.current.type != tt) return error.UnexpectedToken;
        const tok = self.current;
        self.advance();
        return tok;
    }

    fn parseType(self: *Parser) ParseError!Type {
        const tok = try self.expect(.identifier);
        if (std.mem.eql(u8, tok.lexeme, "i8")) return Type.I8;
        if (std.mem.eql(u8, tok.lexeme, "i16")) return Type.I16;
        if (std.mem.eql(u8, tok.lexeme, "i32")) return Type.I32;
        if (std.mem.eql(u8, tok.lexeme, "i64")) return Type.I64;
        if (std.mem.eql(u8, tok.lexeme, "i128")) return Type.I128;
        if (std.mem.eql(u8, tok.lexeme, "f32")) return Type.F32;
        if (std.mem.eql(u8, tok.lexeme, "f64")) return Type.F64;
        return error.InvalidType;
    }

    fn parseValue(self: *Parser) ParseError!Value {
        const tok = try self.expect(.value);
        const id = tok.entity_id orelse return error.InvalidValue;
        return self.value_map.get(id) orelse error.InvalidValue;
    }

    fn parseIntCC(self: *Parser) ParseError!IntCC {
        const tok = try self.expect(.identifier);
        if (std.mem.eql(u8, tok.lexeme, "eq")) return .eq;
        if (std.mem.eql(u8, tok.lexeme, "ne")) return .ne;
        if (std.mem.eql(u8, tok.lexeme, "slt")) return .slt;
        if (std.mem.eql(u8, tok.lexeme, "sle")) return .sle;
        if (std.mem.eql(u8, tok.lexeme, "sgt")) return .sgt;
        if (std.mem.eql(u8, tok.lexeme, "sge")) return .sge;
        if (std.mem.eql(u8, tok.lexeme, "ult")) return .ult;
        if (std.mem.eql(u8, tok.lexeme, "ule")) return .ule;
        if (std.mem.eql(u8, tok.lexeme, "ugt")) return .ugt;
        if (std.mem.eql(u8, tok.lexeme, "uge")) return .uge;
        return error.InvalidCondCode;
    }

    fn parseInt(self: *Parser) ParseError!i64 {
        const tok = try self.expect(.integer);
        return std.fmt.parseInt(i64, tok.lexeme, 10) catch return error.UnexpectedToken;
    }

    fn parseSignature(self: *Parser) ParseError!Signature {
        var sig = Signature.init(self.alloc, .fast);

        _ = try self.expect(.lparen);
        while (self.current.type != .rparen) {
            const param_ty = try self.parseType();
            try sig.params.append(self.alloc, AbiParam.new(param_ty));
            if (self.current.type == .comma) self.advance();
        }
        _ = try self.expect(.rparen);

        if (self.current.type == .arrow) {
            self.advance();
            const ret_ty = try self.parseType();
            try sig.returns.append(self.alloc, AbiParam.new(ret_ty));
        }

        return sig;
    }

    fn parseBlockHeader(self: *Parser, builder: *FunctionBuilder) ParseError!Block {
        const tok = try self.expect(.block);
        const id = tok.entity_id orelse return error.InvalidBlock;

        const blk = self.block_map.get(id) orelse blk: {
            const b = try builder.createBlock();
            try self.block_map.put(id, b);
            break :blk b;
        };

        if (self.current.type == .lparen) {
            _ = try self.expect(.lparen);
            while (self.current.type == .value) {
                const val_tok = try self.expect(.value);
                const val_id = val_tok.entity_id orelse return error.InvalidValue;
                _ = try self.expect(.colon);
                const ty = try self.parseType();

                const block_data = builder.func.dfg.blocks.getMut(blk) orelse return error.InvalidBlock;
                const num: u16 = @intCast(builder.func.dfg.value_lists.len(block_data.params));
                const val_idx = builder.func.dfg.values.elems.items.len;
                const value_data = try builder.func.dfg.values.getOrDefault(Value.new(val_idx));
                const val = Value.new(val_idx);
                value_data.* = dfg_mod.ValueData.param(ty, num, blk);
                try builder.func.dfg.value_lists.push(&block_data.params, val);
                try self.value_map.put(val_id, val);

                if (self.current.type == .comma) self.advance();
            }
            _ = try self.expect(.rparen);
        }
        _ = try self.expect(.colon);

        return blk;
    }

    fn parseInstruction(self: *Parser, builder: *FunctionBuilder) ParseError!void {
        if (self.current.type != .identifier and self.current.type != .value) return;

        var result_id: ?u32 = null;
        if (self.current.type == .value) {
            const val_tok = try self.expect(.value);
            result_id = val_tok.entity_id;
            if (self.current.type == .equal) {
                _ = try self.expect(.equal);
            } else {
                return;
            }
        }

        const op_tok = try self.expect(.identifier);
        const op = op_tok.lexeme;

        if (std.mem.eql(u8, op, "iconst")) {
            const ty = Type.I32;
            const imm = try self.parseInt();
            const val = try builder.iconst(ty, imm);
            if (result_id) |id| try self.value_map.put(id, val);
        } else if (std.mem.eql(u8, op, "iadd")) {
            const lhs = try self.parseValue();
            _ = try self.expect(.comma);
            const rhs = try self.parseValue();
            const ty = Type.I32;
            const val = try builder.iadd(ty, lhs, rhs);
            if (result_id) |id| try self.value_map.put(id, val);
        } else if (std.mem.eql(u8, op, "isub")) {
            const lhs = try self.parseValue();
            _ = try self.expect(.comma);
            const rhs = try self.parseValue();
            const ty = Type.I32;
            const val = try builder.isub(ty, lhs, rhs);
            if (result_id) |id| try self.value_map.put(id, val);
        } else if (std.mem.eql(u8, op, "icmp")) {
            const cc = try self.parseIntCC();
            const lhs = try self.parseValue();
            _ = try self.expect(.comma);
            const rhs = try self.parseValue();
            const ty = Type.I8;
            const val = try builder.icmp(ty, cc, lhs, rhs);
            if (result_id) |id| try self.value_map.put(id, val);
        } else if (std.mem.eql(u8, op, "brif")) {
            const cond = try self.parseValue();
            _ = try self.expect(.comma);
            const then_tok = try self.expect(.block);
            const then_id = then_tok.entity_id orelse return error.InvalidBlock;
            const then_blk = self.block_map.get(then_id) orelse blk: {
                const b = try builder.createBlock();
                try self.block_map.put(then_id, b);
                break :blk b;
            };
            _ = try self.expect(.comma);
            const else_tok = try self.expect(.block);
            const else_id = else_tok.entity_id orelse return error.InvalidBlock;
            const else_blk = self.block_map.get(else_id) orelse blk: {
                const b = try builder.createBlock();
                try self.block_map.put(else_id, b);
                break :blk b;
            };
            try builder.brif(cond, then_blk, else_blk);
        } else if (std.mem.eql(u8, op, "return")) {
            try builder.ret();
        } else if (std.mem.eql(u8, op, "call")) {
            const name_tok = try self.expect(.identifier);
            const func_id = try self.alloc.create(FuncRef);
            func_id.* = FuncRef.new(0);

            _ = try self.expect(.lparen);
            var args = std.ArrayList(Value){};
            defer args.deinit(self.alloc);
            while (self.current.type == .value) {
                try args.append(self.alloc, try self.parseValue());
                if (self.current.type == .comma) self.advance();
            }
            _ = try self.expect(.rparen);

            const inst_data = instruction_data_mod.InstructionData{
                .call = .{
                    .opcode = .call,
                    .func_ref = func_id.*,
                    .args = try builder.buildValueList(args.items),
                },
            };
            const inst = try builder.func.dfg.makeInst(inst_data);
            try builder.func.layout.appendInst(inst, builder.current_block orelse return error.UnexpectedToken);
            const val = try builder.func.dfg.appendInstResult(inst, Type.I32);
            if (result_id) |id| try self.value_map.put(id, val);
            _ = name_tok;
        } else {
            return error.InvalidOpcode;
        }
    }

    pub fn parseFunction(self: *Parser) ParseError!*Function {
        _ = try self.expect(.identifier);

        const name_tok = try self.expect(.string);
        const name = name_tok.lexeme[1 .. name_tok.lexeme.len - 1];

        const sig = try self.parseSignature();
        _ = try self.expect(.lbrace);

        const func = try self.alloc.create(Function);
        func.* = try Function.init(self.alloc, name, sig);
        var builder = FunctionBuilder.init(func);

        while (self.current.type == .block) {
            const blk = try self.parseBlockHeader(&builder);
            try builder.appendBlock(blk);
            try builder.switchToBlock(blk);

            while (self.current.type != .block and self.current.type != .rbrace and self.current.type != .eof) {
                try self.parseInstruction(&builder);
            }
        }

        _ = try self.expect(.rbrace);
        return func;
    }
};

test "parse add function" {
    const src =
        \\function "add" (i32, i32) -> i32 {
        \\  block0(v0: i32, v1: i32):
        \\    v2 = iadd v0, v1
        \\    return v2
        \\}
    ;

    var parser = try Parser.init(testing.allocator, src);
    defer parser.deinit();

    const func = try parser.parseFunction();
    defer {
        var f = func;
        f.sig.deinit();
        f.deinit();
        testing.allocator.destroy(func);
    }

    try testing.expectEqualStrings("add", func.name);
    try testing.expectEqual(@as(usize, 2), func.sig.params.items.len);
    try testing.expectEqual(@as(usize, 1), func.sig.returns.items.len);
}

test "parse fib function" {
    const src =
        \\function "fib" (i32) -> i32 {
        \\  block0(v0: i32):
        \\    v1 = iconst 1
        \\    v2 = icmp sle v0, v1
        \\    brif v2, block1, block2
        \\
        \\  block1:
        \\    return v0
        \\
        \\  block2:
        \\    v3 = isub v0, v1
        \\    return v3
        \\}
    ;

    var parser = try Parser.init(testing.allocator, src);
    defer parser.deinit();

    const func = try parser.parseFunction();
    defer {
        var f = func;
        f.sig.deinit();
        f.deinit();
        testing.allocator.destroy(func);
    }

    try testing.expectEqualStrings("fib", func.name);
    try testing.expectEqual(@as(usize, 1), func.sig.params.items.len);
    try testing.expectEqual(@as(usize, 1), func.sig.returns.items.len);
}
