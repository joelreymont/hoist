//! Instruction predicates/properties, shared by various analyses.
//!
//! Ported from cranelift-codegen inst_predicates.rs.
//! Provides query functions for instruction properties used in optimization passes.

const std = @import("std");
const Function = @import("function.zig").Function;
const entities = @import("entities.zig");
const Inst = entities.Inst;
const Value = entities.Value;
const Opcode = @import("opcodes.zig").Opcode;
const InstructionData = @import("instruction_data.zig").InstructionData;
const Type = @import("types.zig").Type;

/// Test whether the given opcode is unsafe to even consider as side-effect-free.
pub inline fn triviallyHasSideEffects(opcode: Opcode) bool {
    return opcode.is_call() or
        opcode.is_branch() or
        opcode.is_terminator() or
        opcode.is_return() or
        opcode.can_trap() or
        opcode.other_side_effects() or
        opcode.can_store();
}

/// Load instructions without the `notrap` flag are defined to trap when
/// operating on inaccessible memory, so we can't treat them as side-effect-free
/// even if the loaded value is unused.
pub inline fn isLoadWithDefinedTrapping(opcode: Opcode, data: *const InstructionData) bool {
    if (!opcode.can_load()) return false;

    return switch (data.*) {
        // Stack loads never trap
        .load => |load_data| blk: {
            // TODO: Check flags.notrap() when MemFlags are implemented
            _ = load_data;
            break :blk true;
        },
        else => true,
    };
}

/// Does the given instruction have any side-effect that would preclude it from
/// being removed when its value is unused?
pub inline fn hasSideEffect(func: *const Function, inst: Inst) bool {
    const data = func.dfg.insts.get(inst) orelse return false;
    const opcode = data.opcode();
    return triviallyHasSideEffects(opcode) or isLoadWithDefinedTrapping(opcode, data);
}

/// Does the given instruction behave as a "pure" node with respect to
/// egraph semantics?
///
/// - Trivially pure nodes (bitwise arithmetic, etc)
/// - Loads with the `readonly`, `notrap`, and `can_move` flags set
pub fn isPureForEgraph(func: *const Function, inst: Inst) bool {
    const inst_data = func.dfg.insts.get(inst) orelse return false;

    // Check if this is a pure load
    const is_pure_load = switch (inst_data.*) {
        .load => |load_data| blk: {
            if (load_data.opcode != .load) break :blk false;
            // TODO: Check flags.readonly() && flags.notrap() && flags.can_move()
            // when MemFlags are implemented
            _ = load_data;
            break :blk false;
        },
        else => false,
    };

    // Multi-value results do not play nicely with much of the egraph
    // infrastructure. They are in practice used only for multi-return
    // calls and some other odd instructions (e.g. uadd_overflow) which,
    // for now, we can afford to leave in place as opaque
    // side-effecting ops. So if more than one result, then the inst
    // is "not pure". Similarly, ops with zero results can be used
    // only for their side-effects, so are never pure.
    const results = func.dfg.instResults(inst);
    const has_one_result = results.len == 1;

    const op = inst_data.opcode();

    return has_one_result and (is_pure_load or (!op.can_load() and !triviallyHasSideEffects(op)));
}

/// Can the given instruction be merged into another copy of itself?
/// These instructions may have side-effects, but as long as we retain
/// the first instance of the instruction, the second and further
/// instances are redundant if they would produce the same trap or result.
pub fn isMergeableForEgraph(func: *const Function, inst: Inst) bool {
    const inst_data = func.dfg.insts.get(inst) orelse return false;
    const op = inst_data.opcode();

    // We can only merge zero- and one-result operators due to the way that GVN
    // is structured in the egraph implementation.
    const results = func.dfg.instResults(inst);
    if (results.len > 1) return false;

    // Loads/stores are handled by alias analysis and not otherwise mergeable.
    if (op.can_load() or op.can_store()) return false;

    // Can only have idempotent side-effects.
    // TODO: Add op.side_effects_idempotent() when implemented
    if (hasSideEffect(func, inst)) return false;

    return true;
}

/// Does the given instruction have any side-effect as per hasSideEffect,
/// or else is a load, but not the get_pinned_reg opcode?
pub fn hasLoweringSideEffect(func: *const Function, inst: Inst) bool {
    const inst_data = func.dfg.insts.get(inst) orelse return false;
    const op = inst_data.opcode();

    if (op == .get_pinned_reg) return false;

    return hasSideEffect(func, inst) or op.can_load();
}

/// Is the given instruction a constant value (`iconst`, `fconst`) that can be
/// represented in 64 bits?
pub fn isConstant64bit(func: *const Function, inst: Inst) ?u64 {
    const inst_data = func.dfg.insts.get(inst) orelse return null;

    return switch (inst_data.*) {
        .unary_imm => |data| @bitCast(@as(i64, data.imm.value)),
        // TODO: Add UnaryIeee16, UnaryIeee32, UnaryIeee64 when implemented
        else => null,
    };
}

/// Determine whether this opcode behaves as a memory fence, i.e.,
/// prohibits any moving of memory accesses across it.
pub fn hasMemoryFenceSemantics(op: Opcode) bool {
    return switch (op) {
        .fence,
        .debugtrap,
        .call,
        .call_indirect,
        .try_call,
        .try_call_indirect,
        => true,
        else => op.can_trap(),
    };
}
