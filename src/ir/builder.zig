const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const function = @import("function.zig");
const entities = @import("entities.zig");
const types = @import("types.zig");
const opcodes = @import("opcodes.zig");
const instruction_data = @import("instruction_data.zig");
const dfg_mod = @import("dfg.zig");

const Function = function.Function;
const Block = entities.Block;
const Inst = entities.Inst;
const Value = entities.Value;
const FuncRef = entities.FuncRef;
const Type = types.Type;
const Opcode = opcodes.Opcode;
const InstructionData = instruction_data.InstructionData;
const BinaryData = instruction_data.BinaryData;
const UnaryData = instruction_data.UnaryData;
const UnaryImmData = instruction_data.UnaryImmData;
const NullaryData = instruction_data.NullaryData;
const TernaryData = instruction_data.TernaryData;
const IntCompareData = instruction_data.IntCompareData;
const FloatCompareData = instruction_data.FloatCompareData;
const BranchData = instruction_data.BranchData;
const LoadData = instruction_data.LoadData;
const StoreData = instruction_data.StoreData;
const TryCallData = instruction_data.TryCallData;
const Imm64 = @import("immediates.zig").Imm64;
const IntCC = @import("condcodes.zig").IntCC;
const FloatCC = @import("condcodes.zig").FloatCC;
const MemFlags = @import("memflags.zig").MemFlags;

/// Function builder - ergonomic IR construction.
pub const FunctionBuilder = struct {
    func: *Function,
    current_block: ?Block,

    const Self = @This();

    pub fn init(func: *Function) Self {
        return .{
            .func = func,
            .current_block = null,
        };
    }

    pub fn createBlock(self: *Self) !Block {
        const block = Block.new(self.func.layout.blocks.elems.items.len);
        return block;
    }

    pub fn switchToBlock(self: *Self, block: Block) void {
        self.current_block = block;
    }

    pub fn appendBlockParam(self: *Self, block: Block, ty: Type) !Value {
        const block_data = try self.func.dfg.blocks.getOrDefault(block);
        const num: u16 = @intCast(self.func.dfg.value_lists.len(block_data.params));
        const val_idx = self.func.dfg.values.elems.items.len;
        const value_data = try self.func.dfg.values.getOrDefault(Value.new(val_idx));
        const val = Value.new(val_idx);
        value_data.* = dfg_mod.ValueData.param(ty, num, block);
        try self.func.dfg.value_lists.push(&block_data.params, val);
        return val;
    }

    pub fn appendBlock(self: *Self, block: Block) !void {
        try self.func.layout.appendBlock(block);
    }

    pub fn iconst(self: *Self, ty: Type, imm: i64) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        // Create unary_imm iconst instruction with immediate value
        const inst_data = InstructionData{ .unary_imm = UnaryImmData.init(.iconst, Imm64.new(imm)) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn iadd(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.iadd, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn isub(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.isub, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn imul(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.imul, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn udiv(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.udiv, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn sdiv(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.sdiv, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn ishl(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.ishl, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn ushr(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.ushr, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn sshr(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.sshr, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn band(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.band, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn bor(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.bor, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn bxor(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.bxor, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn bnot(self: *Self, ty: Type, val: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .unary = UnaryData.init(.bnot, val) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn fadd(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.fadd, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn fsub(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.fsub, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn fmul(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.fmul, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn fdiv(self: *Self, ty: Type, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .binary = BinaryData.init(.fdiv, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn sextend(self: *Self, ty: Type, val: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .unary = UnaryData.init(.sextend, val) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn uextend(self: *Self, ty: Type, val: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .unary = UnaryData.init(.uextend, val) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn bitcast(self: *Self, ty: Type, val: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .unary = UnaryData.init(.bitcast, val) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn bmask(self: *Self, ty: Type, val: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .unary = UnaryData.init(.bmask, val) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn icmp(self: *Self, ty: Type, cond: IntCC, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .int_compare = IntCompareData.init(.icmp, cond, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn fcmp(self: *Self, ty: Type, cond: FloatCC, lhs: Value, rhs: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .float_compare = FloatCompareData.init(.fcmp, cond, lhs, rhs) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn select(self: *Self, ty: Type, cond: Value, then_val: Value, else_val: Value) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .ternary = TernaryData.init(.select, cond, then_val, else_val) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn load(self: *Self, ty: Type, addr: Value, flags: MemFlags) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .load = LoadData.init(.load, flags, addr, Imm64.new(0)) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
        return try self.func.dfg.appendInstResult(inst, ty);
    }

    pub fn store(self: *Self, val: Value, addr: Value, flags: MemFlags) !void {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .store = StoreData.init(.store, flags, val, addr, Imm64.new(0)) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
    }

    pub fn brif(self: *Self, cond: Value, then_block: Block, else_block: Block) !void {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .branch = BranchData.init(.brif, cond, then_block, else_block) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
    }

    pub fn jump(self: *Self, dest: Block) !void {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .jump = instruction_data.JumpData.init(.jump, dest) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
    }

    pub fn ret(self: *Self) !void {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .nullary = NullaryData.init(.@"return") };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
    }

    /// Emit a sequence point for debug information.
    /// This marks a source location boundary for debuggers.
    /// Has no runtime effect - purely metadata.
    pub fn sequencePoint(self: *Self) !void {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .nullary = NullaryData.init(.sequence_point) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
    }

    /// Emit a Spectre mitigation fence.
    /// Prevents speculative execution across security boundaries.
    /// Has no runtime effect on non-vulnerable CPUs.
    pub fn spectreFence(self: *Self) !void {
        const block = self.current_block orelse return error.NoCurrentBlock;

        const inst_data = InstructionData{ .nullary = NullaryData.init(.spectre_fence) };
        const inst = try self.func.dfg.makeInst(inst_data);

        try self.func.layout.appendInst(inst, block);
    }

    pub fn instTryCall(
        self: *Self,
        callee: FuncRef,
        args: []const Value,
        normal_block: Block,
        exception_block: Block,
    ) !Value {
        const block = self.current_block orelse return error.NoCurrentBlock;

        // Create empty args list and populate with provided arguments
        var args_list = instruction_data.ValueList.default();
        try self.func.dfg.value_lists.extend(&args_list, args);

        // Create try_call instruction with both successors
        const inst_data = InstructionData{
            .try_call = TryCallData{
                .opcode = .try_call,
                .func_ref = callee,
                .args = args_list,
                .normal_successor = normal_block,
                .exception_successor = exception_block,
            },
        };
        const inst = try self.func.dfg.makeInst(inst_data);

        // Append instruction to current block
        try self.func.layout.appendInst(inst, block);

        // Return the call result value
        return try self.func.dfg.appendInstResult(inst, types.Type.I64);
    }
};

test "FunctionBuilder basic" {
    const sig = @import("signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = FunctionBuilder.init(&func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    try testing.expectEqual(block, builder.current_block.?);
}

test "FunctionBuilder iconst and iadd" {
    const sig = @import("signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = FunctionBuilder.init(&func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v1 = try builder.iconst(Type.I32, 10);
    const v2 = try builder.iconst(Type.I32, 20);
    _ = try builder.iadd(Type.I32, v1, v2);
    try builder.ret();

    try testing.expectEqual(@as(usize, 3), func.dfg.insts.elems.items.len);
    try testing.expectEqual(@as(usize, 4), func.layout.insts.elems.items.len);

    // Verify iconst immediate values are stored correctly
    const v1_def = func.dfg.valueDef(v1).?;
    const v1_inst = v1_def.unwrapInst();
    const v1_data = func.dfg.insts.get(v1_inst).?;
    try testing.expectEqual(InstructionData.unary_imm, @as(std.meta.Tag(InstructionData), v1_data.*));
    try testing.expectEqual(@as(i64, 10), v1_data.unary_imm.imm.value);

    const v2_def = func.dfg.valueDef(v2).?;
    const v2_inst = v2_def.unwrapInst();
    const v2_data = func.dfg.insts.get(v2_inst).?;
    try testing.expectEqual(InstructionData.unary_imm, @as(std.meta.Tag(InstructionData), v2_data.*));
    try testing.expectEqual(@as(i64, 20), v2_data.unary_imm.imm.value);
}
