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
const Context = @import("context.zig").Context;
const CompiledCode = @import("context.zig").CompiledCode;
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
};
const MachBuffer = @import("../machinst/buffer.zig").MachBuffer;

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
    target: *const Target,
) CompileResult {
    // 1. Verify IR (if enabled)
    try verifyIf(ctx, target);

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
fn verifyIf(ctx: *Context, target: *const Target) CodegenError!void {
    if (!target.verify) return;

    var verifier = ir.Verifier.init(ctx.allocator, &ctx.func);
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
    try ctx.cfg.compute(&ctx.func) catch return error.OptimizationFailed;

    // 3. Compute dominator tree
    if (ctx.func.entryBlock()) |entry| {
        try ctx.domtree.compute(ctx.allocator, entry, &ctx.cfg) catch return error.OptimizationFailed;
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
    const Value = ir.Value;
    var changed = false;

    var block_iter = ctx.func.layout.blockIter();
    while (block_iter.next()) |block| {
        const block_data = ctx.func.dfg.blocks.get(block) orelse continue;
        const params = block_data.getParams(&ctx.func.dfg.value_lists);

        if (params.len == 0) continue;

        // For each block parameter
        for (params, 0..) |param, param_idx| {
            var common_value: ?Value = null;
            var all_same = true;

            // Iterate over all predecessors
            var pred_iter = ctx.cfg.predIter(block);
            while (pred_iter.next()) |pred| {
                const pred_inst = pred.inst;
                const inst_data = ctx.func.dfg.insts.get(pred_inst) orelse {
                    all_same = false;
                    break;
                };

                // Extract argument at param_idx from branch instruction
                const arg_value = switch (inst_data.*) {
                    .branch => |br| blk: {
                        if (br.destination.len(&ctx.func.dfg.value_lists) <= param_idx) {
                            all_same = false;
                            break;
                        }
                        break :blk br.destination.getArg(&ctx.func.dfg.value_lists, param_idx);
                    },
                    .jump => {
                        // Jump instructions don't carry arguments in this IR
                        all_same = false;
                        break;
                    },
                    else => {
                        all_same = false;
                        break;
                    },
                } orelse {
                    all_same = false;
                    break;
                };

                // Resolve aliases
                const resolved_value = ctx.func.dfg.resolveAliases(arg_value);

                if (common_value) |cv| {
                    // Check if same as previous
                    if (!std.meta.eql(ctx.func.dfg.resolveAliases(cv), resolved_value)) {
                        all_same = false;
                        break;
                    }
                } else {
                    common_value = resolved_value;
                }
            }

            // If all incoming values are the same, replace param with alias
            if (all_same and common_value != null) {
                const cv = common_value.?;
                // Don't create self-alias
                if (!std.meta.eql(param, cv)) {
                    if (ctx.func.dfg.values.getMut(param)) |param_data| {
                        const param_type = param_data.getType();
                        param_data.* = ir.ValueData.alias(param_type, cv);
                        changed = true;
                    }
                }
            }
        }
    }

    return changed;
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
    var worklist = std.ArrayList(Block).init(ctx.allocator);
    defer worklist.deinit();

    try worklist.append(entry);
    try reachable.put(entry, {});

    while (worklist.items.len > 0) {
        const block = worklist.pop();
        var succ_iter = ctx.cfg.succIter(block);
        while (succ_iter.next()) |succ| {
            if (!reachable.contains(succ)) {
                try reachable.put(succ, {});
                try worklist.append(succ);
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
    // TODO: Implement legalization
    _ = ctx;
}

/// Lower IR to VCode via ISLE.
fn lower(ctx: *Context, target: *const Target) CodegenError!void {
    const LowerCtx = @import("isle_ctx.zig").LowerCtx;
    const VCodeBuilder = @import("../machinst/vcode.zig").VCodeBuilder;

    // Create VCode builder for the target architecture
    var vcode_builder = VCodeBuilder.init(ctx.allocator, &ctx.func) catch |err| {
        std.debug.print("Failed to create VCode builder: {}\n", .{err});
        return error.LoweringFailed;
    };
    defer vcode_builder.deinit();

    // Create ISLE lowering context
    var lower_ctx = LowerCtx.init(ctx.allocator, &ctx.func, &vcode_builder) catch |err| {
        std.debug.print("Failed to create lowering context: {}\n", .{err});
        return error.LoweringFailed;
    };
    defer lower_ctx.deinit();

    // Lower each block in layout order
    var block_iter = ctx.func.layout.blockIter();
    while (block_iter.next()) |block| {
        // Start lowering this block
        lower_ctx.startBlock(block) catch |err| {
            std.debug.print("Failed to start block lowering: {}\n", .{err});
            return error.LoweringFailed;
        };

        // Lower each instruction in the block
        var inst_iter = ctx.func.layout.blockInstIter(block);
        while (inst_iter.next()) |inst| {
            // Set current instruction for diagnostics
            lower_ctx.setCurrentInst(inst);

            // Lower instruction via ISLE rules or backend-specific lowering
            lowerInstruction(&lower_ctx, inst, target) catch |err| {
                std.debug.print("Failed to lower instruction: {}\n", .{err});
                return error.LoweringFailed;
            };
        }

        // End block lowering
        lower_ctx.endBlock() catch |err| {
            std.debug.print("Failed to end block lowering: {}\n", .{err});
            return error.LoweringFailed;
        };
    }

    // Store the built VCode in context for register allocation
    ctx.vcode = vcode_builder.finish() catch |err| {
        std.debug.print("Failed to finish VCode: {}\n", .{err});
        return error.LoweringFailed;
    };
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
    // TODO: Implement register allocation
    _ = ctx;
    _ = target;
}

/// Insert function prologue and epilogue.
fn insertPrologueEpilogue(ctx: *Context, target: *const Target) CodegenError!void {
    // TODO: Implement prologue/epilogue insertion
    _ = ctx;
    _ = target;
}

/// Emit machine code.
fn emit(ctx: *Context, target: *const Target) CodegenError!void {
    // TODO: Implement code emission
    _ = target;

    // Allocate compiled code result
    const code = CompiledCode.init(ctx.allocator);
    ctx.compiled_code = code;
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
    buffer: *const MachBuffer,
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
        var disasm_buf = std.ArrayList(u8).init(allocator);
        try disasm_buf.writer().print("; Machine code ({d} bytes)\n", .{result.code.items.len});
        try disasm_buf.writer().print("; {d} relocations\n", .{result.relocs.items.len});
        result.disasm = disasm_buf;
    }

    return result;
}

/// Convert MachBuffer relocation to output relocation kind.
fn convertRelocKind(kind: MachBuffer.Reloc) RelocKind {
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
    const sig = try ir.Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const builder = IRBuilder.init(testing.allocator, &func);
    try testing.expectEqual(&func, builder.func);
}

test "IRBuilder: create and append block" {
    const sig = try ir.Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);

    try testing.expectEqual(block, func.layout.entryBlock().?);
}

test "IRBuilder: emit instructions" {
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
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
    const sig = try ir.Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    try buildIR(testing.allocator, &func);

    try testing.expect(func.layout.entryBlock() != null);
}

test "buildIR: emits return instruction" {
    const sig = try ir.Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    try buildIR(testing.allocator, &func);

    try testing.expect(func.dfg.insts.elems.items.len > 0);
}

test "buildIR: function is valid" {
    const sig = try ir.Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    try buildIR(testing.allocator, &func);

    try testing.expect(func.layout.entryBlock() != null);
    try testing.expect(func.layout.blocks.elems.items.len > 0);
}
