const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const Function = root.function.Function;
const Block = root.entities.Block;
const Inst = root.entities.Inst;
const InstructionData = root.instruction_data.InstructionData;
const cfg_mod = @import("cfg.zig");
const CFG = cfg_mod.CFG;

/// Build control flow graph from function layout.
pub fn buildCFG(allocator: Allocator, func: *const Function) !CFG {
    var cfg = CFG.init(allocator);
    errdefer cfg.deinit();

    // Iterate blocks and find terminator instructions
    var block_iter = func.layout.blocks();
    while (block_iter.next()) |block| {
        try analyzeBlock(&cfg, func, block);
    }

    return cfg;
}

fn analyzeBlock(cfg: *CFG, func: *const Function, block: Block) !void {
    // Find terminator instruction
    var inst_iter = func.layout.blockInsts(block);
    var last_inst: ?Inst = null;
    while (inst_iter.next()) |inst| {
        last_inst = inst;
    }

    if (last_inst) |term_inst| {
        const inst_data = func.dfg.insts.get(term_inst) orelse return;

        switch (inst_data.*) {
            .jump => |jmp| {
                try cfg.addEdge(block, jmp.destination);
            },
            .branch => |br| {
                try cfg.addEdge(block, br.then_dst);
                try cfg.addEdge(block, br.else_dst);
            },
            .br_table => |brt| {
                // Add edge to default target
                try cfg.addEdge(block, brt.default_dst);
                // TODO: Add edges to jump table targets
            },
            .@"return", .trap => {
                // No successors
            },
            else => {},
        }
    }
}

test "buildCFG empty function" {
    const sig = try @import("signature.zig").Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var cfg = try buildCFG(testing.allocator, &func);
    defer cfg.deinit();

    // Empty function - no edges
    try testing.expectEqual(@as(usize, 0), cfg.succs.count());
}

test "buildCFG linear flow" {
    const sig = try @import("signature.zig").Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    try func.layout.appendBlock(b0);
    try func.layout.appendBlock(b1);

    // b0: jump b1
    const jmp_data = InstructionData{ .jump = .{ .opcode = .jump, .destination = b1 } };
    const jmp_inst = try func.dfg.makeInst(jmp_data);
    try func.layout.appendInst(jmp_inst, b0);

    // b1: ret
    const ret_data = InstructionData{ .nullary = .{ .opcode = .@"return" } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, b1);

    var cfg = try buildCFG(testing.allocator, &func);
    defer cfg.deinit();

    // b0 -> b1
    const b0_succs = cfg.successors(b0);
    try testing.expectEqual(@as(usize, 1), b0_succs.len);
    try testing.expectEqual(b1, b0_succs[0]);

    // b1 has no successors
    const b1_succs = cfg.successors(b1);
    try testing.expectEqual(@as(usize, 0), b1_succs.len);
}

test "buildCFG branch" {
    const sig = try @import("signature.zig").Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    try func.layout.appendBlock(b0);
    try func.layout.appendBlock(b1);
    try func.layout.appendBlock(b2);

    // Create condition value
    const cond_val = root.entities.Value.new(0);

    // b0: branch cond, b1, b2
    const br_data = InstructionData{
        .branch = .{
            .opcode = .brif,
            .condition = cond_val,
            .then_dst = b1,
            .else_dst = b2,
        },
    };
    const br_inst = try func.dfg.makeInst(br_data);
    try func.layout.appendInst(br_inst, b0);

    var cfg = try buildCFG(testing.allocator, &func);
    defer cfg.deinit();

    // b0 -> b1, b2
    const b0_succs = cfg.successors(b0);
    try testing.expectEqual(@as(usize, 2), b0_succs.len);
}
