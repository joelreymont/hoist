//! Cursor for navigating and editing IR.
//!
//! Minimal implementation of cranelift cursor.rs.
//! Provides position tracking and basic navigation for IR editing.

const std = @import("std");
const Function = @import("function.zig").Function;
const entities = @import("entities.zig");
const Block = entities.Block;
const Inst = entities.Inst;

/// The possible positions of a cursor.
pub const CursorPosition = union(enum) {
    /// Cursor is not pointing anywhere.
    nowhere,
    /// Cursor is pointing at an existing instruction.
    /// New instructions will be inserted *before* the current instruction.
    at: Inst,
    /// Cursor is before the beginning of a block.
    before: Block,
    /// Cursor is pointing after the end of a block.
    /// New instructions will be appended to the block.
    after: Block,
};

/// Function cursor for navigating and editing IR.
pub const FuncCursor = struct {
    func: *Function,
    pos: CursorPosition,
    srcloc: u32, // TODO: Use SourceLoc when implemented

    pub fn init(func: *Function) FuncCursor {
        return .{
            .func = func,
            .pos = .nowhere,
            .srcloc = 0,
        };
    }

    /// Get the current cursor position.
    pub fn position(self: *const FuncCursor) CursorPosition {
        return self.pos;
    }

    /// Set the current position.
    pub fn setPosition(self: *FuncCursor, pos: CursorPosition) void {
        self.pos = pos;
    }

    /// Move cursor to an instruction.
    pub fn gotoInst(self: *FuncCursor, inst: Inst) void {
        self.pos = .{ .at = inst };
    }

    /// Move cursor to the start of a block.
    pub fn gotoTop(self: *FuncCursor, block: Block) void {
        if (self.func.layout.blockFirstInst(block)) |first_inst| {
            self.pos = .{ .at = first_inst };
        } else {
            self.pos = .{ .after = block };
        }
    }

    /// Move cursor to the end of a block.
    pub fn gotoBottom(self: *FuncCursor, block: Block) void {
        self.pos = .{ .after = block };
    }

    /// Move to the next instruction in layout order.
    pub fn nextInst(self: *FuncCursor) ?Inst {
        switch (self.pos) {
            .at => |inst| {
                if (self.func.layout.instNext(inst)) |next| {
                    self.pos = .{ .at = next };
                    return next;
                } else {
                    // End of block
                    const block = self.func.layout.instBlock(inst) orelse return null;
                    self.pos = .{ .after = block };
                    return null;
                }
            },
            .before => |block| {
                if (self.func.layout.blockFirstInst(block)) |first| {
                    self.pos = .{ .at = first };
                    return first;
                } else {
                    self.pos = .{ .after = block };
                    return null;
                }
            },
            else => return null,
        }
    }

    /// Move to the previous instruction in layout order.
    pub fn prevInst(self: *FuncCursor) ?Inst {
        switch (self.pos) {
            .at => |inst| {
                if (self.func.layout.instPrev(inst)) |prev| {
                    self.pos = .{ .at = prev };
                    return prev;
                } else {
                    // Start of block
                    const block = self.func.layout.instBlock(inst) orelse return null;
                    self.pos = .{ .before = block };
                    return null;
                }
            },
            .after => |block| {
                if (self.func.layout.blockLastInst(block)) |last| {
                    self.pos = .{ .at = last };
                    return last;
                } else {
                    self.pos = .{ .before = block };
                    return null;
                }
            },
            else => return null,
        }
    }

    /// Move to the next block in layout order.
    pub fn nextBlock(self: *FuncCursor) ?Block {
        const current_block = switch (self.pos) {
            .at => |inst| self.func.layout.instBlock(inst),
            .before => |block| block,
            .after => |block| block,
            .nowhere => null,
        } orelse return null;

        if (self.func.layout.blockNext(current_block)) |next_block| {
            self.pos = .{ .before = next_block };
            return next_block;
        }
        return null;
    }

    /// Get the current block if positioned in one.
    pub fn currentBlock(self: *const FuncCursor) ?Block {
        return switch (self.pos) {
            .at => |inst| self.func.layout.instBlock(inst),
            .before => |block| block,
            .after => |block| block,
            .nowhere => null,
        };
    }

    /// Get the current instruction if positioned at one.
    pub fn currentInst(self: *const FuncCursor) ?Inst {
        return switch (self.pos) {
            .at => |inst| inst,
            else => null,
        };
    }
};

const testing = std.testing;

test "FuncCursor basic" {
    const Signature = @import("../ir/signature.zig").Signature;

    const sig = Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var cursor = FuncCursor.init(&func);
    try testing.expectEqual(CursorPosition.nowhere, cursor.position());
}
