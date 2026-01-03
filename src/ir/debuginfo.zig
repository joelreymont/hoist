const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const sourceloc = @import("sourceloc.zig");
const SourceLoc = sourceloc.SourceLoc;

/// Debug info for a variable.
pub const DebugVariable = struct {
    /// Variable name.
    name: []const u8,
    /// Type name.
    type_name: []const u8,
    /// Source location where declared.
    loc: SourceLoc,
    /// Scope depth (0 = global, 1+ = nested scopes).
    scope_depth: u32,

    pub fn init(name: []const u8, type_name: []const u8, loc: SourceLoc, scope_depth: u32) DebugVariable {
        return .{
            .name = name,
            .type_name = type_name,
            .loc = loc,
            .scope_depth = scope_depth,
        };
    }
};

/// Debug info for a function.
pub const DebugFunction = struct {
    /// Function name.
    name: []const u8,
    /// Source location where defined.
    loc: SourceLoc,
    /// Local variables.
    variables: std.ArrayList(DebugVariable),
    allocator: Allocator,

    pub fn init(allocator: Allocator, name: []const u8, loc: SourceLoc) DebugFunction {
        return .{
            .name = name,
            .loc = loc,
            .variables = std.ArrayList(DebugVariable){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DebugFunction) void {
        for (self.variables.items) |*var_info| {
            self.allocator.free(var_info.name);
            self.allocator.free(var_info.type_name);
        }
        self.variables.deinit();
    }

    pub fn addVariable(
        self: *DebugFunction,
        name: []const u8,
        type_name: []const u8,
        loc: SourceLoc,
        scope_depth: u32,
    ) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        const owned_type = try self.allocator.dupe(u8, type_name);
        errdefer self.allocator.free(owned_type);

        const var_info = DebugVariable.init(owned_name, owned_type, loc, scope_depth);
        try self.variables.append(var_info);
    }
};

/// Debug info collector for the entire compilation unit.
pub const DebugInfo = struct {
    /// Map from function ID to debug info.
    functions: std.AutoHashMap(u32, DebugFunction),
    allocator: Allocator,

    pub fn init(allocator: Allocator) DebugInfo {
        return .{
            .functions = std.AutoHashMap(u32, DebugFunction).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DebugInfo) void {
        var iter = self.functions.valueIterator();
        while (iter.next()) |func| {
            func.deinit();
        }
        self.functions.deinit();
    }

    pub fn addFunction(
        self: *DebugInfo,
        func_id: u32,
        name: []const u8,
        loc: SourceLoc,
    ) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        const func = DebugFunction.init(self.allocator, owned_name, loc);
        try self.functions.put(func_id, func);
    }

    pub fn getFunction(self: *DebugInfo, func_id: u32) ?*DebugFunction {
        return self.functions.getPtr(func_id);
    }
};

test "DebugVariable init" {
    const loc = SourceLoc.init("test.zig", 10, 5);
    const var_info = DebugVariable.init("x", "i32", loc, 1);

    try testing.expectEqualStrings("x", var_info.name);
    try testing.expectEqualStrings("i32", var_info.type_name);
    try testing.expectEqual(@as(u32, 1), var_info.scope_depth);
}

test "DebugFunction addVariable" {
    const loc = SourceLoc.init("test.zig", 5, 1);
    var func = DebugFunction.init(testing.allocator, "main", loc);
    defer func.deinit();

    const var_loc = SourceLoc.init("test.zig", 6, 5);
    try func.addVariable("count", "u32", var_loc, 1);

    try testing.expectEqual(@as(usize, 1), func.variables.items.len);
    try testing.expectEqualStrings("count", func.variables.items[0].name);
    try testing.expectEqualStrings("u32", func.variables.items[0].type_name);
}

test "DebugInfo addFunction and get" {
    var debug_info = DebugInfo.init(testing.allocator);
    defer debug_info.deinit();

    const loc = SourceLoc.init("main.zig", 1, 1);
    try debug_info.addFunction(0, "main", loc);

    const func = debug_info.getFunction(0).?;
    try testing.expectEqualStrings("main", func.name);
    try testing.expectEqual(@as(u32, 1), func.loc.line);
}

test "DebugInfo with variables" {
    var debug_info = DebugInfo.init(testing.allocator);
    defer debug_info.deinit();

    const func_loc = SourceLoc.init("main.zig", 1, 1);
    try debug_info.addFunction(0, "test_func", func_loc);

    const func = debug_info.getFunction(0).?;
    const var_loc = SourceLoc.init("main.zig", 2, 5);
    try func.addVariable("result", "i64", var_loc, 1);

    try testing.expectEqual(@as(usize, 1), func.variables.items.len);
    try testing.expectEqualStrings("result", func.variables.items[0].name);
}
