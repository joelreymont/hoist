const std = @import("std");
const testing = std.testing;
const hoist = @import("hoist");

const legalize = hoist.aarch64_legalize;
const IntCC = hoist.condcodes.IntCC;
const FloatCC = hoist.condcodes.FloatCC;
const Type = hoist.types.Type;
const CondCode = hoist.aarch64_inst.CondCode;
const OperandSize = hoist.aarch64_inst.OperandSize;

test "aarch64 legalize: intCCToCondCode maps all conditions" {
    try testing.expectEqual(CondCode.eq, legalize.intCCToCondCode(.eq));
    try testing.expectEqual(CondCode.ne, legalize.intCCToCondCode(.ne));
    try testing.expectEqual(CondCode.lt, legalize.intCCToCondCode(.slt));
    try testing.expectEqual(CondCode.ge, legalize.intCCToCondCode(.sge));
    try testing.expectEqual(CondCode.gt, legalize.intCCToCondCode(.sgt));
    try testing.expectEqual(CondCode.le, legalize.intCCToCondCode(.sle));
    try testing.expectEqual(CondCode.cc, legalize.intCCToCondCode(.ult));
    try testing.expectEqual(CondCode.cs, legalize.intCCToCondCode(.uge));
    try testing.expectEqual(CondCode.hi, legalize.intCCToCondCode(.ugt));
    try testing.expectEqual(CondCode.ls, legalize.intCCToCondCode(.ule));
}

test "aarch64 legalize: floatCCToCondCode handles ordered conditions" {
    try testing.expectEqual(CondCode.eq, legalize.floatCCToCondCode(.eq).?);
    try testing.expectEqual(CondCode.ne, legalize.floatCCToCondCode(.ne).?);
    try testing.expectEqual(CondCode.mi, legalize.floatCCToCondCode(.lt).?);
    try testing.expectEqual(CondCode.gt, legalize.floatCCToCondCode(.gt).?);
    try testing.expectEqual(CondCode.vs, legalize.floatCCToCondCode(.uno).?);
    try testing.expectEqual(CondCode.vc, legalize.floatCCToCondCode(.ord).?);
}

test "aarch64 legalize: floatCCToCondCode returns null for unordered variants" {
    try testing.expect(legalize.floatCCToCondCode(.ueq) == null);
    try testing.expect(legalize.floatCCToCondCode(.one) == null);
    try testing.expect(legalize.floatCCToCondCode(.ult) == null);
    try testing.expect(legalize.floatCCToCondCode(.ule) == null);
    try testing.expect(legalize.floatCCToCondCode(.ugt) == null);
    try testing.expect(legalize.floatCCToCondCode(.uge) == null);
}

test "aarch64 legalize: immediate legalization for arithmetic" {
    // Valid 12-bit immediate
    try testing.expect(legalize.isValidArithImm(100));
    try testing.expect(legalize.isValidArithImm(4095));

    // Valid with shift
    try testing.expect(legalize.isValidArithImm(0x123000));

    // Invalid
    try testing.expect(!legalize.isValidArithImm(0x10000));
    try testing.expect(!legalize.isValidArithImm(0xABCDEF));
}

test "aarch64 legalize: load/store offset validation" {
    // Valid offsets for 8-byte access
    try testing.expect(legalize.isValidLoadStoreOffset(0, 8));
    try testing.expect(legalize.isValidLoadStoreOffset(8, 8));
    try testing.expect(legalize.isValidLoadStoreOffset(32760, 8)); // 4095 * 8

    // Invalid offsets
    try testing.expect(!legalize.isValidLoadStoreOffset(-8, 8)); // negative
    try testing.expect(!legalize.isValidLoadStoreOffset(4, 8)); // misaligned
    try testing.expect(!legalize.isValidLoadStoreOffset(32768, 8)); // too large
}

test "aarch64 legalize: indexed offset validation" {
    try testing.expect(legalize.isValidIndexedOffset(0));
    try testing.expect(legalize.isValidIndexedOffset(255));
    try testing.expect(legalize.isValidIndexedOffset(-256));
    try testing.expect(!legalize.isValidIndexedOffset(256));
    try testing.expect(!legalize.isValidIndexedOffset(-257));
}

test "aarch64 legalize: conditional select strategy" {
    const result = legalize.condSelectStrategy(.eq);
    try testing.expect(result == .native);

    const result2 = legalize.condSelectStrategy(.slt);
    try testing.expect(result2 == .native);
}

test "aarch64 legalize: float conditional select expansion" {
    // Ordered conditions use native FCSEL
    const result = legalize.floatCondSelectStrategy(.eq);
    try testing.expect(result == .native);

    // Unordered conditions require expansion
    const result2 = legalize.floatCondSelectStrategy(.ueq);
    try testing.expectEqual(legalize.CondSelectExpansion.expand, result2);
}

test "aarch64 legalize: vector element size checking" {
    // Supported NEON vector types
    try testing.expectEqual(legalize.VectorLegalization.supported, legalize.checkVectorElementSize(Type.I8X16));
    try testing.expectEqual(legalize.VectorLegalization.supported, legalize.checkVectorElementSize(Type.I16X8));
    try testing.expectEqual(legalize.VectorLegalization.supported, legalize.checkVectorElementSize(Type.I32X4));
    try testing.expectEqual(legalize.VectorLegalization.supported, legalize.checkVectorElementSize(Type.I64X2));

    // Scalar types are supported
    try testing.expectEqual(legalize.VectorLegalization.supported, legalize.checkVectorElementSize(Type.I32));
    try testing.expectEqual(legalize.VectorLegalization.supported, legalize.checkVectorElementSize(Type.F64));
}

test "aarch64 legalize: MOV synthesis counting" {
    try testing.expectEqual(@as(u8, 1), legalize.countMovInstructions(0));
    try testing.expectEqual(@as(u8, 1), legalize.countMovInstructions(0x1234));
    try testing.expectEqual(@as(u8, 1), legalize.countMovInstructions(0x56780000));
    try testing.expectEqual(@as(u8, 2), legalize.countMovInstructions(0x12340000ABCD));
    try testing.expectEqual(@as(u8, 4), legalize.countMovInstructions(0x1234567890ABCDEF));
}

test "aarch64 legalize: legalizeArithImm decisions" {
    const result1 = legalize.legalizeArithImm(100);
    try testing.expectEqual(legalize.ImmLegalization.valid, result1);

    const result2 = legalize.legalizeArithImm(0x123456789ABC);
    // Large value should either synthesize or use literal pool
    try testing.expect(result2 == .synthesize_mov or result2 == .literal_pool);
}

test "aarch64 legalize: legalizeOffset decisions" {
    const result1 = legalize.legalizeOffset(64, 8);
    try testing.expectEqual(@as(@TypeOf(result1), .valid), result1);

    const result2 = legalize.legalizeOffset(40000, 8);
    // Large offset requires splitting or materialization
    try testing.expect(result2 == .split_offset or result2 == .materialize_base);
}
