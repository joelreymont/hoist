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
        fn combineLoadPairs(self: *Self, insts: *std.ArrayList(MachInst)) !bool {
            _ = self;
            _ = insts;
            // TODO: Implement load-pair combining
            // This requires backend-specific instruction analysis
            return false;
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
        fn combineStorePairs(self: *Self, insts: *std.ArrayList(MachInst)) !bool {
            _ = self;
            _ = insts;
            // TODO: Implement store-pair combining
            return false;
        }

        /// Eliminate dead moves where source and destination are identical.
        /// Pattern: MOV Ra, Ra
        /// Rewrite: (delete)
        fn eliminateDeadMoves(self: *Self, insts: *std.ArrayList(MachInst)) !bool {
            _ = self;
            _ = insts;
            // TODO: Implement dead move elimination
            return false;
        }

        /// Eliminate redundant loads from the same address.
        /// Pattern: LDR Ra, [Rb, #off]; ... no writes to [Rb, #off] ...; LDR Ra, [Rb, #off]
        /// Rewrite: LDR Ra, [Rb, #off]; ... no writes ...; (delete second LDR)
        ///
        /// Requires: Alias analysis to prove no intervening writes
        fn eliminateRedundantLoads(self: *Self, insts: *std.ArrayList(MachInst)) !bool {
            _ = self;
            _ = insts;
            // TODO: Implement redundant load elimination
            // Requires alias analysis infrastructure
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
