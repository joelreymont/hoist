//! Main compilation entry point.
//!
//! Orchestrates the entire compilation pipeline:
//! 1. Verification
//! 2. Legalization
//! 3. Optimization
//! 4. CFG/dominator tree computation
//! 5. Lowering (IR -> VCode via ISLE)
//! 6. Register allocation
//! 7. Prologue/epilogue insertion
//! 8. Code emission

const std = @import("std");
const Context = @import("context.zig").Context;
const CompiledCode = @import("context.zig").CompiledCode;
const Function = @import("../ir.zig").Function;
const Block = @import("../ir.zig").Block;
const ir = @import("../ir.zig");

/// Compilation error with context.
pub const CompileError = struct {
    inner: CodegenError,
    message: []const u8,

    pub fn format(
        self: CompileError,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Compile error: {s}", .{self.message});
    }
};

/// Codegen errors.
pub const CodegenError = error{
    /// Verification failed.
    VerificationFailed,
    /// Legalization failed.
    LegalizationFailed,
    /// Optimization failed.
    OptimizationFailed,
    /// Lowering failed.
    LoweringFailed,
    /// Register allocation failed.
    RegisterAllocationFailed,
    /// Code emission failed.
    EmissionFailed,
    /// Out of memory.
    OutOfMemory,
};

/// Compilation result type.
pub const CompileResult = CodegenError!*const CompiledCode;

/// Main compilation entry point.
///
/// Runs the function through all compilation passes:
/// - Verification (if enabled)
/// - Legalization
/// - Optimization
/// - Lowering to machine code
/// - Register allocation
/// - Code emission
///
/// Returns compiled machine code with relocations.
pub fn compile(
    ctx: *Context,
    target: *const Target,
) CompileResult {
    // 1. Verify IR (if enabled)
    try verifyIf(ctx, target);

    // 2. Optimize IR
    try optimize(ctx, target);

    // 3. Lower to VCode via ISLE
    try lower(ctx, target);

    // 4. Register allocation
    try allocateRegisters(ctx, target);

    // 5. Prologue/epilogue insertion
    try insertPrologueEpilogue(ctx, target);

    // 6. Emit machine code
    try emit(ctx, target);

    return ctx.getCompiledCode() orelse return error.EmissionFailed;
}

/// Verify function if verification is enabled.
fn verifyIf(ctx: *Context, target: *const Target) CodegenError!void {
    if (!target.verify) return;

    var verifier = ir.Verifier.init(ctx.allocator, &ctx.func);
    defer verifier.deinit();

    verifier.verify() catch {
        // Verification failed - print errors
        const errors = verifier.getErrors();
        if (errors.len > 0) {
            std.debug.print("IR Verification failed:\n", .{});
            for (errors) |err| {
                std.debug.print("  {s}\n", .{err});
            }
            return error.VerificationFailed;
        }
        return error.VerificationFailed;
    };
}

/// Optimize the function.
///
/// Performs all optimization passes up to but not including lowering:
/// - NaN canonicalization (if enabled)
/// - Legalization
/// - CFG computation
/// - Dominator tree computation
/// - Unreachable code elimination
/// - Constant phi removal
/// - E-graph optimization (if opt level > 0)
fn optimize(ctx: *Context, target: *const Target) CodegenError!void {
    _ = target;

    // 1. Legalize IR
    try legalize(ctx);

    // 2. Compute CFG
    try ctx.cfg.compute(&ctx.func) catch return error.OptimizationFailed;

    // 3. Compute dominator tree
    // TODO: Implement dominator tree computation
    // try ctx.domtree.compute(&ctx.cfg);

    // 4. Eliminate unreachable code
    _ = try eliminateUnreachableCode(ctx);

    // 5. Remove constant phis
    // TODO: Implement constant phi removal

    // 6. Resolve value aliases
    // TODO: ctx.func.dfg.resolveAllAliases();

    // 7. E-graph optimization (if opt_level > 0)
    // TODO: Implement e-graph pass
}

/// Eliminate unreachable code.
///
/// Uses CFG to find blocks unreachable from entry and removes them.
/// Returns true if any blocks were removed.
fn eliminateUnreachableCode(ctx: *Context) CodegenError!bool {
    const entry = ctx.func.layout.entryBlock() orelse return false;

    var changed = false;
    var reachable = std.AutoHashMap(Block, void).init(ctx.allocator);
    defer reachable.deinit();

    // Mark all reachable blocks using worklist algorithm
    var worklist = std.ArrayList(Block).init(ctx.allocator);
    defer worklist.deinit();

    try worklist.append(entry);
    try reachable.put(entry, {});

    while (worklist.items.len > 0) {
        const block = worklist.pop();
        var succ_iter = ctx.cfg.succIter(block);
        while (succ_iter.next()) |succ| {
            if (!reachable.contains(succ)) {
                try reachable.put(succ, {});
                try worklist.append(succ);
            }
        }
    }

    // Remove unreachable blocks
    var block_iter = ctx.func.layout.blockIter();
    while (block_iter.next()) |block| {
        if (!reachable.contains(block)) {
            ctx.func.layout.removeBlock(block);
            changed = true;
        }
    }

    return changed;
}

/// Legalize IR for target.
fn legalize(ctx: *Context) CodegenError!void {
    // TODO: Implement legalization
    _ = ctx;
}

/// Lower IR to VCode via ISLE.
fn lower(ctx: *Context, target: *const Target) CodegenError!void {
    // TODO: Implement lowering phase
    _ = ctx;
    _ = target;
}

/// Allocate registers.
fn allocateRegisters(ctx: *Context, target: *const Target) CodegenError!void {
    // TODO: Implement register allocation
    _ = ctx;
    _ = target;
}

/// Insert function prologue and epilogue.
fn insertPrologueEpilogue(ctx: *Context, target: *const Target) CodegenError!void {
    // TODO: Implement prologue/epilogue insertion
    _ = ctx;
    _ = target;
}

/// Emit machine code.
fn emit(ctx: *Context, target: *const Target) CodegenError!void {
    // TODO: Implement code emission
    _ = ctx;
    _ = target;

    // Allocate compiled code result
    var code = CompiledCode.init(ctx.allocator);
    ctx.compiled_code = code;
}

/// Target ISA configuration.
pub const Target = struct {
    /// Target architecture.
    arch: Architecture,
    /// Optimization level.
    opt_level: OptLevel,
    /// Enable verification.
    verify: bool,

    pub const Architecture = enum {
        aarch64,
        x86_64,
    };

    pub const OptLevel = enum {
        none,
        speed,
        speed_and_size,
    };

    pub fn init(arch: Architecture) Target {
        return .{
            .arch = arch,
            .opt_level = .none,
            .verify = false,
        };
    }
};

// Tests

const testing = std.testing;

test "compile: target initialization" {
    const target = Target.init(.aarch64);
    try testing.expectEqual(Target.Architecture.aarch64, target.arch);
    try testing.expectEqual(Target.OptLevel.none, target.opt_level);
    try testing.expect(!target.verify);
}
