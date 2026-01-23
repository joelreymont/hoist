const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const types = @import("../ir/types.zig");
const sig_mod = @import("../ir/signature.zig");

pub const data = @import("data.zig");
pub const DataDesc = data.DataDesc;

/// Function or data identifier in module.
pub const FuncOrDataId = union(enum) {
    func: FuncId,
    data: DataId,
};

/// Function identifier.
pub const FuncId = packed struct(u32) {
    idx: u32,

    pub fn from(i: u32) FuncId {
        return .{ .idx = i };
    }
};

/// Data identifier.
pub const DataId = packed struct(u32) {
    idx: u32,

    pub fn from(i: u32) DataId {
        return .{ .idx = i };
    }
};

/// Linkage type.
pub const Linkage = enum {
    /// Exported from this module.
    @"export",
    /// Local to this module.
    local,
    /// Import from another module.
    import,
};

/// Module declarations.
pub const ModuleDeclarations = struct {
    names: std.StringHashMap(FuncOrDataId),
    allocator: Allocator,

    pub fn init(allocator: Allocator) ModuleDeclarations {
        return .{
            .names = std.StringHashMap(FuncOrDataId).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ModuleDeclarations) void {
        var it = self.names.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.names.deinit();
    }

    pub fn getName(self: *const ModuleDeclarations, name: []const u8) ?FuncOrDataId {
        return self.names.get(name);
    }
};

/// Module trait interface.
pub fn Module(comptime Impl: type) type {
    return struct {
        const Self = @This();

        impl: *Impl,

        /// Declare a function.
        pub fn declareFunction(
            self: *Self,
            name: []const u8,
            linkage: Linkage,
            signature: sig_mod.Signature,
        ) !FuncId {
            return self.impl.declareFunction(name, linkage, signature);
        }

        /// Declare data.
        pub fn declareData(
            self: *Self,
            name: []const u8,
            linkage: Linkage,
            writable: bool,
            tls: bool,
        ) !DataId {
            return self.impl.declareData(name, linkage, writable, tls);
        }

        /// Define a function.
        pub fn defineFunction(
            self: *Self,
            func: FuncId,
            ctx: anytype,
        ) !void {
            return self.impl.defineFunction(func, ctx);
        }

        /// Define data.
        pub fn defineData(
            self: *Self,
            id: DataId,
            desc: *const DataDesc,
        ) !void {
            return self.impl.defineData(id, desc);
        }

        /// Finalize the module.
        pub fn finalize(self: *Self) !void {
            return self.impl.finalize();
        }

        /// Get declarations.
        pub fn declarations(self: *const Self) *const ModuleDeclarations {
            return self.impl.declarations();
        }
    };
}
