//! External name for function references.
//!
//! Represents the symbol name used for linking to external functions.

const std = @import("std");

/// External name for functions (symbol name).
pub const ExternalName = struct {
    name: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !ExternalName {
        const name_copy = try allocator.dupe(u8, name);
        return .{
            .name = name_copy,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: ExternalName, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }

    /// For testing: create an external name (alias for init).
    pub fn testable(allocator: std.mem.Allocator, name: []const u8) !ExternalName {
        return init(allocator, name);
    }
};
