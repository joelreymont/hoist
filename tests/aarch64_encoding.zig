const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const WritableReg = root.aarch64_inst.WritableReg;
const PReg = root.reg.PReg;
const OperandSize = root.aarch64_inst.OperandSize;
const MachBuffer = root.buffer.MachBuffer;

/// Test MOV encoding: mov x0, x1
test "aarch64 encode mov" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x0_w = WritableReg.fromReg(x0);

    const inst = Inst{
        .mov_rr = .{
            .dst = x0_w,
            .src = x1,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    // mov x0, x1: ORR x0, XZR, x1
    // Expected: 4 bytes (ARM instructions are fixed 32-bit)
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test ADD encoding: add x0, x1, x2
test "aarch64 encode add" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x2 = Reg.fromPReg(PReg.new(.int, 2));
    const x0_w = WritableReg.fromReg(x0);

    const inst = Inst{
        .add_rr = .{
            .dst = x0_w,
            .src1 = x1,
            .src2 = x2,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test SUB encoding: sub x0, x1, x2
test "aarch64 encode sub" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x2 = Reg.fromPReg(PReg.new(.int, 2));
    const x0_w = WritableReg.fromReg(x0);

    const inst = Inst{
        .sub_rr = .{
            .dst = x0_w,
            .src1 = x1,
            .src2 = x2,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test ADD immediate: add x0, x1, #42
test "aarch64 encode add immediate" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x0_w = WritableReg.fromReg(x0);

    const inst = Inst{
        .add_imm = .{
            .dst = x0_w,
            .src = x1,
            .imm = 42,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test LDR encoding: ldr x0, [x1, #8]
test "aarch64 encode load" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x0_w = WritableReg.fromReg(x0);

    const inst = Inst{
        .ldr = .{
            .dst = x0_w,
            .base = x1,
            .offset = 8,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test STR encoding: str x0, [x1, #16]
test "aarch64 encode store" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));

    const inst = Inst{
        .str = .{
            .src = x0,
            .base = x1,
            .offset = 16,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test STP encoding: stp x0, x1, [sp, #-16]
test "aarch64 encode store pair" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const sp = Reg.fromPReg(PReg.new(.int, 31));

    const inst = Inst{
        .stp = .{
            .src1 = x0,
            .src2 = x1,
            .base = sp,
            .offset = -16,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test LDP encoding: ldp x0, x1, [sp, #16]
test "aarch64 encode load pair" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const sp = Reg.fromPReg(PReg.new(.int, 31));
    const x0_w = WritableReg.fromReg(x0);
    const x1_w = WritableReg.fromReg(x1);

    const inst = Inst{
        .ldp = .{
            .dst1 = x0_w,
            .dst2 = x1_w,
            .base = sp,
            .offset = 16,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test RET encoding
test "aarch64 encode ret" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const inst = Inst{ .ret = {} };

    try inst.emit(&buffer);

    // ret: D65F03C0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test B (unconditional branch)
test "aarch64 encode branch" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const target = root.aarch64_inst.BranchTarget{ .label = 0 };

    const inst = Inst{
        .b = .{
            .target = target,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test B.cond (conditional branch)
test "aarch64 encode conditional branch" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const target = root.aarch64_inst.BranchTarget{ .label = 0 };

    const inst = Inst{
        .b_cond = .{
            .cond = .eq,
            .target = target,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

/// Test 32-bit operand size: add w0, w1, w2
test "aarch64 encode 32bit" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const w0 = Reg.fromPReg(PReg.new(.int, 0));
    const w1 = Reg.fromPReg(PReg.new(.int, 1));
    const w2 = Reg.fromPReg(PReg.new(.int, 2));
    const w0_w = WritableReg.fromReg(w0);

    const inst = Inst{
        .add_rr = .{
            .dst = w0_w,
            .src1 = w1,
            .src2 = w2,
            .size = .size32,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}
