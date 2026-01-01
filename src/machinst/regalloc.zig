const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const reg_mod = @import("reg.zig");
const vcode_mod = @import("vcode.zig");

pub const Reg = reg_mod.Reg;
pub const PReg = reg_mod.PReg;
pub const VReg = reg_mod.VReg;
pub const RegClass = reg_mod.RegClass;

/// Simple linear scan register allocator.
/// This is a minimal allocator for bootstrapping - will be replaced with
/// regalloc2 (FFI or port) once backend is working.
pub const LinearScanAllocator = struct {
    /// Available physical registers by class.
    available_int: std.ArrayList(PReg),
    available_float: std.ArrayList(PReg),
    available_vector: std.ArrayList(PReg),

    /// VReg -> PReg allocation map.
    allocations: std.AutoHashMap(VReg, PReg),

    /// Next spill slot index.
    next_spill_slot: u32,

    /// Allocator.
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .available_int = std.ArrayList(PReg){},
            .available_float = std.ArrayList(PReg){},
            .available_vector = std.ArrayList(PReg){},
            .allocations = std.AutoHashMap(VReg, PReg).init(allocator),
            .next_spill_slot = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.available_int.deinit(self.allocator);
        self.available_float.deinit(self.allocator);
        self.available_vector.deinit(self.allocator);
        self.allocations.deinit();
    }

    /// Initialize with available physical registers for a platform.
    pub fn initRegs(
        self: *Self,
        int_regs: []const PReg,
        float_regs: []const PReg,
        vector_regs: []const PReg,
    ) !void {
        try self.available_int.appendSlice(self.allocator, int_regs);
        try self.available_float.appendSlice(self.allocator, float_regs);
        try self.available_vector.appendSlice(self.allocator, vector_regs);
    }

    /// Allocate a physical register for a virtual register.
    pub fn allocate(self: *Self, vreg: VReg) !PReg {
        // Check if already allocated
        if (self.allocations.get(vreg)) |preg| {
            return preg;
        }

        // Get available list for this register class
        const list = switch (vreg.class()) {
            .int => &self.available_int,
            .float => &self.available_float,
            .vector => &self.available_vector,
        };

        // Try to allocate from available pool
        if (list.pop()) |preg| {
            try self.allocations.put(vreg, preg);
            return preg;
        }

        // No registers available - would need to spill
        // For now, return error
        return error.OutOfRegisters;
    }

    /// Free a physical register (return to available pool).
    pub fn free(self: *Self, vreg: VReg) !void {
        if (self.allocations.fetchRemove(vreg)) |entry| {
            const preg = entry.value;
            const list = switch (preg.class()) {
                .int => &self.available_int,
                .float => &self.available_float,
                .vector => &self.available_vector,
            };
            try list.append(self.allocator, preg);
        }
    }

    /// Get allocation for a vreg, if it exists.
    pub fn getAllocation(self: *const Self, vreg: VReg) ?PReg {
        return self.allocations.get(vreg);
    }
};

/// Allocation result - maps vregs to physical locations.
pub const Allocation = struct {
    /// VReg -> PReg mapping.
    regs: std.AutoHashMap(VReg, PReg),
    /// VReg -> SpillSlot mapping for spilled values.
    spills: std.AutoHashMap(VReg, reg_mod.SpillSlot),
    /// Allocator.
    allocator: Allocator,

    pub fn init(allocator: Allocator) Allocation {
        return .{
            .regs = std.AutoHashMap(VReg, PReg).init(allocator),
            .spills = std.AutoHashMap(VReg, reg_mod.SpillSlot).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Allocation) void {
        self.regs.deinit();
        self.spills.deinit();
    }

    /// Get the physical register for a vreg, if allocated to a register.
    pub fn getReg(self: *const Allocation, vreg: VReg) ?PReg {
        return self.regs.get(vreg);
    }

    /// Get the spill slot for a vreg, if spilled.
    pub fn getSpill(self: *const Allocation, vreg: VReg) ?reg_mod.SpillSlot {
        return self.spills.get(vreg);
    }

    /// Add a register allocation.
    pub fn addReg(self: *Allocation, vreg: VReg, preg: PReg) !void {
        try self.regs.put(vreg, preg);
    }

    /// Add a spill allocation.
    pub fn addSpill(self: *Allocation, vreg: VReg, slot: reg_mod.SpillSlot) !void {
        try self.spills.put(vreg, slot);
    }
};

test "LinearScanAllocator basic" {
    var alloc = LinearScanAllocator.init(testing.allocator);
    defer alloc.deinit();

    // Set up available registers (x86-64 example)
    const int_regs = [_]PReg{
        PReg.new(.int, 0), // RAX
        PReg.new(.int, 1), // RCX
        PReg.new(.int, 2), // RDX
    };

    try alloc.initRegs(&int_regs, &.{}, &.{});

    // Allocate virtual registers
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);

    const p0 = try alloc.allocate(v0);
    const p1 = try alloc.allocate(v1);

    // Should get different physical registers
    try testing.expect(!std.meta.eql(p0, p1));

    // Same vreg should return same preg
    const p0_again = try alloc.allocate(v0);
    try testing.expectEqual(p0, p0_again);

    // Free and reallocate
    try alloc.free(v0);
    const v2 = VReg.new(2, .int);
    const p2 = try alloc.allocate(v2);

    // Should reuse freed register
    try testing.expectEqual(p0, p2);
}

test "Allocation" {
    var allocation = Allocation.init(testing.allocator);
    defer allocation.deinit();

    const v0 = VReg.new(0, .int);
    const p0 = PReg.new(.int, 0);

    try allocation.addReg(v0, p0);
    try testing.expectEqual(p0, allocation.getReg(v0).?);
    try testing.expect(allocation.getSpill(v0) == null);

    const v1 = VReg.new(1, .int);
    const s1 = reg_mod.SpillSlot.new(0);

    try allocation.addSpill(v1, s1);
    try testing.expectEqual(s1, allocation.getSpill(v1).?);
    try testing.expect(allocation.getReg(v1) == null);
}
