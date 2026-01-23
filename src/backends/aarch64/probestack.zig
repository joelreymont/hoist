//! Stack Probing for AArch64
//!
//! Emits stack probing code to ensure stack guard pages are touched
//! before allocating large stack frames. This prevents stack overflow
//! from skipping over guard pages.
//!
//! Two strategies:
//! 1. Inline probing: emit explicit stores to touch each page
//! 2. Libcall: call __probestack helper function
//!
//! The probe interval is typically one page (4KB or 16KB on Apple Silicon).

const std = @import("std");
const Allocator = std.mem.Allocator;

const inst_mod = @import("inst.zig");
const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const PReg = inst_mod.PReg;
const WritableReg = inst_mod.WritableReg;

// Register helpers
fn xzr() Reg {
    return Reg.fromPReg(PReg.new(.int, 31)); // XZR/SP encoding
}

fn sp() Reg {
    return Reg.fromPReg(inst_mod.sp);
}

fn x0() Reg {
    return Reg.fromPReg(PReg.new(.int, 0));
}

fn x16() Reg {
    return Reg.fromPReg(PReg.new(.int, 16));
}

fn x17() Reg {
    return Reg.fromPReg(PReg.new(.int, 17));
}

/// Probestack configuration.
pub const Config = struct {
    /// Page size for probing (bytes).
    page_size: u32 = 4096,

    /// Use inline probing instead of libcall.
    inline_probes: bool = true,

    /// Maximum stack size for inline probing (use libcall above this).
    inline_threshold: u32 = 4096 * 8,

    /// Unroll probe loop up to this many iterations.
    unroll_limit: u32 = 4,
};

/// Probestack emission result.
pub const ProbeResult = struct {
    /// Instructions emitted.
    insts: std.ArrayList(Inst),

    pub fn deinit(self: *ProbeResult) void {
        self.insts.deinit();
    }
};

/// Emit stack probing for a given frame size.
pub fn emitProbestack(
    allocator: Allocator,
    frame_size: u32,
    config: Config,
) !ProbeResult {
    var result = ProbeResult{
        .insts = std.ArrayList(Inst).init(allocator),
    };
    errdefer result.deinit();

    // No probing needed for small frames
    if (frame_size <= config.page_size) {
        return result;
    }

    // Use libcall for very large frames
    if (frame_size > config.inline_threshold) {
        try emitLibcallProbe(&result, frame_size);
        return result;
    }

    // Inline probing
    try emitInlineProbes(&result, frame_size, config);
    return result;
}

/// Emit inline probe instructions.
fn emitInlineProbes(result: *ProbeResult, frame_size: u32, config: Config) !void {
    const num_pages = (frame_size + config.page_size - 1) / config.page_size;

    // Use x16 as scratch register (caller-saved, not argument reg)
    const scratch = x16();

    if (num_pages <= config.unroll_limit) {
        // Unrolled probing - emit store for each page
        var offset: i32 = -@as(i32, @intCast(config.page_size));
        for (0..num_pages) |_| {
            // str xzr, [sp, #offset]
            try result.insts.append(.{ .str_imm = .{
                .src = xzr(),
                .base = sp(),
                .offset = offset,
                .size = .d,
            } });
            offset -= @as(i32, @intCast(config.page_size));
        }
    } else {
        // Loop-based probing for many pages

        // mov x16, #-page_size
        try result.insts.append(.{ .movz = .{
            .dst = scratch.toWritable(),
            .imm = @as(u16, @truncate(config.page_size)),
            .shift = 0,
            .size = .d,
        } });

        // neg x16, x16
        try result.insts.append(.{ .neg = .{
            .dst = scratch.toWritable(),
            .src = scratch,
            .size = .d,
        } });

        // Loop: probe each page
        // add x17, sp, x16
        const probe_addr = x17();
        try result.insts.append(.{ .add_reg = .{
            .dst = probe_addr.toWritable(),
            .src1 = sp(),
            .src2 = scratch,
            .size = .d,
        } });

        // Loop body would need labels - for now just document
        // TODO: Implement loop with proper label support

        // str xzr, [x17]
        try result.insts.append(.{ .str_imm = .{
            .src = xzr(),
            .base = probe_addr,
            .offset = 0,
            .size = .d,
        } });
    }
}

/// Emit libcall-based probing.
fn emitLibcallProbe(result: *ProbeResult, frame_size: u32) !void {
    // Load frame size into x0
    try result.insts.append(.{ .movz = .{
        .dst = x0().toWritable(),
        .imm = @as(u16, @truncate(frame_size)),
        .shift = 0,
        .size = .d,
    } });

    if (frame_size > 0xFFFF) {
        // movk x0, #high, lsl #16
        try result.insts.append(.{ .movk = .{
            .dst = x0().toWritable(),
            .imm = @as(u16, @truncate(frame_size >> 16)),
            .shift = 16,
            .size = .d,
        } });
    }

    // bl __probestack
    // The actual call emission happens in the caller - we just set up args
}

/// Calculate if probing is needed for a frame size.
pub fn needsProbing(frame_size: u32, page_size: u32) bool {
    return frame_size > page_size;
}

/// Get the number of probe points needed.
pub fn probeCount(frame_size: u32, page_size: u32) u32 {
    if (frame_size <= page_size) return 0;
    return (frame_size + page_size - 1) / page_size;
}

// Tests
test "Config defaults" {
    const testing = std.testing;
    const config = Config{};

    try testing.expectEqual(@as(u32, 4096), config.page_size);
    try testing.expect(config.inline_probes);
    try testing.expectEqual(@as(u32, 4), config.unroll_limit);
}

test "needsProbing" {
    const testing = std.testing;

    try testing.expect(!needsProbing(1000, 4096));
    try testing.expect(!needsProbing(4096, 4096));
    try testing.expect(needsProbing(4097, 4096));
    try testing.expect(needsProbing(8192, 4096));
}

test "probeCount" {
    const testing = std.testing;

    try testing.expectEqual(@as(u32, 0), probeCount(1000, 4096));
    try testing.expectEqual(@as(u32, 1), probeCount(4096, 4096));
    try testing.expectEqual(@as(u32, 2), probeCount(4097, 4096));
    try testing.expectEqual(@as(u32, 2), probeCount(8192, 4096));
    try testing.expectEqual(@as(u32, 3), probeCount(8193, 4096));
}

test "emitProbestack small frame" {
    const testing = std.testing;

    var result = try emitProbestack(testing.allocator, 1000, .{});
    defer result.deinit();

    // No probing for small frames
    try testing.expectEqual(@as(usize, 0), result.insts.items.len);
}

test "emitProbestack one page" {
    const testing = std.testing;

    var result = try emitProbestack(testing.allocator, 8000, .{ .page_size = 4096 });
    defer result.deinit();

    // Should emit 2 probe stores
    try testing.expectEqual(@as(usize, 2), result.insts.items.len);
}
