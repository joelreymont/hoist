//! NaN Canonicalization Pass
//!
//! Ensures all NaN values have a canonical bit pattern for WebAssembly
//! determinism. FP operations can produce NaNs with arbitrary payloads;
//! this pass inserts checks to replace them with canonical quiet NaNs.
//!
//! Canonical NaN values:
//! - f32: 0x7fc00000 (quiet NaN, canonical payload)
//! - f64: 0x7ff8000000000000 (quiet NaN, canonical payload)

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir_mod = @import("../../ir.zig");
const Function = @import("../../ir/function.zig").Function;
const Block = ir_mod.Block;
const Inst = ir_mod.Inst;
const Value = ir_mod.Value;
const Type = @import("../../ir/types.zig").Type;
const Opcode = @import("../../ir/opcodes.zig").Opcode;
const InstructionData = @import("../../ir/instruction_data.zig").InstructionData;
const Imm64 = @import("../../ir/immediates.zig").Imm64;
const ValueData = @import("../../ir/dfg.zig").ValueData;

/// Canonical NaN bit patterns.
pub const CANONICAL_NAN_F32: u32 = 0x7fc00000;
pub const CANONICAL_NAN_F64: u64 = 0x7ff8000000000000;

/// NaN canonicalization pass for WebAssembly compliance.
pub const NaNCanon = struct {
    allocator: Allocator,
    /// Number of canonicalization sequences inserted.
    insertions: u32,

    pub fn init(allocator: Allocator) NaNCanon {
        return .{
            .allocator = allocator,
            .insertions = 0,
        };
    }

    pub fn deinit(self: *NaNCanon) void {
        _ = self;
    }

    /// Run NaN canonicalization on the function.
    /// Returns true if any canonicalization sequences were inserted.
    pub fn run(self: *NaNCanon, func: *Function) !bool {
        self.insertions = 0;

        // Collect instructions that need canonicalization
        var to_canonicalize = std.ArrayList(struct { inst: Inst, block: Block }).init(self.allocator);
        defer to_canonicalize.deinit();

        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = func.dfg.insts.get(inst) orelse continue;
                const opcode = inst_data.opcode();

                if (needsCanonicalization(opcode)) {
                    // Check if result is float type
                    const results = func.dfg.instResults(inst);
                    if (results.len > 0) {
                        const result_ty = func.dfg.valueType(results[0]);
                        if (result_ty == .F32 or result_ty == .F64) {
                            try to_canonicalize.append(.{ .inst = inst, .block = block });
                        }
                    }
                }
            }
        }

        // Insert canonicalization after each collected instruction
        for (to_canonicalize.items) |item| {
            try self.insertCanonSequence(func, item.inst, item.block);
        }

        // Resolve all aliases to update uses
        if (self.insertions > 0) {
            func.dfg.resolveAllAliases();
        }

        return self.insertions > 0;
    }

    /// Check if an opcode can produce non-canonical NaN.
    fn needsCanonicalization(opcode: Opcode) bool {
        return switch (opcode) {
            // Arithmetic ops that can produce NaN
            .fadd, .fsub, .fmul, .fdiv, .sqrt => true,
            // Min/max can propagate either operand's NaN
            .fmin, .fmax => true,
            // FMA can produce NaN
            .fma => true,
            // Conversions from int can't produce NaN, but float-to-float can
            .fpromote, .fdemote => true,
            // These preserve NaN payload, but we still canonicalize for safety
            .fneg, .fabs, .fcopysign => true,
            // Comparisons return int, not float
            else => false,
        };
    }

    /// Insert a NaN canonicalization sequence after an instruction.
    /// Pattern: result = isnan(orig) ? canonical_nan : orig
    fn insertCanonSequence(self: *NaNCanon, func: *Function, inst: Inst, block: Block) !void {
        const results = func.dfg.instResults(inst);
        if (results.len == 0) return;

        const orig_result = results[0];
        const result_ty = func.dfg.valueType(orig_result);

        // Create canonical NaN constant
        const canon_nan = switch (result_ty) {
            .F32 => Imm64.new(@as(i64, @bitCast(@as(u64, CANONICAL_NAN_F32)))),
            .F64 => Imm64.new(@as(i64, @bitCast(CANONICAL_NAN_F64))),
            else => return,
        };

        const const_opcode: Opcode = if (result_ty == .F32) .f32const else .f64const;

        // Create: nan_const = fXXconst canonical_nan
        const nan_const_data = InstructionData{ .unary_imm = .{
            .opcode = const_opcode,
            .imm = canon_nan,
        } };
        const nan_const_inst = try func.dfg.makeInst(nan_const_data);
        const nan_const_val = try func.dfg.appendInstResult(nan_const_inst, result_ty);

        // Create: is_nan = fcmp uno orig, orig (unordered comparison with self detects NaN)
        const is_nan_data = InstructionData{ .float_compare = .{
            .opcode = .fcmp,
            .cond = .uno,
            .args = .{ orig_result, orig_result },
        } };
        const is_nan_inst = try func.dfg.makeInst(is_nan_data);
        const is_nan_val = try func.dfg.appendInstResult(is_nan_inst, .I8);

        // Create: canonical = select is_nan, nan_const, orig
        const select_data = InstructionData{ .ternary = .{
            .opcode = .select,
            .args = .{ is_nan_val, nan_const_val, orig_result },
        } };
        const select_inst = try func.dfg.makeInst(select_data);
        const canonical_val = try func.dfg.appendInstResult(select_inst, result_ty);

        // Insert instructions after the original
        _ = block; // Block is inferred from 'after' instruction
        try func.layout.insertInstAfter(nan_const_inst, inst);
        try func.layout.insertInstAfter(is_nan_inst, nan_const_inst);
        try func.layout.insertInstAfter(select_inst, is_nan_inst);

        // Replace uses of orig_result with canonical_val by making orig_result alias to canonical_val
        const orig_data = func.dfg.values.getMut(orig_result) orelse return;
        orig_data.* = ValueData.alias(result_ty, canonical_val);

        self.insertions += 1;
    }

    /// Get statistics.
    pub fn getInsertions(self: *const NaNCanon) u32 {
        return self.insertions;
    }
};

test "NaN canonicalization constants" {
    const testing = std.testing;

    // Verify canonical NaN patterns
    const f32_nan: f32 = @bitCast(CANONICAL_NAN_F32);
    const f64_nan: f64 = @bitCast(CANONICAL_NAN_F64);

    try testing.expect(std.math.isNan(f32_nan));
    try testing.expect(std.math.isNan(f64_nan));

    // Verify they are quiet NaNs (not signaling)
    // Quiet NaN has the most significant fraction bit set
    try testing.expect((CANONICAL_NAN_F32 & 0x00400000) != 0);
    try testing.expect((CANONICAL_NAN_F64 & 0x0008000000000000) != 0);
}

test "needsCanonicalization identifies FP ops" {
    const testing = std.testing;

    // Should need canonicalization
    try testing.expect(NaNCanon.needsCanonicalization(.fadd));
    try testing.expect(NaNCanon.needsCanonicalization(.fsub));
    try testing.expect(NaNCanon.needsCanonicalization(.fmul));
    try testing.expect(NaNCanon.needsCanonicalization(.fdiv));
    try testing.expect(NaNCanon.needsCanonicalization(.sqrt));
    try testing.expect(NaNCanon.needsCanonicalization(.fmin));
    try testing.expect(NaNCanon.needsCanonicalization(.fmax));

    // Should not need canonicalization
    try testing.expect(!NaNCanon.needsCanonicalization(.iadd));
    try testing.expect(!NaNCanon.needsCanonicalization(.isub));
    try testing.expect(!NaNCanon.needsCanonicalization(.load));
    try testing.expect(!NaNCanon.needsCanonicalization(.store));
}
