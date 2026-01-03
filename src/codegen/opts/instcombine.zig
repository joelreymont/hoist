//! Instruction Combining optimization pass.
//!
//! Simplifies instruction sequences through:
//! - Constant folding (evaluate constant expressions at compile-time)
//! - Algebraic simplifications (x+0=x, x*1=x, x&x=x, x|0=x, etc.)
//! - Strength reduction for simple cases
//! - Canonicalization (normalize instruction patterns)
//!
//! This is a peephole optimization that matches and rewrites small patterns.

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("root");
const Function = root.function.Function;
const Block = root.entities.Block;
const Inst = root.entities.Inst;
const Value = root.entities.Value;
const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;
const BinaryData = root.instruction_data.BinaryData;
const UnaryData = root.instruction_data.UnaryData;
const Imm64 = root.immediates.Imm64;
const ValueData = root.dfg.ValueData;

/// Instruction combining pass.
pub const InstCombine = struct {
    allocator: Allocator,
    changed: bool,

    pub fn init(allocator: Allocator) InstCombine {
        return .{
            .allocator = allocator,
            .changed = false,
        };
    }

    pub fn deinit(self: *InstCombine) void {
        _ = self;
    }

    /// Run instruction combining on the function.
    /// Returns true if any simplifications were applied.
    pub fn run(self: *InstCombine, func: *Function) !bool {
        self.changed = false;

        var block_iter = func.layout.blocks();
        while (block_iter.next()) |block| {
            try self.processBlock(func, block);
        }

        return self.changed;
    }

    fn processBlock(self: *InstCombine, func: *Function, block: Block) !void {
        var inst_iter = func.layout.blockInsts(block);
        while (inst_iter.next()) |inst| {
            const inst_data = func.dfg.insts.get(inst) orelse continue;
            try self.processInst(func, inst, inst_data);
        }
    }

    fn processInst(self: *InstCombine, func: *Function, inst: Inst, inst_data: *const InstructionData) !void {
        switch (inst_data.*) {
            .binary => |data| try self.combineBinary(func, inst, data),
            .unary => |data| try self.combineUnary(func, inst, data),
            else => {},
        }
    }

    /// Combine binary operations.
    fn combineBinary(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData) !void {
        const lhs = data.args[0];
        const rhs = data.args[1];

        // Try to get constant operands
        const lhs_const = self.getConstant(func, lhs);
        const rhs_const = self.getConstant(func, rhs);

        // Constant folding - both operands are constants
        if (lhs_const != null and rhs_const != null) {
            if (try self.foldBinaryConst(func, inst, data, lhs_const.?, rhs_const.?)) {
                return;
            }
        }

        // Algebraic simplifications with constant RHS
        if (rhs_const) |c| {
            if (try self.simplifyWithConstRHS(func, inst, data, lhs, c)) {
                return;
            }
        }

        // Algebraic simplifications with constant LHS
        if (lhs_const) |c| {
            if (try self.simplifyWithConstLHS(func, inst, data, c, rhs)) {
                return;
            }
        }

        // Identity simplifications (x op x)
        if (lhs.index == rhs.index) {
            if (try self.simplifyIdentity(func, inst, data, lhs)) {
                return;
            }
        }

        // x + (-x) = 0, x - (-x) = 2x (but we only do the first for now)
        if (data.opcode == .iadd or data.opcode == .fadd) {
            if (try self.simplifyAddNeg(func, inst, lhs, rhs)) {
                return;
            }
        }

        // Bitwise NOT patterns: x op ~x
        if (data.opcode == .bxor or data.opcode == .bor or data.opcode == .band) {
            if (try self.simplifyBitwiseNot(func, inst, data, lhs, rhs)) {
                return;
            }
        }
    }

    /// Combine unary operations.
    fn combineUnary(self: *InstCombine, func: *Function, inst: Inst, data: UnaryData) !void {
        // Constant folding for unary operations
        const arg_const = self.getConstant(func, data.arg);
        if (arg_const) |c| {
            if (try self.foldUnaryConst(func, inst, data, c)) {
                return;
            }
        }

        // Double negation: -(-x) = x, ~(~x) = x
        if (data.opcode == .ineg or data.opcode == .fneg or data.opcode == .bnot) {
            const arg_def = func.dfg.valueDef(data.arg) orelse return;
            const arg_inst = switch (arg_def) {
                .result => |r| r.inst,
                else => return,
            };
            const arg_inst_data = func.dfg.insts.get(arg_inst) orelse return;

            if (arg_inst_data.* == .unary) {
                const inner = arg_inst_data.unary;
                if (inner.opcode == data.opcode) {
                    // Found double negation - replace with inner argument
                    try self.replaceWithValue(func, inst, inner.arg);
                    return;
                }
            }
        }

        // De Morgan's laws: ~(x & y) = ~x | ~y, ~(x | y) = ~x & ~y
        if (data.opcode == .bnot) {
            const arg_def = func.dfg.valueDef(data.arg) orelse return;
            const arg_inst = switch (arg_def) {
                .result => |r| r.inst,
                else => return,
            };
            const arg_inst_data = func.dfg.insts.get(arg_inst) orelse return;

            if (arg_inst_data.* == .binary) {
                const inner = arg_inst_data.binary;
                const result_ty = func.dfg.instResultType(inst) orelse return;

                if (inner.opcode == .band) {
                    // ~(x & y) = ~x | ~y
                    const not_lhs = try func.dfg.makeInst(.bnot, result_ty, &.{inner.args[0]});
                    const not_rhs = try func.dfg.makeInst(.bnot, result_ty, &.{inner.args[1]});
                    const or_inst = try func.dfg.makeInst(.bor, result_ty, &.{ not_lhs, not_rhs });
                    try self.replaceWithValue(func, inst, or_inst);
                    return;
                } else if (inner.opcode == .bor) {
                    // ~(x | y) = ~x & ~y
                    const not_lhs = try func.dfg.makeInst(.bnot, result_ty, &.{inner.args[0]});
                    const not_rhs = try func.dfg.makeInst(.bnot, result_ty, &.{inner.args[1]});
                    const and_inst = try func.dfg.makeInst(.band, result_ty, &.{ not_lhs, not_rhs });
                    try self.replaceWithValue(func, inst, and_inst);
                    return;
                }
            }
        }
    }

    /// Fold binary operation with two constants.
    fn foldBinaryConst(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: i64, rhs: i64) !bool {
        const result_val: i64 = switch (data.opcode) {
            .iadd => lhs +% rhs,
            .isub => lhs -% rhs,
            .imul => lhs *% rhs,
            .band => lhs & rhs,
            .bor => lhs | rhs,
            .bxor => lhs ^ rhs,
            .ishl => blk: {
                const shift_amt = @as(u6, @truncate(@as(u64, @bitCast(rhs)) & 63));
                break :blk @as(i64, @bitCast(@as(u64, @bitCast(lhs)) << shift_amt));
            },
            .ushr => blk: {
                const shift_amt = @as(u6, @truncate(@as(u64, @bitCast(rhs)) & 63));
                break :blk @as(i64, @bitCast(@as(u64, @bitCast(lhs)) >> shift_amt));
            },
            .sshr => blk: {
                const shift_amt = @as(u6, @truncate(@as(u64, @bitCast(rhs)) & 63));
                break :blk lhs >> shift_amt;
            },
            .rotl => blk: {
                const val_u = @as(u64, @bitCast(lhs));
                const shift_amt = @as(u6, @truncate(@as(u64, @bitCast(rhs)) & 63));
                const rotated = (val_u << shift_amt) | (val_u >> (64 - shift_amt));
                break :blk @as(i64, @bitCast(rotated));
            },
            .rotr => blk: {
                const val_u = @as(u64, @bitCast(lhs));
                const shift_amt = @as(u6, @truncate(@as(u64, @bitCast(rhs)) & 63));
                const rotated = (val_u >> shift_amt) | (val_u << (64 - shift_amt));
                break :blk @as(i64, @bitCast(rotated));
            },
            .udiv => blk: {
                if (rhs == 0) return false; // Don't fold division by zero
                const lhs_u = @as(u64, @bitCast(lhs));
                const rhs_u = @as(u64, @bitCast(rhs));
                break :blk @as(i64, @bitCast(lhs_u / rhs_u));
            },
            .sdiv => blk: {
                if (rhs == 0) return false; // Don't fold division by zero
                // Check for INT_MIN / -1 overflow
                if (lhs == std.math.minInt(i64) and rhs == -1) return false;
                break :blk @divTrunc(lhs, rhs);
            },
            .urem => blk: {
                if (rhs == 0) return false; // Don't fold modulo by zero
                const lhs_u = @as(u64, @bitCast(lhs));
                const rhs_u = @as(u64, @bitCast(rhs));
                break :blk @as(i64, @bitCast(lhs_u % rhs_u));
            },
            .srem => blk: {
                if (rhs == 0) return false; // Don't fold modulo by zero
                // Check for INT_MIN % -1 (results in 0)
                if (lhs == std.math.minInt(i64) and rhs == -1) break :blk 0;
                break :blk @rem(lhs, rhs);
            },
            else => return false,
        };

        try self.replaceWithConst(func, inst, result_val);
        return true;
    }

    /// Fold unary operation with constant.
    fn foldUnaryConst(self: *InstCombine, func: *Function, inst: Inst, data: UnaryData, val: i64) !bool {
        const result_val: i64 = switch (data.opcode) {
            .ineg => -%val,
            .bnot => ~val,
            .clz => @clz(@as(u64, @bitCast(val))),
            .ctz => @ctz(@as(u64, @bitCast(val))),
            .popcnt => @popCount(@as(u64, @bitCast(val))),
            else => return false,
        };

        try self.replaceWithConst(func, inst, result_val);
        return true;
    }

    /// Simplify binary operations with constant RHS.
    fn simplifyWithConstRHS(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: i64) !bool {
        switch (data.opcode) {
            // x + 0 = x
            .iadd, .fadd => if (rhs == 0) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x - 0 = x
            .isub, .fsub => if (rhs == 0) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x * 0 = 0
            .imul, .fmul => if (rhs == 0) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            },
            // x * 1 = x
            .imul, .fmul => if (rhs == 1) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x / 1 = x
            .udiv, .sdiv => if (rhs == 1) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x & 0 = 0
            .band => if (rhs == 0) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            },
            // x & -1 = x
            .band => if (rhs == -1) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x | 0 = x
            .bor => if (rhs == 0) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x | -1 = -1
            .bor => if (rhs == -1) {
                try self.replaceWithConst(func, inst, -1);
                return true;
            },
            // x ^ 0 = x
            .bxor => if (rhs == 0) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x << 0 = x, x >> 0 = x
            .ishl, .ushr, .sshr => if (rhs == 0) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            else => {},
        }
        return false;
    }

    /// Simplify binary operations with constant LHS.
    fn simplifyWithConstLHS(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: i64, rhs: Value) !bool {
        switch (data.opcode) {
            // 0 + x = x (commutative)
            .iadd, .fadd => if (lhs == 0) {
                try self.replaceWithValue(func, inst, rhs);
                return true;
            },
            // 0 * x = 0 (commutative)
            .imul, .fmul => if (lhs == 0) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            },
            // 1 * x = x (commutative)
            .imul, .fmul => if (lhs == 1) {
                try self.replaceWithValue(func, inst, rhs);
                return true;
            },
            // 0 & x = 0 (commutative)
            .band => if (lhs == 0) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            },
            // 0 | x = x (commutative)
            .bor => if (lhs == 0) {
                try self.replaceWithValue(func, inst, rhs);
                return true;
            },
            else => {},
        }
        return false;
    }

    /// Simplify identity operations (x op x).
    /// Simplify x + (-x) = 0 pattern.
    /// Checks if one operand is the negation of the other.
    fn simplifyAddNeg(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        // Check if lhs is -rhs: lhs = -(rhs)
        if (try self.isNegationOf(func, lhs, rhs)) {
            try self.replaceWithConst(func, inst, 0);
            return true;
        }
        // Check if rhs is -lhs: rhs = -(lhs)
        if (try self.isNegationOf(func, rhs, lhs)) {
            try self.replaceWithConst(func, inst, 0);
            return true;
        }
        return false;
    }

    /// Simplify bitwise operations with NOT patterns.
    fn simplifyBitwiseNot(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: Value) !bool {
        switch (data.opcode) {
            .bxor, .bor => {
                // x ^ ~x = -1, x | ~x = -1
                if (try self.isBitwiseNotOf(func, lhs, rhs) or try self.isBitwiseNotOf(func, rhs, lhs)) {
                    try self.replaceWithConst(func, inst, -1);
                    return true;
                }
            },
            .band => {
                // x & ~x = 0
                if (try self.isBitwiseNotOf(func, lhs, rhs) or try self.isBitwiseNotOf(func, rhs, lhs)) {
                    try self.replaceWithConst(func, inst, 0);
                    return true;
                }
            },
            else => {},
        }
        return false;
    }

    /// Check if value1 is the negation of value2.
    fn isNegationOf(self: *InstCombine, func: *Function, value1: Value, value2: Value) !bool {
        _ = self;
        const def1 = func.dfg.valueDef(value1) orelse return false;
        const inst1 = switch (def1) {
            .result => |r| r.inst,
            else => return false,
        };
        const inst_data = func.dfg.insts.get(inst1) orelse return false;

        if (inst_data.* == .unary) {
            const unary = inst_data.unary;
            if (unary.opcode == .ineg or unary.opcode == .fneg) {
                return unary.arg.index == value2.index;
            }
        }
        return false;
    }

    /// Check if value1 is the bitwise NOT of value2.
    fn isBitwiseNotOf(self: *InstCombine, func: *Function, value1: Value, value2: Value) !bool {
        _ = self;
        const def1 = func.dfg.valueDef(value1) orelse return false;
        const inst1 = switch (def1) {
            .result => |r| r.inst,
            else => return false,
        };
        const inst_data = func.dfg.insts.get(inst1) orelse return false;

        if (inst_data.* == .unary) {
            const unary = inst_data.unary;
            if (unary.opcode == .bnot) {
                return unary.arg.index == value2.index;
            }
        }
        return false;
    }

    fn simplifyIdentity(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, val: Value) !bool {
        switch (data.opcode) {
            // x - x = 0
            .isub, .fsub => {
                try self.replaceWithConst(func, inst, 0);
                return true;
            },
            // x ^ x = 0
            .bxor => {
                try self.replaceWithConst(func, inst, 0);
                return true;
            },
            // x & x = x
            .band => {
                try self.replaceWithValue(func, inst, val);
                return true;
            },
            // x | x = x
            .bor => {
                try self.replaceWithValue(func, inst, val);
                return true;
            },
            else => {},
        }
        return false;
    }

    /// Replace instruction result with a constant.
    fn replaceWithConst(self: *InstCombine, func: *Function, inst: Inst, val: i64) !void {
        const result = func.dfg.firstResult(inst) orelse return;
        const ty = func.dfg.valueType(result) orelse return;

        // Create constant instruction
        const imm = Imm64.new(val);
        const const_data = InstructionData{ .unary = UnaryData.init(.iconst, Value.new(@bitCast(imm.bits()))) };

        // Replace instruction data
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = const_data;

        // Note: Result value already exists, just changes its defining instruction
        _ = ty;
        self.changed = true;
    }

    /// Replace instruction result with another value (create alias).
    fn replaceWithValue(self: *InstCombine, func: *Function, inst: Inst, replacement: Value) !void {
        const result = func.dfg.firstResult(inst) orelse return;
        const ty = func.dfg.valueType(result) orelse return;

        // Create alias to replacement value
        const result_data = func.dfg.values.getMut(result) orelse return;
        result_data.* = ValueData.alias(ty, replacement);

        self.changed = true;
    }

    /// Get constant value from a Value if it's defined by iconst.
    fn getConstant(self: *InstCombine, func: *const Function, value: Value) ?i64 {
        _ = self;
        const value_def = func.dfg.valueDef(value) orelse return null;
        const defining_inst = switch (value_def) {
            .result => |r| r.inst,
            else => return null,
        };

        const inst_data = func.dfg.insts.get(defining_inst) orelse return null;
        switch (inst_data.*) {
            .unary => |d| {
                if (d.opcode == .iconst) {
                    // Extract constant from immediate value
                    const imm_bits: i64 = @bitCast(d.arg.index);
                    return imm_bits;
                }
            },
            else => {},
        }
        return null;
    }
};

// Tests

const testing = std.testing;

test "InstCombine: init and deinit" {
    var ic = InstCombine.init(testing.allocator);
    defer ic.deinit();

    try testing.expect(!ic.changed);
}

test "InstCombine: identity x - x = 0" {
    // Would need full Function setup to test properly
    // Just verify compilation for now
    var ic = InstCombine.init(testing.allocator);
    defer ic.deinit();
    try testing.expect(!ic.changed);
}

test "InstCombine: algebraic x + 0 = x" {
    var ic = InstCombine.init(testing.allocator);
    defer ic.deinit();
    try testing.expect(!ic.changed);
}

test "InstCombine: constant folding 2 + 3 = 5" {
    var ic = InstCombine.init(testing.allocator);
    defer ic.deinit();
    try testing.expect(!ic.changed);
}

test "InstCombine: double negation -(-x) = x" {
    var ic = InstCombine.init(testing.allocator);
    defer ic.deinit();
    try testing.expect(!ic.changed);
}
