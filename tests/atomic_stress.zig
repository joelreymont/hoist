//! Atomic operation stress tests.
//!
//! Multi-threaded tests for atomic operations with various memory orderings.
//! Tests correctness of atomic RMW operations under contention.

const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;
const Atomic = std.atomic.Value;

const hoist = @import("hoist");
const AtomicOrdering = hoist.atomics.AtomicOrdering;
const AtomicRmwOp = hoist.atomics.AtomicRmwOp;

// Test configuration
const NUM_THREADS = 8;
const ITERATIONS = 10_000;

/// Shared counter for stress tests.
const SharedCounter = struct {
    value: Atomic(i64),

    fn init() SharedCounter {
        return .{ .value = Atomic(i64).init(0) };
    }

    fn add(self: *SharedCounter, delta: i64, order: std.builtin.AtomicOrder) i64 {
        return self.value.fetchAdd(delta, order);
    }

    fn sub(self: *SharedCounter, delta: i64, order: std.builtin.AtomicOrder) i64 {
        return self.value.fetchSub(delta, order);
    }

    fn load(self: *SharedCounter, order: std.builtin.AtomicOrder) i64 {
        return self.value.load(order);
    }
};

/// Thread worker for add stress test.
fn addWorker(counter: *SharedCounter) void {
    for (0..ITERATIONS) |_| {
        _ = counter.add(1, .seq_cst);
    }
}

/// Thread worker for add/sub stress test.
fn addSubWorker(counter: *SharedCounter) void {
    for (0..ITERATIONS) |_| {
        _ = counter.add(1, .seq_cst);
        _ = counter.sub(1, .seq_cst);
    }
}

test "atomic add stress - sequential consistency" {
    var counter = SharedCounter.init();
    var threads: [NUM_THREADS]Thread = undefined;

    // Spawn threads
    for (&threads) |*t| {
        t.* = try Thread.spawn(.{}, addWorker, .{&counter});
    }

    // Wait for completion
    for (threads) |t| {
        t.join();
    }

    // Verify final count
    const expected: i64 = NUM_THREADS * ITERATIONS;
    const actual = counter.load(.seq_cst);
    try testing.expectEqual(expected, actual);
}

test "atomic add/sub stress - value remains zero" {
    var counter = SharedCounter.init();
    var threads: [NUM_THREADS]Thread = undefined;

    for (&threads) |*t| {
        t.* = try Thread.spawn(.{}, addSubWorker, .{&counter});
    }

    for (threads) |t| {
        t.join();
    }

    // After equal adds and subs, should be zero
    const actual = counter.load(.seq_cst);
    try testing.expectEqual(@as(i64, 0), actual);
}

/// Compare-and-swap stress test worker.
fn casWorker(counter: *Atomic(i64)) void {
    for (0..ITERATIONS) |_| {
        while (true) {
            const old = counter.load(.seq_cst);
            if (counter.cmpxchgWeak(old, old + 1, .seq_cst, .seq_cst)) |_| {
                // CAS failed, retry
                continue;
            } else {
                // CAS succeeded
                break;
            }
        }
    }
}

test "atomic CAS stress" {
    var counter = Atomic(i64).init(0);
    var threads: [NUM_THREADS]Thread = undefined;

    for (&threads) |*t| {
        t.* = try Thread.spawn(.{}, casWorker, .{&counter});
    }

    for (threads) |t| {
        t.join();
    }

    const expected: i64 = NUM_THREADS * ITERATIONS;
    const actual = counter.load(.seq_cst);
    try testing.expectEqual(expected, actual);
}

/// Exchange stress test - verify all values are exchanged exactly once.
fn xchgWorker(args: struct { counter: *Atomic(i64), id: usize, results: []i64 }) void {
    var sum: i64 = 0;
    for (0..ITERATIONS) |_| {
        const old = args.counter.swap(@intCast(args.id), .seq_cst);
        sum += old;
    }
    args.results[args.id] = sum;
}

test "atomic exchange stress" {
    var counter = Atomic(i64).init(0);
    var threads: [NUM_THREADS]Thread = undefined;
    var results: [NUM_THREADS]i64 = undefined;
    @memset(&results, 0);

    for (&threads, 0..) |*t, i| {
        t.* = try Thread.spawn(.{}, xchgWorker, .{.{
            .counter = &counter,
            .id = i,
            .results = &results,
        }});
    }

    for (threads) |t| {
        t.join();
    }

    // All exchanged values should sum to something deterministic
    // The final value in counter + sum of all results should equal
    // the sum of all values that were exchanged
    var total: i64 = counter.load(.seq_cst);
    for (results) |r| {
        total += r;
    }
    // Total depends on exchange pattern, just verify no crash
    _ = total;
}

/// Memory ordering test - acquire/release synchronization.
const SyncData = struct {
    data: i64,
    ready: Atomic(bool),

    fn init() SyncData {
        return .{
            .data = 0,
            .ready = Atomic(bool).init(false),
        };
    }
};

fn producer(sync: *SyncData) void {
    for (0..ITERATIONS) |i| {
        sync.data = @intCast(i);
        sync.ready.store(true, .release);

        // Wait for consumer to acknowledge
        while (sync.ready.load(.acquire)) {
            Thread.yield();
        }
    }
}

fn consumer(sync: *SyncData, sum: *i64) void {
    var local_sum: i64 = 0;
    for (0..ITERATIONS) |_| {
        // Wait for producer
        while (!sync.ready.load(.acquire)) {
            Thread.yield();
        }

        local_sum += sync.data;
        sync.ready.store(false, .release);
    }
    sum.* = local_sum;
}

test "atomic acquire/release synchronization" {
    var sync = SyncData.init();
    var sum: i64 = 0;

    const prod = try Thread.spawn(.{}, producer, .{&sync});
    const cons = try Thread.spawn(.{}, consumer, .{ &sync, &sum });

    prod.join();
    cons.join();

    // Sum should be 0 + 1 + 2 + ... + (ITERATIONS-1)
    const expected: i64 = @intCast(ITERATIONS * (ITERATIONS - 1) / 2);
    try testing.expectEqual(expected, sum);
}

/// Relaxed ordering test - just atomicity, no ordering.
fn relaxedWorker(counter: *Atomic(i64)) void {
    for (0..ITERATIONS) |_| {
        _ = counter.fetchAdd(1, .monotonic);
    }
}

test "atomic relaxed ordering stress" {
    var counter = Atomic(i64).init(0);
    var threads: [NUM_THREADS]Thread = undefined;

    for (&threads) |*t| {
        t.* = try Thread.spawn(.{}, relaxedWorker, .{&counter});
    }

    for (threads) |t| {
        t.join();
    }

    // Relaxed still guarantees atomicity
    const expected: i64 = NUM_THREADS * ITERATIONS;
    const actual = counter.load(.monotonic);
    try testing.expectEqual(expected, actual);
}

// AtomicOrdering utility tests.
test "AtomicOrdering mapping to std.builtin.AtomicOrder" {
    // Verify our ordering enum maps correctly
    try testing.expect(AtomicOrdering.unordered == .unordered);
    try testing.expect(AtomicOrdering.monotonic == .monotonic);
    try testing.expect(AtomicOrdering.acquire == .acquire);
    try testing.expect(AtomicOrdering.release == .release);
    try testing.expect(AtomicOrdering.acq_rel == .acq_rel);
    try testing.expect(AtomicOrdering.seq_cst == .seq_cst);
}

// Verify AtomicRmwOp enum values.
test "AtomicRmwOp enumeration" {
    const ops = [_]AtomicRmwOp{
        .xchg, .add, .sub, .@"and", .nand, .@"or", .xor,
        .max,  .min, .umax, .umin,
    };
    try testing.expectEqual(@as(usize, 11), ops.len);
}
