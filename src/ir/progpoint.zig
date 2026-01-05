//! Program points.
//!
//! Ported from cranelift-codegen ir/progpoint.rs.
//! Represents positions in a function where SSA value live ranges can begin or end.

const std = @import("std");
const entities = @import("entities.zig");
const Block = entities.Block;
const Inst = entities.Inst;

/// A ProgramPoint represents a position in a function where the live range of an SSA value can
/// begin or end. It can be either an instruction or a block header.
///
/// This corresponds more or less to the lines in the textual form of Cranelift IR.
pub const ProgramPoint = union(enum) {
    /// An instruction in the function.
    inst: Inst,
    /// A block header.
    block: Block,

    /// Get the instruction we know is inside.
    pub fn unwrapInst(self: ProgramPoint) Inst {
        return switch (self) {
            .inst => |x| x,
            .block => |x| @panic("expected inst, got block"),
        };
    }

    /// Format for display.
    pub fn format(
        self: ProgramPoint,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .inst => |x| try writer.print("inst{}", .{x.index()}),
            .block => |x| try writer.print("block{}", .{x.index()}),
        }
    }
};

const testing = std.testing;

test "ProgramPoint convert" {
    const i5 = Inst.fromIndex(5);
    const b3 = Block.fromIndex(3);

    const pp1: ProgramPoint = .{ .inst = i5 };
    const pp2: ProgramPoint = .{ .block = b3 };

    var buf1: [64]u8 = undefined;
    const str1 = try std.fmt.bufPrint(&buf1, "{any}", .{pp1});
    try testing.expectEqualStrings("inst5", str1);

    var buf2: [64]u8 = undefined;
    const str2 = try std.fmt.bufPrint(&buf2, "{any}", .{pp2});
    try testing.expectEqualStrings("block3", str2);
}
