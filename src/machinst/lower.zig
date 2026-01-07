const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const vcode_mod = @import("vcode.zig");
const reg_mod = @import("reg.zig");

/// Track whether an SSA value is used zero, one, or multiple times.
/// Enables dead code elimination and single-use optimizations.
pub const ValueUseState = enum {
    /// Value is never used (dead code).
    unused,
    /// Value is used exactly once.
    once,
    /// Value is used more than once.
    multiple,
};

// Import real IR types
pub const Function = root.function.Function;
pub const Block = root.entities.Block;
pub const Inst = root.entities.Inst;
pub const Value = root.entities.Value;
pub const StackSlot = root.entities.StackSlot;

pub const VReg = reg_mod.VReg;
pub const Reg = reg_mod.Reg;
pub const RegClass = reg_mod.RegClass;

/// Simplified lowering context for IR -> MachInst translation.
/// This is a minimal bootstrap implementation - full lowering includes:
/// - Side-effect tracking and instruction coloring
/// - Value liveness analysis
/// - Instruction sinking optimization
/// - Block parameter handling
/// - Constant materialization
pub fn LowerCtx(comptime MachInst: type) type {
    return struct {
        /// Input IR function.
        func: *const Function,

        /// Output VCode being built.
        vcode: *vcode_mod.VCode(MachInst),

        /// Current block being lowered.
        current_block: ?vcode_mod.BlockIndex,

        /// Mapping from IR Value to VReg.
        /// This tracks which virtual register holds each SSA value.
        value_to_reg: std.AutoHashMap(Value, VReg),

        /// Mapping from IR Block to VCode BlockIndex.
        /// Used for branch target resolution.
        block_map: std.AutoHashMap(Block, vcode_mod.BlockIndex),

        /// Next available virtual register index.
        next_vreg: u32,

        /// Value use state (unused, once, multiple) for each SSA value.
        /// Used to skip dead code and enable single-use optimizations.
        value_uses: std.AutoHashMap(Value, ValueUseState),

        /// Allocator.
        allocator: Allocator,

        const Self = @This();

        pub fn init(
            allocator: Allocator,
            func: *const Function,
            vcode: *vcode_mod.VCode(MachInst),
        ) Self {
            return .{
                .func = func,
                .vcode = vcode,
                .current_block = null,
                .value_to_reg = std.AutoHashMap(Value, VReg).init(allocator),
                .block_map = std.AutoHashMap(Block, vcode_mod.BlockIndex).init(allocator),
                .next_vreg = 0,
                .value_uses = std.AutoHashMap(Value, ValueUseState).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.value_to_reg.deinit();
            self.block_map.deinit();
            self.value_uses.deinit();
        }

        /// Get the virtual register holding a value, allocating if needed.
        pub fn getValueReg(self: *Self, value: Value, class: RegClass) !VReg {
            const entry = try self.value_to_reg.getOrPut(value);
            if (!entry.found_existing) {
                const vreg = VReg.new(self.next_vreg, class);
                self.next_vreg += 1;
                entry.value_ptr.* = vreg;
            }
            return entry.value_ptr.*;
        }

        /// Allocate a fresh virtual register.
        pub fn allocVReg(self: *Self, class: RegClass) VReg {
            const vreg = VReg.new(self.next_vreg, class);
            self.next_vreg += 1;
            return vreg;
        }

        /// Emit a machine instruction to the current block.
        pub fn emit(self: *Self, inst: MachInst) !void {
            _ = self.current_block orelse return error.NoCurrentBlock;
            _ = try self.vcode.addInst(inst);
        }

        /// Start lowering a new block.
        pub fn startBlock(self: *Self, ir_block: Block) !vcode_mod.BlockIndex {
            // Get block parameters from IR and look up their VRegs
            const ir_params = self.func.dfg.blockParams(ir_block);
            var vregs = try self.allocator.alloc(VReg, ir_params.len);
            defer self.allocator.free(vregs);

            for (ir_params, 0..) |param_value, i| {
                // Look up the VReg that was pre-allocated for this parameter
                const vreg = self.value_to_reg.get(param_value) orelse return error.UnallocatedBlockParam;
                vregs[i] = vreg;
            }

            const block_idx = try self.vcode.startBlock(vregs);
            self.current_block = block_idx;
            try self.block_map.put(ir_block, block_idx);
            return block_idx;
        }

        /// Finish lowering the current block.
        pub fn endBlock(self: *Self) void {
            self.current_block = null;
        }

        /// Get the VCode block index for an IR block.
        /// Returns label for branch targets.
        pub fn getBlockLabel(self: *const Self, ir_block: Block) !u32 {
            const block_idx = self.block_map.get(ir_block) orelse return error.BlockNotFound;
            return block_idx;
        }

        /// Get instruction data for an IR instruction.
        pub fn getInstData(self: *const Self, inst: Inst) *const root.instruction_data.InstructionData {
            return self.func.dfg.insts.get(inst).?;
        }

        /// Get the type of an IR value.
        pub fn getValueType(self: *const Self, value: Value) root.types.Type {
            return self.func.dfg.valueType(value) orelse unreachable; // Value must have type
        }

        /// Compute value use counts for dead code elimination.
        /// Marks each SSA value as unused, used once, or used multiple times.
        pub fn computeValueUses(self: *Self) !void {
            // Initialize all values as unused
            var block_iter = self.func.layout.blockIter();
            while (block_iter.next()) |block| {
                // Mark block params as unused initially
                const block_params = self.func.dfg.blockParams(block);
                for (block_params) |param_value| {
                    try self.value_uses.put(param_value, .unused);
                }

                // Mark instruction results as unused initially
                var inst_iter = self.func.layout.blockInsts(block);
                while (inst_iter.next()) |inst| {
                    const results = self.func.dfg.instResults(inst);
                    for (results) |result_value| {
                        try self.value_uses.put(result_value, .unused);
                    }
                }
            }

            // Scan all instruction operands to count uses
            block_iter = self.func.layout.blockIter();
            while (block_iter.next()) |block| {
                var inst_iter = self.func.layout.blockInsts(block);
                while (inst_iter.next()) |inst| {
                    const inst_data = self.func.dfg.insts.get(inst).?;

                    // TODO: Implement InstructionData.collectOperands
                    _ = inst_data;
                    const operands: [0]Value = .{};
                    for (operands) |operand| {
                        // Increment use count: unused -> once -> multiple
                        const entry = try self.value_uses.getOrPut(operand);
                        if (!entry.found_existing) {
                            // Value used but not defined - could be a constant
                            entry.value_ptr.* = .once;
                        } else {
                            entry.value_ptr.* = switch (entry.value_ptr.*) {
                                .unused => .once,
                                .once => .multiple,
                                .multiple => .multiple,
                            };
                        }
                    }
                }
            }
        }

        /// Pre-allocate VRegs for all SSA values in the function.
        /// This must be called before lowering begins.
        /// Cranelift does this to enable vreg aliasing (ISLE temps → SSA vregs).
        pub fn allocateSSAVRegs(self: *Self) !void {
            // Allocate VRegs for all instruction results
            var block_iter = self.func.layout.blockIter();
            while (block_iter.next()) |block| {
                // Allocate VRegs for block parameters
                const block_params = self.func.dfg.blockParams(block);
                for (block_params) |param_value| {
                    const param_type = self.func.dfg.valueType(param_value) orelse continue;
                    const reg_class = regClassForType(param_type);
                    const vreg = VReg.new(self.next_vreg, reg_class);
                    self.next_vreg += 1;
                    try self.value_to_reg.put(param_value, vreg);
                }

                // Allocate VRegs for instruction results
                var inst_iter = self.func.layout.blockInsts(block);
                while (inst_iter.next()) |inst| {
                    const results = self.func.dfg.instResults(inst);
                    for (results) |result_value| {
                        const result_type = self.func.dfg.valueType(result_value) orelse continue;
                        const reg_class = regClassForType(result_type);
                        const vreg = VReg.new(self.next_vreg, reg_class);
                        self.next_vreg += 1;
                        try self.value_to_reg.put(result_value, vreg);
                    }
                }
            }
        }

        /// Determine register class from IR type.
        fn regClassForType(ty: root.types.Type) RegClass {
            return if (ty.isInt()) .int else .float;
        }

        /// Get the offset of a stack slot within the locals area.
        /// Returns offset in bytes from the start of the locals/spills area.
        /// Note: This is NOT the final SP offset - the ABI layer adds FP/LR
        /// and callee-save overhead during prologue/epilogue generation.
        pub fn getStackSlotOffset(self: *const Self, slot: StackSlot) i32 {
            var offset: u32 = 0;

            // Iterate through all stack slots up to the requested one
            const slots = self.func.stack_slots.elems.items;
            const slot_idx = slot.index();

            for (slots[0..@min(slot_idx, slots.len)]) |slot_data| {
                // Align to slot's required alignment
                const alignment = slot_data.alignment();
                const mask = alignment - 1;
                offset = (offset + mask) & ~mask;

                // Add slot size
                offset += slot_data.size;
            }

            // Align final offset to the requested slot's alignment
            if (slot_idx < slots.len) {
                const slot_data = slots[slot_idx];
                const alignment = slot_data.alignment();
                const mask = alignment - 1;
                offset = (offset + mask) & ~mask;
            }

            return @intCast(offset);
        }
    };
}

/// Backend trait for architecture-specific lowering.
/// Each target (x64, aarch64, etc.) implements this.
pub fn LowerBackend(comptime MachInst: type) type {
    return struct {
        /// Lower a single IR instruction to machine instructions.
        /// Returns true if the instruction was handled, false otherwise.
        lowerInstFn: *const fn (
            ctx: *LowerCtx(MachInst),
            inst: Inst,
        ) anyerror!bool,

        /// Lower a branch instruction.
        /// Branches are handled separately because they affect control flow.
        lowerBranchFn: *const fn (
            ctx: *LowerCtx(MachInst),
            inst: Inst,
        ) anyerror!bool,
    };
}

/// Compute reverse postorder traversal of blocks.
fn computeRPO(allocator: Allocator, func: *const Function) !std.ArrayList(Block) {
    var rpo = std.ArrayList(Block){};
    errdefer rpo.deinit(allocator);

    var visited = std.AutoHashMap(Block, void).init(allocator);
    defer visited.deinit();

    // Get entry block (first block in layout)
    var block_iter = func.layout.blockIter();
    const entry = block_iter.next() orelse return rpo;

    // DFS postorder traversal
    try dfsPostorder(func, entry, &visited, &rpo, allocator);

    // Reverse to get reverse postorder
    std.mem.reverse(Block, rpo.items);

    return rpo;
}

/// DFS helper for postorder traversal.
fn dfsPostorder(
    func: *const Function,
    block: Block,
    visited: *std.AutoHashMap(Block, void),
    postorder: *std.ArrayList(Block),
    allocator: Allocator,
) !void {
    if (visited.contains(block)) return;
    try visited.put(block, {});

    // Visit successors by examining block terminator
    // TODO: Implement proper CFG successor traversal
    // For now, just iterate through instructions (stub implementation)
    var inst_iter = func.layout.blockInsts(block);
    while (inst_iter.next()) |_| {
        // TODO: analyze terminator to get CFG successors
    }

    // Add block to postorder after visiting successors
    try postorder.append(allocator, block);
}

/// Lower an entire function from IR to VCode.
pub fn lowerFunction(
    comptime MachInst: type,
    allocator: Allocator,
    func: *const Function,
    backend: LowerBackend(MachInst),
) !vcode_mod.VCode(MachInst) {
    var vcode = vcode_mod.VCode(MachInst).init(allocator);
    errdefer vcode.deinit();

    var ctx = LowerCtx(MachInst).init(allocator, func, &vcode);
    defer ctx.deinit();

    // Pre-allocate VRegs for all SSA values
    try ctx.allocateSSAVRegs();

    // Compute value use counts for dead code elimination
    try ctx.computeValueUses();

    // Lower each block in reverse postorder
    var rpo = try computeRPO(allocator, func);
    defer rpo.deinit(allocator);

    for (rpo.items) |ir_block| {
        // Start new machine block
        _ = try ctx.startBlock(ir_block);

        // Lower each instruction in the block, tracking last instruction
        var inst_iter = func.layout.blockInsts(ir_block);
        var last_inst: ?Inst = null;
        while (inst_iter.next()) |ir_inst| {
            last_inst = ir_inst;
            // Try to lower the instruction
            const handled = try backend.lowerInstFn(&ctx, ir_inst);
            if (!handled) {
                // Instruction not handled - this is an error
                std.debug.print("Unhandled instruction: {any}\n", .{ir_inst});
                return error.UnhandledInstruction;
            }
        }

        // Handle block terminator (branch) - last instruction in block
        if (last_inst) |term_inst| {
            _ = try backend.lowerBranchFn(&ctx, term_inst);
        }

        ctx.endBlock();
    }

    return vcode;
}

// Stub test - actual lowering requires a real backend implementation
test "LowerCtx basic" {
    const TestInst = struct {
        opcode: u32,
    };

    const Signature = root.signature.Signature;

    // Create minimal stub function
    const sig = Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var vcode = vcode_mod.VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(TestInst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Test vreg allocation
    const v1 = Value.new(0);
    const r1 = try ctx.getValueReg(v1, .int);
    const r1_again = try ctx.getValueReg(v1, .int);
    try testing.expectEqual(r1, r1_again);

    const v2 = Value.new(1);
    const r2 = try ctx.getValueReg(v2, .int);
    try testing.expect(!std.meta.eql(r1, r2));
}

test "SSA VReg pre-allocation" {
    const TestInst = struct {
        opcode: u32,
    };

    const Signature = root.signature.Signature;
    //     const Type = root.types.Type;
    const InstructionData = root.instruction_data.InstructionData;

    // Create function with some instructions
    const sig = Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test_prealloc", sig);
    defer func.deinit();

    // Create block with instructions
    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    // Add an instruction that produces a value
    const iconst_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = .{ .value = 42 },
    } };
    const inst1 = try func.dfg.makeInst(iconst_data);
    try func.layout.appendInst(inst1, block0);
    const v1 = func.dfg.firstResult(inst1).?;
    //     try func.dfg.attachResult(inst1, Type.i64());

    // Create LowerCtx and pre-allocate VRegs
    var vcode = vcode_mod.VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(TestInst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Pre-allocate VRegs
    try ctx.allocateSSAVRegs();

    // Verify that v1 already has a VReg allocated
    const vreg = try ctx.getValueReg(v1, .int);
    try testing.expectEqual(@as(u32, 0), vreg.index());
    try testing.expectEqual(RegClass.int, vreg.class());

    // Verify that calling getValueReg again returns the same VReg
    const vreg_again = try ctx.getValueReg(v1, .int);
    try testing.expectEqual(vreg, vreg_again);
}

test "Value use state computation" {
    const TestInst = struct {
        opcode: u32,
    };

    const Signature = root.signature.Signature;
    //     const Type = root.types.Type;
    const InstructionData = root.instruction_data.InstructionData;

    // Create function with dead and live values
    // block0:
    //   v0 = iconst 10   (dead - never used)
    //   v1 = iconst 20   (used once)
    //   v2 = iconst 30   (used multiple times)
    //   v3 = iadd v1, v2
    //   v4 = iadd v2, v2
    //   return v4

    const sig = Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test_value_uses", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    // v0 = iconst 10 (dead)
    const v0_inst = try func.dfg.makeInst(InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = .{ .value = 10 },
    } });
    try func.layout.appendInst(v0_inst, block0);
    const v0 = func.dfg.firstResult(v0_inst).?;
    //     try func.dfg.attachResult(v0_inst, Type.i64());

    // v1 = iconst 20 (used once in v3)
    const v1_inst = try func.dfg.makeInst(InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = .{ .value = 20 },
    } });
    try func.layout.appendInst(v1_inst, block0);
    const v1 = func.dfg.firstResult(v1_inst).?;
    //     try func.dfg.attachResult(v1_inst, Type.i64());

    // v2 = iconst 30 (used multiple times)
    const v2_inst = try func.dfg.makeInst(InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = .{ .value = 30 },
    } });
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;
    //     try func.dfg.attachResult(v2_inst, Type.i64());

    // v3 = iadd v1, v2
    const v3_inst = try func.dfg.makeInst(InstructionData{ .binary = .{
        .opcode = .iadd,
        .args = .{ v1, v2 },
    } });
    try func.layout.appendInst(v3_inst, block0);
    const v3 = func.dfg.firstResult(v3_inst).?;
    //     try func.dfg.attachResult(v3_inst, Type.i64());

    // v4 = iadd v2, v2 (uses v2 again)
    const v4_inst = try func.dfg.makeInst(InstructionData{ .binary = .{
        .opcode = .iadd,
        .args = .{ v2, v2 },
    } });
    try func.layout.appendInst(v4_inst, block0);
    const v4 = func.dfg.firstResult(v4_inst).?;
    //     try func.dfg.attachResult(v4_inst, Type.i64());

    // return v4
    const ret_inst = try func.dfg.makeInst(InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v4,
    } });
    try func.layout.appendInst(ret_inst, block0);

    // Create LowerCtx and compute value uses
    var vcode = vcode_mod.VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(TestInst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    try ctx.computeValueUses();

    // Verify use states
    try testing.expectEqual(ValueUseState.unused, ctx.value_uses.get(v0).?); // dead
    try testing.expectEqual(ValueUseState.once, ctx.value_uses.get(v1).?); // used once
    try testing.expectEqual(ValueUseState.multiple, ctx.value_uses.get(v2).?); // used 3 times
    try testing.expectEqual(ValueUseState.unused, ctx.value_uses.get(v3).?); // dead (not used in return)
    try testing.expectEqual(ValueUseState.once, ctx.value_uses.get(v4).?); // used once (in return)
}
