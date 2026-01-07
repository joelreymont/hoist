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

/// Element type for vectors.
pub const VectorElementType = enum {
    i8,
    i16,
    i32,
    i64,
    f32,
    f64,
};

/// Type stub for ABI.
pub const Type = union(enum) {
    i32,
    i64,
    f32,
    f64,
    /// 64-bit SIMD vector (e.g., D register on ARM64).
    v64: struct {
        elem_type: VectorElementType,
        lane_count: u8,
    },
    /// 128-bit SIMD vector (e.g., Q register on ARM64, XMM on x64).
    v128: struct {
        elem_type: VectorElementType,
        lane_count: u8,
    },
    @"struct": []const StructField,

    pub fn regClass(self: Type) RegClass {
        return switch (self) {
            .i32, .i64 => .int,
            .f32, .f64 => .float,
            .v64, .v128 => .vector,
            .@"struct" => .int, // Default to int, caller should use classifyStruct
        };
    }

    pub fn bytes(self: Type) u32 {
        return switch (self) {
            .i32, .f32 => 4,
            .i64, .f64 => 8,
            .v64 => 8,
            .v128 => 16,
            .@"struct" => |fields| blk: {
                if (fields.len == 0) break :blk 0;
                const last = fields[fields.len - 1];
                break :blk last.offset + last.ty.bytes();
            },
        };
    }

    /// Check if this type is a vector type.
    pub fn isVector(self: Type) bool {
        return switch (self) {
            .v64, .v128 => true,
            else => false,
        };
    }

    /// Get the element type of a vector type.
    /// Returns null if this is not a vector type.
    pub fn vectorElementType(self: Type) ?VectorElementType {
        return switch (self) {
            .v64 => |v| v.elem_type,
            .v128 => |v| v.elem_type,
            else => null,
        };
    }

    /// Get the lane count of a vector type.
    /// Returns null if this is not a vector type.
    pub fn vectorLaneCount(self: Type) ?u8 {
        return switch (self) {
            .v64 => |v| v.lane_count,
            .v128 => |v| v.lane_count,
            else => null,
        };
    }

    /// Get the size in bytes of a vector element type.
    pub fn vectorElementBytes(elem_type: VectorElementType) u32 {
        return switch (elem_type) {
            .i8 => 1,
            .i16 => 2,
            .i32, .f32 => 4,
            .i64, .f64 => 8,
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
    /// Fast calling convention - aggressive register usage, caller-save all volatiles.
    /// Passes more arguments in registers than standard C convention.
    fast,
    /// PreserveAll calling convention - callee saves all GPRs and FPRs except arguments.
    /// Used for statepoints/patchpoints in garbage collection.
    preserve_all,
    /// Cold calling convention - marks function as rarely executed.
    /// Same register allocation as C, but hints for de-prioritizing optimization.
    cold,
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
                var slots = std.ArrayList(ABIArgSlot){};
                errdefer slots.deinit(allocator);

                // Handle struct classification for ARM64
                if (arg_ty == .@"struct") {
                    const aarch64_abi = @import("../backends/aarch64/abi.zig");
                    const classification = aarch64_abi.classifyStruct(arg_ty);

                    switch (classification.class) {
                        .indirect => {
                            // Pass pointer in integer register or on stack
                            if (int_reg_idx < self.int_arg_regs.len) {
                                const preg = self.int_arg_regs[int_reg_idx];
                                try slots.append(allocator, .{
                                    .reg = .{
                                        .preg = preg,
                                        .ty = .i64, // Pointer type
                                        .extension = .none,
                                    },
                                });
                                int_reg_idx += 1;
                            } else {
                                try slots.append(allocator, .{ .stack = .{
                                    .offset = stack_offset,
                                    .ty = .i64,
                                    .extension = .none,
                                } });
                                stack_offset += 8;
                                stack_offset = std.mem.alignForward(i64, stack_offset, self.stack_align);
                            }
                        },
                        .hfa => {
                            // HFA: allocate to consecutive float registers
                            const fields = arg_ty.@"struct";
                            const num_members = fields.len;

                            if (float_reg_idx + num_members <= self.float_arg_regs.len) {
                                for (0..num_members) |i| {
                                    const preg = self.float_arg_regs[float_reg_idx + i];
                                    try slots.append(allocator, .{ .reg = .{
                                        .preg = preg,
                                        .ty = classification.elem_ty.?,
                                        .extension = .none,
                                    } });
                                }
                                float_reg_idx += num_members;
                            } else {
                                // Entire HFA spills to stack
                                float_reg_idx = self.float_arg_regs.len; // Exhaust float regs
                                const struct_size = arg_ty.bytes();
                                try slots.append(allocator, .{ .stack = .{
                                    .offset = stack_offset,
                                    .ty = arg_ty,
                                    .extension = .none,
                                } });
                                stack_offset += @intCast(struct_size);
                                stack_offset = std.mem.alignForward(i64, stack_offset, 8);
                            }
                        },
                        .hva => {
                            // HVA: similar to HFA but for vector types
                            // TODO: implement when vector types are added
                            return error.UnsupportedHVA;
                        },
                        .general => {
                            // General struct ≤16 bytes: treat as composite integer
                            // Fall through to normal handling
                            const rc = arg_ty.regClass();
                            try handleRegClass(rc, arg_ty, &int_reg_idx, &float_reg_idx, &stack_offset, &slots, self, allocator);
                        },
                    }
                } else {
                    const rc = arg_ty.regClass();
                    try handleRegClass(rc, arg_ty, &int_reg_idx, &float_reg_idx, &stack_offset, &slots, self, allocator);
                }

                try args.append(allocator, .{ .slots = try slots.toOwnedSlice(allocator) });
            }

            return args.toOwnedSlice(allocator);
        }

        fn handleRegClass(
            rc: RegClass,
            arg_ty: Type,
            int_reg_idx: *usize,
            float_reg_idx: *usize,
            stack_offset: *i64,
            slots: *std.ArrayList(ABIArgSlot),
            self: *const Self,
            allocator: Allocator,
        ) !void {
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

test "vector type v64 properties" {
    const vec_ty = Type{ .v64 = .{ .elem_type = .f32, .lane_count = 2 } };

    // Check type classification
    try testing.expect(vec_ty.isVector());
    try testing.expectEqual(RegClass.vector, vec_ty.regClass());

    // Check size
    try testing.expectEqual(@as(u32, 8), vec_ty.bytes());

    // Check element type and lane count
    try testing.expectEqual(VectorElementType.f32, vec_ty.vectorElementType().?);
    try testing.expectEqual(@as(u8, 2), vec_ty.vectorLaneCount().?);
}

test "vector type v128 properties" {
    const vec_ty = Type{ .v128 = .{ .elem_type = .i32, .lane_count = 4 } };

    // Check type classification
    try testing.expect(vec_ty.isVector());
    try testing.expectEqual(RegClass.vector, vec_ty.regClass());

    // Check size
    try testing.expectEqual(@as(u32, 16), vec_ty.bytes());

    // Check element type and lane count
    try testing.expectEqual(VectorElementType.i32, vec_ty.vectorElementType().?);
    try testing.expectEqual(@as(u8, 4), vec_ty.vectorLaneCount().?);
}

test "vector type isVector returns false for scalars" {
    try testing.expect(!Type.i32.isVector());
    try testing.expect(!Type.i64.isVector());
    try testing.expect(!Type.f32.isVector());
    try testing.expect(!Type.f64.isVector());

    const struct_ty = Type{ .@"struct" = &.{} };
    try testing.expect(!struct_ty.isVector());
}

test "vector type vectorElementType returns null for non-vectors" {
    try testing.expectEqual(@as(?VectorElementType, null), Type.i32.vectorElementType());
    try testing.expectEqual(@as(?VectorElementType, null), Type.f32.vectorElementType());
    try testing.expectEqual(@as(?VectorElementType, null), Type.i64.vectorElementType());
}

test "vector type vectorLaneCount returns null for non-vectors" {
    try testing.expectEqual(@as(?u8, null), Type.i32.vectorLaneCount());
    try testing.expectEqual(@as(?u8, null), Type.f32.vectorLaneCount());
    try testing.expectEqual(@as(?u8, null), Type.i64.vectorLaneCount());
}

test "vectorElementBytes helper function" {
    try testing.expectEqual(@as(u32, 1), Type.vectorElementBytes(.i8));
    try testing.expectEqual(@as(u32, 2), Type.vectorElementBytes(.i16));
    try testing.expectEqual(@as(u32, 4), Type.vectorElementBytes(.i32));
    try testing.expectEqual(@as(u32, 4), Type.vectorElementBytes(.f32));
    try testing.expectEqual(@as(u32, 8), Type.vectorElementBytes(.i64));
    try testing.expectEqual(@as(u32, 8), Type.vectorElementBytes(.f64));
}

test "vector type v64 with different element types" {
    // v64 with i8 elements (8 lanes)
    const v64_i8 = Type{ .v64 = .{ .elem_type = .i8, .lane_count = 8 } };
    try testing.expectEqual(@as(u32, 8), v64_i8.bytes());
    try testing.expectEqual(VectorElementType.i8, v64_i8.vectorElementType().?);
    try testing.expectEqual(@as(u8, 8), v64_i8.vectorLaneCount().?);

    // v64 with i16 elements (4 lanes)
    const v64_i16 = Type{ .v64 = .{ .elem_type = .i16, .lane_count = 4 } };
    try testing.expectEqual(@as(u32, 8), v64_i16.bytes());
    try testing.expectEqual(VectorElementType.i16, v64_i16.vectorElementType().?);
    try testing.expectEqual(@as(u8, 4), v64_i16.vectorLaneCount().?);

    // v64 with i32 elements (2 lanes)
    const v64_i32 = Type{ .v64 = .{ .elem_type = .i32, .lane_count = 2 } };
    try testing.expectEqual(@as(u32, 8), v64_i32.bytes());
    try testing.expectEqual(VectorElementType.i32, v64_i32.vectorElementType().?);
    try testing.expectEqual(@as(u8, 2), v64_i32.vectorLaneCount().?);

    // v64 with i64 elements (1 lane)
    const v64_i64 = Type{ .v64 = .{ .elem_type = .i64, .lane_count = 1 } };
    try testing.expectEqual(@as(u32, 8), v64_i64.bytes());
    try testing.expectEqual(VectorElementType.i64, v64_i64.vectorElementType().?);
    try testing.expectEqual(@as(u8, 1), v64_i64.vectorLaneCount().?);
}

test "vector type v128 with different element types" {
    // v128 with i8 elements (16 lanes)
    const v128_i8 = Type{ .v128 = .{ .elem_type = .i8, .lane_count = 16 } };
    try testing.expectEqual(@as(u32, 16), v128_i8.bytes());
    try testing.expectEqual(VectorElementType.i8, v128_i8.vectorElementType().?);
    try testing.expectEqual(@as(u8, 16), v128_i8.vectorLaneCount().?);

    // v128 with f32 elements (4 lanes)
    const v128_f32 = Type{ .v128 = .{ .elem_type = .f32, .lane_count = 4 } };
    try testing.expectEqual(@as(u32, 16), v128_f32.bytes());
    try testing.expectEqual(VectorElementType.f32, v128_f32.vectorElementType().?);
    try testing.expectEqual(@as(u8, 4), v128_f32.vectorLaneCount().?);

    // v128 with f64 elements (2 lanes)
    const v128_f64 = Type{ .v128 = .{ .elem_type = .f64, .lane_count = 2 } };
    try testing.expectEqual(@as(u32, 16), v128_f64.bytes());
    try testing.expectEqual(VectorElementType.f64, v128_f64.vectorElementType().?);
    try testing.expectEqual(@as(u8, 2), v128_f64.vectorLaneCount().?);
}

test "vector argument allocation in float registers" {
    const abi = sysv_amd64();

    const vec_ty = Type{ .v128 = .{ .elem_type = .f32, .lane_count = 4 } };
    const args = [_]Type{ .f32, vec_ty, .f64 };
    const sig = ABISignature.init(&args, &.{}, .system_v);

    const arg_locs = try abi.computeArgLocs(sig, testing.allocator);
    defer {
        for (arg_locs) |arg| {
            testing.allocator.free(arg.slots);
        }
        testing.allocator.free(arg_locs);
    }

    try testing.expectEqual(@as(usize, 3), arg_locs.len);

    // All should be in float registers (XMM0, XMM1, XMM2)
    try testing.expect(arg_locs[0].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 0), arg_locs[0].slots[0].reg.preg);

    try testing.expect(arg_locs[1].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 1), arg_locs[1].slots[0].reg.preg);
    try testing.expectEqual(RegClass.vector, arg_locs[1].slots[0].reg.ty.regClass());

    try testing.expect(arg_locs[2].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 2), arg_locs[2].slots[0].reg.preg);
}

test "vector return value allocation in float registers" {
    const abi = sysv_amd64();

    const vec_ty = Type{ .v128 = .{ .elem_type = .f64, .lane_count = 2 } };
    const rets = [_]Type{vec_ty};
    const sig = ABISignature.init(&.{}, &rets, .system_v);

    const ret_locs = try abi.computeRetLocs(sig, testing.allocator);
    defer {
        for (ret_locs) |ret| {
            testing.allocator.free(ret.slots);
        }
        testing.allocator.free(ret_locs);
    }

    try testing.expectEqual(@as(usize, 1), ret_locs.len);

    // Vector return in XMM0
    try testing.expect(ret_locs[0].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 0), ret_locs[0].slots[0].reg.preg);
    try testing.expectEqual(RegClass.vector, ret_locs[0].slots[0].reg.ty.regClass());
}
// ARM64 AAPCS ABI tests

test "AAPCS64 float argument allocation" {
    const aarch64_abi = @import("../backends/aarch64/abi.zig");
    const abi = aarch64_abi.aapcs64();

    const args = [_]Type{ .f32, .f64, .f32 };
    const sig = ABISignature.init(&args, &.{}, .aapcs64);

    const arg_locs = try abi.computeArgLocs(sig, testing.allocator);
    defer {
        for (arg_locs) |arg| {
            testing.allocator.free(arg.slots);
        }
        testing.allocator.free(arg_locs);
    }

    try testing.expectEqual(@as(usize, 3), arg_locs.len);

    // First float arg in V0
    try testing.expect(arg_locs[0].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 0), arg_locs[0].slots[0].reg.preg);
    try testing.expectEqual(Type.f32, arg_locs[0].slots[0].reg.ty);

    // Second float arg in V1
    try testing.expect(arg_locs[1].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 1), arg_locs[1].slots[0].reg.preg);
    try testing.expectEqual(Type.f64, arg_locs[1].slots[0].reg.ty);

    // Third float arg in V2
    try testing.expect(arg_locs[2].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 2), arg_locs[2].slots[0].reg.preg);
    try testing.expectEqual(Type.f32, arg_locs[2].slots[0].reg.ty);
}

test "AAPCS64 mixed int and float arguments" {
    const aarch64_abi = @import("../backends/aarch64/abi.zig");
    const abi = aarch64_abi.aapcs64();

    // Mix of int and float args: int, float, int, float
    const args = [_]Type{ .i64, .f32, .i32, .f64 };
    const sig = ABISignature.init(&args, &.{}, .aapcs64);

    const arg_locs = try abi.computeArgLocs(sig, testing.allocator);
    defer {
        for (arg_locs) |arg| {
            testing.allocator.free(arg.slots);
        }
        testing.allocator.free(arg_locs);
    }

    try testing.expectEqual(@as(usize, 4), arg_locs.len);

    // First int arg in X0
    try testing.expect(arg_locs[0].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.int, 0), arg_locs[0].slots[0].reg.preg);

    // First float arg in V0
    try testing.expect(arg_locs[1].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 0), arg_locs[1].slots[0].reg.preg);

    // Second int arg in X1
    try testing.expect(arg_locs[2].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.int, 1), arg_locs[2].slots[0].reg.preg);

    // Second float arg in V1
    try testing.expect(arg_locs[3].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 1), arg_locs[3].slots[0].reg.preg);
}

test "AAPCS64 float register exhaustion" {
    const aarch64_abi = @import("../backends/aarch64/abi.zig");
    const abi = aarch64_abi.aapcs64();

    // 9 float args - first 8 in V0-V7, 9th on stack
    const args = [_]Type{ .f64, .f32, .f64, .f32, .f64, .f32, .f64, .f32, .f64 };
    const sig = ABISignature.init(&args, &.{}, .aapcs64);

    const arg_locs = try abi.computeArgLocs(sig, testing.allocator);
    defer {
        for (arg_locs) |arg| {
            testing.allocator.free(arg.slots);
        }
        testing.allocator.free(arg_locs);
    }

    try testing.expectEqual(@as(usize, 9), arg_locs.len);

    // First 8 in float registers
    for (0..8) |i| {
        try testing.expect(arg_locs[i].slots[0] == .reg);
        try testing.expectEqual(PReg.new(.float, @intCast(i)), arg_locs[i].slots[0].reg.preg);
    }

    // 9th on stack
    try testing.expect(arg_locs[8].slots[0] == .stack);
    try testing.expectEqual(@as(i64, 0), arg_locs[8].slots[0].stack.offset);
}

test "AAPCS64 float return values" {
    const aarch64_abi = @import("../backends/aarch64/abi.zig");
    const abi = aarch64_abi.aapcs64();

    const rets = [_]Type{ .f32, .f64 };
    const sig = ABISignature.init(&.{}, &rets, .aapcs64);

    const ret_locs = try abi.computeRetLocs(sig, testing.allocator);
    defer {
        for (ret_locs) |ret| {
            testing.allocator.free(ret.slots);
        }
        testing.allocator.free(ret_locs);
    }

    try testing.expectEqual(@as(usize, 2), ret_locs.len);

    // First return in V0
    try testing.expect(ret_locs[0].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 0), ret_locs[0].slots[0].reg.preg);
    try testing.expectEqual(Type.f32, ret_locs[0].slots[0].reg.ty);

    // Second return in V1
    try testing.expect(ret_locs[1].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 1), ret_locs[1].slots[0].reg.preg);
    try testing.expectEqual(Type.f64, ret_locs[1].slots[0].reg.ty);
}

test "AAPCS64 vector arguments in float registers" {
    const aarch64_abi = @import("../backends/aarch64/abi.zig");
    const abi = aarch64_abi.aapcs64();

    const vec_ty = Type{ .v128 = .{ .elem_type = .f32, .lane_count = 4 } };
    const args = [_]Type{ vec_ty, .f64, vec_ty };
    const sig = ABISignature.init(&args, &.{}, .aapcs64);

    const arg_locs = try abi.computeArgLocs(sig, testing.allocator);
    defer {
        for (arg_locs) |arg| {
            testing.allocator.free(arg.slots);
        }
        testing.allocator.free(arg_locs);
    }

    try testing.expectEqual(@as(usize, 3), arg_locs.len);

    // All should be in float registers (V0, V1, V2)
    try testing.expect(arg_locs[0].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 0), arg_locs[0].slots[0].reg.preg);
    try testing.expectEqual(RegClass.vector, arg_locs[0].slots[0].reg.ty.regClass());

    try testing.expect(arg_locs[1].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 1), arg_locs[1].slots[0].reg.preg);
    try testing.expectEqual(RegClass.float, arg_locs[1].slots[0].reg.ty.regClass());

    try testing.expect(arg_locs[2].slots[0] == .reg);
    try testing.expectEqual(PReg.new(.float, 2), arg_locs[2].slots[0].reg.preg);
    try testing.expectEqual(RegClass.vector, arg_locs[2].slots[0].reg.ty.regClass());
}
