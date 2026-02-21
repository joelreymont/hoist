const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("root.zig");
const Function = root.function.Function;
const compile_mod = root.codegen.compile;
const parallel_mod = @import("codegen/parallel.zig");
const signature_mod = root.signature;
const Verifier = @import("ir/verifier.zig").Verifier;
const Features = @import("target/features.zig").Features;
const FeatureDetector = @import("target/features.zig").FeatureDetector;

fn envUnsignedOrDefault(
    comptime T: type,
    allocator: Allocator,
    name: []const u8,
    default_value: T,
) T {
    const value = std.process.getEnvVarOwned(allocator, name) catch |err| {
        return switch (err) {
            error.EnvironmentVariableNotFound => default_value,
            error.OutOfMemory => blk: {
                std.log.warn("failed reading {s}: out of memory", .{name});
                break :blk default_value;
            },
            error.InvalidWtf8 => blk: {
                std.log.warn("failed reading {s}: invalid UTF-8", .{name});
                break :blk default_value;
            },
        };
    };
    defer allocator.free(value);
    if (value.len == 0) return default_value;
    return std.fmt.parseUnsigned(T, value, 10) catch {
        std.log.warn("invalid {s} value: {s}", .{ name, value });
        return default_value;
    };
}

/// Compiler configuration and context.
/// Central API for configuring and invoking the compiler.
pub const Context = struct {
    /// Allocator for compilation.
    allocator: Allocator,

    /// Target ISA configuration.
    target: TargetConfig,

    /// Optimization level.
    opt_level: OptLevel,

    /// Calling convention.
    call_conv: signature_mod.CallConv,

    /// Enable verification.
    verify: bool,

    /// Enable optimization passes.
    optimize: bool,

    /// Minimum complexity required to run e-graph optimization.
    egraph_min_complexity: u32,
    egraph_min_complexity_explicit: bool,
    /// Minimum complexity required to run alias analysis.
    alias_min_complexity: u32,
    alias_min_complexity_explicit: bool,
    /// Minimum complexity required to run range optimization.
    range_min_complexity: u32,
    range_min_complexity_explicit: bool,
    /// Minimum instruction count required to fold iadd iconst in lowering.
    fold_iadd_iconst_min_insts: usize,
    fold_iadd_iconst_min_insts_explicit: bool,
    /// True after one-time tuning env load.
    pgo_env_loaded: bool,

    /// Reusable codegen pipeline context.
    codegen_ctx: compile_mod.Context,

    pub fn init(allocator: Allocator) Context {
        return .{
            .allocator = allocator,
            .target = .{
                .arch = .aarch64,
                .os = .macos,
                .features = Features.init(),
            },
            .opt_level = .none,
            .call_conv = defaultCallConv(.aarch64, .macos),
            .verify = false,
            .optimize = false,
            .egraph_min_complexity = compile_mod.default_egraph_min_complexity,
            .egraph_min_complexity_explicit = false,
            .alias_min_complexity = compile_mod.default_alias_min_complexity,
            .alias_min_complexity_explicit = false,
            .range_min_complexity = compile_mod.default_range_min_complexity,
            .range_min_complexity_explicit = false,
            .fold_iadd_iconst_min_insts = compile_mod.default_fold_iadd_iconst_min_insts,
            .fold_iadd_iconst_min_insts_explicit = false,
            .pgo_env_loaded = false,
            .codegen_ctx = compile_mod.Context.init(allocator),
        };
    }

    /// Create context with specific target.
    pub fn withTarget(allocator: Allocator, arch: Arch, os: OS) Context {
        var ctx = init(allocator);
        ctx.target.arch = arch;
        ctx.target.os = os;
        ctx.call_conv = defaultCallConv(arch, os);
        return ctx;
    }

    /// Set optimization level.
    pub fn setOptLevel(self: *Context, level: OptLevel) void {
        self.opt_level = level;
        self.optimize = level != .none;
    }

    pub fn setEgraphMinComplexity(self: *Context, min_complexity: u32) void {
        self.egraph_min_complexity = min_complexity;
        self.egraph_min_complexity_explicit = true;
    }

    pub fn setAliasMinComplexity(self: *Context, min_complexity: u32) void {
        self.alias_min_complexity = min_complexity;
        self.alias_min_complexity_explicit = true;
    }

    pub fn setRangeMinComplexity(self: *Context, min_complexity: u32) void {
        self.range_min_complexity = min_complexity;
        self.range_min_complexity_explicit = true;
    }

    pub fn setFoldIaddIconstMinInsts(self: *Context, min_insts: usize) void {
        self.fold_iadd_iconst_min_insts = min_insts;
        self.fold_iadd_iconst_min_insts_explicit = true;
    }

    pub fn deinit(self: *Context) void {
        self.codegen_ctx.deinit();
    }

    fn makeCompileTarget(self: *const Context) compile_mod.Target {
        return .{
            .arch = switch (self.target.arch) {
                .x86_64 => .x86_64,
                .aarch64 => .aarch64,
                .riscv64 => .riscv64,
                .s390x => .s390x,
            },
            .opt_level = switch (self.opt_level) {
                .none => .none,
                .basic, .moderate => .speed,
                .aggressive => .speed_and_size,
            },
            .verify = self.verify,
            .optimize = self.optimize,
            .egraph_min_complexity = self.egraph_min_complexity,
            .alias_min_complexity = self.alias_min_complexity,
            .range_min_complexity = self.range_min_complexity,
            .fold_iadd_iconst_min_insts = self.fold_iadd_iconst_min_insts,
            .features = self.target.features,
        };
    }

    fn maybeLoadPgoFromEnv(self: *Context) void {
        if (self.pgo_env_loaded) return;
        if (!self.egraph_min_complexity_explicit) {
            self.egraph_min_complexity = envUnsignedOrDefault(
                u32,
                self.allocator,
                "HOIST_EGRAPH_MIN_COMPLEXITY",
                self.egraph_min_complexity,
            );
        }
        if (!self.alias_min_complexity_explicit) {
            self.alias_min_complexity = envUnsignedOrDefault(
                u32,
                self.allocator,
                "HOIST_ALIAS_MIN_COMPLEXITY",
                self.alias_min_complexity,
            );
        }
        if (!self.range_min_complexity_explicit) {
            self.range_min_complexity = envUnsignedOrDefault(
                u32,
                self.allocator,
                "HOIST_RANGE_MIN_COMPLEXITY",
                self.range_min_complexity,
            );
        }
        if (!self.fold_iadd_iconst_min_insts_explicit) {
            self.fold_iadd_iconst_min_insts = envUnsignedOrDefault(
                usize,
                self.allocator,
                "HOIST_FOLD_IADD_ICONST_MIN_INSTS",
                self.fold_iadd_iconst_min_insts,
            );
        }
        self.pgo_env_loaded = true;
    }

    fn estimateFunctionCycles(func: *const Function) u32 {
        var inst_count: u32 = 0;
        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |_| {
                inst_count +%= 1;
            }
        }
        return if (inst_count == 0) 1 else inst_count;
    }

    /// Compile a function to machine code.
    pub fn compileFunction(
        self: *Context,
        func: *Function,
    ) !compile_mod.CompiledCode {
        self.maybeLoadPgoFromEnv();
        const target = self.makeCompileTarget();

        self.codegen_ctx.clear();

        // Call the main compilation pipeline
        _ = try compile_mod.compile(&self.codegen_ctx, func, &target);

        // Take ownership of compiled code (transfers ownership, prevents double-free)
        return self.codegen_ctx.takeCompiledCode().?;
    }

    /// Compile a batch of functions in parallel and return sorted per-index results.
    pub fn compileFunctionsParallel(
        self: *Context,
        funcs: []*Function,
        config: parallel_mod.Config,
    ) ![]parallel_mod.CompileResult {
        self.maybeLoadPgoFromEnv();
        var compiler = parallel_mod.ParallelCompiler.init(self.allocator, config);
        defer compiler.deinit();

        const target = self.makeCompileTarget();
        compiler.setCompilationInputs(funcs, target);

        for (funcs, 0..) |func, idx| {
            try compiler.addFunction(@intCast(idx), estimateFunctionCycles(func));
        }

        try compiler.start();
        compiler.finish();
        compiler.wait();
        compiler.stop();

        return try compiler.takeResultsSorted(self.allocator);
    }

    pub fn setCompileProfiling(self: *Context, enabled: bool) void {
        self.codegen_ctx.profile_enabled = enabled;
    }

    pub fn resetCompileProfile(self: *Context) void {
        self.codegen_ctx.last_profile = compile_mod.CompileProfile.init();
        self.codegen_ctx.accum_profile = compile_mod.CompileProfile.init();
        self.codegen_ctx.compile_count = 0;
    }

    pub fn getLastCompileProfile(self: *const Context) compile_mod.CompileProfile {
        return self.codegen_ctx.last_profile;
    }

    pub fn getAccumCompileProfile(self: *const Context) compile_mod.CompileProfile {
        return self.codegen_ctx.accum_profile;
    }

    pub fn getCompileCount(self: *const Context) u64 {
        return self.codegen_ctx.compile_count;
    }

    /// Get target ISA name string.
    fn targetISAName(arch: Arch) []const u8 {
        return switch (arch) {
            .x86_64 => "x86_64",
            .aarch64 => "aarch64",
            .riscv64 => "riscv64",
            .s390x => "s390x",
        };
    }

    /// Get default calling convention for target.
    fn defaultCallConv(arch: Arch, os: OS) signature_mod.CallConv {
        return switch (arch) {
            .x86_64 => switch (os) {
                .linux, .macos => .system_v,
                .windows => .windows_fastcall,
            },
            .aarch64 => switch (os) {
                .linux => .system_v,
                .macos => .apple_aarch64,
                .windows => .windows_fastcall,
            },
            .riscv64 => .system_v,
            .s390x => .system_v,
        };
    }
};

/// Target configuration.
pub const TargetConfig = struct {
    /// Target architecture.
    arch: Arch,
    /// Target operating system.
    os: OS,
    /// CPU features.
    features: Features,
};

/// Supported architectures.
pub const Arch = enum {
    x86_64,
    aarch64,
    riscv64,
    s390x,
};

/// Supported operating systems.
pub const OS = enum {
    linux,
    macos,
    windows,
};

pub const TargetError = error{
    UnsupportedArch,
    UnsupportedOS,
};

/// Optimization levels.
pub const OptLevel = enum {
    /// No optimization.
    none,
    /// Basic optimizations (-O1).
    basic,
    /// Moderate optimizations (-O2).
    moderate,
    /// Aggressive optimizations (-O3).
    aggressive,
};

/// Builder pattern for Context configuration.
pub const ContextBuilder = struct {
    ctx: Context,

    pub fn init(allocator: Allocator) ContextBuilder {
        return .{
            .ctx = Context.init(allocator),
        };
    }

    pub fn target(self: *ContextBuilder, arch: Arch, os: OS) *ContextBuilder {
        self.ctx.target.arch = arch;
        self.ctx.target.os = os;
        self.ctx.call_conv = Context.defaultCallConv(arch, os);
        return self;
    }

    pub fn targetNative(self: *ContextBuilder) TargetError!*ContextBuilder {
        const builtin = @import("builtin");
        const arch: Arch = switch (builtin.cpu.arch) {
            .aarch64 => .aarch64,
            .x86_64 => .x86_64,
            else => return error.UnsupportedArch,
        };
        const os: OS = switch (builtin.os.tag) {
            .linux => .linux,
            .macos => .macos,
            .windows => .windows,
            else => return error.UnsupportedOS,
        };

        var detector = FeatureDetector.init(self.ctx.allocator);
        detector.detect() catch |err| {
            std.log.warn("Feature detection failed: {}, using baseline", .{err});
        };

        _ = self.target(arch, os);
        self.ctx.target.features = detector.getFeatures();
        return self;
    }

    pub fn optLevel(self: *ContextBuilder, level: OptLevel) *ContextBuilder {
        self.ctx.setOptLevel(level);
        return self;
    }

    pub fn callConv(self: *ContextBuilder, conv: signature_mod.CallConv) *ContextBuilder {
        self.ctx.call_conv = conv;
        return self;
    }

    pub fn verification(self: *ContextBuilder, enable: bool) *ContextBuilder {
        self.ctx.verify = enable;
        return self;
    }

    pub fn optimization(self: *ContextBuilder, enable: bool) *ContextBuilder {
        self.ctx.optimize = enable;
        return self;
    }

    pub fn egraphMinComplexity(self: *ContextBuilder, min_complexity: u32) *ContextBuilder {
        self.ctx.setEgraphMinComplexity(min_complexity);
        return self;
    }

    pub fn aliasMinComplexity(self: *ContextBuilder, min_complexity: u32) *ContextBuilder {
        self.ctx.setAliasMinComplexity(min_complexity);
        return self;
    }

    pub fn rangeMinComplexity(self: *ContextBuilder, min_complexity: u32) *ContextBuilder {
        self.ctx.setRangeMinComplexity(min_complexity);
        return self;
    }

    pub fn foldIaddIconstMinInsts(self: *ContextBuilder, min_insts: usize) *ContextBuilder {
        self.ctx.setFoldIaddIconstMinInsts(min_insts);
        return self;
    }

    pub fn build(self: *ContextBuilder) Context {
        return self.ctx;
    }
};

test "Context basic" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();

    // Default configuration
    try testing.expectEqual(Arch.aarch64, ctx.target.arch);
    try testing.expectEqual(OS.macos, ctx.target.os);
    try testing.expectEqual(OptLevel.none, ctx.opt_level);
    try testing.expectEqual(false, ctx.verify);
    try testing.expectEqual(false, ctx.optimize);
    try testing.expectEqual(compile_mod.default_egraph_min_complexity, ctx.egraph_min_complexity);
    try testing.expectEqual(compile_mod.default_alias_min_complexity, ctx.alias_min_complexity);
    try testing.expectEqual(compile_mod.default_range_min_complexity, ctx.range_min_complexity);
    try testing.expectEqual(compile_mod.default_fold_iadd_iconst_min_insts, ctx.fold_iadd_iconst_min_insts);
}

test "Context with target" {
    var ctx = Context.withTarget(testing.allocator, .aarch64, .macos);
    defer ctx.deinit();

    try testing.expectEqual(Arch.aarch64, ctx.target.arch);
    try testing.expectEqual(OS.macos, ctx.target.os);
    try testing.expectEqual(signature_mod.CallConv.apple_aarch64, ctx.call_conv);
}

test "Context optimization level" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();

    ctx.setOptLevel(.aggressive);
    try testing.expectEqual(OptLevel.aggressive, ctx.opt_level);
    try testing.expectEqual(true, ctx.optimize);

    ctx.setOptLevel(.none);
    try testing.expectEqual(false, ctx.optimize);
}

test "Context egraph threshold" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();

    ctx.setEgraphMinComplexity(192);
    try testing.expectEqual(@as(u32, 192), ctx.egraph_min_complexity);
}

test "Context threshold setters" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();

    ctx.setAliasMinComplexity(224);
    ctx.setRangeMinComplexity(208);
    ctx.setFoldIaddIconstMinInsts(1536);

    try testing.expectEqual(@as(u32, 224), ctx.alias_min_complexity);
    try testing.expectEqual(@as(u32, 208), ctx.range_min_complexity);
    try testing.expectEqual(@as(usize, 1536), ctx.fold_iadd_iconst_min_insts);
}

test "ContextBuilder" {
    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder
        .target(.aarch64, .linux)
        .optLevel(.moderate)
        .verification(false)
        .egraphMinComplexity(256)
        .aliasMinComplexity(192)
        .rangeMinComplexity(224)
        .foldIaddIconstMinInsts(2048)
        .build();
    defer ctx.deinit();

    try testing.expectEqual(Arch.aarch64, ctx.target.arch);
    try testing.expectEqual(OptLevel.moderate, ctx.opt_level);
    try testing.expectEqual(false, ctx.verify);
    try testing.expectEqual(@as(u32, 256), ctx.egraph_min_complexity);
    try testing.expectEqual(@as(u32, 192), ctx.alias_min_complexity);
    try testing.expectEqual(@as(u32, 224), ctx.range_min_complexity);
    try testing.expectEqual(@as(usize, 2048), ctx.fold_iadd_iconst_min_insts);
}

test "Context compile function" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();
    ctx.verify = false; // Skip verification for stub function
    ctx.setCompileProfiling(true);
    ctx.resetCompileProfile();

    const sig = root.signature.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Empty function produces minimal code
    try testing.expect(code.code.len == 0);
    try testing.expectEqual(@as(u64, 1), ctx.getCompileCount());
    try testing.expectEqual(
        ctx.getLastCompileProfile().total_ns,
        ctx.getAccumCompileProfile().total_ns,
    );
}

test "Context compile function unsupported target" {
    var ctx = Context.withTarget(testing.allocator, .x86_64, .linux);
    defer ctx.deinit();
    ctx.verify = false;

    const sig = root.signature.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    if (ctx.compileFunction(&func)) |code| {
        defer code.deinit();
        try testing.expect(false);
    } else |err| {
        try testing.expectEqual(error.UnsupportedTarget, err);
    }
}

test "Context compileFunctionsParallel returns sorted success results" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();
    ctx.verify = false;

    const sig0 = root.signature.Signature.init(testing.allocator, .fast);
    var func0 = try Function.init(testing.allocator, "p0", sig0);
    defer func0.deinit();

    const sig1 = root.signature.Signature.init(testing.allocator, .fast);
    var func1 = try Function.init(testing.allocator, "p1", sig1);
    defer func1.deinit();

    var funcs = [_]*Function{ &func0, &func1 };
    const results = try ctx.compileFunctionsParallel(funcs[0..], .{ .num_threads = 2 });
    defer {
        for (results) |*result| result.deinit(testing.allocator);
        testing.allocator.free(results);
    }

    try testing.expectEqual(@as(usize, 2), results.len);
    try testing.expectEqual(@as(u32, 0), results[0].func_idx);
    try testing.expectEqual(@as(u32, 1), results[1].func_idx);
    try testing.expect(results[0].err == null);
    try testing.expect(results[1].err == null);
}

test "Context compileFunctionsParallel handles mixed success and failure" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();
    ctx.verify = true;

    var sig_ok = root.signature.Signature.init(testing.allocator, .fast);
    try sig_ok.returns.append(testing.allocator, root.signature.AbiParam.new(root.types.Type.I64));
    var func_ok = try Function.init(testing.allocator, "ok", sig_ok);
    defer func_ok.deinit();

    const block_ok = try func_ok.dfg.makeBlock();
    try func_ok.layout.appendBlock(block_ok);
    const iconst_ok = try func_ok.dfg.makeInst(.{ .unary_imm = .{
        .opcode = .iconst,
        .imm = root.immediates.Imm64.new(7),
    } });
    try func_ok.layout.appendInst(iconst_ok, block_ok);
    const v_ok = try func_ok.dfg.appendInstResult(iconst_ok, root.types.Type.I64);
    const ret_ok = try func_ok.dfg.makeInst(.{ .unary = .{
        .opcode = .@"return",
        .arg = v_ok,
    } });
    try func_ok.layout.appendInst(ret_ok, block_ok);

    var sig_bad = root.signature.Signature.init(testing.allocator, .fast);
    try sig_bad.returns.append(testing.allocator, root.signature.AbiParam.new(root.types.Type.I64));
    var func_bad = try Function.init(testing.allocator, "bad", sig_bad);
    defer func_bad.deinit();

    const block_bad = try func_bad.dfg.makeBlock();
    try func_bad.layout.appendBlock(block_bad);
    const ret_bad = try func_bad.dfg.makeInst(.{ .unary = .{
        .opcode = .@"return",
        .arg = root.entities.Value.new(9999),
    } });
    try func_bad.layout.appendInst(ret_bad, block_bad);

    var funcs = [_]*Function{ &func_ok, &func_bad };
    const results = try ctx.compileFunctionsParallel(funcs[0..], .{ .num_threads = 2 });
    defer {
        for (results) |*result| result.deinit(testing.allocator);
        testing.allocator.free(results);
    }

    try testing.expectEqual(@as(usize, 2), results.len);
    try testing.expectEqual(@as(u32, 0), results[0].func_idx);
    try testing.expectEqual(@as(u32, 1), results[1].func_idx);
    try testing.expect(results[0].err == null);
    try testing.expect(results[1].err != null);
}

test "Context compileFunctionsParallel matches serial output" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();
    ctx.verify = false;
    ctx.setOptLevel(.moderate);

    var sig_a = root.signature.Signature.init(testing.allocator, .fast);
    try sig_a.returns.append(testing.allocator, root.signature.AbiParam.new(root.types.Type.I64));
    var func_a = try Function.init(testing.allocator, "pa", sig_a);
    defer func_a.deinit();

    const block_a = try func_a.dfg.makeBlock();
    try func_a.layout.appendBlock(block_a);
    const iconst_a = try func_a.dfg.makeInst(.{ .unary_imm = .{
        .opcode = .iconst,
        .imm = root.immediates.Imm64.new(11),
    } });
    try func_a.layout.appendInst(iconst_a, block_a);
    const v_a = try func_a.dfg.appendInstResult(iconst_a, root.types.Type.I64);
    const ret_a = try func_a.dfg.makeInst(.{ .unary = .{
        .opcode = .@"return",
        .arg = v_a,
    } });
    try func_a.layout.appendInst(ret_a, block_a);

    var sig_b = root.signature.Signature.init(testing.allocator, .fast);
    try sig_b.returns.append(testing.allocator, root.signature.AbiParam.new(root.types.Type.I64));
    var func_b = try Function.init(testing.allocator, "pb", sig_b);
    defer func_b.deinit();

    const block_b = try func_b.dfg.makeBlock();
    try func_b.layout.appendBlock(block_b);
    const iconst_b = try func_b.dfg.makeInst(.{ .unary_imm = .{
        .opcode = .iconst,
        .imm = root.immediates.Imm64.new(29),
    } });
    try func_b.layout.appendInst(iconst_b, block_b);
    const v_b = try func_b.dfg.appendInstResult(iconst_b, root.types.Type.I64);
    const ret_b = try func_b.dfg.makeInst(.{ .unary = .{
        .opcode = .@"return",
        .arg = v_b,
    } });
    try func_b.layout.appendInst(ret_b, block_b);

    var serial_a = try ctx.compileFunction(&func_a);
    defer serial_a.deinit();
    var serial_b = try ctx.compileFunction(&func_b);
    defer serial_b.deinit();

    var funcs = [_]*Function{ &func_a, &func_b };
    const parallel_results = try ctx.compileFunctionsParallel(funcs[0..], .{ .num_threads = 2 });
    defer {
        for (parallel_results) |*result| result.deinit(testing.allocator);
        testing.allocator.free(parallel_results);
    }

    try testing.expectEqual(@as(usize, 2), parallel_results.len);
    try testing.expect(parallel_results[0].err == null);
    try testing.expect(parallel_results[1].err == null);
    try testing.expectEqualSlices(u8, serial_a.code.items, parallel_results[0].code);
    try testing.expectEqualSlices(u8, serial_b.code.items, parallel_results[1].code);
}

test "Context default calling convention" {
    try testing.expectEqual(
        signature_mod.CallConv.system_v,
        Context.defaultCallConv(.x86_64, .linux),
    );

    try testing.expectEqual(
        signature_mod.CallConv.windows_fastcall,
        Context.defaultCallConv(.x86_64, .windows),
    );

    try testing.expectEqual(
        signature_mod.CallConv.apple_aarch64,
        Context.defaultCallConv(.aarch64, .linux),
    );
}
