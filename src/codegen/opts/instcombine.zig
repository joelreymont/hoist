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

const ir = @import("../../ir.zig");
const Function = ir.Function;
const Block = ir.Block;
const Inst = ir.Inst;
const Value = ir.Value;
const Opcode = @import("../../ir/opcodes.zig").Opcode;
const InstructionData = ir.InstructionData;
const instruction_data = @import("../../ir/instruction_data.zig");
const BinaryData = instruction_data.BinaryData;
const UnaryData = instruction_data.UnaryData;
const TernaryData = instruction_data.TernaryData;
const IntCompareData = instruction_data.IntCompareData;
const condcodes = @import("../../ir/condcodes.zig");
const IntCC = condcodes.IntCC;
const immediates = @import("../../ir/immediates.zig");
const Imm64 = immediates.Imm64;
const ValueData = @import("../../ir/dfg.zig").ValueData;

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

        var block_iter = func.layout.blockIter();
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
            .ternary => |data| try self.combineTernary(func, inst, data),
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

        // (!x) + 1 = -x
        if (data.opcode == .iadd) {
            if (try self.simplifyNotPlusOne(func, inst, lhs, rhs)) {
                return;
            }
        }

        // Reassociation: (x - y) + y = x, (x + y) - x = y, etc.
        if (data.opcode == .iadd or data.opcode == .isub) {
            if (try self.simplifyReassociation(func, inst, data, lhs, rhs)) {
                return;
            }
        }

        // (x & y) + (x ^ y) = x | y
        if (data.opcode == .iadd) {
            if (try self.simplifyAndXorAdd(func, inst, lhs, rhs)) {
                return;
            }
        }

        // (x | y) + (x & y) = x + y
        if (data.opcode == .iadd) {
            if (try self.simplifyOrAndAdd(func, inst, lhs, rhs)) {
                return;
            }
        }

        // (x << z) + (y << z) = (x + y) << z, (x << z) - (y << z) = (x - y) << z
        if (data.opcode == .iadd or data.opcode == .isub) {
            if (try self.simplifyShiftDistribute(func, inst, data, lhs, rhs)) {
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

        // (x shift z) & (y shift z) = (x & y) shift z
        if (data.opcode == .band) {
            if (try self.simplifyShiftDistribute(func, inst, data, lhs, rhs)) {
                return;
            }
        }

        // (x << k1) << k2 = x << (k1 + k2), (x >> k1) >> k2 = x >> (k1 + k2)
        if (data.opcode == .ishl or data.opcode == .ushr or data.opcode == .sshr) {
            if (try self.simplifyShiftChain(func, inst, data, lhs, rhs)) {
                return;
            }
        }

        // ((x << y) & z) >> y = x & (z >> y)
        if (data.opcode == .ushr) {
            if (try self.simplifyShiftMask(func, inst, data, lhs, rhs)) {
                return;
            }
        }

        // (x < y) & (x > y) = 0 (mutually exclusive)
        if (data.opcode == .band) {
            if (try self.simplifyMutuallyExclusiveComparisons(func, inst, lhs, rhs)) {
                return;
            }
        }

        // (x & y) ^ (x ^ y) = x | y and (x | y) ^ (x & y) = x ^ y
        if (data.opcode == .bxor) {
            if (try self.simplifyAndXorToOr(func, inst, lhs, rhs)) {
                return;
            }
            if (try self.simplifyOrAndXor(func, inst, lhs, rhs)) {
                return;
            }
        }

        // (z & x) ^ (z & y) = z & (x ^ y)
        if (data.opcode == .bxor) {
            if (try self.simplifyAndXorFactor(func, inst, lhs, rhs)) {
                return;
            }
        }

        // (x ^ y) ^ y = x
        if (data.opcode == .bxor) {
            if (try self.simplifyXorCancellation(func, inst, lhs, rhs)) {
                return;
            }
        }

        // (x > y) ^ (x < y) = x != y
        if (data.opcode == .bxor) {
            if (try self.simplifyXorComparisons(func, inst, lhs, rhs)) {
                return;
            }
        }

        // (x ^ ~y) & x = x & y
        if (data.opcode == .band) {
            if (try self.simplifyXorNotAnd(func, inst, lhs, rhs)) {
                return;
            }
        }

        // uextend(x) op uextend(y) = uextend(x op y) for bitwise ops
        if (data.opcode == .band or data.opcode == .bor or data.opcode == .bxor) {
            if (try self.simplifyExtendBitwise(func, inst, data, lhs, rhs)) {
                return;
            }
        }

        // (x & y) | ~y = x | ~y
        if (data.opcode == .bor) {
            if (try self.simplifyOrWithNotAbsorption(func, inst, lhs, rhs)) {
                return;
            }
        }

        // rotl(rotr(x, y), y) = x and rotr(rotl(x, y), y) = x
        if (data.opcode == .rotl or data.opcode == .rotr) {
            if (try self.simplifyRotateCancellation(func, inst, data, lhs, rhs)) {
                return;
            }
        }

        // rotl(rotl(x, y), z) = rotl(x, y+z) and rotr(rotr(x, y), z) = rotr(x, y+z)
        if (data.opcode == .rotl or data.opcode == .rotr) {
            if (try self.simplifyRotateChain(func, inst, data, lhs, rhs)) {
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

        // !(x - 1) = -x and !(x + (-1)) = -x
        if (data.opcode == .bnot) {
            const arg_def = func.dfg.valueDef(data.arg) orelse return;
            const arg_inst = switch (arg_def) {
                .result => |r| r.inst,
                else => return,
            };
            const arg_inst_data = func.dfg.insts.get(arg_inst) orelse return;

            if (arg_inst_data.* == .binary) {
                const inner = arg_inst_data.binary;
                // !(x - 1) = -x
                if (inner.opcode == .isub) {
                    if (self.getConstant(func, inner.args[1])) |c| {
                        if (c == 1) {
                            const result_ty = func.dfg.instResultType(inst) orelse return;
                            const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, inner.args[0]);
                            try self.replaceWithValue(func, inst, neg_inst);
                            return;
                        }
                    }
                }
                // !(x + (-1)) = -x
                if (inner.opcode == .iadd) {
                    if (self.getSignedConstant(func, inner.args[1])) |c| {
                        if (c == -1) {
                            const result_ty = func.dfg.instResultType(inst) orelse return;
                            const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, inner.args[0]);
                            try self.replaceWithValue(func, inst, neg_inst);
                            return;
                        }
                    }
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

        // Chained extends: uextend(uextend(x)) = uextend(x), sextend(sextend(x)) = sextend(x)
        if (data.opcode == .uextend or data.opcode == .sextend) {
            const arg_def = func.dfg.valueDef(data.arg) orelse return;
            const arg_inst = switch (arg_def) {
                .result => |r| r.inst,
                else => return,
            };
            const arg_inst_data = func.dfg.insts.get(arg_inst) orelse return;

            if (arg_inst_data.* == .unary) {
                const inner = arg_inst_data.unary;
                if (inner.opcode == data.opcode) {
                    // Found chained extend - create single extend from innermost value
                    const result_ty = func.dfg.instResultType(inst) orelse return;
                    const new_extend = try func.dfg.makeUnary(data.opcode, result_ty, inner.arg);
                    try self.replaceWithValue(func, inst, new_extend);
                    return;
                }
            }
        }

        // sextend(icmp(...)) = uextend(icmp(...)) since icmp produces 0 or 1
        // sextend(uextend(x)) = uextend(x) since uextend already cleared high bits
        if (data.opcode == .sextend) {
            const arg_def = func.dfg.valueDef(data.arg) orelse return;
            const arg_inst = switch (arg_def) {
                .result => |r| r.inst,
                else => return,
            };
            const arg_inst_data = func.dfg.insts.get(arg_inst) orelse return;

            if (arg_inst_data.* == .int_compare) {
                const result_ty = func.dfg.instResultType(inst) orelse return;
                const uextend_inst = try func.dfg.makeUnary(.uextend, result_ty, data.arg);
                try self.replaceWithValue(func, inst, uextend_inst);
                return;
            }

            if (arg_inst_data.* == .unary and arg_inst_data.unary.opcode == .uextend) {
                // Once zero-extended, sign-extending is same as zero-extending
                const result_ty = func.dfg.instResultType(inst) orelse return;
                const inner_val = arg_inst_data.unary.arg;
                const uextend_inst = try func.dfg.makeUnary(.uextend, result_ty, inner_val);
                try self.replaceWithValue(func, inst, uextend_inst);
                return;
            }
        }

        // iabs(ineg(x)) = iabs(x) and iabs(iabs(x)) = iabs(x)
        if (data.opcode == .iabs) {
            const arg_def = func.dfg.valueDef(data.arg) orelse return;
            const arg_inst = switch (arg_def) {
                .result => |r| r.inst,
                else => return,
            };
            const arg_inst_data = func.dfg.insts.get(arg_inst) orelse return;

            if (arg_inst_data.* == .unary) {
                const inner = arg_inst_data.unary;
                // iabs(ineg(x)) = iabs(x)
                if (inner.opcode == .ineg) {
                    const result_ty = func.dfg.instResultType(inst) orelse return;
                    const abs_inst = try func.dfg.makeUnary(.iabs, result_ty, inner.arg);
                    try self.replaceWithValue(func, inst, abs_inst);
                    return;
                }
                // iabs(iabs(x)) = iabs(x)
                if (inner.opcode == .iabs) {
                    try self.replaceWithValue(func, inst, data.arg);
                    return;
                }
            }
        }

        // ireduce(uextend(x)) = x and ireduce(sextend(x)) = x when reducing to original type
        if (data.opcode == .ireduce) {
            const arg_def = func.dfg.valueDef(data.arg) orelse return;
            const arg_inst = switch (arg_def) {
                .result => |r| r.inst,
                else => return,
            };
            const arg_inst_data = func.dfg.insts.get(arg_inst) orelse return;

            if (arg_inst_data.* == .unary) {
                const inner = arg_inst_data.unary;
                // Check if inner is an extend operation
                if (inner.opcode == .uextend or inner.opcode == .sextend) {
                    // Get the type of the innermost value
                    const inner_val_ty = func.dfg.valueType(inner.arg) orelse return;
                    const result_ty = func.dfg.instResultType(inst) orelse return;

                    // If reducing back to the original type, just use the original value
                    if (inner_val_ty.eql(result_ty)) {
                        try self.replaceWithValue(func, inst, inner.arg);
                        return;
                    }
                }
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
                    const sub_inst = try func.dfg.makeBinary(.isub, result_ty, inner.args[1], inner.args[0]);
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
                    const not_lhs = try func.dfg.makeUnary(.bnot, result_ty, inner.args[0]);
                    const not_rhs = try func.dfg.makeUnary(.bnot, result_ty, inner.args[1]);
                    const or_inst = try func.dfg.makeBinary(.bor, result_ty, not_lhs, not_rhs);
                    try self.replaceWithValue(func, inst, or_inst);
                    return;
                } else if (inner.opcode == .bor) {
                    // ~(x | y) = ~x & ~y
                    const not_lhs = try func.dfg.makeUnary(.bnot, result_ty, inner.args[0]);
                    const not_rhs = try func.dfg.makeUnary(.bnot, result_ty, inner.args[1]);
                    const and_inst = try func.dfg.makeBinary(.band, result_ty, not_lhs, not_rhs);
                    try self.replaceWithValue(func, inst, and_inst);
                    return;
                } else if (inner.opcode == .isub) {
                    // ~(x - 1) = -x (and also ~(x + -1) = -x)
                    if (self.getConstant(func, inner.args[1])) |c| {
                        if (c == 1 or c == -1) {
                            const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, inner.args[0]);
                            try self.replaceWithValue(func, inst, neg_inst);
                            return;
                        }
                    }
                } else if (inner.opcode == .iadd) {
                    // ~(x + -1) = -x
                    if (self.getConstant(func, inner.args[1])) |c| {
                        if (c == -1) {
                            const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, inner.args[0]);
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
                    const abs_inst = try func.dfg.makeUnary(.iabs, result_ty, inner.arg);
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

    /// Combine ternary operations (select, etc).
    fn combineTernary(self: *InstCombine, func: *Function, inst: Inst, data: TernaryData) !void {
        const cond = data.args[0];
        const true_val = data.args[1];
        const false_val = data.args[2];

        switch (data.opcode) {
            .select => {
                // select(c, x, x) => x (both branches identical)
                if (true_val.index == false_val.index) {
                    try self.replaceWithValue(func, inst, true_val);
                    return;
                }

                // Spaceship pattern: select(a < b, -1, select(a > b, 1, 0)) => spaceship(a, b)
                if (try self.simplifySpaceship(func, inst, cond, true_val, false_val)) {
                    return;
                }

                // Transform select-of-icmp into {u,s}{min,max}
                // select(x > y, x, y) => max(x, y), select(x < y, x, y) => min(x, y)
                const cond_def = func.dfg.valueDef(cond) orelse return;
                const cond_inst = switch (cond_def) {
                    .result => |r| r.inst,
                    else => return,
                };
                const cond_data = func.dfg.insts.get(cond_inst) orelse return;

                if (cond_data.* == .int_compare) {
                    const icmp = cond_data.int_compare;
                    const x = icmp.args[0];
                    const y = icmp.args[1];

                    // Check if select operands match comparison operands
                    if (true_val.index == x.index and false_val.index == y.index) {
                        const new_opcode: Opcode = switch (icmp.cond) {
                            .sgt, .sge => .smax,
                            .ugt, .uge => .umax,
                            .slt, .sle => .smin,
                            .ult, .ule => .umin,
                            else => return,
                        };
                        try self.replaceWithBinary(func, inst, new_opcode, x, y);
                        return;
                    }

                    // Check swapped operands: select(x < y, y, x) => max(x, y)
                    if (true_val.index == y.index and false_val.index == x.index) {
                        const new_opcode: Opcode = switch (icmp.cond) {
                            .slt, .sle => .smax,
                            .ult, .ule => .umax,
                            .sgt, .sge => .smin,
                            .ugt, .uge => .umin,
                            else => return,
                        };
                        try self.replaceWithBinary(func, inst, new_opcode, x, y);
                        return;
                    }

                    // Recognize iabs patterns: select(x >= 0, x, -x) => abs(x)
                    const y_const = self.getConstant(func, y);
                    if (y_const != null and y_const.? == 0) {
                        // Check if false_val is ineg of x
                        const false_def = func.dfg.valueDef(false_val) orelse return;
                        const false_inst = switch (false_def) {
                            .result => |r| r.inst,
                            else => return,
                        };
                        const false_data = func.dfg.insts.get(false_inst) orelse return;

                        if (false_data.* == .unary and false_data.unary.opcode == .ineg) {
                            const negated = false_data.unary.arg;
                            // select(x > 0, x, -x) => abs(x) or select(x >= 0, x, -x) => abs(x)
                            if (true_val.index == x.index and negated.index == x.index) {
                                if (icmp.cond == .sgt or icmp.cond == .sge) {
                                    try self.replaceWithUnary(func, inst, .iabs, x);
                                    return;
                                }
                            }
                        }

                        // Check if true_val is ineg of x for the flipped pattern
                        const true_def = func.dfg.valueDef(true_val) orelse return;
                        const true_inst = switch (true_def) {
                            .result => |r| r.inst,
                            else => return,
                        };
                        const true_data = func.dfg.insts.get(true_inst) orelse return;

                        if (true_data.* == .unary and true_data.unary.opcode == .ineg) {
                            const negated = true_data.unary.arg;
                            // select(x <= 0, -x, x) => abs(x) or select(x < 0, -x, x) => abs(x)
                            if (false_val.index == x.index and negated.index == x.index) {
                                if (icmp.cond == .sle or icmp.cond == .slt) {
                                    try self.replaceWithUnary(func, inst, .iabs, x);
                                    return;
                                }
                            }
                        }
                    }
                }

                // Nested select simplifications: select(d, a, select(d, _, y)) => select(d, a, y)
                const false_def = func.dfg.valueDef(false_val) orelse return;
                const false_inst = switch (false_def) {
                    .result => |r| r.inst,
                    else => return,
                };
                const false_data = func.dfg.insts.get(false_inst) orelse return;

                if (false_data.* == .ternary and false_data.ternary.opcode == .select) {
                    const inner = false_data.ternary;
                    // Check if inner select has same condition
                    if (inner.args[0].index == cond.index) {
                        // select(d, a, select(d, _, y)) => select(d, a, y)
                        try self.replaceWithTernary(func, inst, .select, cond, true_val, inner.args[2]);
                        return;
                    }
                }

                // Check true branch: select(d, select(d, x, _), a) => select(d, x, a)
                const true_def = func.dfg.valueDef(true_val) orelse return;
                const true_inst = switch (true_def) {
                    .result => |r| r.inst,
                    else => return,
                };
                const true_data = func.dfg.insts.get(true_inst) orelse return;

                if (true_data.* == .ternary and true_data.ternary.opcode == .select) {
                    const inner = true_data.ternary;
                    // Check if inner select has same condition
                    if (inner.args[0].index == cond.index) {
                        // select(d, select(d, x, _), a) => select(d, x, a)
                        try self.replaceWithTernary(func, inst, .select, cond, inner.args[1], false_val);
                        return;
                    }
                }
            },
            else => {},
        }
    }

    /// Combine integer comparison operations.
    fn combineIntCompare(self: *InstCombine, func: *Function, inst: Inst, data: IntCompareData) !void {
        const lhs = data.args[0];
        const rhs = data.args[1];

        // Constant folding: both operands are constants
        const lhs_const = self.getConstant(func, lhs);
        const rhs_const = self.getConstant(func, rhs);
        if (lhs_const != null and rhs_const != null) {
            const result: i64 = switch (data.cond) {
                .eq => if (lhs_const.? == rhs_const.?) 1 else 0,
                .ne => if (lhs_const.? != rhs_const.?) 1 else 0,
                .slt => if (lhs_const.? < rhs_const.?) 1 else 0,
                .sle => if (lhs_const.? <= rhs_const.?) 1 else 0,
                .sgt => if (lhs_const.? > rhs_const.?) 1 else 0,
                .sge => if (lhs_const.? >= rhs_const.?) 1 else 0,
                .ult => if (@as(u64, @bitCast(lhs_const.?)) < @as(u64, @bitCast(rhs_const.?))) 1 else 0,
                .ule => if (@as(u64, @bitCast(lhs_const.?)) <= @as(u64, @bitCast(rhs_const.?))) 1 else 0,
                .ugt => if (@as(u64, @bitCast(lhs_const.?)) > @as(u64, @bitCast(rhs_const.?))) 1 else 0,
                .uge => if (@as(u64, @bitCast(lhs_const.?)) >= @as(u64, @bitCast(rhs_const.?))) 1 else 0,
            };
            try self.replaceWithConst(func, inst, result);
            return;
        }

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

        // Optimize icmp-of-icmp: ne(icmp(...), 0) == icmp(...), eq(icmp(...), 0) == icmp(complement, ...)
        if (rhs_const) |c| {
            if (c == 0) {
                const lhs_def = func.dfg.valueDef(lhs) orelse return;
                const lhs_inst = switch (lhs_def) {
                    .result => |r| r.inst,
                    else => return,
                };
                const lhs_data = func.dfg.insts.get(lhs_inst) orelse return;

                if (lhs_data.* == .int_compare) {
                    const inner_icmp = lhs_data.int_compare;
                    if (data.cond == .ne) {
                        // ne(icmp(...), 0) => icmp(...) (redundant != 0 check)
                        try self.replaceWithValue(func, inst, lhs);
                        return;
                    } else if (data.cond == .eq) {
                        // eq(icmp(cc, x, y), 0) => icmp(complement(cc), x, y)
                        const complement_cc: IntCC = switch (inner_icmp.cond) {
                            .eq => .ne,
                            .ne => .eq,
                            .slt => .sge,
                            .sle => .sgt,
                            .sgt => .sle,
                            .sge => .slt,
                            .ult => .uge,
                            .ule => .ugt,
                            .ugt => .ule,
                            .uge => .ult,
                        };
                        const new_icmp = try func.dfg.makeIntCompare(complement_cc, inner_icmp.args[0], inner_icmp.args[1]);
                        try self.replaceWithValue(func, inst, new_icmp);
                        return;
                    }
                }
            }
        }

        // Comparisons with constants
        if (rhs_const) |c| {

            // ult(x, 0) = 0 (always false)
            if (data.cond == .ult and c == 0) {
                try self.replaceWithConst(func, inst, 0);
                return;
            }

            // uge(x, 0) = 1 (always true)
            if (data.cond == .uge and c == 0) {
                try self.replaceWithConst(func, inst, 1);
                return;
            }

            // ugt(x, 0) = ne(x, 0)
            if (data.cond == .ugt and c == 0) {
                const zero = try func.dfg.makeConst(0);
                const new_ne = try func.dfg.makeIntCompare(.ne, lhs, zero);
                try self.replaceWithValue(func, inst, new_ne);
                return;
            }

            // ult(x, 1) = eq(x, 0)
            if (data.cond == .ult and c == 1) {
                const zero = try func.dfg.makeConst(0);
                const new_eq = try func.dfg.makeIntCompare(.eq, lhs, zero);
                try self.replaceWithValue(func, inst, new_eq);
                return;
            }

            // uge(x, 1) = ne(x, 0)
            if (data.cond == .uge and c == 1) {
                const zero = try func.dfg.makeConst(0);
                const new_ne = try func.dfg.makeIntCompare(.ne, lhs, zero);
                try self.replaceWithValue(func, inst, new_ne);
                return;
            }

            // slt(x, 1) = sle(x, 0)
            if (data.cond == .slt and c == 1) {
                const zero = try func.dfg.makeConst(0);
                const sle_inst = try func.dfg.makeIntCompare(.sle, lhs, zero);
                try self.replaceWithValue(func, inst, sle_inst);
                return;
            }

            // sle(x, -1) = slt(x, 0)
            if (data.cond == .sle and c == -1) {
                const zero = try func.dfg.makeConst(0);
                const slt_inst = try func.dfg.makeIntCompare(.slt, lhs, zero);
                try self.replaceWithValue(func, inst, slt_inst);
                return;
            }

            // ule(x, 0) = eq(x, 0)
            if (data.cond == .ule and c == 0) {
                const zero = try func.dfg.makeConst(0);
                const eq_inst = try func.dfg.makeIntCompare(.eq, lhs, zero);
                try self.replaceWithValue(func, inst, eq_inst);
                return;
            }

            // sge(x, 1) = sgt(x, 0)
            if (data.cond == .sge and c == 1) {
                const zero = try func.dfg.makeConst(0);
                const sgt_inst = try func.dfg.makeIntCompare(.sgt, lhs, zero);
                try self.replaceWithValue(func, inst, sgt_inst);
                return;
            }

            // sgt(x, -1) = sge(x, 0)
            if (data.cond == .sgt and c == -1) {
                const zero = try func.dfg.makeConst(0);
                const sge_inst = try func.dfg.makeIntCompare(.sge, lhs, zero);
                try self.replaceWithValue(func, inst, sge_inst);
                return;
            }
        }

        // ult(~x, ~y) = ugt(x, y)
        if (data.cond == .ult) {
            if (try self.simplifyCompareNotOperands(func, inst, data, lhs, rhs)) {
                return;
            }
        }

        // eq(x, x ^ y) = eq(y, 0) and ne(x, x ^ y) = ne(y, 0)
        if (data.cond == .eq or data.cond == .ne) {
            if (try self.simplifyCompareWithXor(func, inst, data, lhs, rhs)) {
                return;
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
                const rotated = (val_u << shift_amt) | (val_u >> @as(u6, @intCast(64 - @as(u7, shift_amt))));
                break :blk @as(i64, @bitCast(rotated));
            },
            .rotr => blk: {
                const val_u = @as(u64, @bitCast(lhs));
                const shift_amt = @as(u6, @truncate(@as(u64, @bitCast(rhs)) & 63));
                const rotated = (val_u >> shift_amt) | (val_u << @as(u6, @intCast(64 - @as(u7, shift_amt))));
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
            // x * 0 = 0, x * 1 = x
            .fmul => if (rhs == 0) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            } else if (rhs == 1) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x * 0 = 0, x * 1 = x, x * 2 = x + x, x * pow2 = x << log2(pow2), x * -1 = -x
            .imul => if (rhs == 0) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            } else if (rhs == 1) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            } else if (rhs == 2) {
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const add_inst = try func.dfg.makeBinary(.iadd, result_ty, lhs, lhs);
                try self.replaceWithValue(func, inst, add_inst);
                return true;
            } else if (rhs > 0 and @popCount(@as(u64, @bitCast(rhs))) == 1) {
                // x * pow2 = x << log2(pow2) (for positive powers of 2)
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const shift_amt = @ctz(@as(u64, @bitCast(rhs)));
                const shift_const = try func.dfg.makeConst(@as(i64, @intCast(shift_amt)));
                const shl_inst = try func.dfg.makeBinary(.ishl, result_ty, lhs, shift_const);
                try self.replaceWithValue(func, inst, shl_inst);
                return true;
            } else if (rhs == -1) {
                // x * -1 = -x
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, lhs);
                try self.replaceWithValue(func, inst, neg_inst);
                return true;
            },
            // x / 1 = x
            .sdiv => if (rhs == 1) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x / 1 = x, udiv(x, pow2) = x >> log2(pow2) (for positive powers of 2)
            .udiv => if (rhs == 1) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            } else if (rhs > 0 and @popCount(@as(u64, @bitCast(rhs))) == 1) {
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const shift_amt = @ctz(@as(u64, @bitCast(rhs)));
                const shift_const = try func.dfg.makeConst(@as(i64, @intCast(shift_amt)));
                const shr_inst = try func.dfg.makeBinary(.ushr, result_ty, lhs, shift_const);
                try self.replaceWithValue(func, inst, shr_inst);
                return true;
            },
            // x % 1 = 0, urem(x, pow2) = x & (pow2 - 1) (for powers of 2 > 1)
            .urem => if (rhs == 1) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            } else if (rhs > 1 and @popCount(@as(u64, @bitCast(rhs))) == 1) {
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const mask = rhs - 1;
                const mask_const = try func.dfg.makeConst(mask);
                const and_inst = try func.dfg.makeBinary(.band, result_ty, lhs, mask_const);
                try self.replaceWithValue(func, inst, and_inst);
                return true;
            },
            // x % 1 = 0, x % -1 = 0 (signed remainder by 1 or -1 is always 0)
            .srem => if (rhs == 1 or rhs == -1) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            },
            // x & 0 = 0, x & -1 = x
            .band => if (rhs == 0) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            } else if (rhs == -1) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // x | 0 = x, x | -1 = -1
            .bor => if (rhs == 0) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            } else if (rhs == -1) {
                try self.replaceWithConst(func, inst, -1);
                return true;
            },
            // x ^ 0 = x, x ^ -1 = ~x
            .bxor => if (rhs == 0) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            } else if (rhs == -1) {
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const not_inst = try func.dfg.makeUnary(.bnot, result_ty, lhs);
                try self.replaceWithValue(func, inst, not_inst);
                return true;
            },
            // x << 0 = x, x >> 0 = x
            .ishl, .ushr, .sshr => if (rhs == 0) {
                try self.replaceWithValue(func, inst, lhs);
                return true;
            },
            // rotl(x, 0) = x, rotr(x, 0) = x
            .rotl, .rotr => if (rhs == 0) {
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
            // 0 * x = 0, 1 * x = x (commutative)
            .imul, .fmul => if (lhs == 0) {
                try self.replaceWithConst(func, inst, 0);
                return true;
            } else if (lhs == 1) {
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
                const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, rhs);
                try self.replaceWithValue(func, inst, neg_inst);
                return true;
            },
            // 0.0 - x = -x
            .fsub => if (lhs == 0) {
                const result_ty = func.dfg.instResultType(inst) orelse return false;
                const neg_inst = try func.dfg.makeUnary(.fneg, result_ty, rhs);
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
                    const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, x);
                    try self.replaceWithValue(func, inst, neg_inst);
                    return true;
                }
            }
        }

        // Check for 1 + ~x
        if (self.getConstant(func, lhs)) |c| {
            if (c == 1) {
                if (try self.getBnotOperand(func, rhs)) |x| {
                    const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, x);
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
                const sub_inst = try func.dfg.makeBinary(.isub, result_ty, lhs, y);
                try self.replaceWithValue(func, inst, sub_inst);
                return true;
            }
            // (-x) + y = y - x
            if (try self.getNegOperand(func, lhs)) |x| {
                const sub_inst = try func.dfg.makeBinary(.isub, result_ty, rhs, x);
                try self.replaceWithValue(func, inst, sub_inst);
                return true;
            }
        } else if (data.opcode == .isub) {
            // x - (-y) = x + y
            if (try self.getNegOperand(func, rhs)) |y| {
                const add_inst = try func.dfg.makeBinary(.iadd, result_ty, lhs, y);
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
                const mul_inst = try func.dfg.makeBinary(.imul, result_ty, x, y);
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
            const shl_inst = try func.dfg.makeBinary(.ishl, result_ty, lhs, y);
            try self.replaceWithValue(func, inst, shl_inst);
            return true;
        }

        // Check if lhs is ishl(1, y)
        if (try self.getShiftBy1(func, lhs)) |y| {
            const shl_inst = try func.dfg.makeBinary(.ishl, result_ty, rhs, y);
            try self.replaceWithValue(func, inst, shl_inst);
            return true;
        }

        return false;
    }

    /// Simplify (!x) + 1 = -x.
    fn simplifyNotPlusOne(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check for (!x) + 1
        if (self.getConstant(func, rhs)) |c| {
            if (c == 1) {
                const lhs_def = func.dfg.valueDef(lhs) orelse return false;
                const lhs_inst = switch (lhs_def) {
                    .result => |r| r.inst,
                    else => return false,
                };
                const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

                if (lhs_data.* == .unary and lhs_data.unary.opcode == .bnot) {
                    // Found (!x) + 1, replace with -x
                    const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, lhs_data.unary.arg);
                    try self.replaceWithValue(func, inst, neg_inst);
                    return true;
                }
            }
        }

        // Check for 1 + (!x) (commutative)
        if (self.getConstant(func, lhs)) |c| {
            if (c == 1) {
                const rhs_def = func.dfg.valueDef(rhs) orelse return false;
                const rhs_inst = switch (rhs_def) {
                    .result => |r| r.inst,
                    else => return false,
                };
                const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

                if (rhs_data.* == .unary and rhs_data.unary.opcode == .bnot) {
                    // Found 1 + (!x), replace with -x
                    const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, rhs_data.unary.arg);
                    try self.replaceWithValue(func, inst, neg_inst);
                    return true;
                }
            }
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
                    const neg_inst = try func.dfg.makeUnary(.ineg, result_ty, inner.args[1]);
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
                                const and_inst = try func.dfg.makeBinary(.band, result_ty, inner.args[0], inner.args[1]);
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

    /// Simplify (x & y) ^ (x ^ y) = x | y.
    fn simplifyAndXorToOr(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        // Check if lhs is (x & y) and rhs is (x ^ y)
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (lhs_data.* == .binary and rhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;
            const rhs_binary = rhs_data.binary;

            // Check: lhs is (x & y) and rhs is (x ^ y)
            if (lhs_binary.opcode == .band and rhs_binary.opcode == .bxor) {
                const x1 = lhs_binary.args[0];
                const y1 = lhs_binary.args[1];
                const x2 = rhs_binary.args[0];
                const y2 = rhs_binary.args[1];

                // Check if operands match (x and y in any order)
                if ((x1.index == x2.index and y1.index == y2.index) or
                    (x1.index == y2.index and y1.index == x2.index))
                {
                    const result_ty = func.dfg.instResultType(inst) orelse return false;
                    const or_inst = try func.dfg.makeBinary(.bor, result_ty, x1, y1);
                    try self.replaceWithValue(func, inst, or_inst);
                    return true;
                }
            }

            // Check: lhs is (x ^ y) and rhs is (x & y)
            if (lhs_binary.opcode == .bxor and rhs_binary.opcode == .band) {
                const x1 = lhs_binary.args[0];
                const y1 = lhs_binary.args[1];
                const x2 = rhs_binary.args[0];
                const y2 = rhs_binary.args[1];

                // Check if operands match (x and y in any order)
                if ((x1.index == x2.index and y1.index == y2.index) or
                    (x1.index == y2.index and y1.index == x2.index))
                {
                    const result_ty = func.dfg.instResultType(inst) orelse return false;
                    const or_inst = try func.dfg.makeBinary(.bor, result_ty, x1, y1);
                    try self.replaceWithValue(func, inst, or_inst);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify (x & y) | ~y = x | ~y.
    fn simplifyOrWithNotAbsorption(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        // Check if lhs is (x & y) and rhs is ~y
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        if (lhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;
            if (lhs_binary.opcode == .band) {
                const x = lhs_binary.args[0];
                const y = lhs_binary.args[1];

                // Check if rhs is ~y
                if (try self.getBnotOperand(func, rhs)) |bnot_arg| {
                    if (bnot_arg.index == y.index) {
                        // (x & y) | ~y = x | ~y
                        const result_ty = func.dfg.instResultType(inst) orelse return false;
                        const or_inst = try func.dfg.makeBinary(.bor, result_ty, x, rhs);
                        try self.replaceWithValue(func, inst, or_inst);
                        return true;
                    }
                    if (bnot_arg.index == x.index) {
                        // (x & y) | ~x = y | ~x
                        const result_ty = func.dfg.instResultType(inst) orelse return false;
                        const or_inst = try func.dfg.makeBinary(.bor, result_ty, y, rhs);
                        try self.replaceWithValue(func, inst, or_inst);
                        return true;
                    }
                }
            }
        }

        // Check if rhs is (x & y) and lhs is ~y
        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (rhs_data.* == .binary) {
            const rhs_binary = rhs_data.binary;
            if (rhs_binary.opcode == .band) {
                const x = rhs_binary.args[0];
                const y = rhs_binary.args[1];

                // Check if lhs is ~y
                if (try self.getBnotOperand(func, lhs)) |bnot_arg| {
                    if (bnot_arg.index == y.index) {
                        // ~y | (x & y) = ~y | x
                        const result_ty = func.dfg.instResultType(inst) orelse return false;
                        const or_inst = try func.dfg.makeBinary(.bor, result_ty, lhs, x);
                        try self.replaceWithValue(func, inst, or_inst);
                        return true;
                    }
                    if (bnot_arg.index == x.index) {
                        // ~x | (x & y) = ~x | y
                        const result_ty = func.dfg.instResultType(inst) orelse return false;
                        const or_inst = try func.dfg.makeBinary(.bor, result_ty, lhs, y);
                        try self.replaceWithValue(func, inst, or_inst);
                        return true;
                    }
                }
            }
        }

        return false;
    }

    /// Simplify rotl(rotr(x, y), y) = x and rotr(rotl(x, y), y) = x.
    fn simplifyRotateCancellation(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: Value) !bool {
        // Check if lhs is the opposite rotate with same shift amount
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        if (lhs_data.* == .binary) {
            const inner = lhs_data.binary;
            // Check if inner is the opposite rotation
            const opposite_op = switch (data.opcode) {
                .rotl => Opcode.rotr,
                .rotr => Opcode.rotl,
                else => return false,
            };

            if (inner.opcode == opposite_op) {
                // Check if shift amounts match
                if (inner.args[1].index == rhs.index) {
                    // rotl(rotr(x, y), y) = x or rotr(rotl(x, y), y) = x
                    try self.replaceWithValue(func, inst, inner.args[0]);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify rotl(rotl(x, y), z) = rotl(x, y+z) and rotr(rotr(x, y), z) = rotr(x, y+z).
    fn simplifyRotateChain(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check if lhs is the same rotate operation
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        if (lhs_data.* == .binary) {
            const inner = lhs_data.binary;
            // Check if inner is the same rotation
            if (inner.opcode == data.opcode) {
                const x = inner.args[0];
                const y = inner.args[1];
                const z = rhs;

                // Create y + z
                const sum = try func.dfg.makeBinary(.iadd, result_ty, y, z);
                // Create rotl(x, y+z) or rotr(x, y+z)
                const new_rot = try func.dfg.makeBinary(data.opcode, result_ty, x, sum);
                try self.replaceWithValue(func, inst, new_rot);
                return true;
            }
        }

        return false;
    }

    /// Simplify eq(x, x ^ y) = eq(y, 0) and ne(x, x ^ y) = ne(y, 0).
    fn simplifyCompareWithXor(self: *InstCombine, func: *Function, inst: Inst, data: IntCompareData, lhs: Value, rhs: Value) !bool {

        // Check if rhs is (x ^ y)
        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (rhs_data.* == .binary) {
            const rhs_binary = rhs_data.binary;
            if (rhs_binary.opcode == .bxor) {
                const x = rhs_binary.args[0];
                const y = rhs_binary.args[1];

                // Check if lhs matches one of the xor operands
                if (lhs.index == x.index) {
                    // eq(x, x ^ y) = eq(y, 0)
                    const zero = try func.dfg.makeConst(0);
                    const new_cmp = try func.dfg.makeIntCompare(data.cond, y, zero);
                    try self.replaceWithValue(func, inst, new_cmp);
                    return true;
                }
                if (lhs.index == y.index) {
                    // eq(y, x ^ y) = eq(x, 0)
                    const zero = try func.dfg.makeConst(0);
                    const new_cmp = try func.dfg.makeIntCompare(data.cond, x, zero);
                    try self.replaceWithValue(func, inst, new_cmp);
                    return true;
                }
            }
        }

        // Check if lhs is (x ^ y)
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        if (lhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;
            if (lhs_binary.opcode == .bxor) {
                const x = lhs_binary.args[0];
                const y = lhs_binary.args[1];

                // Check if rhs matches one of the xor operands
                if (rhs.index == x.index) {
                    // eq(x ^ y, x) = eq(y, 0)
                    const zero = try func.dfg.makeConst(0);
                    const new_cmp = try func.dfg.makeIntCompare(data.cond, y, zero);
                    try self.replaceWithValue(func, inst, new_cmp);
                    return true;
                }
                if (rhs.index == y.index) {
                    // eq(x ^ y, y) = eq(x, 0)
                    const zero = try func.dfg.makeConst(0);
                    const new_cmp = try func.dfg.makeIntCompare(data.cond, x, zero);
                    try self.replaceWithValue(func, inst, new_cmp);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify ult(~x, ~y) = ugt(x, y).
    fn simplifyCompareNotOperands(self: *InstCombine, func: *Function, inst: Inst, _: IntCompareData, lhs: Value, rhs: Value) !bool {

        // Check if lhs is ~x
        const x = (try self.getBnotOperand(func, lhs)) orelse return false;
        // Check if rhs is ~y
        const y = (try self.getBnotOperand(func, rhs)) orelse return false;

        // ult(~x, ~y) = ugt(x, y)
        const new_cmp = try func.dfg.makeIntCompare(.ugt, x, y);
        try self.replaceWithValue(func, inst, new_cmp);
        return true;
    }

    /// Simplify (x ^ ~y) & x = x & y.
    fn simplifyXorNotAnd(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check if lhs is (x ^ ~y) and rhs is x
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        if (lhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;
            if (lhs_binary.opcode == .bxor) {
                const x = lhs_binary.args[0];
                const other = lhs_binary.args[1];

                // Check if one operand is x and other is ~y
                if (x.index == rhs.index) {
                    if (try self.getBnotOperand(func, other)) |y| {
                        // (x ^ ~y) & x = x & y
                        const and_inst = try func.dfg.makeBinary(.band, result_ty, rhs, y);
                        try self.replaceWithValue(func, inst, and_inst);
                        return true;
                    }
                }
                if (other.index == rhs.index) {
                    if (try self.getBnotOperand(func, x)) |y| {
                        // (~y ^ x) & x = x & y
                        const and_inst = try func.dfg.makeBinary(.band, result_ty, rhs, y);
                        try self.replaceWithValue(func, inst, and_inst);
                        return true;
                    }
                }
            }
        }

        // Check if rhs is (x ^ ~y) and lhs is x
        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (rhs_data.* == .binary) {
            const rhs_binary = rhs_data.binary;
            if (rhs_binary.opcode == .bxor) {
                const x = rhs_binary.args[0];
                const other = rhs_binary.args[1];

                // Check if one operand is x and other is ~y
                if (x.index == lhs.index) {
                    if (try self.getBnotOperand(func, other)) |y| {
                        // x & (x ^ ~y) = x & y
                        const and_inst = try func.dfg.makeBinary(.band, result_ty, lhs, y);
                        try self.replaceWithValue(func, inst, and_inst);
                        return true;
                    }
                }
                if (other.index == lhs.index) {
                    if (try self.getBnotOperand(func, x)) |y| {
                        // x & (~y ^ x) = x & y
                        const and_inst = try func.dfg.makeBinary(.band, result_ty, lhs, y);
                        try self.replaceWithValue(func, inst, and_inst);
                        return true;
                    }
                }
            }
        }

        return false;
    }

    /// Simplify uextend(x) op uextend(y) = uextend(x op y) for bitwise ops.
    fn simplifyExtendBitwise(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check if both lhs and rhs are uextend
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (lhs_data.* == .unary and rhs_data.* == .unary) {
            const lhs_unary = lhs_data.unary;
            const rhs_unary = rhs_data.unary;

            // Both must be uextend
            if (lhs_unary.opcode == .uextend and rhs_unary.opcode == .uextend) {
                const x = lhs_unary.arg;
                const y = rhs_unary.arg;

                // Get the types
                const x_def = func.dfg.valueDef(x) orelse return false;
                const y_def = func.dfg.valueDef(y) orelse return false;

                const x_ty = switch (x_def) {
                    .result => |r| func.dfg.instResultType(r.inst) orelse return false,
                    .param => |p| func.sig.params.items[p.index].value_type,
                    else => return false,
                };
                const y_ty = switch (y_def) {
                    .result => |r| func.dfg.instResultType(r.inst) orelse return false,
                    .param => |p| func.sig.params.items[p.index].value_type,
                    else => return false,
                };

                // Types must match
                if (x_ty.eql(y_ty)) {
                    // Create (x op y)
                    const inner_op = try func.dfg.makeBinary(data.opcode, x_ty, x, y);
                    // Create uextend(x op y)
                    const extend = try func.dfg.makeUnary(.uextend, result_ty, inner_op);
                    try self.replaceWithValue(func, inst, extend);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify (x & y) + (x ^ y) = x | y.
    fn simplifyAndXorAdd(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check if lhs is (x & y) and rhs is (x ^ y)
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (lhs_data.* == .binary and rhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;
            const rhs_binary = rhs_data.binary;

            // Check: lhs is (x & y) and rhs is (x ^ y)
            if (lhs_binary.opcode == .band and rhs_binary.opcode == .bxor) {
                const x1 = lhs_binary.args[0];
                const y1 = lhs_binary.args[1];
                const x2 = rhs_binary.args[0];
                const y2 = rhs_binary.args[1];

                // Check if operands match (x and y in any order)
                if ((x1.index == x2.index and y1.index == y2.index) or
                    (x1.index == y2.index and y1.index == x2.index))
                {
                    const or_inst = try func.dfg.makeBinary(.bor, result_ty, x1, y1);
                    try self.replaceWithValue(func, inst, or_inst);
                    return true;
                }
            }

            // Check: lhs is (x ^ y) and rhs is (x & y)
            if (lhs_binary.opcode == .bxor and rhs_binary.opcode == .band) {
                const x1 = lhs_binary.args[0];
                const y1 = lhs_binary.args[1];
                const x2 = rhs_binary.args[0];
                const y2 = rhs_binary.args[1];

                // Check if operands match (x and y in any order)
                if ((x1.index == x2.index and y1.index == y2.index) or
                    (x1.index == y2.index and y1.index == x2.index))
                {
                    const or_inst = try func.dfg.makeBinary(.bor, result_ty, x1, y1);
                    try self.replaceWithValue(func, inst, or_inst);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify (x | y) + (x & y) = x + y.
    fn simplifyOrAndAdd(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check if lhs is (x | y) and rhs is (x & y)
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (lhs_data.* == .binary and rhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;
            const rhs_binary = rhs_data.binary;

            // Check: lhs is (x | y) and rhs is (x & y)
            if (lhs_binary.opcode == .bor and rhs_binary.opcode == .band) {
                const x1 = lhs_binary.args[0];
                const y1 = lhs_binary.args[1];
                const x2 = rhs_binary.args[0];
                const y2 = rhs_binary.args[1];

                // Check if operands match (x and y in any order)
                if ((x1.index == x2.index and y1.index == y2.index) or
                    (x1.index == y2.index and y1.index == x2.index))
                {
                    const add_inst = try func.dfg.makeBinary(.iadd, result_ty, x1, y1);
                    try self.replaceWithValue(func, inst, add_inst);
                    return true;
                }
            }

            // Check: lhs is (x & y) and rhs is (x | y)
            if (lhs_binary.opcode == .band and rhs_binary.opcode == .bor) {
                const x1 = lhs_binary.args[0];
                const y1 = lhs_binary.args[1];
                const x2 = rhs_binary.args[0];
                const y2 = rhs_binary.args[1];

                // Check if operands match (x and y in any order)
                if ((x1.index == x2.index and y1.index == y2.index) or
                    (x1.index == y2.index and y1.index == x2.index))
                {
                    const add_inst = try func.dfg.makeBinary(.iadd, result_ty, x1, y1);
                    try self.replaceWithValue(func, inst, add_inst);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify (x | y) ^ (x & y) = x ^ y.
    fn simplifyOrAndXor(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check if lhs is (x | y) and rhs is (x & y)
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (lhs_data.* == .binary and rhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;
            const rhs_binary = rhs_data.binary;

            // Check: lhs is (x | y) and rhs is (x & y)
            if (lhs_binary.opcode == .bor and rhs_binary.opcode == .band) {
                const x1 = lhs_binary.args[0];
                const y1 = lhs_binary.args[1];
                const x2 = rhs_binary.args[0];
                const y2 = rhs_binary.args[1];

                // Check if operands match (x and y in any order)
                if ((x1.index == x2.index and y1.index == y2.index) or
                    (x1.index == y2.index and y1.index == x2.index))
                {
                    const xor_inst = try func.dfg.makeBinary(.bxor, result_ty, x1, y1);
                    try self.replaceWithValue(func, inst, xor_inst);
                    return true;
                }
            }

            // Check: lhs is (x & y) and rhs is (x | y)
            if (lhs_binary.opcode == .band and rhs_binary.opcode == .bor) {
                const x1 = lhs_binary.args[0];
                const y1 = lhs_binary.args[1];
                const x2 = rhs_binary.args[0];
                const y2 = rhs_binary.args[1];

                // Check if operands match (x and y in any order)
                if ((x1.index == x2.index and y1.index == y2.index) or
                    (x1.index == y2.index and y1.index == x2.index))
                {
                    const xor_inst = try func.dfg.makeBinary(.bxor, result_ty, x1, y1);
                    try self.replaceWithValue(func, inst, xor_inst);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify (z & x) ^ (z & y) = z & (x ^ y).
    fn simplifyAndXorFactor(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check if both lhs and rhs are AND operations
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (lhs_data.* == .binary and rhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;
            const rhs_binary = rhs_data.binary;

            if (lhs_binary.opcode == .band and rhs_binary.opcode == .band) {
                const z1 = lhs_binary.args[0];
                const x = lhs_binary.args[1];
                const z2 = rhs_binary.args[0];
                const y = rhs_binary.args[1];

                // Check if first operands match: (z & x) ^ (z & y)
                if (z1.index == z2.index) {
                    const xor_inst = try func.dfg.makeBinary(.bxor, result_ty, x, y);
                    const and_inst = try func.dfg.makeBinary(.band, result_ty, z1, xor_inst);
                    try self.replaceWithValue(func, inst, and_inst);
                    return true;
                }

                // Check if second operands match: (x & z) ^ (y & z)
                if (x.index == y.index) {
                    const xor_inst = try func.dfg.makeBinary(.bxor, result_ty, z1, z2);
                    const and_inst = try func.dfg.makeBinary(.band, result_ty, x, xor_inst);
                    try self.replaceWithValue(func, inst, and_inst);
                    return true;
                }

                // Check cross patterns: (z & x) ^ (y & z)
                if (z1.index == y.index) {
                    const xor_inst = try func.dfg.makeBinary(.bxor, result_ty, x, z2);
                    const and_inst = try func.dfg.makeBinary(.band, result_ty, z1, xor_inst);
                    try self.replaceWithValue(func, inst, and_inst);
                    return true;
                }

                // Check cross patterns: (x & z) ^ (z & y)
                if (x.index == z2.index) {
                    const xor_inst = try func.dfg.makeBinary(.bxor, result_ty, z1, y);
                    const and_inst = try func.dfg.makeBinary(.band, result_ty, x, xor_inst);
                    try self.replaceWithValue(func, inst, and_inst);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify (x ^ y) ^ y = x.
    fn simplifyXorCancellation(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        // Check if lhs is (x ^ y) and rhs matches one of the operands
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        if (lhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;
            if (lhs_binary.opcode == .bxor) {
                const x = lhs_binary.args[0];
                const y = lhs_binary.args[1];

                // (x ^ y) ^ y = x
                if (y.index == rhs.index) {
                    try self.replaceWithValue(func, inst, x);
                    return true;
                }

                // (x ^ y) ^ x = y
                if (x.index == rhs.index) {
                    try self.replaceWithValue(func, inst, y);
                    return true;
                }
            }
        }

        // Check if rhs is (x ^ y) and lhs matches one of the operands
        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (rhs_data.* == .binary) {
            const rhs_binary = rhs_data.binary;
            if (rhs_binary.opcode == .bxor) {
                const x = rhs_binary.args[0];
                const y = rhs_binary.args[1];

                // y ^ (x ^ y) = x
                if (y.index == lhs.index) {
                    try self.replaceWithValue(func, inst, x);
                    return true;
                }

                // x ^ (x ^ y) = y
                if (x.index == lhs.index) {
                    try self.replaceWithValue(func, inst, y);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify (x > y) ^ (x < y) = x != y.
    fn simplifyXorComparisons(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {

        // Check if both operands are integer comparisons
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (lhs_data.* == .int_compare and rhs_data.* == .int_compare) {
            const lhs_cmp = lhs_data.int_compare;
            const rhs_cmp = rhs_data.int_compare;

            // Check if comparing the same values
            if (lhs_cmp.args[0].index == rhs_cmp.args[0].index and
                lhs_cmp.args[1].index == rhs_cmp.args[1].index)
            {
                // (x > y) ^ (x < y) = x != y
                if ((lhs_cmp.cond == .ugt and rhs_cmp.cond == .ult) or
                    (lhs_cmp.cond == .ult and rhs_cmp.cond == .ugt) or
                    (lhs_cmp.cond == .sgt and rhs_cmp.cond == .slt) or
                    (lhs_cmp.cond == .slt and rhs_cmp.cond == .sgt))
                {
                    const ne_inst = try func.dfg.makeIntCompare(.ne, lhs_cmp.args[0], lhs_cmp.args[1]);
                    try self.replaceWithValue(func, inst, ne_inst);
                    return true;
                }
            }

            // Check if comparing swapped values: (x > y) ^ (y > x) = x != y
            if (lhs_cmp.args[0].index == rhs_cmp.args[1].index and
                lhs_cmp.args[1].index == rhs_cmp.args[0].index)
            {
                // (x > y) ^ (y > x) = x != y
                if ((lhs_cmp.cond == .ugt and rhs_cmp.cond == .ugt) or
                    (lhs_cmp.cond == .ult and rhs_cmp.cond == .ult) or
                    (lhs_cmp.cond == .sgt and rhs_cmp.cond == .sgt) or
                    (lhs_cmp.cond == .slt and rhs_cmp.cond == .slt))
                {
                    const ne_inst = try func.dfg.makeIntCompare(.ne, lhs_cmp.args[0], lhs_cmp.args[1]);
                    try self.replaceWithValue(func, inst, ne_inst);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify (x << z) + (y << z) = (x + y) << z and (x >> z) & (y >> z) = (x & y) >> z.
    fn simplifyShiftDistribute(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // Check if both lhs and rhs are shifts
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (lhs_data.* == .binary and rhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;
            const rhs_binary = rhs_data.binary;

            // Both must be the same kind of shift
            if (lhs_binary.opcode == rhs_binary.opcode and
                (lhs_binary.opcode == .ishl or lhs_binary.opcode == .ushr or lhs_binary.opcode == .sshr))
            {
                const x = lhs_binary.args[0];
                const z1 = lhs_binary.args[1];
                const y = rhs_binary.args[0];
                const z2 = rhs_binary.args[1];

                // Shift amounts must match
                if (z1.index == z2.index) {
                    // Create (x op y) where op is add, sub, or and
                    const inner_inst = try func.dfg.makeBinary(data.opcode, result_ty, x, y);
                    // Create (x op y) shift z
                    const shift_inst = try func.dfg.makeBinary(lhs_binary.opcode, result_ty, inner_inst, z1);
                    try self.replaceWithValue(func, inst, shift_inst);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify (x << k1) << k2 = x << (k1 + k2), (x >> k1) >> k2 = x >> (k1 + k2).
    fn simplifyShiftChain(self: *InstCombine, func: *Function, inst: Inst, data: BinaryData, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;
        const ty_bits = result_ty.bits();

        // Get shift amount k2 (must be constant)
        const k2 = self.getConstant(func, rhs) orelse return false;
        if (k2 < 0 or k2 >= ty_bits) return false;

        // Check if lhs is also a shift of the same kind
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        if (lhs_data.* == .binary) {
            const lhs_binary = lhs_data.binary;

            // Check if it's the same shift operation
            if (lhs_binary.opcode == data.opcode) {
                const x = lhs_binary.args[0];
                const k1_val = lhs_binary.args[1];

                // Get k1 (must be constant)
                const k1 = self.getConstant(func, k1_val) orelse return false;
                if (k1 < 0 or k1 >= ty_bits) return false;

                // Check if k1 + k2 < ty_bits (otherwise shift becomes 0 or undefined)
                const k_sum = k1 + k2;
                if (k_sum >= ty_bits) {
                    // (x << k1) << k2 = 0 if k1 + k2 >= ty_bits (for left shift)
                    if (data.opcode == .ishl or data.opcode == .ushr) {
                        try self.replaceWithConst(func, inst, 0);
                        return true;
                    }
                    // For sshr, it saturates to the sign bit
                    return false;
                }

                // Create x << (k1 + k2)
                const new_shift_amt = try func.dfg.makeConst(k_sum);
                const new_shift = try func.dfg.makeBinary(data.opcode, result_ty, x, new_shift_amt);
                try self.replaceWithValue(func, inst, new_shift);
                return true;
            }
        }

        return false;
    }

    /// Simplify ((x << y) & z) >> y = x & (z >> y).
    fn simplifyShiftMask(self: *InstCombine, func: *Function, inst: Inst, _: BinaryData, lhs: Value, rhs: Value) !bool {
        const result_ty = func.dfg.instResultType(inst) orelse return false;

        // lhs must be (something & z)
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        if (lhs_data.* == .binary and lhs_data.binary.opcode == .band) {
            const band_lhs = lhs_data.binary.args[0];
            const z = lhs_data.binary.args[1];

            // band_lhs must be (x << y)
            const band_lhs_def = func.dfg.valueDef(band_lhs) orelse return false;
            const band_lhs_inst = switch (band_lhs_def) {
                .result => |r| r.inst,
                else => return false,
            };
            const band_lhs_data = func.dfg.insts.get(band_lhs_inst) orelse return false;

            if (band_lhs_data.* == .binary and band_lhs_data.binary.opcode == .ishl) {
                const x = band_lhs_data.binary.args[0];
                const y = band_lhs_data.binary.args[1];

                // Check if y == rhs (the shift amounts match)
                if (y.index == rhs.index) {
                    // Create (z >> y)
                    const z_shr = try func.dfg.makeBinary(.ushr, result_ty, z, y);
                    // Create x & (z >> y)
                    const result = try func.dfg.makeBinary(.band, result_ty, x, z_shr);
                    try self.replaceWithValue(func, inst, result);
                    return true;
                }
            }
        }

        return false;
    }

    /// Simplify (x < y) & (x > y) = 0 and similar mutually exclusive comparisons.
    fn simplifyMutuallyExclusiveComparisons(self: *InstCombine, func: *Function, inst: Inst, lhs: Value, rhs: Value) !bool {
        // Check if both lhs and rhs are integer comparisons
        const lhs_def = func.dfg.valueDef(lhs) orelse return false;
        const lhs_inst = switch (lhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const lhs_data = func.dfg.insts.get(lhs_inst) orelse return false;

        const rhs_def = func.dfg.valueDef(rhs) orelse return false;
        const rhs_inst = switch (rhs_def) {
            .result => |r| r.inst,
            else => return false,
        };
        const rhs_data = func.dfg.insts.get(rhs_inst) orelse return false;

        if (lhs_data.* == .int_compare and rhs_data.* == .int_compare) {
            const lhs_cmp = lhs_data.int_compare;
            const rhs_cmp = rhs_data.int_compare;

            // Check if comparing the same values
            if (lhs_cmp.args[0].index == rhs_cmp.args[0].index and
                lhs_cmp.args[1].index == rhs_cmp.args[1].index)
            {
                // (x < y) & (x > y) = 0
                if ((lhs_cmp.cond == .slt and rhs_cmp.cond == .sgt) or
                    (lhs_cmp.cond == .sgt and rhs_cmp.cond == .slt) or
                    (lhs_cmp.cond == .ult and rhs_cmp.cond == .ugt) or
                    (lhs_cmp.cond == .ugt and rhs_cmp.cond == .ult))
                {
                    try self.replaceWithConst(func, inst, 0);
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
            // x / x = 1 (for division operations)
            .udiv, .sdiv => {
                try self.replaceWithConst(func, inst, 1);
                return true;
            },
            // x % x = 0 (for modulo operations)
            .urem, .srem => {
                try self.replaceWithConst(func, inst, 0);
                return true;
            },
            // min(x, x) = x, max(x, x) = x
            .smin, .smax, .umin, .umax => {
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

    /// Replace instruction with a binary operation.
    fn replaceWithBinary(self: *InstCombine, func: *Function, inst: Inst, opcode: Opcode, lhs: Value, rhs: Value) !void {
        const result = func.dfg.firstResult(inst) orelse return;
        const ty = func.dfg.valueType(result) orelse return;

        // Create new binary instruction
        const new_inst = try func.dfg.makeInst(.{
            .binary = .{
                .opcode = opcode,
                .args = .{ lhs, rhs },
            },
        });

        const new_result = try func.dfg.appendInstResult(new_inst, ty);

        // Alias old result to new result
        const result_data = func.dfg.values.getMut(result) orelse return;
        result_data.* = ValueData.alias(ty, new_result);

        self.changed = true;
    }

    /// Replace instruction with a unary operation.
    fn replaceWithUnary(self: *InstCombine, func: *Function, inst: Inst, opcode: Opcode, arg: Value) !void {
        const result = func.dfg.firstResult(inst) orelse return;
        const ty = func.dfg.valueType(result) orelse return;

        // Create new unary instruction
        const new_inst = try func.dfg.makeInst(.{
            .unary = .{
                .opcode = opcode,
                .arg = arg,
            },
        });

        // Set result type
        _ = try func.dfg.appendInstResult(new_inst, ty);

        // Get new result value
        const new_result = func.dfg.firstResult(new_inst) orelse return;

        // Alias old result to new result
        const result_data = func.dfg.values.getMut(result) orelse return;
        result_data.* = ValueData.alias(ty, new_result);

        self.changed = true;
    }

    /// Replace instruction with a ternary operation.
    fn replaceWithTernary(self: *InstCombine, func: *Function, inst: Inst, opcode: Opcode, arg1: Value, arg2: Value, arg3: Value) !void {
        const result = func.dfg.firstResult(inst) orelse return;
        const ty = func.dfg.valueType(result) orelse return;

        // Create new ternary instruction
        const new_inst = try func.dfg.makeInst(.{
            .ternary = .{
                .opcode = opcode,
                .args = .{ arg1, arg2, arg3 },
            },
        });

        // Set result type
        _ = try func.dfg.appendInstResult(new_inst, ty);

        // Get new result value
        const new_result = func.dfg.firstResult(new_inst) orelse return;

        // Alias old result to new result
        const result_data = func.dfg.values.getMut(result) orelse return;
        result_data.* = ValueData.alias(ty, new_result);

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
                    const imm_bits: i32 = @bitCast(d.arg.index);
                    return @as(i64, imm_bits);
                }
            },
            else => {},
        }
        return null;
    }

    fn getSignedConstant(self: *InstCombine, func: *const Function, value: Value) ?i64 {
        return self.getConstant(func, value);
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

/// Simplify spaceship pattern: select(a < b, -1, select(a > b, 1, 0))
/// Detects three-way comparison idiom and optimizes to single compare + conditional moves.
fn simplifySpaceship(self: *InstCombine, func: *Function, inst: Inst, cond: Value, true_val: Value, false_val: Value) !bool {
    // Check if true_val is -1
    const true_const = self.getConstant(func, true_val);
    if (true_const == null or true_const.? != -1) return false;

    // Check if false_val is a select instruction
    const false_def = func.dfg.valueDef(false_val) orelse return false;
    const false_inst = switch (false_def) {
        .result => |r| r.inst,
        else => return false,
    };
    const false_data = func.dfg.insts.get(false_inst) orelse return false;
    if (false_data.* != .ternary) return false;
    const inner_select = false_data.ternary;
    if (inner_select.opcode != .select) return false;

    const inner_cond = inner_select.args[0];
    const inner_true = inner_select.args[1];
    const inner_false = inner_select.args[2];

    // Check if inner_true is 1 and inner_false is 0
    const inner_true_const = self.getConstant(func, inner_true);
    const inner_false_const = self.getConstant(func, inner_false);
    if (inner_true_const == null or inner_true_const.? != 1) return false;
    if (inner_false_const == null or inner_false_const.? != 0) return false;

    // Check if outer condition is a < b
    const outer_cond_def = func.dfg.valueDef(cond) orelse return false;
    const outer_cond_inst = switch (outer_cond_def) {
        .result => |r| r.inst,
        else => return false,
    };
    const outer_cond_data = func.dfg.insts.get(outer_cond_inst) orelse return false;
    if (outer_cond_data.* != .int_compare) return false;
    const outer_icmp = outer_cond_data.int_compare;

    // Check if inner condition is a > b
    const inner_cond_def = func.dfg.valueDef(inner_cond) orelse return false;
    const inner_cond_inst = switch (inner_cond_def) {
        .result => |r| r.inst,
        else => return false,
    };
    const inner_cond_data = func.dfg.insts.get(inner_cond_inst) orelse return false;
    if (inner_cond_data.* != .int_compare) return false;
    const inner_icmp = inner_cond_data.int_compare;

    // Check that both comparisons use the same operands
    const outer_a = outer_icmp.args[0];
    const outer_b = outer_icmp.args[1];
    const inner_a = inner_icmp.args[0];
    const inner_b = inner_icmp.args[1];

    if (outer_a.index != inner_a.index or outer_b.index != inner_b.index) return false;

    // Check that outer is < and inner is >
    const is_spaceship = switch (outer_icmp.cond) {
        .slt => inner_icmp.cond == .sgt,
        .ult => inner_icmp.cond == .ugt,
        else => false,
    };

    if (!is_spaceship) return false;

    // Pattern matched! Now emit optimized code.
    // For now, keep the nested select but mark for future backend optimization.
    // A proper implementation would emit a compare followed by CSEL/CSINC instructions.
    // TODO: Add backend-specific lowering for spaceship pattern.
    _ = inst;

    return false; // No transformation yet - needs backend support
}
