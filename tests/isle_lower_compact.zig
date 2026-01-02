//! ISLE lowering integration tests - compact version for build system
//!
//! Tests basic ISLE lowering infrastructure. Full test suite in isle_lower.zig
//! can be run standalone when ISLE compiler is complete.

const std = @import("std");
const testing = std.testing;

const root = @import("root");

test "ISLE: LowerCtx initialization" {
    const Inst = root.aarch64_inst.Inst;
    const lower_mod = root.lower;
    const vcode_mod = root.vcode;

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    try testing.expectEqual(@as(?vcode_mod.BlockIndex, null), ctx.current_block);
}

test "ISLE: immediate extractors" {
    const isle_helpers = root.aarch64_isle_helpers;

    const valid = isle_helpers.imm12_from_u64(100);
    try testing.expect(valid != null);

    const invalid = isle_helpers.imm12_from_u64(5000);
    try testing.expect(invalid == null);
}

test "ISLE: backend trait" {
    const aarch64_lower = root.aarch64_lower;
    const backend = aarch64_lower.Aarch64Lower.backend();

    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);
}
