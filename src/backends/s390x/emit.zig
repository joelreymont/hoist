const std = @import("std");
const testing = std.testing;

const inst_mod = @import("inst.zig");
const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const PReg = inst_mod.PReg;
const buffer_mod = @import("../../machinst/buffer.zig");

pub fn emit(inst: Inst, buffer: *buffer_mod.MachBuffer) !void {
    switch (inst) {
        // 64-bit ALU
        .agr => |i| try emitRRE(0xB908, i.dst.toReg(), i.src2, buffer),
        .agfi => |i| try emitRIL(0xC2, 0x8, i.dst.toReg(), @bitCast(i.imm), buffer),
        .aghi => |i| try emitRI(0xA7, 0xB, i.dst.toReg(), @bitCast(i.imm), buffer),
        .sgr => |i| try emitRRE(0xB909, i.dst.toReg(), i.src2, buffer),
        .sgfr => |i| try emitRRE(0xB919, i.dst.toReg(), i.src2, buffer),
        .msgr => |i| try emitRRE(0xB90C, i.dst.toReg(), i.src2, buffer),
        .mghi => |i| try emitRI(0xA7, 0xD, i.dst.toReg(), @bitCast(i.imm), buffer),
        .dsgr => |i| try emitRRE(0xB90D, i.dst.toReg(), i.src, buffer),
        .dlgr => |i| try emitRRE(0xB987, i.dst.toReg(), i.src, buffer),

        // Logical
        .ngr => |i| try emitRRE(0xB980, i.dst.toReg(), i.src2, buffer),
        .ogr => |i| try emitRRE(0xB981, i.dst.toReg(), i.src2, buffer),
        .xgr => |i| try emitRRE(0xB982, i.dst.toReg(), i.src2, buffer),

        // Shift/Rotate
        .sllg => |i| try emitRSY(0xEB, 0x0D, i.dst.toReg(), i.src, 0, @intCast(i.imm), buffer),
        .srlg => |i| try emitRSY(0xEB, 0x0C, i.dst.toReg(), i.src, 0, @intCast(i.imm), buffer),
        .srag => |i| try emitRSY(0xEB, 0x0A, i.dst.toReg(), i.src, 0, @intCast(i.imm), buffer),
        .rllg => |i| try emitRSY(0xEB, 0x1C, i.dst.toReg(), i.src, 0, @intCast(i.imm), buffer),

        // Load
        .lg => |i| try emitRXY(0xE3, 0x04, i.dst.toReg(), i.base, 0, i.offset, buffer),
        .lghi => |i| try emitRI(0xA7, 0x9, i.dst.toReg(), @bitCast(i.imm), buffer),
        .l => |i| try emitRX(0x58, i.dst.toReg(), i.base, 0, i.offset, buffer),
        .lh => |i| try emitRX(0x48, i.dst.toReg(), i.base, 0, i.offset, buffer),
        .lb => |i| try emitRXY(0xE3, 0x76, i.dst.toReg(), i.base, 0, i.offset, buffer),

        // Store
        .stg => |i| try emitRXY(0xE3, 0x24, i.src, i.base, 0, i.offset, buffer),
        .st => |i| try emitRX(0x50, i.src, i.base, 0, i.offset, buffer),
        .sth => |i| try emitRX(0x40, i.src, i.base, 0, i.offset, buffer),
        .stc => |i| try emitRX(0x42, i.src, i.base, 0, i.offset, buffer),

        // Branch
        .brc => |i| try emitRI(0xA7, i.mask, zeroReg(), @bitCast(@as(i32, i.offset) >> 1), buffer),
        .brasl => |i| try emitRIL(0xC0, 0x5, i.link.toReg(), @bitCast(i.offset >> 1), buffer),
        .basr => |i| try emitRR(0x0D, i.link.toReg(), i.target, buffer),
        .bcr => |i| try emitRR(0x07, regAtEnc(i.mask), i.target, buffer),

        // FP
        .adbr => |i| try emitRRE(0xB31A, i.dst.toReg(), i.src2, buffer),
        .aebr => |i| try emitRRE(0xB30A, i.dst.toReg(), i.src2, buffer),
        .sdbr => |i| try emitRRE(0xB31B, i.dst.toReg(), i.src2, buffer),
        .sebr => |i| try emitRRE(0xB30B, i.dst.toReg(), i.src2, buffer),
        .mdbr => |i| try emitRRE(0xB31C, i.dst.toReg(), i.src2, buffer),
        .meebr => |i| try emitRRE(0xB317, i.dst.toReg(), i.src2, buffer),
        .ddbr => |i| try emitRRE(0xB31D, i.dst.toReg(), i.src2, buffer),
        .debr => |i| try emitRRE(0xB30D, i.dst.toReg(), i.src2, buffer),
        .ld => |i| try emitRX(0x68, i.dst.toReg(), i.base, 0, i.offset, buffer),
        .le => |i| try emitRX(0x78, i.dst.toReg(), i.base, 0, i.offset, buffer),
        .std => |i| try emitRX(0x60, i.src, i.base, 0, i.offset, buffer),
        .ste => |i| try emitRX(0x70, i.src, i.base, 0, i.offset, buffer),

        // Pseudo
        .ret => try emitRR(0x07, regAtEnc(14), zeroReg(), buffer),
    }
}

fn regEnc(r: Reg) u4 {
    const rreg = r.toRealReg() orelse unreachable;
    return @truncate(rreg.hwEnc());
}

fn regAtEnc(enc: u4) Reg {
    return Reg.fromPReg(PReg.new(.int, enc));
}

fn zeroReg() Reg {
    return regAtEnc(0);
}

// RR format (2 bytes): opcode[8] r1[4] r2[4]
fn emitRR(opcode: u8, r1: Reg, r2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const enc1 = regEnc(r1);
    const enc2 = regEnc(r2);
    const bytes = [_]u8{
        opcode,
        (@as(u8, enc1) << 4) | enc2,
    };
    try buffer.putData(&bytes);
}

// RRE format (4 bytes): opcode[16] pad[8] r1[4] r2[4]
fn emitRRE(opcode: u16, r1: Reg, r2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const enc1 = regEnc(r1);
    const enc2 = regEnc(r2);
    const bytes = [_]u8{
        @truncate(opcode >> 8),
        @truncate(opcode),
        0,
        (@as(u8, enc1) << 4) | enc2,
    };
    try buffer.putData(&bytes);
}

// RI format (4 bytes): opcode[8] r1[4] op2[4] imm[16]
fn emitRI(opcode: u8, op2: u4, r1: Reg, imm: u16, buffer: *buffer_mod.MachBuffer) !void {
    const enc1 = regEnc(r1);
    const bytes = [_]u8{
        opcode,
        (@as(u8, enc1) << 4) | op2,
        @truncate(imm >> 8),
        @truncate(imm),
    };
    try buffer.putData(&bytes);
}

// RIL format (6 bytes): opcode[8] r1[4] op2[4] imm[32]
fn emitRIL(opcode: u8, op2: u4, r1: Reg, imm: u32, buffer: *buffer_mod.MachBuffer) !void {
    const enc1 = regEnc(r1);
    const bytes = [_]u8{
        opcode,
        (@as(u8, enc1) << 4) | op2,
        @truncate(imm >> 24),
        @truncate(imm >> 16),
        @truncate(imm >> 8),
        @truncate(imm),
    };
    try buffer.putData(&bytes);
}

// RX format (4 bytes): opcode[8] r1[4] x2[4] b2[4] d2[12]
fn emitRX(opcode: u8, r1: Reg, b2: Reg, x2: u4, d2: i12, buffer: *buffer_mod.MachBuffer) !void {
    const enc1 = regEnc(r1);
    const enc_b2 = regEnc(b2);
    const disp: u12 = @bitCast(d2);
    const bytes = [_]u8{
        opcode,
        (@as(u8, enc1) << 4) | x2,
        (@as(u8, enc_b2) << 4) | @as(u8, @truncate(disp >> 8)),
        @truncate(disp),
    };
    try buffer.putData(&bytes);
}

// RXY format (6 bytes): opcode[8] r1[4] x2[4] b2[4] dl2[12] dh2[8] op2[8]
fn emitRXY(opcode: u8, op2: u8, r1: Reg, b2: Reg, x2: u4, d2: i20, buffer: *buffer_mod.MachBuffer) !void {
    const enc1 = regEnc(r1);
    const enc_b2 = regEnc(b2);
    const disp: u20 = @bitCast(d2);
    const dl: u12 = @truncate(disp);
    const dh: u8 = @truncate(disp >> 12);
    const bytes = [_]u8{
        opcode,
        (@as(u8, enc1) << 4) | x2,
        (@as(u8, enc_b2) << 4) | @as(u8, @truncate(dl >> 8)),
        @truncate(dl),
        dh,
        op2,
    };
    try buffer.putData(&bytes);
}

// RSY format (6 bytes): opcode[8] r1[4] r3[4] b2[4] d2[12] dh2[8] op2[8]
fn emitRSY(opcode: u8, op2: u8, r1: Reg, r3: Reg, b2: u4, d2: i20, buffer: *buffer_mod.MachBuffer) !void {
    const enc1 = regEnc(r1);
    const enc3 = regEnc(r3);
    const disp: u20 = @bitCast(d2);
    const dl: u12 = @truncate(disp);
    const dh: u8 = @truncate(disp >> 12);
    const bytes = [_]u8{
        opcode,
        (@as(u8, enc1) << 4) | enc3,
        (@as(u8, b2) << 4) | @as(u8, @truncate(dl >> 8)),
        @truncate(dl),
        dh,
        op2,
    };
    try buffer.putData(&bytes);
}

test "emit agr" {
    const regs = @import("regs.zig");
    var buf = buffer_mod.MachBuffer.init(testing.allocator);
    defer buf.deinit();

    try emit(.{ .agr = .{ .dst = regs.r2().toWritable(), .src1 = regs.r2(), .src2 = regs.r3() } }, &buf);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xB9, 0x08, 0x00, 0x23 }, buf.data.items);
}

test "emit lghi" {
    const regs = @import("regs.zig");
    var buf = buffer_mod.MachBuffer.init(testing.allocator);
    defer buf.deinit();

    try emit(.{ .lghi = .{ .dst = regs.r2().toWritable(), .imm = 42 } }, &buf);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xA7, 0x29, 0x00, 0x2A }, buf.data.items);
}

test "emit lg" {
    const regs = @import("regs.zig");
    var buf = buffer_mod.MachBuffer.init(testing.allocator);
    defer buf.deinit();

    try emit(.{ .lg = .{ .dst = regs.r2().toWritable(), .base = regs.r15(), .offset = 160 } }, &buf);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xE3, 0x20, 0xF0, 0xA0, 0x00, 0x04 }, buf.data.items);
}
