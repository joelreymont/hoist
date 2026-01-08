const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Optimization levels (use -Doptimize=<level>):
    //   Debug        - No optimizations, safety checks enabled (default)
    //   ReleaseSafe  - Optimizations enabled, safety checks enabled
    //   ReleaseSmall - Optimize for small binary size
    //   ReleaseFast  - Optimize for execution speed, safety checks disabled

    // Debug info generation
    // In Debug/ReleaseSafe: full debug info by default (unless stripped)
    // In ReleaseFast/ReleaseSmall: no debug info by default (unless forced)
    const default_debug_info = switch (optimize) {
        .Debug, .ReleaseSafe => true,
        .ReleaseFast, .ReleaseSmall => false,
    };

    const debug_info = b.option(
        bool,
        "debug-info",
        "Generate debug information (default: true for Debug/ReleaseSafe, false otherwise)",
    ) orelse default_debug_info;

    const strip_debug = b.option(
        bool,
        "strip-debug",
        "Strip debug information from binaries (overrides debug-info, default: false)",
    ) orelse false;

    // Additional compilation flags
    const enable_lto = b.option(
        bool,
        "lto",
        "Enable link-time optimization (requires LLD linker, default: false)",
    ) orelse false;

    const pic = b.option(
        bool,
        "pic",
        "Build position-independent code (default: true on macOS)",
    ) orelse (target.result.os.tag == .macos);

    const single_threaded = b.option(
        bool,
        "single-threaded",
        "Build for single-threaded execution (default: false)",
    ) orelse false;

    // Helper to apply flags to a compile step
    const applyFlags = struct {
        fn apply(step: *std.Build.Step.Compile, lto: bool, debug: bool, strip_flag: bool, pic_flag: bool, single_thread: bool) void {
            step.want_lto = lto;
            // strip overrides debug_info
            step.root_module.strip = strip_flag;
            // Only set omit_frame_pointer when not generating debug info (unless stripped)
            if (!debug or strip_flag) {
                step.root_module.omit_frame_pointer = true;
            }
            step.root_module.pic = pic_flag;
            step.root_module.single_threaded = single_thread;
        }
    }.apply;

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
    applyFlags(lib, enable_lto, debug_info, strip_debug, pic, single_threaded);
    b.installArtifact(lib);

    // Dependencies
    const zcheck = b.dependency("zcheck", .{
        .target = target,
        .optimize = optimize,
    });

    // Unit tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("zcheck", zcheck.module("zcheck"));
    applyFlags(tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
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
    applyFlags(e2e_branches, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_e2e_branches = b.addRunArtifact(e2e_branches);
    test_step.dependOn(&run_e2e_branches.step);

    const e2e_loops = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/e2e_loops.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    e2e_loops.root_module.addImport("hoist", lib.root_module);
    applyFlags(e2e_loops, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_e2e_loops = b.addRunArtifact(e2e_loops);
    test_step.dependOn(&run_e2e_loops.step);

    const e2e_jit = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/e2e_jit.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    e2e_jit.root_module.addImport("hoist", lib.root_module);
    applyFlags(e2e_jit, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_e2e_jit = b.addRunArtifact(e2e_jit);
    test_step.dependOn(&run_e2e_jit.step);

    const aarch64_tls = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/aarch64_tls.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    aarch64_tls.root_module.addImport("hoist", lib.root_module);
    applyFlags(aarch64_tls, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_aarch64_tls = b.addRunArtifact(aarch64_tls);
    test_step.dependOn(&run_aarch64_tls.step);

    const fp_special_values = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/fp_special_values.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    fp_special_values.root_module.addImport("hoist", lib.root_module);
    applyFlags(fp_special_values, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_fp_special_values = b.addRunArtifact(fp_special_values);
    test_step.dependOn(&run_fp_special_values.step);

    const aarch64_ccmp = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/aarch64_ccmp.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    aarch64_ccmp.root_module.addImport("hoist", lib.root_module);
    applyFlags(aarch64_ccmp, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_aarch64_ccmp = b.addRunArtifact(aarch64_ccmp);
    test_step.dependOn(&run_aarch64_ccmp.step);

    const e2e_tail_calls = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/e2e_tail_calls.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    e2e_tail_calls.root_module.addImport("hoist", lib.root_module);
    e2e_tail_calls.root_module.addImport("zcheck", zcheck.module("zcheck"));
    applyFlags(e2e_tail_calls, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_e2e_tail_calls = b.addRunArtifact(e2e_tail_calls);
    test_step.dependOn(&run_e2e_tail_calls.step);

    const aarch64_struct_args = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/aarch64_struct_args.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    aarch64_struct_args.root_module.addImport("hoist", lib.root_module);
    aarch64_struct_args.root_module.addImport("zcheck", zcheck.module("zcheck"));
    applyFlags(aarch64_struct_args, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_aarch64_struct_args = b.addRunArtifact(aarch64_struct_args);
    test_step.dependOn(&run_aarch64_struct_args.step);

    const aarch64_stack_args = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/aarch64_stack_args.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    aarch64_stack_args.root_module.addImport("hoist", lib.root_module);
    aarch64_stack_args.root_module.addImport("zcheck", zcheck.module("zcheck"));
    applyFlags(aarch64_stack_args, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_aarch64_stack_args = b.addRunArtifact(aarch64_stack_args);
    test_step.dependOn(&run_aarch64_stack_args.step);

    const aarch64_return_marshaling = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/aarch64_return_marshaling.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    aarch64_return_marshaling.root_module.addImport("hoist", lib.root_module);
    applyFlags(aarch64_return_marshaling, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_aarch64_return_marshaling = b.addRunArtifact(aarch64_return_marshaling);
    test_step.dependOn(&run_aarch64_return_marshaling.step);

    const aarch64_indirect_return = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/aarch64_indirect_return.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    aarch64_indirect_return.root_module.addImport("hoist", lib.root_module);
    aarch64_indirect_return.root_module.addImport("zcheck", zcheck.module("zcheck"));
    applyFlags(aarch64_indirect_return, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_aarch64_indirect_return = b.addRunArtifact(aarch64_indirect_return);
    test_step.dependOn(&run_aarch64_indirect_return.step);

    const test_legalize_ops = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/test_legalize_ops.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_legalize_ops.root_module.addImport("hoist", lib.root_module);
    applyFlags(test_legalize_ops, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_test_legalize_ops = b.addRunArtifact(test_legalize_ops);
    test_step.dependOn(&run_test_legalize_ops.step);

    // Integration tests (future: full pipeline tests)
    const integration_step = b.step("test-integration", "Run integration tests");
    integration_step.dependOn(&run_tests.step);

    // Standalone E2E test (bypasses test framework)
    const standalone_e2e = b.addExecutable(.{
        .name = "standalone_e2e",
        .root_module = b.createModule(.{
            .root_source_file = b.path("standalone_e2e.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    standalone_e2e.root_module.addImport("hoist", lib.root_module);
    applyFlags(standalone_e2e, enable_lto, debug_info, strip_debug, pic, single_threaded);
    b.installArtifact(standalone_e2e);

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
    applyFlags(bench_fib, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const bench_large = b.addExecutable(.{
        .name = "bench_large",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/compile_large.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    bench_large.root_module.addImport("root", lib.root_module);
    applyFlags(bench_large, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const bench_aarch64 = b.addExecutable(.{
        .name = "bench_aarch64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/aarch64_perf.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    bench_aarch64.root_module.addImport("root", lib.root_module);
    applyFlags(bench_aarch64, enable_lto, debug_info, strip_debug, pic, single_threaded);

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
    applyFlags(fuzz_compile, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const fuzz_regalloc = b.addExecutable(.{
        .name = "fuzz_regalloc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("fuzz/fuzz_regalloc.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    fuzz_regalloc.root_module.addImport("root", lib.root_module);
    applyFlags(fuzz_regalloc, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const fuzz_step = b.step("fuzz", "Run fuzzers");
    const run_fuzz_compile = b.addRunArtifact(fuzz_compile);
    const run_fuzz_regalloc = b.addRunArtifact(fuzz_regalloc);
    fuzz_step.dependOn(&run_fuzz_compile.step);
    fuzz_step.dependOn(&run_fuzz_regalloc.step);

    // ISLE compiler executable (respects user's optimization level)
    const isle_compiler = b.addExecutable(.{
        .name = "isle_compiler",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/isle_compiler.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    applyFlags(isle_compiler, enable_lto, debug_info, strip_debug, pic, single_threaded);

    // Add isle module to the compiler
    const isle_module = b.createModule(.{
        .root_source_file = b.path("src/dsl/isle/compile.zig"),
        .target = target,
        .optimize = optimize,
    });
    isle_compiler.root_module.addImport("isle", isle_module);

    // ISLE compilation (.isle -> .zig generation)
    // Temporarily disabled due to parser issues - using pre-generated files
    // const IsleCompileStep = @import("build/IsleCompileStep.zig");
    // const isle_step = IsleCompileStep.create(
    //     b,
    //     isle_compiler,
    //     &.{
    //         "src/backends/aarch64/lower.isle",
    //         "src/backends/x64/lower.isle",
    //         "src/dsl/isle/opts.isle",
    //     },
    //     "src/generated",
    // );

    // Make library depend on ISLE code generation
    // lib.step.dependOn(&isle_step.step);
}
