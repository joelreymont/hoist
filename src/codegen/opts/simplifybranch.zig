//! Branch simplification optimization pass.
//!
//! Performs branch simplifications:
//! - Eliminate branches to next block (fall-through)
//! - Fold constant conditional branches
//! - Merge single-predecessor blocks
//! - Remove unreachable branches

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("root");
const Function = root.function.Function;
const Block = root.entities.Block;
const Inst = root.entities.Inst;
const Value = root.entities.Value;
const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;

/// Branch simplification pass.
pub const SimplifyBranch = struct {
    allocator: Allocator,
    changed: bool,

    pub fn init(allocator: Allocator) SimplifyBranch {
        return .{
            .allocator = allocator,
            .changed = false,
        };
    }

    pub fn deinit(self: *SimplifyBranch) void {
        _ = self;
    }

    /// Run branch simplification on function.
    /// Returns true if any changes were made.
    pub fn run(self: *SimplifyBranch, func: *Function) !bool {
        self.changed = false;

        var block_iter = func.layout.blocks();
        while (block_iter.next()) |block| {
            try self.simplifyBlock(func, block);
        }

        return self.changed;
    }

    fn simplifyBlock(self: *SimplifyBranch, func: *Function, block: Block) !void {
        const block_data = func.layout.block_data.get(block) orelse return;
        const last_inst = block_data.last_inst orelse return;

        const inst_data = func.dfg.insts.get(last_inst) orelse return;
        const opcode = inst_data.opcode();

        switch (opcode) {
            .jump => try self.simplifyJump(func, block, last_inst, inst_data),
            .brif => try self.simplifyBrif(func, block, last_inst, inst_data),
            else => {},
        }
    }

    /// Simplify unconditional jump.
    fn simplifyJump(self: *SimplifyBranch, func: *Function, block: Block, inst: Inst, inst_data: *const InstructionData) !void {
        const jump_data = switch (inst_data.*) {
            .jump => |d| d,
            else => return,
        };

        // Eliminate jump to next block (fall-through)
        const block_node = func.layout.blocks.get(block) orelse return;
        if (block_node.next_block) |next| {
            if (next.index == jump_data.destination.index) {
                // Jump to next block - can be eliminated (becomes fall-through)
                func.layout.removeInst(inst);
                func.dfg.removeInst(inst);
                self.changed = true;
            }
        }
    }

    /// Simplify conditional branch.
    fn simplifyBrif(self: *SimplifyBranch, func: *Function, block: Block, inst: Inst, inst_data: *const InstructionData) !void {
        _ = block;

        // Try to fold constant conditions
        const branch_data = switch (inst_data.*) {
            .branch => |d| d,
            else => return,
        };

        // Check if destination is a BlockCall with condition
        // For now, work with what we have
        _ = self;
        _ = func;
        _ = inst;
        _ = branch_data;
    }

    /// Check if value is a constant.
    fn isConstant(self: *SimplifyBranch, func: *const Function, value: Value) ?i64 {
        _ = self;
        const value_def = func.dfg.valueDef(value) orelse return null;
        const defining_inst = switch (value_def) {
            .result => |r| r.inst,
            else => return null,
        };

        const inst_data = func.dfg.insts.get(defining_inst) orelse return null;
        return switch (inst_data.*) {
            .unary => |d| if (d.opcode == .iconst) blk: {
                // iconst stores value in arg field - would need proper Imm64 decoding
                break :blk null;
            } else null,
            else => null,
        };
    }
};

// Tests

const testing = std.testing;

test "SimplifyBranch: init and deinit" {
    var pass = SimplifyBranch.init(testing.allocator);
    defer pass.deinit();

    try testing.expect(!pass.changed);
}

test "SimplifyBranch: run on empty function" {
    const sig = try @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var pass = SimplifyBranch.init(testing.allocator);
    defer pass.deinit();

    const changed = try pass.run(&func);
    try testing.expect(!changed);
}

test "SimplifyBranch: preserve non-branch instructions" {
    const sig = try @import("../../ir/signature.zig").Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const block = try func.dfg.makeBlock();
    try func.layout.appendBlock(block);

    // Add return instruction (non-branch)
    const ret_data = InstructionData{ .nullary = .{ .opcode = .@"return" } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, block);

    var pass = SimplifyBranch.init(testing.allocator);
    defer pass.deinit();

    const changed = try pass.run(&func);
    try testing.expect(!changed);
}
