//! ISLE lowering integration tests
//!
//! Tests IR to VCode lowering via ISLE pattern matching:
//! - Pattern matching against IR instructions
//! - Constructor application to emit machine instructions
//! - Extractor evaluation to decompose IR patterns
//! - Lowering context management
//! - Priority-based rule selection
//!
//! Note: Many tests use scaffolding until ISLE compiler is complete.
//! They verify the lowering infrastructure works correctly.
//!
//! Run with: zig build test

const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const WritableReg = root.aarch64_inst.WritableReg;
const PReg = root.reg.PReg;
const VReg = root.reg.VReg;
const RegClass = root.reg.RegClass;
const lower_mod = root.lower;
const vcode_mod = root.vcode;
const ir_mod = root.ir;
const types = root.types;
const aarch64_lower = root.aarch64_lower;
const isle_helpers = root.aarch64_isle_helpers;

// Test basic lowering context setup and teardown
test "LowerCtx: basic initialization and cleanup" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Context should be initialized with no current block
    try testing.expectEqual(@as(?vcode_mod.BlockIndex, null), ctx.current_block);
    try testing.expectEqual(@as(u32, 0), ctx.next_vreg);
}

// Test VReg allocation through lowering context
test "LowerCtx: virtual register allocation" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Allocate different register classes
    const int_vreg = ctx.allocVReg(.int);
    const float_vreg = ctx.allocVReg(.float);
    const vec_vreg = ctx.allocVReg(.vector);

    try testing.expectEqual(RegClass.int, int_vreg.class());
    try testing.expectEqual(RegClass.float, float_vreg.class());
    try testing.expectEqual(RegClass.vector, vec_vreg.class());

    // Should allocate sequentially
    try testing.expectEqual(@as(u32, 0), int_vreg.index());
    try testing.expectEqual(@as(u32, 1), float_vreg.index());
    try testing.expectEqual(@as(u32, 2), vec_vreg.index());
}

// Test value-to-register mapping (SSA value tracking)
test "LowerCtx: SSA value to VReg mapping" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Map IR values to virtual registers
    const v1 = lower_mod.Value.new(0);
    const v2 = lower_mod.Value.new(1);
    const v3 = lower_mod.Value.new(2);

    const r1 = try ctx.getValueReg(v1, .int);
    const r2 = try ctx.getValueReg(v2, .int);
    const r3 = try ctx.getValueReg(v3, .float);

    // Should get unique registers for different values
    try testing.expect(!std.meta.eql(r1, r2));
    try testing.expect(!std.meta.eql(r1, r3));
    try testing.expect(!std.meta.eql(r2, r3));

    // Same value should return same register
    const r1_again = try ctx.getValueReg(v1, .int);
    try testing.expectEqual(r1, r1_again);
}

// Test block creation and management
test "LowerCtx: block creation and current block tracking" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const ir_block = lower_mod.Block.new(0);
    const vcode_block = try ctx.startBlock(ir_block);

    try testing.expectEqual(@as(vcode_mod.BlockIndex, 0), vcode_block);
    try testing.expectEqual(@as(?vcode_mod.BlockIndex, 0), ctx.current_block);

    ctx.endBlock();
    try testing.expectEqual(@as(?vcode_mod.BlockIndex, null), ctx.current_block);
}

// Test instruction emission through context
test "LowerCtx: instruction emission to current block" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const ir_block = lower_mod.Block.new(0);
    const vcode_block = try ctx.startBlock(ir_block);

    // Emit some instructions
    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x0_w = WritableReg.fromReg(x0);

    try ctx.emit(Inst{
        .add_imm = .{
            .dst = x0_w,
            .src = x1,
            .imm = 42,
            .size = .size64,
        },
    });

    try ctx.emit(Inst{ .ret = {} });

    try vcode.finishBlock(vcode_block, &.{});

    // Should have 2 instructions in block
    const block = vcode.getBlock(vcode_block);
    try testing.expectEqual(@as(usize, 2), block.insnCount());

    ctx.endBlock();
}

// Test error when emitting without current block
test "LowerCtx: emit fails without current block" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Try to emit without starting a block
    const result = ctx.emit(Inst{ .ret = {} });

    try testing.expectError(error.NoCurrentBlock, result);
}

// Test pattern matching infrastructure (scaffolding)
test "ISLE patterns: immediate extractor" {
    // When ISLE works, this will test:
    // (extractor imm12_from_u64 (value: u64) (imm: Imm12)
    //   (if (< value 4096)
    //     (some (Imm12.new value))
    //     (none)))

    // Valid 12-bit immediate
    const imm1 = isle_helpers.imm12_from_u64(100);
    try testing.expect(imm1 != null);
    try testing.expectEqual(@as(u16, 100), imm1.?.bits);

    // Invalid - too large
    const imm2 = isle_helpers.imm12_from_u64(5000);
    try testing.expectEqual(@as(@TypeOf(imm2), null), imm2);

    // Boundary - maximum 12-bit value
    const imm3 = isle_helpers.imm12_from_u64(4095);
    try testing.expect(imm3 != null);

    // Boundary - one over maximum
    const imm4 = isle_helpers.imm12_from_u64(4096);
    try testing.expectEqual(@as(@TypeOf(imm4), null), imm4);
}

// Test constructor application (scaffolding)
test "ISLE constructors: register allocation" {
    // When ISLE works, this will test:
    // (constructor add_rr (dst: Reg) (src1: Reg) (src2: Reg) (size: Size)
    //   (emit (Inst.add_rr dst src1 src2 size)))

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const ir_block = lower_mod.Block.new(0);
    _ = try ctx.startBlock(ir_block);

    // Simulate ISLE constructor allocating output register
    const out_reg = aarch64_lower.allocOutputReg(&ctx, .int);

    try testing.expectEqual(RegClass.int, out_reg.toReg().class());

    ctx.endBlock();
}

// Test extractor evaluation (scaffolding)
test "ISLE extractors: value decomposition" {
    // When ISLE works, this will test:
    // (extractor extended_value (value: Value) (ev: ExtendedValue)
    //   (match (def value)
    //     ((sload8 addr) (some (ExtendedValue reg:addr op:sxtb)))
    //     (_ (none))))

    // Test extractor helpers exist
    _ = isle_helpers.imm12_from_u64;
    _ = isle_helpers.imm_shift_from_u64;
    _ = isle_helpers.u8_into_imm12;

    // ExtendedValue type should exist for pattern matching
    const ExtendedValue = isle_helpers.ExtendedValue;
    _ = ExtendedValue;
}

// Test lowering backend trait
test "ISLE lowering: backend trait implementation" {
    const backend = aarch64_lower.Aarch64Lower.backend();

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Backend should have lowering functions
    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);

    // Try lowering an instruction (will return false until ISLE works)
    const ir_inst = lower_mod.Inst.new(0);
    const handled = try backend.lowerInstFn(&ctx, ir_inst);

    // Currently returns false (not handled) - will be true when ISLE works
    try testing.expectEqual(false, handled);
}

// Test full function lowering pipeline
test "ISLE lowering: complete function lowering" {
    const backend = aarch64_lower.Aarch64Lower.backend();

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    // When ISLE works, this will lower a complete IR function
    var result = try lower_mod.lowerFunction(Inst, testing.allocator, &func, backend);
    defer result.deinit();

    // Empty function should produce empty VCode
    try testing.expectEqual(@as(usize, 0), result.numBlocks());
}

// Test type-based lowering
test "ISLE lowering: type-dependent patterns" {
    // Type mapping for different sizes
    const i32_size = aarch64_lower.typeToSize(types.Type.I32);
    const i64_size = aarch64_lower.typeToSize(types.Type.I64);

    try testing.expectEqual(@as(@TypeOf(i32_size), .size32), i32_size);
    try testing.expectEqual(@as(@TypeOf(i64_size), .size64), i64_size);

    // Floating-point types
    const f32_size = aarch64_lower.typeToSize(types.Type.F32);
    const f64_size = aarch64_lower.typeToSize(types.Type.F64);

    try testing.expectEqual(@as(@TypeOf(f32_size), .size32), f32_size);
    try testing.expectEqual(@as(@TypeOf(f64_size), .size64), f64_size);
}

// Test VReg renaming for SSA construction
test "ISLE lowering: VReg renaming" {
    var rename_map = vcode_mod.VRegRenameMap.init(testing.allocator);
    defer rename_map.deinit();

    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);

    // Rename v1 to v2
    try rename_map.addRename(v1, v2);

    try testing.expect(rename_map.isRenamed(v1));
    try testing.expect(!rename_map.isRenamed(v2));

    const renamed = rename_map.getRename(v1);
    try testing.expectEqual(v2, renamed);

    // Unrenamed value returns itself
    const v3 = VReg.new(3, .int);
    const not_renamed = rename_map.getRename(v3);
    try testing.expectEqual(v3, not_renamed);
}
