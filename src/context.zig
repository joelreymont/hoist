const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("root.zig");
const Function = root.ir.function.Function;
const compile_mod = root.codegen.compile;
const signature_mod = root.signature;

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

    pub fn init(allocator: Allocator) Context {
        return .{
            .allocator = allocator,
            .target = .{
                .arch = .x86_64,
                .os = .linux,
            },
            .opt_level = .none,
            .call_conv = .system_v,
            .verify = true,
            .optimize = false,
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

    /// Compile a function to machine code.
    pub fn compileFunction(
        self: *Context,
        func: *Function,
    ) !compile_mod.CompiledCode {
        // Run verification if enabled
        if (self.verify) {
            var verifier = root.ir.verifier.Verifier.init(self.allocator, func);
            defer verifier.deinit();
            try verifier.verify();
        }

        // Run optimization passes if enabled
        if (self.optimize) {
            var opt_pass = root.passes.optimize.OptimizationPass.init(self.allocator, func);
            _ = try opt_pass.run();
        }

        // Select backend and compile
        const compile_ctx = compile_mod.CompileCtx.init(
            self.allocator,
            targetISAName(self.target.arch),
        );

        return switch (self.target.arch) {
            .x86_64 => root.backends.x64.isa.X64ISA.compileFunction(compile_ctx, func),
            .aarch64 => root.backends.aarch64.isa.Aarch64ISA.compileFunction(compile_ctx, func),
        };
    }

    /// Get target ISA name string.
    fn targetISAName(arch: Arch) []const u8 {
        return switch (arch) {
            .x86_64 => "x86_64",
            .aarch64 => "aarch64",
        };
    }

    /// Get default calling convention for target.
    fn defaultCallConv(arch: Arch, os: OS) signature_mod.CallConv {
        return switch (arch) {
            .x86_64 => switch (os) {
                .linux, .macos => .system_v,
                .windows => .windows_fastcall,
            },
            .aarch64 => .aapcs64,
        };
    }
};

/// Target configuration.
pub const TargetConfig = struct {
    /// Target architecture.
    arch: Arch,
    /// Target operating system.
    os: OS,
};

/// Supported architectures.
pub const Arch = enum {
    x86_64,
    aarch64,
};

/// Supported operating systems.
pub const OS = enum {
    linux,
    macos,
    windows,
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

    pub fn build(self: *ContextBuilder) Context {
        return self.ctx;
    }
};

test "Context basic" {
    const ctx = Context.init(testing.allocator);

    // Default configuration
    try testing.expectEqual(Arch.x86_64, ctx.target.arch);
    try testing.expectEqual(OS.linux, ctx.target.os);
    try testing.expectEqual(OptLevel.none, ctx.opt_level);
    try testing.expectEqual(true, ctx.verify);
    try testing.expectEqual(false, ctx.optimize);
}

test "Context with target" {
    const ctx = Context.withTarget(testing.allocator, .aarch64, .macos);

    try testing.expectEqual(Arch.aarch64, ctx.target.arch);
    try testing.expectEqual(OS.macos, ctx.target.os);
    try testing.expectEqual(signature_mod.CallConv.aapcs64, ctx.call_conv);
}

test "Context optimization level" {
    var ctx = Context.init(testing.allocator);

    ctx.setOptLevel(.aggressive);
    try testing.expectEqual(OptLevel.aggressive, ctx.opt_level);
    try testing.expectEqual(true, ctx.optimize);

    ctx.setOptLevel(.none);
    try testing.expectEqual(false, ctx.optimize);
}

test "ContextBuilder" {
    var builder = ContextBuilder.init(testing.allocator);
    const ctx = builder
        .target(.aarch64, .linux)
        .optLevel(.moderate)
        .verification(false)
        .build();

    try testing.expectEqual(Arch.aarch64, ctx.target.arch);
    try testing.expectEqual(OptLevel.moderate, ctx.opt_level);
    try testing.expectEqual(false, ctx.verify);
}

test "Context compile function" {
    var ctx = Context.init(testing.allocator);
    ctx.verify = false; // Skip verification for stub function

    const sig = try root.signature.Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Empty function produces minimal code
    try testing.expect(code.code.len == 0);
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
        signature_mod.CallConv.aapcs64,
        Context.defaultCallConv(.aarch64, .linux),
    );
}
