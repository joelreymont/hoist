//! Target Specification
//!
//! Describes the target platform for code generation including:
//! - Architecture (aarch64, x86_64, etc.)
//! - Operating system (linux, macos, windows)
//! - Calling convention
//! - Object file format
//! - CPU features

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const features_mod = @import("features.zig");
pub const Features = features_mod.Features;
pub const AArch64Features = features_mod.AArch64Features;
pub const X86Features = features_mod.X86Features;

/// Target architecture.
pub const Arch = enum {
    aarch64,
    x86_64,
    riscv64,
    s390x,

    /// Get pointer size in bytes.
    pub fn ptrSize(self: Arch) u8 {
        return switch (self) {
            .aarch64, .x86_64, .riscv64, .s390x => 8,
        };
    }

    /// Get pointer size in bits.
    pub fn ptrBits(self: Arch) u8 {
        return self.ptrSize() * 8;
    }

    /// Get default stack alignment.
    pub fn stackAlign(self: Arch) u8 {
        return switch (self) {
            .aarch64 => 16,
            .x86_64 => 16,
            .riscv64 => 16,
            .s390x => 8,
        };
    }

    /// Get endianness.
    pub fn endian(self: Arch) std.builtin.Endian {
        return switch (self) {
            .aarch64, .x86_64, .riscv64 => .little,
            .s390x => .big,
        };
    }

    /// Number of general purpose registers.
    pub fn numGPR(self: Arch) u8 {
        return switch (self) {
            .aarch64 => 31, // x0-x30
            .x86_64 => 16, // rax-r15
            .riscv64 => 32, // x0-x31
            .s390x => 16, // r0-r15
        };
    }

    /// Number of floating point registers.
    pub fn numFPR(self: Arch) u8 {
        return switch (self) {
            .aarch64 => 32, // v0-v31
            .x86_64 => 16, // xmm0-xmm15
            .riscv64 => 32, // f0-f31
            .s390x => 16, // f0-f15
        };
    }

};

/// Operating system.
pub const Os = enum {
    linux,
    macos,
    windows,
    freebsd,
    netbsd,
    openbsd,
    none, // Bare metal / freestanding

    /// Whether this OS uses ELF object format.
    pub fn isElf(self: Os) bool {
        return switch (self) {
            .linux, .freebsd, .netbsd, .openbsd => true,
            .macos, .windows, .none => false,
        };
    }

    /// Whether this OS is Unix-like.
    pub fn isUnix(self: Os) bool {
        return switch (self) {
            .linux, .macos, .freebsd, .netbsd, .openbsd => true,
            .windows, .none => false,
        };
    }

};

/// Object file format.
pub const ObjFmt = enum {
    elf,
    macho,
    coff,
    raw, // Raw binary

};

/// ABI variant.
pub const Abi = enum {
    gnu,
    musl,
    msvc,
    eabi, // Embedded ABI
    darwin,
    none,

};

/// Calling convention.
pub const CallConv = enum {
    /// System V AMD64 ABI (Linux/macOS x86_64).
    sysv,
    /// Microsoft x64 calling convention (Windows).
    win64,
    /// AArch64 AAPCS64.
    aapcs64,
    /// RISC-V calling convention.
    riscv,
    /// SystemZ calling convention.
    systemz,
    /// Tail call optimized.
    tail,
    /// Fast call (caller-saved only).
    fast,

};

/// Complete target specification.
pub const Target = struct {
    arch: Arch,
    os: Os,
    abi: Abi,
    features: Features,

    /// Create target from components.
    pub fn init(arch: Arch, os: Os, abi: Abi) Target {
        return .{
            .arch = arch,
            .os = os,
            .abi = abi,
            .features = Features.init(),
        };
    }

    /// Create target with features.
    pub fn initWithFeatures(arch: Arch, os: Os, abi: Abi, features: Features) Target {
        return .{
            .arch = arch,
            .os = os,
            .abi = abi,
            .features = features,
        };
    }

    /// Detect native target from current build environment.
    pub fn native() Target {
        const arch: Arch = switch (builtin.cpu.arch) {
            .aarch64 => .aarch64,
            .x86_64 => .x86_64,
            .riscv64 => .riscv64,
            .s390x => .s390x,
            else => .x86_64, // fallback
        };

        const os: Os = switch (builtin.os.tag) {
            .linux => .linux,
            .macos => .macos,
            .windows => .windows,
            .freebsd => .freebsd,
            .netbsd => .netbsd,
            .openbsd => .openbsd,
            .freestanding => .none,
            else => .linux, // fallback
        };

        const abi: Abi = switch (builtin.os.tag) {
            .macos => .darwin,
            .windows => .msvc,
            .linux => .gnu, // Could be musl
            else => .none,
        };

        var target = Target.init(arch, os, abi);
        target.features = nativeFeatures(arch);
        return target;
    }

    fn nativeFeatures(arch: Arch) Features {
        return switch (arch) {
            .aarch64 => AArch64Features.baseline(),
            .x86_64 => X86Features.baseline(),
            else => Features.init(),
        };
    }

    /// Get object file format for this target.
    pub fn objFmt(self: Target) ObjFmt {
        return switch (self.os) {
            .linux, .freebsd, .netbsd, .openbsd => .elf,
            .macos => .macho,
            .windows => .coff,
            .none => .raw,
        };
    }

    /// Get default calling convention.
    pub fn defaultCallConv(self: Target) CallConv {
        return switch (self.arch) {
            .aarch64 => .aapcs64,
            .x86_64 => if (self.os == .windows) .win64 else .sysv,
            .riscv64 => .riscv,
            .s390x => .systemz,
        };
    }

    /// Get pointer size in bytes.
    pub fn ptrSize(self: Target) u8 {
        return self.arch.ptrSize();
    }

    /// Get pointer size in bits.
    pub fn ptrBits(self: Target) u8 {
        return self.arch.ptrBits();
    }

    /// Get stack alignment.
    pub fn stackAlign(self: Target) u8 {
        return self.arch.stackAlign();
    }

    /// Get endianness.
    pub fn endian(self: Target) std.builtin.Endian {
        return self.arch.endian();
    }

    /// Check if target needs position-independent code.
    pub fn needsPIC(self: Target) bool {
        // macOS always requires PIC for shared libs
        if (self.os == .macos) return true;
        return false;
    }

    /// Check if target supports thread-local storage.
    pub fn hasTLS(self: Target) bool {
        return self.os != .none;
    }

    /// Check if we should use GOT-relative addressing.
    pub fn usesGOT(self: Target) bool {
        return self.needsPIC() and self.objFmt() == .elf;
    }

    /// Get max immediate for this target's load/store.
    pub fn maxLoadStoreImm(self: Target) i64 {
        return switch (self.arch) {
            .aarch64 => 4095, // 12-bit unsigned
            .x86_64 => @as(i64, 1) << 31 - 1, // 32-bit signed
            .riscv64 => 2047, // 12-bit signed
            .s390x => (1 << 20) - 1, // 20-bit
        };
    }

    /// Get page size.
    pub fn pageSize(self: Target) u32 {
        return switch (self.os) {
            .macos => 16384, // 16KB on Apple Silicon
            else => 4096,
        };
    }

    /// Format triple into buffer. Returns length written.
    pub fn writeTriple(self: Target, buf: []u8) usize {
        const arch_name = @tagName(self.arch);
        const os_name = @tagName(self.os);
        const abi_name = @tagName(self.abi);

        var pos: usize = 0;
        @memcpy(buf[pos..][0..arch_name.len], arch_name);
        pos += arch_name.len;
        buf[pos] = '-';
        pos += 1;
        @memcpy(buf[pos..][0..os_name.len], os_name);
        pos += os_name.len;
        buf[pos] = '-';
        pos += 1;
        @memcpy(buf[pos..][0..abi_name.len], abi_name);
        pos += abi_name.len;

        return pos;
    }

    /// Parse from triple string.
    pub fn parse(triple: []const u8) !Target {
        var iter = std.mem.splitScalar(u8, triple, '-');

        const arch_str = iter.next() orelse return error.InvalidTriple;
        const os_str = iter.next() orelse return error.InvalidTriple;
        const abi_str = iter.next();

        const arch = std.meta.stringToEnum(Arch, arch_str) orelse return error.UnknownArch;
        const os = std.meta.stringToEnum(Os, os_str) orelse return error.UnknownOs;
        const abi = if (abi_str) |s|
            std.meta.stringToEnum(Abi, s) orelse return error.UnknownAbi
        else
            defaultAbi(os);

        return Target.init(arch, os, abi);
    }

    fn defaultAbi(os: Os) Abi {
        return switch (os) {
            .macos => .darwin,
            .windows => .msvc,
            .linux => .gnu,
            else => .none,
        };
    }
};

/// Pre-defined targets.
pub const targets = struct {
    pub const aarch64_macos = Target.initWithFeatures(.aarch64, .macos, .darwin, AArch64Features.baseline());
    pub const aarch64_linux = Target.initWithFeatures(.aarch64, .linux, .gnu, AArch64Features.baseline());
    pub const x86_64_linux = Target.initWithFeatures(.x86_64, .linux, .gnu, X86Features.baseline());
    pub const x86_64_windows = Target.initWithFeatures(.x86_64, .windows, .msvc, X86Features.baseline());
    pub const riscv64_linux = Target.init(.riscv64, .linux, .gnu);
    pub const s390x_linux = Target.init(.s390x, .linux, .gnu);
};

// Tests
test "Arch properties" {
    try testing.expectEqual(@as(u8, 8), Arch.aarch64.ptrSize());
    try testing.expectEqual(@as(u8, 64), Arch.x86_64.ptrBits());
    try testing.expectEqual(@as(u8, 16), Arch.aarch64.stackAlign());
    try testing.expectEqual(std.builtin.Endian.little, Arch.aarch64.endian());
    try testing.expectEqual(std.builtin.Endian.big, Arch.s390x.endian());
}

test "Target native" {
    const target = Target.native();
    try testing.expectEqual(@as(u8, 8), target.ptrSize());
    try testing.expect(target.stackAlign() >= 8);
}

test "Target object format" {
    try testing.expectEqual(ObjFmt.macho, targets.aarch64_macos.objFmt());
    try testing.expectEqual(ObjFmt.elf, targets.aarch64_linux.objFmt());
    try testing.expectEqual(ObjFmt.coff, targets.x86_64_windows.objFmt());
}

test "Target calling convention" {
    try testing.expectEqual(CallConv.aapcs64, targets.aarch64_macos.defaultCallConv());
    try testing.expectEqual(CallConv.sysv, targets.x86_64_linux.defaultCallConv());
    try testing.expectEqual(CallConv.win64, targets.x86_64_windows.defaultCallConv());
}

test "Target parse" {
    const target = try Target.parse("aarch64-linux-gnu");
    try testing.expectEqual(Arch.aarch64, target.arch);
    try testing.expectEqual(Os.linux, target.os);
    try testing.expectEqual(Abi.gnu, target.abi);
}

test "Target triple" {
    var buf: [64]u8 = undefined;
    const len = targets.aarch64_macos.writeTriple(&buf);
    try testing.expectEqualStrings("aarch64-macos-darwin", buf[0..len]);
}

test "Target PIC requirements" {
    try testing.expect(targets.aarch64_macos.needsPIC());
    try testing.expect(!targets.aarch64_linux.needsPIC());
}
