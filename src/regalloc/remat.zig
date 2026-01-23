//! Rematerialization Support for Register Allocation
//!
//! Rematerialization is recomputing a value instead of spilling/reloading it.
//! This is profitable when:
//! 1. The value is cheap to recompute (constants, simple expressions)
//! 2. Register pressure is high
//! 3. Spill slots are precious (e.g., in loops)
//!
//! Rematerializable values:
//! - Integer constants (iconst)
//! - Float constants (f32const, f64const)
//! - Address computations (global_value, stack_addr)
//! - Simple unary ops on rematerializable values

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir_mod = @import("../ir.zig");
const Inst = ir_mod.Inst;
const Value = ir_mod.Value;
const Opcode = @import("../ir/opcodes.zig").Opcode;
const Type = ir_mod.Type;
const Function = ir_mod.Function;
const InstructionData = @import("../ir/instruction_data.zig").InstructionData;

/// Rematerialization cost (lower is better).
pub const Cost = enum(u8) {
    /// Free - just a register move.
    free = 0,
    /// Very cheap - single instruction, no memory.
    very_cheap = 1,
    /// Cheap - simple ALU op.
    cheap = 2,
    /// Medium - load from constant pool.
    medium = 4,
    /// Expensive - multiple instructions.
    expensive = 8,
    /// Cannot rematerialize.
    impossible = 255,

    pub fn add(self: Cost, other: Cost) Cost {
        const sum = @as(u16, @intFromEnum(self)) + @as(u16, @intFromEnum(other));
        if (sum >= 255) return .impossible;
        return @enumFromInt(@as(u8, @intCast(sum)));
    }

    pub fn betterThan(self: Cost, other: Cost) bool {
        return @intFromEnum(self) < @intFromEnum(other);
    }
};

/// Information about a rematerializable value.
pub const RematInfo = struct {
    /// Original instruction that defined this value.
    def_inst: Inst,
    /// Cost to rematerialize.
    cost: Cost,
    /// Dependencies (other values needed to remat).
    deps: []const Value,
    /// Whether this is a constant (no deps).
    is_const: bool,
};

/// Rematerialization analysis.
pub const RematAnalysis = struct {
    allocator: Allocator,
    /// Map from value to remat info.
    remat_info: std.AutoHashMap(Value, RematInfo),
    /// Threshold cost for rematerialization.
    threshold: Cost,

    pub fn init(allocator: Allocator, threshold: Cost) RematAnalysis {
        return .{
            .allocator = allocator,
            .remat_info = std.AutoHashMap(Value, RematInfo).init(allocator),
            .threshold = threshold,
        };
    }

    pub fn deinit(self: *RematAnalysis) void {
        self.remat_info.deinit();
    }

    /// Analyze a function for rematerializable values.
    pub fn analyze(self: *RematAnalysis, func: *const Function) !void {
        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const results = func.dfg.instResults(inst);
                if (results.len == 0) continue;

                const cost = self.computeCost(func, inst);
                if (cost.betterThan(self.threshold) or cost == self.threshold) {
                    const deps = try self.getDependencies(func, inst);
                    try self.remat_info.put(results[0], .{
                        .def_inst = inst,
                        .cost = cost,
                        .deps = deps,
                        .is_const = deps.len == 0,
                    });
                }
            }
        }
    }

    /// Check if a value can be rematerialized.
    pub fn canRemat(self: *const RematAnalysis, value: Value) bool {
        return self.remat_info.contains(value);
    }

    /// Get rematerialization info for a value.
    pub fn getInfo(self: *const RematAnalysis, value: Value) ?RematInfo {
        return self.remat_info.get(value);
    }

    /// Compute rematerialization cost for an instruction.
    fn computeCost(self: *RematAnalysis, func: *const Function, inst: Inst) Cost {
        _ = self;

        const inst_data = func.dfg.insts.get(inst) orelse return .impossible;
        const opcode = inst_data.opcode();

        return switch (opcode) {
            // Constants - very cheap (single instruction)
            .iconst, .f32const, .f64const => .very_cheap,

            // Address computations - cheap
            .stack_addr, .global_value => .cheap,

            // Simple unary ops on constants - cheap
            .ineg, .fneg, .bnot => .cheap,

            // Extension/truncation - cheap
            .sextend, .uextend, .ireduce => .cheap,

            // Float conversion - medium
            .fpromote, .fdemote => .medium,

            // Bitcast - free
            .bitcast => .free,

            // Binary ops with immediate - cheap
            .iadd_imm, .isub_imm, .imul_imm => .cheap,

            // Can't rematerialize anything with side effects
            .load, .store, .call, .call_indirect => .impossible,

            // Default - cannot rematerialize
            else => .impossible,
        };
    }

    /// Get dependencies for an instruction.
    fn getDependencies(self: *RematAnalysis, func: *const Function, inst: Inst) ![]const Value {
        _ = self;

        const inst_data = func.dfg.insts.get(inst) orelse return &.{};

        // Get operand values
        return switch (inst_data) {
            .unary => |u| &[_]Value{u.arg},
            .unary_imm => &.{}, // No dependencies
            .binary => |b| &b.args,
            .binary_imm => |bi| &[_]Value{bi.arg},
            else => &.{},
        };
    }

    /// Emit rematerialization code for a value.
    pub fn emitRemat(self: *RematAnalysis, func: *Function, value: Value) !?Inst {
        const info = self.getInfo(value) orelse return null;

        // Clone the original instruction
        const orig_data = func.dfg.insts.get(info.def_inst) orelse return null;
        const new_inst = try func.dfg.makeInst(orig_data);

        return new_inst;
    }
};

/// Statistics for rematerialization.
pub const Stats = struct {
    /// Values analyzed.
    values_analyzed: u32 = 0,
    /// Values marked rematerializable.
    rematerializable: u32 = 0,
    /// Constants found.
    constants: u32 = 0,
    /// Actual remats performed.
    remats_performed: u32 = 0,
    /// Spills avoided.
    spills_avoided: u32 = 0,
};

// Tests
test "Cost comparison" {
    const testing = std.testing;

    try testing.expect(Cost.free.betterThan(.cheap));
    try testing.expect(Cost.cheap.betterThan(.medium));
    try testing.expect(!Cost.impossible.betterThan(.expensive));
}

test "Cost addition" {
    const testing = std.testing;

    try testing.expectEqual(Cost.cheap, Cost.very_cheap.add(.very_cheap));
    try testing.expectEqual(Cost.impossible, Cost.expensive.add(.impossible));
}

test "RematAnalysis init" {
    const testing = std.testing;

    var analysis = RematAnalysis.init(testing.allocator, .medium);
    defer analysis.deinit();

    try testing.expectEqual(Cost.medium, analysis.threshold);
}
