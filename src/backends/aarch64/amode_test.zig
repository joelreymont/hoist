//! Unit tests for AArch64 addressing mode selection and legalization.

const std = @import("std");
const testing = std.testing;
const inst_mod = @import("inst.zig");

const Amode = inst_mod.Amode;
const Reg = inst_mod.Reg;
const PReg = inst_mod.PReg;
const ExtendOp = inst_mod.ExtendOp;

test "Amode: reg_offset simple" {
    const x0 = PReg.new(.int, 0).toReg();
    const amode = Amode{ .reg_offset = .{
        .base = x0,
        .offset = 16,
    } };

    switch (amode) {
        .reg_offset => |a| {
            try testing.expectEqual(x0, a.base);
            try testing.expectEqual(@as(i64, 16), a.offset);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: reg_offset negative" {
    const sp = PReg.new(.int, 31).toReg();
    const amode = Amode{ .reg_offset = .{
        .base = sp,
        .offset = -32,
    } };

    switch (amode) {
        .reg_offset => |a| {
            try testing.expectEqual(sp, a.base);
            try testing.expectEqual(@as(i64, -32), a.offset);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: reg_offset zero" {
    const x1 = PReg.new(.int, 1).toReg();
    const amode = Amode{ .reg_offset = .{
        .base = x1,
        .offset = 0,
    } };

    switch (amode) {
        .reg_offset => |a| {
            try testing.expectEqual(x1, a.base);
            try testing.expectEqual(@as(i64, 0), a.offset);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: reg_offset large positive" {
    const x2 = PReg.new(.int, 2).toReg();
    const amode = Amode{ .reg_offset = .{
        .base = x2,
        .offset = 4096,
    } };

    switch (amode) {
        .reg_offset => |a| {
            try testing.expectEqual(x2, a.base);
            try testing.expectEqual(@as(i64, 4096), a.offset);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: reg_reg basic" {
    const x0 = PReg.new(.int, 0).toReg();
    const x1 = PReg.new(.int, 1).toReg();
    const amode = Amode{ .reg_reg = .{
        .base = x0,
        .index = x1,
    } };

    switch (amode) {
        .reg_reg => |a| {
            try testing.expectEqual(x0, a.base);
            try testing.expectEqual(x1, a.index);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: reg_reg same register" {
    const x5 = PReg.new(.int, 5).toReg();
    const amode = Amode{ .reg_reg = .{
        .base = x5,
        .index = x5,
    } };

    switch (amode) {
        .reg_reg => |a| {
            try testing.expectEqual(x5, a.base);
            try testing.expectEqual(x5, a.index);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: reg_extended SXTW" {
    const x0 = PReg.new(.int, 0).toReg();
    const w1 = PReg.new(.int, 1).toReg();
    const amode = Amode{ .reg_extended = .{
        .base = x0,
        .index = w1,
        .extend = .sxtw,
    } };

    switch (amode) {
        .reg_extended => |a| {
            try testing.expectEqual(x0, a.base);
            try testing.expectEqual(w1, a.index);
            try testing.expectEqual(ExtendOp.sxtw, a.extend);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: reg_extended UXTW" {
    const x10 = PReg.new(.int, 10).toReg();
    const w11 = PReg.new(.int, 11).toReg();
    const amode = Amode{ .reg_extended = .{
        .base = x10,
        .index = w11,
        .extend = .uxtw,
    } };

    switch (amode) {
        .reg_extended => |a| {
            try testing.expectEqual(x10, a.base);
            try testing.expectEqual(w11, a.index);
            try testing.expectEqual(ExtendOp.uxtw, a.extend);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: reg_scaled scale 0" {
    const x0 = PReg.new(.int, 0).toReg();
    const x1 = PReg.new(.int, 1).toReg();
    const amode = Amode{ .reg_scaled = .{
        .base = x0,
        .index = x1,
        .scale = 0,
    } };

    switch (amode) {
        .reg_scaled => |a| {
            try testing.expectEqual(x0, a.base);
            try testing.expectEqual(x1, a.index);
            try testing.expectEqual(@as(u8, 0), a.scale);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: reg_scaled scale 3 (8-byte)" {
    const x2 = PReg.new(.int, 2).toReg();
    const x3 = PReg.new(.int, 3).toReg();
    const amode = Amode{
        .reg_scaled = .{
            .base = x2,
            .index = x3,
            .scale = 3, // LSL #3 = multiply by 8
        },
    };

    switch (amode) {
        .reg_scaled => |a| {
            try testing.expectEqual(x2, a.base);
            try testing.expectEqual(x3, a.index);
            try testing.expectEqual(@as(u8, 3), a.scale);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: reg_scaled scale 2 (4-byte)" {
    const x4 = PReg.new(.int, 4).toReg();
    const x5 = PReg.new(.int, 5).toReg();
    const amode = Amode{
        .reg_scaled = .{
            .base = x4,
            .index = x5,
            .scale = 2, // LSL #2 = multiply by 4
        },
    };

    switch (amode) {
        .reg_scaled => |a| {
            try testing.expectEqual(x4, a.base);
            try testing.expectEqual(x5, a.index);
            try testing.expectEqual(@as(u8, 2), a.scale);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: pre_index positive" {
    const x0 = PReg.new(.int, 0).toReg();
    const amode = Amode{ .pre_index = .{
        .base = x0,
        .offset = 16,
    } };

    switch (amode) {
        .pre_index => |a| {
            try testing.expectEqual(x0, a.base);
            try testing.expectEqual(@as(i64, 16), a.offset);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: pre_index negative" {
    const sp = PReg.new(.int, 31).toReg();
    const amode = Amode{ .pre_index = .{
        .base = sp,
        .offset = -16,
    } };

    switch (amode) {
        .pre_index => |a| {
            try testing.expectEqual(sp, a.base);
            try testing.expectEqual(@as(i64, -16), a.offset);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: post_index positive" {
    const x1 = PReg.new(.int, 1).toReg();
    const amode = Amode{ .post_index = .{
        .base = x1,
        .offset = 8,
    } };

    switch (amode) {
        .post_index => |a| {
            try testing.expectEqual(x1, a.base);
            try testing.expectEqual(@as(i64, 8), a.offset);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: post_index negative" {
    const x2 = PReg.new(.int, 2).toReg();
    const amode = Amode{ .post_index = .{
        .base = x2,
        .offset = -32,
    } };

    switch (amode) {
        .post_index => |a| {
            try testing.expectEqual(x2, a.base);
            try testing.expectEqual(@as(i64, -32), a.offset);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: label" {
    const amode = Amode{ .label = 42 };

    switch (amode) {
        .label => |l| {
            try testing.expectEqual(@as(u32, 42), l);
        },
        else => return error.WrongAmodeVariant,
    }
}

test "Amode: different variants are distinct" {
    const x0 = PReg.new(.int, 0).toReg();
    const x1 = PReg.new(.int, 1).toReg();

    const reg_offset = Amode{ .reg_offset = .{ .base = x0, .offset = 16 } };
    const reg_reg = Amode{ .reg_reg = .{ .base = x0, .index = x1 } };
    const pre_index = Amode{ .pre_index = .{ .base = x0, .offset = 16 } };
    const post_index = Amode{ .post_index = .{ .base = x0, .offset = 16 } };

    // Verify they're different variants (would fail if converted to same type)
    switch (reg_offset) {
        .reg_offset => {},
        else => return error.WrongVariant,
    }
    switch (reg_reg) {
        .reg_reg => {},
        else => return error.WrongVariant,
    }
    switch (pre_index) {
        .pre_index => {},
        else => return error.WrongVariant,
    }
    switch (post_index) {
        .post_index => {},
        else => return error.WrongVariant,
    }
}

test "Amode: offset range boundary values" {
    const x0 = PReg.new(.int, 0).toReg();

    // Test maximum positive 9-bit signed offset for pre/post-index (-256 to 255)
    const max_indexed = Amode{ .pre_index = .{ .base = x0, .offset = 255 } };
    const min_indexed = Amode{ .pre_index = .{ .base = x0, .offset = -256 } };

    switch (max_indexed) {
        .pre_index => |a| try testing.expectEqual(@as(i64, 255), a.offset),
        else => return error.WrongVariant,
    }
    switch (min_indexed) {
        .pre_index => |a| try testing.expectEqual(@as(i64, -256), a.offset),
        else => return error.WrongVariant,
    }

    // Test larger offsets that require reg_offset mode
    const large_pos = Amode{ .reg_offset = .{ .base = x0, .offset = 8192 } };
    const large_neg = Amode{ .reg_offset = .{ .base = x0, .offset = -8192 } };

    switch (large_pos) {
        .reg_offset => |a| try testing.expectEqual(@as(i64, 8192), a.offset),
        else => return error.WrongVariant,
    }
    switch (large_neg) {
        .reg_offset => |a| try testing.expectEqual(@as(i64, -8192), a.offset),
        else => return error.WrongVariant,
    }
}
