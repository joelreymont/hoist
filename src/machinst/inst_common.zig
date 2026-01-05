//! MachInst fragments common across multiple architectures.
//!
//! Ported from cranelift-codegen machinst/inst_common.rs.
//! Provides type-safe identifiers for instruction inputs and outputs.

const IRInst = @import("../ir/entities.zig").Inst;

/// Identifier for a particular input of an instruction.
pub const InsnInput = struct {
    insn: IRInst,
    input: usize,
};
