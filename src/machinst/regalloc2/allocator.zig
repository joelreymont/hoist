const Allocator = std.mem.Allocator;
SpillSlotSpillSlot;
const LiveRange = liveness.LiveRangeconstBundlePriority=u32;const SpillWeight = u32;
const MINIMAL_BUNDLE_SPILL_WEIGHT: SpillWeight = 1;

id    ranges: std.ArrayList(LiveRange),
    alloc: Allocation,
    spill_weight: SpillWeight,
    prio: BundlePriority,
    allocator: Allocator,
, id: u32idid            .ranges = .{},
            .alloc = .none,
            .spill_weight = MINIMAL_BUNDLE_SPILL_WEIGHT,
            .prio = 0,
            .allocator = allocator,
for (self.ranges.items) |*r| r.deinit();
        self.allocator    pub fn addRange(self: *LiveBundle, range: LiveRange) !void {
        try self.ranges.append(self.allocator, range);
const QueueEntry = struct {
    bundle_id: u32,
    prio: BundlePriority,
    hint: PhysReg,

    fn lessThan(_: void, a: QueueEntry, b: QueueEntry) std.math.Order {
        return std.math.order(b.prio, a.prio);
    }
};

pub const RegAllocator = struct {
queuestd.PriorityQueue(QueueEntry, void, QueueEntry.lessThan),
    avail_regs: std.ArrayList(PhysReg),
    preg_allocs: std.AutoHashMap(u8, ds.IntervalTree)u32spill_slotsstd.ArrayList(SpillSlot),
    next_spill_slot: u32    pub fn init(allocator: Allocator) RegAllocator {
.{},
            .queue = PriorityQueueQueueEntry, void, QueueEntry.lessThan).init(allocator, {}),
            .avail_regs = .{},
            .preg_allocs = std.AutoHashMap(u8, ds.IntervalTree{}spill_slots.{},
            .next_spill_slot = 0RegAllocatorself.allocator);
        self.queue.deinit();
        self.avail_regs.deinit(self.allocatorvarit = preg_allocs.valueIterator(;
        while (it.next())treetreepreg_allocsdeinitself.allocator);
        self.spill_slots.deinit(self.allocatorinitRegsRegAllocatorregs[]const PhysRegvoidavail_regsappendSliceself.allocator,regs)addBundleRegAllocatorbundleLiveBundleu32id@as(u32, @intCast(.len))trybundles.append(self.allocator, bundle)
        return id;
    }    pubfn queueBundle(self: *RegAllocator, bundle_id: u32, prio: BundlePriority) !void {
        try self.queue.add(.{
            .bundle_idbundle_id,
            prio= prio,
            hint = PhysReg.new0),
        }
    }    pub fn allocate(self: *RegAllocator) !void {
        while (self.queue.removeOrNull()) |entry| {
            try self.processBundle(entry.bundle_id, entry.hint);
        }
    }

    fn processBundle(self: *RegAllocator, bundle_id: u32, hint: PhysReg) !void {
        const bundle = &self.bundles.items[bundle_id];

        if (hint.index != 0) {
            if (self.tryAllocateToReg(bundle_id, hint)) {
                bundle.alloc = Allocation{ .reg = hint };
                try self.recordAllocation(bundle_id, hint);
                return;
            }
        }

        for (self.avail_regs.items) |preg| {
            if (self.tryAllocateToReg(bundle_id, preg)) {
                bundle.alloc = Allocation{ .reg = preg };
                try self.recordAllocation(bundle_id, preg);
                return;
            }
        }

        try self.spillBundle(bundle_id);
    }

    fn tryAllocateToReg(self: *RegAllocator, bundle_id: u32, preg: PhysReg) bool {
        const bundle = &self.bundles.items[bundle_id];

        const tree = self.preg_allocs.get(preg.index) orelse {
            return true;
        };

        for (bundle.ranges.items) |*lr| {
            for (lr.ranges.items) |inst_range| {
                var conflicts: std.ArrayList(usize) = .{};
                defer conflicts.deinit(self.allocator);

                tree.query(self.allocator, inst_range.start, inst_range.end, &conflicts) catch {
                    return false;
                };

                if (conflicts.items.len > 0) {
                    return false;
        return true;
recordAllocationRegAllocator, bundle_id: u32, preg: PhysRegconstbundle = &[bundle_id]        var tree = if (self.preg_allocs.getPtr(preg.index)) |t|
            t.*
        else blk: {
            const new_tree = ds.IntervalTree.init(self.allocator);
            try self.preg_allocs.put(preg.index, new_tree);
            break :blk self.preg_allocs.getPtr(preg.index).?.*;
        };
        forbundle.ranges.items |*lr| {
            for (lr.ranges.items) |inst_range|treeinsertinst_range.start, inst_range.end, bundle_id
        try self.preg_allocs.put(preg.index, tree);
    fn spillBundle(self: *RegAllocator, bundle_id: u32) !void {
        const bundle = &self.bundles.items[bundle_id];

        const slot = SpillSlot.new(self.next_spill_slot);
        self.next_spill_slot += 1;

        bundle.alloc = Allocation{ .stack = slot };
        try self.spilled.append(self.allocator, bundle_id);
        try self.spill_slots.append(self.allocator, slot);
    }

    pub fn getAllocation(self: *const RegAllocator, vreg: VReg) ?Allocation {
        for (self.bundles.items) |*bundle| {
            if (bundle.vreg.index == vreg.index) {
                return bundle.alloc;
            }
        }
        return null;
    }

    fn evictBundle(self: *RegAllocator, bundle_id: u32) !void {
        const bundle = &self.bundles.items[bundle_id];
        if (bundle.alloc != .reg) return;

        bundle.alloc = .none;
        try self.queueBundle(bundle_id, bundle.prio);
    }

    pub fn allocateSpilled(self: *RegAllocator) !void {
        for (self.spilled.items) |bundle_id| {
            _ = bundle_id;
        }
    }
test "RegAllocator init" {
    raRegAllocatordefer radeinit()int_regs[_]PhysReg{
        PhysRegnew,
        PhysReg.new(1),
        PhysReg.new(2),
    }rainitRegs&int_regsRegAllocatoraddBundleraRegAllocatorraconstvreg = VReg.new(0);
    constvregidrabundletestingexpectEqual@as(u32, id)
}test "RegAllocator queueBundle" {
    var ra = RegAllocator.init(testing.allocator);
    defer ra.deinit();

    const vreg = VReg.new(0);
    const bundle = LiveBundle.init(testing.allocator, 0, vreg);

    const id = try ra.addBundle(bundle);
    try ra.queueBundle(id, 100);

    const entry = ra.queue.removeOrNull();
    try testing.expect(entry != null);
    try testing.expectEqual(id, entry.?.bundle_id);
    try testing.expectEqual(@as(BundlePriority, 100), entry.?.prio);
