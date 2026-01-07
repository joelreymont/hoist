//! Unit tests for instruction predicates.

const std = @import("std");
const testing = std.testing;
const predicates = @import("inst_predicates.zig");
const Opcode = @import("opcodes.zig").Opcode;

test "triviallyHasSideEffects: pure arithmetic ops" {
    // Pure arithmetic should not have side effects
    try testing.expect(!predicates.triviallyHasSideEffects(.iadd));
    try testing.expect(!predicates.triviallyHasSideEffects(.isub));
    try testing.expect(!predicates.triviallyHasSideEffects(.imul));
    try testing.expect(!predicates.triviallyHasSideEffects(.udiv));
    try testing.expect(!predicates.triviallyHasSideEffects(.sdiv));
}

test "triviallyHasSideEffects: bitwise ops" {
    // Bitwise ops should not have side effects
    try testing.expect(!predicates.triviallyHasSideEffects(.band));
    try testing.expect(!predicates.triviallyHasSideEffects(.bor));
    try testing.expect(!predicates.triviallyHasSideEffects(.bxor));
    try testing.expect(!predicates.triviallyHasSideEffects(.bnot));
}

test "triviallyHasSideEffects: shift ops" {
    // Shift ops should not have side effects
    try testing.expect(!predicates.triviallyHasSideEffects(.ishl));
    try testing.expect(!predicates.triviallyHasSideEffects(.ushr));
    try testing.expect(!predicates.triviallyHasSideEffects(.sshr));
    try testing.expect(!predicates.triviallyHasSideEffects(.rotl));
    try testing.expect(!predicates.triviallyHasSideEffects(.rotr));
}

test "triviallyHasSideEffects: comparison ops" {
    // Comparisons should not have side effects
    try testing.expect(!predicates.triviallyHasSideEffects(.icmp));
    try testing.expect(!predicates.triviallyHasSideEffects(.fcmp));
}

test "triviallyHasSideEffects: constant loading" {
    // Loading constants should not have side effects
    try testing.expect(!predicates.triviallyHasSideEffects(.iconst));
    try testing.expect(!predicates.triviallyHasSideEffects(.f32const));
    try testing.expect(!predicates.triviallyHasSideEffects(.f64const));
    try testing.expect(!predicates.triviallyHasSideEffects(.vconst));
}

test "triviallyHasSideEffects: calls have side effects" {
    // Calls should have side effects
    try testing.expect(predicates.triviallyHasSideEffects(.call));
    try testing.expect(predicates.triviallyHasSideEffects(.call_indirect));
    try testing.expect(predicates.triviallyHasSideEffects(.return_call));
    try testing.expect(predicates.triviallyHasSideEffects(.return_call_indirect));
    try testing.expect(predicates.triviallyHasSideEffects(.try_call));
    try testing.expect(predicates.triviallyHasSideEffects(.try_call_indirect));
}

test "triviallyHasSideEffects: branches have side effects" {
    // Branches should have side effects
    try testing.expect(predicates.triviallyHasSideEffects(.jump));
    try testing.expect(predicates.triviallyHasSideEffects(.brif));
    try testing.expect(predicates.triviallyHasSideEffects(.br_table));
}

test "triviallyHasSideEffects: returns have side effects" {
    // Returns should have side effects
    try testing.expect(predicates.triviallyHasSideEffects(.@"return"));
    try testing.expect(predicates.triviallyHasSideEffects(.return_call));
    try testing.expect(predicates.triviallyHasSideEffects(.return_call_indirect));
}

test "triviallyHasSideEffects: stores have side effects" {
    // Stores should have side effects
    try testing.expect(predicates.triviallyHasSideEffects(.store));
    try testing.expect(predicates.triviallyHasSideEffects(.istore8));
    try testing.expect(predicates.triviallyHasSideEffects(.istore16));
    try testing.expect(predicates.triviallyHasSideEffects(.istore32));
}

test "triviallyHasSideEffects: atomic ops have side effects" {
    // Atomic operations should have side effects
    try testing.expect(predicates.triviallyHasSideEffects(.atomic_rmw));
    try testing.expect(predicates.triviallyHasSideEffects(.atomic_cas));
    try testing.expect(predicates.triviallyHasSideEffects(.atomic_load));
    try testing.expect(predicates.triviallyHasSideEffects(.atomic_store));
    try testing.expect(predicates.triviallyHasSideEffects(.fence));
}

test "triviallyHasSideEffects: trapping ops have side effects" {
    // Operations that can trap should have side effects
    try testing.expect(predicates.triviallyHasSideEffects(.trap));
    try testing.expect(predicates.triviallyHasSideEffects(.debugtrap));
}

test "triviallyHasSideEffects: conversion ops" {
    // Conversions should not have side effects (non-trapping)
    try testing.expect(!predicates.triviallyHasSideEffects(.sextend));
    try testing.expect(!predicates.triviallyHasSideEffects(.uextend));
    try testing.expect(!predicates.triviallyHasSideEffects(.ireduce));
    try testing.expect(!predicates.triviallyHasSideEffects(.bitcast));
}

test "triviallyHasSideEffects: vector ops" {
    // Vector ops should not have side effects
    try testing.expect(!predicates.triviallyHasSideEffects(.vconst));
    try testing.expect(!predicates.triviallyHasSideEffects(.splat));
    try testing.expect(!predicates.triviallyHasSideEffects(.extractlane));
    try testing.expect(!predicates.triviallyHasSideEffects(.insertlane));
}

test "triviallyHasSideEffects: select is pure" {
    // Select should not have side effects
    try testing.expect(!predicates.triviallyHasSideEffects(.select));
    try testing.expect(!predicates.triviallyHasSideEffects(.selectif));
}

test "triviallyHasSideEffects: stack operations" {
    // Stack slot operations should not trivially have side effects
    // (though stack_load/stack_store may have them via other checks)
    try testing.expect(!predicates.triviallyHasSideEffects(.stack_addr));
}

test "triviallyHasSideEffects: float arithmetic" {
    // Float arithmetic should not have side effects (non-trapping)
    try testing.expect(!predicates.triviallyHasSideEffects(.fadd));
    try testing.expect(!predicates.triviallyHasSideEffects(.fsub));
    try testing.expect(!predicates.triviallyHasSideEffects(.fmul));
    try testing.expect(!predicates.triviallyHasSideEffects(.fdiv));
    try testing.expect(!predicates.triviallyHasSideEffects(.fmin));
    try testing.expect(!predicates.triviallyHasSideEffects(.fmax));
    try testing.expect(!predicates.triviallyHasSideEffects(.sqrt));
    try testing.expect(!predicates.triviallyHasSideEffects(.fneg));
    try testing.expect(!predicates.triviallyHasSideEffects(.fabs));
}

test "triviallyHasSideEffects: safepoint has side effects" {
    // Safepoints should have side effects
    try testing.expect(predicates.triviallyHasSideEffects(.safepoint));
}

test "triviallyHasSideEffects: null check can trap" {
    // Null checks can trap
    try testing.expect(predicates.triviallyHasSideEffects(.null_check));
}
