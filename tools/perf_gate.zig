const std = @import("std");

const MetricId = enum(u8) {
    fib_compile_us,
    large_100_compile_us,
    large_500_compile_us,
    large_1000_compile_us,
    large_5000_compile_us,
    int_compile_us,
    vector_compile_us,
    memory_compile_us,
    mixed_compile_us,
    serial_batch_compile_us,
    parallel_batch_compile_us,
};

const metric_ids = [_]MetricId{
    .fib_compile_us,
    .large_100_compile_us,
    .large_500_compile_us,
    .large_1000_compile_us,
    .large_5000_compile_us,
    .int_compile_us,
    .vector_compile_us,
    .memory_compile_us,
    .mixed_compile_us,
    .serial_batch_compile_us,
    .parallel_batch_compile_us,
};

const budget_metric_ids = [_]MetricId{
    .fib_compile_us,
    .large_5000_compile_us,
    .int_compile_us,
    .vector_compile_us,
    .memory_compile_us,
    .mixed_compile_us,
};

fn metricName(id: MetricId) []const u8 {
    return switch (id) {
        .fib_compile_us => "fib avg compile (us)",
        .large_100_compile_us => "large(100) compile (us)",
        .large_500_compile_us => "large(500) compile (us)",
        .large_1000_compile_us => "large(1000) compile (us)",
        .large_5000_compile_us => "large(5000) compile (us)",
        .int_compile_us => "aarch64 int avg compile (us)",
        .vector_compile_us => "aarch64 vector avg compile (us)",
        .memory_compile_us => "aarch64 memory avg compile (us)",
        .mixed_compile_us => "aarch64 mixed avg compile (us)",
        .serial_batch_compile_us => "serial batch compile (us)",
        .parallel_batch_compile_us => "parallel batch compile (us)",
    };
}

const MetricResult = struct {
    id: MetricId,
    baseline_median_us: f64,
    current_median_us: f64,
    delta_pct: f64,
    baseline_n: usize,
    current_n: usize,
    regression: bool,
    improvement: bool,
};

const BudgetViolation = struct {
    id: MetricId,
    reference_median_us: f64,
    target_max_us: f64,
    current_median_us: f64,
};

const MetricSamples = struct {
    values: [metric_ids.len]std.ArrayListUnmanaged(u64) = [_]std.ArrayListUnmanaged(u64){.{}} ** metric_ids.len,

    fn deinit(self: *MetricSamples, al: std.mem.Allocator) void {
        for (&self.values) |*list| list.deinit(al);
    }

    fn add(self: *MetricSamples, al: std.mem.Allocator, id: MetricId, value: u64) !void {
        try self.values[@intFromEnum(id)].append(al, value);
    }

    fn slice(self: *const MetricSamples, id: MetricId) []const u64 {
        return self.values[@intFromEnum(id)].items;
    }

    fn count(self: *const MetricSamples, id: MetricId) usize {
        return self.slice(id).len;
    }

    fn requireComplete(self: *const MetricSamples) !void {
        var expected_count: ?usize = null;
        for (metric_ids) |id| {
            const n = self.count(id);
            if (n == 0) {
                std.debug.print("missing metric: {s}\n", .{metricName(id)});
                return error.MissingMetric;
            }
            if (expected_count == null) {
                expected_count = n;
                continue;
            }
            if (n != expected_count.?) {
                std.debug.print(
                    "inconsistent samples for {s}: got {d}, expected {d}\n",
                    .{ metricName(id), n, expected_count.? },
                );
                return error.InconsistentMetricSamples;
            }
        }
    }

    fn median(self: *MetricSamples, id: MetricId) !f64 {
        const idx = @intFromEnum(id);
        const items = self.values[idx].items;
        if (items.len == 0) return error.MissingMetric;

        std.mem.sort(u64, items, {}, lessThanU64);
        const mid = items.len / 2;
        if ((items.len & 1) == 1) {
            return @as(f64, @floatFromInt(items[mid]));
        }
        const left = @as(f64, @floatFromInt(items[mid - 1]));
        const right = @as(f64, @floatFromInt(items[mid]));
        return (left + right) / 2.0;
    }
};

const Section = enum {
    int,
    vector,
    memory,
    mixed,
};

const JsonMetric = struct {
    id: []const u8,
    baseline_median_us: f64,
    current_median_us: f64,
    delta_pct: f64,
    baseline_n: usize,
    current_n: usize,
    baseline_samples_us: []const u64,
    current_samples_us: []const u64,
    regression: bool,
};

const JsonReport = struct {
    baseline: []const u8,
    current: []const u8,
    max_regress_pct: f64,
    min_regress_us: f64,
    min_positive_pct: f64,
    min_positive_us: f64,
    min_positive_count: usize,
    positive_wins: usize,
    insufficient_gain: bool,
    status: []const u8,
    regressions: usize,
    metrics: [metric_ids.len]JsonMetric,
};

const HistoryMetric = struct {
    id: []const u8,
    baseline_median_us: f64,
    current_median_us: f64,
    delta_pct: f64,
    regression: bool,
};

const HistoryEntry = struct {
    timestamp_unix: i64,
    baseline: []const u8,
    current: []const u8,
    max_regress_pct: f64,
    min_regress_us: f64,
    min_positive_pct: f64,
    min_positive_us: f64,
    min_positive_count: usize,
    positive_wins: usize,
    insufficient_gain: bool,
    status: []const u8,
    regressions: usize,
    metrics: [metric_ids.len]HistoryMetric,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const al = gpa.allocator();

    const args = try std.process.argsAlloc(al);
    defer std.process.argsFree(al, args);

    var baseline_path: ?[]const u8 = null;
    var current_path: ?[]const u8 = null;
    var out_path: []const u8 = "/tmp/hoist-bench-report.md";
    var json_out_path: ?[]const u8 = null;
    var history_json_path: ?[]const u8 = null;
    var budget_reference_path: ?[]const u8 = null;
    var budget_multiplier: ?f64 = null;
    var max_regress_pct: f64 = 5.0;
    var min_regress_us: f64 = 2.0;
    var min_positive_pct: f64 = 0.0;
    var min_positive_us: f64 = 2.0;
    var min_positive_count: usize = 0;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--baseline")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            baseline_path = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, arg, "--current")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            current_path = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, arg, "--out")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            out_path = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, arg, "--json-out")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            json_out_path = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, arg, "--history-json")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            history_json_path = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, arg, "--budget-reference")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            budget_reference_path = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, arg, "--budget-multiplier")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            budget_multiplier = try std.fmt.parseFloat(f64, args[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--max-regress-pct")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            max_regress_pct = try std.fmt.parseFloat(f64, args[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--min-regress-us")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            min_regress_us = try std.fmt.parseFloat(f64, args[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--min-positive-pct")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            min_positive_pct = try std.fmt.parseFloat(f64, args[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--min-positive-us")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            min_positive_us = try std.fmt.parseFloat(f64, args[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "--min-positive-count")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            min_positive_count = try std.fmt.parseUnsigned(usize, args[i + 1], 10);
            i += 1;
        } else {
            std.debug.print("unknown arg: {s}\n", .{arg});
            return error.InvalidArgs;
        }
    }

    const baseline_file = baseline_path orelse {
        std.debug.print("missing --baseline <path>\n", .{});
        return error.InvalidArgs;
    };
    const current_file = current_path orelse {
        std.debug.print("missing --current <path>\n", .{});
        return error.InvalidArgs;
    };
    if ((budget_reference_path == null) != (budget_multiplier == null)) {
        std.debug.print("budget flags require both --budget-reference and --budget-multiplier\n", .{});
        return error.InvalidArgs;
    }
    if (budget_multiplier) |multiplier| {
        if (multiplier <= 1.0) {
            std.debug.print("--budget-multiplier must be > 1.0\n", .{});
            return error.InvalidArgs;
        }
    }
    if (min_regress_us < 0.0) {
        std.debug.print("--min-regress-us must be >= 0\n", .{});
        return error.InvalidArgs;
    }
    if (min_positive_pct < 0.0) {
        std.debug.print("--min-positive-pct must be >= 0\n", .{});
        return error.InvalidArgs;
    }
    if (min_positive_us < 0.0) {
        std.debug.print("--min-positive-us must be >= 0\n", .{});
        return error.InvalidArgs;
    }

    const baseline_text = std.fs.cwd().readFileAlloc(al, baseline_file, 16 * 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print(
                "baseline log not found: {s}\nrefresh it with: zig build baseline-log\n",
                .{baseline_file},
            );
            return err;
        },
        else => return err,
    };
    defer al.free(baseline_text);
    const current_text = std.fs.cwd().readFileAlloc(al, current_file, 16 * 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print(
                "current log not found: {s}\ngenerate it with: zig build bench-log\n",
                .{current_file},
            );
            return err;
        },
        else => return err,
    };
    defer al.free(current_text);

    var baseline = try parseMetrics(al, baseline_text);
    defer baseline.deinit(al);
    try baseline.requireComplete();

    var current = try parseMetrics(al, current_text);
    defer current.deinit(al);
    try current.requireComplete();

    var results: [metric_ids.len]MetricResult = undefined;
    var regressions: usize = 0;
    var positive_wins: usize = 0;

    for (metric_ids, 0..) |id, idx| {
        const b_med = try baseline.median(id);
        const c_med = try current.median(id);
        const delta_pct = deltaPercent(b_med, c_med);
        const reg = isRegression(b_med, c_med, max_regress_pct, min_regress_us);
        const improved = isImprovement(b_med, c_med, min_positive_pct, min_positive_us);
        regressions += @intFromBool(reg);
        positive_wins += @intFromBool(improved);
        results[idx] = .{
            .id = id,
            .baseline_median_us = b_med,
            .current_median_us = c_med,
            .delta_pct = delta_pct,
            .baseline_n = baseline.count(id),
            .current_n = current.count(id),
            .regression = reg,
            .improvement = improved,
        };
    }

    var budget_violations = std.ArrayList(BudgetViolation){};
    defer budget_violations.deinit(al);
    if (budget_reference_path) |budget_ref_file| {
        const budget_ref_text = try std.fs.cwd().readFileAlloc(al, budget_ref_file, 16 * 1024 * 1024);
        defer al.free(budget_ref_text);
        var budget_ref = try parseMetrics(al, budget_ref_text);
        defer budget_ref.deinit(al);
        try budget_ref.requireComplete();

        budget_violations = try collectBudgetViolations(al, &budget_ref, &current, budget_multiplier.?);
    }

    const budget_failed = budget_violations.items.len != 0;
    const insufficient_gain = positive_wins < min_positive_count;
    const status = if (regressions == 0 and !budget_failed and !insufficient_gain) "PASS" else "FAIL";

    var report = std.ArrayList(u8){};
    defer report.deinit(al);
    const w = report.writer(al);
    try w.print("# Hoist Perf Gate Report\n\n", .{});
    try w.print("- Baseline: `{s}`\n", .{baseline_file});
    try w.print("- Current: `{s}`\n", .{current_file});
    try w.print("- Max allowed regression: {d:.2}%\n", .{max_regress_pct});
    try w.print("- Min absolute regression: {d:.2}us\n", .{min_regress_us});
    try w.print("- Min positive improvement: {d:.2}%\n", .{min_positive_pct});
    try w.print("- Min absolute improvement: {d:.2}us\n", .{min_positive_us});
    try w.print("- Required positive wins: {d}\n", .{min_positive_count});
    if (budget_reference_path) |budget_ref_file| {
        try w.print("- Budget reference: `{s}`\n", .{budget_ref_file});
        try w.print("- Budget multiplier: {d:.2}x\n", .{budget_multiplier.?});
    }
    try w.print("\n", .{});
    try report.appendSlice(al, "| Metric | Baseline median (us) | Current median (us) | Delta % | N (b/c) |\n");
    try report.appendSlice(al, "|---|---:|---:|---:|---:|\n");

    for (results) |r| {
        try w.print("| {s} | {d:.2} | {d:.2} | {d:.2}% | {d}/{d} |\n", .{
            metricName(r.id),
            r.baseline_median_us,
            r.current_median_us,
            r.delta_pct,
            r.baseline_n,
            r.current_n,
        });
    }

    if (budget_reference_path != null) {
        try report.appendSlice(al, "\n## Budget Check\n\n");
        if (budget_failed) {
            try report.appendSlice(al, "| Metric | Current median (us) | Target max (us) | Reference median (us) |\n");
            try report.appendSlice(al, "|---|---:|---:|---:|\n");
            for (budget_violations.items) |v| {
                try w.print("| {s} | {d:.2} | {d:.2} | {d:.2} |\n", .{
                    metricName(v.id),
                    v.current_median_us,
                    v.target_max_us,
                    v.reference_median_us,
                });
                std.debug.print(
                    "budget miss: {s}: current {d:.2}us exceeds {d:.2}x target {d:.2}us (reference {d:.2}us)\n",
                    .{
                        metricName(v.id),
                        v.current_median_us,
                        budget_multiplier.?,
                        v.target_max_us,
                        v.reference_median_us,
                    },
                );
            }
            try w.print("\nBudget status: **FAIL** ({d} metrics over target)\n", .{budget_violations.items.len});
        } else {
            try report.appendSlice(al, "Budget status: **PASS** (all tracked metrics meet target)\n");
        }
    }
    if (min_positive_count != 0) {
        try w.print("\nPositive wins meeting threshold: {d}\n", .{positive_wins});
        if (insufficient_gain) {
            try w.print("Positive-gain status: **FAIL** (required {d})\n", .{min_positive_count});
        } else {
            try report.appendSlice(al, "Positive-gain status: **PASS**\n");
        }
    }

    try w.print("\nStatus: **{s}** ({d} regressions)\n", .{ status, regressions });

    var out_file = try std.fs.createFileAbsolute(out_path, .{ .truncate = true });
    defer out_file.close();
    try out_file.writeAll(report.items);
    try out_file.sync();

    if (json_out_path) |json_path| {
        var metrics_json: [metric_ids.len]JsonMetric = undefined;
        for (results, 0..) |r, idx| {
            metrics_json[idx] = .{
                .id = metricName(r.id),
                .baseline_median_us = r.baseline_median_us,
                .current_median_us = r.current_median_us,
                .delta_pct = r.delta_pct,
                .baseline_n = r.baseline_n,
                .current_n = r.current_n,
                .baseline_samples_us = baseline.slice(r.id),
                .current_samples_us = current.slice(r.id),
                .regression = r.regression,
            };
        }

        const json_report = JsonReport{
            .baseline = baseline_file,
            .current = current_file,
            .max_regress_pct = max_regress_pct,
            .min_regress_us = min_regress_us,
            .min_positive_pct = min_positive_pct,
            .min_positive_us = min_positive_us,
            .min_positive_count = min_positive_count,
            .positive_wins = positive_wins,
            .insufficient_gain = insufficient_gain,
            .status = status,
            .regressions = regressions,
            .metrics = metrics_json,
        };

        var json_file = try std.fs.createFileAbsolute(json_path, .{ .truncate = true });
        defer json_file.close();
        const json_text = try std.json.Stringify.valueAlloc(al, json_report, .{ .whitespace = .indent_2 });
        defer al.free(json_text);
        try json_file.writeAll(json_text);
        try json_file.writeAll("\n");
        try json_file.sync();
        std.debug.print("perf json written: {s}\n", .{json_path});
    }

    if (history_json_path) |history_path| {
        var metrics_history: [metric_ids.len]HistoryMetric = undefined;
        for (results, 0..) |r, idx| {
            metrics_history[idx] = .{
                .id = metricName(r.id),
                .baseline_median_us = r.baseline_median_us,
                .current_median_us = r.current_median_us,
                .delta_pct = r.delta_pct,
                .regression = r.regression,
            };
        }

        const history_entry = HistoryEntry{
            .timestamp_unix = std.time.timestamp(),
            .baseline = baseline_file,
            .current = current_file,
            .max_regress_pct = max_regress_pct,
            .min_regress_us = min_regress_us,
            .min_positive_pct = min_positive_pct,
            .min_positive_us = min_positive_us,
            .min_positive_count = min_positive_count,
            .positive_wins = positive_wins,
            .insufficient_gain = insufficient_gain,
            .status = status,
            .regressions = regressions,
            .metrics = metrics_history,
        };
        try appendHistoryEntry(al, history_path, history_entry);
        std.debug.print("perf history appended: {s}\n", .{history_path});
    }

    std.debug.print("perf report written: {s}\n", .{out_path});
    if (regressions != 0) return error.PerfRegression;
    if (budget_failed) return error.PerfBudgetMiss;
    if (insufficient_gain) return error.PerfInsufficientGain;
}

fn appendHistoryEntry(al: std.mem.Allocator, path: []const u8, entry: HistoryEntry) !void {
    const create_flags = std.fs.File.CreateFlags{ .truncate = false, .read = true };
    var file = if (std.fs.path.isAbsolute(path))
        std.fs.openFileAbsolute(path, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => try std.fs.createFileAbsolute(path, create_flags),
            else => return err,
        }
    else
        std.fs.cwd().openFile(path, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => try std.fs.cwd().createFile(path, create_flags),
            else => return err,
        };
    defer file.close();

    try file.seekFromEnd(0);
    const json_line = try std.json.Stringify.valueAlloc(al, entry, .{});
    defer al.free(json_line);
    try file.writeAll(json_line);
    try file.writeAll("\n");
    try file.sync();
}

fn collectBudgetViolations(
    al: std.mem.Allocator,
    reference: *MetricSamples,
    current: *MetricSamples,
    multiplier: f64,
) !std.ArrayList(BudgetViolation) {
    var out = std.ArrayList(BudgetViolation){};
    errdefer out.deinit(al);

    for (budget_metric_ids) |id| {
        const ref_median = try reference.median(id);
        const current_median = try current.median(id);
        const target_max = ref_median / multiplier;
        if (current_median > target_max) {
            try out.append(al, .{
                .id = id,
                .reference_median_us = ref_median,
                .target_max_us = target_max,
                .current_median_us = current_median,
            });
        }
    }

    return out;
}

fn parseMetrics(al: std.mem.Allocator, text: []const u8) !MetricSamples {
    var out = MetricSamples{};
    errdefer out.deinit(al);

    var section: ?Section = null;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, "Integer Arithmetic Benchmark")) {
            section = .int;
            continue;
        }
        if (std.mem.startsWith(u8, line, "Vector Operations Benchmark")) {
            section = .vector;
            continue;
        }
        if (std.mem.startsWith(u8, line, "Memory Operations Benchmark")) {
            section = .memory;
            continue;
        }
        if (std.mem.startsWith(u8, line, "Mixed Workload Benchmark")) {
            section = .mixed;
            continue;
        }

        if (std.mem.startsWith(u8, line, "Avg compilation:")) {
            const v = parseFirstUnsignedAfter(line, "Avg compilation:") orelse return error.ParseFailed;
            try out.add(al, .fib_compile_us, v);
            continue;
        }

        if (std.mem.startsWith(u8, line, "Size")) {
            const size = parseFirstUnsignedAfter(line, "Size") orelse return error.ParseFailed;
            const compile_us = parseFirstUnsignedAfter(line, "compile") orelse return error.ParseFailed;
            switch (size) {
                100 => try out.add(al, .large_100_compile_us, compile_us),
                500 => try out.add(al, .large_500_compile_us, compile_us),
                1000 => try out.add(al, .large_1000_compile_us, compile_us),
                5000 => try out.add(al, .large_5000_compile_us, compile_us),
                else => {},
            }
            continue;
        }

        if (std.mem.startsWith(u8, line, "Avg compile time:")) {
            const v = parseFirstUnsignedAfter(line, "Avg compile time:") orelse return error.ParseFailed;
            const s = section orelse continue;
            switch (s) {
                .int => try out.add(al, .int_compile_us, v),
                .vector => try out.add(al, .vector_compile_us, v),
                .memory => try out.add(al, .memory_compile_us, v),
                .mixed => try out.add(al, .mixed_compile_us, v),
            }
            continue;
        }

        if (std.mem.startsWith(u8, line, "Serial batch compile:")) {
            const v = parseFirstUnsignedAfter(line, "Serial batch compile:") orelse return error.ParseFailed;
            try out.add(al, .serial_batch_compile_us, v);
            continue;
        }

        if (std.mem.startsWith(u8, line, "Parallel batch compile:")) {
            const v = parseFirstUnsignedAfter(line, "Parallel batch compile:") orelse return error.ParseFailed;
            try out.add(al, .parallel_batch_compile_us, v);
            continue;
        }
    }

    return out;
}

fn parseFirstUnsignedAfter(line: []const u8, needle: []const u8) ?u64 {
    const idx = std.mem.indexOf(u8, line, needle) orelse return null;
    var i = idx + needle.len;
    while (i < line.len and !std.ascii.isDigit(line[i])) : (i += 1) {}
    if (i >= line.len) return null;

    const start = i;
    while (i < line.len and std.ascii.isDigit(line[i])) : (i += 1) {}
    return std.fmt.parseUnsigned(u64, line[start..i], 10) catch null;
}

fn lessThanU64(_: void, a: u64, b: u64) bool {
    return a < b;
}

fn deltaPercent(baseline: f64, current: f64) f64 {
    if (baseline == 0.0) return 0.0;
    return ((current - baseline) / baseline) * 100.0;
}

fn isRegression(baseline: f64, current: f64, max_regress_pct: f64, min_regress_us: f64) bool {
    return deltaPercent(baseline, current) > max_regress_pct and
        (current - baseline) > min_regress_us;
}

fn isImprovement(baseline: f64, current: f64, min_positive_pct: f64, min_positive_us: f64) bool {
    return -deltaPercent(baseline, current) >= min_positive_pct and
        (baseline - current) >= min_positive_us;
}

test "appendHistoryEntry appends JSON lines" {
    const testing = std.testing;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const rel_path = try std.fmt.bufPrint(&path_buf, ".zig-cache/tmp/{s}/hist.jsonl", .{tmp.sub_path});

    var metrics: [metric_ids.len]HistoryMetric = undefined;
    for (&metrics, metric_ids) |*m, id| {
        m.* = .{
            .id = metricName(id),
            .baseline_median_us = 100,
            .current_median_us = 90,
            .delta_pct = -10,
            .regression = false,
        };
    }

    const entry1 = HistoryEntry{
        .timestamp_unix = 1,
        .baseline = "b1",
        .current = "c1",
        .max_regress_pct = 5.0,
        .min_regress_us = 2.0,
        .min_positive_pct = 5.0,
        .min_positive_us = 2.0,
        .min_positive_count = 1,
        .positive_wins = 2,
        .insufficient_gain = false,
        .status = "PASS",
        .regressions = 0,
        .metrics = metrics,
    };
    const entry2 = HistoryEntry{
        .timestamp_unix = 2,
        .baseline = "b2",
        .current = "c2",
        .max_regress_pct = 5.0,
        .min_regress_us = 2.0,
        .min_positive_pct = 5.0,
        .min_positive_us = 2.0,
        .min_positive_count = 1,
        .positive_wins = 2,
        .insufficient_gain = false,
        .status = "PASS",
        .regressions = 0,
        .metrics = metrics,
    };

    try appendHistoryEntry(testing.allocator, rel_path, entry1);
    try appendHistoryEntry(testing.allocator, rel_path, entry2);

    const text = try std.fs.cwd().readFileAlloc(testing.allocator, rel_path, 1024 * 1024);
    defer testing.allocator.free(text);

    var line_count: usize = 0;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        line_count += 1;
        var parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, line, .{});
        defer parsed.deinit();
    }
    try testing.expectEqual(@as(usize, 2), line_count);
}

test "collectBudgetViolations flags breaches" {
    const testing = std.testing;

    var reference = MetricSamples{};
    defer reference.deinit(testing.allocator);
    var current = MetricSamples{};
    defer current.deinit(testing.allocator);

    for (metric_ids) |id| {
        try reference.add(testing.allocator, id, 100);
        try current.add(testing.allocator, id, 40);
    }
    // Breach fib for a 2x goal (target max 50us).
    current.values[@intFromEnum(MetricId.fib_compile_us)].items[0] = 70;

    var violations = try collectBudgetViolations(testing.allocator, &reference, &current, 2.0);
    defer violations.deinit(testing.allocator);

    try testing.expect(violations.items.len >= 1);
    try testing.expectEqual(MetricId.fib_compile_us, violations.items[0].id);
}

test "isRegression requires percent and absolute thresholds" {
    try std.testing.expect(!isRegression(100.0, 106.0, 5.0, 10.0));
    try std.testing.expect(!isRegression(100.0, 103.0, 5.0, 2.0));
    try std.testing.expect(isRegression(100.0, 111.0, 5.0, 2.0));
}

test "isImprovement requires percent and absolute thresholds" {
    try std.testing.expect(!isImprovement(100.0, 96.0, 5.0, 2.0));
    try std.testing.expect(!isImprovement(100.0, 94.0, 5.0, 10.0));
    try std.testing.expect(isImprovement(100.0, 94.0, 5.0, 2.0));
}
