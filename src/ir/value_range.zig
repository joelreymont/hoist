//! Value range analysis: track possible values of SSA values.
//! Enables optimizations: bounds check elimination, dead code elimination,
//! overflow check elimination, comparison simplification.

const std = @import("std");
const Type = @import("types.zig").Type;

/// Range of possible values for an SSA value.
/// Represents interval [min, max] with bit width and signedness.
pub const ValueRange = struct {
    /// Minimum possible value (signed interpretation).
    min: i64,

    /// Maximum possible value (signed interpretation).
    max: i64,

    /// Bit width of the value (8, 16, 32, 64).
    bits: u8,

    /// Whether this is a signed type.
    signed: bool,

    /// Empty range (unreachable code).
    pub fn empty(bits: u8, signed: bool) ValueRange {
        return .{
            .min = 1,
            .max = 0,
            .bits = bits,
            .signed = signed,
        };
    }

    /// Full range (unknown value).
    pub fn full(bits: u8, signed: bool) ValueRange {
        if (signed) {
            if (bits == 64) {
                return .{
                    .min = std.math.minInt(i64),
                    .max = std.math.maxInt(i64),
                    .bits = bits,
                    .signed = true,
                };
            }
            const half: i64 = @as(i64, 1) << @intCast(bits - 1);
            return .{
                .min = -half,
                .max = half - 1,
                .bits = bits,
                .signed = true,
            };
        } else {
            if (bits == 64) {
                // u64 max doesn't fit in i64, use i64 max
                return .{
                    .min = 0,
                    .max = std.math.maxInt(i64),
                    .bits = bits,
                    .signed = false,
                };
            }
            return .{
                .min = 0,
                .max = (@as(i64, 1) << @intCast(bits)) - 1,
                .bits = bits,
                .signed = false,
            };
        }
    }

    /// Single constant value.
    pub fn constant(value: i64, bits: u8, signed: bool) ValueRange {
        return .{
            .min = value,
            .max = value,
            .bits = bits,
            .signed = signed,
        };
    }

    /// Range from IR type.
    pub fn fromType(ty: Type) ValueRange {
        return switch (ty) {
            .i8 => full(8, true),
            .i16 => full(16, true),
            .i32 => full(32, true),
            .i64 => full(64, true),
            .f32, .f64 => unreachable, // No range analysis for floats
            .isize => full(64, true),
        };
    }

    /// Check if range is empty (unreachable).
    pub fn isEmpty(self: ValueRange) bool {
        return self.min > self.max;
    }

    /// Check if range contains single value.
    pub fn isConstant(self: ValueRange) bool {
        return self.min == self.max;
    }

    /// Get constant value if single value.
    pub fn getConstant(self: ValueRange) ?i64 {
        if (self.isConstant()) {
            return self.min;
        }
        return null;
    }

    /// Check if value is in range.
    pub fn contains(self: ValueRange, value: i64) bool {
        return value >= self.min and value <= self.max;
    }

    /// Intersection (meet): most precise range containing both.
    pub fn meet(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        const new_min = @max(self.min, other.min);
        const new_max = @min(self.max, other.max);

        return .{
            .min = new_min,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Union (join): least precise range containing both.
    pub fn join(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty()) return other;
        if (other.isEmpty()) return self;

        return .{
            .min = @min(self.min, other.min),
            .max = @max(self.max, other.max),
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Widen: expand range to ensure fixpoint convergence.
    /// Used when range keeps growing during iteration.
    pub fn widen(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty()) return other;
        if (other.isEmpty()) return self;

        // If other exceeds self, widen to full range in that direction
        const new_min = if (other.min < self.min)
            self.minBound()
        else
            self.min;

        const new_max = if (other.max > self.max)
            self.maxBound()
        else
            self.max;

        return .{
            .min = new_min,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Minimum bound for bit width and signedness.
    fn minBound(self: ValueRange) i64 {
        if (self.signed) {
            return -(@as(i64, 1) << @intCast(self.bits - 1));
        } else {
            return 0;
        }
    }

    /// Maximum bound for bit width and signedness.
    fn maxBound(self: ValueRange) i64 {
        if (self.signed) {
            return (@as(i64, 1) << @intCast(self.bits - 1)) - 1;
        } else {
            return (@as(i64, 1) << @intCast(self.bits)) - 1;
        }
    }

    /// Add two ranges (interval arithmetic).
    pub fn add(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        const min_sum = self.min + other.min;
        const max_sum = self.max + other.max;

        // Check for overflow
        const min_bound = self.minBound();
        const max_bound = self.maxBound();

        if (min_sum < min_bound or max_sum > max_bound) {
            // Overflow: return full range
            return full(self.bits, self.signed);
        }

        return .{
            .min = min_sum,
            .max = max_sum,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Subtract two ranges (interval arithmetic).
    pub fn sub(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        const min_diff = self.min - other.max;
        const max_diff = self.max - other.min;

        // Check for overflow
        const min_bound = self.minBound();
        const max_bound = self.maxBound();

        if (min_diff < min_bound or max_diff > max_bound) {
            return full(self.bits, self.signed);
        }

        return .{
            .min = min_diff,
            .max = max_diff,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Multiply two ranges (interval arithmetic).
    pub fn mul(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        // All four combinations of endpoints
        const products = [_]i64{
            self.min * other.min,
            self.min * other.max,
            self.max * other.min,
            self.max * other.max,
        };

        var min_prod: i64 = products[0];
        var max_prod: i64 = products[0];

        for (products[1..]) |p| {
            min_prod = @min(min_prod, p);
            max_prod = @max(max_prod, p);
        }

        const min_bound = self.minBound();
        const max_bound = self.maxBound();

        if (min_prod < min_bound or max_prod > max_bound) {
            return full(self.bits, self.signed);
        }

        return .{
            .min = min_prod,
            .max = max_prod,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Bitwise AND two ranges.
    pub fn bitAnd(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        // Conservative: AND can only make bits 0, so max is min of maxes
        // But min could be 0 (if any bit can be cleared)
        const new_max = @min(self.max, other.max);

        return .{
            .min = 0,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Bitwise OR two ranges.
    pub fn bitOr(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        // Conservative: OR can only make bits 1, so min is max of mins
        const new_min = @max(self.min, other.min);
        const new_max = self.maxBound(); // Could set any bit

        return .{
            .min = new_min,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Bitwise XOR two ranges.
    pub fn bitXor(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        // Very conservative: XOR can produce any value
        return full(self.bits, self.signed);
    }

    /// Left shift by constant amount.
    pub fn shl(self: ValueRange, shift: u6) ValueRange {
        if (self.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        const new_min = self.min << shift;
        const new_max = self.max << shift;

        const min_bound = self.minBound();
        const max_bound = self.maxBound();

        if (new_min < min_bound or new_max > max_bound) {
            return full(self.bits, self.signed);
        }

        return .{
            .min = new_min,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Unsigned right shift by constant amount.
    pub fn ushr(self: ValueRange, shift: u6) ValueRange {
        if (self.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        const new_min = @as(u64, @bitCast(self.min)) >> shift;
        const new_max = @as(u64, @bitCast(self.max)) >> shift;

        return .{
            .min = @bitCast(new_min),
            .max = @bitCast(new_max),
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Signed right shift by constant amount.
    pub fn sshr(self: ValueRange, shift: u6) ValueRange {
        if (self.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        const new_min = self.min >> shift;
        const new_max = self.max >> shift;

        return .{
            .min = new_min,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }
};

const Allocator = std.mem.Allocator;
const Function = @import("function.zig").Function;
const Value = @import("entities.zig").Value;
const Block = @import("entities.zig").Block;
const Inst = @import("entities.zig").Inst;
const InstructionData = @import("instruction_data.zig").InstructionData;
const Opcode = @import("opcodes.zig").Opcode;
const Imm64 = @import("immediates.zig").Imm64;

/// Value range analysis pass.
/// Computes possible value ranges for all SSA values via forward dataflow.
pub const RangeAnalysis = struct {
    allocator: Allocator,
    function: *Function,

    /// Ranges for each SSA value.
    ranges: std.AutoHashMap(Value, ValueRange),

    /// Block visit order (RPO for forward dataflow).
    visit_order: std.ArrayList(Block),

    pub fn init(allocator: Allocator, function: *Function) RangeAnalysis {
        return .{
            .allocator = allocator,
            .function = function,
            .ranges = std.AutoHashMap(Value, ValueRange).init(allocator),
            .visit_order = std.ArrayList(Block).init(allocator),
        };
    }

    pub fn deinit(self: *RangeAnalysis) void {
        self.ranges.deinit();
        self.visit_order.deinit(self.allocator);
    }

    /// Run range analysis to fixpoint.
    pub fn analyze(self: *RangeAnalysis) !void {
        // Compute RPO visit order
        try self.computeVisitOrder();

        // Initialize ranges for block parameters
        try self.initializeRanges();

        // Iterate to fixpoint
        var changed = true;
        var iteration: u32 = 0;
        const max_iterations: u32 = 100;

        while (changed and iteration < max_iterations) : (iteration += 1) {
            changed = false;

            for (self.visit_order.items) |block| {
                if (try self.visitBlock(block)) {
                    changed = true;
                }
            }
        }
    }

    /// Get range for value.
    pub fn getRange(self: *RangeAnalysis, value: Value) ?ValueRange {
        return self.ranges.get(value);
    }

    /// Compute reverse postorder visit order.
    fn computeVisitOrder(self: *RangeAnalysis) !void {
        self.visit_order.clearRetainingCapacity();

        // Use function layout order (approximation of RPO)
        var block_iter = self.function.layout.blocks();
        while (block_iter.next()) |block| {
            try self.visit_order.append(self.allocator, block);
        }
    }

    /// Initialize ranges for block parameters.
    fn initializeRanges(self: *RangeAnalysis) !void {
        var block_iter = self.function.layout.blocks();
        while (block_iter.next()) |block| {
            const params = self.function.dfg.blockParams(block);
            for (params) |param| {
                const ty = self.function.dfg.valueType(param);
                const range = ValueRange.fromType(ty);
                try self.ranges.put(param, range);
            }
        }
    }

    /// Visit block, propagate ranges through instructions.
    /// Returns true if any range changed.
    fn visitBlock(self: *RangeAnalysis, block: Block) !bool {
        var changed = false;

        var inst_iter = self.function.layout.blockInsts(block);
        while (inst_iter.next()) |inst| {
            if (try self.visitInst(inst)) {
                changed = true;
            }
        }

        return changed;
    }

    /// Visit instruction, compute result ranges.
    fn visitInst(self: *RangeAnalysis, inst: Inst) !bool {
        const data = self.function.dfg.insts.items[@intFromEnum(inst)];
        const results = self.function.dfg.instResults(inst);

        if (results.len == 0) return false;

        const result = results[0];
        const ty = self.function.dfg.valueType(result);

        // Compute range based on opcode
        const new_range = switch (data) {
            .unary_imm => |u| blk: {
                if (u.opcode == .iconst) {
                    const bits = ty.bits() orelse 64;
                    const signed = ty.isSigned();
                    break :blk ValueRange.constant(u.imm.bits, bits, signed);
                }
                break :blk ValueRange.fromType(ty);
            },
            .binary => |b| try self.visitBinary(b.opcode, b.args, ty),
            .binary_imm64 => |bi| try self.visitBinaryImm(bi.opcode, bi.arg, bi.imm, ty),
            .unary => |u| try self.visitUnary(u.opcode, u.arg, ty),
            else => ValueRange.fromType(ty),
        };

        // Update range if changed
        if (self.ranges.get(result)) |old_range| {
            const joined = old_range.join(new_range);
            if (!rangesEqual(old_range, joined)) {
                try self.ranges.put(result, joined);
                return true;
            }
            return false;
        } else {
            try self.ranges.put(result, new_range);
            return true;
        }
    }

    /// Visit binary operation.
    fn visitBinary(self: *RangeAnalysis, opcode: Opcode, args: [2]Value, ty: Type) !ValueRange {
        const lhs_range = self.ranges.get(args[0]) orelse ValueRange.fromType(ty);
        const rhs_range = self.ranges.get(args[1]) orelse ValueRange.fromType(ty);

        return switch (opcode) {
            .iadd => lhs_range.add(rhs_range),
            .isub => lhs_range.sub(rhs_range),
            .imul => lhs_range.mul(rhs_range),
            .band => lhs_range.bitAnd(rhs_range),
            .bor => lhs_range.bitOr(rhs_range),
            .bxor => lhs_range.bitXor(rhs_range),
            else => ValueRange.fromType(ty),
        };
    }

    /// Visit binary operation with immediate.
    fn visitBinaryImm(self: *RangeAnalysis, opcode: Opcode, arg: Value, imm: Imm64, ty: Type) !ValueRange {
        const arg_range = self.ranges.get(arg) orelse ValueRange.fromType(ty);
        const bits = ty.bits() orelse 64;
        const signed = ty.isSigned();
        const imm_range = ValueRange.constant(imm.bits, bits, signed);

        return switch (opcode) {
            .iadd_imm => arg_range.add(imm_range),
            .ishl_imm => if (imm.bits >= 0 and imm.bits < 64)
                arg_range.shl(@intCast(imm.bits))
            else
                ValueRange.fromType(ty),
            .ushr_imm => if (imm.bits >= 0 and imm.bits < 64)
                arg_range.ushr(@intCast(imm.bits))
            else
                ValueRange.fromType(ty),
            .sshr_imm => if (imm.bits >= 0 and imm.bits < 64)
                arg_range.sshr(@intCast(imm.bits))
            else
                ValueRange.fromType(ty),
            else => ValueRange.fromType(ty),
        };
    }

    /// Visit unary operation.
    fn visitUnary(self: *RangeAnalysis, opcode: Opcode, arg: Value, ty: Type) !ValueRange {
        const arg_range = self.ranges.get(arg) orelse ValueRange.fromType(ty);

        return switch (opcode) {
            .bnot => ValueRange.fromType(ty), // Conservative
            else => arg_range,
        };
    }

    /// Check if two ranges are equal.
    fn rangesEqual(a: ValueRange, b: ValueRange) bool {
        return a.min == b.min and a.max == b.max and a.bits == b.bits and a.signed == b.signed;
    }
};
