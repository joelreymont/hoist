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
const compile_mod = @import("compile.zig");
const codegen_ctx_mod = @import("context.zig");
const ir = @import("../ir.zig");
const sig_mod = @import("../ir/signature.zig");

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
    /// True if `code` and `relocs` were heap-allocated and must be freed.
    owns_memory: bool = false,

    pub const Reloc = struct {
        offset: u32,
        kind: RelocKind,
        name: []const u8,
        addend: i64,
    };

    pub const RelocKind = enum {
        abs8,
        pcrel4,
        aarch64_adr_prel_pg_hi21,
        aarch64_add_abs_lo12_nc,
    };

    pub const CompileError = struct {
        func_idx: u32,
        message: []const u8,
        owned: bool = false,
    };

    pub fn deinit(self: *CompileResult, allocator: Allocator) void {
        if (self.err) |err| {
            if (err.owned) allocator.free(err.message);
        }
        if (self.owns_memory) {
            for (self.relocs) |reloc| {
                allocator.free(reloc.name);
            }
            allocator.free(self.relocs);
            allocator.free(self.code);
        }
        self.* = undefined;
    }
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

        if (self.items.items.len == 0) return null;
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
        for (self.results.items) |*result| {
            result.deinit(self.allocator);
        }
        for (self.errors.items) |err| {
            if (err.owned) self.allocator.free(err.message);
        }
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

    pub fn takeSorted(self: *ResultCollector, allocator: Allocator) ![]CompileResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        const total = self.results.items.len + self.errors.items.len;
        const out = try allocator.alloc(CompileResult, total);
        errdefer allocator.free(out);

        var idx: usize = 0;
        for (self.results.items) |result| {
            out[idx] = result;
            idx += 1;
        }
        for (self.errors.items) |err| {
            out[idx] = .{
                .func_idx = err.func_idx,
                .code = &.{},
                .relocs = &.{},
                .err = err,
                .owns_memory = false,
            };
            idx += 1;
        }

        self.results.clearRetainingCapacity();
        self.errors.clearRetainingCapacity();

        std.mem.sort(CompileResult, out, {}, struct {
            fn lessThan(_: void, a: CompileResult, b: CompileResult) bool {
                return a.func_idx < b.func_idx;
            }
        }.lessThan);
        return out;
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
    functions: ?[]*ir.Function,
    target: ?compile_mod.Target,

    /// Stats.
    funcs_compiled: std.atomic.Value(u32),
    total_cycles: std.atomic.Value(u64),

    pub fn init(allocator: Allocator, config: Config) ParallelCompiler {
        return .{
            .allocator = allocator,
            .config = config,
            .work_queue = WorkQueue.init(allocator),
            .results = ResultCollector.init(allocator),
            .workers = std.ArrayList(Thread){},
            .running = std.atomic.Value(bool).init(false),
            .functions = null,
            .target = null,
            .funcs_compiled = std.atomic.Value(u32).init(0),
            .total_cycles = std.atomic.Value(u64).init(0),
        };
    }

    /// Provide function table and target used by worker compilation.
    pub fn setCompilationInputs(self: *ParallelCompiler, functions: []*ir.Function, target: compile_mod.Target) void {
        self.functions = functions;
        self.target = target;
    }

    pub fn deinit(self: *ParallelCompiler) void {
        self.stop();
        self.work_queue.deinit();
        self.results.deinit();
        self.workers.deinit(self.allocator);
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
            try self.workers.append(self.allocator, worker);
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

    /// Signal that no more functions will be enqueued.
    pub fn finish(self: *ParallelCompiler) void {
        self.work_queue.finish();
    }

    /// Wait for all work to complete.
    pub fn wait(self: *ParallelCompiler) void {
        while (!self.work_queue.isDone() and self.running.load(.acquire)) {
            Thread.yield() catch {};
        }
    }

    /// Consume and return all completed results sorted by function index.
    /// Caller owns returned memory and each entry's owned allocations.
    pub fn takeResultsSorted(self: *ParallelCompiler, allocator: Allocator) ![]CompileResult {
        return self.results.takeSorted(allocator);
    }

    /// Worker thread main loop.
    fn workerLoop(self: *ParallelCompiler) void {
        while (self.running.load(.acquire)) {
            const item = self.work_queue.pop() orelse {
                if (self.work_queue.isDone()) break;
                Thread.yield() catch {};
                continue;
            };

            const result = self.compileFunction(item);

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

    fn compileFunction(self: *ParallelCompiler, item: WorkItem) CompileResult {
        const funcs = self.functions orelse return makeErrorResult(self.allocator, item.func_idx, "missing function table");
        const target = self.target orelse return makeErrorResult(self.allocator, item.func_idx, "missing compile target");
        if (item.func_idx >= funcs.len) return makeErrorResult(self.allocator, item.func_idx, "function index out of bounds");

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const worker_allocator = arena.allocator();

        var codegen_ctx = compile_mod.Context.init(worker_allocator);
        defer codegen_ctx.deinit();

        const func = funcs[item.func_idx];
        _ = compile_mod.compile(&codegen_ctx, func, &target) catch |err| {
            return makeErrorResult(self.allocator, item.func_idx, @errorName(err));
        };

        const compiled = codegen_ctx.getCompiledCode() orelse {
            return makeErrorResult(self.allocator, item.func_idx, "missing compiled code");
        };

        const code = self.allocator.alloc(u8, compiled.code.items.len) catch {
            return makeErrorResult(self.allocator, item.func_idx, "out of memory");
        };
        @memcpy(code, compiled.code.items);
        errdefer self.allocator.free(code);

        const relocs = self.allocator.alloc(CompileResult.Reloc, compiled.relocs.items.len) catch {
            return makeErrorResult(self.allocator, item.func_idx, "out of memory");
        };
        errdefer self.allocator.free(relocs);

        for (compiled.relocs.items, 0..) |reloc, idx| {
            const name = self.allocator.dupe(u8, reloc.name) catch {
                for (relocs[0..idx]) |prev| self.allocator.free(prev.name);
                self.allocator.free(relocs);
                self.allocator.free(code);
                return makeErrorResult(self.allocator, item.func_idx, "out of memory");
            };
            relocs[idx] = .{
                .offset = reloc.offset,
                .kind = mapRelocKind(reloc.kind),
                .name = name,
                .addend = reloc.addend,
            };
        }

        return .{
            .func_idx = item.func_idx,
            .code = code,
            .relocs = relocs,
            .err = null,
            .owns_memory = true,
        };
    }
};

fn mapRelocKind(kind: codegen_ctx_mod.RelocKind) CompileResult.RelocKind {
    return switch (kind) {
        .abs8 => .abs8,
        .pcrel4 => .pcrel4,
        .aarch64_adr_prel_pg_hi21 => .aarch64_adr_prel_pg_hi21,
        .aarch64_add_abs_lo12_nc => .aarch64_add_abs_lo12_nc,
    };
}

fn makeErrorResult(allocator: Allocator, func_idx: u32, message: []const u8) CompileResult {
    const duped = allocator.dupe(u8, message) catch null;
    const owned_msg = duped orelse message;
    return .{
        .func_idx = func_idx,
        .code = &.{},
        .relocs = &.{},
        .err = .{
            .func_idx = func_idx,
            .message = owned_msg,
            .owned = duped != null,
        },
        .owns_memory = false,
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

test "ParallelCompiler compileFunction errors without inputs" {
    const testing = std.testing;

    var pc = ParallelCompiler.init(testing.allocator, .{});
    defer pc.deinit();

    var result = pc.compileFunction(.{
        .func_idx = 0,
        .priority = 0,
        .estimated_cycles = 1,
    });
    defer result.deinit(testing.allocator);
    try testing.expect(result.err != null);
}

test "ParallelCompiler compileFunction uses real codegen" {
    const testing = std.testing;

    var sig = ir.Signature.init(testing.allocator, .fast);
    try sig.returns.append(testing.allocator, sig_mod.AbiParam.new(ir.I64));
    var func = try ir.Function.init(testing.allocator, "parallel_compile", sig);
    defer func.deinit();

    var builder = try ir.FunctionBuilder.init(testing.allocator, &func);
    defer builder.deinit();
    const block = try builder.createBlock();
    builder.switchToBlock(block);
    const c = try builder.iconst(ir.I64, 7);
    try builder.retValues(&.{c});

    var funcs = [_]*ir.Function{&func};
    var target = compile_mod.Target.init(.aarch64);
    target.verify = false;
    target.opt_level = .speed;

    var pc = ParallelCompiler.init(testing.allocator, .{});
    defer pc.deinit();
    pc.setCompilationInputs(funcs[0..], target);

    var result = pc.compileFunction(.{
        .func_idx = 0,
        .priority = 0,
        .estimated_cycles = 10,
    });
    defer result.deinit(testing.allocator);
    try testing.expect(result.err == null);
    try testing.expect(result.owns_memory);
    try testing.expect(result.code.len > 0);
}
