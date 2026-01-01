const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "cranelift",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);

    // Unit tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Integration tests (future: full pipeline tests)
    const integration_step = b.step("test-integration", "Run integration tests");
    integration_step.dependOn(&run_tests.step);

    // Benchmarks (future: performance regression tests)
    const bench_step = b.step("bench", "Run benchmarks");
    _ = bench_step;

    // ISLE compilation (future: .isle -> .zig generation)
    // Bootstrap: check in generated files until Zig ISLE compiler ready
    // const isle_step = b.addIsleCompile(.{
    //     .sources = &.{
    //         "src/backends/x64/lower.isle",
    //         "src/backends/aarch64/lower.isle",
    //         "src/dsl/isle/opts.isle",
    //     },
    //     .output_dir = "src/generated",
    // });
    // lib.step.dependOn(&isle_step.step);
}
