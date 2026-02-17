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
    status: []const u8,
    regressions: usize,
    metrics: [metric_ids.len]JsonMetric,
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
    var max_regress_pct: f64 = 5.0;

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
        } else if (std.mem.eql(u8, arg, "--max-regress-pct")) {
            if (i + 1 >= args.len) return error.InvalidArgs;
            max_regress_pct = try std.fmt.parseFloat(f64, args[i + 1]);
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

    const baseline_text = try std.fs.cwd().readFileAlloc(al, baseline_file, 16 * 1024 * 1024);
    defer al.free(baseline_text);
    const current_text = try std.fs.cwd().readFileAlloc(al, current_file, 16 * 1024 * 1024);
    defer al.free(current_text);

    var baseline = try parseMetrics(al, baseline_text);
    defer baseline.deinit(al);
    try baseline.requireComplete();

    var current = try parseMetrics(al, current_text);
    defer current.deinit(al);
    try current.requireComplete();

    var results: [metric_ids.len]MetricResult = undefined;
    var regressions: usize = 0;

    for (metric_ids, 0..) |id, idx| {
        const b_med = try baseline.median(id);
        const c_med = try current.median(id);
        const delta_pct = deltaPercent(b_med, c_med);
        const reg = delta_pct > max_regress_pct;
        regressions += @intFromBool(reg);
        results[idx] = .{
            .id = id,
            .baseline_median_us = b_med,
            .current_median_us = c_med,
            .delta_pct = delta_pct,
            .baseline_n = baseline.count(id),
            .current_n = current.count(id),
            .regression = reg,
        };
    }

    const status = if (regressions == 0) "PASS" else "FAIL";

    var report = std.ArrayList(u8){};
    defer report.deinit(al);
    const w = report.writer(al);
    try w.print("# Hoist Perf Gate Report\n\n", .{});
    try w.print("- Baseline: `{s}`\n", .{baseline_file});
    try w.print("- Current: `{s}`\n", .{current_file});
    try w.print("- Max allowed regression: {d:.2}%\n\n", .{max_regress_pct});
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

    std.debug.print("perf report written: {s}\n", .{out_path});
    if (regressions != 0) return error.PerfRegression;
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
