//! Strength Reduction optimization pass.
//!
//! Replaces expensive operations with cheaper equivalents:
//! - Multiply by power-of-2 → left shift
//! - Unsigned divide by power-of-2 → right shift
//! - Signed divide by power-of-2 → arithmetic right shift (with adjustment)
//! - Modulo by power-of-2 → bitwise AND
//! - Induction variable optimization

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir = @import("../../ir.zig");
const Function = ir.Function;
const Block = ir.Block;
const Inst = ir.Inst;
const Value = ir.Value;
const Type = ir.Type;
const Opcode = @import("../../ir/opcodes.zig").Opcode;
const InstructionData = ir.InstructionData;
const instruction_data = @import("../../ir/instruction_data.zig");
const BinaryData = instruction_data.BinaryData;
const UnaryData = instruction_data.UnaryData;
const div_const = @import("div_const.zig");

/// Strength reduction pass.
pub const StrengthReduction = struct {
    allocator: Allocator,
    changed: bool,

    pub fn init(allocator: Allocator) StrengthReduction {
        return .{
            .allocator = allocator,
            .changed = false,
        };
    }

    pub fn deinit(self: *StrengthReduction) void {
        _ = self;
    }

    /// Run strength reduction on the function.
    /// Returns true if any optimizations were applied.
    pub fn run(self: *StrengthReduction, func: *Function) !bool {
        self.changed = false;

        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            try self.processBlock(func, block);
        }

        return self.changed;
    }

    fn processBlock(self: *StrengthReduction, func: *Function, block: Block) !void {
        var inst_iter = func.layout.blockInsts(block);
        while (inst_iter.next()) |inst| {
            const inst_data = func.dfg.insts.get(inst) orelse continue;
            try self.processInst(func, inst, inst_data);
        }
    }

    fn processInst(self: *StrengthReduction, func: *Function, inst: Inst, inst_data: *const InstructionData) !void {
        switch (inst_data.*) {
            .binary => |data| {
                switch (data.opcode) {
                    .imul => try self.reduceMul(func, inst, data),
                    .udiv => try self.reduceUdiv(func, inst, data),
                    .sdiv => try self.reduceSdiv(func, inst, data),
                    .urem => try self.reduceUrem(func, inst, data),
                    .srem => try self.reduceSrem(func, inst, data),
                    else => {},
                }
            },
            else => {},
        }
    }

    /// Reduce multiply by power-of-2 to left shift.
    fn reduceMul(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData) !void {
        const log2 = try self.getPowerOfTwo(func, data.args[1]) orelse return;

        // Create constant for shift amount
        const shift_imm = @import("../../ir/immediates.zig").Imm64.new(log2);
        const shift_inst_data = InstructionData{ .unary_imm = @import("../../ir/instruction_data.zig").UnaryImmData.init(.iconst, shift_imm) };
        const shift_inst = try func.dfg.makeInst(shift_inst_data);
        const val_type = func.dfg.valueType(data.args[0]) orelse return;
        const shift_val = try func.dfg.appendInstResult(shift_inst, val_type);

        const new_data = InstructionData{ .binary = BinaryData.init(.ishl, data.args[0], shift_val) };
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = new_data;
        self.changed = true;
    }

    /// Reduce unsigned divide by power-of-2 to right shift.
    /// For non-power-of-2, use magic number multiply-shift.
    fn reduceUdiv(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData) !void {
        const ty = func.dfg.valueType(data.args[0]) orelse return;

        // Try power-of-2 optimization first
        if (try self.getPowerOfTwo(func, data.args[1])) |log2| {
            // Create constant for shift amount
            const shift_imm = @import("../../ir/immediates.zig").Imm64.new(log2);
            const shift_inst_data = InstructionData{ .unary_imm = @import("../../ir/instruction_data.zig").UnaryImmData.init(.iconst, shift_imm) };
            const shift_inst = try func.dfg.makeInst(shift_inst_data);
            const shift_val = try func.dfg.appendInstResult(shift_inst, ty);

            const new_data = InstructionData{ .binary = BinaryData.init(.ushr, data.args[0], shift_val) };
            const inst_mut = func.dfg.insts.getMut(inst) orelse return;
            inst_mut.* = new_data;
            self.changed = true;
            return;
        }

        // Try magic number optimization for non-power-of-2
        const divisor = try self.getConstantU64(func, data.args[1]) orelse return;
        if (divisor == 0 or divisor == 1) return;

        if (ty.eql(Type.I32)) {
            try self.reduceUdiv32Magic(func, inst, data, @intCast(divisor));
        } else if (ty.eql(Type.I64)) {
            try self.reduceUdiv64Magic(func, inst, data, divisor);
        }
    }

    /// Reduce u32 divide by constant using magic numbers.
    fn reduceUdiv32Magic(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData, divisor: u32) !void {
        const magic = div_const.magicU32(divisor);
        const ty = Type.I32;

        const Imm64 = @import("../../ir/immediates.zig").Imm64;
        const UnaryImmData = @import("../../ir/instruction_data.zig").UnaryImmData;

        // Load magic multiplier
        const mul_imm = Imm64.new(magic.mul_by);
        const mul_const_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, mul_imm) };
        const mul_const_inst = try func.dfg.makeInst(mul_const_data);
        const mul_const_val = try func.dfg.appendInstResult(mul_const_inst, ty);

        // Multiply: dividend * magic
        const mul_data = InstructionData{ .binary = BinaryData.init(.umulhi, data.args[0], mul_const_val) };
        const mul_inst = try func.dfg.makeInst(mul_data);
        var result_val = try func.dfg.appendInstResult(mul_inst, ty);

        // Add dividend if needed
        if (magic.do_add) {
            const add_data = InstructionData{ .binary = BinaryData.init(.iadd, result_val, data.args[0]) };
            const add_inst = try func.dfg.makeInst(add_data);
            result_val = try func.dfg.appendInstResult(add_inst, ty);

            // Right shift by 1
            const shift1_imm = Imm64.new(1);
            const shift1_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, shift1_imm) };
            const shift1_inst = try func.dfg.makeInst(shift1_data);
            const shift1_val = try func.dfg.appendInstResult(shift1_inst, ty);

            const shr1_data = InstructionData{ .binary = BinaryData.init(.ushr, result_val, shift1_val) };
            const shr1_inst = try func.dfg.makeInst(shr1_data);
            result_val = try func.dfg.appendInstResult(shr1_inst, ty);
        }

        // Final shift
        const shift_imm = Imm64.new(if (magic.shift_by > 0) magic.shift_by else 0);
        const shift_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, shift_imm) };
        const shift_inst = try func.dfg.makeInst(shift_data);
        const shift_val = try func.dfg.appendInstResult(shift_inst, ty);

        const new_data = InstructionData{ .binary = BinaryData.init(.ushr, result_val, shift_val) };
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = new_data;

        self.changed = true;
    }

    /// Reduce u64 divide by constant using magic numbers.
    fn reduceUdiv64Magic(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData, divisor: u64) !void {
        const magic = div_const.magicU64(divisor);
        const ty = Type.I64;

        const Imm64 = @import("../../ir/immediates.zig").Imm64;
        const UnaryImmData = @import("../../ir/instruction_data.zig").UnaryImmData;

        // Load magic multiplier
        const mul_imm = Imm64.new(@bitCast(magic.mul_by));
        const mul_const_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, mul_imm) };
        const mul_const_inst = try func.dfg.makeInst(mul_const_data);
        const mul_const_val = try func.dfg.appendInstResult(mul_const_inst, ty);

        // Multiply: dividend * magic
        const mul_data = InstructionData{ .binary = BinaryData.init(.umulhi, data.args[0], mul_const_val) };
        const mul_inst = try func.dfg.makeInst(mul_data);
        var result_val = try func.dfg.appendInstResult(mul_inst, ty);

        // Add dividend if needed
        if (magic.do_add) {
            const add_data = InstructionData{ .binary = BinaryData.init(.iadd, result_val, data.args[0]) };
            const add_inst = try func.dfg.makeInst(add_data);
            result_val = try func.dfg.appendInstResult(add_inst, ty);

            // Right shift by 1
            const shift1_imm = Imm64.new(1);
            const shift1_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, shift1_imm) };
            const shift1_inst = try func.dfg.makeInst(shift1_data);
            const shift1_val = try func.dfg.appendInstResult(shift1_inst, ty);

            const shr1_data = InstructionData{ .binary = BinaryData.init(.ushr, result_val, shift1_val) };
            const shr1_inst = try func.dfg.makeInst(shr1_data);
            result_val = try func.dfg.appendInstResult(shr1_inst, ty);
        }

        // Final shift
        const shift_imm = Imm64.new(if (magic.shift_by > 0) magic.shift_by else 0);
        const shift_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, shift_imm) };
        const shift_inst = try func.dfg.makeInst(shift_data);
        const shift_val = try func.dfg.appendInstResult(shift_inst, ty);

        const new_data = InstructionData{ .binary = BinaryData.init(.ushr, result_val, shift_val) };
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = new_data;

        self.changed = true;
    }

    /// Old power-of-2 path, now integrated above - unused.
    fn reduceUdiv_OLD(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData) !void {
        const log2 = try self.getPowerOfTwo(func, data.args[1]) orelse return;

        // Create constant for shift amount
        const shift_imm = @import("../../ir/immediates.zig").Imm64.new(log2);
        const shift_inst_data = InstructionData{ .unary_imm = @import("../../ir/instruction_data.zig").UnaryImmData.init(.iconst, shift_imm) };
        const shift_inst = try func.dfg.makeInst(shift_inst_data);
        const shift_val = try func.dfg.appendInstResult(shift_inst, func.dfg.valueType(data.args[0]) orelse return);

        const new_data = InstructionData{ .binary = BinaryData.init(.ushr, data.args[0], shift_val) };
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = new_data;
        self.changed = true;
    }

    /// Reduce signed divide by power-of-2 to arithmetic right shift.
    /// For x / 2^N, computes: (x + ((x >> (bits-1)) & (2^N - 1))) >> N
    /// This correctly rounds toward zero for negative values.
    fn reduceSdiv(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData) !void {
        const log2 = try self.getPowerOfTwo(func, data.args[1]) orelse return;

        // Get type info to determine bit width
        const ty = func.dfg.valueType(data.args[0]) orelse return;
        const bits: u7 = if (ty.eql(Type.I8))
            8
        else if (ty.eql(Type.I16))
            16
        else if (ty.eql(Type.I32))
            32
        else if (ty.eql(Type.I64))
            64
        else
            return; // Not a supported integer type

        // Create constants
        const Imm64 = @import("../../ir/immediates.zig").Imm64;
        const UnaryImmData = @import("../../ir/instruction_data.zig").UnaryImmData;

        // Constant for sign extraction: bits - 1
        const sign_shift = Imm64.new(bits - 1);
        const sign_shift_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, sign_shift) };
        const sign_shift_inst = try func.dfg.makeInst(sign_shift_data);
        const sign_shift_val = try func.dfg.appendInstResult(sign_shift_inst, ty);

        // Extract sign: x >> (bits-1) - arithmetic shift replicates sign bit
        const sign_data = InstructionData{ .binary = BinaryData.init(.sshr, data.args[0], sign_shift_val) };
        const sign_inst = try func.dfg.makeInst(sign_data);
        const sign_val = try func.dfg.appendInstResult(sign_inst, ty);

        // Constant for bias mask: 2^N - 1
        const bias_mask = Imm64.new((@as(i64, 1) << @intCast(log2)) - 1);
        const bias_mask_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, bias_mask) };
        const bias_mask_inst = try func.dfg.makeInst(bias_mask_data);
        const bias_mask_val = try func.dfg.appendInstResult(bias_mask_inst, ty);

        // Compute bias: sign & (2^N - 1)
        const bias_data = InstructionData{ .binary = BinaryData.init(.band, sign_val, bias_mask_val) };
        const bias_inst = try func.dfg.makeInst(bias_data);
        const bias_val = try func.dfg.appendInstResult(bias_inst, ty);

        // Add bias: x + bias
        const biased_data = InstructionData{ .binary = BinaryData.init(.iadd, data.args[0], bias_val) };
        const biased_inst = try func.dfg.makeInst(biased_data);
        const biased_val = try func.dfg.appendInstResult(biased_inst, ty);

        // Constant for final shift: N
        const shift_imm = Imm64.new(log2);
        const shift_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, shift_imm) };
        const shift_inst = try func.dfg.makeInst(shift_data);
        const shift_val = try func.dfg.appendInstResult(shift_inst, ty);

        // Final shift: (x + bias) >> N - arithmetic shift
        const new_data = InstructionData{ .binary = BinaryData.init(.sshr, biased_val, shift_val) };
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = new_data;
        self.changed = true;
    }

    /// Reduce unsigned remainder by power-of-2 to bitwise AND.
    /// x % N becomes x & (N-1) when N is a power of 2.
    fn reduceUrem(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData) !void {
        const log2 = try self.getPowerOfTwo(func, data.args[1]) orelse return;

        // Create constant for mask (2^log2 - 1)
        const mask_val: i64 = (@as(i64, 1) << @intCast(log2)) - 1;
        const mask_imm = @import("../../ir/immediates.zig").Imm64.new(mask_val);
        const mask_inst_data = InstructionData{ .unary_imm = @import("../../ir/instruction_data.zig").UnaryImmData.init(.iconst, mask_imm) };
        const mask_inst = try func.dfg.makeInst(mask_inst_data);
        const mask = try func.dfg.appendInstResult(mask_inst, func.dfg.valueType(data.args[0]) orelse return);

        const new_data = InstructionData{ .binary = BinaryData.init(.band, data.args[0], mask) };
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = new_data;
        self.changed = true;
    }

    /// Reduce signed remainder by power-of-2.
    /// For x % 2^N, computes: x - ((x + bias) >> N) << N
    /// where bias = (x >> (bits-1)) & (2^N - 1)
    fn reduceSrem(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData) !void {
        const log2 = try self.getPowerOfTwo(func, data.args[1]) orelse return;

        // Get type info to determine bit width
        const ty = func.dfg.valueType(data.args[0]) orelse return;
        const bits: u7 = if (ty.eql(Type.I8))
            8
        else if (ty.eql(Type.I16))
            16
        else if (ty.eql(Type.I32))
            32
        else if (ty.eql(Type.I64))
            64
        else
            return; // Not a supported integer type

        // Create constants
        const Imm64 = @import("../../ir/immediates.zig").Imm64;
        const UnaryImmData = @import("../../ir/instruction_data.zig").UnaryImmData;

        // Constant for sign extraction: bits - 1
        const sign_shift = Imm64.new(bits - 1);
        const sign_shift_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, sign_shift) };
        const sign_shift_inst = try func.dfg.makeInst(sign_shift_data);
        const sign_shift_val = try func.dfg.appendInstResult(sign_shift_inst, ty);

        // Extract sign: x >> (bits-1)
        const sign_data = InstructionData{ .binary = BinaryData.init(.sshr, data.args[0], sign_shift_val) };
        const sign_inst = try func.dfg.makeInst(sign_data);
        const sign_val = try func.dfg.appendInstResult(sign_inst, ty);

        // Constant for bias mask: 2^N - 1
        const bias_mask = Imm64.new((@as(i64, 1) << @intCast(log2)) - 1);
        const bias_mask_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, bias_mask) };
        const bias_mask_inst = try func.dfg.makeInst(bias_mask_data);
        const bias_mask_val = try func.dfg.appendInstResult(bias_mask_inst, ty);

        // Compute bias: sign & (2^N - 1)
        const bias_data = InstructionData{ .binary = BinaryData.init(.band, sign_val, bias_mask_val) };
        const bias_inst = try func.dfg.makeInst(bias_data);
        const bias_val = try func.dfg.appendInstResult(bias_inst, ty);

        // Add bias: x + bias
        const biased_data = InstructionData{ .binary = BinaryData.init(.iadd, data.args[0], bias_val) };
        const biased_inst = try func.dfg.makeInst(biased_data);
        const biased_val = try func.dfg.appendInstResult(biased_inst, ty);

        // Constant for arithmetic shift: N
        const arith_shift_imm = Imm64.new(log2);
        const arith_shift_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, arith_shift_imm) };
        const arith_shift_inst = try func.dfg.makeInst(arith_shift_data);
        const arith_shift_val = try func.dfg.appendInstResult(arith_shift_inst, ty);

        // Arithmetic shift right: (x + bias) >> N
        const quot_data = InstructionData{ .binary = BinaryData.init(.sshr, biased_val, arith_shift_val) };
        const quot_inst = try func.dfg.makeInst(quot_data);
        const quot_val = try func.dfg.appendInstResult(quot_inst, ty);

        // Constant for left shift: N
        const left_shift_imm = Imm64.new(log2);
        const left_shift_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, left_shift_imm) };
        const left_shift_inst = try func.dfg.makeInst(left_shift_data);
        const left_shift_val = try func.dfg.appendInstResult(left_shift_inst, ty);

        // Left shift: quot << N
        const prod_data = InstructionData{ .binary = BinaryData.init(.ishl, quot_val, left_shift_val) };
        const prod_inst = try func.dfg.makeInst(prod_data);
        const prod_val = try func.dfg.appendInstResult(prod_inst, ty);

        // Subtract: x - (quot << N)
        const new_data = InstructionData{ .binary = BinaryData.init(.isub, data.args[0], prod_val) };
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = new_data;
        self.changed = true;
    }

    /// Get constant u64 value from a Value.
    fn getConstantU64(self: *StrengthReduction, func: *const Function, value: Value) !?u64 {
        _ = self;
        const value_def = func.dfg.valueDef(value) orelse return null;
        const defining_inst = switch (value_def) {
            .result => |r| r.inst,
            else => return null,
        };

        const inst_data = func.dfg.insts.get(defining_inst) orelse return null;
        const imm_val = switch (inst_data.*) {
            .unary_imm => |d| if (d.opcode == .iconst) d.imm.bits() else return null,
            else => return null,
        };

        if (imm_val <= 0) return null;
        return @intCast(imm_val);
    }

    /// Check if a value is a constant power of two.
    /// Returns the power if true, null otherwise.
    fn getPowerOfTwo(self: *StrengthReduction, func: *const Function, value: Value) !?u6 {
        const uval = try self.getConstantU64(func, value) orelse return null;

        // Check if power of 2: exactly one bit set
        if (uval == 0 or (uval & (uval - 1)) != 0) return null;

        // Return log2
        const log2_val = @ctz(uval);
        if (log2_val > 63) return null;
        return @intCast(log2_val);
    }
};

// Tests

const testing = std.testing;

test "StrengthReduction: init and deinit" {
    var sr = StrengthReduction.init(testing.allocator);
    defer sr.deinit();

    try testing.expect(!sr.changed);
}

test "StrengthReduction: run on empty function" {
    const sig = @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var sr = StrengthReduction.init(testing.allocator);
    defer sr.deinit();

    const changed = try sr.run(&func);
    try testing.expect(!changed);
}

test "StrengthReduction: preserve non-arithmetic instructions" {
    const sig = @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const block = try func.dfg.makeBlock();
    try func.layout.appendBlock(block);

    const ret_data = InstructionData{ .nullary = .{ .opcode = .@"return" } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, block);

    var sr = StrengthReduction.init(testing.allocator);
    defer sr.deinit();

    const changed = try sr.run(&func);
    try testing.expect(!changed);
}
test "StrengthReduction: sdiv by power-of-2 generates bias correction" {
    const sig = @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const block = try func.dfg.makeBlock();
    try func.layout.appendBlock(block);

    // Create x parameter
    const x = try func.dfg.appendBlockParam(block, @import("../../ir/types.zig").Type.I32);

    // Create constant 8 (power of 2)
    const Imm64 = @import("../../ir/immediates.zig").Imm64;
    const UnaryImmData = @import("../../ir/instruction_data.zig").UnaryImmData;
    const const_8_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, Imm64.new(8)) };
    const const_8_inst = try func.dfg.makeInst(const_8_data);
    try func.layout.appendInst(const_8_inst, block);
    const const_8 = try func.dfg.appendInstResult(const_8_inst, @import("../../ir/types.zig").Type.I32);

    // Create sdiv instruction: x / 8
    const sdiv_data = InstructionData{ .binary = BinaryData.init(.sdiv, x, const_8) };
    const sdiv_inst = try func.dfg.makeInst(sdiv_data);
    try func.layout.appendInst(sdiv_inst, block);
    _ = try func.dfg.appendInstResult(sdiv_inst, @import("../../ir/types.zig").Type.I32);

    // Run strength reduction
    var sr = StrengthReduction.init(testing.allocator);
    defer sr.deinit();

    const changed = try sr.run(&func);
    try testing.expect(changed);

    // Verify the sdiv was transformed (instruction count increased due to bias correction)
    const initial_inst_count: usize = 2; // const_8 + sdiv
    try testing.expect(func.dfg.insts.elems.items.len > initial_inst_count);
}

test "StrengthReduction: srem by power-of-2 generates bias correction" {
    const sig = @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const block = try func.dfg.makeBlock();
    try func.layout.appendBlock(block);

    // Create x parameter
    const x = try func.dfg.appendBlockParam(block, @import("../../ir/types.zig").Type.I32);

    // Create constant 4 (power of 2)
    const Imm64 = @import("../../ir/immediates.zig").Imm64;
    const UnaryImmData = @import("../../ir/instruction_data.zig").UnaryImmData;
    const const_4_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, Imm64.new(4)) };
    const const_4_inst = try func.dfg.makeInst(const_4_data);
    try func.layout.appendInst(const_4_inst, block);
    const const_4 = try func.dfg.appendInstResult(const_4_inst, @import("../../ir/types.zig").Type.I32);

    // Create srem instruction: x % 4
    const srem_data = InstructionData{ .binary = BinaryData.init(.srem, x, const_4) };
    const srem_inst = try func.dfg.makeInst(srem_data);
    try func.layout.appendInst(srem_inst, block);
    _ = try func.dfg.appendInstResult(srem_inst, @import("../../ir/types.zig").Type.I32);

    // Run strength reduction
    var sr = StrengthReduction.init(testing.allocator);
    defer sr.deinit();

    const changed = try sr.run(&func);
    try testing.expect(changed);

    // Verify the srem was transformed (instruction count increased due to bias correction)
    const initial_inst_count: usize = 2; // const_4 + srem
    try testing.expect(func.dfg.insts.elems.items.len > initial_inst_count);
}

test "StrengthReduction: sdiv/srem by non-power-of-2 unchanged" {
    const sig = @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const block = try func.dfg.makeBlock();
    try func.layout.appendBlock(block);

    // Create x parameter
    const x = try func.dfg.appendBlockParam(block, @import("../../ir/types.zig").Type.I32);

    // Create constant 7 (not a power of 2)
    const Imm64 = @import("../../ir/immediates.zig").Imm64;
    const UnaryImmData = @import("../../ir/instruction_data.zig").UnaryImmData;
    const const_7_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, Imm64.new(7)) };
    const const_7_inst = try func.dfg.makeInst(const_7_data);
    try func.layout.appendInst(const_7_inst, block);
    const const_7 = try func.dfg.appendInstResult(const_7_inst, @import("../../ir/types.zig").Type.I32);

    // Create sdiv and srem instructions
    const sdiv_data = InstructionData{ .binary = BinaryData.init(.sdiv, x, const_7) };
    const sdiv_inst = try func.dfg.makeInst(sdiv_data);
    try func.layout.appendInst(sdiv_inst, block);
    _ = try func.dfg.appendInstResult(sdiv_inst, @import("../../ir/types.zig").Type.I32);

    const srem_data = InstructionData{ .binary = BinaryData.init(.srem, x, const_7) };
    const srem_inst = try func.dfg.makeInst(srem_data);
    try func.layout.appendInst(srem_inst, block);
    _ = try func.dfg.appendInstResult(srem_inst, @import("../../ir/types.zig").Type.I32);

    // Run strength reduction
    var sr = StrengthReduction.init(testing.allocator);
    defer sr.deinit();

    const changed = try sr.run(&func);
    try testing.expect(!changed);
}
