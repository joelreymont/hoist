const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("root");
const Function = root.function.Function;
const Value = root.entities.Value;
const Inst = root.entities.Inst;
const InstructionData = root.instruction_data.InstructionData;
const Opcode = root.opcodes.Opcode;

/// ISLE-based optimization pass.
/// Applies pattern-matching optimizations defined in opts.isle.
pub const OptimizationPass = struct {
    /// Function being optimized.
    func: *Function,
    /// Allocator for temporary data.
    allocator: Allocator,
    /// Changed flag - true if any optimization was applied.
    changed: bool,

    pub fn init(allocator: Allocator, func: *Function) OptimizationPass {
        return .{
            .func = func,
            .allocator = allocator,
            .changed = false,
        };
    }

    /// Run optimization pass on the function.
    pub fn run(self: *OptimizationPass) !bool {
        self.changed = false;

        // Iterate over all instructions
        var block_iter = self.func.layout.blockIter();
        while (block_iter.next()) |block| {
            var inst_iter = self.func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                try self.optimizeInst(inst);
            }
        }

        return self.changed;
    }

    /// Try to optimize a single instruction.
    fn optimizeInst(self: *OptimizationPass, inst: Inst) !void {
        const inst_data = self.func.dfg.insts.get(inst) orelse return;

        // Pattern match against optimization rules
        switch (inst_data.*) {
            .binary => |bin| {
                try self.optimizeBinary(inst, bin);
            },
            .unary => |un| {
                try self.optimizeUnary(inst, un);
            },
            else => {},
        }
    }

    /// Optimize binary operations.
    fn optimizeBinary(self: *OptimizationPass, inst: Inst, data: anytype) !void {
        const opcode = data.opcode;
        const lhs = data.args[0];
        const rhs = data.args[1];

        // Check for constant operands
        const lhs_const = self.getConstValue(lhs);
        const rhs_const = self.getConstValue(rhs);

        // Algebraic simplifications
        switch (opcode) {
            .iadd => {
                // x + 0 => x
                if (rhs_const) |val| {
                    if (val == 0) {
                        try self.replaceWithValue(inst, lhs);
                        return;
                    }
                }
                // Constant folding: a + b => c
                if (lhs_const != null and rhs_const != null) {
                    const result = lhs_const.? + rhs_const.?;
                    try self.replaceWithConst(inst, result);
                    return;
                }
            },
            .isub => {
                // x - 0 => x
                if (rhs_const) |val| {
                    if (val == 0) {
                        try self.replaceWithValue(inst, lhs);
                        return;
                    }
                }
                // Constant folding: a - b => c
                if (lhs_const != null and rhs_const != null) {
                    const result = lhs_const.? - rhs_const.?;
                    try self.replaceWithConst(inst, result);
                    return;
                }
            },
            .imul => {
                // x * 0 => 0
                if (rhs_const) |val| {
                    if (val == 0) {
                        try self.replaceWithConst(inst, 0);
                        return;
                    }
                    // x * 1 => x
                    if (val == 1) {
                        try self.replaceWithValue(inst, lhs);
                        return;
                    }
                    // Strength reduction: x * 2 => x << 1
                    if (val == 2 or val == 4 or val == 8) {
                        const shift = @ctz(val);
                        try self.replaceWithShift(inst, lhs, shift);
                        return;
                    }
                }
                // Constant folding: a * b => c
                if (lhs_const != null and rhs_const != null) {
                    const result = lhs_const.? * rhs_const.?;
                    try self.replaceWithConst(inst, result);
                    return;
                }
            },
            .band => {
                // x & 0 => 0
                if (rhs_const) |val| {
                    if (val == 0) {
                        try self.replaceWithConst(inst, 0);
                        return;
                    }
                }
            },
            .bor => {
                // x | 0 => x
                if (rhs_const) |val| {
                    if (val == 0) {
                        try self.replaceWithValue(inst, lhs);
                        return;
                    }
                }
            },
            .bxor => {
                // x ^ 0 => x
                if (rhs_const) |val| {
                    if (val == 0) {
                        try self.replaceWithValue(inst, lhs);
                        return;
                    }
                }
                // x ^ x => 0
                if (std.meta.eql(lhs, rhs)) {
                    try self.replaceWithConst(inst, 0);
                    return;
                }
            },
            else => {},
        }
    }

    /// Optimize unary operations.
    fn optimizeUnary(self: *OptimizationPass, inst: Inst, data: anytype) !void {
        const opcode = data.opcode;
        const arg = data.arg;

        // Check for constant operand
        const arg_const = self.getConstValue(arg);

        // Algebraic simplifications
        switch (opcode) {
            .bnot => {
                // not(not(x)) => x
                const arg_def = self.func.dfg.valueDef(arg);
                if (arg_def.inst) |arg_inst| {
                    const arg_data = self.func.dfg.insts.get(arg_inst) orelse return;
                    if (arg_data.* == .unary and arg_data.unary.opcode == .bnot) {
                        try self.replaceWithValue(inst, arg_data.unary.arg);
                        return;
                    }
                }
                // Constant folding: not(c) => ~c
                if (arg_const) |val| {
                    const result = ~val;
                    try self.replaceWithConst(inst, result);
                    return;
                }
            },
            .ineg => {
                // neg(neg(x)) => x
                const arg_def = self.func.dfg.valueDef(arg);
                if (arg_def.inst) |arg_inst| {
                    const arg_data = self.func.dfg.insts.get(arg_inst) orelse return;
                    if (arg_data.* == .unary and arg_data.unary.opcode == .ineg) {
                        try self.replaceWithValue(inst, arg_data.unary.arg);
                        return;
                    }
                }
                // Constant folding: neg(c) => -c
                if (arg_const) |val| {
                    const result = -%val;
                    try self.replaceWithConst(inst, result);
                    return;
                }
            },
            else => {},
        }
    }

    /// Get constant value if operand is iconst.
    fn getConstValue(self: *OptimizationPass, value: Value) ?i64 {
        const def = self.func.dfg.valueDef(value);
        if (def.inst) |inst| {
            const inst_data = self.func.dfg.insts.get(inst) orelse return null;
            if (inst_data.* == .unary_imm) {
                if (inst_data.unary_imm.opcode == .iconst) {
                    return inst_data.unary_imm.imm.value;
                }
            }
        }
        return null;
    }

    /// Replace instruction result with a value.
    fn replaceWithValue(self: *OptimizationPass, inst: Inst, value: Value) !void {
        const results = self.func.dfg.instResults(inst);
        if (results.len > 0) {
            const old_value = results[0];
            // Replace all uses of old_value with value
            try self.func.dfg.replaceAllUses(old_value, value);
            self.changed = true;
        }
    }

    /// Replace instruction result with a constant.
    fn replaceWithConst(self: *OptimizationPass, inst: Inst, val: i64) !void {
        _ = val; // TODO: Store immediate value when immediate pool is implemented

        const results = self.func.dfg.instResults(inst);
        if (results.len == 0) return;

        const old_value = results[0];
        const ty = self.func.dfg.valueType(old_value);

        // Create iconst instruction
        const iconst_data = InstructionData{ .nullary = .{ .opcode = .iconst } };
        const iconst_inst = try self.func.dfg.makeInst(iconst_data);
        const const_value = try self.func.dfg.appendInstResult(iconst_inst, ty);

        // Insert iconst before the current instruction
        if (self.func.layout.instBlock(inst)) |block| {
            try self.func.layout.insertInstBefore(iconst_inst, inst, block);
        }

        // Replace all uses
        try self.func.dfg.replaceAllUses(old_value, const_value);
        self.changed = true;
    }

    /// Replace multiplication with left shift.
    fn replaceWithShift(self: *OptimizationPass, inst: Inst, value: Value, shift: u6) !void {
        _ = shift; // TODO: Store shift amount when immediate pool is implemented

        const results = self.func.dfg.instResults(inst);
        if (results.len == 0) return;

        const old_value = results[0];
        const ty = self.func.dfg.valueType(old_value);

        // Create shift instruction - for now use ishl with placeholder shift value
        // In full implementation, would encode shift amount as immediate
        const shift_data = InstructionData{
            .binary = .{
                .opcode = .ishl,
                .args = [2]Value{ value, value }, // TODO: Second arg should be shift immediate
            },
        };
        const shift_inst = try self.func.dfg.makeInst(shift_data);
        const shift_value = try self.func.dfg.appendInstResult(shift_inst, ty);

        // Insert shift before the current instruction
        if (self.func.layout.instBlock(inst)) |block| {
            try self.func.layout.insertInstBefore(shift_inst, inst, block);
        }

        // Replace all uses
        try self.func.dfg.replaceAllUses(old_value, shift_value);
        self.changed = true;
    }
};

test "OptimizationPass basic" {
    const sig = root.signature.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var pass = OptimizationPass.init(testing.allocator, &func);
    const changed = try pass.run();

    // Empty function - no changes
    try testing.expectEqual(false, changed);
}
