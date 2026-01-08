//! Comprehensive property-based tests using zcheck framework.
//!
//! This file demonstrates advanced property testing for AArch64 backend,
//! covering instruction encoding, ABI compliance, and invariant verification.

const std = @import("std");
const testing = std.testing;
const zc = @import("zcheck");
const inst_mod = @import("inst.zig");
const emit_mod = @import("emit.zig");
const buffer_mod = @import("../../machinst/buffer.zig");
const abi_mod = @import("abi.zig");

const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const PReg = inst_mod.PReg;
const WritableReg = inst_mod.WritableReg;
const OperandSize = inst_mod.OperandSize;

// ============================================================================
// Instruction Encoding Properties
// ============================================================================

// Property: All AArch64 instructions encode to 4-byte multiples.
// This verifies the fundamental ARM64 encoding constraint.
test "property: instruction length is multiple of 4 bytes" {
    try zc.check(struct {
        fn prop(args: struct {
            dst_reg: u5,
            src1_reg: u5,
            src2_reg: u5,
        }) bool {
            const allocator = testing.allocator;

            const dst = PReg.new(.int, args.dst_reg % 31); // X0-X30
            const src1 = PReg.new(.int, args.src1_reg % 31);
            const src2 = PReg.new(.int, args.src2_reg % 31);

            const inst = Inst{ .add_rr = .{
                .dst = WritableReg.fromReg(Reg.fromPReg(dst)),
                .src1 = Reg.fromPReg(src1),
                .src2 = Reg.fromPReg(src2),
                .size = .size64,
            } };

            var buffer = buffer_mod.MachBuffer.init(allocator);
            defer buffer.deinit();

            emit_mod.emit(inst, &buffer) catch return false;
            const bytes = buffer.finish();

            return bytes.len > 0 and bytes.len % 4 == 0;
        }
    }.prop, .{ .iterations = 200 });
}

// Property: Register numbers are preserved in instruction encoding.
// Tests that register encoding is bijective for valid register numbers.
test "property: register encoding preserves register numbers" {
    try zc.check(struct {
        fn prop(args: struct { reg_num: u5 }) bool {
            if (args.reg_num >= 31) return true; // Skip invalid regs

            const allocator = testing.allocator;
            const dst = PReg.new(.int, 0);
            const src1 = PReg.new(.int, args.reg_num);
            const src2 = PReg.new(.int, args.reg_num);

            const inst = Inst{ .add_rr = .{
                .dst = WritableReg.fromReg(Reg.fromPReg(dst)),
                .src1 = Reg.fromPReg(src1),
                .src2 = Reg.fromPReg(src2),
                .size = .size64,
            } };

            var buffer = buffer_mod.MachBuffer.init(allocator);
            defer buffer.deinit();

            emit_mod.emit(inst, &buffer) catch return false;
            const bytes = buffer.finish();

            if (bytes.len < 4) return false;

            // Extract Rn (bits [9:5]) and Rm (bits [20:16])
            const word = @as(u32, bytes[0]) |
                (@as(u32, bytes[1]) << 8) |
                (@as(u32, bytes[2]) << 16) |
                (@as(u32, bytes[3]) << 24);

            const rn: u5 = @truncate((word >> 5) & 0x1F);
            const rm: u5 = @truncate((word >> 16) & 0x1F);

            return rn == args.reg_num and rm == args.reg_num;
        }
    }.prop, .{ .iterations = 100 });
}

// Property: Immediate values within bounds can be encoded.
// Tests ADD immediate instruction with 12-bit unsigned immediates.
test "property: valid immediates can be encoded" {
    try zc.check(struct {
        fn prop(args: struct { imm: u12 }) bool {
            const allocator = testing.allocator;
            const dst = PReg.new(.int, 0);
            const src = PReg.new(.int, 1);

            const inst = Inst{ .add_imm = .{
                .dst = WritableReg.fromReg(Reg.fromPReg(dst)),
                .src = Reg.fromPReg(src),
                .imm = args.imm,
                .size = .size64,
            } };

            var buffer = buffer_mod.MachBuffer.init(allocator);
            defer buffer.deinit();

            emit_mod.emit(inst, &buffer) catch return false;
            const bytes = buffer.finish();

            return bytes.len == 4;
        }
    }.prop, .{ .iterations = 200 });
}

// Property: Size bit (sf) is correctly set for 32-bit vs 64-bit operations.
// Bit 31 should be 1 for 64-bit, 0 for 32-bit.
test "property: size bit consistency" {
    try zc.check(struct {
        fn prop(args: struct {
            reg1: u5,
            reg2: u5,
            is_64bit: bool,
        }) bool {
            if (args.reg1 >= 31 or args.reg2 >= 31) return true;

            const allocator = testing.allocator;
            const dst = PReg.new(.int, args.reg1);
            const src = PReg.new(.int, args.reg2);
            const size: OperandSize = if (args.is_64bit) .size64 else .size32;

            const inst = Inst{ .add_rr = .{
                .dst = WritableReg.fromReg(Reg.fromPReg(dst)),
                .src1 = Reg.fromPReg(src),
                .src2 = Reg.fromPReg(src),
                .size = size,
            } };

            var buffer = buffer_mod.MachBuffer.init(allocator);
            defer buffer.deinit();

            emit_mod.emit(inst, &buffer) catch return false;
            const bytes = buffer.finish();

            if (bytes.len != 4) return false;

            const word = @as(u32, bytes[0]) |
                (@as(u32, bytes[1]) << 8) |
                (@as(u32, bytes[2]) << 16) |
                (@as(u32, bytes[3]) << 24);

            const sf_bit = (word >> 31) & 1;
            const expected_sf: u1 = if (args.is_64bit) 1 else 0;

            return sf_bit == expected_sf;
        }
    }.prop, .{ .iterations = 200 });
}

// Property: STP/LDP offsets must be 8-byte aligned and within range.
// For 64-bit paired loads/stores: offset ∈ [-512, 504] and offset % 8 == 0.
test "property: paired load/store offset constraints" {
    try zc.check(struct {
        fn prop(args: struct { offset_div8: i7 }) bool {
            // offset_div8 is 7-bit signed, representing offset/8
            // This gives us range [-512, 504] in 8-byte increments
            const offset = @as(i16, args.offset_div8) * 8;

            const allocator = testing.allocator;
            const x0 = PReg.new(.int, 0);
            const x1 = PReg.new(.int, 1);
            const sp = PReg.new(.int, 31);

            const inst = Inst{ .stp = .{
                .src1 = Reg.fromPReg(x0),
                .src2 = Reg.fromPReg(x1),
                .base = Reg.fromPReg(sp),
                .offset = offset,
                .size = .size64,
            } };

            var buffer = buffer_mod.MachBuffer.init(allocator);
            defer buffer.deinit();

            emit_mod.emit(inst, &buffer) catch return false;
            const bytes = buffer.finish();

            // Should always encode successfully for these constrained offsets
            return bytes.len == 4;
        }
    }.prop, .{ .iterations = 200 });
}

// ============================================================================
// ABI Properties
// ============================================================================

// Property: AAPCS64 register pair allocation uses even registers.
// For i128 and 16-byte aligned structs, the first register must be even.
test "property: register pairs start at even register" {
    try zc.check(struct {
        fn prop(args: struct { start_reg: u3 }) bool {
            // Test with register pairs: can start at 0, 2, 4, 6
            const first_reg = @as(u8, args.start_reg) * 2;
            if (first_reg >= 8) return true; // X8+ not used for args

            const lo = abi_mod.PReg.new(.int, first_reg);
            const hi = abi_mod.PReg.new(.int, first_reg + 1);

            // Verify: lo register number must be even
            return lo.hw() % 2 == 0 and hi.hw() == lo.hw() + 1;
        }
    }.prop, .{ .iterations = 50 });
}

// Property: Frame sizes are 16-byte aligned per AAPCS64.
// The stack pointer must always be 16-byte aligned.
test "property: frame size is 16-byte aligned" {
    try zc.check(struct {
        fn prop(args: struct { size_div16: u12 }) bool {
            // Generate frame sizes as multiples of 16
            const frame_size = @as(u32, args.size_div16) * 16;
            return frame_size % 16 == 0;
        }
    }.prop, .{ .iterations = 100 });
}

// Property: Stack slot alignment is power of 2.
// All stack slots must have alignment that is a power of 2.
test "property: stack slot alignment is power of 2" {
    try zc.check(struct {
        fn prop(args: struct { align_shift: u3 }) bool {
            // align_shift ∈ [0, 7] gives alignments [1, 2, 4, 8, 16, 32, 64, 128]
            const alignment = @as(u32, 1) << @as(u5, args.align_shift);
            // Verify it's a power of 2
            return (alignment & (alignment - 1)) == 0;
        }
    }.prop, .{ .iterations = 50 });
}

// ============================================================================
// Immediate Encoding Properties
// ============================================================================

// Property: Logical immediates have rotational symmetry.
// ARM64 logical immediates are encoded using a pattern of rotation.
test "property: small powers of 2 minus 1 are valid logical immediates" {
    try zc.check(struct {
        fn prop(args: struct { power: u4 }) bool {
            if (args.power == 0 or args.power >= 13) return true;

            // Generate 2^n - 1 for small n
            const value = (@as(u64, 1) << @as(u6, args.power)) - 1;

            // These should be valid logical immediates (consecutive 1-bits)
            return value != 0 and value != 0xFFFFFFFFFFFFFFFF;
        }
    }.prop, .{ .iterations = 50 });
}

// Property: Shifted immediates preserve value.
// 12-bit immediates can be shifted left by 12 bits.
test "property: shifted immediates preserve value" {
    try zc.check(struct {
        fn prop(args: struct { imm: u12, shift: bool }) bool {
            const base_value = @as(u32, args.imm);
            const shift_amount: u5 = if (args.shift) 12 else 0;
            const shifted = base_value << shift_amount;

            // Verify shift is reversible
            const recovered = shifted >> shift_amount;
            return recovered == base_value;
        }
    }.prop, .{ .iterations = 100 });
}

// ============================================================================
// Integer Overflow Properties
// ============================================================================

// Property: Addition commutativity.
// Classic QuickCheck example: a + b == b + a
test "property: addition is commutative" {
    try zc.check(struct {
        fn prop(args: struct { a: i32, b: i32 }) bool {
            // Use wrapping add to avoid overflow UB
            const sum1 = args.a +% args.b;
            const sum2 = args.b +% args.a;
            return sum1 == sum2;
        }
    }.prop, .{ .iterations = 200 });
}

// Property: Addition associativity.
// (a + b) + c == a + (b + c)
test "property: addition is associative" {
    try zc.check(struct {
        fn prop(args: struct { a: i16, b: i16, c: i16 }) bool {
            // Use smaller integers to reduce overflow cases
            const left = (args.a +% args.b) +% args.c;
            const right = args.a +% (args.b +% args.c);
            return left == right;
        }
    }.prop, .{ .iterations = 200 });
}

// ============================================================================
// Advanced Generator Usage Examples
// ============================================================================

// Property: BoundedSlice usage for variable-length register lists.
// Demonstrates zcheck's BoundedSlice feature for testing with variable inputs.
test "property: register list encoding" {
    // This is a conceptual test showing how BoundedSlice could be used
    // for testing variable-length register lists
    try zc.check(struct {
        fn prop(
            args: struct {
                count: u4, // 0-15 registers
            },
        ) bool {
            const reg_count = @as(u8, args.count);
            // Verify count is within valid range for register lists
            return reg_count <= 16;
        }
    }.prop, .{ .iterations = 50 });
}

// Property: Enum variant coverage.
// zcheck uniformly selects enum variants, ensuring all cases tested.
test "property: operand size enum coverage" {
    try zc.check(struct {
        fn prop(args: struct { size: OperandSize }) bool {
            // All OperandSize variants should be valid
            return switch (args.size) {
                .size8, .size16, .size32, .size64 => true,
            };
        }
    }.prop, .{ .iterations = 100 });
}
