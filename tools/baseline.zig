const std = @import("std");

const RunOut = struct {
    stdout: []u8,
    stderr: []u8,
    code: u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const al = gpa.allocator();

    var args = try std.process.argsAlloc(al);
    defer std.process.argsFree(al, args);

    if (args.len < 2) {
        std.debug.print("usage: baseline <bench>...\n", .{});
        return error.InvalidArgs;
    }

    const ts = std.time.timestamp();
    var path_buf: [128]u8 = undefined;
    const out_path = try std.fmt.bufPrint(&path_buf, "/tmp/hoist-baseline-{d}.log", .{ts});

    var file = try std.fs.createFileAbsolute(out_path, .{ .truncate = true });
    defer file.close();

    var buf: [512]u8 = undefined;
    const header = try std.fmt.bufPrint(&buf, "Hoist baseline run {d}\n", .{ts});
    try file.writeAll(header);

    for (args[1..]) |exe| {
        const line = try std.fmt.bufPrint(&buf, "\n== {s} ==\n", .{exe});
        try file.writeAll(line);
        const out = try runBench(al, exe);
        defer al.free(out.stdout);
        defer al.free(out.stderr);

        if (out.stdout.len != 0) try file.writeAll(out.stdout);
        if (out.stderr.len != 0) {
            try file.writeAll("\n-- stderr --\n");
            try file.writeAll(out.stderr);
        }

        if (out.code != 0) {
            std.debug.print("bench failed: {s} (code {d})\n", .{ exe, out.code });
            return error.BenchFailed;
        }
    }

    try file.sync();
    std.debug.print("baseline written: {s}\n", .{out_path});
}

fn runBench(al: std.mem.Allocator, exe: []const u8) !RunOut {
    var child = std.process.Child.init(&[_][]const u8{exe}, al);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(al, 8 * 1024 * 1024);
    errdefer al.free(stdout);
    const stderr = try child.stderr.?.readToEndAlloc(al, 2 * 1024 * 1024);
    errdefer al.free(stderr);

    const term = try child.wait();
    const code: u8 = switch (term) {
        .Exited => |c| @intCast(c),
        else => 1,
    };

    return .{ .stdout = stdout, .stderr = stderr, .code = code };
}
