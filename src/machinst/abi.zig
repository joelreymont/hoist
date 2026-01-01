const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const reg_mod = @import("reg.zig");
// Type stubs for testing

pub const Reg = reg_mod.Reg;
pub const PReg = reg_mod.PReg;
pub const VReg = reg_mod.VReg;
pub const RegClass = reg_mod.RegClass;

/// Struct field descriptor for ABI.
pub const StructField = struct {
    ty: Type,
    offset: u32,
};

/// Type stub for ABI.
pub const Type = union(enum) {
    i32,
    i64,
    f32,
    f64,
    @"struct": []const StructField,

    pub fn regClass(self: Type) RegClass {
        return switch (self) {
            .i32, .i64 => .int,
            .f32, .f64 => .float,
            .@"struct" => .int, // Default to int, caller should use classifyStruct
        };
    }

    pub fn bytes(self: Type) u32 {
        return switch (self) {
            .i32, .f32 => 4,
            .i64, .f64 => 8,
            .@"struct" => |fields| blk: {
                if (fields.len == 0) break :blk 0;
                const last = fields[fields.len - 1];
                break :blk last.offset + last.ty.bytes();
            },
        };
    }
};

/// Calling convention identifier.
pub const CallConv = enum {
    /// System V AMD64 ABI (Linux, macOS, BSD).
    system_v,
    /// Windows x64 calling convention.
    windows_fastcall,
    /// ARM64 AAPCS calling convention.
    aapcs64,
};

/// Argument extension mode.
pub const ArgumentExtension = enum {
    /// No extension.
    none,
    /// Zero-extend.
    uext,
    /// Sign-extend.
    sext,
};

/// Location of a single argument or return value part.
pub const ABIArgSlot = union(enum) {
    /// Argument in a register.
    reg: struct {
        /// Physical register.
        preg: PReg,
        /// Value type.
        ty: Type,
        /// Extension mode.
        extension: ArgumentExtension,
    },
    /// Argument on stack.
    stack: struct {
        /// Offset from stack pointer.
        offset: i64,
        /// Value type.
        ty: Type,
        /// Extension mode.
        extension: ArgumentExtension,
    },

    pub fn format(
        self: ABIArgSlot,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .reg => |r| try writer.print("reg({}, {})", .{ r.preg, r.ty }),
            .stack => |s| try writer.print("stack({d}, {})", .{ s.offset, s.ty }),
        }
    }
};

/// Complete argument or return value location (may span multiple slots).
pub const ABIArg = struct {
    /// Slots for this argument (one per register part).
    slots: []const ABIArgSlot,

    pub fn format(
        self: ABIArg,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (self.slots.len == 1) {
            try writer.print("{}", .{self.slots[0]});
        } else {
            try writer.writeAll("[");
            for (self.slots, 0..) |slot, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.print("{}", .{slot});
            }
            try writer.writeAll("]");
        }
    }
};

/// Function signature for ABI computations.
pub const ABISignature = struct {
    /// Argument types.
    args: []const Type,
    /// Return value types.
    rets: []const Type,
    /// Calling convention.
    call_conv: CallConv,

    pub fn init(
        args: []const Type,
        rets: []const Type,
        call_conv: CallConv,
    ) ABISignature {
        return .{
            .args = args,
            .rets = rets,
            .call_conv = call_conv,
        };
    }
};

/// Computed argument/return locations for a signature.
pub const ABICallingConvention = struct {
    /// Argument locations.
    args: []const ABIArg,
    /// Return value locations.
    rets: []const ABIArg,
    /// Total stack space needed for arguments (bytes).
    stack_arg_space: u32,
    /// Total stack space needed for returns (bytes).
    stack_ret_space: u32,
    /// Allocator.
    allocator: Allocator,

    pub fn deinit(self: *ABICallingConvention) void {
        for (self.args) |arg| {
            self.allocator.free(arg.slots);
        }
        self.allocator.free(self.args);

        for (self.rets) |ret| {
            self.allocator.free(ret.slots);
        }
        self.allocator.free(self.rets);
    }
};

/// ABI machine specification - defines calling convention behavior.
pub fn ABIMachineSpec(comptime WordSize: type) type {
    return struct {
        /// Word size in bits (32 or 64).
        pub const word_bits: u32 = @bitSizeOf(WordSize);
        /// Word size in bytes.
        pub const word_bytes: u32 = @sizeOf(WordSize);

        /// Integer argument registers (in order).
        int_arg_regs: []const PReg,
        /// Float argument registers (in order).
        float_arg_regs: []const PReg,
        /// Integer return registers.
        int_ret_regs: []const PReg,
        /// Float return registers.
        float_ret_regs: []const PReg,
        /// Callee-save registers.
        callee_saves: []const PReg,
        /// Stack alignment in bytes.
        stack_align: u32,

        const Self = @This();

        /// Compute argument locations for a signature.
        pub fn computeArgLocs(
            self: *const Self,
            sig: ABISignature,
            allocator: Allocator,
        ) ![]ABIArg {
            var args = std.ArrayList(ABIArg){};
            errdefer {
                for (args.items) |arg| {
                    allocator.free(arg.slots);
                }
                args.deinit(allocator);
            }

            var int_reg_idx: usize = 0;
            var float_reg_idx: usize = 0;
            var stack_offset: i64 = 0;

            for (sig.args) |arg_ty| {
                const rc = arg_ty.regClass();
                var slots = std.ArrayList(ABIArgSlot){};
                errdefer slots.deinit(allocator);

                switch (rc) {
                    .int => {
                        if (int_reg_idx < self.int_arg_regs.len) {
                            const preg = self.int_arg_regs[int_reg_idx];
                            try slots.append(allocator, .{ .reg = .{
                                .preg = preg,
                                .ty = arg_ty,
                                .extension = .none,
                            } });
                            int_reg_idx += 1;
                        } else {
                            // Spill to stack.
                            try slots.append(allocator, .{ .stack = .{
                                .offset = stack_offset,
                                .ty = arg_ty,
                                .extension = .none,
                            } });
                            stack_offset += @as(i64, @intCast(arg_ty.bytes()));
                            stack_offset = std.mem.alignForward(i64, stack_offset, self.stack_align);
                        }
                    },
                    .float, .vector => {
                        if (float_reg_idx < self.float_arg_regs.len) {
                            const preg = self.float_arg_regs[float_reg_idx];
                            try slots.append(allocator, .{ .reg = .{
                                .preg = preg,
                                .ty = arg_ty,
                                .extension = .none,
                            } });
                            float_reg_idx += 1;
                        } else {
                            try slots.append(allocator, .{ .stack = .{
                                .offset = stack_offset,
                                .ty = arg_ty,
                                .extension = .none,
                            } });
                            stack_offset += @as(i64, @intCast(arg_ty.bytes()));
                            stack_offset = std.mem.alignForward(i64, stack_offset, self.stack_align);
                        }
                    },
                }

                try args.append(allocator, .{ .slots = try slots.toOwnedSlice(allocator) });
            }

            return args.toOwnedSlice(allocator);
        }

        /// Compute return value locations for a signature.
        pub fn computeRetLocs(
            self: *const Self,
            sig: ABISignature,
            allocator: Allocator,
        ) ![]ABIArg {
            var rets = std.ArrayList(ABIArg){};
            errdefer {
                for (rets.items) |ret| {
                    allocator.free(ret.slots);
                }
                rets.deinit(allocator);
            }

            var int_reg_idx: usize = 0;
            var float_reg_idx: usize = 0;

            for (sig.rets) |ret_ty| {
                const rc = ret_ty.regClass();
                var slots = std.ArrayList(ABIArgSlot){};
                errdefer slots.deinit(allocator);

                switch (rc) {
                    .int => {
                        if (int_reg_idx < self.int_ret_regs.len) {
                            const preg = self.int_ret_regs[int_reg_idx];
                            try slots.append(allocator, .{ .reg = .{
                                .preg = preg,
                                .ty = ret_ty,
                                .extension = .none,
                            } });
                            int_reg_idx += 1;
                        } else {
                            return error.TooManyReturns;
                        }
                    },
                    .float, .vector => {
                        if (float_reg_idx < self.float_ret_regs.len) {
                            const preg = self.float_ret_regs[float_reg_idx];
                            try slots.append(allocator, .{ .reg = .{
                                .preg = preg,
                                .ty = ret_ty,
                                .extension = .none,
                            } });
                            float_reg_idx += 1;
                        } else {
                            return error.TooManyReturns;
                        }
                    },
                }

                try rets.append(allocator, .{ .slots = try slots.toOwnedSlice(allocator) });
            }

            return rets.toOwnedSlice(allocator);
        }

        /// Compute full calling convention for a signature.
        pub fn computeCallingConvention(
            self: *const Self,
            sig: ABISignature,
            allocator: Allocator,
        ) !ABICallingConvention {
            const args = try self.computeArgLocs(sig, allocator);
            errdefer {
                for (args) |arg| {
                    allocator.free(arg.slots);
                }
                allocator.free(args);
            }

            const rets = try self.computeRetLocs(sig, allocator);
            errdefer {
                for (rets) |ret| {
                    allocator.free(ret.slots);
                }
                allocator.free(rets);
            }

            // Calculate stack space.
            var stack_arg_space: u32 = 0;
            for (args) |arg| {
                for (arg.slots) |slot| {
                    if (slot == .stack) {
                        const end = slot.stack.offset + @as(i64, @intCast(slot.stack.ty.bytes()));
                        stack_arg_space = @max(stack_arg_space, @as(u32, @intCast(end)));
                    }
                }
            }

            return ABICallingConvention{
                .args = args,
                .rets = rets,
                .stack_arg_space = stack_arg_space,
                .stack_ret_space = 0,
                .allocator = allocator,
            };
        }
    };
}

/// System V AMD64 ABI specification.
pub fn sysv_amd64() ABIMachineSpec(u64) {
    // System V argument registers: RDI, RSI, RDX, RCX, R8, R9
    const int_args = [_]PReg{
        PReg.new(.int, 7), // RDI
        PReg.new(.int, 6), // RSI
        PReg.new(.int, 2), // RDX
        PReg.new(.int, 1), // RCX
        PReg.new(.int, 8), // R8
        PReg.new(.int, 9), // R9
    };

    // XMM0-XMM7 for float args
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

    // Return registers: RAX, RDX
    const int_rets = [_]PReg{
        PReg.new(.int, 0), // RAX
        PReg.new(.int, 2), // RDX
    };

    // XMM0, XMM1 for float returns
    const float_rets = [_]PReg{
        PReg.new(.float, 0),
        PReg.new(.float, 1),
    };

    // Callee-saves: RBX, RBP, R12-R15
    const callee_saves = [_]PReg{
        PReg.new(.int, 3), // RBX
        PReg.new(.int, 5), // RBP
        PReg.new(.int, 12),
        PReg.new(.int, 13),
        PReg.new(.int, 14),
        PReg.new(.int, 15),
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

test "ABIMachineSpec arg allocation" {
    const abi = sysv_amd64();

    const args = [_]Type{ .i64, .i32, .i64 };
    const sig = ABISignature.init(&args, &.{}, .system_v);

    const arg_locs = try abi.computeArgLocs(sig, testing.allocator);
    defer {
        for (arg_locs) |arg| {
            testing.allocator.free(arg.slots);
        }
        testing.allocator.free(arg_locs);
    }

    try testing.expectEqual(@as(usize, 3), arg_locs.len);

    // First arg in RDI
    try testing.expectEqual(@as(usize, 1), arg_locs[0].slots.len);
    try testing.expect(arg_locs[0].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.int, 7), arg_locs[0].slots[0].reg.preg);

    // Second arg in RSI
    try testing.expect(arg_locs[1].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.int, 6), arg_locs[1].slots[0].reg.preg);

    // Third arg in RDX
    try testing.expect(arg_locs[2].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.int, 2), arg_locs[2].slots[0].reg.preg);
}

test "ABIMachineSpec stack spillover" {
    const abi = sysv_amd64();

    // 7 int args - first 6 in regs, 7th on stack
    const args = [_]Type{ .i64, .i64, .i64, .i64, .i64, .i64, .i64 };
    const sig = ABISignature.init(&args, &.{}, .system_v);

    const arg_locs = try abi.computeArgLocs(sig, testing.allocator);
    defer {
        for (arg_locs) |arg| {
            testing.allocator.free(arg.slots);
        }
        testing.allocator.free(arg_locs);
    }

    // First 6 in regs
    for (0..6) |i| {
        try testing.expect(arg_locs[i].slots[0] == .reg);
    }

    // 7th on stack
    try testing.expect(arg_locs[6].slots[0] == .stack);
    try testing.expectEqual(@as(i64, 0), arg_locs[6].slots[0].stack.offset);
}

test "ABIMachineSpec return values" {
    const abi = sysv_amd64();

    const rets = [_]Type{ .i64, .i32 };
    const sig = ABISignature.init(&.{}, &rets, .system_v);

    const ret_locs = try abi.computeRetLocs(sig, testing.allocator);
    defer {
        for (ret_locs) |ret| {
            testing.allocator.free(ret.slots);
        }
        testing.allocator.free(ret_locs);
    }

    try testing.expectEqual(@as(usize, 2), ret_locs.len);

    // First return in RAX
    try testing.expect(ret_locs[0].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.int, 0), ret_locs[0].slots[0].reg.preg);

    // Second return in RDX
    try testing.expect(ret_locs[1].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.int, 2), ret_locs[1].slots[0].reg.preg);
}
