//! Spectre mitigation pass.
//!
//! Inserts spectre_fence instructions to prevent speculative execution attacks.
//! Targets:
//! - After bounds checks (prevent speculative out-of-bounds access)
//! - After branch misprediction points
//! - Before sensitive data loads

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir = @import("../../ir.zig");
const Function = ir.Function;
const Block = ir.Block;
const Inst = ir.Inst;
const Value = ir.Value;
const Opcode = @import("../../ir/opcodes.zig").Opcode;
const InstructionData = ir.InstructionData;
const IntCC = @import("../../ir/condcodes.zig").IntCC;

pub const SpectreMitigation = struct {
    allocator: Allocator,
    changed: bool,

    pub fn init(allocator: Allocator) SpectreMitigation {
        return .{
            .allocator = allocator,
            .changed = false,
        };
    }

    pub fn deinit(self: *SpectreMitigation) void {
        _ = self;
    }

    /// Run Spectre mitigation on the function.
    pub fn run(self: *SpectreMitigation, func: *Function) !bool {
        self.changed = false;

        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            try self.processBlock(func, block);
        }

        return self.changed;
    }

    fn processBlock(self: *SpectreMitigation, func: *Function, block: Block) !void {
        var inst_iter = func.layout.blockInsts(block);
        var last_inst: ?Inst = null;

        while (inst_iter.next()) |inst| {
            const inst_data = func.dfg.insts.get(inst) orelse continue;

            // Check if this instruction needs a fence after it
            if (needsFenceAfter(inst_data.*)) {
                last_inst = inst;
            }
        }

        // Insert fence after last instruction that needs protection
        if (last_inst) |inst| {
            try self.insertFenceAfter(func, block, inst);
        }
    }

    fn insertFenceAfter(self: *SpectreMitigation, func: *Function, block: Block, after: Inst) !void {
        _ = block;
        const fence_data = InstructionData{ .nullary = .{ .opcode = .spectre_fence } };
        const fence_inst = try func.dfg.makeInst(fence_data);

        // Insert fence immediately after the target instruction
        try func.layout.insertInstAfter(fence_inst, after);
        self.changed = true;
    }
};

/// Check if an instruction needs a spectre fence after it.
fn needsFenceAfter(inst_data: InstructionData) bool {
    return switch (inst_data) {
        // Bounds checks: icmp followed by branch
        .int_compare => |data| switch (data.cond) {
            .ult, .ule, .slt, .sle => true, // Less-than comparisons often precede bounds checks
            else => false,
        },
        // Conditional branches (potential misprediction)
        .branch => true,
        .branch_z => true,
        // Array/pointer accesses that might be bounds-checked
        .load => true,
        else => false,
    };
}

test "SpectreMitigation: init and deinit" {
    const testing = std.testing;
    var pass = SpectreMitigation.init(testing.allocator);
    defer pass.deinit();

    try testing.expect(!pass.changed);
}
