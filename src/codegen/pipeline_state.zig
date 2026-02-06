const std = @import("std");

const ir_entities = @import("../ir/entities.zig");
const Opcode = @import("../ir/opcodes.zig").Opcode;
const a64_inst = @import("../backends/aarch64/inst.zig");
const x64_inst = @import("../backends/x64/inst.zig");
const vcode_mod = @import("../machinst/vcode.zig");
const reg_mod = @import("../machinst/reg.zig");
const linear_scan_mod = @import("../regalloc/linear_scan.zig");

pub const VRegOrigin = struct {
    opcode: Opcode,
    imm: ?i64,
    operands: [2]?reg_mod.VReg,

    pub fn forConst(op: Opcode, value: i64) VRegOrigin {
        return .{ .opcode = op, .imm = value, .operands = .{ null, null } };
    }

    pub fn forBinop(op: Opcode, lhs: reg_mod.VReg, rhs: reg_mod.VReg) VRegOrigin {
        return .{ .opcode = op, .imm = null, .operands = .{ lhs, rhs } };
    }

    pub fn isCheap(self: VRegOrigin) bool {
        return switch (self.opcode) {
            .iconst, .f32const, .f64const => true,
            .iadd, .isub, .band, .bor, .bxor => true,
            .ishl, .ushr, .sshr => true,
            else => false,
        };
    }
};

pub const AArch64Lowered = struct {
    allocator: std.mem.Allocator,
    vcode: vcode_mod.VCode(a64_inst.Inst),
    vreg_origins: std.AutoHashMap(reg_mod.VReg, VRegOrigin),
    ir_to_vcode_blocks: std.AutoHashMap(ir_entities.Block, vcode_mod.BlockIndex),

    pub fn deinit(self: *AArch64Lowered) void {
        self.vcode.deinit();
        self.vreg_origins.deinit();
        self.ir_to_vcode_blocks.deinit();
        self.* = undefined;
    }
};

pub const AArch64RegAlloc = struct {
    allocator: std.mem.Allocator,
    result: linear_scan_mod.RegAllocResult,
    spill_bytes: u32,

    pub fn deinit(self: *AArch64RegAlloc) void {
        self.result.deinit();
        self.* = undefined;
    }
};

pub const X64Lowered = struct {
    vcode: vcode_mod.VCode(x64_inst.Inst),

    pub fn deinit(self: *X64Lowered) void {
        self.vcode.deinit();
        self.* = undefined;
    }
};
