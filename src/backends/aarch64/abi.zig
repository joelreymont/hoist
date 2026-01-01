const std = @import("std");
const testing = std.testing;

const root = @import("root");
const abi_mod = root.abi;
const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const PReg = root.aarch64_inst.PReg;
const WritableReg = root.aarch64_inst.WritableReg;
const OperandSize = root.aarch64_inst.OperandSize;
const buffer_mod = root.buffer;
const vcode_mod = root.vcode;

/// ARM64 AAPCS ABI machine spec.
pub fn aapcs64() abi_mod.ABIMachineSpec(u64) {
    // AAPCS64 argument registers: X0-X7
    const int_args = [_]PReg{
        PReg.new(.int, 0), // X0
        PReg.new(.int, 1), // X1
        PReg.new(.int, 2), // X2
        PReg.new(.int, 3), // X3
        PReg.new(.int, 4), // X4
        PReg.new(.int, 5), // X5
        PReg.new(.int, 6), // X6
        PReg.new(.int, 7), // X7
    };

    // V0-V7 for float args
    const float_args = [_]PReg{
        PReg.new(.float, 0),
        PReg.new(.float, 1),
        PReg.new(.float, 2),
        PReg.new(.float, 3),
        PReg.new(.float, 4),
        PReg.new(.float, 5),
        PReg.new(.float, 6),
        PReg.new(.float, 7),
    };

    // Return registers: X0-X7 for integers
    const int_rets = [_]PReg{
        PReg.new(.int, 0), // X0
        PReg.new(.int, 1), // X1
        PReg.new(.int, 2), // X2
        PReg.new(.int, 3), // X3
        PReg.new(.int, 4), // X4
        PReg.new(.int, 5), // X5
        PReg.new(.int, 6), // X6
        PReg.new(.int, 7), // X7
    };

    // V0-V7 for float returns
    const float_rets = [_]PReg{
        PReg.new(.float, 0),
        PReg.new(.float, 1),
        PReg.new(.float, 2),
        PReg.new(.float, 3),
        PReg.new(.float, 4),
        PReg.new(.float, 5),
        PReg.new(.float, 6),
        PReg.new(.float, 7),
    };

    // Callee-saves: X19-X28, X29 (FP), X30 (LR)
    const callee_saves = [_]PReg{
        PReg.new(.int, 19),
        PReg.new(.int, 20),
        PReg.new(.int, 21),
        PReg.new(.int, 22),
        PReg.new(.int, 23),
        PReg.new(.int, 24),
        PReg.new(.int, 25),
        PReg.new(.int, 26),
        PReg.new(.int, 27),
        PReg.new(.int, 28),
        PReg.new(.int, 29), // FP
        PReg.new(.int, 30), // LR
    };

    return .{
        .int_arg_regs = &int_args,
        .float_arg_regs = &float_args,
        .int_ret_regs = &int_rets,
        .float_ret_regs = &float_rets,
        .callee_saves = &callee_saves,
        .stack_align = 16,
    };
}

/// Round up size to 16-byte alignment as required by AAPCS64.
fn alignTo16(size: u32) u32 {
    return (size + 15) & ~@as(u32, 15);
}

/// Calculate total stack frame size including alignment.
/// Frame layout (high to low address):
/// - Saved FP + LR (16 bytes)
/// - Callee-save registers (8 bytes each, paired if odd count)
/// - Local variables and spills
/// Total must be 16-byte aligned per AAPCS64 section 6.2.2.
fn calculateFrameSize(locals_and_spills: u32, num_callee_saves: u32) u32 {
    // FP + LR = 16 bytes (already aligned)
    const fp_lr_size: u32 = 16;

    // Callee-saves: round up to even count for STP pairing, each pair = 16 bytes
    const callee_save_pairs = (num_callee_saves + 1) / 2;
    const callee_save_size = callee_save_pairs * 16;

    // Total before alignment
    const total = fp_lr_size + callee_save_size + locals_and_spills;

    // Ensure 16-byte alignment
    return alignTo16(total);
}

/// Prologue/epilogue generation for aarch64 functions.
pub const Aarch64ABICallee = struct {
    /// Function signature.
    sig: abi_mod.ABISignature,
    /// Calling convention.
    abi: abi_mod.ABIMachineSpec(u64),
    /// Computed calling convention.
    call_conv: ?abi_mod.ABICallingConvention,
    /// Callee-save registers to preserve.
    clobbered_callee_saves: std.ArrayList(PReg),
    /// Stack frame size for locals and spills (before alignment).
    locals_size: u32,
    /// Total aligned stack frame size (including FP, LR, callee-saves).
    frame_size: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        sig: abi_mod.ABISignature,
    ) Aarch64ABICallee {
        const abi = switch (sig.call_conv) {
            .aapcs64 => aapcs64(),
            .system_v, .windows_fastcall => unreachable,
        };

        return .{
            .sig = sig,
            .abi = abi,
            .call_conv = null,
            .clobbered_callee_saves = std.ArrayList(PReg).init(allocator),
            .locals_size = 0,
            .frame_size = 0,
        };
    }

    /// Set the size needed for local variables and spills.
    /// This will recalculate the total frame size with proper alignment.
    pub fn setLocalsSize(self: *Aarch64ABICallee, size: u32) void {
        self.locals_size = size;
        self.frame_size = calculateFrameSize(
            self.locals_size,
            @intCast(self.clobbered_callee_saves.items.len),
        );
    }

    pub fn deinit(self: *Aarch64ABICallee) void {
        if (self.call_conv) |*cc| {
            var cc_mut = cc;
            cc_mut.deinit();
        }
        self.clobbered_callee_saves.deinit();
    }

    /// Compute calling convention and setup frame.
    pub fn computeCallConv(self: *Aarch64ABICallee, allocator: std.mem.Allocator) !void {
        self.call_conv = try self.abi.computeCallingConvention(self.sig, allocator);
    }

    /// Emit function prologue.
    /// Saves FP, LR, callee-saves, and allocates stack frame with 16-byte alignment.
    /// Frame layout (high to low address):
    ///   [SP at entry]
    ///   [FP, LR] <- saved by STP with pre-index
    ///   [callee-saves] <- saved in pairs with STP
    ///   [locals/spills]
    ///   [SP after prologue] <- 16-byte aligned
    pub fn emitPrologue(
        self: *Aarch64ABICallee,
        buffer: *buffer_mod.MachBuffer,
    ) !void {
        const emit_fn = @import("emit.zig").emit;

        const fp = Reg.fromPReg(PReg.new(.int, 29)); // X29 (FP)
        const lr = Reg.fromPReg(PReg.new(.int, 30)); // X30 (LR)
        const sp = Reg.fromPReg(PReg.new(.int, 31)); // SP
        const fp_w = WritableReg.fromReg(fp);
        // Recalculate frame size to ensure alignment
        self.frame_size = calculateFrameSize(
            self.locals_size,
            @intCast(self.clobbered_callee_saves.items.len),
        );

        // 1. Save FP and LR with pre-index: STP X29, X30, [SP, #-frame_size]!
        // This allocates the entire frame and saves FP/LR atomically
        const frame_offset: i16 = -@as(i16, @intCast(self.frame_size));
        try emit_fn(.{ .stp = .{
            .src1 = fp,
            .src2 = lr,
            .base = sp,
            .offset = frame_offset,
            .size = .size64,
        } }, buffer);

        // 2. Set up frame pointer: MOV X29, SP
        try emit_fn(.{ .mov_rr = .{
            .dst = fp_w,
            .src = sp,
            .size = .size64,
        } }, buffer);

        // 3. Save callee-save registers in pairs using STP
        // Stack offset starts after FP/LR (16 bytes from SP)
        var stack_offset: i16 = 16;
        var i: usize = 0;
        while (i < self.clobbered_callee_saves.items.len) : (i += 2) {
            const reg1 = Reg.fromPReg(self.clobbered_callee_saves.items[i]);

            if (i + 1 < self.clobbered_callee_saves.items.len) {
                // Save pair with STP
                const reg2 = Reg.fromPReg(self.clobbered_callee_saves.items[i + 1]);
                try emit_fn(.{ .stp = .{
                    .src1 = reg1,
                    .src2 = reg2,
                    .base = sp,
                    .offset = stack_offset,
                    .size = .size64,
                } }, buffer);
                stack_offset += 16;
            } else {
                // Odd register: save with STR and pad with 8 bytes
                try emit_fn(.{ .str = .{
                    .src = reg1,
                    .base = sp,
                    .offset = stack_offset,
                    .size = .size64,
                } }, buffer);
                stack_offset += 16; // Reserve 16 bytes for alignment
            }
        }
    }

    /// Emit function epilogue.
    /// Restores callee-saves, FP, LR, and returns with proper stack cleanup.
    pub fn emitEpilogue(
        self: *Aarch64ABICallee,
        buffer: *buffer_mod.MachBuffer,
    ) !void {
        const emit_fn = @import("emit.zig").emit;

        const fp = Reg.fromPReg(PReg.new(.int, 29));
        const lr = Reg.fromPReg(PReg.new(.int, 30));
        const sp = Reg.fromPReg(PReg.new(.int, 31));
        const fp_w = WritableReg.fromReg(fp);
        const lr_w = WritableReg.fromReg(lr);

        // 1. Restore callee-save registers in reverse order (using pairs)
        var stack_offset: i16 = 16;
        var i: usize = 0;
        while (i < self.clobbered_callee_saves.items.len) : (i += 2) {
            const reg1_w = WritableReg.fromReg(Reg.fromPReg(self.clobbered_callee_saves.items[i]));

            if (i + 1 < self.clobbered_callee_saves.items.len) {
                // Restore pair with LDP
                const reg2_w = WritableReg.fromReg(Reg.fromPReg(self.clobbered_callee_saves.items[i + 1]));
                try emit_fn(.{ .ldp = .{
                    .dst1 = reg1_w,
                    .dst2 = reg2_w,
                    .base = sp,
                    .offset = stack_offset,
                    .size = .size64,
                } }, buffer);
                stack_offset += 16;
            } else {
                // Odd register: restore with LDR
                try emit_fn(.{ .ldr = .{
                    .dst = reg1_w,
                    .base = sp,
                    .offset = stack_offset,
                    .size = .size64,
                } }, buffer);
                stack_offset += 16; // Skip padding
            }
        }

        // 2. Restore FP and LR, deallocate frame: LDP X29, X30, [SP], #frame_size
        // Post-index form adds frame_size to SP after loading
        try emit_fn(.{ .ldp = .{
            .dst1 = fp_w,
            .dst2 = lr_w,
            .base = sp,
            .offset = @intCast(self.frame_size),
            .size = .size64,
        } }, buffer);

        // 3. Return: RET (defaults to X30/LR)
        try emit_fn(.{ .ret = .{ .reg = null } }, buffer);
    }

    /// Mark a callee-save register as clobbered.
    pub fn clobberCalleeSave(self: *Aarch64ABICallee, preg: PReg) !void {
        // Check if already in list
        for (self.clobbered_callee_saves.items) |existing| {
            if (std.meta.eql(existing, preg)) return;
        }
        try self.clobbered_callee_saves.append(preg);
    }
};

test "Aarch64ABICallee prologue/epilogue" {
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    try callee.computeCallConv(testing.allocator);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Should have: STP FP/LR, MOV FP SP, LDP FP/LR, RET
    try testing.expect(buffer.data.items.len >= 16);
}

test "Aarch64ABICallee with callee-saves" {
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Mark X19 as clobbered
    try callee.clobberCalleeSave(PReg.new(.int, 19));

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Should save/restore X19
    try testing.expect(buffer.data.items.len >= 20);
}

test "AAPCS64 ABI" {
    const abi = aapcs64();

    const args = [_]abi_mod.Type{ .i64, .i64, .i64, .i64, .i64, .i64, .i64, .i64, .i64 };
    const sig = abi_mod.ABISignature.init(&args, &.{}, .aapcs64);

    const arg_locs = try abi.computeArgLocs(sig, testing.allocator);
    defer {
        for (arg_locs) |arg| {
            testing.allocator.free(arg.slots);
        }
        testing.allocator.free(arg_locs);
    }

    // First 8 in X0-X7
    for (0..8) |i| {
        try testing.expect(arg_locs[i].slots[0] == .reg);
        try testing.expectEqual(PReg.new(.int, @intCast(i)), arg_locs[i].slots[0].reg.preg);
    }

    // 9th on stack
    try testing.expect(arg_locs[8].slots[0] == .stack);
}

test "alignTo16 helper function" {
    // Already aligned
    try testing.expectEqual(@as(u32, 0), alignTo16(0));
    try testing.expectEqual(@as(u32, 16), alignTo16(16));
    try testing.expectEqual(@as(u32, 32), alignTo16(32));
    try testing.expectEqual(@as(u32, 48), alignTo16(48));

    // Needs alignment
    try testing.expectEqual(@as(u32, 16), alignTo16(1));
    try testing.expectEqual(@as(u32, 16), alignTo16(15));
    try testing.expectEqual(@as(u32, 32), alignTo16(17));
    try testing.expectEqual(@as(u32, 32), alignTo16(31));
    try testing.expectEqual(@as(u32, 48), alignTo16(33));
    try testing.expectEqual(@as(u32, 48), alignTo16(47));
}

test "calculateFrameSize with no locals and no callee-saves" {
    // Only FP + LR = 16 bytes (already aligned)
    const frame_size = calculateFrameSize(0, 0);
    try testing.expectEqual(@as(u32, 16), frame_size);
    try testing.expectEqual(@as(u32, 0), frame_size % 16);
}

test "calculateFrameSize with locals only" {
    // FP+LR (16) + 8 bytes locals = 24, rounds to 32
    const frame_size = calculateFrameSize(8, 0);
    try testing.expectEqual(@as(u32, 32), frame_size);
    try testing.expectEqual(@as(u32, 0), frame_size % 16);

    // FP+LR (16) + 24 bytes locals = 40, rounds to 48
    const frame_size2 = calculateFrameSize(24, 0);
    try testing.expectEqual(@as(u32, 48), frame_size2);
    try testing.expectEqual(@as(u32, 0), frame_size2 % 16);
}

test "calculateFrameSize with one callee-save" {
    // FP+LR (16) + 1 callee-save rounded to 1 pair (16) = 32
    const frame_size = calculateFrameSize(0, 1);
    try testing.expectEqual(@as(u32, 32), frame_size);
    try testing.expectEqual(@as(u32, 0), frame_size % 16);
}

test "calculateFrameSize with two callee-saves" {
    // FP+LR (16) + 2 callee-saves = 1 pair (16) = 32
    const frame_size = calculateFrameSize(0, 2);
    try testing.expectEqual(@as(u32, 32), frame_size);
    try testing.expectEqual(@as(u32, 0), frame_size % 16);
}

test "calculateFrameSize with three callee-saves" {
    // FP+LR (16) + 3 callee-saves rounded to 2 pairs (32) = 48
    const frame_size = calculateFrameSize(0, 3);
    try testing.expectEqual(@as(u32, 48), frame_size);
    try testing.expectEqual(@as(u32, 0), frame_size % 16);
}

test "calculateFrameSize complex case" {
    // FP+LR (16) + 5 callee-saves rounded to 3 pairs (48) + 17 locals = 81, rounds to 96
    const frame_size = calculateFrameSize(17, 5);
    try testing.expectEqual(@as(u32, 96), frame_size);
    try testing.expectEqual(@as(u32, 0), frame_size % 16);
}

test "setLocalsSize updates frame_size correctly" {
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Initially zero
    try testing.expectEqual(@as(u32, 0), callee.locals_size);
    try testing.expectEqual(@as(u32, 0), callee.frame_size);

    // Set 8 bytes of locals (no callee-saves)
    // Expected: FP+LR (16) + locals (8) = 24, rounds to 32
    callee.setLocalsSize(8);
    try testing.expectEqual(@as(u32, 8), callee.locals_size);
    try testing.expectEqual(@as(u32, 32), callee.frame_size);
    try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);

    // Add a callee-save
    try callee.clobberCalleeSave(PReg.new(.int, 19));

    // Update locals size - should recalculate with callee-save
    // Expected: FP+LR (16) + 1 callee-save pair (16) + locals (8) = 40, rounds to 48
    callee.setLocalsSize(8);
    try testing.expectEqual(@as(u32, 48), callee.frame_size);
    try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);
}

test "frame alignment with multiple callee-saves" {
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Add 3 callee-saves (X19, X20, X21)
    try callee.clobberCalleeSave(PReg.new(.int, 19));
    try callee.clobberCalleeSave(PReg.new(.int, 20));
    try callee.clobberCalleeSave(PReg.new(.int, 21));

    // Set 25 bytes of locals
    // Expected: FP+LR (16) + 3 callee-saves rounded to 2 pairs (32) + locals (25) = 73, rounds to 80
    callee.setLocalsSize(25);
    try testing.expectEqual(@as(u32, 80), callee.frame_size);
    try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Verify we generated code
    try testing.expect(buffer.data.items.len > 0);
}
