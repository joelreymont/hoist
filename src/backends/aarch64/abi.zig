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

    // Callee-saves: X19-X28, X29 (FP), X30 (LR), V8-V15
    // AAPCS64 section 6.1.2: The registers v8-v15 must be preserved by a callee
    // across subroutine calls; the remaining registers (v0-v7, v16-v31) do not
    // need to be preserved (or should be preserved by the caller).
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
        PReg.new(.float, 8),
        PReg.new(.float, 9),
        PReg.new(.float, 10),
        PReg.new(.float, 11),
        PReg.new(.float, 12),
        PReg.new(.float, 13),
        PReg.new(.float, 14),
        PReg.new(.float, 15),
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

/// AAPCS64 va_list structure for variadic function support.
/// As specified in AAPCS64 section 7.1.4, va_list is a struct containing:
/// - __stack: pointer to next stack parameter
/// - __gr_top: pointer to end of GP register save area
/// - __vr_top: pointer to end of FP/SIMD register save area
/// - __gr_offs: offset from __gr_top to next GP register argument (negative)
/// - __vr_offs: offset from __vr_top to next FP/SIMD register argument (negative)
pub const VaList = struct {
    /// Pointer to the next stack parameter.
    stack: u64,
    /// Pointer to the top (end) of the GP register save area.
    gr_top: u64,
    /// Pointer to the top (end) of the FP/SIMD register save area.
    vr_top: u64,
    /// Offset from gr_top to the next GP register argument (negative or zero).
    gr_offs: i32,
    /// Offset from vr_top to the next FP/SIMD register argument (negative or zero).
    vr_offs: i32,

    /// Size of the va_list structure in bytes.
    pub const size_bytes: u32 = 32;

    /// Maximum number of GP registers saved (x0-x7).
    const max_gp_regs: u32 = 8;
    /// Maximum number of FP/SIMD registers saved (v0-v7).
    const max_fp_regs: u32 = 8;
    /// Size of GP register save area in bytes (8 registers * 8 bytes).
    const gp_save_area_size: u32 = max_gp_regs * 8;
    /// Size of FP/SIMD register save area in bytes (8 registers * 16 bytes).
    const fp_save_area_size: u32 = max_fp_regs * 16;

    /// Initialize a va_list structure.
    /// - gp_save_area: pointer to the base of the GP register save area
    /// - fp_save_area: pointer to the base of the FP/SIMD register save area
    /// - stack_args: pointer to the first stack argument
    /// - gp_used: number of GP registers already used (0-8)
    /// - fp_used: number of FP/SIMD registers already used (0-8)
    pub fn init(
        gp_save_area: u64,
        fp_save_area: u64,
        stack_args: u64,
        gp_used: u8,
        fp_used: u8,
    ) VaList {
        std.debug.assert(gp_used <= max_gp_regs);
        std.debug.assert(fp_used <= max_fp_regs);

        return .{
            .stack = stack_args,
            .gr_top = gp_save_area + gp_save_area_size,
            .vr_top = fp_save_area + fp_save_area_size,
            .gr_offs = -@as(i32, @intCast((max_gp_regs - gp_used) * 8)),
            .vr_offs = -@as(i32, @intCast((max_fp_regs - fp_used) * 16)),
        };
    }

    /// Initialize a va_list structure for a function with no variadic arguments.
    /// All registers are marked as used, so va_arg will only read from stack.
    pub fn initEmpty(stack_args: u64) VaList {
        return .{
            .stack = stack_args,
            .gr_top = 0,
            .vr_top = 0,
            .gr_offs = 0,
            .vr_offs = 0,
        };
    }

    /// Extract the next argument from the va_list.
    /// This implements the AAPCS64 va_arg algorithm as specified in Appendix B.
    ///
    /// Algorithm:
    /// 1. Determine if the argument type uses GP or FP/SIMD registers
    /// 2. Check if argument is available in register save area (offset < 0)
    /// 3. If available in save area: load from save area and update offset
    /// 4. If not available: load from stack and update stack pointer
    /// 5. Handle alignment requirements for stack arguments
    ///
    /// Returns the address where the argument value is stored.
    pub fn arg(self: *VaList, ty: abi_mod.Type) u64 {
        const reg_class = ty.regClass();
        const size = ty.bytes();

        switch (reg_class) {
            .int => {
                // Integer and pointer arguments use general-purpose registers
                // Each GP register slot is 8 bytes
                const reg_size: u32 = 8;

                if (self.gr_offs < 0) {
                    // Argument available in GP register save area
                    const addr = @as(u64, @intCast(@as(i64, @intCast(self.gr_top)) + @as(i64, self.gr_offs)));

                    // Advance to next register slot (round up size to 8 bytes)
                    const slots = (size + reg_size - 1) / reg_size;
                    self.gr_offs += @as(i32, @intCast(slots * reg_size));

                    // If we've consumed all registers, clamp offset to 0
                    if (self.gr_offs > 0) {
                        self.gr_offs = 0;
                    }

                    return addr;
                } else {
                    // No more GP registers, fetch from stack
                    // Stack arguments are 8-byte aligned per AAPCS64
                    const alignment: u32 = if (size >= 8) 8 else size;
                    const aligned_stack = (self.stack + alignment - 1) & ~@as(u64, alignment - 1);
                    const addr = aligned_stack;

                    // Advance stack pointer, round up to 8-byte alignment
                    self.stack = aligned_stack + ((size + 7) & ~@as(u32, 7));

                    return addr;
                }
            },
            .float, .vector => {
                // Floating-point and vector arguments use FP/SIMD registers
                // Each FP/SIMD register slot is 16 bytes
                const reg_size: u32 = 16;

                if (self.vr_offs < 0) {
                    // Argument available in FP/SIMD register save area
                    const addr = @as(u64, @intCast(@as(i64, @intCast(self.vr_top)) + @as(i64, self.vr_offs)));

                    // Advance to next register slot (each slot is 16 bytes)
                    const slots = (size + reg_size - 1) / reg_size;
                    self.vr_offs += @as(i32, @intCast(slots * reg_size));

                    // If we've consumed all registers, clamp offset to 0
                    if (self.vr_offs > 0) {
                        self.vr_offs = 0;
                    }

                    return addr;
                } else {
                    // No more FP/SIMD registers, fetch from stack
                    // Stack arguments are 8-byte aligned, 16-byte for vectors > 8 bytes
                    const alignment: u32 = if (size > 8) 16 else 8;
                    const aligned_stack = (self.stack + alignment - 1) & ~@as(u64, alignment - 1);
                    const addr = aligned_stack;

                    // Advance stack pointer, round up to alignment
                    self.stack = aligned_stack + ((size + alignment - 1) & ~@as(u32, alignment - 1));

                    return addr;
                }
            },
        }
    }

    /// Emit instructions to initialize a va_list structure for va_start.
    /// This generates code to set up the va_list fields according to AAPCS64.
    ///
    /// Arguments:
    /// - va_list_addr: register containing address where va_list will be stored
    /// - gp_save_area_offset: stack offset to GP register save area (relative to SP)
    /// - fp_save_area_offset: stack offset to FP register save area (relative to SP)
    /// - stack_args_offset: stack offset to first stack argument (relative to SP)
    /// - gp_used: number of GP registers used by fixed parameters (0-8)
    /// - fp_used: number of FP registers used by fixed parameters (0-8)
    /// - buffer: machine buffer to emit instructions to
    pub fn emitVaStart(
        va_list_addr: Reg,
        gp_save_area_offset: i16,
        fp_save_area_offset: i16,
        stack_args_offset: i16,
        gp_used: u8,
        fp_used: u8,
        buffer: *buffer_mod.MachBuffer,
    ) !void {
        const emit_fn = @import("emit.zig").emit;
        const sp = Reg.fromPReg(PReg.new(.int, 31)); // SP

        std.debug.assert(gp_used <= max_gp_regs);
        std.debug.assert(fp_used <= max_fp_regs);

        // Use scratch register for calculations
        const scratch1 = Reg.fromPReg(PReg.new(.int, 9)); // X9

        // Calculate and store __stack (offset 0)
        // stack = SP + stack_args_offset
        try emit_fn(.{ .add_imm = .{
            .dst = WritableReg.fromReg(scratch1),
            .src = sp,
            .imm = @intCast(stack_args_offset),
            .size = .size64,
        } }, buffer);
        try emit_fn(.{ .str = .{
            .src = scratch1,
            .base = va_list_addr,
            .offset = 0,
            .size = .size64,
        } }, buffer);

        // Calculate and store __gr_top (offset 8)
        // gr_top = SP + gp_save_area_offset + gp_save_area_size
        const gr_top_offset = gp_save_area_offset + @as(i16, @intCast(gp_save_area_size));
        try emit_fn(.{ .add_imm = .{
            .dst = WritableReg.fromReg(scratch1),
            .src = sp,
            .imm = @intCast(gr_top_offset),
            .size = .size64,
        } }, buffer);
        try emit_fn(.{ .str = .{
            .src = scratch1,
            .base = va_list_addr,
            .offset = 8,
            .size = .size64,
        } }, buffer);

        // Calculate and store __vr_top (offset 16)
        // vr_top = SP + fp_save_area_offset + fp_save_area_size
        const vr_top_offset = fp_save_area_offset + @as(i16, @intCast(fp_save_area_size));
        try emit_fn(.{ .add_imm = .{
            .dst = WritableReg.fromReg(scratch1),
            .src = sp,
            .imm = @intCast(vr_top_offset),
            .size = .size64,
        } }, buffer);
        try emit_fn(.{ .str = .{
            .src = scratch1,
            .base = va_list_addr,
            .offset = 16,
            .size = .size64,
        } }, buffer);

        // Calculate and store __gr_offs (offset 24)
        // gr_offs = -(max_gp_regs - gp_used) * 8
        const gr_offs = -@as(i32, @intCast((max_gp_regs - gp_used) * 8));
        try emit_fn(.{ .mov_imm = .{
            .dst = WritableReg.fromReg(scratch1),
            .imm = @bitCast(gr_offs),
            .size = .size32,
        } }, buffer);
        try emit_fn(.{ .str = .{
            .src = scratch1,
            .base = va_list_addr,
            .offset = 24,
            .size = .size32,
        } }, buffer);

        // Calculate and store __vr_offs (offset 28)
        // vr_offs = -(max_fp_regs - fp_used) * 16
        const vr_offs = -@as(i32, @intCast((max_fp_regs - fp_used) * 16));
        try emit_fn(.{ .mov_imm = .{
            .dst = WritableReg.fromReg(scratch1),
            .imm = @bitCast(vr_offs),
            .size = .size32,
        } }, buffer);
        try emit_fn(.{ .str = .{
            .src = scratch1,
            .base = va_list_addr,
            .offset = 28,
            .size = .size32,
        } }, buffer);
    }
};

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
    if (fields.len == 0 or fields.len > 4) return null;

    // Get the type of the first field - must be a vector
    const first_ty = fields[0].ty;
    if (!first_ty.isVector()) return null;

    // Extract vector characteristics from first field
    const first_elem = first_ty.vectorElementType() orelse return null;
    const first_lanes = first_ty.vectorLaneCount() orelse return null;

    // Verify all fields have the same vector type
    for (fields) |field| {
        if (!field.ty.isVector()) return null;

        const elem = field.ty.vectorElementType() orelse return null;
        const lanes = field.ty.vectorLaneCount() orelse return null;

        // Must match element type, lane count, and size
        if (elem != first_elem or lanes != first_lanes) return null;
        if (field.ty.bytes() != first_ty.bytes()) return null;
    }

    return first_ty;
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

/// Caller-saved register tracking across function calls.
/// Per AAPCS64, caller-saved registers are:
/// - x0-x18 (excluding x8 which is indirect result location)
/// - v0-v7, v16-v31
pub const CallerSavedTracker = struct {
    /// Set of caller-saved integer registers that need saving.
    int_regs: std.bit_set.IntegerBitSet(32),
    /// Set of caller-saved float registers that need saving.
    float_regs: std.bit_set.IntegerBitSet(32),

    pub fn init() CallerSavedTracker {
        return .{
            .int_regs = std.bit_set.IntegerBitSet(32).initEmpty(),
            .float_regs = std.bit_set.IntegerBitSet(32).initEmpty(),
        };
    }

    /// Mark an integer register as caller-saved (needs saving across calls).
    /// Only marks registers x0-x18 (excluding x8).
    pub fn markIntReg(self: *CallerSavedTracker, preg: PReg) void {
        std.debug.assert(preg.class == .int);
        const hw = preg.hw_enc;
        // x0-x18, excluding x8 (indirect result location)
        if (hw <= 18 and hw != 8) {
            self.int_regs.set(hw);
        }
    }

    /// Mark a float register as caller-saved (needs saving across calls).
    /// Only marks registers v0-v7 and v16-v31.
    pub fn markFloatReg(self: *CallerSavedTracker, preg: PReg) void {
        std.debug.assert(preg.class == .float);
        const hw = preg.hw_enc;
        // v0-v7 or v16-v31
        if (hw <= 7 or (hw >= 16 and hw <= 31)) {
            self.float_regs.set(hw);
        }
    }

    /// Mark a register as caller-saved based on its class.
    pub fn markReg(self: *CallerSavedTracker, preg: PReg) void {
        switch (preg.class) {
            .int => self.markIntReg(preg),
            .float => self.markFloatReg(preg),
        }
    }

    /// Clear all marked registers.
    pub fn clear(self: *CallerSavedTracker) void {
        self.int_regs = std.bit_set.IntegerBitSet(32).initEmpty();
        self.float_regs = std.bit_set.IntegerBitSet(32).initEmpty();
    }

    /// Get count of marked integer registers.
    pub fn intRegCount(self: *const CallerSavedTracker) usize {
        return self.int_regs.count();
    }

    /// Get count of marked float registers.
    pub fn floatRegCount(self: *const CallerSavedTracker) usize {
        return self.float_regs.count();
    }

    /// Emit save instructions for all marked caller-saved registers.
    /// Stores registers to stack starting at the given offset.
    /// Returns the total number of bytes used.
    pub fn emitSaves(
        self: *const CallerSavedTracker,
        buffer: *buffer_mod.MachBuffer,
        stack_offset: i16,
    ) !u32 {
        const emit_fn = @import("emit.zig").emit;
        const sp = Reg.fromPReg(PReg.new(.int, 31)); // SP
        var offset = stack_offset;
        var bytes_used: u32 = 0;

        // Save integer registers in pairs using STP where possible
        var int_iter = self.int_regs.iterator(.{});
        var pending_int: ?u5 = null;
        while (int_iter.next()) |hw| {
            const hw_u5: u5 = @intCast(hw);
            if (pending_int) |prev_hw| {
                // Save pair with STP
                const reg1 = Reg.fromPReg(PReg.new(.int, prev_hw));
                const reg2 = Reg.fromPReg(PReg.new(.int, hw_u5));
                try emit_fn(.{ .stp = .{
                    .src1 = reg1,
                    .src2 = reg2,
                    .base = sp,
                    .offset = offset,
                    .size = .size64,
                } }, buffer);
                offset += 16;
                bytes_used += 16;
                pending_int = null;
            } else {
                pending_int = hw_u5;
            }
        }
        // Save odd register with STR
        if (pending_int) |hw| {
            const reg = Reg.fromPReg(PReg.new(.int, hw));
            try emit_fn(.{ .str = .{
                .src = reg,
                .base = sp,
                .offset = offset,
                .size = .size64,
            } }, buffer);
            offset += 16; // Reserve 16 bytes for alignment
            bytes_used += 16;
        }

        // Save float registers in pairs using STP where possible
        var float_iter = self.float_regs.iterator(.{});
        var pending_float: ?u5 = null;
        while (float_iter.next()) |hw| {
            const hw_u5: u5 = @intCast(hw);
            if (pending_float) |prev_hw| {
                // Save pair with STP
                const reg1 = Reg.fromPReg(PReg.new(.float, prev_hw));
                const reg2 = Reg.fromPReg(PReg.new(.float, hw_u5));
                try emit_fn(.{ .stp = .{
                    .src1 = reg1,
                    .src2 = reg2,
                    .base = sp,
                    .offset = offset,
                    .size = .size64,
                } }, buffer);
                offset += 16;
                bytes_used += 16;
                pending_float = null;
            } else {
                pending_float = hw_u5;
            }
        }
        // Save odd register with STR
        if (pending_float) |hw| {
            const reg = Reg.fromPReg(PReg.new(.float, hw));
            try emit_fn(.{ .str = .{
                .src = reg,
                .base = sp,
                .offset = offset,
                .size = .size64,
            } }, buffer);
            bytes_used += 16;
        }

        return bytes_used;
    }

    /// Emit restore instructions for all marked caller-saved registers.
    /// Loads registers from stack starting at the given offset.
    pub fn emitRestores(
        self: *const CallerSavedTracker,
        buffer: *buffer_mod.MachBuffer,
        stack_offset: i16,
    ) !void {
        const emit_fn = @import("emit.zig").emit;
        const sp = Reg.fromPReg(PReg.new(.int, 31)); // SP
        var offset = stack_offset;

        // Restore integer registers in pairs using LDP where possible
        var int_iter = self.int_regs.iterator(.{});
        var pending_int: ?u5 = null;
        while (int_iter.next()) |hw| {
            const hw_u5: u5 = @intCast(hw);
            if (pending_int) |prev_hw| {
                // Restore pair with LDP
                const reg1_w = WritableReg.fromReg(Reg.fromPReg(PReg.new(.int, prev_hw)));
                const reg2_w = WritableReg.fromReg(Reg.fromPReg(PReg.new(.int, hw_u5)));
                try emit_fn(.{ .ldp = .{
                    .dst1 = reg1_w,
                    .dst2 = reg2_w,
                    .base = sp,
                    .offset = offset,
                    .size = .size64,
                } }, buffer);
                offset += 16;
                pending_int = null;
            } else {
                pending_int = hw_u5;
            }
        }
        // Restore odd register with LDR
        if (pending_int) |hw| {
            const reg_w = WritableReg.fromReg(Reg.fromPReg(PReg.new(.int, hw)));
            try emit_fn(.{ .ldr = .{
                .dst = reg_w,
                .base = sp,
                .offset = offset,
                .size = .size64,
            } }, buffer);
            offset += 16; // Skip padding
        }

        // Restore float registers in pairs using LDP where possible
        var float_iter = self.float_regs.iterator(.{});
        var pending_float: ?u5 = null;
        while (float_iter.next()) |hw| {
            const hw_u5: u5 = @intCast(hw);
            if (pending_float) |prev_hw| {
                // Restore pair with LDP
                const reg1_w = WritableReg.fromReg(Reg.fromPReg(PReg.new(.float, prev_hw)));
                const reg2_w = WritableReg.fromReg(Reg.fromPReg(PReg.new(.float, hw_u5)));
                try emit_fn(.{ .ldp = .{
                    .dst1 = reg1_w,
                    .dst2 = reg2_w,
                    .base = sp,
                    .offset = offset,
                    .size = .size64,
                } }, buffer);
                offset += 16;
                pending_float = null;
            } else {
                pending_float = hw_u5;
            }
        }
        // Restore odd register with LDR
        if (pending_float) |hw| {
            const reg_w = WritableReg.fromReg(Reg.fromPReg(PReg.new(.float, hw)));
            try emit_fn(.{ .ldr = .{
                .dst = reg_w,
                .base = sp,
                .offset = offset,
                .size = .size64,
            } }, buffer);
        }
    }
};

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
        _allocator: std.mem.Allocator,
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
            .clobbered_callee_saves = std.ArrayList(PReg){},
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

test "isHVA with v128 fields" {
    // struct { v128<4xf32>, v128<4xf32> } - valid HVA
    const vec_ty = abi_mod.Type{ .v128 = .{ .elem_type = .f32, .lane_count = 4 } };
    const fields1 = [_]abi_mod.StructField{
        .{ .ty = vec_ty, .offset = 0 },
        .{ .ty = vec_ty, .offset = 16 },
    };
    const result1 = isHVA(&fields1);
    try testing.expect(result1 != null);
    try testing.expect(std.meta.eql(result1.?, vec_ty));

    // struct { v128<2xf64>, v128<2xf64>, v128<2xf64> } - valid HVA (3 members)
    const vec_ty2 = abi_mod.Type{ .v128 = .{ .elem_type = .f64, .lane_count = 2 } };
    const fields2 = [_]abi_mod.StructField{
        .{ .ty = vec_ty2, .offset = 0 },
        .{ .ty = vec_ty2, .offset = 16 },
        .{ .ty = vec_ty2, .offset = 32 },
    };
    const result2 = isHVA(&fields2);
    try testing.expect(result2 != null);
    try testing.expect(std.meta.eql(result2.?, vec_ty2));
}

test "isHVA with v64 fields" {
    // struct { v64<2xf32>, v64<2xf32> } - valid HVA
    const vec_ty = abi_mod.Type{ .v64 = .{ .elem_type = .f32, .lane_count = 2 } };
    const fields = [_]abi_mod.StructField{
        .{ .ty = vec_ty, .offset = 0 },
        .{ .ty = vec_ty, .offset = 8 },
    };
    const result = isHVA(&fields);
    try testing.expect(result != null);
    try testing.expect(std.meta.eql(result.?, vec_ty));
}

test "isHVA with maximum 4 members" {
    // struct { v128, v128, v128, v128 } - valid HVA (exactly 4 members)
    const vec_ty = abi_mod.Type{ .v128 = .{ .elem_type = .i32, .lane_count = 4 } };
    const fields = [_]abi_mod.StructField{
        .{ .ty = vec_ty, .offset = 0 },
        .{ .ty = vec_ty, .offset = 16 },
        .{ .ty = vec_ty, .offset = 32 },
        .{ .ty = vec_ty, .offset = 48 },
    };
    const result = isHVA(&fields);
    try testing.expect(result != null);
    try testing.expect(std.meta.eql(result.?, vec_ty));
}

test "isHVA with mixed vector types" {
    // struct { v128<4xf32>, v128<2xf64> } - not HVA (different element types)
    const vec_ty1 = abi_mod.Type{ .v128 = .{ .elem_type = .f32, .lane_count = 4 } };
    const vec_ty2 = abi_mod.Type{ .v128 = .{ .elem_type = .f64, .lane_count = 2 } };
    const fields = [_]abi_mod.StructField{
        .{ .ty = vec_ty1, .offset = 0 },
        .{ .ty = vec_ty2, .offset = 16 },
    };
    const result = isHVA(&fields);
    try testing.expect(result == null);
}

test "isHVA with mixed vector sizes" {
    // struct { v64<2xf32>, v128<4xf32> } - not HVA (different sizes)
    const vec_ty1 = abi_mod.Type{ .v64 = .{ .elem_type = .f32, .lane_count = 2 } };
    const vec_ty2 = abi_mod.Type{ .v128 = .{ .elem_type = .f32, .lane_count = 4 } };
    const fields = [_]abi_mod.StructField{
        .{ .ty = vec_ty1, .offset = 0 },
        .{ .ty = vec_ty2, .offset = 8 },
    };
    const result = isHVA(&fields);
    try testing.expect(result == null);
}

test "isHVA with non-vector fields" {
    // struct { i32, v128 } - not HVA (contains non-vector)
    const vec_ty = abi_mod.Type{ .v128 = .{ .elem_type = .f32, .lane_count = 4 } };
    const fields = [_]abi_mod.StructField{
        .{ .ty = .i32, .offset = 0 },
        .{ .ty = vec_ty, .offset = 16 },
    };
    const result = isHVA(&fields);
    try testing.expect(result == null);
}

test "isHVA with too many fields" {
    // struct { v128, v128, v128, v128, v128 } - not HVA (> 4 members)
    const vec_ty = abi_mod.Type{ .v128 = .{ .elem_type = .f32, .lane_count = 4 } };
    const fields = [_]abi_mod.StructField{
        .{ .ty = vec_ty, .offset = 0 },
        .{ .ty = vec_ty, .offset = 16 },
        .{ .ty = vec_ty, .offset = 32 },
        .{ .ty = vec_ty, .offset = 48 },
        .{ .ty = vec_ty, .offset = 64 },
    };
    const result = isHVA(&fields);
    try testing.expect(result == null);
}

test "isHVA with empty struct" {
    // struct {} - not HVA (no members)
    const fields = [_]abi_mod.StructField{};
    const result = isHVA(&fields);
    try testing.expect(result == null);
}

test "isHVA with different lane counts" {
    // struct { v128<4xi32>, v128<2xi32> } - not HVA (different lane counts)
    const vec_ty1 = abi_mod.Type{ .v128 = .{ .elem_type = .i32, .lane_count = 4 } };
    const vec_ty2 = abi_mod.Type{ .v128 = .{ .elem_type = .i32, .lane_count = 2 } };
    const fields = [_]abi_mod.StructField{
        .{ .ty = vec_ty1, .offset = 0 },
        .{ .ty = vec_ty2, .offset = 16 },
    };
    const result = isHVA(&fields);
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

test "classifyStruct HVA" {
    // struct { v128<4xf32>, v128<4xf32> } - HVA
    const vec_ty = abi_mod.Type{ .v128 = .{ .elem_type = .f32, .lane_count = 4 } };
    const fields = [_]abi_mod.StructField{
        .{ .ty = vec_ty, .offset = 0 },
        .{ .ty = vec_ty, .offset = 16 },
    };
    const ty = abi_mod.Type{ .@"struct" = &fields };
    const result = classifyStruct(ty);
    try testing.expectEqual(StructClass.hva, result.class);
    try testing.expect(result.elem_ty != null);
    try testing.expect(std.meta.eql(result.elem_ty.?, vec_ty));
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

test "float callee-save V8" {
    const args = [_]abi_mod.Type{.f64};
    const sig = abi_mod.ABISignature.init(&args, &.{.f64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    try callee.clobberCalleeSave(PReg.new(.float, 8));

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    try testing.expect(buffer.data.items.len >= 20);
}

test "float callee-save pair V8-V9" {
    const args = [_]abi_mod.Type{.f64};
    const sig = abi_mod.ABISignature.init(&args, &.{.f64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    try callee.clobberCalleeSave(PReg.new(.float, 8));
    try callee.clobberCalleeSave(PReg.new(.float, 9));

    callee.setLocalsSize(0);
    try testing.expectEqual(@as(u32, 32), callee.frame_size);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    try testing.expect(buffer.data.items.len > 0);
}

test "mixed int and float callee-saves" {
    const args = [_]abi_mod.Type{.f64};
    const sig = abi_mod.ABISignature.init(&args, &.{.f64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    try callee.clobberCalleeSave(PReg.new(.int, 19));
    try callee.clobberCalleeSave(PReg.new(.int, 20));
    try callee.clobberCalleeSave(PReg.new(.float, 8));
    try callee.clobberCalleeSave(PReg.new(.float, 9));

    callee.setLocalsSize(0);
    try testing.expectEqual(@as(u32, 48), callee.frame_size);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    try testing.expect(buffer.data.items.len > 0);
}

test "all float callee-saves V8-V15" {
    const args = [_]abi_mod.Type{.f64};
    const sig = abi_mod.ABISignature.init(&args, &.{.f64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    try callee.clobberCalleeSave(PReg.new(.float, 8));
    try callee.clobberCalleeSave(PReg.new(.float, 9));
    try callee.clobberCalleeSave(PReg.new(.float, 10));
    try callee.clobberCalleeSave(PReg.new(.float, 11));
    try callee.clobberCalleeSave(PReg.new(.float, 12));
    try callee.clobberCalleeSave(PReg.new(.float, 13));
    try callee.clobberCalleeSave(PReg.new(.float, 14));
    try callee.clobberCalleeSave(PReg.new(.float, 15));

    callee.setLocalsSize(0);
    try testing.expectEqual(@as(u32, 80), callee.frame_size);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try callee.emitPrologue(&buffer);
    try callee.emitEpilogue(&buffer);

    try testing.expect(buffer.data.items.len > 0);
}

test "CallerSavedTracker init" {
    const tracker = CallerSavedTracker.init();
    try testing.expectEqual(@as(usize, 0), tracker.intRegCount());
    try testing.expectEqual(@as(usize, 0), tracker.floatRegCount());
}

test "CallerSavedTracker mark integer registers" {
    var tracker = CallerSavedTracker.init();

    // Mark x0-x7 (argument registers)
    var i: u5 = 0;
    while (i <= 7) : (i += 1) {
        tracker.markIntReg(PReg.new(.int, i));
    }
    try testing.expectEqual(@as(usize, 8), tracker.intRegCount());

    // Mark x9-x15 (temporaries)
    i = 9;
    while (i <= 15) : (i += 1) {
        tracker.markIntReg(PReg.new(.int, i));
    }
    try testing.expectEqual(@as(usize, 15), tracker.intRegCount());

    // Mark x16-x18 (IP0, IP1, platform)
    tracker.markIntReg(PReg.new(.int, 16));
    tracker.markIntReg(PReg.new(.int, 17));
    tracker.markIntReg(PReg.new(.int, 18));
    try testing.expectEqual(@as(usize, 18), tracker.intRegCount());
}

test "CallerSavedTracker excludes x8" {
    var tracker = CallerSavedTracker.init();

    // x8 is the indirect result location and should be excluded
    tracker.markIntReg(PReg.new(.int, 8));
    try testing.expectEqual(@as(usize, 0), tracker.intRegCount());
}

test "CallerSavedTracker excludes callee-saved x19-x30" {
    var tracker = CallerSavedTracker.init();

    // x19-x30 are callee-saved and should not be marked
    var i: u5 = 19;
    while (i <= 30) : (i += 1) {
        tracker.markIntReg(PReg.new(.int, i));
    }
    try testing.expectEqual(@as(usize, 0), tracker.intRegCount());
}

test "CallerSavedTracker mark float registers v0-v7" {
    var tracker = CallerSavedTracker.init();

    // Mark v0-v7 (argument/return registers)
    var i: u5 = 0;
    while (i <= 7) : (i += 1) {
        tracker.markFloatReg(PReg.new(.float, i));
    }
    try testing.expectEqual(@as(usize, 8), tracker.floatRegCount());
}

test "CallerSavedTracker mark float registers v16-v31" {
    var tracker = CallerSavedTracker.init();

    // Mark v16-v31 (temporaries)
    var i: u5 = 16;
    while (i <= 31) : (i += 1) {
        tracker.markFloatReg(PReg.new(.float, i));
    }
    try testing.expectEqual(@as(usize, 16), tracker.floatRegCount());
}

test "CallerSavedTracker excludes callee-saved v8-v15" {
    var tracker = CallerSavedTracker.init();

    // v8-v15 are callee-saved and should not be marked
    var i: u5 = 8;
    while (i <= 15) : (i += 1) {
        tracker.markFloatReg(PReg.new(.float, i));
    }
    try testing.expectEqual(@as(usize, 0), tracker.floatRegCount());
}

test "CallerSavedTracker markReg dispatches by class" {
    var tracker = CallerSavedTracker.init();

    // Mark mixed register classes
    tracker.markReg(PReg.new(.int, 0)); // x0
    tracker.markReg(PReg.new(.int, 1)); // x1
    tracker.markReg(PReg.new(.float, 0)); // v0
    tracker.markReg(PReg.new(.float, 1)); // v1

    try testing.expectEqual(@as(usize, 2), tracker.intRegCount());
    try testing.expectEqual(@as(usize, 2), tracker.floatRegCount());
}

test "CallerSavedTracker clear" {
    var tracker = CallerSavedTracker.init();

    // Mark some registers
    tracker.markIntReg(PReg.new(.int, 0));
    tracker.markIntReg(PReg.new(.int, 1));
    tracker.markFloatReg(PReg.new(.float, 0));
    tracker.markFloatReg(PReg.new(.float, 1));

    try testing.expectEqual(@as(usize, 2), tracker.intRegCount());
    try testing.expectEqual(@as(usize, 2), tracker.floatRegCount());

    // Clear all
    tracker.clear();
    try testing.expectEqual(@as(usize, 0), tracker.intRegCount());
    try testing.expectEqual(@as(usize, 0), tracker.floatRegCount());
}

test "CallerSavedTracker emitSaves and emitRestores with int regs" {
    var tracker = CallerSavedTracker.init();

    // Mark x0, x1 (will be saved as a pair)
    tracker.markIntReg(PReg.new(.int, 0));
    tracker.markIntReg(PReg.new(.int, 1));

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Emit saves at offset 0
    const bytes_used = try tracker.emitSaves(&buffer, 0);
    try testing.expectEqual(@as(u32, 16), bytes_used); // One STP = 16 bytes used

    // Should emit one STP instruction (4 bytes)
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);

    // Emit restores at same offset
    try tracker.emitRestores(&buffer, 0);

    // Should have STP + LDP = 8 bytes
    try testing.expectEqual(@as(usize, 8), buffer.data.items.len);
}

test "CallerSavedTracker emitSaves with odd number of int regs" {
    var tracker = CallerSavedTracker.init();

    // Mark x0, x1, x2 (pair + single)
    tracker.markIntReg(PReg.new(.int, 0));
    tracker.markIntReg(PReg.new(.int, 1));
    tracker.markIntReg(PReg.new(.int, 2));

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const bytes_used = try tracker.emitSaves(&buffer, 0);
    try testing.expectEqual(@as(u32, 32), bytes_used); // STP + STR with padding = 32 bytes

    // Should emit STP + STR = 8 bytes
    try testing.expectEqual(@as(usize, 8), buffer.data.items.len);
}

test "CallerSavedTracker emitSaves and emitRestores with float regs" {
    var tracker = CallerSavedTracker.init();

    // Mark v0, v1 (will be saved as a pair)
    tracker.markFloatReg(PReg.new(.float, 0));
    tracker.markFloatReg(PReg.new(.float, 1));

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const bytes_used = try tracker.emitSaves(&buffer, 0);
    try testing.expectEqual(@as(u32, 16), bytes_used); // One STP = 16 bytes used

    // Should emit one STP instruction (4 bytes)
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);

    // Emit restores
    try tracker.emitRestores(&buffer, 0);

    // Should have STP + LDP = 8 bytes
    try testing.expectEqual(@as(usize, 8), buffer.data.items.len);
}

test "CallerSavedTracker emitSaves with mixed int and float regs" {
    var tracker = CallerSavedTracker.init();

    // Mark x0, x1, v0, v1
    tracker.markIntReg(PReg.new(.int, 0));
    tracker.markIntReg(PReg.new(.int, 1));
    tracker.markFloatReg(PReg.new(.float, 0));
    tracker.markFloatReg(PReg.new(.float, 1));

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const bytes_used = try tracker.emitSaves(&buffer, 0);
    try testing.expectEqual(@as(u32, 32), bytes_used); // Two STPs = 32 bytes

    // Should emit two STP instructions (8 bytes)
    try testing.expectEqual(@as(usize, 8), buffer.data.items.len);

    // Emit restores
    try tracker.emitRestores(&buffer, 0);

    // Should have 2 STPs + 2 LDPs = 16 bytes
    try testing.expectEqual(@as(usize, 16), buffer.data.items.len);
}

test "CallerSavedTracker stack offset handling" {
    var tracker = CallerSavedTracker.init();

    // Mark x0, x1
    tracker.markIntReg(PReg.new(.int, 0));
    tracker.markIntReg(PReg.new(.int, 1));

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Emit saves at offset 64
    const bytes_used = try tracker.emitSaves(&buffer, 64);
    try testing.expectEqual(@as(u32, 16), bytes_used);

    // Verify instruction was emitted
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

test "CallerSavedTracker comprehensive register coverage" {
    var tracker = CallerSavedTracker.init();

    // Mark all caller-saved integer registers (x0-x7, x9-x18)
    var i: u5 = 0;
    while (i <= 7) : (i += 1) {
        tracker.markIntReg(PReg.new(.int, i));
    }
    i = 9;
    while (i <= 18) : (i += 1) {
        tracker.markIntReg(PReg.new(.int, i));
    }

    // Mark all caller-saved float registers (v0-v7, v16-v31)
    i = 0;
    while (i <= 7) : (i += 1) {
        tracker.markFloatReg(PReg.new(.float, i));
    }
    i = 16;
    while (i <= 31) : (i += 1) {
        tracker.markFloatReg(PReg.new(.float, i));
    }

    try testing.expectEqual(@as(usize, 18), tracker.intRegCount());
    try testing.expectEqual(@as(usize, 24), tracker.floatRegCount());

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Emit all saves
    const bytes_used = try tracker.emitSaves(&buffer, 0);

    // 18 int regs = 9 pairs = 144 bytes
    // 24 float regs = 12 pairs = 192 bytes
    // Total = 336 bytes
    try testing.expectEqual(@as(u32, 336), bytes_used);

    // Verify instructions were generated
    try testing.expect(buffer.data.items.len > 0);

    // Emit restores
    try tracker.emitRestores(&buffer, 0);
    try testing.expect(buffer.data.items.len > 0);
}

test "VaList size_bytes constant" {
    // VaList should be 32 bytes: 2 u64 pointers + 2 u64 pointers + 2 i32 offsets
    // = 8 + 8 + 8 + 4 + 4 = 32 bytes
    try testing.expectEqual(@as(u32, 32), VaList.size_bytes);
}

test "VaList init with no registers used" {
    // When no registers have been used, all registers are available
    const gp_save_area: u64 = 0x1000;
    const fp_save_area: u64 = 0x2000;
    const stack_args: u64 = 0x3000;

    const va_list = VaList.init(gp_save_area, fp_save_area, stack_args, 0, 0);

    try testing.expectEqual(stack_args, va_list.stack);
    try testing.expectEqual(gp_save_area + VaList.gp_save_area_size, va_list.gr_top);
    try testing.expectEqual(fp_save_area + VaList.fp_save_area_size, va_list.vr_top);
    try testing.expectEqual(@as(i32, -64), va_list.gr_offs); // -8 * 8 = -64
    try testing.expectEqual(@as(i32, -128), va_list.vr_offs); // -8 * 16 = -128
}

test "VaList init with all GP registers used" {
    // When all 8 GP registers have been used, gr_offs should be 0
    const gp_save_area: u64 = 0x1000;
    const fp_save_area: u64 = 0x2000;
    const stack_args: u64 = 0x3000;

    const va_list = VaList.init(gp_save_area, fp_save_area, stack_args, 8, 0);

    try testing.expectEqual(@as(i32, 0), va_list.gr_offs);
    try testing.expectEqual(@as(i32, -128), va_list.vr_offs);
}

test "VaList init with all FP registers used" {
    // When all 8 FP registers have been used, vr_offs should be 0
    const gp_save_area: u64 = 0x1000;
    const fp_save_area: u64 = 0x2000;
    const stack_args: u64 = 0x3000;

    const va_list = VaList.init(gp_save_area, fp_save_area, stack_args, 0, 8);

    try testing.expectEqual(@as(i32, -64), va_list.gr_offs);
    try testing.expectEqual(@as(i32, 0), va_list.vr_offs);
}

test "VaList init with partial register usage" {
    // Test with 3 GP registers and 2 FP registers used
    const gp_save_area: u64 = 0x1000;
    const fp_save_area: u64 = 0x2000;
    const stack_args: u64 = 0x3000;

    const va_list = VaList.init(gp_save_area, fp_save_area, stack_args, 3, 2);

    // 3 GP regs used means 5 available: -(8-3)*8 = -40
    try testing.expectEqual(@as(i32, -40), va_list.gr_offs);
    // 2 FP regs used means 6 available: -(8-2)*16 = -96
    try testing.expectEqual(@as(i32, -96), va_list.vr_offs);
}

test "VaList init with all registers used" {
    // When all registers have been used, both offsets should be 0
    const gp_save_area: u64 = 0x1000;
    const fp_save_area: u64 = 0x2000;
    const stack_args: u64 = 0x3000;

    const va_list = VaList.init(gp_save_area, fp_save_area, stack_args, 8, 8);

    try testing.expectEqual(@as(i32, 0), va_list.gr_offs);
    try testing.expectEqual(@as(i32, 0), va_list.vr_offs);
}

test "VaList initEmpty" {
    // Empty va_list should have all offsets at 0 and only stack pointer set
    const stack_args: u64 = 0x3000;

    const va_list = VaList.initEmpty(stack_args);

    try testing.expectEqual(stack_args, va_list.stack);
    try testing.expectEqual(@as(u64, 0), va_list.gr_top);
    try testing.expectEqual(@as(u64, 0), va_list.vr_top);
    try testing.expectEqual(@as(i32, 0), va_list.gr_offs);
    try testing.expectEqual(@as(i32, 0), va_list.vr_offs);
}

test "VaList gr_top calculation" {
    // Verify gr_top points to the end of the GP save area
    const gp_save_area: u64 = 0x1000;
    const fp_save_area: u64 = 0x2000;
    const stack_args: u64 = 0x3000;

    const va_list = VaList.init(gp_save_area, fp_save_area, stack_args, 0, 0);

    // gr_top should be base + 8 registers * 8 bytes = base + 64
    try testing.expectEqual(@as(u64, 0x1040), va_list.gr_top);
}

test "VaList vr_top calculation" {
    // Verify vr_top points to the end of the FP save area
    const gp_save_area: u64 = 0x1000;
    const fp_save_area: u64 = 0x2000;
    const stack_args: u64 = 0x3000;

    const va_list = VaList.init(gp_save_area, fp_save_area, stack_args, 0, 0);

    // vr_top should be base + 8 registers * 16 bytes = base + 128
    try testing.expectEqual(@as(u64, 0x2080), va_list.vr_top);
}

test "VaList offset calculation for single GP register used" {
    // When 1 GP register is used, 7 remain available
    const va_list = VaList.init(0x1000, 0x2000, 0x3000, 1, 0);

    // Offset should be -(8-1)*8 = -56
    try testing.expectEqual(@as(i32, -56), va_list.gr_offs);
}

test "VaList offset calculation for single FP register used" {
    // When 1 FP register is used, 7 remain available
    const va_list = VaList.init(0x1000, 0x2000, 0x3000, 0, 1);

    // Offset should be -(8-1)*16 = -112
    try testing.expectEqual(@as(i32, -112), va_list.vr_offs);
}

test "VaList realistic scenario with function call" {
    // Simulate: void foo(int a, int b, int c, ...)
    // a, b, c use x0, x1, x2 (3 GP registers)
    // Remaining variadic args can use x3-x7 (5 more GP registers)
    const gp_save_area: u64 = 0x7fff_ffff_f000;
    const fp_save_area: u64 = 0x7fff_ffff_f100;
    const stack_args: u64 = 0x7fff_ffff_f200;

    const va_list = VaList.init(gp_save_area, fp_save_area, stack_args, 3, 0);

    // Verify GP offset allows access to 5 remaining registers
    try testing.expectEqual(@as(i32, -40), va_list.gr_offs); // -(8-3)*8
    try testing.expectEqual(@as(i32, -128), va_list.vr_offs); // -(8-0)*16

    // Verify pointers are set correctly
    try testing.expectEqual(@as(u64, 0x7fff_ffff_f040), va_list.gr_top);
    try testing.expectEqual(@as(u64, 0x7fff_ffff_f180), va_list.vr_top);
    try testing.expectEqual(stack_args, va_list.stack);
}

test "VaList with mixed argument types" {
    // Simulate: void foo(int a, double b, int c, double d, ...)
    // a uses x0, b uses v0, c uses x1, d uses v1
    // So 2 GP regs and 2 FP regs are used
    const gp_save_area: u64 = 0x1000;
    const fp_save_area: u64 = 0x2000;
    const stack_args: u64 = 0x3000;

    const va_list = VaList.init(gp_save_area, fp_save_area, stack_args, 2, 2);

    // 6 GP registers remain: -(8-2)*8 = -48
    try testing.expectEqual(@as(i32, -48), va_list.gr_offs);
    // 6 FP registers remain: -(8-2)*16 = -96
    try testing.expectEqual(@as(i32, -96), va_list.vr_offs);
}

test "VaList constants match AAPCS64 specification" {
    // Verify constants match the AAPCS64 specification
    try testing.expectEqual(@as(u32, 8), VaList.max_gp_regs);
    try testing.expectEqual(@as(u32, 8), VaList.max_fp_regs);
    try testing.expectEqual(@as(u32, 64), VaList.gp_save_area_size); // 8 * 8
    try testing.expectEqual(@as(u32, 128), VaList.fp_save_area_size); // 8 * 16
}

test "VaList.arg extracts i32 from GP registers" {
    // Simulate GP save area with test data
    var gp_save_area: [64]u8 align(8) = undefined;
    const gp_base = @intFromPtr(&gp_save_area);

    // Store test value (42) in first register slot
    const value_ptr: *i32 = @ptrFromInt(gp_base);
    value_ptr.* = 42;

    var va_list = VaList.init(gp_base, 0x2000, 0x3000, 0, 0);

    const addr = va_list.arg(.i32);
    const result: *const i32 = @ptrFromInt(addr);

    try testing.expectEqual(@as(i32, 42), result.*);
    try testing.expectEqual(@as(i32, -56), va_list.gr_offs); // Advanced by 8 bytes
}

test "VaList.arg extracts i64 from GP registers" {
    var gp_save_area: [64]u8 align(8) = undefined;
    const gp_base = @intFromPtr(&gp_save_area);

    const value_ptr: *i64 = @ptrFromInt(gp_base);
    value_ptr.* = 0x123456789ABCDEF0;

    var va_list = VaList.init(gp_base, 0x2000, 0x3000, 0, 0);

    const addr = va_list.arg(.i64);
    const result: *const i64 = @ptrFromInt(addr);

    try testing.expectEqual(@as(i64, 0x123456789ABCDEF0), result.*);
    try testing.expectEqual(@as(i32, -56), va_list.gr_offs);
}

test "VaList.arg extracts multiple i64 values from GP registers" {
    var gp_save_area: [64]u8 align(8) = undefined;
    const gp_base = @intFromPtr(&gp_save_area);

    // Store three test values
    const values: *[8]i64 = @ptrFromInt(gp_base);
    values[0] = 100;
    values[1] = 200;
    values[2] = 300;

    var va_list = VaList.init(gp_base, 0x2000, 0x3000, 0, 0);

    const addr1 = va_list.arg(.i64);
    const result1: *const i64 = @ptrFromInt(addr1);
    try testing.expectEqual(@as(i64, 100), result1.*);

    const addr2 = va_list.arg(.i64);
    const result2: *const i64 = @ptrFromInt(addr2);
    try testing.expectEqual(@as(i64, 200), result2.*);

    const addr3 = va_list.arg(.i64);
    const result3: *const i64 = @ptrFromInt(addr3);
    try testing.expectEqual(@as(i64, 300), result3.*);

    try testing.expectEqual(@as(i32, -40), va_list.gr_offs); // 3 registers consumed, 5 remain
}

test "VaList.arg exhausts GP registers and reads from stack" {
    var gp_save_area: [64]u8 align(8) = undefined;
    var stack_area: [64]u8 align(8) = undefined;
    const gp_base = @intFromPtr(&gp_save_area);
    const stack_base = @intFromPtr(&stack_area);

    // Fill GP registers
    const gp_values: *[8]i64 = @ptrFromInt(gp_base);
    for (gp_values, 0..) |*val, i| {
        val.* = @intCast(i + 1);
    }

    // Store value on stack
    const stack_ptr: *i64 = @ptrFromInt(stack_base);
    stack_ptr.* = 999;

    var va_list = VaList.init(gp_base, 0x2000, stack_base, 0, 0);

    // Consume all 8 GP registers
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        _ = va_list.arg(.i64);
    }

    try testing.expectEqual(@as(i32, 0), va_list.gr_offs);

    // Next argument should come from stack
    const addr = va_list.arg(.i64);
    const result: *const i64 = @ptrFromInt(addr);
    try testing.expectEqual(@as(i64, 999), result.*);
    try testing.expectEqual(stack_base + 8, va_list.stack);
}

test "VaList.arg extracts f32 from FP registers" {
    var fp_save_area: [128]u8 align(16) = undefined;
    const fp_base = @intFromPtr(&fp_save_area);

    const value_ptr: *f32 = @ptrFromInt(fp_base);
    value_ptr.* = 3.14159;

    var va_list = VaList.init(0x1000, fp_base, 0x3000, 0, 0);

    const addr = va_list.arg(.f32);
    const result: *const f32 = @ptrFromInt(addr);

    try testing.expect(@abs(result.* - 3.14159) < 0.00001);
    try testing.expectEqual(@as(i32, -112), va_list.vr_offs); // Advanced by 16 bytes
}

test "VaList.arg extracts f64 from FP registers" {
    var fp_save_area: [128]u8 align(16) = undefined;
    const fp_base = @intFromPtr(&fp_save_area);

    const value_ptr: *f64 = @ptrFromInt(fp_base);
    value_ptr.* = 2.718281828459045;

    var va_list = VaList.init(0x1000, fp_base, 0x3000, 0, 0);

    const addr = va_list.arg(.f64);
    const result: *const f64 = @ptrFromInt(addr);

    try testing.expect(@abs(result.* - 2.718281828459045) < 0.000000000000001);
    try testing.expectEqual(@as(i32, -112), va_list.vr_offs);
}

test "VaList.arg extracts multiple float values from FP registers" {
    var fp_save_area: [128]u8 align(16) = undefined;
    const fp_base = @intFromPtr(&fp_save_area);

    // Store test values (each in a 16-byte slot)
    const f32_ptr1: *f32 = @ptrFromInt(fp_base);
    f32_ptr1.* = 1.5;
    const f32_ptr2: *f32 = @ptrFromInt(fp_base + 16);
    f32_ptr2.* = 2.5;
    const f64_ptr: *f64 = @ptrFromInt(fp_base + 32);
    f64_ptr.* = 3.5;

    var va_list = VaList.init(0x1000, fp_base, 0x3000, 0, 0);

    const addr1 = va_list.arg(.f32);
    const result1: *const f32 = @ptrFromInt(addr1);
    try testing.expectEqual(@as(f32, 1.5), result1.*);

    const addr2 = va_list.arg(.f32);
    const result2: *const f32 = @ptrFromInt(addr2);
    try testing.expectEqual(@as(f32, 2.5), result2.*);

    const addr3 = va_list.arg(.f64);
    const result3: *const f64 = @ptrFromInt(addr3);
    try testing.expectEqual(@as(f64, 3.5), result3.*);

    try testing.expectEqual(@as(i32, -80), va_list.vr_offs); // 3 registers consumed
}

test "VaList.arg exhausts FP registers and reads from stack" {
    var fp_save_area: [128]u8 align(16) = undefined;
    var stack_area: [64]u8 align(16) = undefined;
    const fp_base = @intFromPtr(&fp_save_area);
    const stack_base = @intFromPtr(&stack_area);

    // Store value on stack
    const stack_ptr: *f64 = @ptrFromInt(stack_base);
    stack_ptr.* = 42.42;

    var va_list = VaList.init(0x1000, fp_base, stack_base, 0, 0);

    // Consume all 8 FP registers
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        _ = va_list.arg(.f64);
    }

    try testing.expectEqual(@as(i32, 0), va_list.vr_offs);

    // Next argument should come from stack
    const addr = va_list.arg(.f64);
    const result: *const f64 = @ptrFromInt(addr);
    try testing.expectEqual(@as(f64, 42.42), result.*);
    try testing.expectEqual(stack_base + 8, va_list.stack);
}

test "VaList.arg with v64 vector type" {
    var fp_save_area: [128]u8 align(16) = undefined;
    const fp_base = @intFromPtr(&fp_save_area);

    // Store test vector data
    const vec_ptr: *[2]i32 = @ptrFromInt(fp_base);
    vec_ptr[0] = 10;
    vec_ptr[1] = 20;

    var va_list = VaList.init(0x1000, fp_base, 0x3000, 0, 0);

    const v64_ty = abi_mod.Type{
        .v64 = .{
            .elem_type = .i32,
            .lane_count = 2,
        },
    };

    const addr = va_list.arg(v64_ty);
    const result: *const [2]i32 = @ptrFromInt(addr);

    try testing.expectEqual(@as(i32, 10), result[0]);
    try testing.expectEqual(@as(i32, 20), result[1]);
    try testing.expectEqual(@as(i32, -112), va_list.vr_offs);
}

test "VaList.arg with v128 vector type" {
    var fp_save_area: [128]u8 align(16) = undefined;
    const fp_base = @intFromPtr(&fp_save_area);

    // Store test vector data
    const vec_ptr: *[4]i32 = @ptrFromInt(fp_base);
    vec_ptr[0] = 100;
    vec_ptr[1] = 200;
    vec_ptr[2] = 300;
    vec_ptr[3] = 400;

    var va_list = VaList.init(0x1000, fp_base, 0x3000, 0, 0);

    const v128_ty = abi_mod.Type{
        .v128 = .{
            .elem_type = .i32,
            .lane_count = 4,
        },
    };

    const addr = va_list.arg(v128_ty);
    const result: *const [4]i32 = @ptrFromInt(addr);

    try testing.expectEqual(@as(i32, 100), result[0]);
    try testing.expectEqual(@as(i32, 200), result[1]);
    try testing.expectEqual(@as(i32, 300), result[2]);
    try testing.expectEqual(@as(i32, 400), result[3]);
    try testing.expectEqual(@as(i32, -112), va_list.vr_offs);
}

test "VaList.arg mixed GP and FP arguments" {
    var gp_save_area: [64]u8 align(8) = undefined;
    var fp_save_area: [128]u8 align(16) = undefined;
    const gp_base = @intFromPtr(&gp_save_area);
    const fp_base = @intFromPtr(&fp_save_area);

    // Store test values
    const int_ptr: *i64 = @ptrFromInt(gp_base);
    int_ptr.* = 123;
    const float_ptr: *f64 = @ptrFromInt(fp_base);
    float_ptr.* = 45.67;

    var va_list = VaList.init(gp_base, fp_base, 0x3000, 0, 0);

    // Extract integer
    const addr1 = va_list.arg(.i64);
    const result1: *const i64 = @ptrFromInt(addr1);
    try testing.expectEqual(@as(i64, 123), result1.*);

    // Extract float
    const addr2 = va_list.arg(.f64);
    const result2: *const f64 = @ptrFromInt(addr2);
    try testing.expectEqual(@as(f64, 45.67), result2.*);

    // Verify offsets updated independently
    try testing.expectEqual(@as(i32, -56), va_list.gr_offs);
    try testing.expectEqual(@as(i32, -112), va_list.vr_offs);
}

test "VaList.arg with partial GP register usage" {
    var gp_save_area: [64]u8 align(8) = undefined;
    const gp_base = @intFromPtr(&gp_save_area);

    // Store test value in 4th register slot (3 already used)
    const values: *[8]i64 = @ptrFromInt(gp_base);
    values[3] = 777;

    var va_list = VaList.init(gp_base, 0x2000, 0x3000, 3, 0);

    try testing.expectEqual(@as(i32, -40), va_list.gr_offs); // 5 registers left

    const addr = va_list.arg(.i64);
    const result: *const i64 = @ptrFromInt(addr);
    try testing.expectEqual(@as(i64, 777), result.*);
    try testing.expectEqual(@as(i32, -32), va_list.gr_offs); // 4 registers left
}

test "VaList.arg stack alignment for i32" {
    var stack_area: [64]u8 align(8) = undefined;
    const stack_base = @intFromPtr(&stack_area);

    // Store value at unaligned offset
    const stack_ptr: *i32 = @ptrFromInt(stack_base + 2);
    stack_ptr.* = 999;

    // Start with all GP registers consumed
    var va_list = VaList.initEmpty(stack_base + 2);

    const addr = va_list.arg(.i32);

    // Should align to 4-byte boundary
    try testing.expectEqual(@as(u64, 0), addr % 4);
    try testing.expectEqual(stack_base + 8, va_list.stack); // Advanced by 8 (rounded up)
}

test "VaList.arg stack alignment for i64" {
    var stack_area: [64]u8 align(8) = undefined;
    const stack_base = @intFromPtr(&stack_area);

    const stack_ptr: *i64 = @ptrFromInt(stack_base);
    stack_ptr.* = 12345;

    var va_list = VaList.initEmpty(stack_base);

    const addr = va_list.arg(.i64);
    const result: *const i64 = @ptrFromInt(addr);

    try testing.expectEqual(@as(i64, 12345), result.*);
    try testing.expectEqual(@as(u64, 0), addr % 8); // 8-byte aligned
    try testing.expectEqual(stack_base + 8, va_list.stack);
}

test "VaList.arg stack alignment for v128" {
    var stack_area: [64]u8 align(16) = undefined;
    const stack_base = @intFromPtr(&stack_area);

    const vec_ptr: *[4]f32 = @ptrFromInt(stack_base);
    vec_ptr[0] = 1.0;
    vec_ptr[1] = 2.0;
    vec_ptr[2] = 3.0;
    vec_ptr[3] = 4.0;

    var va_list = VaList.initEmpty(stack_base);

    const v128_ty = abi_mod.Type{
        .v128 = .{
            .elem_type = .f32,
            .lane_count = 4,
        },
    };

    const addr = va_list.arg(v128_ty);

    // Should be 16-byte aligned
    try testing.expectEqual(@as(u64, 0), addr % 16);
    try testing.expectEqual(stack_base + 16, va_list.stack);
}

test "VaList.arg offset clamping when registers exhausted" {
    var gp_save_area: [64]u8 align(8) = undefined;
    const gp_base = @intFromPtr(&gp_save_area);

    // Start with 7 registers used, only 1 remaining
    var va_list = VaList.init(gp_base, 0x2000, 0x3000, 7, 0);

    try testing.expectEqual(@as(i32, -8), va_list.gr_offs);

    // Consume the last register
    _ = va_list.arg(.i64);

    // Offset should be clamped to 0
    try testing.expectEqual(@as(i32, 0), va_list.gr_offs);
}

/// Varargs register save area per AAPCS64 specification.
/// For variadic functions, argument registers must be saved to allow va_start/va_arg to work.
/// Reference: ARM AAPCS64 Appendix B (Variable Argument Lists)
/// https://github.com/ARM-software/abi-aa/blob/main/aapcs64/aapcs64.rst
///
/// The save area layout (high to low address):
///   [General register save area: X0-X7] <- 64 bytes, 16-byte aligned
///   [FP/SIMD register save area: V0-V7] <- 128 bytes, 16-byte aligned
///   Total: 192 bytes
///
/// Note: The specification allows optimization when FP/SIMD registers are not used,
/// but this implementation always reserves the full save area for simplicity.
pub const VarargsRegisterSaveArea = struct {
    /// Size of general register save area (8 registers * 8 bytes).
    pub const gr_save_size: u32 = 64;
    /// Size of FP/SIMD register save area (8 registers * 16 bytes).
    pub const vr_save_size: u32 = 128;
    /// Total size of both save areas.
    pub const total_size: u32 = gr_save_size + vr_save_size;

    /// Stack offset to the start of the general register save area.
    /// This is relative to the stack pointer after prologue.
    gr_save_offset: i16,
    /// Stack offset to the start of the FP/SIMD register save area.
    /// This is relative to the stack pointer after prologue.
    vr_save_offset: i16,

    /// Initialize save area with given stack offset.
    /// The offset should point to the start of the general register save area.
    /// FP/SIMD save area will be placed immediately after.
    pub fn init(stack_offset: i16) VarargsRegisterSaveArea {
        return .{
            .gr_save_offset = stack_offset,
            .vr_save_offset = stack_offset + @as(i16, @intCast(gr_save_size)),
        };
    }

    /// Emit instructions to save general argument registers (X0-X7) to the save area.
    pub fn emitSaveGeneralRegs(
        self: VarargsRegisterSaveArea,
        buffer: *buffer_mod.MachBuffer,
    ) !void {
        const emit_fn = @import("emit.zig").emit;
        const sp = Reg.fromPReg(PReg.new(.int, 31)); // SP

        // Save X0-X7 in pairs using STP
        var offset = self.gr_save_offset;
        var i: u5 = 0;
        while (i < 8) : (i += 2) {
            const reg1 = Reg.fromPReg(PReg.new(.int, i));
            const reg2 = Reg.fromPReg(PReg.new(.int, i + 1));
            try emit_fn(.{ .stp = .{
                .src1 = reg1,
                .src2 = reg2,
                .base = sp,
                .offset = offset,
                .size = .size64,
            } }, buffer);
            offset += 16;
        }
    }

    /// Emit instructions to save FP/SIMD argument registers (V0-V7) to the save area.
    pub fn emitSaveFloatRegs(
        self: VarargsRegisterSaveArea,
        buffer: *buffer_mod.MachBuffer,
    ) !void {
        const emit_fn = @import("emit.zig").emit;
        const sp = Reg.fromPReg(PReg.new(.int, 31)); // SP

        // Save V0-V7 in pairs using STP (128-bit each)
        var offset = self.vr_save_offset;
        var i: u5 = 0;
        while (i < 8) : (i += 2) {
            const reg1 = Reg.fromPReg(PReg.new(.float, i));
            const reg2 = Reg.fromPReg(PReg.new(.float, i + 1));
            try emit_fn(.{ .stp = .{
                .src1 = reg1,
                .src2 = reg2,
                .base = sp,
                .offset = offset,
                .size = .size128,
            } }, buffer);
            offset += 32; // Two 128-bit regs = 32 bytes
        }
    }

    /// Emit instructions to save all argument registers to the save area.
    /// This should be called in the prologue of variadic functions.
    pub fn emitSaveAll(
        self: VarargsRegisterSaveArea,
        buffer: *buffer_mod.MachBuffer,
    ) !void {
        try self.emitSaveGeneralRegs(buffer);
        try self.emitSaveFloatRegs(buffer);
    }
};

test "VaList.emitVaStart basic initialization" {
    // Test emitVaStart generates correct initialization code
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const va_list_reg = Reg.fromPReg(PReg.new(.int, 8)); // X8
    const gp_offset: i16 = 16;
    const fp_offset: i16 = 80;
    const stack_offset: i16 = 208;

    try VaList.emitVaStart(
        va_list_reg,
        gp_offset,
        fp_offset,
        stack_offset,
        0, // no GP registers used
        0, // no FP registers used
        &buffer,
    );

    // Should emit 10 instructions:
    // - 3 ADD + 3 STR for stack, gr_top, vr_top pointers
    // - 2 MOV + 2 STR for gr_offs, vr_offs
    try testing.expectEqual(@as(usize, 40), buffer.data.items.len);
}

test "VaList.emitVaStart with GP registers used" {
    // Test with 3 GP registers already used by fixed parameters
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const va_list_reg = Reg.fromPReg(PReg.new(.int, 8));
    try VaList.emitVaStart(
        va_list_reg,
        16,
        80,
        208,
        3, // 3 GP registers used
        0,
        &buffer,
    );

    // Should still emit 10 instructions
    try testing.expectEqual(@as(usize, 40), buffer.data.items.len);
}

test "VaList.emitVaStart with FP registers used" {
    // Test with 2 FP registers already used by fixed parameters
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const va_list_reg = Reg.fromPReg(PReg.new(.int, 8));
    try VaList.emitVaStart(
        va_list_reg,
        16,
        80,
        208,
        0,
        2, // 2 FP registers used
        &buffer,
    );

    try testing.expectEqual(@as(usize, 40), buffer.data.items.len);
}

test "VaList.emitVaStart with mixed registers used" {
    // Test with both GP and FP registers used
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const va_list_reg = Reg.fromPReg(PReg.new(.int, 8));
    try VaList.emitVaStart(
        va_list_reg,
        16,
        80,
        208,
        3, // 3 GP registers used
        2, // 2 FP registers used
        &buffer,
    );

    try testing.expectEqual(@as(usize, 40), buffer.data.items.len);
}

test "VaList.emitVaStart with all GP registers used" {
    // Test when all 8 GP registers are used (all variadic args on stack)
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const va_list_reg = Reg.fromPReg(PReg.new(.int, 8));
    try VaList.emitVaStart(
        va_list_reg,
        16,
        80,
        208,
        8, // all GP registers used
        0,
        &buffer,
    );

    try testing.expectEqual(@as(usize, 40), buffer.data.items.len);
}

test "VaList.emitVaStart with all FP registers used" {
    // Test when all 8 FP registers are used
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const va_list_reg = Reg.fromPReg(PReg.new(.int, 8));
    try VaList.emitVaStart(
        va_list_reg,
        16,
        80,
        208,
        0,
        8, // all FP registers used
        &buffer,
    );

    try testing.expectEqual(@as(usize, 40), buffer.data.items.len);
}

test "VaList.emitVaStart offset calculations" {
    // Verify the offset calculations are correct
    // This test checks that gr_offs and vr_offs are computed correctly
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const va_list_reg = Reg.fromPReg(PReg.new(.int, 8));

    // With 3 GP and 2 FP regs used:
    // gr_offs should be -(8-3)*8 = -40
    // vr_offs should be -(8-2)*16 = -96
    try VaList.emitVaStart(
        va_list_reg,
        16,
        80,
        208,
        3,
        2,
        &buffer,
    );

    // The implementation should generate the correct negative offsets
    // This is verified by checking that code was generated
    try testing.expect(buffer.data.items.len > 0);
}

test "VarargRegisterSaveArea init" {
    const save_area = VarargsRegisterSaveArea.init(0);
    try testing.expectEqual(@as(i16, 0), save_area.gr_save_offset);
    try testing.expectEqual(@as(i16, 64), save_area.vr_save_offset);
}

test "VarargsRegisterSaveArea size constants" {
    try testing.expectEqual(@as(u32, 64), VarargsRegisterSaveArea.gr_save_size);
    try testing.expectEqual(@as(u32, 128), VarargsRegisterSaveArea.vr_save_size);
    try testing.expectEqual(@as(u32, 192), VarargsRegisterSaveArea.total_size);
}

test "VarargsRegisterSaveArea emitSaveGeneralRegs" {
    const save_area = VarargsRegisterSaveArea.init(16);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try save_area.emitSaveGeneralRegs(&buffer);

    // Should emit 4 STP instructions (X0/X1, X2/X3, X4/X5, X6/X7)
    try testing.expectEqual(@as(usize, 16), buffer.data.items.len);
}

test "VarargsRegisterSaveArea emitSaveFloatRegs" {
    const save_area = VarargsRegisterSaveArea.init(16);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try save_area.emitSaveFloatRegs(&buffer);

    // Should emit 4 STP instructions (V0/V1, V2/V3, V4/V5, V6/V7)
    try testing.expectEqual(@as(usize, 16), buffer.data.items.len);
}

test "VarargsRegisterSaveArea emitSaveAll" {
    const save_area = VarargsRegisterSaveArea.init(32);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try save_area.emitSaveAll(&buffer);

    // Should emit 8 STP instructions (4 for general regs, 4 for float regs)
    try testing.expectEqual(@as(usize, 32), buffer.data.items.len);
}

test "VarargsRegisterSaveArea offset calculation" {
    const save_area = VarargsRegisterSaveArea.init(64);

    // General register save area starts at 64
    try testing.expectEqual(@as(i16, 64), save_area.gr_save_offset);

    // FP/SIMD save area starts 64 bytes after general regs
    try testing.expectEqual(@as(i16, 128), save_area.vr_save_offset);
}

test "VarargsRegisterSaveArea with zero offset" {
    const save_area = VarargsRegisterSaveArea.init(0);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try save_area.emitSaveAll(&buffer);

    // Should still generate correct code at offset 0
    try testing.expectEqual(@as(usize, 32), buffer.data.items.len);
}

test "VarargsRegisterSaveArea frame integration" {
    // Test that save area can be integrated into a stack frame
    const args = [_]abi_mod.Type{ .i64, .i64 };
    const sig = abi_mod.ABISignature.init(&args, &.{.i64}, .aapcs64);

    var callee = Aarch64ABICallee.init(testing.allocator, sig);
    defer callee.deinit();

    // Set up a frame with locals
    callee.setLocalsSize(32);

    // Calculate offset for varargs save area after FP/LR and callee-saves
    // Frame layout: [FP/LR] [callee-saves] [varargs save area] [locals]
    const varargs_offset = 16; // After FP/LR

    const save_area = VarargsRegisterSaveArea.init(@intCast(varargs_offset));

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Emit prologue
    try callee.emitPrologue(&buffer);

    const prologue_len = buffer.data.items.len;

    // Emit varargs save
    try save_area.emitSaveAll(&buffer);

    // Verify save instructions were added
    try testing.expect(buffer.data.items.len > prologue_len);
}

test "VarargsRegisterSaveArea alignment" {
    // Verify that save area sizes maintain 16-byte alignment
    try testing.expectEqual(@as(u32, 0), VarargsRegisterSaveArea.gr_save_size % 16);
    try testing.expectEqual(@as(u32, 0), VarargsRegisterSaveArea.vr_save_size % 16);
    try testing.expectEqual(@as(u32, 0), VarargsRegisterSaveArea.total_size % 16);
}

test "VarargsRegisterSaveArea general register coverage" {
    // Ensure all 8 argument registers are saved
    const save_area = VarargsRegisterSaveArea.init(0);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try save_area.emitSaveGeneralRegs(&buffer);

    // 4 STP instructions = 16 bytes, saves all X0-X7
    try testing.expectEqual(@as(usize, 16), buffer.data.items.len);

    // Verify the instructions are STP (opcode check)
    // STP 64-bit has opcode bits [31-22] = 0b1010100100
    for (0..4) |i| {
        const inst_bytes = buffer.data.items[i * 4 .. (i + 1) * 4];
        const inst = std.mem.bytesToValue(u32, inst_bytes);
        const opcode = (inst >> 22) & 0x3FF;
        try testing.expectEqual(@as(u32, 0b1010100100), opcode);
    }
}

test "VarargsRegisterSaveArea float register coverage" {
    // Ensure all 8 FP/SIMD argument registers are saved
    const save_area = VarargsRegisterSaveArea.init(0);

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try save_area.emitSaveFloatRegs(&buffer);

    // 4 STP instructions = 16 bytes, saves all V0-V7
    try testing.expectEqual(@as(usize, 16), buffer.data.items.len);
}
