const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const machinst = @import("machinst.zig");
const stubs_mod = @import("stubs.zig");
pub const MachLabel = machinst.MachLabel;
const Block = @import("../ir/entities.zig").Block;

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

    // AArch64 relocations (ELF relocation types)
    /// R_AARCH64_CALL26 - BL to external function.
    aarch64_call26,
    /// R_AARCH64_JUMP26 - B to external target.
    aarch64_jump26,
    /// R_AARCH64_ADR_PREL_PG_HI21 - ADRP for symbol access (high 21 bits).
    aarch64_adr_prel_pg_hi21,
    /// R_AARCH64_ADD_ABS_LO12_NC - ADD for symbol access (low 12 bits).
    aarch64_add_abs_lo12_nc,
    /// R_AARCH64_LDST64_ABS_LO12_NC - LDR/STR offset (low 12 bits).
    aarch64_ldst64_abs_lo12_nc,
    /// R_AARCH64_ABS64 - Absolute 64-bit address.
    aarch64_abs64,
    /// R_AARCH64_ADR_GOT_PAGE - ADRP for GOT entry (high 21 bits).
    aarch64_adr_got_page,
    /// R_AARCH64_LD64_GOT_LO12_NC - LDR from GOT entry (low 12 bits).
    aarch64_ld64_got_lo12_nc,

    // TLS relocations - Local Exec (LE) model
    /// R_AARCH64_TLSLE_ADD_TPREL_HI12 - ADD for TLS LE (high 12 bits).
    aarch64_tlsle_add_tprel_hi12,
    /// R_AARCH64_TLSLE_ADD_TPREL_LO12_NC - ADD for TLS LE (low 12 bits).
    aarch64_tlsle_add_tprel_lo12_nc,

    // TLS relocations - Initial Exec (IE) model
    /// R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21 - ADRP for GOT entry containing TP offset.
    aarch64_tlsie_adr_gottprel_page21,
    /// R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC - LDR from GOT entry for TP offset.
    aarch64_tlsie_ld64_gottprel_lo12_nc,

    // TLS relocations - General Dynamic (GD) model with TLS descriptors
    /// R_AARCH64_TLSDESC_ADR_PAGE21 - ADRP for TLS descriptor.
    aarch64_tlsdesc_adr_page21,
    /// R_AARCH64_TLSDESC_LD64_LO12 - LDR for TLS descriptor function pointer.
    aarch64_tlsdesc_ld64_lo12,
    /// R_AARCH64_TLSDESC_ADD_LO12 - ADD for TLS descriptor offset.
    aarch64_tlsdesc_add_lo12,
    /// R_AARCH64_TLSDESC_CALL - BLR to TLS descriptor resolver.
    aarch64_tlsdesc_call,
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

/// Source line info entry - maps code offset to source location.
pub const SourceLineInfo = struct {
    /// Offset in code buffer.
    offset: CodeOffset,
    /// File index (into file table).
    file: u32,
    /// Line number (1-indexed).
    line: u32,
    /// Column number (1-indexed, 0 = unknown).
    column: u32,
    /// Is this a statement boundary?
    is_stmt: bool,
    /// Is this the end of the prologue?
    prologue_end: bool,
    /// Is this the start of the epilogue?
    epilogue_begin: bool,
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
    /// Used by: B.cond, CBZ, CBNZ
    branch19,
    /// AArch64 test-bit branch - 14-bit PC-relative (±32KB range).
    /// Used by: TBZ, TBNZ
    branch14,
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
            .branch19, .branch14, .branch26, .adr21, .ldr_literal19 => 4,
        };
    }

    pub fn maxPosRange(self: LabelUseKind) CodeOffset {
        return switch (self) {
            .pc_rel8 => 127,
            .pc_rel32 => 0x7FFF_FFFF,
            .branch19 => 1 << 20,
            .branch14 => 1 << 15,
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
            .branch14 => 1 << 15,
            .branch26 => 1 << 27,
            .adr21 => 1 << 20,
            .ldr_literal19 => 1 << 20,
        };
    }
};

/// Constant pool entry.
const ConstPoolEntry = struct {
    /// 64-bit constant value.
    value: u64,
    /// Size in bytes (4 for f32/i32, 8 for f64/i64).
    size: u8,
    /// Label for this constant (for LDR literal references).
    label: MachLabel,
};

const ConstPoolKey = struct {
    value: u64,
    size: u8,
};

/// Jump table entry for br_table implementation.
pub const JumpTableEntry = struct {
    /// Target block for this table entry.
    target: Block,
    /// Label for the target block (resolved during emission).
    label: MachLabel,
};

/// Jump table for br_table instruction.
pub const JumpTable = struct {
    /// Table of branch targets.
    targets: std.ArrayList(JumpTableEntry),
    /// Default target when index is out of bounds.
    default_target: Block,
    /// Label for default target.
    default_label: MachLabel,
    /// Label for the jump table data itself.
    table_label: MachLabel,
    /// Alignment requirement (4 or 8 bytes).
    alignment: u32,

    pub fn init(allocator: Allocator, default_target: Block, alignment: u32) JumpTable {
        _ = allocator;
        return .{
            .targets = std.ArrayList(JumpTableEntry){},
            .default_target = default_target,
            .default_label = MachLabel.new(0), // Set during emission
            .table_label = MachLabel.new(0), // Set during emission
            .alignment = alignment,
        };
    }

    pub fn deinit(self: *JumpTable, allocator: Allocator) void {
        self.targets.deinit(allocator);
    }

    pub fn addTarget(self: *JumpTable, allocator: Allocator, target: Block, label: MachLabel) !void {
        try self.targets.append(allocator, .{
            .target = target,
            .label = label,
        });
    }

    pub fn len(self: *const JumpTable) usize {
        return self.targets.items.len;
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
    /// Constant pool entries.
    const_pool: std.ArrayList(ConstPoolEntry),
    /// Map from constant key to pool index (for deduplication).
    const_pool_map: std.AutoHashMap(ConstPoolKey, u32),
    /// Jump tables for br_table instructions.
    jump_tables: std.ArrayList(JumpTable),
    /// Map from IR Block to MachLabel for exception handling.
    block_labels: std.AutoHashMap(Block, MachLabel),
    /// Source line info entries for debug info.
    source_lines: std.ArrayList(SourceLineInfo),
    /// Source file paths (indexed by file ID).
    source_files: std.ArrayList([]const u8),
    /// Map from file path to file ID for deduplication.
    source_file_map: std.StringHashMap(u32),
    /// Trampoline/veneer pool for far-branch fixups.
    trampoline_pool: stubs_mod.TrampolinePool,
    /// Allocator for dynamic allocations.
    allocator: Allocator,
    /// Test hook to force branch26 veneer emission on finalize.
    force_branch26_veneers_for_test: bool = false,

    const UNKNOWN_OFFSET: CodeOffset = 0xFFFF_FFFF;

    pub fn init(allocator: Allocator) MachBuffer {
        return .{
            .data = std.ArrayList(u8){},
            .relocs = std.ArrayList(MachReloc){},
            .traps = std.ArrayList(MachTrap){},
            .fixups = std.ArrayList(LabelFixup){},
            .label_offsets = std.ArrayList(CodeOffset){},
            .const_pool = std.ArrayList(ConstPoolEntry){},
            .const_pool_map = std.AutoHashMap(ConstPoolKey, u32).init(allocator),
            .jump_tables = std.ArrayList(JumpTable){},
            .block_labels = std.AutoHashMap(Block, MachLabel).init(allocator),
            .source_lines = std.ArrayList(SourceLineInfo){},
            .source_files = std.ArrayList([]const u8){},
            .source_file_map = std.StringHashMap(u32).init(allocator),
            .trampoline_pool = stubs_mod.TrampolinePool.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MachBuffer) void {
        self.data.deinit(self.allocator);
        // Free relocation name strings before deiniting relocs array
        for (self.relocs.items) |reloc| {
            self.allocator.free(reloc.name);
        }
        self.relocs.deinit(self.allocator);
        self.traps.deinit(self.allocator);
        self.fixups.deinit(self.allocator);
        self.label_offsets.deinit(self.allocator);
        self.const_pool.deinit(self.allocator);
        self.const_pool_map.deinit();
        for (self.jump_tables.items) |*jt| {
            jt.deinit(self.allocator);
        }
        self.jump_tables.deinit(self.allocator);
        self.block_labels.deinit();
        self.source_lines.deinit(self.allocator);
        // Free source file paths
        for (self.source_files.items) |path| {
            self.allocator.free(path);
        }
        self.source_files.deinit(self.allocator);
        self.source_file_map.deinit();
        self.trampoline_pool.deinit();
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

    /// Intern a source file path and return its index.
    pub fn internSourceFile(self: *MachBuffer, path: []const u8) !u32 {
        if (self.source_file_map.get(path)) |idx| {
            return idx;
        }
        const idx: u32 = @intCast(self.source_files.items.len);
        const owned = try self.allocator.dupe(u8, path);
        try self.source_files.append(self.allocator, owned);
        try self.source_file_map.put(owned, idx);
        return idx;
    }

    /// Record source location at current code offset.
    pub fn recordSourceLoc(
        self: *MachBuffer,
        file: []const u8,
        line: u32,
        column: u32,
    ) !void {
        const file_idx = try self.internSourceFile(file);
        try self.source_lines.append(self.allocator, .{
            .offset = self.curOffset(),
            .file = file_idx,
            .line = line,
            .column = column,
            .is_stmt = true,
            .prologue_end = false,
            .epilogue_begin = false,
        });
    }

    /// Record source location with full control over flags.
    pub fn recordSourceLocFull(
        self: *MachBuffer,
        file_idx: u32,
        line: u32,
        column: u32,
        is_stmt: bool,
        prologue_end: bool,
        epilogue_begin: bool,
    ) !void {
        try self.source_lines.append(self.allocator, .{
            .offset = self.curOffset(),
            .file = file_idx,
            .line = line,
            .column = column,
            .is_stmt = is_stmt,
            .prologue_end = prologue_end,
            .epilogue_begin = epilogue_begin,
        });
    }

    /// Mark current offset as end of prologue.
    pub fn markPrologueEnd(self: *MachBuffer, file_idx: u32, line: u32) !void {
        try self.recordSourceLocFull(file_idx, line, 0, true, true, false);
    }

    /// Mark current offset as start of epilogue.
    pub fn markEpilogueBegin(self: *MachBuffer, file_idx: u32, line: u32) !void {
        try self.recordSourceLocFull(file_idx, line, 0, true, false, true);
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

    /// Add a constant to the pool, return its label.
    /// Deduplicates identical constants.
    pub fn addConstant(self: *MachBuffer, value: u64, size: u8) !MachLabel {
        if (size != 4 and size != 8) return error.InvalidConstantSize;

        const key = ConstPoolKey{ .value = value, .size = size };

        // Check if constant already exists
        if (self.const_pool_map.get(key)) |index| {
            return self.const_pool.items[index].label;
        }

        // Allocate new label for this constant
        const label = try self.allocLabel();

        // Add to pool
        const index: u32 = @intCast(self.const_pool.items.len);
        try self.const_pool.append(self.allocator, .{
            .value = value,
            .size = size,
            .label = label,
        });
        try self.const_pool_map.put(key, index);

        return label;
    }

    /// Create a new jump table and return its index.
    /// The table will be emitted at the end of the function.
    pub fn createJumpTable(self: *MachBuffer, default_target: Block, alignment: u32) !u32 {
        const table_label = try self.allocLabel();
        const index: u32 = @intCast(self.jump_tables.items.len);

        var jt = JumpTable.init(self.allocator, default_target, alignment);
        jt.table_label = table_label;

        try self.jump_tables.append(self.allocator, jt);
        return index;
    }

    /// Add a target to an existing jump table.
    pub fn addJumpTableTarget(self: *MachBuffer, jt_index: u32, target: Block, label: MachLabel) !void {
        try self.jump_tables.items[jt_index].addTarget(self.allocator, target, label);
    }

    /// Get the label for a jump table (for PC-relative addressing).
    pub fn getJumpTableLabel(self: *const MachBuffer, jt_index: u32) MachLabel {
        return self.jump_tables.items[jt_index].table_label;
    }

    /// Register a mapping from IR block to MachLabel.
    /// Used for exception handling to track landing pad locations.
    pub fn registerBlockLabel(self: *MachBuffer, block: Block, label: MachLabel) !void {
        try self.block_labels.put(block, label);
    }

    /// Get the code offset for a block (if label has been bound).
    /// Returns null if block not registered or label not yet bound.
    pub fn getBlockOffset(self: *const MachBuffer, block: Block) ?CodeOffset {
        const label = self.block_labels.get(block) orelse return null;
        if (label.index >= self.label_offsets.items.len) return null;
        const offset = self.label_offsets.items[label.index];
        if (offset == UNKNOWN_OFFSET) return null;
        return offset;
    }

    /// Emit the constant pool at the current offset.
    /// Should be called at the end of function emission.
    pub fn emitConstPool(self: *MachBuffer) !void {
        if (self.const_pool.items.len == 0) {
            return;
        }

        // Align to 8 bytes for constant pool
        try self.alignTo(8);

        // Emit each constant and bind its label
        for (self.const_pool.items) |entry| {
            try self.bindLabel(entry.label);

            if (entry.size == 8) {
                try self.put8(entry.value);
            } else if (entry.size == 4) {
                try self.put4(@intCast(entry.value & 0xFFFFFFFF));
            } else {
                return error.InvalidConstantSize;
            }
        }
    }

    /// Emit all jump tables at the current offset.
    /// Should be called at the end of function emission, after constant pool.
    pub fn emitJumpTables(self: *MachBuffer) !void {
        if (self.jump_tables.items.len == 0) {
            return;
        }

        for (self.jump_tables.items) |*jt| {
            // Align to the jump table's alignment requirement
            try self.alignTo(@intCast(jt.alignment));

            // Bind the jump table label (for PC-relative addressing)
            try self.bindLabel(jt.table_label);
            const table_base_offset = self.curOffset();

            // Emit offsets to each target
            // For ARM64: typically use 32-bit signed offsets from table base
            for (jt.targets.items) |entry| {
                if (entry.label.index >= self.label_offsets.items.len) {
                    return error.InvalidLabel;
                }

                // Get the offset of the target label
                const target_offset = self.label_offsets.items[entry.label.index];
                if (target_offset == UNKNOWN_OFFSET) {
                    return error.UnresolvedLabel;
                }

                // Calculate PC-relative offset
                const offset: i32 = @intCast(@as(i64, target_offset) - @as(i64, table_base_offset));

                // Emit 4-byte offset
                const offset_u32: u32 = @bitCast(offset);
                try self.put4(offset_u32);
            }
        }
    }

    /// Align code buffer to specified byte boundary.
    fn alignTo(self: *MachBuffer, alignment: u8) !void {
        const offset = self.curOffset();
        const remainder = offset % alignment;
        if (remainder != 0) {
            const padding = alignment - remainder;
            var i: u8 = 0;
            while (i < padding) : (i += 1) {
                try self.put1(0); // NOP or zero padding
            }
        }
    }

    /// Patch a 19-bit branch offset into an instruction.
    /// Used by B.cond (bits [23:5]), CBZ/CBNZ
    fn patchBranch19(insn_bytes: *[4]u8, offset: i64) !void {
        const offset_bits: u32 = @bitCast(@as(i32, @intCast(offset & 0x7FFFF)));
        var insn = std.mem.readInt(u32, insn_bytes, .little);
        // Clear bits [23:5], insert offset
        insn &= ~(@as(u32, 0x7FFFF) << 5);
        insn |= offset_bits << 5;
        std.mem.writeInt(u32, insn_bytes, insn, .little);
    }

    /// Patch a 14-bit branch offset into an instruction.
    /// Used by TBZ/TBNZ (bits [18:5]).
    fn patchBranch14(insn_bytes: *[4]u8, offset: i64) !void {
        const offset_bits: u32 = @bitCast(@as(i32, @intCast(offset & 0x3FFF)));
        var insn = std.mem.readInt(u32, insn_bytes, .little);
        // Clear bits [18:5], insert offset
        insn &= ~(@as(u32, 0x3FFF) << 5);
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

    /// Emit a direct-jump veneer and track it in the trampoline pool.
    fn emitBranch26Veneer(self: *MachBuffer, target_label: MachLabel, target_offset: CodeOffset) !CodeOffset {
        try self.alignTo(4);
        const veneer_offset = self.curOffset();

        var veneer_bytes: [4]u8 = undefined;
        const patcher = stubs_mod.TrampolinePatcher.init(.aarch64);
        _ = patcher.emitVeneer(&veneer_bytes, veneer_offset, target_offset) catch |err| switch (err) {
            error.VeneerTargetOutOfRange => return error.BranchOutOfRange,
        };
        try self.putData(&veneer_bytes);

        try self.trampoline_pool.addTrampoline(
            .direct_jump,
            veneer_offset,
            .{ .label = target_label },
            4,
        );

        return veneer_offset;
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
                .branch14 => {
                    // TBZ/TBNZ: 14-bit signed offset in instructions (word offset)
                    const pc_aarch64 = fixup.offset;
                    const delta_aarch64: i64 = @as(i64, @intCast(label_offset)) - @as(i64, @intCast(pc_aarch64));
                    if (@rem(delta_aarch64, 4) != 0) {
                        return error.UnalignedBranchTarget;
                    }
                    const offset_words = @divTrunc(delta_aarch64, 4);
                    if (offset_words < -(1 << 13) or offset_words >= (1 << 13)) {
                        return error.BranchOutOfRange;
                    }
                    try patchBranch14(self.data.items[fixup.offset..][0..4], offset_words);
                },
                .branch26 => {
                    // B, BL: 26-bit signed offset in instructions (word offset)
                    const pc_aarch64 = fixup.offset;
                    const delta_aarch64: i64 = @as(i64, @intCast(label_offset)) - @as(i64, @intCast(pc_aarch64));
                    if (@rem(delta_aarch64, 4) != 0) {
                        return error.UnalignedBranchTarget;
                    }
                    const offset_words = @divTrunc(delta_aarch64, 4);
                    const out_of_range = offset_words < -(1 << 25) or offset_words >= (1 << 25);

                    if (out_of_range or self.force_branch26_veneers_for_test) {
                        const veneer_offset = try self.emitBranch26Veneer(fixup.label, label_offset);
                        const veneer_delta: i64 = @as(i64, @intCast(veneer_offset)) - @as(i64, @intCast(pc_aarch64));
                        if (@rem(veneer_delta, 4) != 0) {
                            return error.UnalignedBranchTarget;
                        }
                        const veneer_words = @divTrunc(veneer_delta, 4);
                        if (veneer_words < -(1 << 25) or veneer_words >= (1 << 25)) {
                            return error.BranchOutOfRange;
                        }
                        try patchBranch26(self.data.items[fixup.offset..][0..4], veneer_words);
                    } else {
                        try patchBranch26(self.data.items[fixup.offset..][0..4], offset_words);
                    }
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

test "MachBuffer branch26 forward label reference" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const target = try buf.allocLabel();

    // AArch64 B with placeholder imm26.
    try buf.put4(0x14000000);
    try buf.useLabelAtOffset(0, target, .branch26);

    // One 4-byte instruction between branch and target.
    try buf.put4(0xD503201F); // NOP
    try buf.bindLabel(target);

    try buf.finalize();

    const patched = std.mem.readInt(u32, buf.data.items[0..4], .little);
    try testing.expectEqual(@as(u32, 0x14000002), patched);
}

test "MachBuffer branch26 uses veneer trampoline when forced" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const target = try buf.allocLabel();

    // AArch64 B with placeholder imm26.
    try buf.put4(0x14000000);
    try buf.useLabelAtOffset(0, target, .branch26);

    // One 4-byte instruction between branch and target.
    try buf.put4(0xD503201F); // NOP
    try buf.bindLabel(target);

    buf.force_branch26_veneers_for_test = true;
    try buf.finalize();

    // Original branch now targets veneer at offset 8.
    const patched = std.mem.readInt(u32, buf.data.items[0..4], .little);
    try testing.expectEqual(@as(u32, 0x14000002), patched);

    // Veneer emitted at end (offset 8), branching to target at offset 8.
    try testing.expectEqual(@as(usize, 12), buf.data.items.len);
    const veneer = std.mem.readInt(u32, buf.data.items[8..12], .little);
    try testing.expectEqual(@as(u32, 0x14000000), veneer);

    const tramps = buf.trampoline_pool.getTrampolines();
    try testing.expectEqual(@as(usize, 1), tramps.len);
    try testing.expectEqual(stubs_mod.TrampolineKind.direct_jump, tramps[0].kind);
    try testing.expectEqual(@as(CodeOffset, 8), tramps[0].offset);
}

test "MachBuffer branch19 forward label reference" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const target = try buf.allocLabel();

    // AArch64 B.cond EQ with placeholder imm19.
    try buf.put4(0x54000000);
    try buf.useLabelAtOffset(0, target, .branch19);

    // One 4-byte instruction between branch and target.
    try buf.put4(0xD503201F); // NOP
    try buf.bindLabel(target);

    try buf.finalize();

    const patched = std.mem.readInt(u32, buf.data.items[0..4], .little);
    try testing.expectEqual(@as(u32, 0x54000040), patched);
}

test "MachBuffer branch14 forward label reference preserves bit index" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const target = try buf.allocLabel();

    // TBZ X5, #31, <target> with placeholder imm14.
    // b5=0, b40=31, Rt=5
    try buf.put4(0x36F80005);
    try buf.useLabelAtOffset(0, target, .branch14);

    // One 4-byte instruction between branch and target.
    try buf.put4(0xD503201F); // NOP
    try buf.bindLabel(target);

    try buf.finalize();

    const patched = std.mem.readInt(u32, buf.data.items[0..4], .little);
    // imm14 = +2 words -> 0x40 in bits [18:5]
    try testing.expectEqual(@as(u32, 0x36F80045), patched);
    // Ensure b40 field (bit index low bits) is preserved.
    try testing.expectEqual(@as(u32, 31), (patched >> 19) & 0x1F);
}

test "MachBuffer branch14 out-of-range returns BranchOutOfRange" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const target = try buf.allocLabel();

    // TBZ X0, #0, <target> with placeholder imm14.
    try buf.put4(0x36000000);
    try buf.useLabelAtOffset(0, target, .branch14);

    // Place target at +8192 words (+32768 bytes), just outside signed imm14 range.
    var i: usize = 0;
    while (i < 8191) : (i += 1) {
        try buf.put4(0xD503201F); // NOP
    }
    try buf.bindLabel(target);

    try testing.expectError(error.BranchOutOfRange, buf.finalize());
}

test "MachBuffer addConstant dedupes by value and size" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const l1 = try buf.addConstant(0x1234, 8);
    const l2 = try buf.addConstant(0x1234, 8);

    try testing.expectEqual(l1.index, l2.index);
    try testing.expectEqual(@as(usize, 1), buf.const_pool.items.len);
}

test "MachBuffer addConstant keeps same value with different sizes separate" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const l32 = try buf.addConstant(0x3F800000, 4);
    const l64 = try buf.addConstant(0x3F800000, 8);

    try testing.expect(l32.index != l64.index);
    try testing.expectEqual(@as(usize, 2), buf.const_pool.items.len);

    try buf.emitConstPool();
    try testing.expectEqual(@as(usize, 12), buf.data.items.len);

    const first = std.mem.readInt(u32, buf.data.items[0..4], .little);
    const second = std.mem.readInt(u64, buf.data.items[4..12], .little);
    try testing.expectEqual(@as(u32, 0x3F800000), first);
    try testing.expectEqual(@as(u64, 0x000000003F800000), second);
}

test "MachBuffer addConstant rejects invalid size" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    try testing.expectError(error.InvalidConstantSize, buf.addConstant(0x1234, 1));
    try testing.expectError(error.InvalidConstantSize, buf.addConstant(0x1234, 16));
}

test "MachBuffer emitJumpTables rejects unresolved labels" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const jt_idx = try buf.createJumpTable(Block.new(0), 4);
    const unresolved = try buf.allocLabel();
    try buf.addJumpTableTarget(jt_idx, Block.new(1), unresolved);

    try testing.expectError(error.UnresolvedLabel, buf.emitJumpTables());
}

test "MachBuffer emitJumpTables rejects invalid labels" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const jt_idx = try buf.createJumpTable(Block.new(0), 4);
    const invalid_label = MachLabel.new(999999);
    try buf.addJumpTableTarget(jt_idx, Block.new(1), invalid_label);

    try testing.expectError(error.InvalidLabel, buf.emitJumpTables());
}

test "MachBuffer emitJumpTables uses table-base-relative offsets" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const t0 = try buf.allocLabel();
    try buf.bindLabel(t0); // offset 0
    try buf.put4(0xD503201F); // NOP

    const t1 = try buf.allocLabel();
    try buf.bindLabel(t1); // offset 4
    try buf.put4(0xD503201F); // NOP

    const jt_idx = try buf.createJumpTable(Block.new(0), 4);
    try buf.addJumpTableTarget(jt_idx, Block.new(0), t0);
    try buf.addJumpTableTarget(jt_idx, Block.new(1), t1);

    try buf.emitJumpTables();

    const off0 = std.mem.readInt(i32, buf.data.items[8..12], .little);
    const off1 = std.mem.readInt(i32, buf.data.items[12..16], .little);
    try testing.expectEqual(@as(i32, -8), off0);
    try testing.expectEqual(@as(i32, -4), off1);
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

test "MachBuffer source line info" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    // Record source location
    try buf.recordSourceLoc("main.zig", 10, 1);
    try buf.put4(0x12345678);

    try buf.recordSourceLoc("main.zig", 11, 5);
    try buf.put4(0xDEADBEEF);

    // Different file
    try buf.recordSourceLoc("util.zig", 5, 1);
    try buf.put4(0xCAFEBABE);

    try testing.expectEqual(@as(usize, 3), buf.source_lines.items.len);
    try testing.expectEqual(@as(usize, 2), buf.source_files.items.len);

    // Check first entry
    try testing.expectEqual(@as(u32, 0), buf.source_lines.items[0].offset);
    try testing.expectEqual(@as(u32, 0), buf.source_lines.items[0].file);
    try testing.expectEqual(@as(u32, 10), buf.source_lines.items[0].line);

    // Check file interning
    try testing.expectEqual(@as(u32, 0), buf.source_lines.items[1].file);
    try testing.expectEqual(@as(u32, 1), buf.source_lines.items[2].file);

    // Check file paths
    try testing.expectEqualStrings("main.zig", buf.source_files.items[0]);
    try testing.expectEqualStrings("util.zig", buf.source_files.items[1]);
}

test "MachBuffer prologue/epilogue markers" {
    var buf = MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const file_idx = try buf.internSourceFile("test.zig");
    try buf.markPrologueEnd(file_idx, 5);
    try buf.put4(0x12345678);
    try buf.markEpilogueBegin(file_idx, 20);

    try testing.expectEqual(@as(usize, 2), buf.source_lines.items.len);
    try testing.expect(buf.source_lines.items[0].prologue_end);
    try testing.expect(!buf.source_lines.items[0].epilogue_begin);
    try testing.expect(!buf.source_lines.items[1].prologue_end);
    try testing.expect(buf.source_lines.items[1].epilogue_begin);
}

/// ELF Rela entry for relocations.
pub const ElfRela = struct {
    /// Offset in code where relocation applies.
    r_offset: u64,
    /// Symbol index and relocation type.
    r_info: u64,
    /// Addend.
    r_addend: i64,

    /// Convert MachReloc to ELF Rela format.
    pub fn fromMachReloc(reloc: MachReloc, sym_index: u32) ElfRela {
        const r_type = relocTypeToElf(reloc.kind);
        return .{
            .r_offset = reloc.offset,
            .r_info = (@as(u64, sym_index) << 32) | r_type,
            .r_addend = reloc.addend,
        };
    }
};

/// Convert Reloc enum to ELF relocation type number.
fn relocTypeToElf(kind: Reloc) u32 {
    return switch (kind) {
        .aarch64_call26 => 283, // R_AARCH64_CALL26
        .aarch64_jump26 => 282, // R_AARCH64_JUMP26
        .aarch64_adr_prel_pg_hi21 => 275, // R_AARCH64_ADR_PREL_PG_HI21
        .aarch64_add_abs_lo12_nc => 277, // R_AARCH64_ADD_ABS_LO12_NC
        .aarch64_ldst64_abs_lo12_nc => 286, // R_AARCH64_LDST64_ABS_LO12_NC
        .aarch64_abs64 => 257, // R_AARCH64_ABS64
        .aarch64_adr_got_page => 311, // R_AARCH64_ADR_GOT_PAGE
        .aarch64_ld64_got_lo12_nc => 312, // R_AARCH64_LD64_GOT_LO12_NC
        // TLS Local Exec
        .aarch64_tlsle_add_tprel_hi12 => 549, // R_AARCH64_TLSLE_ADD_TPREL_HI12
        .aarch64_tlsle_add_tprel_lo12_nc => 550, // R_AARCH64_TLSLE_ADD_TPREL_LO12_NC
        // TLS Initial Exec
        .aarch64_tlsie_adr_gottprel_page21 => 541, // R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21
        .aarch64_tlsie_ld64_gottprel_lo12_nc => 542, // R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC
        // TLS General Dynamic
        .aarch64_tlsdesc_adr_page21 => 562, // R_AARCH64_TLSDESC_ADR_PAGE21
        .aarch64_tlsdesc_ld64_lo12 => 563, // R_AARCH64_TLSDESC_LD64_LO12
        .aarch64_tlsdesc_add_lo12 => 564, // R_AARCH64_TLSDESC_ADD_LO12
        .aarch64_tlsdesc_call => 569, // R_AARCH64_TLSDESC_CALL
        .abs8, .abs4 => 257, // Generic absolute
        .x86_pc_rel_32 => 2, // R_X86_64_PC32
    };
}
