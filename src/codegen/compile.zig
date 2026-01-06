//! Main compilation entry point.
//!
//! Orchestrates the entire compilation pipeline:
//! 1. Verification
//! 2. Legalization
//! 3. Optimization
//! 4. CFG/dominator tree computation
//! 5. Lowering (IR -> VCode via ISLE)
//! 6. Register allocation
//! 7. Prologue/epilogue insertion
//! 8. Code emission

const std = @import("std");
pub const Context = @import("context.zig").Context;
pub const CompiledCode = @import("context.zig").CompiledCode;
const Relocation = @import("context.zig").Relocation;
const RelocKind = @import("context.zig").RelocKind;
const Function = @import("../ir/function.zig").Function;
const Block = @import("../ir/entities.zig").Block;
const ir = struct {
    pub const Type = @import("../ir/types.zig").Type;
    pub const I32 = @import("../ir/types.zig").Type.I32;
    pub const I64 = @import("../ir/types.zig").Type.I64;
    pub const Signature = @import("../ir/signature.zig").Signature;
    pub const Verifier = @import("../ir/verifier.zig").Verifier;
    pub const Inst = @import("../ir/entities.zig").Inst;
    pub const Value = @import("../ir/entities.zig").Value;
    pub const ValueData = @import("../ir/dfg.zig").ValueData;
    pub const FunctionBuilder = @import("../ir/builder.zig").FunctionBuilder;
};
const MachBuffer = @import("../machinst/buffer.zig").MachBuffer;
const Reloc = @import("../machinst/buffer.zig").Reloc;

/// Compilation error with context.
pub const CompileError = struct {
    inner: CodegenError,
    message: []const u8,

    pub fn format(
        self: CompileError,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Compile error: {s}", .{self.message});
    }
};

/// Codegen errors.
pub const CodegenError = error{
    /// Verification failed.
    VerificationFailed,
    /// Legalization failed.
    LegalizationFailed,
    /// Optimization failed.
    OptimizationFailed,
    /// Lowering failed.
    LoweringFailed,
    /// Register allocation failed.
    RegisterAllocationFailed,
    /// Code emission failed.
    EmissionFailed,
    /// Out of memory.
    OutOfMemory,
    /// IR building failed.
    IRBuildFailed,
};

/// Compilation result type.
pub const CompileResult = CodegenError!*const CompiledCode;

/// Main compilation entry point.
///
/// Runs the function through all compilation passes:
/// - Verification (if enabled)
/// - Legalization
/// - Optimization
/// - Lowering to machine code
/// - Register allocation
/// - Code emission
///
/// Returns compiled machine code with relocations.
pub fn compile(
    ctx: *Context,
    func: *Function,
    target: *const Target,
) CompileResult {
    // Set the function pointer in context
    ctx.func = func;

    // 1. Verify IR (if enabled)
    try verifyIf(ctx, func, target);

    // 2. Optimize IR
    try optimize(ctx, target);

    // 3. Lower to VCode via ISLE
    try lower(ctx, target);

    // 4. Register allocation
    try allocateRegisters(ctx, target);

    // 5. Prologue/epilogue insertion
    try insertPrologueEpilogue(ctx, target);

    // 6. Emit machine code
    try emit(ctx, target);

    return ctx.getCompiledCode() orelse return error.EmissionFailed;
}

/// Verify function if verification is enabled.
fn verifyIf(ctx: *Context, func: *Function, target: *const Target) CodegenError!void {
    if (!target.verify) return;

    var verifier = ir.Verifier.init(ctx.allocator, func);
    defer verifier.deinit();

    verifier.verify() catch {
        // Verification failed - print errors
        const errors = verifier.getErrors();
        if (errors.len > 0) {
            std.debug.print("IR Verification failed:\n", .{});
            for (errors) |err| {
                std.debug.print("  {s}\n", .{err});
            }
            return error.VerificationFailed;
        }
        return error.VerificationFailed;
    };
}

/// Optimize the function.
///
/// Performs all optimization passes up to but not including lowering:
/// - NaN canonicalization (if enabled)
/// - Legalization
/// - CFG computation
/// - Dominator tree computation
/// - Unreachable code elimination
/// - Constant phi removal
/// - E-graph optimization (if opt level > 0)
fn optimize(ctx: *Context, target: *const Target) CodegenError!void {
    _ = target;

    // 1. Legalize IR
    try legalize(ctx);

    // 2. Compute CFG
    try ctx.cfg.compute(ctx.func);

    // 3. Compute dominator tree
    if (ctx.func.entryBlock()) |entry| {
        try ctx.domtree.compute(ctx.allocator, entry, &ctx.cfg);
    }

    // 4. Eliminate unreachable code
    _ = try eliminateUnreachableCode(ctx);

    // 5. Remove constant phis
    _ = try removeConstantPhis(ctx);

    // 6. Resolve value aliases
    ctx.func.dfg.resolveAllAliases();

    // 7. E-graph optimization (if opt_level > 0)
    // TODO: Implement e-graph pass
}

/// Remove constant phi nodes.
///
/// Finds block parameters where all incoming values are the same,
/// and replaces the parameter with an alias to that value.
/// Returns true if any phis were removed.
fn removeConstantPhis(ctx: *Context) CodegenError!bool {
    // TODO: Block parameters not yet implemented in IR
    _ = ctx;
    _ = ctx;
    return false;
}

/// Eliminate unreachable code.
///
/// Uses CFG to find blocks unreachable from entry and removes them.
/// Returns true if any blocks were removed.
fn eliminateUnreachableCode(ctx: *Context) CodegenError!bool {
    const entry = ctx.func.layout.entryBlock() orelse return false;

    var changed = false;
    var reachable = std.AutoHashMap(Block, void).init(ctx.allocator);
    defer reachable.deinit();

    // Mark all reachable blocks using worklist algorithm
    var worklist = std.ArrayList(Block){};
    defer worklist.deinit(ctx.allocator);

    try worklist.append(ctx.allocator, entry);
    try reachable.put(entry, {});

    while (worklist.items.len > 0) {
        const block = worklist.pop() orelse break;
        var succ_iter = ctx.cfg.succIter(block);
        while (succ_iter.next()) |succ| {
            if (!reachable.contains(succ)) {
                try reachable.put(succ, {});
                try worklist.append(ctx.allocator, succ);
            }
        }
    }

    // Remove unreachable blocks
    var block_iter = ctx.func.layout.blockIter();
    while (block_iter.next()) |block| {
        if (!reachable.contains(block)) {
            ctx.func.layout.removeBlock(block);
            changed = true;
        }
    }

    return changed;
}

/// IR building infrastructure for converting frontend input to IR.
pub const IRBuilder = struct {
    allocator: std.mem.Allocator,
    func: *Function,
    builder: ir.FunctionBuilder,

    const Self = @This();

    /// Initialize IR builder for a function.
    pub fn init(allocator: std.mem.Allocator, func: *Function) Self {
        return .{
            .allocator = allocator,
            .func = func,
            .builder = ir.FunctionBuilder.init(func),
        };
    }

    /// Create a new basic block.
    pub fn createBlock(self: *Self) !Block {
        return try self.builder.createBlock();
    }

    /// Append a block to the function layout.
    pub fn appendBlock(self: *Self, block: Block) !void {
        try self.builder.appendBlock(block);
    }

    /// Switch to building into a specific block.
    pub fn switchToBlock(self: *Self, block: Block) void {
        self.builder.switchToBlock(block);
    }

    /// Emit iconst instruction.
    pub fn emitIconst(self: *Self, ty: ir.Type, value: i64) !ir.Value {
        return try self.builder.iconst(ty, value);
    }

    /// Emit iadd instruction.
    pub fn emitIadd(self: *Self, ty: ir.Type, lhs: ir.Value, rhs: ir.Value) !ir.Value {
        return try self.builder.iadd(ty, lhs, rhs);
    }

    /// Emit isub instruction.
    pub fn emitIsub(self: *Self, ty: ir.Type, lhs: ir.Value, rhs: ir.Value) !ir.Value {
        return try self.builder.isub(ty, lhs, rhs);
    }

    /// Emit imul instruction.
    pub fn emitImul(self: *Self, ty: ir.Type, lhs: ir.Value, rhs: ir.Value) !ir.Value {
        return try self.builder.imul(ty, lhs, rhs);
    }

    /// Emit jump instruction.
    pub fn emitJump(self: *Self, dest: Block) !void {
        try self.builder.jump(dest);
    }

    /// Emit return instruction.
    pub fn emitReturn(self: *Self) !void {
        try self.builder.ret();
    }
};

/// Build IR from frontend representation.
///
/// This is the entry point for converting frontend AST or other
/// representation to Cranelift IR. Currently a placeholder that
/// demonstrates the IR building infrastructure.
pub fn buildIR(allocator: std.mem.Allocator, func: *Function) CodegenError!void {
    var ir_builder = IRBuilder.init(allocator, func);

    // Create entry block
    const entry = ir_builder.createBlock() catch return error.IRBuildFailed;
    ir_builder.appendBlock(entry) catch return error.IRBuildFailed;
    ir_builder.switchToBlock(entry);

    // TODO: Convert frontend AST/input to IR instructions
    // For now, just emit a return instruction
    ir_builder.emitReturn() catch return error.IRBuildFailed;
}

/// Legalize IR for target.
fn legalize(ctx: *Context) CodegenError!void {
    const TypeLegalizer = @import("legalize_types.zig").TypeLegalizer;
    const OpLegalizer = @import("legalize_ops.zig").OpLegalizer;

    // Create type legalizer (TODO: make target-specific)
    const type_legalizer = TypeLegalizer.default64();

    // Create operation legalizer (TODO: make target-specific)
    const op_legalizer = OpLegalizer.default64();

    // Iterate over all values in the function
    var value_iter = ctx.func.dfg.values.iterator();
    while (value_iter.next()) |entry| {
        const value = entry.key;
        const value_type = ctx.func.dfg.valueType(value) orelse continue;

        // Check if type needs legalization
        const type_action = type_legalizer.legalize(value_type);
        switch (type_action.action) {
            .legal => {}, // No action needed
            .promote => {
                // TODO: Widen narrow types to legal width
            },
            .expand => {
                // TODO: Split wide types into multiple operations
            },
            .split_vector, .widen_vector => {
                // TODO: Legalize vector types
            },
        }
    }

    // Iterate over all instructions
    var block_iter = ctx.func.layout.blockIter();
    while (block_iter.next()) |block| {
        var inst_iter = ctx.func.layout.blockInsts(block);
        while (inst_iter.next()) |inst| {
            const inst_data = ctx.func.dfg.insts.get(inst) orelse continue;

            // Check if operation needs legalization based on opcode
            // TODO: Map instruction data to operation type and check legalization
            _ = inst_data;
            _ = op_legalizer;
        }
    }

    // Note: Full legalization will expand illegal operations and insert
    // new instructions. For now, this is a framework that will be
    // expanded as the IR instruction set is finalized.
}

/// Lower IR to VCode via ISLE.
fn lower(ctx: *Context, target: *const Target) CodegenError!void {
    // Determine instruction type based on target architecture
    switch (target.arch) {
        .aarch64 => try lowerAArch64(ctx),
        .x86_64 => try lowerX86_64(ctx),
    }
}

/// Lower IR to AArch64 VCode.
fn lowerAArch64(ctx: *Context) CodegenError!void {
    const Inst = @import("../backends/aarch64/inst.zig").Inst;
    const VCodeBuilder = @import("../machinst/vcode_builder.zig").VCodeBuilder;

    // Create VCode builder
    var builder = VCodeBuilder(Inst).init(ctx.allocator, .forward);
    defer builder.deinit();

    // Lower each block
    var block_iter = ctx.func.layout.blockIter();
    var first_block = true;
    while (block_iter.next()) |block| {
        // Start VCode block
        const vcode_block = try builder.startBlock(&.{});
        if (first_block) {
            builder.setEntry(vcode_block);

            // For entry block, emit moves from ABI registers to parameter vregs
            const VReg = @import("../machinst/reg.zig").VReg;
            const PReg = @import("../machinst/reg.zig").PReg;
            const Reg = @import("../machinst/reg.zig").Reg;
            const WritableReg = @import("../machinst/reg.zig").WritableReg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const OperandSize = @import("../backends/aarch64/inst.zig").OperandSize;

            const block_data = ctx.func.dfg.blocks.get(block) orelse return error.LoweringFailed;
            const params = block_data.getParams(&ctx.func.dfg.value_lists);

            // Emit MOV from x0-x7 to parameter vregs
            for (params, 0..) |param, i| {
                if (i < 8) {
                    // Source: physical register x0-x7
                    const preg = PReg.new(RegClass.int, @intCast(i));
                    const src = Reg.fromPReg(preg);

                    // Destination: virtual register for this parameter
                    // Offset by PINNED_VREGS to avoid collision with physical registers
                    const param_vreg = VReg.new(@intCast(param.index + Reg.PINNED_VREGS), RegClass.int);
                    const dst = WritableReg.fromVReg(param_vreg);

                    // Get parameter type to determine size
                    const param_type = ctx.func.dfg.valueType(param) orelse return error.LoweringFailed;
                    const size: OperandSize = if (param_type.bits() == 64)
                        .size64
                    else
                        .size32;

                    // Emit: MOV dst, src
                    try builder.emit(Inst{
                        .mov_rr = .{
                            .dst = dst,
                            .src = src,
                            .size = size,
                        },
                    });
                } else {
                    return error.LoweringFailed;
                }
            }

            first_block = false;
        }

        // Lower each instruction in block
        var inst_iter = ctx.func.layout.blockInsts(block);
        while (inst_iter.next()) |inst| {
            try lowerInstructionAArch64(ctx, &builder, inst);
        }

        // Finish block (no successors tracked yet)
        try builder.finishBlock(&.{});
    }

    // Finish building VCode
    var vcode = try builder.finish();
    defer vcode.deinit();

    // Allocate registers using trivial allocator
    const TrivialAllocator = @import("../regalloc/trivial.zig").TrivialAllocator;
    const inst_mod = @import("../backends/aarch64/inst.zig");
    const OperandCollector = inst_mod.OperandCollector;

    var allocator = TrivialAllocator.init(ctx.allocator);
    defer allocator.deinit();

    // Walk instructions and allocate registers for all vregs
    for (vcode.insns.items) |*inst| {
        var collector = OperandCollector.init(ctx.allocator);
        defer collector.deinit();

        try inst.getOperands(&collector);

        // Allocate registers for all def operands
        for (collector.defs.items) |def_reg| {
            const vreg = def_reg.toReg().toVReg() orelse continue;
            _ = allocator.allocate(vreg) catch {
                return CodegenError.RegisterAllocationFailed;
            };
        }

        // Allocate registers for all use operands (should already be allocated)
        for (collector.uses.items) |use_reg| {
            const vreg = use_reg.toVReg() orelse continue;
            _ = allocator.allocate(vreg) catch {
                return CodegenError.RegisterAllocationFailed;
            };
        }
    }

    // Emit machine code with register allocation
    try emitAArch64WithAllocation(ctx, &vcode, &allocator);
}

/// Emit AArch64 machine code with register allocation applied.
fn emitAArch64WithAllocation(ctx: *Context, vcode: anytype, allocator: anytype) CodegenError!void {
    const emit_mod = @import("../backends/aarch64/emit.zig");
    const buffer_mod = @import("../machinst/buffer.zig");
    const Reg = @import("../machinst/reg.zig").Reg;
    const WritableReg = @import("../machinst/reg.zig").WritableReg;
    const context_mod = @import("context.zig");

    // Create machine code buffer
    var buffer = buffer_mod.MachBuffer.init(ctx.allocator);
    defer buffer.deinit();

    // Emit each instruction with vregs rewritten to pregs
    for (vcode.insns.items) |inst| {
        var rewritten_inst = inst;

        // Rewrite virtual registers to physical registers
        switch (rewritten_inst) {
            .mov_imm => |*i| {
                if (i.dst.toReg().toVReg()) |vreg| {
                    if (allocator.getAllocation(vreg)) |preg| {
                        i.dst = WritableReg.fromReg(Reg.fromPReg(preg));
                    }
                }
            },
            .add_rr => |*i| {
                if (i.dst.toReg().toVReg()) |vreg| {
                    if (allocator.getAllocation(vreg)) |preg| {
                        i.dst = WritableReg.fromReg(Reg.fromPReg(preg));
                    }
                }
                if (i.src1.toVReg()) |vreg| {
                    if (allocator.getAllocation(vreg)) |preg| {
                        i.src1 = Reg.fromPReg(preg);
                    }
                }
                if (i.src2.toVReg()) |vreg| {
                    if (allocator.getAllocation(vreg)) |preg| {
                        i.src2 = Reg.fromPReg(preg);
                    }
                }
            },
            .mov_rr => |*i| {
                if (i.dst.toReg().toVReg()) |vreg| {
                    if (allocator.getAllocation(vreg)) |preg| {
                        i.dst = WritableReg.fromReg(Reg.fromPReg(preg));
                    }
                }
                if (i.src.toVReg()) |vreg| {
                    if (allocator.getAllocation(vreg)) |preg| {
                        i.src = Reg.fromPReg(preg);
                    }
                }
            },
            .mul_rr => |*i| {
                if (i.dst.toReg().toVReg()) |vreg| {
                    if (allocator.getAllocation(vreg)) |preg| {
                        i.dst = WritableReg.fromReg(Reg.fromPReg(preg));
                    }
                }
                if (i.src1.toVReg()) |vreg| {
                    if (allocator.getAllocation(vreg)) |preg| {
                        i.src1 = Reg.fromPReg(preg);
                    }
                }
                if (i.src2.toVReg()) |vreg| {
                    if (allocator.getAllocation(vreg)) |preg| {
                        i.src2 = Reg.fromPReg(preg);
                    }
                }
            },
            .ret => {
                // No registers to rewrite
            },
            else => {
                // Other instructions - no rewriting needed for now
                // TODO: Add register rewriting for all instruction variants
            },
        }

        // MVP: Emit supported instructions
        switch (rewritten_inst) {
            .mov_imm => |i| try emit_mod.emitMovImm(i.dst.toReg(), i.imm, i.size, &buffer),
            .mov_rr => |i| {
                // Skip redundant mov when src == dst (both are physical registers after rewriting)
                const dst_reg = i.dst.toReg();
                const src_reg = i.src;
                if (dst_reg.toRealReg()) |dst_real| {
                    if (src_reg.toRealReg()) |src_real| {
                        if (dst_real.hwEnc() == src_real.hwEnc()) {
                            // Redundant mov - skip it
                            continue;
                        }
                    }
                }
                try emit_mod.emitMovRR(dst_reg, src_reg, i.size, &buffer);
            },
            .add_rr => |i| try emit_mod.emitAddRR(i.dst.toReg(), i.src1, i.src2, i.size, &buffer),
            .mul_rr => |i| try emit_mod.emitMulRR(i.dst.toReg(), i.src1, i.src2, i.size, &buffer),
            .ret => try emit_mod.emitRet(null, &buffer),
            .nop => {}, // Skip NOPs
            else => return CodegenError.EmissionFailed, // Unsupported instruction for MVP
        }
    }

    // Store compiled code in context
    var compiled = context_mod.CompiledCode.init(ctx.allocator);

    // Transfer buffer data to compiled code
    try compiled.code.appendSlice(ctx.allocator, buffer.data.items);

    // Transfer relocations (convert MachReloc to Relocation)
    for (buffer.relocs.items) |mach_reloc| {
        const reloc_kind: context_mod.RelocKind = switch (mach_reloc.kind) {
            .abs8, .aarch64_abs64 => .abs8,
            .x86_pc_rel_32 => .pcrel4,
            .aarch64_adr_prel_pg_hi21 => .aarch64_adr_prel_pg_hi21,
            .aarch64_add_abs_lo12_nc => .aarch64_add_abs_lo12_nc,
            else => .abs8, // Default fallback
        };

        try compiled.relocs.append(ctx.allocator, .{
            .offset = mach_reloc.offset,
            .kind = reloc_kind,
            .name = mach_reloc.name,
            .addend = mach_reloc.addend,
        });
    }

    ctx.compiled_code = compiled;
}

/// Lower a single AArch64 instruction.
fn lowerInstructionAArch64(ctx: *Context, builder: anytype, inst: ir.Inst) CodegenError!void {
    const Inst = @import("../backends/aarch64/inst.zig").Inst;
    const OperandSize = @import("../backends/aarch64/inst.zig").OperandSize;

    // Get instruction data from DFG
    const inst_data_ptr = ctx.func.dfg.insts.get(inst) orelse {
        // No instruction data - emit NOP
        try builder.emit(Inst.nop);
        return;
    };

    // Match instruction opcode and lower accordingly
    switch (inst_data_ptr.*) {
        .unary_imm => |data| {
            // Handle unary_imm instructions (iconst)
            if (data.opcode != .iconst) {
                try builder.emit(Inst.nop);
                return;
            }
            // Load immediate constant into a virtual register
            const VReg = @import("../machinst/reg.zig").VReg;
            const WritableReg = @import("../machinst/reg.zig").WritableReg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const Reg = @import("../machinst/reg.zig").Reg;

            // Allocate virtual register for result
            // Offset by PINNED_VREGS to avoid collision with physical registers
            const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
            const vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
            const writable = WritableReg.fromVReg(vreg);

            // Get immediate value and size from instruction type
            const value_type = ctx.func.dfg.valueType(result_value) orelse {
                try builder.emit(Inst.nop);
                return;
            };

            const size: OperandSize = if (value_type.bits() == 64)
                .size64
            else
                .size32;

            // Get actual immediate value from instruction
            const imm_value = data.imm.bits();

            // Emit MOV immediate instruction
            try builder.emit(Inst{
                .mov_imm = .{
                    .dst = writable,
                    .imm = @bitCast(imm_value),
                    .size = size,
                },
            });
        },
        .nullary => |data| {
            // Handle nullary instructions (trap, debugtrap, nop, etc.)
            if (data.opcode == .trap) {
                // Unconditional trap - BRK with trap code as immediate
                const trap_code = if (@hasField(@TypeOf(data), "trap_code"))
                    data.trap_code.toRaw()
                else
                    0; // Default trap code
                try builder.emit(Inst{
                    .brk = .{ .imm = trap_code },
                });
            } else if (data.opcode == .debugtrap) {
                // Debug trap - BRK #0xF000 (debugger-specific)
                try builder.emit(Inst{
                    .brk = .{ .imm = 0xF000 },
                });
            } else {
                try builder.emit(Inst.nop);
            }
        },
        .binary => |data| {
            // Handle binary instructions (iadd, isub, etc.)
            if (data.opcode == .iadd) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                // Map IR values to virtual registers
                // Offset by PINNED_VREGS to avoid collision with physical registers
                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                // Get size from result type
                const value_type = ctx.func.dfg.valueType(ctx.func.dfg.firstResult(inst).?) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: OperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                // Emit ADD instruction
                try builder.emit(Inst{
                    .add_rr = .{
                        .dst = dst,
                        .src1 = src1,
                        .src2 = src2,
                        .size = size,
                    },
                });
            } else if (data.opcode == .isub) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: OperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                try builder.emit(Inst{
                    .sub_rr = .{
                        .dst = dst,
                        .src1 = src1,
                        .src2 = src2,
                        .size = size,
                    },
                });
            } else if (data.opcode == .isub) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: OperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                try builder.emit(Inst{
                    .sub_rr = .{
                        .dst = dst,
                        .src1 = src1,
                        .src2 = src2,
                        .size = size,
                    },
                });
            } else if (data.opcode == .imul) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                // Map IR values to virtual registers
                // Offset by PINNED_VREGS to avoid collision with physical registers
                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                // Get size from result type
                const value_type = ctx.func.dfg.valueType(ctx.func.dfg.firstResult(inst).?) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: OperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                // Emit MUL instruction
                try builder.emit(Inst{
                    .mul_rr = .{
                        .dst = dst,
                        .src1 = src1,
                        .src2 = src2,
                        .size = size,
                    },
                });
            } else if (data.opcode == .smulhi or data.opcode == .umulhi) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                if (data.opcode == .smulhi) {
                    try builder.emit(Inst{
                        .smulh = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                        },
                    });
                } else {
                    try builder.emit(Inst{
                        .umulh = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                        },
                    });
                }
            } else if (data.opcode == .sdiv or data.opcode == .udiv) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: OperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                // Emit SDIV or UDIV instruction
                if (data.opcode == .sdiv) {
                    try builder.emit(Inst{
                        .sdiv = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else {
                    try builder.emit(Inst{
                        .udiv = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .ishl or data.opcode == .ushr or data.opcode == .sshr) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: OperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                // Emit shift instruction
                // TODO: Optimize to use immediate form when shift amount is constant
                if (data.opcode == .ishl) {
                    try builder.emit(Inst{
                        .lsl_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else if (data.opcode == .ushr) {
                    try builder.emit(Inst{
                        .lsr_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else {
                    // sshr - arithmetic shift right
                    try builder.emit(Inst{
                        .asr_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .rotr or data.opcode == .rotl) {
                // Rotate operations
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                if (data.opcode == .rotr) {
                    // Rotate right - direct instruction
                    try builder.emit(Inst{
                        .ror_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else {
                    // Rotate left: rotl(x, n) = rotr(x, bitwidth - n)
                    // Need to compute (bitwidth - shift_amount)
                    // For now, emit NEG + ROR sequence
                    const temp_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                    const temp = Reg.fromVReg(temp_vreg);
                    const temp_writable = WritableReg.fromVReg(temp_vreg);

                    // NEG shift amount
                    try builder.emit(Inst{
                        .neg = .{ .dst = temp_writable, .src = src2, .size = size },
                    });

                    // ROR with negated shift
                    try builder.emit(Inst{
                        .ror_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = temp,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .srem or data.opcode == .urem) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);

                const dividend = Reg.fromVReg(arg0_vreg);
                const divisor = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: OperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                // Remainder requires two instructions:
                // quotient = SDIV/UDIV dividend, divisor
                // remainder = MSUB quotient, divisor, dividend  (dividend - quotient * divisor)

                // Allocate temporary vreg for quotient
                // Use a high vreg number to avoid collision (result + 1)
                const temp_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                const quotient = Reg.fromVReg(temp_vreg);
                const quotient_writable = WritableReg.fromVReg(temp_vreg);

                // Emit division to get quotient
                if (data.opcode == .srem) {
                    try builder.emit(Inst{
                        .sdiv = .{
                            .dst = quotient_writable,
                            .src1 = dividend,
                            .src2 = divisor,
                            .size = size,
                        },
                    });
                } else {
                    try builder.emit(Inst{
                        .udiv = .{
                            .dst = quotient_writable,
                            .src1 = dividend,
                            .src2 = divisor,
                            .size = size,
                        },
                    });
                }

                // Emit MSUB to get remainder: dividend - quotient * divisor
                try builder.emit(Inst{
                    .msub = .{
                        .dst = dst,
                        .src1 = quotient,
                        .src2 = divisor,
                        .minuend = dividend,
                        .size = size,
                    },
                });
            } else if (data.opcode == .band or data.opcode == .bor or data.opcode == .bxor) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: OperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                // Emit bitwise instruction
                // TODO: Optimize to use immediate form when operand is constant
                if (data.opcode == .band) {
                    try builder.emit(Inst{
                        .and_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else if (data.opcode == .bor) {
                    try builder.emit(Inst{
                        .orr_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else {
                    // bxor
                    try builder.emit(Inst{
                        .eor_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .band_not or data.opcode == .bor_not or data.opcode == .bxor_not) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);

                if (data.opcode == .band_not) {
                    try builder.emit(Inst{
                        .bic_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else if (data.opcode == .bor_not) {
                    try builder.emit(Inst{
                        .orn_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else {
                    try builder.emit(Inst{
                        .eon_rr = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .fadd or data.opcode == .fsub or data.opcode == .fmul or data.opcode == .fdiv) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.float);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.float);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.float);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: FpuOperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                if (data.opcode == .fadd) {
                    try builder.emit(Inst{
                        .fadd = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else if (data.opcode == .fsub) {
                    try builder.emit(Inst{
                        .fsub = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else if (data.opcode == .fmul) {
                    try builder.emit(Inst{
                        .fmul = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else {
                    // fdiv
                    try builder.emit(Inst{
                        .fdiv = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .fmin or data.opcode == .fmax) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.float);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.float);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.float);

                const src1 = Reg.fromVReg(arg0_vreg);
                const src2 = Reg.fromVReg(arg1_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: FpuOperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                if (data.opcode == .fmin) {
                    try builder.emit(Inst{
                        .fmin = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                } else {
                    try builder.emit(Inst{
                        .fmax = .{
                            .dst = dst,
                            .src1 = src1,
                            .src2 = src2,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .fcopysign) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                const mag_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.float);
                const sign_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.float);
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.float);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: FpuOperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const abs_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.float);
                const neg_abs_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 2), RegClass.float);
                const zero_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 3), RegClass.float);

                try builder.emit(Inst{
                    .fabs = .{
                        .dst = WritableReg.fromVReg(abs_vreg),
                        .src = Reg.fromVReg(mag_vreg),
                        .size = size,
                    },
                });

                try builder.emit(Inst{
                    .fneg = .{
                        .dst = WritableReg.fromVReg(neg_abs_vreg),
                        .src = Reg.fromVReg(abs_vreg),
                        .size = size,
                    },
                });

                try builder.emit(Inst{
                    .fmov_imm = .{
                        .dst = WritableReg.fromVReg(zero_vreg),
                        .imm = 0.0,
                        .size = size,
                    },
                });

                try builder.emit(Inst{
                    .fcmp = .{
                        .src1 = Reg.fromVReg(sign_vreg),
                        .src2 = Reg.fromVReg(zero_vreg),
                        .size = size,
                    },
                });

                try builder.emit(Inst{
                    .fcsel = .{
                        .dst = WritableReg.fromVReg(result_vreg),
                        .src1 = Reg.fromVReg(neg_abs_vreg),
                        .src2 = Reg.fromVReg(abs_vreg),
                        .cond = CondCode.mi,
                        .size = size,
                    },
                });
            } else {
                // Other binary ops not yet implemented
                try builder.emit(Inst.nop);
            }
        },
        .ternary => |data| {
            if (data.opcode == .select) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const PReg = @import("../machinst/reg.zig").PReg;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                const cond_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const true_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const false_vreg = VReg.new(@intCast(data.args[2].index + Reg.PINNED_VREGS), RegClass.int);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const zero = Reg.fromPReg(PReg.new(RegClass.int, 31));

                try builder.emit(Inst{
                    .cmp_rr = .{
                        .src1 = Reg.fromVReg(cond_vreg),
                        .src2 = zero,
                        .size = .size32,
                    },
                });

                try builder.emit(Inst{
                    .csel = .{
                        .dst = dst,
                        .src1 = Reg.fromVReg(true_vreg),
                        .src2 = Reg.fromVReg(false_vreg),
                        .cond = CondCode.ne,
                        .size = size,
                    },
                });
            } else if (data.opcode == .smin or data.opcode == .smax or data.opcode == .umin or data.opcode == .umax) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                try builder.emit(Inst{
                    .cmp_rr = .{
                        .src1 = Reg.fromVReg(arg0_vreg),
                        .src2 = Reg.fromVReg(arg1_vreg),
                        .size = size,
                    },
                });

                const cond: CondCode = switch (data.opcode) {
                    .smin => .lt,
                    .smax => .gt,
                    .umin => .cc,
                    .umax => .hi,
                    else => unreachable,
                };

                try builder.emit(Inst{
                    .csel = .{
                        .dst = dst,
                        .src1 = Reg.fromVReg(arg0_vreg),
                        .src2 = Reg.fromVReg(arg1_vreg),
                        .cond = cond,
                        .size = size,
                    },
                });
            } else if (data.opcode == .uadd_overflow or data.opcode == .sadd_overflow) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                const x_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const y_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);

                const results = ctx.func.dfg.instResults(inst);
                if (results.len != 2) return error.LoweringFailed;

                const sum_vreg = VReg.new(@intCast(results[0].index + Reg.PINNED_VREGS), RegClass.int);
                const overflow_vreg = VReg.new(@intCast(results[1].index + Reg.PINNED_VREGS), RegClass.int);

                const value_type = ctx.func.dfg.valueType(results[0]) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                try builder.emit(Inst{
                    .adds_rr = .{
                        .dst = WritableReg.fromVReg(sum_vreg),
                        .src1 = Reg.fromVReg(x_vreg),
                        .src2 = Reg.fromVReg(y_vreg),
                        .size = size,
                    },
                });

                const cond: CondCode = if (data.opcode == .sadd_overflow) .vs else .cs;
                try builder.emit(Inst{
                    .cset = .{
                        .dst = WritableReg.fromVReg(overflow_vreg),
                        .cond = cond,
                        .size = .size32,
                    },
                });
            } else if (data.opcode == .usub_overflow or data.opcode == .ssub_overflow) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                const x_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const y_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);

                const results = ctx.func.dfg.instResults(inst);
                if (results.len != 2) return error.LoweringFailed;

                const diff_vreg = VReg.new(@intCast(results[0].index + Reg.PINNED_VREGS), RegClass.int);
                const overflow_vreg = VReg.new(@intCast(results[1].index + Reg.PINNED_VREGS), RegClass.int);

                const value_type = ctx.func.dfg.valueType(results[0]) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                try builder.emit(Inst{
                    .subs_rr = .{
                        .dst = WritableReg.fromVReg(diff_vreg),
                        .src1 = Reg.fromVReg(x_vreg),
                        .src2 = Reg.fromVReg(y_vreg),
                        .size = size,
                    },
                });

                const cond: CondCode = if (data.opcode == .ssub_overflow) .vs else .cc;
                try builder.emit(Inst{
                    .cset = .{
                        .dst = WritableReg.fromVReg(overflow_vreg),
                        .cond = cond,
                        .size = .size32,
                    },
                });
            } else if (data.opcode == .umul_overflow or data.opcode == .smul_overflow) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                const x_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const y_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);

                const results = ctx.func.dfg.instResults(inst);
                if (results.len != 2) return error.LoweringFailed;

                const prod_vreg = VReg.new(@intCast(results[0].index + Reg.PINNED_VREGS), RegClass.int);
                const overflow_vreg = VReg.new(@intCast(results[1].index + Reg.PINNED_VREGS), RegClass.int);

                const value_type = ctx.func.dfg.valueType(results[0]) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                if (size != .size64) return error.LoweringFailed;

                try builder.emit(Inst{
                    .mul_rr = .{
                        .dst = WritableReg.fromVReg(prod_vreg),
                        .src1 = Reg.fromVReg(x_vreg),
                        .src2 = Reg.fromVReg(y_vreg),
                        .size = size,
                    },
                });

                const high_vreg = VReg.new(@intCast(results[0].index + Reg.PINNED_VREGS + 1), RegClass.int);

                if (data.opcode == .umul_overflow) {
                    try builder.emit(Inst{
                        .umulh = .{
                            .dst = WritableReg.fromVReg(high_vreg),
                            .src1 = Reg.fromVReg(x_vreg),
                            .src2 = Reg.fromVReg(y_vreg),
                        },
                    });

                    try builder.emit(Inst{
                        .cmp_imm = .{
                            .src = Reg.fromVReg(high_vreg),
                            .imm = .{ .bits = 0, .shift12 = false },
                        },
                    });

                    try builder.emit(Inst{
                        .cset = .{
                            .dst = WritableReg.fromVReg(overflow_vreg),
                            .cond = CondCode.ne,
                            .size = .size32,
                        },
                    });
                } else {
                    try builder.emit(Inst{
                        .smulh = .{
                            .dst = WritableReg.fromVReg(high_vreg),
                            .src1 = Reg.fromVReg(x_vreg),
                            .src2 = Reg.fromVReg(y_vreg),
                        },
                    });

                    const temp_vreg = VReg.new(@intCast(results[0].index + Reg.PINNED_VREGS + 2), RegClass.int);

                    try builder.emit(Inst{
                        .asr_imm = .{
                            .dst = WritableReg.fromVReg(temp_vreg),
                            .src = Reg.fromVReg(prod_vreg),
                            .imm = 63,
                            .size = .size64,
                        },
                    });

                    try builder.emit(Inst{
                        .cmp_rr = .{
                            .src1 = Reg.fromVReg(high_vreg),
                            .src2 = Reg.fromVReg(temp_vreg),
                            .size = .size64,
                        },
                    });

                    try builder.emit(Inst{
                        .cset = .{
                            .dst = WritableReg.fromVReg(overflow_vreg),
                            .cond = CondCode.ne,
                            .size = .size32,
                        },
                    });
                }
            } else if (data.opcode == .sadd_sat or data.opcode == .ssub_sat or data.opcode == .uadd_sat or data.opcode == .usub_sat) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                if (data.opcode == .sadd_sat) {
                    try builder.emit(Inst{
                        .sqadd = .{
                            .dst = dst,
                            .src1 = Reg.fromVReg(arg0_vreg),
                            .src2 = Reg.fromVReg(arg1_vreg),
                            .size = size,
                        },
                    });
                } else if (data.opcode == .ssub_sat) {
                    try builder.emit(Inst{
                        .sqsub = .{
                            .dst = dst,
                            .src1 = Reg.fromVReg(arg0_vreg),
                            .src2 = Reg.fromVReg(arg1_vreg),
                            .size = size,
                        },
                    });
                } else if (data.opcode == .uadd_sat) {
                    try builder.emit(Inst{
                        .uqadd = .{
                            .dst = dst,
                            .src1 = Reg.fromVReg(arg0_vreg),
                            .src2 = Reg.fromVReg(arg1_vreg),
                            .size = size,
                        },
                    });
                } else if (data.opcode == .usub_sat) {
                    try builder.emit(Inst{
                        .uqsub = .{
                            .dst = dst,
                            .src1 = Reg.fromVReg(arg0_vreg),
                            .src2 = Reg.fromVReg(arg1_vreg),
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .fma) {
                // Fused multiply-add: result = args[0] * args[1] + args[2]
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

                const src1_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.float);
                const src2_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.float);
                const addend_vreg = VReg.new(@intCast(data.args[2].index + Reg.PINNED_VREGS), RegClass.float);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.float);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: FpuOperandSize = if (value_type.bits() == 64) .size64 else .size32;

                try builder.emit(Inst{
                    .fmadd = .{
                        .dst = dst,
                        .src1 = Reg.fromVReg(src1_vreg),
                        .src2 = Reg.fromVReg(src2_vreg),
                        .addend = Reg.fromVReg(addend_vreg),
                        .size = size,
                    },
                });
            } else if (data.opcode == .sadd_overflow_cin) {
                // Add with carry in and overflow out: (sum, c_out) = x + y + c_in
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const PReg = @import("../machinst/reg.zig").PReg;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                // Get inputs: x, y, c_in
                const x_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const y_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const c_in_vreg = VReg.new(@intCast(data.args[2].index + Reg.PINNED_VREGS), RegClass.int);

                // Get outputs: sum, c_out
                const results = ctx.func.dfg.instResults(inst);
                if (results.len != 2) return error.LoweringFailed;

                const sum_vreg = VReg.new(@intCast(results[0].index + Reg.PINNED_VREGS), RegClass.int);
                const c_out_vreg = VReg.new(@intCast(results[1].index + Reg.PINNED_VREGS), RegClass.int);

                const value_type = ctx.func.dfg.valueType(results[0]) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                // Set carry flag from c_in: SUBS xzr, c_in, #1
                // This sets C = (c_in >= 1) = (c_in != 0)
                const xzr = Reg.fromPReg(PReg.new(RegClass.int, 31));
                const xzr_writable = WritableReg.fromReg(xzr);
                try builder.emit(Inst{
                    .subs_imm = .{
                        .dst = xzr_writable,
                        .src = Reg.fromVReg(c_in_vreg),
                        .imm = 1,
                        .size = .size32,
                    },
                });

                // ADCS: sum = x + y + carry
                try builder.emit(Inst{
                    .adcs = .{
                        .dst = WritableReg.fromVReg(sum_vreg),
                        .src1 = Reg.fromVReg(x_vreg),
                        .src2 = Reg.fromVReg(y_vreg),
                        .size = size,
                    },
                });

                // Extract carry flag to c_out
                try builder.emit(Inst{
                    .cset = .{
                        .dst = WritableReg.fromVReg(c_out_vreg),
                        .cond = CondCode.cs, // carry set
                        .size = .size32,
                    },
                });
            } else if (data.opcode == .uadd_overflow_cin) {
                // Add with carry in (unsigned): (sum, c_out) = x + y + c_in
                // Identical lowering to sadd_overflow_cin (ADCS works for both signed/unsigned)
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const PReg = @import("../machinst/reg.zig").PReg;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                const x_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const y_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const c_in_vreg = VReg.new(@intCast(data.args[2].index + Reg.PINNED_VREGS), RegClass.int);

                const results = ctx.func.dfg.instResults(inst);
                if (results.len != 2) return error.LoweringFailed;

                const sum_vreg = VReg.new(@intCast(results[0].index + Reg.PINNED_VREGS), RegClass.int);
                const c_out_vreg = VReg.new(@intCast(results[1].index + Reg.PINNED_VREGS), RegClass.int);

                const value_type = ctx.func.dfg.valueType(results[0]) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const xzr = Reg.fromPReg(PReg.new(RegClass.int, 31));
                const xzr_writable = WritableReg.fromReg(xzr);
                try builder.emit(Inst{
                    .subs_imm = .{
                        .dst = xzr_writable,
                        .src = Reg.fromVReg(c_in_vreg),
                        .imm = 1,
                        .size = .size32,
                    },
                });

                try builder.emit(Inst{
                    .adcs = .{
                        .dst = WritableReg.fromVReg(sum_vreg),
                        .src1 = Reg.fromVReg(x_vreg),
                        .src2 = Reg.fromVReg(y_vreg),
                        .size = size,
                    },
                });

                try builder.emit(Inst{
                    .cset = .{
                        .dst = WritableReg.fromVReg(c_out_vreg),
                        .cond = CondCode.cs,
                        .size = .size32,
                    },
                });
            } else if (data.opcode == .ssub_overflow_bin) {
                // Subtract with borrow in (signed): (diff, b_out) = x - y - b_in
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const PReg = @import("../machinst/reg.zig").PReg;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                const x_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const y_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const b_in_vreg = VReg.new(@intCast(data.args[2].index + Reg.PINNED_VREGS), RegClass.int);

                const results = ctx.func.dfg.instResults(inst);
                if (results.len != 2) return error.LoweringFailed;

                const diff_vreg = VReg.new(@intCast(results[0].index + Reg.PINNED_VREGS), RegClass.int);
                const b_out_vreg = VReg.new(@intCast(results[1].index + Reg.PINNED_VREGS), RegClass.int);

                const value_type = ctx.func.dfg.valueType(results[0]) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                // Set carry flag: SUBS xzr, xzr, b_in
                // C = (0 >= b_in) = NOT(b_in) for ARM64 borrow semantics
                const xzr = Reg.fromPReg(PReg.new(RegClass.int, 31));
                const xzr_writable = WritableReg.fromReg(xzr);
                try builder.emit(Inst{
                    .subs_rr = .{
                        .dst = xzr_writable,
                        .src1 = xzr,
                        .src2 = Reg.fromVReg(b_in_vreg),
                        .size = .size32,
                    },
                });

                // SBCS: diff = x - y - NOT(C)
                try builder.emit(Inst{
                    .sbcs = .{
                        .dst = WritableReg.fromVReg(diff_vreg),
                        .src1 = Reg.fromVReg(x_vreg),
                        .src2 = Reg.fromVReg(y_vreg),
                        .size = size,
                    },
                });

                // Extract borrow flag: b_out = NOT(C) = C is clear
                try builder.emit(Inst{
                    .cset = .{
                        .dst = WritableReg.fromVReg(b_out_vreg),
                        .cond = CondCode.cc, // carry clear (borrow)
                        .size = .size32,
                    },
                });
            } else if (data.opcode == .usub_overflow_bin) {
                // Subtract with borrow in (unsigned): (diff, b_out) = x - y - b_in
                // Identical lowering to ssub_overflow_bin (SBCS works for both signed/unsigned)
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const PReg = @import("../machinst/reg.zig").PReg;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                const x_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
                const y_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
                const b_in_vreg = VReg.new(@intCast(data.args[2].index + Reg.PINNED_VREGS), RegClass.int);

                const results = ctx.func.dfg.instResults(inst);
                if (results.len != 2) return error.LoweringFailed;

                const diff_vreg = VReg.new(@intCast(results[0].index + Reg.PINNED_VREGS), RegClass.int);
                const b_out_vreg = VReg.new(@intCast(results[1].index + Reg.PINNED_VREGS), RegClass.int);

                const value_type = ctx.func.dfg.valueType(results[0]) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const xzr = Reg.fromPReg(PReg.new(RegClass.int, 31));
                const xzr_writable = WritableReg.fromReg(xzr);
                try builder.emit(Inst{
                    .subs_rr = .{
                        .dst = xzr_writable,
                        .src1 = xzr,
                        .src2 = Reg.fromVReg(b_in_vreg),
                        .size = .size32,
                    },
                });

                try builder.emit(Inst{
                    .sbcs = .{
                        .dst = WritableReg.fromVReg(diff_vreg),
                        .src1 = Reg.fromVReg(x_vreg),
                        .src2 = Reg.fromVReg(y_vreg),
                        .size = size,
                    },
                });

                try builder.emit(Inst{
                    .cset = .{
                        .dst = WritableReg.fromVReg(b_out_vreg),
                        .cond = CondCode.cc,
                        .size = .size32,
                    },
                });
            } else {
                try builder.emit(Inst.nop);
            }
        },
        .binary_imm64 => |data| {
            if (data.opcode == .iadd_imm) {
                // Add immediate: result = arg + imm
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                // ARM64 ADD immediate supports 12-bit unsigned immediate
                const imm_val = data.imm.value;
                const imm_u16: u16 = @intCast(@mod(imm_val, 4096)); // Mask to 12 bits

                try builder.emit(Inst{
                    .add_imm = .{
                        .dst = dst,
                        .src = src,
                        .imm = imm_u16,
                        .size = size,
                    },
                });
            } else if (data.opcode == .irsub_imm) {
                // Reverse subtract immediate: result = imm - arg
                // Implement as: NEG dst, arg; ADD dst, dst, #imm
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                // NEG dst, src (dst = -src)
                try builder.emit(Inst{
                    .neg = .{
                        .dst = dst,
                        .src = src,
                        .size = size,
                    },
                });

                // ADD dst, dst, #imm (dst = -src + imm = imm - src)
                const imm_val = data.imm.value;
                const imm_u16: u16 = @intCast(@mod(imm_val, 4096));

                try builder.emit(Inst{
                    .add_imm = .{
                        .dst = dst,
                        .src = Reg.fromVReg(result_vreg),
                        .imm = imm_u16,
                        .size = size,
                    },
                });
            } else if (data.opcode == .imul_imm) {
                // Multiply immediate: result = arg * imm
                // Optimize power-of-2 to LSL, otherwise use MOVZ+MUL
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const imm_val: u64 = @bitCast(data.imm.value);

                // Check if power of 2 - optimize to left shift
                if (imm_val > 0 and (imm_val & (imm_val - 1)) == 0) {
                    const shift: u8 = @intCast(@ctz(imm_val));
                    try builder.emit(Inst{
                        .lsl_imm = .{
                            .dst = dst,
                            .src = src,
                            .imm = shift,
                            .size = size,
                        },
                    });
                } else {
                    // General case: MOV temp, #imm; MUL dst, src, temp
                    const temp_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                    const temp = WritableReg.fromVReg(temp_vreg);

                    // MOVZ temp, #imm (simplified - only handles lower 16 bits)
                    const imm_u16: u16 = @intCast(imm_val & 0xFFFF);
                    try builder.emit(Inst{
                        .movz = .{
                            .dst = temp,
                            .imm = imm_u16,
                            .shift = 0,
                            .size = size,
                        },
                    });

                    // MUL dst, src, temp
                    try builder.emit(Inst{
                        .mul_rr = .{
                            .dst = dst,
                            .src1 = src,
                            .src2 = Reg.fromVReg(temp_vreg),
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .ishl_imm) {
                // Left shift immediate: result = arg << imm
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const shift_amt: u8 = @intCast(data.imm.value & 63); // Mask to 6 bits

                try builder.emit(Inst{
                    .lsl_imm = .{
                        .dst = dst,
                        .src = src,
                        .imm = shift_amt,
                        .size = size,
                    },
                });
            } else if (data.opcode == .ushr_imm) {
                // Logical right shift immediate: result = arg >> imm (unsigned)
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const shift_amt: u8 = @intCast(data.imm.value & 63);

                try builder.emit(Inst{
                    .lsr_imm = .{
                        .dst = dst,
                        .src = src,
                        .imm = shift_amt,
                        .size = size,
                    },
                });
            } else if (data.opcode == .sshr_imm) {
                // Arithmetic right shift immediate: result = arg >> imm (signed)
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const shift_amt: u8 = @intCast(data.imm.value & 63);

                try builder.emit(Inst{
                    .asr_imm = .{
                        .dst = dst,
                        .src = src,
                        .imm = shift_amt,
                        .size = size,
                    },
                });
            } else if (data.opcode == .band_imm) {
                // Bitwise AND immediate: result = arg & imm
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const ImmLogic = @import("../backends/aarch64/inst.zig").ImmLogic;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const imm_val: u64 = @bitCast(data.imm.value);

                try builder.emit(Inst{
                    .and_imm = .{
                        .dst = dst,
                        .src = src,
                        .imm = ImmLogic{ .value = imm_val, .size = size },
                    },
                });
            } else if (data.opcode == .bor_imm) {
                // Bitwise OR immediate: result = arg | imm
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const ImmLogic = @import("../backends/aarch64/inst.zig").ImmLogic;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const imm_val: u64 = @bitCast(data.imm.value);

                try builder.emit(Inst{
                    .orr_imm = .{
                        .dst = dst,
                        .src = src,
                        .imm = ImmLogic{ .value = imm_val, .size = size },
                    },
                });
            } else if (data.opcode == .bxor_imm) {
                // Bitwise XOR immediate: result = arg ^ imm
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const ImmLogic = @import("../backends/aarch64/inst.zig").ImmLogic;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const imm_val: u64 = @bitCast(data.imm.value);

                try builder.emit(Inst{
                    .eor_imm = .{
                        .dst = dst,
                        .src = src,
                        .imm = ImmLogic{ .value = imm_val, .size = size },
                    },
                });
            } else if (data.opcode == .rotr_imm) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const shift_amt: u8 = @intCast(data.imm.value & 63);

                try builder.emit(Inst{
                    .ror_imm = .{
                        .dst = dst,
                        .src = src,
                        .imm = shift_amt,
                        .size = size,
                    },
                });
            } else if (data.opcode == .rotl_imm) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                // ARM64 has no ROL, compute as: rotr bitwidth - amt
                const bitwidth: u64 = if (size == .size64) 64 else 32;
                const shift_amt: u8 = @intCast(data.imm.value & 63);
                const ror_amt: u8 = @intCast((bitwidth - shift_amt) & 63);

                try builder.emit(Inst{
                    .ror_imm = .{
                        .dst = dst,
                        .src = src,
                        .imm = ror_amt,
                        .size = size,
                    },
                });
            } else if (data.opcode == .udiv_imm) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const imm_val = data.imm.value;

                if (imm_val > 0 and std.math.isPowerOfTwo(imm_val)) {
                    const shift_amt: u8 = @intCast(@ctz(imm_val));
                    try builder.emit(Inst{
                        .lsr_imm = .{
                            .dst = dst,
                            .src = src,
                            .imm = shift_amt,
                            .size = size,
                        },
                    });
                } else {
                    const temp_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                    const temp_reg = Reg.fromVReg(temp_vreg);
                    const temp_dst = WritableReg.fromVReg(temp_vreg);

                    try builder.emit(Inst{
                        .movz = .{
                            .dst = temp_dst,
                            .imm = @intCast(imm_val & 0xFFFF),
                            .shift = 0,
                            .size = size,
                        },
                    });

                    try builder.emit(Inst{
                        .udiv = .{
                            .dst = dst,
                            .src1 = src,
                            .src2 = temp_reg,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .urem_imm) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const imm_val = data.imm.value;

                if (imm_val > 0 and std.math.isPowerOfTwo(imm_val)) {
                    const mask: u64 = @intCast(imm_val - 1);
                    const ImmLogic = @import("../backends/aarch64/inst.zig").ImmLogic;
                    if (ImmLogic.maybeFromU64(mask, size)) |imm_logic| {
                        try builder.emit(Inst{
                            .and_imm = .{
                                .dst = dst,
                                .src = src,
                                .imm = imm_logic,
                            },
                        });
                    } else {
                        const temp_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                        const temp_reg = Reg.fromVReg(temp_vreg);
                        const temp_dst = WritableReg.fromVReg(temp_vreg);

                        try builder.emit(Inst{
                            .movz = .{
                                .dst = temp_dst,
                                .imm = @intCast(mask & 0xFFFF),
                                .shift = 0,
                                .size = size,
                            },
                        });

                        try builder.emit(Inst{
                            .and_rr = .{
                                .dst = dst,
                                .src1 = src,
                                .src2 = temp_reg,
                                .size = size,
                            },
                        });
                    }
                } else {
                    const divisor_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                    const divisor_reg = Reg.fromVReg(divisor_vreg);
                    const divisor_dst = WritableReg.fromVReg(divisor_vreg);

                    const quot_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 2), RegClass.int);
                    const quot_reg = Reg.fromVReg(quot_vreg);
                    const quot_dst = WritableReg.fromVReg(quot_vreg);

                    try builder.emit(Inst{
                        .movz = .{
                            .dst = divisor_dst,
                            .imm = @intCast(imm_val & 0xFFFF),
                            .shift = 0,
                            .size = size,
                        },
                    });

                    try builder.emit(Inst{
                        .udiv = .{
                            .dst = quot_dst,
                            .src1 = src,
                            .src2 = divisor_reg,
                            .size = size,
                        },
                    });

                    try builder.emit(Inst{
                        .msub = .{
                            .dst = dst,
                            .src1 = quot_reg,
                            .src2 = divisor_reg,
                            .minuend = src,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .sdiv_imm) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const imm_val = data.imm.value;

                if (imm_val > 0 and std.math.isPowerOfTwo(@as(u64, @intCast(imm_val)))) {
                    const shift_amt: u8 = @intCast(@ctz(@as(u64, @intCast(imm_val))));
                    const temp_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                    const temp_reg = Reg.fromVReg(temp_vreg);
                    const temp_dst = WritableReg.fromVReg(temp_vreg);
                    const bitwidth: u8 = if (size == .size64) 64 else 32;

                    try builder.emit(Inst{
                        .asr_imm = .{
                            .dst = temp_dst,
                            .src = src,
                            .imm = bitwidth - 1,
                            .size = size,
                        },
                    });

                    try builder.emit(Inst{
                        .lsr_imm = .{
                            .dst = temp_dst,
                            .src = temp_reg,
                            .imm = bitwidth - shift_amt,
                            .size = size,
                        },
                    });

                    try builder.emit(Inst{
                        .add_rr = .{
                            .dst = temp_dst,
                            .src1 = src,
                            .src2 = temp_reg,
                            .size = size,
                        },
                    });

                    try builder.emit(Inst{
                        .asr_imm = .{
                            .dst = dst,
                            .src = temp_reg,
                            .imm = shift_amt,
                            .size = size,
                        },
                    });
                } else {
                    const temp_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                    const temp_reg = Reg.fromVReg(temp_vreg);
                    const temp_dst = WritableReg.fromVReg(temp_vreg);

                    try builder.emit(Inst{
                        .movz = .{
                            .dst = temp_dst,
                            .imm = @intCast(@as(u64, @intCast(imm_val)) & 0xFFFF),
                            .shift = 0,
                            .size = size,
                        },
                    });

                    try builder.emit(Inst{
                        .sdiv = .{
                            .dst = dst,
                            .src1 = src,
                            .src2 = temp_reg,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .srem_imm) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const imm_val = data.imm.value;

                const divisor_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                const divisor_reg = Reg.fromVReg(divisor_vreg);
                const divisor_dst = WritableReg.fromVReg(divisor_vreg);

                const quot_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 2), RegClass.int);
                const quot_reg = Reg.fromVReg(quot_vreg);
                const quot_dst = WritableReg.fromVReg(quot_vreg);

                try builder.emit(Inst{
                    .movz = .{
                        .dst = divisor_dst,
                        .imm = @intCast(@as(u64, @intCast(imm_val)) & 0xFFFF),
                        .shift = 0,
                        .size = size,
                    },
                });

                try builder.emit(Inst{
                    .sdiv = .{
                        .dst = quot_dst,
                        .src1 = src,
                        .src2 = divisor_reg,
                        .size = size,
                    },
                });

                try builder.emit(Inst{
                    .msub = .{
                        .dst = dst,
                        .src1 = quot_reg,
                        .src2 = divisor_reg,
                        .minuend = src,
                        .size = size,
                    },
                });
            } else {
                try builder.emit(Inst.nop);
            }
        },
        .unary => |data| {
            // Handle unary instructions (return, etc.)
            if (data.opcode == .@"return") {
                const VReg = @import("../machinst/reg.zig").VReg;
                const PReg = @import("../machinst/reg.zig").PReg;
                const Reg = @import("../machinst/reg.zig").Reg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;

                // Map return value to vreg (will be rewritten to preg later)
                // Offset by PINNED_VREGS to avoid collision with physical registers
                const return_val_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(return_val_vreg);

                // Destination is PHYSICAL x0
                const x0_preg = PReg.new(RegClass.int, 0);
                const x0 = Reg.fromPReg(x0_preg);
                const dst = WritableReg.fromReg(x0);

                // Get size from return value type
                const value_type = ctx.func.dfg.valueType(data.arg) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: OperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                // Emit: MOV x0, return_val_vreg
                try builder.emit(Inst{
                    .mov_rr = .{
                        .dst = dst,
                        .src = src,
                        .size = size,
                    },
                });

                // Emit RET instruction
                try builder.emit(Inst.ret);
            } else if (data.opcode == .ireduce) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse {
                    try builder.emit(Inst.nop);
                    return;
                };

                const size: OperandSize = if (value_type.bits() == 64)
                    .size64
                else
                    .size32;

                // Emit MOV with target size (truncates via W vs X register)
                try builder.emit(Inst{
                    .mov_rr = .{
                        .dst = dst,
                        .src = src,
                        .size = size,
                    },
                });
            } else if (data.opcode == .sextend or data.opcode == .uextend) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const src_type = ctx.func.dfg.valueType(data.arg) orelse return error.LoweringFailed;
                const dst_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;

                const dst_size: OperandSize = if (dst_type.bits() == 64) .size64 else .size32;

                // Select instruction based on source type size
                const is_signed = data.opcode == .sextend;
                switch (src_type.bits()) {
                    8 => {
                        if (is_signed) {
                            try builder.emit(Inst{ .sxtb = .{ .dst = dst, .src = src, .dst_size = dst_size } });
                        } else {
                            try builder.emit(Inst{ .uxtb = .{ .dst = dst, .src = src, .dst_size = dst_size } });
                        }
                    },
                    16 => {
                        if (is_signed) {
                            try builder.emit(Inst{ .sxth = .{ .dst = dst, .src = src, .dst_size = dst_size } });
                        } else {
                            try builder.emit(Inst{ .uxth = .{ .dst = dst, .src = src, .dst_size = dst_size } });
                        }
                    },
                    32 => {
                        if (is_signed) {
                            try builder.emit(Inst{ .sxtw = .{ .dst = dst, .src = src } });
                        } else {
                            // For uextend i32→i64, just use 32-bit MOV (auto zero-extends)
                            try builder.emit(Inst{ .mov_rr = .{ .dst = dst, .src = src, .size = .size32 } });
                        }
                    },
                    else => return error.LoweringFailed,
                }
            } else if (data.opcode == .clz or data.opcode == .cls or data.opcode == .ctz or data.opcode == .popcnt) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                if (data.opcode == .clz) {
                    // Count leading zeros - direct instruction
                    try builder.emit(Inst{
                        .clz = .{ .dst = dst, .src = src, .size = size },
                    });
                } else if (data.opcode == .cls) {
                    // Count leading sign bits - direct instruction
                    try builder.emit(Inst{
                        .cls = .{ .dst = dst, .src = src, .size = size },
                    });
                } else if (data.opcode == .ctz) {
                    // Count trailing zeros: RBIT + CLZ
                    // Allocate temporary vreg for reversed bits
                    const temp_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                    const temp = Reg.fromVReg(temp_vreg);
                    const temp_writable = WritableReg.fromVReg(temp_vreg);

                    // Reverse bits
                    try builder.emit(Inst{
                        .rbit = .{ .dst = temp_writable, .src = src, .size = size },
                    });

                    // Count leading zeros of reversed value
                    try builder.emit(Inst{
                        .clz = .{ .dst = dst, .src = temp, .size = size },
                    });
                } else {
                    // popcnt - count set bits
                    try builder.emit(Inst{
                        .popcnt = .{ .dst = dst, .src = src, .size = size },
                    });
                }
            } else if (data.opcode == .bnot) {
                // Bitwise NOT
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                // MVN - bitwise NOT
                try builder.emit(Inst{
                    .mvn_rr = .{ .dst = dst, .src = src, .size = size },
                });
            } else if (data.opcode == .bitrev) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                try builder.emit(Inst{
                    .rbit = .{
                        .dst = dst,
                        .src = src,
                        .size = size,
                    },
                });
            } else if (data.opcode == .bswap) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const bits = value_type.bits();

                if (bits == 64) {
                    try builder.emit(Inst{
                        .rev64 = .{
                            .dst = dst,
                            .src = src,
                        },
                    });
                } else {
                    const size: OperandSize = if (bits == 32) .size32 else .size32;
                    try builder.emit(Inst{
                        .rev32 = .{
                            .dst = dst,
                            .src = src,
                            .size = size,
                        },
                    });
                }
            } else if (data.opcode == .ineg) {
                // Integer negate (two's complement)
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                // NEG - two's complement negation
                try builder.emit(Inst{
                    .neg = .{ .dst = dst, .src = src, .size = size },
                });
            } else if (data.opcode == .iabs) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: OperandSize = if (value_type.bits() == 64) .size64 else .size32;

                const temp_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                const temp_reg = Reg.fromVReg(temp_vreg);
                const temp_dst = WritableReg.fromVReg(temp_vreg);

                try builder.emit(Inst{
                    .neg = .{
                        .dst = temp_dst,
                        .src = src,
                        .size = size,
                    },
                });

                try builder.emit(Inst{
                    .cmp_imm = .{
                        .src = src,
                        .imm = .{ .bits = 0, .shift12 = false },
                    },
                });

                try builder.emit(Inst{
                    .csel = .{
                        .dst = dst,
                        .src1 = temp_reg,
                        .src2 = src,
                        .cond = CondCode.lt,
                        .size = size,
                    },
                });
            } else if (data.opcode == .sqrt) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.float);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.float);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: FpuOperandSize = if (value_type.bits() == 64) .size64 else .size32;

                try builder.emit(Inst{
                    .fsqrt = .{ .dst = dst, .src = src, .size = size },
                });
            } else if (data.opcode == .fcvt_from_sint or data.opcode == .fcvt_from_uint) {
                // int → float conversion
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.float);
                const dst = WritableReg.fromVReg(result_vreg);

                const src_type = ctx.func.dfg.valueType(data.arg) orelse return error.LoweringFailed;
                const dst_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;

                const src_size: OperandSize = if (src_type.bits() == 64) .size64 else .size32;
                const dst_size: FpuOperandSize = if (dst_type.bits() == 64) .size64 else .size32;

                if (data.opcode == .fcvt_from_sint) {
                    try builder.emit(Inst{
                        .scvtf = .{ .dst = dst, .src = src, .src_size = src_size, .dst_size = dst_size },
                    });
                } else {
                    try builder.emit(Inst{
                        .ucvtf = .{ .dst = dst, .src = src, .src_size = src_size, .dst_size = dst_size },
                    });
                }
            } else if (data.opcode == .fcvt_to_sint or data.opcode == .fcvt_to_uint or data.opcode == .fcvt_to_sint_sat or data.opcode == .fcvt_to_uint_sat) {
                // float → int conversion
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.float);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
                const dst = WritableReg.fromVReg(result_vreg);

                const src_type = ctx.func.dfg.valueType(data.arg) orelse return error.LoweringFailed;
                const dst_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;

                const src_size: FpuOperandSize = if (src_type.bits() == 64) .size64 else .size32;
                const dst_size: OperandSize = if (dst_type.bits() == 64) .size64 else .size32;

                // Note: ARM64 FCVTZS/FCVTZU are saturating by default
                if (data.opcode == .fcvt_to_sint or data.opcode == .fcvt_to_sint_sat) {
                    try builder.emit(Inst{
                        .fcvtzs = .{ .dst = dst, .src = src, .src_size = src_size, .dst_size = dst_size },
                    });
                } else {
                    try builder.emit(Inst{
                        .fcvtzu = .{ .dst = dst, .src = src, .src_size = src_size, .dst_size = dst_size },
                    });
                }
            } else if (data.opcode == .fpromote) {
                // f32 → f64
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.float);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.float);
                const dst = WritableReg.fromVReg(result_vreg);

                try builder.emit(Inst{
                    .fcvt_f32_to_f64 = .{ .dst = dst, .src = src },
                });
            } else if (data.opcode == .fdemote) {
                // f64 → f32
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.float);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.float);
                const dst = WritableReg.fromVReg(result_vreg);

                try builder.emit(Inst{
                    .fcvt_f64_to_f32 = .{ .dst = dst, .src = src },
                });
            } else if (data.opcode == .ceil or data.opcode == .floor or data.opcode == .trunc or data.opcode == .nearest) {
                // FP rounding operations
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.float);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.float);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: FpuOperandSize = if (value_type.bits() == 64) .size64 else .size32;

                if (data.opcode == .ceil) {
                    // Round towards +infinity
                    try builder.emit(Inst{
                        .frintp = .{ .dst = dst, .src = src, .size = size },
                    });
                } else if (data.opcode == .floor) {
                    // Round towards -infinity
                    try builder.emit(Inst{
                        .frintm = .{ .dst = dst, .src = src, .size = size },
                    });
                } else if (data.opcode == .trunc) {
                    // Round towards zero
                    try builder.emit(Inst{
                        .frintz = .{ .dst = dst, .src = src, .size = size },
                    });
                } else {
                    // nearest - round to nearest, ties to even
                    try builder.emit(Inst{
                        .frintn = .{ .dst = dst, .src = src, .size = size },
                    });
                }
            } else if (data.opcode == .fneg or data.opcode == .fabs) {
                // FP sign manipulation (unary)
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.float);
                const src = Reg.fromVReg(arg_vreg);

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.float);
                const dst = WritableReg.fromVReg(result_vreg);

                const value_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;
                const size: FpuOperandSize = if (value_type.bits() == 64) .size64 else .size32;

                if (data.opcode == .fneg) {
                    try builder.emit(Inst{
                        .fneg = .{ .dst = dst, .src = src, .size = size },
                    });
                } else {
                    try builder.emit(Inst{
                        .fabs = .{ .dst = dst, .src = src, .size = size },
                    });
                }
            } else if (data.opcode == .scalar_to_vector) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const arg_type = ctx.func.dfg.valueType(data.arg) orelse return error.LoweringFailed;

                const is_float = arg_type.isFloat();
                const src_class: RegClass = if (is_float) .float else .int;
                const fp_size: FpuOperandSize = if (arg_type.bits() == 64) .size64 else .size32;

                const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), src_class);
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), .float);

                const src = Reg.fromVReg(arg_vreg);
                const dst = WritableReg.fromVReg(result_vreg);

                if (is_float) {
                    try builder.emit(Inst{
                        .fmov = .{
                            .dst = dst,
                            .src = src,
                            .size = fp_size,
                        },
                    });
                } else {
                    try builder.emit(Inst{
                        .fmov_from_gpr = .{
                            .dst = dst,
                            .src = src,
                            .size = fp_size,
                        },
                    });
                }
            } else {
                // Other unary ops not yet implemented
                try builder.emit(Inst.nop);
            }
        },
        .unary_with_trap => |data| {
            // Handle unary instructions with trap codes (trapz, trapnz)
            const VReg = @import("../machinst/reg.zig").VReg;
            const Reg = @import("../machinst/reg.zig").Reg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const inst_module = @import("../backends/aarch64/inst.zig");
            const BranchTarget = inst_module.BranchTarget;

            // Map argument to vreg
            const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
            const arg_reg = Reg.fromVReg(arg_vreg);

            // Get value type for size
            const value_type = ctx.func.dfg.valueType(data.arg) orelse {
                try builder.emit(Inst.nop);
                return;
            };

            const size: OperandSize = if (value_type.bits() == 64)
                .size64
            else
                .size32;

            if (data.opcode == .trapz) {
                // Trap if zero: CBZ arg, +8; BRK #code
                // Skip forward 1 instruction (4 bytes) if not zero
                try builder.emit(Inst{
                    .cbz = .{
                        .reg = arg_reg,
                        .target = BranchTarget{ .offset = 8 }, // Skip BRK if not zero
                        .size = size,
                    },
                });
                try builder.emit(Inst{
                    .brk = .{ .imm = data.trap_code.toRaw() },
                });
            } else if (data.opcode == .trapnz) {
                // Trap if not zero: CBNZ arg, +8; BRK #code
                try builder.emit(Inst{
                    .cbnz = .{
                        .reg = arg_reg,
                        .target = BranchTarget{ .offset = 8 }, // Skip BRK if zero
                        .size = size,
                    },
                });
                try builder.emit(Inst{
                    .brk = .{ .imm = data.trap_code.toRaw() },
                });
            } else {
                try builder.emit(Inst.nop);
            }
        },
        .load => |data| {
            // Handle load instructions
            const VReg = @import("../machinst/reg.zig").VReg;
            const WritableReg = @import("../machinst/reg.zig").WritableReg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const Reg = @import("../machinst/reg.zig").Reg;

            // Get base address register
            const base_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
            const base = Reg.fromVReg(base_vreg);

            // Get result register
            const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
            const result_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;

            // Determine register class based on result type
            const reg_class: RegClass = if (result_type.isFloat()) .float else .int;
            const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), reg_class);
            const dst = WritableReg.fromVReg(result_vreg);

            // Emit load instruction based on size
            const offset_i16: i16 = @intCast(data.offset);
            if (result_type.bits() == 64) {
                try builder.emit(Inst{
                    .ldr = .{
                        .dst = dst,
                        .base = base,
                        .offset = offset_i16,
                        .size = .size64,
                    },
                });
            } else if (result_type.bits() == 32) {
                try builder.emit(Inst{
                    .ldr = .{
                        .dst = dst,
                        .base = base,
                        .offset = offset_i16,
                        .size = .size32,
                    },
                });
            } else if (result_type.bits() == 16) {
                try builder.emit(Inst{
                    .ldrh = .{
                        .dst = dst,
                        .base = base,
                        .offset = offset_i16,
                        .size = .size32, // zero-extend to 32-bit
                    },
                });
            } else {
                // 8-bit load
                try builder.emit(Inst{
                    .ldrb = .{
                        .dst = dst,
                        .base = base,
                        .offset = offset_i16,
                        .size = .size32, // zero-extend to 32-bit
                    },
                });
            }
        },
        .store => |data| {
            // Handle store instructions (store, istore8, istore16, istore32)
            const VReg = @import("../machinst/reg.zig").VReg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const Reg = @import("../machinst/reg.zig").Reg;

            // args[0] = address, args[1] = value to store
            const base_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
            const base = Reg.fromVReg(base_vreg);

            // Get value type to determine register class
            const value_type = ctx.func.dfg.valueType(data.args[1]) orelse return error.LoweringFailed;
            const reg_class: RegClass = if (value_type.isFloat()) .float else .int;

            const src_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), reg_class);
            const src = Reg.fromVReg(src_vreg);

            const offset_i16: i16 = @intCast(data.offset);

            // Handle explicit sub-word stores (istore8/16/32)
            if (data.opcode == .istore8) {
                // Store low 8 bits
                try builder.emit(Inst{
                    .strb = .{
                        .src = src,
                        .base = base,
                        .offset = offset_i16,
                    },
                });
            } else if (data.opcode == .istore16) {
                // Store low 16 bits
                try builder.emit(Inst{
                    .strh = .{
                        .src = src,
                        .base = base,
                        .offset = offset_i16,
                    },
                });
            } else if (data.opcode == .istore32) {
                // Store low 32 bits
                try builder.emit(Inst{
                    .str = .{
                        .src = src,
                        .base = base,
                        .offset = offset_i16,
                        .size = .size32,
                    },
                });
            } else if (value_type.bits() == 64) {
                try builder.emit(Inst{
                    .str = .{
                        .src = src,
                        .base = base,
                        .offset = offset_i16,
                        .size = .size64,
                    },
                });
            } else if (value_type.bits() == 32) {
                try builder.emit(Inst{
                    .str = .{
                        .src = src,
                        .base = base,
                        .offset = offset_i16,
                        .size = .size32,
                    },
                });
            } else if (value_type.bits() == 16) {
                try builder.emit(Inst{
                    .strh = .{
                        .src = src,
                        .base = base,
                        .offset = offset_i16,
                    },
                });
            } else {
                // 8-bit store
                try builder.emit(Inst{
                    .strb = .{
                        .src = src,
                        .base = base,
                        .offset = offset_i16,
                    },
                });
            }
        },
        .jump => |data| {
            // Handle unconditional jump
            const inst_module = @import("../backends/aarch64/inst.zig");
            const BranchTarget = inst_module.BranchTarget;

            // Emit B instruction with block label
            // For now, use the block index as the label
            // TODO: Proper label resolution when block layout is implemented
            try builder.emit(Inst{
                .b = .{
                    .target = BranchTarget{ .label = data.destination.index },
                },
            });
        },
        .branch => |data| {
            // Handle conditional branch (brif)
            const VReg = @import("../machinst/reg.zig").VReg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const Reg = @import("../machinst/reg.zig").Reg;
            const inst_module = @import("../backends/aarch64/inst.zig");
            const BranchTarget = inst_module.BranchTarget;

            // Get condition value (i1)
            const cond_vreg = VReg.new(@intCast(data.condition.index + Reg.PINNED_VREGS), RegClass.int);
            const cond_reg = Reg.fromVReg(cond_vreg);

            // Optimize: Use CBNZ (compare and branch if non-zero) instead of CMP+B.ne
            // This is more efficient for the common case of branching on a boolean condition
            if (data.then_dest) |then_block| {
                try builder.emit(Inst{
                    .cbnz = .{
                        .reg = cond_reg,
                        .target = BranchTarget{ .label = then_block.index },
                        .size = .size32,
                    },
                });
            }

            // Fall through or jump to else_dest
            if (data.else_dest) |else_block| {
                try builder.emit(Inst{
                    .b = .{
                        .target = BranchTarget{ .label = else_block.index },
                    },
                });
            }
        },
        .int_compare => |data| {
            // Handle integer comparison (icmp)
            const VReg = @import("../machinst/reg.zig").VReg;
            const WritableReg = @import("../machinst/reg.zig").WritableReg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const Reg = @import("../machinst/reg.zig").Reg;
            const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

            // Get operands
            const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.int);
            const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.int);
            const src1 = Reg.fromVReg(arg0_vreg);
            const src2 = Reg.fromVReg(arg1_vreg);

            // Get result register (i8 boolean result)
            const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
            const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
            const dst = WritableReg.fromVReg(result_vreg);

            // Determine size from operand type
            const arg_type = ctx.func.dfg.valueType(data.args[0]) orelse return error.LoweringFailed;
            const size: OperandSize = if (arg_type.bits() == 64) .size64 else .size32;

            // Emit CMP instruction (sets condition flags)
            try builder.emit(Inst{
                .cmp_rr = .{
                    .src1 = src1,
                    .src2 = src2,
                    .size = size,
                },
            });

            // Map IntCC to ARM64 CondCode
            const cond: CondCode = switch (data.cond) {
                .eq => .eq, // equal
                .ne => .ne, // not equal
                .slt => .lt, // signed less than
                .sle => .le, // signed less than or equal
                .sgt => .gt, // signed greater than
                .sge => .ge, // signed greater than or equal
                .ult => .cc, // unsigned less than (carry clear)
                .ule => .ls, // unsigned less than or equal
                .ugt => .hi, // unsigned greater than
                .uge => .cs, // unsigned greater than or equal (carry set)
            };

            // Emit CSET to materialize boolean result
            try builder.emit(Inst{
                .cset = .{
                    .dst = dst,
                    .cond = cond,
                    .size = .size32,
                },
            });
        },
        .int_compare_imm => |data| {
            const VReg = @import("../machinst/reg.zig").VReg;
            const WritableReg = @import("../machinst/reg.zig").WritableReg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const Reg = @import("../machinst/reg.zig").Reg;
            const CondCode = @import("../backends/aarch64/inst.zig").CondCode;
            const Imm12 = @import("../backends/aarch64/inst.zig").Imm12;

            const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), RegClass.int);
            const src = Reg.fromVReg(arg_vreg);

            const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
            const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
            const dst = WritableReg.fromVReg(result_vreg);

            const arg_type = ctx.func.dfg.valueType(data.arg) orelse return error.LoweringFailed;
            const size: OperandSize = if (arg_type.bits() == 64) .size64 else .size32;

            const imm_val = data.imm.value;
            if (imm_val <= 4095) {
                try builder.emit(Inst{
                    .cmp_imm = .{
                        .src = src,
                        .imm = Imm12{ .bits = @intCast(imm_val), .shift12 = false },
                    },
                });

                const cond: CondCode = switch (data.cond) {
                    .eq => .eq,
                    .ne => .ne,
                    .slt => .lt,
                    .sle => .le,
                    .sgt => .gt,
                    .sge => .ge,
                    .ult => .cc,
                    .ule => .ls,
                    .ugt => .hi,
                    .uge => .cs,
                };

                try builder.emit(Inst{
                    .cset = .{
                        .dst = dst,
                        .cond = cond,
                        .size = .size32,
                    },
                });
            } else {
                const temp_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS + 1), RegClass.int);
                const temp_reg = Reg.fromVReg(temp_vreg);
                const temp_dst = WritableReg.fromVReg(temp_vreg);

                try builder.emit(Inst{
                    .movz = .{
                        .dst = temp_dst,
                        .imm = @intCast(imm_val & 0xFFFF),
                        .shift = 0,
                        .size = size,
                    },
                });

                try builder.emit(Inst{
                    .cmp_rr = .{
                        .src1 = src,
                        .src2 = temp_reg,
                        .size = size,
                    },
                });

                const cond: CondCode = switch (data.cond) {
                    .eq => .eq,
                    .ne => .ne,
                    .slt => .lt,
                    .sle => .le,
                    .sgt => .gt,
                    .sge => .ge,
                    .ult => .cc,
                    .ule => .ls,
                    .ugt => .hi,
                    .uge => .cs,
                };

                try builder.emit(Inst{
                    .cset = .{
                        .dst = dst,
                        .cond = cond,
                        .size = .size32,
                    },
                });
            }
        },
        .float_compare => |data| {
            // Handle floating-point comparison (fcmp)
            const VReg = @import("../machinst/reg.zig").VReg;
            const WritableReg = @import("../machinst/reg.zig").WritableReg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const Reg = @import("../machinst/reg.zig").Reg;
            const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;
            const CondCode = @import("../backends/aarch64/inst.zig").CondCode;

            // Get operands
            const arg0_vreg = VReg.new(@intCast(data.args[0].index + Reg.PINNED_VREGS), RegClass.float);
            const arg1_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), RegClass.float);
            const src1 = Reg.fromVReg(arg0_vreg);
            const src2 = Reg.fromVReg(arg1_vreg);

            // Get result register (i8 boolean result)
            const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
            const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), RegClass.int);
            const dst = WritableReg.fromVReg(result_vreg);

            // Determine FP size from operand type
            const arg_type = ctx.func.dfg.valueType(data.args[0]) orelse return error.LoweringFailed;
            const size: FpuOperandSize = if (arg_type.bits() == 64) .size64 else .size32;

            // Emit FCMP instruction (sets condition flags)
            try builder.emit(Inst{
                .fcmp = .{
                    .src1 = src1,
                    .src2 = src2,
                    .size = size,
                },
            });

            // Map FloatCC to ARM64 CondCode
            // ARM64 condition codes for FP:
            // EQ - equal
            // NE - not equal
            // CS/HS - greater than, equal, or unordered
            // CC/LO - less than
            // MI - less than
            // PL - greater than, equal, or unordered
            // VS - unordered (at least one NaN)
            // VC - ordered (no NaN)
            // HI - greater than
            // LS - less than or equal
            // GE - greater than or equal
            // LT - less than
            // GT - greater than
            // LE - less than or equal
            const cond: CondCode = switch (data.cond) {
                .ord => .vc, // ordered (no NaN)
                .uno => .vs, // unordered (NaN present)
                .eq => .eq, // equal
                .ne => .ne, // not equal
                .one => blk: {
                    // ordered not equal - need VC && NE
                    // For now, use NE (will be refined with multiple CSET)
                    break :blk .ne;
                },
                .ueq => blk: {
                    // unordered or equal - need VS || EQ
                    // For now, use EQ (will be refined)
                    break :blk .eq;
                },
                .lt => .mi, // less than (MI = minus/negative)
                .le => .ls, // less than or equal
                .gt => .gt, // greater than
                .ge => .ge, // greater than or equal
                .ult => blk: {
                    // unordered or less than
                    break :blk .lt;
                },
                .ule => blk: {
                    // unordered or less than or equal
                    break :blk .le;
                },
                .ugt => blk: {
                    // unordered or greater than
                    break :blk .gt;
                },
                .uge => blk: {
                    // unordered or greater than or equal
                    break :blk .ge;
                },
            };

            // Emit CSET to materialize boolean result
            try builder.emit(Inst{
                .cset = .{
                    .dst = dst,
                    .cond = cond,
                    .size = .size32,
                },
            });
        },
        .call => |data| {
            // Handle direct function call
            const CallTarget = @import("../backends/aarch64/inst.zig").CallTarget;

            // For now, use the func_ref index as label
            // In a real implementation, we'd resolve the function name or address
            const target = CallTarget{ .label = data.func_ref.index };

            try builder.emit(Inst{
                .call = .{
                    .target = target,
                },
            });
        },
        .call_indirect => |data| {
            // Handle indirect function call through register
            const VReg = @import("../machinst/reg.zig").VReg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const Reg = @import("../machinst/reg.zig").Reg;

            // First argument is the function pointer (callee)
            const callee_value = ctx.func.dfg.value_lists.get(data.args, 0) orelse return error.LoweringFailed;
            const callee_vreg = VReg.new(@intCast(callee_value.index + Reg.PINNED_VREGS), RegClass.int);
            const target = Reg.fromVReg(callee_vreg);

            try builder.emit(Inst{
                .call_indirect = .{
                    .target = target,
                },
            });
        },
        .extract_lane => |data| {
            const VReg = @import("../machinst/reg.zig").VReg;
            const WritableReg = @import("../machinst/reg.zig").WritableReg;
            const RegClass = @import("../machinst/reg.zig").RegClass;
            const Reg = @import("../machinst/reg.zig").Reg;
            const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

            if (data.lane != 0) return error.LoweringFailed;

            const arg_vreg = VReg.new(@intCast(data.arg.index + Reg.PINNED_VREGS), .float);
            const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
            const result_type = ctx.func.dfg.valueType(result_value) orelse return error.LoweringFailed;

            const is_float = result_type.isFloat();
            const dst_class: RegClass = if (is_float) .float else .int;
            const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), dst_class);

            const src = Reg.fromVReg(arg_vreg);
            const dst = WritableReg.fromVReg(result_vreg);
            const size: FpuOperandSize = if (result_type.bits() == 64) .size64 else .size32;

            if (is_float) {
                try builder.emit(Inst{
                    .fmov = .{
                        .dst = dst,
                        .src = src,
                        .size = size,
                    },
                });
            } else {
                try builder.emit(Inst{
                    .fmov_to_gpr = .{
                        .dst = dst,
                        .src = src,
                        .size = size,
                    },
                });
            }
        },
        .ternary_imm8 => |data| {
            if (data.opcode == .insertlane) {
                const VReg = @import("../machinst/reg.zig").VReg;
                const WritableReg = @import("../machinst/reg.zig").WritableReg;
                const RegClass = @import("../machinst/reg.zig").RegClass;
                const Reg = @import("../machinst/reg.zig").Reg;
                const FpuOperandSize = @import("../backends/aarch64/inst.zig").FpuOperandSize;

                if (data.imm != 0) return error.LoweringFailed;

                _ = data.args[0];
                const result_value = ctx.func.dfg.firstResult(inst) orelse return error.LoweringFailed;
                const result_vreg = VReg.new(@intCast(result_value.index + Reg.PINNED_VREGS), .float);

                const scalar_type = ctx.func.dfg.valueType(data.args[1]) orelse return error.LoweringFailed;
                const is_float = scalar_type.isFloat();
                const scalar_class: RegClass = if (is_float) .float else .int;
                const scalar_vreg = VReg.new(@intCast(data.args[1].index + Reg.PINNED_VREGS), scalar_class);

                const dst = WritableReg.fromVReg(result_vreg);
                const size: FpuOperandSize = if (scalar_type.bits() == 64) .size64 else .size32;

                if (is_float) {
                    try builder.emit(Inst{
                        .fmov = .{
                            .dst = dst,
                            .src = Reg.fromVReg(scalar_vreg),
                            .size = size,
                        },
                    });
                } else {
                    try builder.emit(Inst{
                        .fmov_from_gpr = .{
                            .dst = dst,
                            .src = Reg.fromVReg(scalar_vreg),
                            .size = size,
                        },
                    });
                }
            } else {
                try builder.emit(Inst.nop);
            }
        },
        else => {
            // Unimplemented instruction - emit NOP placeholder
            try builder.emit(Inst.nop);
        },
    }
}

/// Lower IR to x86-64 VCode.
fn lowerX86_64(ctx: *Context) CodegenError!void {
    // TODO: x86-64 lowering not yet implemented
    _ = ctx;
    return error.LoweringFailed;
}

/// Lower a single instruction.
fn lowerInstruction(lower_ctx: anytype, inst: ir.Inst, target: *const Target) CodegenError!void {
    _ = lower_ctx;
    _ = inst;
    _ = target;
    // TODO: Call ISLE-generated lowering rules or backend-specific lowering
    // For now, this is a stub that will be connected to the ISLE compiler output
}

/// Allocate registers.
fn allocateRegisters(ctx: *Context, target: *const Target) CodegenError!void {
    // TODO: Register allocation not yet implemented
    _ = ctx;
    _ = target;
    _ = target;
}

/// Insert function prologue and epilogue.
fn insertPrologueEpilogue(ctx: *Context, target: *const Target) CodegenError!void {
    // TODO: Prologue/epilogue insertion not yet implemented
    _ = ctx;
    _ = target;
    _ = target;
}

/// Emit machine code.
fn emit(ctx: *Context, target: *const Target) CodegenError!void {
    // TODO: Machine code emission not yet implemented
    _ = ctx;
    _ = target;
    _ = target;
}

/// Assemble final result from MachBuffer.
///
/// Performs final assembly phase:
/// - Finalizes label fixups and resolves relocations
/// - Emits constant pool
/// - Copies machine code to result buffer
/// - Copies relocation entries
/// - Optionally generates disassembly
pub fn assembleResult(
    allocator: std.mem.Allocator,
    buffer: *MachBuffer,
    want_disasm: bool,
) CodegenError!CompiledCode {
    var result = CompiledCode.init(allocator);
    errdefer result.deinit();

    // Copy machine code bytes
    try result.code.appendSlice(allocator, buffer.finish());

    // Copy relocations, converting to output format
    try result.relocs.ensureTotalCapacity(allocator, buffer.relocs.items.len);
    for (buffer.relocs.items) |mach_reloc| {
        const reloc = Relocation{
            .offset = mach_reloc.offset,
            .kind = convertRelocKind(mach_reloc.kind),
            .name = try allocator.dupe(u8, mach_reloc.name),
            .addend = mach_reloc.addend,
        };
        result.relocs.appendAssumeCapacity(reloc);
    }

    // Generate disassembly if requested
    if (want_disasm) {
        var disasm_buf = std.ArrayList(u8){};
        try disasm_buf.writer(allocator).print("; Machine code ({d} bytes)\n", .{result.code.items.len});
        try disasm_buf.writer(allocator).print("; {d} relocations\n", .{result.relocs.items.len});
        result.disasm = disasm_buf;
    }

    return result;
}

/// Convert MachBuffer relocation to output relocation kind.
fn convertRelocKind(kind: Reloc) RelocKind {
    return switch (kind) {
        .abs8, .aarch64_abs64 => .abs8,
        .x86_pc_rel_32 => .pcrel4,
        .aarch64_adr_prel_pg_hi21 => .aarch64_adr_prel_pg_hi21,
        .aarch64_add_abs_lo12_nc => .aarch64_add_abs_lo12_nc,
        else => .pcrel4, // Default fallback
    };
}

/// Target ISA configuration.
pub const Target = struct {
    /// Target architecture.
    arch: Architecture,
    /// Optimization level.
    opt_level: OptLevel,
    /// Enable verification.
    verify: bool,

    pub const Architecture = enum {
        aarch64,
        x86_64,
    };

    pub const OptLevel = enum {
        none,
        speed,
        speed_and_size,
    };

    pub fn init(arch: Architecture) Target {
        return .{
            .arch = arch,
            .opt_level = .none,
            .verify = false,
        };
    }
};

// Tests

const testing = std.testing;

test "compile: target initialization" {
    const target = Target.init(.aarch64);
    try testing.expectEqual(Target.Architecture.aarch64, target.arch);
    try testing.expectEqual(Target.OptLevel.none, target.opt_level);
    try testing.expect(!target.verify);
}

test "IRBuilder: initialization" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const builder = IRBuilder.init(testing.allocator, &func);
    try testing.expectEqual(&func, builder.func);
}

test "IRBuilder: create and append block" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);

    try testing.expectEqual(block, func.layout.entryBlock().?);
}

test "IRBuilder: emit instructions" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v1 = try builder.emitIconst(ir.Type.I32, 10);
    const v2 = try builder.emitIconst(ir.Type.I32, 20);
    const v3 = try builder.emitIadd(ir.Type.I32, v1, v2);
    _ = try builder.emitIsub(ir.Type.I32, v3, v1);
    _ = try builder.emitImul(ir.Type.I32, v1, v2);
    try builder.emitReturn();

    try testing.expectEqual(@as(usize, 5), func.dfg.insts.elems.items.len);
}

test "IRBuilder: emit control flow" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block1 = try builder.createBlock();
    const block2 = try builder.createBlock();

    try builder.appendBlock(block1);
    try builder.appendBlock(block2);

    builder.switchToBlock(block1);
    try builder.emitJump(block2);

    builder.switchToBlock(block2);
    try builder.emitReturn();

    try testing.expectEqual(@as(usize, 2), func.dfg.insts.elems.items.len);
}

test "buildIR: basic function" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    try buildIR(testing.allocator, &func);

    try testing.expect(func.layout.entryBlock() != null);
    try testing.expect(func.dfg.insts.elems.items.len > 0);
}

test "assembleResult: basic assembly" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Emit some machine code
    try buffer.put4(0xD65F03C0); // RET instruction (aarch64)
    try buffer.put4(0xD503201F); // NOP instruction (aarch64)

    // Add a relocation
    try buffer.addReloc(0, .aarch64_call26, "external_func", 0);

    // Finalize buffer
    try buffer.finalize();

    // Assemble result without disassembly
    var result = try assembleResult(testing.allocator, &buffer, false);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 8), result.code.items.len);
    try testing.expectEqual(@as(usize, 1), result.relocs.items.len);
    try testing.expect(result.disasm == null);

    const reloc = result.relocs.items[0];
    try testing.expectEqual(@as(u32, 0), reloc.offset);
    try testing.expectEqualStrings("external_func", reloc.name);
}

test "assembleResult: with disassembly" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try buffer.put4(0xD65F03C0); // RET
    try buffer.finalize();

    var result = try assembleResult(testing.allocator, &buffer, true);
    defer result.deinit();

    try testing.expect(result.disasm != null);
    const disasm = result.disasm.?;
    try testing.expect(disasm.items.len > 0);
}

test "assembleResult: empty buffer" {
    var buffer = MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try buffer.finalize();

    var result = try assembleResult(testing.allocator, &buffer, false);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 0), result.code.items.len);
    try testing.expectEqual(@as(usize, 0), result.relocs.items.len);
}

test "convertRelocKind: all variants" {
    const abs8_kind = convertRelocKind(.abs8);
    try testing.expectEqual(RelocKind.abs8, abs8_kind);

    const pcrel_kind = convertRelocKind(.x86_pc_rel_32);
    try testing.expectEqual(RelocKind.pcrel4, pcrel_kind);

    const aarch64_adr_kind = convertRelocKind(.aarch64_adr_prel_pg_hi21);
    try testing.expectEqual(RelocKind.aarch64_adr_prel_pg_hi21, aarch64_adr_kind);

    const aarch64_add_kind = convertRelocKind(.aarch64_add_abs_lo12_nc);
    try testing.expectEqual(RelocKind.aarch64_add_abs_lo12_nc, aarch64_add_kind);
}

// Comprehensive IRBuilder tests

test "IRBuilder: create multiple blocks" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block1 = try builder.createBlock();
    const block2 = try builder.createBlock();
    const block3 = try builder.createBlock();

    try builder.appendBlock(block1);
    try builder.appendBlock(block2);
    try builder.appendBlock(block3);

    try testing.expectEqual(block1, func.layout.entryBlock().?);

    var count: usize = 0;
    var iter = func.layout.blockIter();
    while (iter.next()) |_| {
        count += 1;
    }
    try testing.expectEqual(@as(usize, 3), count);
}

test "IRBuilder: switch to block" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block1 = try builder.createBlock();
    const block2 = try builder.createBlock();

    try builder.appendBlock(block1);
    try builder.appendBlock(block2);

    builder.switchToBlock(block1);
    try testing.expectEqual(block1, builder.builder.current_block.?);

    builder.switchToBlock(block2);
    try testing.expectEqual(block2, builder.builder.current_block.?);
}

test "IRBuilder: emit iconst with different types" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v1 = try builder.emitIconst(ir.Type.I32, 42);
    const v2 = try builder.emitIconst(ir.Type.I64, 100);

    try testing.expect(func.dfg.values.get(v1) != null);
    try testing.expect(func.dfg.values.get(v2) != null);

    const v1_data = func.dfg.values.get(v1).?;
    const v2_data = func.dfg.values.get(v2).?;
    try testing.expectEqual(ir.Type.I32, v1_data.getType());
    try testing.expectEqual(ir.Type.I64, v2_data.getType());
}

test "IRBuilder: emit multiple iconsts" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    _ = try builder.emitIconst(ir.Type.I32, 1);
    _ = try builder.emitIconst(ir.Type.I32, 2);
    _ = try builder.emitIconst(ir.Type.I32, 3);
    _ = try builder.emitIconst(ir.Type.I32, 4);
    _ = try builder.emitIconst(ir.Type.I32, 5);

    try testing.expectEqual(@as(usize, 5), func.dfg.insts.elems.items.len);
}

test "IRBuilder: emit iadd" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v1 = try builder.emitIconst(ir.Type.I32, 10);
    const v2 = try builder.emitIconst(ir.Type.I32, 20);
    const v3 = try builder.emitIadd(ir.Type.I32, v1, v2);

    try testing.expect(func.dfg.values.get(v3) != null);
    try testing.expectEqual(@as(usize, 3), func.dfg.insts.elems.items.len);
}

test "IRBuilder: emit isub" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v1 = try builder.emitIconst(ir.Type.I32, 100);
    const v2 = try builder.emitIconst(ir.Type.I32, 30);
    const v3 = try builder.emitIsub(ir.Type.I32, v1, v2);

    try testing.expect(func.dfg.values.get(v3) != null);
    try testing.expectEqual(@as(usize, 3), func.dfg.insts.elems.items.len);
}

test "IRBuilder: emit imul" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v1 = try builder.emitIconst(ir.Type.I32, 5);
    const v2 = try builder.emitIconst(ir.Type.I32, 7);
    const v3 = try builder.emitImul(ir.Type.I32, v1, v2);

    try testing.expect(func.dfg.values.get(v3) != null);
    try testing.expectEqual(@as(usize, 3), func.dfg.insts.elems.items.len);
}

test "IRBuilder: emit chained arithmetic" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v1 = try builder.emitIconst(ir.Type.I32, 10);
    const v2 = try builder.emitIconst(ir.Type.I32, 20);
    const v3 = try builder.emitIconst(ir.Type.I32, 30);
    const v4 = try builder.emitIconst(ir.Type.I32, 5);

    const sum = try builder.emitIadd(ir.Type.I32, v1, v2);
    const diff = try builder.emitIsub(ir.Type.I32, v3, v4);
    const product = try builder.emitImul(ir.Type.I32, sum, diff);

    try testing.expect(func.dfg.values.get(product) != null);
    try testing.expectEqual(@as(usize, 7), func.dfg.insts.elems.items.len);
}

test "IRBuilder: emit return" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    try builder.emitReturn();

    try testing.expectEqual(@as(usize, 1), func.dfg.insts.elems.items.len);
}

test "IRBuilder: emit jump" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block1 = try builder.createBlock();
    const block2 = try builder.createBlock();

    try builder.appendBlock(block1);
    try builder.appendBlock(block2);

    builder.switchToBlock(block1);
    try builder.emitJump(block2);

    try testing.expectEqual(@as(usize, 1), func.dfg.insts.elems.items.len);
}

test "IRBuilder: emit control flow with multiple blocks" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const entry = try builder.createBlock();
    const middle = try builder.createBlock();
    const exit = try builder.createBlock();

    try builder.appendBlock(entry);
    try builder.appendBlock(middle);
    try builder.appendBlock(exit);

    builder.switchToBlock(entry);
    try builder.emitJump(middle);

    builder.switchToBlock(middle);
    try builder.emitJump(exit);

    builder.switchToBlock(exit);
    try builder.emitReturn();

    try testing.expectEqual(@as(usize, 3), func.dfg.insts.elems.items.len);
}

test "IRBuilder: value tracking with simple expression" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v1 = try builder.emitIconst(ir.Type.I32, 10);
    const v2 = try builder.emitIconst(ir.Type.I32, 20);
    const v3 = try builder.emitIadd(ir.Type.I32, v1, v2);
    const v4 = try builder.emitIsub(ir.Type.I32, v3, v1);
    const v5 = try builder.emitImul(ir.Type.I32, v1, v2);

    try testing.expect(func.dfg.values.get(v1) != null);
    try testing.expect(func.dfg.values.get(v2) != null);
    try testing.expect(func.dfg.values.get(v3) != null);
    try testing.expect(func.dfg.values.get(v4) != null);
    try testing.expect(func.dfg.values.get(v5) != null);

    try testing.expectEqual(@as(usize, 5), func.dfg.values.elems.items.len);
}

test "IRBuilder: value types are preserved" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v_i32 = try builder.emitIconst(ir.Type.I32, 42);
    const v_i64 = try builder.emitIconst(ir.Type.I64, 100);

    const v_i32_data = func.dfg.values.get(v_i32).?;
    const v_i64_data = func.dfg.values.get(v_i64).?;

    try testing.expectEqual(ir.Type.I32, v_i32_data.getType());
    try testing.expectEqual(ir.Type.I64, v_i64_data.getType());
}

test "IRBuilder: build simple function" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const entry = try builder.createBlock();
    try builder.appendBlock(entry);
    builder.switchToBlock(entry);

    const a = try builder.emitIconst(ir.Type.I32, 5);
    const b = try builder.emitIconst(ir.Type.I32, 3);
    const c = try builder.emitIconst(ir.Type.I32, 2);

    const sum = try builder.emitIadd(ir.Type.I32, a, b);
    _ = try builder.emitImul(ir.Type.I32, sum, c);
    try builder.emitReturn();

    try testing.expectEqual(entry, func.layout.entryBlock().?);
    try testing.expectEqual(@as(usize, 6), func.dfg.insts.elems.items.len);
}

test "IRBuilder: build function with conditional flow" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);

    const entry = try builder.createBlock();
    const then_block = try builder.createBlock();
    const else_block = try builder.createBlock();
    const merge = try builder.createBlock();

    try builder.appendBlock(entry);
    try builder.appendBlock(then_block);
    try builder.appendBlock(else_block);
    try builder.appendBlock(merge);

    builder.switchToBlock(entry);
    const val = try builder.emitIconst(ir.Type.I32, 10);
    _ = val;
    try builder.emitJump(then_block);

    builder.switchToBlock(then_block);
    const t1 = try builder.emitIconst(ir.Type.I32, 5);
    _ = try builder.emitIadd(ir.Type.I32, t1, t1);
    try builder.emitJump(merge);

    builder.switchToBlock(else_block);
    const e1 = try builder.emitIconst(ir.Type.I32, 20);
    _ = try builder.emitIsub(ir.Type.I32, e1, e1);
    try builder.emitJump(merge);

    builder.switchToBlock(merge);
    try builder.emitReturn();

    try testing.expectEqual(@as(usize, 4), func.layout.blocks.elems.items.len);
    try testing.expectEqual(@as(usize, 8), func.dfg.insts.elems.items.len);
}

test "IRBuilder: build function with loop structure" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);

    const entry = try builder.createBlock();
    const loop_header = try builder.createBlock();
    const loop_body = try builder.createBlock();
    const loop_exit = try builder.createBlock();

    try builder.appendBlock(entry);
    try builder.appendBlock(loop_header);
    try builder.appendBlock(loop_body);
    try builder.appendBlock(loop_exit);

    builder.switchToBlock(entry);
    _ = try builder.emitIconst(ir.Type.I32, 0);
    try builder.emitJump(loop_header);

    builder.switchToBlock(loop_header);
    try builder.emitJump(loop_body);

    builder.switchToBlock(loop_body);
    const v1 = try builder.emitIconst(ir.Type.I32, 1);
    const v2 = try builder.emitIconst(ir.Type.I32, 2);
    _ = try builder.emitIadd(ir.Type.I32, v1, v2);
    try builder.emitJump(loop_header);

    builder.switchToBlock(loop_exit);
    try builder.emitReturn();

    try testing.expectEqual(@as(usize, 4), func.layout.blocks.elems.items.len);
    try testing.expectEqual(@as(usize, 7), func.dfg.insts.elems.items.len);
}

test "IRBuilder: emit instructions in different blocks" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block1 = try builder.createBlock();
    const block2 = try builder.createBlock();

    try builder.appendBlock(block1);
    try builder.appendBlock(block2);

    builder.switchToBlock(block1);
    _ = try builder.emitIconst(ir.Type.I32, 10);
    _ = try builder.emitIconst(ir.Type.I32, 20);

    builder.switchToBlock(block2);
    _ = try builder.emitIconst(ir.Type.I32, 30);
    try builder.emitReturn();

    try testing.expectEqual(@as(usize, 4), func.dfg.insts.elems.items.len);
}

test "IRBuilder: empty function with just return" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    try builder.emitReturn();

    try testing.expectEqual(@as(usize, 1), func.dfg.insts.elems.items.len);
}

test "IRBuilder: multiple jumps to same block" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const entry = try builder.createBlock();
    const b1 = try builder.createBlock();
    const b2 = try builder.createBlock();
    const merge = try builder.createBlock();

    try builder.appendBlock(entry);
    try builder.appendBlock(b1);
    try builder.appendBlock(b2);
    try builder.appendBlock(merge);

    builder.switchToBlock(entry);
    try builder.emitJump(b1);

    builder.switchToBlock(b1);
    try builder.emitJump(merge);

    builder.switchToBlock(b2);
    try builder.emitJump(merge);

    builder.switchToBlock(merge);
    try builder.emitReturn();

    try testing.expectEqual(@as(usize, 4), func.dfg.insts.elems.items.len);
}

test "buildIR: creates entry block" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    try buildIR(testing.allocator, &func);

    try testing.expect(func.layout.entryBlock() != null);
}

test "buildIR: emits return instruction" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    try buildIR(testing.allocator, &func);

    try testing.expect(func.dfg.insts.elems.items.len > 0);
}

test "buildIR: function is valid" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    try buildIR(testing.allocator, &func);

    try testing.expect(func.layout.entryBlock() != null);
    try testing.expect(func.layout.blocks.elems.items.len > 0);
}
