//! Peephole optimization pass for post-regalloc instruction rewriting.
//!
//! Runs after register allocation but before emission. Performs local
//! pattern matching and rewriting to combine/optimize instruction sequences.
//!
//! Key optimizations:
//! - Load-pair combining: LDR X0, [SP]; LDR X1, [SP, #8] → LDP X0, X1, [SP]
//! - Store-pair combining: STR X0, [SP]; STR X1, [SP, #8] → STP X0, X1, [SP]
//! - Dead move elimination: MOV X0, X0 → (delete)
//! - Redundant load elimination: LDR X0, [SP]; LDR X0, [SP] → LDR X0, [SP]
//!
//! Constraints:
//! - Post-regalloc: all registers are physical (no vregs)
//! - Local only: patterns within a single basic block
//! - Conservative: preserve program semantics

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Generic peephole optimization interface.
/// Backends implement this for their instruction sets.
pub fn PeepholeOptimizer(comptime MachInst: type) type {
    return struct {
        allocator: Allocator,
        stats: Stats,

        const Self = @This();

        pub const Stats = struct {
            load_pairs_formed: u32 = 0,
            store_pairs_formed: u32 = 0,
            dead_moves_eliminated: u32 = 0,
            redundant_loads_eliminated: u32 = 0,

            pub fn total(self: Stats) u32 {
                return self.load_pairs_formed +
                    self.store_pairs_formed +
                    self.dead_moves_eliminated +
                    self.redundant_loads_eliminated;
            }
        };

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .stats = .{},
            };
        }

        /// Run peephole optimizations on a sequence of instructions.
        /// Modifies the instruction list in-place.
        pub fn optimize(self: *Self, insts: *std.ArrayList(MachInst)) !void {
            var changed = true;
            var iteration: u32 = 0;
            const max_iterations = 3; // Prevent infinite loops

            while (changed and iteration < max_iterations) {
                changed = false;
                iteration += 1;

                // Pattern matching happens in multiple passes
                // Each pass may enable subsequent passes

                // Pass 1: Combine adjacent loads into load-pairs
                if (try self.combineLoadPairs(insts)) {
                    changed = true;
                }

                // Pass 2: Combine adjacent stores into store-pairs
                if (try self.combineStorePairs(insts)) {
                    changed = true;
                }

                // Pass 3: Eliminate dead moves (mov reg, reg)
                if (try self.eliminateDeadMoves(insts)) {
                    changed = true;
                }

                // Pass 4: Eliminate redundant loads
                if (try self.eliminateRedundantLoads(insts)) {
                    changed = true;
                }
            }
        }

        /// Combine adjacent LDR instructions into LDP.
        /// Pattern: LDR Ra, [Rb, #off]; LDR Rc, [Rb, #off+8]
        /// Rewrite: LDP Ra, Rc, [Rb, #off]
        ///
        /// Constraints:
        /// - Same base register
        /// - Offsets differ by 8 bytes (for 64-bit)
        /// - Offset within LDP encoding range [-512, 504], multiple of 8
        /// - No writes to base register between the two loads
        /// - No writes to first destination before second load
        pub fn combineLoadPairs(self: *Self, insts: *std.ArrayList(MachInst)) !bool {
            if (!(@hasField(MachInst, "ldr") and @hasField(MachInst, "ldp"))) {
                return false;
            }

            var changed = false;
            var i: usize = 0;

            while (i + 1 < insts.items.len) {
                const inst1 = &insts.items[i];
                const inst2 = &insts.items[i + 1];

                if (inst1.* != .ldr or inst2.* != .ldr) {
                    i += 1;
                    continue;
                }

                const ldr1 = inst1.ldr;
                const ldr2 = inst2.ldr;

                if (ldr1.size != .size64 or ldr2.size != .size64) {
                    i += 1;
                    continue;
                }

                if (!std.meta.eql(ldr1.base, ldr2.base)) {
                    i += 1;
                    continue;
                }

                if (!canFormPair(ldr1.offset, ldr2.offset)) {
                    i += 1;
                    continue;
                }

                // Be conservative: if either load writes the base register,
                // pairing could change effective-address semantics.
                if (std.meta.eql(ldr1.dst.toReg(), ldr1.base) or
                    std.meta.eql(ldr2.dst.toReg(), ldr1.base))
                {
                    i += 1;
                    continue;
                }

                if (std.meta.eql(ldr1.dst.toReg(), ldr2.dst.toReg())) {
                    i += 1;
                    continue;
                }

                const ldp = MachInst{ .ldp = .{
                    .dst1 = ldr1.dst,
                    .dst2 = ldr2.dst,
                    .base = ldr1.base,
                    .offset = @intCast(ldr1.offset),
                    .size = .size64,
                } };

                insts.items[i] = ldp;
                _ = insts.orderedRemove(i + 1);

                self.stats.load_pairs_formed += 1;
                changed = true;
                i += 1;
            }

            return changed;
        }

        /// Combine adjacent STR instructions into STP.
        /// Pattern: STR Ra, [Rb, #off]; STR Rc, [Rb, #off+8]
        /// Rewrite: STP Ra, Rc, [Rb, #off]
        ///
        /// Constraints:
        /// - Same base register
        /// - Offsets differ by 8 bytes (for 64-bit)
        /// - Offset within STP encoding range [-512, 504], multiple of 8
        /// - No writes to base register between the two stores
        /// - No writes to source registers between stores
        pub fn combineStorePairs(self: *Self, insts: *std.ArrayList(MachInst)) !bool {
            if (!(@hasField(MachInst, "str") and @hasField(MachInst, "stp"))) {
                return false;
            }

            var changed = false;
            var i: usize = 0;

            while (i + 1 < insts.items.len) {
                const inst1 = &insts.items[i];
                const inst2 = &insts.items[i + 1];

                if (inst1.* != .str or inst2.* != .str) {
                    i += 1;
                    continue;
                }

                const str1 = inst1.str;
                const str2 = inst2.str;

                if (str1.size != .size64 or str2.size != .size64) {
                    i += 1;
                    continue;
                }

                if (!std.meta.eql(str1.base, str2.base)) {
                    i += 1;
                    continue;
                }

                if (!canFormPair(str1.offset, str2.offset)) {
                    i += 1;
                    continue;
                }

                const stp = MachInst{ .stp = .{
                    .src1 = str1.src,
                    .src2 = str2.src,
                    .base = str1.base,
                    .offset = @intCast(str1.offset),
                    .size = .size64,
                } };

                insts.items[i] = stp;
                _ = insts.orderedRemove(i + 1);

                self.stats.store_pairs_formed += 1;
                changed = true;
                i += 1;
            }

            return changed;
        }

        /// Eliminate dead moves where source and destination are identical.
        /// Pattern: MOV Ra, Ra
        /// Rewrite: (delete)
        pub fn eliminateDeadMoves(self: *Self, insts: *std.ArrayList(MachInst)) !bool {
            var changed = false;
            var i: usize = 0;

            while (i < insts.items.len) {
                const inst = &insts.items[i];
                var remove = false;

                if (@hasField(MachInst, "mov_rr")) {
                    if (inst.* == .mov_rr) {
                        const mov = inst.mov_rr;
                        if (std.meta.eql(mov.dst.toReg(), mov.src)) {
                            remove = true;
                        }
                    }
                }

                if (!remove and @hasField(MachInst, "fmov")) {
                    if (inst.* == .fmov) {
                        const mov = inst.fmov;
                        if (std.meta.eql(mov.dst.toReg(), mov.src)) {
                            remove = true;
                        }
                    }
                }

                if (!remove and @hasField(MachInst, "movss_rr")) {
                    if (inst.* == .movss_rr) {
                        const mov = inst.movss_rr;
                        if (std.meta.eql(mov.dst.toReg(), mov.src)) {
                            remove = true;
                        }
                    }
                }

                if (!remove and @hasField(MachInst, "movsd_rr")) {
                    if (inst.* == .movsd_rr) {
                        const mov = inst.movsd_rr;
                        if (std.meta.eql(mov.dst.toReg(), mov.src)) {
                            remove = true;
                        }
                    }
                }

                if (!remove and @hasField(MachInst, "movdqa_rr")) {
                    if (inst.* == .movdqa_rr) {
                        const mov = inst.movdqa_rr;
                        if (std.meta.eql(mov.dst.toReg(), mov.src)) {
                            remove = true;
                        }
                    }
                }

                if (!remove and @hasField(MachInst, "movdqu_rr")) {
                    if (inst.* == .movdqu_rr) {
                        const mov = inst.movdqu_rr;
                        if (std.meta.eql(mov.dst.toReg(), mov.src)) {
                            remove = true;
                        }
                    }
                }

                if (!remove and @hasField(MachInst, "movups_rr")) {
                    if (inst.* == .movups_rr) {
                        const mov = inst.movups_rr;
                        if (std.meta.eql(mov.dst.toReg(), mov.src)) {
                            remove = true;
                        }
                    }
                }

                if (!remove and @hasField(MachInst, "movupd_rr")) {
                    if (inst.* == .movupd_rr) {
                        const mov = inst.movupd_rr;
                        if (std.meta.eql(mov.dst.toReg(), mov.src)) {
                            remove = true;
                        }
                    }
                }

                if (remove) {
                    _ = insts.orderedRemove(i);
                    self.stats.dead_moves_eliminated += 1;
                    changed = true;
                    continue;
                }

                i += 1;
            }

            return changed;
        }

        /// Eliminate redundant loads from the same address.
        /// Pattern: LDR Ra, [Rb, #off]; ... safe insns ...; LDR Ra, [Rb, #off]
        /// Rewrite: LDR Ra, [Rb, #off]; ... no writes ...; (delete second LDR)
        ///
        /// Conservative policy: only skip over known-safe move/nop instructions
        /// that do not clobber the load base or destination registers.
        pub fn eliminateRedundantLoads(self: *Self, insts: *std.ArrayList(MachInst)) !bool {
            if (!@hasField(MachInst, "ldr")) {
                return false;
            }

            var changed = false;
            var i: usize = 0;

            while (i < insts.items.len) {
                const inst1 = &insts.items[i];
                if (inst1.* != .ldr) {
                    i += 1;
                    continue;
                }

                const ldr1 = inst1.ldr;
                var j = i + 1;
                var removed = false;

                while (j < insts.items.len) {
                    const inst2 = &insts.items[j];
                    if (inst2.* == .ldr) {
                        const ldr2 = inst2.ldr;
                        if (std.meta.eql(ldr1.base, ldr2.base) and
                            ldr1.offset == ldr2.offset and
                            ldr1.size == ldr2.size and
                            std.meta.eql(ldr1.dst.toReg(), ldr2.dst.toReg()))
                        {
                            _ = insts.orderedRemove(j);
                            self.stats.redundant_loads_eliminated += 1;
                            changed = true;
                            removed = true;
                        }
                        break;
                    }

                    if (!isSafeBetweenLoads(inst2.*, ldr1.base, ldr1.dst.toReg())) {
                        break;
                    }

                    j += 1;
                }

                if (removed) {
                    i += 1;
                    continue;
                }

                i += 1;
            }

            return changed;
        }

        fn isSafeBetweenLoads(inst: MachInst, base_reg: anytype, dst_reg: anytype) bool {
            if (@hasField(MachInst, "nop") and inst == .nop) {
                return true;
            }

            if (@hasField(MachInst, "mov_rr") and inst == .mov_rr) {
                const mov = inst.mov_rr;
                const wr = mov.dst.toReg();
                return !std.meta.eql(wr, base_reg) and !std.meta.eql(wr, dst_reg);
            }

            if (@hasField(MachInst, "fmov") and inst == .fmov) {
                const mov = inst.fmov;
                const wr = mov.dst.toReg();
                return !std.meta.eql(wr, base_reg) and !std.meta.eql(wr, dst_reg);
            }

            if (@hasField(MachInst, "movss_rr") and inst == .movss_rr) {
                const mov = inst.movss_rr;
                const wr = mov.dst.toReg();
                return !std.meta.eql(wr, base_reg) and !std.meta.eql(wr, dst_reg);
            }

            if (@hasField(MachInst, "movsd_rr") and inst == .movsd_rr) {
                const mov = inst.movsd_rr;
                const wr = mov.dst.toReg();
                return !std.meta.eql(wr, base_reg) and !std.meta.eql(wr, dst_reg);
            }

            if (@hasField(MachInst, "movdqa_rr") and inst == .movdqa_rr) {
                const mov = inst.movdqa_rr;
                const wr = mov.dst.toReg();
                return !std.meta.eql(wr, base_reg) and !std.meta.eql(wr, dst_reg);
            }

            if (@hasField(MachInst, "movdqu_rr") and inst == .movdqu_rr) {
                const mov = inst.movdqu_rr;
                const wr = mov.dst.toReg();
                return !std.meta.eql(wr, base_reg) and !std.meta.eql(wr, dst_reg);
            }

            if (@hasField(MachInst, "movups_rr") and inst == .movups_rr) {
                const mov = inst.movups_rr;
                const wr = mov.dst.toReg();
                return !std.meta.eql(wr, base_reg) and !std.meta.eql(wr, dst_reg);
            }

            if (@hasField(MachInst, "movupd_rr") and inst == .movupd_rr) {
                const mov = inst.movupd_rr;
                const wr = mov.dst.toReg();
                return !std.meta.eql(wr, base_reg) and !std.meta.eql(wr, dst_reg);
            }

            return false;
        }

        /// Get optimization statistics.
        pub fn getStats(self: *const Self) Stats {
            return self.stats;
        }

        /// Reset statistics counters.
        pub fn resetStats(self: *Self) void {
            self.stats = .{};
        }
    };
}

// ============================================================================
// Pattern Matching Utilities
// ============================================================================

/// Check if offset is valid for LDP/STP encoding.
/// AArch64 LDP/STP use 7-bit signed immediate scaled by 8.
/// Valid range: [-512, 504] in multiples of 8.
pub fn isValidPairOffset(offset: i32) bool {
    // Must be 8-byte aligned
    if (@rem(offset, 8) != 0) return false;

    // Scale to imm7
    const scaled = @divExact(offset, 8);

    // Check 7-bit signed range: -64 to +63
    return scaled >= -64 and scaled <= 63;
}

/// Check if two offsets are suitable for load/store pair combining.
/// Returns true if:
/// - offsets differ by exactly 8 bytes
/// - lower offset is valid for LDP/STP encoding
pub fn canFormPair(offset1: i32, offset2: i32) bool {
    const diff = offset2 - offset1;
    if (diff != 8) return false;

    return isValidPairOffset(offset1);
}

test "isValidPairOffset" {
    const testing = std.testing;

    // Valid offsets
    try testing.expect(isValidPairOffset(0));
    try testing.expect(isValidPairOffset(8));
    try testing.expect(isValidPairOffset(16));
    try testing.expect(isValidPairOffset(-8));
    try testing.expect(isValidPairOffset(-512)); // min
    try testing.expect(isValidPairOffset(504)); // max

    // Invalid: not 8-byte aligned
    try testing.expect(!isValidPairOffset(4));
    try testing.expect(!isValidPairOffset(12));

    // Invalid: out of range
    try testing.expect(!isValidPairOffset(-520));
    try testing.expect(!isValidPairOffset(512));
}

test "canFormPair" {
    const testing = std.testing;

    // Valid pairs
    try testing.expect(canFormPair(0, 8));
    try testing.expect(canFormPair(16, 24));
    try testing.expect(canFormPair(-16, -8));
    try testing.expect(canFormPair(496, 504)); // at max

    // Invalid: wrong spacing
    try testing.expect(!canFormPair(0, 16)); // diff = 16, not 8
    try testing.expect(!canFormPair(0, 4)); // diff = 4, not 8

    // Invalid: base offset out of range
    try testing.expect(!canFormPair(512, 520)); // base 512 too large (> 504)
}

test "eliminateDeadMoves removes self-moves" {
    const testing = std.testing;

    const TestReg = struct {
        bits: u8,
    };

    const TestWritableReg = struct {
        reg: TestReg,

        pub fn toReg(self: @This()) TestReg {
            return self.reg;
        }
    };

    const TestInst = union(enum) {
        mov_rr: struct { dst: TestWritableReg, src: TestReg },
        add_rr: struct { dst: TestWritableReg, src: TestReg },
    };

    var optimizer = PeepholeOptimizer(TestInst).init(testing.allocator);

    const r0 = TestReg{ .bits = 0 };
    const r1 = TestReg{ .bits = 1 };

    var insts: std.ArrayList(TestInst) = .{};
    defer insts.deinit(testing.allocator);

    try insts.append(testing.allocator, .{ .mov_rr = .{
        .dst = .{ .reg = r0 },
        .src = r0,
    } });
    try insts.append(testing.allocator, .{ .add_rr = .{
        .dst = .{ .reg = r0 },
        .src = r1,
    } });

    const changed = try optimizer.eliminateDeadMoves(&insts);

    try testing.expect(changed);
    try testing.expectEqual(@as(usize, 1), insts.items.len);
    try testing.expect(insts.items[0] == .add_rr);
    try testing.expectEqual(@as(u32, 1), optimizer.stats.dead_moves_eliminated);
}

test "eliminateRedundantLoads removes adjacent duplicate load" {
    const testing = std.testing;

    const TestReg = struct {
        bits: u8,
    };

    const TestWritableReg = struct {
        reg: TestReg,

        pub fn toReg(self: @This()) TestReg {
            return self.reg;
        }
    };

    const TestSize = enum { size32, size64 };

    const TestInst = union(enum) {
        ldr: struct { dst: TestWritableReg, base: TestReg, offset: i32, size: TestSize },
        nop: void,
    };

    var optimizer = PeepholeOptimizer(TestInst).init(testing.allocator);

    const r0 = TestReg{ .bits = 0 };
    const r1 = TestReg{ .bits = 1 };

    var insts: std.ArrayList(TestInst) = .{};
    defer insts.deinit(testing.allocator);

    try insts.append(testing.allocator, .{ .ldr = .{
        .dst = .{ .reg = r0 },
        .base = r1,
        .offset = 16,
        .size = .size64,
    } });
    try insts.append(testing.allocator, .{ .ldr = .{
        .dst = .{ .reg = r0 },
        .base = r1,
        .offset = 16,
        .size = .size64,
    } });

    const changed = try optimizer.eliminateRedundantLoads(&insts);

    try testing.expect(changed);
    try testing.expectEqual(@as(usize, 1), insts.items.len);
    try testing.expectEqual(@as(u32, 1), optimizer.stats.redundant_loads_eliminated);
}

test "eliminateRedundantLoads skips over safe move and nop" {
    const testing = std.testing;

    const TestReg = struct {
        bits: u8,
    };

    const TestWritableReg = struct {
        reg: TestReg,

        pub fn toReg(self: @This()) TestReg {
            return self.reg;
        }
    };

    const TestSize = enum { size32, size64 };

    const TestInst = union(enum) {
        ldr: struct { dst: TestWritableReg, base: TestReg, offset: i32, size: TestSize },
        mov_rr: struct { dst: TestWritableReg, src: TestReg },
        nop: void,
    };

    var optimizer = PeepholeOptimizer(TestInst).init(testing.allocator);

    const r0 = TestReg{ .bits = 0 };
    const r1 = TestReg{ .bits = 1 };
    const r2 = TestReg{ .bits = 2 };
    const r3 = TestReg{ .bits = 3 };

    var insts: std.ArrayList(TestInst) = .{};
    defer insts.deinit(testing.allocator);

    try insts.append(testing.allocator, .{ .ldr = .{
        .dst = .{ .reg = r0 },
        .base = r1,
        .offset = 16,
        .size = .size64,
    } });
    try insts.append(testing.allocator, .{ .mov_rr = .{
        .dst = .{ .reg = r2 },
        .src = r3,
    } });
    try insts.append(testing.allocator, .{ .nop = {} });
    try insts.append(testing.allocator, .{ .ldr = .{
        .dst = .{ .reg = r0 },
        .base = r1,
        .offset = 16,
        .size = .size64,
    } });

    const changed = try optimizer.eliminateRedundantLoads(&insts);

    try testing.expect(changed);
    try testing.expectEqual(@as(usize, 3), insts.items.len);
    try testing.expectEqual(@as(u32, 1), optimizer.stats.redundant_loads_eliminated);
}

test "eliminateRedundantLoads stops on clobber or store" {
    const testing = std.testing;

    const TestReg = struct {
        bits: u8,
    };

    const TestWritableReg = struct {
        reg: TestReg,

        pub fn toReg(self: @This()) TestReg {
            return self.reg;
        }
    };

    const TestSize = enum { size32, size64 };

    const TestInst = union(enum) {
        ldr: struct { dst: TestWritableReg, base: TestReg, offset: i32, size: TestSize },
        mov_rr: struct { dst: TestWritableReg, src: TestReg },
        str: struct { src: TestReg, base: TestReg, offset: i32, size: TestSize },
    };

    var optimizer = PeepholeOptimizer(TestInst).init(testing.allocator);

    const r0 = TestReg{ .bits = 0 };
    const r1 = TestReg{ .bits = 1 };
    const r2 = TestReg{ .bits = 2 };

    var clobber_insts: std.ArrayList(TestInst) = .{};
    defer clobber_insts.deinit(testing.allocator);

    try clobber_insts.append(testing.allocator, .{ .ldr = .{
        .dst = .{ .reg = r0 },
        .base = r1,
        .offset = 16,
        .size = .size64,
    } });
    try clobber_insts.append(testing.allocator, .{
        .mov_rr = .{
            .dst = .{ .reg = r1 }, // clobbers base
            .src = r2,
        },
    });
    try clobber_insts.append(testing.allocator, .{ .ldr = .{
        .dst = .{ .reg = r0 },
        .base = r1,
        .offset = 16,
        .size = .size64,
    } });

    const changed1 = try optimizer.eliminateRedundantLoads(&clobber_insts);
    try testing.expect(!changed1);
    try testing.expectEqual(@as(usize, 3), clobber_insts.items.len);

    optimizer.resetStats();

    var store_insts: std.ArrayList(TestInst) = .{};
    defer store_insts.deinit(testing.allocator);

    try store_insts.append(testing.allocator, .{ .ldr = .{
        .dst = .{ .reg = r0 },
        .base = r1,
        .offset = 16,
        .size = .size64,
    } });
    try store_insts.append(testing.allocator, .{ .str = .{
        .src = r2,
        .base = r1,
        .offset = 16,
        .size = .size64,
    } });
    try store_insts.append(testing.allocator, .{ .ldr = .{
        .dst = .{ .reg = r0 },
        .base = r1,
        .offset = 16,
        .size = .size64,
    } });

    const changed2 = try optimizer.eliminateRedundantLoads(&store_insts);
    try testing.expect(!changed2);
    try testing.expectEqual(@as(usize, 3), store_insts.items.len);
}

// ============================================================================
// Instruction Analysis Helpers
// ============================================================================

/// Generic interface for instruction analysis.
/// Backends implement this for their instruction sets.
pub fn InstAnalyzer(comptime MachInst: type, comptime Reg: type) type {
    return struct {
        /// Check if instruction is a load.
        pub fn isLoad(inst: *const MachInst) bool {
            _ = inst;
            return false; // Backend-specific
        }

        /// Check if instruction is a store.
        pub fn isStore(inst: *const MachInst) bool {
            _ = inst;
            return false; // Backend-specific
        }

        /// Check if instruction is a move.
        pub fn isMove(inst: *const MachInst) bool {
            _ = inst;
            return false; // Backend-specific
        }

        /// Check if instruction writes to a register.
        pub fn writesReg(inst: *const MachInst, reg: Reg) bool {
            _ = inst;
            _ = reg;
            return false; // Backend-specific
        }

        /// Check if instruction reads from a register.
        pub fn readsReg(inst: *const MachInst, reg: Reg) bool {
            _ = inst;
            _ = reg;
            return false; // Backend-specific
        }

        /// Check if instruction may write to memory.
        pub fn writesMemory(inst: *const MachInst) bool {
            _ = inst;
            return false; // Backend-specific
        }

        /// Check if instruction may read from memory.
        pub fn readsMemory(inst: *const MachInst) bool {
            _ = inst;
            return false; // Backend-specific
        }
    };
}
