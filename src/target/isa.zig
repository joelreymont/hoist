const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Register class for virtual registers.
pub const RegClass = enum {
    int,
    float,
    vector,
};

/// Target-specific ISA descriptor.
/// Each backend implements this interface to provide ISA-specific information.
pub const TargetISA = struct {
    /// ISA name (e.g., "aarch64", "x86_64").
    name: []const u8,

    /// Pointer size in bytes.
    pointer_size: u8,

    /// Stack alignment in bytes.
    stack_alignment: u8,

    /// Number of physical general-purpose registers.
    num_gpr: u8,

    /// Number of physical floating-point registers.
    num_fpr: u8,

    /// Number of physical vector registers.
    num_vec: u8,

    /// Register classes this ISA supports.
    reg_classes: []const RegClass,

    /// VTable for ISA-specific operations.
    vtable: *const VTable,

    pub const VTable = struct {
        /// Get register name for display.
        getRegName: *const fn (reg_class: RegClass, index: u8) []const u8,

        /// Check if register is caller-saved.
        isCallerSaved: *const fn (reg_class: RegClass, index: u8) bool,

        /// Check if register is callee-saved.
        isCalleeSaved: *const fn (reg_class: RegClass, index: u8) bool,

        /// Get maximum immediate value for operations.
        getMaxImmediate: *const fn () i64,
    };

    pub fn getRegName(self: *const TargetISA, reg_class: RegClass, index: u8) []const u8 {
        return self.vtable.getRegName(reg_class, index);
    }

    pub fn isCallerSaved(self: *const TargetISA, reg_class: RegClass, index: u8) bool {
        return self.vtable.isCallerSaved(reg_class, index);
    }

    pub fn isCalleeSaved(self: *const TargetISA, reg_class: RegClass, index: u8) bool {
        return self.vtable.isCalleeSaved(reg_class, index);
    }

    pub fn getMaxImmediate(self: *const TargetISA) i64 {
        return self.vtable.getMaxImmediate();
    }
};

// Example ISA implementation for testing
const TestISA = struct {
    fn getRegName(reg_class: RegClass, index: u8) []const u8 {
        _ = reg_class;
        return switch (index) {
            0 => "r0",
            1 => "r1",
            else => "rN",
        };
    }

    fn isCallerSaved(reg_class: RegClass, index: u8) bool {
        _ = reg_class;
        return index < 4; // r0-r3 are caller-saved
    }

    fn isCalleeSaved(reg_class: RegClass, index: u8) bool {
        _ = reg_class;
        return index >= 4; // r4+ are callee-saved
    }

    fn getMaxImmediate() i64 {
        return 0xFFFF;
    }

    const vtable = TargetISA.VTable{
        .getRegName = getRegName,
        .isCallerSaved = isCallerSaved,
        .isCalleeSaved = isCalleeSaved,
        .getMaxImmediate = getMaxImmediate,
    };

    const reg_classes = [_]RegClass{ .int, .float };

    pub fn descriptor() TargetISA {
        return .{
            .name = "test",
            .pointer_size = 8,
            .stack_alignment = 16,
            .num_gpr = 16,
            .num_fpr = 16,
            .num_vec = 0,
            .reg_classes = &reg_classes,
            .vtable = &vtable,
        };
    }
};

test "TargetISA basic" {
    const isa = TestISA.descriptor();

    try testing.expectEqualStrings("test", isa.name);
    try testing.expectEqual(@as(u8, 8), isa.pointer_size);
    try testing.expectEqual(@as(u8, 16), isa.stack_alignment);
    try testing.expectEqual(@as(u8, 16), isa.num_gpr);
}

test "TargetISA getRegName" {
    const isa = TestISA.descriptor();

    const name = isa.getRegName(.int, 0);
    try testing.expectEqualStrings("r0", name);
}

test "TargetISA caller/callee saved" {
    const isa = TestISA.descriptor();

    try testing.expect(isa.isCallerSaved(.int, 0));
    try testing.expect(isa.isCallerSaved(.int, 3));
    try testing.expect(!isa.isCallerSaved(.int, 4));

    try testing.expect(!isa.isCalleeSaved(.int, 0));
    try testing.expect(isa.isCalleeSaved(.int, 4));
}

test "TargetISA getMaxImmediate" {
    const isa = TestISA.descriptor();

    try testing.expectEqual(@as(i64, 0xFFFF), isa.getMaxImmediate());
}
