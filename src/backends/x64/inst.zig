const std = @import("std");
const testing = std.testing;

const root = @import("root");
const reg_mod = root.reg;

pub const Reg = reg_mod.Reg;
pub const PReg = reg_mod.PReg;
pub const VReg = reg_mod.VReg;
pub const WritableReg = reg_mod.WritableReg;

/// x86-64 machine instruction.
/// Minimal bootstrap set - full x64 backend needs ~100+ variants.
pub const Inst = union(enum) {
    /// Move register to register.
    mov_rr: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },

    /// Move immediate to register.
    mov_imm: struct {
        dst: WritableReg,
        imm: i64,
        size: OperandSize,
    },

    /// Add register to register.
    add_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Subtract register from register.
    sub_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Add immediate to register.
    add_imm: struct {
        dst: WritableReg, // Also source
        imm: i32,
        size: OperandSize,
    },

    /// Subtract immediate from register.
    sub_imm: struct {
        dst: WritableReg, // Also source
        imm: i32,
        size: OperandSize,
    },

    /// Bitwise AND register with register.
    and_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Bitwise AND immediate with register.
    and_imm: struct {
        dst: WritableReg, // Also source
        imm: i32,
        size: OperandSize,
    },

    /// Bitwise OR register with register.
    or_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Bitwise OR immediate with register.
    or_imm: struct {
        dst: WritableReg, // Also source
        imm: i32,
        size: OperandSize,
    },

    /// Bitwise XOR register with register.
    xor_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Bitwise XOR immediate with register.
    xor_imm: struct {
        dst: WritableReg, // Also source
        imm: i32,
        size: OperandSize,
    },

    /// Compare register with register (sets flags, doesn't store result).
    cmp_rr: struct {
        lhs: Reg,
        rhs: Reg,
        size: OperandSize,
    },

    /// Compare register with immediate.
    cmp_imm: struct {
        lhs: Reg,
        imm: i32,
        size: OperandSize,
    },

    /// Test register with register (bitwise AND, sets flags only).
    test_rr: struct {
        lhs: Reg,
        rhs: Reg,
        size: OperandSize,
    },

    /// Test register with immediate.
    test_imm: struct {
        lhs: Reg,
        imm: i32,
        size: OperandSize,
    },

    /// Shift left logical.
    shl_rr: struct {
        dst: WritableReg, // Also source
        count: Reg, // Must be CL
        size: OperandSize,
    },

    /// Shift left logical by immediate.
    shl_imm: struct {
        dst: WritableReg, // Also source
        count: u8,
        size: OperandSize,
    },

    /// Shift right logical.
    shr_rr: struct {
        dst: WritableReg, // Also source
        count: Reg, // Must be CL
        size: OperandSize,
    },

    /// Shift right logical by immediate.
    shr_imm: struct {
        dst: WritableReg, // Also source
        count: u8,
        size: OperandSize,
    },

    /// Shift right arithmetic.
    sar_rr: struct {
        dst: WritableReg, // Also source
        count: Reg, // Must be CL
        size: OperandSize,
    },

    /// Shift right arithmetic by immediate.
    sar_imm: struct {
        dst: WritableReg, // Also source
        count: u8,
        size: OperandSize,
    },

    /// Rotate left.
    rol_rr: struct {
        dst: WritableReg, // Also source
        count: Reg, // Must be CL
        size: OperandSize,
    },

    /// Rotate left by immediate.
    rol_imm: struct {
        dst: WritableReg, // Also source
        count: u8,
        size: OperandSize,
    },

    /// Rotate right.
    ror_rr: struct {
        dst: WritableReg, // Also source
        count: Reg, // Must be CL
        size: OperandSize,
    },

    /// Rotate right by immediate.
    ror_imm: struct {
        dst: WritableReg, // Also source
        count: u8,
        size: OperandSize,
    },

    /// Multiply (unsigned).
    imul_rr: struct {
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize,
    },

    /// Multiply by immediate.
    imul_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: i32,
        size: OperandSize,
    },

    /// Negate.
    neg: struct {
        dst: WritableReg, // Also source
        size: OperandSize,
    },

    /// Bitwise NOT.
    not: struct {
        dst: WritableReg, // Also source
        size: OperandSize,
    },

    /// Push register to stack.
    push_r: struct {
        src: Reg,
    },

    /// Pop from stack to register.
    pop_r: struct {
        dst: WritableReg,
    },

    /// Load from memory to register.
    load: struct {
        dst: WritableReg,
        src: Mem,
        size: OperandSize,
    },

    /// Store from register to memory.
    store: struct {
        dst: Mem,
        src: Reg,
        size: OperandSize,
    },

    /// Load effective address (LEA).
    lea: struct {
        dst: WritableReg,
        src: Mem,
    },

    /// Move with memory source.
    mov_rm: struct {
        dst: WritableReg,
        src: Mem,
        size: OperandSize,
    },

    /// Move with memory destination.
    mov_mr: struct {
        dst: Mem,
        src: Reg,
        size: OperandSize,
    },

    /// Move immediate to memory.
    mov_mi: struct {
        dst: Mem,
        imm: i32,
        size: OperandSize,
    },

    /// Unconditional jump.
    jmp: struct {
        target: BranchTarget,
    },

    /// Conditional jump.
    jmp_cond: struct {
        cc: CondCode,
        target: BranchTarget,
    },

    /// Call function.
    call: struct {
        target: CallTarget,
    },

    /// Set byte on condition.
    setcc: struct {
        cc: CondCode,
        dst: WritableReg, // 8-bit register
    },

    /// Conditional move.
    cmov: struct {
        cc: CondCode,
        dst: WritableReg, // Also source
        src: Reg,
        size: OperandSize, // 16/32/64 only
    },

    /// Return from function.
    ret,

    /// Return with immediate (pop bytes).
    ret_imm: struct {
        imm: u16,
    },

    /// No operation.
    nop,

    // ============ SIMD/XMM Instructions ============

    /// Move aligned packed data (SSE2).
    movdqa_rr: struct {
        dst: WritableReg, // XMM
        src: Reg, // XMM
    },

    /// Move aligned packed data to memory (SSE2).
    movdqa_mr: struct {
        dst: Mem,
        src: Reg, // XMM
    },

    /// Move aligned packed data from memory (SSE2).
    movdqa_rm: struct {
        dst: WritableReg, // XMM
        src: Mem,
    },

    /// Move unaligned packed data (SSE2).
    movdqu_rr: struct {
        dst: WritableReg, // XMM
        src: Reg, // XMM
    },

    /// Move unaligned packed data to memory (SSE2).
    movdqu_mr: struct {
        dst: Mem,
        src: Reg, // XMM
    },

    /// Move unaligned packed data from memory (SSE2).
    movdqu_rm: struct {
        dst: WritableReg, // XMM
        src: Mem,
    },

    /// Move unaligned packed single-precision (SSE).
    movups_rr: struct {
        dst: WritableReg, // XMM
        src: Reg, // XMM
    },

    /// Move unaligned packed single-precision to memory (SSE).
    movups_mr: struct {
        dst: Mem,
        src: Reg, // XMM
    },

    /// Move unaligned packed single-precision from memory (SSE).
    movups_rm: struct {
        dst: WritableReg, // XMM
        src: Mem,
    },

    /// Move unaligned packed double-precision (SSE2).
    movupd_rr: struct {
        dst: WritableReg, // XMM
        src: Reg, // XMM
    },

    /// Move unaligned packed double-precision to memory (SSE2).
    movupd_mr: struct {
        dst: Mem,
        src: Reg, // XMM
    },

    /// Move unaligned packed double-precision from memory (SSE2).
    movupd_rm: struct {
        dst: WritableReg, // XMM
        src: Mem,
    },

    /// Move scalar single-precision (SSE).
    movss_rr: struct {
        dst: WritableReg, // XMM
        src: Reg, // XMM
    },

    /// Move scalar single-precision to memory (SSE).
    movss_mr: struct {
        dst: Mem,
        src: Reg, // XMM
    },

    /// Move scalar single-precision from memory (SSE).
    movss_rm: struct {
        dst: WritableReg, // XMM
        src: Mem,
    },

    /// Move scalar double-precision (SSE2).
    movsd_rr: struct {
        dst: WritableReg, // XMM
        src: Reg, // XMM
    },

    /// Move scalar double-precision to memory (SSE2).
    movsd_mr: struct {
        dst: Mem,
        src: Reg, // XMM
    },

    /// Move scalar double-precision from memory (SSE2).
    movsd_rm: struct {
        dst: WritableReg, // XMM
        src: Mem,
    },

    /// Packed add doubleword (SSE2).
    paddd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed add quadword (SSE2).
    paddq_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed subtract doubleword (SSE2).
    psubd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed subtract quadword (SSE2).
    psubq_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed multiply low doubleword (SSE4.1).
    pmulld_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed bitwise AND (SSE2).
    pand_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed bitwise OR (SSE2).
    por_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed bitwise XOR (SSE2).
    pxor_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed bitwise AND-NOT (SSE2).
    pandn_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed compare equal doubleword (SSE2).
    pcmpeqd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed compare equal quadword (SSE4.1).
    pcmpeqq_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed compare greater-than doubleword (SSE2).
    pcmpgtd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed compare greater-than quadword (SSE4.2).
    pcmpgtq_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Packed shift left logical doubleword (SSE2).
    pslld_imm: struct {
        dst: WritableReg, // XMM
        count: u8,
    },

    /// Packed shift right logical doubleword (SSE2).
    psrld_imm: struct {
        dst: WritableReg, // XMM
        count: u8,
    },

    /// Packed shift right arithmetic doubleword (SSE2).
    psrad_imm: struct {
        dst: WritableReg, // XMM
        count: u8,
    },

    /// Packed shift left logical quadword (SSE2).
    psllq_imm: struct {
        dst: WritableReg, // XMM
        count: u8,
    },

    /// Packed shift right logical quadword (SSE2).
    psrlq_imm: struct {
        dst: WritableReg, // XMM
        count: u8,
    },

    /// Shuffle packed single-precision (SSE).
    shufps_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
        imm: u8,
    },

    /// Shuffle packed double-precision (SSE2).
    shufpd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
        imm: u8,
    },

    /// Shuffle packed doublewords (SSE2).
    pshufd_rr: struct {
        dst: WritableReg, // XMM
        src: Reg, // XMM
        imm: u8,
    },

    /// Add packed single-precision (SSE).
    addps_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Add packed double-precision (SSE2).
    addpd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Subtract packed single-precision (SSE).
    subps_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Subtract packed double-precision (SSE2).
    subpd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Multiply packed single-precision (SSE).
    mulps_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Multiply packed double-precision (SSE2).
    mulpd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Divide packed single-precision (SSE).
    divps_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Divide packed double-precision (SSE2).
    divpd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Add scalar single-precision (SSE).
    addss_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Add scalar double-precision (SSE2).
    addsd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Subtract scalar single-precision (SSE).
    subss_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Subtract scalar double-precision (SSE2).
    subsd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Multiply scalar single-precision (SSE).
    mulss_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Multiply scalar double-precision (SSE2).
    mulsd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Divide scalar single-precision (SSE).
    divss_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Divide scalar double-precision (SSE2).
    divsd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Square root scalar single-precision (SSE).
    sqrtss_rr: struct {
        dst: WritableReg, // XMM
        src: Reg, // XMM
    },

    /// Square root scalar double-precision (SSE2).
    sqrtsd_rr: struct {
        dst: WritableReg, // XMM
        src: Reg, // XMM
    },

    /// Min scalar single-precision (SSE).
    minss_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Min scalar double-precision (SSE2).
    minsd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Max scalar single-precision (SSE).
    maxss_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    /// Max scalar double-precision (SSE2).
    maxsd_rr: struct {
        dst: WritableReg, // XMM, also src1
        src: Reg, // XMM
    },

    // ============ Atomic Instructions ============

    /// Compare and exchange (lock prefix implied).
    cmpxchg_mr: struct {
        dst: Mem,
        src: Reg, // Value to store
        size: OperandSize, // RAX implicit src/dst
    },

    /// Exchange and add (lock prefix implied).
    xadd_mr: struct {
        dst: Mem,
        src: WritableReg, // Also receives old value
        size: OperandSize,
    },

    /// Atomic exchange (lock prefix implied).
    xchg_mr: struct {
        dst: Mem,
        src: WritableReg, // Also receives old value
        size: OperandSize,
    },

    /// Atomic add to memory (lock prefix).
    lock_add_mi: struct {
        dst: Mem,
        imm: i32,
        size: OperandSize,
    },

    /// Atomic sub from memory (lock prefix).
    lock_sub_mi: struct {
        dst: Mem,
        imm: i32,
        size: OperandSize,
    },

    /// Atomic and with memory (lock prefix).
    lock_and_mi: struct {
        dst: Mem,
        imm: i32,
        size: OperandSize,
    },

    /// Atomic or with memory (lock prefix).
    lock_or_mi: struct {
        dst: Mem,
        imm: i32,
        size: OperandSize,
    },

    /// Atomic xor with memory (lock prefix).
    lock_xor_mi: struct {
        dst: Mem,
        imm: i32,
        size: OperandSize,
    },

    /// Load fence.
    lfence,

    /// Store fence.
    sfence,

    /// Memory fence.
    mfence,

    pub fn getOperands(self: *const Inst, c: *OperandCollector) !void {
        return inst_impl.getOperands(self, c);
    }

    pub fn format(
        self: Inst,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .mov_rr => |i| try writer.print("mov.{} {}, {}", .{ i.size, i.dst, i.src }),
            .mov_imm => |i| try writer.print("mov.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .add_rr => |i| try writer.print("add.{} {}, {}", .{ i.size, i.dst, i.src }),
            .add_imm => |i| try writer.print("add.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .sub_rr => |i| try writer.print("sub.{} {}, {}", .{ i.size, i.dst, i.src }),
            .sub_imm => |i| try writer.print("sub.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .and_rr => |i| try writer.print("and.{} {}, {}", .{ i.size, i.dst, i.src }),
            .and_imm => |i| try writer.print("and.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .or_rr => |i| try writer.print("or.{} {}, {}", .{ i.size, i.dst, i.src }),
            .or_imm => |i| try writer.print("or.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .xor_rr => |i| try writer.print("xor.{} {}, {}", .{ i.size, i.dst, i.src }),
            .xor_imm => |i| try writer.print("xor.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .cmp_rr => |i| try writer.print("cmp.{} {}, {}", .{ i.size, i.lhs, i.rhs }),
            .cmp_imm => |i| try writer.print("cmp.{} {}, ${d}", .{ i.size, i.lhs, i.imm }),
            .test_rr => |i| try writer.print("test.{} {}, {}", .{ i.size, i.lhs, i.rhs }),
            .test_imm => |i| try writer.print("test.{} {}, ${d}", .{ i.size, i.lhs, i.imm }),
            .shl_rr => |i| try writer.print("shl.{} {}, {}", .{ i.size, i.dst, i.count }),
            .shl_imm => |i| try writer.print("shl.{} {}, ${d}", .{ i.size, i.dst, i.count }),
            .shr_rr => |i| try writer.print("shr.{} {}, {}", .{ i.size, i.dst, i.count }),
            .shr_imm => |i| try writer.print("shr.{} {}, ${d}", .{ i.size, i.dst, i.count }),
            .sar_rr => |i| try writer.print("sar.{} {}, {}", .{ i.size, i.dst, i.count }),
            .sar_imm => |i| try writer.print("sar.{} {}, ${d}", .{ i.size, i.dst, i.count }),
            .rol_rr => |i| try writer.print("rol.{} {}, {}", .{ i.size, i.dst, i.count }),
            .rol_imm => |i| try writer.print("rol.{} {}, ${d}", .{ i.size, i.dst, i.count }),
            .ror_rr => |i| try writer.print("ror.{} {}, {}", .{ i.size, i.dst, i.count }),
            .ror_imm => |i| try writer.print("ror.{} {}, ${d}", .{ i.size, i.dst, i.count }),
            .imul_rr => |i| try writer.print("imul.{} {}, {}", .{ i.size, i.dst, i.src }),
            .imul_imm => |i| try writer.print("imul.{} {}, {}, ${d}", .{ i.size, i.dst, i.src, i.imm }),
            .neg => |i| try writer.print("neg.{} {}", .{ i.size, i.dst }),
            .not => |i| try writer.print("not.{} {}", .{ i.size, i.dst }),
            .push_r => |i| try writer.print("push {}", .{i.src}),
            .pop_r => |i| try writer.print("pop {}", .{i.dst}),
            .load => |i| try writer.print("load.{} {}, {}", .{ i.size, i.dst, i.src }),
            .store => |i| try writer.print("store.{} {}, {}", .{ i.size, i.dst, i.src }),
            .lea => |i| try writer.print("lea {}, {}", .{ i.dst, i.src }),
            .mov_rm => |i| try writer.print("mov.{} {}, {}", .{ i.size, i.dst, i.src }),
            .mov_mr => |i| try writer.print("mov.{} {}, {}", .{ i.size, i.dst, i.src }),
            .mov_mi => |i| try writer.print("mov.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .jmp => |i| try writer.print("jmp {}", .{i.target}),
            .jmp_cond => |i| try writer.print("j{} {}", .{ i.cc, i.target }),
            .call => |i| try writer.print("call {}", .{i.target}),
            .setcc => |i| try writer.print("set{} {}", .{ i.cc, i.dst }),
            .cmov => |i| try writer.print("cmov{}.{} {}, {}", .{ i.cc, i.size, i.dst, i.src }),
            .ret => try writer.writeAll("ret"),
            .ret_imm => |i| try writer.print("ret ${d}", .{i.imm}),
            .nop => try writer.writeAll("nop"),
            .movdqa_rr => |i| try writer.print("movdqa {}, {}", .{ i.dst, i.src }),
            .movdqa_mr => |i| try writer.print("movdqa {}, {}", .{ i.dst, i.src }),
            .movdqa_rm => |i| try writer.print("movdqa {}, {}", .{ i.dst, i.src }),
            .movdqu_rr => |i| try writer.print("movdqu {}, {}", .{ i.dst, i.src }),
            .movdqu_mr => |i| try writer.print("movdqu {}, {}", .{ i.dst, i.src }),
            .movdqu_rm => |i| try writer.print("movdqu {}, {}", .{ i.dst, i.src }),
            .movups_rr => |i| try writer.print("movups {}, {}", .{ i.dst, i.src }),
            .movups_mr => |i| try writer.print("movups {}, {}", .{ i.dst, i.src }),
            .movups_rm => |i| try writer.print("movups {}, {}", .{ i.dst, i.src }),
            .movupd_rr => |i| try writer.print("movupd {}, {}", .{ i.dst, i.src }),
            .movupd_mr => |i| try writer.print("movupd {}, {}", .{ i.dst, i.src }),
            .movupd_rm => |i| try writer.print("movupd {}, {}", .{ i.dst, i.src }),
            .movss_rr => |i| try writer.print("movss {}, {}", .{ i.dst, i.src }),
            .movss_mr => |i| try writer.print("movss {}, {}", .{ i.dst, i.src }),
            .movss_rm => |i| try writer.print("movss {}, {}", .{ i.dst, i.src }),
            .movsd_rr => |i| try writer.print("movsd {}, {}", .{ i.dst, i.src }),
            .movsd_mr => |i| try writer.print("movsd {}, {}", .{ i.dst, i.src }),
            .movsd_rm => |i| try writer.print("movsd {}, {}", .{ i.dst, i.src }),
            .paddd_rr => |i| try writer.print("paddd {}, {}", .{ i.dst, i.src }),
            .paddq_rr => |i| try writer.print("paddq {}, {}", .{ i.dst, i.src }),
            .psubd_rr => |i| try writer.print("psubd {}, {}", .{ i.dst, i.src }),
            .psubq_rr => |i| try writer.print("psubq {}, {}", .{ i.dst, i.src }),
            .pmulld_rr => |i| try writer.print("pmulld {}, {}", .{ i.dst, i.src }),
            .pand_rr => |i| try writer.print("pand {}, {}", .{ i.dst, i.src }),
            .por_rr => |i| try writer.print("por {}, {}", .{ i.dst, i.src }),
            .pxor_rr => |i| try writer.print("pxor {}, {}", .{ i.dst, i.src }),
            .pandn_rr => |i| try writer.print("pandn {}, {}", .{ i.dst, i.src }),
            .pcmpeqd_rr => |i| try writer.print("pcmpeqd {}, {}", .{ i.dst, i.src }),
            .pcmpeqq_rr => |i| try writer.print("pcmpeqq {}, {}", .{ i.dst, i.src }),
            .pcmpgtd_rr => |i| try writer.print("pcmpgtd {}, {}", .{ i.dst, i.src }),
            .pcmpgtq_rr => |i| try writer.print("pcmpgtq {}, {}", .{ i.dst, i.src }),
            .pslld_imm => |i| try writer.print("pslld {}, ${d}", .{ i.dst, i.count }),
            .psrld_imm => |i| try writer.print("psrld {}, ${d}", .{ i.dst, i.count }),
            .psrad_imm => |i| try writer.print("psrad {}, ${d}", .{ i.dst, i.count }),
            .psllq_imm => |i| try writer.print("psllq {}, ${d}", .{ i.dst, i.count }),
            .psrlq_imm => |i| try writer.print("psrlq {}, ${d}", .{ i.dst, i.count }),
            .shufps_rr => |i| try writer.print("shufps {}, {}, ${d}", .{ i.dst, i.src, i.imm }),
            .shufpd_rr => |i| try writer.print("shufpd {}, {}, ${d}", .{ i.dst, i.src, i.imm }),
            .pshufd_rr => |i| try writer.print("pshufd {}, {}, ${d}", .{ i.dst, i.src, i.imm }),
            .addps_rr => |i| try writer.print("addps {}, {}", .{ i.dst, i.src }),
            .addpd_rr => |i| try writer.print("addpd {}, {}", .{ i.dst, i.src }),
            .subps_rr => |i| try writer.print("subps {}, {}", .{ i.dst, i.src }),
            .subpd_rr => |i| try writer.print("subpd {}, {}", .{ i.dst, i.src }),
            .mulps_rr => |i| try writer.print("mulps {}, {}", .{ i.dst, i.src }),
            .mulpd_rr => |i| try writer.print("mulpd {}, {}", .{ i.dst, i.src }),
            .divps_rr => |i| try writer.print("divps {}, {}", .{ i.dst, i.src }),
            .divpd_rr => |i| try writer.print("divpd {}, {}", .{ i.dst, i.src }),
            .addss_rr => |i| try writer.print("addss {}, {}", .{ i.dst, i.src }),
            .addsd_rr => |i| try writer.print("addsd {}, {}", .{ i.dst, i.src }),
            .subss_rr => |i| try writer.print("subss {}, {}", .{ i.dst, i.src }),
            .subsd_rr => |i| try writer.print("subsd {}, {}", .{ i.dst, i.src }),
            .mulss_rr => |i| try writer.print("mulss {}, {}", .{ i.dst, i.src }),
            .mulsd_rr => |i| try writer.print("mulsd {}, {}", .{ i.dst, i.src }),
            .divss_rr => |i| try writer.print("divss {}, {}", .{ i.dst, i.src }),
            .divsd_rr => |i| try writer.print("divsd {}, {}", .{ i.dst, i.src }),
            .sqrtss_rr => |i| try writer.print("sqrtss {}, {}", .{ i.dst, i.src }),
            .sqrtsd_rr => |i| try writer.print("sqrtsd {}, {}", .{ i.dst, i.src }),
            .minss_rr => |i| try writer.print("minss {}, {}", .{ i.dst, i.src }),
            .minsd_rr => |i| try writer.print("minsd {}, {}", .{ i.dst, i.src }),
            .maxss_rr => |i| try writer.print("maxss {}, {}", .{ i.dst, i.src }),
            .maxsd_rr => |i| try writer.print("maxsd {}, {}", .{ i.dst, i.src }),
            .cmpxchg_mr => |i| try writer.print("lock cmpxchg.{} {}, {}", .{ i.size, i.dst, i.src }),
            .xadd_mr => |i| try writer.print("lock xadd.{} {}, {}", .{ i.size, i.dst, i.src }),
            .xchg_mr => |i| try writer.print("lock xchg.{} {}, {}", .{ i.size, i.dst, i.src }),
            .lock_add_mi => |i| try writer.print("lock add.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .lock_sub_mi => |i| try writer.print("lock sub.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .lock_and_mi => |i| try writer.print("lock and.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .lock_or_mi => |i| try writer.print("lock or.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .lock_xor_mi => |i| try writer.print("lock xor.{} {}, ${d}", .{ i.size, i.dst, i.imm }),
            .lfence => try writer.writeAll("lfence"),
            .sfence => try writer.writeAll("sfence"),
            .mfence => try writer.writeAll("mfence"),
        }
    }
};

/// Operand size for x64 instructions.
pub const OperandSize = enum {
    /// 8-bit (AL, BL, etc.)
    size8,
    /// 16-bit (AX, BX, etc.)
    size16,
    /// 32-bit (EAX, EBX, etc.)
    size32,
    /// 64-bit (RAX, RBX, etc.)
    size64,

    pub fn format(
        self: OperandSize,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const suffix = switch (self) {
            .size8 => "b",
            .size16 => "w",
            .size32 => "l",
            .size64 => "q",
        };
        try writer.writeAll(suffix);
    }

    pub fn bytes(self: OperandSize) u32 {
        return switch (self) {
            .size8 => 1,
            .size16 => 2,
            .size32 => 4,
            .size64 => 8,
        };
    }
};

/// Condition code for conditional jumps.
pub const CondCode = enum {
    /// Overflow.
    o,
    /// Not overflow.
    no,
    /// Below/Carry.
    b,
    /// Above or equal/Not carry.
    ae,
    /// Equal/Zero.
    e,
    /// Not equal/Not zero.
    ne,
    /// Below or equal.
    be,
    /// Above.
    a,
    /// Sign.
    s,
    /// Not sign.
    ns,
    /// Parity/Parity even.
    p,
    /// Not parity/Parity odd.
    np,
    /// Less than.
    l,
    /// Greater or equal.
    ge,
    /// Less or equal.
    le,
    /// Greater.
    g,

    pub fn format(
        self: CondCode,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const name = @tagName(self);
        try writer.writeAll(name);
    }

    /// Invert the condition code (e.g., e -> ne, l -> ge).
    pub fn invert(self: CondCode) CondCode {
        return switch (self) {
            .o => .no,
            .no => .o,
            .b => .ae,
            .ae => .b,
            .e => .ne,
            .ne => .e,
            .be => .a,
            .a => .be,
            .s => .ns,
            .ns => .s,
            .p => .np,
            .np => .p,
            .l => .ge,
            .ge => .l,
            .le => .g,
            .g => .le,
        };
    }
};

/// Memory operand for x64 addressing modes.
/// Represents [base + index*scale + disp]
pub const Mem = struct {
    /// Base register (optional).
    base: ?Reg,
    /// Index register (optional).
    idx: ?Reg,
    /// Scale factor (1, 2, 4, or 8).
    scale: u8,
    /// Displacement (signed offset).
    disp: i32,

    pub fn new(base: ?Reg, idx: ?Reg, scale: u8, disp: i32) Mem {
        return .{ .base = base, .idx = idx, .scale = scale, .disp = disp };
    }

    /// Simple [base + disp] mode.
    pub fn base_disp(base: Reg, disp: i32) Mem {
        return .{ .base = base, .idx = null, .scale = 1, .disp = disp };
    }

    /// Simple [base] mode (zero displacement).
    pub fn base_only(base: Reg) Mem {
        return .{ .base = base, .idx = null, .scale = 1, .disp = 0 };
    }

    pub fn format(
        self: Mem,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll("[");

        if (self.base) |base| {
            try writer.print("{}", .{base});
            if (self.idx != null or self.disp != 0) {
                try writer.writeAll(" + ");
            }
        }

        if (self.idx) |idx| {
            try writer.print("{}", .{idx});
            if (self.scale > 1) {
                try writer.print("*{d}", .{self.scale});
            }
            if (self.disp != 0) {
                try writer.writeAll(" + ");
            }
        }

        if (self.disp != 0 or (self.base == null and self.idx == null)) {
            if (self.disp < 0) {
                try writer.print("{d}", .{self.disp});
            } else {
                try writer.print("{d}", .{self.disp});
            }
        }

        try writer.writeAll("]");
    }
};

/// Branch target (label for jumps).
pub const BranchTarget = struct {
    label: u32,

    pub fn new(label: u32) BranchTarget {
        return .{ .label = label };
    }

    pub fn format(
        self: BranchTarget,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(".L{d}", .{self.label});
    }
};

/// Call target (function name or address).
pub const CallTarget = union(enum) {
    /// Direct call to a named function.
    direct: []const u8,
    /// Indirect call through register.
    indirect: Reg,

    pub fn format(
        self: CallTarget,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .direct => |name| try writer.print("{s}", .{name}),
            .indirect => |reg| try writer.print("*{}", .{reg}),
        }
    }
};

test "Inst formatting" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    const inst = Inst{ .add_rr = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } };

    var buf: [64]u8 = undefined;
    const str = try std.fmt.bufPrint(&buf, "{}", .{inst});
    try testing.expect(std.mem.indexOf(u8, str, "add") != null);
}

test "CondCode invert" {
    try testing.expectEqual(CondCode.ne, CondCode.e.invert());
    try testing.expectEqual(CondCode.e, CondCode.ne.invert());
    try testing.expectEqual(CondCode.ge, CondCode.l.invert());
    try testing.expectEqual(CondCode.le, CondCode.g.invert());
}

test "OperandSize bytes" {
    try testing.expectEqual(@as(u32, 1), OperandSize.size8.bytes());
    try testing.expectEqual(@as(u32, 2), OperandSize.size16.bytes());
    try testing.expectEqual(@as(u32, 4), OperandSize.size32.bytes());
    try testing.expectEqual(@as(u32, 8), OperandSize.size64.bytes());
}

test "ALU instruction formatting" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    var buf: [64]u8 = undefined;

    // Test immediate forms
    const add_imm = Inst{ .add_imm = .{ .dst = wr0, .imm = 42, .size = .size64 } };
    const str1 = try std.fmt.bufPrint(&buf, "{}", .{add_imm});
    try testing.expect(std.mem.indexOf(u8, str1, "add") != null);
    try testing.expect(std.mem.indexOf(u8, str1, "$42") != null);

    // Test bitwise ops
    const and_rr = Inst{ .and_rr = .{ .dst = wr0, .src = r1, .size = .size32 } };
    const str2 = try std.fmt.bufPrint(&buf, "{}", .{and_rr});
    try testing.expect(std.mem.indexOf(u8, str2, "and") != null);

    const xor_imm = Inst{ .xor_imm = .{ .dst = wr0, .imm = -1, .size = .size64 } };
    const str3 = try std.fmt.bufPrint(&buf, "{}", .{xor_imm});
    try testing.expect(std.mem.indexOf(u8, str3, "xor") != null);

    // Test compare/test
    const cmp_rr = Inst{ .cmp_rr = .{ .lhs = r0, .rhs = r1, .size = .size64 } };
    const str4 = try std.fmt.bufPrint(&buf, "{}", .{cmp_rr});
    try testing.expect(std.mem.indexOf(u8, str4, "cmp") != null);

    const test_imm = Inst{ .test_imm = .{ .lhs = r0, .imm = 1, .size = .size8 } };
    const str5 = try std.fmt.bufPrint(&buf, "{}", .{test_imm});
    try testing.expect(std.mem.indexOf(u8, str5, "test") != null);

    // Test shifts
    const shl_imm = Inst{ .shl_imm = .{ .dst = wr0, .count = 3, .size = .size64 } };
    const str6 = try std.fmt.bufPrint(&buf, "{}", .{shl_imm});
    try testing.expect(std.mem.indexOf(u8, str6, "shl") != null);

    const sar_rr = Inst{ .sar_rr = .{ .dst = wr0, .count = r1, .size = .size32 } };
    const str7 = try std.fmt.bufPrint(&buf, "{}", .{sar_rr});
    try testing.expect(std.mem.indexOf(u8, str7, "sar") != null);

    // Test rotate
    const rol_imm = Inst{ .rol_imm = .{ .dst = wr0, .count = 1, .size = .size64 } };
    const str7a = try std.fmt.bufPrint(&buf, "{}", .{rol_imm});
    try testing.expect(std.mem.indexOf(u8, str7a, "rol") != null);

    const ror_rr = Inst{ .ror_rr = .{ .dst = wr0, .count = r1, .size = .size32 } };
    const str7b = try std.fmt.bufPrint(&buf, "{}", .{ror_rr});
    try testing.expect(std.mem.indexOf(u8, str7b, "ror") != null);

    // Test multiply
    const imul_rr = Inst{ .imul_rr = .{ .dst = wr0, .src = r1, .size = .size64 } };
    const str8 = try std.fmt.bufPrint(&buf, "{}", .{imul_rr});
    try testing.expect(std.mem.indexOf(u8, str8, "imul") != null);

    // Test unary
    const neg = Inst{ .neg = .{ .dst = wr0, .size = .size64 } };
    const str9 = try std.fmt.bufPrint(&buf, "{}", .{neg});
    try testing.expect(std.mem.indexOf(u8, str9, "neg") != null);

    const not = Inst{ .not = .{ .dst = wr0, .size = .size64 } };
    const str10 = try std.fmt.bufPrint(&buf, "{}", .{not});
    try testing.expect(std.mem.indexOf(u8, str10, "not") != null);
}

test "setcc and cmov formatting" {
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);

    var buf: [64]u8 = undefined;

    const setcc = Inst{ .setcc = .{ .cc = .e, .dst = wr0 } };
    const str1 = try std.fmt.bufPrint(&buf, "{}", .{setcc});
    try testing.expect(std.mem.indexOf(u8, str1, "sete") != null);

    const cmov = Inst{ .cmov = .{ .cc = .l, .dst = wr0, .src = r1, .size = .size64 } };
    const str2 = try std.fmt.bufPrint(&buf, "{}", .{cmov});
    try testing.expect(std.mem.indexOf(u8, str2, "cmovl") != null);
}

test "ret_imm formatting" {
    var buf: [64]u8 = undefined;
    const ret_imm = Inst{ .ret_imm = .{ .imm = 8 } };
    const str = try std.fmt.bufPrint(&buf, "{}", .{ret_imm});
    try testing.expect(std.mem.indexOf(u8, str, "ret") != null);
    try testing.expect(std.mem.indexOf(u8, str, "$8") != null);
}

/// Operand collector for register allocation.
pub const OperandCollector = struct {
    uses: std.ArrayList(Reg),
    defs: std.ArrayList(WritableReg),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) OperandCollector {
        return .{
            .uses = std.ArrayList(Reg).init(alloc),
            .defs = std.ArrayList(WritableReg).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *OperandCollector) void {
        self.uses.deinit();
        self.defs.deinit();
    }

    pub fn regUse(self: *OperandCollector, r: Reg) !void {
        try self.uses.append(r);
    }

    pub fn regDef(self: *OperandCollector, wr: WritableReg) !void {
        try self.defs.append(wr);
    }

    pub fn regLateDef(self: *OperandCollector, wr: WritableReg) !void {
        try self.defs.append(wr);
    }
};

pub const inst_impl = struct {
    pub fn getOperands(self: *const Inst, c: *OperandCollector) !void {
        switch (self.*) {
            .mov_rr => |*i| {
                try c.regUse(i.src);
                try c.regDef(i.dst);
            },
            .mov_imm => |*i| {
                try c.regDef(i.dst);
            },
            .add_rr, .sub_rr, .and_rr, .or_rr, .xor_rr => |*i| {
                try c.regUse(i.dst.toReg());
                try c.regUse(i.src);
                try c.regDef(i.dst);
            },
            .add_imm, .sub_imm, .and_imm, .or_imm, .xor_imm => |*i| {
                try c.regUse(i.dst.toReg());
                try c.regDef(i.dst);
            },
            .cmp_rr => |*i| {
                try c.regUse(i.lhs);
                try c.regUse(i.rhs);
            },
            .cmp_imm => |*i| {
                try c.regUse(i.lhs);
            },
            .test_rr => |*i| {
                try c.regUse(i.lhs);
                try c.regUse(i.rhs);
            },
            .test_imm => |*i| {
                try c.regUse(i.lhs);
            },
            .shl_rr, .shr_rr, .sar_rr, .rol_rr, .ror_rr => |*i| {
                try c.regUse(i.dst.toReg());
                try c.regUse(i.count);
                try c.regDef(i.dst);
            },
            .shl_imm, .shr_imm, .sar_imm, .rol_imm, .ror_imm => |*i| {
                try c.regUse(i.dst.toReg());
                try c.regDef(i.dst);
            },
            .imul_rr => |*i| {
                try c.regUse(i.dst.toReg());
                try c.regUse(i.src);
                try c.regDef(i.dst);
            },
            .imul_imm => |*i| {
                try c.regUse(i.src);
                try c.regDef(i.dst);
            },
            .neg, .not => |*i| {
                try c.regUse(i.dst.toReg());
                try c.regDef(i.dst);
            },
            .push_r => |*i| {
                try c.regUse(i.src);
            },
            .pop_r => |*i| {
                try c.regDef(i.dst);
            },
            .load, .mov_rm => |*i| {
                if (i.src.base) |b| try c.regUse(b);
                if (i.src.idx) |idx| try c.regUse(idx);
                try c.regDef(i.dst);
            },
            .store, .mov_mr => |*i| {
                if (i.dst.base) |b| try c.regUse(b);
                if (i.dst.idx) |idx| try c.regUse(idx);
                try c.regUse(i.src);
            },
            .mov_mi => |*i| {
                if (i.dst.base) |b| try c.regUse(b);
                if (i.dst.idx) |idx| try c.regUse(idx);
            },
            .lea => |*i| {
                if (i.src.base) |b| try c.regUse(b);
                if (i.src.idx) |idx| try c.regUse(idx);
                try c.regDef(i.dst);
            },
            .setcc => |*i| {
                try c.regDef(i.dst);
            },
            .cmov => |*i| {
                try c.regUse(i.dst.toReg());
                try c.regUse(i.src);
                try c.regDef(i.dst);
            },
            .call => |*i| {
                if (i.target == .indirect) {
                    try c.regUse(i.target.indirect);
                }
            },
            .jmp, .jmp_cond, .ret, .ret_imm, .nop => {},
            .movdqa_rr, .movdqu_rr, .movups_rr, .movupd_rr, .movss_rr, .movsd_rr => |*i| {
                try c.regUse(i.src);
                try c.regDef(i.dst);
            },
            .movdqa_mr, .movdqu_mr, .movups_mr, .movupd_mr, .movss_mr, .movsd_mr => |*i| {
                if (i.dst.base) |b| try c.regUse(b);
                if (i.dst.idx) |idx| try c.regUse(idx);
                try c.regUse(i.src);
            },
            .movdqa_rm, .movdqu_rm, .movups_rm, .movupd_rm, .movss_rm, .movsd_rm => |*i| {
                if (i.src.base) |b| try c.regUse(b);
                if (i.src.idx) |idx| try c.regUse(idx);
                try c.regDef(i.dst);
            },
            .paddd_rr, .paddq_rr, .psubd_rr, .psubq_rr, .pmulld_rr, .pand_rr, .por_rr, .pxor_rr, .pandn_rr, .pcmpeqd_rr, .pcmpeqq_rr, .pcmpgtd_rr, .pcmpgtq_rr, .addps_rr, .addpd_rr, .subps_rr, .subpd_rr, .mulps_rr, .mulpd_rr, .divps_rr, .divpd_rr, .addss_rr, .addsd_rr, .subss_rr, .subsd_rr, .mulss_rr, .mulsd_rr, .divss_rr, .divsd_rr, .minss_rr, .minsd_rr, .maxss_rr, .maxsd_rr => |*i| {
                try c.regUse(i.dst.toReg());
                try c.regUse(i.src);
                try c.regDef(i.dst);
            },
            .pslld_imm, .psrld_imm, .psrad_imm, .psllq_imm, .psrlq_imm => |*i| {
                try c.regUse(i.dst.toReg());
                try c.regDef(i.dst);
            },
            .shufps_rr, .shufpd_rr => |*i| {
                try c.regUse(i.dst.toReg());
                try c.regUse(i.src);
                try c.regDef(i.dst);
            },
            .pshufd_rr => |*i| {
                try c.regUse(i.src);
                try c.regDef(i.dst);
            },
            .sqrtss_rr, .sqrtsd_rr => |*i| {
                try c.regUse(i.src);
                try c.regDef(i.dst);
            },
            .cmpxchg_mr => |*i| {
                if (i.dst.base) |b| try c.regUse(b);
                if (i.dst.idx) |idx| try c.regUse(idx);
                try c.regUse(i.src);
                // RAX implicit use/def
            },
            .xadd_mr => |*i| {
                if (i.dst.base) |b| try c.regUse(b);
                if (i.dst.idx) |idx| try c.regUse(idx);
                try c.regUse(i.src.toReg());
                try c.regDef(i.src);
            },
            .xchg_mr => |*i| {
                if (i.dst.base) |b| try c.regUse(b);
                if (i.dst.idx) |idx| try c.regUse(idx);
                try c.regUse(i.src.toReg());
                try c.regDef(i.src);
            },
            .lock_add_mi, .lock_sub_mi, .lock_and_mi, .lock_or_mi, .lock_xor_mi => |*i| {
                if (i.dst.base) |b| try c.regUse(b);
                if (i.dst.idx) |idx| try c.regUse(idx);
            },
            .lfence, .sfence, .mfence => {},
        }
    }
};
