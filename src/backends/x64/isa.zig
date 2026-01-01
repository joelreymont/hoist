const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.x64_inst.Inst;
const abi_mod = root.abi;
const lower_mod = root.lower;
const compile_mod = root.compile;

/// X64 ISA descriptor.
/// This integrates all x64 backend components into a unified interface.
pub const X64ISA = struct {
    /// ISA name.
    pub const name = "x86_64";

    /// Machine instruction type.
    pub const MachInst = Inst;

    /// ABI specification for this ISA.
    pub fn abi(call_conv: abi_mod.CallConv) abi_mod.ABIMachineSpec(u64) {
        return switch (call_conv) {
            .system_v => @import("abi.zig").systemV(),
            .windows_fastcall => @import("abi.zig").windowsFastcall(),
            .aapcs64 => unreachable,
        };
    }

    /// Lowering backend for instruction selection.
    pub fn lower() lower_mod.LowerBackend(Inst) {
        return @import("lower.zig").X64Lower.backend();
    }

    /// Register information.
    pub const registers = struct {
        /// Number of general-purpose registers.
        pub const num_gpr: u8 = 16;
        /// Number of vector registers.
        pub const num_vec: u8 = 16;
        /// Stack pointer register.
        pub const sp_reg = 4; // RSP
        /// Frame pointer register.
        pub const fp_reg = 5; // RBP
        /// Link register (none on x64).
        pub const lr_reg: ?u8 = null;
    };

    /// Compile a function to machine code using this ISA.
    pub fn compileFunction(
        ctx: compile_mod.CompileCtx,
        func: *const lower_mod.Function,
    ) !compile_mod.CompiledCode {
        return compile_mod.compile(
            Inst,
            ctx,
            func,
            lower(),
        );
    }
};

test "X64ISA basic properties" {
    try testing.expectEqualStrings("x86_64", X64ISA.name);
    try testing.expectEqual(@as(u8, 16), X64ISA.registers.num_gpr);
    try testing.expectEqual(@as(u8, 16), X64ISA.registers.num_vec);
    try testing.expectEqual(@as(u8, 4), X64ISA.registers.sp_reg);
}

test "X64ISA ABI selection" {
    const sysv = X64ISA.abi(.system_v);
    const win = X64ISA.abi(.windows_fastcall);

    // System V has 6 int arg regs
    try testing.expectEqual(@as(usize, 6), sysv.int_arg_regs.len);

    // Windows has 4 int arg regs
    try testing.expectEqual(@as(usize, 4), win.int_arg_regs.len);
}

test "X64ISA lowering backend" {
    const backend = X64ISA.lower();

    // Should have function pointers
    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);
}

test "X64ISA compile function" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    const ctx = compile_mod.CompileCtx.init(testing.allocator, "x86_64");

    var code = try X64ISA.compileFunction(ctx, &func);
    defer code.deinit();

    // Empty function produces minimal code
    try testing.expect(code.code.len == 0);
}
