const std = @import("std");
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;

const root = @import("../root.zig");
const ir = @import("../ir.zig");
const Function = ir.Function;
const cfg_mod = @import("cfg.zig");
const Block = root.entities.Block;
const Value = root.entities.Value;
const Type = root.types.Type;
const Inst = root.entities.Inst;

/// Variable handle for SSA construction.
pub const Variable = enum(u32) { _ };

/// SSA builder implementing on-demand phi insertion.
/// Based on Braun et al. (2013) "Simple and Efficient Construction of SSA Form".
pub const SSABuilder = struct {
    alloc: Allocator,

    /// Variable definitions per block
    variables: AutoHashMap(Variable, AutoHashMap(Block, Value)),

    /// Sealed status per block
    sealed: AutoHashMap(Block, BlockState),

    /// Pending phi resolutions
    calls: ArrayList(Call),

    /// Results stack
    results: ArrayList(Value),

    const BlockState = struct {
        sealed: bool,
        undef_vars: ArrayList(Variable),
    };

    const Call = union(enum) {
        use_var: struct { variable: Variable, ty: Type, block: Block },
        finish_preds: struct { sentinel: Value, dest: Block },
    };

    fn cfgFor(self: *SSABuilder, func: *Function) !*cfg_mod.ControlFlowGraph {
        if (func.cfg == null) {
            func.cfg = cfg_mod.ControlFlowGraph.init(self.alloc);
        }
        const cfg = &func.cfg.?;
        if (!cfg.valid) {
            try cfg.compute(func);
        }
        return cfg;
    }

    pub fn init(alloc: Allocator) !SSABuilder {
        return .{
            .alloc = alloc,
            .variables = AutoHashMap(Variable, AutoHashMap(Block, Value)).init(alloc),
            .sealed = AutoHashMap(Block, BlockState).init(alloc),
            .calls = ArrayList(Call){},
            .results = ArrayList(Value){},
        };
    }

    pub fn deinit(self: *SSABuilder) void {
        var it = self.variables.valueIterator();
        while (it.next()) |map| map.deinit();
        self.variables.deinit();

        var sit = self.sealed.valueIterator();
        while (sit.next()) |st| st.undef_vars.deinit(self.alloc);
        self.sealed.deinit();

        self.calls.deinit(self.alloc);
        self.results.deinit(self.alloc);
    }

    pub fn defVar(self: *SSABuilder, variable: Variable, val: Value, block: Block) !void {
        const gop = try self.variables.getOrPut(variable);
        if (!gop.found_existing) {
            gop.value_ptr.* = AutoHashMap(Block, Value).init(self.alloc);
        }
        try gop.value_ptr.put(block, val);
    }

    pub fn useVar(self: *SSABuilder, func: *Function, variable: Variable, ty: Type, block: Block) !Value {
        try self.useVarNonlocal(func, variable, ty, block);
        return try self.runStateMachine(func);
    }

    pub fn sealBlock(self: *SSABuilder, func: *Function, block: Block) !void {
        const gop = try self.sealed.getOrPut(block);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{ .sealed = false, .undef_vars = ArrayList(Variable){} };
        }

        if (gop.value_ptr.sealed) return;
        gop.value_ptr.sealed = true;

        const undef = gop.value_ptr.undef_vars.items;
        for (undef) |variable| {
            if (self.variables.get(variable)) |var_defs| {
                if (var_defs.get(block)) |sentinel| {
                    const ty = func.dfg.valueType(sentinel).?;
                    try self.beginPredsLookup(func, variable, ty, block, sentinel);
                }
            }
        }
        gop.value_ptr.undef_vars.clearRetainingCapacity();
    }

    fn useVarNonlocal(self: *SSABuilder, func: *Function, variable: Variable, ty: Type, block: Block) !void {
        if (self.variables.get(variable)) |var_defs| {
            if (var_defs.get(block)) |val| {
                try self.results.append(self.alloc, val);
                return;
            }
        }
        try self.findVar(func, variable, ty, block);
    }

    fn findVar(self: *SSABuilder, func: *Function, variable: Variable, ty: Type, block: Block) !void {
        const state = self.sealed.get(block);
        if (state == null or !state.?.sealed) {
            const sentinel = try func.dfg.appendBlockParam(block, ty);
            try self.defVar(variable, sentinel, block);

            const gop = try self.sealed.getOrPut(block);
            if (!gop.found_existing) {
                gop.value_ptr.* = .{ .sealed = false, .undef_vars = ArrayList(Variable){} };
            }
            try gop.value_ptr.undef_vars.append(self.alloc, variable);
            try self.results.append(self.alloc, sentinel);
            return;
        }

        const cfg = try self.cfgFor(func);
        const pred_count = cfg.predecessorCount(block);
        if (pred_count == 0) {
            const zero = try func.dfg.makeConst(0);
            try self.defVar(variable, zero, block);
            try self.results.append(self.alloc, zero);
        } else if (pred_count == 1) {
            var pred_iter = cfg.predecessors(block);
            const pred_block = pred_iter.next().?.block;
            try self.useVarNonlocal(func, variable, ty, pred_block);
        } else {
            const sentinel = try func.dfg.appendBlockParam(block, ty);
            try self.defVar(variable, sentinel, block);
            try self.beginPredsLookup(func, variable, ty, block, sentinel);
        }
    }

    fn beginPredsLookup(self: *SSABuilder, func: *Function, variable: Variable, ty: Type, block: Block, sentinel: Value) !void {
        const cfg = try self.cfgFor(func);
        var pred_iter = cfg.predecessors(block);
        while (pred_iter.next()) |pred| {
            try self.calls.append(self.alloc, .{ .use_var = .{ .variable = variable, .ty = ty, .block = pred.block } });
        }
        try self.calls.append(self.alloc, .{ .finish_preds = .{ .sentinel = sentinel, .dest = block } });
    }

    fn finishPredsLookup(self: *SSABuilder, func: *Function, sentinel: Value, dest: Block) !Value {
        const cfg = try self.cfgFor(func);
        const pred_count = cfg.predecessorCount(dest);
        const pred_vals = self.results.items[self.results.items.len - pred_count ..];

        var unique: ?Value = null;
        var all_same = true;
        for (pred_vals) |pv| {
            const resolved = func.dfg.resolveAliases(pv);
            if (resolved.index == sentinel.index) continue;

            if (unique) |u| {
                if (u.index != resolved.index) {
                    all_same = false;
                    break;
                }
            } else {
                unique = resolved;
            }
        }

        if (all_same and unique != null) {
            func.dfg.removeBlockParam(sentinel);
            func.dfg.changeToAlias(sentinel, unique.?);
            self.results.shrinkRetainingCapacity(self.results.items.len - pred_count);
            return unique.?;
        }

        var pred_iter = cfg.predecessors(dest);
        var idx: usize = 0;
        while (pred_iter.next()) |pred| : (idx += 1) {
            const val = pred_vals[idx];
            try func.dfg.appendBranchArg(pred.inst, val);
        }

        self.results.shrinkRetainingCapacity(self.results.items.len - pred_count);
        return sentinel;
    }

    fn runStateMachine(self: *SSABuilder, func: *Function) !Value {
        while (self.calls.popOrNull()) |call| {
            switch (call) {
                .use_var => |uv| try self.useVarNonlocal(func, uv.variable, uv.ty, uv.block),
                .finish_preds => |fp| {
                    const val = try self.finishPredsLookup(func, fp.sentinel, fp.dest);
                    try self.results.append(self.alloc, val);
                },
            }
        }
        return self.results.pop().?;
    }
};

// Tests require CFG integration with Function struct.
// See: hoist-wire-ssa-builder-80d7576f dot for wiring.
