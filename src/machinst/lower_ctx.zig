const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const vcode_builder_mod = @import("vcode_builder.zig");
const vreg_allocator_mod = @import("vreg_allocator.zig");
const reg_mod = @import("reg.zig");

pub const VCodeBuilder = vcode_builder_mod.VCodeBuilder;
pub const VCodeBuildDirection = vcode_builder_mod.VCodeBuildDirection;
pub const VRegAllocator = vreg_allocator_mod.VRegAllocator;
pub const VCode = vcode_builder_mod.VCode;

pub const VReg = reg_mod.VReg;
pub const Reg = reg_mod.Reg;
pub const RegClass = reg_mod.RegClass;

// Placeholder types for IR (u32 indices).
pub const Value = u32;
pub const Block = u32;
pub const Inst = u32;

/// LowerCtx - lowering context for instruction selection.
///
/// Wraps VCodeBuilder and VRegAllocator, manages value-to-vreg mapping.
/// Simplified version - full DFG integration happens in higher layers.
///
/// Based on Cranelift's machinst/lower.rs:Lower.
pub fn LowerCtx(comptime MInst: type) type {
    return struct {
        /// VCode builder for emitting machine instructions.
        vcode: VCodeBuilder(MInst),

        /// Virtual register allocator.
        vregs: VRegAllocator,

        /// Mapping from IR Value to VReg.
        value_map: std.AutoHashMap(Value, VReg),

        /// Allocator.
        allocator: Allocator,

        const Self = @This();

        /// Create a new lowering context.
        pub fn init(allocator: Allocator) Self {
            return .{
                .vcode = VCodeBuilder(MInst).init(allocator, .backward),
                .vregs = VRegAllocator.init(allocator),
                .value_map = std.AutoHashMap(Value, VReg).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.value_map.deinit();
            self.vregs.deinit();
            self.vcode.deinit();
        }

        /// Allocate a vreg for an IR value (if not already allocated).
        pub fn ensureVReg(self: *Self, val: Value, reg_class: RegClass) !VReg {
            if (self.value_map.get(val)) |vreg| {
                return vreg;
            }

            const vreg = try self.vregs.alloc(reg_class);
            try self.value_map.put(val, vreg);
            return vreg;
        }

        /// Get the vreg for an IR value (must already be allocated).
        pub fn getVReg(self: *const Self, val: Value) ?VReg {
            return self.value_map.get(val);
        }

        /// Allocate a temporary vreg (not tied to an IR value).
        pub fn allocTemp(self: *Self, reg_class: RegClass) !VReg {
            return try self.vregs.allocTemp(reg_class);
        }

        /// Emit a machine instruction.
        pub fn emit(self: *Self, inst: MInst) !void {
            try self.vcode.emit(inst);
        }

        /// Start a new basic block.
        pub fn startBlock(self: *Self) !void {
            _ = try self.vcode.startBlock(&.{});
        }

        /// Finish the current basic block.
        pub fn finishBlock(self: *Self) !void {
            try self.vcode.finishBlock(&.{});
        }

        /// Finish building and return VCode.
        pub fn finish(self: *Self) !VCode(MInst) {
            return try self.vcode.finish();
        }
    };
}

test "LowerCtx basic" {
    const TestInst = struct { opcode: u8 };

    var ctx = LowerCtx(TestInst).init(testing.allocator);
    defer ctx.deinit();

    // Allocate a temp vreg.
    const v0 = try ctx.allocTemp(.int);
    try testing.expectEqual(@as(u32, 0), v0.index());
    try testing.expectEqual(RegClass.int, v0.class());

    // Emit some instructions.
    try ctx.startBlock();
    try ctx.emit(.{ .opcode = 0x90 }); // NOP
    try ctx.emit(.{ .opcode = 0xC3 }); // RET
    try ctx.finishBlock();

    var vcode = try ctx.finish();
    defer vcode.deinit();

    try testing.expectEqual(@as(usize, 1), vcode.numBlocks());
    try testing.expectEqual(@as(usize, 2), vcode.numInsns());
}

test "LowerCtx value mapping" {
    const TestInst = struct { opcode: u8 };

    var ctx = LowerCtx(TestInst).init(testing.allocator);
    defer ctx.deinit();

    // Create some IR values (just indices).
    const val1: Value = 1;
    const val2: Value = 2;

    // Allocate vregs for them.
    const v1 = try ctx.ensureVReg(val1, .int);
    const v2 = try ctx.ensureVReg(val2, .float);

    try testing.expectEqual(@as(u32, 0), v1.index());
    try testing.expectEqual(@as(u32, 0), v2.index());
    try testing.expectEqual(RegClass.int, v1.class());
    try testing.expectEqual(RegClass.float, v2.class());

    // Get them back.
    try testing.expectEqual(v1, ctx.getVReg(val1).?);
    try testing.expectEqual(v2, ctx.getVReg(val2).?);

    // Ensure idempotent.
    const v1_again = try ctx.ensureVReg(val1, .int);
    try testing.expectEqual(v1, v1_again);
}
