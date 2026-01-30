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
    return optimizer.combineLoadPairs(insts);
}

/// AArch64-specific store-pair combining implementation.
/// Combines adjacent STR instructions into STP when possible.
pub fn combineStorePairs(
    optimizer: *AArch64PeepholeOptimizer,
    insts: *std.ArrayList(Inst),
) !bool {
    return optimizer.combineStorePairs(insts);
}

/// AArch64-specific dead move elimination.
/// Removes MOV instructions where source and destination are identical.
pub fn eliminateDeadMoves(
    optimizer: *AArch64PeepholeOptimizer,
    insts: *std.ArrayList(Inst),
) !bool {
    return optimizer.eliminateDeadMoves(insts);
}

/// AArch64-specific redundant load elimination.
/// Removes adjacent duplicate loads from the same address into the same register.
pub fn eliminateRedundantLoads(
    optimizer: *AArch64PeepholeOptimizer,
    insts: *std.ArrayList(Inst),
) !bool {
    return optimizer.eliminateRedundantLoads(insts);
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
