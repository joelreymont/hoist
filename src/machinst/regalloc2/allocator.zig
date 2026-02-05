const std = @import("std");
const types = @import("types.zig");
const api = @import("api.zig");
const liveness = @import("liveness.zig");
const Allocator_mem = std.mem.Allocator;
const VReg = types.VReg;
const PhysReg = types.PhysReg;
const Allocation = types.Allocation;
const RegAllocAdapter = api.RegAllocAdapter;
const LivenessInfo = liveness.LivenessInfo;
const SpillSlot = types.SpillSlot;
const testing = std.testing;

pub const Allocator = struct {
    mem: Allocator_mem,
    adapter: *RegAllocAdapter,
    int_pregs: std.ArrayList(PhysReg),
    fp_pregs: std.ArrayList(PhysReg),
    active_int: std.AutoHashMap(VReg, PhysReg),
    active_fp: std.AutoHashMap(VReg, PhysReg),
    spills: std.AutoHashMap(VReg, u32),
    next_spill: u32,

    pub fn init(mem: Allocator_mem, adapter: *RegAllocAdapter) !Allocator {
        var int_pregs = std.ArrayList(PhysReg).init(mem);
        var fp_pregs = std.ArrayList(PhysReg).init(mem);

        var i: u8 = 0;
        while (i < 31) : (i += 1) {
            try int_pregs.append(PhysReg.new(i));
        }
        i = 0;
        while (i < 32) : (i += 1) {
            try fp_pregs.append(PhysReg.new(32 + i));
        }

        return .{
            .mem = mem,
            .adapter = adapter,
            .int_pregs = int_pregs,
            .fp_pregs = fp_pregs,
            .active_int = std.AutoHashMap(VReg, PhysReg).init(mem),
            .active_fp = std.AutoHashMap(VReg, PhysReg).init(mem),
            .spills = std.AutoHashMap(VReg, u32).init(mem),
            .next_spill = 0,
        };
    }

    pub fn deinit(self: *Allocator) void {
        self.int_pregs.deinit();
        self.fp_pregs.deinit();
        self.active_int.deinit();
        self.active_fp.deinit();
        self.spills.deinit();
    }

    pub fn run(self: *Allocator, live: *const LivenessInfo) !void {
        _ = live;

        var vreg_idx: u32 = 0;
        while (vreg_idx < self.adapter.num_vregs) : (vreg_idx += 1) {
            const vreg = VReg.new(vreg_idx);
            const is_fp = false;

            if (is_fp) {
                if (self.active_fp.count() < self.fp_pregs.items.len) {
                    const preg = self.fp_pregs.items[self.active_fp.count()];
                    try self.active_fp.put(vreg, preg);
                    try self.adapter.setAllocation(vreg, Allocation{ .reg = preg });
                } else {
                    const slot = self.next_spill;
                    self.next_spill += 8;
                    try self.spills.put(vreg, slot);
                    try self.adapter.setAllocation(vreg, Allocation{ .stack = SpillSlot.new(slot) });
                }
            } else {
                if (self.active_int.count() < self.int_pregs.items.len) {
                    const preg = self.int_pregs.items[self.active_int.count()];
                    try self.active_int.put(vreg, preg);
                    try self.adapter.setAllocation(vreg, Allocation{ .reg = preg });
                } else {
                    const slot = self.next_spill;
                    self.next_spill += 8;
                    try self.spills.put(vreg, slot);
                    try self.adapter.setAllocation(vreg, Allocation{ .stack = SpillSlot.new(slot) });
                }
            }
        }
    }
};

test "Allocator run allocates vregs discovered from operands" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    try adapter.addOperand(types.Operand.init(types.VReg.new(0), .any_reg, .use));
    try adapter.addOperand(types.Operand.init(types.VReg.new(3), .any_reg, .def));

    var live = LivenessInfo.init(testing.allocator);
    defer live.deinit();

    var alloc = try Allocator.init(testing.allocator, &adapter);
    defer alloc.deinit();

    try alloc.run(&live);

    try testing.expectEqual(@as(u32, 4), adapter.num_vregs);
    try testing.expect(adapter.getAllocation(types.VReg.new(0)) != null);
    try testing.expect(adapter.getAllocation(types.VReg.new(3)) != null);
}

test "Allocator run spills when vregs exceed integer preg count" {
    var adapter = RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();

    var i: u32 = 0;
    while (i < 40) : (i += 1) {
        try adapter.addOperand(types.Operand.init(types.VReg.new(i), .any_reg, .use));
    }

    var live = LivenessInfo.init(testing.allocator);
    defer live.deinit();

    var alloc = try Allocator.init(testing.allocator, &adapter);
    defer alloc.deinit();

    try alloc.run(&live);

    try testing.expect(alloc.next_spill > 0);
    try testing.expect(adapter.getAllocation(types.VReg.new(39)).?.isStack());
}
