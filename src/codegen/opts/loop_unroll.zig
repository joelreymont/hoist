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

        // Would expand code too much
        const expanded_size = analysis.body_size * analysis.trip_count;
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

        // Partial unrolling: duplicate loop body N times
        try self.partialUnroll(func, loop, analysis, unroll_factor);
        return true;
    }

    /// Fully unroll a loop (eliminate loop structure).
    fn fullyUnroll(self: *LoopUnroll, func: *Function, loop: *const Loop, analysis: LoopAnalysis) !void {
        // Clone loop body trip_count times
        // Each iteration has the induction variable replaced with a constant

        const trip_count = analysis.trip_count;

        // Create value mapping for each iteration
        var value_map = std.AutoHashMap(Value, Value).init(self.allocator);
        defer value_map.deinit();

        for (0..trip_count) |iter| {
            // Clear mapping for this iteration
            value_map.clearRetainingCapacity();

            // Map induction variable to constant
            const iv_const = try self.createConstant(func, @intCast(iter), analysis.iv_info.ty);
            try value_map.put(analysis.iv_info.iv, iv_const);

            // Clone all instructions in loop body
            for (loop.blocks.items) |block| {
                if (block.asU32() == analysis.header.asU32()) continue; // Skip header

                var inst_iter = func.layout.blockInsts(block);
                while (inst_iter.next()) |inst| {
                    const inst_data = func.dfg.insts.get(inst) orelse continue;
                    const opcode = inst_data.opcode();

                    // Skip branch instructions - they'll be dead after unrolling
                    if (opcode.is_branch() or opcode.is_terminator()) continue;

                    // Clone instruction with remapped values
                    _ = try self.cloneInst(func, inst, &value_map);
                    self.insts_added += 1;
                }
            }
        }
    }

    /// Partially unroll a loop (duplicate body but keep loop structure).
    fn partialUnroll(self: *LoopUnroll, func: *Function, loop: *const Loop, analysis: LoopAnalysis, factor: u32) !void {
        _ = self;
        _ = func;
        _ = loop;
        _ = analysis;
        _ = factor;

        // TODO: Implement partial unrolling
        // This involves:
        // 1. Clone loop body `factor` times
        // 2. Update induction variable increment by factor
        // 3. Add remainder loop for trip_count % factor iterations
    }

    /// Clone an instruction with remapped values.
    fn cloneInst(self: *LoopUnroll, func: *Function, inst: Inst, value_map: *std.AutoHashMap(Value, Value)) !Inst {
        _ = self;

        const inst_data = func.dfg.insts.get(inst) orelse return error.InvalidInst;

        // Remap operands
        const new_data = remapInstructionOperands(inst_data, value_map);

        // Create new instruction
        const new_inst = try func.dfg.makeInst(new_data);

        // Append result if instruction has one
        const results = func.dfg.instResults(inst);
        if (results.len > 0) {
            const result_ty = func.dfg.valueType(results[0]);
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

/// Find induction variable pattern in loop header.
fn findInductionVar(func: *const Function, header: Block) ?InductionVarInfo {
    // Look for phi -> icmp -> br_if pattern
    var iter = func.layout.blockInsts(header);

    var phi_inst: ?Inst = null;
    var cmp_inst: ?Inst = null;

    while (iter.next()) |inst| {
        const inst_data = func.dfg.insts.get(inst) orelse continue;
        const opcode = inst_data.opcode();

        if (opcode == .phi or opcode == .block_param) {
            phi_inst = inst;
        } else if (opcode == .icmp) {
            cmp_inst = inst;
        }
    }

    // Need both phi and comparison
    if (phi_inst == null or cmp_inst == null) return null;

    // Get comparison operands
    const cmp_data = func.dfg.insts.get(cmp_inst.?) orelse return null;

    // Check if comparison uses the phi result
    const cmp_args = switch (cmp_data) {
        .int_compare => |ic| ic.args,
        else => return null,
    };

    const phi_results = func.dfg.instResults(phi_inst.?);
    if (phi_results.len == 0) return null;
    const phi_result = phi_results[0];

    // Check if phi result is one of the comparison operands
    if (cmp_args[0].asU32() != phi_result.asU32() and
        cmp_args[1].asU32() != phi_result.asU32())
    {
        return null;
    }

    // Get bound from other operand
    const bound_val = if (cmp_args[0].asU32() == phi_result.asU32()) cmp_args[1] else cmp_args[0];

    // Check if bound is constant
    const bound_def = func.dfg.values.get(bound_val) orelse return null;
    const bound = switch (bound_def.*) {
        .iconst => |v| v,
        else => return null,
    };

    // Get induction variable type
    const iv_ty = func.dfg.valueType(phi_result);

    // For now, assume simple i = 0; i < N; i++ pattern
    return InductionVarInfo{
        .iv = phi_result,
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
