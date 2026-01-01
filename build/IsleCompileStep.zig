const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Allocator = std.mem.Allocator;

const IsleCompileStep = @This();

step: Step,
owner: *Build,
source_files: []const []const u8,
output_dir: []const u8,
generated_files: std.ArrayList(Build.GeneratedFile),

pub fn create(
    owner: *Build,
    source_files: []const []const u8,
    output_dir: []const u8,
) *IsleCompileStep {
    const self = owner.allocator.create(IsleCompileStep) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = .custom,
            .name = "compile ISLE",
            .owner = owner,
            .makeFn = make,
        }),
        .owner = owner,
        .source_files = owner.allocator.dupe([]const u8, source_files) catch @panic("OOM"),
        .output_dir = owner.allocator.dupe(u8, output_dir) catch @panic("OOM"),
        .generated_files = .{},
    };
    return self;
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    _ = options;
    const self: *IsleCompileStep = @fieldParentPtr("step", step);
    const b = self.owner;

    // Create output directory
    const output_dir = b.pathJoin(&.{ b.build_root.path.?, self.output_dir });
    try std.fs.cwd().makePath(output_dir);

    // Compile each ISLE file
    for (self.source_files) |source_path| {
        const full_source_path = b.pathJoin(&.{ b.build_root.path.?, source_path });

        // Read source file
        const source_content = std.fs.cwd().readFileAlloc(
            b.allocator,
            full_source_path,
            10 * 1024 * 1024, // 10MB max
        ) catch |err| {
            std.debug.print("Failed to read ISLE source {s}: {}\n", .{ full_source_path, err });
            return err;
        };
        defer b.allocator.free(source_content);

        // Determine output file name
        const basename = std.fs.path.basename(source_path);
        const name_without_ext = if (std.mem.endsWith(u8, basename, ".isle"))
            basename[0 .. basename.len - 5]
        else
            basename;

        const output_filename = try std.fmt.allocPrint(
            b.allocator,
            "{s}_generated.zig",
            .{name_without_ext},
        );
        defer b.allocator.free(output_filename);

        const output_path = b.pathJoin(&.{ output_dir, output_filename });

        // For now, write a stub generated file
        // TODO: Invoke actual ISLE compiler once module linking is set up
        const stub_code = try std.fmt.allocPrint(
            b.allocator,
            \\// Generated from {s}
            \\// TODO: Implement ISLE compiler invocation
            \\
            \\const std = @import("std");
            \\
            \\pub fn lowerInst() void {{}}
            \\
        ,
            .{basename},
        );
        defer b.allocator.free(stub_code);

        // Write stub to output file
        try std.fs.cwd().writeFile(.{
            .sub_path = output_path,
            .data = stub_code,
        });

        std.debug.print("Generated {s} from {s}\n", .{ output_path, source_path });

        // Track generated file
        try self.generated_files.append(b.allocator, .{
            .step = &self.step,
            .path = try b.allocator.dupe(u8, output_path),
        });
    }
}

fn getBackendFromPath(path: []const u8) []const u8 {
    if (std.mem.indexOf(u8, path, "x64") != null or
        std.mem.indexOf(u8, path, "x86_64") != null)
    {
        return "x64";
    } else if (std.mem.indexOf(u8, path, "aarch64") != null or
        std.mem.indexOf(u8, path, "arm64") != null)
    {
        return "aarch64";
    } else {
        return "generic";
    }
}

pub fn getGeneratedFiles(self: *const IsleCompileStep) []const Build.GeneratedFile {
    return self.generated_files.items;
}
