//! Debug tag storage.
//!
//! Ported from cranelift-codegen ir/debug_tags.rs.
//! Cranelift permits the embedder to place "debug tags" on instructions in CLIF.
//! These tags are sequences of items of various kinds, passed through to metadata
//! provided alongside the compilation result.

const std = @import("std");
const Allocator = std.mem.Allocator;
const entities = @import("entities.zig");
const Inst = entities.Inst;
const StackSlot = entities.StackSlot;

/// One debug tag.
pub const DebugTag = union(enum) {
    /// User-specified u32 value, opaque to Cranelift.
    user: u32,
    /// A stack slot reference.
    stack_slot: StackSlot,

    /// Format for display.
    pub fn format(
        self: DebugTag,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .user => |value| try writer.print("{}", .{value}),
            .stack_slot => |slot| try writer.print("ss{}", .{slot.index()}),
        }
    }
};

/// Debug tags for instructions.
pub const DebugTags = struct {
    /// Pool of tags, referred to by insts map.
    tags: std.ArrayList(DebugTag),
    /// Per-instruction range for its list of tags in the tag pool (if any).
    insts: std.AutoHashMap(Inst, Range),

    const Range = struct {
        start: u32,
        end: u32,
    };

    pub fn init(allocator: Allocator) DebugTags {
        return .{
            .tags = std.ArrayList(DebugTag).init(allocator),
            .insts = std.AutoHashMap(Inst, Range).init(allocator),
        };
    }

    pub fn deinit(self: *DebugTags) void {
        self.tags.deinit();
        self.insts.deinit();
    }

    /// Set the tags on an instruction, overwriting existing tag list.
    ///
    /// Tags can only be set on call instructions and on sequence_point instructions.
    /// This property is checked by the CLIF verifier.
    pub fn set(self: *DebugTags, allocator: Allocator, inst: Inst, tag_list: []const DebugTag) !void {
        const start: u32 = @intCast(self.tags.items.len);
        try self.tags.appendSlice(allocator, tag_list);
        const end: u32 = @intCast(self.tags.items.len);

        if (end > start) {
            try self.insts.put(allocator, inst, .{ .start = start, .end = end });
        } else {
            _ = self.insts.remove(inst);
        }
    }

    /// Get the tags associated with an instruction.
    pub fn get(self: *const DebugTags, inst: Inst) []const DebugTag {
        if (self.insts.get(inst)) |range| {
            const start: usize = @intCast(range.start);
            const end: usize = @intCast(range.end);
            return self.tags.items[start..end];
        }
        return &[_]DebugTag{};
    }

    /// Does the given instruction have any tags?
    pub fn has(self: *const DebugTags, inst: Inst) bool {
        return self.insts.contains(inst);
    }

    /// Clone the tags from one instruction to another.
    ///
    /// This clone is cheap (references the same underlying storage)
    /// because the tag lists are immutable.
    pub fn cloneTags(self: *DebugTags, allocator: Allocator, from: Inst, to: Inst) !void {
        if (self.insts.get(from)) |range| {
            try self.insts.put(allocator, to, range);
        } else {
            _ = self.insts.remove(to);
        }
    }

    /// Are any debug tags present?
    ///
    /// This is used for adjusting margins when pretty-printing CLIF.
    pub fn isEmpty(self: *const DebugTags) bool {
        return self.insts.count() == 0;
    }

    /// Clear all tags.
    pub fn clear(self: *DebugTags) void {
        self.insts.clearRetainingCapacity();
        self.tags.clearRetainingCapacity();
    }
};

const testing = std.testing;

test "DebugTags basic" {
    var tags = DebugTags.init(testing.allocator);
    defer tags.deinit();

    const inst1 = Inst.fromIndex(1);
    const inst2 = Inst.fromIndex(2);

    const tag_items = [_]DebugTag{
        .{ .user = 42 },
        .{ .stack_slot = StackSlot.fromIndex(0) },
    };

    try tags.set(testing.allocator, inst1, &tag_items);
    try testing.expect(tags.has(inst1));
    try testing.expect(!tags.has(inst2));

    const retrieved = tags.get(inst1);
    try testing.expectEqual(@as(usize, 2), retrieved.len);
    try testing.expectEqual(DebugTag{ .user = 42 }, retrieved[0]);

    try tags.cloneTags(testing.allocator, inst1, inst2);
    try testing.expect(tags.has(inst2));
}
