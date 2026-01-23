const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.x64_inst.Inst;
const OperandSize = root.x64_inst.OperandSize;
const Reg = root.x64_inst.Reg;
const PReg = root.x64_inst.PReg;
const Mem = root.x64_inst.Mem;
const CallTarget = root.x64_inst.CallTarget;
const buffer_mod = root.buffer;
const reg_mod = root.reg;

pub fn emit(inst: Inst, buffer: *buffer_mod.MachBuffer) !void {
    switch (inst) {
        .mov_rr => |i| try emitMovRR(i.dst.toReg(), i.src, i.size, buffer),
        .mov_imm => |i| try emitMovImm(i.dst.toReg(), i.imm, i.size, buffer),
        .mov_rm => |i| try emitMovRM(i.dst.toReg(), i.src, i.size, buffer),
        .mov_mr => |i| try emitMovMR(i.dst, i.src, i.size, buffer),
        .mov_mi => |i| try emitMovMI(i.dst, i.imm, i.size, buffer),
        .add_rr => |i| try emitAluRR(0x01, i.dst.toReg(), i.src, i.size, buffer),
        .add_imm => |i| try emitAluImm(0, i.dst.toReg(), i.imm, i.size, buffer),
        .sub_rr => |i| try emitAluRR(0x29, i.dst.toReg(), i.src, i.size, buffer),
        .sub_imm => |i| try emitAluImm(5, i.dst.toReg(), i.imm, i.size, buffer),
        .and_rr => |i| try emitAluRR(0x21, i.dst.toReg(), i.src, i.size, buffer),
        .and_imm => |i| try emitAluImm(4, i.dst.toReg(), i.imm, i.size, buffer),
        .or_rr => |i| try emitAluRR(0x09, i.dst.toReg(), i.src, i.size, buffer),
        .or_imm => |i| try emitAluImm(1, i.dst.toReg(), i.imm, i.size, buffer),
        .xor_rr => |i| try emitAluRR(0x31, i.dst.toReg(), i.src, i.size, buffer),
        .xor_imm => |i| try emitAluImm(6, i.dst.toReg(), i.imm, i.size, buffer),
        .cmp_rr => |i| try emitAluRR(0x39, i.lhs, i.rhs, i.size, buffer),
        .cmp_imm => |i| try emitAluImm(7, i.lhs, i.imm, i.size, buffer),
        .test_rr => |i| try emitTest(i.lhs, i.rhs, i.size, buffer),
        .test_imm => |i| try emitTestImm(i.lhs, i.imm, i.size, buffer),
        .push_r => |i| try emitPush(i.src, buffer),
        .pop_r => |i| try emitPop(i.dst.toReg(), buffer),
        .load => |i| try emitMovRM(i.dst.toReg(), i.src, i.size, buffer),
        .store => |i| try emitMovMR(i.dst, i.src, i.size, buffer),
        .lea => |i| try emitLea(i.dst.toReg(), i.src, buffer),
        .jmp => |i| try emitJmp(i.target.label, buffer),
        .jmp_cond => |i| try emitJmpCond(@intFromEnum(i.cc), i.target.label, buffer),
        .call => |i| try emitCall(i.target, buffer),
        .ret => try buffer.put(&[_]u8{0xC3}),
        .ret_imm => |i| try emitRetImm(i.imm, buffer),
        .nop => try buffer.put(&[_]u8{0x90}),
        .cmpxchg_mr => |i| try emitCmpxchg(i.dst, i.src, i.size, buffer),
        .xadd_mr => |i| try emitXadd(i.dst, i.src.toReg(), i.size, buffer),
        .xchg_mr => |i| try emitXchg(i.dst, i.src.toReg(), i.size, buffer),
        .lock_add_mi => |i| try emitLockAluMI(0, i.dst, i.imm, i.size, buffer),
        .lock_sub_mi => |i| try emitLockAluMI(5, i.dst, i.imm, i.size, buffer),
        .lock_and_mi => |i| try emitLockAluMI(4, i.dst, i.imm, i.size, buffer),
        .lock_or_mi => |i| try emitLockAluMI(1, i.dst, i.imm, i.size, buffer),
        .lock_xor_mi => |i| try emitLockAluMI(6, i.dst, i.imm, i.size, buffer),
        .lfence => try buffer.put(&[_]u8{ 0x0F, 0xAE, 0xE8 }),
        .sfence => try buffer.put(&[_]u8{ 0x0F, 0xAE, 0xF8 }),
        .mfence => try buffer.put(&[_]u8{ 0x0F, 0xAE, 0xF0 }),
        // SIMD moves
        .movdqa_rr => |i| try emitSse2RR(0x6F, i.dst.toReg(), i.src, buffer),
        .movdqa_mr => |i| try emitSse2MR(0x7F, i.dst, i.src, buffer),
        .movdqa_rm => |i| try emitSse2RM(0x6F, i.dst.toReg(), i.src, buffer),
        .movdqu_rr => |i| try emitSse2UnalignedRR(0x6F, i.dst.toReg(), i.src, buffer),
        .movdqu_mr => |i| try emitSse2UnalignedMR(0x7F, i.dst, i.src, buffer),
        .movdqu_rm => |i| try emitSse2UnalignedRM(0x6F, i.dst.toReg(), i.src, buffer),
        .movups_rr => |i| try emitSseRR(0x10, i.dst.toReg(), i.src, buffer),
        .movups_mr => |i| try emitSseMR(0x11, i.dst, i.src, buffer),
        .movups_rm => |i| try emitSseRM(0x10, i.dst.toReg(), i.src, buffer),
        .movupd_rr => |i| try emitSse2RR(0x10, i.dst.toReg(), i.src, buffer),
        .movupd_mr => |i| try emitSse2MR(0x11, i.dst, i.src, buffer),
        .movupd_rm => |i| try emitSse2RM(0x10, i.dst.toReg(), i.src, buffer),
        .movss_rr => |i| try emitSseScalarRR(0xF3, 0x10, i.dst.toReg(), i.src, buffer),
        .movss_mr => |i| try emitSseScalarMR(0xF3, 0x11, i.dst, i.src, buffer),
        .movss_rm => |i| try emitSseScalarRM(0xF3, 0x10, i.dst.toReg(), i.src, buffer),
        .movsd_rr => |i| try emitSseScalarRR(0xF2, 0x10, i.dst.toReg(), i.src, buffer),
        .movsd_mr => |i| try emitSseScalarMR(0xF2, 0x11, i.dst, i.src, buffer),
        .movsd_rm => |i| try emitSseScalarRM(0xF2, 0x10, i.dst.toReg(), i.src, buffer),
        // SIMD integer arithmetic
        .paddd_rr => |i| try emitSse2RR(0xFE, i.dst.toReg(), i.src, buffer),
        .paddq_rr => |i| try emitSse2RR(0xD4, i.dst.toReg(), i.src, buffer),
        .psubd_rr => |i| try emitSse2RR(0xFA, i.dst.toReg(), i.src, buffer),
        .psubq_rr => |i| try emitSse2RR(0xFB, i.dst.toReg(), i.src, buffer),
        .pmulld_rr => |i| try emitSse41RR(0x40, i.dst.toReg(), i.src, buffer),
        // SIMD bitwise
        .pand_rr => |i| try emitSse2RR(0xDB, i.dst.toReg(), i.src, buffer),
        .por_rr => |i| try emitSse2RR(0xEB, i.dst.toReg(), i.src, buffer),
        .pxor_rr => |i| try emitSse2RR(0xEF, i.dst.toReg(), i.src, buffer),
        .pandn_rr => |i| try emitSse2RR(0xDF, i.dst.toReg(), i.src, buffer),
        // SIMD comparison
        .pcmpeqd_rr => |i| try emitSse2RR(0x76, i.dst.toReg(), i.src, buffer),
        .pcmpeqq_rr => |i| try emitSse41RR(0x29, i.dst.toReg(), i.src, buffer),
        .pcmpgtd_rr => |i| try emitSse2RR(0x66, i.dst.toReg(), i.src, buffer),
        .pcmpgtq_rr => |i| try emitSse42RR(0x37, i.dst.toReg(), i.src, buffer),
        // SIMD shifts
        .pslld_imm => |i| try emitSse2ShiftImm(0xF2, 6, i.dst.toReg(), i.count, buffer),
        .psrld_imm => |i| try emitSse2ShiftImm(0xD2, 2, i.dst.toReg(), i.count, buffer),
        .psrad_imm => |i| try emitSse2ShiftImm(0xE2, 4, i.dst.toReg(), i.count, buffer),
        .psllq_imm => |i| try emitSse2ShiftImm(0xF3, 6, i.dst.toReg(), i.count, buffer),
        .psrlq_imm => |i| try emitSse2ShiftImm(0xD3, 2, i.dst.toReg(), i.count, buffer),
        // SIMD shuffles
        .shufps_rr => |i| try emitSseShuffleRR(0xC6, i.dst.toReg(), i.src, i.imm, buffer),
        .shufpd_rr => |i| try emitSse2ShuffleRR(0xC6, i.dst.toReg(), i.src, i.imm, buffer),
        .pshufd_rr => |i| try emitSse2ShuffleRR(0x70, i.dst.toReg(), i.src, i.imm, buffer),
        // SIMD FP arithmetic
        .addps_rr => |i| try emitSseRR(0x58, i.dst.toReg(), i.src, buffer),
        .addpd_rr => |i| try emitSse2RR(0x58, i.dst.toReg(), i.src, buffer),
        .subps_rr => |i| try emitSseRR(0x5C, i.dst.toReg(), i.src, buffer),
        .subpd_rr => |i| try emitSse2RR(0x5C, i.dst.toReg(), i.src, buffer),
        .mulps_rr => |i| try emitSseRR(0x59, i.dst.toReg(), i.src, buffer),
        .mulpd_rr => |i| try emitSse2RR(0x59, i.dst.toReg(), i.src, buffer),
        .divps_rr => |i| try emitSseRR(0x5E, i.dst.toReg(), i.src, buffer),
        .divpd_rr => |i| try emitSse2RR(0x5E, i.dst.toReg(), i.src, buffer),
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

/// Encode SIB byte.
fn sib(scale: u8, idx: u8, base: u8) u8 {
    const scale_bits: u8 = switch (scale) {
        1 => 0b00,
        2 => 0b01,
        4 => 0b10,
        8 => 0b11,
        else => 0b00,
    };
    return (scale_bits << 6) | ((idx & 0x07) << 3) | (base & 0x07);
}

/// Emit ModR/M and optional SIB for memory operand.
fn emitModrmMem(reg: Reg, mem: Mem, buffer: *buffer_mod.MachBuffer) !void {
    const reg_enc = hwEnc(reg);

    // Check if we need SIB byte
    const needs_sib = mem.idx != null or (mem.base != null and hwEnc(mem.base.?) == 4); // RSP/R12 requires SIB

    if (mem.base) |base| {
        const base_enc = hwEnc(base);
        const disp = mem.disp;

        // Determine mod bits based on displacement
        const mod: u8 = if (disp == 0 and base_enc != 5) // RBP/R13 always needs disp
            0b00 // No displacement
        else if (disp >= -128 and disp <= 127)
            0b01 // disp8
        else
            0b10; // disp32

        if (needs_sib) {
            // Emit ModR/M with SIB indicator (rm = 100)
            try buffer.put(&[_]u8{modrm(mod, reg_enc, 0b100)});

            // Emit SIB byte
            if (mem.idx) |idx| {
                const idx_enc = hwEnc(idx);
                try buffer.put(&[_]u8{sib(mem.scale, idx_enc, base_enc)});
            } else {
                // No index - use RSP (100) as "no index" marker
                try buffer.put(&[_]u8{sib(1, 0b100, base_enc)});
            }
        } else {
            // Direct ModR/M encoding (no SIB)
            try buffer.put(&[_]u8{modrm(mod, reg_enc, base_enc)});
        }

        // Emit displacement
        if (mod == 0b01) {
            try buffer.put(&[_]u8{@intCast(@as(u8, @bitCast(@as(i8, @intCast(disp)))))});
        } else if (mod == 0b10 or base_enc == 5) {
            const disp32: u32 = @bitCast(@as(i32, @intCast(disp)));
            try buffer.put(std.mem.asBytes(&disp32));
        }
    } else {
        // RIP-relative or absolute addressing
        // For now: disp32 only (mod=00, rm=101)
        try buffer.put(&[_]u8{modrm(0b00, reg_enc, 0b101)});
        const disp32: u32 = @bitCast(mem.disp);
        try buffer.put(std.mem.asBytes(&disp32));
    }
}

/// MOV reg, mem
fn emitMovRM(dst: Reg, src: Mem, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(size, dst, src.base, buffer);
    try buffer.put(&[_]u8{0x8B}); // MOV r, r/m
    try emitModrmMem(dst, src, buffer);
}

/// MOV mem, reg
fn emitMovMR(dst: Mem, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(size, src, dst.base, buffer);
    try buffer.put(&[_]u8{0x89}); // MOV r/m, r
    try emitModrmMem(src, dst, buffer);
}

/// MOV mem, imm
fn emitMovMI(dst: Mem, imm: i32, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(size, null, dst.base, buffer);
    try buffer.put(&[_]u8{0xC7}); // MOV r/m, imm32
    try emitModrmMem(Reg.fromPReg(PReg.rax()), dst, buffer); // Use /0 subopcode
    const imm32: u32 = @bitCast(imm);
    try buffer.put(std.mem.asBytes(&imm32));
}

/// LEA - Load Effective Address
fn emitLea(dst: Reg, src: Mem, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(.size64, dst, src.base, buffer);
    try buffer.put(&[_]u8{0x8D}); // LEA
    try emitModrmMem(dst, src, buffer);
}

/// ALU operation reg, imm (ADD/SUB/AND/OR/XOR/CMP with immediate)
fn emitAluImm(subopcode: u8, dst: Reg, imm: i32, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(size, null, dst, buffer);

    // Check if imm fits in simm8
    const fits_simm8 = imm >= -128 and imm <= 127;

    if (fits_simm8 and size != .size8) {
        // Use 0x83 encoding with simm8
        try buffer.put(&[_]u8{0x83});
        try buffer.put(&[_]u8{modrm(0b11, subopcode, hwEnc(dst))});
        try buffer.put(&[_]u8{@intCast(@as(u8, @bitCast(@as(i8, @intCast(imm)))))});
    } else if (size == .size8) {
        // 8-bit operation
        try buffer.put(&[_]u8{0x80});
        try buffer.put(&[_]u8{modrm(0b11, subopcode, hwEnc(dst))});
        try buffer.put(&[_]u8{@intCast(@as(u8, @bitCast(@as(i8, @intCast(imm)))))});
    } else {
        // Full 32-bit immediate
        if (hwEnc(dst) == 0 and subopcode != 4) { // Special encoding for AL/AX/EAX/RAX, except AND
            const base_opcode: u8 = switch (subopcode) {
                0 => 0x05, // ADD
                1 => 0x0D, // OR
                5 => 0x2D, // SUB
                6 => 0x35, // XOR
                7 => 0x3D, // CMP
                else => 0x81,
            };
            try buffer.put(&[_]u8{base_opcode});
        } else {
            try buffer.put(&[_]u8{0x81});
            try buffer.put(&[_]u8{modrm(0b11, subopcode, hwEnc(dst))});
        }
        const imm32: u32 = @bitCast(imm);
        try buffer.put(std.mem.asBytes(&imm32));
    }
}

/// TEST reg, reg
fn emitTest(lhs: Reg, rhs: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(size, rhs, lhs, buffer);
    try buffer.put(&[_]u8{0x85}); // TEST r/m, r
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(rhs), hwEnc(lhs))});
}

/// TEST reg, imm
fn emitTestImm(lhs: Reg, imm: i32, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(size, null, lhs, buffer);

    if (hwEnc(lhs) == 0) {
        // Special encoding for AL/AX/EAX/RAX
        try buffer.put(&[_]u8{0xA9});
    } else {
        try buffer.put(&[_]u8{0xF7});
        try buffer.put(&[_]u8{modrm(0b11, 0, hwEnc(lhs))});
    }

    if (size == .size8) {
        try buffer.put(&[_]u8{@intCast(@as(u8, @bitCast(@as(i8, @intCast(imm)))))});
    } else {
        const imm32: u32 = @bitCast(imm);
        try buffer.put(std.mem.asBytes(&imm32));
    }
}

/// CALL
fn emitCall(target: CallTarget, buffer: *buffer_mod.MachBuffer) !void {
    switch (target) {
        .direct => {
            // Direct call: E8 rel32
            try buffer.put(&[_]u8{0xE8});
            // Placeholder - would need symbol resolution
            try buffer.put(&[_]u8{ 0x00, 0x00, 0x00, 0x00 });
        },
        .indirect => |reg| {
            // Indirect call: FF /2
            try emitRex(.size64, null, reg, buffer);
            try buffer.put(&[_]u8{0xFF});
            try buffer.put(&[_]u8{modrm(0b11, 2, hwEnc(reg))});
        },
    }
}

/// RET imm16
fn emitRetImm(imm: u16, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0xC2});
    try buffer.put(std.mem.asBytes(&imm));
}

/// LOCK CMPXCHG mem, reg (0xF0 0x0F 0xB1 for 32/64-bit)
fn emitCmpxchg(mem: Mem, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0xF0}); // LOCK prefix
    try emitRex(size, src, mem.base, buffer);

    if (size == .size8) {
        try buffer.put(&[_]u8{0x0F, 0xB0}); // CMPXCHG r/m8, r8
    } else {
        try buffer.put(&[_]u8{0x0F, 0xB1}); // CMPXCHG r/m, r
    }
    try emitModrmMem(src, mem, buffer);
}

/// LOCK XADD mem, reg (0xF0 0x0F 0xC1 for 32/64-bit)
fn emitXadd(mem: Mem, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0xF0}); // LOCK prefix
    try emitRex(size, src, mem.base, buffer);

    if (size == .size8) {
        try buffer.put(&[_]u8{0x0F, 0xC0}); // XADD r/m8, r8
    } else {
        try buffer.put(&[_]u8{0x0F, 0xC1}); // XADD r/m, r
    }
    try emitModrmMem(src, mem, buffer);
}

/// XCHG mem, reg (0x87 for 32/64-bit, LOCK implicit)
fn emitXchg(mem: Mem, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(size, src, mem.base, buffer);

    if (size == .size8) {
        try buffer.put(&[_]u8{0x86}); // XCHG r/m8, r8
    } else {
        try buffer.put(&[_]u8{0x87}); // XCHG r/m, r
    }
    try emitModrmMem(src, mem, buffer);
}

/// LOCK ALU mem, imm (ADD/SUB/AND/OR/XOR with LOCK prefix)
fn emitLockAluMI(subopcode: u8, mem: Mem, imm: i32, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0xF0}); // LOCK prefix
    try emitRex(size, null, mem.base, buffer);

    const fits_simm8 = imm >= -128 and imm <= 127;

    if (fits_simm8 and size != .size8) {
        try buffer.put(&[_]u8{0x83}); // ALU r/m, simm8
        try emitModrmMem(Reg.fromPReg(PReg.new(@intCast(subopcode), reg_mod.RegClass.int)), mem, buffer);
        try buffer.put(&[_]u8{@intCast(@as(u8, @bitCast(@as(i8, @intCast(imm)))))});
    } else if (size == .size8) {
        try buffer.put(&[_]u8{0x80}); // ALU r/m8, imm8
        try emitModrmMem(Reg.fromPReg(PReg.new(@intCast(subopcode), reg_mod.RegClass.int)), mem, buffer);
        try buffer.put(&[_]u8{@intCast(@as(u8, @bitCast(@as(i8, @intCast(imm)))))});
    } else {
        try buffer.put(&[_]u8{0x81}); // ALU r/m, imm32
        try emitModrmMem(Reg.fromPReg(PReg.new(@intCast(subopcode), reg_mod.RegClass.int)), mem, buffer);
        const imm32: u32 = @bitCast(imm);
        try buffer.put(std.mem.asBytes(&imm32));
    }
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
    try testing.expectEqual(@as(u8, 0x50), buffer.data.items[0]);
    try testing.expectEqual(@as(u8, 0x58), buffer.data.items[1]);
}

test "emit mov [base+disp], reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);

    const mem = Mem.base_disp(r0, 8);
    try emit(.{ .mov_mr = .{
        .dst = mem,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    // REX.W + opcode 0x89 + ModR/M + disp8
    try testing.expect(buffer.data.items.len >= 4);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x89), buffer.data.items[1]); // MOV r/m, r
}

test "emit mov reg, [base]" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    const mem = Mem.base_only(r0);
    try emit(.{ .mov_rm = .{
        .dst = wr1,
        .src = mem,
        .size = .size64,
    } }, &buffer);

    // REX.W + opcode 0x8B + ModR/M
    try testing.expect(buffer.data.items.len >= 3);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x8B), buffer.data.items[1]); // MOV r, r/m
}

test "emit lea" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    const mem = Mem.base_disp(r0, 16);
    try emit(.{ .lea = .{
        .dst = wr1,
        .src = mem,
    } }, &buffer);

    // REX.W + opcode 0x8D + ModR/M + disp8
    try testing.expect(buffer.data.items.len >= 4);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x8D), buffer.data.items[1]); // LEA
}

test "emit sib encoding" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    // [base + idx*4 + disp]
    const mem = Mem.new(r0, r1, 4, 8);
    try emit(.{ .mov_mr = .{
        .dst = mem,
        .src = r2,
        .size = .size64,
    } }, &buffer);

    // REX.W + opcode + ModR/M + SIB + disp8
    try testing.expect(buffer.data.items.len >= 5);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x89), buffer.data.items[1]); // MOV r/m, r
}

// ============ SSE/SSE2 Encoding Helpers ============

/// Emit SSE instruction (no prefix, 0x0F opcode map).
fn emitSseRR(opcode: u8, dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(.size64, dst, src, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(dst), hwEnc(src))});
}

fn emitSseMR(opcode: u8, dst: Mem, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(.size64, src, dst.base, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try emitModrmMem(src, dst, buffer);
}

fn emitSseRM(opcode: u8, dst: Reg, src: Mem, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(.size64, dst, src.base, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try emitModrmMem(dst, src, buffer);
}

/// Emit SSE2 instruction (0x66 prefix, 0x0F opcode map).
fn emitSse2RR(opcode: u8, dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0x66}); // SSE2 prefix
    try emitRex(.size64, dst, src, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(dst), hwEnc(src))});
}

fn emitSse2MR(opcode: u8, dst: Mem, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0x66}); // SSE2 prefix
    try emitRex(.size64, src, dst.base, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try emitModrmMem(src, dst, buffer);
}

fn emitSse2RM(opcode: u8, dst: Reg, src: Mem, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0x66}); // SSE2 prefix
    try emitRex(.size64, dst, src.base, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try emitModrmMem(dst, src, buffer);
}

/// Emit SSE2 unaligned (0xF3 prefix for movdqu).
fn emitSse2UnalignedRR(opcode: u8, dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0xF3}); // Unaligned prefix
    try emitRex(.size64, dst, src, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(dst), hwEnc(src))});
}

fn emitSse2UnalignedMR(opcode: u8, dst: Mem, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0xF3}); // Unaligned prefix
    try emitRex(.size64, src, dst.base, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try emitModrmMem(src, dst, buffer);
}

fn emitSse2UnalignedRM(opcode: u8, dst: Reg, src: Mem, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0xF3}); // Unaligned prefix
    try emitRex(.size64, dst, src.base, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try emitModrmMem(dst, src, buffer);
}

/// Emit SSE scalar instruction (F3/F2 prefix, 0x0F opcode map).
fn emitSseScalarRR(prefix: u8, opcode: u8, dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{prefix});
    try emitRex(.size64, dst, src, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(dst), hwEnc(src))});
}

fn emitSseScalarMR(prefix: u8, opcode: u8, dst: Mem, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{prefix});
    try emitRex(.size64, src, dst.base, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try emitModrmMem(src, dst, buffer);
}

fn emitSseScalarRM(prefix: u8, opcode: u8, dst: Reg, src: Mem, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{prefix});
    try emitRex(.size64, dst, src.base, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try emitModrmMem(dst, src, buffer);
}

/// Emit SSE4.1 instruction (0x66 0x0F 0x38 prefix).
fn emitSse41RR(opcode: u8, dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0x66}); // SSE4.1 prefix
    try emitRex(.size64, dst, src, buffer);
    try buffer.put(&[_]u8{ 0x0F, 0x38, opcode });
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(dst), hwEnc(src))});
}

/// Emit SSE4.2 instruction (0x66 0x0F 0x3A prefix).
fn emitSse42RR(opcode: u8, dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0x66}); // SSE4.2 prefix
    try emitRex(.size64, dst, src, buffer);
    try buffer.put(&[_]u8{ 0x0F, 0x3A, opcode });
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(dst), hwEnc(src))});
}

/// Emit SSE2 shift immediate.
fn emitSse2ShiftImm(opcode: u8, subop: u8, dst: Reg, count: u8, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0x66}); // SSE2 prefix
    try emitRex(.size64, null, dst, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try buffer.put(&[_]u8{modrm(0b11, subop, hwEnc(dst))});
    try buffer.put(&[_]u8{count});
}

/// Emit SSE shuffle with immediate.
fn emitSseShuffleRR(opcode: u8, dst: Reg, src: Reg, imm: u8, buffer: *buffer_mod.MachBuffer) !void {
    try emitRex(.size64, dst, src, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(dst), hwEnc(src))});
    try buffer.put(&[_]u8{imm});
}

/// Emit SSE2 shuffle with immediate.
fn emitSse2ShuffleRR(opcode: u8, dst: Reg, src: Reg, imm: u8, buffer: *buffer_mod.MachBuffer) !void {
    try buffer.put(&[_]u8{0x66}); // SSE2 prefix
    try emitRex(.size64, dst, src, buffer);
    try buffer.put(&[_]u8{ 0x0F, opcode });
    try buffer.put(&[_]u8{modrm(0b11, hwEnc(dst), hwEnc(src))});
    try buffer.put(&[_]u8{imm});
}
