const std = @import("std");
const hoist = @import("root");

/// Minimal example: compile a simple function that returns a constant.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create signature: fn() -> i32
    var sig = try hoist.signature.Signature.init(allocator);
    defer sig.deinit(allocator);

    try sig.returns.append(allocator, hoist.types.Type{ .int = .{ .width = 32 } });

    // Create function
    var func = try hoist.function.Function.init(allocator, "hello", sig);
    defer func.deinit();

    // Create entry block
    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create iconst instruction: return 42
    const const_data = hoist.instruction_data.InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 42,
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_val = try func.dfg.appendInstResult(const_inst, hoist.types.Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(const_inst, entry);

    // Create return instruction
    const ret_data = hoist.instruction_data.InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_val,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile to machine code
    var ctx = hoist.context.ContextBuilder.init(allocator)
        .target(.x86_64, .linux)
        .optLevel(.none)
        .verify(true)
        .build();

    const code = try ctx.compileFunction(&func);
    defer code.deinit(allocator);

    std.debug.print("Compiled 'hello' function:\n", .{});
    std.debug.print("  Code size: {d} bytes\n", .{code.buffer.len});
    std.debug.print("  Machine code: ", .{});
    for (code.buffer) |byte| {
        std.debug.print("{X:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});
}
