const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const entities = @import("entities.zig");
const signature = @import("signature.zig");

const SigRef = entities.SigRef;

/// External name - reference to symbol outside current function.
pub const ExternalName = union(enum) {
    /// User-defined symbol (namespace:index)
    user: UserExternalName,
    /// Test case name
    testcase: []const u8,

    pub fn fromUser(namespace: u32, index: u32) ExternalName {
        return .{ .user = UserExternalName.init(namespace, index) };
    }

    pub fn fromTestcase(allocator: Allocator, name: []const u8) !ExternalName {
        const owned = try allocator.dupe(u8, name);
        return .{ .testcase = owned };
    }

    pub fn deinit(self: *ExternalName, allocator: Allocator) void {
        switch (self.*) {
            .testcase => |name| allocator.free(name),
            .user => {},
        }
    }

    pub fn format(self: ExternalName, writer: anytype) !void {
        switch (self) {
            .user => |u| try writer.print("u{d}:{d}", .{ u.namespace, u.index }),
            .testcase => |name| try writer.print("%{s}", .{name}),
        }
    }
};

/// User-defined external name.
pub const UserExternalName = struct {
    namespace: u32,
    index: u32,

    pub fn init(namespace: u32, index: u32) UserExternalName {
        return .{ .namespace = namespace, .index = index };
    }

    pub fn format(self: UserExternalName, writer: anytype) !void {
        try writer.print("u{d}:{d}", .{ self.namespace, self.index });
    }
};

/// External function data.
pub const ExtFuncData = struct {
    name: ExternalName,
    signature: SigRef,
    colocated: bool = false,

    pub fn init(name: ExternalName, sig: SigRef) ExtFuncData {
        return .{ .name = name, .signature = sig };
    }

    pub fn deinit(self: *ExtFuncData, allocator: Allocator) void {
        self.name.deinit(allocator);
    }

    pub fn format(self: ExtFuncData, writer: anytype) !void {
        if (self.colocated) {
            try writer.writeAll("colocated ");
        }
        try self.name.format(writer);
        try writer.print(" {}", .{self.signature});
    }
};

test "UserExternalName" {
    const name = UserExternalName.init(0, 42);
    try testing.expectEqual(0, name.namespace);
    try testing.expectEqual(42, name.index);
}

test "ExternalName user" {
    const name = ExternalName.fromUser(0, 42);
    try testing.expectEqual(0, name.user.namespace);
    try testing.expectEqual(42, name.user.index);
}

test "ExternalName testcase" {
    var name = try ExternalName.fromTestcase(testing.allocator, "test_func");
    defer name.deinit(testing.allocator);

    try testing.expectEqualStrings("test_func", name.testcase);
}

test "ExtFuncData" {
    const name = ExternalName.fromUser(0, 1);
    const sig = SigRef.new(0);
    var data = ExtFuncData.init(name, sig);
    defer data.deinit(testing.allocator);

    try testing.expectEqual(sig, data.signature);
    try testing.expect(!data.colocated);
}
