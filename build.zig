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

    // E2E tests
    const e2e_branches = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/e2e_branches.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    e2e_branches.root_module.addImport("hoist", lib.root_module);
    const run_e2e_branches = b.addRunArtifact(e2e_branches);
    test_step.dependOn(&run_e2e_branches.step);

    const e2e_jit = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/e2e_jit.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    e2e_jit.root_module.addImport("hoist", lib.root_module);
    const run_e2e_jit = b.addRunArtifact(e2e_jit);
    test_step.dependOn(&run_e2e_jit.step);

    // Integration tests (future: full pipeline tests)
    const integration_step = b.step("test-integration", "Run integration tests");
    integration_step.dependOn(&run_tests.step);

    // Benchmarks
    const bench_fib = b.addExecutable(.{
        .name = "bench_fib",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/compile_fib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    bench_fib.root_module.addImport("root", lib.root_module);

    const bench_large = b.addExecutable(.{
        .name = "bench_large",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/compile_large.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    bench_large.root_module.addImport("root", lib.root_module);

    const bench_aarch64 = b.addExecutable(.{
        .name = "bench_aarch64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/aarch64_perf.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    bench_aarch64.root_module.addImport("root", lib.root_module);

    const bench_step = b.step("bench", "Run benchmarks");
    const run_bench_fib = b.addRunArtifact(bench_fib);
    const run_bench_large = b.addRunArtifact(bench_large);
    const run_bench_aarch64 = b.addRunArtifact(bench_aarch64);
    bench_step.dependOn(&run_bench_fib.step);
    bench_step.dependOn(&run_bench_large.step);
    bench_step.dependOn(&run_bench_aarch64.step);

    // Fuzzing
    const fuzz_compile = b.addExecutable(.{
        .name = "fuzz_compile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("fuzz/fuzz_compile.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    fuzz_compile.root_module.addImport("root", lib.root_module);

    const fuzz_regalloc = b.addExecutable(.{
        .name = "fuzz_regalloc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("fuzz/fuzz_regalloc.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    fuzz_regalloc.root_module.addImport("root", lib.root_module);

    const fuzz_step = b.step("fuzz", "Run fuzzers");
    const run_fuzz_compile = b.addRunArtifact(fuzz_compile);
    const run_fuzz_regalloc = b.addRunArtifact(fuzz_regalloc);
    fuzz_step.dependOn(&run_fuzz_compile.step);
    fuzz_step.dependOn(&run_fuzz_regalloc.step);

    // ISLE compiler executable
    const isle_compiler = b.addExecutable(.{
        .name = "isle_compiler",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/isle_compiler.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });

    // Add isle module to the compiler
    const isle_module = b.createModule(.{
        .root_source_file = b.path("src/dsl/isle/compile.zig"),
        .target = target,
        .optimize = optimize,
    });
    isle_compiler.root_module.addImport("isle", isle_module);

    // ISLE compilation (.isle -> .zig generation)
    const IsleCompileStep = @import("build/IsleCompileStep.zig");
    const isle_step = IsleCompileStep.create(
        b,
        isle_compiler,
        &.{
            "src/backends/aarch64/lower.isle",
            "src/backends/x64/lower.isle",
            "src/dsl/isle/opts.isle",
        },
        "src/generated",
    );

    // Make library depend on ISLE code generation
    lib.step.dependOn(&isle_step.step);
}
