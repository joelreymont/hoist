//! Cranelift IR instruction opcodes.
//!
//! Ported from cranelift-codegen generated opcodes.rs.
//! Defines the Opcode enum with ~150 instruction variants.

const std = @import("std");

/// Instruction opcode.
pub const Opcode = enum(u16) {
    jump = 1,
    brif,
    br_table,
    brz,
    brnz,
    debugtrap,
    trap,
    trapz,
    trapnz,
    @"return",
    call,
    call_indirect,
    return_call,
    return_call_indirect,
    func_addr,
    try_call,
    try_call_indirect,
    splat,
    swizzle,
    x86_pshufb,
    insertlane,
    extractlane,
    smin,
    umin,
    smax,
    umax,
    avg_round,
    uadd_sat,
    sadd_sat,
    usub_sat,
    ssub_sat,
    load,
    store,
    uload8,
    sload8,
    istore8,
    uload16,
    sload16,
    istore16,
    uload32,
    sload32,
    istore32,
    stack_switch,
    uload8x8,
    sload8x8,
    uload16x4,
    sload16x4,
    uload32x2,
    sload32x2,
    stack_load,
    stack_store,
    stack_addr,
    dynamic_stack_load,
    dynamic_stack_store,
    dynamic_stack_addr,
    global_value,
    symbol_value,
    tls_value,
    get_pinned_reg,
    set_pinned_reg,
    get_frame_pointer,
    get_stack_pointer,
    get_return_address,
    get_exception_handler_address,
    landingpad,
    iconst,
    f16const,
    f32const,
    f64const,
    f128const,
    vconst,
    shuffle,
    nop,
    select,
    select_spectre_guard,
    bitselect,
    x86_blendv,
    vany_true,
    vall_true,
    vhigh_bits,
    icmp,
    icmp_imm,
    iadd,
    isub,
    ineg,
    iabs,
    imul,
    umulhi,
    smulhi,
    sqmul_round_sat,
    x86_pmulhrsw,
    udiv,
    sdiv,
    urem,
    srem,
    iadd_imm,
    imul_imm,
    udiv_imm,
    sdiv_imm,
    urem_imm,
    srem_imm,
    irsub_imm,
    sadd_overflow_cin,
    uadd_overflow_cin,
    uadd_overflow,
    sadd_overflow,
    usub_overflow,
    ssub_overflow,
    umul_overflow,
    smul_overflow,
    uadd_overflow_trap,
    usub_overflow_trap,
    umul_overflow_trap,
    sadd_overflow_trap,
    ssub_overflow_trap,
    smul_overflow_trap,
    ssub_overflow_bin,
    usub_overflow_bin,
    band,
    bor,
    bxor,
    bnot,
    band_not,
    bor_not,
    bxor_not,
    band_imm,
    bor_imm,
    bxor_imm,
    rotl,
    rotr,
    rotl_imm,
    rotr_imm,
    ishl,
    ushr,
    sshr,
    ishl_imm,
    ushr_imm,
    sshr_imm,
    bitrev,
    clz,
    cls,
    ctz,
    bswap,
    popcnt,
    fcmp,
    fadd,
    fsub,
    fmul,
    fdiv,
    sqrt,
    fma,
    fneg,
    fabs,
    fcopysign,
    fmin,
    fmax,
    // Type conversions - integer
    sextend,
    uextend,
    ireduce,
    iconcat,
    isplit,
    // Type conversions - float to int
    fcvt_from_sint,
    fcvt_from_uint,
    fcvt_to_sint,
    fcvt_to_sint_sat,
    fcvt_to_uint,
    fcvt_to_uint_sat,
    // Type conversions - float width
    fpromote,
    fdemote,
    // Atomic operations
    atomic_load,
    atomic_store,
    atomic_rmw,
    atomic_cas,
    fence,
    // SIMD vector operations - widening
    swiden_low,
    swiden_high,
    uwiden_low,
    uwiden_high,
    // SIMD vector operations - narrowing
    snarrow,
    unarrow,
    uunarrow,
    // SIMD vector operations - lane manipulation
    scalar_to_vector,
    extract_vector,
    iadd_pairwise,
    // SIMD vector operations - float
    fvpromote_low,
    fvdemote,
    // Float rounding operations
    ceil,
    floor,
    trunc,
    nearest,

    /// Returns true if this is a call instruction.
    pub fn is_call(self: Opcode) bool {
        return switch (self) {
            .call, .call_indirect, .return_call, .return_call_indirect, .try_call, .try_call_indirect => true,
            else => false,
        };
    }

    /// Returns true if this is a branch instruction.
    pub fn is_branch(self: Opcode) bool {
        return switch (self) {
            .brif, .br_table => true,
            else => false,
        };
    }

    /// Returns true if this is a terminator instruction (ends a basic block).
    pub fn is_terminator(self: Opcode) bool {
        return switch (self) {
            .jump,
            .brif,
            .br_table,
            .brz,
            .brnz,
            .@"return",
            .return_call,
            .return_call_indirect,
            .trap,
            .trapz,
            .trapnz,
            => true,
            else => false,
        };
    }

    /// Returns true if this is a return instruction.
    pub fn is_return(self: Opcode) bool {
        return switch (self) {
            .@"return", .return_call, .return_call_indirect => true,
            else => false,
        };
    }

    /// Returns true if this instruction can trap.
    pub fn can_trap(self: Opcode) bool {
        return switch (self) {
            .trap,
            .trapz,
            .trapnz,
            .debugtrap,
            .udiv,
            .sdiv,
            .urem,
            .srem,
            .load,
            .uload8,
            .sload8,
            .uload16,
            .sload16,
            .uload32,
            .sload32,
            .uadd_overflow_trap,
            .usub_overflow_trap,
            .umul_overflow_trap,
            .sadd_overflow_trap,
            .ssub_overflow_trap,
            .smul_overflow_trap,
            => true,
            else => false,
        };
    }

    /// Returns true if this instruction can store to memory.
    pub fn can_store(self: Opcode) bool {
        return switch (self) {
            .store,
            .istore8,
            .istore16,
            .istore32,
            .stack_store,
            .dynamic_stack_store,
            => true,
            else => false,
        };
    }

    /// Returns true if this instruction can load from memory.
    pub fn can_load(self: Opcode) bool {
        return switch (self) {
            .load,
            .uload8,
            .sload8,
            .uload16,
            .sload16,
            .uload32,
            .sload32,
            .uload8x8,
            .sload8x8,
            .uload16x4,
            .sload16x4,
            .uload32x2,
            .sload32x2,
            .stack_load,
            .dynamic_stack_load,
            => true,
            else => false,
        };
    }

    /// Returns true if this instruction has other side effects (besides trap/call/branch/load/store).
    pub fn other_side_effects(self: Opcode) bool {
        return switch (self) {
            .set_pinned_reg,
            .stack_switch,
            => true,
            else => false,
        };
    }
};

// Tests
const testing = std.testing;

test "Opcode basic" {
    try testing.expectEqual(@as(u16, 1), @intFromEnum(Opcode.jump));
    try testing.expectEqual(@as(u16, 2), @intFromEnum(Opcode.brif));
}

test "Opcode count" {
    const count = @typeInfo(Opcode).@"enum".fields.len;
    try testing.expect(count > 100);
    try testing.expect(count < 200);
}
