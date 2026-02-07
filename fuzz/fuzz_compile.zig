const std = @import("std");
const hoist = @import("hoist");
const builtin = @import("builtin");

const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const Type = hoist.types.Type;
const Opcode = hoist.opcodes.Opcode;
const ContextBuilder = hoist.context.ContextBuilder;
const ir_print = hoist.ir_print;

const Mode = enum {
    compile,
    diff,
};

const Config = struct {
    iterations: usize = 1000,
    seed: ?u64 = null,
    mode: Mode = .diff,
};

const ModelBinOp = enum {
    iadd,
    isub,
    imul,
    band,
    bor,
    bxor,
};

const ModelStep = union(enum) {
    const_i64: i64,
    binary: struct {
        op: ModelBinOp,
        lhs: u16,
        rhs: u16,
    },
};

const DiffModel = struct {
    steps: std.ArrayList(ModelStep),
    ret_idx: u16,

    pub fn init() DiffModel {
        return .{
            .steps = .{},
            .ret_idx = 0,
        };
    }

    pub fn deinit(self: *DiffModel, allocator: std.mem.Allocator) void {
        self.steps.deinit(allocator);
    }
};

const DiffCase = struct {
    func: Function,
    model: DiffModel,

    pub fn deinit(self: *DiffCase, allocator: std.mem.Allocator) void {
        self.model.deinit(allocator);
        self.func.deinit();
    }
};

/// Fuzzer for compilation pipeline.
/// Generates random valid IR and attempts to compile it.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cfg = try parseArgs(args);
    const seed = cfg.seed orelse blk: {
        var random_seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&random_seed));
        break :blk random_seed;
    };
    std.debug.print(
        "Running {s} fuzzer for {d} iterations (seed={d})...\n",
        .{ @tagName(cfg.mode), cfg.iterations, seed },
    );

    if (cfg.mode == .diff and builtin.os.tag != .macos and builtin.os.tag != .linux) {
        std.debug.print("Differential mode requires macOS or Linux executable memory support.\n", .{});
        std.process.exit(1);
    }

    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    var failures: usize = 0;
    var successes: usize = 0;

    for (0..cfg.iterations) |i| {
        if (i % 100 == 0) {
            std.debug.print("Iteration {d}/{d} (failures: {d}, successes: {d})\n", .{
                i,
                cfg.iterations,
                failures,
                successes,
            });
        }

        if (cfg.mode == .compile) {
            var diff_case = generateDiffCase(allocator, rand) catch |err| {
                std.debug.print("Failed to generate function: {}\n", .{err});
                failures += 1;
                continue;
            };
            defer diff_case.deinit(allocator);

            var builder = ContextBuilder.init(allocator);
            _ = try builder.targetNative();
            var ctx = builder.optLevel(.none).verification(true).build();

            var code = ctx.compileFunction(&diff_case.func) catch |err| {
                std.debug.print("Compilation failed (expected): {}\n", .{err});
                continue;
            };
            defer code.deinit();
            successes += 1;
            continue;
        }

        var diff_case = generateDiffCase(allocator, rand) catch |err| {
            std.debug.print("Failed to generate differential function: {}\n", .{err});
            failures += 1;
            continue;
        };
        defer diff_case.deinit(allocator);

        const arg1 = rand.int(i64);
        const arg2 = rand.int(i64);
        const compare_result = compareModelAndJit(allocator, &diff_case, arg1, arg2) catch |err| {
            std.debug.print("Differential execution failed: {}\n", .{err});
            std.debug.print("seed={d} iteration={d} arg1={d} arg2={d}\n", .{ seed, i, arg1, arg2 });
            try dumpFunction(allocator, &diff_case.func);
            failures += 1;
            continue;
        };
        if (!compare_result.match) {
            std.debug.print(
                "Mismatch: seed={d} iteration={d} arg1={d} arg2={d} model={d} jit={d}\n",
                .{ seed, i, arg1, arg2, compare_result.model, compare_result.jit },
            );
            try dumpFunction(allocator, &diff_case.func);
            failures += 1;
            continue;
        }
        successes += 1;
    }

    std.debug.print("\nFuzzing complete:\n", .{});
    std.debug.print("  Iterations: {d}\n", .{cfg.iterations});
    std.debug.print("  Successes: {d}\n", .{successes});
    std.debug.print("  Failures: {d}\n", .{failures});

    if (failures > 0) {
        std.process.exit(1);
    }
}

fn parseArgs(args: []const [:0]u8) !Config {
    var cfg = Config{};
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--mode")) {
            i += 1;
            if (i >= args.len) return error.InvalidArgument;
            if (std.mem.eql(u8, args[i], "compile")) {
                cfg.mode = .compile;
            } else if (std.mem.eql(u8, args[i], "diff")) {
                cfg.mode = .diff;
            } else {
                return error.InvalidArgument;
            }
            continue;
        }
        if (std.mem.eql(u8, arg, "--seed")) {
            i += 1;
            if (i >= args.len) return error.InvalidArgument;
            cfg.seed = try std.fmt.parseInt(u64, args[i], 10);
            continue;
        }
        cfg.iterations = try std.fmt.parseInt(usize, arg, 10);
    }
    return cfg;
}

/// Generate a deterministic i64-only function and reference model.
fn generateDiffCase(allocator: std.mem.Allocator, rand: std.Random) !DiffCase {
    var sig = Signature.init(allocator, .fast);
    try sig.params.append(allocator, hoist.signature.AbiParam.new(Type.I64));
    try sig.params.append(allocator, hoist.signature.AbiParam.new(Type.I64));
    try sig.returns.append(allocator, hoist.signature.AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "fuzz_diff", sig);
    errdefer func.deinit();
    var model = DiffModel.init();
    errdefer model.deinit(allocator);

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    var vals = std.ArrayList(hoist.entities.Value){};
    defer vals.deinit(allocator);

    const p0 = try func.dfg.appendBlockParam(entry, Type.I64);
    const p1 = try func.dfg.appendBlockParam(entry, Type.I64);
    try vals.append(allocator, p0);
    try vals.append(allocator, p1);

    const num_insts = rand.uintAtMost(u8, 12) + 4;
    const opcodes = [_]Opcode{ .iadd, .isub, .imul, .band, .bor, .bxor };

    for (0..num_insts) |_| {
        if (rand.uintAtMost(u8, 4) == 0) {
            const c = rand.int(i64);
            const inst = try func.dfg.makeInst(.{ .unary_imm = .{
                .opcode = .iconst,
                .imm = .{ .value = @intCast(c) },
            } });
            try func.layout.appendInst(inst, entry);
            const out = try func.dfg.appendInstResult(inst, Type.I64);
            try vals.append(allocator, out);
            try model.steps.append(allocator, .{ .const_i64 = c });
            continue;
        }

        const lhs_idx = rand.uintAtMost(usize, vals.items.len - 1);
        const rhs_idx = rand.uintAtMost(usize, vals.items.len - 1);
        const lhs = vals.items[lhs_idx];
        const rhs = vals.items[rhs_idx];
        const op = opcodes[rand.uintAtMost(usize, opcodes.len - 1)];
        const inst = try func.dfg.makeInst(.{ .binary = .{
            .opcode = op,
            .args = .{ lhs, rhs },
        } });
        try func.layout.appendInst(inst, entry);
        const out = try func.dfg.appendInstResult(inst, Type.I64);
        try vals.append(allocator, out);
        try model.steps.append(allocator, .{ .binary = .{
            .op = switch (op) {
                .iadd => .iadd,
                .isub => .isub,
                .imul => .imul,
                .band => .band,
                .bor => .bor,
                .bxor => .bxor,
                else => unreachable,
            },
            .lhs = std.math.cast(u16, lhs_idx) orelse return error.IndexOutOfRange,
            .rhs = std.math.cast(u16, rhs_idx) orelse return error.IndexOutOfRange,
        } });
    }

    const ret_idx = rand.uintAtMost(usize, vals.items.len - 1);
    model.ret_idx = std.math.cast(u16, ret_idx) orelse return error.IndexOutOfRange;
    const ret_val = vals.items[ret_idx];
    const ret_inst = try func.dfg.makeInst(.{ .unary = .{
        .opcode = .@"return",
        .arg = ret_val,
    } });
    try func.layout.appendInst(ret_inst, entry);

    return .{
        .func = func,
        .model = model,
    };
}

const CompareResult = struct {
    match: bool,
    model: i64,
    jit: i64,
};

fn compareModelAndJit(
    allocator: std.mem.Allocator,
    diff_case: *const DiffCase,
    arg1: i64,
    arg2: i64,
) !CompareResult {
    const model_val = try evaluateModel(&diff_case.model, arg1, arg2);
    const jit_val = try compileAndExecuteI64I64ToI64(allocator, @constCast(&diff_case.func), arg1, arg2);
    return .{
        .match = model_val == jit_val,
        .model = model_val,
        .jit = jit_val,
    };
}

fn evaluateModel(model: *const DiffModel, arg1: i64, arg2: i64) !i64 {
    var vals: [128]i64 = undefined;
    var next: usize = 0;
    vals[next] = arg1;
    next += 1;
    vals[next] = arg2;
    next += 1;

    for (model.steps.items) |step| {
        const out = switch (step) {
            .const_i64 => |v| v,
            .binary => |b| blk: {
                if (b.lhs >= next or b.rhs >= next) return error.InvalidModelIndex;
                const lhs = vals[b.lhs];
                const rhs = vals[b.rhs];
                break :blk switch (b.op) {
                    .iadd => lhs +% rhs,
                    .isub => lhs -% rhs,
                    .imul => lhs *% rhs,
                    .band => lhs & rhs,
                    .bor => lhs | rhs,
                    .bxor => lhs ^ rhs,
                };
            },
        };
        if (next >= vals.len) return error.ModelValueOverflow;
        vals[next] = out;
        next += 1;
    }

    if (model.ret_idx >= next) return error.InvalidModelReturn;
    return vals[model.ret_idx];
}

fn dumpFunction(allocator: std.mem.Allocator, func: *const Function) !void {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try ir_print.writeFunction(buf.writer(allocator), func, .{});
    std.debug.print("---- FUNCTION IR ----\n{s}\n---------------------\n", .{buf.items});
}

fn compileAndExecuteI64I64ToI64(
    allocator: std.mem.Allocator,
    func: *Function,
    arg1: i64,
    arg2: i64,
) !i64 {
    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var compiled = try ctx.compileFunction(func);
    defer compiled.deinit();
    const mem = try allocExecutableMemory(compiled.code.items.len);
    defer freeExecutableMemory(mem);
    @memcpy(mem[0..compiled.code.items.len], compiled.code.items);
    try makeExecutable(mem);

    const jit_fn: *const fn (i64, i64) callconv(.c) i64 = @ptrCast(@alignCast(mem.ptr));
    return jit_fn(arg1, arg2);
}

fn allocExecutableMemory(size: usize) ![]align(std.heap.page_size_min) u8 {
    const page_size = std.heap.pageSize();
    const aligned_size = std.mem.alignForward(usize, size, page_size);

    switch (builtin.os.tag) {
        .linux => {
            const prot = std.posix.PROT.READ | std.posix.PROT.WRITE;
            const flags = std.posix.MAP{ .TYPE = .PRIVATE, .ANONYMOUS = true };
            return try std.posix.mmap(null, aligned_size, prot, flags, -1, 0);
        },
        .macos => {
            if (builtin.cpu.arch == .aarch64 or builtin.cpu.arch == .aarch64_be) {
                const prot = std.posix.PROT.READ | std.posix.PROT.WRITE | std.posix.PROT.EXEC;
                const flags = std.posix.MAP{ .TYPE = .PRIVATE, .ANONYMOUS = true, .JIT = true };
                const mem = try std.posix.mmap(null, aligned_size, prot, flags, -1, 0);
                const pthread_jit_write_protect_np = struct {
                    extern "c" fn pthread_jit_write_protect_np(enabled: c_int) void;
                }.pthread_jit_write_protect_np;
                pthread_jit_write_protect_np(0);
                return mem;
            }
            const prot = std.posix.PROT.READ | std.posix.PROT.WRITE;
            const flags = std.posix.MAP{ .TYPE = .PRIVATE, .ANONYMOUS = true };
            return try std.posix.mmap(null, aligned_size, prot, flags, -1, 0);
        },
        else => return error.UnsupportedPlatform,
    }
}

fn makeExecutable(memory: []align(std.heap.page_size_min) u8) !void {
    switch (builtin.os.tag) {
        .linux => {
            try std.posix.mprotect(memory, std.posix.PROT.READ | std.posix.PROT.EXEC);
        },
        .macos => {
            if (builtin.cpu.arch == .aarch64 or builtin.cpu.arch == .aarch64_be) {
                const pthread_jit_write_protect_np = struct {
                    extern "c" fn pthread_jit_write_protect_np(enabled: c_int) void;
                }.pthread_jit_write_protect_np;
                pthread_jit_write_protect_np(1);
                const sys_icache_invalidate = struct {
                    extern "c" fn sys_icache_invalidate(start: *anyopaque, size: usize) void;
                }.sys_icache_invalidate;
                sys_icache_invalidate(memory.ptr, memory.len);
                return;
            }
            try std.posix.mprotect(memory, std.posix.PROT.READ | std.posix.PROT.EXEC);
        },
        else => return error.UnsupportedPlatform,
    }
}

fn freeExecutableMemory(memory: []align(std.heap.page_size_min) u8) void {
    switch (builtin.os.tag) {
        .linux, .macos => std.posix.munmap(memory),
        else => {},
    }
}
