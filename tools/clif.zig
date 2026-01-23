const std = @import("std");
const hoist = @import("hoist");
const Parser = hoist.ir.text.Parser;
const Printer = hoist.ir.text.Printer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 2) {
        usage();
        return;
    }

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "print")) {
        if (args.len < 3) {
            usage();
            return;
        }
        try printFile(alloc, args[2]);
    } else if (std.mem.eql(u8, cmd, "roundtrip")) {
        if (args.len < 3) {
            usage();
            return;
        }
        try roundtrip(alloc, args[2]);
    } else {
        usage();
    }
}

fn usage() void {
    std.debug.print(
        \\Usage: clif <command> [args]
        \\
        \\Commands:
        \\  print <file>      Parse and print IR
        \\  roundtrip <file>  Parse, print, parse again
        \\
    , .{});
}

fn printFile(alloc: std.mem.Allocator, path: []const u8) !void {
    const src = try std.fs.cwd().readFileAlloc(alloc, path, 1024 * 1024);
    defer alloc.free(src);

    var parser = try Parser.init(alloc, src);
    defer parser.deinit();

    var func = try parser.parseFunction();
    defer func.deinit();

    var printer = Printer.init(alloc, func);
    defer printer.deinit();

    try printer.print();
    std.debug.print("{s}", .{printer.finish()});
}

fn roundtrip(alloc: std.mem.Allocator, path: []const u8) !void {
    const src = try std.fs.cwd().readFileAlloc(alloc, path, 1024 * 1024);
    defer alloc.free(src);

    var parser1 = try Parser.init(alloc, src);
    defer parser1.deinit();

    var func1 = try parser1.parseFunction();
    defer func1.deinit();

    var printer1 = Printer.init(alloc, func1);
    defer printer1.deinit();

    try printer1.print();
    const txt1 = printer1.finish();

    var parser2 = try Parser.init(alloc, txt1);
    defer parser2.deinit();

    var func2 = try parser2.parseFunction();
    defer func2.deinit();

    var printer2 = Printer.init(alloc, func2);
    defer printer2.deinit();

    try printer2.print();
    const txt2 = printer2.finish();

    if (!std.mem.eql(u8, txt1, txt2)) {
        std.debug.print("Roundtrip failed\nFirst:\n{s}\nSecond:\n{s}\n", .{txt1, txt2});
        std.process.exit(1);
    }

    std.debug.print("{s}", .{txt2});
}
