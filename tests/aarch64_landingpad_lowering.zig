const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const compile_mod = hoist.codegen_compile;
const Context = hoist.codegen_context.Context;
const Inst = hoist.aarch64_inst.Inst;
const OperandSize = hoist.aarch64_inst.OperandSize;
const Reg = hoist.aarch64_inst.Reg;

test "aarch64: landingpad lowers to mov from x0" {
    var sig = Signature.init(testing.allocator, .fast);
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "landingpad_lower", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    func.dfg.blocks.elems.items[block0.toIndex()].is_landing_pad = true;
    try func.layout.appendBlock(block0);

    const lp_data = InstructionData{ .nullary = .{ .opcode = .landingpad } };
    const lp_inst = try func.dfg.makeInst(lp_data);
    const lp_val = try func.dfg.appendInstResult(lp_inst, Type.I64);
    try func.layout.appendInst(lp_inst, block0);

    const ret_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = lp_val,
    } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, block0);

    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();

    _ = try compile_mod.compile(&ctx, &func, &.{
        .arch = .aarch64,
        .opt_level = .none,
        .verify = false,
        .features = .{ .bits = 0 },
    });

    const lowered = ctx.aarch64_lowered orelse return error.LoweringFailed;
    var found = false;
    for (lowered.vcode.insns.items) |inst| {
        if (inst == .mov_rr and inst.mov_rr.src.eq(Reg.gpr(0))) {
            try testing.expectEqual(OperandSize.size64, inst.mov_rr.size);
            found = true;
            break;
        }
    }
    try testing.expect(found);
}
