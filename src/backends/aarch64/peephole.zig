//! AArch64-specific peephole optimizations.
//!
//! Implements load-pair and store-pair combining for AArch64 backend.

const std = @import("std");
const Allocator = std.mem.Allocator;
const peephole_mod = @import("../../codegen/peephole.zig");
const inst_mod = @import("inst.zig");
const reg_mod = @import("../../machinst/reg.zig");

const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const PReg = reg_mod.PReg;
const RegClass = reg_mod.RegClass;
const OperandSize = inst_mod.OperandSize;

inline fn regEq(a: Reg, b: Reg) bool {
    return a.bits == b.bits;
}

pub const AArch64PeepholeOptimizer = peephole_mod.PeepholeOptimizer(Inst);

/// AArch64-specific load-pair combining implementation.
/// Combines adjacent LDR instructions into LDP when possible.
pub fn combineLoadPairs(
    optimizer: *AArch64PeepholeOptimizer,
    insts: *std.ArrayList(Inst),
) !bool {
    var changed = false;
    var i: usize = 0;

    while (i + 1 < insts.items.len) {
        const inst1 = &insts.items[i];
        const inst2 = &insts.items[i + 1];

        // Check if both are LDR instructions
        if (inst1.* != .ldr or inst2.* != .ldr) {
            i += 1;
            continue;
        }

        const ldr1 = inst1.ldr;
        const ldr2 = inst2.ldr;

        // Must be same size (only combine 64-bit loads for now)
        if (ldr1.size != .size64 or ldr2.size != .size64) {
            i += 1;
            continue;
        }

        // Must have same base register
        if (!regEq(ldr1.base, ldr2.base)) {
            i += 1;
            continue;
        }

        // Check if offsets are suitable for pairing
        const offset1 = ldr1.offset;
        const offset2 = ldr2.offset;

        if (!peephole_mod.canFormPair(offset1, offset2)) {
            i += 1;
            continue;
        }

        // Check for hazards between the two loads:
        // 1. Base register must not be written between loads
        // 2. First destination must not be written before second load
        // 3. Destinations must be different registers
        if (regEq(ldr1.dst.toReg(), ldr2.dst.toReg())) {
            i += 1;
            continue;
        }

        // Since we're only looking at adjacent instructions, no intervening
        // writes are possible. In a more sophisticated implementation, we
        // could look for non-adjacent pairs with intervening instructions.

        // Form the LDP instruction
        const ldp = Inst{ .ldp = .{
            .dst1 = ldr1.dst,
            .dst2 = ldr2.dst,
            .base = ldr1.base,
            .offset = @intCast(offset1),
            .size = .size64,
        } };

        // Replace first load with LDP
        insts.items[i] = ldp;

        // Remove second load
        _ = insts.orderedRemove(i + 1);

        // Update statistics
        optimizer.stats.load_pairs_formed += 1;
        changed = true;

        // Continue from the LDP instruction
        i += 1;
    }

    return changed;
}

/// AArch64-specific store-pair combining implementation.
/// Combines adjacent STR instructions into STP when possible.
pub fn combineStorePairs(
    optimizer: *AArch64PeepholeOptimizer,
    insts: *std.ArrayList(Inst),
) !bool {
    var changed = false;
    var i: usize = 0;

    while (i + 1 < insts.items.len) {
        const inst1 = &insts.items[i];
        const inst2 = &insts.items[i + 1];

        // Check if both are STR instructions
        if (inst1.* != .str or inst2.* != .str) {
            i += 1;
            continue;
        }

        const str1 = inst1.str;
        const str2 = inst2.str;

        // Must be same size (only combine 64-bit stores for now)
        if (str1.size != .size64 or str2.size != .size64) {
            i += 1;
            continue;
        }

        // Must have same base register
        if (!regEq(str1.base, str2.base)) {
            i += 1;
            continue;
        }

        // Check if offsets are suitable for pairing
        const offset1 = str1.offset;
        const offset2 = str2.offset;

        if (!peephole_mod.canFormPair(offset1, offset2)) {
            i += 1;
            continue;
        }

        // Check for hazards:
        // 1. Base register must not be written between stores
        // 2. Source registers must not be written between stores
        // (Both automatically satisfied for adjacent instructions)

        // Form the STP instruction
        const stp = Inst{ .stp = .{
            .src1 = str1.src,
            .src2 = str2.src,
            .base = str1.base,
            .offset = @intCast(offset1),
            .size = .size64,
        } };

        // Replace first store with STP
        insts.items[i] = stp;

        // Remove second store
        _ = insts.orderedRemove(i + 1);

        // Update statistics
        optimizer.stats.store_pairs_formed += 1;
        changed = true;

        // Continue from the STP instruction
        i += 1;
    }

    return changed;
}

/// AArch64-specific dead move elimination.
/// Removes MOV instructions where source and destination are identical.
pub fn eliminateDeadMoves(
    optimizer: *AArch64PeepholeOptimizer,
    insts: *std.ArrayList(Inst),
) !bool {
    var changed = false;
    var i: usize = 0;

    while (i < insts.items.len) {
        const inst = &insts.items[i];

        // Check for MOV Xd, Xd
        if (inst.* == .mov_rr) {
            const mov = inst.mov_rr;
            if (regEq(mov.dst.toReg(), mov.src)) {
                // Dead move - remove it
                _ = insts.orderedRemove(i);
                optimizer.stats.dead_moves_eliminated += 1;
                changed = true;
                // Don't increment i - check the new instruction at this index
                continue;
            }
        }

        // Check for FMOV Vd, Vd
        if (inst.* == .fmov) {
            const fmov = inst.fmov;
            if (regEq(fmov.dst.toReg(), fmov.src)) {
                // Dead move - remove it
                _ = insts.orderedRemove(i);
                optimizer.stats.dead_moves_eliminated += 1;
                changed = true;
                continue;
            }
        }

        i += 1;
    }

    return changed;
}

test "combineLoadPairs: adjacent loads with consecutive offsets" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var optimizer = AArch64PeepholeOptimizer.init(allocator);

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const sp = Reg.fromPReg(PReg.new(.int, 31));
    const x0_w = inst_mod.WritableReg.fromReg(x0);
    const x1_w = inst_mod.WritableReg.fromReg(x1);

    var insts: std.ArrayList(Inst) = .{};
    defer insts.deinit(allocator);

    // LDR X0, [SP, #0]
    try insts.append(allocator, .{ .ldr = .{
        .dst = x0_w,
        .base = sp,
        .offset = 0,
        .size = .size64,
    } });

    // LDR X1, [SP, #8]
    try insts.append(allocator, .{ .ldr = .{
        .dst = x1_w,
        .base = sp,
        .offset = 8,
        .size = .size64,
    } });

    const changed = try combineLoadPairs(&optimizer, &insts);

    try testing.expect(changed);
    try testing.expectEqual(@as(usize, 1), insts.items.len);
    try testing.expect(insts.items[0] == .ldp);
    try testing.expectEqual(@as(u32, 1), optimizer.stats.load_pairs_formed);

    const ldp = insts.items[0].ldp;
    try testing.expect(regEq(ldp.dst1.toReg(), x0));
    try testing.expect(regEq(ldp.dst2.toReg(), x1));
    try testing.expect(regEq(ldp.base, sp));
    try testing.expectEqual(@as(i16, 0), ldp.offset);
}

test "combineLoadPairs: loads with same destination - skip" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var optimizer = AArch64PeepholeOptimizer.init(allocator);

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const sp = Reg.fromPReg(PReg.new(.int, 31));
    const x0_w = inst_mod.WritableReg.fromReg(x0);

    var insts: std.ArrayList(Inst) = .{};
    defer insts.deinit(allocator);

    // LDR X0, [SP, #0]
    try insts.append(allocator, .{ .ldr = .{
        .dst = x0_w,
        .base = sp,
        .offset = 0,
        .size = .size64,
    } });

    // LDR X0, [SP, #8] - same destination!
    try insts.append(allocator, .{ .ldr = .{
        .dst = x0_w,
        .base = sp,
        .offset = 8,
        .size = .size64,
    } });

    const changed = try combineLoadPairs(&optimizer, &insts);

    try testing.expect(!changed);
    try testing.expectEqual(@as(usize, 2), insts.items.len);
    try testing.expectEqual(@as(u32, 0), optimizer.stats.load_pairs_formed);
}

test "combineStorePairs: adjacent stores with consecutive offsets" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var optimizer = AArch64PeepholeOptimizer.init(allocator);

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const sp = Reg.fromPReg(PReg.new(.int, 31));

    var insts: std.ArrayList(Inst) = .{};
    defer insts.deinit(allocator);

    // STR X0, [SP, #16]
    try insts.append(allocator, .{ .str = .{
        .src = x0,
        .base = sp,
        .offset = 16,
        .size = .size64,
    } });

    // STR X1, [SP, #24]
    try insts.append(allocator, .{ .str = .{
        .src = x1,
        .base = sp,
        .offset = 24,
        .size = .size64,
    } });

    const changed = try combineStorePairs(&optimizer, &insts);

    try testing.expect(changed);
    try testing.expectEqual(@as(usize, 1), insts.items.len);
    try testing.expect(insts.items[0] == .stp);
    try testing.expectEqual(@as(u32, 1), optimizer.stats.store_pairs_formed);

    const stp = insts.items[0].stp;
    try testing.expect(regEq(stp.src1, x0));
    try testing.expect(regEq(stp.src2, x1));
    try testing.expect(regEq(stp.base, sp));
    try testing.expectEqual(@as(i16, 16), stp.offset);
}

test "eliminateDeadMoves: removes mov reg, reg" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var optimizer = AArch64PeepholeOptimizer.init(allocator);

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x0_w = inst_mod.WritableReg.fromReg(x0);

    var insts: std.ArrayList(Inst) = .{};
    defer insts.deinit(allocator);

    // MOV X0, X0 - dead move
    try insts.append(allocator, .{ .mov_rr = .{
        .dst = x0_w,
        .src = x0,
        .size = .size64,
    } });

    const changed = try eliminateDeadMoves(&optimizer, &insts);

    try testing.expect(changed);
    try testing.expectEqual(@as(usize, 0), insts.items.len);
    try testing.expectEqual(@as(u32, 1), optimizer.stats.dead_moves_eliminated);
}
