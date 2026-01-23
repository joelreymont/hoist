//! JIT executable memory management.

const std = @import("std");
const builtin = @import("builtin");

/// Executable memory region for JIT-compiled code.
pub const Mem = struct {
    ptr: [*]align(std.mem.page_size) u8,
    len: usize,
    alloc: std.mem.Allocator,

    /// Allocate executable memory region.
    pub fn init(alloc: std.mem.Allocator, size: usize) !Mem {
        const page_size = std.mem.page_size;
        const aligned_size = std.mem.alignForward(usize, size, page_size);

        const ptr = switch (builtin.os.tag) {
            .macos, .ios, .tvos, .watchos => blk: {
                const mmap = std.c.mmap(
                    null,
                    aligned_size,
                    std.c.PROT.READ | std.c.PROT.WRITE | std.c.PROT.EXEC,
                    std.c.MAP{ .TYPE = .PRIVATE, .ANONYMOUS = true },
                    -1,
                    0,
                );
                if (mmap == std.c.MAP_FAILED) return error.OutOfMemory;
                break :blk @as([*]align(page_size) u8, @ptrCast(@alignCast(mmap)));
            },
            .linux => blk: {
                const mmap = std.os.linux.mmap(
                    null,
                    aligned_size,
                    std.os.linux.PROT.READ | std.os.linux.PROT.WRITE | std.os.linux.PROT.EXEC,
                    .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
                    -1,
                    0,
                );
                if (mmap < 0) return error.OutOfMemory;
                break :blk @as([*]align(page_size) u8, @ptrFromInt(@as(usize, @intCast(mmap))));
            },
            else => return error.UnsupportedPlatform,
        };

        return .{ .ptr = ptr, .len = aligned_size, .alloc = alloc };
    }

    /// Free executable memory.
    pub fn deinit(self: *Mem) void {
        switch (builtin.os.tag) {
            .macos, .ios, .tvos, .watchos => _ = std.c.munmap(self.ptr, self.len),
            .linux => _ = std.os.linux.munmap(self.ptr, self.len),
            else => {},
        }
    }

    /// Copy machine code into executable memory.
    pub fn write(self: *Mem, code: []const u8) !void {
        if (code.len > self.len) return error.CodeTooLarge;
        @memcpy(self.ptr[0..code.len], code);
        if (builtin.cpu.arch == .aarch64 or builtin.cpu.arch == .arm) {
            self.flushCache(code.len);
        }
    }

    /// Flush instruction cache for ARM architectures.
    fn flushCache(self: *Mem, len: usize) void {
        if (builtin.os.tag == .macos or builtin.os.tag == .ios) {
            const sys_icache_invalidate = struct {
                extern "c" fn sys_icache_invalidate(addr: *anyopaque, size: usize) void;
            }.sys_icache_invalidate;
            sys_icache_invalidate(self.ptr, len);
        } else if (builtin.os.tag == .linux) {
            const clear_cache = struct {
                extern "c" fn __clear_cache(begin: *anyopaque, end: *anyopaque) void;
            }.__clear_cache;
            clear_cache(self.ptr, self.ptr + len);
        }
    }

    /// Get function pointer with any signature.
    pub fn getFn(self: *Mem, comptime T: type) T {
        return @ptrCast(@alignCast(self.ptr));
    }

    /// Get function pointer for () -> i32 signature.
    pub fn getFnVoidToI32(self: *Mem) *const fn () callconv(.C) i32 {
        return @ptrCast(@alignCast(self.ptr));
    }

    /// Get function pointer for (i32, i32) -> i32 signature.
    pub fn getFnI32I32ToI32(self: *Mem) *const fn (i32, i32) callconv(.C) i32 {
        return @ptrCast(@alignCast(self.ptr));
    }

    /// Get function pointer for (i64, i64) -> i64 signature.
    pub fn getFnI64I64ToI64(self: *Mem) *const fn (i64, i64) callconv(.C) i64 {
        return @ptrCast(@alignCast(self.ptr));
    }
};
