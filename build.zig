const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const bench_optimize = b.option(
        std.builtin.OptimizeMode,
        "bench-optimize",
        "Optimization mode for benchmark and perf-gate executables (default: ReleaseFast)",
    ) orelse .ReleaseFast;

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

    const bench_baseline_path = b.option(
        []const u8,
        "bench-baseline-path",
        "Baseline benchmark log path for perf gate (default: /tmp/hoist-baseline.log)",
    ) orelse "/tmp/hoist-baseline.log";

    const bench_current_path = b.option(
        []const u8,
        "bench-current-path",
        "Current benchmark log path for perf gate (default: /tmp/hoist-bench.log)",
    ) orelse "/tmp/hoist-bench.log";

    const bench_report_path = b.option(
        []const u8,
        "bench-report-path",
        "Perf report output path (default: /tmp/hoist-bench-report.md)",
    ) orelse "/tmp/hoist-bench-report.md";
    const bench_report_json_path = b.option(
        []const u8,
        "bench-report-json-path",
        "Perf JSON report output path (default: /tmp/hoist-bench-report.json)",
    ) orelse "/tmp/hoist-bench-report.json";
    const bench_history_json_path = b.option(
        []const u8,
        "bench-history-json-path",
        "Perf history JSONL output path for appended runs (default: /tmp/hoist-bench-history.jsonl)",
    ) orelse "/tmp/hoist-bench-history.jsonl";

    const bench_max_regress_pct = b.option(
        f64,
        "bench-max-regress-pct",
        "Maximum allowed regression percentage (default: 5.0)",
    ) orelse 5.0;
    const bench_min_regress_us = b.option(
        f64,
        "bench-min-regress-us",
        "Minimum absolute regression in microseconds required to fail perf gate (default: 2.0)",
    ) orelse 2.0;
    const bench_repeat = b.option(
        usize,
        "bench-repeat",
        "Benchmark repetitions per run for median gate stability (default: 5)",
    ) orelse 5;
    const bench_refresh_baseline = b.option(
        bool,
        "bench-refresh-baseline",
        "Refresh baseline log during bench-gate (default: false; use baseline-log explicitly)",
    ) orelse false;
    const bench_budget_reference_path = b.option(
        []const u8,
        "bench-budget-reference-path",
        "Reference benchmark log path for optional 2x/3x budget checks",
    );
    const bench_budget_multiplier = b.option(
        f64,
        "bench-budget-multiplier",
        "Optional budget speedup target multiplier (e.g. 2.0 for 2x, 3.0 for 3x)",
    );

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
    const ohsnap = b.dependency("ohsnap", .{
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
    tests.root_module.addImport("ohsnap", ohsnap.module("ohsnap"));
    tests.linkSystemLibrary("capstone");
    tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/capstone/include" });
    tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/capstone/lib" });
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

    const compile_simple = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/compile_simple.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    compile_simple.root_module.addImport("hoist", lib.root_module);
    applyFlags(compile_simple, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_compile_simple = b.addRunArtifact(compile_simple);
    test_step.dependOn(&run_compile_simple.step);

    const egraph_opt = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/egraph_opt.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    egraph_opt.root_module.addImport("hoist", lib.root_module);
    applyFlags(egraph_opt, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_egraph_opt = b.addRunArtifact(egraph_opt);
    test_step.dependOn(&run_egraph_opt.step);

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

    const riscv64_encoding = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/riscv64_encoding.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    riscv64_encoding.root_module.addImport("hoist", lib.root_module);
    applyFlags(riscv64_encoding, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_riscv64_encoding = b.addRunArtifact(riscv64_encoding);
    test_step.dependOn(&run_riscv64_encoding.step);

    // TODO: s390x_encoding.zig requires complete s390x backend (lowering not implemented)
    // const s390x_encoding = b.addTest(.{
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("tests/s390x_encoding.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    // s390x_encoding.root_module.addImport("hoist", lib.root_module);
    // applyFlags(s390x_encoding, enable_lto, debug_info, strip_debug, pic, single_threaded);
    // const run_s390x_encoding = b.addRunArtifact(s390x_encoding);
    // test_step.dependOn(&run_s390x_encoding.step);

    const x64_encoding = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/x64_encoding.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    x64_encoding.root_module.addImport("hoist", lib.root_module);
    applyFlags(x64_encoding, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_x64_encoding = b.addRunArtifact(x64_encoding);
    test_step.dependOn(&run_x64_encoding.step);

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

    const e2e_merge = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/e2e_merge.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    e2e_merge.root_module.addImport("hoist", lib.root_module);
    applyFlags(e2e_merge, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_e2e_merge = b.addRunArtifact(e2e_merge);
    test_step.dependOn(&run_e2e_merge.step);

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

    const isle_coverage_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/isle_coverage.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    isle_coverage_tests.root_module.addImport("hoist", lib.root_module);
    applyFlags(isle_coverage_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_isle_coverage_tests = b.addRunArtifact(isle_coverage_tests);
    test_step.dependOn(&run_isle_coverage_tests.step);

    // TODO: Enable once compare coverage expectations are stable
    // const isle_compare_tests = b.addTest(.{
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("tests/isle_compare.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    // isle_compare_tests.root_module.addImport("hoist", lib.root_module);
    // applyFlags(isle_compare_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    // const run_isle_compare_tests = b.addRunArtifact(isle_compare_tests);
    // test_step.dependOn(&run_isle_compare_tests.step);

    const isle_memory_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/isle_memory.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    isle_memory_tests.root_module.addImport("hoist", lib.root_module);
    applyFlags(isle_memory_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_isle_memory_tests = b.addRunArtifact(isle_memory_tests);
    test_step.dependOn(&run_isle_memory_tests.step);

    // const isle_bitwise_tests = b.addTest(.{
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("tests/isle_bitwise.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    // isle_bitwise_tests.root_module.addImport("hoist", lib.root_module);
    // applyFlags(isle_bitwise_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    // const run_isle_bitwise_tests = b.addRunArtifact(isle_bitwise_tests);
    // test_step.dependOn(&run_isle_bitwise_tests.step);

    // const isle_conversions_tests = b.addTest(.{
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("tests/isle_conversions.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    // isle_conversions_tests.root_module.addImport("hoist", lib.root_module);
    // applyFlags(isle_conversions_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    // const run_isle_conversions_tests = b.addRunArtifact(isle_conversions_tests);
    // test_step.dependOn(&run_isle_conversions_tests.step);

    // const isle_float_tests = b.addTest(.{
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("tests/isle_float.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    // isle_float_tests.root_module.addImport("hoist", lib.root_module);
    // applyFlags(isle_float_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    // const run_isle_float_tests = b.addRunArtifact(isle_float_tests);
    // test_step.dependOn(&run_isle_float_tests.step);

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

    const value_range_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/value_range_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    value_range_tests.root_module.addImport("hoist", lib.root_module);
    applyFlags(value_range_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_value_range_tests = b.addRunArtifact(value_range_tests);
    test_step.dependOn(&run_value_range_tests.step);

    const domtree_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/domtree.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    domtree_tests.root_module.addImport("hoist", lib.root_module);
    applyFlags(domtree_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_domtree_tests = b.addRunArtifact(domtree_tests);
    test_step.dependOn(&run_domtree_tests.step);

    const interference_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/interference.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    interference_tests.root_module.addImport("hoist", lib.root_module);
    applyFlags(interference_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_interference_tests = b.addRunArtifact(interference_tests);
    test_step.dependOn(&run_interference_tests.step);

    const atomic_stress_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/atomic_stress.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    atomic_stress_tests.root_module.addImport("hoist", lib.root_module);
    applyFlags(atomic_stress_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_atomic_stress_tests = b.addRunArtifact(atomic_stress_tests);
    test_step.dependOn(&run_atomic_stress_tests.step);

    const filetest_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/filetest.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    filetest_tests.root_module.addImport("hoist", lib.root_module);
    applyFlags(filetest_tests, enable_lto, debug_info, strip_debug, pic, single_threaded);
    const run_filetest_tests = b.addRunArtifact(filetest_tests);
    test_step.dependOn(&run_filetest_tests.step);

    // Integration tests (future: full pipeline tests)
    const integration_step = b.step("test-integration", "Run integration tests");
    integration_step.dependOn(&run_tests.step);

    // JIT tests only
    const jit_step = b.step("test-jit", "Run JIT tests only");
    jit_step.dependOn(&run_e2e_jit.step);

    // Filetest only
    const filetest_step = b.step("test-filetest", "Run filetests only");
    filetest_step.dependOn(&run_filetest_tests.step);

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
    const bench_hoist = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = bench_optimize,
    });

    const bench_fib = b.addExecutable(.{
        .name = "bench_fib",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/compile_fib.zig"),
            .target = target,
            .optimize = bench_optimize,
        }),
    });
    bench_fib.root_module.addImport("hoist", bench_hoist);
    applyFlags(bench_fib, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const bench_large = b.addExecutable(.{
        .name = "bench_large",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/compile_large.zig"),
            .target = target,
            .optimize = bench_optimize,
        }),
    });
    bench_large.root_module.addImport("hoist", bench_hoist);
    applyFlags(bench_large, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const bench_aarch64 = b.addExecutable(.{
        .name = "bench_aarch64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/aarch64_perf.zig"),
            .target = target,
            .optimize = bench_optimize,
        }),
    });
    bench_aarch64.root_module.addImport("hoist", bench_hoist);
    applyFlags(bench_aarch64, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const bench_parallel = b.addExecutable(.{
        .name = "bench_parallel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/compile_parallel.zig"),
            .target = target,
            .optimize = bench_optimize,
        }),
    });
    bench_parallel.root_module.addImport("hoist", bench_hoist);
    applyFlags(bench_parallel, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const bench_step = b.step("bench", "Run benchmarks");
    const run_bench_fib = b.addRunArtifact(bench_fib);
    const run_bench_large = b.addRunArtifact(bench_large);
    const run_bench_aarch64 = b.addRunArtifact(bench_aarch64);
    const run_bench_parallel = b.addRunArtifact(bench_parallel);
    bench_step.dependOn(&run_bench_fib.step);
    bench_step.dependOn(&run_bench_large.step);
    bench_step.dependOn(&run_bench_aarch64.step);
    bench_step.dependOn(&run_bench_parallel.step);

    const baseline = b.addExecutable(.{
        .name = "baseline",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/baseline.zig"),
            .target = target,
            .optimize = bench_optimize,
        }),
    });
    applyFlags(baseline, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const baseline_step = b.step("baseline", "Run benchmarks and write baseline logs to /tmp");
    const run_baseline = b.addRunArtifact(baseline);
    run_baseline.addArg("--repeat");
    run_baseline.addArg(b.fmt("{d}", .{bench_repeat}));
    run_baseline.addFileArg(bench_fib.getEmittedBin());
    run_baseline.addFileArg(bench_large.getEmittedBin());
    run_baseline.addFileArg(bench_aarch64.getEmittedBin());
    run_baseline.addFileArg(bench_parallel.getEmittedBin());
    baseline_step.dependOn(&run_baseline.step);

    const bench_log_step = b.step("bench-log", "Run benchmarks and write /tmp/hoist-bench.log");
    const run_bench_log = b.addRunArtifact(baseline);
    run_bench_log.addArg("--out");
    run_bench_log.addArg(bench_current_path);
    run_bench_log.addArg("--repeat");
    run_bench_log.addArg(b.fmt("{d}", .{bench_repeat}));
    run_bench_log.addFileArg(bench_fib.getEmittedBin());
    run_bench_log.addFileArg(bench_large.getEmittedBin());
    run_bench_log.addFileArg(bench_aarch64.getEmittedBin());
    run_bench_log.addFileArg(bench_parallel.getEmittedBin());
    bench_log_step.dependOn(&run_bench_log.step);

    const baseline_log_step = b.step("baseline-log", "Refresh baseline benchmark log");
    const run_baseline_log = b.addRunArtifact(baseline);
    run_baseline_log.addArg("--out");
    run_baseline_log.addArg(bench_baseline_path);
    run_baseline_log.addArg("--repeat");
    run_baseline_log.addArg(b.fmt("{d}", .{bench_repeat}));
    run_baseline_log.addFileArg(bench_fib.getEmittedBin());
    run_baseline_log.addFileArg(bench_large.getEmittedBin());
    run_baseline_log.addFileArg(bench_aarch64.getEmittedBin());
    run_baseline_log.addFileArg(bench_parallel.getEmittedBin());
    baseline_log_step.dependOn(&run_baseline_log.step);

    const perf_gate = b.addExecutable(.{
        .name = "perf_gate",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/perf_gate.zig"),
            .target = target,
            .optimize = bench_optimize,
        }),
    });
    applyFlags(perf_gate, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const bench_gate_step = b.step("bench-gate", "Run perf gate using baseline/current bench logs");
    const run_bench_gate = b.addRunArtifact(perf_gate);
    run_bench_gate.addArg("--baseline");
    run_bench_gate.addArg(bench_baseline_path);
    run_bench_gate.addArg("--current");
    run_bench_gate.addArg(bench_current_path);
    run_bench_gate.addArg("--out");
    run_bench_gate.addArg(bench_report_path);
    run_bench_gate.addArg("--json-out");
    run_bench_gate.addArg(bench_report_json_path);
    run_bench_gate.addArg("--history-json");
    run_bench_gate.addArg(bench_history_json_path);
    if (bench_budget_reference_path) |budget_ref| {
        if (bench_budget_multiplier) |budget_mult| {
            run_bench_gate.addArg("--budget-reference");
            run_bench_gate.addArg(budget_ref);
            run_bench_gate.addArg("--budget-multiplier");
            run_bench_gate.addArg(b.fmt("{d}", .{budget_mult}));
        }
    }
    run_bench_gate.addArg("--max-regress-pct");
    run_bench_gate.addArg(b.fmt("{d}", .{bench_max_regress_pct}));
    run_bench_gate.addArg("--min-regress-us");
    run_bench_gate.addArg(b.fmt("{d}", .{bench_min_regress_us}));
    if (bench_refresh_baseline) {
        run_bench_gate.step.dependOn(&run_baseline_log.step);
    }
    run_bench_gate.step.dependOn(&run_bench_log.step);
    bench_gate_step.dependOn(&run_bench_gate.step);

    const bench_compare_step = b.step("bench-compare", "Compare existing benchmark logs with perf gate (no benchmark rerun)");
    const run_bench_compare = b.addRunArtifact(perf_gate);
    run_bench_compare.addArg("--baseline");
    run_bench_compare.addArg(bench_baseline_path);
    run_bench_compare.addArg("--current");
    run_bench_compare.addArg(bench_current_path);
    run_bench_compare.addArg("--out");
    run_bench_compare.addArg(bench_report_path);
    run_bench_compare.addArg("--json-out");
    run_bench_compare.addArg(bench_report_json_path);
    run_bench_compare.addArg("--history-json");
    run_bench_compare.addArg(bench_history_json_path);
    if (bench_budget_reference_path) |budget_ref| {
        if (bench_budget_multiplier) |budget_mult| {
            run_bench_compare.addArg("--budget-reference");
            run_bench_compare.addArg(budget_ref);
            run_bench_compare.addArg("--budget-multiplier");
            run_bench_compare.addArg(b.fmt("{d}", .{budget_mult}));
        }
    }
    run_bench_compare.addArg("--max-regress-pct");
    run_bench_compare.addArg(b.fmt("{d}", .{bench_max_regress_pct}));
    run_bench_compare.addArg("--min-regress-us");
    run_bench_compare.addArg(b.fmt("{d}", .{bench_min_regress_us}));
    bench_compare_step.dependOn(&run_bench_compare.step);

    // Fuzzing
    const fuzz_compile = b.addExecutable(.{
        .name = "fuzz_compile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("fuzz/fuzz_compile.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    fuzz_compile.root_module.addImport("hoist", lib.root_module);
    applyFlags(fuzz_compile, enable_lto, debug_info, strip_debug, pic, single_threaded);

    const fuzz_regalloc = b.addExecutable(.{
        .name = "fuzz_regalloc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("fuzz/fuzz_regalloc.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    fuzz_regalloc.root_module.addImport("hoist", lib.root_module);
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
    const IsleCompileStep = @import("build/IsleCompileStep.zig");
    const isle_debug_comments = b.option(
        bool,
        "isle-debug-comments",
        "Include debug comments in ISLE-generated Zig (can be huge)",
    ) orelse false;

    const isle_step = IsleCompileStep.create(
        b,
        isle_compiler,
        &.{
            "src/backends/aarch64/lower.isle",
            "src/backends/x64/lower.isle",
            "src/backends/riscv64/lower.isle",
            "src/dsl/isle/opts.isle",
        },
        "src/generated/isle",
        .{ .debug_comments = isle_debug_comments },
    );

    const gen_isle_step = b.step("gen-isle", "Regenerate ISLE-generated Zig code");
    gen_isle_step.dependOn(&isle_step.step);

    // CLIF tool
    const clif = b.addExecutable(.{
        .name = "clif",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/clif.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    clif.root_module.addImport("hoist", lib.root_module);
    applyFlags(clif, enable_lto, debug_info, strip_debug, pic, single_threaded);
    b.installArtifact(clif);

    const isle_dependents = &[_]*std.Build.Step{
        &lib.step,
        &tests.step,
        &e2e_branches.step,
        &e2e_loops.step,
        &e2e_jit.step,
        &compile_simple.step,
        &egraph_opt.step,
        &aarch64_tls.step,
        &fp_special_values.step,
        &aarch64_ccmp.step,
        &riscv64_encoding.step,
        &e2e_tail_calls.step,
        &aarch64_stack_args.step,
        &isle_coverage_tests.step,
        &test_legalize_ops.step,
        &value_range_tests.step,
        &domtree_tests.step,
        &interference_tests.step,
        &atomic_stress_tests.step,
        &filetest_tests.step,
        &standalone_e2e.step,
        &bench_fib.step,
        &bench_large.step,
        &bench_aarch64.step,
        &fuzz_compile.step,
        &fuzz_regalloc.step,
        &clif.step,
    };
    for (isle_dependents) |dep| dep.dependOn(&isle_step.step);
}
