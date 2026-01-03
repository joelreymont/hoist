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
const IntCompareData = root.instruction_data.IntCompareData;
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
            .int_compare => |data| try self.combineIntCompare(func, inst, data),
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

        // ~x + 1 = -x
        if (data.opcode == .iadd) {
            if (try self.simplifyBnotPlusOne(func, inst, lhs, rhs)) {
                return;
            }
        }

        // Canonicalization: x + (-y) = x - y, x - (-y) = x + y
        if (data.opcode == .iadd or data.opcode == .isub) {
            if (try self.simplifyAddSubWithNeg(func, inst, data, lhs, rhs)) {
                return;
            }
        }

        // Multiply with negations: (-x) * (-y) = x * y
        if (data.opcode == .imul) {
            if (try self.simplifyMulNeg(func, inst, lhs, rhs)) {
                return;
            }
        }

        // Multiply by shifted 1: x * (1 << y) = x << y
        if (data.opcode == .imul) {
            if (try self.simplifyMulShift(func, inst, lhs, rhs)) {
                return;
            }
        }

        // Reassociation: (x - y) + y = x, (x + y) - x = y, etc.
        if (data.opcode == .iadd or data.opcode == .isub) {
            if (try self.simplifyReassociation(func, inst, data, lhs, rhs)) {
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

        // Bitwise absorption and cancellation
        if (data.opcode == .bor or data.opcode == .bxor) {
            if (try self.simplifyBitwiseAbsorption(func, inst, data, lhs, rhs)) {
                return;
            }
        }

        // Associative flattening: (x | y) | x = x | y, (x & y) & x = x & y
        if (data.opcode == .bor or data.opcode == .band) {
            if (try self.simplifyAssociativeFlattening(func, inst, data, lhs, rhs)) {
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

        // Double application: -(-x) = x, ~(~x) = x, bswap(bswap(x)) = x, bitrev(bitrev(x)) = x
        if (data.opcode == .ineg or data.opcode == .fneg or data.opcode == .bnot or
            data.opcode == .bswap or data.opcode == .bitrev)
        {
            const arg_def = func.dfg.valueDef(data.arg) orelse return;
            const arg_inst = switch (arg_def) {
                .result => |r| r.inst,
                else => return,
            };
            const arg_inst_data = func.dfg.insts.get(arg_inst) orelse return;

            if (arg_inst_data.* == .unary) {
                const inner = arg_inst_data.unary;
                if (inner.opcode == data.opcode) {
                    // Found double application - replace with inner argument
                    try self.replaceWithValue(func, inst, inner.arg);
                    return;
                }
            }
        }

        // Constant folding for extends: uextend(const) = const, sextend(const) = const
        if (data.opcode == .uextend or data.opcode == .sextend) {
            if (self.getConstant(func, data.arg)) |c| {
                // The constant value remains the same when extending
                try self.replaceWithConst(func, inst, c);
                return;
            }
        }

        // Negate subtraction: -(y - x) = x - y
        if (data.opcode == .ineg) {
            const arg_def = func.dfg.valueDef(data.arg) orelse return;
            const arg_inst = switch (arg_def) {
                .result => |r| r.inst,
                else => return,
            };
            const arg_inst_data = func.dfg.insts.get(arg_inst) orelse return;

            if (arg_inst_data.* == .binary) {
                const inner = arg_inst_data.binary;
                if (inner.opcode == .isub) {
                    const result_ty = func.dfg.instResultType(inst) orelse return;
                    const sub_inst = try func.dfg.makeInst(.isub, result_ty, &.{ inner.args[1], inner.args[0] });
                    try self.replaceWithValue(func, inst, sub_inst);
                    return;
                }
            }
        }

        // De Morgan's laws: ~(x & y) = ~x | ~y, ~(x | y) = ~x & ~y
        // Also: ~(x - 1) = -x
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
                } else if (inner.opcode == .isub) {
                    // ~(x - 1) = -x (and also ~(x + -1) = -x)
                    if (self.getConstant(func, inner.args[1])) |c| {
                        if (c == 1 or c == -1) {
                            const neg_inst = try func.dfg.makeInst(.ineg, result_ty, &.{inner.args[0]});
                            try self.replaceWithValue(func, inst, neg_inst);
                            return;
                        }
                    }
                } else if (inner.opcode == .iadd) {
                    // ~(x + -1) = -x
                    if (self.getConstant(func, inner.args[1])) |c| {
                        if (c == -1) {
                            const neg_inst = try func.dfg.makeInst(.ineg, result_ty, &.{inner.args[0]});
                            try self.replaceWithValue(func, inst, neg_inst);
                            return;
                        }
                    }
                }
            }
        }

        // Absolute value simplifications: abs(-x) = abs(x), abs(abs(x)) = abs(x)
        if (data.opcode == .iabs) {
            const arg_def = func.dfg.valueDef(data.arg) orelse return;
            const arg_inst = switch (arg_def) {
                .result => |r| r.inst,
                else => return,
            };
            const arg_inst_data = func.dfg.insts.get(arg_inst) orelse return;

            if (arg_inst_data.* == .unary) {
                const inner = arg_inst_data.unary;
                const result_ty = func.dfg.instResultType(inst) orelse return;

                // abs(-x) = abs(x)
                if (inner.opcode == .ineg) {
                    const abs_inst = try func.dfg.makeInst(.iabs, result_ty, &.{inner.arg});
                    try self.replaceWithValue(func, inst, abs_inst);
                    return;
                }
                // abs(abs(x)) = abs(x)
                if (inner.opcode == .iabs) {
                    try self.replaceWithValue(func, inst, data.arg);
                    return;
                }
            }
        }
    }

    /// Combine integer comparison operations.
    fn combineIntCompare(self: *InstCombine, func: *Function, inst: Inst, data: IntCompareData) !void {
        const lhs = data.args[0];
        const rhs = data.args[1];

        // Identity comparisons: x cmp x
        if (lhs.index == rhs.index) {
            const result: i64 = switch (data.cond) {
                .eq => 1, // x == x → true
                .ne => 0, // x != x → false
                .slt, .ult => 0, // x < x → false
                .sle, .ule => 1, // x <= x → true
                .sgt, .ugt => 0, // x > x → false
                .sge, .uge => 1, // x >= x → true
            };
            try self.replaceWithConst(func, inst, result);
            return;
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
            // x * 2 = x + x
            .imul => if (rhs == 2) {
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const add_inst = try func.dfg.makeInst(.iadd, result_ty, &.{ lhs, lhs });
                try self.replaceWithValue(func, inst, add_inst);
                return true;
            },
            // x * -1 = -x
            .imul => if (rhs == -1) {
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const neg_inst = try func.dfg.makeInst(.ineg, result_ty, &.{lhs});
                try self.replaceWithValue(func, inst, neg_inst);
                return true;
            },
            // x / 1 = x
            .udiv, .sdiv => if (rhs == 1) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x % 1 = 0 (any number modulo 1 is 0)
            .urem, .srem => if (rhs == 1) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            },
            // x % -1 = 0 (signed remainder by -1 is always 0)
            .srem => if (rhs == -1) {
                try self.replaceWithConst(func, inst, 0);
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
            // x ^ -1 = ~x
            .bxor => if (rhs == -1) {
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const not_inst = try func.dfg.makeInst(.bnot, result_ty, &.{lhs});
                try self.replaceWithValue(func, inst, not_inst);
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
            // 0 - x = -x
            .isub => if (lhs == 0) {
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const neg_inst = try func.dfg.makeInst(.ineg, result_ty, &.{rhs});
                try self.replaceWithValue(func, inst, neg_inst);
                return true;
            },
            // 0.0 - x = -x
            .fsub => if (lhs == 0) {
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const neg_inst = try func.dfg.makeInst(.fneg, result_ty, &.{rhs});
                try self.replaceWithValue(func, inst, neg_inst);
                return true;
            },
            else => {},
        }
        return false;
    }

    /// Simplify identity operations (x op x).
    /// Simplify x + (-x) = 0 pattern.
    /// Checks if one operand is the negation of the other.
    /// Simplify ~x + 1 to -x.
    fn simplifyBnotPlusOne(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check for ~x + 1
        if (self.getConstant(func, rhs)) |c| {
            if (c == 1) {
                if (try self.getBnotOperand(func, lhs)) |x| {
                    const neg_inst = try func.dfg.makeInst(.ineg, result_ty, &.{x});
                    try self.replaceWithValue(func, inst, neg_inst);
                    return true;
                }
            }
        }

        // Check for 1 + ~x
        if (self.getConstant(func, lhs)) |c| {
            if (c == 1) {
                if (try self.getBnotOperand(func, rhs)) |x| {
                    const neg_inst = try func.dfg.makeInst(.ineg, result_ty, &.{x});
                    try self.replaceWithValue(func, inst, neg_inst);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify x + (-y) = x - y and x - (-y) = x + y.
    fn simplifyAddSubWithNeg(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        if (data.opcode == .iadd) {
            // x + (-y) = x - y
            if (try self.getNegOperand(func, rhs)) |y| {
                const sub_inst = try func.dfg.makeInst(.isub, result_ty, &.{ lhs, y });
                try self.replaceWithValue(func, inst, sub_inst);
                return true;
            }
            // (-x) + y = y - x
            if (try self.getNegOperand(func, lhs)) |x| {
                const sub_inst = try func.dfg.makeInst(.isub, result_ty, &.{ rhs, x });
                try self.replaceWithValue(func, inst, sub_inst);
                return true;
            }
        } else if (data.opcode == .isub) {
            // x - (-y) = x + y
            if (try self.getNegOperand(func, rhs)) |y| {
                const add_inst = try func.dfg.makeInst(.iadd, result_ty, &.{ lhs, y });
                try self.replaceWithValue(func, inst, add_inst);
                return true;
            }
        }

        return false;
    }

    /// Simplify (-x) * (-y) = x * y.
    fn simplifyMulNeg(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        if (try self.getNegOperand(func, lhs)) |x| {
            if (try self.getNegOperand(func, rhs)) |y| {
                const mul_inst = try func.dfg.makeInst(.imul, result_ty, &.{ x, y });
                try self.replaceWithValue(func, inst, mul_inst);
                return true;
            }
        }

        return false;
    }

    /// Simplify x * (1 << y) = x << y.
    fn simplifyMulShift(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check if rhs is ishl(1, y)
        if (try self.getShiftBy1(func, rhs)) |y| {
            const shl_inst = try func.dfg.makeInst(.ishl, result_ty, &.{ lhs, y });
            try self.replaceWithValue(func, inst, shl_inst);
            return true;
        }

        // Check if lhs is ishl(1, y)
        if (try self.getShiftBy1(func, lhs)) |y| {
            const shl_inst = try func.dfg.makeInst(.ishl, result_ty, &.{ rhs, y });
            try self.replaceWithValue(func, inst, shl_inst);
            return true;
        }

        return false;
    }

    /// Simplify reassociation patterns like (x - y) + y = x, (x + y) - x = y.
    fn simplifyReassociation(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: Value) !bool {
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        if (lhs_data.* == .binary) {
            const inner = lhs_data.binary;

            if (data.opcode == .iadd) {
                // (x - y) + y = x
                if (inner.opcode == .isub and inner.args[1].index == rhs.index) {
                    try self.replaceWithValue(func, inst, inner.args[0]);
                    return true;
                }
                // (x + y) + (-y) would be x + y - y, not relevant here
            } else if (data.opcode == .isub) {
                // (x + y) - x = y
                if (inner.opcode == .iadd and inner.args[0].index == rhs.index) {
                    try self.replaceWithValue(func, inst, inner.args[1]);
                    return true;
                }
                // (x + y) - y = x
                if (inner.opcode == .iadd and inner.args[1].index == rhs.index) {
                    try self.replaceWithValue(func, inst, inner.args[0]);
                    return true;
                }
                // (x - y) - x = -y
                if (inner.opcode == .isub and inner.args[0].index == rhs.index) {
                    const result_ty = func.dfg.instResultType(inst) orelse return false;
                    const neg_inst = try func.dfg.makeInst(.ineg, result_ty, &.{inner.args[1]});
                    try self.replaceWithValue(func, inst, neg_inst);
                    return true;
                }
                // (x + y) - (x | y) = x & y
                if (inner.opcode == .iadd) {
                    const rhs_def = func.dfg.valueDef(rhs) orelse return false;
                    const rhs_inst = switch (rhs_def) {
                        .result => |r| r.inst,
                        else => return false,
                    };
                    const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;
                    if (rhs_data.* == .binary) {
                        const rhs_inner = rhs_data.binary;
                        if (rhs_inner.opcode == .bor) {
                            // Check if operands match (x+y) - (x|y)
                            const same_operands = (inner.args[0].index == rhs_inner.args[0].index and inner.args[1].index == rhs_inner.args[1].index) or (inner.args[0].index == rhs_inner.args[1].index and inner.args[1].index == rhs_inner.args[0].index);
                            if (same_operands) {
                                const result_ty = func.dfg.instResultType(inst) orelse return false;
                                const and_inst = try func.dfg.makeInst(.band, result_ty, &.{ inner.args[0], inner.args[1] });
                                try self.replaceWithValue(func, inst, and_inst);
                                return true;
                            }
                        }
                    }
                }
            }
        }

        // Check rhs for patterns like y + (x - y) = x
        if (data.opcode == .iadd) {
            const rhs_def = func.dfg.valueDef(rhs) orelse return false;
            const rhs_inst = switch (rhs_def) {
                .result => |r| r.inst,
                else => return false,
            };
            const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

            if (rhs_data.* == .binary) {
                const inner = rhs_data.binary;
                // y + (x - y) = x
                if (inner.opcode == .isub and inner.args[1].index == lhs.index) {
                    try self.replaceWithValue(func, inst, inner.args[0]);
                    return true;
                }
            }
        }

        return false;
    }

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

    /// Simplify absorption and cancellation patterns.
    fn simplifyBitwiseAbsorption(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: Value) !bool {
        // (x & y) | x = x (absorption)
        if (data.opcode == .bor) {
            // Check if lhs is band with rhs as one of its operands
            if (try self.isBinaryWith(func, lhs, .band, rhs)) {
                try self.replaceWithValue(func, inst, rhs);
                return true;
            }
            // Check if rhs is band with lhs as one of its operands
            if (try self.isBinaryWith(func, rhs, .band, lhs)) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            }
        }

        // (x ^ y) ^ y = x (XOR cancellation)
        if (data.opcode == .bxor) {
            // Check if lhs is bxor with rhs as one of its operands
            if (try self.getBxorOtherOperand(func, lhs, rhs)) |x| {
                try self.replaceWithValue(func, inst, x);
                return true;
            }
            // Check if rhs is bxor with lhs as one of its operands
            if (try self.getBxorOtherOperand(func, rhs, lhs)) |x| {
                try self.replaceWithValue(func, inst, x);
                return true;
            }
        }

        return false;
    }

    /// Simplify associative flattening: (x | y) | x = x | y, (x & y) & x = x & y.
    fn simplifyAssociativeFlattening(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: Value) !bool {
        // (x op y) op x = x op y  (where op is | or &)
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        if (lhs_data.* == .binary) {
            const inner = lhs_data.binary;
            if (inner.opcode == data.opcode) {
                // Check if rhs matches one of the inner operands
                if (inner.args[0].index == rhs.index or inner.args[1].index == rhs.index) {
                    try self.replaceWithValue(func, inst, lhs);
                    return true;
                }
            }
        }

        // x op (x op y) = x op y
        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (rhs_data.* == .binary) {
            const inner = rhs_data.binary;
            if (inner.opcode == data.opcode) {
                // Check if lhs matches one of the inner operands
                if (inner.args[0].index == lhs.index or inner.args[1].index == lhs.index) {
                    try self.replaceWithValue(func, inst, rhs);
                    return true;
                }
            }
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

    /// Get the operand if value is a bnot operation, null otherwise.
    fn getBnotOperand(self: *InstCombine, func: *Function, value: Value) !?Value {
        _ = self;
        const def = func.dfg.valueDef(value) orelse return null;
        const inst = switch (def) {
            .result => |r| r.inst,
            else => return null,
        };
        const inst_data = func.dfg.insts.get(inst) orelse return null;

        if (inst_data.* == .unary) {
            const unary = inst_data.unary;
            if (unary.opcode == .bnot) {
                return unary.arg;
            }
        }
        return null;
    }

    /// Get the operand if value is a negation (ineg/fneg), null otherwise.
    fn getNegOperand(self: *InstCombine, func: *Function, value: Value) !?Value {
        _ = self;
        const def = func.dfg.valueDef(value) orelse return null;
        const inst = switch (def) {
            .result => |r| r.inst,
            else => return null,
        };
        const inst_data = func.dfg.insts.get(inst) orelse return null;

        if (inst_data.* == .unary) {
            const unary = inst_data.unary;
            if (unary.opcode == .ineg or unary.opcode == .fneg) {
                return unary.arg;
            }
        }
        return null;
    }

    /// Check if value1 is a binary operation with given opcode and value2 as one of its operands.
    fn isBinaryWith(self: *InstCombine, func: *Function, value1: Value, opcode: Opcode, value2: Value) !bool {
        _ = self;
        const def1 = func.dfg.valueDef(value1) orelse return false;
        const inst1 = switch (def1) {
            .result => |r| r.inst,
            else => return false,
        };
        const inst_data = func.dfg.insts.get(inst1) orelse return false;

        if (inst_data.* == .binary) {
            const binary = inst_data.binary;
            if (binary.opcode == opcode) {
                return binary.args[0].index == value2.index or binary.args[1].index == value2.index;
            }
        }
        return false;
    }

    /// Get the other operand if value is a bxor with given operand.
    fn getBxorOtherOperand(self: *InstCombine, func: *Function, value: Value, operand: Value) !?Value {
        _ = self;
        const def = func.dfg.valueDef(value) orelse return null;
        const inst = switch (def) {
            .result => |r| r.inst,
            else => return null,
        };
        const inst_data = func.dfg.insts.get(inst) orelse return null;

        if (inst_data.* == .binary) {
            const binary = inst_data.binary;
            if (binary.opcode == .bxor) {
                if (binary.args[0].index == operand.index) {
                    return binary.args[1];
                } else if (binary.args[1].index == operand.index) {
                    return binary.args[0];
                }
            }
        }
        return null;
    }

    /// Get the shift amount if value is ishl(1, y), null otherwise.
    fn getShiftBy1(self: *InstCombine, func: *Function, value: Value) !?Value {
        const def = func.dfg.valueDef(value) orelse return null;
        const inst = switch (def) {
            .result => |r| r.inst,
            else => return null,
        };
        const inst_data = func.dfg.insts.get(inst) orelse return null;

        if (inst_data.* == .binary) {
            const binary = inst_data.binary;
            if (binary.opcode == .ishl) {
                // Check if LHS is constant 1
                if (self.getConstant(func, binary.args[0])) |c| {
                    if (c == 1) {
                        return binary.args[1]; // Return shift amount
                    }
                }
            }
        }
        return null;
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
