const std = @import("std");
const testing = std.testing;

/// Atomic read-modify-write operation.
pub const AtomicRmwOp = enum(u8) {
    add,
    sub,
    @"and",
    nand,
    @"or",
    xor,
    xchg,
    umin,
    umax,
    smin,
    smax,

    pub fn format(self: AtomicRmwOp, writer: anytype) !void {
        const s = switch (self) {
            .add => "add",
            .sub => "sub",
            .@"and" => "and",
            .nand => "nand",
            .@"or" => "or",
            .xor => "xor",
            .xchg => "xchg",
            .umin => "umin",
            .umax => "umax",
            .smin => "smin",
            .smax => "smax",
        };
        try writer.writeAll(s);
    }
};

test "AtomicRmwOp count" {
    const count = @typeInfo(AtomicRmwOp).@"enum".fields.len;
    try testing.expectEqual(11, count);
}

test "AtomicRmwOp format" {
    var buf: [16]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    try AtomicRmwOp.add.format(writer);
    try testing.expectEqualStrings("add", fbs.getWritten());

    fbs.reset();
    try AtomicRmwOp.xchg.format(writer);
    try testing.expectEqualStrings("xchg", fbs.getWritten());
}
