const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const Type = hoist.types.Type;
const Context = hoist.context.Context;
const ContextBuilder = hoist.context.ContextBuilder;
const InstructionData = hoist.instruction_data.InstructionData;

/// Allocate executable memory for JIT code.
/// Uses platform-specific APIs to allocate memory with execute permissions.
fn allocExecutableMemory(allocator: std.mem.Allocator, size: usize) ![]align(std.mem.page_size) u8 {
    const aligned_size = std.mem.alignForward(usize, size, std.mem.page_size);

    switch (builtin.os.tag) {
        .linux, .macos => {
            const prot = std.posix.PROT.READ | std.posix.PROT.WRITE;
            const flags = std.posix.MAP{ .TYPE = .PRIVATE, .ANONYMOUS = true };
            const mem = try std.posix.mmap(
                null,
                aligned_size,
                prot,
                flags,
                -1,
                0,
            );
            return mem;
        },
        .windows => {
            const windows = std.os.windows;
            const addr = try windows.VirtualAlloc(
                null,
                aligned_size,
                windows.MEM_COMMIT | windows.MEM_RESERVE,
                windows.PAGE_READWRITE,
            );
            return @as([*]align(std.mem.page_size) u8, @ptrCast(@alignCast(addr)))[0..aligned_size];
        },
        else => return error.UnsupportedPlatform,
    }
}

/// Make memory executable.
fn makeExecutable(memory: []align(std.mem.page_size) u8) !void {
    switch (builtin.os.tag) {
        .linux, .macos => {
            const prot = std.posix.PROT.READ | std.posix.PROT.EXEC;
            try std.posix.mprotect(memory, prot);
        },
        .windows => {
            const windows = std.os.windows;
            var old_protect: windows.DWORD = undefined;
            if (windows.VirtualProtect(
                memory.ptr,
                memory.len,
                windows.PAGE_EXECUTE_READ,
                &old_protect,
            ) == 0) {
                return error.ProtectFailed;
            }
        },
        else => return error.UnsupportedPlatform,
    }
}

/// Free executable memory.
fn freeExecutableMemory(memory: []align(std.mem.page_size) u8) void {
    switch (builtin.os.tag) {
        .linux, .macos => {
            std.posix.munmap(memory);
        },
        .windows => {
            const windows = std.os.windows;
            _ = windows.VirtualFree(memory.ptr, 0, windows.MEM_RELEASE);
        },
        else => {},
    }
}

test "JIT: compile and execute return constant i32" {
    // Skip on unsupported platforms
    if (builtin.os.tag != .linux and builtin.os.tag != .macos and builtin.os.tag != .windows) {
        return error.SkipZigTest;
    }

    // Create function: fn() -> i32 { return 42; }
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "const_42", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(42),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, Type.I32);
    try func.layout.appendInst(const_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile function
    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.none)
        .build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    // Allocate executable memory
    const exec_mem = try allocExecutableMemory(testing.allocator, code.code.len);
    defer freeExecutableMemory(exec_mem);

    // Copy machine code to executable memory
    @memcpy(exec_mem[0..code.code.len], code.code);

    // Make memory executable
    try makeExecutable(exec_mem);

    // Execute compiled code
    const FnType = *const fn () callconv(.C) i32;
    const jit_fn: FnType = @ptrCast(exec_mem.ptr);
    const result = jit_fn();

    // Verify result
    try testing.expectEqual(@as(i32, 42), result);
}

test "JIT: compile and execute i32 add" {
    // Skip on unsupported platforms
    if (builtin.os.tag != .linux and builtin.os.tag != .macos and builtin.os.tag != .windows) {
        return error.SkipZigTest;
    }

    // Create function: fn(a: i32, b: i32) -> i32 { return a + b; }
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "add_i32", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ param0, param1 },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, Type.I32);
    try func.layout.appendInst(add_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile function
    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.none)
        .build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    // Allocate executable memory
    const exec_mem = try allocExecutableMemory(testing.allocator, code.code.len);
    defer freeExecutableMemory(exec_mem);

    // Copy machine code to executable memory
    @memcpy(exec_mem[0..code.code.len], code.code);

    // Make memory executable
    try makeExecutable(exec_mem);

    // Execute compiled code with different inputs
    const FnType = *const fn (i32, i32) callconv(.C) i32;
    const jit_fn: FnType = @ptrCast(exec_mem.ptr);

    try testing.expectEqual(@as(i32, 5), jit_fn(2, 3));
    try testing.expectEqual(@as(i32, 0), jit_fn(0, 0));
    try testing.expectEqual(@as(i32, -1), jit_fn(10, -11));
    try testing.expectEqual(@as(i32, 100), jit_fn(50, 50));
}

test "JIT: compile and execute i64 multiply" {
    // Skip on unsupported platforms
    if (builtin.os.tag != .linux and builtin.os.tag != .macos and builtin.os.tag != .windows) {
        return error.SkipZigTest;
    }

    // Create function: fn(a: i64, b: i64) -> i64 { return a * b; }
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "mul_i64", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    const mul_data = InstructionData{
        .binary = .{
            .opcode = .imul,
            .args = .{ param0, param1 },
        },
    };
    const mul_inst = try func.dfg.makeInst(mul_data);
    const mul_result = try func.dfg.appendInstResult(mul_inst, Type.I64);
    try func.layout.appendInst(mul_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = mul_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile function
    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.none)
        .build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    // Allocate executable memory
    const exec_mem = try allocExecutableMemory(testing.allocator, code.code.len);
    defer freeExecutableMemory(exec_mem);

    // Copy machine code to executable memory
    @memcpy(exec_mem[0..code.code.len], code.code);

    // Make memory executable
    try makeExecutable(exec_mem);

    // Execute compiled code with different inputs
    const FnType = *const fn (i64, i64) callconv(.C) i64;
    const jit_fn: FnType = @ptrCast(exec_mem.ptr);

    try testing.expectEqual(@as(i64, 6), jit_fn(2, 3));
    try testing.expectEqual(@as(i64, 0), jit_fn(0, 100));
    try testing.expectEqual(@as(i64, 25), jit_fn(5, 5));
    try testing.expectEqual(@as(i64, 1000000), jit_fn(1000, 1000));
}

test "JIT: memory management with multiple allocations" {
    // Skip on unsupported platforms
    if (builtin.os.tag != .linux and builtin.os.tag != .macos and builtin.os.tag != .windows) {
        return error.SkipZigTest;
    }

    // Test that we can allocate, use, and free multiple executable memory regions
    const sizes = [_]usize{ 64, 128, 256, 512, 1024 };

    for (sizes) |size| {
        const mem = try allocExecutableMemory(testing.allocator, size);
        defer freeExecutableMemory(mem);

        // Write some data
        @memset(mem[0..size], 0x90); // NOP instruction on x86

        // Make executable
        try makeExecutable(mem);

        // Verify alignment
        try testing.expect(@intFromPtr(mem.ptr) % std.mem.page_size == 0);
    }
}

test "JIT: executable memory boundaries" {
    // Skip on unsupported platforms
    if (builtin.os.tag != .linux and builtin.os.tag != .macos and builtin.os.tag != .windows) {
        return error.SkipZigTest;
    }

    // Test allocation of different sizes
    const test_sizes = [_]usize{
        1, // Minimum
        std.mem.page_size, // Exactly one page
        std.mem.page_size + 1, // Just over one page
        std.mem.page_size * 4, // Multiple pages
    };

    for (test_sizes) |size| {
        const mem = try allocExecutableMemory(testing.allocator, size);
        defer freeExecutableMemory(mem);

        // Verify size is page-aligned
        const aligned_size = std.mem.alignForward(usize, size, std.mem.page_size);
        try testing.expectEqual(aligned_size, mem.len);

        // Verify we can write to the entire allocated region
        @memset(mem, 0xCC); // INT3 on x86
    }
}
