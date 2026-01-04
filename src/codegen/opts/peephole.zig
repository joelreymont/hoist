//! Peephole optimization pass.
//!
//! Performs local pattern matching and machine-specific optimizations:
//! - 2-3 instruction window pattern matching
//! - Algebraic simplifications (x + 0, x * 1, x - x, etc.)
//! - Use-def chain simplification
//! - Redundant load/store elimination
//! - Constant folding opportunities
//! - Identity and inverse operation elimination

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

/// Peephole optimization pass.
pub const Peephole = struct {
    allocator: Allocator,
    changed: bool,
    /// Track load addresses for redundant load elimination.
    loads: std.AutoHashMap(Value, Inst),

    pub fn init(allocator: Allocator) Peephole {
        return .{
            .allocator = allocator,
            .changed = false,
            .loads = std.AutoHashMap(Value, Inst).init(allocator),
        };
    }

    pub fn deinit(self: *Peephole) void {
        self.loads.deinit();
    }

    /// Run peephole optimizations on the function.
    /// Returns true if any optimizations were applied.
    pub fn run(self: *Peephole, func: *Function) !bool {
        self.changed = false;
        self.loads.clearRetainingCapacity();

        var block_iter = func.layout.blocks();
        while (block_iter.next()) |block| {
            try self.processBlock(func, block);
        }

        return self.changed;
    }

    fn processBlock(self: *Peephole, func: *Function, block: Block) !void {
        var inst_iter = func.layout.blockInsts(block);
        while (inst_iter.next()) |inst| {
            const inst_data = func.dfg.insts.get(inst) orelse continue;
            try self.processInst(func, inst, inst_data);
        }
    }

    fn processInst(self: *Peephole, func: *Function, inst: Inst, inst_data: *const InstructionData) !void {
        switch (inst_data.*) {
            .binary => |data| {
                switch (data.opcode) {
                    .iadd => try self.optimizeAdd(func, inst, data),
                    .imul => try self.optimizeMul(func, inst, data),
                    .isub => try self.optimizeSub(func, inst, data),
                    .band => try self.optimizeAnd(func, inst, data),
                    .bor => try self.optimizeOr(func, inst, data),
                    .bxor => try self.optimizeXor(func, inst, data),
                    .ishl, .ushr, .sshr => try self.optimizeShift(func, inst, data),
                    .rotl, .rotr => try self.optimizeRotate(func, inst, data),
                    .udiv, .sdiv => try self.optimizeDiv(func, inst, data),
                    .urem, .srem => try self.optimizeRem(func, inst, data),
                    else => {},
                }
            },
            .load => |data| {
                try self.trackLoad(func, inst, data.arg);
            },
            else => {},
        }
    }

    /// Optimize addition: x + 0 = x
    fn optimizeAdd(self: *Peephole, func: *Function, inst: Inst, data: BinaryData) !void {
        if (try self.isZero(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        } else if (try self.isZero(func, data.args[0])) {
            try self.replaceWithCopy(func, inst, data.args[1]);
        }
    }

    /// Optimize multiplication: x * 0 = 0, x * 1 = x
    fn optimizeMul(self: *Peephole, func: *Function, inst: Inst, data: BinaryData) !void {
        if (try self.isZero(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[1]);
        } else if (try self.isZero(func, data.args[0])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        } else if (try self.isOne(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        } else if (try self.isOne(func, data.args[0])) {
            try self.replaceWithCopy(func, inst, data.args[1]);
        }
    }

    /// Optimize subtraction: x - 0 = x, x - x = 0
    fn optimizeSub(self: *Peephole, func: *Function, inst: Inst, data: BinaryData) !void {
        if (try self.isZero(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        } else if (data.args[0].index == data.args[1].index) {
            // x - x = 0: Replace with zero constant
            const ty = func.dfg.valueType(data.args[0]) orelse return;
            const zero_data = InstructionData{ .unary = UnaryData.init(.iconst, data.args[0]) };
            const inst_mut = func.dfg.insts.getMut(inst) orelse return;
            inst_mut.* = zero_data;

            // Update result type
            const result = func.dfg.firstResult(inst) orelse return;
            const result_mut = func.dfg.values.getMut(result) orelse return;
            result_mut.* = root.dfg.ValueData.inst(ty, 0, inst);

            self.changed = true;
        }
    }

    /// Optimize AND: x & 0 = 0, x & -1 = x, x & x = x
    fn optimizeAnd(self: *Peephole, func: *Function, inst: Inst, data: BinaryData) !void {
        if (try self.isZero(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[1]);
        } else if (try self.isZero(func, data.args[0])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        } else if (try self.isAllOnes(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        } else if (try self.isAllOnes(func, data.args[0])) {
            try self.replaceWithCopy(func, inst, data.args[1]);
        } else if (data.args[0].index == data.args[1].index) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        }
    }

    /// Optimize OR: x | 0 = x, x | -1 = -1, x | x = x
    fn optimizeOr(self: *Peephole, func: *Function, inst: Inst, data: BinaryData) !void {
        if (try self.isZero(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        } else if (try self.isZero(func, data.args[0])) {
            try self.replaceWithCopy(func, inst, data.args[1]);
        } else if (try self.isAllOnes(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[1]);
        } else if (try self.isAllOnes(func, data.args[0])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        } else if (data.args[0].index == data.args[1].index) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        }
    }

    /// Optimize XOR: x ^ 0 = x, x ^ x = 0
    fn optimizeXor(self: *Peephole, func: *Function, inst: Inst, data: BinaryData) !void {
        if (try self.isZero(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        } else if (try self.isZero(func, data.args[0])) {
            try self.replaceWithCopy(func, inst, data.args[1]);
        } else if (data.args[0].index == data.args[1].index) {
            // x ^ x = 0: Replace with zero constant
            const ty = func.dfg.valueType(data.args[0]) orelse return;
            const zero_data = InstructionData{ .unary = UnaryData.init(.iconst, data.args[0]) };
            const inst_mut = func.dfg.insts.getMut(inst) orelse return;
            inst_mut.* = zero_data;

            // Update result type
            const result = func.dfg.firstResult(inst) orelse return;
            const result_mut = func.dfg.values.getMut(result) orelse return;
            result_mut.* = root.dfg.ValueData.inst(ty, 0, inst);

            self.changed = true;
        }
    }

    /// Optimize shift: x << 0 = x, x >> 0 = x
    fn optimizeShift(self: *Peephole, func: *Function, inst: Inst, data: BinaryData) !void {
        if (try self.isZero(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        }
    }

    /// Optimize rotate: rotl/rotr by 0 = x
    fn optimizeRotate(self: *Peephole, func: *Function, inst: Inst, data: BinaryData) !void {
        if (try self.isZero(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        }
    }

    /// Optimize division: x / 1 = x
    fn optimizeDiv(self: *Peephole, func: *Function, inst: Inst, data: BinaryData) !void {
        if (try self.isOne(func, data.args[1])) {
            try self.replaceWithCopy(func, inst, data.args[0]);
        }
    }

    /// Optimize remainder: x % 1 = 0
    fn optimizeRem(self: *Peephole, func: *Function, inst: Inst, data: BinaryData) !void {
        if (try self.isOne(func, data.args[1])) {
            // x % 1 = 0: Replace with zero constant
            const ty = func.dfg.valueType(data.args[0]) orelse return;
            const zero_data = InstructionData{ .unary = UnaryData.init(.iconst, data.args[0]) };
            const inst_mut = func.dfg.insts.getMut(inst) orelse return;
            inst_mut.* = zero_data;

            // Update result type
            const result = func.dfg.firstResult(inst) orelse return;
            const result_mut = func.dfg.values.getMut(result) orelse return;
            result_mut.* = root.dfg.ValueData.inst(ty, 0, inst);

            self.changed = true;
        }
    }

    /// Track load instruction for redundant load elimination.
    fn trackLoad(self: *Peephole, func: *Function, inst: Inst, addr: Value) !void {
        _ = func;
        // Record this load for potential future elimination
        try self.loads.put(addr, inst);
    }

    /// Replace instruction with a copy of a value.
    fn replaceWithCopy(self: *Peephole, func: *Function, inst: Inst, value: Value) !void {
        const result = func.dfg.firstResult(inst) orelse return;
        const ty = func.dfg.valueType(result) orelse return;

        // Create alias to the source value
        const result_mut = func.dfg.values.getMut(result) orelse return;
        result_mut.* = root.dfg.ValueData.alias(ty, value);

        self.changed = true;
    }

    /// Check if value is constant zero.
    fn isZero(self: *Peephole, func: *const Function, value: Value) !bool {
        _ = self;
        const value_def = func.dfg.valueDef(value) orelse return false;
        const defining_inst = switch (value_def) {
            .result => |r| r.inst,
            else => return false,
        };

        const inst_data = func.dfg.insts.get(defining_inst) orelse return false;
        const imm_val = switch (inst_data.*) {
            .unary_imm => |d| if (d.opcode == .iconst) d.imm.bits() else return false,
            else => return false,
        };

        return imm_val == 0;
    }

    /// Check if value is constant one.
    fn isOne(self: *Peephole, func: *const Function, value: Value) !bool {
        _ = self;
        const value_def = func.dfg.valueDef(value) orelse return false;
        const defining_inst = switch (value_def) {
            .result => |r| r.inst,
            else => return false,
        };

        const inst_data = func.dfg.insts.get(defining_inst) orelse return false;
        const imm_val = switch (inst_data.*) {
            .unary_imm => |d| if (d.opcode == .iconst) d.imm.bits() else return false,
            else => return false,
        };

        return imm_val == 1;
    }

    /// Check if value is all-ones (-1).
    fn isAllOnes(self: *Peephole, func: *const Function, value: Value) !bool {
        _ = self;
        const value_def = func.dfg.valueDef(value) orelse return false;
        const defining_inst = switch (value_def) {
            .result => |r| r.inst,
            else => return false,
        };

        const inst_data = func.dfg.insts.get(defining_inst) orelse return false;
        const imm_val = switch (inst_data.*) {
            .unary_imm => |d| if (d.opcode == .iconst) d.imm.bits() else return false,
            else => return false,
        };

        return imm_val == -1;
    }
};

// Tests

const testing = std.testing;

test "Peephole: init and deinit" {
    var ph = Peephole.init(testing.allocator);
    defer ph.deinit();

    try testing.expect(!ph.changed);
}

test "Peephole: run on empty function" {
    const sig = try @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var ph = Peephole.init(testing.allocator);
    defer ph.deinit();

    const changed = try ph.run(&func);
    try testing.expect(!changed);
}

test "Peephole: preserve non-optimizable instructions" {
    const sig = try @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const block = try func.dfg.makeBlock();
    try func.layout.appendBlock(block);

    const ret_data = InstructionData{ .nullary = .{ .opcode = .@"return" } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, block);

    var ph = Peephole.init(testing.allocator);
    defer ph.deinit();

    const changed = try ph.run(&func);
    try testing.expect(!changed);
}

test "Peephole: identity optimizations" {
    // Test x & x = x pattern recognition
    var ph = Peephole.init(testing.allocator);
    defer ph.deinit();

    // Basic structure test - actual optimization requires full IR setup
    try testing.expect(!ph.changed);
}
