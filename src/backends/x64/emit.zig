const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.x64_inst.Inst;
const OperandSize = root.x64_inst.OperandSize;
const Reg = root.x64_inst.Reg;
const PReg = root.x64_inst.PReg;
const buffer_mod = root.buffer;

/// Emit x64 instruction to binary.
/// This is a minimal bootstrap - full x64 emission needs:
/// - Complete ModR/M and SIB byte encoding
/// - REX prefix handling for 64-bit and extended regs
/// - VEX prefixes for AVX
/// - All addressing modes
pub fn emit(inst: Inst, buffer: *buffer_mod.MachBuffer) !void {
    switch (inst) {
        .mov_rr => |i| try emitMovRR(i.dst.toReg(), i.src, i.size, buffer),
        .mov_imm => |i| try emitMovImm(i.dst.toReg(), i.imm, i.size, buffer),
        .add_rr => |i| try emitAluRR(0x01, i.dst.toReg(), i.src, i.size, buffer), // ADD opcode
        .sub_rr => |i| try emitAluRR(0x29, i.dst.toReg(), i.src, i.size, buffer), // SUB opcode
        .push_r => |i| try emitPush(i.src, buffer),
        .pop_r => |i| try emitPop(i.dst.toReg(), buffer),
        .jmp => |i| try emitJmp(i.target.label, buffer),
        .jmp_cond => |i| try emitJmpCond(@intFromEnum(i.cc), i.target.label, buffer),
        .call => try buffer.put(&[_]u8{ 0xE8, 0x00, 0x00, 0x00, 0x00 }), // CALL rel32 (stub)
        .ret => try buffer.put(&[_]u8{0xC3}), // RET
        .nop => try buffer.put(&[_]u8{0x90}), // NOP
    }
}

/// Emit REX prefix if needed for 64-bit operation or extended registers.
fn emitRex(size: OperandSize, reg: ?Reg, rm: ?Reg, buffer: *buffer_mod.MachBuffer) !void {
    var rex: u8 = 0x40; // Base REX prefix
    var needs_rex = false;

    // REX.W for 64-bit operand size
    if (size == .size64) {
        rex |= 0x08; // REX.W
        needs_rex = true;
    }

    // REX.R for extended register in ModR/M reg field
    if (reg) |r| {
        if (r.isVirtual()) {
            // Virtual regs don't have hw encoding - assume low regs for now
        } else {
            const preg = r.toPReg();
            if (preg.hwEnc() >= 8) {
                rex |= 0x04; // REX.R
                needs_rex = true;
            }
        }
    }

    // REX.B for extended register in ModR/M r/m field
    if (rm) |r| {
        if (r.isVirtual()) {
            // Virtual regs don't have hw encoding
        } else {
            const preg = r.toPReg();
            if (preg.hwEnc() >= 8) {
                rex |= 0x01; // REX.B
                needs_rex = true;
            }
        }
    }

    if (needs_rex) {
        try buffer.put(&[_]u8{rex});
    }
}

/// Encode ModR/M byte.
fn modrm(mod: u8, reg: u8, rm: u8) u8 {
    return (mod << 6) | ((reg & 0x07) << 3) | (rm & 0x07);
}

/// Get hardware register encoding (low 3 bits for ModR/M).
fn hwEnc(reg: Reg) u8 {
    if (reg.isVirtual()) {
        // For testing - map virtual regs to low physical regs
        return @intCast(reg.toVReg().index() % 8);
    } else {
        return @intCast(reg.toPReg().hwEnc() & 0x07);
    }
}

/// MOV reg, reg
fn emitMovRR(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(size, src, dst, buffer);

    // MOV opcode (0x89 for reg->reg)
    try buffer.put(&[_]u8{0x89});

    // ModR/M: mod=11 (reg-reg), reg=src, rm=dst
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(src), hwEnc(dst))});
}

/// MOV reg, imm
fn emitMovImm(dst: Reg, imm: i64, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(size, null, dst, buffer);

    // MOV immediate opcode (0xB8 + reg for 32/64-bit)
    if (size == .size64 or size == .size32) {
        try buffer.put(&[_]u8{0xB8 + hwEnc(dst)});
        // Emit 32-bit immediate (sign-extended to 64-bit if needed)
        const imm32: u32 = @intCast(@as(i32, @truncate(imm)));
        try buffer.put(std.mem.asBytes(&imm32));
    } else {
        // 8-bit or 16-bit immediates (simplified)
        try buffer.put(&[_]u8{0xB0 + hwEnc(dst)});
        try buffer.put(&[_]u8{@intCast(@as(u8, @truncate(@as(u64, @bitCast(imm)))))});
    }
}

/// ALU operation reg, reg (ADD, SUB, etc.)
fn emitAluRR(opcode: u8, dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(size, src, dst, buffer);
    try buffer.put(&[_]u8{opcode});
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(src), hwEnc(dst))});
}

/// PUSH reg
fn emitPush(src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    // PUSH opcode (0x50 + reg)
    try buffer.put(&[_]u8{0x50 + hwEnc(src)});
}

/// POP reg
fn emitPop(dst: Reg, buffer: *buffer_mod.MachBuffer) !void {
    // POP opcode (0x58 + reg)
    try buffer.put(&[_]u8{0x58 + hwEnc(dst)});
}

/// JMP rel32
fn emitJmp(label: u32, buffer: *buffer_mod.MachBuffer) !void {
    // JMP rel32 opcode
    try buffer.put(&[_]u8{0xE9});

    // Add label use for fixup
    try buffer.useLabel(
        buffer_mod.MachLabel.new(label),
        buffer_mod.LabelUseKind.pc_rel32,
    );

    // Placeholder for rel32 (will be fixed up)
    try buffer.put(&[_]u8{ 0x00, 0x00, 0x00, 0x00 });
}

/// Jcc rel32 (conditional jump)
fn emitJmpCond(cc: u8, label: u32, buffer: *buffer_mod.MachBuffer) !void {
    // Jcc rel32 opcode (0x0F 0x80+cc)
    try buffer.put(&[_]u8{ 0x0F, 0x80 + cc });

    // Add label use for fixup
    try buffer.useLabel(
        buffer_mod.MachLabel.new(label),
        buffer_mod.LabelUseKind.pc_rel32,
    );

    // Placeholder for rel32
    try buffer.put(&[_]u8{ 0x00, 0x00, 0x00, 0x00 });
}

test "emit nop" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try emit(.nop, &buffer);

    try testing.expectEqual(@as(usize, 1), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x90), buffer.data.items[0]);
}

test "emit ret" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try emit(.ret, &buffer);

    try testing.expectEqual(@as(usize, 1), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0xC3), buffer.data.items[0]);
}

test "emit mov imm32" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .mov_imm = .{
        .dst = wr0,
        .imm = 42,
        .size = .size32,
    } }, &buffer);

    // Should emit: MOV r0, 42
    // B8+reg (1 byte) + imm32 (4 bytes) = 5 bytes
    try testing.expectEqual(@as(usize, 5), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0xB8), buffer.data.items[0]); // MOV eax, imm32
}

test "emit push/pop" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .push_r = .{ .src = r0 } }, &buffer);
    try emit(.{ .pop_r = .{ .dst = wr0 } }, &buffer);

    try testing.expectEqual(@as(usize, 2), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x50), buffer.data.items[0]); // PUSH
    try testing.expectEqual(@as(u8, 0x58), buffer.data.items[1]); // POP
}
