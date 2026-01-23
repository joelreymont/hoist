const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const types = @import("types.zig");

const Type = types.Type;

/// Calling convention.
pub const CallConv = enum(u8) {
    /// Best performance, not ABI-stable
    fast,
    /// Supports tail calls
    tail,
    /// System V-style convention
    system_v,
    /// Windows fastcall
    windows_fastcall,
    /// Mac aarch64 calling convention
    apple_aarch64,
    /// Probestack function
    probestack,
    /// Winch calling convention
    winch,
    /// Preserve all registers
    preserve_all,

    pub fn supportsTailCalls(self: CallConv) bool {
        return self == .tail;
    }

    pub fn supportsExceptions(self: CallConv) bool {
        return switch (self) {
            .tail, .system_v, .winch, .preserve_all => true,
            else => false,
        };
    }

    pub fn format(self: CallConv, writer: anytype) !void {
        const s = switch (self) {
            .fast => "fast",
            .tail => "tail",
            .system_v => "system_v",
            .windows_fastcall => "windows_fastcall",
            .apple_aarch64 => "apple_aarch64",
            .probestack => "probestack",
            .winch => "winch",
            .preserve_all => "preserve_all",
        };
        try writer.writeAll(s);
    }
};

/// Argument extension.
pub const ArgumentExtension = enum(u8) {
    none,
    /// Unsigned extension
    uext,
    /// Signed extension
    sext,

    pub fn format(self: ArgumentExtension, writer: anytype) !void {
        const s = switch (self) {
            .none => "",
            .uext => " uext",
            .sext => " sext",
        };
        try writer.writeAll(s);
    }
};

/// Argument purpose.
pub const ArgumentPurpose = union(enum) {
    normal,
    struct_argument: u32,
    struct_return,
    vm_context,

    pub fn format(self: ArgumentPurpose, writer: anytype) !void {
        switch (self) {
            .normal => {},
            .struct_argument => |size| try writer.print(" sarg({d})", .{size}),
            .struct_return => try writer.writeAll(" sret"),
            .vm_context => try writer.writeAll(" vmctx"),
        }
    }
};

/// Function parameter or return value.
pub const AbiParam = struct {
    value_type: Type,
    purpose: ArgumentPurpose = .normal,
    extension: ArgumentExtension = .none,

    pub fn new(vt: Type) AbiParam {
        return .{ .value_type = vt };
    }

    pub fn special(vt: Type, purpose: ArgumentPurpose) AbiParam {
        return .{ .value_type = vt, .purpose = purpose };
    }

    pub fn uext(self: AbiParam) AbiParam {
        return .{ .value_type = self.value_type, .purpose = self.purpose, .extension = .uext };
    }

    pub fn sext(self: AbiParam) AbiParam {
        return .{ .value_type = self.value_type, .purpose = self.purpose, .extension = .sext };
    }

    pub fn format(self: AbiParam, writer: anytype) !void {
        try writer.print("{f}", .{self.value_type});
        try self.extension.format(writer);
        try self.purpose.format(writer);
    }
};

/// Function signature.
pub const Signature = struct {
    params: std.ArrayList(AbiParam),
    returns: std.ArrayList(AbiParam),
    call_conv: CallConv,
    is_varargs: bool,
    allocator: Allocator,

    pub fn init(allocator: Allocator, call_conv: CallConv) Signature {
        return .{
            .params = .{},
            .returns = .{},
            .call_conv = call_conv,
            .is_varargs = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Signature) void {
        self.params.deinit(self.allocator);
        self.returns.deinit(self.allocator);
    }

    pub fn clear(self: *Signature, call_conv: CallConv) void {
        self.params.clearRetainingCapacity();
        self.returns.clearRetainingCapacity();
        self.call_conv = call_conv;
        self.is_varargs = false;
    }

    pub fn specialParamIndex(self: *const Signature, purpose: ArgumentPurpose) ?usize {
        var i = self.params.items.len;
        while (i > 0) {
            i -= 1;
            if (std.meta.eql(self.params.items[i].purpose, purpose)) {
                return i;
            }
        }
        return null;
    }

    pub fn specialReturnIndex(self: *const Signature, purpose: ArgumentPurpose) ?usize {
        var i = self.returns.items.len;
        while (i > 0) {
            i -= 1;
            if (std.meta.eql(self.returns.items[i].purpose, purpose)) {
                return i;
            }
        }
        return null;
    }

    pub fn usesSpecialParam(self: *const Signature, purpose: ArgumentPurpose) bool {
        return self.specialParamIndex(purpose) != null;
    }

    pub fn usesSpecialReturn(self: *const Signature, purpose: ArgumentPurpose) bool {
        return self.specialReturnIndex(purpose) != null;
    }

    pub fn numSpecialParams(self: *const Signature) usize {
        var count: usize = 0;
        for (self.params.items) |p| {
            if (!std.meta.eql(p.purpose, ArgumentPurpose.normal)) {
                count += 1;
            }
        }
        return count;
    }

    pub fn numSpecialReturns(self: *const Signature) usize {
        var count: usize = 0;
        for (self.returns.items) |r| {
            if (!std.meta.eql(r.purpose, ArgumentPurpose.normal)) {
                count += 1;
            }
        }
        return count;
    }

    pub fn usesStructReturnParam(self: *const Signature) bool {
        return self.usesSpecialParam(.struct_return);
    }

    pub fn isMultiReturn(self: *const Signature) bool {
        var count: usize = 0;
        for (self.returns.items) |r| {
            if (std.meta.eql(r.purpose, ArgumentPurpose.normal)) {
                count += 1;
            }
        }
        return count > 1;
    }

    pub fn format(self: Signature, writer: anytype) !void {
        try writer.writeAll("(");
        for (self.params.items, 0..) |param, i| {
            if (i > 0) try writer.writeAll(", ");
            try param.format(writer);
        }
        try writer.writeAll(")");
        if (self.returns.items.len > 0) {
            try writer.writeAll(" -> ");
            for (self.returns.items, 0..) |ret, i| {
                if (i > 0) try writer.writeAll(", ");
                try ret.format(writer);
            }
        }
        try writer.writeAll(" ");
        try self.call_conv.format(writer);
    }
};

test "CallConv" {
    try testing.expect(CallConv.tail.supportsTailCalls());
    try testing.expect(!CallConv.fast.supportsTailCalls());
    try testing.expect(CallConv.system_v.supportsExceptions());
}

test "AbiParam" {
    const param = AbiParam.new(Type.I32);
    try testing.expectEqual(Type.I32, param.value_type);
    try testing.expectEqual(ArgumentExtension.none, param.extension);

    const uext_param = param.uext();
    try testing.expectEqual(ArgumentExtension.uext, uext_param.extension);
}

test "Signature basic" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    try testing.expectEqual(2, sig.params.items.len);
    try testing.expectEqual(1, sig.returns.items.len);
    try testing.expect(!sig.isMultiReturn());
}

test "Signature special params" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.params.append(testing.allocator, AbiParam.special(Type.I64, .vm_context));

    try testing.expect(sig.usesSpecialParam(.vm_context));
    try testing.expect(!sig.usesSpecialParam(.struct_return));
    try testing.expectEqual(1, sig.numSpecialParams());
}

test "Signature multi-return" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    try testing.expect(sig.isMultiReturn());
}
