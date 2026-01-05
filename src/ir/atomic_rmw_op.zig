//! Atomic read-modify-write operations.
//!
//! Ported from cranelift-codegen ir/atomic_rmw_op.rs.
//! Describes the arithmetic operation in an atomic memory read-modify-write operation.

const std = @import("std");

/// Describes the arithmetic operation in an atomic memory read-modify-write operation.
pub const AtomicRmwOp = enum {
    /// Add
    add,
    /// Sub
    sub,
    /// And
    and_,
    /// Nand
    nand,
    /// Or
    or_,
    /// Xor
    xor,
    /// Exchange
    xchg,
    /// Unsigned min
    umin,
    /// Unsigned max
    umax,
    /// Signed min
    smin,
    /// Signed max
    smax,

    /// Returns a slice with all supported AtomicRmwOp's.
    pub fn all() []const AtomicRmwOp {
        const ops = [_]AtomicRmwOp{
            .add,
            .sub,
            .and_,
            .nand,
            .or_,
            .xor,
            .xchg,
            .umin,
            .umax,
            .smin,
            .smax,
        };
        return &ops;
    }

    /// Parse from string.
    pub fn parse(s: []const u8) ?AtomicRmwOp {
        if (std.mem.eql(u8, s, "add")) return .add;
        if (std.mem.eql(u8, s, "sub")) return .sub;
        if (std.mem.eql(u8, s, "and")) return .and_;
        if (std.mem.eql(u8, s, "nand")) return .nand;
        if (std.mem.eql(u8, s, "or")) return .or_;
        if (std.mem.eql(u8, s, "xor")) return .xor;
        if (std.mem.eql(u8, s, "xchg")) return .xchg;
        if (std.mem.eql(u8, s, "umin")) return .umin;
        if (std.mem.eql(u8, s, "umax")) return .umax;
        if (std.mem.eql(u8, s, "smin")) return .smin;
        if (std.mem.eql(u8, s, "smax")) return .smax;
        return null;
    }

    /// Format for display.
    pub fn format(
        self: AtomicRmwOp,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const s = switch (self) {
            .add => "add",
            .sub => "sub",
            .and_ => "and",
            .nand => "nand",
            .or_ => "or",
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

const testing = std.testing;

test "AtomicRmwOp roundtrip" {
    for (AtomicRmwOp.all()) |op| {
        var buf: [16]u8 = undefined;
        const s = try std.fmt.bufPrint(&buf, "{any}", .{op});
        const roundtripped = AtomicRmwOp.parse(s).?;
        try testing.expectEqual(op, roundtripped);
    }
}
