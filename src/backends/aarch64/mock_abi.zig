//! Mock ABI for testing without full compilation pipeline.
//!
//! Provides lightweight ABICallee mock that tracks frame layout
//! and argument classification without requiring instruction emission.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("root");
const abi_mod = root.abi;
const PReg = root.aarch64_inst.PReg;

/// Mock ABICallee for testing frame layout and argument classification.
pub const MockABICallee = struct {
    allocator: Allocator,
    /// Number of integer arguments.
    num_int_args: u32,
    /// Number of float arguments.
    num_float_args: u32,
    /// Number of return values.
    num_rets: u32,
    /// Local variables and spill size.
    locals_size: u32,
    /// Number of clobbered callee-save registers.
    num_callee_saves: u32,
    /// Total aligned frame size.
    frame_size: u32,
    /// Number of arguments passed in registers.
    register_args: u32,
    /// Number of arguments passed on stack.
    stack_args: u32,
    /// Whether frame pointer is required.
    uses_frame_pointer: bool,
    /// Whether dynamic allocations are enabled.
    has_dynamic_alloc: bool,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .num_int_args = 0,
            .num_float_args = 0,
            .num_rets = 0,
            .locals_size = 0,
            .num_callee_saves = 0,
            .frame_size = 0,
            .register_args = 0,
            .stack_args = 0,
            .uses_frame_pointer = false,
            .has_dynamic_alloc = false,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Set number of integer arguments.
    pub fn setNumIntArgs(self: *Self, count: u32) void {
        self.num_int_args = count;
        self.updateArgClassification();
    }

    /// Set number of float arguments.
    pub fn setNumFloatArgs(self: *Self, count: u32) void {
        self.num_float_args = count;
        self.updateArgClassification();
    }

    /// Set number of return values.
    pub fn setNumRets(self: *Self, count: u32) void {
        self.num_rets = count;
    }

    /// Set size of local variables and spills.
    pub fn setLocalsSize(self: *Self, size: u32) void {
        self.locals_size = size;
        self.computeFrame();
    }

    /// Set number of clobbered callee-save registers.
    pub fn setNumCalleeSaves(self: *Self, count: u32) void {
        self.num_callee_saves = count;
        self.computeFrame();
    }

    /// Enable dynamic stack allocations.
    pub fn enableDynamicAlloc(self: *Self) void {
        self.has_dynamic_alloc = true;
        self.uses_frame_pointer = true;
    }

    /// Update argument classification (register vs stack).
    fn updateArgClassification(self: *Self) void {
        // AAPCS64: X0-X7 (8 int regs), V0-V7 (8 float regs)
        const max_int_regs = 8;
        const max_float_regs = 8;

        const int_in_regs = @min(self.num_int_args, max_int_regs);
        const float_in_regs = @min(self.num_float_args, max_float_regs);

        self.register_args = int_in_regs + float_in_regs;
        self.stack_args = (self.num_int_args -| int_in_regs) + (self.num_float_args -| float_in_regs);
    }

    /// Compute frame size with proper alignment.
    fn computeFrame(self: *Self) void {
        // FP + LR = 16 bytes
        const fp_lr_size: u32 = 16;

        // Callee-saves: round up to even count for STP pairing
        const callee_save_pairs = (self.num_callee_saves + 1) / 2;
        const callee_save_size = callee_save_pairs * 16;

        // Total before alignment
        const total = fp_lr_size + callee_save_size + self.locals_size;

        // 16-byte alignment
        self.frame_size = alignTo16(total);

        // Large frames (>4KB) require FP
        if (self.frame_size > 4096) {
            self.uses_frame_pointer = true;
        }
    }

    /// Get offset of local variable area.
    pub fn getLocalsOffset(self: Self) u32 {
        // Locals are after FP+LR and callee-saves
        const fp_lr_size: u32 = 16;
        const callee_save_pairs = (self.num_callee_saves + 1) / 2;
        const callee_save_size = callee_save_pairs * 16;
        return fp_lr_size + callee_save_size;
    }

    /// Get offset of nth stack argument.
    pub fn getStackArgOffset(self: Self, arg_index: u32) u32 {
        _ = self;
        // Stack args are at positive offsets from SP (caller's frame)
        // First stack arg is at SP+0, next at SP+8, etc.
        return arg_index * 8;
    }

    /// Get physical register for nth integer argument.
    pub fn getIntArgReg(self: Self, arg_index: u32) ?PReg {
        _ = self;
        if (arg_index < 8) {
            return PReg.new(.int, @intCast(arg_index));
        }
        return null; // On stack
    }

    /// Get physical register for nth float argument.
    pub fn getFloatArgReg(self: Self, arg_index: u32) ?PReg {
        _ = self;
        if (arg_index < 8) {
            return PReg.new(.float, @intCast(arg_index));
        }
        return null; // On stack
    }
};

/// Align value to 16-byte boundary.
fn alignTo16(value: u32) u32 {
    return (value + 15) & ~@as(u32, 15);
}

// Tests

test "MockABICallee: basic initialization" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    try testing.expectEqual(@as(u32, 0), mock.num_int_args);
    try testing.expectEqual(@as(u32, 0), mock.num_float_args);
    try testing.expectEqual(@as(u32, 0), mock.frame_size);
    try testing.expectEqual(@as(u32, 0), mock.register_args);
    try testing.expectEqual(@as(u32, 0), mock.stack_args);
    try testing.expect(!mock.uses_frame_pointer);
}

test "MockABICallee: argument classification - all in registers" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    mock.setNumIntArgs(4);
    mock.setNumFloatArgs(4);

    try testing.expectEqual(@as(u32, 8), mock.register_args);
    try testing.expectEqual(@as(u32, 0), mock.stack_args);
}

test "MockABICallee: argument classification - overflow to stack" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 10 int args: 8 in regs, 2 on stack
    mock.setNumIntArgs(10);

    try testing.expectEqual(@as(u32, 8), mock.register_args);
    try testing.expectEqual(@as(u32, 2), mock.stack_args);
}

test "MockABICallee: frame size calculation" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // Just FP+LR (16 bytes) -> aligned to 16
    mock.setLocalsSize(0);
    try testing.expectEqual(@as(u32, 16), mock.frame_size);

    // FP+LR + 10 bytes locals -> 26 -> align to 32
    mock.setLocalsSize(10);
    try testing.expectEqual(@as(u32, 32), mock.frame_size);

    // FP+LR + 100 bytes locals -> 116 -> align to 128
    mock.setLocalsSize(100);
    try testing.expectEqual(@as(u32, 128), mock.frame_size);
}

test "MockABICallee: callee-save registers affect frame size" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // 2 callee-saves = 1 pair = 16 bytes
    // FP+LR (16) + 1 pair (16) = 32
    mock.setNumCalleeSaves(2);
    try testing.expectEqual(@as(u32, 32), mock.frame_size);

    // 3 callee-saves = 2 pairs = 32 bytes (odd count rounds up)
    // FP+LR (16) + 2 pairs (32) = 48
    mock.setNumCalleeSaves(3);
    try testing.expectEqual(@as(u32, 48), mock.frame_size);
}

test "MockABICallee: large frame requires FP" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // Small frame
    mock.setLocalsSize(1000);
    try testing.expect(!mock.uses_frame_pointer);

    // Large frame (>4KB)
    mock.setLocalsSize(5000);
    try testing.expect(mock.uses_frame_pointer);
}

test "MockABICallee: dynamic allocations require FP" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    try testing.expect(!mock.uses_frame_pointer);

    mock.enableDynamicAlloc();

    try testing.expect(mock.uses_frame_pointer);
    try testing.expect(mock.has_dynamic_alloc);
}

test "MockABICallee: argument register mapping" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // Int args: X0-X7
    try testing.expectEqual(PReg.new(.int, 0), mock.getIntArgReg(0).?);
    try testing.expectEqual(PReg.new(.int, 7), mock.getIntArgReg(7).?);
    try testing.expectEqual(@as(?PReg, null), mock.getIntArgReg(8));

    // Float args: V0-V7
    try testing.expectEqual(PReg.new(.float, 0), mock.getFloatArgReg(0).?);
    try testing.expectEqual(PReg.new(.float, 7), mock.getFloatArgReg(7).?);
    try testing.expectEqual(@as(?PReg, null), mock.getFloatArgReg(8));
}

test "MockABICallee: stack argument offsets" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // Stack args at SP+0, SP+8, SP+16, ...
    try testing.expectEqual(@as(u32, 0), mock.getStackArgOffset(0));
    try testing.expectEqual(@as(u32, 8), mock.getStackArgOffset(1));
    try testing.expectEqual(@as(u32, 16), mock.getStackArgOffset(2));
}

test "MockABICallee: locals offset calculation" {
    var mock = MockABICallee.init(testing.allocator);
    defer mock.deinit();

    // With no callee-saves: offset = FP+LR = 16
    try testing.expectEqual(@as(u32, 16), mock.getLocalsOffset());

    // With 2 callee-saves (1 pair = 16 bytes): offset = 16 + 16 = 32
    mock.setNumCalleeSaves(2);
    try testing.expectEqual(@as(u32, 32), mock.getLocalsOffset());
}
