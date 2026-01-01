//! Cranelift IR instruction formats.
//!
//! Every opcode has a corresponding instruction format which describes
//! the layout of operands (values, immediates, blocks).
//!
//! Ported from cranelift-codegen generated opcodes.rs.

const std = @import("std");

/// Instruction format.
///
/// Describes the operand layout for an instruction:
/// - How many value operands
/// - How many block operands
/// - What immediate operands
pub const InstructionFormat = enum(u8) {
    atomic_cas,
    atomic_rmw,
    binary,
    binary_imm64,
    binary_imm8,
    branch_table,
    brif,
    call,
    call_indirect,
    cond_trap,
    dynamic_stack_load,
    dynamic_stack_store,
    exception_handler_address,
    float_compare,
    func_addr,
    int_add_trap,
    int_compare,
    int_compare_imm,
    jump,
    load,
    load_no_offset,
    multi_ary,
    null_ary,
    shuffle,
    stack_load,
    stack_store,
    store,
    store_no_offset,
    ternary,
    ternary_imm8,
    trap,
    try_call,
    try_call_indirect,
    unary,
    unary_const,
    unary_global_value,
    unary_ieee16,
    unary_ieee32,
    unary_ieee64,
    unary_imm,
};

// Tests
const testing = std.testing;

test "InstructionFormat basic" {
    const fmt = InstructionFormat.binary;
    try testing.expect(fmt == .binary);
}

test "InstructionFormat count" {
    const count = @typeInfo(InstructionFormat).@"enum".fields.len;
    try testing.expectEqual(@as(usize, 40), count);
}
