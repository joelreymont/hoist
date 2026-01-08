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
const Imm64 = hoist.immediates.Imm64;
const entities = hoist.entities;
const value_list = hoist.value_list;
const Builder = hoist.builder.Builder;
const ExternalName = hoist.external_name.ExternalName;
const types = hoist.types;

/// Allocate executable memory for JIT code.
/// Uses platform-specific APIs to allocate memory with execute permissions.
fn allocExecutableMemory(_: std.mem.Allocator, size: usize) ![]align(std.heap.page_size_min) u8 {
    const page_size = std.heap.pageSize();
    const aligned_size = std.mem.alignForward(usize, size, page_size);

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
            return @as([*]align(std.heap.page_size_min) u8, @ptrCast(@alignCast(addr)))[0..aligned_size];
        },
        else => return error.UnsupportedPlatform,
    }
}

/// Make memory executable.
fn makeExecutable(memory: []align(std.heap.page_size_min) u8) !void {
    switch (builtin.os.tag) {
        .linux, .macos => {
            const prot = std.posix.PROT.READ | std.posix.PROT.EXEC;
            try std.posix.mprotect(memory, prot);

            // On ARM64, we must flush the instruction cache after writing code
            if (builtin.cpu.arch == .aarch64 or builtin.cpu.arch == .aarch64_be) {
                // Use __builtin___clear_cache equivalent
                // On macOS/iOS, we need to call sys_icache_invalidate
                // On Linux, we can use __builtin___clear_cache
                if (builtin.os.tag == .macos) {
                    // sys_icache_invalidate(memory.ptr, memory.len)
                    // This is exported by libSystem on macOS
                    const sys_icache_invalidate = struct {
                        extern "c" fn sys_icache_invalidate(start: *anyopaque, size: usize) void;
                    }.sys_icache_invalidate;
                    sys_icache_invalidate(memory.ptr, memory.len);
                }
            }
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

            // On Windows ARM64, flush instruction cache
            if (builtin.cpu.arch == .aarch64 or builtin.cpu.arch == .aarch64_be) {
                _ = windows.FlushInstructionCache(
                    windows.GetCurrentProcess(),
                    memory.ptr,
                    memory.len,
                );
            }
        },
        else => return error.UnsupportedPlatform,
    }
}

/// Free executable memory.
fn freeExecutableMemory(memory: []align(std.heap.page_size_min) u8) void {
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

test "JIT: CRITICAL - verify ABI calling convention" {
    // This is a critical test to verify that Zig can correctly call
    // JIT-compiled ARM64 code and read the w0 register as the return value.
    // If this fails, the calling convention is fundamentally broken.

    // Skip on unsupported platforms
    if (builtin.os.tag != .linux and builtin.os.tag != .macos and builtin.os.tag != .windows) {
        return error.SkipZigTest;
    }

    // Skip on non-ARM64 platforms
    if (builtin.cpu.arch != .aarch64 and builtin.cpu.arch != .aarch64_be) {
        return error.SkipZigTest;
    }

    // Hand-written ARM64 machine code:
    // movz w0, #123, lsl #0  (load 123 into w0)
    // ret                     (return)
    const code_bytes = [_]u8{
        0x60, 0x0f, 0x80, 0x52, // movz w0, #123 (NOTE: 0x60 not 0x6f - targets w0 not w15)
        0xc0, 0x03, 0x5f, 0xd6, // ret
    };

    std.debug.print("\n=== ABI VERIFICATION TEST ===\n", .{});
    std.debug.print("Hand-written machine code: ", .{});
    for (code_bytes) |byte| {
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});

    // Allocate executable memory
    const exec_mem = try allocExecutableMemory(testing.allocator, code_bytes.len);
    defer freeExecutableMemory(exec_mem);

    // Copy machine code
    @memcpy(exec_mem[0..code_bytes.len], &code_bytes);

    // Make executable
    try makeExecutable(exec_mem);

    std.debug.print("Calling JIT function at {*}...\n", .{exec_mem.ptr});

    // Call the JIT function
    const FnType = *const fn () callconv(.c) i32;
    const jit_fn: FnType = @ptrCast(exec_mem.ptr);
    const result = jit_fn();

    std.debug.print("Result: {}\n", .{result});

    // This is the critical test - if this fails, our calling convention is wrong
    if (result != 123) {
        std.debug.print("CRITICAL FAILURE: Expected 123, got {}\n", .{result});
        std.debug.print("This means the ABI/calling convention is broken!\n", .{});
        std.debug.print("Possible causes:\n", .{});
        std.debug.print("- Zig is not reading w0 as the return value\n", .{});
        std.debug.print("- Register preservation issue\n", .{});
        std.debug.print("- Calling convention mismatch\n", .{});
    }

    try testing.expectEqual(@as(i32, 123), result);
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
    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder
        .targetNative()
        .optLevel(.none)
        .build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Debug: Print generated machine code
    std.debug.print("\nGenerated code ({d} bytes):\n", .{code.code.items.len});
    for (code.code.items, 0..) |byte, i| {
        if (i % 4 == 0) std.debug.print("{x:0>8}: ", .{i});
        std.debug.print("{x:0>2} ", .{byte});
        if (i % 4 == 3) std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});

    // Allocate executable memory
    const exec_mem = try allocExecutableMemory(testing.allocator, code.code.items.len);
    defer freeExecutableMemory(exec_mem);

    // Copy machine code to executable memory
    @memcpy(exec_mem[0..code.code.items.len], code.code.items);

    // Make memory executable
    try makeExecutable(exec_mem);

    // Execute compiled code
    const FnType = *const fn () callconv(.c) i32;
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

    // Add block parameters for function arguments
    const param0 = try func.dfg.appendBlockParam(entry, Type.I64);
    const param1 = try func.dfg.appendBlockParam(entry, Type.I64);

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
    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder
        .targetNative()
        .optLevel(.none)
        .build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Allocate executable memory
    const exec_mem = try allocExecutableMemory(testing.allocator, code.code.items.len);
    defer freeExecutableMemory(exec_mem);

    // Copy machine code to executable memory
    @memcpy(exec_mem[0..code.code.items.len], code.code.items);

    // Make memory executable
    try makeExecutable(exec_mem);

    // Execute compiled code with different inputs
    const FnType = *const fn (i32, i32) callconv(.c) i32;
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

    // Add block parameters for function arguments
    const param0 = try func.dfg.appendBlockParam(entry, Type.I64);
    const param1 = try func.dfg.appendBlockParam(entry, Type.I64);

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
    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder
        .targetNative()
        .optLevel(.none)
        .build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Debug: Print generated machine code
    std.debug.print("\nGenerated machine code ({} bytes):\n", .{code.code.items.len});
    for (code.code.items, 0..) |byte, i| {
        if (i % 4 == 0) std.debug.print("\n{x:0>8}: ", .{i});
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("\n\n", .{});

    // Allocate executable memory
    const exec_mem = try allocExecutableMemory(testing.allocator, code.code.items.len);
    defer freeExecutableMemory(exec_mem);

    // Copy machine code to executable memory
    @memcpy(exec_mem[0..code.code.items.len], code.code.items);

    // Make memory executable
    try makeExecutable(exec_mem);

    // Execute compiled code with different inputs
    const FnType = *const fn (i64, i64) callconv(.c) i64;
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
        try testing.expect(@intFromPtr(mem.ptr) % std.heap.page_size_min == 0);
    }
}

test "JIT: executable memory boundaries" {
    // Skip on unsupported platforms
    if (builtin.os.tag != .linux and builtin.os.tag != .macos and builtin.os.tag != .windows) {
        return error.SkipZigTest;
    }

    // Test allocation of different sizes
    const page_size = std.heap.pageSize();
    const test_sizes = [_]usize{
        1, // Minimum
        page_size, // Exactly one page
        page_size + 1, // Just over one page
        page_size * 4, // Multiple pages
    };

    for (test_sizes) |size| {
        const mem = try allocExecutableMemory(testing.allocator, size);
        defer freeExecutableMemory(mem);

        // Verify size is page-aligned
        const aligned_size = std.mem.alignForward(usize, size, page_size);
        try testing.expectEqual(aligned_size, mem.len);

        // Verify we can write to the entire allocated region
        @memset(mem, 0xCC); // INT3 on x86
    }
}

test "JIT: register spilling with 40+ live values" {
    // Skip on unsupported platforms
    if (builtin.os.tag != .linux and builtin.os.tag != .macos and builtin.os.tag != .windows) {
        return error.SkipZigTest;
    }

    // Create function with 40+ intermediate values that are all live simultaneously
    // This forces register spilling since AArch64 only has 31 integer registers.
    // Function computes: f(x) = v0 + v1 + v2 + ... + v39
    // where each vi is derived from x through different operations.
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "spill_test", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Function parameter
    const param = try func.dfg.appendBlockParam(entry, Type.I64);

    // Create 40 intermediate values, each derived from the parameter
    // All values will be live at the same time when we sum them
    var values: [40]hoist.entities.Value = undefined;

    // Generate values: v[i] = param + i
    var i: u32 = 0;
    while (i < 40) : (i += 1) {
        const const_data = InstructionData{
            .unary_imm = .{
                .opcode = .iconst,
                .imm = Imm64.new(@as(i64, @intCast(i))),
            },
        };
        const const_inst = try func.dfg.makeInst(const_data);
        const const_val = try func.dfg.appendInstResult(const_inst, Type.I64);
        try func.layout.appendInst(const_inst, entry);

        const add_data = InstructionData{
            .binary = .{
                .opcode = .iadd,
                .args = .{ param, const_val },
            },
        };
        const add_inst = try func.dfg.makeInst(add_data);
        values[i] = try func.dfg.appendInstResult(add_inst, Type.I64);
        try func.layout.appendInst(add_inst, entry);
    }

    // Now sum all 40 values together (all become live)
    var sum = values[0];
    i = 1;
    while (i < 40) : (i += 1) {
        const sum_data = InstructionData{
            .binary = .{
                .opcode = .iadd,
                .args = .{ sum, values[i] },
            },
        };
        const sum_inst = try func.dfg.makeInst(sum_data);
        sum = try func.dfg.appendInstResult(sum_inst, Type.I64);
        try func.layout.appendInst(sum_inst, entry);
    }

    // Return the sum
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = sum,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile function
    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder
        .targetNative()
        .optLevel(.none)
        .build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Allocate executable memory
    const exec_mem = try allocExecutableMemory(testing.allocator, code.code.items.len);
    defer freeExecutableMemory(exec_mem);

    // Copy machine code to executable memory
    @memcpy(exec_mem[0..code.code.items.len], code.code.items);

    // Make memory executable
    try makeExecutable(exec_mem);

    // Execute compiled code
    // Expected result: sum of (x+0) + (x+1) + ... + (x+39)
    // = 40*x + (0+1+2+...+39)
    // = 40*x + (39*40/2)
    // = 40*x + 780
    const FnType = *const fn (i64) callconv(.c) i64;
    const jit_fn: FnType = @ptrCast(exec_mem.ptr);

    try testing.expectEqual(@as(i64, 780), jit_fn(0)); // 40*0 + 780
    try testing.expectEqual(@as(i64, 820), jit_fn(1)); // 40*1 + 780
    try testing.expectEqual(@as(i64, 1780), jit_fn(25)); // 40*25 + 780
    try testing.expectEqual(@as(i64, 4780), jit_fn(100)); // 40*100 + 780
}

test "try_call basic lowering" {
    const allocator = testing.allocator;

    // Build signature: fn() -> i32
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.returns.append(allocator, hoist.abi_param.AbiParam.new(Type.I32));

    // Create function
    var func = try Function.init(allocator, "test_try_call", sig);
    defer func.deinit();

    // Build IR:
    // block0:
    //   v0 = iconst.i32 42
    //   v1 = try_call some_func() -> block1, block2  // normal, exception
    // block1:  // normal return
    //   return v0
    // block2:  // exception handler (landing pad)
    //   v2 = iconst.i32 99
    //   return v2

    const block0 = try func.dfg.makeBlock();
    const block1 = try func.dfg.makeBlock();
    const block2 = try func.dfg.makeBlock();

    // Mark block2 as landing pad
    func.dfg.blocks.items(.data)[block2.index()].is_landing_pad = true;

    try func.layout.appendBlock(block0);
    try func.layout.appendBlock(block1);
    try func.layout.appendBlock(block2);

    // block0: v0 = iconst.i32 42
    const v0_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = Imm64.new(42),
    } };
    const v0_inst = try func.dfg.makeInst(v0_data);
    try func.layout.appendInst(v0_inst, block0);
    const v0 = func.dfg.firstResult(v0_inst).?;

    // block0: try_call (skeleton - needs proper function reference)
    // For now, we create the try_call instruction data but can't lower it
    // because we need a valid FuncRef (external function metadata)
    // This test verifies the IR accepts try_call instructions
    const empty_args = try func.dfg.value_lists.allocate(allocator, &.{});
    const try_call_data = InstructionData{
        .try_call = .{
            .opcode = .try_call,
            .func_ref = entities.FuncRef.new(0), // Placeholder
            .args = empty_args,
            .normal_successor = block1,
            .exception_successor = block2,
        },
    };
    const try_call_inst = try func.dfg.makeInst(try_call_data);
    try func.layout.appendInst(try_call_inst, block0);
    // try_call has no result (returns void)

    // block0: jump to block1 (after try_call succeeds)
    const jump_data = InstructionData{ .jump = .{
        .opcode = .jump,
        .destination = block1,
    } };
    const jump_inst = try func.dfg.makeInst(jump_data);
    try func.layout.appendInst(jump_inst, block0);

    // block1: return v0
    const ret1_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v0,
    } };
    const ret1_inst = try func.dfg.makeInst(ret1_data);
    try func.layout.appendInst(ret1_inst, block1);

    // block2: v2 = iconst.i32 99
    const v2_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = Imm64.new(99),
    } };
    const v2_inst = try func.dfg.makeInst(v2_data);
    try func.layout.appendInst(v2_inst, block2);
    const v2 = func.dfg.firstResult(v2_inst).?;

    // block2: return v2
    const ret2_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret2_inst = try func.dfg.makeInst(ret2_data);
    try func.layout.appendInst(ret2_inst, block2);

    // Verify IR structure
    try testing.expectEqual(@as(usize, 3), func.layout.blocks.items.len);

    // Verify block0 has try_call instruction
    var found_try_call = false;
    var inst_iter = func.layout.blockInsts(block0);
    while (inst_iter.next()) |inst| {
        const inst_data = func.dfg.insts.items(.data)[inst.index()];
        if (inst_data == .try_call) {
            found_try_call = true;
            // Verify successors
            try testing.expectEqual(block1, inst_data.try_call.normal_successor);
            try testing.expectEqual(block2, inst_data.try_call.exception_successor);
        }
    }
    try testing.expect(found_try_call);

    // Verify block2 is marked as landing pad
    try testing.expect(func.dfg.blocks.items(.data)[block2.index()].is_landing_pad);

    // Note: Full lowering test would require:
    // 1. Valid external function reference (FuncRef with metadata)
    // 2. Compilation through lower/regalloc/emit pipeline
    // 3. Verification of BL+CBZ+B instruction sequence
    // For now, this tests IR construction and basic validation
}

test "landing pad with exception edge" {
    const allocator = testing.allocator;

    // Build signature: fn() -> i32
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.returns.append(allocator, hoist.abi_param.AbiParam.new(Type.I32));

    // Create function
    var func = try Function.init(allocator, "test_landing_pad", sig);
    defer func.deinit();

    // Build IR with try_call and landing pad:
    // block0:
    //   v0 = iconst.i32 10
    //   try_call some_func() -> block1, block2
    // block1: (normal)
    //   return v0
    // block2: (landing pad)
    //   v1 = landingpad
    //   v2 = iconst.i32 20
    //   return v2

    const block0 = try func.dfg.makeBlock();
    const block1 = try func.dfg.makeBlock();
    const block2 = try func.dfg.makeBlock();

    // Mark block2 as landing pad
    func.dfg.blocks.items(.data)[block2.index()].is_landing_pad = true;

    try func.layout.appendBlock(block0);
    try func.layout.appendBlock(block1);
    try func.layout.appendBlock(block2);

    // block0: v0 = iconst.i32 10
    const v0_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = Imm64.new(10),
    } };
    const v0_inst = try func.dfg.makeInst(v0_data);
    try func.layout.appendInst(v0_inst, block0);
    const v0 = func.dfg.firstResult(v0_inst).?;

    // block0: try_call
    const empty_args = try func.dfg.value_lists.allocate(allocator, &.{});
    const try_call_data = InstructionData{ .try_call = .{
        .opcode = .try_call,
        .func_ref = entities.FuncRef.new(0),
        .args = empty_args,
        .normal_successor = block1,
        .exception_successor = block2,
    } };
    const try_call_inst = try func.dfg.makeInst(try_call_data);
    try func.layout.appendInst(try_call_inst, block0);

    // block0: jump block1
    const jump_data = InstructionData{ .jump = .{
        .opcode = .jump,
        .destination = block1,
    } };
    const jump_inst = try func.dfg.makeInst(jump_data);
    try func.layout.appendInst(jump_inst, block0);

    // block1: return v0
    const ret1_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v0,
    } };
    const ret1_inst = try func.dfg.makeInst(ret1_data);
    try func.layout.appendInst(ret1_inst, block1);

    // block2: v1 = landingpad (exception value in X0)
    const landingpad_data = InstructionData{ .nullary = .{
        .opcode = .landingpad,
    } };
    const landingpad_inst = try func.dfg.makeInst(landingpad_data);
    try func.layout.appendInst(landingpad_inst, block2);
    const v1 = func.dfg.firstResult(landingpad_inst).?;

    // block2: v2 = iconst.i32 20
    const v2_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = Imm64.new(20),
    } };
    const v2_inst = try func.dfg.makeInst(v2_data);
    try func.layout.appendInst(v2_inst, block2);
    const v2 = func.dfg.firstResult(v2_inst).?;

    // block2: return v2
    const ret2_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret2_inst = try func.dfg.makeInst(ret2_data);
    try func.layout.appendInst(ret2_inst, block2);

    // Compute CFG to verify exception edges
    const cfg_mod = @import("hoist").cfg;
    var cfg = cfg_mod.CFG.init(allocator);
    defer cfg.deinit();
    try cfg.compute(&func);

    // Verify block0 has block1 as normal successor
    const block0_node = cfg.nodes.get(block0).?;
    try testing.expect(block0_node.successors.contains(block1));

    // Verify block0 has block2 as exception successor
    try testing.expect(block0_node.exception_successors.contains(block2));

    // Verify block2 is marked as landing pad
    try testing.expect(func.dfg.blocks.items(.data)[block2.index()].is_landing_pad);

    // Verify block2 has landingpad instruction
    var found_landingpad = false;
    var inst_iter = func.layout.blockInsts(block2);
    while (inst_iter.next()) |inst| {
        const inst_data = func.dfg.insts.items(.data)[inst.index()];
        if (inst_data == .nullary and inst_data.nullary.opcode == .landingpad) {
            found_landingpad = true;
            // landingpad returns exception value (conceptually from X0)
            try testing.expectEqual(v1, func.dfg.firstResult(inst).?);
        }
    }
    try testing.expect(found_landingpad);

    // Verify exception value (v1) is available in landing pad
    _ = v1; // v1 would be used in real exception handling code
}

test "exception propagation with unwinding" {
    const allocator = testing.allocator;

    // Build signature: fn(i32) -> i32
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, hoist.abi_param.AbiParam.new(Type.I32));
    try sig.returns.append(allocator, hoist.abi_param.AbiParam.new(Type.I32));

    // Create function
    var func = try Function.init(allocator, "test_exception_propagation", sig);
    defer func.deinit();

    // Build IR simulating exception propagation:
    // block0(v0: i32):  // Entry with parameter
    //   v1 = iadd v0, v0  // Double the input
    //   try_call throw_func() -> block1, block2
    // block1: (normal - no exception)
    //   v2 = iadd v1, 10
    //   return v2
    // block2: (landing pad - exception caught)
    //   v3 = landingpad  // Exception value from X0
    //   v4 = iadd v1, 100  // Use pre-exception state (v1)
    //   return v4

    const block0 = try func.dfg.makeBlock();
    const block1 = try func.dfg.makeBlock();
    const block2 = try func.dfg.makeBlock();

    // Mark block2 as landing pad
    func.dfg.blocks.items(.data)[block2.index()].is_landing_pad = true;

    try func.layout.appendBlock(block0);
    try func.layout.appendBlock(block1);
    try func.layout.appendBlock(block2);

    // block0: function parameter
    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);

    // block0: v1 = iadd v0, v0
    const v1_data = InstructionData{ .binary = .{
        .opcode = .iadd,
        .args = .{ v0, v0 },
    } };
    const v1_inst = try func.dfg.makeInst(v1_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = func.dfg.firstResult(v1_inst).?;

    // block0: try_call throw_func()
    const empty_args = try func.dfg.value_lists.allocate(allocator, &.{});
    const try_call_data = InstructionData{
        .try_call = .{
            .opcode = .try_call,
            .func_ref = entities.FuncRef.new(0), // Placeholder
            .args = empty_args,
            .normal_successor = block1,
            .exception_successor = block2,
        },
    };
    const try_call_inst = try func.dfg.makeInst(try_call_data);
    try func.layout.appendInst(try_call_inst, block0);

    // block0: jump block1 (if no exception)
    const jump_data = InstructionData{ .jump = .{
        .opcode = .jump,
        .destination = block1,
    } };
    const jump_inst = try func.dfg.makeInst(jump_data);
    try func.layout.appendInst(jump_inst, block0);

    // block1: v2 = iadd v1, 10
    const v2_data = InstructionData{ .binary_imm64 = .{
        .opcode = .iadd_imm,
        .arg = v1,
        .imm = Imm64.new(10),
    } };
    const v2_inst = try func.dfg.makeInst(v2_data);
    try func.layout.appendInst(v2_inst, block1);
    const v2 = func.dfg.firstResult(v2_inst).?;

    // block1: return v2
    const ret1_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret1_inst = try func.dfg.makeInst(ret1_data);
    try func.layout.appendInst(ret1_inst, block1);

    // block2: v3 = landingpad
    const landingpad_data = InstructionData{ .nullary = .{
        .opcode = .landingpad,
    } };
    const landingpad_inst = try func.dfg.makeInst(landingpad_data);
    try func.layout.appendInst(landingpad_inst, block2);
    const v3 = func.dfg.firstResult(landingpad_inst).?;

    // block2: v4 = iadd v1, 100 (v1 is live across try_call)
    const v4_data = InstructionData{ .binary_imm64 = .{
        .opcode = .iadd_imm,
        .arg = v1,
        .imm = Imm64.new(100),
    } };
    const v4_inst = try func.dfg.makeInst(v4_data);
    try func.layout.appendInst(v4_inst, block2);
    const v4 = func.dfg.firstResult(v4_inst).?;

    // block2: return v4
    const ret2_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v4,
    } };
    const ret2_inst = try func.dfg.makeInst(ret2_data);
    try func.layout.appendInst(ret2_inst, block2);

    // Compute CFG for liveness analysis
    const cfg_mod = @import("hoist").cfg;
    var cfg = cfg_mod.CFG.init(allocator);
    defer cfg.deinit();
    try cfg.compute(&func);

    // Verify CFG exception edges
    const block0_node = cfg.nodes.get(block0).?;
    try testing.expect(block0_node.successors.contains(block1));
    try testing.expect(block0_node.exception_successors.contains(block2));

    // Verify v1 is used in both normal and exception paths
    // This validates that values must be preserved across try_call
    var v1_used_in_block1 = false;
    var v1_used_in_block2 = false;

    var iter1 = func.layout.blockInsts(block1);
    while (iter1.next()) |inst| {
        const inst_data = func.dfg.insts.items(.data)[inst.index()];
        if (inst_data == .binary_imm64) {
            if (inst_data.binary_imm64.arg.eql(v1)) {
                v1_used_in_block1 = true;
            }
        }
    }

    var iter2 = func.layout.blockInsts(block2);
    while (iter2.next()) |inst| {
        const inst_data = func.dfg.insts.items(.data)[inst.index()];
        if (inst_data == .binary_imm64) {
            if (inst_data.binary_imm64.arg.eql(v1)) {
                v1_used_in_block2 = true;
            }
        }
    }

    try testing.expect(v1_used_in_block1);
    try testing.expect(v1_used_in_block2);

    // This validates key exception handling properties:
    // 1. Values live at try_call must be preserved across exception edge
    // 2. Landing pad receives exception value via landingpad instruction
    // 3. Exception handler can access both exception value (v3) and pre-exception state (v1)
    // 4. Stack unwinding would restore v1 from spill slot if needed
    _ = v3; // Exception value would be used in real handler
}

test "try_call with external function reference" {
    const allocator = testing.allocator;

    // Create function signature for external function: (i64) -> i64
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, hoist.signature.AbiParam{
        .value_type = Type.I64,
        .purpose = .normal,
        .extension = .none,
    });
    try sig.returns.append(allocator, hoist.signature.AbiParam{
        .value_type = Type.I64,
        .purpose = .normal,
        .extension = .none,
    });

    // Create function with external function metadata
    var func = try Function.init(allocator, "test_func", sig);
    defer func.deinit();

    // Register external function in metadata table
    const ext_name = try ExternalName.init(allocator, "test_external");
    const sig_ref = entities.SigRef.new(0);
    try func.signatures.elems.append(allocator, sig);

    const func_ref = try func.func_metadata.registerExternalFunc(
        ext_name,
        sig_ref,
        .import,
    );

    // Build IR with try_call to external function
    // block0: v0 = iconst 42, try_call test_external(v0) -> block1, block2
    // block1: return v0
    // block2: v1 = landingpad, return v1

    const block0 = try func.dfg.makeBlock();
    const block1 = try func.dfg.makeBlock();
    const block2 = try func.dfg.makeBlock();

    try func.layout.appendBlock(block0);
    try func.layout.appendBlock(block1);
    try func.layout.appendBlock(block2);

    // Mark block2 as landing pad
    func.dfg.blocks.items(.is_landing_pad)[block2.index()] = true;

    // block0: v0 = iconst 42
    var builder = Builder.init(&func, block0);
    const v0 = try builder.insIconst(types.Type.I64, 42);

    // try_call test_external(v0) -> block1, block2
    const args = [_]entities.Value{v0};
    var args_list = entities.ValueList.empty();
    args_list = try func.dfg.value_lists.extend(allocator, args_list, &args);

    const try_call_inst = try func.dfg.makeTryCall(
        func_ref,
        args_list,
        block1,
        block2,
    );
    try func.layout.appendInst(try_call_inst, block0);

    // block1: return v0
    builder.switchBlock(block1);
    const ret_inst = try builder.insReturn(&[_]entities.Value{v0});
    try func.layout.appendInst(ret_inst, block1);

    // block2: v1 = landingpad, return v1
    builder.switchBlock(block2);
    const v1 = try builder.insLandingpad();
    const ret_inst2 = try builder.insReturn(&[_]entities.Value{v1});
    try func.layout.appendInst(ret_inst2, block2);

    // Verify IR structure
    try testing.expectEqual(@as(usize, 3), func.layout.blocks.elems.items.len);

    // Verify try_call instruction
    const inst_data = func.dfg.insts.items(.data)[try_call_inst.index()];
    try testing.expect(inst_data == .try_call);
    try testing.expectEqual(func_ref, inst_data.try_call.func_ref);
    try testing.expectEqual(block1, inst_data.try_call.normal_successor);
    try testing.expectEqual(block2, inst_data.try_call.exception_successor);

    // Verify function metadata
    const metadata = func.func_metadata.getMetadata(func_ref);
    try testing.expect(metadata != null);
    try testing.expectEqual(sig_ref, metadata.?.sig_ref);
    try testing.expectEqualStrings("test_external", metadata.?.name.name);

    // Test compilation would go here, but requires full lowering infrastructure
    // For now, this validates the FuncRef system and IR building
}
