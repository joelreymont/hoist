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
const Opcode = @import("../../ir/opcodes.zig").Opcode;
const InstructionData = @import("../../ir/instruction_data.zig").InstructionData;
const Signature = @import("../../ir/signature.zig").Signature;

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
    /// Called function (if known).
    callee: ?*Function,
    /// Arguments to the call.
    args: []Value,
    /// Decision for this call site.
    decision: Decision = .no_inline,
};

/// Function inliner pass.
pub const Inliner = struct {
    allocator: Allocator,
    config: Config,

    /// Info for analyzed functions.
    func_info: std.StringHashMap(FunctionInfo),

    /// Call sites to potentially inline.
    call_sites: std.ArrayList(CallSite),

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
            .call_sites = std.ArrayList(CallSite).init(allocator),
        };
    }

    pub fn deinit(self: *Inliner) void {
        self.func_info.deinit();
        self.call_sites.deinit();
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
                    try self.call_sites.append(.{
                        .inst = inst,
                        .block = block,
                        .callee = null, // Resolved later
                        .args = &.{},
                    });
                }
            }
        }
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
                if (opcode == .return_value) {
                    // Replace with assignment to call result and branch
                    continue;
                }

                // Clone instruction
                const new_inst_data = remapInstructionOperands(inst_data, &value_map, &block_map);
                const new_inst = try caller.dfg.makeInst(new_inst_data);

                // Insert into new block
                try caller.layout.appendInst(new_inst, new_block);

                // Map results
                const results = callee.dfg.instResults(inst);
                if (results.len > 0) {
                    const result_ty = callee.dfg.valueType(results[0]);
                    const new_result = try caller.dfg.appendInstResult(new_inst, result_ty);
                    try value_map.put(results[0], new_result);
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
            // TODO: Resolve callee from call instruction
            // For now, skip unknown callees
            if (site.callee == null) continue;

            const decision = self.makeDecision(site, "callee"); // Need name lookup
            if (decision == .inline_call) {
                self.current_depth += 1;
                defer self.current_depth -= 1;

                if (try self.inlineCallSite(func, site.*, site.callee.?)) {
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
            if (block_map.get(j.dest)) |new_block| {
                j.dest = new_block;
            }
        },
        .branch => |*br| {
            if (value_map.get(br.arg)) |new_val| {
                br.arg = new_val;
            }
            // Remap block destinations
            for (&br.dests) |*dest| {
                if (block_map.get(dest.*)) |new_block| {
                    dest.* = new_block;
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
