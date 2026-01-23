const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("root.zig");
const Function = root.function.Function;
const compile_mod = root.codegen.compile;
const signature_mod = root.signature;
const Verifier = @import("ir/verifier.zig").Verifier;

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
                .arch = .aarch64,
                .os = .macos,
            },
            .opt_level = .none,
            .call_conv = defaultCallConv(.aarch64, .macos),
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
        // Convert Context settings to compile.Target
        const target = compile_mod.Target{
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
        };

        // Create a codegen Context for compilation with the function
        var codegen_ctx = compile_mod.Context.init(self.allocator);
        defer codegen_ctx.deinit();

        // Call the main compilation pipeline
        _ = try compile_mod.compile(&codegen_ctx, func, &target);

        // Take ownership of compiled code (transfers ownership, prevents double-free)
        return codegen_ctx.takeCompiledCode().?;
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
        return self.target(arch, os);
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
    try testing.expectEqual(Arch.aarch64, ctx.target.arch);
    try testing.expectEqual(OS.macos, ctx.target.os);
    try testing.expectEqual(OptLevel.none, ctx.opt_level);
    try testing.expectEqual(true, ctx.verify);
    try testing.expectEqual(false, ctx.optimize);
}

test "Context with target" {
    const ctx = Context.withTarget(testing.allocator, .aarch64, .macos);

    try testing.expectEqual(Arch.aarch64, ctx.target.arch);
    try testing.expectEqual(OS.macos, ctx.target.os);
    try testing.expectEqual(signature_mod.CallConv.apple_aarch64, ctx.call_conv);
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

    const sig = root.signature.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Empty function produces minimal code
    try testing.expect(code.code.len == 0);
}

test "Context compile function unsupported target" {
    var ctx = Context.withTarget(testing.allocator, .x86_64, .linux);
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
