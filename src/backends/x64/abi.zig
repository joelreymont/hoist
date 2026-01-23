const std = @import("std");
const testing = std.testing;

const root = @import("root");
const abi_mod = root.abi;
const Inst = root.x64_inst.Inst;
const Reg = root.x64_inst.Reg;
const PReg = root.x64_inst.PReg;
const WritableReg = root.x64_inst.WritableReg;
const OperandSize = root.x64_inst.OperandSize;
const buffer_mod = root.buffer;
const vcode_mod = root.vcode;

/// System V AMD64 ABI machine spec.
pub fn systemV() abi_mod.ABIMachineSpec(u64) {
    return abi_mod.sysv_amd64();
}

/// Windows x64 ABI machine spec.
const win_int_args = [_]PReg{
    PReg.new(.int, 1), // RCX
    PReg.new(.int, 2), // RDX
    PReg.new(.int, 8), // R8
    PReg.new(.int, 9), // R9
};

const win_float_args = [_]PReg{
    PReg.new(.float, 0),
    PReg.new(.float, 1),
    PReg.new(.float, 2),
    PReg.new(.float, 3),
};

const win_int_rets = [_]PReg{
    PReg.new(.int, 0), // RAX
};

const win_float_rets = [_]PReg{
    PReg.new(.float, 0),
};

const win_callee_saves = [_]PReg{
    PReg.new(.int, 3), // RBX
    PReg.new(.int, 5), // RBP
    PReg.new(.int, 7), // RDI
    PReg.new(.int, 6), // RSI
    PReg.new(.int, 12),
    PReg.new(.int, 13),
    PReg.new(.int, 14),
    PReg.new(.int, 15),
};

pub fn windowsFastcall() abi_mod.ABIMachineSpec(u64) {
    return .{
        .int_arg_regs = &win_int_args,
        .float_arg_regs = &win_float_args,
        .int_ret_regs = &win_int_rets,
        .float_ret_regs = &win_float_rets,
        .callee_saves = &win_callee_saves,
        .stack_align = 16,
        .align_int_pairs = false,
    };
}

/// Prologue/epilogue generation for x64 functions.
pub const X64ABICallee = struct {
    /// Function signature.
    sig: abi_mod.ABISignature,
    /// Calling convention.
    abi: abi_mod.ABIMachineSpec(u64),
    /// Computed calling convention.
    call_conv: ?abi_mod.ABICallingConvention,
    /// Callee-save registers to preserve.
    clobbered_callee_saves: std.ArrayList(PReg),
    /// Stack frame size (local slots only).
    frame_size: u32,
    /// Shadow space size (Win64: 32 bytes).
    shadow_size: u32,
    /// Struct return pointer register (SysV: RAX, Win64: RCX implicit in return).
    sret_reg: ?PReg,

    pub fn init(
        _allocator: std.mem.Allocator,
        sig: abi_mod.ABISignature,
    ) X64ABICallee {
        _ = _allocator;
        const abi = switch (sig.call_conv) {
            .system_v => systemV(),
            .windows_fastcall => windowsFastcall(),
            .aapcs64 => unreachable,
        };

        const shadow_sz: u32 = if (sig.call_conv == .windows_fastcall) 32 else 0;

        return .{
            .sig = sig,
            .abi = abi,
            .call_conv = null,
            .clobbered_callee_saves = std.ArrayList(PReg){},
            .frame_size = 0,
            .shadow_size = shadow_sz,
            .sret_reg = null,
        };
    }

    pub fn deinit(self: *X64ABICallee) void {
        if (self.call_conv) |*cc| {
            var cc_mut = cc;
            cc_mut.deinit();
        }
        self.clobbered_callee_saves.deinit();
    }

    /// Compute calling convention and setup frame.
    pub fn computeCallConv(self: *X64ABICallee, allocator: std.mem.Allocator) !void {
        self.call_conv = try self.abi.computeCallingConvention(self.sig, allocator);
    }

    /// Emit function prologue.
    /// Saves callee-save registers and allocates stack frame.
    pub fn emitPrologue(
        self: *X64ABICallee,
        buffer: *buffer_mod.MachBuffer,
    ) !void {
        const emit_fn = @import("emit.zig").emit;

        // Push RBP (frame pointer)
        const rbp = Reg.fromPReg(PReg.new(.int, 5));
        try emit_fn(.{ .push_r = .{ .src = rbp } }, buffer);

        // MOV RBP, RSP (setup frame pointer)
        const rsp = Reg.fromPReg(PReg.new(.int, 4));
        const rbp_w = WritableReg.fromReg(rbp);
        try emit_fn(.{ .mov_rr = .{
            .dst = rbp_w,
            .src = rsp,
            .size = .size64,
        } }, buffer);

        // Push callee-save registers
        for (self.clobbered_callee_saves.items) |preg| {
            const reg = Reg.fromPReg(preg);
            try emit_fn(.{ .push_r = .{ .src = reg } }, buffer);
        }

        // Allocate stack frame + shadow space (if needed)
        const total_size = self.frame_size + self.shadow_size;
        if (total_size > 0) {
            const rsp_w = WritableReg.fromReg(rsp);
            try emit_fn(.{
                .sub_imm = .{
                    .dst = rsp_w,
                    .imm = @intCast(total_size),
                    .size = .size64,
                },
            }, buffer);
        }
    }

    /// Emit function epilogue.
    /// Restores callee-save registers and returns.
    pub fn emitEpilogue(
        self: *X64ABICallee,
        buffer: *buffer_mod.MachBuffer,
    ) !void {
        const emit_fn = @import("emit.zig").emit;

        // Deallocate stack frame + shadow space (if needed)
        const total_size = self.frame_size + self.shadow_size;
        if (total_size > 0) {
            const rsp = Reg.fromPReg(PReg.new(.int, 4));
            const rsp_w = WritableReg.fromReg(rsp);
            try emit_fn(.{ .add_imm = .{
                .dst = rsp_w,
                .imm = @intCast(total_size),
                .size = .size64,
            } }, buffer);
        }

        // Pop callee-save registers (reverse order)
        var i = self.clobbered_callee_saves.items.len;
        while (i > 0) {
            i -= 1;
            const preg = self.clobbered_callee_saves.items[i];
            const reg = Reg.fromPReg(preg);
            const wreg = WritableReg.fromReg(reg);
            try emit_fn(.{ .pop_r = .{ .dst = wreg } }, buffer);
        }

        // Pop RBP
        const rbp = Reg.fromPReg(PReg.new(.int, 5));
        const rbp_w = WritableReg.fromReg(rbp);
        try emit_fn(.{ .pop_r = .{ .dst = rbp_w } }, buffer);

        // Return
        try emit_fn(.ret, buffer);
    }

    /// Mark a callee-save register as clobbered.
    pub fn clobberCalleeSave(self: *X64ABICallee, preg: PReg) !void {
        // Check if already in list
        for (self.clobbered_callee_saves.items) |existing| {
            if (std.meta.eql(existing, preg)) return;
        }
        try self.clobbered_callee_saves.append(preg);
    }
};

test "X64ABICallee prologue/epilogue" {
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .system_v);

    var callee = X64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    try callee.computeCallConv(testing.allocator);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Should have: PUSH RBP, MOV RBP RSP, POP RBP, RET
    try testing.expect(buffer.data.items.len >= 4);
}

test "X64ABICallee with callee-saves" {
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .system_v);

    var callee = X64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Mark RBX as clobbered
    try callee.clobberCalleeSave(PReg.new(.int, 3));

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Should save/restore RBX
    try testing.expect(buffer.data.items.len >= 6);
}

test "Windows fastcall ABI" {
    const abi = windowsFastcall();

    const args = [_]abi_mod.Type{ .i64, .i64, .i64, .i64, .i64 };
    const sig = abi_mod.ABISignature.init(&args, &.{}, .windows_fastcall);

    const arg_locs = try abi.computeArgLocs(sig, testing.allocator);
    defer {
        for (arg_locs) |arg| {
            testing.allocator.free(arg.slots);
        }
        testing.allocator.free(arg_locs);
    }

    // First 4 in RCX, RDX, R8, R9
    try testing.expectEqual(PReg.new(.int, 1), arg_locs[0].slots[0].reg.preg); // RCX
    try testing.expectEqual(PReg.new(.int, 2), arg_locs[1].slots[0].reg.preg); // RDX
    try testing.expectEqual(PReg.new(.int, 8), arg_locs[2].slots[0].reg.preg); // R8
    try testing.expectEqual(PReg.new(.int, 9), arg_locs[3].slots[0].reg.preg); // R9

    // 5th on stack
    try testing.expect(arg_locs[4].slots[0] == .stack);
}

/// Check if signature needs struct return (sret) handling.
/// Sret is passed as an implicit first parameter (pointer in RDI/RCX).
pub fn needsStructReturn(params: []const @import("../../ir/signature.zig").AbiParam) bool {
    const sig_mod = @import("../../ir/signature.zig");
    for (params) |param| {
        if (param.purpose == sig_mod.ArgumentPurpose.struct_return) {
            return true;
        }
    }
    return false;
}

/// Get sret register for calling convention.
/// SysV: RDI (first int arg reg, hw_enc=7).
/// Win64: RCX (first int arg reg, hw_enc=1).
pub fn sretReg(cc: abi_mod.CallConv) PReg {
    return switch (cc) {
        .system_v => PReg.new(.int, 7), // RDI
        .windows_fastcall => PReg.new(.int, 1), // RCX
        .aapcs64 => unreachable,
    };
}

test "needsStructReturn" {
    const sig_mod = @import("../../ir/signature.zig");
    const AbiParam = sig_mod.AbiParam;
    const Type = @import("../../ir/types.zig").Type;

    // No sret param
    const args1 = [_]AbiParam{AbiParam.new(Type.i64)};
    try testing.expectEqual(false, needsStructReturn(&args1));

    // Explicit struct_return param
    const args2 = [_]AbiParam{
        AbiParam.special(Type.i64, sig_mod.ArgumentPurpose.struct_return),
    };
    try testing.expectEqual(true, needsStructReturn(&args2));
}

test "sretReg" {
    try testing.expectEqual(PReg.new(.int, 7), sretReg(.system_v)); // RDI
    try testing.expectEqual(PReg.new(.int, 1), sretReg(.windows_fastcall)); // RCX
}
