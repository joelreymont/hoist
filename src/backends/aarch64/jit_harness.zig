//! JIT execution harness for testing code generation.
//!
//! Allocates executable memory, copies machine code, and executes it.
//! Used for end-to-end testing of code generation.

const std = @import("std");
const testing = std.testing;
const jit = @import("../../jit/memory.zig");

pub const JitMemory = jit.Mem;

/// Test helper: compile IR function and execute it with JIT.
/// Returns the compiled machine code and JIT memory for inspection/execution.
pub const CompileResult = struct {
    mem: JitMemory,
    code: []const u8,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.mem.deinit();
        allocator.free(self.code);
    }
};

/// Compile a function to machine code and load it into executable memory.
/// Caller owns returned CompileResult and must call deinit().
pub fn compileAndLoad(
    allocator: std.mem.Allocator,
    func: anytype,
) !CompileResult {
    const hoist = @import("../../root.zig");
    const ContextBuilder = hoist.context.ContextBuilder;

    // Compile function
    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    const compiled = try ctx.compileFunction(func);

    // Allocate JIT memory
    var mem = try JitMemory.init(allocator, compiled.code.items.len);
    errdefer mem.deinit();

    // Copy compiled code
    const code = try allocator.dupe(u8, compiled.code.items);
    errdefer allocator.free(code);

    // Write to executable memory
    try mem.write(code);

    return .{
        .mem = mem,
        .code = code,
    };
}

/// Test helper: compile and execute a function with () -> i32 signature.
pub fn compileAndExecuteVoidToI32(
    allocator: std.mem.Allocator,
    func: anytype,
) !i32 {
    var result = try compileAndLoad(allocator, func);
    defer result.deinit(allocator);

    const jit_fn = result.mem.getFnVoidToI32();
    return jit_fn();
}

/// Test helper: compile and execute a function with (i32, i32) -> i32 signature.
pub fn compileAndExecuteI32I32ToI32(
    allocator: std.mem.Allocator,
    func: anytype,
    arg1: i32,
    arg2: i32,
) !i32 {
    var result = try compileAndLoad(allocator, func);
    defer result.deinit(allocator);

    const jit_fn = result.mem.getFnI32I32ToI32();
    return jit_fn(arg1, arg2);
}

/// Test helper: compile and execute a function with (i64, i64) -> i64 signature.
pub fn compileAndExecuteI64I64ToI64(
    allocator: std.mem.Allocator,
    func: anytype,
    arg1: i64,
    arg2: i64,
) !i64 {
    var result = try compileAndLoad(allocator, func);
    defer result.deinit(allocator);

    const jit_fn = result.mem.getFnI64I64ToI64();
    return jit_fn(arg1, arg2);
}

test "JitMemory allocate and free" {
    if (builtin.os.tag != .macos and builtin.os.tag != .linux) {
        return error.SkipZigTest;
    }

    var mem = try JitMemory.init(testing.allocator, 4096);
    defer mem.deinit();

    try testing.expect(mem.len >= 4096);
    try testing.expect(@intFromPtr(mem.ptr) % std.mem.page_size == 0);
}

test "JitMemory write and execute - return constant" {
    if (builtin.os.tag != .macos and builtin.os.tag != .linux) {
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch != .aarch64) {
        return error.SkipZigTest;
    }

    var mem = try JitMemory.init(testing.allocator, 4096);
    defer mem.deinit();

    // ARM64 code to return 42:
    // MOV W0, #42
    // RET
    const code = [_]u8{
        0x40, 0x05, 0x80, 0x52, // MOV W0, #42 (0x2a)
        0xC0, 0x03, 0x5F, 0xD6, // RET
    };

    try mem.write(&code);

    const func = mem.getFnVoidToI32();
    const result = func();

    try testing.expectEqual(@as(i32, 42), result);
}

test "JitMemory write and execute - add function" {
    if (builtin.os.tag != .macos and builtin.os.tag != .linux) {
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch != .aarch64) {
        return error.SkipZigTest;
    }

    var mem = try JitMemory.init(testing.allocator, 4096);
    defer mem.deinit();

    // ARM64 code to add two i32 arguments (W0 + W1 -> W0):
    // ADD W0, W0, W1
    // RET
    const code = [_]u8{
        0x00, 0x00, 0x01, 0x0B, // ADD W0, W0, W1
        0xC0, 0x03, 0x5F, 0xD6, // RET
    };

    try mem.write(&code);

    const func = mem.getFnI32I32ToI32();
    const result = func(10, 32);

    try testing.expectEqual(@as(i32, 42), result);
}

test "JitMemory write and execute - i64 function" {
    if (builtin.os.tag != .macos and builtin.os.tag != .linux) {
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch != .aarch64) {
        return error.SkipZigTest;
    }

    var mem = try JitMemory.init(testing.allocator, 4096);
    defer mem.deinit();

    // ARM64 code to add two i64 arguments (X0 + X1 -> X0):
    // ADD X0, X0, X1
    // RET
    const code = [_]u8{
        0x00, 0x00, 0x01, 0x8B, // ADD X0, X0, X1
        0xC0, 0x03, 0x5F, 0xD6, // RET
    };

    try mem.write(&code);

    const func = mem.getFnI64I64ToI64();
    const result = func(100, 200);

    try testing.expectEqual(@as(i64, 300), result);
}
