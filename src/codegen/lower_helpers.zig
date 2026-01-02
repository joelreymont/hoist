//! Value lowering helpers for instruction selection.
//!
//! This module provides helper functions for lowering IR values to machine code:
//! - Value materialization (constants, immediates)
//! - Register class selection for values
//! - Type-aware value handling
//! - Multi-register value packing/unpacking for wide types
//!
//! Reference: Cranelift's lowering helpers in machinst/lower.rs

const std = @import("std");
const Type = @import("../ir/types.zig").Type;
const Value = @import("../ir/entities.zig").Value;
const Imm64 = @import("../ir/immediates.zig").Imm64;

/// Register class for physical register allocation.
pub const RegClass = enum {
    /// General-purpose integer registers
    gpr,
    /// Floating-point/vector registers
    fpr,
    /// Special-purpose registers (flags, etc.)
    special,

    pub fn forType(ty: Type) RegClass {
        if (ty.isFloat() or ty.isVector()) {
            return .fpr;
        } else {
            return .gpr;
        }
    }
};

/// Represents a value packed into one or more registers.
/// Values wider than the native register size require multiple registers.
pub fn ValueRegs(comptime R: type) type {
    return struct {
        const Self = @This();

        regs: [2]R,
        len: u8,

        /// Single register value.
        pub fn one(r: R) Self {
            return .{
                .regs = [_]R{ r, undefined },
                .len = 1,
            };
        }

        /// Two-register value (for i128 on 64-bit, etc.).
        pub fn two(r1: R, r2: R) Self {
            return .{
                .regs = [_]R{ r1, r2 },
                .len = 2,
            };
        }

        /// Invalid/uninitialized value.
        pub fn invalid() Self {
            return .{
                .regs = undefined,
                .len = 0,
            };
        }

        pub fn isValid(self: Self) bool {
            return self.len > 0;
        }

        pub fn isInvalid(self: Self) bool {
            return self.len == 0;
        }

        /// Get slice of registers.
        pub fn slice(self: Self) []const R {
            return self.regs[0..self.len];
        }

        /// Get single register (asserts len == 1).
        pub fn onlyReg(self: Self) ?R {
            if (self.len == 1) {
                return self.regs[0];
            }
            return null;
        }

        /// Map over registers.
        pub fn map(self: Self, comptime NewR: type, f: fn (R) NewR) ValueRegs(NewR) {
            var result = ValueRegs(NewR){
                .regs = undefined,
                .len = self.len,
            };
            for (self.slice(), 0..) |r, i| {
                result.regs[i] = f(r);
            }
            return result;
        }
    };
}

/// Writable register wrapper for output values.
pub fn WritableReg(comptime R: type) type {
    return struct {
        const Self = @This();
        reg: R,

        pub fn new(r: R) Self {
            return .{ .reg = r };
        }

        pub fn toReg(self: Self) R {
            return self.reg;
        }
    };
}

/// Number of registers needed for a type.
pub fn numRegsForType(ty: Type) u8 {
    const bits = ty.bits();
    if (bits == 0) return 0;

    // Assume 64-bit native register size
    const reg_bits = 64;

    // i128 needs 2 registers, everything else needs 1
    if (bits > reg_bits) {
        return 2;
    } else {
        return 1;
    }
}

/// Determine if a constant can be materialized as an immediate.
pub fn isImmediateConstant(value: i64, ty: Type) bool {
    const bits = ty.bits();
    if (bits == 0) return false;

    // Check if value fits in type's bit width
    const shift = 64 - bits;
    const sign_extended = (value << @intCast(shift)) >> @intCast(shift);
    return value == sign_extended;
}

/// Determine if a constant can fit in a small immediate field (12-bit signed).
pub fn fitsInSmallImm(value: i64) bool {
    return value >= -2048 and value <= 2047;
}

/// Determine if a constant can fit in a medium immediate field (16-bit signed).
pub fn fitsInMediumImm(value: i64) bool {
    return value >= -32768 and value <= 32767;
}

/// Check if value is a power of two.
pub fn isPowerOfTwo(value: u64) bool {
    return value != 0 and (value & (value - 1)) == 0;
}

/// Get log2 of a power-of-two value.
pub fn log2(value: u64) ?u6 {
    if (!isPowerOfTwo(value)) return null;
    return @intCast(@ctz(value));
}

/// Immediate materialization strategy.
pub const ImmStrategy = enum {
    /// Fits in instruction immediate field
    inline_imm,
    /// Requires move immediate instruction
    move_imm,
    /// Requires loading from constant pool
    constant_pool,
};

/// Determine how to materialize an immediate value.
pub fn immediateStrategy(value: i64, ty: Type, has_move_wide: bool) ImmStrategy {
    _ = ty;

    // Small immediates can usually be inlined
    if (fitsInSmallImm(value)) {
        return .inline_imm;
    }

    // If we have MOVZ/MOVK (AArch64) or equivalent, use move_imm
    if (has_move_wide) {
        return .move_imm;
    }

    // Medium immediates might fit in move on some architectures
    if (fitsInMediumImm(value)) {
        return .move_imm;
    }

    // Large constants need constant pool
    return .constant_pool;
}

/// Split i128 value into two i64 parts (low, high).
pub fn splitI128(value: u128) struct { lo: u64, hi: u64 } {
    return .{
        .lo = @truncate(value),
        .hi = @truncate(value >> 64),
    };
}

/// Combine two i64 parts into i128.
pub fn combineI128(lo: u64, hi: u64) u128 {
    return @as(u128, lo) | (@as(u128, hi) << 64);
}

/// Value source information for pattern matching.
pub const ValueSource = union(enum) {
    /// Value is in a register
    reg: void,
    /// Value is a known constant
    constant: u64,
    /// Value is produced by an instruction
    inst: struct {
        /// Instruction that produces this value
        inst_id: u32,
        /// Output index (for multi-output instructions)
        output_idx: usize,
        /// Is this the only use of this value?
        unique: bool,
    },
    /// Value is a block parameter
    block_param: void,

    pub fn isConstant(self: ValueSource) bool {
        return self == .constant;
    }

    pub fn asConstant(self: ValueSource) ?u64 {
        return switch (self) {
            .constant => |c| c,
            else => null,
        };
    }

    pub fn isInst(self: ValueSource) bool {
        return self == .inst;
    }
};

/// Helper to check if two types have the same width.
pub fn sameWidth(ty1: Type, ty2: Type) bool {
    return ty1.bits() == ty2.bits();
}

/// Helper to get the smallest type that can hold a constant.
pub fn typeForConstant(value: u64) Type {
    if (value <= 0xFF) {
        return Type.I8;
    } else if (value <= 0xFFFF) {
        return Type.I16;
    } else if (value <= 0xFFFFFFFF) {
        return Type.I32;
    } else {
        return Type.I64;
    }
}

/// Check if a type requires special handling (vectors, i128, etc.).
pub fn requiresSpecialLowering(ty: Type) bool {
    return ty.bits() > 64 or ty.isVector();
}

/// Get the natural register type for the target (I64 on 64-bit).
pub fn nativeRegType() Type {
    return Type.I64;
}

/// Check if value is zero.
pub fn isZero(value: i64) bool {
    return value == 0;
}

/// Check if value is all ones (for AND/OR optimization).
pub fn isAllOnes(value: u64, ty: Type) bool {
    const bits = ty.bits();
    if (bits == 0) return false;
    if (bits == 64) return value == 0xFFFFFFFFFFFFFFFF;

    const mask = (@as(u64, 1) << @intCast(bits)) - 1;
    return (value & mask) == mask;
}

// Tests
const testing = std.testing;

test "ValueRegs basic operations" {
    const V = ValueRegs(u32);

    const r1 = V.one(42);
    try testing.expect(r1.isValid());
    try testing.expectEqual(@as(u8, 1), r1.len);
    try testing.expectEqual(@as(u32, 42), r1.onlyReg().?);

    const r2 = V.two(10, 20);
    try testing.expect(r2.isValid());
    try testing.expectEqual(@as(u8, 2), r2.len);
    try testing.expectEqual(@as(?u32, null), r2.onlyReg());

    const invalid = V.invalid();
    try testing.expect(invalid.isInvalid());
}

test "RegClass for types" {
    try testing.expectEqual(RegClass.gpr, RegClass.forType(Type.I32));
    try testing.expectEqual(RegClass.gpr, RegClass.forType(Type.I64));
    try testing.expectEqual(RegClass.fpr, RegClass.forType(Type.F32));
    try testing.expectEqual(RegClass.fpr, RegClass.forType(Type.F64));
    try testing.expectEqual(RegClass.fpr, RegClass.forType(Type.I32X4));
}

test "numRegsForType" {
    try testing.expectEqual(@as(u8, 1), numRegsForType(Type.I8));
    try testing.expectEqual(@as(u8, 1), numRegsForType(Type.I32));
    try testing.expectEqual(@as(u8, 1), numRegsForType(Type.I64));
    try testing.expectEqual(@as(u8, 2), numRegsForType(Type.I128));
}

test "isImmediateConstant" {
    // Positive values
    try testing.expect(isImmediateConstant(42, Type.I32));
    try testing.expect(isImmediateConstant(1000, Type.I64));

    // Negative values
    try testing.expect(isImmediateConstant(-42, Type.I32));

    // Out of range
    try testing.expect(!isImmediateConstant(256, Type.I8));
    try testing.expect(!isImmediateConstant(-129, Type.I8));
}

test "fitsInSmallImm" {
    try testing.expect(fitsInSmallImm(0));
    try testing.expect(fitsInSmallImm(100));
    try testing.expect(fitsInSmallImm(-100));
    try testing.expect(fitsInSmallImm(2047));
    try testing.expect(fitsInSmallImm(-2048));

    try testing.expect(!fitsInSmallImm(2048));
    try testing.expect(!fitsInSmallImm(-2049));
}

test "isPowerOfTwo" {
    try testing.expect(isPowerOfTwo(1));
    try testing.expect(isPowerOfTwo(2));
    try testing.expect(isPowerOfTwo(4));
    try testing.expect(isPowerOfTwo(1024));

    try testing.expect(!isPowerOfTwo(0));
    try testing.expect(!isPowerOfTwo(3));
    try testing.expect(!isPowerOfTwo(100));
}

test "log2 of power of two" {
    try testing.expectEqual(@as(u6, 0), log2(1).?);
    try testing.expectEqual(@as(u6, 1), log2(2).?);
    try testing.expectEqual(@as(u6, 10), log2(1024).?);
    try testing.expectEqual(@as(?u6, null), log2(3));
}

test "immediateStrategy" {
    // Small immediate
    try testing.expectEqual(ImmStrategy.inline_imm, immediateStrategy(100, Type.I32, true));

    // Medium immediate with move_wide
    try testing.expectEqual(ImmStrategy.move_imm, immediateStrategy(10000, Type.I32, true));

    // Large constant
    try testing.expectEqual(
        ImmStrategy.constant_pool,
        immediateStrategy(0x123456789ABC, Type.I64, true),
    );
}

test "splitI128 and combineI128" {
    const value: u128 = 0x123456789ABCDEF0FEDCBA9876543210;
    const parts = splitI128(value);

    try testing.expectEqual(@as(u64, 0xFEDCBA9876543210), parts.lo);
    try testing.expectEqual(@as(u64, 0x123456789ABCDEF0), parts.hi);

    const combined = combineI128(parts.lo, parts.hi);
    try testing.expectEqual(value, combined);
}

test "ValueSource operations" {
    const src = ValueSource{ .constant = 42 };
    try testing.expect(src.isConstant());
    try testing.expectEqual(@as(u64, 42), src.asConstant().?);

    const inst_src = ValueSource{
        .inst = .{
            .inst_id = 10,
            .output_idx = 0,
            .unique = true,
        },
    };
    try testing.expect(inst_src.isInst());
    try testing.expect(!inst_src.isConstant());
}

test "sameWidth" {
    try testing.expect(sameWidth(Type.I32, Type.F32));
    try testing.expect(sameWidth(Type.I64, Type.F64));
    try testing.expect(!sameWidth(Type.I32, Type.I64));
}

test "typeForConstant" {
    try testing.expectEqual(Type.I8, typeForConstant(100));
    try testing.expectEqual(Type.I16, typeForConstant(1000));
    try testing.expectEqual(Type.I32, typeForConstant(100000));
    try testing.expectEqual(Type.I64, typeForConstant(0x100000000));
}

test "requiresSpecialLowering" {
    try testing.expect(!requiresSpecialLowering(Type.I32));
    try testing.expect(!requiresSpecialLowering(Type.I64));
    try testing.expect(requiresSpecialLowering(Type.I128));
    try testing.expect(requiresSpecialLowering(Type.I32X4));
}

test "isZero" {
    try testing.expect(isZero(0));
    try testing.expect(!isZero(1));
    try testing.expect(!isZero(-1));
}

test "isAllOnes" {
    try testing.expect(isAllOnes(0xFF, Type.I8));
    try testing.expect(isAllOnes(0xFFFF, Type.I16));
    try testing.expect(isAllOnes(0xFFFFFFFF, Type.I32));
    try testing.expect(isAllOnes(0xFFFFFFFFFFFFFFFF, Type.I64));

    try testing.expect(!isAllOnes(0xFE, Type.I8));
    try testing.expect(!isAllOnes(0xFF, Type.I16));
}
