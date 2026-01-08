const std = @import("std");

/// ULEB128 encoding and decoding utilities.
pub const Uleb128 = struct {
    /// Encode a u32 as ULEB128 into a buffer.
    /// Returns the number of bytes written.
    pub fn encode(value: u32, buf: []u8) !usize {
        var v = value;
        var pos: usize = 0;
        while (v >= 0x80) : (pos += 1) {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = @as(u8, @truncate(v & 0x7f)) | 0x80;
            v >>= 7;
        }
        if (pos >= buf.len) return error.BufferTooSmall;
        buf[pos] = @as(u8, @truncate(v & 0x7f));
        return pos + 1;
    }

    /// Encode a i32 as SLEB128 into a buffer.
    /// Returns the number of bytes written.
    pub fn encodeSigned(value: i32, buf: []u8) !usize {
        var v = value;
        var pos: usize = 0;
        while (true) : (pos += 1) {
            if (pos >= buf.len) return error.BufferTooSmall;
            const byte = @as(u8, @truncate(@as(u32, @bitCast(v)) & 0x7f));
            v >>= 7;
            // For signed, check if more bytes needed
            if ((v == 0 and (byte & 0x40) == 0) or (v == -1 and (byte & 0x40) != 0)) {
                buf[pos] = byte;
                return pos + 1;
            }
            buf[pos] = byte | 0x80;
        }
    }
};

/// Unwind information for aarch64 System V ABI.
/// Generates .eh_frame entries for stack unwinding.
/// DWARF register numbers for aarch64.
/// See ARM DWARF spec: https://github.com/ARM-software/abi-aa/blob/main/aadwarf64/aadwarf64.rst
pub const DwarfReg = enum(u8) {
    x0 = 0,
    x1 = 1,
    x2 = 2,
    x3 = 3,
    x4 = 4,
    x5 = 5,
    x6 = 6,
    x7 = 7,
    x8 = 8,
    x9 = 9,
    x10 = 10,
    x11 = 11,
    x12 = 12,
    x13 = 13,
    x14 = 14,
    x15 = 15,
    x16 = 16,
    x17 = 17,
    x18 = 18,
    x19 = 19,
    x20 = 20,
    x21 = 21,
    x22 = 22,
    x23 = 23,
    x24 = 24,
    x25 = 25,
    x26 = 26,
    x27 = 27,
    x28 = 28,
    x29 = 29,
    x30 = 30,
    sp = 31,
    v0 = 64,
    v1 = 65,
    v2 = 66,
    v3 = 67,
    v4 = 68,
    v5 = 69,
    v6 = 70,
    v7 = 71,
    v8 = 72,
    v9 = 73,
    v10 = 74,
    v11 = 75,
    v12 = 76,
    v13 = 77,
    v14 = 78,
    v15 = 79,
    v16 = 80,
    v17 = 81,
    v18 = 82,
    v19 = 83,
    v20 = 84,
    v21 = 85,
    v22 = 86,
    v23 = 87,
    v24 = 88,
    v25 = 89,
    v26 = 90,
    v27 = 91,
    v28 = 92,
    v29 = 93,
    v30 = 94,
    v31 = 95,

    pub fn fromIntReg(reg_num: u8) DwarfReg {
        return @enumFromInt(reg_num);
    }

    pub fn fromVecReg(reg_num: u8) DwarfReg {
        return @enumFromInt(64 + reg_num);
    }
};

/// Call Frame Instruction opcodes for DWARF.
pub const CFIOpcode = enum(u8) {
    set_loc = 0x01,
    advance_loc1 = 0x02,
    advance_loc2 = 0x03,
    advance_loc4 = 0x04,
    def_cfa = 0x0c,
    def_cfa_register = 0x0d,
    def_cfa_offset = 0x0e,
    offset = 0x80,
    restore = 0xc0,
    undefined = 0x07,
    same_value = 0x08,
    register = 0x09,
    remember_state = 0x0a,
    restore_state = 0x0b,
    advance_loc = 0x40,
};

/// Call Frame Instruction.
pub const CFI = union(enum) {
    advance_loc: u32,
    def_cfa: struct { reg: DwarfReg, offset: i32 },
    def_cfa_register: DwarfReg,
    def_cfa_offset: u32,
    offset: struct { reg: DwarfReg, offset: i32 },
    restore: DwarfReg,
    undefined: DwarfReg,
    same_value: DwarfReg,
    remember_state: void,
    restore_state: void,
};

/// Common Information Entry for aarch64.
pub const CIE = struct {
    version: u8 = 1,
    code_align_factor: u32 = 4,
    data_align_factor: i32 = -8,
    return_address_register: DwarfReg = .x30,
    initial_instructions: std.ArrayList(CFI),

    pub fn init(allocator: std.mem.Allocator) !CIE {
        var cie = CIE{
            .initial_instructions = std.ArrayList(CFI){
                .items = &.{},
                .capacity = 0,
            },
        };

        try cie.initial_instructions.append(allocator, .{
            .def_cfa = .{
                .reg = .sp,
                .offset = 0,
            },
        });

        return cie;
    }

    pub fn deinit(self: *CIE, allocator: std.mem.Allocator) void {
        self.initial_instructions.deinit(allocator);
    }

    pub fn encode(self: *CIE, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.ArrayList(u8){
            .items = &.{},
            .capacity = 0,
        };

        try buf.append(allocator, self.version);
        const augmentation = "zR";
        try buf.appendSlice(allocator, augmentation);
        try buf.append(allocator, 0);

        var code_align_buf: [10]u8 = undefined;
        const code_align_len = try Uleb128.encode(self.code_align_factor, &code_align_buf);
        try buf.appendSlice(allocator, code_align_buf[0..code_align_len]);

        var data_align_buf: [10]u8 = undefined;
        const data_align_len = try Uleb128.encodeSigned(self.data_align_factor, &data_align_buf);
        try buf.appendSlice(allocator, data_align_buf[0..data_align_len]);

        var return_reg_buf: [10]u8 = undefined;
        const return_reg_len = try Uleb128.encode(@intFromEnum(self.return_address_register), &return_reg_buf);
        try buf.appendSlice(allocator, return_reg_buf[0..return_reg_len]);

        try buf.append(allocator, 1);
        try buf.append(allocator, 0x00);

        for (self.initial_instructions.items) |cfi| {
            var cfi_buf: [32]u8 = undefined;
            const cfi_len = try encodeCFI(cfi, &cfi_buf);
            try buf.appendSlice(allocator, cfi_buf[0..cfi_len]);
        }

        return buf.toOwnedSlice(allocator);
    }
};

/// Call site entry in LSDA call site table.
/// Maps a try_call instruction PC range to its landing pad.
pub const CallSiteEntry = struct {
    start_offset: u32,
    length: u32,
    landing_pad_offset: u32,
};

/// Language-Specific Data Area (LSDA) for exception handling.
/// Maps instruction PC ranges to landing pad PCs using ULEB128 encoding.
/// Follows Itanium C++ ABI exception handling specification.
pub const LSDA = struct {
    call_sites: std.ArrayList(CallSiteEntry),

    pub fn init(allocator: std.mem.Allocator) LSDA {
        return .{
            .call_sites = std.ArrayList(CallSiteEntry){
                .items = &.{},
                .capacity = 0,
            },
        };
    }

    pub fn deinit(self: *LSDA, allocator: std.mem.Allocator) void {
        self.call_sites.deinit(allocator);
    }

    /// Add a call site entry mapping a try_call range to landing pad.
    pub fn addCallSite(self: *LSDA, allocator: std.mem.Allocator, start_offset: u32, length: u32, landing_pad_offset: u32) !void {
        try self.call_sites.append(allocator, .{
            .start_offset = start_offset,
            .length = length,
            .landing_pad_offset = landing_pad_offset,
        });
    }

    /// Encode LSDA call site table as ULEB128 pairs.
    /// Format: (start_offset, length, landing_pad_offset) for each call site.
    /// Returns allocated byte slice containing encoded data.
    pub fn encode(self: *LSDA, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.ArrayList(u8){
            .items = &.{},
            .capacity = 0,
        };

        // Encode each call site entry as three ULEB128 values
        for (self.call_sites.items) |entry| {
            var uleb_buf: [10]u8 = undefined;

            // Encode start_offset
            const start_len = try Uleb128.encode(entry.start_offset, &uleb_buf);
            try buf.appendSlice(allocator, uleb_buf[0..start_len]);

            // Encode length
            const length_len = try Uleb128.encode(entry.length, &uleb_buf);
            try buf.appendSlice(allocator, uleb_buf[0..length_len]);

            // Encode landing_pad_offset
            const lp_len = try Uleb128.encode(entry.landing_pad_offset, &uleb_buf);
            try buf.appendSlice(allocator, uleb_buf[0..lp_len]);
        }

        return buf.toOwnedSlice(allocator);
    }
};

/// Frame Description Entry for a function.
pub const FDE = struct {
    pc_begin: u64,
    code_size: u32,
    instructions: std.ArrayList(CFI),
    lsda: ?*LSDA = null,

    pub fn init(pc_begin: u64, code_size: u32) FDE {
        return .{
            .pc_begin = pc_begin,
            .code_size = code_size,
            .instructions = std.ArrayList(CFI){
                .items = &.{},
                .capacity = 0,
            },
            .lsda = null,
        };
    }

    pub fn deinit(self: *FDE, allocator: std.mem.Allocator) void {
        self.instructions.deinit(allocator);
        if (self.lsda) |lsda| {
            lsda.deinit(allocator);
            allocator.destroy(lsda);
        }
    }

    pub fn encode(self: *FDE, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.ArrayList(u8){
            .items = &.{},
            .capacity = 0,
        };

        var pc_begin_bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &pc_begin_bytes, self.pc_begin, .little);
        try buf.appendSlice(allocator, &pc_begin_bytes);

        var code_size_bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &code_size_bytes, self.code_size, .little);
        try buf.appendSlice(allocator, &code_size_bytes);

        // FDE augmentation data: if LSDA is present, encode pointer to LSDA
        if (self.lsda) |lsda| {
            // Augmentation: one byte indicating LSDA pointer follows (0x1b for absolute pointer)
            try buf.append(allocator, 0x1b);
            // Placeholder for LSDA pointer (8 bytes for 64-bit)
            // In actual use, this would be filled with the LSDA address
            var lsda_ptr_bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &lsda_ptr_bytes, 0, .little);
            try buf.appendSlice(allocator, &lsda_ptr_bytes);
        } else {
            try buf.append(allocator, 0);
        }

        for (self.instructions.items) |cfi| {
            var cfi_buf: [32]u8 = undefined;
            const cfi_len = try encodeCFI(cfi, &cfi_buf);
            try buf.appendSlice(allocator, cfi_buf[0..cfi_len]);
        }

        return buf.toOwnedSlice(allocator);
    }

    pub fn addPrologueSaveFpLr(self: *FDE, allocator: std.mem.Allocator, offset: u32) !void {
        try self.instructions.append(allocator, .{ .advance_loc = offset });
        try self.instructions.append(allocator, .{ .def_cfa_offset = 16 });
        try self.instructions.append(allocator, .{ .offset = .{ .reg = .x29, .offset = -16 } });
        try self.instructions.append(allocator, .{ .offset = .{ .reg = .x30, .offset = -8 } });
    }

    pub fn addPrologueSetFp(self: *FDE, allocator: std.mem.Allocator, offset: u32) !void {
        try self.instructions.append(allocator, .{ .advance_loc = offset });
        try self.instructions.append(allocator, .{ .def_cfa_register = .x29 });
    }

    pub fn addPrologueAllocStack(self: *FDE, allocator: std.mem.Allocator, offset: u32, size: u32) !void {
        try self.instructions.append(allocator, .{ .advance_loc = offset });
        try self.instructions.append(allocator, .{ .def_cfa_offset = size + 16 });
    }

    pub fn addPrologueSaveReg(self: *FDE, allocator: std.mem.Allocator, offset: u32, reg: DwarfReg, cfa_offset: i32) !void {
        try self.instructions.append(allocator, .{ .advance_loc = offset });
        try self.instructions.append(allocator, .{ .offset = .{ .reg = reg, .offset = cfa_offset } });
    }
};

/// Build an LSDA from a list of try_call locations and their landing pads.
/// Maps instruction PC ranges to landing pad offsets using ULEB128 encoding.
pub fn buildLSDA(
    allocator: std.mem.Allocator,
    try_call_locations: []const struct { start: u32, length: u32 },
    landing_pads: []const u32,
) !*LSDA {
    if (try_call_locations.len != landing_pads.len) {
        return error.MismatchedArrayLengths;
    }

    const lsda = try allocator.create(LSDA);
    lsda.* = LSDA.init(allocator);

    for (try_call_locations, landing_pads) |try_call, landing_pad| {
        try lsda.addCallSite(allocator, try_call.start, try_call.length, landing_pad);
    }

    return lsda;
}

/// Unwind information for a compiled function.
pub const UnwindInfo = struct {
    cie: CIE,
    fde: FDE,

    pub fn init(allocator: std.mem.Allocator, pc_begin: u64, code_size: u32) !UnwindInfo {
        return .{
            .cie = try CIE.init(allocator),
            .fde = FDE.init(pc_begin, code_size),
        };
    }

    pub fn deinit(self: *UnwindInfo, allocator: std.mem.Allocator) void {
        self.cie.deinit(allocator);
        self.fde.deinit(allocator);
    }

    pub fn generateStandardPrologue(self: *UnwindInfo, allocator: std.mem.Allocator, stack_size: u32) !void {
        try self.fde.addPrologueSaveFpLr(allocator, 4);
        try self.fde.addPrologueSetFp(allocator, 8);
        if (stack_size > 0) {
            try self.fde.addPrologueAllocStack(allocator, 12, stack_size);
        }
    }
};

/// Encode a CFI (Call Frame Instruction) to binary format.
fn encodeCFI(cfi: CFI, buf: []u8) !usize {
    var pos: usize = 0;

    switch (cfi) {
        .advance_loc => |delta| {
            if (delta < 64) {
                if (pos >= buf.len) return error.BufferTooSmall;
                buf[pos] = @as(u8, @truncate(delta)) | 0x40;
                pos += 1;
            } else {
                if (pos + 4 >= buf.len) return error.BufferTooSmall;
                buf[pos] = 0x04;
                pos += 1;
                std.mem.writeInt(u32, buf[pos..][0..4], delta, .little);
                pos += 4;
            }
        },

        .def_cfa => |dc| {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = @intFromEnum(CFIOpcode.def_cfa);
            pos += 1;

            var reg_buf: [10]u8 = undefined;
            const reg_len = try Uleb128.encode(@intFromEnum(dc.reg), &reg_buf);
            if (pos + reg_len >= buf.len) return error.BufferTooSmall;
            @memcpy(buf[pos..][0..reg_len], reg_buf[0..reg_len]);
            pos += reg_len;

            var offset_buf: [10]u8 = undefined;
            const offset_len = try Uleb128.encode(@as(u32, @intCast(dc.offset)), &offset_buf);
            if (pos + offset_len >= buf.len) return error.BufferTooSmall;
            @memcpy(buf[pos..][0..offset_len], offset_buf[0..offset_len]);
            pos += offset_len;
        },

        .def_cfa_register => |reg| {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = @intFromEnum(CFIOpcode.def_cfa_register);
            pos += 1;

            var reg_buf: [10]u8 = undefined;
            const reg_len = try Uleb128.encode(@intFromEnum(reg), &reg_buf);
            if (pos + reg_len >= buf.len) return error.BufferTooSmall;
            @memcpy(buf[pos..][0..reg_len], reg_buf[0..reg_len]);
            pos += reg_len;
        },

        .def_cfa_offset => |offset| {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = @intFromEnum(CFIOpcode.def_cfa_offset);
            pos += 1;

            var offset_buf: [10]u8 = undefined;
            const offset_len = try Uleb128.encode(offset, &offset_buf);
            if (pos + offset_len >= buf.len) return error.BufferTooSmall;
            @memcpy(buf[pos..][0..offset_len], offset_buf[0..offset_len]);
            pos += offset_len;
        },

        .offset => |o| {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = @intFromEnum(CFIOpcode.offset) | @as(u8, @truncate(@intFromEnum(o.reg)));
            pos += 1;

            var offset_buf: [10]u8 = undefined;
            const offset_len = try Uleb128.encodeSigned(o.offset, &offset_buf);
            if (pos + offset_len >= buf.len) return error.BufferTooSmall;
            @memcpy(buf[pos..][0..offset_len], offset_buf[0..offset_len]);
            pos += offset_len;
        },

        .restore => |reg| {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = @intFromEnum(CFIOpcode.restore) | @as(u8, @truncate(@intFromEnum(reg)));
            pos += 1;
        },

        .undefined => |reg| {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = @intFromEnum(CFIOpcode.undefined);
            pos += 1;

            var reg_buf: [10]u8 = undefined;
            const reg_len = try Uleb128.encode(@intFromEnum(reg), &reg_buf);
            if (pos + reg_len >= buf.len) return error.BufferTooSmall;
            @memcpy(buf[pos..][0..reg_len], reg_buf[0..reg_len]);
            pos += reg_len;
        },

        .same_value => |reg| {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = @intFromEnum(CFIOpcode.same_value);
            pos += 1;

            var reg_buf: [10]u8 = undefined;
            const reg_len = try Uleb128.encode(@intFromEnum(reg), &reg_buf);
            if (pos + reg_len >= buf.len) return error.BufferTooSmall;
            @memcpy(buf[pos..][0..reg_len], reg_buf[0..reg_len]);
            pos += reg_len;
        },

        .remember_state => {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = @intFromEnum(CFIOpcode.remember_state);
            pos += 1;
        },

        .restore_state => {
            if (pos >= buf.len) return error.BufferTooSmall;
            buf[pos] = @intFromEnum(CFIOpcode.restore_state);
            pos += 1;
        },
    }

    return pos;
}

/// Emit DW_CFA_def_cfa opcode.
pub fn emitDefCfa(reg: DwarfReg, offset: u32, buf: []u8) !usize {
    return try encodeCFI(.{
        .def_cfa = .{
            .reg = reg,
            .offset = @as(i32, @intCast(offset)),
        },
    }, buf);
}

/// Emit DW_CFA_offset opcode.
pub fn emitOffset(reg: DwarfReg, offset: i32, buf: []u8) !usize {
    return try encodeCFI(.{
        .offset = .{
            .reg = reg,
            .offset = offset,
        },
    }, buf);
}

/// Emit DW_CFA_remember_state opcode.
pub fn emitRememberState(buf: []u8) !usize {
    if (buf.len == 0) return error.BufferTooSmall;
    buf[0] = @intFromEnum(CFIOpcode.remember_state);
    return 1;
}

/// Emit DW_CFA_restore_state opcode.
pub fn emitRestoreState(buf: []u8) !usize {
    if (buf.len == 0) return error.BufferTooSmall;
    buf[0] = @intFromEnum(CFIOpcode.restore_state);
    return 1;
}

test "DwarfReg mapping" {
    const testing = std.testing;
    try testing.expectEqual(DwarfReg.x0, DwarfReg.fromIntReg(0));
    try testing.expectEqual(DwarfReg.x30, DwarfReg.fromIntReg(30));
    try testing.expectEqual(DwarfReg.v31, DwarfReg.fromVecReg(31));
}

test "CIE initialization" {
    const testing = std.testing;
    var cie = try CIE.init(testing.allocator);
    defer cie.deinit(testing.allocator);
    try testing.expectEqual(@as(u8, 1), cie.version);
    try testing.expectEqual(@as(usize, 1), cie.initial_instructions.items.len);
}

test "FDE standard prologue" {
    const testing = std.testing;
    var unwind = try UnwindInfo.init(testing.allocator, 0x1000, 64);
    defer unwind.deinit(testing.allocator);
    try unwind.generateStandardPrologue(testing.allocator, 32);
    try testing.expect(unwind.fde.instructions.items.len > 0);
}

test "ULEB128 encode" {
    var buf: [10]u8 = undefined;
    var len = try Uleb128.encode(0, &buf);
    try std.testing.expectEqual(@as(usize, 1), len);
    len = try Uleb128.encode(128, &buf);
    try std.testing.expectEqual(@as(usize, 2), len);
}

test "SLEB128 encode" {
    var buf: [10]u8 = undefined;
    var len = try Uleb128.encodeSigned(0, &buf);
    try std.testing.expectEqual(@as(usize, 1), len);
    len = try Uleb128.encodeSigned(-1, &buf);
    try std.testing.expectEqual(@as(usize, 1), len);
}

test "CIE encode" {
    const testing = std.testing;
    var cie = try CIE.init(testing.allocator);
    defer cie.deinit(testing.allocator);
    const encoded = try cie.encode(testing.allocator);
    defer testing.allocator.free(encoded);
    try testing.expect(encoded.len > 0);
    try testing.expectEqual(@as(u8, 1), encoded[0]);
}

test "FDE encode" {
    const testing = std.testing;
    var fde = FDE.init(0x1000, 64);
    defer fde.deinit(testing.allocator);
    try fde.addPrologueSaveFpLr(testing.allocator, 4);
    const encoded = try fde.encode(testing.allocator);
    defer testing.allocator.free(encoded);
    try testing.expect(encoded.len >= 17);
}

test "emitDefCfa" {
    var buf: [32]u8 = undefined;
    const len = try emitDefCfa(.sp, 0, &buf);
    try std.testing.expect(len > 0);
    try std.testing.expectEqual(@as(u8, 0x0c), buf[0]);
}

test "emitOffset" {
    var buf: [32]u8 = undefined;
    const len = try emitOffset(.x29, -16, &buf);
    try std.testing.expect(len > 0);
    try std.testing.expectEqual(@as(u8, 0x80 | 29), buf[0]);
}

test "emitRememberState" {
    var buf: [32]u8 = undefined;
    const len = try emitRememberState(&buf);
    try std.testing.expectEqual(@as(usize, 1), len);
    try std.testing.expectEqual(@as(u8, 0x0a), buf[0]);
}

test "emitRestoreState" {
    var buf: [32]u8 = undefined;
    const len = try emitRestoreState(&buf);
    try std.testing.expectEqual(@as(usize, 1), len);
    try std.testing.expectEqual(@as(u8, 0x0b), buf[0]);
}
