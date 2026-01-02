const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const reg_mod = @import("reg.zig");

pub const VReg = reg_mod.VReg;
pub const Reg = reg_mod.Reg;
pub const RegClass = reg_mod.RegClass;

/// VRegAllocator - allocates virtual registers during lowering.
///
/// Tracks the next available VReg index for each register class.
/// Virtual registers are allocated sequentially within each class.
///
/// Based on Cranelift's machinst/vcode.rs:VRegAllocator.
pub const VRegAllocator = struct {
    /// Next vreg index per register class.
    next_vreg: [RegClass.count]u32,

    /// Allocator (currently unused, for future vreg metadata).
    allocator: Allocator,

    const Self = @This();

    /// Create a new VRegAllocator.
    pub fn init(allocator: Allocator) Self {
        return .{
            .next_vreg = [_]u32{0} ** RegClass.count,
            .allocator = allocator,
        };
    }

    pub fn deinit(_: *Self) void {
        // No cleanup needed currently.
    }

    /// Allocate a fresh virtual register for the given register class.
    pub fn alloc(self: *Self, reg_class: RegClass) !VReg {
        const class_idx = reg_class.index();
        const idx = self.next_vreg[class_idx];

        // Check for overflow (VReg uses u32 index).
        if (idx == std.math.maxInt(u32)) {
            return error.TooManyVRegs;
        }

        self.next_vreg[class_idx] = idx + 1;
        return VReg.new(idx, reg_class);
    }

    /// Allocate a temporary virtual register.
    /// Alias for alloc() - provided for API compatibility.
    pub fn allocTemp(self: *Self, reg_class: RegClass) !VReg {
        return try self.alloc(reg_class);
    }

    /// Get the count of allocated vregs for a register class.
    pub fn count(self: *const Self, reg_class: RegClass) u32 {
        return self.next_vreg[reg_class.index()];
    }

    /// Get total count of all allocated vregs across all classes.
    pub fn totalCount(self: *const Self) usize {
        var total: usize = 0;
        for (self.next_vreg) |n| {
            total += n;
        }
        return total;
    }
};

test "VRegAllocator basic" {
    var allocator = VRegAllocator.init(testing.allocator);
    defer allocator.deinit();

    // Allocate int registers.
    const v0 = try allocator.alloc(.int);
    const v1 = try allocator.alloc(.int);
    const v2 = try allocator.alloc(.int);

    try testing.expectEqual(@as(u32, 0), v0.index());
    try testing.expectEqual(@as(u32, 1), v1.index());
    try testing.expectEqual(@as(u32, 2), v2.index());

    try testing.expectEqual(RegClass.int, v0.class());
    try testing.expectEqual(RegClass.int, v1.class());
    try testing.expectEqual(RegClass.int, v2.class());

    try testing.expectEqual(@as(u32, 3), allocator.count(.int));
}

test "VRegAllocator multiple classes" {
    var allocator = VRegAllocator.init(testing.allocator);
    defer allocator.deinit();

    // Allocate from different classes.
    const int0 = try allocator.alloc(.int);
    const flt0 = try allocator.alloc(.float);
    const int1 = try allocator.alloc(.int);
    const flt1 = try allocator.alloc(.float);
    const vec0 = try allocator.alloc(.vector);

    // Int registers.
    try testing.expectEqual(@as(u32, 0), int0.index());
    try testing.expectEqual(@as(u32, 1), int1.index());
    try testing.expectEqual(RegClass.int, int0.class());

    // Float registers.
    try testing.expectEqual(@as(u32, 0), flt0.index());
    try testing.expectEqual(@as(u32, 1), flt1.index());
    try testing.expectEqual(RegClass.float, flt0.class());

    // Vector registers.
    try testing.expectEqual(@as(u32, 0), vec0.index());
    try testing.expectEqual(RegClass.vector, vec0.class());

    // Counts per class.
    try testing.expectEqual(@as(u32, 2), allocator.count(.int));
    try testing.expectEqual(@as(u32, 2), allocator.count(.float));
    try testing.expectEqual(@as(u32, 1), allocator.count(.vector));

    // Total count.
    try testing.expectEqual(@as(usize, 5), allocator.totalCount());
}

test "VRegAllocator temp allocation" {
    var allocator = VRegAllocator.init(testing.allocator);
    defer allocator.deinit();

    const t0 = try allocator.allocTemp(.int);
    const t1 = try allocator.allocTemp(.int);

    try testing.expectEqual(@as(u32, 0), t0.index());
    try testing.expectEqual(@as(u32, 1), t1.index());
}
