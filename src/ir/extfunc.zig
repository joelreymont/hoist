const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const entities = @import("entities.zig");
const signature = @import("signature.zig");

const SigRef = entities.SigRef;

/// TLS access model for thread-local storage variables.
pub const TlsModel = enum {
    /// Local-Exec: TLS offset known at link time, executable only.
    /// Fastest model: MRS + ADD with immediate offset.
    local_exec,
    /// Initial-Exec: TLS offset loaded from GOT, shared library or executable.
    /// Fast model: ADRP + LDR (GOT) + MRS + ADD.
    initial_exec,
    /// General-Dynamic: Full dynamic TLS, works in all cases.
    /// Slowest model: ADRP + LDR (descriptor) + BLR (resolver).
    general_dynamic,

    pub fn format(self: TlsModel, writer: anytype) !void {
        try writer.writeAll(@tagName(self));
    }
};

/// External symbol linkage category.
pub const SymbolLinkage = enum {
    /// Regular global symbol (function or data).
    global,
    /// Thread-local storage symbol with specified access model.
    tls,

    pub fn format(self: SymbolLinkage, writer: anytype) !void {
        try writer.writeAll(@tagName(self));
    }
};

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

/// External global variable data.
pub const ExtGlobalData = struct {
    name: ExternalName,
    linkage: SymbolLinkage = .global,
    tls_model: ?TlsModel = null,
    colocated: bool = false,

    pub fn init(name: ExternalName) ExtGlobalData {
        return .{ .name = name };
    }

    pub fn initTls(name: ExternalName, model: TlsModel) ExtGlobalData {
        return .{
            .name = name,
            .linkage = .tls,
            .tls_model = model,
        };
    }

    pub fn deinit(self: *ExtGlobalData, allocator: Allocator) void {
        self.name.deinit(allocator);
    }

    pub fn isTls(self: ExtGlobalData) bool {
        return self.linkage == .tls;
    }

    pub fn format(self: ExtGlobalData, writer: anytype) !void {
        if (self.colocated) {
            try writer.writeAll("colocated ");
        }
        if (self.isTls()) {
            try writer.print("tls({}) ", .{self.tls_model.?});
        }
        try self.name.format(writer);
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

test "TlsModel" {
    const le = TlsModel.local_exec;
    const ie = TlsModel.initial_exec;
    const gd = TlsModel.general_dynamic;

    try testing.expect(le == .local_exec);
    try testing.expect(ie == .initial_exec);
    try testing.expect(gd == .general_dynamic);
}

test "SymbolLinkage" {
    const global = SymbolLinkage.global;
    const tls = SymbolLinkage.tls;

    try testing.expect(global == .global);
    try testing.expect(tls == .tls);
}

test "ExtGlobalData regular global" {
    const name = ExternalName.fromUser(0, 1);
    var data = ExtGlobalData.init(name);
    defer data.deinit(testing.allocator);

    try testing.expect(!data.isTls());
    try testing.expectEqual(SymbolLinkage.global, data.linkage);
    try testing.expectEqual(@as(?TlsModel, null), data.tls_model);
}

test "ExtGlobalData TLS local-exec" {
    const name = ExternalName.fromUser(0, 2);
    var data = ExtGlobalData.initTls(name, .local_exec);
    defer data.deinit(testing.allocator);

    try testing.expect(data.isTls());
    try testing.expectEqual(SymbolLinkage.tls, data.linkage);
    try testing.expectEqual(TlsModel.local_exec, data.tls_model.?);
}

test "ExtGlobalData TLS initial-exec" {
    const name = ExternalName.fromUser(0, 3);
    var data = ExtGlobalData.initTls(name, .initial_exec);
    defer data.deinit(testing.allocator);

    try testing.expect(data.isTls());
    try testing.expectEqual(TlsModel.initial_exec, data.tls_model.?);
}

test "ExtGlobalData TLS general-dynamic" {
    const name = ExternalName.fromUser(0, 4);
    var data = ExtGlobalData.initTls(name, .general_dynamic);
    defer data.deinit(testing.allocator);

    try testing.expect(data.isTls());
    try testing.expectEqual(TlsModel.general_dynamic, data.tls_model.?);
}
