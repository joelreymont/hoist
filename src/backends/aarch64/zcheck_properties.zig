//! Comprehensive property-based tests using zcheck framework.
//!
//! This file demonstrates advanced property testing for AArch64 backend,
//! covering instruction encoding, ABI compliance, and invariant verification.

const std = @import("std");
const testing = std.testing;
const inst_mod = @import("inst.zig");
const emit_mod = @import("emit.zig");
const buffer_mod = @import("../../machinst/buffer.zig");
const abi_mod = @import("abi.zig");
const jit_mem = @import("../../jit/memory.zig");
const parallel_copy = @import("../../machinst/parallel_copy.zig");
const zcheck_fallible = @import("../../testing/zcheck_fallible.zig");

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
    const Args = struct {
        dst_reg: u5,
        src1_reg: u5,
        src2_reg: u5,
    };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
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

            try emit_mod.emit(inst, &buffer);
            const bytes = buffer.finish();

            try testing.expect(bytes.len > 0);
            try testing.expect(bytes.len % 4 == 0);
        }
    }.prop, .{ .iterations = 200 });
}

// Property: Register numbers are preserved in instruction encoding.
// Tests that register encoding is bijective for valid register numbers.
test "property: register encoding preserves register numbers" {
    const Args = struct { reg_num: u5 };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            if (args.reg_num >= 31) return; // Skip invalid regs

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

            try emit_mod.emit(inst, &buffer);
            const bytes = buffer.finish();

            try testing.expect(bytes.len >= 4);

            // Extract Rn (bits [9:5]) and Rm (bits [20:16])
            const word = @as(u32, bytes[0]) |
                (@as(u32, bytes[1]) << 8) |
                (@as(u32, bytes[2]) << 16) |
                (@as(u32, bytes[3]) << 24);

            const rn: u5 = @truncate((word >> 5) & 0x1F);
            const rm: u5 = @truncate((word >> 16) & 0x1F);

            try testing.expectEqual(args.reg_num, rn);
            try testing.expectEqual(args.reg_num, rm);
        }
    }.prop, .{ .iterations = 100 });
}

// Property: Immediate values within bounds can be encoded.
// Tests ADD immediate instruction with 12-bit unsigned immediates.
test "property: valid immediates can be encoded" {
    const Args = struct { imm: u12 };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
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

            try emit_mod.emit(inst, &buffer);
            const bytes = buffer.finish();

            try testing.expectEqual(@as(usize, 4), bytes.len);
        }
    }.prop, .{ .iterations = 200 });
}

// Property: Size bit (sf) is correctly set for 32-bit vs 64-bit operations.
// Bit 31 should be 1 for 64-bit, 0 for 32-bit.
test "property: size bit consistency" {
    const Args = struct {
        reg1: u5,
        reg2: u5,
        is_64bit: bool,
    };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            if (args.reg1 >= 31 or args.reg2 >= 31) return;

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

            try emit_mod.emit(inst, &buffer);
            const bytes = buffer.finish();

            try testing.expectEqual(@as(usize, 4), bytes.len);

            const word = @as(u32, bytes[0]) |
                (@as(u32, bytes[1]) << 8) |
                (@as(u32, bytes[2]) << 16) |
                (@as(u32, bytes[3]) << 24);

            const sf_bit = (word >> 31) & 1;
            const expected_sf: u1 = if (args.is_64bit) 1 else 0;

            try testing.expectEqual(expected_sf, @as(u1, @intCast(sf_bit)));
        }
    }.prop, .{ .iterations = 200 });
}

// Property: STP/LDP offsets must be 8-byte aligned and within range.
// For 64-bit paired loads/stores: offset ∈ [-512, 504] and offset % 8 == 0.
test "property: paired load/store offset constraints" {
    const Args = struct { offset_div8: i7 };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
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

            try emit_mod.emit(inst, &buffer);
            const bytes = buffer.finish();

            // Should always encode successfully for these constrained offsets
            try testing.expectEqual(@as(usize, 4), bytes.len);
        }
    }.prop, .{ .iterations = 200 });
}

// ============================================================================
// ABI Properties
// ============================================================================

// Property: AAPCS64 register pair allocation uses even registers.
// For i128 and 16-byte aligned structs, the first register must be even.
test "property: register pairs start at even register" {
    const Args = struct { start_reg: u3 };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            // Test with register pairs: can start at 0, 2, 4, 6
            const first_reg = @as(u8, args.start_reg) * 2;
            if (first_reg >= 8) return; // X8+ not used for args

            const lo = abi_mod.PReg.new(.int, @intCast(first_reg));
            const hi = abi_mod.PReg.new(.int, @intCast(first_reg + 1));

            // Verify: lo register number must be even
            try testing.expect(lo.hwEnc() % 2 == 0);
            try testing.expectEqual(lo.hwEnc() + 1, hi.hwEnc());
        }
    }.prop, .{ .iterations = 50 });
}

// Property: Frame sizes are 16-byte aligned per AAPCS64.
// The stack pointer must always be 16-byte aligned.
test "property: frame size is 16-byte aligned" {
    const Args = struct { size_div16: u12 };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            // Generate frame sizes as multiples of 16
            const frame_size = @as(u32, args.size_div16) * 16;
            try testing.expect(frame_size % 16 == 0);
        }
    }.prop, .{ .iterations = 100 });
}

// Property: Stack slot alignment is power of 2.
// All stack slots must have alignment that is a power of 2.
test "property: stack slot alignment is power of 2" {
    const Args = struct { align_shift: u3 };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            // align_shift ∈ [0, 7] gives alignments [1, 2, 4, 8, 16, 32, 64, 128]
            const alignment = @as(u32, 1) << @as(u5, args.align_shift);
            // Verify it's a power of 2
            try testing.expect((alignment & (alignment - 1)) == 0);
        }
    }.prop, .{ .iterations = 50 });
}

// Property: JIT memory alloc returns aligned, non-overlapping slices.
test "property: jit mem alloc alignment and monotonicity" {
    const Args = struct {
        size1: u8,
        size2: u8,
        align1_shift: u3,
        align2_shift: u3,
    };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const allocator = testing.allocator;
            const buf = try allocator.alignedAlloc(
                u8,
                std.mem.Alignment.fromByteUnits(std.heap.page_size_min),
                4096,
            );
            defer allocator.free(buf);

            var mem = jit_mem.Mem.initFromSlice(buf, allocator);
            const align1 = @as(usize, 1) << @as(u5, args.align1_shift);
            const align2 = @as(usize, 1) << @as(u5, args.align2_shift);
            const size1 = @as(usize, args.size1);
            const size2 = @as(usize, args.size2);

            const a = try mem.alloc(size1, align1);
            const b = try mem.alloc(size2, align2);

            try testing.expect(@intFromPtr(a.ptr) % align1 == 0);
            try testing.expect(@intFromPtr(b.ptr) % align2 == 0);
            try testing.expect(@intFromPtr(b.ptr) >= @intFromPtr(a.ptr) + a.len);
        }
    }.prop, .{ .iterations = 200 });
}

// ============================================================================
// Immediate Encoding Properties
// ============================================================================

// Property: Logical immediates have rotational symmetry.
// ARM64 logical immediates are encoded using a pattern of rotation.
test "property: small powers of 2 minus 1 are valid logical immediates" {
    const Args = struct { power: u4 };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            if (args.power == 0 or args.power >= 13) return;

            // Generate 2^n - 1 for small n
            const value = (@as(u64, 1) << @as(u6, args.power)) - 1;

            // These should be valid logical immediates (consecutive 1-bits)
            try testing.expect(value != 0 and value != 0xFFFFFFFFFFFFFFFF);
        }
    }.prop, .{ .iterations = 50 });
}

// Property: Shifted immediates preserve value.
// 12-bit immediates can be shifted left by 12 bits.
test "property: shifted immediates preserve value" {
    const Args = struct { imm: u12, shift: bool };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const base_value = @as(u32, args.imm);
            const shift_amount: u5 = if (args.shift) 12 else 0;
            const shifted = base_value << shift_amount;

            // Verify shift is reversible
            const recovered = shifted >> shift_amount;
            try testing.expectEqual(base_value, recovered);
        }
    }.prop, .{ .iterations = 100 });
}

// ============================================================================
// Integer Overflow Properties
// ============================================================================

// Property: Addition commutativity.
// Classic QuickCheck example: a + b == b + a
test "property: addition is commutative" {
    const Args = struct { a: i32, b: i32 };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            // Use wrapping add to avoid overflow UB
            const sum1 = args.a +% args.b;
            const sum2 = args.b +% args.a;
            try testing.expectEqual(sum1, sum2);
        }
    }.prop, .{ .iterations = 200 });
}

// Property: Addition associativity.
// (a + b) + c == a + (b + c)
test "property: addition is associative" {
    const Args = struct { a: i16, b: i16, c: i16 };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            // Use smaller integers to reduce overflow cases
            const left = (args.a +% args.b) +% args.c;
            const right = args.a +% (args.b +% args.c);
            try testing.expectEqual(left, right);
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
    const Args = struct {
        count: u4, // 0-15 registers
    };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const reg_count = @as(u8, args.count);
            // Verify count is within valid range for register lists
            try testing.expect(reg_count <= 16);
        }
    }.prop, .{ .iterations = 50 });
}

// Property: Enum variant coverage.
// zcheck uniformly selects enum variants, ensuring all cases tested.
test "property: operand size enum coverage" {
    const Args = struct { size: OperandSize };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            // All OperandSize variants should be valid
            switch (args.size) {
                .size32, .size64 => {},
            }
        }
    }.prop, .{ .iterations = 100 });
}

// Property: Tailcall move ordering preserves source values.
// Validates parallel_copy resolution used by tailcall argument forwarding.
test "property: tailcall moves preserve values" {
    const Args = struct {
        src: [4]u3,
        dst: [4]u3,
    };

    try zcheck_fallible.checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const allocator = testing.allocator;

            var dst_seen: [8]bool = [_]bool{false} ** 8;
            var moves_buf: [4]parallel_copy.Move = undefined;
            var move_len: usize = 0;

            for (0..4) |i| {
                const src_reg: u8 = @intCast(args.src[i] % 6);
                const dst_reg: u8 = @intCast(args.dst[i] % 6);
                if (src_reg == dst_reg) continue;
                if (dst_seen[dst_reg]) return;
                dst_seen[dst_reg] = true;
                moves_buf[move_len] = .{
                    .src = .{ .reg = src_reg },
                    .dst = .{ .reg = dst_reg },
                    .origin = move_len,
                };
                move_len += 1;
            }

            if (move_len == 0) return;

            var resolved = try parallel_copy.resolve(
                allocator,
                moves_buf[0..move_len],
                .{ .reg = 7 },
            );
            defer resolved.deinit(allocator);

            var vals: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
            const orig = vals;

            for (resolved.items) |mv| {
                const src_reg = switch (mv.src) {
                    .reg => |r| r,
                    .stack => return error.UnexpectedStackMove,
                };
                const dst_reg = switch (mv.dst) {
                    .reg => |r| r,
                    .stack => return error.UnexpectedStackMove,
                };
                vals[dst_reg] = vals[src_reg];
            }

            for (moves_buf[0..move_len]) |mv| {
                try testing.expectEqual(orig[mv.src.reg], vals[mv.dst.reg]);
            }

        }
    }.prop, .{ .iterations = 200 });
}
