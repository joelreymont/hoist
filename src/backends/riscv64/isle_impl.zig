const std = @import("std");
const root = @import("root");

const Inst = @import("inst.zig").Inst;
const Reg = @import("inst.zig").Reg;
const WritableReg = @import("inst.zig").WritableReg;

const lower_mod = @import("../../machinst/lower.zig");
const LowerCtx = lower_mod.LowerCtx;
const Value = lower_mod.Value;
const Type = @import("../../ir/types.zig").Type;

pub const IsleCtx = struct {
    lower_ctx: *LowerCtx(Inst),

    pub fn init(ctx: *LowerCtx(Inst)) IsleCtx {
        return .{ .lower_ctx = ctx };
    }

    pub fn emit(self: *IsleCtx, inst: Inst) !void {
        try self.lower_ctx.emit(inst);
    }

    pub fn getValueReg(self: *IsleCtx, value: Value, class: lower_mod.RegClass) !Reg {
        const vreg = try self.lower_ctx.getValueReg(value, class);
        return Reg.fromVReg(vreg);
    }

    pub fn allocOutputReg(self: *IsleCtx, class: lower_mod.RegClass) WritableReg {
        const vreg = self.lower_ctx.allocVReg(class);
        return WritableReg.fromVReg(vreg);
    }
};

fn is32Bit(ty: Type) bool {
    return ty.bits() <= 32;
}

// Integer arithmetic

pub fn rv_add(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .addw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .add = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return dst;
}

pub fn rv_sub(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .subw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .sub = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return dst;
}

pub fn rv_mul(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .mulw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .mul = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return dst;
}

pub fn rv_div(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .divw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .div = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return dst;
}

pub fn rv_divu(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .divuw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .divu = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return dst;
}

pub fn rv_rem(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .remw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .rem = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return dst;
}

pub fn rv_remu(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .remuw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .remu = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return dst;
}

pub fn rv_addi(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .addiw = .{ .dst = dst, .src = rx, .imm = imm } });
    } else {
        try ctx.emit(.{ .addi = .{ .dst = dst, .src = rx, .imm = imm } });
    }
    return dst;
}

// Bitwise operations

pub fn rv_and(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(.{ .@"and" = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    return dst;
}

pub fn rv_or(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(.{ .@"or" = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    return dst;
}

pub fn rv_xor(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(.{ .xor = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    return dst;
}

pub fn rv_andi(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !WritableReg {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);
    try ctx.emit(.{ .andi = .{ .dst = dst, .src = rx, .imm = imm } });
    return dst;
}

pub fn rv_ori(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !WritableReg {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);
    try ctx.emit(.{ .ori = .{ .dst = dst, .src = rx, .imm = imm } });
    return dst;
}

pub fn rv_xori(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !WritableReg {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);
    try ctx.emit(.{ .xori = .{ .dst = dst, .src = rx, .imm = imm } });
    return dst;
}

// Shifts

pub fn rv_sll(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .sllw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .sll = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return dst;
}

pub fn rv_srl(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .srlw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .srl = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return dst;
}

pub fn rv_sra(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .sraw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .sra = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return dst;
}

pub fn rv_slli(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        const shamt: u5 = @intCast(@as(u64, @bitCast(k)) & 0x1f);
        try ctx.emit(.{ .slliw = .{ .dst = dst, .src = rx, .shamt = shamt } });
    } else {
        const shamt: u6 = @intCast(@as(u64, @bitCast(k)) & 0x3f);
        try ctx.emit(.{ .slli = .{ .dst = dst, .src = rx, .shamt = shamt } });
    }
    return dst;
}

pub fn rv_srli(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        const shamt: u5 = @intCast(@as(u64, @bitCast(k)) & 0x1f);
        try ctx.emit(.{ .srliw = .{ .dst = dst, .src = rx, .shamt = shamt } });
    } else {
        const shamt: u6 = @intCast(@as(u64, @bitCast(k)) & 0x3f);
        try ctx.emit(.{ .srli = .{ .dst = dst, .src = rx, .shamt = shamt } });
    }
    return dst;
}

pub fn rv_srai(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !WritableReg {
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        const shamt: u5 = @intCast(@as(u64, @bitCast(k)) & 0x1f);
        try ctx.emit(.{ .sraiw = .{ .dst = dst, .src = rx, .shamt = shamt } });
    } else {
        const shamt: u6 = @intCast(@as(u64, @bitCast(k)) & 0x3f);
        try ctx.emit(.{ .srai = .{ .dst = dst, .src = rx, .shamt = shamt } });
    }
    return dst;
}

// Comparisons

pub fn rv_slt(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(.{ .slt = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    return dst;
}

pub fn rv_sltu(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(.{ .sltu = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    return dst;
}

pub fn rv_slti(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !WritableReg {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);
    try ctx.emit(.{ .slti = .{ .dst = dst, .src = rx, .imm = imm } });
    return dst;
}

pub fn rv_sltiu(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !WritableReg {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);
    try ctx.emit(.{ .sltiu = .{ .dst = dst, .src = rx, .imm = imm } });
    return dst;
}

// Stubs for remaining constructors (to be implemented)

pub fn rv_load(ctx: *IsleCtx, ty: Type, addr: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_store(ctx: *IsleCtx, val: Value, addr: Value) !void {
    _ = ctx;
    _ = val;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_jmp(ctx: *IsleCtx, target: lower_mod.Block) !void {
    _ = ctx;
    _ = target;
    return error.Unimplemented;
}

pub fn rv_brif(ctx: *IsleCtx, cond: Value, target: lower_mod.Block) !void {
    _ = ctx;
    _ = cond;
    _ = target;
    return error.Unimplemented;
}

pub fn rv_ret(ctx: *IsleCtx) !void {
    _ = ctx;
    return error.Unimplemented;
}

pub fn rv_iconst(ctx: *IsleCtx, ty: Type, k: i64) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = k;
    return error.Unimplemented;
}

pub fn rv_fadd(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fsub(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fmul(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fdiv(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fsqrt(ctx: *IsleCtx, ty: Type, x: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fmin(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fmax(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_feq(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_flt(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fle(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fcvt_from_sint(ctx: *IsleCtx, ty: Type, x: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fcvt_from_uint(ctx: *IsleCtx, ty: Type, x: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fcvt_to_sint(ctx: *IsleCtx, ty: Type, x: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fcvt_to_uint(ctx: *IsleCtx, ty: Type, x: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fcvt_s_d(ctx: *IsleCtx, x: Value) !WritableReg {
    _ = ctx;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fcvt_d_s(ctx: *IsleCtx, x: Value) !WritableReg {
    _ = ctx;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_flw(ctx: *IsleCtx, addr: Value) !WritableReg {
    _ = ctx;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_fld(ctx: *IsleCtx, addr: Value) !WritableReg {
    _ = ctx;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_fsw(ctx: *IsleCtx, val: Value, addr: Value) !void {
    _ = ctx;
    _ = val;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_fsd(ctx: *IsleCtx, val: Value, addr: Value) !void {
    _ = ctx;
    _ = val;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_amoadd(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amoswap(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amoand(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amoor(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amoxor(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amomin(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amomax(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amominu(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amomaxu(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_lr(ctx: *IsleCtx, ty: Type, addr: Value) !WritableReg {
    _ = ctx;
    _ = ty;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_sc(ctx: *IsleCtx, val: Value, addr: Value) !WritableReg {
    _ = ctx;
    _ = val;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_fence(ctx: *IsleCtx) !void {
    _ = ctx;
    return error.Unimplemented;
}
