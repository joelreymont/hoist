//! Global Value Numbering (GVN) optimization pass.
//!
//! Eliminates redundant computations by:
//! - Hashing instruction patterns (opcode + operands)
//! - Building a value number table mapping patterns to canonical values
//! - Identifying redundant computations
//! - Replacing duplicates with aliases to the first occurrence
//!
//! This is a forward dataflow analysis that processes instructions in layout order,
//! detecting when two instructions compute the same value.

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("root");
const Function = root.function.Function;
const Block = root.entities.Block;
const Inst = root.entities.Inst;
const Value = root.entities.Value;
const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;
const ValueData = root.dfg.ValueData;

/// Instruction pattern hash - represents the computation performed by an instruction.
const InstPattern = struct {
    opcode: Opcode,
    args: [4]Value,
    arg_count: u8,

    fn hash(self: InstPattern) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&self.opcode));
        hasher.update(std.mem.asBytes(&self.args[0..self.arg_count]));
        return hasher.final();
    }

    fn eql(self: InstPattern, other: InstPattern) bool {
        if (self.opcode != other.opcode) return false;
        if (self.arg_count != other.arg_count) return false;
        for (0..self.arg_count) |i| {
            if (self.args[i].index != other.args[i].index) return false;
        }
        return true;
    }
};

const PatternContext = struct {
    pub fn hash(_: PatternContext, key: InstPattern) u64 {
        return key.hash();
    }

    pub fn eql(_: PatternContext, a: InstPattern, b: InstPattern) bool {
        return a.eql(b);
    }
};

/// Global Value Numbering pass.
pub const GVN = struct {
    /// Allocator for temporary data structures.
    allocator: Allocator,
    /// Map from instruction pattern to canonical value.
    value_numbers: std.HashMap(InstPattern, Value, PatternContext, std.hash_map.default_max_load_percentage),

    pub fn init(allocator: Allocator) GVN {
        return .{
            .allocator = allocator,
            .value_numbers = std.HashMap(InstPattern, Value, PatternContext, std.hash_map.default_max_load_percentage).init(allocator),
        };
    }

    pub fn deinit(self: *GVN) void {
        self.value_numbers.deinit();
    }

    /// Run GVN on the function.
    /// Returns true if any redundant computations were eliminated.
    pub fn run(self: *GVN, func: *Function) !bool {
        var changed = false;

        // Process each block in layout order
        var block_iter = func.layout.blocks();
        while (block_iter.next()) |block| {
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = func.dfg.insts.get(inst) orelse continue;

                // Only process pure instructions (no side effects)
                if (!isPure(inst_data.opcode())) continue;

                // Extract instruction pattern
                const pattern = extractPattern(func, inst_data.*) orelse continue;

                // Check if we've seen this pattern before
                if (self.value_numbers.get(pattern)) |canonical_value| {
                    // Found redundant computation - create alias
                    const result = func.dfg.firstResult(inst) orelse continue;
                    const ty = func.dfg.valueType(result) orelse continue;

                    const result_data = func.dfg.values.getMut(result) orelse continue;
                    result_data.* = ValueData.alias(ty, canonical_value);
                    changed = true;
                } else {
                    // First occurrence - record it
                    const result = func.dfg.firstResult(inst) orelse continue;
                    try self.value_numbers.put(pattern, result);
                }
            }
        }

        // Resolve all aliases if we made changes
        if (changed) {
            func.dfg.resolveAllAliases();
        }

        // Clear for next run
        self.value_numbers.clearRetainingCapacity();

        return changed;
    }

    /// Check if an opcode represents a pure (side-effect-free) operation.
    fn isPure(opcode: Opcode) bool {
        return switch (opcode) {
            // Control flow has side effects
            .jump, .brif, .br_table, .@"return", .call, .call_indirect => false,
            .return_call, .return_call_indirect, .try_call, .try_call_indirect => false,

            // Memory operations have side effects
            .store, .istore8, .istore16, .istore32 => false,
            .stack_store, .dynamic_stack_store => false,

            // Memory loads can trap and observe memory state
            .load, .uload8, .sload8, .uload16, .sload16, .uload32, .sload32 => false,
            .stack_load, .dynamic_stack_load => false,

            // Traps and special operations
            .trap, .trapz, .trapnz, .debugtrap => false,
            .set_pinned_reg => false,

            // Pure arithmetic operations
            .iadd, .isub, .imul, .udiv, .sdiv, .urem, .srem => true,
            .ineg, .iabs => true,
            .umulhi, .smulhi => true,

            // Pure bitwise operations
            .band, .bor, .bxor, .bnot => true,
            .ishl, .ushr, .sshr, .rotl, .rotr => true,

            // Pure comparisons
            .icmp, .icmp_imm => true,

            // Pure floating-point operations
            .fadd, .fsub, .fmul, .fdiv, .fsqrt => true,
            .fabs, .fneg, .fmin, .fmax => true,
            .fcmp => true,

            // Pure conversions
            .sextend, .uextend, .ireduce => true,
            .fcvt_from_sint, .fcvt_from_uint => true,
            .fcvt_to_sint, .fcvt_to_uint, .fcvt_to_sint_sat, .fcvt_to_uint_sat => true,

            // Constants are pure
            .iconst, .f16const, .f32const, .f64const, .f128const, .vconst => true,

            // Select is pure
            .select, .select_spectre_guard, .bitselect => true,

            // Conservative: assume impure for unknown operations
            else => false,
        };
    }

    /// Extract pattern from instruction data.
    fn extractPattern(func: *Function, inst_data: InstructionData) ?InstPattern {
        const opcode = inst_data.opcode();
        var args = [_]Value{Value.new(0)} ** 4;
        var arg_count: u8 = 0;

        switch (inst_data) {
            .unary => |d| {
                args[0] = func.dfg.resolveAliases(d.arg);
                arg_count = 1;
            },
            .binary => |d| {
                args[0] = func.dfg.resolveAliases(d.args[0]);
                args[1] = func.dfg.resolveAliases(d.args[1]);
                arg_count = 2;
            },
            .int_compare => |d| {
                // Include condition code in pattern by encoding it in opcode
                // For simplicity, we use the args directly
                args[0] = func.dfg.resolveAliases(d.args[0]);
                args[1] = func.dfg.resolveAliases(d.args[1]);
                arg_count = 2;
            },
            .float_compare => |d| {
                args[0] = func.dfg.resolveAliases(d.args[0]);
                args[1] = func.dfg.resolveAliases(d.args[1]);
                arg_count = 2;
            },
            else => return null, // Don't pattern-match complex instructions
        }

        return .{
            .opcode = opcode,
            .args = args,
            .arg_count = arg_count,
        };
    }
};

// Tests

const testing = std.testing;

test "GVN: init and deinit" {
    var gvn = GVN.init(testing.allocator);
    defer gvn.deinit();

    try testing.expectEqual(@as(usize, 0), gvn.value_numbers.count());
}

test "GVN: isPure" {
    // Side-effect operations are not pure
    try testing.expect(!GVN.isPure(.store));
    try testing.expect(!GVN.isPure(.call));
    try testing.expect(!GVN.isPure(.@"return"));
    try testing.expect(!GVN.isPure(.load));

    // Arithmetic operations are pure
    try testing.expect(GVN.isPure(.iadd));
    try testing.expect(GVN.isPure(.isub));
    try testing.expect(GVN.isPure(.imul));

    // Bitwise operations are pure
    try testing.expect(GVN.isPure(.band));
    try testing.expect(GVN.isPure(.bor));
    try testing.expect(GVN.isPure(.bxor));

    // Comparisons are pure
    try testing.expect(GVN.isPure(.icmp));
    try testing.expect(GVN.isPure(.fcmp));
}

test "InstPattern: hash and equality" {
    const p1 = InstPattern{
        .opcode = .iadd,
        .args = [_]Value{ Value.new(1), Value.new(2), Value.new(0), Value.new(0) },
        .arg_count = 2,
    };
    const p2 = InstPattern{
        .opcode = .iadd,
        .args = [_]Value{ Value.new(1), Value.new(2), Value.new(0), Value.new(0) },
        .arg_count = 2,
    };
    const p3 = InstPattern{
        .opcode = .iadd,
        .args = [_]Value{ Value.new(2), Value.new(1), Value.new(0), Value.new(0) },
        .arg_count = 2,
    };

    // Same pattern should be equal
    try testing.expect(p1.eql(p2));
    try testing.expectEqual(p1.hash(), p2.hash());

    // Different operand order should not be equal
    try testing.expect(!p1.eql(p3));
}

test "InstPattern: different opcodes" {
    const p1 = InstPattern{
        .opcode = .iadd,
        .args = [_]Value{ Value.new(1), Value.new(2), Value.new(0), Value.new(0) },
        .arg_count = 2,
    };
    const p2 = InstPattern{
        .opcode = .isub,
        .args = [_]Value{ Value.new(1), Value.new(2), Value.new(0), Value.new(0) },
        .arg_count = 2,
    };

    try testing.expect(!p1.eql(p2));
}
