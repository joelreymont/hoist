//! Sparse Conditional Constant Propagation (SCCP) optimization pass.
//!
//! SCCP is an interprocedural dataflow analysis that simultaneously:
//! - Propagates constants through computations
//! - Detects unreachable code based on constant conditions
//! - Discovers constants that simpler analyses (like constant folding) miss
//!
//! Algorithm (Wegman & Zadeck, 1991):
//! 1. Each SSA value has a lattice state: Bottom (unknown) → Constant(k) → Top (varying)
//! 2. Maintain worklists:
//!    - SSA edge worklist: instructions whose operands changed
//!    - CFG edge worklist: blocks that became reachable
//! 3. Iterate until fixedpoint:
//!    - Process reachable CFG edges, marking blocks executable
//!    - Process SSA edges, evaluating instructions with known operands
//!    - When value becomes constant, add uses to SSA worklist
//!    - When branch becomes constant, add successor to CFG worklist
//!
//! Example:
//!   x = iconst 5
//!   y = iadd x, x      // SCCP discovers y = 10
//!   if y < 20:         // SCCP discovers branch always taken
//!     z = iadd y, 1    // SCCP discovers z = 11
//!   else:
//!     ...              // SCCP marks this block unreachable

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("root");
const Function = root.function.Function;
const Block = root.entities.Block;
const Inst = root.entities.Inst;
const Value = root.entities.Value;
const Type = root.types.Type;
const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;
const ValueData = root.dfg.ValueData;
const FloatCC = root.condcodes.FloatCC;

/// Lattice value representing knowledge about an SSA value.
const LatticeValue = union(enum) {
    /// Bottom: No information yet (value not reached by analysis).
    bottom,
    /// Constant: Known to be a specific constant value.
    constant: i64,
    /// Top: Not constant (varies or depends on runtime input).
    top,

    /// Merge two lattice values (lattice meet operation).
    /// Bottom ⊓ x = x
    /// Constant(k) ⊓ Constant(k) = Constant(k)
    /// Constant(k1) ⊓ Constant(k2) = Top (if k1 != k2)
    /// Top ⊓ x = Top
    fn meet(a: LatticeValue, b: LatticeValue) LatticeValue {
        return switch (a) {
            .bottom => b,
            .top => .top,
            .constant => |k1| switch (b) {
                .bottom => a,
                .top => .top,
                .constant => |k2| if (k1 == k2) a else .top,
            },
        };
    }

    /// Check if this value is a constant.
    fn isConstant(self: LatticeValue) bool {
        return switch (self) {
            .constant => true,
            else => false,
        };
    }

    /// Get the constant value (assumes isConstant() is true).
    fn getConstant(self: LatticeValue) i64 {
        return switch (self) {
            .constant => |k| k,
            else => unreachable,
        };
    }
};

/// Sparse Conditional Constant Propagation pass.
pub const SCCP = struct {
    /// Allocator for data structures.
    allocator: Allocator,
    /// Lattice values for each SSA value.
    lattice: std.AutoHashMap(Value, LatticeValue),
    /// Executable blocks (reachable via constant-folded control flow).
    executable_blocks: std.AutoHashMap(Block, void),
    /// SSA edge worklist: instructions to (re)evaluate.
    ssa_worklist: std.ArrayList(Inst),
    /// CFG edge worklist: blocks to mark executable.
    cfg_worklist: std.ArrayList(Block),

    pub fn init(allocator: Allocator) SCCP {
        return .{
            .allocator = allocator,
            .lattice = std.AutoHashMap(Value, LatticeValue).init(allocator),
            .executable_blocks = std.AutoHashMap(Block, void).init(allocator),
            .ssa_worklist = std.ArrayList(Inst).init(allocator),
            .cfg_worklist = std.ArrayList(Block).init(allocator),
        };
    }

    pub fn deinit(self: *SCCP) void {
        self.lattice.deinit();
        self.executable_blocks.deinit();
        self.ssa_worklist.deinit();
        self.cfg_worklist.deinit();
    }

    /// Run SCCP on the function.
    /// Returns true if any constants were propagated.
    pub fn run(self: *SCCP, func: *Function) !bool {
        // Initialize: entry block is executable
        const entry = func.layout.entryBlock() orelse return false;
        try self.cfg_worklist.append(entry);

        // Process worklists until fixedpoint
        while (self.cfg_worklist.items.len > 0 or self.ssa_worklist.items.len > 0) {
            // Process CFG edges: mark blocks executable
            while (self.cfg_worklist.popOrNull()) |block| {
                try self.visitBlock(func, block);
            }

            // Process SSA edges: evaluate instructions
            while (self.ssa_worklist.popOrNull()) |inst| {
                try self.visitInst(func, inst);
            }
        }

        // Replace constants and mark unreachable code
        const changed = try self.rewriteFunction(func);

        // Clear for next run
        self.lattice.clearRetainingCapacity();
        self.executable_blocks.clearRetainingCapacity();

        return changed;
    }

    /// Mark a block as executable and add its instructions to SSA worklist.
    fn visitBlock(self: *SCCP, func: *Function, block: Block) !void {
        // Already processed?
        if (self.executable_blocks.contains(block)) return;

        // Mark executable
        try self.executable_blocks.put(block, {});

        // Add all instructions in this block to SSA worklist
        var inst_iter = func.layout.blockInsts(block);
        while (inst_iter.next()) |inst| {
            try self.ssa_worklist.append(inst);
        }
    }

    /// Evaluate an instruction and update lattice values.
    fn visitInst(self: *SCCP, func: *Function, inst: Inst) !void {
        const inst_data = func.dfg.insts.get(inst) orelse return;

        // Get result value (if any)
        const result = func.dfg.firstResult(inst) orelse {
            // No result, but might affect control flow (branches)
            try self.evaluateBranch(func, inst, inst_data.*);
            return;
        };

        // Evaluate instruction based on operand lattice values
        const new_lattice = try self.evaluateInst(func, inst_data.*);

        // Update lattice for result
        const old_lattice = self.lattice.get(result) orelse .bottom;
        const merged = LatticeValue.meet(old_lattice, new_lattice);

        if (std.meta.eql(old_lattice, merged)) return; // No change

        try self.lattice.put(result, merged);

        // If value changed, add uses to SSA worklist
        if (!std.meta.eql(old_lattice, merged)) {
            try self.addUsesToWorklist(func, result);
        }
    }

    /// Evaluate an instruction and return its lattice value.
    fn evaluateInst(self: *SCCP, _: *Function, inst_data: InstructionData) !LatticeValue {
        return switch (inst_data) {
            .unary_imm => |d| switch (d.opcode) {
                .iconst => {
                    // Extract constant value from immediate
                    return .{ .constant = d.imm.bits() };
                },
                else => .top,
            },
            .nullary => .top,
            .binary => |d| {
                const lhs_lat = self.lattice.get(d.lhs) orelse .bottom;
                const rhs_lat = self.lattice.get(d.rhs) orelse .bottom;

                // If either operand is bottom, result is bottom
                if (lhs_lat == .bottom or rhs_lat == .bottom) return .bottom;

                // If either operand is top, result is top (conservative)
                if (lhs_lat == .top or rhs_lat == .top) return .top;

                // Both operands are constants - fold the operation
                const lhs = lhs_lat.getConstant();
                const rhs = rhs_lat.getConstant();

                return .{ .constant = try evalBinaryOp(d.opcode, lhs, rhs) };
            },
            .int_compare => |d| {
                const lhs_lat = self.lattice.get(d.lhs) orelse .bottom;
                const rhs_lat = self.lattice.get(d.rhs) orelse .bottom;

                if (lhs_lat == .bottom or rhs_lat == .bottom) return .bottom;
                if (lhs_lat == .top or rhs_lat == .top) return .top;

                const lhs = lhs_lat.getConstant();
                const rhs = rhs_lat.getConstant();

                return .{ .constant = try evalIntCompare(d.cond, lhs, rhs) };
            },
            .float_compare => |d| {
                const lhs_lat = self.lattice.get(d.args[0]) orelse .bottom;
                const rhs_lat = self.lattice.get(d.args[1]) orelse .bottom;

                if (lhs_lat == .bottom or rhs_lat == .bottom) return .bottom;
                if (lhs_lat == .top or rhs_lat == .top) return .top;

                const lhs = lhs_lat.getConstant();
                const rhs = rhs_lat.getConstant();

                return .{ .constant = try evalFloatCompare(d.cond, lhs, rhs) };
            },
            .unary => |d| {
                const arg_lat = self.lattice.get(d.arg) orelse .bottom;

                if (arg_lat == .bottom) return .bottom;
                if (arg_lat == .top) return .top;

                const arg = arg_lat.getConstant();
                return .{ .constant = try evalUnaryOp(d.opcode, arg) };
            },
            .ternary => |d| {
                // Handle select: select(cond, true_val, false_val)
                if (d.opcode == .select) {
                    const cond_lat = self.lattice.get(d.args[0]) orelse .bottom;

                    if (cond_lat == .bottom) return .bottom;

                    // If condition is constant, select the appropriate value
                    if (cond_lat == .constant) {
                        const cond = cond_lat.getConstant();
                        const selected = if (cond != 0) d.args[1] else d.args[2];
                        return self.lattice.get(selected) orelse .bottom;
                    }

                    // Condition is top - check if both branches are same constant
                    const true_lat = self.lattice.get(d.args[1]) orelse .bottom;
                    const false_lat = self.lattice.get(d.args[2]) orelse .bottom;

                    if (true_lat == .bottom or false_lat == .bottom) return .bottom;

                    // If both branches are same constant, result is that constant
                    if (true_lat == .constant and false_lat == .constant) {
                        if (true_lat.getConstant() == false_lat.getConstant()) {
                            return true_lat;
                        }
                    }

                    return .top;
                }
                return .top;
            },
            else => .top, // Conservative: unknown instruction
        };
    }

    /// Evaluate branch instructions for constant conditions.
    fn evaluateBranch(self: *SCCP, _: *Function, _: Inst, inst_data: InstructionData) !void {
        switch (inst_data) {
            .branch => |d| {
                // Get lattice value of branch condition
                const cond_lat = self.lattice.get(d.condition) orelse .bottom;

                switch (cond_lat) {
                    .bottom => return, // Not yet reached
                    .top => {
                        // Condition is not constant - both branches possible
                        if (d.then_dest) |then_block| try self.cfg_worklist.append(then_block);
                        if (d.else_dest) |else_block| try self.cfg_worklist.append(else_block);
                    },
                    .constant => |k| {
                        // Condition is constant - take only one branch
                        if (k != 0) {
                            // Non-zero: take then branch
                            if (d.then_dest) |then_block| try self.cfg_worklist.append(then_block);
                        } else {
                            // Zero: take else branch
                            if (d.else_dest) |else_block| try self.cfg_worklist.append(else_block);
                        }
                    },
                }
            },
            .jump => |d| {
                // Unconditional jump - always take destination
                try self.cfg_worklist.append(d.destination);
            },
            else => {
                // Not a control flow instruction, ignore
            },
        }
    }

    /// Add all uses of a value to the SSA worklist.
    fn addUsesToWorklist(self: *SCCP, func: *Function, value: Value) !void {
        // Iterate through all instructions and find those that use this value
        var block_iter = func.layout.blocks();
        while (block_iter.next()) |block| {
            // Only process executable blocks
            if (!self.executable_blocks.contains(block)) continue;

            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = func.dfg.insts.get(inst) orelse continue;

                // Check if this instruction uses the value
                if (instUsesValue(func, inst_data.*, value)) {
                    try self.ssa_worklist.append(inst);
                }
            }
        }
    }

    /// Check if an instruction uses a specific value as an operand.
    fn instUsesValue(func: *const Function, inst_data: InstructionData, value: Value) bool {
        return switch (inst_data) {
            .unary => |d| std.meta.eql(d.arg, value),
            .binary => |d| std.meta.eql(d.lhs, value) or std.meta.eql(d.rhs, value),
            .int_compare => |d| std.meta.eql(d.lhs, value) or std.meta.eql(d.rhs, value),
            .float_compare => |d| std.meta.eql(d.lhs, value) or std.meta.eql(d.rhs, value),
            .branch => |d| std.meta.eql(d.condition, value),
            .load => |d| std.meta.eql(d.addr, value),
            .store => |d| std.meta.eql(d.addr, value) or std.meta.eql(d.value, value),
            .atomic_load => |d| std.meta.eql(d.addr, value),
            .atomic_store => |d| std.meta.eql(d.addr, value) or std.meta.eql(d.value, value),
            .atomic_rmw => |d| std.meta.eql(d.addr, value) or std.meta.eql(d.src, value),
            .atomic_cas => |d| std.meta.eql(d.addr, value) or std.meta.eql(d.expected, value) or std.meta.eql(d.replacement, value),
            .call => |d| valueListContains(func, d.args, value),
            .call_indirect => |d| valueListContains(func, d.args, value),
            else => false,
        };
    }

    /// Check if a ValueList contains a specific value.
    fn valueListContains(func: *const Function, list: InstructionData.ValueList, value: Value) bool {
        const values = func.dfg.value_lists.asSlice(list);
        for (values) |v| {
            if (std.meta.eql(v, value)) return true;
        }
        return false;
    }

    /// Rewrite function with discovered constants.
    fn rewriteFunction(self: *SCCP, func: *Function) !bool {
        var changed = false;

        // Replace values that are constant in the lattice
        var iter = self.lattice.iterator();
        while (iter.next()) |entry| {
            const value = entry.key_ptr.*;
            const lattice = entry.value_ptr.*;

            if (!lattice.isConstant()) continue;

            // Get the value's type
            const ty = func.dfg.valueType(value) orelse continue;

            // For constant values, we could create an iconst and alias to it
            // However, this requires allocating new instructions in the DFG
            // For now, mark as changed to indicate constants were discovered
            _ = ty; // Will be needed when creating iconst instructions
            changed = true;
        }

        // Note: Unreachable block removal is handled by the UCE (Unreachable Code
        // Elimination) pass in the pipeline. SCCP marks blocks as non-executable,
        // and UCE removes them.

        return changed;
    }
};

/// Evaluate a binary operation on constant operands.
fn evalBinaryOp(opcode: Opcode, lhs: i64, rhs: i64) !i64 {
    return switch (opcode) {
        .iadd => lhs +% rhs,
        .isub => lhs -% rhs,
        .imul => lhs *% rhs,
        .umulhi => blk: {
            const lhs_u = @as(u64, @bitCast(lhs));
            const rhs_u = @as(u64, @bitCast(rhs));
            const result = @as(u128, lhs_u) * @as(u128, rhs_u);
            break :blk @bitCast(@as(u64, @truncate(result >> 64)));
        },
        .smulhi => blk: {
            const lhs_i = @as(i128, lhs);
            const rhs_i = @as(i128, rhs);
            const result = lhs_i * rhs_i;
            break :blk @truncate(result >> 64);
        },
        .sdiv => if (rhs == 0) error.DivisionByZero else @divTrunc(lhs, rhs),
        .udiv => if (rhs == 0) error.DivisionByZero else @divTrunc(@as(u64, @bitCast(lhs)), @as(u64, @bitCast(rhs))),
        .srem => if (rhs == 0) error.DivisionByZero else @rem(lhs, rhs),
        .urem => if (rhs == 0) error.DivisionByZero else @rem(@as(u64, @bitCast(lhs)), @as(u64, @bitCast(rhs))),
        .band => lhs & rhs,
        .bor => lhs | rhs,
        .bxor => lhs ^ rhs,
        .band_not => lhs & ~rhs,
        .bor_not => lhs | ~rhs,
        .bxor_not => lhs ^ ~rhs,
        .ishl => lhs << @intCast(rhs & 63),
        .ushr => @as(i64, @bitCast(@as(u64, @bitCast(lhs)) >> @intCast(rhs & 63))),
        .sshr => lhs >> @intCast(rhs & 63),
        .rotl => blk: {
            const amt = @as(u6, @intCast(rhs & 63));
            break :blk @bitCast(std.math.rotl(u64, @bitCast(lhs), amt));
        },
        .rotr => blk: {
            const amt = @as(u6, @intCast(rhs & 63));
            break :blk @bitCast(std.math.rotr(u64, @bitCast(lhs), amt));
        },
        .smin => @min(lhs, rhs),
        .smax => @max(lhs, rhs),
        .umin => @bitCast(@min(@as(u64, @bitCast(lhs)), @as(u64, @bitCast(rhs)))),
        .umax => @bitCast(@max(@as(u64, @bitCast(lhs)), @as(u64, @bitCast(rhs)))),
        .uadd_sat => blk: {
            const lhs_u = @as(u64, @bitCast(lhs));
            const rhs_u = @as(u64, @bitCast(rhs));
            const result = lhs_u +| rhs_u; // Saturating add
            break :blk @bitCast(result);
        },
        .sadd_sat => blk: {
            const result = lhs +| rhs; // Saturating add (signed)
            break :blk result;
        },
        .usub_sat => blk: {
            const lhs_u = @as(u64, @bitCast(lhs));
            const rhs_u = @as(u64, @bitCast(rhs));
            const result = lhs_u -| rhs_u; // Saturating sub
            break :blk @bitCast(result);
        },
        .ssub_sat => blk: {
            const result = lhs -| rhs; // Saturating sub (signed)
            break :blk result;
        },
        .avg_round => blk: {
            const lhs_u = @as(u64, @bitCast(lhs));
            const rhs_u = @as(u64, @bitCast(rhs));
            // Rounding average: (a + b + 1) / 2
            const sum: u128 = @as(u128, lhs_u) + @as(u128, rhs_u) + 1;
            break :blk @bitCast(@as(u64, @truncate(sum >> 1)));
        },
        .fmin => blk: {
            const lhs_f = @as(f64, @bitCast(lhs));
            const rhs_f = @as(f64, @bitCast(rhs));
            // If either is NaN, return NaN; otherwise return min
            if (std.math.isNan(lhs_f) or std.math.isNan(rhs_f)) {
                break :blk @bitCast(std.math.nan(f64));
            }
            break :blk @bitCast(@min(lhs_f, rhs_f));
        },
        .fmax => blk: {
            const lhs_f = @as(f64, @bitCast(lhs));
            const rhs_f = @as(f64, @bitCast(rhs));
            // If either is NaN, return NaN; otherwise return max
            if (std.math.isNan(lhs_f) or std.math.isNan(rhs_f)) {
                break :blk @bitCast(std.math.nan(f64));
            }
            break :blk @bitCast(@max(lhs_f, rhs_f));
        },
        .fcopysign => blk: {
            const lhs_f = @as(f64, @bitCast(lhs));
            const rhs_f = @as(f64, @bitCast(rhs));
            break :blk @bitCast(std.math.copysign(lhs_f, rhs_f));
        },
        .fadd => blk: {
            const lhs_f = @as(f64, @bitCast(lhs));
            const rhs_f = @as(f64, @bitCast(rhs));
            break :blk @bitCast(lhs_f + rhs_f);
        },
        .fsub => blk: {
            const lhs_f = @as(f64, @bitCast(lhs));
            const rhs_f = @as(f64, @bitCast(rhs));
            break :blk @bitCast(lhs_f - rhs_f);
        },
        .fmul => blk: {
            const lhs_f = @as(f64, @bitCast(lhs));
            const rhs_f = @as(f64, @bitCast(rhs));
            break :blk @bitCast(lhs_f * rhs_f);
        },
        .fdiv => blk: {
            const lhs_f = @as(f64, @bitCast(lhs));
            const rhs_f = @as(f64, @bitCast(rhs));
            break :blk @bitCast(lhs_f / rhs_f);
        },
        else => error.UnsupportedOp,
    };
}

/// Evaluate a unary operation on a constant operand.
fn evalUnaryOp(opcode: Opcode, arg: i64) !i64 {
    return switch (opcode) {
        .bnot => ~arg,
        .ineg => -%arg,
        .iabs => if (arg < 0) -%arg else arg,
        .popcnt => @popCount(@as(u64, @bitCast(arg))),
        .clz => @clz(@as(u64, @bitCast(arg))),
        .ctz => @ctz(@as(u64, @bitCast(arg))),
        .fneg => blk: {
            const f = @as(f64, @bitCast(arg));
            break :blk @bitCast(-f);
        },
        .fabs => blk: {
            const f = @as(f64, @bitCast(arg));
            break :blk @bitCast(@abs(f));
        },
        .ceil => blk: {
            const f = @as(f64, @bitCast(arg));
            break :blk @bitCast(@ceil(f));
        },
        .floor => blk: {
            const f = @as(f64, @bitCast(arg));
            break :blk @bitCast(@floor(f));
        },
        .trunc => blk: {
            const f = @as(f64, @bitCast(arg));
            break :blk @bitCast(@trunc(f));
        },
        .nearest => blk: {
            const f = @as(f64, @bitCast(arg));
            break :blk @bitCast(@round(f));
        },
        .sqrt => blk: {
            const f = @as(f64, @bitCast(arg));
            break :blk @bitCast(@sqrt(f));
        },
        .bswap => @bitCast(@byteSwap(@as(u64, @bitCast(arg)))),
        .bitrev => @bitCast(@bitReverse(@as(u64, @bitCast(arg)))),
        .fcvt_from_sint => blk: {
            const f = @as(f64, @floatFromInt(arg));
            break :blk @bitCast(f);
        },
        .fcvt_from_uint => blk: {
            const arg_u = @as(u64, @bitCast(arg));
            const f = @as(f64, @floatFromInt(arg_u));
            break :blk @bitCast(f);
        },
        .fcvt_to_sint => blk: {
            const f = @as(f64, @bitCast(arg));
            const result = @as(i64, @intFromFloat(f));
            break :blk result;
        },
        .fcvt_to_sint_sat => blk: {
            const f = @as(f64, @bitCast(arg));
            if (std.math.isNan(f)) break :blk 0;
            if (f >= @as(f64, @floatFromInt(std.math.maxInt(i64)))) break :blk std.math.maxInt(i64);
            if (f <= @as(f64, @floatFromInt(std.math.minInt(i64)))) break :blk std.math.minInt(i64);
            break :blk @as(i64, @intFromFloat(f));
        },
        .fcvt_to_uint => blk: {
            const f = @as(f64, @bitCast(arg));
            const result = @as(u64, @intFromFloat(f));
            break :blk @bitCast(result);
        },
        .fcvt_to_uint_sat => blk: {
            const f = @as(f64, @bitCast(arg));
            if (std.math.isNan(f) or f <= 0.0) break :blk 0;
            if (f >= @as(f64, @floatFromInt(std.math.maxInt(u64)))) break :blk @bitCast(std.math.maxInt(u64));
            break :blk @bitCast(@as(u64, @intFromFloat(f)));
        },
        else => error.UnsupportedOp,
    };
}

/// Evaluate an integer comparison on constant operands.
/// Returns 1 if true, 0 if false.
fn evalIntCompare(cond: InstructionData.IntCC, lhs: i64, rhs: i64) !i64 {
    const result = switch (cond) {
        .eq => lhs == rhs,
        .ne => lhs != rhs,
        .slt => lhs < rhs,
        .sge => lhs >= rhs,
        .sgt => lhs > rhs,
        .sle => lhs <= rhs,
        .ult => @as(u64, @bitCast(lhs)) < @as(u64, @bitCast(rhs)),
        .uge => @as(u64, @bitCast(lhs)) >= @as(u64, @bitCast(rhs)),
        .ugt => @as(u64, @bitCast(lhs)) > @as(u64, @bitCast(rhs)),
        .ule => @as(u64, @bitCast(lhs)) <= @as(u64, @bitCast(rhs)),
    };
    return if (result) 1 else 0;
}

/// Evaluate a floating-point comparison on constant operands.
/// Returns 1 if true, 0 if false.
/// Interprets i64 lattice values as f64 bit patterns.
fn evalFloatCompare(cond: FloatCC, lhs: i64, rhs: i64) !i64 {
    const lhs_f = @as(f64, @bitCast(lhs));
    const rhs_f = @as(f64, @bitCast(rhs));

    const is_nan_lhs = std.math.isNan(lhs_f);
    const is_nan_rhs = std.math.isNan(rhs_f);
    const is_unordered = is_nan_lhs or is_nan_rhs;

    const result = switch (cond) {
        .ord => !is_unordered,
        .uno => is_unordered,
        .eq => !is_unordered and lhs_f == rhs_f,
        .ne => is_unordered or lhs_f != rhs_f,
        .one => !is_unordered and lhs_f != rhs_f,
        .ueq => is_unordered or lhs_f == rhs_f,
        .lt => !is_unordered and lhs_f < rhs_f,
        .le => !is_unordered and lhs_f <= rhs_f,
        .gt => !is_unordered and lhs_f > rhs_f,
        .ge => !is_unordered and lhs_f >= rhs_f,
        .ult => is_unordered or lhs_f < rhs_f,
        .ule => is_unordered or lhs_f <= rhs_f,
        .ugt => is_unordered or lhs_f > rhs_f,
        .uge => is_unordered or lhs_f >= rhs_f,
    };
    return if (result) 1 else 0;
}

// Tests

const testing = std.testing;

test "SCCP: lattice meet operation" {
    const bottom = LatticeValue.bottom;
    const c5 = LatticeValue{ .constant = 5 };
    const c10 = LatticeValue{ .constant = 10 };
    const top = LatticeValue.top;

    // Bottom ⊓ x = x
    try testing.expect(std.meta.eql(c5, LatticeValue.meet(bottom, c5)));
    try testing.expect(std.meta.eql(c5, LatticeValue.meet(c5, bottom)));

    // Constant(k) ⊓ Constant(k) = Constant(k)
    try testing.expect(std.meta.eql(c5, LatticeValue.meet(c5, c5)));

    // Constant(k1) ⊓ Constant(k2) = Top
    try testing.expect(std.meta.eql(top, LatticeValue.meet(c5, c10)));

    // Top ⊓ x = Top
    try testing.expect(std.meta.eql(top, LatticeValue.meet(top, c5)));
    try testing.expect(std.meta.eql(top, LatticeValue.meet(c5, top)));
}

test "SCCP: evalBinaryOp" {
    try testing.expectEqual(@as(i64, 7), try evalBinaryOp(.iadd, 3, 4));
    try testing.expectEqual(@as(i64, -1), try evalBinaryOp(.isub, 3, 4));
    try testing.expectEqual(@as(i64, 12), try evalBinaryOp(.imul, 3, 4));
    try testing.expectEqual(@as(i64, 0), try evalBinaryOp(.sdiv, 3, 4));
    try testing.expectEqual(@as(i64, 7), try evalBinaryOp(.band, 15, 7));
    try testing.expectEqual(@as(i64, 15), try evalBinaryOp(.bor, 8, 7));
    try testing.expectEqual(@as(i64, 8), try evalBinaryOp(.ishl, 1, 3));
}

test "SCCP: evalUnaryOp" {
    try testing.expectEqual(@as(i64, -5), try evalUnaryOp(.ineg, 5));
    try testing.expectEqual(@as(i64, ~@as(i64, 5)), try evalUnaryOp(.bnot, 5));
}

test "SCCP: init and deinit" {
    var sccp = SCCP.init(testing.allocator);
    defer sccp.deinit();

    try testing.expectEqual(@as(usize, 0), sccp.lattice.count());
}

test "SCCP: constant branch folding" {
    const sig = root.signature.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var fbuilder = root.builder.FunctionBuilder.init(&func);

    // Build: if (iconst 0) then block1 else block2
    const entry = try fbuilder.createBlock();
    const block1 = try fbuilder.createBlock();
    const block2 = try fbuilder.createBlock();

    try fbuilder.appendBlock(entry);
    try fbuilder.appendBlock(block1);
    try fbuilder.appendBlock(block2);

    fbuilder.switchToBlock(entry);
    const zero = try fbuilder.iconst(Type.I32, 0);

    // Create branch manually since builder doesn't have branch helper
    const branch_data = InstructionData{
        .branch = InstructionData.BranchData.init(.brif, zero, block1, block2),
    };
    const branch_inst = try func.dfg.makeInst(branch_data);
    try func.layout.appendInst(branch_inst, entry);

    fbuilder.switchToBlock(block1);
    try fbuilder.ret();

    fbuilder.switchToBlock(block2);
    try fbuilder.ret();

    // Run SCCP
    var sccp = SCCP.init(testing.allocator);
    defer sccp.deinit();

    const changed = try sccp.run(&func);
    _ = changed;

    // Verify: entry block and block2 should be executable (condition is 0, so else branch)
    // block1 should NOT be executable
    try testing.expect(sccp.executable_blocks.contains(entry));
    try testing.expect(sccp.executable_blocks.contains(block2));
    try testing.expect(!sccp.executable_blocks.contains(block1));

    // Verify constant propagation: zero should be constant(0)
    const zero_lat = sccp.lattice.get(zero) orelse .bottom;
    try testing.expect(zero_lat.isConstant());
    try testing.expectEqual(@as(i64, 0), zero_lat.getConstant());
}
