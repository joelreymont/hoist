//! Hoist IR entity references.
//!
//! Instructions in Hoist IR need to reference other entities in the function. This can be other
//! parts of the function like basic blocks or stack slots, or it can be external entities
//! that are declared in the function preamble in the text format.
//!
//! These entity references in instruction operands are not implemented as Zig pointers both
//! because ownership and mutability rules make it difficult, and because 64-bit pointers
//! take up a lot of space, and we want a compact in-memory representation. Instead, entity
//! references are structs wrapping a u32 index into a table in the Function main data
//! structure. There is a separate index type for each entity type, so we don't lose type safety.
//!
//! The entity references all implement the format trait in a way that matches the textual IR
//! format.

const std = @import("std");
const entity = @import("../entity.zig");

/// An opaque reference to a basic block in a Function.
///
/// While the order is stable, it is arbitrary and does not necessarily resemble the layout order.
pub const Block = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "block");

    /// Create a new block reference from its number. This corresponds to the blockNN representation.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) ?Block {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to an SSA value.
///
/// While the order is stable, it is arbitrary.
pub const Value = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "v");

    /// Create a value from its number representation.
    /// This is the number in the vNN notation.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?Value {
        return if (n < std.math.maxInt(u32) / 2) @enumFromInt(n) else null;
    }
};

/// An opaque reference to an instruction in a Function.
///
/// While the order is stable, it is arbitrary and does not necessarily resemble the layout order.
pub const Inst = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "inst");
};

/// An opaque reference to a stack slot.
///
/// Stack slots represent an address on the call stack.
///
/// While the order is stable, it is arbitrary and does not necessarily resemble the stack order.
pub const StackSlot = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "ss");

    /// Create a new stack slot reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?StackSlot {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to a dynamic stack slot.
pub const DynamicStackSlot = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "dss");

    /// Create a new stack slot reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?DynamicStackSlot {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to a dynamic type.
pub const DynamicType = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "dt");

    /// Create a new dynamic type reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?DynamicType {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to a global value.
///
/// A GlobalValue is a Value that will be live across the entire function lifetime.
/// It can be preloaded from other global values.
///
/// While the order is stable, it is arbitrary.
pub const GlobalValue = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "gv");

    /// Create a new global value reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?GlobalValue {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to a memory type.
///
/// A MemoryType is a descriptor of a struct layout in memory, with
/// types and proof-carrying-code facts optionally attached to the fields.
pub const MemoryType = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "mt");

    /// Create a new memory type reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?MemoryType {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to a constant.
///
/// While the order is stable, it is arbitrary and does not necessarily resemble the order in which
/// the constants are written in the constant pool.
pub const Constant = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "const");

    /// Create a const reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?Constant {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to an immediate.
///
/// Some immediates (e.g. SIMD shuffle masks) are too large to store in the
/// InstructionData struct and therefore must be tracked separately in DataFlowGraph.
/// Immediate provides a way to reference values stored there.
///
/// While the order is stable, it is arbitrary.
pub const Immediate = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "imm");

    /// Create an immediate reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?Immediate {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to a jump table.
///
/// Jump tables are used for indirect branching and are specialized for dense,
/// 0-based jump offsets.
///
/// While the order is stable, it is arbitrary.
pub const JumpTable = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "jt");

    /// Create a new jump table reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?JumpTable {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to another Function.
///
/// FuncRefs are used for direct function calls and by func_addr for use in
/// indirect function calls.
///
/// While the order is stable, it is arbitrary.
pub const FuncRef = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "fn");

    /// Create a new external function reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?FuncRef {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// A reference to a UserExternalName, declared with Function.declare_imported_user_function.
pub const UserExternalNameRef = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    pub usingnamespace entity.EntityRef(@This(), "userextname");
};

/// An opaque reference to a function Signature.
///
/// While the order is stable, it is arbitrary.
pub const SigRef = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "sig");

    /// Create a new function signature reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?SigRef {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque exception tag.
///
/// Exception tags are used to denote the identity of an exception for
/// matching by catch-handlers in exception tables.
///
/// The index space is arbitrary and is given meaning only by the
/// embedder. Hoist will carry through these tags from exception tables
/// to the handler metadata produced as output (for use by the embedder's unwinder).
pub const ExceptionTag = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "tag");

    /// Create a new exception tag from its arbitrary index.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?ExceptionTag {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to an exception table.
///
/// ExceptionTables are used for describing exception catch handlers on
/// try_call and try_call_indirect instructions.
pub const ExceptionTable = enum(u32) {
    _,

    pub usingnamespace entity.EntityRef(@This(), "extable");

    /// Create a new exception table reference from its number.
    ///
    /// This method is for use by the parser.
    pub fn withNumber(n: u32) -> ?ExceptionTable {
        return if (n < std.math.maxInt(u32)) @enumFromInt(n) else null;
    }
};

/// An opaque reference to any of the entities defined in this module that can appear in IR.
pub const AnyEntity = union(enum) {
    /// The whole function.
    function,
    /// A basic block.
    block: Block,
    /// An instruction.
    inst: Inst,
    /// An SSA value.
    value: Value,
    /// A stack slot.
    stack_slot: StackSlot,
    /// A dynamic stack slot.
    dynamic_stack_slot: DynamicStackSlot,
    /// A dynamic type
    dynamic_type: DynamicType,
    /// A global value.
    global_value: GlobalValue,
    /// A memory type.
    memory_type: MemoryType,
    /// A jump table.
    jump_table: JumpTable,
    /// A constant.
    constant: Constant,
    /// An external function.
    func_ref: FuncRef,
    /// A function call signature.
    sig_ref: SigRef,
    /// An exception table.
    exception_table: ExceptionTable,
    /// A function's stack limit
    stack_limit,

    pub fn format(
        self: AnyEntity,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .function => try writer.writeAll("function"),
            .block => |r| try r.format("", .{}, writer),
            .inst => |r| try r.format("", .{}, writer),
            .value => |r| try r.format("", .{}, writer),
            .stack_slot => |r| try r.format("", .{}, writer),
            .dynamic_stack_slot => |r| try r.format("", .{}, writer),
            .dynamic_type => |r| try r.format("", .{}, writer),
            .global_value => |r| try r.format("", .{}, writer),
            .memory_type => |r| try r.format("", .{}, writer),
            .jump_table => |r| try r.format("", .{}, writer),
            .constant => |r| try r.format("", .{}, writer),
            .func_ref => |r| try r.format("", .{}, writer),
            .sig_ref => |r| try r.format("", .{}, writer),
            .exception_table => |r| try r.format("", .{}, writer),
            .stack_limit => try writer.writeAll("stack_limit"),
        }
    }
};

test "Value.withNumber" {
    const testing = std.testing;

    const v0 = Value.withNumber(0).?;
    const v1 = Value.withNumber(1).?;

    var buf: [16]u8 = undefined;
    const s0 = try std.fmt.bufPrint(&buf, "{}", .{v0});
    try testing.expectEqualStrings("v0", s0);

    const s1 = try std.fmt.bufPrint(&buf, "{}", .{v1});
    try testing.expectEqualStrings("v1", s1);

    try testing.expect(Value.withNumber(std.math.maxInt(u32) / 2) == null);
    try testing.expect(Value.withNumber(std.math.maxInt(u32) / 2 - 1) != null);
}

test "Constant.withNumber" {
    const testing = std.testing;

    const c0 = Constant.withNumber(0).?;
    const c1 = Constant.withNumber(1).?;

    var buf: [16]u8 = undefined;
    const s0 = try std.fmt.bufPrint(&buf, "{}", .{c0});
    try testing.expectEqualStrings("const0", s0);

    const s1 = try std.fmt.bufPrint(&buf, "{}", .{c1});
    try testing.expectEqualStrings("const1", s1);
}

test "entity size" {
    const testing = std.testing;

    // Entity references should be 4 bytes
    try testing.expectEqual(@sizeOf(u32), @sizeOf(Value));
    try testing.expectEqual(@sizeOf(u32), @sizeOf(Block));
    try testing.expectEqual(@sizeOf(u32), @sizeOf(Inst));

    // Optional entity references should be 8 bytes (standard optional enum layout)
    // Note: Zig's optional enums use a dedicated tag value, so ?Value is larger than Value
    try testing.expect(@sizeOf(?Value) > @sizeOf(Value));
}
