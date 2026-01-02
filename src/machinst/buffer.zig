const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const machinst = @import("machinst.zig");
const MachLabel = machinst.MachLabel;

/// Code offset in bytes from the start of the function.
pub const CodeOffset = u32;

/// Relocation type for external symbols.
pub const Reloc = enum {
    /// Absolute 8-byte pointer.
    abs8,
    /// PC-relative 32-bit signed offset.
    x86_pc_rel_32,
    /// Absolute 4-byte pointer.
    abs4,
};

/// Addend for relocations.
pub const Addend = i64;

/// External relocation entry.
pub const MachReloc = struct {
    /// Offset in the code where this relocation applies.
    offset: CodeOffset,
    /// Type of relocation.
    kind: Reloc,
    /// Name of the external symbol.
    name: []const u8,
    /// Addend to apply.
    addend: Addend,
};

/// Trap code for exceptional conditions.
pub const TrapCode = enum {
    /// Stack overflow.
    stack_overflow,
    /// Heap out of bounds.
    heap_out_of_bounds,
    /// Integer division by zero.
    int_div_by_zero,
    /// Unreachable code executed.
    unreachable_code_reached,
};

/// Trap site record.
pub const MachTrap = struct {
    /// Offset in the code where the trap instruction is.
    offset: CodeOffset,
    /// Trap code.
    code: TrapCode,
};

/// Label fixup record - tracks unresolved label references.
const LabelFixup = struct {
    /// Label being referenced.
    label: MachLabel,
    /// Offset in code buffer where the reference is.
    offset: CodeOffset,
    /// How to patch the reference (PC-relative offset size).
    kind: LabelUseKind,
};

/// Kind of label use - how the label reference should be encoded.
pub const LabelUseKind = enum {
    /// PC-relative 8-bit signed offset.
    pc_rel8,
    /// PC-relative 32-bit signed offset.
    pc_rel32,
    /// AArch64 conditional branch - 19-bit PC-relative (±1MB range).
    /// Used by: B.cond, CBZ, CBNZ, TBZ, TBNZ
    branch19,
    /// AArch64 unconditional branch - 26-bit PC-relative (±128MB range).
    /// Used by: B, BL
    branch26,
    /// AArch64 ADR - 21-bit PC-relative (±1MB range).
    adr21,
    /// AArch64 LDR literal - 19-bit PC-relative word offset (±1MB range).
    /// Used for constant pool access.
    ldr_literal19,

    pub fn patchSize(self: LabelUseKind) CodeOffset {
        return switch (self) {
            .pc_rel8 => 1,
            .pc_rel32 => 4,
            .branch19, .branch26, .adr21, .ldr_literal19 => 4,
        };
    }

    pub fn maxPosRange(self: LabelUseKind) CodeOffset {
        return switch (self) {
            .pc_rel8 => 127,
            .pc_rel32 => 0x7FFF_FFFF,
            .branch19 => 1 << 20,
            .branch26 => 1 << 27,
            .adr21 => 1 << 20,
            .ldr_literal19 => 1 << 20,
        };
    }

    pub fn maxNegRange(self: LabelUseKind) CodeOffset {
        return switch (self) {
            .pc_rel8 => 128,
            .pc_rel32 => 0x8000_0000,
            .branch19 => 1 << 20,
            .branch26 => 1 << 27,
            .adr21 => 1 << 20,
            .ldr_literal19 => 1 << 20,
        };
    }
};

/// Machine code buffer with label resolution and fixups.
pub const MachBuffer = struct {
    /// Raw bytes of emitted code.
    data: std.ArrayList(u8),
    /// External relocations.
    relocs: std.ArrayList(MachReloc),
    /// Trap records.
    traps: std.ArrayList(MachTrap),
    /// Pending label fixups.
    fixups: std.ArrayList(LabelFixup),
    /// Resolved label offsets (UNKNOWN_OFFSET if not yet bound).
    label_offsets: std.ArrayList(CodeOffset),
    /// Allocator for dynamic allocations.
    allocator: Allocator,

    const UNKNOWN_OFFSET: CodeOffset = 0xFFFF_FFFF;

    pub fn init(allocator: Allocator) MachBuffer {
        return .{
            .data = std.ArrayList(u8){},
            .relocs = std.ArrayList(MachReloc){},
            .traps = std.ArrayList(MachTrap){},
            .fixups = std.ArrayList(LabelFixup){},
            .label_offsets = std.ArrayList(CodeOffset){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MachBuffer) void {
        self.data.deinit(self.allocator);
        self.relocs.deinit(self.allocator);
        self.traps.deinit(self.allocator);
        self.fixups.deinit(self.allocator);
        self.label_offsets.deinit(self.allocator);
    }

    /// Get current code offset.
    pub fn curOffset(self: *const MachBuffer) CodeOffset {
        return @intCast(self.data.items.len);
    }

    /// Emit raw bytes into the buffer.
    pub fn putData(self: *MachBuffer, bytes: []const u8) !void {
        try self.data.appendSlice(self.allocator, bytes);
    }

    /// Emit a single byte.
    pub fn put1(self: *MachBuffer, byte: u8) !void {
        try self.data.append(self.allocator, byte);
    }

    /// Emit a 4-byte value (little-endian).
    pub fn put4(self: *MachBuffer, value: u32) !void {
        var bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &bytes, value, .little);
        try self.data.appendSlice(self.allocator, &bytes);
    }

    /// Emit an 8-byte value (little-endian).
    pub fn put8(self: *MachBuffer, value: u64) !void {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, value, .little);
        try self.data.appendSlice(self.allocator, &bytes);
    }

    /// Allocate a new label.
    pub fn allocLabel(self: *MachBuffer) !MachLabel {
        const index: u32 = @intCast(self.label_offsets.items.len);
        try self.label_offsets.append(self.allocator, UNKNOWN_OFFSET);
        return MachLabel.new(index);
    }

    /// Bind a label to the current offset.
    pub fn bindLabel(self: *MachBuffer, label: MachLabel) !void {
        const offset = self.curOffset();
        if (label.index < self.label_offsets.items.len) {
            self.label_offsets.items[label.index] = offset;
        } else {
            return error.InvalidLabel;
        }
    }

    /// Add a label use (forward or backward reference).
    pub fn useLabelAtOffset(
        self: *MachBuffer,
        offset: CodeOffset,
        label: MachLabel,
        kind: LabelUseKind,
    ) !void {
        try self.fixups.append(self.allocator, .{
            .label = label,
            .offset = offset,
            .kind = kind,
        });
    }

    /// Convenience wrapper - use label at current offset.
    pub fn useLabel(self: *MachBuffer, label: MachLabel, kind: LabelUseKind) !void {
        const offset = self.curOffset();
        try self.useLabelAtOffset(offset, label, kind);
    }

    /// Add an external relocation.
    pub fn addReloc(
        self: *MachBuffer,
        offset: CodeOffset,
        kind: Reloc,
        name: []const u8,
        addend: Addend,
    ) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        try self.relocs.append(self.allocator, .{
            .offset = offset,
            .kind = kind,
            .name = owned_name,
            .addend = addend,
        });
    }

    /// Add a trap record.
    pub fn addTrap(self: *MachBuffer, offset: CodeOffset, code: TrapCode) !void {
        try self.traps.append(self.allocator, .{
            .offset = offset,
            .code = code,
        });
    }

    /// Patch a 19-bit branch offset into an instruction.
    /// Used by B.cond (bits [23:5]), CBZ/CBNZ, TBZ/TBNZ
    fn patchBranch19(insn_bytes: *[4]u8, offset: i64) !void {
        const offset_bits: u32 = @bitCast(@as(i32, @intCast(offset & 0x7FFFF)));
        var insn = std.mem.readInt(u32, insn_bytes, .little);
        // Clear bits [23:5], insert offset
        insn &= ~(@as(u32, 0x7FFFF) << 5);
        insn |= offset_bits << 5;
        std.mem.writeInt(u32, insn_bytes, insn, .little);
    }

    /// Patch a 26-bit branch offset into an instruction.
    /// Used by B, BL (bits [25:0])
    fn patchBranch26(insn_bytes: *[4]u8, offset: i64) !void {
        const offset_bits: u32 = @bitCast(@as(i32, @intCast(offset & 0x3FFFFFF)));
        var insn = std.mem.readInt(u32, insn_bytes, .little);
        // Clear bits [25:0], insert offset
        insn &= ~@as(u32, 0x3FFFFFF);
        insn |= offset_bits;
        std.mem.writeInt(u32, insn_bytes, insn, .little);
    }

    /// Patch ADR instruction with 21-bit byte offset.
    fn patchAdr21(insn_bytes: *[4]u8, offset: i64) !void {
        var insn = std.mem.readInt(u32, insn_bytes, .little);
        const offset_u: u32 = @bitCast(@as(i32, @intCast(offset)));
        // ADR encoding: immlo [30:29], immhi [23:5]
        const immlo = offset_u & 0x3;
        const immhi = (offset_u >> 2) & 0x7FFFF;
        insn &= ~((@as(u32, 0x3) << 29) | (@as(u32, 0x7FFFF) << 5));
        insn |= (immlo << 29) | (immhi << 5);
        std.mem.writeInt(u32, insn_bytes, insn, .little);
    }

    /// Patch LDR literal instruction with 19-bit word offset.
    fn patchLdrLiteral19(insn_bytes: *[4]u8, offset: i64) !void {
        const offset_bits: u32 = @bitCast(@as(i32, @intCast(offset & 0x7FFFF)));
        var insn = std.mem.readInt(u32, insn_bytes, .little);
        // LDR literal: bits [23:5]
        insn &= ~(@as(u32, 0x7FFFF) << 5);
        insn |= offset_bits << 5;
        std.mem.writeInt(u32, insn_bytes, insn, .little);
    }

    /// Resolve all label fixups.
    pub fn finalize(self: *MachBuffer) !void {
        for (self.fixups.items) |fixup| {
            const label_offset = self.label_offsets.items[fixup.label.index];
            if (label_offset == UNKNOWN_OFFSET) {
                return error.UnresolvedLabel;
            }

            // Calculate PC-relative offset.
            // PC points to the byte after the offset field.
            const pc = fixup.offset + fixup.kind.patchSize();
            const delta: i64 = @as(i64, @intCast(label_offset)) - @as(i64, @intCast(pc));

            // Patch the offset into the code.
            switch (fixup.kind) {
                .pc_rel8 => {
                    if (delta < -128 or delta > 127) {
                        return error.LabelOutOfRange;
                    }
                    self.data.items[fixup.offset] = @bitCast(@as(i8, @intCast(delta)));
                },
                .pc_rel32 => {
                    if (delta < std.math.minInt(i32) or delta > std.math.maxInt(i32)) {
                        return error.LabelOutOfRange;
                    }
                    const val: u32 = @bitCast(@as(i32, @intCast(delta)));
                    std.mem.writeInt(u32, self.data.items[fixup.offset..][0..4], val, .little);
                },
                .branch19 => {
                    // B.cond, CBZ, CBNZ: 19-bit signed offset in instructions (word offset)
                    // For AArch64, PC points to the instruction itself
                    const pc_aarch64 = fixup.offset;
                    const delta_aarch64: i64 = @as(i64, @intCast(label_offset)) - @as(i64, @intCast(pc_aarch64));
                    if (@rem(delta_aarch64, 4) != 0) {
                        return error.UnalignedBranchTarget;
                    }
                    const offset_words = @divTrunc(delta_aarch64, 4);
                    if (offset_words < -(1 << 18) or offset_words >= (1 << 18)) {
                        return error.BranchOutOfRange;
                    }
                    try patchBranch19(self.data.items[fixup.offset..][0..4], offset_words);
                },
                .branch26 => {
                    // B, BL: 26-bit signed offset in instructions (word offset)
                    const pc_aarch64 = fixup.offset;
                    const delta_aarch64: i64 = @as(i64, @intCast(label_offset)) - @as(i64, @intCast(pc_aarch64));
                    if (@rem(delta_aarch64, 4) != 0) {
                        return error.UnalignedBranchTarget;
                    }
                    const offset_words = @divTrunc(delta_aarch64, 4);
                    if (offset_words < -(1 << 25) or offset_words >= (1 << 25)) {
                        return error.BranchOutOfRange;
                    }
                    try patchBranch26(self.data.items[fixup.offset..][0..4], offset_words);
                },
                .adr21 => {
                    // ADR: 21-bit signed byte offset
                    const pc_aarch64 = fixup.offset;
                    const delta_aarch64: i64 = @as(i64, @intCast(label_offset)) - @as(i64, @intCast(pc_aarch64));
                    if (delta_aarch64 < -(1 << 20) or delta_aarch64 >= (1 << 20)) {
                        return error.AdrOutOfRange;
                    }
                    try patchAdr21(self.data.items[fixup.offset..][0..4], delta_aarch64);
                },
                .ldr_literal19 => {
                    // LDR literal: 19-bit signed word offset
                    const pc_aarch64 = fixup.offset;
                    const delta_aarch64: i64 = @as(i64, @intCast(label_offset)) - @as(i64, @intCast(pc_aarch64));
                    if (@rem(delta_aarch64, 4) != 0) {
                        return error.UnalignedLiteralTarget;
                    }
                    const offset_words = @divTrunc(delta_aarch64, 4);
                    if (offset_words < -(1 << 18) or offset_words >= (1 << 18)) {
                        return error.LiteralOutOfRange;
                    }
                    try patchLdrLiteral19(self.data.items[fixup.offset..][0..4], offset_words);
                },
            }
        }

        // Clear fixups after resolution.
        self.fixups.clearRetainingCapacity();
    }

    /// Get the final code bytes.
    pub fn finish(self: *MachBuffer) []const u8 {
        return self.data.items;
    }
};

test "MachBuffer basic emission" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    try buf.put1(0x90); // NOP
    try buf.put4(0x12345678);

    try testing.expectEqual(@as(CodeOffset, 5), buf.curOffset());
    try testing.expectEqual(@as(u8, 0x90), buf.data.items[0]);
    try testing.expectEqual(@as(u32, 0x12345678), std.mem.readInt(u32, buf.data.items[1..5], .little));
}

test "MachBuffer label binding" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const label1 = try buf.allocLabel();
    const label2 = try buf.allocLabel();

    try buf.put1(0x90);
    try buf.bindLabel(label1);

    try buf.put4(0x12345678);
    try buf.bindLabel(label2);

    try testing.expectEqual(@as(CodeOffset, 1), buf.label_offsets.items[label1.index]);
    try testing.expectEqual(@as(CodeOffset, 5), buf.label_offsets.items[label2.index]);
}

test "MachBuffer forward label reference" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const target = try buf.allocLabel();

    // Emit a jump with placeholder offset.
    try buf.put1(0xEB); // JMP rel8
    const fixup_offset = buf.curOffset();
    try buf.put1(0x00); // Placeholder
    try buf.useLabelAtOffset(fixup_offset, target, .pc_rel8);

    // Emit some code.
    try buf.put1(0x90);
    try buf.put1(0x90);

    // Bind the target.
    try buf.bindLabel(target);
    try buf.put1(0xC3); // RET

    // Finalize should resolve the forward reference.
    try buf.finalize();

    // Check: PC after offset is at offset 2, target is at offset 4, delta = 2.
    try testing.expectEqual(@as(u8, 2), buf.data.items[fixup_offset]);
}

test "MachBuffer backward label reference" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const target = try buf.allocLabel();

    try buf.bindLabel(target);
    try buf.put1(0x90); // NOP

    // Jump back to start.
    try buf.put1(0xEB); // JMP rel8
    const fixup_offset = buf.curOffset();
    try buf.put1(0x00); // Placeholder
    try buf.useLabelAtOffset(fixup_offset, target, .pc_rel8);

    try buf.finalize();

    // PC after offset is at 3, target is at 0, delta = -3.
    try testing.expectEqual(@as(u8, @bitCast(@as(i8, -3))), buf.data.items[fixup_offset]);
}

test "MachBuffer trap records" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    try buf.put1(0xCC); // INT3
    try buf.addTrap(0, .unreachable_code_reached);

    try testing.expectEqual(@as(usize, 1), buf.traps.items.len);
    try testing.expectEqual(@as(CodeOffset, 0), buf.traps.items[0].offset);
    try testing.expectEqual(TrapCode.unreachable_code_reached, buf.traps.items[0].code);
}
