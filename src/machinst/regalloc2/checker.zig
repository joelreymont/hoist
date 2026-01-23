const std = @import("std");
const types = @import("types.zig");
const api = @import("api.zig");
const Allocator_mem = std.mem.Allocator;
const VReg = types.VReg;
const PhysReg = types.PhysReg;
const Allocation = types.Allocation;
const RegAllocAdapter = api.RegAllocAdapter;

pub const CheckerError = union(enum) {
    unknown_val_in_alloc: struct { inst_idx: u32, op_idx: u32, alloc: Allocation },
    incorrect_vals_in_alloc: struct { inst_idx: u32, op_idx: u32, alloc: Allocation },
    constraint_violated: struct { inst_idx: u32, op_idx: u32, alloc: Allocation },
    alloc_not_reg: struct { inst_idx: u32, op_idx: u32, alloc: Allocation },
    alloc_not_fixed: struct { inst_idx: u32, op_idx: u32, alloc: Allocation, expected: PhysReg },
    stack_to_stack: struct { into: Allocation, from: Allocation },
};

const CheckerValue = union(enum) {
    universe,
    vregs: std.AutoHashMap(VReg, void),

    fn deinit(self: *CheckerValue, mem: Allocator_mem) void {
        switch (self.*) {
            .universe => {},
            .vregs => |*v| v.deinit(),
        }
    }

    fn meet(self: *CheckerValue, other: *const CheckerValue, mem: Allocator_mem) !void {
        switch (self.*) {
            .universe => {
                if (other.* == .vregs) {
                    var new = std.AutoHashMap(VReg, void).init(mem);
                    var it = other.vregs.keyIterator();
                    while (it.next()) |k| {
                        try new.put(k.*, {});
                    }
                    self.* = .{ .vregs = new };
                }
            },
            .vregs => |*v| {
                if (other.* == .vregs) {
                    var keys = std.ArrayList(VReg).init(mem);
                    defer keys.deinit();
                    var it = v.keyIterator();
                    while (it.next()) |k| {
                        if (!other.vregs.contains(k.*)) {
                            try keys.append(k.*);
                        }
                    }
                    for (keys.items) |k| {
                        _ = v.remove(k);
                    }
                }
            },
        }
    }

    fn fromVReg(mem: Allocator_mem, vreg: VReg) !CheckerValue {
        var v = std.AutoHashMap(VReg, void).init(mem);
        try v.put(vreg, {});
        return .{ .vregs = v };
    }

    fn removeVReg(self: *CheckerValue, vreg: VReg) void {
        switch (self.*) {
            .universe => unreachable,
            .vregs => |*v| _ = v.remove(vreg),
        }
    }

    fn empty(mem: Allocator_mem) CheckerValue {
        return .{ .vregs = std.AutoHashMap(VReg, void).init(mem) };
    }

    fn contains(self: *const CheckerValue, vreg: VReg) bool {
        return switch (self.*) {
            .universe => true,
            .vregs => |*v| v.contains(vreg),
        };
    }
};

const CheckerState = struct {
    allocs: std.AutoHashMap(Allocation, CheckerValue),

    fn init(mem: Allocator_mem) CheckerState {
        return .{ .allocs = std.AutoHashMap(Allocation, CheckerValue).init(mem) };
    }

    fn deinit(self: *CheckerState, mem: Allocator_mem) void {
        var it = self.allocs.valueIterator();
        while (it.next()) |v| {
            var val = v.*;
            val.deinit(mem);
        }
        self.allocs.deinit();
    }

    fn getVal(self: *const CheckerState, alloc: Allocation) ?*const CheckerValue {
        return self.allocs.getPtr(alloc);
    }

    fn setVal(self: *CheckerState, alloc: Allocation, val: CheckerValue) !void {
        try self.allocs.put(alloc, val);
    }

    fn removeVReg(self: *CheckerState, vreg: VReg) void {
        var it = self.allocs.valueIterator();
        while (it.next()) |v| {
            v.removeVReg(vreg);
        }
    }

    fn removeVal(self: *CheckerState, alloc: Allocation) void {
        _ = self.allocs.remove(alloc);
    }
};

pub const Checker = struct {
    mem: Allocator_mem,
    adapter: *RegAllocAdapter,
    state: CheckerState,
    errors: std.ArrayList(CheckerError),

    pub fn init(mem: Allocator_mem, adapter: *RegAllocAdapter) Checker {
        return .{
            .mem = mem,
            .adapter = adapter,
            .state = CheckerState.init(mem),
            .errors = std.ArrayList(CheckerError).init(mem),
        };
    }

    pub fn deinit(self: *Checker) void {
        self.state.deinit(self.mem);
        self.errors.deinit();
    }

    pub fn verify(self: *Checker) !bool {
        const num_insts = self.adapter.num_insts;
        var inst_idx: u32 = 0;
        while (inst_idx < num_insts) : (inst_idx += 1) {
            try self.checkInst(inst_idx);
            try self.updateInst(inst_idx);
        }
        return self.errors.items.len == 0;
    }

    fn checkInst(self: *Checker, inst_idx: u32) !void {
        const ops = self.adapter.getOperands(inst_idx);
        for (ops, 0..) |op, op_idx| {
            const alloc = self.adapter.getAllocation(op.vreg) orelse {
                try self.errors.append(.{
                    .unknown_val_in_alloc = .{
                        .inst_idx = inst_idx,
                        .op_idx = @intCast(op_idx),
                        .alloc = Allocation.none,
                    },
                });
                continue;
            };

            const val = self.state.getVal(alloc) orelse {
                try self.errors.append(.{
                    .unknown_val_in_alloc = .{
                        .inst_idx = inst_idx,
                        .op_idx = @intCast(op_idx),
                        .alloc = alloc,
                    },
                });
                continue;
            };

            if (op.pos == .use or op.pos == .use_def) {
                try self.checkVal(inst_idx, @intCast(op_idx), alloc, val, op.vreg);
            }

            try self.checkConstraintOp(inst_idx, @intCast(op_idx), alloc, op.constraint);
        }
    }

    fn updateInst(self: *Checker, inst_idx: u32) !void {
        const ops = self.adapter.getOperands(inst_idx);
        for (ops) |op| {
            if (op.pos == .def or op.pos == .use_def) {
                self.state.removeVReg(op.vreg);
                const alloc = self.adapter.getAllocation(op.vreg) orelse continue;
                try self.state.setVal(alloc, try CheckerValue.fromVReg(self.mem, op.vreg));
            }
        }
    }

    fn checkVal(
        self: *Checker,
        inst_idx: u32,
        op_idx: u32,
        alloc: Allocation,
        val: *const CheckerValue,
        vreg: VReg,
    ) !void {
        if (!val.contains(vreg)) {
            try self.errors.append(.{
                .incorrect_vals_in_alloc = .{
                    .inst_idx = inst_idx,
                    .op_idx = op_idx,
                    .alloc = alloc,
                },
            });
        }
    }

    fn checkConstraintOp(
        self: *Checker,
        inst_idx: u32,
        op_idx: u32,
        alloc: Allocation,
        constraint: types.Operand.Constraint,
    ) !void {
        switch (constraint) {
            .any_reg => {},
            .fixed_reg => {
                if (!alloc.isReg()) {
                    try self.errors.append(.{
                        .alloc_not_reg = .{
                            .inst_idx = inst_idx,
                            .op_idx = op_idx,
                            .alloc = alloc,
                        },
                    });
                }
            },
            .stack => {
                if (!alloc.isStack()) {
                    try self.errors.append(.{
                        .constraint_violated = .{
                            .inst_idx = inst_idx,
                            .op_idx = op_idx,
                            .alloc = alloc,
                        },
                    });
                }
            },
            .reuse => {},
        }
    }
};
