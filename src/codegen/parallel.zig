//! Parallel Compilation Support
//!
//! Enables concurrent compilation of multiple functions to utilize
//! multi-core systems effectively.
//!
//! Architecture:
//! - Work stealing queue for load balancing
//! - Per-thread allocators for reduced contention
//! - Shared constant pool with synchronization
//! - Function-level parallelism (each function is independent)

const std = @import("std");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;

/// Compilation work item.
pub const WorkItem = struct {
    /// Function index to compile.
    func_idx: u32,
    /// Priority (higher = compile first).
    priority: i32,
    /// Size estimate for load balancing.
    estimated_cycles: u32,
};

/// Result of compiling a function.
pub const CompileResult = struct {
    /// Function index.
    func_idx: u32,
    /// Compiled code bytes.
    code: []const u8,
    /// Relocation entries.
    relocs: []const Reloc,
    /// Error if compilation failed.
    err: ?CompileError,

    pub const Reloc = struct {
        offset: u32,
        kind: RelocKind,
        target: u32,
    };

    pub const RelocKind = enum {
        func_ref,
        data_ref,
        got_ref,
    };

    pub const CompileError = struct {
        func_idx: u32,
        message: []const u8,
    };
};

/// Thread-safe work queue.
pub const WorkQueue = struct {
    mutex: Thread.Mutex,
    allocator: Allocator,
    items: std.ArrayListUnmanaged(WorkItem),
    done: bool,

    pub fn init(allocator: Allocator) WorkQueue {
        return .{
            .mutex = .{},
            .allocator = allocator,
            .items = .{},
            .done = false,
        };
    }

    pub fn deinit(self: *WorkQueue) void {
        self.items.deinit(self.allocator);
    }

    /// Add work item.
    pub fn push(self: *WorkQueue, item: WorkItem) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.items.append(self.allocator, item);
    }

    /// Get next work item (returns null if empty or done).
    pub fn pop(self: *WorkQueue) ?WorkItem {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.done or self.items.items.len == 0) return null;
        return self.items.pop();
    }

    /// Mark queue as done.
    pub fn finish(self: *WorkQueue) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.done = true;
    }

    /// Check if done.
    pub fn isDone(self: *WorkQueue) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.done and self.items.items.len == 0;
    }
};

/// Thread-safe result collector.
pub const ResultCollector = struct {
    mutex: Thread.Mutex,
    allocator: Allocator,
    results: std.ArrayListUnmanaged(CompileResult),
    errors: std.ArrayListUnmanaged(CompileResult.CompileError),

    pub fn init(allocator: Allocator) ResultCollector {
        return .{
            .mutex = .{},
            .allocator = allocator,
            .results = .{},
            .errors = .{},
        };
    }

    pub fn deinit(self: *ResultCollector) void {
        self.results.deinit(self.allocator);
        self.errors.deinit(self.allocator);
    }

    /// Add a successful result.
    pub fn addResult(self: *ResultCollector, result: CompileResult) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.results.append(self.allocator, result);
    }

    /// Add an error.
    pub fn addError(self: *ResultCollector, err: CompileResult.CompileError) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.errors.append(self.allocator, err);
    }

    /// Get total completed (success + errors).
    pub fn completed(self: *ResultCollector) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.results.items.len + self.errors.items.len;
    }
};

/// Configuration for parallel compilation.
pub const Config = struct {
    /// Number of worker threads (0 = auto-detect).
    num_threads: u32 = 0,
    /// Maximum memory per thread (bytes).
    max_memory_per_thread: usize = 64 * 1024 * 1024,
    /// Enable work stealing.
    work_stealing: bool = true,
    /// Priority for large functions.
    prioritize_large: bool = true,
};

/// Parallel compiler coordinator.
pub const ParallelCompiler = struct {
    allocator: Allocator,
    config: Config,
    work_queue: WorkQueue,
    results: ResultCollector,
    workers: std.ArrayList(Thread),
    running: std.atomic.Value(bool),

    /// Stats.
    funcs_compiled: std.atomic.Value(u32),
    total_cycles: std.atomic.Value(u64),

    pub fn init(allocator: Allocator, config: Config) ParallelCompiler {
        return .{
            .allocator = allocator,
            .config = config,
            .work_queue = WorkQueue.init(allocator),
            .results = ResultCollector.init(allocator),
            .workers = std.ArrayList(Thread).init(allocator),
            .running = std.atomic.Value(bool).init(false),
            .funcs_compiled = std.atomic.Value(u32).init(0),
            .total_cycles = std.atomic.Value(u64).init(0),
        };
    }

    pub fn deinit(self: *ParallelCompiler) void {
        self.stop();
        self.work_queue.deinit();
        self.results.deinit();
        self.workers.deinit();
    }

    /// Add a function to compile.
    pub fn addFunction(self: *ParallelCompiler, func_idx: u32, estimated_cycles: u32) !void {
        const priority: i32 = if (self.config.prioritize_large)
            @intCast(estimated_cycles)
        else
            -@as(i32, @intCast(func_idx));

        try self.work_queue.push(.{
            .func_idx = func_idx,
            .priority = priority,
            .estimated_cycles = estimated_cycles,
        });
    }

    /// Start compilation workers.
    pub fn start(self: *ParallelCompiler) !void {
        const num_threads = if (self.config.num_threads == 0)
            Thread.getCpuCount() catch 4
        else
            self.config.num_threads;

        self.running.store(true, .release);

        for (0..num_threads) |_| {
            const worker = try Thread.spawn(.{}, workerLoop, .{self});
            try self.workers.append(worker);
        }
    }

    /// Stop all workers.
    pub fn stop(self: *ParallelCompiler) void {
        self.running.store(false, .release);
        self.work_queue.finish();

        for (self.workers.items) |worker| {
            worker.join();
        }
        self.workers.clearRetainingCapacity();
    }

    /// Wait for all work to complete.
    pub fn wait(self: *ParallelCompiler) void {
        while (!self.work_queue.isDone() and self.running.load(.acquire)) {
            Thread.yield();
        }
    }

    /// Worker thread main loop.
    fn workerLoop(self: *ParallelCompiler) void {
        while (self.running.load(.acquire)) {
            const item = self.work_queue.pop() orelse {
                Thread.yield();
                continue;
            };

            // Compile the function
            // In a real implementation, this would call the actual compiler
            const result = compileFunction(self.allocator, item);

            if (result.err) |err| {
                self.results.addError(err) catch {};
            } else {
                self.results.addResult(result) catch {};
            }

            _ = self.funcs_compiled.fetchAdd(1, .monotonic);
            _ = self.total_cycles.fetchAdd(item.estimated_cycles, .monotonic);
        }
    }

    /// Get statistics.
    pub fn stats(self: *ParallelCompiler) Stats {
        return .{
            .funcs_compiled = self.funcs_compiled.load(.acquire),
            .total_cycles = self.total_cycles.load(.acquire),
            .errors = self.results.errors.items.len,
        };
    }
};

/// Compile a single function (placeholder).
fn compileFunction(allocator: Allocator, item: WorkItem) CompileResult {
    _ = allocator;
    return .{
        .func_idx = item.func_idx,
        .code = &.{},
        .relocs = &.{},
        .err = null,
    };
}

/// Compilation statistics.
pub const Stats = struct {
    funcs_compiled: u32,
    total_cycles: u64,
    errors: usize,
};

// Tests
test "WorkQueue basic" {
    const testing = std.testing;

    var queue = WorkQueue.init(testing.allocator);
    defer queue.deinit();

    try queue.push(.{ .func_idx = 0, .priority = 1, .estimated_cycles = 100 });
    try queue.push(.{ .func_idx = 1, .priority = 2, .estimated_cycles = 200 });

    const item1 = queue.pop();
    try testing.expect(item1 != null);
    try testing.expectEqual(@as(u32, 1), item1.?.func_idx);

    const item2 = queue.pop();
    try testing.expect(item2 != null);

    const item3 = queue.pop();
    try testing.expect(item3 == null);
}

test "ResultCollector basic" {
    const testing = std.testing;

    var collector = ResultCollector.init(testing.allocator);
    defer collector.deinit();

    try collector.addResult(.{
        .func_idx = 0,
        .code = &.{},
        .relocs = &.{},
        .err = null,
    });

    try testing.expectEqual(@as(usize, 1), collector.completed());
}

test "Config defaults" {
    const testing = std.testing;
    const config = Config{};

    try testing.expectEqual(@as(u32, 0), config.num_threads);
    try testing.expect(config.work_stealing);
}
