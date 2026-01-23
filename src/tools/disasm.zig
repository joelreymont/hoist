//! Capstone disassembler wrapper for test verification.

const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @cImport({
    @cInclude("capstone/capstone.h");
    @cInclude("capstone/arm64.h");
    @cInclude("capstone/x86.h");
});

pub const Arch = enum {
    aarch64,
    x86_64,
};

pub const Instruction = struct {
    addr: u64,
    size: u16,
    mnemonic: []const u8,
    op_str: []const u8,
    bytes: []const u8,
};

pub const Disassembler = struct {
    handle: c.csh,
    arch: Arch,
    allocator: Allocator,

    pub fn init(allocator: Allocator, arch: Arch) !Disassembler {
        var handle: c.csh = undefined;

        const cs_arch: c.cs_arch = switch (arch) {
            .aarch64 => c.CS_ARCH_ARM64,
            .x86_64 => c.CS_ARCH_X86,
        };

        const cs_mode: c.cs_mode = switch (arch) {
            .aarch64 => c.CS_MODE_ARM,
            .x86_64 => c.CS_MODE_64,
        };

        if (c.cs_open(cs_arch, cs_mode, &handle) != c.CS_ERR_OK) {
            return error.CapstoneInitFailed;
        }

        return .{
            .handle = handle,
            .arch = arch,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Disassembler) void {
        _ = c.cs_close(&self.handle);
    }

    pub fn disassemble(self: *Disassembler, bytes: []const u8, addr: u64) ![]Instruction {
        var insn: [*c]c.cs_insn = undefined;
        const count = c.cs_disasm(
            self.handle,
            bytes.ptr,
            bytes.len,
            addr,
            0, // disasm all
            &insn,
        );

        if (count == 0) {
            return error.DisassemblyFailed;
        }

        const result = try self.allocator.alloc(Instruction, count);
        errdefer self.allocator.free(result);

        for (0..count) |i| {
            const inst = insn[i];
            result[i] = .{
                .addr = inst.address,
                .size = inst.size,
                .mnemonic = std.mem.span(@as([*:0]const u8, @ptrCast(&inst.mnemonic))),
                .op_str = std.mem.span(@as([*:0]const u8, @ptrCast(&inst.op_str))),
                .bytes = inst.bytes[0..inst.size],
            };
        }

        c.cs_free(insn, count);
        return result;
    }

    pub fn free(self: *Disassembler, insns: []Instruction) void {
        self.allocator.free(insns);
    }
};

test "Disassembler: aarch64 basic" {
    if (@import("builtin").cpu.arch != .aarch64) return error.SkipZigTest;

    var disasm = try Disassembler.init(std.testing.allocator, .aarch64);
    defer disasm.deinit();

    // mov x0, #42
    const bytes = [_]u8{ 0x40, 0x05, 0x80, 0xd2 };
    const insns = try disasm.disassemble(&bytes, 0);
    defer disasm.free(insns);

    try std.testing.expectEqual(@as(usize, 1), insns.len);
    try std.testing.expect(std.mem.eql(u8, insns[0].mnemonic, "mov"));
}

test "Disassembler: x86_64 basic" {
    if (@import("builtin").cpu.arch != .x86_64) return error.SkipZigTest;

    var disasm = try Disassembler.init(std.testing.allocator, .x86_64);
    defer disasm.deinit();

    // mov eax, 42
    const bytes = [_]u8{ 0xb8, 0x2a, 0x00, 0x00, 0x00 };
    const insns = try disasm.disassemble(&bytes, 0);
    defer disasm.free(insns);

    try std.testing.expectEqual(@as(usize, 1), insns.len);
    try std.testing.expect(std.mem.eql(u8, insns[0].mnemonic, "mov"));
}
