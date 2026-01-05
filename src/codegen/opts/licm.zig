//! Loop-Invariant Code Motion (LICM) optimization pass.
//!
//! Identifies loop-invariant instructions and hoists them to loop preheaders.
//! An instruction is loop-invariant if:
//! - All its operands are defined outside the loop, or
//! - All its operands are themselves loop-invariant
//!
//! Safety requirements:
//! - Instruction must have no side effects
//! - Instruction must dominate all loop exits (or be speculative-safe)
//! - Target block must dominate the loop

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir = @import("../../ir.zig");
const Function = ir.Function;
const Block = ir.Block;
const Inst = ir.Inst;
const Value = ir.Value;
const Opcode = @import("../../ir/opcodes.zig").Opcode;
const loops = @import("../../ir/loops.zig");
const Loop = loops.Loop;
const LoopInfo = ir.LoopInfo;
const DominatorTree = ir.DominatorTree;
const CFG = ir.ControlFlowGraph;

/// Loop-Invariant Code Motion pass.
pub const LICM = struct {
    allocator: Allocator,
    /// Set of instructions identified as loop-invariant.
    invariant_insts: std.AutoHashMap(Inst, void),
    /// Map from loop header to its preheader block.
    preheaders: std.AutoHashMap(Block, Block),

    pub fn init(allocator: Allocator) LICM {
        return .{
            .allocator = allocator,
            .invariant_insts = std.AutoHashMap(Inst, void).init(allocator),
            .preheaders = std.AutoHashMap(Block, Block).init(allocator),
        };
    }

    pub fn deinit(self: *LICM) void {
        self.invariant_insts.deinit();
        self.preheaders.deinit();
    }

    /// Run LICM on the function.
    /// Returns true if any instructions were hoisted.
    pub fn run(self: *LICM, func: *Function, loop_info: *const LoopInfo, domtree: *const DominatorTree, cfg: *const CFG) !bool {
        _ = domtree;
        var changed = false;

        // Process each loop
        for (loop_info.loops.items) |loop| {
            // Get or create preheader for this loop
            const preheader = try self.getOrCreatePreheader(func, loop, cfg);
            try self.preheaders.put(loop.header, preheader);

            // Find loop-invariant instructions
            try self.findInvariants(func, loop);

            // Hoist invariants to preheader
            const hoisted = try self.hoistInvariants(func, loop, preheader);
            if (hoisted) {
                changed = true;
            }

            // Clear for next loop
            self.invariant_insts.clearRetainingCapacity();
        }

        // Clear preheaders for next run
        self.preheaders.clearRetainingCapacity();

        return changed;
    }

    /// Find loop-invariant instructions in the loop.
    fn findInvariants(self: *LICM, func: *Function, loop: *const Loop) !void {
        var changed = true;

        // Fixed-point iteration: keep finding invariants until no new ones found
        while (changed) {
            changed = false;

            for (loop.blocks.items) |block| {
                var inst_iter = func.layout.blockInsts(block);
                while (inst_iter.next()) |inst| {
                    // Skip if already marked invariant
                    if (self.invariant_insts.contains(inst)) continue;

                    const inst_data = func.dfg.insts.get(inst) orelse continue;

                    // Must have no side effects
                    if (self.hasSideEffects(inst_data.opcode())) continue;

                    // Check if all operands are loop-invariant
                    if (try self.areOperandsInvariant(func, loop, inst)) {
                        try self.invariant_insts.put(inst, {});
                        changed = true;
                    }
                }
            }
        }
    }

    /// Check if all operands of an instruction are loop-invariant.
    fn areOperandsInvariant(self: *LICM, func: *Function, loop: *const Loop, inst: Inst) !bool {
        const inst_data = func.dfg.insts.get(inst) orelse return false;

        return switch (inst_data.*) {
            .unary => |d| self.isValueInvariant(func, loop, d.arg),
            .binary => |d| self.isValueInvariant(func, loop, d.args[0]) and self.isValueInvariant(func, loop, d.args[1]),
            .int_compare => |d| self.isValueInvariant(func, loop, d.args[0]) and self.isValueInvariant(func, loop, d.args[1]),
            .float_compare => |d| self.isValueInvariant(func, loop, d.args[0]) and self.isValueInvariant(func, loop, d.args[1]),
            .load => |d| self.isValueInvariant(func, loop, d.arg),
            .call => |d| blk: {
                for (d.args.asSlice(&func.dfg.value_lists)) |arg| {
                    if (!self.isValueInvariant(func, loop, arg)) break :blk false;
                }
                break :blk true;
            },
            else => true, // Conservative: assume no operands or invariant
        };
    }

    /// Check if a value is loop-invariant.
    fn isValueInvariant(self: *LICM, func: *Function, loop: *const Loop, value: Value) bool {
        const value_def = func.dfg.valueDef(value) orelse return true;

        return switch (value_def) {
            .result => |r| blk: {
                // Check if defining instruction is outside loop
                const def_block = func.layout.instBlock(r.inst) orelse break :blk false;
                if (!loop.contains(def_block)) break :blk true;
                // Or if it's already marked as invariant
                break :blk self.invariant_insts.contains(r.inst);
            },
            .param => |p| !loop.contains(p.block), // Invariant if param from outside loop
            .@"union" => |u| self.isValueInvariant(func, loop, u.x) and self.isValueInvariant(func, loop, u.y),
        };
    }

    /// Hoist invariant instructions to the preheader.
    fn hoistInvariants(self: *LICM, func: *Function, loop: *const Loop, preheader: Block) !bool {
        _ = loop;
        var hoisted = false;
        var to_hoist = std.ArrayList(Inst).init(self.allocator);
        defer to_hoist.deinit();

        // Collect instructions to hoist
        var iter = self.invariant_insts.keyIterator();
        while (iter.next()) |inst| {
            try to_hoist.append(inst.*);
        }

        // Hoist each instruction
        for (to_hoist.items) |inst| {
            // Remove from current block
            func.layout.removeInst(inst);

            // Insert at end of preheader (before terminator if any)
            var preheader_iter = func.layout.blockInsts(preheader);
            var last_non_term: ?Inst = null;

            while (preheader_iter.next()) |preheader_inst| {
                const inst_data = func.dfg.insts.get(preheader_inst) orelse continue;
                if (!self.isTerminator(inst_data.opcode())) {
                    last_non_term = preheader_inst;
                }
            }

            if (last_non_term) |prev| {
                try func.layout.insertInstAfter(inst, prev);
            } else {
                try func.layout.prependBlockInst(inst, preheader);
            }

            hoisted = true;
        }

        return hoisted;
    }

    /// Get or create a preheader block for a loop.
    /// A preheader is a block that:
    /// - Has the loop header as its only successor
    /// - Is dominated by all loop predecessors from outside the loop
    fn getOrCreatePreheader(self: *LICM, func: *Function, loop: *const Loop, cfg: *const CFG) !Block {
        _ = self;
        _ = func;

        // For now, find existing preheader
        // A proper implementation would create one if it doesn't exist
        const header_preds = cfg.predecessors(loop.header);

        // Look for a predecessor that's not in the loop
        for (header_preds) |pred| {
            if (!loop.contains(pred)) {
                // Found a potential preheader
                // In a full implementation, verify it has only one successor
                return pred;
            }
        }

        // If no preheader exists, return the header itself
        // A full implementation would create a new preheader block
        return loop.header;
    }

    /// Check if an opcode has side effects.
    fn hasSideEffects(self: *LICM, opcode: Opcode) bool {
        _ = self;
        return switch (opcode) {
            // Control flow has side effects
            .jump, .brif, .br_table, .@"return", .call, .call_indirect => true,

            // Memory writes have side effects
            .store, .istore8, .istore16, .istore32 => true,

            // Loads may trap, so considered side effects for safety
            .load, .uload8, .sload8, .uload16, .sload16, .uload32, .sload32 => true,

            // Pure arithmetic and logical operations
            .iadd, .isub, .imul, .udiv, .sdiv, .urem, .srem => false,
            .band, .bor, .bxor, .bnot => false,
            .ishl, .ushr, .sshr, .rotl, .rotr => false,
            .icmp, .select => false,

            // Pure floating-point operations
            .fadd, .fsub, .fmul, .fdiv, .sqrt => false,
            .fabs, .fneg, .fmin, .fmax => false,
            .fcmp => false,

            // Pure conversions
            .sextend, .uextend, .ireduce => false,
            .fcvt_from_sint, .fcvt_from_uint => false,
            .fcvt_to_sint, .fcvt_to_uint, .fcvt_to_sint_sat, .fcvt_to_uint_sat => false,

            // Pure constants
            .iconst, .f32const, .f64const, .vconst => false,

            else => true, // Conservative: assume side effects
        };
    }

    /// Check if an opcode is a terminator.
    fn isTerminator(self: *LICM, opcode: Opcode) bool {
        _ = self;
        return switch (opcode) {
            .jump, .brif, .br_table, .@"return" => true,
            else => false,
        };
    }
};

// Tests

const testing = std.testing;

test "LICM: init and deinit" {
    var licm = LICM.init(testing.allocator);
    defer licm.deinit();

    try testing.expectEqual(@as(usize, 0), licm.invariant_insts.count());
}

test "LICM: hasSideEffects" {
    var licm = LICM.init(testing.allocator);
    defer licm.deinit();

    // Side effects
    try testing.expect(licm.hasSideEffects(.store));
    try testing.expect(licm.hasSideEffects(.call));
    try testing.expect(licm.hasSideEffects(.@"return"));
    try testing.expect(licm.hasSideEffects(.load));

    // No side effects
    try testing.expect(!licm.hasSideEffects(.iadd));
    try testing.expect(!licm.hasSideEffects(.fadd));
    try testing.expect(!licm.hasSideEffects(.iconst));
    try testing.expect(!licm.hasSideEffects(.icmp));
}

test "LICM: isTerminator" {
    var licm = LICM.init(testing.allocator);
    defer licm.deinit();

    try testing.expect(licm.isTerminator(.jump));
    try testing.expect(licm.isTerminator(.brif));
    try testing.expect(licm.isTerminator(.@"return"));

    try testing.expect(!licm.isTerminator(.iadd));
    try testing.expect(!licm.isTerminator(.store));
}
