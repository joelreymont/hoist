const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const function_mod = @import("function.zig");
const entities_mod = @import("entities.zig");
const cfg_mod = @import("cfg.zig");

const Function = function_mod.Function;
const Block = entities_mod.Block;
const Inst = entities_mod.Inst;
const Value = entities_mod.Value;
const Type = root.types.Type;
const ControlFlowGraph = cfg_mod.ControlFlowGraph;

/// IR verification errors.
pub const VerifyError = error{
    /// Value used before definition.
    UseBeforeDef,
    /// Instruction not in any block.
    InstructionOrphaned,
    /// Block not in function layout.
    BlockOrphaned,
    /// Type mismatch in operation.
    TypeMismatch,
    /// Invalid operand count.
    InvalidOperandCount,
    /// Control flow error (unreachable code, etc.).
    ControlFlowError,
    /// Dominator violation.
    DominatorViolation,
    /// Invalid block parameters.
    InvalidBlockParams,
} || Allocator.Error;

/// IR verifier - validates IR well-formedness.
pub const Verifier = struct {
    /// Function being verified.
    func: *const Function,
    /// Allocator for temporary data.
    allocator: Allocator,
    /// Error messages collected during verification.
    errors: std.ArrayList([]const u8),

    pub fn init(allocator: Allocator, func: *const Function) Verifier {
        return .{
            .func = func,
            .allocator = allocator,
            .errors = .{},
        };
    }

    pub fn deinit(self: *Verifier) void {
        for (self.errors.items) |msg| {
            self.allocator.free(msg);
        }
        self.errors.deinit();
    }

    /// Run full verification on the function.
    pub fn verify(self: *Verifier) !void {
        try self.verifyStructure();
        try self.verifySSA();
        try self.verifyTypes();
        try self.verifyControlFlow();

        // If any errors were collected, fail
        if (self.errors.items.len > 0) {
            return error.ControlFlowError;
        }
    }

    /// Verify basic structural properties.
    fn verifyStructure(self: *Verifier) !void {
        // Build CFG for validation
        var cfg = ControlFlowGraph.init(self.allocator);
        defer cfg.deinit();
        try cfg.compute(self.func);

        // Check that all blocks in layout exist in CFG
        var block_iter = self.func.layout.blocks();
        while (block_iter.next()) |block| {
            const block_idx = block.index();

            // Verify block is in CFG
            if (block_idx >= cfg.data.items.len) {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "Block {d} not in CFG (CFG size: {d})",
                    .{ block_idx, cfg.data.items.len },
                );
                try self.errors.append(msg);
                continue;
            }

            // Verify predecessor/successor consistency
            cfg.validateBlock(self.func, block) catch |err| {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "CFG validation failed for block {d}: {s}",
                    .{ block_idx, @errorName(err) },
                );
                try self.errors.append(msg);
            };
        }

        // Check that all instructions are in some block
        var inst_count: usize = 0;
        var block_iter2 = self.func.layout.blocks();
        while (block_iter2.next()) |block| {
            var inst_iter = self.func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                _ = inst;
                inst_count += 1;
            }
        }

        // Should match total instruction count in DFG
        if (inst_count != self.func.dfg.insts.elems.items.len) {
            const msg = try std.fmt.allocPrint(
                self.allocator,
                "Instruction count mismatch: layout={d}, dfg={d}",
                .{ inst_count, self.func.dfg.insts.elems.items.len },
            );
            try self.errors.append(msg);
        }
    }

    /// Verify SSA properties (values defined before use).
    fn verifySSA(self: *Verifier) !void {
        // Track which values have been defined
        var defined = std.AutoHashMap(Value, void).init(self.allocator);
        defer defined.deinit();

        // Iterate through blocks in layout order
        var block_iter = self.func.layout.blocks();
        while (block_iter.next()) |block| {
            // Block parameters are defined at block entry
            if (self.func.dfg.blocks.get(block)) |block_data| {
                const params = block_data.getParams(&self.func.dfg.value_lists);
                for (params) |param| {
                    try defined.put(param, {});
                }
            }

            // Check each instruction
            var inst_iter = self.func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = self.func.dfg.insts.get(inst) orelse continue;

                // Check that operands are defined
                switch (inst_data.*) {
                    .binary => |bin| {
                        if (!defined.contains(bin.args[0])) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "Use before def: value {d} in inst {d}",
                                .{ bin.args[0].index, inst.index },
                            );
                            try self.errors.append(msg);
                        }
                        if (!defined.contains(bin.args[1])) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "Use before def: value {d} in inst {d}",
                                .{ bin.args[1].index, inst.index },
                            );
                            try self.errors.append(msg);
                        }
                    },
                    .unary => |un| {
                        if (!defined.contains(un.arg)) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "Use before def: value {d} in inst {d}",
                                .{ un.arg.index, inst.index },
                            );
                            try self.errors.append(msg);
                        }
                    },
                    else => {},
                }

                // Mark results as defined
                const results = self.func.dfg.instResults(inst);
                for (results) |result| {
                    try defined.put(result, {});
                }
            }
        }
    }

    /// Verify type consistency.
    fn verifyTypes(self: *Verifier) !void {
        // Check that operations have type-compatible operands
        var block_iter = self.func.layout.blocks();
        while (block_iter.next()) |block| {
            var inst_iter = self.func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = self.func.dfg.insts.get(inst) orelse continue;

                switch (inst_data.*) {
                    .binary => |bin| {
                        // Both operands should have the same type for arithmetic
                        const lhs_ty = self.func.dfg.valueType(bin.args[0]);
                        const rhs_ty = self.func.dfg.valueType(bin.args[1]);

                        if (!std.meta.eql(lhs_ty, rhs_ty)) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "Type mismatch in binary op: inst {d}",
                                .{inst.index},
                            );
                            try self.errors.append(msg);
                        }
                    },
                    else => {},
                }
            }
        }
    }

    /// Verify control flow properties.
    fn verifyControlFlow(self: *Verifier) !void {
        // Check that each block ends with a terminator
        var block_iter = self.func.layout.blocks();
        while (block_iter.next()) |block| {
            const last_inst = self.func.layout.lastInst(block);
            if (last_inst == null) {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "Block {d} has no instructions",
                    .{block.index},
                );
                try self.errors.append(msg);
                continue;
            }

            // Check that last instruction is a terminator
            const inst = last_inst.?;
            const inst_data = self.func.dfg.insts.get(inst) orelse continue;
            const opcode = inst_data.opcode();

            if (!isTerminator(opcode)) {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "Block {d} does not end with terminator (last opcode: {s})",
                    .{ block.index, @tagName(opcode) },
                );
                try self.errors.append(msg);
            }
        }
    }

    /// Check if an opcode is a terminator instruction.
    fn isTerminator(opcode: root.opcodes.Opcode) bool {
        return switch (opcode) {
            .jump, .brif, .br_table, .@"return", .return_call, .return_call_indirect, .trap, .trapz, .trapnz, .debugtrap => true,
            else => false,
        };
    }

    /// Get collected error messages.
    pub fn getErrors(self: *const Verifier) []const []const u8 {
        return self.errors.items;
    }
};

test "Verifier basic" {
    const sig = root.signature.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();

    // Empty function should verify (no errors)
    try verifier.verify();
    try testing.expectEqual(@as(usize, 0), verifier.errors.items.len);
}

test "Verifier detects orphaned instruction" {
    const sig = root.signature.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    // Create instruction but don't add to layout
    const inst_data = root.instruction_data.InstructionData{
        .nullary = root.instruction_data.NullaryData.init(.nop),
    };
    _ = try func.dfg.makeInst(inst_data);

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();

    // Should detect instruction count mismatch
    verifier.verify() catch |err| {
        try testing.expectEqual(VerifyError.ControlFlowError, err);
    };

    try testing.expect(verifier.errors.items.len > 0);
}

test "Verifier type checking" {
    const sig = root.signature.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();

    // Would need to create mismatched types to test
    // For now, verify empty function
    try verifier.verify();
}
