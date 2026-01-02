const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const buffer_mod = @import("buffer.zig");
const CodeOffset = buffer_mod.CodeOffset;
const MachLabel = @import("machinst.zig").MachLabel;

/// Trampoline type for indirect calls and far jumps.
pub const TrampolineKind = enum {
    /// Direct jump trampoline (unconditional branch).
    /// Used when target is too far for direct encoding.
    direct_jump,
    /// Indirect call trampoline through PLT (Procedure Linkage Table).
    /// Used for calls to external functions in shared libraries.
    plt_call,
    /// Veneer for conditional branches that can't reach their target.
    /// Extends range via unconditional jump.
    conditional_veneer,
    /// Long-range call stub that loads target address into register.
    far_call,
};

/// Trampoline entry - a small stub that extends jump/call range.
pub const Trampoline = struct {
    /// Kind of trampoline.
    kind: TrampolineKind,
    /// Offset where this trampoline is located in the code buffer.
    offset: CodeOffset,
    /// Target label or external symbol this trampoline reaches.
    target: Target,
    /// Size in bytes of this trampoline.
    size: u32,

    pub const Target = union(enum) {
        /// Jump to a local label.
        label: MachLabel,
        /// Call to an external symbol.
        external: []const u8,
    };

    pub fn init(kind: TrampolineKind, offset: CodeOffset, target: Target, size: u32) Trampoline {
        return .{
            .kind = kind,
            .offset = offset,
            .target = target,
            .size = size,
        };
    }
};

/// Trampoline pool - manages code stubs for far calls and indirect jumps.
pub const TrampolinePool = struct {
    /// List of all trampolines.
    trampolines: std.ArrayList(Trampoline),
    /// Map from external symbol name to trampoline offset (for PLT stubs).
    plt_map: std.StringHashMap(CodeOffset),
    /// Allocator for memory management.
    allocator: Allocator,

    pub fn init(allocator: Allocator) TrampolinePool {
        return .{
            .trampolines = .{},
            .plt_map = std.StringHashMap(CodeOffset).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TrampolinePool) void {
        for (self.trampolines.items) |tramp| {
            if (tramp.target == .external) {
                self.allocator.free(tramp.target.external);
            }
        }
        self.trampolines.deinit(self.allocator);
        self.plt_map.deinit();
    }

    /// Add a trampoline to the pool.
    pub fn addTrampoline(
        self: *TrampolinePool,
        kind: TrampolineKind,
        offset: CodeOffset,
        target: Trampoline.Target,
        size: u32,
    ) !void {
        const owned_target = switch (target) {
            .label => target,
            .external => |name| blk: {
                const name_copy = try self.allocator.dupe(u8, name);
                break :blk Trampoline.Target{ .external = name_copy };
            },
        };

        const tramp = Trampoline.init(kind, offset, owned_target, size);
        try self.trampolines.append(self.allocator, tramp);

        // Track PLT stubs for deduplication.
        if (kind == .plt_call) {
            if (owned_target == .external) {
                try self.plt_map.put(owned_target.external, offset);
            }
        }
    }

    /// Find existing PLT stub for an external symbol.
    /// Returns null if no stub exists yet.
    pub fn findPLTStub(self: *const TrampolinePool, symbol: []const u8) ?CodeOffset {
        return self.plt_map.get(symbol);
    }

    /// Get all trampolines.
    pub fn getTrampolines(self: *const TrampolinePool) []const Trampoline {
        return self.trampolines.items;
    }

    /// Count trampolines of a specific kind.
    pub fn countKind(self: *const TrampolinePool, kind: TrampolineKind) usize {
        var count: usize = 0;
        for (self.trampolines.items) |tramp| {
            if (tramp.kind == kind) count += 1;
        }
        return count;
    }
};

/// Veneer generator - creates small stubs to extend branch range.
///
/// A veneer is a small piece of code that acts as an intermediate jump point,
/// allowing branches with limited range to reach distant targets.
pub const VeneerGenerator = struct {
    /// Architecture-specific veneer size (in bytes).
    veneer_size: u32,

    /// Create a veneer generator for the target architecture.
    pub fn init(arch: Architecture) VeneerGenerator {
        return .{
            .veneer_size = arch.veneerSize(),
        };
    }

    /// Calculate if a veneer is needed for a branch.
    /// Returns true if the offset exceeds the branch's encoding range.
    pub fn needsVeneer(self: VeneerGenerator, offset: i64, max_range: CodeOffset) bool {
        _ = self;
        const abs_offset = if (offset < 0) @as(u64, @intCast(-offset)) else @as(u64, @intCast(offset));
        return abs_offset > max_range;
    }

    /// Size in bytes required for a veneer.
    pub fn getVeneerSize(self: VeneerGenerator) u32 {
        return self.veneer_size;
    }
};

/// Architecture-specific configuration for trampolines and veneers.
pub const Architecture = enum {
    aarch64,
    x86_64,

    /// Size of a veneer in bytes for this architecture.
    pub fn veneerSize(self: Architecture) u32 {
        return switch (self) {
            // AArch64: single unconditional branch (B instruction) = 4 bytes
            .aarch64 => 4,
            // x86_64: JMP rel32 = 5 bytes (opcode + 4-byte offset)
            .x86_64 => 5,
        };
    }

    /// Size of a PLT stub in bytes for this architecture.
    pub fn pltStubSize(self: Architecture) u32 {
        return switch (self) {
            // AArch64 PLT stub:
            //   ADRP x16, GOT_page
            //   LDR x16, [x16, GOT_offset]
            //   BR x16
            // = 12 bytes
            .aarch64 => 12,
            // x86_64 PLT stub:
            //   JMP *GOT(%rip)
            //   PUSH index
            //   JMP PLT[0]
            // = 16 bytes
            .x86_64 => 16,
        };
    }

    /// Alignment requirement for trampolines.
    pub fn trampolineAlign(self: Architecture) u32 {
        return switch (self) {
            // AArch64: 4-byte aligned (instruction alignment)
            .aarch64 => 4,
            // x86_64: 1-byte aligned (no strict requirement)
            .x86_64 => 1,
        };
    }
};

/// Patch buffer to insert a trampoline at the given offset.
/// This is architecture-specific and should be implemented per backend.
pub const TrampolinePatcher = struct {
    arch: Architecture,

    pub fn init(arch: Architecture) TrampolinePatcher {
        return .{ .arch = arch };
    }

    /// Emit a veneer (unconditional branch) to the target offset.
    /// Returns the number of bytes written.
    pub fn emitVeneer(
        self: TrampolinePatcher,
        buffer: []u8,
        veneer_offset: CodeOffset,
        target_offset: CodeOffset,
    ) !u32 {
        switch (self.arch) {
            .aarch64 => {
                // AArch64 B instruction encoding:
                // 31-26: 000101 (opcode)
                // 25-0: signed offset in instructions (PC-relative)
                const pc_offset = @as(i64, @intCast(target_offset)) - @as(i64, @intCast(veneer_offset));
                const instr_offset = @divExact(pc_offset, 4);

                // Ensure offset fits in 26 bits.
                if (instr_offset < -(1 << 25) or instr_offset >= (1 << 25)) {
                    return error.VeneerTargetOutOfRange;
                }

                const imm26 = @as(u32, @intCast(instr_offset)) & 0x03FF_FFFF;
                const encoding = 0x1400_0000 | imm26;

                std.mem.writeInt(u32, buffer[0..4], encoding, .little);
                return 4;
            },
            .x86_64 => {
                // x86_64 JMP rel32 instruction:
                // Opcode: 0xE9
                // Operand: 32-bit signed offset from end of instruction
                const pc_offset = @as(i64, @intCast(target_offset)) - @as(i64, @intCast(veneer_offset + 5));

                if (pc_offset < std.math.minInt(i32) or pc_offset > std.math.maxInt(i32)) {
                    return error.VeneerTargetOutOfRange;
                }

                buffer[0] = 0xE9;
                std.mem.writeInt(i32, buffer[1..5], @as(i32, @intCast(pc_offset)), .little);
                return 5;
            },
        }
    }

    /// Emit a PLT stub for an external function call.
    /// Returns the number of bytes written.
    /// Note: actual GOT address patching happens during linking.
    pub fn emitPLTStub(
        self: TrampolinePatcher,
        buffer: []u8,
        _: CodeOffset,
    ) !u32 {
        switch (self.arch) {
            .aarch64 => {
                // AArch64 PLT stub pattern:
                //   ADRP x16, #0  (page offset, patched by linker)
                //   LDR x16, [x16, #0]  (page offset, patched by linker)
                //   BR x16

                // ADRP x16, #0
                std.mem.writeInt(u32, buffer[0..4], 0x9000_0010, .little);

                // LDR x16, [x16, #0]
                std.mem.writeInt(u32, buffer[4..8], 0xF940_0210, .little);

                // BR x16
                std.mem.writeInt(u32, buffer[8..12], 0xD61F_0200, .little);

                return 12;
            },
            .x86_64 => {
                // x86_64 PLT stub pattern:
                //   JMP *GOT(%rip)  (6 bytes: FF 25 00 00 00 00)
                buffer[0] = 0xFF;
                buffer[1] = 0x25;
                std.mem.writeInt(i32, buffer[2..6], 0, .little); // Patched by linker

                // PUSH index (5 bytes: 68 00 00 00 00)
                buffer[6] = 0x68;
                std.mem.writeInt(i32, buffer[7..11], 0, .little);

                // JMP PLT[0] (5 bytes: E9 00 00 00 00)
                buffer[11] = 0xE9;
                std.mem.writeInt(i32, buffer[12..16], 0, .little);

                return 16;
            },
        }
    }
};

test "TrampolinePool basic operations" {
    var pool = TrampolinePool.init(testing.allocator);
    defer pool.deinit();

    const target = Trampoline.Target{ .label = MachLabel.new(42) };
    try pool.addTrampoline(.direct_jump, 0x1000, target, 4);

    const trampolines = pool.getTrampolines();
    try testing.expectEqual(@as(usize, 1), trampolines.len);
    try testing.expectEqual(TrampolineKind.direct_jump, trampolines[0].kind);
    try testing.expectEqual(@as(CodeOffset, 0x1000), trampolines[0].offset);
    try testing.expectEqual(@as(u32, 4), trampolines[0].size);
}

test "TrampolinePool PLT deduplication" {
    var pool = TrampolinePool.init(testing.allocator);
    defer pool.deinit();

    const target = Trampoline.Target{ .external = "malloc" };
    try pool.addTrampoline(.plt_call, 0x2000, target, 12);

    const stub_offset = pool.findPLTStub("malloc");
    try testing.expect(stub_offset != null);
    try testing.expectEqual(@as(CodeOffset, 0x2000), stub_offset.?);

    try testing.expect(pool.findPLTStub("free") == null);
}

test "TrampolinePool count by kind" {
    var pool = TrampolinePool.init(testing.allocator);
    defer pool.deinit();

    try pool.addTrampoline(.direct_jump, 0x1000, .{ .label = MachLabel.new(1) }, 4);
    try pool.addTrampoline(.plt_call, 0x2000, .{ .external = "foo" }, 12);
    try pool.addTrampoline(.direct_jump, 0x3000, .{ .label = MachLabel.new(2) }, 4);

    try testing.expectEqual(@as(usize, 2), pool.countKind(.direct_jump));
    try testing.expectEqual(@as(usize, 1), pool.countKind(.plt_call));
    try testing.expectEqual(@as(usize, 0), pool.countKind(.conditional_veneer));
}

test "VeneerGenerator needs veneer check" {
    const gen = VeneerGenerator.init(.aarch64);

    // Within range - no veneer needed
    try testing.expect(!gen.needsVeneer(1000, 1 << 20));

    // Out of range - veneer needed
    try testing.expect(gen.needsVeneer(2_000_000, 1 << 20));
    try testing.expect(gen.needsVeneer(-2_000_000, 1 << 20));
}

test "Architecture veneer size" {
    try testing.expectEqual(@as(u32, 4), Architecture.aarch64.veneerSize());
    try testing.expectEqual(@as(u32, 5), Architecture.x86_64.veneerSize());
}

test "Architecture PLT stub size" {
    try testing.expectEqual(@as(u32, 12), Architecture.aarch64.pltStubSize());
    try testing.expectEqual(@as(u32, 16), Architecture.x86_64.pltStubSize());
}

test "Architecture trampoline alignment" {
    try testing.expectEqual(@as(u32, 4), Architecture.aarch64.trampolineAlign());
    try testing.expectEqual(@as(u32, 1), Architecture.x86_64.trampolineAlign());
}

test "TrampolinePatcher emit veneer AArch64" {
    const patcher = TrampolinePatcher.init(.aarch64);
    var buffer: [4]u8 = undefined;

    // Forward branch by 1024 bytes (256 instructions)
    const bytes_written = try patcher.emitVeneer(&buffer, 0x1000, 0x1400);
    try testing.expectEqual(@as(u32, 4), bytes_written);

    // Check encoding: B #256
    // Offset in instructions: (0x1400 - 0x1000) / 4 = 256
    const encoding = std.mem.readInt(u32, &buffer, .little);
    try testing.expectEqual(@as(u32, 0x1400_0100), encoding);
}

test "TrampolinePatcher emit veneer x86_64" {
    const patcher = TrampolinePatcher.init(.x86_64);
    var buffer: [5]u8 = undefined;

    // Forward jump by 1000 bytes
    const bytes_written = try patcher.emitVeneer(&buffer, 0x1000, 0x13E9);
    try testing.expectEqual(@as(u32, 5), bytes_written);

    // Check encoding: JMP rel32
    try testing.expectEqual(@as(u8, 0xE9), buffer[0]);

    // Offset: 0x13E9 - (0x1000 + 5) = 0x3E4
    const offset = std.mem.readInt(i32, buffer[1..5], .little);
    try testing.expectEqual(@as(i32, 0x3E4), offset);
}

test "TrampolinePatcher emit PLT stub AArch64" {
    const patcher = TrampolinePatcher.init(.aarch64);
    var buffer: [12]u8 = undefined;

    const bytes_written = try patcher.emitPLTStub(&buffer, 0x2000);
    try testing.expectEqual(@as(u32, 12), bytes_written);

    // Check first instruction: ADRP x16, #0
    const adrp = std.mem.readInt(u32, buffer[0..4], .little);
    try testing.expectEqual(@as(u32, 0x9000_0010), adrp);

    // Check second instruction: LDR x16, [x16, #0]
    const ldr = std.mem.readInt(u32, buffer[4..8], .little);
    try testing.expectEqual(@as(u32, 0xF940_0210), ldr);

    // Check third instruction: BR x16
    const br = std.mem.readInt(u32, buffer[8..12], .little);
    try testing.expectEqual(@as(u32, 0xD61F_0200), br);
}

test "TrampolinePatcher emit PLT stub x86_64" {
    const patcher = TrampolinePatcher.init(.x86_64);
    var buffer: [16]u8 = undefined;

    const bytes_written = try patcher.emitPLTStub(&buffer, 0x3000);
    try testing.expectEqual(@as(u32, 16), bytes_written);

    // Check JMP *GOT(%rip)
    try testing.expectEqual(@as(u8, 0xFF), buffer[0]);
    try testing.expectEqual(@as(u8, 0x25), buffer[1]);

    // Check PUSH index
    try testing.expectEqual(@as(u8, 0x68), buffer[6]);

    // Check JMP PLT[0]
    try testing.expectEqual(@as(u8, 0xE9), buffer[11]);
}

test "TrampolinePatcher veneer out of range" {
    const patcher = TrampolinePatcher.init(.aarch64);
    var buffer: [4]u8 = undefined;

    // Try to create a veneer that's too far (> ±128MB for AArch64)
    const result = patcher.emitVeneer(&buffer, 0, 200_000_000);
    try testing.expectError(error.VeneerTargetOutOfRange, result);
}
