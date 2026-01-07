//! Unit tests for condition codes.

const std = @import("std");
const testing = std.testing;
const condcodes = @import("condcodes.zig");

const IntCC = condcodes.IntCC;
const FloatCC = condcodes.FloatCC;

// IntCC tests

test "IntCC.complement: equality" {
    try testing.expectEqual(IntCC.ne, IntCC.eq.complement());
    try testing.expectEqual(IntCC.eq, IntCC.ne.complement());
}

test "IntCC.complement: signed comparisons" {
    try testing.expectEqual(IntCC.sge, IntCC.slt.complement());
    try testing.expectEqual(IntCC.slt, IntCC.sge.complement());
    try testing.expectEqual(IntCC.sle, IntCC.sgt.complement());
    try testing.expectEqual(IntCC.sgt, IntCC.sle.complement());
}

test "IntCC.complement: unsigned comparisons" {
    try testing.expectEqual(IntCC.uge, IntCC.ult.complement());
    try testing.expectEqual(IntCC.ult, IntCC.uge.complement());
    try testing.expectEqual(IntCC.ule, IntCC.ugt.complement());
    try testing.expectEqual(IntCC.ugt, IntCC.ule.complement());
}

test "IntCC.complement: is involutive" {
    // complement(complement(x)) == x for all x
    const all_ccs = [_]IntCC{ .eq, .ne, .slt, .sge, .sgt, .sle, .ult, .uge, .ugt, .ule };
    for (all_ccs) |cc| {
        try testing.expectEqual(cc, cc.complement().complement());
    }
}

test "IntCC.swapArgs: equality symmetric" {
    try testing.expectEqual(IntCC.eq, IntCC.eq.swapArgs());
    try testing.expectEqual(IntCC.ne, IntCC.ne.swapArgs());
}

test "IntCC.swapArgs: signed comparisons" {
    try testing.expectEqual(IntCC.slt, IntCC.sgt.swapArgs());
    try testing.expectEqual(IntCC.sgt, IntCC.slt.swapArgs());
    try testing.expectEqual(IntCC.sle, IntCC.sge.swapArgs());
    try testing.expectEqual(IntCC.sge, IntCC.sle.swapArgs());
}

test "IntCC.swapArgs: unsigned comparisons" {
    try testing.expectEqual(IntCC.ult, IntCC.ugt.swapArgs());
    try testing.expectEqual(IntCC.ugt, IntCC.ult.swapArgs());
    try testing.expectEqual(IntCC.ule, IntCC.uge.swapArgs());
    try testing.expectEqual(IntCC.uge, IntCC.ule.swapArgs());
}

test "IntCC.swapArgs: is involutive" {
    // swapArgs(swapArgs(x)) == x for all x
    const all_ccs = [_]IntCC{ .eq, .ne, .slt, .sge, .sgt, .sle, .ult, .uge, .ugt, .ule };
    for (all_ccs) |cc| {
        try testing.expectEqual(cc, cc.swapArgs().swapArgs());
    }
}

test "IntCC.withoutEqual: greater than" {
    try testing.expectEqual(IntCC.sgt, IntCC.sgt.withoutEqual());
    try testing.expectEqual(IntCC.sgt, IntCC.sge.withoutEqual());
    try testing.expectEqual(IntCC.ugt, IntCC.ugt.withoutEqual());
    try testing.expectEqual(IntCC.ugt, IntCC.uge.withoutEqual());
}

test "IntCC.withoutEqual: less than" {
    try testing.expectEqual(IntCC.slt, IntCC.slt.withoutEqual());
    try testing.expectEqual(IntCC.slt, IntCC.sle.withoutEqual());
    try testing.expectEqual(IntCC.ult, IntCC.ult.withoutEqual());
    try testing.expectEqual(IntCC.ult, IntCC.ule.withoutEqual());
}

test "IntCC.withoutEqual: equality unchanged" {
    try testing.expectEqual(IntCC.eq, IntCC.eq.withoutEqual());
    try testing.expectEqual(IntCC.ne, IntCC.ne.withoutEqual());
}

test "IntCC.withoutEqual: is idempotent" {
    // withoutEqual(withoutEqual(x)) == withoutEqual(x) for all x
    const all_ccs = [_]IntCC{ .eq, .ne, .slt, .sge, .sgt, .sle, .ult, .uge, .ugt, .ule };
    for (all_ccs) |cc| {
        try testing.expectEqual(cc.withoutEqual(), cc.withoutEqual().withoutEqual());
    }
}

test "IntCC.unsigned: signed to unsigned" {
    try testing.expectEqual(IntCC.ugt, IntCC.sgt.unsigned());
    try testing.expectEqual(IntCC.uge, IntCC.sge.unsigned());
    try testing.expectEqual(IntCC.ult, IntCC.slt.unsigned());
    try testing.expectEqual(IntCC.ule, IntCC.sle.unsigned());
}

test "IntCC.unsigned: unsigned unchanged" {
    try testing.expectEqual(IntCC.ugt, IntCC.ugt.unsigned());
    try testing.expectEqual(IntCC.uge, IntCC.uge.unsigned());
    try testing.expectEqual(IntCC.ult, IntCC.ult.unsigned());
    try testing.expectEqual(IntCC.ule, IntCC.ule.unsigned());
}

test "IntCC.unsigned: equality unchanged" {
    try testing.expectEqual(IntCC.eq, IntCC.eq.unsigned());
    try testing.expectEqual(IntCC.ne, IntCC.ne.unsigned());
}

test "IntCC.unsigned: is idempotent" {
    // unsigned(unsigned(x)) == unsigned(x) for all x
    const all_ccs = [_]IntCC{ .eq, .ne, .slt, .sge, .sgt, .sle, .ult, .uge, .ugt, .ule };
    for (all_ccs) |cc| {
        try testing.expectEqual(cc.unsigned(), cc.unsigned().unsigned());
    }
}

test "IntCC: complement and swapArgs commute" {
    // complement(swapArgs(x)) == swapArgs(complement(x)) for all x
    const all_ccs = [_]IntCC{ .eq, .ne, .slt, .sge, .sgt, .sle, .ult, .uge, .ugt, .ule };
    for (all_ccs) |cc| {
        try testing.expectEqual(cc.complement().swapArgs(), cc.swapArgs().complement());
    }
}

test "IntCC: signed <-> unsigned preserves ordering" {
    // sgt.unsigned() == ugt
    try testing.expectEqual(IntCC.ugt, IntCC.sgt.unsigned());
    try testing.expectEqual(IntCC.uge, IntCC.sge.unsigned());
    try testing.expectEqual(IntCC.ult, IntCC.slt.unsigned());
    try testing.expectEqual(IntCC.ule, IntCC.sle.unsigned());
}

// FloatCC tests

test "FloatCC.complement: basic complementation" {
    try testing.expectEqual(FloatCC.ne, FloatCC.eq.complement());
    try testing.expectEqual(FloatCC.eq, FloatCC.ne.complement());
}

test "FloatCC.complement: is involutive" {
    // complement(complement(x)) == x for all x
    const all_fcs = [_]FloatCC{ .ord, .uno, .eq, .ne, .lt, .le, .gt, .ge, .ueq, .une, .ult, .ule, .ugt, .uge };
    for (all_fcs) |fc| {
        try testing.expectEqual(fc, fc.complement().complement());
    }
}

test "FloatCC.swapArgs: symmetric operations" {
    try testing.expectEqual(FloatCC.eq, FloatCC.eq.swapArgs());
    try testing.expectEqual(FloatCC.ne, FloatCC.ne.swapArgs());
    try testing.expectEqual(FloatCC.ueq, FloatCC.ueq.swapArgs());
    try testing.expectEqual(FloatCC.une, FloatCC.une.swapArgs());
    try testing.expectEqual(FloatCC.ord, FloatCC.ord.swapArgs());
    try testing.expectEqual(FloatCC.uno, FloatCC.uno.swapArgs());
}

test "FloatCC.swapArgs: less/greater swap" {
    try testing.expectEqual(FloatCC.gt, FloatCC.lt.swapArgs());
    try testing.expectEqual(FloatCC.lt, FloatCC.gt.swapArgs());
    try testing.expectEqual(FloatCC.ge, FloatCC.le.swapArgs());
    try testing.expectEqual(FloatCC.le, FloatCC.ge.swapArgs());
    try testing.expectEqual(FloatCC.ugt, FloatCC.ult.swapArgs());
    try testing.expectEqual(FloatCC.ult, FloatCC.ugt.swapArgs());
    try testing.expectEqual(FloatCC.uge, FloatCC.ule.swapArgs());
    try testing.expectEqual(FloatCC.ule, FloatCC.uge.swapArgs());
}

test "FloatCC.swapArgs: is involutive" {
    // swapArgs(swapArgs(x)) == x for all x
    const all_fcs = [_]FloatCC{ .ord, .uno, .eq, .ne, .lt, .le, .gt, .ge, .ueq, .une, .ult, .ule, .ugt, .uge };
    for (all_fcs) |fc| {
        try testing.expectEqual(fc, fc.swapArgs().swapArgs());
    }
}

test "FloatCC: complement and swapArgs commute" {
    // complement(swapArgs(x)) == swapArgs(complement(x)) for all x
    const all_fcs = [_]FloatCC{ .ord, .uno, .eq, .ne, .lt, .le, .gt, .ge, .ueq, .une, .ult, .ule, .ugt, .uge };
    for (all_fcs) |fc| {
        try testing.expectEqual(fc.complement().swapArgs(), fc.swapArgs().complement());
    }
}

test "FloatCC: ordered vs unordered" {
    // Ordered comparisons
    try testing.expect(FloatCC.eq != FloatCC.ueq);
    try testing.expect(FloatCC.ne != FloatCC.une);
    try testing.expect(FloatCC.lt != FloatCC.ult);
    try testing.expect(FloatCC.le != FloatCC.ule);
    try testing.expect(FloatCC.gt != FloatCC.ugt);
    try testing.expect(FloatCC.ge != FloatCC.uge);
}
