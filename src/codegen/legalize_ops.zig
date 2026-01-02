//! Operation legalization for target ISAs.
//!
//! Converts unsupported operations into sequences of legal operations.
//! Implements strategies:
//! - Expand: Replace operation with sequence (udiv/urem by power of 2)
//! - Library call: Call runtime function (soft-float operations)
//! - Custom sequence: Target-specific expansion
//!
//! Reference: Cranelift's legalizer in wasmtime/cranelift/codegen/src/legalizer/

const std = @import("std");
const Allocator = std.mem.Allocator;
const Type = @import("../ir/types.zig").Type;
const Opcode = @import("../ir/opcodes.zig").Opcode;
const Value = @import("../ir/entities.zig").Value;
const Inst = @import("../ir/entities.zig").Inst;

/// Legalization strategy for an operation.
pub const OpAction = enum {
    /// Operation is legal as-is.
    legal,
    /// Expand into sequence of operations.
    expand,
    /// Call runtime library function.
    libcall,
    /// Custom target-specific expansion.
    custom,
};

/// Result of operation legalization analysis.
pub const LegalizeOpResult = struct {
    action: OpAction,
    /// For libcall: name of the runtime function.
    libcall_name: ?[]const u8 = null,
};

/// Operation legalizer for a target.
pub const OpLegalizer = struct {
    /// Whether target has native division instructions.
    has_idiv: bool,
    /// Whether target has native remainder instructions.
    has_irem: bool,
    /// Whether target has native f32 operations.
    has_f32: bool,
    /// Whether target has native f64 operations.
    has_f64: bool,
    /// Whether target has native vector operations.
    has_vector: bool,

    /// Default configuration for modern 64-bit targets.
    pub fn default64() OpLegalizer {
        return .{
            .has_idiv = true,
            .has_irem = true,
            .has_f32 = true,
            .has_f64 = true,
            .has_vector = true,
        };
    }

    /// AArch64 configuration.
    pub fn aarch64() OpLegalizer {
        return .{
            .has_idiv = true,
            .has_irem = false, // No direct remainder, expand to div+msub
            .has_f32 = true,
            .has_f64 = true,
            .has_vector = true,
        };
    }

    /// x86-64 configuration.
    pub fn x86_64() OpLegalizer {
        return .{
            .has_idiv = true,
            .has_irem = true, // Via div instruction
            .has_f32 = true,
            .has_f64 = true,
            .has_vector = true,
        };
    }

    /// RISC-V configuration (minimal).
    pub fn riscv64_minimal() OpLegalizer {
        return .{
            .has_idiv = false, // M extension optional
            .has_irem = false,
            .has_f32 = false, // F extension optional
            .has_f64 = false, // D extension optional
            .has_vector = false,
        };
    }

    /// Determine legalization action for an operation.
    pub fn legalize(self: *const OpLegalizer, op: Opcode, ty: Type) LegalizeOpResult {
        return switch (op) {
            .udiv, .sdiv => self.legalizeDiv(ty),
            .urem, .srem => self.legalizeRem(ty),
            .fadd, .fsub, .fmul, .fdiv => self.legalizeFpOp(op, ty),
            .sqrt, .fma => self.legalizeFpSpecial(op, ty),
            .splat, .insertlane, .extractlane => self.legalizeVectorOp(ty),
            else => .{ .action = .legal },
        };
    }

    fn legalizeDiv(self: *const OpLegalizer, ty: Type) LegalizeOpResult {
        if (!ty.isInt() or ty.isVector()) {
            return .{ .action = .legal };
        }

        if (!self.has_idiv) {
            // No hardware division - requires library call or shift optimization
            return .{ .action = .expand };
        }

        return .{ .action = .legal };
    }

    fn legalizeRem(self: *const OpLegalizer, ty: Type) LegalizeOpResult {
        if (!ty.isInt() or ty.isVector()) {
            return .{ .action = .legal };
        }

        if (!self.has_irem) {
            // Expand: a % b = a - (a / b) * b
            return .{ .action = .expand };
        }

        return .{ .action = .legal };
    }

    fn legalizeFpOp(self: *const OpLegalizer, op: Opcode, ty: Type) LegalizeOpResult {
        _ = op;
        if (!ty.isFloat()) {
            return .{ .action = .legal };
        }

        if (ty.eql(Type.F32) and !self.has_f32) {
            return .{ .action = .libcall, .libcall_name = "soft_float32" };
        }

        if (ty.eql(Type.F64) and !self.has_f64) {
            return .{ .action = .libcall, .libcall_name = "soft_float64" };
        }

        // f16, f128 always require soft-float
        if (ty.eql(Type.F16)) {
            return .{ .action = .libcall, .libcall_name = "soft_float16" };
        }
        if (ty.eql(Type.F128)) {
            return .{ .action = .libcall, .libcall_name = "soft_float128" };
        }

        return .{ .action = .legal };
    }

    fn legalizeFpSpecial(self: *const OpLegalizer, op: Opcode, ty: Type) LegalizeOpResult {
        _ = op;
        if (!ty.isFloat()) {
            return .{ .action = .legal };
        }

        // sqrt, fma typically require library calls on minimal targets
        if (ty.eql(Type.F32) and !self.has_f32) {
            return .{ .action = .libcall, .libcall_name = "soft_float32_special" };
        }
        if (ty.eql(Type.F64) and !self.has_f64) {
            return .{ .action = .libcall, .libcall_name = "soft_float64_special" };
        }

        return .{ .action = .legal };
    }

    fn legalizeVectorOp(self: *const OpLegalizer, ty: Type) LegalizeOpResult {
        if (!ty.isVector()) {
            return .{ .action = .legal };
        }

        if (!self.has_vector) {
            return .{ .action = .expand };
        }

        return .{ .action = .legal };
    }

    /// Check if operation is legal.
    pub fn isLegal(self: *const OpLegalizer, op: Opcode, ty: Type) bool {
        const result = self.legalize(op, ty);
        return result.action == .legal;
    }
};

// ============================================================================
// Integer division/remainder optimization
// ============================================================================

/// Check if value is a power of 2.
pub fn isPowerOfTwo(value: u64) bool {
    return value != 0 and (value & (value - 1)) == 0;
}

/// Get log2 of a power of 2 value.
pub fn log2(value: u64) u6 {
    std.debug.assert(isPowerOfTwo(value));
    return @intCast(@ctz(value));
}

/// Integer division optimization strategy.
pub const DivOptimization = enum {
    /// Cannot optimize, use division instruction.
    none,
    /// Divisor is power of 2, use shift.
    shift_right,
    /// Divisor is constant, use multiplication by reciprocal.
    multiply_reciprocal,
};

/// Analyze integer division for optimization opportunities.
pub fn analyzeDivision(dividend_ty: Type, divisor_value: ?u64, is_signed: bool) DivOptimization {
    _ = dividend_ty;
    _ = is_signed;

    const divisor = divisor_value orelse return .none;

    if (isPowerOfTwo(divisor)) {
        return .shift_right;
    }

    // Multiplication by reciprocal is complex and target-dependent
    // For now, only optimize power-of-2 divisions
    return .none;
}

/// Integer remainder optimization strategy.
pub const RemOptimization = enum {
    /// Cannot optimize, use remainder instruction or expand.
    none,
    /// Divisor is power of 2, use bitwise AND.
    mask,
};

/// Analyze integer remainder for optimization opportunities.
pub fn analyzeRemainder(dividend_ty: Type, divisor_value: ?u64, is_signed: bool) RemOptimization {
    _ = dividend_ty;

    const divisor = divisor_value orelse return .none;

    // For unsigned remainder by power of 2: x % (2^n) = x & (2^n - 1)
    // For signed remainder, it's more complex
    if (!is_signed and isPowerOfTwo(divisor)) {
        return .mask;
    }

    return .none;
}

// ============================================================================
// Expansion helpers
// ============================================================================

/// Information needed to expand udiv by power of 2.
pub const UdivPow2Expansion = struct {
    shift_amount: u6,
};

/// Get expansion for unsigned division by power of 2.
pub fn expandUdivPow2(divisor: u64) ?UdivPow2Expansion {
    if (!isPowerOfTwo(divisor)) return null;
    return .{ .shift_amount = log2(divisor) };
}

/// Information needed to expand urem by power of 2.
pub const UremPow2Expansion = struct {
    mask_value: u64,
};

/// Get expansion for unsigned remainder by power of 2.
pub fn expandUremPow2(divisor: u64) ?UremPow2Expansion {
    if (!isPowerOfTwo(divisor)) return null;
    return .{ .mask_value = divisor - 1 };
}

/// Information needed to expand sdiv by power of 2.
pub const SdivPow2Expansion = struct {
    shift_amount: u6,
    needs_bias: bool,
};

/// Get expansion for signed division by power of 2.
/// For positive divisors that are powers of 2:
///   sdiv(x, 2^n) = (x + (x >> (width-1) & (2^n - 1))) >> n
pub fn expandSdivPow2(divisor: i64, width: u32) ?SdivPow2Expansion {
    if (divisor <= 0) return null;
    const udivisor: u64 = @intCast(divisor);
    if (!isPowerOfTwo(udivisor)) return null;

    const shift_amt = log2(udivisor);
    // Need to add bias for negative dividends
    const needs_bias = shift_amt > 0;

    _ = width; // Will be used for bias calculation

    return .{
        .shift_amount = shift_amt,
        .needs_bias = needs_bias,
    };
}

/// Information needed to expand srem.
pub const SremExpansion = struct {
    // srem(x, y) = x - sdiv(x, y) * y
};

/// Get expansion for signed remainder.
pub fn expandSrem() SremExpansion {
    return .{};
}

/// Information needed to expand urem.
pub const UremExpansion = struct {
    // urem(x, y) = x - udiv(x, y) * y
};

/// Get expansion for unsigned remainder.
pub fn expandUrem() UremExpansion {
    return .{};
}

// ============================================================================
// Vector operation expansion
// ============================================================================

/// Strategy for expanding vector operations.
pub const VectorExpansion = enum {
    /// Extract lanes, operate on scalars, reconstruct vector.
    scalarize,
    /// Split into smaller vectors.
    split,
};

/// Analyze vector operation for expansion.
pub fn analyzeVectorOp(ty: Type, op: Opcode) ?VectorExpansion {
    _ = op;
    if (!ty.isVector()) return null;

    // For small vectors, scalarize
    if (ty.laneCount() <= 4) {
        return .scalarize;
    }

    // For large vectors, split
    return .split;
}

// ============================================================================
// Library call information
// ============================================================================

/// Library call descriptor.
pub const LibCall = struct {
    name: []const u8,
    arg_types: []const Type,
    ret_type: Type,
};

/// Get library call information for an operation.
pub fn getLibCall(op: Opcode, ty: Type, allocator: Allocator) ?LibCall {
    _ = allocator;

    const name = switch (op) {
        .fdiv => if (ty.eql(Type.F32)) "__divsf3" else if (ty.eql(Type.F64)) "__divdf3" else return null,
        .fmul => if (ty.eql(Type.F32)) "__mulsf3" else if (ty.eql(Type.F64)) "__muldf3" else return null,
        .fadd => if (ty.eql(Type.F32)) "__addsf3" else if (ty.eql(Type.F64)) "__adddf3" else return null,
        .fsub => if (ty.eql(Type.F32)) "__subsf3" else if (ty.eql(Type.F64)) "__subdf3" else return null,
        .sqrt => if (ty.eql(Type.F32)) "sqrtf" else if (ty.eql(Type.F64)) "sqrt" else return null,
        else => return null,
    };

    return .{
        .name = name,
        .arg_types = &.{ty},
        .ret_type = ty,
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "OpLegalizer: default64 config" {
    const legalizer = OpLegalizer.default64();
    try testing.expect(legalizer.has_idiv);
    try testing.expect(legalizer.has_irem);
    try testing.expect(legalizer.has_f32);
    try testing.expect(legalizer.has_f64);
    try testing.expect(legalizer.has_vector);
}

test "OpLegalizer: aarch64 config" {
    const legalizer = OpLegalizer.aarch64();
    try testing.expect(legalizer.has_idiv);
    try testing.expect(!legalizer.has_irem); // Must expand
    try testing.expect(legalizer.has_f32);
    try testing.expect(legalizer.has_f64);
}

test "OpLegalizer: riscv64 minimal config" {
    const legalizer = OpLegalizer.riscv64_minimal();
    try testing.expect(!legalizer.has_idiv);
    try testing.expect(!legalizer.has_irem);
    try testing.expect(!legalizer.has_f32);
    try testing.expect(!legalizer.has_f64);
}

test "OpLegalizer: integer division legal on default64" {
    const legalizer = OpLegalizer.default64();
    const result = legalizer.legalize(.udiv, Type.I32);
    try testing.expectEqual(OpAction.legal, result.action);

    const sdiv_result = legalizer.legalize(.sdiv, Type.I64);
    try testing.expectEqual(OpAction.legal, sdiv_result.action);
}

test "OpLegalizer: remainder expansion on aarch64" {
    const legalizer = OpLegalizer.aarch64();
    const result = legalizer.legalize(.urem, Type.I32);
    try testing.expectEqual(OpAction.expand, result.action);
}

test "OpLegalizer: float ops require libcall on minimal target" {
    const legalizer = OpLegalizer.riscv64_minimal();
    const result = legalizer.legalize(.fadd, Type.F32);
    try testing.expectEqual(OpAction.libcall, result.action);
    try testing.expect(result.libcall_name != null);
}

test "OpLegalizer: f16 always requires libcall" {
    const legalizer = OpLegalizer.default64();
    const result = legalizer.legalize(.fadd, Type.F16);
    try testing.expectEqual(OpAction.libcall, result.action);
}

test "OpLegalizer: vector ops expand on minimal target" {
    const legalizer = OpLegalizer.riscv64_minimal();
    const result = legalizer.legalize(.splat, Type.I32X4);
    try testing.expectEqual(OpAction.expand, result.action);
}

test "isPowerOfTwo: basic cases" {
    try testing.expect(isPowerOfTwo(1));
    try testing.expect(isPowerOfTwo(2));
    try testing.expect(isPowerOfTwo(4));
    try testing.expect(isPowerOfTwo(8));
    try testing.expect(isPowerOfTwo(1024));

    try testing.expect(!isPowerOfTwo(0));
    try testing.expect(!isPowerOfTwo(3));
    try testing.expect(!isPowerOfTwo(5));
    try testing.expect(!isPowerOfTwo(6));
    try testing.expect(!isPowerOfTwo(100));
}

test "log2: power of two values" {
    try testing.expectEqual(@as(u6, 0), log2(1));
    try testing.expectEqual(@as(u6, 1), log2(2));
    try testing.expectEqual(@as(u6, 2), log2(4));
    try testing.expectEqual(@as(u6, 3), log2(8));
    try testing.expectEqual(@as(u6, 10), log2(1024));
}

test "analyzeDivision: power of 2 optimization" {
    const result = analyzeDivision(Type.I32, 8, false);
    try testing.expectEqual(DivOptimization.shift_right, result);

    const result2 = analyzeDivision(Type.I32, 1024, false);
    try testing.expectEqual(DivOptimization.shift_right, result2);
}

test "analyzeDivision: non-power of 2" {
    const result = analyzeDivision(Type.I32, 7, false);
    try testing.expectEqual(DivOptimization.none, result);

    const result2 = analyzeDivision(Type.I32, 100, false);
    try testing.expectEqual(DivOptimization.none, result2);
}

test "analyzeRemainder: unsigned power of 2 optimization" {
    const result = analyzeRemainder(Type.I32, 8, false);
    try testing.expectEqual(RemOptimization.mask, result);

    const result2 = analyzeRemainder(Type.I32, 256, false);
    try testing.expectEqual(RemOptimization.mask, result2);
}

test "analyzeRemainder: signed cannot use mask" {
    const result = analyzeRemainder(Type.I32, 8, true);
    try testing.expectEqual(RemOptimization.none, result);
}

test "expandUdivPow2: valid power of 2" {
    const result = expandUdivPow2(8);
    try testing.expect(result != null);
    try testing.expectEqual(@as(u6, 3), result.?.shift_amount);

    const result2 = expandUdivPow2(1024);
    try testing.expect(result2 != null);
    try testing.expectEqual(@as(u6, 10), result2.?.shift_amount);
}

test "expandUdivPow2: non-power of 2" {
    const result = expandUdivPow2(7);
    try testing.expect(result == null);

    const result2 = expandUdivPow2(100);
    try testing.expect(result2 == null);
}

test "expandUremPow2: valid power of 2" {
    const result = expandUremPow2(8);
    try testing.expect(result != null);
    try testing.expectEqual(@as(u64, 7), result.?.mask_value);

    const result2 = expandUremPow2(256);
    try testing.expect(result2 != null);
    try testing.expectEqual(@as(u64, 255), result2.?.mask_value);
}

test "expandSdivPow2: valid power of 2" {
    const result = expandSdivPow2(8, 32);
    try testing.expect(result != null);
    try testing.expectEqual(@as(u6, 3), result.?.shift_amount);
    try testing.expect(result.?.needs_bias);

    const result2 = expandSdivPow2(1, 32);
    try testing.expect(result2 != null);
    try testing.expectEqual(@as(u6, 0), result2.?.shift_amount);
    try testing.expect(!result2.?.needs_bias); // No bias for divide by 1
}

test "expandSdivPow2: negative divisor" {
    const result = expandSdivPow2(-8, 32);
    try testing.expect(result == null);
}

test "expandSrem: returns expansion info" {
    const result = expandSrem();
    _ = result; // Just verify it compiles and returns
}

test "expandUrem: returns expansion info" {
    const result = expandUrem();
    _ = result; // Just verify it compiles and returns
}

test "analyzeVectorOp: small vector scalarizes" {
    const result = analyzeVectorOp(Type.I32X4, .iadd);
    try testing.expect(result != null);
    try testing.expectEqual(VectorExpansion.scalarize, result.?);
}

test "getLibCall: float division" {
    const result = getLibCall(.fdiv, Type.F32, testing.allocator);
    try testing.expect(result != null);
    try testing.expectEqualStrings("__divsf3", result.?.name);

    const result64 = getLibCall(.fdiv, Type.F64, testing.allocator);
    try testing.expect(result64 != null);
    try testing.expectEqualStrings("__divdf3", result64.?.name);
}

test "getLibCall: sqrt" {
    const result = getLibCall(.sqrt, Type.F32, testing.allocator);
    try testing.expect(result != null);
    try testing.expectEqualStrings("sqrtf", result.?.name);

    const result64 = getLibCall(.sqrt, Type.F64, testing.allocator);
    try testing.expect(result64 != null);
    try testing.expectEqualStrings("sqrt", result64.?.name);
}

test "getLibCall: unsupported op returns null" {
    const result = getLibCall(.iadd, Type.I32, testing.allocator);
    try testing.expect(result == null);
}
