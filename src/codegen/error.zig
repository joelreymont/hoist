const std = @import("std");

/// Source location information for error reporting
pub const SourceLocation = struct {
    file: []const u8,
    line: u32,
    column: u32,

    pub fn format(
        self: SourceLocation,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}:{}:{}", .{ self.file, self.line, self.column });
    }
};

/// Compilation error type
pub const CodegenError = union(enum) {
    /// IR verification failed
    verifier: VerifierError,
    /// Register allocation failed
    regalloc: []const u8,
    /// Implementation limit exceeded
    impl_limit: []const u8,
    /// Code size too large
    code_too_large: usize,
    /// Unsupported feature
    unsupported: []const u8,
    /// Invalid IR
    invalid_ir: []const u8,
    /// Type mismatch
    type_mismatch: TypeMismatch,
    /// Undefined value
    undefined_value: []const u8,
    /// Invalid block reference
    invalid_block: []const u8,
    /// Invalid instruction
    invalid_instruction: []const u8,

    pub fn format(
        self: CodegenError,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .verifier => |e| try e.format("", .{}, writer),
            .regalloc => |msg| try writer.print("Register allocation error: {s}", .{msg}),
            .impl_limit => |msg| try writer.print("Implementation limit exceeded: {s}", .{msg}),
            .code_too_large => |size| try writer.print("Code too large: {} bytes", .{size}),
            .unsupported => |msg| try writer.print("Unsupported feature: {s}", .{msg}),
            .invalid_ir => |msg| try writer.print("Invalid IR: {s}", .{msg}),
            .type_mismatch => |e| try e.format("", .{}, writer),
            .undefined_value => |msg| try writer.print("Undefined value: {s}", .{msg}),
            .invalid_block => |msg| try writer.print("Invalid block: {s}", .{msg}),
            .invalid_instruction => |msg| try writer.print("Invalid instruction: {s}", .{msg}),
        }
    }
};

/// Verifier error with location tracking
pub const VerifierError = struct {
    location: SourceLocation,
    message: []const u8,
    context: ?[]const u8,

    pub fn format(
        self: VerifierError,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try self.location.format("", .{}, writer);
        if (self.context) |ctx| {
            try writer.print(" ({s})", .{ctx});
        }
        try writer.print(": {s}", .{self.message});
    }
};

/// Type mismatch error
pub const TypeMismatch = struct {
    location: SourceLocation,
    expected: []const u8,
    found: []const u8,

    pub fn format(
        self: TypeMismatch,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try self.location.format("", .{}, writer);
        try writer.print(": expected {s}, found {s}", .{ self.expected, self.found });
    }
};

/// Result type for codegen operations
pub fn CodegenResult(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: CodegenError,

        pub fn isOk(self: @This()) bool {
            return self == .ok;
        }

        pub fn isErr(self: @This()) bool {
            return self == .err;
        }

        pub fn unwrap(self: @This()) T {
            return switch (self) {
                .ok => |v| v,
                .err => @panic("unwrap on error value"),
            };
        }

        pub fn unwrapErr(self: @This()) CodegenError {
            return switch (self) {
                .ok => @panic("unwrapErr on ok value"),
                .err => |e| e,
            };
        }
    };
}

test "SourceLocation formatting" {
    const loc = SourceLocation{
        .file = "test.isle",
        .line = 42,
        .column = 10,
    };

    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try loc.format("", .{}, fbs.writer());
    const result = fbs.getWritten();
    try std.testing.expectEqualStrings("test.isle:42:10", result);
}

test "VerifierError formatting" {
    const err = VerifierError{
        .location = .{ .file = "test.isle", .line = 10, .column = 5 },
        .message = "invalid operand",
        .context = "add instruction",
    };

    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try err.format("", .{}, fbs.writer());
    const result = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, result, "test.isle:10:5") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "add instruction") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "invalid operand") != null);
}

test "TypeMismatch formatting" {
    const err = TypeMismatch{
        .location = .{ .file = "test.isle", .line = 20, .column = 15 },
        .expected = "i32",
        .found = "i64",
    };

    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try err.format("", .{}, fbs.writer());
    const result = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, result, "test.isle:20:15") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "expected i32") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "found i64") != null);
}

test "CodegenError variants" {
    const verifier_err = CodegenError{
        .verifier = .{
            .location = .{ .file = "test.isle", .line = 1, .column = 1 },
            .message = "test error",
            .context = null,
        },
    };

    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try verifier_err.format("", .{}, fbs.writer());
    const result = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, result, "test.isle:1:1") != null);

    const unsupported_err = CodegenError{ .unsupported = "vector operations" };
    fbs.reset();
    try unsupported_err.format("", .{}, fbs.writer());
    const result2 = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, result2, "Unsupported feature") != null);
}

test "CodegenResult basic operations" {
    const ok_result = CodegenResult(u32){ .ok = 42 };
    try std.testing.expect(ok_result.isOk());
    try std.testing.expect(!ok_result.isErr());
    try std.testing.expectEqual(@as(u32, 42), ok_result.unwrap());

    const err_result = CodegenResult(u32){ .err = .{ .unsupported = "test" } };
    try std.testing.expect(!err_result.isOk());
    try std.testing.expect(err_result.isErr());
}
