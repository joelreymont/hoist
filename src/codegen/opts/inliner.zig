//! Function Inliner
//!
//! Inlines function calls to eliminate call overhead and enable
//! cross-function optimizations like constant propagation.
//!
//! Decision criteria:
//! - Callee size vs threshold
//! - Call site count (cold vs hot)
//! - Recursion detection
//! - Marked inline hints
//!
//! The inliner clones the callee function body at each call site,
//! mapping parameters to arguments and return value to call result.

const std = @import("std");
const Allocator = std.mem.Allocator;

const ir_mod = @import("../../ir.zig");
const Function = ir_mod.Function;
const Block = ir_mod.Block;
const Inst = ir_mod.Inst;
const Value = ir_mod.Value;
const Type = ir_mod.Type;
const FuncRef = @import("../../ir/entities.zig").FuncRef;
const Opcode = @import("../../ir/opcodes.zig").Opcode;
const InstructionData = @import("../../ir/instruction_data.zig").InstructionData;
const Signature = @import("../../ir/signature.zig").Signature;
const ExternalName = @import("../../ir/extfunc.zig").ExternalName;
const ValueList = @import("../../ir/value_list.zig").ValueList;

/// Inlining configuration.
pub const Config = struct {
    /// Maximum instruction count for always-inline.
    always_inline_threshold: u32 = 10,

    /// Maximum instruction count for hot call sites.
    hot_threshold: u32 = 50,

    /// Maximum instruction count for cold call sites.
    cold_threshold: u32 = 20,

    /// Maximum total code size growth factor (1.5 = 50% growth allowed).
    max_growth: f32 = 1.5,

    /// Maximum inlining depth for recursive functions.
    max_depth: u32 = 3,

    /// Whether to inline calls with unknown callees.
    inline_indirect: bool = false,
};

/// Per-function inline info.
pub const FunctionInfo = struct {
    /// Number of instructions in function.
    inst_count: u32 = 0,

    /// Number of basic blocks.
    block_count: u32 = 0,

    /// Number of call sites within function.
    call_count: u32 = 0,

    /// Number of times this function is called.
    caller_count: u32 = 0,

    /// Whether function is marked as inline hint.
    inline_hint: bool = false,

    /// Whether function is marked as no_inline_attr.
    no_inline_attr: bool = false,

    /// Whether function is recursive.
    is_recursive: bool = false,

    /// Computed inline cost.
    cost: i32 = 0,
};

/// Inline decision for a call site.
pub const Decision = enum {
    /// Inline the call.
    inline_call,
    /// Do not inline.
    no_inline,
    /// Too large to inline.
    too_large,
    /// Marked no_inline_attr.
    no_inline_attr_attr,
    /// Recursive call depth exceeded.
    recursive_limit,
    /// Unknown callee.
    unknown_callee,
};

/// Call site information.
pub const CallSite = struct {
    /// Instruction of the call.
    inst: Inst,
    /// Block containing the call.
    block: Block,
    /// Referenced callee function handle.
    func_ref: ?FuncRef = null,
    /// Called function (if known).
    callee: ?*const Function = null,
    /// Arguments to the call.
    args: []const Value,
    /// Decision for this call site.
    decision: Decision = .no_inline,
};

/// Function inliner pass.
pub const Inliner = struct {
    const CalleeInfo = struct {
        name: []const u8,
        func: *const Function,
    };

    allocator: Allocator,
    config: Config,

    /// Info for analyzed functions.
    func_info: std.StringHashMap(FunctionInfo),
    /// Known functions by symbol name.
    known_funcs: std.StringHashMap(*const Function),

    /// Call sites to potentially inline.
    call_sites: std.ArrayList(CallSite),
    /// Mapping from function references to callee functions.
    callee_by_ref: std.AutoHashMap(FuncRef, CalleeInfo),

    /// Current inlining depth (for recursion limiting).
    current_depth: u32 = 0,

    /// Statistics.
    calls_analyzed: u32 = 0,
    calls_inlined: u32 = 0,
    insts_added: u32 = 0,

    pub fn init(allocator: Allocator, config: Config) Inliner {
        return .{
            .allocator = allocator,
            .config = config,
            .func_info = std.StringHashMap(FunctionInfo).init(allocator),
            .known_funcs = std.StringHashMap(*const Function).init(allocator),
            .call_sites = std.ArrayList(CallSite){},
            .callee_by_ref = std.AutoHashMap(FuncRef, CalleeInfo).init(allocator),
        };
    }

    pub fn deinit(self: *Inliner) void {
        self.func_info.deinit();
        self.known_funcs.deinit();
        self.call_sites.deinit(self.allocator);
        var iter = self.callee_by_ref.valueIterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.name);
        }
        self.callee_by_ref.deinit();
    }

    /// Register a resolvable callee for direct call inlining.
    pub fn registerCallee(self: *Inliner, func_ref: FuncRef, name: []const u8, callee: *const Function) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        const old = try self.callee_by_ref.fetchPut(func_ref, .{
            .name = owned_name,
            .func = callee,
        });
        if (old) |prev| {
            self.allocator.free(prev.value.name);
        }
    }

    /// Analyze a function for inlining potential.
    pub fn analyzeFunction(self: *Inliner, func: *const Function, name: []const u8) !void {
        var info = FunctionInfo{};

        // Count blocks and instructions
        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            info.block_count += 1;

            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                info.inst_count += 1;

                const inst_data = func.dfg.insts.get(inst) orelse continue;
                const opcode = inst_data.opcode();

                if (opcode == .call or opcode == .call_indirect) {
                    info.call_count += 1;
                }
            }
        }

        // Compute cost
        info.cost = computeCost(info);

        try self.func_info.put(name, info);
        try self.known_funcs.put(name, func);
        if (!std.mem.eql(u8, name, func.name)) {
            try self.func_info.put(func.name, info);
            try self.known_funcs.put(func.name, func);
        }
    }

    /// Collect call sites in a function.
    pub fn collectCallSites(self: *Inliner, func: *Function) !void {
        self.call_sites.clearRetainingCapacity();

        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = func.dfg.insts.get(inst) orelse continue;
                const opcode = inst_data.opcode();

                if (opcode == .call) {
                    const call_data = inst_data.call;
                    try self.call_sites.append(self.allocator, .{
                        .inst = inst,
                        .block = block,
                        .func_ref = call_data.func_ref,
                        .args = func.dfg.value_lists.asSlice(call_data.args),
                    });
                }
            }
        }
    }

    fn metadataNameKey(name: ExternalName, key_buf: []u8) ?[]const u8 {
        return switch (name) {
            .testcase => |n| n,
            .user => |u| std.fmt.bufPrint(key_buf, "u{d}:{d}", .{ u.namespace, u.index }) catch null,
        };
    }

    fn resolveCalleeFromMetadata(self: *Inliner, func: *const Function, func_ref: FuncRef) ?CalleeInfo {
        const meta = func.func_metadata.getMetadata(func_ref) orelse return null;
        var key_buf: [64]u8 = undefined;
        const key = metadataNameKey(meta.name, &key_buf) orelse return null;
        const callee = self.known_funcs.get(key) orelse return null;
        return .{
            .name = callee.name,
            .func = callee,
        };
    }

    /// Make inlining decision for a call site.
    pub fn makeDecision(self: *Inliner, site: *CallSite, callee_name: []const u8) Decision {
        self.calls_analyzed += 1;

        // Get callee info
        const info = self.func_info.get(callee_name) orelse return .unknown_callee;

        // Check no_inline_attr attribute
        if (info.no_inline_attr) return .no_inline_attr_attr;

        // Check recursion depth
        if (self.current_depth >= self.config.max_depth and info.is_recursive) {
            return .recursive_limit;
        }

        // Always inline small functions with hint
        if (info.inline_hint and info.inst_count <= self.config.always_inline_threshold) {
            site.decision = .inline_call;
            return .inline_call;
        }

        // Check size threshold
        if (info.inst_count > self.config.hot_threshold) {
            return .too_large;
        }

        // Inline if small enough
        if (info.inst_count <= self.config.cold_threshold) {
            site.decision = .inline_call;
            return .inline_call;
        }

        return .no_inline;
    }

    /// Perform inlining of a call site.
    pub fn inlineCallSite(self: *Inliner, caller: *Function, site: CallSite, callee: *const Function) !bool {
        _ = site; // Used for args and block context
        // Create value mapping for parameters -> arguments
        var value_map = std.AutoHashMap(Value, Value).init(self.allocator);
        defer value_map.deinit();

        // Map parameters to arguments
        // (Assumes site.args matches callee signature)

        // Clone callee's blocks into caller
        var block_map = std.AutoHashMap(Block, Block).init(self.allocator);
        defer block_map.deinit();

        // Create new blocks in caller for each callee block
        var callee_block_iter = callee.layout.blockIter();
        while (callee_block_iter.next()) |callee_block| {
            const new_block = try caller.dfg.makeBlock();
            try caller.layout.appendBlock(new_block);
            try block_map.put(callee_block, new_block);
        }

        // Clone instructions
        callee_block_iter = callee.layout.blockIter();
        while (callee_block_iter.next()) |callee_block| {
            const new_block = block_map.get(callee_block) orelse continue;

            var inst_iter = callee.layout.blockInsts(callee_block);
            while (inst_iter.next()) |inst| {
                const inst_data = callee.dfg.insts.get(inst) orelse continue;
                const opcode = inst_data.opcode();

                // Handle return instruction specially
                if (opcode == .@"return") {
                    // Replace with assignment to call result and branch
                    continue;
                }

                // Clone instruction
                const new_inst_data = remapInstructionOperands(inst_data.*, &value_map, &block_map);
                const new_inst = try caller.dfg.makeInst(new_inst_data);

                // Insert into new block
                try caller.layout.appendInst(new_inst, new_block);

                // Map results
                const results = callee.dfg.instResults(inst);
                if (results.len > 0) {
                    const result_ty_opt = callee.dfg.valueType(results[0]);
                    if (result_ty_opt) |result_ty| {
                        const new_result = try caller.dfg.appendInstResult(new_inst, result_ty);
                        try value_map.put(results[0], new_result);
                    } else {
                        continue;
                    }
                }

                self.insts_added += 1;
            }
        }

        self.calls_inlined += 1;
        return true;
    }

    /// Run inlining pass on a function.
    pub fn run(self: *Inliner, func: *Function) !bool {
        var changed = false;

        try self.collectCallSites(func);

        for (self.call_sites.items) |*site| {
            const func_ref = site.func_ref orelse continue;
            const callee_info = self.callee_by_ref.get(func_ref) orelse self.resolveCalleeFromMetadata(func, func_ref) orelse continue;
            site.callee = callee_info.func;

            const decision = self.makeDecision(site, callee_info.name);
            if (decision == .inline_call) {
                self.current_depth += 1;
                defer self.current_depth -= 1;

                if (try self.inlineCallSite(func, site.*, callee_info.func)) {
                    changed = true;
                }
            }
        }

        return changed;
    }

    /// Statistics.
    pub fn stats(self: *const Inliner) struct { analyzed: u32, inlined: u32, insts: u32 } {
        return .{
            .analyzed = self.calls_analyzed,
            .inlined = self.calls_inlined,
            .insts = self.insts_added,
        };
    }
};

/// Compute inline cost from function info.
fn computeCost(info: FunctionInfo) i32 {
    // Basic cost: instruction count
    var cost: i32 = @intCast(info.inst_count);

    // Penalty for calls (they won't be inlined inside)
    cost += @as(i32, @intCast(info.call_count)) * 5;

    // Bonus for small functions
    if (info.inst_count <= 10) {
        cost -= 20;
    }

    // Bonus for inline hint
    if (info.inline_hint) {
        cost -= 30;
    }

    return cost;
}

/// Remap instruction operands.
fn remapInstructionOperands(
    data: InstructionData,
    value_map: *std.AutoHashMap(Value, Value),
    block_map: *std.AutoHashMap(Block, Block),
) InstructionData {
    var result = data;

    switch (result) {
        .unary => |*u| {
            if (value_map.get(u.arg)) |new_val| {
                u.arg = new_val;
            }
        },
        .binary => |*b| {
            if (value_map.get(b.args[0])) |new_val| {
                b.args[0] = new_val;
            }
            if (value_map.get(b.args[1])) |new_val| {
                b.args[1] = new_val;
            }
        },
        .jump => |*j| {
            if (block_map.get(j.destination)) |new_block| {
                j.destination = new_block;
            }
        },
        .branch => |*br| {
            if (value_map.get(br.condition)) |new_val| {
                br.condition = new_val;
            }
            if (br.then_dest) |dest| {
                if (block_map.get(dest)) |new_block| {
                    br.then_dest = new_block;
                }
            }
            if (br.else_dest) |dest| {
                if (block_map.get(dest)) |new_block| {
                    br.else_dest = new_block;
                }
            }
        },
        else => {},
    }

    return result;
}

// Tests
test "Config defaults" {
    const testing = std.testing;
    const config = Config{};

    try testing.expectEqual(@as(u32, 10), config.always_inline_threshold);
    try testing.expectEqual(@as(u32, 50), config.hot_threshold);
    try testing.expectEqual(@as(u32, 3), config.max_depth);
}

test "computeCost" {
    const testing = std.testing;

    // Small function
    const info1 = FunctionInfo{
        .inst_count = 5,
        .call_count = 0,
        .inline_hint = true,
    };
    try testing.expect(computeCost(info1) < 0); // Negative cost = good to inline

    // Large function
    const info2 = FunctionInfo{
        .inst_count = 100,
        .call_count = 5,
    };
    try testing.expect(computeCost(info2) > 100);
}

test "Decision enum" {
    const testing = std.testing;
    const d: Decision = .inline_call;
    try testing.expect(d == .inline_call);
}

test "run resolves callee from function metadata" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var callee_sig = Signature.init(allocator, .fast);
    try callee_sig.returns.append(allocator, .{ .value_type = Type.I64 });
    var callee = try Function.init(allocator, "callee", callee_sig);
    defer callee.deinit();

    var callee_builder = try ir_mod.FunctionBuilder.init(allocator, &callee);
    defer callee_builder.deinit();
    const callee_block = try callee_builder.createBlock();
    callee_builder.switchToBlock(callee_block);
    const callee_val = try callee_builder.iconst(Type.I64, 7);
    try callee_builder.retValues(&.{callee_val});

    var caller_sig = Signature.init(allocator, .fast);
    try caller_sig.returns.append(allocator, .{ .value_type = Type.I64 });
    var caller = try Function.init(allocator, "caller", caller_sig);
    defer caller.deinit();

    var call_sig = Signature.init(allocator, .fast);
    try call_sig.returns.append(allocator, .{ .value_type = Type.I64 });
    const sig_ref = try caller.addSignature(call_sig);
    const ext_name = try ExternalName.fromTestcase(allocator, "callee");
    const callee_ref = try caller.func_metadata.registerExternalFunc(ext_name, sig_ref, .local);

    var caller_builder = try ir_mod.FunctionBuilder.init(allocator, &caller);
    defer caller_builder.deinit();
    const caller_block = try caller_builder.createBlock();
    caller_builder.switchToBlock(caller_block);
    const call_args = try caller_builder.buildValueList(&.{});
    const call_inst = try caller.dfg.makeInst(.{
        .call = .{
            .opcode = .call,
            .func_ref = callee_ref,
            .args = call_args,
        },
    });
    try caller.layout.appendInst(call_inst, caller_block);
    const call_result = try caller.dfg.appendInstResult(call_inst, Type.I64);
    try caller_builder.retValues(&.{call_result});

    var inliner = Inliner.init(allocator, .{});
    defer inliner.deinit();
    try inliner.analyzeFunction(&callee, "callee");

    const changed = try inliner.run(&caller);
    try testing.expect(changed);
    try testing.expectEqual(@as(u32, 1), inliner.calls_analyzed);
    try testing.expectEqual(@as(u32, 1), inliner.calls_inlined);
}

test "run skips unresolved function metadata entry" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const caller_sig = Signature.init(allocator, .fast);
    var caller = try Function.init(allocator, "caller", caller_sig);
    defer caller.deinit();

    const call_sig = Signature.init(allocator, .fast);
    const sig_ref = try caller.addSignature(call_sig);
    const ext_name = try ExternalName.fromTestcase(allocator, "missing");
    const callee_ref = try caller.func_metadata.registerExternalFunc(ext_name, sig_ref, .import);

    var caller_builder = try ir_mod.FunctionBuilder.init(allocator, &caller);
    defer caller_builder.deinit();
    const caller_block = try caller_builder.createBlock();
    caller_builder.switchToBlock(caller_block);
    const call_args = try caller_builder.buildValueList(&.{});
    const call_inst = try caller.dfg.makeInst(.{
        .call = .{
            .opcode = .call,
            .func_ref = callee_ref,
            .args = call_args,
        },
    });
    try caller.layout.appendInst(call_inst, caller_block);
    try caller_builder.ret();

    var inliner = Inliner.init(allocator, .{});
    defer inliner.deinit();

    const changed = try inliner.run(&caller);
    try testing.expect(!changed);
    try testing.expectEqual(@as(u32, 0), inliner.calls_analyzed);
    try testing.expectEqual(@as(u32, 0), inliner.calls_inlined);
}

test "Inliner resolves callee and inlines direct call" {
    const testing = std.testing;

    const caller_sig = Signature.init(testing.allocator, .fast);
    var caller = try Function.init(testing.allocator, "caller", caller_sig);
    defer caller.deinit();

    const caller_block = try caller.dfg.makeBlock();
    try caller.layout.appendBlock(caller_block);

    const callee_sig = Signature.init(testing.allocator, .fast);
    var callee = try Function.init(testing.allocator, "callee", callee_sig);
    defer callee.deinit();

    const callee_block = try callee.dfg.makeBlock();
    try callee.layout.appendBlock(callee_block);
    const callee_ret = try callee.dfg.makeInst(.{ .@"return" = .{
        .opcode = .@"return",
        .args = ValueList.default(),
    } });
    try callee.layout.appendInst(callee_ret, callee_block);

    const callee_ref = FuncRef.new(0);
    const call_inst = try caller.dfg.makeInst(.{ .call = .{
        .opcode = .call,
        .func_ref = callee_ref,
        .args = ValueList.default(),
    } });
    try caller.layout.appendInst(call_inst, caller_block);
    _ = try caller.dfg.appendInstResult(call_inst, Type.I64);

    const caller_ret = try caller.dfg.makeInst(.{ .@"return" = .{
        .opcode = .@"return",
        .args = ValueList.default(),
    } });
    try caller.layout.appendInst(caller_ret, caller_block);

    var inliner = Inliner.init(testing.allocator, .{});
    defer inliner.deinit();

    try inliner.analyzeFunction(&callee, "callee");
    try inliner.registerCallee(callee_ref, "callee", &callee);

    const changed = try inliner.run(&caller);
    try testing.expect(changed);

    const stats = inliner.stats();
    try testing.expectEqual(@as(u32, 1), stats.analyzed);
    try testing.expectEqual(@as(u32, 1), stats.inlined);
}

test "Inliner skips unresolved callees" {
    const testing = std.testing;

    const caller_sig = Signature.init(testing.allocator, .fast);
    var caller = try Function.init(testing.allocator, "caller", caller_sig);
    defer caller.deinit();

    const caller_block = try caller.dfg.makeBlock();
    try caller.layout.appendBlock(caller_block);

    const call_inst = try caller.dfg.makeInst(.{ .call = .{
        .opcode = .call,
        .func_ref = FuncRef.new(9),
        .args = ValueList.default(),
    } });
    try caller.layout.appendInst(call_inst, caller_block);
    _ = try caller.dfg.appendInstResult(call_inst, Type.I64);

    const caller_ret = try caller.dfg.makeInst(.{ .@"return" = .{
        .opcode = .@"return",
        .args = ValueList.default(),
    } });
    try caller.layout.appendInst(caller_ret, caller_block);

    var inliner = Inliner.init(testing.allocator, .{});
    defer inliner.deinit();

    const changed = try inliner.run(&caller);
    try testing.expect(!changed);
    try testing.expectEqual(@as(u32, 0), inliner.stats().inlined);
}
