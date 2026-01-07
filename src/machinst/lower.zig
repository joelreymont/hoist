const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("root");
const vcode_mod = @import("vcode.zig");
const reg_mod = @import("reg.zig");

// Import real IR types
pub const Function = root.function.Function;
pub const Block = root.entities.Block;
pub const Inst = root.entities.Inst;
pub const Value = root.entities.Value;

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

        /// Next available virtual register index.
        next_vreg: u32,

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
                .next_vreg = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.value_to_reg.deinit();
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
        pub fn startBlock(self: *Self, _: Block) !vcode_mod.BlockIndex {
            const block_idx = try self.vcode.startBlock(&.{}); // No params for now
            self.current_block = block_idx;
            return block_idx;
        }

        /// Finish lowering the current block.
        pub fn endBlock(self: *Self) void {
            self.current_block = null;
        }

        /// Get instruction data for an IR instruction.
        pub fn getInstData(self: *const Self, inst: Inst) *const root.instruction_data.InstructionData {
            return self.func.dfg.insts.get(inst).?;
        }

        /// Get the type of an IR value.
        pub fn getValueType(self: *const Self, value: Value) root.types.Type {
            return self.func.dfg.valueType(value);
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
    errdefer rpo.deinit();

    var visited = std.AutoHashMap(Block, void).init(allocator);
    defer visited.deinit();

    // Get entry block (first block in layout)
    var block_iter = func.layout.blocks();
    const entry = block_iter.next() orelse return rpo;

    // DFS postorder traversal
    try dfsPostorder(func, entry, &visited, &rpo);

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
) !void {
    if (visited.contains(block)) return;
    try visited.put(block, {});

    // Visit successors by examining block terminator
    if (func.layout.lastInst(block)) |_| {
        // For this stub, we don't have actual CFG analysis
        // In real implementation, would traverse CFG successors here
    }

    // Add block to postorder after visiting successors
    try postorder.append(block);
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

    // Lower each block in reverse postorder
    var rpo = try computeRPO(allocator, func);
    defer rpo.deinit();

    for (rpo.items) |ir_block| {
        // Start new machine block
        _ = try ctx.startBlock(ir_block);

        // Lower each instruction in the block
        var inst_iter = func.layout.blockInsts(ir_block);
        while (inst_iter.next()) |ir_inst| {
            // Try to lower the instruction
            const handled = try backend.lowerInstFn(&ctx, ir_inst);
            if (!handled) {
                // Instruction not handled - this is an error
                std.debug.print("Unhandled instruction: {}\n", .{ir_inst});
                return error.UnhandledInstruction;
            }
        }

        // Handle block terminator (branch)
        if (func.layout.lastInst(ir_block)) |term_inst| {
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
    const sig = Signature.init(&.{}, &.{});
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
