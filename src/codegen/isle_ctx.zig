//! ISLE lowering context for instruction selection.
//!
//! This module provides the LowerCtx structure that ISLE-generated lowering
//! code uses to interact with the IR and emit machine instructions.
//!
//! Reference: Cranelift's Lower context in machinst/lower.rs

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir = @import("../ir.zig");
const Function = ir.Function;
const Block = ir.entities.Block;
const Inst = ir.entities.Inst;
const Value = ir.entities.Value;
const Type = ir.types.Type;
const ValueDef = ir.dfg.ValueDef;
const Signature = ir.signature.Signature;

const lower_helpers = @import("lower_helpers.zig");
const ValueRegs = lower_helpers.ValueRegs;
const RegClass = lower_helpers.RegClass;

const vcode_mod = @import("../machinst/vcode.zig");
const reg_mod = @import("../machinst/reg.zig");
const VCode = vcode_mod.VCode;
const VReg = reg_mod.VReg;
const Reg = reg_mod.Reg;
const BlockIndex = vcode_mod.BlockIndex;

/// ISLE lowering context - the main interface for instruction selection.
///
/// This context provides:
/// - Access to the IR function being lowered
/// - Value-to-register mapping and allocation
/// - Instruction emission to VCode
/// - Helper queries for pattern matching
pub fn LowerCtx(comptime MachInst: type) type {
    return struct {
        /// Input IR function being lowered.
        func: *const Function,

        /// Output VCode being built.
        vcode: *VCode(MachInst),

        /// Mapping from IR Value to virtual register(s).
        /// Wide values (i128) may require multiple registers.
        value_regs: std.AutoHashMap(Value, ValueRegs(VReg)),

        /// Next available virtual register index.
        next_vreg: u32,

        /// Current instruction being lowered (for diagnostics).
        current_inst: ?Inst,

        /// Current block being lowered.
        current_block: ?BlockIndex,

        /// Allocator for temporary data structures.
        allocator: Allocator,

        const Self = @This();

        pub fn init(
            allocator: Allocator,
            func: *const Function,
            vcode: *VCode(MachInst),
        ) Self {
            return .{
                .func = func,
                .vcode = vcode,
                .value_regs = std.AutoHashMap(Value, ValueRegs(VReg)).init(allocator),
                .next_vreg = 0,
                .current_inst = null,
                .current_block = null,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.value_regs.deinit();
        }

        // ===== Value and Register Management =====

        /// Get virtual register(s) for an IR value, allocating if needed.
        /// This is the primary way to get a vreg for a value during lowering.
        pub fn getValueReg(self: *Self, value: Value, class: RegClass) !VReg {
            const regs = try self.getValueRegs(value, class);
            return regs.onlyReg() orelse error.ValueRequiresMultipleRegs;
        }

        /// Get virtual register(s) for an IR value (may be multiple for wide types).
        pub fn getValueRegs(self: *Self, value: Value, class: RegClass) !ValueRegs(VReg) {
            const entry = try self.value_regs.getOrPut(value);
            if (!entry.found_existing) {
                const ty = self.valueType(value);
                const num_regs = lower_helpers.numRegsForType(ty);

                if (num_regs == 1) {
                    const vreg = self.allocVReg(class);
                    entry.value_ptr.* = ValueRegs(VReg).one(vreg);
                } else if (num_regs == 2) {
                    const vreg1 = self.allocVReg(class);
                    const vreg2 = self.allocVReg(class);
                    entry.value_ptr.* = ValueRegs(VReg).two(vreg1, vreg2);
                } else {
                    return error.UnsupportedRegCount;
                }
            }
            return entry.value_ptr.*;
        }

        /// Allocate a fresh virtual register.
        pub fn allocVReg(self: *Self, class: RegClass) VReg {
            const vreg = VReg.new(self.next_vreg, class);
            self.next_vreg += 1;
            return vreg;
        }

        /// Allocate a temporary virtual register of the given type.
        pub fn allocTemp(self: *Self, ty: Type) ValueRegs(VReg) {
            const class = RegClass.forType(ty);
            const num_regs = lower_helpers.numRegsForType(ty);

            if (num_regs == 1) {
                return ValueRegs(VReg).one(self.allocVReg(class));
            } else if (num_regs == 2) {
                const vreg1 = self.allocVReg(class);
                const vreg2 = self.allocVReg(class);
                return ValueRegs(VReg).two(vreg1, vreg2);
            } else {
                unreachable; // Should be caught by type validation
            }
        }

        // ===== Instruction Emission =====

        /// Emit a machine instruction to the current block.
        /// This is called by ISLE constructor functions.
        pub fn emit(self: *Self, inst: MachInst) !void {
            _ = self.current_block orelse return error.NoCurrentBlock;
            _ = try self.vcode.addInst(inst);
        }

        // ===== IR Queries =====

        /// Get the type of a value.
        pub fn valueType(self: *const Self, value: Value) Type {
            return self.func.dfg.valueType(value);
        }

        /// Get the value definition (where it comes from).
        pub fn valueDef(self: *const Self, value: Value) ?ValueDef {
            return self.func.dfg.valueDef(value);
        }

        /// Get instruction data for an instruction.
        pub fn instData(self: *const Self, inst: Inst) ?*const ir.instruction_data.InstructionData {
            return self.func.dfg.insts.get(inst);
        }

        /// Get the number of instruction inputs.
        pub fn numInputs(self: *const Self, inst: Inst) usize {
            const inst_data = self.instData(inst) orelse return 0;
            return inst_data.numArgs();
        }

        /// Get the number of instruction outputs.
        pub fn numOutputs(self: *const Self, inst: Inst) usize {
            const results = self.func.dfg.instResults(inst);
            return results.len;
        }

        /// Get the type of an instruction input.
        pub fn inputType(self: *const Self, inst: Inst, idx: usize) Type {
            const value = self.inputAsValue(inst, idx);
            return self.valueType(value);
        }

        /// Get the type of an instruction output.
        pub fn outputType(self: *const Self, inst: Inst, idx: usize) Type {
            const results = self.func.dfg.instResults(inst);
            if (idx >= results.len) return Type.invalid;
            return self.valueType(results[idx]);
        }

        /// Get an input value.
        pub fn inputAsValue(self: *const Self, inst: Inst, idx: usize) Value {
            const inst_data = self.instData(inst) orelse return Value.invalid;
            const args = inst_data.args(&self.func.dfg.value_lists);
            if (idx >= args.len) return Value.invalid;
            return args[idx];
        }

        /// Try to get a constant value for an instruction.
        /// Returns null if the instruction is not a constant.
        pub fn getConstant(self: *const Self, inst: Inst) ?u64 {
            const inst_data = self.instData(inst) orelse return null;
            return switch (inst_data.*) {
                .iconst => |data| @bitCast(data.imm),
                else => null,
            };
        }

        /// Try to get a constant value for a Value.
        /// Returns null if the value is not defined by a constant instruction.
        pub fn getValueConstant(self: *const Self, value: Value) ?u64 {
            const def = self.valueDef(value) orelse return null;
            const inst = def.inst() orelse return null;
            return self.getConstant(inst);
        }

        // ===== Block Management =====

        /// Start lowering a new block.
        pub fn startBlock(self: *Self, _: Block) !BlockIndex {
            const block_idx = try self.vcode.startBlock(&.{}); // Block params handled separately
            self.current_block = block_idx;
            return block_idx;
        }

        /// Finish lowering the current block.
        pub fn endBlock(self: *Self, successors: []const BlockIndex) !void {
            if (self.current_block) |block| {
                try self.vcode.finishBlock(block, successors);
                self.current_block = null;
            }
        }

        // ===== Pattern Matching Helpers =====

        /// Check if a value is a constant.
        pub fn isConstant(self: *const Self, value: Value) bool {
            return self.getValueConstant(value) != null;
        }

        /// Check if a value is defined by a specific instruction.
        pub fn isInstResult(self: *const Self, value: Value, inst: Inst) bool {
            const def = self.valueDef(value) orelse return false;
            return if (def.inst()) |src_inst| src_inst.eql(inst) else false;
        }

        /// Check if a constant fits in a signed immediate of the given bit width.
        pub fn fitsInSImm(self: *const Self, value: Value, bits: u8) bool {
            const const_val = self.getValueConstant(value) orelse return false;
            const signed: i64 = @bitCast(const_val);
            const max_pos: i64 = (@as(i64, 1) << @intCast(bits - 1)) - 1;
            const max_neg: i64 = -(@as(i64, 1) << @intCast(bits - 1));
            return signed >= max_neg and signed <= max_pos;
        }

        /// Check if a constant fits in an unsigned immediate of the given bit width.
        pub fn fitsInUImm(self: *const Self, value: Value, bits: u8) bool {
            const const_val = self.getValueConstant(value) orelse return false;
            const max: u64 = (@as(u64, 1) << @intCast(bits)) - 1;
            return const_val <= max;
        }

        // ===== Diagnostic Helpers =====

        /// Set the current instruction being lowered (for error messages).
        pub fn setCurrentInst(self: *Self, inst: Inst) void {
            self.current_inst = inst;
        }

        /// Get diagnostic context for error reporting.
        pub fn getDiagnosticContext(self: *const Self) struct {
            func: *const Function,
            inst: ?Inst,
            block: ?BlockIndex,
        } {
            return .{
                .func = self.func,
                .inst = self.current_inst,
                .block = self.current_block,
            };
        }
    };
}

// ===== Tests =====

const testing = std.testing;
const root = @import("root");

test "LowerCtx: basic initialization" {
    const TestInst = struct {
        opcode: u32,
    };

    const sig = try Signature.init(testing.allocator);
    const func = try Function.init(testing.allocator, "test", sig);
    var func_mut = func;
    defer func_mut.deinit();

    var vcode = VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(TestInst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    try testing.expectEqual(@as(u32, 0), ctx.next_vreg);
    try testing.expectEqual(@as(?Inst, null), ctx.current_inst);
}

test "LowerCtx: vreg allocation" {
    const TestInst = struct {
        opcode: u32,
    };

    const sig = try Signature.init(testing.allocator);
    const func = try Function.init(testing.allocator, "test", sig);
    var func_mut = func;
    defer func_mut.deinit();

    var vcode = VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(TestInst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const r1 = ctx.allocVReg(.int);
    const r2 = ctx.allocVReg(.int);
    const r3 = ctx.allocVReg(.fp);

    try testing.expectEqual(@as(u32, 0), r1.index);
    try testing.expectEqual(@as(u32, 1), r2.index);
    try testing.expectEqual(@as(u32, 2), r3.index);
    try testing.expectEqual(RegClass.int, r1.class);
    try testing.expectEqual(RegClass.fp, r3.class);
}

test "LowerCtx: value to register mapping" {
    const TestInst = struct {
        opcode: u32,
    };

    const sig = try Signature.init(testing.allocator);
    const func = try Function.init(testing.allocator, "test", sig);
    var func_mut = func;
    defer func_mut.deinit();

    var vcode = VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(TestInst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    // Mock: would need real value types in actual implementation
    // For now, test allocation consistency
    const count_before = ctx.value_regs.count();
    try testing.expectEqual(@as(usize, 0), count_before);

    // Note: This test is limited because we can't create real values without a full DFG
    // In practice, values would come from the IR function
    // Values v1 and v2 would be used here in a full implementation
}

test "LowerCtx: temporary allocation" {
    const TestInst = struct {
        opcode: u32,
    };

    const sig = try Signature.init(testing.allocator);
    const func = try Function.init(testing.allocator, "test", sig);
    var func_mut = func;
    defer func_mut.deinit();

    var vcode = VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(TestInst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const temp1 = ctx.allocTemp(Type.I32);
    const temp2 = ctx.allocTemp(Type.I64);

    try testing.expect(temp1.isValid());
    try testing.expect(temp2.isValid());
    try testing.expectEqual(@as(u8, 1), temp1.len);
    try testing.expectEqual(@as(u8, 1), temp2.len);
}

test "LowerCtx: diagnostic context" {
    const TestInst = struct {
        opcode: u32,
    };

    const sig = try Signature.init(testing.allocator);
    const func = try Function.init(testing.allocator, "test", sig);
    var func_mut = func;
    defer func_mut.deinit();

    var vcode = VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(TestInst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const inst = Inst.new(42);
    ctx.setCurrentInst(inst);

    const diag = ctx.getDiagnosticContext();
    try testing.expectEqual(inst, diag.inst.?);
}

test "LowerCtx: block management" {
    const TestInst = struct {
        opcode: u32,
    };

    const sig = try Signature.init(testing.allocator);
    const func = try Function.init(testing.allocator, "test", sig);
    var func_mut = func;
    defer func_mut.deinit();

    var vcode = VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = LowerCtx(TestInst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const ir_block = Block.new(0);
    const block_idx = try ctx.startBlock(ir_block);
    try testing.expectEqual(@as(BlockIndex, 0), block_idx);
    try testing.expectEqual(@as(?BlockIndex, 0), ctx.current_block);

    try ctx.endBlock(&.{});
    try testing.expectEqual(@as(?BlockIndex, null), ctx.current_block);
}
