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

/// Severity level for diagnostics
pub const Severity = enum {
    error_,
    warning,
    note,

    pub fn format(
        self: Severity,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const str = switch (self) {
            .error_ => "error",
            .warning => "warning",
            .note => "note",
        };
        try writer.writeAll(str);
    }
};

/// A single diagnostic message with location and severity
pub const Diagnostic = struct {
    severity: Severity,
    location: SourceLocation,
    message: []const u8,
    context: ?[]const u8 = null,
    source_line: ?[]const u8 = null,

    pub fn format(
        self: Diagnostic,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        // Write severity and location: "error: file.zig:10:5"
        try self.severity.format("", .{}, writer);
        try writer.writeAll(": ");
        try self.location.format("", .{}, writer);

        // Add context if present
        if (self.context) |ctx| {
            try writer.print(" ({s})", .{ctx});
        }

        // Write message
        try writer.print(": {s}\n", .{self.message});

        // Add source line with caret if available
        if (self.source_line) |line| {
            try writer.print("{s}\n", .{line});

            // Add caret indicator pointing to column
            const col = self.location.column;
            if (col > 0) {
                var i: u32 = 1;
                while (i < col) : (i += 1) {
                    try writer.writeByte(' ');
                }
                try writer.writeAll("^\n");
            }
        }
    }
};

/// Diagnostic emitter for collecting and formatting multiple errors
pub const DiagnosticEmitter = struct {
    allocator: std.mem.Allocator,
    diagnostics: std.ArrayList(Diagnostic),
    source_map: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) DiagnosticEmitter {
        return .{
            .allocator = allocator,
            .diagnostics = std.ArrayList(Diagnostic){},
            .source_map = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *DiagnosticEmitter) void {
        for (self.diagnostics.items) |diag| {
            self.allocator.free(diag.message);
            if (diag.context) |ctx| {
                self.allocator.free(ctx);
            }
            if (diag.source_line) |line| {
                self.allocator.free(line);
            }
        }
        self.diagnostics.deinit(self.allocator);

        var it = self.source_map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.source_map.deinit();
    }

    /// Register source file content for pretty error display
    pub fn registerSource(self: *DiagnosticEmitter, file: []const u8, source: []const u8) !void {
        const file_copy = try self.allocator.dupe(u8, file);
        errdefer self.allocator.free(file_copy);
        const source_copy = try self.allocator.dupe(u8, source);
        errdefer self.allocator.free(source_copy);

        try self.source_map.put(file_copy, source_copy);
    }

    /// Add a diagnostic message
    pub fn emit(
        self: *DiagnosticEmitter,
        severity: Severity,
        location: SourceLocation,
        message: []const u8,
        context: ?[]const u8,
    ) !void {
        const msg_copy = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(msg_copy);

        const ctx_copy = if (context) |c| try self.allocator.dupe(u8, c) else null;
        errdefer if (ctx_copy) |c| self.allocator.free(c);

        // Try to extract source line if we have the source
        const source_line = blk: {
            if (self.source_map.get(location.file)) |source| {
                if (self.extractLine(source, location.line)) |line| {
                    break :blk try self.allocator.dupe(u8, line);
                }
            }
            break :blk null;
        };

        try self.diagnostics.append(self.allocator, .{
            .severity = severity,
            .location = location,
            .message = msg_copy,
            .context = ctx_copy,
            .source_line = source_line,
        });
    }

    /// Emit an error diagnostic
    pub fn emitError(
        self: *DiagnosticEmitter,
        location: SourceLocation,
        message: []const u8,
        context: ?[]const u8,
    ) !void {
        try self.emit(.error_, location, message, context);
    }

    /// Emit a warning diagnostic
    pub fn emitWarning(
        self: *DiagnosticEmitter,
        location: SourceLocation,
        message: []const u8,
        context: ?[]const u8,
    ) !void {
        try self.emit(.warning, location, message, context);
    }

    /// Emit a note diagnostic
    pub fn emitNote(
        self: *DiagnosticEmitter,
        location: SourceLocation,
        message: []const u8,
        context: ?[]const u8,
    ) !void {
        try self.emit(.note, location, message, context);
    }

    /// Extract a specific line from source text
    fn extractLine(self: *DiagnosticEmitter, source: []const u8, line_num: u32) ?[]const u8 {
        _ = self;
        if (line_num == 0) return null;

        var line: u32 = 1;
        var start: usize = 0;

        for (source, 0..) |c, i| {
            if (line == line_num and c == '\n') {
                return source[start..i];
            }
            if (c == '\n') {
                line += 1;
                start = i + 1;
            }
        }

        // Handle last line without newline
        if (line == line_num) {
            return source[start..];
        }

        return null;
    }

    /// Check if any errors were emitted
    pub fn hasErrors(self: *const DiagnosticEmitter) bool {
        for (self.diagnostics.items) |diag| {
            if (diag.severity == .error_) return true;
        }
        return false;
    }

    /// Get count of errors
    pub fn errorCount(self: *const DiagnosticEmitter) usize {
        var count: usize = 0;
        for (self.diagnostics.items) |diag| {
            if (diag.severity == .error_) count += 1;
        }
        return count;
    }

    /// Get count of warnings
    pub fn warningCount(self: *const DiagnosticEmitter) usize {
        var count: usize = 0;
        for (self.diagnostics.items) |diag| {
            if (diag.severity == .warning) count += 1;
        }
        return count;
    }

    /// Format all diagnostics to writer
    pub fn formatAll(self: *const DiagnosticEmitter, writer: anytype) !void {
        for (self.diagnostics.items) |diag| {
            try diag.format("", .{}, writer);
        }

        // Summary line
        const errors = self.errorCount();
        const warnings = self.warningCount();

        if (errors > 0 or warnings > 0) {
            if (errors > 0 and warnings > 0) {
                try writer.print("{d} error(s), {d} warning(s)\n", .{ errors, warnings });
            } else if (errors > 0) {
                try writer.print("{d} error(s)\n", .{errors});
            } else {
                try writer.print("{d} warning(s)\n", .{warnings});
            }
        }
    }
};

test "Diagnostic formatting" {
    const diag = Diagnostic{
        .severity = .error_,
        .location = .{ .file = "test.isle", .line = 10, .column = 5 },
        .message = "invalid operand",
        .context = "add instruction",
        .source_line = "    x = add(a, b)",
    };

    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try diag.format("", .{}, fbs.writer());
    const result = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, result, "error:") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "test.isle:10:5") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "add instruction") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "invalid operand") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "x = add(a, b)") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "^") != null);
}

test "DiagnosticEmitter basic operations" {
    const allocator = std.testing.allocator;
    var emitter = DiagnosticEmitter.init(allocator);
    defer emitter.deinit();

    const loc1 = SourceLocation{ .file = "test.isle", .line = 1, .column = 1 };
    const loc2 = SourceLocation{ .file = "test.isle", .line = 2, .column = 5 };

    try emitter.emitError(loc1, "first error", null);
    try emitter.emitWarning(loc2, "first warning", "context");
    try emitter.emitNote(loc1, "helpful note", null);

    try std.testing.expectEqual(@as(usize, 3), emitter.diagnostics.items.len);
    try std.testing.expect(emitter.hasErrors());
    try std.testing.expectEqual(@as(usize, 1), emitter.errorCount());
    try std.testing.expectEqual(@as(usize, 1), emitter.warningCount());
}

test "DiagnosticEmitter with source context" {
    const allocator = std.testing.allocator;
    var emitter = DiagnosticEmitter.init(allocator);
    defer emitter.deinit();

    const source = "line 1\nline 2 with error\nline 3\n";
    try emitter.registerSource("test.isle", source);

    const loc = SourceLocation{ .file = "test.isle", .line = 2, .column = 8 };
    try emitter.emitError(loc, "unexpected token", "parser");

    try std.testing.expectEqual(@as(usize, 1), emitter.diagnostics.items.len);
    const diag = emitter.diagnostics.items[0];
    try std.testing.expect(diag.source_line != null);
    try std.testing.expectEqualStrings("line 2 with error", diag.source_line.?);
}

test "DiagnosticEmitter multi-error collection" {
    const allocator = std.testing.allocator;
    var emitter = DiagnosticEmitter.init(allocator);
    defer emitter.deinit();

    const source =
        \\(rule (add i32 i32) i32)
        \\(rule (sub i64 i64) i64)
        \\(rule (mul f32 f32) f32)
    ;
    try emitter.registerSource("rules.isle", source);

    // Collect multiple errors
    try emitter.emitError(
        .{ .file = "rules.isle", .line = 1, .column = 7 },
        "duplicate rule definition",
        "add",
    );
    try emitter.emitNote(
        .{ .file = "rules.isle", .line = 1, .column = 7 },
        "first defined here",
        null,
    );
    try emitter.emitError(
        .{ .file = "rules.isle", .line = 3, .column = 7 },
        "invalid type for mul",
        "mul",
    );

    try std.testing.expectEqual(@as(usize, 3), emitter.diagnostics.items.len);
    try std.testing.expectEqual(@as(usize, 2), emitter.errorCount());

    // Test formatting all diagnostics
    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try emitter.formatAll(fbs.writer());
    const output = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, output, "2 error(s)") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "duplicate rule definition") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "invalid type for mul") != null);
}

test "DiagnosticEmitter extractLine" {
    const allocator = std.testing.allocator;
    var emitter = DiagnosticEmitter.init(allocator);
    defer emitter.deinit();

    const source = "first\nsecond\nthird";

    const line1 = emitter.extractLine(source, 1);
    try std.testing.expect(line1 != null);
    try std.testing.expectEqualStrings("first", line1.?);

    const line2 = emitter.extractLine(source, 2);
    try std.testing.expect(line2 != null);
    try std.testing.expectEqualStrings("second", line2.?);

    const line3 = emitter.extractLine(source, 3);
    try std.testing.expect(line3 != null);
    try std.testing.expectEqualStrings("third", line3.?);

    const line4 = emitter.extractLine(source, 4);
    try std.testing.expect(line4 == null);
}
