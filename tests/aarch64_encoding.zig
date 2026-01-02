const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const WritableReg = root.aarch64_inst.WritableReg;
const PReg = root.reg.PReg;
const OperandSize = root.aarch64_inst.OperandSize;
const MachBuffer = root.buffer.MachBuffer;

// Test MOV encoding: mov x0, x1
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

// Test ADD encoding: add x0, x1, x2
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

// Test SUB encoding: sub x0, x1, x2
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

// Test ADD immediate: add x0, x1, #42
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

// Test LDR encoding: ldr x0, [x1, #8]
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

// Test STR encoding: str x0, [x1, #16]
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

// Test STP encoding: stp x0, x1, [sp, #-16]
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

// Test LDP encoding: ldp x0, x1, [sp, #16]
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

// Test RET encoding
test "aarch64 encode ret" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const inst = Inst{ .ret = {} };

    try inst.emit(&buffer);

    // ret: D65F03C0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

// Test B (unconditional branch)
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

// Test B.cond (conditional branch)
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

// Test 32-bit operand size: add w0, w1, w2
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

// Test MADD encoding: madd x0, x1, x2, x3
test "aarch64 encode madd exact bytes" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x2 = Reg.fromPReg(PReg.new(.int, 2));
    const x3 = Reg.fromPReg(PReg.new(.int, 3));
    const x0_w = WritableReg.fromReg(x0);

    const inst = Inst{
        .madd = .{
            .dst = x0_w,
            .src1 = x1,
            .src2 = x2,
            .src3 = x3,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const bytes = buffer.data.items;
    try testing.expectEqual(@as(u8, 0x20), bytes[0]);
    try testing.expectEqual(@as(u8, 0x7c), bytes[1]);
    try testing.expectEqual(@as(u8, 0x02), bytes[2]);
    try testing.expectEqual(@as(u8, 0x9b), bytes[3]);
}

// Test SMULH encoding: smulh x0, x1, x2
test "aarch64 encode smulh exact bytes" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x2 = Reg.fromPReg(PReg.new(.int, 2));
    const x0_w = WritableReg.fromReg(x0);

    const inst = Inst{
        .smulh = .{
            .dst = x0_w,
            .src1 = x1,
            .src2 = x2,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const bytes = buffer.data.items;
    try testing.expectEqual(@as(u8, 0x20), bytes[0]);
    try testing.expectEqual(@as(u8, 0x7c), bytes[1]);
    try testing.expectEqual(@as(u8, 0x42), bytes[2]);
    try testing.expectEqual(@as(u8, 0x9b), bytes[3]);
}

// Test NEG encoding: neg x0, x1
test "aarch64 encode neg exact bytes" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x0_w = WritableReg.fromReg(x0);

    const inst = Inst{
        .neg = .{
            .dst = x0_w,
            .src = x1,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const bytes = buffer.data.items;
    try testing.expectEqual(@as(u8, 0xe0), bytes[0]);
    try testing.expectEqual(@as(u8, 0x03), bytes[1]);
    try testing.expectEqual(@as(u8, 0x01), bytes[2]);
    try testing.expectEqual(@as(u8, 0xcb), bytes[3]);
}

// Test vector ADD: add.16b v0, v1, v2
test "aarch64 encode vector add bytes" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = Reg.fromPReg(PReg.new(.vec, 0));
    const v1 = Reg.fromPReg(PReg.new(.vec, 1));
    const v2 = Reg.fromPReg(PReg.new(.vec, 2));
    const v0_w = WritableReg.fromReg(v0);

    const VectorSize = root.aarch64_inst.VectorSize;
    const inst = Inst{
        .vec_add = .{
            .dst = v0_w,
            .src1 = v1,
            .src2 = v2,
            .size = VectorSize.b16,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const bytes = buffer.data.items;
    try testing.expectEqual(@as(u8, 0x20), bytes[0]);
    try testing.expectEqual(@as(u8, 0x84), bytes[1]);
    try testing.expectEqual(@as(u8, 0x22), bytes[2]);
    try testing.expectEqual(@as(u8, 0x4e), bytes[3]);
}

// Test ADDV reduction: addv b0, v1.16b
test "aarch64 encode addv exact bytes" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = Reg.fromPReg(PReg.new(.vec, 0));
    const v1 = Reg.fromPReg(PReg.new(.vec, 1));
    const v0_w = WritableReg.fromReg(v0);

    const VectorSize = root.aarch64_inst.VectorSize;
    const inst = Inst{
        .addv = .{
            .dst = v0_w,
            .src = v1,
            .size = VectorSize.b16,
        },
    };

    try inst.emit(&buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const bytes = buffer.data.items;
    try testing.expectEqual(@as(u8, 0x20), bytes[0]);
    try testing.expectEqual(@as(u8, 0xb8), bytes[1]);
    try testing.expectEqual(@as(u8, 0x31), bytes[2]);
    try testing.expectEqual(@as(u8, 0x4e), bytes[3]);
}
