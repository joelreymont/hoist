//! Cranelift IR entity references.
//!
//! Instructions in Cranelift IR need to reference other entities in the function. This can be other
//! parts of the function like basic blocks or stack slots, or it can be external entities
//! that are declared in the function preamble in the text format.
//!
//! These entity references in instruction operands are not implemented as pointers because
//! 64-bit pointers take up a lot of space, and we want a compact in-memory representation.
//! Instead, entity references are structs wrapping a u32 index into a table in the Function.
//! There is a separate index type for each entity type, so we don't lose type safety.
//!
//! The entity references all implement format() in a way that matches the textual IR format.

const std = @import("std");
const root = @import("../root.zig");
const entity = root.entity;

/// An opaque reference to a basic block in a Function.
///
/// While the order is stable, it is arbitrary and does not necessarily resemble the layout order.
pub const Block = entity.EntityRef(u32, "block");

/// An opaque reference to an SSA value.
///
/// While the order is stable, it is arbitrary.
pub const Value = entity.EntityRef(u32, "v");

/// An opaque reference to an instruction in a Function.
///
/// While the order is stable, it is arbitrary and does not necessarily resemble the layout order.
pub const Inst = entity.EntityRef(u32, "inst");

/// An opaque reference to a stack slot.
///
/// Stack slots represent an address on the call stack.
///
/// While the order is stable, it is arbitrary and does not necessarily resemble the stack order.
pub const StackSlot = entity.EntityRef(u32, "ss");

/// An opaque reference to a dynamic stack slot.
pub const DynamicStackSlot = entity.EntityRef(u32, "dss");

/// An opaque reference to a dynamic type.
pub const DynamicType = entity.EntityRef(u32, "dt");

/// An opaque reference to a global value.
///
/// A GlobalValue is a Value that will be live across the entire function lifetime.
/// It can be preloaded from other global values.
///
/// While the order is stable, it is arbitrary.
pub const GlobalValue = entity.EntityRef(u32, "gv");

/// An opaque reference to a memory type.
///
/// A MemoryType is a descriptor of a struct layout in memory, with
/// types and proof-carrying-code facts optionally attached to the fields.
pub const MemoryType = entity.EntityRef(u32, "mt");

/// An opaque reference to a constant.
///
/// Constants are stored in a ConstantPool for efficient storage and retrieval.
///
/// While the order is stable, it is arbitrary and does not necessarily resemble the order in which
/// the constants are written in the constant pool.
pub const Constant = entity.EntityRef(u32, "const");

/// An opaque reference to an immediate.
///
/// Some immediates (e.g. SIMD shuffle masks) are too large to store in the
/// InstructionData struct and therefore must be tracked separately in DataFlowGraph.
///
/// While the order is stable, it is arbitrary.
pub const Immediate = entity.EntityRef(u32, "imm");

/// An opaque reference to a function signature.
///
/// Signature references are used to describe the types of arguments and return values for functions.
///
/// While the order is stable, it is arbitrary.
pub const SigRef = entity.EntityRef(u32, "sig");

/// An opaque reference to an external function.
///
/// FuncRef is used to reference external functions that can be called.
///
/// While the order is stable, it is arbitrary.
pub const FuncRef = entity.EntityRef(u32, "fn");

/// An opaque reference to a jump table.
///
/// Jump tables are used to implement multi-way branches efficiently.
///
/// While the order is stable, it is arbitrary.
pub const JumpTable = entity.EntityRef(u32, "jt");

// Tests
const testing = std.testing;

test "Block entity" {
    const b0 = Block.new(0);
    const b1 = Block.new(1);
    try testing.expect(!b0.isValid() or b0.toIndex() == 0);
    try testing.expect(b0.toIndex() != b1.toIndex());
}

test "Value entity" {
    const v0 = Value.new(0);
    const v5 = Value.new(5);
    try testing.expectEqual(@as(usize, 0), v0.toIndex());
    try testing.expectEqual(@as(usize, 5), v5.toIndex());
}

test "Entity invalid sentinel" {
    try testing.expect(!Block.invalid.isValid());
    try testing.expect(!Value.invalid.isValid());
    try testing.expectEqual(std.math.maxInt(u32), Block.invalid.toRaw());
}
