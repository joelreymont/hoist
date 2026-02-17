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

const Metrics = struct {
    values: [metric_ids.len]?u64 = [_]?u64{null} ** metric_ids.len,

    fn set(self: *Metrics, id: MetricId, value: u64) void {
        self.values[@intFromEnum(id)] = value;
    }

    fn get(self: *const Metrics, id: MetricId) ?u64 {
        return self.values[@intFromEnum(id)];
    }

    fn requireComplete(self: *const Metrics) !void {
        for (metric_ids) |id| {
            if (self.get(id) == null) {
                std.debug.print("missing metric: {s}\n", .{metricName(id)});
                return error.MissingMetric;
            }
        }
    }
};

const Section = enum {
    int,
    vector,
    memory,
    mixed,
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

    const baseline = try parseMetrics(baseline_text);
    try baseline.requireComplete();
    const current = try parseMetrics(current_text);
    try current.requireComplete();

    var report = std.ArrayList(u8){};
    defer report.deinit(al);
    try report.writer(al).print("# Hoist Perf Gate Report\n\n", .{});
    try report.writer(al).print("- Baseline: `{s}`\n", .{baseline_file});
    try report.writer(al).print("- Current: `{s}`\n", .{current_file});
    try report.writer(al).print("- Max allowed regression: {d:.2}%\n\n", .{max_regress_pct});
    try report.appendSlice(al, "| Metric | Baseline (us) | Current (us) | Delta % |\n");
    try report.appendSlice(al, "|---|---:|---:|---:|\n");

    var regressions: usize = 0;
    for (metric_ids) |id| {
        const b = baseline.get(id).?;
        const c = current.get(id).?;
        const delta_pct = deltaPercent(b, c);
        if (delta_pct > max_regress_pct) regressions += 1;
        try report.writer(al).print("| {s} | {d} | {d} | {d:.2}% |\n", .{
            metricName(id),
            b,
            c,
            delta_pct,
        });
    }

    const status = if (regressions == 0) "PASS" else "FAIL";
    try report.writer(al).print("\nStatus: **{s}** ({d} regressions)\n", .{ status, regressions });

    var out_file = try std.fs.createFileAbsolute(out_path, .{ .truncate = true });
    defer out_file.close();
    try out_file.writeAll(report.items);
    try out_file.sync();

    std.debug.print("perf report written: {s}\n", .{out_path});
    if (regressions != 0) return error.PerfRegression;
}

fn parseMetrics(text: []const u8) !Metrics {
    var out = Metrics{};
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
            out.set(.fib_compile_us, v);
            continue;
        }

        if (std.mem.startsWith(u8, line, "Size")) {
            const size = parseFirstUnsignedAfter(line, "Size") orelse return error.ParseFailed;
            const compile_us = parseFirstUnsignedAfter(line, "compile") orelse return error.ParseFailed;
            switch (size) {
                100 => out.set(.large_100_compile_us, compile_us),
                500 => out.set(.large_500_compile_us, compile_us),
                1000 => out.set(.large_1000_compile_us, compile_us),
                5000 => out.set(.large_5000_compile_us, compile_us),
                else => {},
            }
            continue;
        }

        if (std.mem.startsWith(u8, line, "Avg compile time:")) {
            const v = parseFirstUnsignedAfter(line, "Avg compile time:") orelse return error.ParseFailed;
            const s = section orelse continue;
            switch (s) {
                .int => out.set(.int_compile_us, v),
                .vector => out.set(.vector_compile_us, v),
                .memory => out.set(.memory_compile_us, v),
                .mixed => out.set(.mixed_compile_us, v),
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

fn deltaPercent(baseline: u64, current: u64) f64 {
    if (baseline == 0) return 0.0;
    const b = @as(f64, @floatFromInt(baseline));
    const c = @as(f64, @floatFromInt(current));
    return ((c - b) / b) * 100.0;
}
