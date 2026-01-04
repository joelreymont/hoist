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
        self.errors.deinit(self.allocator);
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
        defer cfg.deinit(self.allocator);
        try cfg.compute(self.func);

        // Check that all blocks in layout exist in CFG
        var block_iter = self.func.layout.blockIter();
        while (block_iter.next()) |block| {
            const block_idx = block.toIndex();

            // Verify block is in CFG
            if (block_idx >= cfg.data.items.len) {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "Block {d} not in CFG (CFG size: {d})",
                    .{ block_idx, cfg.data.items.len },
                );
                try self.errors.append(self.allocator, msg);
                continue;
            }

            // Verify predecessor/successor consistency
            cfg.validateBlock(self.func, block) catch |err| {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "CFG validation failed for block {d}: {s}",
                    .{ block_idx, @errorName(err) },
                );
                try self.errors.append(self.allocator, msg);
            };
        }

        // Check that all instructions are in some block
        var inst_count: usize = 0;
        var block_iter2 = self.func.layout.blockIter();
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
            try self.errors.append(self.allocator, msg);
        }
    }

    /// Verify SSA properties (values defined before use).
    pub fn verifySSA(self: *Verifier) !void {
        // Track which values have been defined
        var defined = std.AutoHashMap(Value, void).init(self.allocator);
        defer defined.deinit();

        // Iterate through blocks in layout order
        var block_iter = self.func.layout.blockIter();
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
                            try self.errors.append(self.allocator, msg);
                        }
                        if (!defined.contains(bin.args[1])) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "Use before def: value {d} in inst {d}",
                                .{ bin.args[1].index, inst.index },
                            );
                            try self.errors.append(self.allocator, msg);
                        }
                    },
                    .unary => |un| {
                        if (!defined.contains(un.arg)) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "Use before def: value {d} in inst {d}",
                                .{ un.arg.index, inst.index },
                            );
                            try self.errors.append(self.allocator, msg);
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
        var block_iter = self.func.layout.blockIter();
        while (block_iter.next()) |block| {
            var inst_iter = self.func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = self.func.dfg.insts.get(inst) orelse continue;
                const opcode = inst_data.opcode();
                const result_val = self.func.dfg.firstResult(inst) orelse continue;
                const result_ty = self.func.dfg.valueType(result_val) orelse continue;

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
                            try self.errors.append(self.allocator, msg);
                        }
                    },
                    .unary => |un| {
                        const arg_ty = self.func.dfg.valueType(un.arg) orelse continue;

                        // Verify type conversion operations
                        switch (opcode) {
                            .sextend, .uextend => {
                                // Source must be narrower than dest
                                if (arg_ty.bits() >= result_ty.bits()) {
                                    const msg = try std.fmt.allocPrint(
                                        self.allocator,
                                        "{s}: source type ({d} bits) must be narrower than dest ({d} bits) in inst {d}",
                                        .{ @tagName(opcode), arg_ty.bits(), result_ty.bits(), inst.index },
                                    );
                                    try self.errors.append(self.allocator, msg);
                                }
                            },
                            .ireduce => {
                                // Source must be wider than dest
                                if (arg_ty.bits() <= result_ty.bits()) {
                                    const msg = try std.fmt.allocPrint(
                                        self.allocator,
                                        "ireduce: source type ({d} bits) must be wider than dest ({d} bits) in inst {d}",
                                        .{ arg_ty.bits(), result_ty.bits(), inst.index },
                                    );
                                    try self.errors.append(self.allocator, msg);
                                }
                            },
                            .fpromote => {
                                // f32 -> f64 only
                                if (arg_ty.bits() != 32 or result_ty.bits() != 64) {
                                    const msg = try std.fmt.allocPrint(
                                        self.allocator,
                                        "fpromote: must be f32->f64, got {d}->{d} bits in inst {d}",
                                        .{ arg_ty.bits(), result_ty.bits(), inst.index },
                                    );
                                    try self.errors.append(self.allocator, msg);
                                }
                            },
                            .fdemote => {
                                // f64 -> f32 only
                                if (arg_ty.bits() != 64 or result_ty.bits() != 32) {
                                    const msg = try std.fmt.allocPrint(
                                        self.allocator,
                                        "fdemote: must be f64->f32, got {d}->{d} bits in inst {d}",
                                        .{ arg_ty.bits(), result_ty.bits(), inst.index },
                                    );
                                    try self.errors.append(self.allocator, msg);
                                }
                            },
                            .swiden_low, .swiden_high, .uwiden_low, .uwiden_high => {
                                // Widening: input vector lanes must be narrower than output vector lanes
                                // Output width must be 2× input width (e.g., i16x8 → i32x4)
                                if (!arg_ty.isVector() or !result_ty.isVector()) {
                                    const msg = try std.fmt.allocPrint(
                                        self.allocator,
                                        "{s}: both input and output must be vectors in inst {d}",
                                        .{ @tagName(opcode), inst.index },
                                    );
                                    try self.errors.append(self.allocator, msg);
                                } else {
                                    const arg_lane_bits = arg_ty.laneBits();
                                    const result_lane_bits = result_ty.laneBits();
                                    const arg_lanes = arg_ty.laneCount();
                                    const result_lanes = result_ty.laneCount();

                                    if (result_lane_bits != arg_lane_bits * 2) {
                                        const msg = try std.fmt.allocPrint(
                                            self.allocator,
                                            "{s}: output lane bits ({d}) must be 2× input lane bits ({d}) in inst {d}",
                                            .{ @tagName(opcode), result_lane_bits, arg_lane_bits, inst.index },
                                        );
                                        try self.errors.append(self.allocator, msg);
                                    }

                                    if (result_lanes != arg_lanes / 2) {
                                        const msg = try std.fmt.allocPrint(
                                            self.allocator,
                                            "{s}: output lane count ({d}) must be ½ input lane count ({d}) in inst {d}",
                                            .{ @tagName(opcode), result_lanes, arg_lanes, inst.index },
                                        );
                                        try self.errors.append(self.allocator, msg);
                                    }
                                }
                            },
                            else => {},
                        }
                    },
                    .atomic_load => |al| {
                        // Atomic loads must be on integer types
                        if (!result_ty.isInt()) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "atomic_load: must operate on integer type, got {any} in inst {d}",
                                .{ result_ty, inst.index },
                            );
                            try self.errors.append(self.allocator, msg);
                        }
                        // Load ordering cannot be Release-only
                        if (al.ordering == .release) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "atomic_load: invalid ordering 'release' (use acquire, acq_rel, or seq_cst) in inst {d}",
                                .{inst.index},
                            );
                            try self.errors.append(self.allocator, msg);
                        }
                    },
                    .atomic_store => |as| {
                        const src_ty = self.func.dfg.valueType(as.src) orelse continue;
                        // Atomic stores must be on integer types
                        if (!src_ty.isInt()) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "atomic_store: must operate on integer type, got {any} in inst {d}",
                                .{ src_ty, inst.index },
                            );
                            try self.errors.append(self.allocator, msg);
                        }
                        // Store ordering cannot be Acquire-only
                        if (as.ordering == .acquire) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "atomic_store: invalid ordering 'acquire' (use release, acq_rel, or seq_cst) in inst {d}",
                                .{inst.index},
                            );
                            try self.errors.append(self.allocator, msg);
                        }
                    },
                    .atomic_rmw => |ar| {
                        const src_ty = self.func.dfg.valueType(ar.src) orelse continue;
                        // Atomic RMW must be on integer types
                        if (!result_ty.isInt() or !src_ty.isInt()) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "atomic_rmw: must operate on integer types, got result={any} src={any} in inst {d}",
                                .{ result_ty, src_ty, inst.index },
                            );
                            try self.errors.append(self.allocator, msg);
                        }
                        // Result and source must have same type
                        if (!std.meta.eql(result_ty, src_ty)) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "atomic_rmw: result and source must have same type in inst {d}",
                                .{inst.index},
                            );
                            try self.errors.append(self.allocator, msg);
                        }
                    },
                    .atomic_cas => |ac| {
                        const expected_ty = self.func.dfg.valueType(ac.expected) orelse continue;
                        const replacement_ty = self.func.dfg.valueType(ac.replacement) orelse continue;
                        // Atomic CAS must be on integer types
                        if (!result_ty.isInt() or !expected_ty.isInt() or !replacement_ty.isInt()) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "atomic_cas: must operate on integer types in inst {d}",
                                .{inst.index},
                            );
                            try self.errors.append(self.allocator, msg);
                        }
                        // All types must match
                        if (!std.meta.eql(result_ty, expected_ty) or !std.meta.eql(result_ty, replacement_ty)) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "atomic_cas: result, expected, and replacement must have same type in inst {d}",
                                .{inst.index},
                            );
                            try self.errors.append(self.allocator, msg);
                        }
                    },
                    .extract_lane => |el| {
                        const arg_ty = self.func.dfg.valueType(el.arg);

                        // extract_lane requires vector input
                        if (!arg_ty.isVector()) {
                            const msg = try std.fmt.allocPrint(
                                self.allocator,
                                "extract_lane: input must be a vector, got {any} in inst {d}",
                                .{ arg_ty, inst.index },
                            );
                            try self.errors.append(self.allocator, msg);
                        } else {
                            // Lane index must be within bounds
                            const lane_count = arg_ty.laneCount();
                            if (el.lane >= lane_count) {
                                const msg = try std.fmt.allocPrint(
                                    self.allocator,
                                    "extract_lane: lane index {d} out of bounds (vector has {d} lanes) in inst {d}",
                                    .{ el.lane, lane_count, inst.index },
                                );
                                try self.errors.append(self.allocator, msg);
                            }

                            // Result type should match lane type
                            const lane_ty = arg_ty.laneType();
                            if (!std.meta.eql(result_ty, lane_ty)) {
                                const msg = try std.fmt.allocPrint(
                                    self.allocator,
                                    "extract_lane: result type must match vector lane type in inst {d}",
                                    .{inst.index},
                                );
                                try self.errors.append(self.allocator, msg);
                            }
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
        var block_iter = self.func.layout.blockIter();
        while (block_iter.next()) |block| {
            const last_inst = self.func.layout.lastInst(block);
            if (last_inst == null) {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "Block {d} has no instructions",
                    .{block.index},
                );
                try self.errors.append(self.allocator, msg);
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
                try self.errors.append(self.allocator, msg);
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
