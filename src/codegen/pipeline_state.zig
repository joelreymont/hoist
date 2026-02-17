const std = @import("std");

const ir_entities = @import("../ir/entities.zig");
const Opcode = @import("../ir/opcodes.zig").Opcode;
const a64_inst = @import("../backends/aarch64/inst.zig");
const x64_inst = @import("../backends/x64/inst.zig");
const riscv64_inst = @import("../backends/riscv64/inst.zig");
const s390x_inst = @import("../backends/s390x/inst.zig");
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

    pub fn resetForReuse(self: *AArch64Lowered) void {
        self.vcode.deinit();
        self.vcode = vcode_mod.VCode(a64_inst.Inst).init(self.allocator);
        self.vreg_origins.clearRetainingCapacity();
        self.ir_to_vcode_blocks.clearRetainingCapacity();
    }

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
    linear_scan: ?linear_scan_mod.LinearScanAllocator,
    pool_key: u64,

    pub fn resetForReuse(self: *AArch64RegAlloc) void {
        self.result.clearRetainingCapacity();
        self.spill_bytes = 0;
        if (self.linear_scan) |*scan| {
            scan.resetForReuse();
        }
    }

    pub fn deinit(self: *AArch64RegAlloc) void {
        if (self.linear_scan) |*scan| {
            scan.deinit();
            self.linear_scan = null;
        }
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

pub const Riscv64Lowered = struct {
    vcode: vcode_mod.VCode(riscv64_inst.Inst),

    pub fn deinit(self: *Riscv64Lowered) void {
        self.vcode.deinit();
        self.* = undefined;
    }
};

pub const Riscv64RegAlloc = struct {
    allocator: std.mem.Allocator,
    result: linear_scan_mod.RegAllocResult,
    spill_bytes: u32,

    pub fn deinit(self: *Riscv64RegAlloc) void {
        self.result.deinit();
        self.* = undefined;
    }
};

pub const S390xLowered = struct {
    vcode: vcode_mod.VCode(s390x_inst.Inst),

    pub fn deinit(self: *S390xLowered) void {
        self.vcode.deinit();
        self.* = undefined;
    }
};

pub const S390xRegAlloc = struct {
    allocator: std.mem.Allocator,
    result: linear_scan_mod.RegAllocResult,
    spill_bytes: u32,

    pub fn deinit(self: *S390xRegAlloc) void {
        self.result.deinit();
        self.* = undefined;
    }
};

test "AArch64Lowered resetForReuse clears maps" {
    var lowered = AArch64Lowered{
        .allocator = std.testing.allocator,
        .vcode = vcode_mod.VCode(a64_inst.Inst).init(std.testing.allocator),
        .vreg_origins = std.AutoHashMap(reg_mod.VReg, VRegOrigin).init(std.testing.allocator),
        .ir_to_vcode_blocks = std.AutoHashMap(ir_entities.Block, vcode_mod.BlockIndex).init(std.testing.allocator),
    };
    defer lowered.deinit();

    try lowered.vreg_origins.put(reg_mod.VReg.new(1, .int), VRegOrigin.forConst(.iconst, 7));
    try lowered.ir_to_vcode_blocks.put(ir_entities.Block.new(0), 0);

    lowered.resetForReuse();

    try std.testing.expectEqual(@as(usize, 0), lowered.vreg_origins.count());
    try std.testing.expectEqual(@as(usize, 0), lowered.ir_to_vcode_blocks.count());
    try std.testing.expectEqual(@as(usize, 0), lowered.vcode.numInsns());
}

test "AArch64RegAlloc resetForReuse clears result" {
    var state = AArch64RegAlloc{
        .allocator = std.testing.allocator,
        .result = linear_scan_mod.RegAllocResult.init(std.testing.allocator),
        .spill_bytes = 64,
        .linear_scan = null,
        .pool_key = 0,
    };
    defer state.deinit();

    try state.result.assign(reg_mod.VReg.new(3, .int), reg_mod.PReg.new(.int, 1));
    try state.result.assignSpillSlot(reg_mod.VReg.new(9, .int), .{ .offset = 128 });

    state.resetForReuse();

    try std.testing.expectEqual(@as(usize, 0), state.result.vreg_to_preg.count());
    try std.testing.expectEqual(@as(usize, 0), state.result.vreg_to_spill.count());
    try std.testing.expectEqual(@as(u32, 0), state.spill_bytes);
}
