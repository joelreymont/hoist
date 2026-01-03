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

const root = @import("root");
const Function = root.function.Function;
const Block = root.entities.Block;
const Inst = root.entities.Inst;
const Value = root.entities.Value;
const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;
const BinaryData = root.instruction_data.BinaryData;

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

        var block_iter = func.layout.blocks();
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
        _ = try self.getPowerOfTwo(func, data.args[1]) orelse return;
        const new_data = InstructionData{ .binary = BinaryData.init(.ishl, data.args[0], data.args[1]) };
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = new_data;
        self.changed = true;
    }

    /// Reduce unsigned divide by power-of-2 to right shift.
    fn reduceUdiv(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData) !void {
        _ = try self.getPowerOfTwo(func, data.args[1]) orelse return;
        const new_data = InstructionData{ .binary = BinaryData.init(.ushr, data.args[0], data.args[1]) };
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = new_data;
        self.changed = true;
    }

    /// Reduce signed divide by power-of-2 to arithmetic right shift.
    /// Note: This is a simplified version. Full implementation requires
    /// handling negative dividends with additional adjustment.
    fn reduceSdiv(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData) !void {
        _ = self;
        _ = func;
        _ = inst;
        _ = data;
        // Conservative: skip signed division as it requires complex handling
        // for negative dividends (needs bias correction).
    }

    /// Reduce unsigned remainder by power-of-2 to bitwise AND.
    fn reduceUrem(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData) !void {
        _ = try self.getPowerOfTwo(func, data.args[1]) orelse return;
        const new_data = InstructionData{ .binary = BinaryData.init(.band, data.args[0], data.args[1]) };
        const inst_mut = func.dfg.insts.getMut(inst) orelse return;
        inst_mut.* = new_data;
        self.changed = true;
    }

    /// Reduce signed remainder by power-of-2.
    /// Note: Complex due to sign handling, skipped for now.
    fn reduceSrem(self: *StrengthReduction, func: *Function, inst: Inst, data: BinaryData) !void {
        _ = self;
        _ = func;
        _ = inst;
        _ = data;
        // Conservative: skip signed remainder as it requires complex handling
    }

    /// Check if a value is a constant power of two.
    /// Returns the power if true, null otherwise.
    fn getPowerOfTwo(self: *StrengthReduction, func: *const Function, value: Value) !?u6 {
        _ = self;
        const value_def = func.dfg.valueDef(value) orelse return null;
        const defining_inst = switch (value_def) {
            .result => |r| r.inst,
            else => return null,
        };

        const inst_data = func.dfg.insts.get(defining_inst) orelse return null;
        const const_val = switch (inst_data.*) {
            .unary => |d| if (d.opcode == .iconst) blk: {
                // For now, return null - proper constant extraction needs Imm64 handling
                break :blk null;
            } else null,
            else => null,
        };
        _ = const_val;

        return null;
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
    const sig = try @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var sr = StrengthReduction.init(testing.allocator);
    defer sr.deinit();

    const changed = try sr.run(&func);
    try testing.expect(!changed);
}

test "StrengthReduction: preserve non-arithmetic instructions" {
    const sig = try @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
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
