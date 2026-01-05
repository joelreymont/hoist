//! Value labels for debug info tracking.
//!
//! Ported from cranelift-codegen value_label.rs.
//! ValueLabel tracks source-level variable names mapped to IR values for debuggers.

const std = @import("std");
const Value = @import("../ir/entities.zig").Value;
const EntityRef = @import("../foundation/entity.zig").EntityRef;

/// A value label, identifying a source-level variable.
pub const ValueLabel = EntityRef(u32, "vl");

/// Value location range - tracks where a value label is located in generated code.
pub const ValueLocRange = struct {
    /// The location containing a ValueLabel during this range.
    loc: LabelValueLoc,
    /// The start of the range (offset in generated code).
    start: u32,
    /// The end of the range (offset in generated code).
    end: u32,
};

/// The particular location for a value.
pub const LabelValueLoc = union(enum) {
    /// Register location.
    reg: u8, // TODO: Use proper Reg type when available
    /// Offset from the Canonical Frame Address (CFA).
    cfa_offset: i64,
};

/// Resulting map of Value labels and their ranges/locations.
pub const ValueLabelsRanges = std.AutoHashMap(ValueLabel, std.ArrayList(ValueLocRange));

/// Value label assignments: label starts or value aliases.
pub const ValueLabelAssignments = union(enum) {
    /// Original value labels assigned at transform.
    starts: std.ArrayList(ValueLabelStart),
    /// A value alias to original value.
    alias: struct {
        /// Source location when it is in effect.
        from: u32, // TODO: Use RelSourceLoc when implemented
        /// The label index.
        value: Value,
    },
};

/// A label of a Value with source location.
pub const ValueLabelStart = struct {
    /// Source location when it is in effect.
    from: u32, // TODO: Use RelSourceLoc when implemented
    /// The label index.
    label: ValueLabel,
};

const testing = std.testing;

test "ValueLabel basic" {
    const label = ValueLabel.fromIndex(42);
    try testing.expectEqual(@as(u32, 42), label.index());
}

test "ValueLocRange" {
    const range = ValueLocRange{
        .loc = .{ .reg = 5 },
        .start = 100,
        .end = 200,
    };
    try testing.expectEqual(@as(u32, 100), range.start);
    try testing.expectEqual(@as(u32, 200), range.end);
}
