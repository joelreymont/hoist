//! Trivial register allocator for bootstrapping.
//!
//! This is a minimal allocator that assigns registers in linear order
//! without spilling. Used to get end-to-end compilation working before
//! porting regalloc2.
//!
//! Algorithm:
//! - For each instruction in program order:
//!   - For each def operand: allocate next free register
//!   - For each use operand: assert register was allocated
//!
//! Limitations:
//! - No spilling - errors if out of registers
//! - No register reuse - once allocated, never freed
//! - No move coalescing
//! - No allocation across basic blocks
//!
//! These limitations are acceptable for MVP. Once the pipeline works,
//! we'll port regalloc2 for production-quality allocation.

const std = @import("std");
const reg_mod = @import("../machinst/reg.zig");

pub const VReg = reg_mod.VReg;
pub const PReg = reg_mod.PReg;
pub const RegClass = reg_mod.RegClass;

/// Trivial linear-scan register allocator.
pub const TrivialAllocator = struct {
    /// Mapping from virtual register to physical register.
    vreg_to_preg: std.AutoHashMap(VReg, PReg),

    /// Next free integer register (x0-x29 on AArch64).
    next_free_int: u8,

    /// Next free float register (v0-v31 on AArch64).
    next_free_float: u8,

    /// Allocator.
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .vreg_to_preg = std.AutoHashMap(VReg, PReg).init(allocator),
            .next_free_int = 0,
            .next_free_float = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.vreg_to_preg.deinit();
    }

    /// Allocate a physical register for a virtual register.
    /// Returns error if out of registers.
    pub fn allocate(self: *Self, vreg: VReg) !PReg {
        // Check if already allocated
        if (self.vreg_to_preg.get(vreg)) |preg| {
            return preg;
        }

        // Allocate new register based on class
        const preg = switch (vreg.class()) {
            .int => blk: {
                if (self.next_free_int >= 30) {
                    return error.OutOfIntegerRegisters;
                }
                const preg = PReg.new(.int, @intCast(self.next_free_int));
                self.next_free_int += 1;
                break :blk preg;
            },
            .float => blk: {
                if (self.next_free_float >= 32) {
                    return error.OutOfFloatRegisters;
                }
                const preg = PReg.new(.float, @intCast(self.next_free_float));
                self.next_free_float += 1;
                break :blk preg;
            },
            .vector => blk: {
                // Vector registers alias with float registers on AArch64
                if (self.next_free_float >= 32) {
                    return error.OutOfVectorRegisters;
                }
                const preg = PReg.new(.vector, @intCast(self.next_free_float));
                self.next_free_float += 1;
                break :blk preg;
            },
        };

        // Store mapping
        try self.vreg_to_preg.put(vreg, preg);
        return preg;
    }

    /// Get the physical register allocation for a virtual register.
    /// Returns null if not yet allocated.
    pub fn getAllocation(self: *const Self, vreg: VReg) ?PReg {
        return self.vreg_to_preg.get(vreg);
    }
};

test "TrivialAllocator basic allocation" {
    const testing = std.testing;

    var allocator = TrivialAllocator.init(testing.allocator);
    defer allocator.deinit();

    // Allocate integer registers
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);

    const p0 = try allocator.allocate(v0);
    const p1 = try allocator.allocate(v1);

    // Should get x0 and x1
    try testing.expectEqual(RegClass.int, p0.class());
    try testing.expectEqual(RegClass.int, p1.class());
    try testing.expectEqual(@as(u6, 0), p0.hwEnc());
    try testing.expectEqual(@as(u6, 1), p1.hwEnc());

    // Allocating same vreg again should return same preg
    const p0_again = try allocator.allocate(v0);
    try testing.expectEqual(p0.hwEnc(), p0_again.hwEnc());
}

test "TrivialAllocator getAllocation" {
    const testing = std.testing;

    var allocator = TrivialAllocator.init(testing.allocator);
    defer allocator.deinit();

    const v0 = VReg.new(0, .int);

    // Before allocation, should return null
    try testing.expectEqual(@as(?PReg, null), allocator.getAllocation(v0));

    // After allocation, should return preg
    const p0 = try allocator.allocate(v0);
    try testing.expectEqual(p0.hwEnc(), allocator.getAllocation(v0).?.hwEnc());
}
