const std = @import("std");

pub const Stats = struct {
    alloc_calls: u64 = 0,
    free_calls: u64 = 0,
    resize_calls: u64 = 0,
    remap_calls: u64 = 0,
    alloc_bytes: u64 = 0,
    free_bytes: u64 = 0,

    pub fn delta(after: Stats, before: Stats) Stats {
        return .{
            .alloc_calls = after.alloc_calls - before.alloc_calls,
            .free_calls = after.free_calls - before.free_calls,
            .resize_calls = after.resize_calls - before.resize_calls,
            .remap_calls = after.remap_calls - before.remap_calls,
            .alloc_bytes = after.alloc_bytes - before.alloc_bytes,
            .free_bytes = after.free_bytes - before.free_bytes,
        };
    }

    pub fn addAssign(self: *Stats, other: Stats) void {
        self.alloc_calls +%= other.alloc_calls;
        self.free_calls +%= other.free_calls;
        self.resize_calls +%= other.resize_calls;
        self.remap_calls +%= other.remap_calls;
        self.alloc_bytes +%= other.alloc_bytes;
        self.free_bytes +%= other.free_bytes;
    }
};

pub const CountingAllocator = struct {
    child: std.mem.Allocator,
    stats: Stats = .{},

    const Self = @This();

    const vtable = std.mem.Allocator.VTable{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    pub fn init(child: std.mem.Allocator) Self {
        return .{ .child = child };
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    pub fn snapshot(self: *const Self) Stats {
        return self.stats;
    }

    pub fn reset(self: *Self) void {
        self.stats = .{};
    }

    fn cast(ptr: *anyopaque) *Self {
        return @ptrCast(@alignCast(ptr));
    }

    fn alloc(ptr: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self = cast(ptr);
        const memory = self.child.rawAlloc(len, alignment, ret_addr) orelse return null;
        self.stats.alloc_calls +%= 1;
        self.stats.alloc_bytes +%= @intCast(len);
        return memory;
    }

    fn resize(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self = cast(ptr);
        self.stats.resize_calls +%= 1;
        const ok = self.child.rawResize(memory, alignment, new_len, ret_addr);
        if (ok) {
            if (new_len >= memory.len) {
                self.stats.alloc_bytes +%= @intCast(new_len - memory.len);
            } else {
                self.stats.free_bytes +%= @intCast(memory.len - new_len);
            }
        }
        return ok;
    }

    fn remap(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self = cast(ptr);
        self.stats.remap_calls +%= 1;
        const new_ptr = self.child.rawRemap(memory, alignment, new_len, ret_addr) orelse return null;
        if (new_len >= memory.len) {
            self.stats.alloc_bytes +%= @intCast(new_len - memory.len);
        } else {
            self.stats.free_bytes +%= @intCast(memory.len - new_len);
        }
        return new_ptr;
    }

    fn free(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self = cast(ptr);
        self.stats.free_calls +%= 1;
        self.stats.free_bytes +%= @intCast(memory.len);
        self.child.rawFree(memory, alignment, ret_addr);
    }
};
