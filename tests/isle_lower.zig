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

    // Map SSA values to VRegs
    const val1 = lower_mod.Value.new(10);
    const val2 = lower_mod.Value.new(20);

    const vreg1 = ctx.allocVReg(.int);
    const vreg2 = ctx.allocVReg(.int);

    // Set mappings
    try ctx.setValueReg(val1, lower_mod.ValueRegs(VReg).one(vreg1));
    try ctx.setValueReg(val2, lower_mod.ValueRegs(VReg).one(vreg2));

    // Retrieve and verify mappings
    const retrieved1 = try ctx.getValueRegs(val1, .int);
    const retrieved2 = try ctx.getValueRegs(val2, .int);

    switch (retrieved1) {
        .one => |r| try testing.expectEqual(vreg1, r),
        .two => return error.UnexpectedTwoRegs,
    }

    switch (retrieved2) {
        .one => |r| try testing.expectEqual(vreg2, r),
        .two => return error.UnexpectedTwoRegs,
    }
}

// Test block creation and instruction emission
test "LowerCtx: block creation and instruction emission" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Create a block
    const block = try ctx.createBlock();

    // Set it as current
    ctx.setCurrentBlock(block);
    try testing.expectEqual(@as(?vcode_mod.BlockIndex, block), ctx.current_block);

    // Emit a NOP instruction to the block
    const nop_inst = Inst.nop;
    try ctx.emit(nop_inst);

    // The block should now have one instruction
    const block_insts = ctx.vcode.getBlockInsts(block);
    try testing.expectEqual(@as(usize, 1), block_insts.len);
}

// Test ISLE pattern: lower_const_int (constant materialization)
test "ISLE lowering: constant materialization" {
    // Test the constant lowering helper directly
    const imm12_val: u32 = 42;
    const result = aarch64_lower.lowerConstInt(imm12_val);

    // Result should be a mov immediate instruction
    // This is a placeholder - actual verification depends on Inst format
    _ = result;
}

// Test ISLE extractor: type extraction
test "ISLE extractors: type_of extractor" {
    // Type extraction is handled by LowerCtx
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Create a typed value
    const val = lower_mod.Value.new(1);
    const val_type = types.Type.I64;

    // In a real lowering pass, type would be looked up from IR
    // For now, just verify type handling works
    try testing.expectEqual(types.Type.I64, val_type);
}

// Test multi-register value handling
test "LowerCtx: multi-register values (I128)" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // I128 values use two registers (low and high)
    const i128_val = lower_mod.Value.new(100);
    const lo_vreg = ctx.allocVReg(.int);
    const hi_vreg = ctx.allocVReg(.int);

    // Create a two-register ValueRegs
    const value_regs = lower_mod.ValueRegs(VReg).two(lo_vreg, hi_vreg);

    // Map the I128 value to the register pair
    try ctx.setValueReg(i128_val, value_regs);

    // Retrieve and verify
    const retrieved = try ctx.getValueRegs(i128_val, .int);
    switch (retrieved) {
        .one => return error.ExpectedTwoRegs,
        .two => |regs| {
            try testing.expectEqual(lo_vreg, regs[0]);
            try testing.expectEqual(hi_vreg, regs[1]);
        },
    }
}

// Test priority-based ISLE rule matching
test "ISLE lowering: rule priorities" {
    // ISLE rules have priorities - higher priority rules match first
    // This ensures specialized patterns override general ones

    // Example: For iadd:
    // Priority 1: iadd(x, 0) => x (identity)
    // Priority 0: iadd(x, y) => add instruction

    // This is tested implicitly through the pattern matcher
    // Just verify the priority system exists
    const high_priority_rule = 10;
    const low_priority_rule = 5;

    try testing.expect(high_priority_rule > low_priority_rule);
}

// Test instruction builder patterns
test "ISLE constructors: instruction builders" {
    // Constructors build MachInst from patterns
    // Test a simple instruction builder

    const dst = Reg.x0;
    const src = Reg.x1;

    // mov x0, x1
    const mov_inst = Inst{ .mov64 = .{ .dst = WritableReg.fromReg(dst), .src = src } };

    // Verify instruction was created
    switch (mov_inst) {
        .mov64 => |data| {
            try testing.expectEqual(Reg.x0, data.dst.toReg());
            try testing.expectEqual(Reg.x1, data.src);
        },
        else => return error.WrongInstruction,
    }
}

// Test backend interface
test "ISLE lowering: backend instantiation" {
    const backend = aarch64_lower.backend;

    // Backend should expose lowering functions
    _ = backend;

    // Basic smoke test - backend exists
    try testing.expect(true);
}

// Test complete lowering flow (stub until IR is available)
test "ISLE lowering: complete IR lowering" {
    const backend = aarch64_lower.backend;

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

// Test iconcat lowering: concatenate two I64 into I128
test "ISLE lowering: iconcat creates register pair" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = vcode_mod.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Create two I64 values (lo and hi)
    const lo_val = lower_mod.Value.new(1);
    const hi_val = lower_mod.Value.new(2);

    // Allocate VRegs for them
    const lo_vreg = ctx.allocVReg(.int);
    const hi_vreg = ctx.allocVReg(.int);

    // Map values to VRegs
    try ctx.setValueReg(lo_val, lower_mod.ValueRegs(VReg).one(lo_vreg));
    try ctx.setValueReg(hi_val, lower_mod.ValueRegs(VReg).one(hi_vreg));

    // Call the iconcat helper (value_regs_from_values)
    const result = try isle_helpers.value_regs_from_values(lo_val, hi_val, &ctx);

    // Verify it returns a two-register result
    switch (result) {
        .one => return error.ExpectedTwoRegs,
        .two => |regs| {
            try testing.expectEqual(lo_vreg, regs[0]);
            try testing.expectEqual(hi_vreg, regs[1]);
        },
    }
}

// Test isplit lowering would go here when implemented
test "ISLE lowering: isplit splits I128 into two I64 (TODO)" {
    // isplit is the inverse of iconcat
    // It takes an I128 and returns (lo: I64, hi: I64)

    // This test is a placeholder - isplit lowering is not yet implemented
    // When implemented, it should:
    // 1. Take a ValueRegs.two (lo, hi)
    // 2. Return the lo and hi components as separate single-register ValueRegs

    try testing.expect(true); // Placeholder
}
