//! Range-based optimizations using value range analysis.
//! Optimizations: dead branch elimination, comparison simplification, overflow check removal.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Function = @import("../../ir/function.zig").Function;
const Value = @import("../../ir/entities.zig").Value;
const Block = @import("../../ir/entities.zig").Block;
const Inst = @import("../../ir/entities.zig").Inst;
const InstructionData = @import("../../ir/instruction_data.zig").InstructionData;
const Opcode = @import("../../ir/opcodes.zig").Opcode;
const ValueRange = @import("../../ir/value_range.zig").ValueRange;
const RangeAnalysis = @import("../../ir/value_range.zig").RangeAnalysis;
const IntCC = @import("../../ir/condcodes.zig").IntCC;

/// Range-based optimization pass.
pub const RangeOptimizer = struct {
    allocator: Allocator,
    function: *Function,
    analysis: *RangeAnalysis,

    /// Instructions to remove (dead branches, redundant checks).
    dead_insts: std.ArrayList(Inst),

    /// Replacements: map instruction to replacement value.
    replacements: std.AutoHashMap(Inst, Value),

    pub fn init(allocator: Allocator, function: *Function, analysis: *RangeAnalysis) RangeOptimizer {
        return .{
            .allocator = allocator,
            .function = function,
            .analysis = analysis,
            .dead_insts = std.ArrayList(Inst){},
            .replacements = std.AutoHashMap(Inst, Value).init(allocator),
        };
    }

    pub fn deinit(self: *RangeOptimizer) void {
        self.dead_insts.deinit(self.allocator);
        self.replacements.deinit();
    }

    /// Run range-based optimizations.
    pub fn optimize(self: *RangeOptimizer) !bool {
        var changed = false;

        var block_iter = self.function.layout.blockIter();
        while (block_iter.next()) |block| {
            if (try self.optimizeBlock(block)) {
                changed = true;
            }
        }

        // Apply replacements
        if (self.replacements.count() > 0) {
            try self.applyReplacements();
            changed = true;
        }

        // Remove dead instructions
        if (self.dead_insts.items.len > 0) {
            try self.removeDeadInsts();
            changed = true;
        }

        return changed;
    }

    /// Optimize instructions in block.
    fn optimizeBlock(self: *RangeOptimizer, block: Block) !bool {
        var changed = false;

        var inst_iter = self.function.layout.blockInsts(block);
        while (inst_iter.next()) |inst| {
            if (try self.optimizeInst(inst)) {
                changed = true;
            }
        }

        return changed;
    }

    /// Optimize single instruction.
    fn optimizeInst(self: *RangeOptimizer, inst: Inst) !bool {
        const data = self.function.dfg.insts.get(inst) orelse return false;

        return switch (data.*) {
            .int_compare => |ic| try self.optimizeIcmp(inst, ic.cond, ic.args),
            else => false,
        };
    }

    /// Optimize integer comparison.
    fn optimizeIcmp(self: *RangeOptimizer, inst: Inst, cond: IntCC, args: [2]Value) !bool {
        const lhs_range = self.analysis.getRange(args[0]) orelse return false;
        const rhs_range = self.analysis.getRange(args[1]) orelse return false;

        // Check if comparison is always true or always false
        const result = evaluateIcmp(cond, lhs_range, rhs_range) orelse return false;

        // Replace with constant
        const const_val: i64 = if (result) 1 else 0;
        const const_data = InstructionData{
            .unary_imm = .{
                .opcode = .iconst,
                .imm = .{ .value = const_val },
            },
        };

        const const_inst = try self.function.dfg.makeInst(const_data);
        const ty = self.function.dfg.valueType(self.function.dfg.instResults(inst)[0]) orelse return false;
        _ = try self.function.dfg.appendInstResult(const_inst, ty);

        try self.replacements.put(inst, self.function.dfg.instResults(const_inst)[0]);
        return true;
    }

    /// Optimize branch with comparison.
    fn optimizeBranchIcmp(self: *RangeOptimizer, inst: Inst, bi: anytype) !bool {
        const lhs_range = self.analysis.getRange(bi.arg) orelse return false;

        // Get constant range for immediate
        const rhs_range = if (@hasField(@TypeOf(bi), "imm")) blk: {
            const ty = self.function.dfg.valueType(bi.arg);
            const bits = ty.bits() orelse 64;
            const signed = ty.isSigned();
            break :blk ValueRange.constant(bi.imm.bits, bits, signed);
        } else return false;

        // Check if comparison is always true or always false
        const result = evaluateIcmp(bi.cond, lhs_range, rhs_range) orelse return false;

        // Replace conditional branch with unconditional jump
        const target = if (result) bi.then_block else bi.else_block;
        const jump_data = InstructionData{
            .jump = .{
                .opcode = .jump,
                .destination = target,
            },
        };

        const jump_inst = try self.function.dfg.makeInst(jump_data);
        try self.function.layout.insertInstBefore(jump_inst, inst, null);
        try self.dead_insts.append(self.allocator, inst);

        return true;
    }

    /// Apply value replacements.
    fn applyReplacements(self: *RangeOptimizer) !void {
        var inst_iter = self.function.layout.blockIter();
        while (inst_iter.next()) |block| {
            var insts = self.function.layout.blockInsts(block);
            while (insts.next()) |inst| {
                const data_ptr = self.function.dfg.insts.getMut(inst) orelse continue;

                // Replace operands
                switch (data_ptr.*) {
                    .binary => |*b| {
                        b.args[0] = try self.resolveReplacement(b.args[0]);
                        b.args[1] = try self.resolveReplacement(b.args[1]);
                    },
                    .unary => |*u| {
                        u.arg = try self.resolveReplacement(u.arg);
                    },
                    .binary_imm64 => |*bi| {
                        bi.arg = try self.resolveReplacement(bi.arg);
                    },
                    .int_compare => |*ic| {
                        ic.args[0] = try self.resolveReplacement(ic.args[0]);
                        ic.args[1] = try self.resolveReplacement(ic.args[1]);
                    },
                    else => {},
                }
            }
        }
    }

    /// Resolve replacement for value.
    fn resolveReplacement(self: *RangeOptimizer, value: Value) !Value {
        if (self.function.dfg.valueDef(value)) |def| {
            if (def.inst()) |inst| {
                if (self.replacements.get(inst)) |replacement| {
                    return replacement;
                }
            }
        }
        return value;
    }

    /// Remove dead instructions.
    fn removeDeadInsts(self: *RangeOptimizer) !void {
        for (self.dead_insts.items) |inst| {
            self.function.layout.removeInst(inst);
        }
        self.dead_insts.clearRetainingCapacity();
    }
};

/// Evaluate integer comparison with ranges.
/// Returns true if always true, false if always false, null if unknown.
fn evaluateIcmp(cond: IntCC, lhs: ValueRange, rhs: ValueRange) ?bool {
    if (lhs.isEmpty() or rhs.isEmpty()) return null;

    return switch (cond) {
        .eq => {
            // Equal only if both are same constant
            if (lhs.isConstant() and rhs.isConstant()) {
                return lhs.min == rhs.min;
            }
            // Never equal if ranges don't overlap
            if (lhs.max < rhs.min or rhs.max < lhs.min) {
                return false;
            }
            return null;
        },
        .ne => {
            // Not equal if ranges don't overlap
            if (lhs.max < rhs.min or rhs.max < lhs.min) {
                return true;
            }
            // Always equal if both same constant
            if (lhs.isConstant() and rhs.isConstant()) {
                return lhs.min != rhs.min;
            }
            return null;
        },
        .slt => {
            // Signed less than
            if (lhs.max < rhs.min) return true;
            if (lhs.min >= rhs.max) return false;
            return null;
        },
        .sle => {
            // Signed less or equal
            if (lhs.max <= rhs.min) return true;
            if (lhs.min > rhs.max) return false;
            return null;
        },
        .sgt => {
            // Signed greater than
            if (lhs.min > rhs.max) return true;
            if (lhs.max <= rhs.min) return false;
            return null;
        },
        .sge => {
            // Signed greater or equal
            if (lhs.min >= rhs.max) return true;
            if (lhs.max < rhs.min) return false;
            return null;
        },
        .ult => {
            // Unsigned less than - treat as unsigned comparison
            const lhs_min_u: u64 = @bitCast(lhs.min);
            const lhs_max_u: u64 = @bitCast(lhs.max);
            const rhs_min_u: u64 = @bitCast(rhs.min);
            const rhs_max_u: u64 = @bitCast(rhs.max);

            if (lhs_max_u < rhs_min_u) return true;
            if (lhs_min_u >= rhs_max_u) return false;
            return null;
        },
        .ule => {
            const lhs_min_u: u64 = @bitCast(lhs.min);
            const lhs_max_u: u64 = @bitCast(lhs.max);
            const rhs_min_u: u64 = @bitCast(rhs.min);
            const rhs_max_u: u64 = @bitCast(rhs.max);

            if (lhs_max_u <= rhs_min_u) return true;
            if (lhs_min_u > rhs_max_u) return false;
            return null;
        },
        .ugt => {
            const lhs_min_u: u64 = @bitCast(lhs.min);
            const lhs_max_u: u64 = @bitCast(lhs.max);
            const rhs_min_u: u64 = @bitCast(rhs.min);
            const rhs_max_u: u64 = @bitCast(rhs.max);

            if (lhs_min_u > rhs_max_u) return true;
            if (lhs_max_u <= rhs_min_u) return false;
            return null;
        },
        .uge => {
            const lhs_min_u: u64 = @bitCast(lhs.min);
            const lhs_max_u: u64 = @bitCast(lhs.max);
            const rhs_min_u: u64 = @bitCast(rhs.min);
            const rhs_max_u: u64 = @bitCast(rhs.max);

            if (lhs_min_u >= rhs_max_u) return true;
            if (lhs_max_u < rhs_min_u) return false;
            return null;
        },
    };
}
