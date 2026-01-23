const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const abi_mod = @import("../../machinst/abi.zig");
const inst_mod = @import("inst.zig");
const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
pub const PReg = inst_mod.PReg;
const WritableReg = inst_mod.WritableReg;
const buffer_mod = @import("../../machinst/buffer.zig");
const vcode_mod = @import("../../machinst/vcode.zig");
const types = @import("../../ir/types.zig");
const Type = types.Type;
const signature_mod = @import("../../ir/signature.zig");
const AbiParam = signature_mod.AbiParam;

// RISC-V calling convention (LP64D ABI)
const rv64_int_args = [_]PReg{
    PReg.new(.int, 10), // a0 (x10)
    PReg.new(.int, 11), // a1 (x11)
    PReg.new(.int, 12), // a2 (x12)
    PReg.new(.int, 13), // a3 (x13)
    PReg.new(.int, 14), // a4 (x14)
    PReg.new(.int, 15), // a5 (x15)
    PReg.new(.int, 16), // a6 (x16)
    PReg.new(.int, 17), // a7 (x17)
};

const rv64_float_args = [_]PReg{
    PReg.new(.float, 10), // fa0 (f10)
    PReg.new(.float, 11), // fa1 (f11)
    PReg.new(.float, 12), // fa2 (f12)
    PReg.new(.float, 13), // fa3 (f13)
    PReg.new(.float, 14), // fa4 (f14)
    PReg.new(.float, 15), // fa5 (f15)
    PReg.new(.float, 16), // fa6 (f16)
    PReg.new(.float, 17), // fa7 (f17)
};

const rv64_int_rets = [_]PReg{
    PReg.new(.int, 10), // a0 (x10)
    PReg.new(.int, 11), // a1 (x11)
};

const rv64_float_rets = [_]PReg{
    PReg.new(.float, 10), // fa0 (f10)
    PReg.new(.float, 11), // fa1 (f11)
};

const rv64_callee_saves = [_]PReg{
    PReg.new(.int, 8),  // s0/fp (x8)
    PReg.new(.int, 9),  // s1 (x9)
    PReg.new(.int, 18), // s2 (x18)
    PReg.new(.int, 19), // s3 (x19)
    PReg.new(.int, 20), // s4 (x20)
    PReg.new(.int, 21), // s5 (x21)
    PReg.new(.int, 22), // s6 (x22)
    PReg.new(.int, 23), // s7 (x23)
    PReg.new(.int, 24), // s8 (x24)
    PReg.new(.int, 25), // s9 (x25)
    PReg.new(.int, 26), // s10 (x26)
    PReg.new(.int, 27), // s11 (x27)
    PReg.new(.float, 8),  // fs0 (f8)
    PReg.new(.float, 9),  // fs1 (f9)
    PReg.new(.float, 18), // fs2 (f18)
    PReg.new(.float, 19), // fs3 (f19)
    PReg.new(.float, 20), // fs4 (f20)
    PReg.new(.float, 21), // fs5 (f21)
    PReg.new(.float, 22), // fs6 (f22)
    PReg.new(.float, 23), // fs7 (f23)
    PReg.new(.float, 24), // fs8 (f24)
    PReg.new(.float, 25), // fs9 (f25)
    PReg.new(.float, 26), // fs10 (f26)
    PReg.new(.float, 27), // fs11 (f27)
};

pub fn lp64d() abi_mod.ABIMachineSpec(u64) {
    return .{
        .int_arg_regs = &rv64_int_args,
        .float_arg_regs = &rv64_float_args,
        .int_ret_regs = &rv64_int_rets,
        .float_ret_regs = &rv64_float_rets,
        .callee_saves = &rv64_callee_saves,
        .stack_align = 16,
        .align_int_pairs = false,
    };
}

pub const Riscv64ABICallee = struct {
    sig: abi_mod.ABISignature,
    abi: abi_mod.ABIMachineSpec(u64),
    call_conv: ?abi_mod.ABICallingConvention,
    clobbered_callee_saves: std.ArrayList(PReg),
    frame_size: u32,

    pub fn init(
        _allocator: std.mem.Allocator,
        sig: abi_mod.ABISignature,
    ) Riscv64ABICallee {
        _ = _allocator;
        const abi_spec = lp64d();

        return .{
            .sig = sig,
            .abi = abi_spec,
            .call_conv = null,
            .clobbered_callee_saves = std.ArrayList(PReg){},
            .frame_size = 0,
        };
    }

    pub fn deinit(self: *Riscv64ABICallee) void {
        if (self.call_conv) |*cc| {
            var cc_mut = cc;
            cc_mut.deinit();
        }
        self.clobbered_callee_saves.deinit();
    }

    pub fn computeCallConv(self: *Riscv64ABICallee, allocator: Allocator) !void {
        self.call_conv = try abi_mod.ABICallingConvention.new(
            allocator,
            self.sig,
            self.abi,
        );
    }

    pub fn genPrologue(self: *Riscv64ABICallee, vcode: *vcode_mod.VCode(Inst)) !void {
        _ = self;
        _ = vcode;
    }

    pub fn genEpilogue(self: *Riscv64ABICallee, vcode: *vcode_mod.VCode(Inst)) !void {
        _ = self;
        _ = vcode;
    }
};

pub const Riscv64ABICaller = struct {
    sig: abi_mod.ABISignature,
    abi: abi_mod.ABIMachineSpec(u64),
    call_conv: ?abi_mod.ABICallingConvention,

    pub fn init(
        _allocator: std.mem.Allocator,
        sig: abi_mod.ABISignature,
    ) Riscv64ABICaller {
        _ = _allocator;
        const abi_spec = lp64d();

        return .{
            .sig = sig,
            .abi = abi_spec,
            .call_conv = null,
        };
    }

    pub fn deinit(self: *Riscv64ABICaller) void {
        if (self.call_conv) |*cc| {
            var cc_mut = cc;
            cc_mut.deinit();
        }
    }

    pub fn computeCallConv(self: *Riscv64ABICaller, allocator: Allocator) !void {
        self.call_conv = try abi_mod.ABICallingConvention.new(
            allocator,
            self.sig,
            self.abi,
        );
    }

    pub fn emitCall(self: *Riscv64ABICaller, vcode: *vcode_mod.VCode(Inst)) !void {
        _ = self;
        _ = vcode;
    }
};

test "LP64D ABI spec" {
    const abi_spec = lp64d();
    try testing.expectEqual(@as(usize, 8), abi_spec.int_arg_regs.len);
    try testing.expectEqual(@as(usize, 8), abi_spec.float_arg_regs.len);
    try testing.expectEqual(@as(usize, 2), abi_spec.int_ret_regs.len);
    try testing.expectEqual(@as(usize, 2), abi_spec.float_ret_regs.len);
    try testing.expectEqual(@as(u32, 16), abi_spec.stack_align);
}

test "Riscv64ABICallee init" {
    const sig = abi_mod.ABISignature{
        .params = &.{},
        .returns = &.{},
        .call_conv = .system_v,
    };

    var callee = Riscv64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    try testing.expectEqual(@as(u32, 0), callee.frame_size);
}
