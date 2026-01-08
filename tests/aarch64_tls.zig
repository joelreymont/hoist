const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const compile_mod = @import("hoist").codegen.compile;

// Test TLS Local-Exec model with small offset (<4096 bytes).
// Local-Exec: MRS x0, TPIDR_EL0; ADD x0, x0, #offset
test "TLS: Local-Exec model small offset" {
    // Create function: fn() -> i64
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    const i64_type = Type.I64;
    try sig.returns.append(AbiParam.new(i64_type));

    var func = try Function.init(testing.allocator, "tls_le_small", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Build IR: tls_value with small offset (e.g., 256 bytes)
    const tls_data = InstructionData{
        .unary_imm = .{
            .opcode = .tls_value,
            .imm = Imm64.new(256), // Small offset within 12-bit ADD immediate range
        },
    };
    const tls_inst = try func.dfg.makeInst(tls_data);
    const tls_result = try func.dfg.appendInstResult(tls_inst, i64_type);
    try func.layout.appendInst(tls_inst, entry);

    // Return the TLS address
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = tls_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile - should succeed
    const result = try compile_mod.compileFunction(testing.allocator, &func, .aarch64);
    defer testing.allocator.free(result.code);

    // Verify code was generated (non-empty)
    try testing.expect(result.code.len > 0);

    // TODO: When we have a disassembler, verify:
    // 1. MRS x<reg>, TPIDR_EL0 instruction present
    // 2. ADD x<reg>, x<reg>, #256 instruction present
    // 3. RET instruction present
}

// Test TLS Local-Exec model with large offset (>4095 bytes).
// Large offsets require multi-instruction materialization (MOVZ/MOVK sequence + ADD).
test "TLS: Local-Exec model large offset" {
    // Create function: fn() -> i64
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    const i64_type = Type.I64;
    try sig.returns.append(AbiParam.new(i64_type));

    var func = try Function.init(testing.allocator, "tls_le_large", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Build IR: tls_value with large offset (>4KB, outside 12-bit ADD immediate range)
    const tls_data = InstructionData{
        .unary_imm = .{
            .opcode = .tls_value,
            .imm = Imm64.new(0x10000), // 64KB offset - requires MOVZ+ADD
        },
    };
    const tls_inst = try func.dfg.makeInst(tls_data);
    const tls_result = try func.dfg.appendInstResult(tls_inst, i64_type);
    try func.layout.appendInst(tls_inst, entry);

    // Return the TLS address
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = tls_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile - should succeed
    const result = try compile_mod.compileFunction(testing.allocator, &func, .aarch64);
    defer testing.allocator.free(result.code);

    // Verify code was generated (non-empty)
    try testing.expect(result.code.len > 0);

    // TODO: When we have a disassembler, verify:
    // 1. MRS x<reg>, TPIDR_EL0 instruction present
    // 2. MOVZ x<tmp>, #0x1, LSL #16 (for 0x10000)
    // 3. ADD x<reg>, x<reg>, x<tmp>
    // 4. RET instruction present
}

// Test TLS Local-Exec model with zero offset (thread pointer itself).
test "TLS: Local-Exec model zero offset" {
    // Create function: fn() -> i64
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    const i64_type = Type.I64;
    try sig.returns.append(AbiParam.new(i64_type));

    var func = try Function.init(testing.allocator, "tls_le_zero", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Build IR: tls_value with zero offset (get TPIDR_EL0 directly)
    const tls_data = InstructionData{
        .unary_imm = .{
            .opcode = .tls_value,
            .imm = Imm64.new(0), // Zero offset - just MRS
        },
    };
    const tls_inst = try func.dfg.makeInst(tls_data);
    const tls_result = try func.dfg.appendInstResult(tls_inst, i64_type);
    try func.layout.appendInst(tls_inst, entry);

    // Return the TLS address
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = tls_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile - should succeed
    const result = try compile_mod.compileFunction(testing.allocator, &func, .aarch64);
    defer testing.allocator.free(result.code);

    // Verify code was generated (non-empty)
    try testing.expect(result.code.len > 0);

    // TODO: When we have a disassembler, verify:
    // 1. MRS x<reg>, TPIDR_EL0 instruction present
    // 2. RET instruction present (no ADD needed for zero offset)
}
