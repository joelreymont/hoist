//! Loop Unrolling Pass
//!
//! Unrolls loops with small, constant trip counts to reduce branch overhead
//! and enable further optimizations like constant folding and LICM.
//!
//! Supported patterns:
//! - Counted loops with constant bounds (for i = 0; i < N; i++)
//! - Small loop bodies (< threshold instructions)
//! - Trip counts <= unroll_factor
//!
//! Limitations:
//! - Does not handle loops with complex exit conditions
//! - Does not handle loops with early exits (break)
//! - Requires dominator tree and loop info pre-computed

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir_mod = @import("../../ir.zig");
const Function = ir_mod.Function;
const Block = ir_mod.Block;
const Inst = ir_mod.Inst;
const Value = ir_mod.Value;
const Opcode = @import("../../ir/opcodes.zig").Opcode;
const InstructionData = @import("../../ir/instruction_data.zig").InstructionData;
const LoopInfo = @import("../../ir/loops.zig").LoopInfo;
const Loop = @import("../../ir/loops.zig").Loop;
const Type = ir_mod.Type;

/// Configuration for loop unrolling.
pub const Config = struct {
    /// Maximum number of times to unroll a loop.
    max_unroll: u32 = 4,

    /// Maximum number of instructions in loop body to consider unrolling.
    max_body_size: u32 = 32,

    /// Minimum trip count to consider unrolling.
    min_trip_count: u32 = 2,

    /// Whether to fully unroll loops with known constant trip count.
    full_unroll: bool = true,
};

/// Loop unrolling pass.
pub const LoopUnroll = struct {
    allocator: Allocator,
    config: Config,

    /// Stats.
    loops_analyzed: u32 = 0,
    loops_unrolled: u32 = 0,
    insts_added: u32 = 0,

    pub fn init(allocator: Allocator, config: Config) LoopUnroll {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *LoopUnroll) void {
        _ = self;
    }

    /// Run loop unrolling on the function.
    pub fn run(self: *LoopUnroll, func: *Function, loop_info: *const LoopInfo) !bool {
        var changed = false;

        for (loop_info.loops.items) |loop| {
            self.loops_analyzed += 1;

            // Only unroll innermost loops
            if (hasNestedLoops(loop, loop_info)) continue;

            // Analyze loop
            const analysis = self.analyzeLoop(func, loop) orelse continue;

            // Check if suitable for unrolling
            if (!self.shouldUnroll(analysis)) continue;

            // Perform unrolling
            if (try self.unrollLoop(func, loop, analysis)) {
                self.loops_unrolled += 1;
                changed = true;
            }
        }

        return changed;
    }

    /// Analyze a loop to determine if it's a counted loop.
    fn analyzeLoop(self: *LoopUnroll, func: *const Function, loop: *const Loop) ?LoopAnalysis {
        _ = self;

        // Get header block
        const header = loop.header;

        // Count instructions in loop body
        var body_size: u32 = 0;
        for (loop.blocks.items) |block| {
            var iter = func.layout.blockInsts(block);
            while (iter.next()) |_| {
                body_size += 1;
            }
        }

        // Look for induction variable pattern in header
        const iv_info = findInductionVar(func, header) orelse return null;

        // Check if trip count is constant
        const trip_count = computeTripCount(iv_info) orelse return null;

        return LoopAnalysis{
            .loop = loop,
            .header = header,
            .body_size = body_size,
            .trip_count = trip_count,
            .iv_info = iv_info,
        };
    }

    /// Check if loop should be unrolled.
    fn shouldUnroll(self: *const LoopUnroll, analysis: LoopAnalysis) bool {
        // Body too large
        if (analysis.body_size > self.config.max_body_size) return false;

        // Trip count too small
        if (analysis.trip_count < self.config.min_trip_count) return false;

        const effective_unroll = @min(analysis.trip_count, self.config.max_unroll);

        // Would expand code too much
        const expanded_size = analysis.body_size * effective_unroll;
        if (expanded_size > self.config.max_body_size * self.config.max_unroll) return false;

        return true;
    }

    /// Perform loop unrolling.
    fn unrollLoop(self: *LoopUnroll, func: *Function, loop: *const Loop, analysis: LoopAnalysis) !bool {
        const unroll_factor = @min(analysis.trip_count, self.config.max_unroll);

        // For full unrolling, we eliminate the loop entirely
        if (self.config.full_unroll and analysis.trip_count <= self.config.max_unroll) {
            try self.fullyUnroll(func, loop, analysis);
            return true;
        }

        return try self.partialUnroll(func, loop, analysis, unroll_factor);
    }

    /// Fully unroll a loop by peeling all iterations into preheader.
    fn fullyUnroll(self: *LoopUnroll, func: *Function, loop: *const Loop, analysis: LoopAnalysis) !void {
        _ = try self.peelIntoPreheader(func, loop, analysis, analysis.trip_count);
    }

    /// Partially unroll a loop by peeling a bounded chunk and keeping cleanup.
    fn partialUnroll(self: *LoopUnroll, func: *Function, loop: *const Loop, analysis: LoopAnalysis, factor: u32) !bool {
        if (factor == 0 or analysis.trip_count <= factor) return false;
        return try self.peelIntoPreheader(func, loop, analysis, factor);
    }

    const SimpleLoopShape = struct {
        preheader: Block,
        preheader_term: Inst,
        preheader_iv: Value,
        body: Block,
        body_term: Inst,
        body_iv_next: Value,
        body_insts: std.ArrayList(Inst),

        fn deinit(self: *SimpleLoopShape, allocator: Allocator) void {
            self.body_insts.deinit(allocator);
        }
    };

    fn peelIntoPreheader(
        self: *LoopUnroll,
        func: *Function,
        loop: *const Loop,
        analysis: LoopAnalysis,
        peel_count: u32,
    ) !bool {
        if (peel_count == 0) return false;

        var shape = self.findSimpleLoopShape(func, loop, analysis) orelse return false;
        defer shape.deinit(self.allocator);

        var current_iv = shape.preheader_iv;
        var value_map = std.AutoHashMap(Value, Value).init(self.allocator);
        defer value_map.deinit();

        for (0..peel_count) |_| {
            value_map.clearRetainingCapacity();
            try value_map.put(analysis.iv_info.iv, current_iv);

            for (shape.body_insts.items) |inst| {
                _ = try self.cloneInstBefore(func, inst, &value_map, shape.preheader_term);
                self.insts_added += 1;
            }

            current_iv = value_map.get(shape.body_iv_next) orelse return false;
        }

        try self.setJumpArg(func, shape.preheader_term, 0, current_iv);
        return true;
    }

    fn findSimpleLoopShape(
        self: *LoopUnroll,
        func: *Function,
        loop: *const Loop,
        analysis: LoopAnalysis,
    ) ?SimpleLoopShape {
        if (loop.blocks.items.len != 2) return null;

        const header_params = func.dfg.blockParams(analysis.header);
        if (header_params.len != 1) return null;
        if (header_params[0].asU32() != analysis.iv_info.iv.asU32()) return null;

        const header_term = lastInstInBlock(func, analysis.header) orelse return null;
        const header_data = func.dfg.insts.get(header_term) orelse return null;
        const header_branch = switch (header_data.*) {
            .branch => |br| br,
            else => return null,
        };

        const then_dest = header_branch.then_dest orelse return null;
        const else_dest = header_branch.else_dest orelse return null;
        const body_block = if (loop.contains(then_dest) and then_dest.asU32() != analysis.header.asU32())
            then_dest
        else if (loop.contains(else_dest) and else_dest.asU32() != analysis.header.asU32())
            else_dest
        else
            return null;

        const body_term = lastInstInBlock(func, body_block) orelse return null;
        const body_term_data = func.dfg.insts.get(body_term) orelse return null;
        const body_jump = switch (body_term_data.*) {
            .jump => |j| j,
            else => return null,
        };
        if (body_jump.destination.asU32() != analysis.header.asU32()) return null;
        const body_args = func.dfg.value_lists.asSlice(body_jump.args);
        if (body_args.len != 1) return null;

        const preheader_block = findPreheader(func, loop, analysis.header) orelse return null;
        const preheader_term = lastInstInBlock(func, preheader_block) orelse return null;
        const pre_data = func.dfg.insts.get(preheader_term) orelse return null;
        const pre_jump = switch (pre_data.*) {
            .jump => |j| j,
            else => return null,
        };
        if (pre_jump.destination.asU32() != analysis.header.asU32()) return null;
        const pre_args = func.dfg.value_lists.asSlice(pre_jump.args);
        if (pre_args.len != 1) return null;

        var body_insts = std.ArrayList(Inst){};
        var body_iter = func.layout.blockInsts(body_block);
        while (body_iter.next()) |inst| {
            if (inst.asU32() == body_term.asU32()) break;
            const data = func.dfg.insts.get(inst) orelse continue;
            if (data.opcode().is_branch() or data.opcode().is_terminator()) continue;
            body_insts.append(self.allocator, inst) catch return null;
        }

        return .{
            .preheader = preheader_block,
            .preheader_term = preheader_term,
            .preheader_iv = pre_args[0],
            .body = body_block,
            .body_term = body_term,
            .body_iv_next = body_args[0],
            .body_insts = body_insts,
        };
    }

    fn setJumpArg(self: *LoopUnroll, func: *Function, jump_inst: Inst, index: usize, value: Value) !void {
        _ = self;
        const data = func.dfg.insts.getMut(jump_inst) orelse return error.InvalidInst;
        switch (data.*) {
            .jump => |*j| {
                const args = func.dfg.value_lists.asMutSlice(j.args);
                if (index >= args.len) return error.InvalidInst;
                args[index] = value;
            },
            else => return error.InvalidInst,
        }
    }

    /// Clone an instruction with remapped values.
    fn cloneInstBefore(
        self: *LoopUnroll,
        func: *Function,
        inst: Inst,
        value_map: *std.AutoHashMap(Value, Value),
        before_inst: Inst,
    ) !Inst {
        _ = self;

        const inst_data = func.dfg.insts.get(inst) orelse return error.InvalidInst;

        // Remap operands
        const new_data = remapInstructionOperands(inst_data.*, value_map);

        // Create and insert instruction
        const new_inst = try func.dfg.makeInst(new_data);
        try func.layout.insertInstBefore(new_inst, before_inst);

        // Append result if instruction has one
        const results = func.dfg.instResults(inst);
        if (results.len > 0) {
            const result_ty = func.dfg.valueType(results[0]) orelse return error.InvalidType;
            const new_result = try func.dfg.appendInstResult(new_inst, result_ty);

            // Add to mapping
            try value_map.put(results[0], new_result);
        }

        return new_inst;
    }

    /// Create a constant value.
    fn createConstant(self: *LoopUnroll, func: *Function, value: i64, ty: Type) !Value {
        _ = self;

        const imm = @import("../../ir/immediates.zig").Imm64.new(value);
        const const_opcode: Opcode = switch (ty.raw) {
            Type.I8.raw => .iconst,
            Type.I16.raw => .iconst,
            Type.I32.raw => .iconst,
            Type.I64.raw => .iconst,
            else => .iconst,
        };

        const const_data = InstructionData{ .unary_imm = .{
            .opcode = const_opcode,
            .imm = imm,
        } };

        const const_inst = try func.dfg.makeInst(const_data);
        return try func.dfg.appendInstResult(const_inst, ty);
    }

    /// Statistics.
    pub fn stats(self: *const LoopUnroll) struct { analyzed: u32, unrolled: u32, insts: u32 } {
        return .{
            .analyzed = self.loops_analyzed,
            .unrolled = self.loops_unrolled,
            .insts = self.insts_added,
        };
    }
};

/// Analysis result for a loop.
const LoopAnalysis = struct {
    loop: *const Loop,
    header: Block,
    body_size: u32,
    trip_count: u32,
    iv_info: InductionVarInfo,
};

/// Induction variable information.
const InductionVarInfo = struct {
    /// The induction variable SSA value.
    iv: Value,
    /// Initial value (constant).
    init: i64,
    /// Step value (constant).
    step: i64,
    /// Bound value (constant).
    bound: i64,
    /// Comparison kind (< or <=).
    cmp_kind: enum { lt, le },
    /// Type of induction variable.
    ty: Type,
};

/// Check if loop contains nested loops.
fn hasNestedLoops(loop: *const Loop, loop_info: *const LoopInfo) bool {
    for (loop_info.loops.items) |other| {
        if (other == loop) continue;
        if (other.parent == loop) return true;
    }
    return false;
}

fn lastInstInBlock(func: *const Function, block: Block) ?Inst {
    var iter = func.layout.blockInsts(block);
    var last: ?Inst = null;
    while (iter.next()) |inst| {
        last = inst;
    }
    return last;
}

fn findPreheader(func: *const Function, loop: *const Loop, header: Block) ?Block {
    var block_iter = func.layout.blockIter();
    while (block_iter.next()) |block| {
        if (loop.contains(block)) continue;
        const term = lastInstInBlock(func, block) orelse continue;
        const term_data = func.dfg.insts.get(term) orelse continue;
        switch (term_data.*) {
            .jump => |j| {
                if (j.destination.asU32() == header.asU32()) return block;
            },
            else => {},
        }
    }
    return null;
}

/// Find induction variable pattern in loop header.
fn findInductionVar(func: *const Function, header: Block) ?InductionVarInfo {
    // Look for block-param iv + icmp pattern in loop header.
    const header_data = func.dfg.blocks.get(header) orelse return null;
    const header_params = header_data.getParams(&func.dfg.value_lists);
    if (header_params.len == 0) return null;
    const iv_value = header_params[0];

    var iter = func.layout.blockInsts(header);
    var cmp_inst: ?Inst = null;

    while (iter.next()) |inst| {
        const inst_data = func.dfg.insts.get(inst) orelse continue;
        const opcode = inst_data.opcode();
        if (opcode == .icmp) {
            cmp_inst = inst;
        }
    }

    // Need comparison in the header.
    if (cmp_inst == null) return null;

    // Get comparison operands
    const cmp_data = func.dfg.insts.get(cmp_inst.?) orelse return null;

    // Check if comparison uses the phi result
    const cmp_args = switch (cmp_data.*) {
        .int_compare => |ic| ic.args,
        else => return null,
    };

    // Check if iv block parameter is one of the comparison operands.
    if (cmp_args[0].asU32() != iv_value.asU32() and
        cmp_args[1].asU32() != iv_value.asU32())
    {
        return null;
    }

    // Get bound from other operand
    const bound_val = if (cmp_args[0].asU32() == iv_value.asU32()) cmp_args[1] else cmp_args[0];

    // Check if bound is an iconst value.
    const bound_value_def = func.dfg.valueDef(bound_val) orelse return null;
    const bound_inst = switch (bound_value_def) {
        .result => |r| r.inst,
        else => return null,
    };
    const bound_inst_data = func.dfg.insts.get(bound_inst) orelse return null;
    const bound = switch (bound_inst_data.*) {
        .unary_imm => |d| if (d.opcode == .iconst) d.imm.value else return null,
        else => return null,
    };

    // Get induction variable type
    const iv_ty = func.dfg.valueType(iv_value) orelse return null;

    // For now, assume simple i = 0; i < N; i++ pattern
    return InductionVarInfo{
        .iv = iv_value,
        .init = 0,
        .step = 1,
        .bound = @intCast(bound),
        .cmp_kind = .lt,
        .ty = iv_ty,
    };
}

/// Compute trip count from induction variable info.
fn computeTripCount(iv: InductionVarInfo) ?u32 {
    // For i < bound with init and step
    if (iv.step <= 0) return null; // Infinite or negative loop

    const range = iv.bound - iv.init;
    if (range <= 0) return 0;

    const trips: u32 = @intCast(@divTrunc(range, iv.step));
    return switch (iv.cmp_kind) {
        .lt => trips,
        .le => trips + 1,
    };
}

/// Remap instruction operands using value mapping.
fn remapInstructionOperands(data: InstructionData, map: *std.AutoHashMap(Value, Value)) InstructionData {
    var result = data;

    // Remap based on instruction format
    switch (result) {
        .unary => |*u| {
            if (map.get(u.arg)) |new_val| {
                u.arg = new_val;
            }
        },
        .binary => |*b| {
            if (map.get(b.args[0])) |new_val| {
                b.args[0] = new_val;
            }
            if (map.get(b.args[1])) |new_val| {
                b.args[1] = new_val;
            }
        },
        .ternary => |*t| {
            if (map.get(t.args[0])) |new_val| {
                t.args[0] = new_val;
            }
            if (map.get(t.args[1])) |new_val| {
                t.args[1] = new_val;
            }
            if (map.get(t.args[2])) |new_val| {
                t.args[2] = new_val;
            }
        },
        .int_compare => |*ic| {
            if (map.get(ic.args[0])) |new_val| {
                ic.args[0] = new_val;
            }
            if (map.get(ic.args[1])) |new_val| {
                ic.args[1] = new_val;
            }
        },
        else => {},
    }

    return result;
}

// Tests
test "LoopUnroll config defaults" {
    const testing = std.testing;
    const config = Config{};

    try testing.expectEqual(@as(u32, 4), config.max_unroll);
    try testing.expectEqual(@as(u32, 32), config.max_body_size);
    try testing.expect(config.full_unroll);
}

test "computeTripCount" {
    const testing = std.testing;

    // i = 0; i < 10; i++
    const info1 = InductionVarInfo{
        .iv = Value.fromU32(0),
        .init = 0,
        .step = 1,
        .bound = 10,
        .cmp_kind = .lt,
        .ty = Type.I32,
    };
    try testing.expectEqual(@as(?u32, 10), computeTripCount(info1));

    // i = 0; i <= 10; i++
    const info2 = InductionVarInfo{
        .iv = Value.fromU32(0),
        .init = 0,
        .step = 1,
        .bound = 10,
        .cmp_kind = .le,
        .ty = Type.I32,
    };
    try testing.expectEqual(@as(?u32, 11), computeTripCount(info2));

    // i = 0; i < 10; i += 2
    const info3 = InductionVarInfo{
        .iv = Value.fromU32(0),
        .init = 0,
        .step = 2,
        .bound = 10,
        .cmp_kind = .lt,
        .ty = Type.I32,
    };
    try testing.expectEqual(@as(?u32, 5), computeTripCount(info3));
}

test "LoopUnroll shouldUnroll allows bounded partial unroll" {
    const testing = std.testing;

    var pass = LoopUnroll.init(testing.allocator, .{ .max_unroll = 4 });
    defer pass.deinit();

    var loop = Loop.init(testing.allocator, Block.new(0), 0);
    defer loop.deinit();

    const analysis = LoopAnalysis{
        .loop = &loop,
        .header = Block.new(0),
        .body_size = 2,
        .trip_count = 8,
        .iv_info = .{
            .iv = Value.fromU32(0),
            .init = 0,
            .step = 1,
            .bound = 8,
            .cmp_kind = .lt,
            .ty = Type.I32,
        },
    };

    try testing.expect(pass.shouldUnroll(analysis));
}
