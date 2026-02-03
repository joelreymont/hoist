const std = @import("std");
const isle = @import("isle");

const prelude_path = "src/dsl/isle/ir_prelude.isle";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var debug_comments = false;
    var input_path: []const u8 = undefined;
    var output_path: []const u8 = undefined;

    if (args.len == 3) {
        input_path = args[1];
        output_path = args[2];
    } else if (args.len == 4 and std.mem.eql(u8, args[1], "--debug-comments")) {
        debug_comments = true;
        input_path = args[2];
        output_path = args[3];
    } else {
        std.debug.print("Usage: {s} [--debug-comments] <input.isle> <output.zig>\n", .{args[0]});
        std.process.exit(1);
    }

    const prelude_content = std.fs.cwd().readFileAlloc(
        allocator,
        prelude_path,
        10 * 1024 * 1024, // 10MB max
    ) catch |err| {
        std.debug.print("Failed to read {s}: {}\n", .{ prelude_path, err });
        return err;
    };
    defer allocator.free(prelude_content);

    // Read input file
    const input_content = std.fs.cwd().readFileAlloc(
        allocator,
        input_path,
        10 * 1024 * 1024, // 10MB max
    ) catch |err| {
        std.debug.print("Failed to read {s}: {}\n", .{ input_path, err });
        return err;
    };
    defer allocator.free(input_content);

    // Compile ISLE to Zig
    var result = isle.compile(
        allocator,
        &.{
            isle.Source{
                .filename = prelude_path,
                .content = prelude_content,
            },
            isle.Source{
                .filename = input_path,
                .content = input_content,
            },
        },
        .{
            // Debug comments can explode code size. Default off, opt-in via CLI.
            .debug_comments = debug_comments,
        },
    ) catch |err| {
        std.debug.print("ISLE compilation failed for {s}: {}\n", .{ input_path, err });
        return err;
    };
    defer result.deinit();

    // Write output file only if contents changed; avoids spurious rebuilds.
    var needs_write = true;
    if (std.fs.cwd().openFile(output_path, .{})) |f| {
        defer f.close();

        const st = try f.stat();
        if (st.size == result.code.len) {
            var buf: [8192]u8 = undefined;
            var off: usize = 0;
            while (off < result.code.len) {
                const n = try f.read(&buf);
                if (n == 0) break;
                if (!std.mem.eql(u8, result.code[off .. off + n], buf[0..n])) break;
                off += n;
            }
            if (off == result.code.len) needs_write = false;
        }
    } else |_| {
        // File missing or unreadable -> write it.
    }

    if (needs_write) {
        try std.fs.cwd().writeFile(.{
            .sub_path = output_path,
            .data = result.code,
        });
    }

    std.debug.print("Generated {s} from {s}\n", .{ output_path, input_path });
}
