const std = @import("std");
const isle = @import("isle");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        std.debug.print("Usage: {s} <input.isle> <output.zig>\n", .{args[0]});
        std.process.exit(1);
    }

    const input_path = args[1];
    const output_path = args[2];

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
        &.{isle.Source{
            .filename = input_path,
            .content = input_content,
        }},
        .{
            .debug_comments = true,
        },
    ) catch |err| {
        std.debug.print("ISLE compilation failed for {s}: {}\n", .{ input_path, err });
        return err;
    };
    defer result.deinit();

    // Write output file
    try std.fs.cwd().writeFile(.{
        .sub_path = output_path,
        .data = result.code,
    });

    std.debug.print("Generated {s} from {s}\n", .{ output_path, input_path });
}
