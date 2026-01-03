//! Dead Code Elimination (DCE) optimization pass.
//!
//! Removes instructions that have no observable effect:
//! - Instructions whose results are never used
//! - Pure instructions with no side effects
//!
//! This is a backwards dataflow analysis that marks live values,
//! then removes unmarked instructions.

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir_mod = @import("../../ir.zig");
const Function = @import("../../ir/function.zig").Function;
const Block = ir_mod.Block;
const Inst = ir_mod.Inst;
const Value = ir_mod.Value;
const Opcode = @import("../../ir/opcodes.zig").Opcode;

/// Dead code elimination pass.
pub const DCE = struct {
    /// Allocator for temporary data structures.
    allocator: Allocator,
    /// Set of live instructions.
    live_insts: std.AutoHashMap(Inst, void),
    /// Set of live values.
    live_values: std.AutoHashMap(Value, void),

    pub fn init(allocator: Allocator) DCE {
        return .{
            .allocator = allocator,
            .live_insts = std.AutoHashMap(Inst, void).init(allocator),
            .live_values = std.AutoHashMap(Value, void).init(allocator),
        };
    }

    pub fn deinit(self: *DCE) void {
        self.live_insts.deinit();
        self.live_values.deinit();
    }

    /// Run DCE on the function.
    /// Returns true if any instructions were removed.
    pub fn run(self: *DCE, func: *Function) !bool {
        // Mark all live instructions and values
        try self.markLive(func);

        // Remove dead instructions
        const removed = try self.removeDeadInsts(func);

        // Clear for next run
        self.live_insts.clearRetainingCapacity();
        self.live_values.clearRetainingCapacity();

        return removed;
    }

    /// Mark all live instructions starting from roots.
    fn markLive(self: *DCE, func: *Function) !void {
        // Start with instructions that have side effects as roots
        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = func.dfg.insts.get(inst) orelse continue;

                // Instructions with side effects are always live
                if (self.hasSideEffects(inst_data.opcode())) {
                    try self.markInstLive(func, inst);
                }
            }
        }
    }

    /// Mark an instruction and its operands as live.
    fn markInstLive(self: *DCE, func: *Function, inst: Inst) !void {
        // Already marked?
        if (self.live_insts.contains(inst)) return;

        try self.live_insts.put(inst, {});

        // Mark all operands (values used by this instruction)
        const inst_data = func.dfg.insts.get(inst) orelse return;

        // Mark operands based on instruction type
        switch (inst_data) {
            .unary => |d| try self.markValueLive(func, d.arg),
            .binary => |d| {
                try self.markValueLive(func, d.args[0]);
                try self.markValueLive(func, d.args[1]);
            },
            .branch => |d| {
                if (d.condition) |cond| {
                    try self.markValueLive(func, cond);
                }
            },
            .call => |d| {
                for (d.args.asSlice(&func.dfg.value_lists)) |arg| {
                    try self.markValueLive(func, arg);
                }
            },
            else => {}, // Other instruction types
        }
    }

    /// Mark a value and the instruction that defines it as live.
    fn markValueLive(self: *DCE, func: *Function, value: Value) !void {
        // Already marked?
        if (self.live_values.contains(value)) return;

        try self.live_values.put(value, {});

        // Find the defining instruction and mark it live
        const value_def = func.dfg.valueDef(value) orelse return;
        switch (value_def) {
            .result => |r| try self.markInstLive(func, r.inst),
            .param => {}, // Block parameters are always live
            .@"union" => |u| {
                // Mark both union alternatives
                try self.markValueLive(func, u.x);
                try self.markValueLive(func, u.y);
            },
        }
    }

    /// Check if an opcode has side effects.
    fn hasSideEffects(self: *DCE, opcode: Opcode) bool {
        _ = self;
        return switch (opcode) {
            // Control flow always has side effects
            .jump, .brif, .br_table, .@"return", .call, .call_indirect => true,

            // Memory operations have side effects
            .store, .istore8, .istore16, .istore32 => true,

            // Loads are considered to have side effects (may trap)
            .load, .uload8, .sload8, .uload16, .sload16, .uload32, .sload32 => true,

            // Arithmetic and logical operations are pure
            .iadd, .isub, .imul, .udiv, .sdiv, .urem, .srem => false,
            .band, .bor, .bxor, .bnot => false,
            .ishl, .ushr, .sshr, .rotl, .rotr => false,
            .icmp, .select => false,

            // Floating-point operations are pure (ignoring NaN behavior)
            .fadd, .fsub, .fmul, .fdiv => false,
            .fabs, .fneg, .fmin, .fmax => false,
            .fcmp => false,

            // Conversions are pure

            // Constants are pure
            .iconst, .f32const, .f64const, .vconst => false,

            else => true, // Conservative: assume side effects
        };
    }

    /// Remove dead instructions from the function.
    fn removeDeadInsts(self: *DCE, func: *Function) !bool {
        var removed = false;
        var dead_insts = std.ArrayList(Inst).init(self.allocator);
        defer dead_insts.deinit();

        // Collect dead instructions
        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                if (!self.live_insts.contains(inst)) {
                    try dead_insts.append(inst);
                }
            }
        }

        // Remove dead instructions from layout
        for (dead_insts.items) |inst| {
            func.layout.removeInst(inst);
            removed = true;
        }

        return removed;
    }
};

// Tests

const testing = std.testing;

test "DCE: mark side effects live" {
    var dce = DCE.init(testing.allocator);
    defer dce.deinit();

    // Store has side effects
    try testing.expect(dce.hasSideEffects(.store));
    try testing.expect(dce.hasSideEffects(.call));
    try testing.expect(dce.hasSideEffects(.@"return"));

    // Pure operations have no side effects
    try testing.expect(!dce.hasSideEffects(.iadd));
    try testing.expect(!dce.hasSideEffects(.fadd));
    try testing.expect(!dce.hasSideEffects(.iconst));
}
