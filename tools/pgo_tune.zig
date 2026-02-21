const std = @import("std");

const Candidate = struct {
    alias_min_complexity: u32,
    range_min_complexity: u32,
    egraph_min_complexity: u32,
    fold_iadd_iconst_min_insts: usize,
};

const GateMetric = struct {
    id: []const u8,
    baseline_median_us: f64,
    current_median_us: f64,
    delta_pct: f64,
};

const GateReport = struct {
    status: []const u8,
    regressions: usize,
    positive_wins: usize,
    metrics: []const GateMetric,
};

const CandidateScore = struct {
    objective_delta_us: f64,
    objective_avg_speedup: f64,
};

const Best = struct {
    cfg: Candidate,
    score: CandidateScore,
    positive_wins: usize,
    tested: usize,
    passed: usize,
};

const RunOut = struct {
    code: u8,
    stderr: []u8,
};

const objective_metrics = [_][]const u8{
    "fib avg compile (us)",
    "large(5000) compile (us)",
    "aarch64 int avg compile (us)",
    "aarch64 vector avg compile (us)",
    "aarch64 memory avg compile (us)",
    "aarch64 mixed avg compile (us)",
};

fn isObjectiveMetric(id: []const u8) bool {
    for (objective_metrics) |name| {
        if (std.mem.eql(u8, id, name)) return true;
    }
    return false;
}

fn parseUnsignedList(
    comptime T: type,
    al: std.mem.Allocator,
    csv_opt: ?[]const u8,
    defaults: []const T,
) ![]T {
    const csv = csv_opt orelse return try al.dupe(T, defaults);
    var items = std.ArrayList(T){};
    defer items.deinit(al);

    var it = std.mem.splitScalar(u8, csv, ',');
    while (it.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t\r\n");
        if (trimmed.len == 0) continue;
        try items.append(al, try std.fmt.parseUnsigned(T, trimmed, 10));
    }
    if (items.items.len == 0) return error.InvalidArgs;
    return try items.toOwnedSlice(al);
}

fn parseArgUnsigned(
    comptime T: type,
    args: []const []const u8,
    idx: *usize,
) !T {
    if (idx.* + 1 >= args.len) return error.InvalidArgs;
    idx.* += 1;
    return try std.fmt.parseUnsigned(T, args[idx.*], 10);
}

fn parseArgFloat(args: []const []const u8, idx: *usize) !f64 {
    if (idx.* + 1 >= args.len) return error.InvalidArgs;
    idx.* += 1;
    return try std.fmt.parseFloat(f64, args[idx.*]);
}

fn parseArgString(args: []const []const u8, idx: *usize) ![]const u8 {
    if (idx.* + 1 >= args.len) return error.InvalidArgs;
    idx.* += 1;
    return args[idx.*];
}

fn setEnvUnsigned(
    comptime T: type,
    al: std.mem.Allocator,
    env: *std.process.EnvMap,
    key: []const u8,
    value: T,
) !void {
    const text = try std.fmt.allocPrint(al, "{d}", .{value});
    defer al.free(text);
    try env.put(key, text);
}

fn runCommand(
    al: std.mem.Allocator,
    argv: []const []const u8,
    env_map: ?*std.process.EnvMap,
) !RunOut {
    var child = std.process.Child.init(argv, al);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Pipe;
    child.env_map = env_map;
    try child.spawn();
    const stderr = try child.stderr.?.readToEndAlloc(al, 8 * 1024 * 1024);
    const term = try child.wait();
    const code: u8 = switch (term) {
        .Exited => |c| @intCast(c),
        else => 1,
    };
    return .{
        .code = code,
        .stderr = stderr,
    };
}

fn runBaseline(
    al: std.mem.Allocator,
    baseline_bin: []const u8,
    current_log: []const u8,
    repeat: usize,
    benches: []const []const u8,
    env_map: ?*std.process.EnvMap,
) !RunOut {
    var args = std.ArrayList([]const u8){};
    defer args.deinit(al);
    try args.append(al, baseline_bin);
    try args.appendSlice(al, &.{ "--out", current_log, "--repeat" });
    const repeat_text = try std.fmt.allocPrint(al, "{d}", .{repeat});
    defer al.free(repeat_text);
    try args.append(al, repeat_text);
    try args.appendSlice(al, benches);
    return try runCommand(al, args.items, env_map);
}

fn runPerfGate(
    al: std.mem.Allocator,
    perf_gate_bin: []const u8,
    baseline_log: []const u8,
    current_log: []const u8,
    report_out: []const u8,
    json_out: []const u8,
    max_regress_pct: f64,
    min_regress_us: f64,
    min_positive_pct: f64,
    min_positive_us: f64,
    min_positive_count: usize,
) !RunOut {
    var args = std.ArrayList([]const u8){};
    defer args.deinit(al);
    try args.append(al, perf_gate_bin);
    try args.appendSlice(al, &.{
        "--baseline",
        baseline_log,
        "--current",
        current_log,
        "--out",
        report_out,
        "--json-out",
        json_out,
        "--max-regress-pct",
    });

    const max_regress_text = try std.fmt.allocPrint(al, "{d}", .{max_regress_pct});
    defer al.free(max_regress_text);
    try args.append(al, max_regress_text);
    try args.appendSlice(al, &.{"--min-regress-us"});
    const min_regress_text = try std.fmt.allocPrint(al, "{d}", .{min_regress_us});
    defer al.free(min_regress_text);
    try args.append(al, min_regress_text);
    try args.appendSlice(al, &.{"--min-positive-pct"});
    const min_positive_pct_text = try std.fmt.allocPrint(al, "{d}", .{min_positive_pct});
    defer al.free(min_positive_pct_text);
    try args.append(al, min_positive_pct_text);
    try args.appendSlice(al, &.{"--min-positive-us"});
    const min_positive_us_text = try std.fmt.allocPrint(al, "{d}", .{min_positive_us});
    defer al.free(min_positive_us_text);
    try args.append(al, min_positive_us_text);
    try args.appendSlice(al, &.{"--min-positive-count"});
    const min_positive_count_text = try std.fmt.allocPrint(al, "{d}", .{min_positive_count});
    defer al.free(min_positive_count_text);
    try args.append(al, min_positive_count_text);
    return try runCommand(al, args.items, null);
}

fn readGateReport(al: std.mem.Allocator, json_path: []const u8) !std.json.Parsed(GateReport) {
    const text = try std.fs.cwd().readFileAlloc(al, json_path, 16 * 1024 * 1024);
    defer al.free(text);
    return try std.json.parseFromSlice(
        GateReport,
        al,
        text,
        .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        },
    );
}

fn scoreReport(report: GateReport) !CandidateScore {
    var objective_delta_us: f64 = 0;
    var speedup_sum: f64 = 0;
    var count: usize = 0;

    for (report.metrics) |metric| {
        if (!isObjectiveMetric(metric.id)) continue;
        if (metric.current_median_us <= 0 or metric.baseline_median_us <= 0) continue;
        objective_delta_us += (metric.baseline_median_us - metric.current_median_us);
        speedup_sum += metric.baseline_median_us / metric.current_median_us;
        count += 1;
    }
    if (count == 0) return error.MissingObjectiveMetric;
    return .{
        .objective_delta_us = objective_delta_us,
        .objective_avg_speedup = speedup_sum / @as(f64, @floatFromInt(count)),
    };
}

fn scoreBetter(lhs: CandidateScore, rhs: CandidateScore) bool {
    const delta_eps = 0.001;
    if (lhs.objective_delta_us > rhs.objective_delta_us + delta_eps) return true;
    if (rhs.objective_delta_us > lhs.objective_delta_us + delta_eps) return false;
    return lhs.objective_avg_speedup > rhs.objective_avg_speedup;
}

fn writeResultFile(
    al: std.mem.Allocator,
    out_path: []const u8,
    best: Best,
) !void {
    const content = try std.fmt.allocPrint(
        al,
        \\# hoist pgo tuning result
        \\# tested={d} passed={d}
        \\# objective_delta_us={d:.2}
        \\# objective_avg_speedup={d:.4}
        \\export HOIST_ALIAS_MIN_COMPLEXITY={d}
        \\export HOIST_RANGE_MIN_COMPLEXITY={d}
        \\export HOIST_EGRAPH_MIN_COMPLEXITY={d}
        \\export HOIST_FOLD_IADD_ICONST_MIN_INSTS={d}
        \\
    ,
        .{
            best.tested,
            best.passed,
            best.score.objective_delta_us,
            best.score.objective_avg_speedup,
            best.cfg.alias_min_complexity,
            best.cfg.range_min_complexity,
            best.cfg.egraph_min_complexity,
            best.cfg.fold_iadd_iconst_min_insts,
        },
    );
    defer al.free(content);
    try std.fs.cwd().writeFile(.{ .sub_path = out_path, .data = content });
}

fn printUsage() void {
    std.debug.print(
        \\usage: pgo_tune --baseline-bin <path> --perf-gate-bin <path> --bench <path>... [options]
        \\required:
        \\  --baseline-bin <path>     path to baseline executable
        \\  --perf-gate-bin <path>    path to perf_gate executable
        \\  --bench <path>            bench executable (repeat for all benches)
        \\options:
        \\  --baseline-log <path>     baseline log path (default: /tmp/hoist-baseline.log)
        \\  --current-log <path>      candidate log path (default: /tmp/hoist-pgo-current.log)
        \\  --report-out <path>       gate markdown report (default: /tmp/hoist-pgo-report.md)
        \\  --json-out <path>         gate json report (default: /tmp/hoist-pgo-report.json)
        \\  --result-out <path>       tuned env output file (default: /tmp/hoist-pgo.env)
        \\  --repeat <n>              benchmark repeats (default: 5)
        \\  --alias-list <csv>        alias thresholds (default: 96,128,160,192)
        \\  --range-list <csv>        range thresholds (default: 96,128,160,192)
        \\  --egraph-list <csv>       egraph thresholds (default: 64,96,128,160)
        \\  --fold-list <csv>         fold thresholds (default: 512,1000,1536,2048)
        \\  --max-regress-pct <f64>   gate max regression pct (default: 5)
        \\  --min-regress-us <f64>    gate min regression us (default: 2)
        \\  --min-positive-pct <f64>  gate required positive pct (default: 5)
        \\  --min-positive-us <f64>   gate required positive us (default: 2)
        \\  --min-positive-count <n>  gate required positive metric count (default: 1)
        \\
    , .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const al = gpa.allocator();

    const args = try std.process.argsAlloc(al);
    defer std.process.argsFree(al, args);

    var baseline_bin_opt: ?[]const u8 = null;
    var perf_gate_bin_opt: ?[]const u8 = null;
    var baseline_log: []const u8 = "/tmp/hoist-baseline.log";
    var current_log: []const u8 = "/tmp/hoist-pgo-current.log";
    var report_out: []const u8 = "/tmp/hoist-pgo-report.md";
    var json_out: []const u8 = "/tmp/hoist-pgo-report.json";
    var result_out: []const u8 = "/tmp/hoist-pgo.env";
    var repeat: usize = 5;
    var alias_list_csv: ?[]const u8 = null;
    var range_list_csv: ?[]const u8 = null;
    var egraph_list_csv: ?[]const u8 = null;
    var fold_list_csv: ?[]const u8 = null;
    var max_regress_pct: f64 = 5.0;
    var min_regress_us: f64 = 2.0;
    var min_positive_pct: f64 = 5.0;
    var min_positive_us: f64 = 2.0;
    var min_positive_count: usize = 1;
    var benches = std.ArrayList([]const u8){};
    defer benches.deinit(al);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help")) {
            printUsage();
            return;
        }
        if (std.mem.eql(u8, arg, "--baseline-bin")) {
            baseline_bin_opt = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--perf-gate-bin")) {
            perf_gate_bin_opt = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--bench")) {
            try benches.append(al, try parseArgString(args, &i));
        } else if (std.mem.eql(u8, arg, "--baseline-log")) {
            baseline_log = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--current-log")) {
            current_log = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--report-out")) {
            report_out = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--json-out")) {
            json_out = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--result-out")) {
            result_out = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--repeat")) {
            repeat = try parseArgUnsigned(usize, args, &i);
        } else if (std.mem.eql(u8, arg, "--alias-list")) {
            alias_list_csv = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--range-list")) {
            range_list_csv = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--egraph-list")) {
            egraph_list_csv = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--fold-list")) {
            fold_list_csv = try parseArgString(args, &i);
        } else if (std.mem.eql(u8, arg, "--max-regress-pct")) {
            max_regress_pct = try parseArgFloat(args, &i);
        } else if (std.mem.eql(u8, arg, "--min-regress-us")) {
            min_regress_us = try parseArgFloat(args, &i);
        } else if (std.mem.eql(u8, arg, "--min-positive-pct")) {
            min_positive_pct = try parseArgFloat(args, &i);
        } else if (std.mem.eql(u8, arg, "--min-positive-us")) {
            min_positive_us = try parseArgFloat(args, &i);
        } else if (std.mem.eql(u8, arg, "--min-positive-count")) {
            min_positive_count = try parseArgUnsigned(usize, args, &i);
        } else {
            std.debug.print("unknown arg: {s}\n", .{arg});
            printUsage();
            return error.InvalidArgs;
        }
    }

    const baseline_bin = baseline_bin_opt orelse {
        printUsage();
        return error.InvalidArgs;
    };
    const perf_gate_bin = perf_gate_bin_opt orelse {
        printUsage();
        return error.InvalidArgs;
    };
    if (benches.items.len == 0) {
        printUsage();
        return error.InvalidArgs;
    }
    if (repeat == 0) return error.InvalidArgs;

    const alias_defaults = [_]u32{ 96, 128, 160, 192 };
    const range_defaults = [_]u32{ 96, 128, 160, 192 };
    const egraph_defaults = [_]u32{ 64, 96, 128, 160 };
    const fold_defaults = [_]usize{ 512, 1000, 1536, 2048 };

    const alias_values = try parseUnsignedList(u32, al, alias_list_csv, &alias_defaults);
    defer al.free(alias_values);
    const range_values = try parseUnsignedList(u32, al, range_list_csv, &range_defaults);
    defer al.free(range_values);
    const egraph_values = try parseUnsignedList(u32, al, egraph_list_csv, &egraph_defaults);
    defer al.free(egraph_values);
    const fold_values = try parseUnsignedList(usize, al, fold_list_csv, &fold_defaults);
    defer al.free(fold_values);

    var best_opt: ?Best = null;
    var tested: usize = 0;
    var passed: usize = 0;

    for (alias_values) |alias_min| {
        for (range_values) |range_min| {
            for (egraph_values) |egraph_min| {
                for (fold_values) |fold_min| {
                    tested += 1;
                    const candidate = Candidate{
                        .alias_min_complexity = alias_min,
                        .range_min_complexity = range_min,
                        .egraph_min_complexity = egraph_min,
                        .fold_iadd_iconst_min_insts = fold_min,
                    };

                    var env_map = try std.process.getEnvMap(al);
                    defer env_map.deinit();
                    try setEnvUnsigned(u32, al, &env_map, "HOIST_ALIAS_MIN_COMPLEXITY", candidate.alias_min_complexity);
                    try setEnvUnsigned(u32, al, &env_map, "HOIST_RANGE_MIN_COMPLEXITY", candidate.range_min_complexity);
                    try setEnvUnsigned(u32, al, &env_map, "HOIST_EGRAPH_MIN_COMPLEXITY", candidate.egraph_min_complexity);
                    try setEnvUnsigned(usize, al, &env_map, "HOIST_FOLD_IADD_ICONST_MIN_INSTS", candidate.fold_iadd_iconst_min_insts);

                    const baseline_run = try runBaseline(
                        al,
                        baseline_bin,
                        current_log,
                        repeat,
                        benches.items,
                        &env_map,
                    );
                    defer al.free(baseline_run.stderr);
                    if (baseline_run.code != 0) {
                        std.debug.print(
                            "candidate failed benchmark run: alias={d} range={d} egraph={d} fold={d}\n{s}\n",
                            .{
                                candidate.alias_min_complexity,
                                candidate.range_min_complexity,
                                candidate.egraph_min_complexity,
                                candidate.fold_iadd_iconst_min_insts,
                                baseline_run.stderr,
                            },
                        );
                        continue;
                    }

                    const gate_run = try runPerfGate(
                        al,
                        perf_gate_bin,
                        baseline_log,
                        current_log,
                        report_out,
                        json_out,
                        max_regress_pct,
                        min_regress_us,
                        min_positive_pct,
                        min_positive_us,
                        min_positive_count,
                    );
                    defer al.free(gate_run.stderr);
                    if (gate_run.code != 0) continue;

                    var parsed = try readGateReport(al, json_out);
                    defer parsed.deinit();
                    if (!std.mem.eql(u8, parsed.value.status, "PASS")) continue;

                    const score = try scoreReport(parsed.value);
                    passed += 1;

                    const candidate_best = Best{
                        .cfg = candidate,
                        .score = score,
                        .positive_wins = parsed.value.positive_wins,
                        .tested = tested,
                        .passed = passed,
                    };
                    if (best_opt == null or scoreBetter(score, best_opt.?.score)) {
                        best_opt = candidate_best;
                    }
                }
            }
        }
    }

    const best = best_opt orelse {
        std.debug.print("no passing candidate; tested {d}\n", .{tested});
        return error.NoPassingCandidate;
    };

    var best_env = try std.process.getEnvMap(al);
    defer best_env.deinit();
    try setEnvUnsigned(u32, al, &best_env, "HOIST_ALIAS_MIN_COMPLEXITY", best.cfg.alias_min_complexity);
    try setEnvUnsigned(u32, al, &best_env, "HOIST_RANGE_MIN_COMPLEXITY", best.cfg.range_min_complexity);
    try setEnvUnsigned(u32, al, &best_env, "HOIST_EGRAPH_MIN_COMPLEXITY", best.cfg.egraph_min_complexity);
    try setEnvUnsigned(usize, al, &best_env, "HOIST_FOLD_IADD_ICONST_MIN_INSTS", best.cfg.fold_iadd_iconst_min_insts);

    const rerun_baseline = try runBaseline(
        al,
        baseline_bin,
        current_log,
        repeat,
        benches.items,
        &best_env,
    );
    defer al.free(rerun_baseline.stderr);
    if (rerun_baseline.code != 0) {
        std.debug.print("best candidate rerun failed:\n{s}\n", .{rerun_baseline.stderr});
        return error.BenchFailed;
    }

    const rerun_gate = try runPerfGate(
        al,
        perf_gate_bin,
        baseline_log,
        current_log,
        report_out,
        json_out,
        max_regress_pct,
        min_regress_us,
        min_positive_pct,
        min_positive_us,
        min_positive_count,
    );
    defer al.free(rerun_gate.stderr);
    if (rerun_gate.code != 0) {
        std.debug.print("best candidate failed gate rerun:\n{s}\n", .{rerun_gate.stderr});
        return error.RegressionDetected;
    }

    try writeResultFile(al, result_out, .{
        .cfg = best.cfg,
        .score = best.score,
        .positive_wins = best.positive_wins,
        .tested = tested,
        .passed = passed,
    });

    std.debug.print(
        "best candidate: alias={d} range={d} egraph={d} fold={d} wins={d}\n",
        .{
            best.cfg.alias_min_complexity,
            best.cfg.range_min_complexity,
            best.cfg.egraph_min_complexity,
            best.cfg.fold_iadd_iconst_min_insts,
            best.positive_wins,
        },
    );
    std.debug.print(
        "objective gain: {d:.2}us, avg speedup: {d:.4}x, tested={d}, passed={d}\n",
        .{
            best.score.objective_delta_us,
            best.score.objective_avg_speedup,
            tested,
            passed,
        },
    );
    std.debug.print("result file: {s}\n", .{result_out});
    std.debug.print("bench log: {s}\nreport: {s}\njson: {s}\n", .{
        current_log,
        report_out,
        json_out,
    });
}
