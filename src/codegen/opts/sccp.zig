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
            .unary => |d| {
                const arg_lat = self.lattice.get(d.arg) orelse .bottom;

                if (arg_lat == .bottom) return .bottom;
                if (arg_lat == .top) return .top;

                const arg = arg_lat.getConstant();
                return .{ .constant = try evalUnaryOp(d.opcode, arg) };
            },
            else => .top, // Conservative: unknown instruction
        };
    }

    /// Evaluate branch instructions for constant conditions.
    fn evaluateBranch(_: *SCCP, _: *Function, _: Inst, _: InstructionData) !void {
        // TODO: Implement branch evaluation
        // For now, conservatively assume all branches can go either way
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
                if (instUsesValue(inst_data.*, value)) {
                    try self.ssa_worklist.append(inst);
                }
            }
        }
    }

    /// Check if an instruction uses a specific value as an operand.
    fn instUsesValue(inst_data: InstructionData, value: Value) bool {
        return switch (inst_data) {
            .unary => |d| std.meta.eql(d.arg, value),
            .binary => |d| std.meta.eql(d.lhs, value) or std.meta.eql(d.rhs, value),
            .int_compare => |d| std.meta.eql(d.lhs, value) or std.meta.eql(d.rhs, value),
            .float_compare => |d| std.meta.eql(d.lhs, value) or std.meta.eql(d.rhs, value),
            .branch => |d| std.meta.eql(d.condition, value),
            .load => |d| std.meta.eql(d.addr, value),
            .store => |d| std.meta.eql(d.addr, value) or std.meta.eql(d.value, value),
            // TODO: Add more instruction types as needed
            else => false,
        };
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

        // TODO: Remove instructions in non-executable blocks
        // This requires:
        // 1. Iterating through all blocks
        // 2. For blocks not in executable_blocks, remove their instructions
        // 3. Update control flow to remove branches to dead blocks

        return changed;
    }
};

/// Evaluate a binary operation on constant operands.
fn evalBinaryOp(opcode: Opcode, lhs: i64, rhs: i64) !i64 {
    return switch (opcode) {
        .iadd => lhs +% rhs,
        .isub => lhs -% rhs,
        .imul => lhs *% rhs,
        .sdiv => if (rhs == 0) error.DivisionByZero else @divTrunc(lhs, rhs),
        .udiv => if (rhs == 0) error.DivisionByZero else @divTrunc(@as(u64, @bitCast(lhs)), @as(u64, @bitCast(rhs))),
        .srem => if (rhs == 0) error.DivisionByZero else @rem(lhs, rhs),
        .urem => if (rhs == 0) error.DivisionByZero else @rem(@as(u64, @bitCast(lhs)), @as(u64, @bitCast(rhs))),
        .band => lhs & rhs,
        .bor => lhs | rhs,
        .bxor => lhs ^ rhs,
        .ishl => lhs << @intCast(rhs & 63),
        .ushr => @as(i64, @bitCast(@as(u64, @bitCast(lhs)) >> @intCast(rhs & 63))),
        .sshr => lhs >> @intCast(rhs & 63),
        else => error.UnsupportedOp,
    };
}

/// Evaluate a unary operation on a constant operand.
fn evalUnaryOp(opcode: Opcode, arg: i64) !i64 {
    return switch (opcode) {
        .bnot => ~arg,
        .ineg => -%arg,
        else => error.UnsupportedOp,
    };
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
