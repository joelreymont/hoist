const std = @import("std");
const hoist = @import("hoist");
const legalize_ops = hoist.legalize_ops;
const Type = hoist.types.Type;
const Opcode = hoist.opcodes.Opcode;

test "legalize_ops module loads" {
    const legalizer = legalize_ops.OpLegalizer.default64();
    _ = legalizer;
}

test "OpLegalizer configs" {
    const default = legalize_ops.OpLegalizer.default64();
    try std.testing.expect(default.has_idiv);

    const aarch64 = legalize_ops.OpLegalizer.aarch64();
    try std.testing.expect(!aarch64.has_irem);

    const riscv = legalize_ops.OpLegalizer.riscv64_minimal();
    try std.testing.expect(!riscv.has_idiv);
}

test "power of two detection" {
    try std.testing.expect(legalize_ops.isPowerOfTwo(8));
    try std.testing.expect(!legalize_ops.isPowerOfTwo(7));
}

test "division optimization" {
    const opt = legalize_ops.analyzeDivision(Type.I32, 8, false);
    try std.testing.expectEqual(legalize_ops.DivOptimization.shift_right, opt);
}

test "remainder optimization" {
    const opt = legalize_ops.analyzeRemainder(Type.I32, 16, false);
    try std.testing.expectEqual(legalize_ops.RemOptimization.mask, opt);
}

test "expand udiv pow2" {
    const exp = legalize_ops.expandUdivPow2(8);
    try std.testing.expect(exp != null);
    try std.testing.expectEqual(@as(u6, 3), exp.?.shift_amount);
}

test "expand urem pow2" {
    const exp = legalize_ops.expandUremPow2(16);
    try std.testing.expect(exp != null);
    try std.testing.expectEqual(@as(u64, 15), exp.?.mask_value);
}

test "libcall info" {
    const call = legalize_ops.getLibCall(.fdiv, Type.F32, std.testing.allocator);
    try std.testing.expect(call != null);
    try std.testing.expectEqualStrings("__divsf3", call.?.name);
}
