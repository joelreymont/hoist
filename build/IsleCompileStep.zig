const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Allocator = std.mem.Allocator;

const IsleCompileStep = @This();

step: Step,
owner: *Build,
compiler_exe: *Build.Step.Compile,
source_files: []const []const u8,
output_dir: []const u8,
generated_files: std.ArrayList(Build.GeneratedFile),

pub fn create(
    owner: *Build,
    compiler_exe: *Build.Step.Compile,
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
        .compiler_exe = compiler_exe,
        .source_files = owner.allocator.dupe([]const u8, source_files) catch @panic("OOM"),
        .output_dir = owner.allocator.dupe(u8, output_dir) catch @panic("OOM"),
        .generated_files = .{},
    };

    // Create output directory path
    const output_dir_path = owner.pathJoin(&.{ owner.build_root.path.?, output_dir });
    std.fs.cwd().makePath(output_dir_path) catch @panic("Failed to create output dir");

    // Create a Run step for each ISLE file
    for (source_files) |source_path| {
        const full_source_path = owner.pathJoin(&.{ owner.build_root.path.?, source_path });

        // Determine output file name
        const basename = std.fs.path.basename(source_path);
        const name_without_ext = if (std.mem.endsWith(u8, basename, ".isle"))
            basename[0 .. basename.len - 5]
        else
            basename;

        const output_filename = std.fmt.allocPrint(
            owner.allocator,
            "{s}_generated.zig",
            .{name_without_ext},
        ) catch @panic("OOM");

        const output_path = owner.pathJoin(&.{ output_dir_path, output_filename });

        // Create run step for this file
        const run_step = owner.addRunArtifact(compiler_exe);
        run_step.addFileArg(.{ .cwd_relative = full_source_path });
        run_step.addArg(output_path);

        // Make our step depend on this run
        self.step.dependOn(&run_step.step);

        // Track generated file
        self.generated_files.append(owner.allocator, .{
            .step = &self.step,
            .path = output_path,
        }) catch @panic("OOM");
    }

    return self;
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    // All work is done by the Run step dependencies
    _ = step;
    _ = options;
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
