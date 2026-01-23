const std = @import("std");
const builtin = @import("builtin");
const hoist = @import("hoist");

// Standalone E2E test - bypasses test framework
// Compiles a simple function and examines generated code

const Signature = hoist.signature.Signature;
const Function = hoist.function.Function;
const Type = hoist.types.Type;
const Context = hoist.context.Context;
const ContextBuilder = hoist.context.ContextBuilder;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const compile = hoist.codegen.compile;

const pthread_jit_write_protect_np = struct {
    extern "c" fn pthread_jit_write_protect_np(enabled: c_int) void;
}.pthread_jit_write_protect_np;

extern "c" fn sys_icache_invalidate(start: *const anyopaque, len: usize) void;

fn allocExecutableMemory(size: usize) ![]align(std.heap.page_size_min) u8 {
    const page_size = std.heap.pageSize();
    const aligned_size = std.mem.alignForward(usize, size, page_size);

    if (builtin.os.tag == .macos and (builtin.cpu.arch == .aarch64 or builtin.cpu.arch == .aarch64_be)) {
        const prot = std.posix.PROT.READ | std.posix.PROT.WRITE | std.posix.PROT.EXEC;
        const flags = std.posix.MAP{ .TYPE = .PRIVATE, .ANONYMOUS = true, .JIT = true };
        const mem = try std.posix.mmap(null, aligned_size, prot, flags, -1, 0);
        pthread_jit_write_protect_np(0); // Allow writing
        return mem;
    } else {
        const prot = std.posix.PROT.READ | std.posix.PROT.WRITE;
        const flags = std.posix.MAP{ .TYPE = .PRIVATE, .ANONYMOUS = true };
        return try std.posix.mmap(null, aligned_size, prot, flags, -1, 0);
    }
}

fn makeExecutable(memory: []align(std.heap.page_size_min) u8) !void {
    if (builtin.os.tag == .macos and (builtin.cpu.arch == .aarch64 or builtin.cpu.arch == .aarch64_be)) {
        pthread_jit_write_protect_np(1); // Enable execute, disable write
        sys_icache_invalidate(memory.ptr, memory.len);
    } else {
        const prot = std.posix.PROT.READ | std.posix.PROT.EXEC;
        try std.posix.mprotect(memory, prot);
    }
}

fn freeExecutableMemory(memory: []align(std.heap.page_size_min) u8) void {
    std.posix.munmap(memory);
}

pub fn main() !void {
    std.debug.print("\n=== Standalone E2E Test: return 42 ===\n", .{});

    if (builtin.cpu.arch != .aarch64 and builtin.cpu.arch != .aarch64_be) {
        std.debug.print("SKIP: Not running on ARM64\n", .{});
        return;
    }

    const allocator = std.heap.page_allocator;

    // Build IR for: fn() -> i32 { return 42; }
    var sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.returns.append(allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_return_42", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // iconst 42
    const const_data = hoist.instruction_data.InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(42),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, Type.I32);
    try func.layout.appendInst(const_inst, entry);

    // return const_result
    const ret_data = hoist.instruction_data.InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    std.debug.print("\n--- IR Function ---\n", .{});
    std.debug.print("Signature: () -> i32\n", .{});
    std.debug.print("Body: iconst.i32 42; return\n", .{});

    // Compile to machine code
    std.debug.print("\n--- Compiling to ARM64 ---\n", .{});
    var builder = ContextBuilder.init(allocator);
    const native_builder = try builder.targetNative();
    var ctx = native_builder.optLevel(.none).build();
    const compiled = try ctx.compileFunction(&func);

    std.debug.print("Generated {} bytes of machine code\n", .{compiled.code.items.len});

    std.debug.print("\n--- Generated Machine Code (hex) ---\n", .{});
    for (compiled.code.items, 0..) |byte, i| {
        if (i % 16 == 0) {
            if (i > 0) std.debug.print("\n", .{});
            std.debug.print("{x:0>4}: ", .{i});
        }
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});

    std.debug.print("\n--- Disassembly Instructions ---\n", .{});
    std.debug.print("To disassemble, run:\n", .{});
    std.debug.print("  echo '", .{});
    for (compiled.code.items) |byte| {
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("' | xxd -r -p > /tmp/code.bin\n", .{});
    std.debug.print("  # Then use online disassembler or:\n", .{});
    std.debug.print("  # lldb -b -o 'target create /tmp/code.bin' -o 'disassemble -s 0 -c 10'\n", .{});

    std.debug.print("\n--- Expected Code ---\n", .{});
    std.debug.print("movz w0, #42    ; 60 0f 80 52\n", .{});
    std.debug.print("ret             ; c0 03 5f d6\n", .{});
    std.debug.print("Total: 8 bytes\n", .{});

    // Allocate executable memory
    std.debug.print("\n--- Executing JIT Code ---\n", .{});
    const exec_mem = try allocExecutableMemory(compiled.code.items.len);
    defer freeExecutableMemory(exec_mem);

    @memcpy(exec_mem[0..compiled.code.items.len], compiled.code.items);

    try makeExecutable(exec_mem);

    // Call the JIT function
    const FnType = *const fn () callconv(.c) i32;
    const jit_fn: FnType = @ptrCast(exec_mem.ptr);
    const result = jit_fn();

    std.debug.print("Result: {}\n", .{result});

    if (result == 42) {
        std.debug.print("\n✓ SUCCESS! Generated code works correctly!\n", .{});
    } else {
        std.debug.print("\n✗ FAILURE! Expected 42, got {}\n", .{result});
        std.debug.print("This means our code generation has a bug.\n", .{});
        return error.CodeGenerationBug;
    }
}
