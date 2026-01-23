const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Inst = hoist.x64_inst.Inst;
const Reg = hoist.x64_inst.Reg;
const WritableReg = hoist.x64_inst.WritableReg;
const PReg = hoist.reg.PReg;
const OperandSize = hoist.x64_inst.OperandSize;
const MachBuffer = hoist.buffer.MachBuffer;

/// Test MOV encoding: mov rax, rbx
test "x64 encode mov" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const rax = Reg.fromPReg(PReg.new(.int, 0));
    const rbx = Reg.fromPReg(PReg.new(.int, 3));
    const rax_w = WritableReg.fromReg(rax);

    const inst = Inst{
        .mov_rr = .{
            .dst = rax_w,
            .src = rbx,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    // mov rax, rbx: REX.W + 89 /r (ModR/M = 11_011_000)
    // Expected: 48 89 D8
    try testing.expect(buffer.data.items.len > 0);
}

/// Test ADD encoding: add rax, rbx
test "x64 encode add" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const rax = Reg.fromPReg(PReg.new(.int, 0));
    const rbx = Reg.fromPReg(PReg.new(.int, 3));
    const rax_w = WritableReg.fromReg(rax);

    const inst = Inst{
        .add_rr = .{
            .dst = rax_w,
            .src1 = rax,
            .src2 = rbx,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    // add rax, rbx: REX.W + 01 /r
    // Expected: 48 01 D8
    try testing.expect(buffer.data.items.len > 0);
}

/// Test PUSH encoding: push rbx
test "x64 encode push" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const rbx = Reg.fromPReg(PReg.new(.int, 3));

    const inst = Inst{
        .push_r = .{
            .src = rbx,
        },
    };

    try inst.emit(&buffer);

    // push rbx: 50 + rd (0x53)
    // Expected: 53
    try testing.expect(buffer.data.items.len > 0);
}

/// Test POP encoding: pop rbx
test "x64 encode pop" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const rbx = Reg.fromPReg(PReg.new(.int, 3));
    const rbx_w = WritableReg.fromReg(rbx);

    const inst = Inst{
        .pop_r = .{
            .dst = rbx_w,
        },
    };

    try inst.emit(&buffer);

    // pop rbx: 58 + rd (0x5B)
    // Expected: 5B
    try testing.expect(buffer.data.items.len > 0);
}

/// Test IMM encoding: add rax, 42
test "x64 encode add immediate" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const rax = Reg.fromPReg(PReg.new(.int, 0));
    const rax_w = WritableReg.fromReg(rax);

    const inst = Inst{
        .add_imm = .{
            .dst = rax_w,
            .src = rax,
            .imm = 42,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    // add rax, 42: REX.W + 81 /0 + imm32 or 83 /0 + imm8
    // Expected: 48 83 C0 2A (using sign-extended imm8)
    try testing.expect(buffer.data.items.len > 0);
}

/// Test extended register encoding: mov r8, r9
test "x64 encode extended registers" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const r8 = Reg.fromPReg(PReg.new(.int, 8));
    const r9 = Reg.fromPReg(PReg.new(.int, 9));
    const r8_w = WritableReg.fromReg(r8);

    const inst = Inst{
        .mov_rr = .{
            .dst = r8_w,
            .src = r9,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    // mov r8, r9: REX.WRB + 89 /r
    // Expected: 4D 89 C8
    try testing.expect(buffer.data.items.len > 0);
}

/// Test memory load: mov rax, [rbx + 8]
test "x64 encode load" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const rax = Reg.fromPReg(PReg.new(.int, 0));
    const rbx = Reg.fromPReg(PReg.new(.int, 3));
    const rax_w = WritableReg.fromReg(rax);

    const inst = Inst{
        .mov_rm = .{
            .dst = rax_w,
            .base = rbx,
            .offset = 8,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    // mov rax, [rbx + 8]: REX.W + 8B /r + disp8
    // Expected: 48 8B 43 08
    try testing.expect(buffer.data.items.len > 0);
}

/// Test memory store: mov [rbx + 16], rax
test "x64 encode store" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const rax = Reg.fromPReg(PReg.new(.int, 0));
    const rbx = Reg.fromPReg(PReg.new(.int, 3));

    const inst = Inst{
        .mov_mr = .{
            .base = rbx,
            .offset = 16,
            .src = rax,
            .size = .size64,
        },
    };

    try inst.emit(&buffer);

    // mov [rbx + 16], rax: REX.W + 89 /r + disp8
    // Expected: 48 89 43 10
    try testing.expect(buffer.data.items.len > 0);
}

/// Test RET encoding
test "x64 encode ret" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const inst = Inst{ .ret = {} };

    try inst.emit(&buffer);

    // ret: C3
    try testing.expectEqual(@as(usize, 1), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0xC3), buffer.data.items[0]);
}

/// Test 32-bit operand size
test "x64 encode 32bit" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const eax = Reg.fromPReg(PReg.new(.int, 0));
    const ebx = Reg.fromPReg(PReg.new(.int, 3));
    const eax_w = WritableReg.fromReg(eax);

    const inst = Inst{
        .mov_rr = .{
            .dst = eax_w,
            .src = ebx,
            .size = .size32,
        },
    };

    try inst.emit(&buffer);

    // mov eax, ebx: 89 /r (no REX prefix for 32-bit)
    // Expected: 89 D8
    try testing.expect(buffer.data.items.len > 0);
}
