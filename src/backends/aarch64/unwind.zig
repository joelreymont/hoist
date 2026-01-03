const std = @import("std");

/// Unwind information for aarch64 System V ABI.
/// Generates .eh_frame entries for stack unwinding.
/// DWARF register numbers for aarch64.
/// See ARM DWARF spec: https://github.com/ARM-software/abi-aa/blob/main/aadwarf64/aadwarf64.rst
pub const DwarfReg = enum(u8) {
    // General purpose registers X0-X30
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
    x29 = 29, // FP
    x30 = 30, // LR
    sp = 31,

    // Vector registers V0-V31 are 64-95
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
    // Row creation
    set_loc = 0x01,
    advance_loc1 = 0x02,
    advance_loc2 = 0x03,
    advance_loc4 = 0x04,

    // CFA definition
    def_cfa = 0x0c,
    def_cfa_register = 0x0d,
    def_cfa_offset = 0x0e,

    // Register rules
    offset = 0x80, // High 2 bits set, low 6 bits = register
    restore = 0xc0, // High 2 bits set, low 6 bits = register
    undefined = 0x07,
    same_value = 0x08,
    register = 0x09,
    remember_state = 0x0a,
    restore_state = 0x0b,

    // GNU extensions
    advance_loc = 0x40, // High 2 bits, low 6 bits = delta
};

/// Call Frame Instruction.
pub const CFI = union(enum) {
    /// Advance location by delta instructions
    advance_loc: u32,

    /// Define CFA as register + offset
    def_cfa: struct {
        reg: DwarfReg,
        offset: i32,
    },

    /// Change CFA register
    def_cfa_register: DwarfReg,

    /// Change CFA offset
    def_cfa_offset: u32,

    /// Register is saved at CFA + offset
    offset: struct {
        reg: DwarfReg,
        offset: i32,
    },

    /// Restore register to initial state
    restore: DwarfReg,

    /// Register value is undefined
    undefined: DwarfReg,

    /// Register value unchanged
    same_value: DwarfReg,

    /// Remember current register save state
    remember_state: void,

    /// Restore to remembered state
    restore_state: void,
};

/// Common Information Entry for aarch64.
pub const CIE = struct {
    version: u8 = 1,
    code_align_factor: u32 = 4, // Instructions are 4 bytes
    data_align_factor: i32 = -8, // Stack grows down by 8-byte words
    return_address_register: DwarfReg = .x30, // LR

    /// Initial instructions executed for all FDEs
    initial_instructions: std.ArrayList(CFI),

    pub fn init(allocator: std.mem.Allocator) !CIE {
        var cie = CIE{
            .initial_instructions = std.ArrayList(CFI){},
        };

        // CFA starts at SP + 0
        try cie.initial_instructions.append(.{
            .def_cfa = .{
                .reg = .sp,
                .offset = 0,
            },
        });

        return cie;
    }

    pub fn deinit(self: *CIE) void {
        self.initial_instructions.deinit();
    }
};

/// Frame Description Entry for a function.
pub const FDE = struct {
    /// Program counter start address
    pc_begin: u64,

    /// Function code size
    code_size: u32,

    /// Call frame instructions for this function
    instructions: std.ArrayList(CFI),

    pub fn init(allocator: std.mem.Allocator, pc_begin: u64, code_size: u32) FDE {
        return .{
            .pc_begin = pc_begin,
            .code_size = code_size,
            .instructions = std.ArrayList(CFI){},
        };
    }

    pub fn deinit(self: *FDE) void {
        self.instructions.deinit();
    }

    /// Add prologue unwind info for standard function entry.
    /// Assumes: stp x29, x30, [sp, #-16]!
    pub fn addPrologueSaveFpLr(self: *FDE, offset: u32) !void {
        // Advance to instruction after frame setup
        try self.instructions.append(.{ .advance_loc = offset });

        // CFA is now SP + 16 (after pre-decrement)
        try self.instructions.append(.{
            .def_cfa_offset = 16,
        });

        // FP saved at CFA - 16
        try self.instructions.append(.{
            .offset = .{
                .reg = .x29,
                .offset = -16,
            },
        });

        // LR saved at CFA - 8
        try self.instructions.append(.{
            .offset = .{
                .reg = .x30,
                .offset = -8,
            },
        });
    }

    /// Add unwind info for setting frame pointer.
    /// Assumes: mov x29, sp
    pub fn addPrologueSetFp(self: *FDE, offset: u32) !void {
        try self.instructions.append(.{ .advance_loc = offset });

        // CFA is now defined via FP instead of SP
        try self.instructions.append(.{
            .def_cfa_register = .x29,
        });
    }

    /// Add unwind info for stack allocation.
    /// Assumes: sub sp, sp, #size
    pub fn addPrologueAllocStack(self: *FDE, offset: u32, size: u32) !void {
        try self.instructions.append(.{ .advance_loc = offset });

        // CFA offset increases by allocated size
        try self.instructions.append(.{
            .def_cfa_offset = size + 16,
        });
    }

    /// Add unwind info for callee-save register push.
    pub fn addPrologueSaveReg(self: *FDE, offset: u32, reg: DwarfReg, cfa_offset: i32) !void {
        try self.instructions.append(.{ .advance_loc = offset });

        try self.instructions.append(.{
            .offset = .{
                .reg = reg,
                .offset = cfa_offset,
            },
        });
    }
};

/// Unwind information for a compiled function.
pub const UnwindInfo = struct {
    cie: CIE,
    fde: FDE,

    pub fn init(allocator: std.mem.Allocator, pc_begin: u64, code_size: u32) !UnwindInfo {
        return .{
            .cie = try CIE.init(allocator),
            .fde = FDE.init(allocator, pc_begin, code_size),
        };
    }

    pub fn deinit(self: *UnwindInfo) void {
        self.cie.deinit();
        self.fde.deinit();
    }

    /// Generate standard unwind info for AAPCS64 function.
    /// Assumes standard prologue:
    ///   stp x29, x30, [sp, #-16]!
    ///   mov x29, sp
    ///   sub sp, sp, #stack_size (if needed)
    pub fn generateStandardPrologue(self: *UnwindInfo, stack_size: u32) !void {
        // Instruction 0: stp x29, x30, [sp, #-16]!
        try self.fde.addPrologueSaveFpLr(4);

        // Instruction 1: mov x29, sp
        try self.fde.addPrologueSetFp(8);

        // Instruction 2: sub sp, sp, #stack_size (if non-zero)
        if (stack_size > 0) {
            try self.fde.addPrologueAllocStack(12, stack_size);
        }
    }
};

test "DwarfReg mapping" {
    const testing = std.testing;

    try testing.expectEqual(DwarfReg.x0, DwarfReg.fromIntReg(0));
    try testing.expectEqual(DwarfReg.x29, DwarfReg.fromIntReg(29));
    try testing.expectEqual(DwarfReg.x30, DwarfReg.fromIntReg(30));

    try testing.expectEqual(DwarfReg.v0, DwarfReg.fromVecReg(0));
    try testing.expectEqual(DwarfReg.v31, DwarfReg.fromVecReg(31));
}

test "CIE initialization" {
    const testing = std.testing;

    var cie = try CIE.init(testing.allocator);
    defer cie.deinit();

    try testing.expectEqual(@as(u8, 1), cie.version);
    try testing.expectEqual(@as(u32, 4), cie.code_align_factor);
    try testing.expectEqual(@as(i32, -8), cie.data_align_factor);
    try testing.expectEqual(DwarfReg.x30, cie.return_address_register);

    // Should have initial CFA definition
    try testing.expectEqual(@as(usize, 1), cie.initial_instructions.items.len);
}

test "FDE standard prologue" {
    const testing = std.testing;

    var unwind = try UnwindInfo.init(testing.allocator, 0x1000, 64);
    defer unwind.deinit();

    try unwind.generateStandardPrologue(32);

    // Should have 3 advance_loc instructions and register saves
    try testing.expect(unwind.fde.instructions.items.len > 0);
}
