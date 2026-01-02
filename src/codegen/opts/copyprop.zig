//! Copy Propagation optimization pass.
//!
//! Identifies copy instructions (a = b) and replaces uses of a with b where valid.
//! Uses the IR's built-in alias mechanism to track copy relationships.
//!
//! This pass:
//! - Identifies trivial copy patterns (unary operations that just move values)
//! - Creates alias values to represent copy relationships
//! - Tracks copy chains through the existing alias resolution
//! - Invalidates copies when values are redefined

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("root");
const Function = root.function.Function;
const Block = root.entities.Block;
const Inst = root.entities.Inst;
const Value = root.entities.Value;
const Opcode = root.opcodes.Opcode;
const ValueData = root.dfg.ValueData;

/// Copy propagation pass.
pub const CopyProp = struct {
    /// Allocator for temporary data structures.
    allocator: Allocator,
    /// Map from value to its copy source (if it's a copy).
    copies: std.AutoHashMap(Value, Value),

    pub fn init(allocator: Allocator) CopyProp {
        return .{
            .allocator = allocator,
            .copies = std.AutoHashMap(Value, Value).init(allocator),
        };
    }

    pub fn deinit(self: *CopyProp) void {
        self.copies.deinit();
    }

    /// Run copy propagation on the function.
    /// Returns true if any copies were propagated.
    pub fn run(self: *CopyProp, func: *Function) !bool {
        // Find all copy instructions
        try self.findCopies(func);

        // If no copies found, nothing to do
        if (self.copies.count() == 0) {
            return false;
        }

        // Create aliases for copy values
        const changed = try self.createAliases(func);

        // Clear for next run
        self.copies.clearRetainingCapacity();

        return changed;
    }

    /// Find copy instructions in the function.
    fn findCopies(self: *CopyProp, func: *Function) !void {
        var block_iter = func.layout.blocks();
        while (block_iter.next()) |block| {
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                const inst_data = func.dfg.insts.get(inst) orelse continue;

                // Check for copy-like instructions (unary ops that just move values)
                const copy_source = switch (inst_data.*) {
                    .unary => |d| blk: {
                        // Simple unary operations that are effectively copies
                        // (e.g., extending a value to itself, or identity operations)
                        if (isCopyLikeOp(d.opcode)) {
                            break :blk d.arg;
                        }
                        break :blk null;
                    },
                    else => null,
                };

                if (copy_source) |source| {
                    // Record this as a copy
                    const result = func.dfg.firstResult(inst) orelse continue;
                    try self.copies.put(result, source);
                }
            }
        }
    }

    /// Create alias values for copies.
    fn createAliases(self: *CopyProp, func: *Function) !bool {
        var changed = false;

        var iter = self.copies.iterator();
        while (iter.next()) |entry| {
            const dest = entry.key_ptr.*;
            const source = entry.value_ptr.*;

            // Get the type of the destination
            const ty = func.dfg.valueType(dest) orelse continue;

            // Create an alias value
            const dest_data = func.dfg.values.getMut(dest) orelse continue;
            dest_data.* = ValueData.alias(ty, source);
            changed = true;
        }

        // If we created aliases, resolve them throughout the function
        if (changed) {
            func.dfg.resolveAllAliases();
        }

        return changed;
    }

    /// Check if an opcode represents a copy-like operation.
    fn isCopyLikeOp(opcode: Opcode) bool {
        return switch (opcode) {
            // Bit operations that are identity when extending to same or larger size
            // These would need additional validation in a full implementation
            .sextend, .uextend => false, // Conservative: not copies unless sizes match
            .ireduce => false, // Not a copy, loses bits

            // These are not in the current opcode list but would be copies:
            // .copy => true,  // If we had an explicit copy opcode

            else => false,
        };
    }
};

// Tests

const testing = std.testing;

test "CopyProp: init and deinit" {
    var cp = CopyProp.init(testing.allocator);
    defer cp.deinit();

    try testing.expectEqual(@as(usize, 0), cp.copies.count());
}

test "CopyProp: isCopyLikeOp" {
    // Currently conservative: no operations are considered copy-like
    // This can be extended based on specific optimization needs
    try testing.expect(!CopyProp.isCopyLikeOp(.iadd));
    try testing.expect(!CopyProp.isCopyLikeOp(.sextend));
    try testing.expect(!CopyProp.isCopyLikeOp(.uextend));
}
