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

// s390x calling convention (SysV ABI)
const s390x_int_args = [_]PReg{
    PReg.new(.int, 2), // r2
    PReg.new(.int, 3), // r3
    PReg.new(.int, 4), // r4
    PReg.new(.int, 5), // r5
    PReg.new(.int, 6), // r6
};

const s390x_float_args = [_]PReg{
    PReg.new(.float, 0), // f0
    PReg.new(.float, 2), // f2
    PReg.new(.float, 4), // f4
    PReg.new(.float, 6), // f6
};

const s390x_int_rets = [_]PReg{
    PReg.new(.int, 2), // r2
    PReg.new(.int, 3), // r3
};

const s390x_float_rets = [_]PReg{
    PReg.new(.float, 0), // f0
    PReg.new(.float, 2), // f2
};

const s390x_callee_saves = [_]PReg{
    PReg.new(.int, 6),  // r6
    PReg.new(.int, 7),  // r7
    PReg.new(.int, 8),  // r8
    PReg.new(.int, 9),  // r9
    PReg.new(.int, 10), // r10
    PReg.new(.int, 11), // r11
    PReg.new(.int, 12), // r12
    PReg.new(.int, 13), // r13
    PReg.new(.int, 14), // r14
    PReg.new(.float, 8),  // f8
    PReg.new(.float, 9),  // f9
    PReg.new(.float, 10), // f10
    PReg.new(.float, 11), // f11
    PReg.new(.float, 12), // f12
    PReg.new(.float, 13), // f13
    PReg.new(.float, 14), // f14
    PReg.new(.float, 15), // f15
};

pub fn sysv() abi_mod.ABIMachineSpec(u64) {
    return .{
        .int_arg_regs = &s390x_int_args,
        .float_arg_regs = &s390x_float_args,
        .int_ret_regs = &s390x_int_rets,
        .float_ret_regs = &s390x_float_rets,
        .callee_saves = &s390x_callee_saves,
        .stack_align = 8,
        .align_int_pairs = false,
    };
}

pub const S390xABICallee = struct {
    sig: abi_mod.ABISignature,
    abi: abi_mod.ABIMachineSpec(u64),
    call_conv: ?abi_mod.ABICallingConvention,
    clobbered_callee_saves: std.ArrayList(PReg),
    frame_size: u32,

    pub fn init(
        _allocator: std.mem.Allocator,
        sig: abi_mod.ABISignature,
    ) S390xABICallee {
        _ = _allocator;
        const abi_spec = sysv();

        return .{
            .sig = sig,
            .abi = abi_spec,
            .call_conv = null,
            .clobbered_callee_saves = std.ArrayList(PReg){},
            .frame_size = 0,
        };
    }

    pub fn deinit(self: *S390xABICallee) void {
        if (self.call_conv) |*cc| {
            var cc_mut = cc;
            cc_mut.deinit();
        }
        self.clobbered_callee_saves.deinit();
    }

    pub fn computeCallConv(self: *S390xABICallee, allocator: Allocator) !void {
        self.call_conv = try abi_mod.ABICallingConvention.new(
            allocator,
            self.sig,
            self.abi,
        );
    }

    pub fn genPrologue(self: *S390xABICallee, vcode: *vcode_mod.VCode(Inst)) !void {
        _ = self;
        _ = vcode;
    }

    pub fn genEpilogue(self: *S390xABICallee, vcode: *vcode_mod.VCode(Inst)) !void {
        _ = self;
        _ = vcode;
    }
};

pub const S390xABICaller = struct {
    sig: abi_mod.ABISignature,
    abi: abi_mod.ABIMachineSpec(u64),
    call_conv: ?abi_mod.ABICallingConvention,

    pub fn init(
        _allocator: std.mem.Allocator,
        sig: abi_mod.ABISignature,
    ) S390xABICaller {
        _ = _allocator;
        const abi_spec = sysv();

        return .{
            .sig = sig,
            .abi = abi_spec,
            .call_conv = null,
        };
    }

    pub fn deinit(self: *S390xABICaller) void {
        if (self.call_conv) |*cc| {
            var cc_mut = cc;
            cc_mut.deinit();
        }
    }

    pub fn computeCallConv(self: *S390xABICaller, allocator: Allocator) !void {
        self.call_conv = try abi_mod.ABICallingConvention.new(
            allocator,
            self.sig,
            self.abi,
        );
    }

    pub fn emitCall(self: *S390xABICaller, vcode: *vcode_mod.VCode(Inst)) !void {
        _ = self;
        _ = vcode;
    }
};

test "SysV ABI spec" {
    const abi_spec = sysv();
    try testing.expectEqual(@as(usize, 5), abi_spec.int_arg_regs.len);
    try testing.expectEqual(@as(usize, 4), abi_spec.float_arg_regs.len);
    try testing.expectEqual(@as(usize, 2), abi_spec.int_ret_regs.len);
    try testing.expectEqual(@as(usize, 2), abi_spec.float_ret_regs.len);
    try testing.expectEqual(@as(u32, 8), abi_spec.stack_align);
}

test "S390xABICallee init" {
    const sig = abi_mod.ABISignature{
        .params = &.{},
        .returns = &.{},
        .call_conv = .system_v,
    };

    var callee = S390xABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    try testing.expectEqual(@as(u32, 0), callee.frame_size);
}

test "S390xABICaller init" {
    const sig = abi_mod.ABISignature{
        .params = &.{},
        .returns = &.{},
        .call_conv = .system_v,
    };

    var caller = S390xABICaller.init(testing.allocator, sig);
    defer caller.deinit();

    try testing.expect(caller.call_conv == null);
}
