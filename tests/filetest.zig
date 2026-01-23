const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const hoist = @import("hoist");
const Parser = hoist.ir.text.Parser;
const Printer = hoist.ir.text.Printer;
const Function = hoist.function.Function;
const Context = hoist.context.Context;
const Verifier = hoist.ir.Verifier;

const TestDirective = enum {
    compile,
    verify,
    roundtrip,
};

const FiletestError = error{
    InvalidDirective,
    NoDirective,
    ParseFailed,
    VerifyFailed,
    CompileFailed,
    RoundtripFailed,
};

/// Parse a filetest and extract directives and IR source.
fn parseFiletest(src: []const u8) !struct { dirs: [16]TestDirective, dir_count: usize, ir_start: usize } {
    var dirs: [16]TestDirective = undefined;
    var dir_count: usize = 0;
    var pos: usize = 0;

    while (pos < src.len) {
        // Skip whitespace
        while (pos < src.len and (src[pos] == ' ' or src[pos] == '\t')) : (pos += 1) {}

        // Check for directive line
        if (std.mem.startsWith(u8, src[pos..], "test ")) {
            pos += 5;
            const line_end = std.mem.indexOfScalar(u8, src[pos..], '\n') orelse src.len - pos;
            const directive = std.mem.trim(u8, src[pos..][0..line_end], " \t\r");

            if (dir_count >= 16) return error.InvalidDirective;

            if (std.mem.eql(u8, directive, "compile")) {
                dirs[dir_count] = .compile;
                dir_count += 1;
            } else if (std.mem.eql(u8, directive, "verify")) {
                dirs[dir_count] = .verify;
                dir_count += 1;
            } else if (std.mem.eql(u8, directive, "roundtrip")) {
                dirs[dir_count] = .roundtrip;
                dir_count += 1;
            } else {
                return error.InvalidDirective;
            }
            pos += line_end + 1;
        } else if (std.mem.startsWith(u8, src[pos..], "target ")) {
            // Skip target lines for now
            const line_end = std.mem.indexOfScalar(u8, src[pos..], '\n') orelse src.len - pos;
            pos += line_end + 1;
        } else if (src[pos] == '\n') {
            pos += 1;
        } else {
            // Start of IR
            break;
        }
    }

    if (dir_count == 0) return error.NoDirective;

    return .{ .dirs = dirs, .dir_count = dir_count, .ir_start = pos };
}

/// Run a single filetest.
fn runFiletest(alloc: Allocator, name: []const u8, src: []const u8) !void {
    const parsed = parseFiletest(src) catch |err| {
        std.debug.print("filetest '{s}': failed to parse directives: {}\n", .{ name, err });
        return err;
    };

    const ir_src = src[parsed.ir_start..];

    for (parsed.dirs[0..parsed.dir_count]) |dir| {
        switch (dir) {
            .verify => {
                var parser = Parser.init(alloc, ir_src) catch |err| {
                    std.debug.print("filetest '{s}': parse error: {}\n", .{ name, err });
                    return error.ParseFailed;
                };
                defer parser.deinit();

                var func = parser.parseFunction() catch |err| {
                    std.debug.print("filetest '{s}': parse error: {}\n", .{ name, err });
                    return error.ParseFailed;
                };
                defer func.deinit();

                var verifier = Verifier.init(alloc, func);
                defer verifier.deinit();

                verifier.verify() catch |err| {
                    std.debug.print("filetest '{s}': verify error: {}\n", .{ name, err });
                    for (verifier.errors.items) |msg| {
                        std.debug.print("  {s}\n", .{msg});
                    }
                    return error.VerifyFailed;
                };
            },
            .compile => {
                var parser = Parser.init(alloc, ir_src) catch |err| {
                    std.debug.print("filetest '{s}': parse error: {}\n", .{ name, err });
                    return error.ParseFailed;
                };
                defer parser.deinit();

                var func = parser.parseFunction() catch |err| {
                    std.debug.print("filetest '{s}': parse error: {}\n", .{ name, err });
                    return error.ParseFailed;
                };
                defer func.deinit();

                var ctx = Context.init(alloc);
                var code = ctx.compileFunction(func) catch |err| {
                    std.debug.print("filetest '{s}': compile error: {}\n", .{ name, err });
                    return error.CompileFailed;
                };
                defer code.deinit();
            },
            .roundtrip => {
                var parser1 = Parser.init(alloc, ir_src) catch |err| {
                    std.debug.print("filetest '{s}': parse error: {}\n", .{ name, err });
                    return error.ParseFailed;
                };
                defer parser1.deinit();

                var func1 = parser1.parseFunction() catch |err| {
                    std.debug.print("filetest '{s}': parse error: {}\n", .{ name, err });
                    return error.ParseFailed;
                };
                defer func1.deinit();

                var printer = Printer.init(alloc, func1);
                defer printer.deinit();
                try printer.print();
                const txt1 = printer.finish();

                var parser2 = Parser.init(alloc, txt1) catch |err| {
                    std.debug.print("filetest '{s}': roundtrip parse error: {}\n", .{ name, err });
                    return error.RoundtripFailed;
                };
                defer parser2.deinit();

                var func2 = parser2.parseFunction() catch |err| {
                    std.debug.print("filetest '{s}': roundtrip parse error: {}\n", .{ name, err });
                    return error.RoundtripFailed;
                };
                defer func2.deinit();

                var printer2 = Printer.init(alloc, func2);
                defer printer2.deinit();
                try printer2.print();
                const txt2 = printer2.finish();

                if (!std.mem.eql(u8, txt1, txt2)) {
                    std.debug.print("filetest '{s}': roundtrip mismatch\n", .{name});
                    return error.RoundtripFailed;
                }
            },
        }
    }
}

/// Discover and run all filetests in the filetests directory.
fn runAllFiletests(alloc: Allocator) !void {
    const dir_path = "tests/filetests";
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
        std.debug.print("Cannot open filetests directory: {}\n", .{err});
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    var passed: usize = 0;
    var failed: usize = 0;

    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".clif")) continue;

        const src = dir.readFileAlloc(alloc, entry.name, 1024 * 1024) catch |err| {
            std.debug.print("Cannot read {s}: {}\n", .{ entry.name, err });
            failed += 1;
            continue;
        };
        defer alloc.free(src);

        runFiletest(alloc, entry.name, src) catch {
            failed += 1;
            continue;
        };
        passed += 1;
    }

    if (failed > 0) {
        std.debug.print("filetests: {d} passed, {d} failed\n", .{ passed, failed });
        return error.TestsFailed;
    }

    if (passed == 0) {
        std.debug.print("filetests: no tests found\n", .{});
    } else {
        std.debug.print("filetests: {d} passed\n", .{passed});
    }
}

test "run all filetests" {
    try runAllFiletests(testing.allocator);
}

test "parse directive - compile" {
    const src =
        \\test compile
        \\
        \\function "foo"() {
        \\block0:
        \\  return
        \\}
    ;

    const result = try parseFiletest(src);
    try testing.expectEqual(@as(usize, 1), result.dir_count);
    try testing.expectEqual(TestDirective.compile, result.dirs[0]);
}

test "parse directive - verify" {
    const src =
        \\test verify
        \\target aarch64
        \\
        \\function "bar"(i32) -> i32 {
        \\block0(v0: i32):
        \\  return v0
        \\}
    ;

    const result = try parseFiletest(src);
    try testing.expectEqual(@as(usize, 1), result.dir_count);
    try testing.expectEqual(TestDirective.verify, result.dirs[0]);
}

test "parse directive - multiple" {
    const src =
        \\test verify
        \\test compile
        \\test roundtrip
        \\
        \\function "baz"() {
        \\block0:
        \\  return
        \\}
    ;

    const result = try parseFiletest(src);
    try testing.expectEqual(@as(usize, 3), result.dir_count);
    try testing.expectEqual(TestDirective.verify, result.dirs[0]);
    try testing.expectEqual(TestDirective.compile, result.dirs[1]);
    try testing.expectEqual(TestDirective.roundtrip, result.dirs[2]);
}
