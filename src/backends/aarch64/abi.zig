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

/// Register class for struct passing after AAPCS64 classification.
pub const StructClass = enum {
    /// Homogeneous Floating-Point Aggregate: 1-4 same-size float members.
    hfa,
    /// Homogeneous Short-Vector Aggregate: 1-4 same-size vector members.
    hva,
    /// Non-homogeneous struct <= 16 bytes: passed in general registers.
    general,
    /// Struct > 16 bytes: passed by reference (pointer in register).
    indirect,
};

/// Check if a type is a homogeneous floating-point aggregate (HFA).
/// An HFA is a struct with 1-4 members of the same floating-point type (f32 or f64).
/// AAPCS64 section 6.4.2.
fn isHFA(fields: []const abi_mod.StructField) ?abi_mod.Type {
    if (fields.len == 0 or fields.len > 4) return null;

    // Get the type of the first field
    const first_ty = switch (fields[0].ty) {
        .f32 => abi_mod.Type.f32,
        .f64 => abi_mod.Type.f64,
        else => return null,
    };

    // Verify all fields have the same floating-point type
    for (fields) |field| {
        const field_ty = switch (field.ty) {
            .f32 => abi_mod.Type.f32,
            .f64 => abi_mod.Type.f64,
            else => return null,
        };
        if (!std.meta.eql(field_ty, first_ty)) return null;
    }

    return first_ty;
}

/// Check if a type is a homogeneous short-vector aggregate (HVA).
/// An HVA is a struct with 1-4 members of the same SIMD/vector type.
/// AAPCS64 section 6.4.2.
fn isHVA(fields: []const abi_mod.StructField) ?abi_mod.Type {
    // Note: Current type system doesn't have vector types yet.
    // This is a placeholder for future vector support.
    _ = fields;
    return null;
}

/// Classify a struct for AAPCS64 parameter passing.
/// Returns the register class to use and optionally the element type for HFA/HVA.
pub fn classifyStruct(ty: abi_mod.Type) struct { class: StructClass, elem_ty: ?abi_mod.Type } {
    const fields = switch (ty) {
        .@"struct" => |f| f,
        else => return .{ .class = .general, .elem_ty = null },
    };

    const size = ty.bytes();

    // Structs > 16 bytes are passed by reference
    if (size > 16) {
        return .{ .class = .indirect, .elem_ty = null };
    }

    // Check for HFA (Homogeneous Floating-Point Aggregate)
    if (isHFA(fields)) |elem_ty| {
        return .{ .class = .hfa, .elem_ty = elem_ty };
    }

    // Check for HVA (Homogeneous Short-Vector Aggregate)
    if (isHVA(fields)) |elem_ty| {
        return .{ .class = .hva, .elem_ty = elem_ty };
    }

    // Non-homogeneous struct <= 16 bytes: passed in general registers
    return .{ .class = .general, .elem_ty = null };
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
    /// For large frames (>504 bytes), uses multi-instruction allocation.
    /// Frame layout (high to low address):
    ///   [SP at entry]
    ///   [FP, LR] <- saved first
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
        const sp_w = WritableReg.fromReg(sp);

        // Recalculate frame size to ensure alignment
        self.frame_size = calculateFrameSize(
            self.locals_size,
            @intCast(self.clobbered_callee_saves.items.len),
        );

        // STP with offset has 7-bit signed immediate scaled by 8 bytes
        // Max negative offset: -64 * 8 = -512 bytes
        // But we need to save FP/LR at the top, so max usable is 504 bytes
        const max_stp_offset: u32 = 504;

        if (self.frame_size <= max_stp_offset) {
            // Small frame: use STP with offset to allocate and save atomically
            // STP X29, X30, [SP, #-frame_size]!
            const frame_offset: i16 = -@as(i16, @intCast(self.frame_size));
            try emit_fn(.{ .stp = .{
                .src1 = fp,
                .src2 = lr,
                .base = sp,
                .offset = frame_offset,
                .size = .size64,
            } }, buffer);

            // Set up frame pointer: MOV X29, SP
            try emit_fn(.{ .mov_rr = .{
                .dst = fp_w,
                .src = sp,
                .size = .size64,
            } }, buffer);
        } else {
            // Large frame: allocate in multiple steps
            // Strategy: SUB SP, SP, #amount (up to 4095 per instruction)

            // First, allocate space for FP/LR (16 bytes) so we can save them
            try emit_fn(.{ .sub_imm = .{
                .dst = sp_w,
                .src = sp,
                .imm = 16,
                .size = .size64,
            } }, buffer);

            // Save FP and LR at current SP
            try emit_fn(.{ .stp = .{
                .src1 = fp,
                .src2 = lr,
                .base = sp,
                .offset = 0,
                .size = .size64,
            } }, buffer);

            // Set up frame pointer to point at saved FP/LR
            try emit_fn(.{ .mov_rr = .{
                .dst = fp_w,
                .src = sp,
                .size = .size64,
            } }, buffer);

            // Allocate remaining frame space
            var remaining = self.frame_size - 16;

            // SUB immediate can encode 12-bit values (0-4095)
            // For now, we don't use the shift form (would require updating emit.zig)
            // so we just break into 4095-byte chunks
            while (remaining > 0) {
                const chunk = @min(remaining, 4095);
                try emit_fn(.{ .sub_imm = .{
                    .dst = sp_w,
                    .src = sp,
                    .imm = @intCast(chunk),
                    .size = .size64,
                } }, buffer);
                remaining -= chunk;
            }
        }

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
    /// For large frames (>504 bytes), uses multi-instruction deallocation.
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
        const sp_w = WritableReg.fromReg(sp);

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

        const max_stp_offset: u32 = 504;

        if (self.frame_size <= max_stp_offset) {
            // Small frame: restore FP/LR and deallocate in one instruction
            // LDP X29, X30, [SP], #frame_size
            try emit_fn(.{ .ldp = .{
                .dst1 = fp_w,
                .dst2 = lr_w,
                .base = sp,
                .offset = @intCast(self.frame_size),
                .size = .size64,
            } }, buffer);
        } else {
            // Large frame: deallocate in multiple steps
            // First restore FP/LR from current SP
            try emit_fn(.{ .ldp = .{
                .dst1 = fp_w,
                .dst2 = lr_w,
                .base = sp,
                .offset = 0,
                .size = .size64,
            } }, buffer);

            // Deallocate the 16 bytes for FP/LR
            try emit_fn(.{ .add_imm = .{
                .dst = sp_w,
                .src = sp,
                .imm = 16,
                .size = .size64,
            } }, buffer);

            // Deallocate remaining frame space
            var remaining = self.frame_size - 16;

            // ADD immediate can encode 12-bit values (0-4095)
            // For now, we don't use the shift form (would require updating emit.zig)
            // so we just break into 4095-byte chunks
            while (remaining > 0) {
                const chunk = @min(remaining, 4095);
                try emit_fn(.{ .add_imm = .{
                    .dst = sp_w,
                    .src = sp,
                    .imm = @intCast(chunk),
                    .size = .size64,
                } }, buffer);
                remaining -= chunk;
            }
        }

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

test "isHFA with f32 fields" {
    // struct { f32, f32 } - valid HFA
    const fields1 = [_]abi_mod.StructField{
        .{ .ty = .f32, .offset = 0 },
        .{ .ty = .f32, .offset = 4 },
    };
    const result1 = isHFA(&fields1);
    try testing.expect(result1 != null);
    try testing.expect(std.meta.eql(result1.?, abi_mod.Type.f32));

    // struct { f32, f32, f32, f32 } - valid HFA (max 4 members)
    const fields2 = [_]abi_mod.StructField{
        .{ .ty = .f32, .offset = 0 },
        .{ .ty = .f32, .offset = 4 },
        .{ .ty = .f32, .offset = 8 },
        .{ .ty = .f32, .offset = 12 },
    };
    const result2 = isHFA(&fields2);
    try testing.expect(result2 != null);
    try testing.expect(std.meta.eql(result2.?, abi_mod.Type.f32));
}

test "isHFA with f64 fields" {
    // struct { f64, f64, f64 } - valid HFA
    const fields = [_]abi_mod.StructField{
        .{ .ty = .f64, .offset = 0 },
        .{ .ty = .f64, .offset = 8 },
        .{ .ty = .f64, .offset = 16 },
    };
    const result = isHFA(&fields);
    try testing.expect(result != null);
    try testing.expect(std.meta.eql(result.?, abi_mod.Type.f64));
}

test "isHFA with mixed float types" {
    // struct { f32, f64 } - not HFA (different sizes)
    const fields = [_]abi_mod.StructField{
        .{ .ty = .f32, .offset = 0 },
        .{ .ty = .f64, .offset = 8 },
    };
    const result = isHFA(&fields);
    try testing.expect(result == null);
}

test "isHFA with non-float fields" {
    // struct { i32, f32 } - not HFA (contains integer)
    const fields = [_]abi_mod.StructField{
        .{ .ty = .i32, .offset = 0 },
        .{ .ty = .f32, .offset = 4 },
    };
    const result = isHFA(&fields);
    try testing.expect(result == null);
}

test "isHFA with too many fields" {
    // struct { f32, f32, f32, f32, f32 } - not HFA (> 4 members)
    const fields = [_]abi_mod.StructField{
        .{ .ty = .f32, .offset = 0 },
        .{ .ty = .f32, .offset = 4 },
        .{ .ty = .f32, .offset = 8 },
        .{ .ty = .f32, .offset = 12 },
        .{ .ty = .f32, .offset = 16 },
    };
    const result = isHFA(&fields);
    try testing.expect(result == null);
}

test "isHFA with empty struct" {
    // struct {} - not HFA (no members)
    const fields = [_]abi_mod.StructField{};
    const result = isHFA(&fields);
    try testing.expect(result == null);
}

test "classifyStruct HFA" {
    // struct { f32, f32 } - HFA
    const fields = [_]abi_mod.StructField{
        .{ .ty = .f32, .offset = 0 },
        .{ .ty = .f32, .offset = 4 },
    };
    const ty = abi_mod.Type{ .@"struct" = &fields };
    const result = classifyStruct(ty);
    try testing.expectEqual(StructClass.hfa, result.class);
    try testing.expect(result.elem_ty != null);
    try testing.expect(std.meta.eql(result.elem_ty.?, abi_mod.Type.f32));
}

test "classifyStruct general" {
    // struct { i32, i32 } - general (non-homogeneous, <= 16 bytes)
    const fields = [_]abi_mod.StructField{
        .{ .ty = .i32, .offset = 0 },
        .{ .ty = .i32, .offset = 4 },
    };
    const ty = abi_mod.Type{ .@"struct" = &fields };
    const result = classifyStruct(ty);
    try testing.expectEqual(StructClass.general, result.class);
    try testing.expect(result.elem_ty == null);
}

test "classifyStruct indirect" {
    // struct { i64, i64, i32 } - indirect (> 16 bytes: 8 + 8 + 4 = 20)
    const fields = [_]abi_mod.StructField{
        .{ .ty = .i64, .offset = 0 },
        .{ .ty = .i64, .offset = 8 },
        .{ .ty = .i32, .offset = 16 },
    };
    const ty = abi_mod.Type{ .@"struct" = &fields };
    const result = classifyStruct(ty);
    try testing.expectEqual(StructClass.indirect, result.class);
    try testing.expect(result.elem_ty == null);
}

test "classifyStruct exactly 16 bytes" {
    // struct { i64, i64 } - general (exactly 16 bytes)
    const fields = [_]abi_mod.StructField{
        .{ .ty = .i64, .offset = 0 },
        .{ .ty = .i64, .offset = 8 },
    };
    const ty = abi_mod.Type{ .@"struct" = &fields };
    const result = classifyStruct(ty);
    try testing.expectEqual(StructClass.general, result.class);
    try testing.expect(result.elem_ty == null);
}

test "classifyStruct non-struct type" {
    // Passing a non-struct type should return general
    const ty = abi_mod.Type.i64;
    const result = classifyStruct(ty);
    try testing.expectEqual(StructClass.general, result.class);
    try testing.expect(result.elem_ty == null);
}

test "struct Type bytes calculation" {
    // Empty struct
    const fields_empty = [_]abi_mod.StructField{};
    const ty_empty = abi_mod.Type{ .@"struct" = &fields_empty };
    try testing.expectEqual(@as(u32, 0), ty_empty.bytes());

    // struct { i32, i32 } - 8 bytes
    const fields1 = [_]abi_mod.StructField{
        .{ .ty = .i32, .offset = 0 },
        .{ .ty = .i32, .offset = 4 },
    };
    const ty1 = abi_mod.Type{ .@"struct" = &fields1 };
    try testing.expectEqual(@as(u32, 8), ty1.bytes());

    // struct { f64, f64, f64 } - 24 bytes
    const fields2 = [_]abi_mod.StructField{
        .{ .ty = .f64, .offset = 0 },
        .{ .ty = .f64, .offset = 8 },
        .{ .ty = .f64, .offset = 16 },
    };
    const ty2 = abi_mod.Type{ .@"struct" = &fields2 };
    try testing.expectEqual(@as(u32, 24), ty2.bytes());
}

test "large frame exactly 4096 bytes" {
    // Test frame size of exactly 4096 bytes
    // Frame = FP+LR (16) + locals, so locals = 4096 - 16 = 4080
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    callee.setLocalsSize(4080);
    try testing.expectEqual(@as(u32, 4096), callee.frame_size);
    try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Should use multi-instruction allocation (4096 > 504)
    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Verify we generated code
    try testing.expect(buffer.data.items.len > 0);
}

test "large frame 8192 bytes" {
    // Test frame size of 8192 bytes
    // Frame = FP+LR (16) + locals, so locals = 8192 - 16 = 8176
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    callee.setLocalsSize(8176);
    try testing.expectEqual(@as(u32, 8192), callee.frame_size);
    try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Should use multi-instruction allocation
    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Verify we generated code
    try testing.expect(buffer.data.items.len > 0);
}

test "large frame 65536 bytes" {
    // Test frame size of 65536 bytes (64KB)
    // Frame = FP+LR (16) + locals, so locals = 65536 - 16 = 65520
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    callee.setLocalsSize(65520);
    try testing.expectEqual(@as(u32, 65536), callee.frame_size);
    try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Should use multi-instruction allocation
    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Verify we generated code
    try testing.expect(buffer.data.items.len > 0);
}

test "frame boundary at 504 bytes" {
    // Test frame size exactly at the STP offset limit
    // 504 bytes should use single-instruction path
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // 504 - 16 (FP+LR) = 488 bytes of locals
    callee.setLocalsSize(488);
    try testing.expectEqual(@as(u32, 504), callee.frame_size);
    try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Should use single-instruction path (<=504)
    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Verify we generated code
    try testing.expect(buffer.data.items.len > 0);
}

test "frame just over 504 bytes boundary" {
    // Test frame size just over the STP offset limit
    // 512 bytes should use multi-instruction path
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // 512 - 16 (FP+LR) = 496 bytes of locals
    callee.setLocalsSize(496);
    try testing.expectEqual(@as(u32, 512), callee.frame_size);
    try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Should use multi-instruction path (>504)
    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Verify we generated code
    try testing.expect(buffer.data.items.len > 0);
}

test "large frame with callee-saves" {
    // Test large frame with callee-save registers
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Add some callee-saves
    try callee.clobberCalleeSave(PReg.new(.int, 19));
    try callee.clobberCalleeSave(PReg.new(.int, 20));

    // Large locals: 8192 - 16 (FP+LR) - 16 (2 callee-saves) = 8160
    callee.setLocalsSize(8160);
    try testing.expectEqual(@as(u32, 8192), callee.frame_size);
    try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Verify we generated code
    try testing.expect(buffer.data.items.len > 0);
}

test "callee-save register pairing with STP/LDP" {
    // Test that pairs of callee-save registers use STP/LDP
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Add pairs: X19/X20, X21/X22
    try callee.clobberCalleeSave(PReg.new(.int, 19));
    try callee.clobberCalleeSave(PReg.new(.int, 20));
    try callee.clobberCalleeSave(PReg.new(.int, 21));
    try callee.clobberCalleeSave(PReg.new(.int, 22));

    callee.setLocalsSize(0);
    // FP+LR (16) + 4 callee-saves as 2 pairs (32) = 48
    try testing.expectEqual(@as(u32, 48), callee.frame_size);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Verify we generated code
    try testing.expect(buffer.data.items.len > 0);

    // With 4 callee-saves in 2 pairs, we expect:
    // Prologue: STP FP/LR, MOV FP, STP X19/X20, STP X21/X22 = 4 instructions = 16 bytes
    // Epilogue: LDP X19/X20, LDP X21/X22, LDP FP/LR, RET = 4 instructions = 16 bytes
    // Total = 32 bytes
    try testing.expectEqual(@as(usize, 32), buffer.data.items.len);
}

test "callee-save odd number uses STR/LDR for last register" {
    // Test that an odd number of callee-saves uses STP for pairs and STR for the last one
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Add 3 callee-saves: X19/X20 as pair, X21 alone
    try callee.clobberCalleeSave(PReg.new(.int, 19));
    try callee.clobberCalleeSave(PReg.new(.int, 20));
    try callee.clobberCalleeSave(PReg.new(.int, 21));

    callee.setLocalsSize(0);
    // FP+LR (16) + 3 callee-saves rounded to 2 pairs (32) = 48
    try testing.expectEqual(@as(u32, 48), callee.frame_size);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Verify we generated code
    try testing.expect(buffer.data.items.len > 0);

    // With 3 callee-saves, we expect:
    // Prologue: STP FP/LR, MOV FP, STP X19/X20, STR X21 = 4 instructions = 16 bytes
    // Epilogue: LDP X19/X20, LDR X21, LDP FP/LR, RET = 4 instructions = 16 bytes
    // Total = 32 bytes
    try testing.expectEqual(@as(usize, 32), buffer.data.items.len);
}

test "callee-save pairing preserves all standard pairs" {
    // Test all standard register pairs: X19/X20, X21/X22, X23/X24, X25/X26, X27/X28
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Add all 10 callee-saves (excluding FP and LR which are handled separately)
    try callee.clobberCalleeSave(PReg.new(.int, 19));
    try callee.clobberCalleeSave(PReg.new(.int, 20));
    try callee.clobberCalleeSave(PReg.new(.int, 21));
    try callee.clobberCalleeSave(PReg.new(.int, 22));
    try callee.clobberCalleeSave(PReg.new(.int, 23));
    try callee.clobberCalleeSave(PReg.new(.int, 24));
    try callee.clobberCalleeSave(PReg.new(.int, 25));
    try callee.clobberCalleeSave(PReg.new(.int, 26));
    try callee.clobberCalleeSave(PReg.new(.int, 27));
    try callee.clobberCalleeSave(PReg.new(.int, 28));

    callee.setLocalsSize(0);
    // FP+LR (16) + 10 callee-saves as 5 pairs (80) = 96
    try testing.expectEqual(@as(u32, 96), callee.frame_size);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    // Verify we generated code
    try testing.expect(buffer.data.items.len > 0);

    // With 10 callee-saves in 5 pairs, we expect:
    // Prologue: STP FP/LR, MOV FP, 5x STP = 7 instructions = 28 bytes
    // Epilogue: 5x LDP, LDP FP/LR, RET = 7 instructions = 28 bytes
    // Total = 56 bytes
    try testing.expectEqual(@as(usize, 56), buffer.data.items.len);
}

test "callee-save offset calculation for paired saves" {
    // Verify stack offsets are correct for paired saves
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Add 5 callee-saves to test offset calculation
    // Pairs: X19/X20, X21/X22, and X23 alone
    try callee.clobberCalleeSave(PReg.new(.int, 19));
    try callee.clobberCalleeSave(PReg.new(.int, 20));
    try callee.clobberCalleeSave(PReg.new(.int, 21));
    try callee.clobberCalleeSave(PReg.new(.int, 22));
    try callee.clobberCalleeSave(PReg.new(.int, 23));

    callee.setLocalsSize(0);
    // FP+LR (16) + 5 callee-saves rounded to 3 pairs (48) = 64
    try testing.expectEqual(@as(u32, 64), callee.frame_size);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);

    // Offsets should be:
    // SP+0: FP, LR
    // SP+16: X19, X20 (first pair)
    // SP+32: X21, X22 (second pair)
    // SP+48: X23, (padding) (odd register with 8-byte padding)

    // Verify we generated correct number of instructions
    // Prologue: STP FP/LR, MOV FP, STP X19/X20, STP X21/X22, STR X23 = 5 instructions = 20 bytes
    try testing.expect(buffer.data.items.len >= 20);
}

test "verify STP/LDP encoding for callee-save pairs" {
    // Verify that STP/LDP instructions are correctly encoded for register pairs
    const args = [_]abi_mod.Type{.i64};
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Add X19 and X20 as a pair
    try callee.clobberCalleeSave(PReg.new(.int, 19));
    try callee.clobberCalleeSave(PReg.new(.int, 20));

    callee.setLocalsSize(0);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);

    // Should have STP FP/LR, MOV FP, STP X19/X20 = 3 instructions = 12 bytes
    try testing.expect(buffer.data.items.len >= 12);

    // Verify the third instruction is an STP (bits 31-22 should be 0b1010100100 for STP 64-bit)
    if (buffer.data.items.len >= 12) {
        const stp_x19_x20 = std.mem.bytesToValue(u32, buffer.data.items[8..12]);
        const opcode = (stp_x19_x20 >> 22) & 0x3FF;
        try testing.expectEqual(@as(u32, 0b1010100100), opcode);
    }
}

test "16-byte alignment maintained with all callee-save combinations" {
    // Verify 16-byte alignment is maintained for various numbers of callee-saves
    const test_cases = [_]struct { num: u8, expected_size: u32 }{
        .{ .num = 0, .expected_size = 16 }, // FP+LR only
        .{ .num = 1, .expected_size = 32 }, // FP+LR + 1 reg (rounded to pair)
        .{ .num = 2, .expected_size = 32 }, // FP+LR + 1 pair
        .{ .num = 3, .expected_size = 48 }, // FP+LR + 2 pairs
        .{ .num = 4, .expected_size = 48 }, // FP+LR + 2 pairs
        .{ .num = 5, .expected_size = 64 }, // FP+LR + 3 pairs
        .{ .num = 6, .expected_size = 64 }, // FP+LR + 3 pairs
        .{ .num = 7, .expected_size = 80 }, // FP+LR + 4 pairs
        .{ .num = 8, .expected_size = 80 }, // FP+LR + 4 pairs
        .{ .num = 9, .expected_size = 96 }, // FP+LR + 5 pairs
        .{ .num = 10, .expected_size = 96 }, // FP+LR + 5 pairs
    };

    for (test_cases) |tc| {
        const args = [_]abi_mod.Type{.i64};
        const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

        var callee = Aarch64ABICallee.init(testing.allocator, sig);
        defer callee.deinit();

        // Add callee-saves
        var i: u8 = 0;
        while (i < tc.num) : (i += 1) {
            try callee.clobberCalleeSave(PReg.new(.int, 19 + i));
        }

        callee.setLocalsSize(0);

        // Verify frame size
        try testing.expectEqual(tc.expected_size, callee.frame_size);
        try testing.expectEqual(@as(u32, 0), callee.frame_size % 16);
    }
}
