//! A forest of B+-trees.
//!
//! Provides ordered maps and sets optimized for compiler data structures:
//! - Keys/values are small and copyable (optimized for 32-bit types)
//! - Empty trees have minimal 32-bit footprint
//! - All trees in a forest share a node pool and can be cleared in O(1)
//! - Cache-line sized nodes (64 bytes with 32-bit keys/values)
//!
//! Ported from cranelift-bforest.

const std = @import("std");
const Allocator = std.mem.Allocator;
const entity = @import("entity.zig");

/// Maximum branching factor of inner nodes.
/// Minimum outgoing edges is INNER_SIZE/2 = 4.
const INNER_SIZE: usize = 8;

/// Maximum path length from root to leaf.
/// With branching factor of 4, can hold 2^32 entries.
const MAX_PATH: usize = 16;

/// Node reference - an index into the node pool.
const Node = entity.EntityRef(u32, "node");

// ============================================================================
// Slice utilities
// ============================================================================

/// Insert `x` into slice `s` at position `i`, shifting elements right.
/// The last element is lost.
fn sliceInsert(comptime T: type, s: []T, i: usize, x: T) void {
    var j = s.len - 1;
    while (j > i) : (j -= 1) {
        s[j] = s[j - 1];
    }
    s[i] = x;
}

/// Shift elements in slice `s` left by `n` positions.
fn sliceShift(comptime T: type, s: []T, n: usize) void {
    for (0..s.len - n) |j| {
        s[j] = s[j + n];
    }
}

// ============================================================================
// Node Data
// ============================================================================

/// Compute optimal split position for a full node.
fn splitPos(len: usize, ins: usize) usize {
    if (ins <= len / 2) {
        return len / 2;
    } else {
        return (len + 1) / 2;
    }
}

/// Result of removing an entry from a node.
const Removed = enum {
    /// Node is healthy after removal.
    healthy,
    /// Removed the rightmost entry, node still healthy.
    rightmost,
    /// Node has underflowed, needs rebalancing.
    underflow,
    /// Node is now empty.
    empty,

    fn new(removed: usize, new_size: usize, capacity: usize) Removed {
        if (2 * new_size >= capacity) {
            if (removed == new_size) {
                return .rightmost;
            } else {
                return .healthy;
            }
        } else if (new_size > 0) {
            return .underflow;
        } else {
            return .empty;
        }
    }
};

/// B+-tree node parameterized by key/value types and leaf capacity.
pub fn NodeData(comptime K: type, comptime V: type, comptime LEAF_SIZE: usize) type {
    return union(enum) {
        const Self = @This();

        inner: struct {
            size: u8,
            keys: [INNER_SIZE - 1]K,
            tree: [INNER_SIZE]Node,
        },
        leaf: struct {
            size: u8,
            keys: [LEAF_SIZE]K,
            vals: [LEAF_SIZE]V,
        },
        free: struct {
            next: ?Node,
        },

        pub fn isFree(self: Self) bool {
            return self == .free;
        }

        /// Number of entries (subtrees for inner, kv-pairs for leaf).
        pub fn entries(self: Self) usize {
            return switch (self) {
                .inner => |n| @as(usize, n.size) + 1,
                .leaf => |n| @as(usize, n.size),
                .free => unreachable,
            };
        }

        /// Create inner node with single key separating two subtrees.
        pub fn makeInner(left: Node, key: K, right: Node) Self {
            var tree: [INNER_SIZE]Node = [_]Node{right} ** INNER_SIZE;
            tree[0] = left;
            return .{ .inner = .{
                .size = 1,
                .keys = [_]K{key} ** (INNER_SIZE - 1),
                .tree = tree,
            } };
        }

        /// Create leaf node with single key-value pair.
        pub fn makeLeaf(key: K, value: V) Self {
            return .{ .leaf = .{
                .size = 1,
                .keys = [_]K{key} ** LEAF_SIZE,
                .vals = [_]V{value} ** LEAF_SIZE,
            } };
        }

        /// Get (keys, trees) slices from inner node.
        pub fn unwrapInner(self: *const Self) struct { []const K, []const Node } {
            const n = &self.inner;
            const size = @as(usize, n.size);
            return .{ n.keys[0..size], n.tree[0 .. size + 1] };
        }

        /// Get mutable inner node data.
        pub fn unwrapInnerMut(self: *Self) struct { []K, []Node, *u8 } {
            const n = &self.inner;
            return .{ &n.keys, &n.tree, &n.size };
        }

        /// Get (keys, vals) slices from leaf node.
        pub fn unwrapLeaf(self: *const Self) struct { []const K, []const V } {
            const n = &self.leaf;
            const size = @as(usize, n.size);
            return .{ n.keys[0..size], n.vals[0..size] };
        }

        /// Get mutable leaf slices.
        pub fn unwrapLeafMut(self: *Self) struct { []K, []V, *u8 } {
            const n = &self.leaf;
            return .{ &n.keys, &n.vals, &n.size };
        }

        /// Get critical key (first key) from leaf.
        pub fn leafCritKey(self: *const Self) K {
            std.debug.assert(self.leaf.size > 0);
            return self.leaf.keys[0];
        }

        /// Try to insert (key, node) at position in inner node.
        /// Returns false if node is full.
        pub fn tryInnerInsert(self: *Self, index: usize, key: K, node: Node) bool {
            const n = &self.inner;
            const sz = @as(usize, n.size);
            std.debug.assert(sz <= n.keys.len);
            std.debug.assert(index <= sz);

            if (sz >= n.keys.len) return false;

            n.size = @intCast(sz + 1);
            sliceInsert(K, n.keys[0 .. sz + 1], index, key);
            sliceInsert(Node, n.tree[1 .. sz + 2], index, node);
            return true;
        }

        /// Try to insert (key, value) at position in leaf node.
        /// Returns false if node is full.
        pub fn tryLeafInsert(self: *Self, index: usize, key: K, value: V) bool {
            const n = &self.leaf;
            const sz = @as(usize, n.size);
            std.debug.assert(sz <= n.keys.len);
            std.debug.assert(index <= sz);

            if (sz >= n.keys.len) return false;

            n.size = @intCast(sz + 1);
            sliceInsert(K, n.keys[0 .. sz + 1], index, key);
            sliceInsert(V, n.vals[0 .. sz + 1], index, value);
            return true;
        }

        /// Remove subtree at index from inner node.
        pub fn innerRemove(self: *Self, index: usize) Removed {
            const n = &self.inner;
            const ents = @as(usize, n.size) + 1;
            std.debug.assert(ents <= n.tree.len);
            std.debug.assert(index < ents);

            n.size = @intCast(@as(isize, @intCast(ents)) - 2);
            if (ents > 1) {
                const key_start = if (index > 0) index - 1 else 0;
                sliceShift(K, n.keys[key_start .. ents - 1], 1);
            }
            sliceShift(Node, n.tree[index..ents], 1);
            return Removed.new(index, ents - 1, n.tree.len);
        }

        /// Remove key-value pair at index from leaf node.
        pub fn leafRemove(self: *Self, index: usize) Removed {
            const n = &self.leaf;
            const sz = @as(usize, n.size);
            n.size -= 1;
            sliceShift(K, n.keys[index..sz], 1);
            sliceShift(V, n.vals[index..sz], 1);
            return Removed.new(index, sz - 1, n.keys.len);
        }

        /// Split a full node, returning the RHS data and critical key.
        pub fn split(self: *Self, insert_index: usize) SplitOff(K, V, LEAF_SIZE) {
            return switch (self.*) {
                .inner => |*n| self.splitInner(n, insert_index),
                .leaf => |*n| self.splitLeaf(n, insert_index),
                .free => unreachable,
            };
        }

        fn splitInner(self: *Self, n: *@TypeOf(self.inner), insert_index: usize) SplitOff(K, V, LEAF_SIZE) {
            std.debug.assert(n.size == n.keys.len);

            const l_ents = splitPos(n.tree.len, insert_index + 1);
            const r_ents = n.tree.len - l_ents;

            // Truncate LHS
            n.size = @intCast(l_ents - 1);

            // Copy to RHS
            var r_keys = n.keys;
            @memcpy(r_keys[0 .. r_ents - 1], n.keys[l_ents..]);

            var r_tree = n.tree;
            @memcpy(r_tree[0..r_ents], n.tree[l_ents..]);

            return .{
                .lhs_entries = l_ents,
                .rhs_entries = r_ents,
                .crit_key = n.keys[l_ents - 1],
                .rhs_data = .{ .inner = .{
                    .size = @intCast(r_ents - 1),
                    .keys = r_keys,
                    .tree = r_tree,
                } },
            };
        }

        fn splitLeaf(self: *Self, n: *@TypeOf(self.leaf), insert_index: usize) SplitOff(K, V, LEAF_SIZE) {
            std.debug.assert(n.size == n.keys.len);

            const l_size = splitPos(n.keys.len, insert_index);
            const r_size = n.keys.len - l_size;

            // Truncate LHS
            n.size = @intCast(l_size);

            // Copy to RHS
            var r_keys = n.keys;
            @memcpy(r_keys[0..r_size], n.keys[l_size..]);

            var r_vals = n.vals;
            @memcpy(r_vals[0..r_size], n.vals[l_size..]);

            return .{
                .lhs_entries = l_size,
                .rhs_entries = r_size,
                .crit_key = n.keys[l_size],
                .rhs_data = .{ .leaf = .{
                    .size = @intCast(r_size),
                    .keys = r_keys,
                    .vals = r_vals,
                } },
            };
        }

        /// Balance this underflowed node with its right sibling.
        /// Returns new critical key if entries were redistributed, null if merged.
        pub fn balance(self: *Self, crit_key: K, rhs: *Self) ?K {
            return switch (self.*) {
                .inner => self.balanceInner(crit_key, rhs),
                .leaf => self.balanceLeaf(crit_key, rhs),
                .free => unreachable,
            };
        }

        fn balanceInner(self: *Self, crit_key: K, rhs: *Self) ?K {
            const l = &self.inner;
            const r = &rhs.inner;
            const l_ents = @as(usize, l.size) + 1;
            const r_ents = @as(usize, r.size) + 1;
            const ents = l_ents + r_ents;

            if (ents <= r.tree.len) {
                // Merge: all entries fit in RHS
                l.size = 0;
                l.keys[l_ents - 1] = crit_key;
                @memcpy(l.keys[l_ents .. ents - 1], r.keys[0 .. r_ents - 1]);
                @memcpy(r.keys[0 .. ents - 1], l.keys[0 .. ents - 1]);
                @memcpy(l.tree[l_ents..ents], r.tree[0..r_ents]);
                @memcpy(r.tree[0..ents], l.tree[0..ents]);
                r.size = @intCast(ents - 1);
                return null;
            } else {
                // Redistribute
                const r_goal = ents / 2;
                const l_goal = ents - r_goal;

                l.keys[l_ents - 1] = crit_key;
                @memcpy(l.keys[l_ents .. l_goal - 1], r.keys[0 .. l_goal - 1 - l_ents]);
                @memcpy(l.tree[l_ents..l_goal], r.tree[0 .. l_goal - l_ents]);
                l.size = @intCast(l_goal - 1);

                const new_crit = r.keys[r_ents - r_goal - 1];
                sliceShift(K, r.keys[0 .. r_ents - 1], r_ents - r_goal);
                sliceShift(Node, r.tree[0..r_ents], r_ents - r_goal);
                r.size = @intCast(r_goal - 1);

                return new_crit;
            }
        }

        fn balanceLeaf(self: *Self, _: K, rhs: *Self) ?K {
            const l = &self.leaf;
            const r = &rhs.leaf;
            const l_ents = @as(usize, l.size);
            const r_ents = @as(usize, r.size);
            const ents = l_ents + r_ents;

            if (ents <= r.vals.len) {
                // Merge
                l.size = 0;
                @memcpy(l.keys[l_ents..ents], r.keys[0..r_ents]);
                @memcpy(r.keys[0..ents], l.keys[0..ents]);
                @memcpy(l.vals[l_ents..ents], r.vals[0..r_ents]);
                @memcpy(r.vals[0..ents], l.vals[0..ents]);
                r.size = @intCast(ents);
                return null;
            } else {
                // Redistribute
                const r_goal = ents / 2;
                const l_goal = ents - r_goal;

                @memcpy(l.keys[l_ents..l_goal], r.keys[0 .. l_goal - l_ents]);
                @memcpy(l.vals[l_ents..l_goal], r.vals[0 .. l_goal - l_ents]);
                l.size = @intCast(l_goal);

                sliceShift(K, r.keys[0..r_ents], r_ents - r_goal);
                sliceShift(V, r.vals[0..r_ents], r_ents - r_goal);
                r.size = @intCast(r_goal);

                return r.keys[0];
            }
        }
    };
}

fn SplitOff(comptime K: type, comptime V: type, comptime LEAF_SIZE: usize) type {
    return struct {
        lhs_entries: usize,
        rhs_entries: usize,
        crit_key: K,
        rhs_data: NodeData(K, V, LEAF_SIZE),
    };
}

// ============================================================================
// Node Pool
// ============================================================================

/// Pool of B+-tree nodes with free list.
pub fn NodePool(comptime K: type, comptime V: type, comptime LEAF_SIZE: usize) type {
    const ND = NodeData(K, V, LEAF_SIZE);

    return struct {
        const Self = @This();

        nodes: entity.PrimaryMap(Node, ND),
        freelist: ?Node,

        pub fn init(allocator: Allocator) Self {
            return .{
                .nodes = entity.PrimaryMap(Node, ND).init(allocator),
                .freelist = null,
            };
        }

        pub fn deinit(self: *Self) void {
            self.nodes.deinit();
        }

        pub fn clear(self: *Self) void {
            self.nodes.clear();
            self.freelist = null;
        }

        pub fn alloc(self: *Self, data: ND) !Node {
            std.debug.assert(!data.isFree());
            if (self.freelist) |node| {
                const next = self.nodes.getMutAssert(node).free.next;
                self.freelist = next;
                self.nodes.getMutAssert(node).* = data;
                return node;
            } else {
                return try self.nodes.push(data);
            }
        }

        pub fn free(self: *Self, node: Node) void {
            std.debug.assert(!self.nodes.getAssert(node).isFree());
            self.nodes.getMutAssert(node).* = .{ .free = .{ .next = self.freelist } };
            self.freelist = node;
        }

        pub fn freeTree(self: *Self, node: Node) void {
            if (self.nodes.getAssert(node).* == .inner) {
                const n = &self.nodes.getAssert(node).inner;
                const count = @as(usize, n.size) + 1;
                for (n.tree[0..count]) |child| {
                    self.freeTree(child);
                }
            }
            self.free(node);
        }

        pub fn get(self: *const Self, node: Node) *const ND {
            return self.nodes.getAssert(node);
        }

        pub fn getMut(self: *Self, node: Node) *ND {
            return self.nodes.getMutAssert(node);
        }
    };
}

// ============================================================================
// Comparator
// ============================================================================

/// Key comparator interface.
pub fn Comparator(comptime K: type) type {
    return struct {
        const Self = @This();

        cmpFn: *const fn (self: *const Self, a: K, b: K) std.math.Order,

        pub fn cmp(self: *const Self, a: K, b: K) std.math.Order {
            return self.cmpFn(self, a, b);
        }

        pub fn search(self: *const Self, key: K, slice: []const K) union(enum) { found: usize, not_found: usize } {
            var left: usize = 0;
            var right: usize = slice.len;
            while (left < right) {
                const mid = left + (right - left) / 2;
                switch (self.cmp(slice[mid], key)) {
                    .lt => left = mid + 1,
                    .gt => right = mid,
                    .eq => return .{ .found = mid },
                }
            }
            return .{ .not_found = left };
        }
    };
}

/// Default comparator for Ord types.
pub fn defaultComparator(comptime K: type) Comparator(K) {
    const S = struct {
        fn cmpFn(_: *const Comparator(K), a: K, b: K) std.math.Order {
            return std.math.order(a, b);
        }
    };
    return .{ .cmpFn = S.cmpFn };
}

// ============================================================================
// Path
// ============================================================================

/// Path from root to leaf in a B+-tree.
pub fn Path(comptime K: type, comptime V: type, comptime LEAF_SIZE: usize) type {
    const ND = NodeData(K, V, LEAF_SIZE);
    const Pool = NodePool(K, V, LEAF_SIZE);

    return struct {
        const Self = @This();

        size: usize = 0,
        node: [MAX_PATH]Node = [_]Node{Node.invalid} ** MAX_PATH,
        entry: [MAX_PATH]u8 = [_]u8{0} ** MAX_PATH,

        /// Search for key, returning value if found.
        pub fn find(self: *Self, key: K, root: Node, pool: *const Pool, comp: *const Comparator(K)) ?V {
            var node = root;
            var level: usize = 0;
            while (true) : (level += 1) {
                self.size = level + 1;
                self.node[level] = node;

                const data = pool.get(node);
                switch (data.*) {
                    .inner => |n| {
                        const keys = n.keys[0..n.size];
                        const i = switch (comp.search(key, keys)) {
                            .found => |idx| idx + 1,
                            .not_found => |idx| idx,
                        };
                        self.entry[level] = @intCast(i);
                        node = n.tree[i];
                    },
                    .leaf => |n| {
                        const keys = n.keys[0..n.size];
                        switch (comp.search(key, keys)) {
                            .found => |i| {
                                self.entry[level] = @intCast(i);
                                return n.vals[i];
                            },
                            .not_found => |i| {
                                self.entry[level] = @intCast(i);
                                return null;
                            },
                        }
                    },
                    .free => unreachable,
                }
            }
        }

        /// Move to first entry of tree, return (key, value).
        pub fn first(self: *Self, root: Node, pool: *const Pool) struct { K, V } {
            var node = root;
            var level: usize = 0;
            while (true) : (level += 1) {
                self.size = level + 1;
                self.node[level] = node;
                self.entry[level] = 0;

                const data = pool.get(node);
                switch (data.*) {
                    .inner => |n| node = n.tree[0],
                    .leaf => |n| return .{ n.keys[0], n.vals[0] },
                    .free => unreachable,
                }
            }
        }

        /// Get current leaf position.
        pub fn leafPos(self: *const Self) ?struct { Node, usize } {
            if (self.size == 0) return null;
            const i = self.size - 1;
            return .{ self.node[i], self.entry[i] };
        }

        fn leafNode(self: *const Self) Node {
            return self.node[self.size - 1];
        }

        fn leafEntry(self: *const Self) usize {
            return self.entry[self.size - 1];
        }

        /// Move to next entry.
        pub fn next(self: *Self, pool: *const Pool) ?struct { K, V } {
            const pos = self.leafPos() orelse return null;
            const node = pos[0];
            const e = pos[1];

            const data = pool.get(node);
            const kv = data.unwrapLeaf();
            if (e + 1 < kv[0].len) {
                self.entry[self.size - 1] += 1;
                return .{ kv[0][e + 1], kv[1][e + 1] };
            }

            // Move to next leaf
            const new_node = self.nextNode(self.size - 1, pool) orelse return null;
            const new_kv = pool.get(new_node).unwrapLeaf();
            return .{ new_kv[0][0], new_kv[1][0] };
        }

        fn nextNode(self: *Self, level: usize, pool: *const Pool) ?Node {
            const bl = self.rightSiblingBranchLevel(level, pool) orelse {
                self.size = 0;
                return null;
            };

            const bnodes = pool.get(self.node[bl]).unwrapInner()[1];
            self.entry[bl] += 1;
            var node = bnodes[self.entry[bl]];

            var l = bl + 1;
            while (l < level) : (l += 1) {
                self.node[l] = node;
                self.entry[l] = 0;
                node = pool.get(node).unwrapInner()[1][0];
            }

            self.node[level] = node;
            self.entry[level] = 0;
            return node;
        }

        fn rightSiblingBranchLevel(self: *const Self, level: usize, pool: *const Pool) ?usize {
            var l = level;
            while (l > 0) {
                l -= 1;
                const data = pool.get(self.node[l]);
                if (self.entry[l] < data.inner.size) {
                    return l;
                }
            }
            return null;
        }

        /// Set root node.
        pub fn setRootNode(self: *Self, root: Node) void {
            self.size = 1;
            self.node[0] = root;
            self.entry[0] = 0;
        }

        /// Get mutable reference to current value.
        pub fn valueMut(self: *const Self, pool: *Pool) *V {
            const node = pool.getMut(self.leafNode());
            return &node.leaf.vals[self.leafEntry()];
        }

        /// Insert key-value pair at current position, return new root.
        pub fn insert(self: *Self, key: K, value: V, pool: *Pool) !Node {
            if (!self.tryLeafInsert(key, value, pool)) {
                try self.splitAndInsert(key, value, pool);
            }
            return self.node[0];
        }

        fn tryLeafInsert(self: *const Self, key: K, value: V, pool: *Pool) bool {
            const index = self.leafEntry();
            return pool.getMut(self.leafNode()).tryLeafInsert(index, key, value);
        }

        fn splitAndInsert(self: *Self, key_arg: K, value: V, pool: *Pool) !void {
            const orig_root = self.node[0];
            var key = key_arg;
            var ins_node: ?Node = null;

            var level = self.size;
            while (level > 0) {
                level -= 1;

                var node = self.node[level];
                var e = @as(usize, self.entry[level]);
                var split = pool.getMut(node).split(e);
                const rhs_node = try pool.alloc(split.rhs_data);

                // Should path move to RHS?
                if (e > split.lhs_entries or (e == split.lhs_entries and (split.lhs_entries > split.rhs_entries or ins_node != null))) {
                    node = rhs_node;
                    e -= split.lhs_entries;
                    self.node[level] = node;
                    self.entry[level] = @intCast(e);
                }

                // Insert into non-full node
                if (ins_node) |n| {
                    _ = pool.getMut(node).tryInnerInsert(e, key, n);
                    if (n.index == self.node[level + 1].index) {
                        self.entry[level] += 1;
                    }
                } else {
                    _ = pool.getMut(node).tryLeafInsert(e, key, value);
                    if (e == 0 and node.index == rhs_node.index) {
                        split.crit_key = key;
                    }
                }

                key = split.crit_key;
                ins_node = rhs_node;

                if (level > 0) {
                    const pl = level - 1;
                    const pe = @as(usize, self.entry[pl]);
                    if (pool.getMut(self.node[pl]).tryInnerInsert(pe, key, rhs_node)) {
                        if (node.index == rhs_node.index) {
                            self.entry[pl] += 1;
                        }
                        return;
                    }
                }
            }

            // Split root
            const rhs_node = ins_node orelse unreachable;
            const root = try pool.alloc(ND.makeInner(orig_root, key, rhs_node));
            const e: u8 = if (self.node[0].index == rhs_node.index) 1 else 0;
            self.size += 1;
            sliceInsert(Node, self.node[0..self.size], 0, root);
            sliceInsert(u8, self.entry[0..self.size], 0, e);
        }

        /// Remove current entry and return new root (or null if empty).
        pub fn remove(self: *Self, pool: *Pool) ?Node {
            const e = self.leafEntry();
            const status = pool.getMut(self.leafNode()).leafRemove(e);

            switch (status) {
                .healthy => {
                    if (e == 0) self.updateCritKey(pool);
                    return self.node[0];
                },
                else => return self.balanceNodes(status, pool),
            }
        }

        fn updateCritKey(self: *Self, pool: *Pool) void {
            const crit_level = self.leftSiblingBranchLevel(self.size - 1) orelse return;
            const crit_kidx = self.entry[crit_level] - 1;
            const crit_key = pool.get(self.leafNode()).leafCritKey();
            pool.getMut(self.node[crit_level]).inner.keys[crit_kidx] = crit_key;
        }

        fn leftSiblingBranchLevel(self: *const Self, level: usize) ?usize {
            var l = level;
            while (l > 0) {
                l -= 1;
                if (self.entry[l] != 0) return l;
            }
            return null;
        }

        fn balanceNodes(self: *Self, status: Removed, pool: *Pool) ?Node {
            if (status != .empty and self.leafEntry() == 0) {
                self.updateCritKey(pool);
            }

            const leaf_level = self.size - 1;
            if (self.healLevel(status, leaf_level, pool)) {
                self.size = 0;
                return null;
            }

            // Prune single-child root nodes
            var ns: usize = 0;
            while (pool.get(self.node[ns]).* == .inner and pool.get(self.node[ns]).inner.size == 0) {
                ns += 1;
                self.node[ns] = pool.get(self.node[ns - 1]).inner.tree[0];
            }

            if (ns > 0) {
                for (0..ns) |l| {
                    pool.free(self.node[l]);
                }
                sliceShift(Node, &self.node, ns);
                sliceShift(u8, &self.entry, ns);
                if (self.size > 0) {
                    self.size -= ns;
                }
            }

            return self.node[0];
        }

        fn healLevel(self: *Self, status: Removed, level: usize, pool: *Pool) bool {
            switch (status) {
                .healthy => {},
                .rightmost => {
                    _ = self.nextNode(level, pool);
                },
                .underflow => self.underflowedNode(level, pool),
                .empty => return self.emptyNode(level, pool),
            }
            return false;
        }

        fn underflowedNode(self: *Self, level: usize, pool: *Pool) void {
            const sibling = self.rightSibling(level, pool) orelse {
                if (self.entry[level] >= pool.get(self.node[level]).entries()) {
                    self.size = 0;
                }
                return;
            };

            var rhs = pool.get(sibling[1]).*;
            const new_ck = pool.getMut(self.node[level]).balance(sibling[0], &rhs);

            pool.getMut(sibling[1]).* = rhs;

            if (new_ck) |ck| {
                self.updateRightCritKey(level, ck, pool);
            } else {
                const curr_ck = self.currentCritKey(level, pool);
                if (curr_ck) |ck| {
                    self.updateRightCritKey(level, ck, pool);
                }
                _ = self.emptyNode(level, pool);
            }
        }

        fn emptyNode(self: *Self, level: usize, pool: *Pool) bool {
            pool.free(self.node[level]);
            if (level == 0) return true;

            const rhs_node = if (self.rightSibling(level, pool)) |s| s[1] else null;

            const pl = level - 1;
            const pe = self.entry[pl];
            const status = pool.getMut(self.node[pl]).innerRemove(pe);
            _ = self.healLevel(status, pl, pool);

            if (rhs_node) |rhs| {
                self.node[level] = rhs;
            } else {
                self.size = 0;
            }
            return false;
        }

        fn rightSibling(self: *const Self, level: usize, pool: *const Pool) ?struct { K, Node } {
            const bl = self.rightSiblingBranchLevel(level, pool) orelse return null;
            const be = self.entry[bl];
            const inner = pool.get(self.node[bl]).unwrapInner();
            const crit_key = inner[0][be];
            var node = inner[1][be + 1];

            var l = bl + 1;
            while (l < level) : (l += 1) {
                node = pool.get(node).unwrapInner()[1][0];
            }

            return .{ crit_key, node };
        }

        fn currentCritKey(self: *const Self, level: usize, pool: *const Pool) ?K {
            const bl = self.leftSiblingBranchLevel(level) orelse return null;
            const keys = pool.get(self.node[bl]).unwrapInner()[0];
            return keys[self.entry[bl] - 1];
        }

        fn updateRightCritKey(self: *const Self, level: usize, crit_key: K, pool: *Pool) void {
            const bl = self.rightSiblingBranchLevel(level, pool) orelse return;
            pool.getMut(self.node[bl]).inner.keys[self.entry[bl]] = crit_key;
        }

        pub fn normalize(self: *Self, pool: *Pool) void {
            if (self.leafPos()) |pos| {
                if (pos[1] >= pool.get(pos[0]).entries()) {
                    _ = self.nextNode(self.size - 1, pool);
                }
            }
        }
    };
}

// ============================================================================
// Map
// ============================================================================

/// Memory pool for Map instances.
pub fn MapForest(comptime K: type, comptime V: type) type {
    const LEAF_SIZE = INNER_SIZE - 1;

    return struct {
        const Self = @This();

        nodes: NodePool(K, V, LEAF_SIZE),

        pub fn init(allocator: Allocator) Self {
            return .{ .nodes = NodePool(K, V, LEAF_SIZE).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.nodes.deinit();
        }

        pub fn clear(self: *Self) void {
            self.nodes.clear();
        }
    };
}

/// B-tree map from K to V.
pub fn Map(comptime K: type, comptime V: type) type {
    const LEAF_SIZE = INNER_SIZE - 1;
    const PathType = Path(K, V, LEAF_SIZE);
    const ND = NodeData(K, V, LEAF_SIZE);

    return struct {
        const Self = @This();

        root: ?Node = null,

        pub fn isEmpty(self: *const Self) bool {
            return self.root == null;
        }

        pub fn get(self: *const Self, key: K, forest: *const MapForest(K, V), comp: *const Comparator(K)) ?V {
            const root = self.root orelse return null;
            var path = PathType{};
            return path.find(key, root, &forest.nodes, comp);
        }

        pub fn insert(self: *Self, key: K, value: V, forest: *MapForest(K, V), comp: *const Comparator(K)) !?V {
            if (self.root) |root| {
                var path = PathType{};
                const old = path.find(key, root, &forest.nodes, comp);
                if (old != null) {
                    path.valueMut(&forest.nodes).* = value;
                } else {
                    self.root = try path.insert(key, value, &forest.nodes);
                }
                return old;
            } else {
                const root = try forest.nodes.alloc(ND.makeLeaf(key, value));
                self.root = root;
                return null;
            }
        }

        pub fn remove(self: *Self, key: K, forest: *MapForest(K, V), comp: *const Comparator(K)) ?V {
            const root = self.root orelse return null;
            var path = PathType{};
            const val = path.find(key, root, &forest.nodes, comp) orelse return null;
            self.root = path.remove(&forest.nodes);
            return val;
        }

        pub fn clear(self: *Self, forest: *MapForest(K, V)) void {
            if (self.root) |root| {
                forest.nodes.freeTree(root);
                self.root = null;
            }
        }

        pub fn iter(self: *const Self, forest: *const MapForest(K, V)) MapIter(K, V) {
            return MapIter(K, V).init(self.root, &forest.nodes);
        }
    };
}

pub fn MapIter(comptime K: type, comptime V: type) type {
    const LEAF_SIZE = INNER_SIZE - 1;
    const Pool = NodePool(K, V, LEAF_SIZE);
    const PathType = Path(K, V, LEAF_SIZE);

    return struct {
        const Self = @This();

        root: ?Node,
        pool: *const Pool,
        path: PathType,

        pub fn init(root: ?Node, pool: *const Pool) Self {
            return .{ .root = root, .pool = pool, .path = .{} };
        }

        pub fn next(self: *Self) ?struct { K, V } {
            if (self.root) |root| {
                self.root = null;
                return self.path.first(root, self.pool);
            } else {
                return self.path.next(self.pool);
            }
        }
    };
}

// ============================================================================
// Set
// ============================================================================

/// Memory pool for Set instances.
pub fn SetForest(comptime K: type) type {
    const LEAF_SIZE = 2 * INNER_SIZE - 1;

    return struct {
        const Self = @This();

        nodes: NodePool(K, void, LEAF_SIZE),

        pub fn init(allocator: Allocator) Self {
            return .{ .nodes = NodePool(K, void, LEAF_SIZE).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.nodes.deinit();
        }

        pub fn clear(self: *Self) void {
            self.nodes.clear();
        }
    };
}

/// B-tree set of K.
pub fn Set(comptime K: type) type {
    const LEAF_SIZE = 2 * INNER_SIZE - 1;
    const PathType = Path(K, void, LEAF_SIZE);
    const ND = NodeData(K, void, LEAF_SIZE);

    return struct {
        const Self = @This();

        root: ?Node = null,

        pub fn isEmpty(self: *const Self) bool {
            return self.root == null;
        }

        pub fn contains(self: *const Self, key: K, forest: *const SetForest(K), comp: *const Comparator(K)) bool {
            const root = self.root orelse return false;
            var path = PathType{};
            return path.find(key, root, &forest.nodes, comp) != null;
        }

        pub fn insert(self: *Self, key: K, forest: *SetForest(K), comp: *const Comparator(K)) !bool {
            if (self.root) |root| {
                var path = PathType{};
                if (path.find(key, root, &forest.nodes, comp) != null) {
                    return false;
                }
                self.root = try path.insert(key, {}, &forest.nodes);
                return true;
            } else {
                const root = try forest.nodes.alloc(ND.leaf(key, {}));
                self.root = root;
                return true;
            }
        }

        pub fn remove(self: *Self, key: K, forest: *SetForest(K), comp: *const Comparator(K)) bool {
            const root = self.root orelse return false;
            var path = PathType{};
            if (path.find(key, root, &forest.nodes, comp) == null) {
                return false;
            }
            self.root = path.remove(&forest.nodes);
            return true;
        }

        pub fn clear(self: *Self, forest: *SetForest(K)) void {
            if (self.root) |root| {
                forest.nodes.freeTree(root);
                self.root = null;
            }
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "slice utilities" {
    var a = [_]u8{ 'a', 'b', 'c', 'd' };

    sliceInsert(u8, a[0..1], 0, 'e');
    try std.testing.expectEqualStrings("ebcd", &a);

    sliceInsert(u8, &a, 0, 'a');
    try std.testing.expectEqualStrings("aebc", &a);

    sliceShift(u8, a[1..], 1);
    try std.testing.expectEqualStrings("abcc", &a);
}

test "Map basic operations" {
    const allocator = std.testing.allocator;
    var forest = MapForest(u32, f32).init(allocator);
    defer forest.deinit();

    var m = Map(u32, f32){};
    const comp = defaultComparator(u32);

    try std.testing.expect(m.isEmpty());

    // Insert values
    try std.testing.expectEqual(@as(?f32, null), try m.insert(50, 5.0, &forest, &comp));
    try std.testing.expectEqual(@as(?f32, 5.0), try m.insert(50, 5.5, &forest, &comp));
    try std.testing.expectEqual(@as(?f32, null), try m.insert(20, 2.0, &forest, &comp));
    try std.testing.expectEqual(@as(?f32, null), try m.insert(80, 8.0, &forest, &comp));

    try std.testing.expect(!m.isEmpty());

    // Get values
    try std.testing.expectEqual(@as(?f32, 5.5), m.get(50, &forest, &comp));
    try std.testing.expectEqual(@as(?f32, 2.0), m.get(20, &forest, &comp));
    try std.testing.expectEqual(@as(?f32, 8.0), m.get(80, &forest, &comp));
    try std.testing.expectEqual(@as(?f32, null), m.get(99, &forest, &comp));

    // Remove
    try std.testing.expectEqual(@as(?f32, 5.5), m.remove(50, &forest, &comp));
    try std.testing.expectEqual(@as(?f32, null), m.get(50, &forest, &comp));

    m.clear(&forest);
    try std.testing.expect(m.isEmpty());
}

test "Map iterator" {
    const allocator = std.testing.allocator;
    var forest = MapForest(u32, u32).init(allocator);
    defer forest.deinit();

    var m = Map(u32, u32){};
    const comp = defaultComparator(u32);

    _ = try m.insert(30, 3, &forest, &comp);
    _ = try m.insert(10, 1, &forest, &comp);
    _ = try m.insert(20, 2, &forest, &comp);

    var it = m.iter(&forest);
    const e1 = it.next().?;
    try std.testing.expectEqual(@as(u32, 10), e1[0]);
    try std.testing.expectEqual(@as(u32, 1), e1[1]);

    const e2 = it.next().?;
    try std.testing.expectEqual(@as(u32, 20), e2[0]);

    const e3 = it.next().?;
    try std.testing.expectEqual(@as(u32, 30), e3[0]);

    try std.testing.expect(it.next() == null);
}

test "Set basic operations" {
    const allocator = std.testing.allocator;
    var forest = SetForest(u32).init(allocator);
    defer forest.deinit();

    var s = Set(u32){};
    const comp = defaultComparator(u32);

    try std.testing.expect(s.isEmpty());

    try std.testing.expect(try s.insert(50, &forest, &comp));
    try std.testing.expect(!try s.insert(50, &forest, &comp)); // duplicate
    try std.testing.expect(try s.insert(20, &forest, &comp));
    try std.testing.expect(try s.insert(80, &forest, &comp));

    try std.testing.expect(!s.isEmpty());
    try std.testing.expect(s.contains(50, &forest, &comp));
    try std.testing.expect(s.contains(20, &forest, &comp));
    try std.testing.expect(!s.contains(99, &forest, &comp));

    try std.testing.expect(s.remove(50, &forest, &comp));
    try std.testing.expect(!s.remove(50, &forest, &comp));
    try std.testing.expect(!s.contains(50, &forest, &comp));

    s.clear(&forest);
    try std.testing.expect(s.isEmpty());
}

test "Map many insertions" {
    const allocator = std.testing.allocator;
    var forest = MapForest(u32, u32).init(allocator);
    defer forest.deinit();

    var m = Map(u32, u32){};
    const comp = defaultComparator(u32);

    // Insert enough to force tree splits
    const count: u32 = 100;
    for (0..count) |i| {
        const key: u32 = @intCast((i * 7) % count);
        _ = try m.insert(key, @intCast(i), &forest, &comp);
    }

    // Verify all present
    for (0..count) |i| {
        try std.testing.expect(m.get(@intCast(i), &forest, &comp) != null);
    }

    // Remove all
    for (0..count) |i| {
        const key: u32 = @intCast((i * 7) % count);
        _ = m.remove(key, &forest, &comp);
    }

    try std.testing.expect(m.isEmpty());
}
