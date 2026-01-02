const std = @import("std");
const testing = std.testing;
const hoist = @import("hoist");

const lower_helpers = hoist.codegen.lower_helpers;
const Type = hoist.ir_ns.types.Type;

test "ValueRegs basic operations" {
    const V = lower_helpers.ValueRegs(u32);

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
    try testing.expectEqual(lower_helpers.RegClass.gpr, lower_helpers.RegClass.forType(Type.I32));
    try testing.expectEqual(lower_helpers.RegClass.gpr, lower_helpers.RegClass.forType(Type.I64));
    try testing.expectEqual(lower_helpers.RegClass.fpr, lower_helpers.RegClass.forType(Type.F32));
    try testing.expectEqual(lower_helpers.RegClass.fpr, lower_helpers.RegClass.forType(Type.F64));
    try testing.expectEqual(lower_helpers.RegClass.fpr, lower_helpers.RegClass.forType(Type.I32X4));
}

test "numRegsForType" {
    try testing.expectEqual(@as(u8, 1), lower_helpers.numRegsForType(Type.I8));
    try testing.expectEqual(@as(u8, 1), lower_helpers.numRegsForType(Type.I32));
    try testing.expectEqual(@as(u8, 1), lower_helpers.numRegsForType(Type.I64));
    try testing.expectEqual(@as(u8, 2), lower_helpers.numRegsForType(Type.I128));
}

test "isImmediateConstant" {
    // Positive values
    try testing.expect(lower_helpers.isImmediateConstant(42, Type.I32));
    try testing.expect(lower_helpers.isImmediateConstant(1000, Type.I64));

    // Negative values
    try testing.expect(lower_helpers.isImmediateConstant(-42, Type.I32));

    // Out of range
    try testing.expect(!lower_helpers.isImmediateConstant(256, Type.I8));
    try testing.expect(!lower_helpers.isImmediateConstant(-129, Type.I8));
}

test "fitsInSmallImm" {
    try testing.expect(lower_helpers.fitsInSmallImm(0));
    try testing.expect(lower_helpers.fitsInSmallImm(100));
    try testing.expect(lower_helpers.fitsInSmallImm(-100));
    try testing.expect(lower_helpers.fitsInSmallImm(2047));
    try testing.expect(lower_helpers.fitsInSmallImm(-2048));

    try testing.expect(!lower_helpers.fitsInSmallImm(2048));
    try testing.expect(!lower_helpers.fitsInSmallImm(-2049));
}

test "isPowerOfTwo" {
    try testing.expect(lower_helpers.isPowerOfTwo(1));
    try testing.expect(lower_helpers.isPowerOfTwo(2));
    try testing.expect(lower_helpers.isPowerOfTwo(4));
    try testing.expect(lower_helpers.isPowerOfTwo(1024));

    try testing.expect(!lower_helpers.isPowerOfTwo(0));
    try testing.expect(!lower_helpers.isPowerOfTwo(3));
    try testing.expect(!lower_helpers.isPowerOfTwo(100));
}

test "log2 of power of two" {
    try testing.expectEqual(@as(u6, 0), lower_helpers.log2(1).?);
    try testing.expectEqual(@as(u6, 1), lower_helpers.log2(2).?);
    try testing.expectEqual(@as(u6, 10), lower_helpers.log2(1024).?);
    try testing.expectEqual(@as(?u6, null), lower_helpers.log2(3));
}

test "immediateStrategy" {
    // Small immediate
    try testing.expectEqual(
        lower_helpers.ImmStrategy.inline_imm,
        lower_helpers.immediateStrategy(100, Type.I32, true),
    );

    // Medium immediate with move_wide
    try testing.expectEqual(
        lower_helpers.ImmStrategy.move_imm,
        lower_helpers.immediateStrategy(10000, Type.I32, true),
    );

    // Large constant
    try testing.expectEqual(
        lower_helpers.ImmStrategy.constant_pool,
        lower_helpers.immediateStrategy(0x123456789ABC, Type.I64, true),
    );
}

test "splitI128 and combineI128" {
    const value: u128 = 0x123456789ABCDEF0FEDCBA9876543210;
    const parts = lower_helpers.splitI128(value);

    try testing.expectEqual(@as(u64, 0xFEDCBA9876543210), parts.lo);
    try testing.expectEqual(@as(u64, 0x123456789ABCDEF0), parts.hi);

    const combined = lower_helpers.combineI128(parts.lo, parts.hi);
    try testing.expectEqual(value, combined);
}

test "ValueSource operations" {
    const src = lower_helpers.ValueSource{ .constant = 42 };
    try testing.expect(src.isConstant());
    try testing.expectEqual(@as(u64, 42), src.asConstant().?);

    const inst_src = lower_helpers.ValueSource{
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
    try testing.expect(lower_helpers.sameWidth(Type.I32, Type.F32));
    try testing.expect(lower_helpers.sameWidth(Type.I64, Type.F64));
    try testing.expect(!lower_helpers.sameWidth(Type.I32, Type.I64));
}

test "typeForConstant" {
    try testing.expectEqual(Type.I8, lower_helpers.typeForConstant(100));
    try testing.expectEqual(Type.I16, lower_helpers.typeForConstant(1000));
    try testing.expectEqual(Type.I32, lower_helpers.typeForConstant(100000));
    try testing.expectEqual(Type.I64, lower_helpers.typeForConstant(0x100000000));
}

test "requiresSpecialLowering" {
    try testing.expect(!lower_helpers.requiresSpecialLowering(Type.I32));
    try testing.expect(!lower_helpers.requiresSpecialLowering(Type.I64));
    try testing.expect(lower_helpers.requiresSpecialLowering(Type.I128));
    try testing.expect(lower_helpers.requiresSpecialLowering(Type.I32X4));
}

test "isZero" {
    try testing.expect(lower_helpers.isZero(0));
    try testing.expect(!lower_helpers.isZero(1));
    try testing.expect(!lower_helpers.isZero(-1));
}

test "isAllOnes" {
    try testing.expect(lower_helpers.isAllOnes(0xFF, Type.I8));
    try testing.expect(lower_helpers.isAllOnes(0xFFFF, Type.I16));
    try testing.expect(lower_helpers.isAllOnes(0xFFFFFFFF, Type.I32));
    try testing.expect(lower_helpers.isAllOnes(0xFFFFFFFFFFFFFFFF, Type.I64));

    try testing.expect(!lower_helpers.isAllOnes(0xFE, Type.I8));
    try testing.expect(!lower_helpers.isAllOnes(0xFF, Type.I16));
}
