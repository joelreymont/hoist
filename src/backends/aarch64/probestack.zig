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
const CondCode = inst_mod.CondCode;
const Imm12 = inst_mod.Imm12;

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

fn x15() Reg {
    return Reg.fromPReg(PReg.new(.int, 15));
}

fn emitLoadImm32(result: *ProbeResult, dst: WritableReg, value: u32) !void {
    try result.insts.append(.{ .movz = .{
        .dst = dst,
        .imm = @as(u16, @truncate(value)),
        .shift = 0,
        .size = .d,
    } });

    const upper = value >> 16;
    if (upper != 0) {
        try result.insts.append(.{ .movk = .{
            .dst = dst,
            .imm = @as(u16, @truncate(upper)),
            .shift = 16,
            .size = .d,
        } });
    }
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

        // mov x16, #page_size
        try emitLoadImm32(result, scratch.toWritable(), config.page_size);

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

        const counter = x15();
        try emitLoadImm32(result, counter.toWritable(), num_pages);

        const loop_start: i32 = @intCast(result.insts.items.len);

        // str xzr, [x17]
        try result.insts.append(.{ .str_imm = .{
            .src = xzr(),
            .base = probe_addr,
            .offset = 0,
            .size = .d,
        } });

        // add x17, x17, x16
        try result.insts.append(.{ .add_reg = .{
            .dst = probe_addr.toWritable(),
            .src1 = probe_addr,
            .src2 = scratch,
            .size = .d,
        } });

        // subs x15, x15, #1
        const dec = Imm12{ .bits = 1, .shift12 = false };
        try result.insts.append(.{ .subs_imm = .{
            .dst = counter.toWritable(),
            .src = counter,
            .imm = dec,
            .size = .d,
        } });

        // b.ne loop_start
        const branch_idx: i32 = @intCast(result.insts.items.len);
        const offset_bytes: i32 = (loop_start - branch_idx) * 4;
        try result.insts.append(.{ .b_cond = .{
            .cond = CondCode.ne,
            .target = .{ .offset = offset_bytes },
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

test "emitProbestack loop probes" {
    const testing = std.testing;

    const cfg = Config{
        .page_size = 4096,
        .inline_threshold = 4096 * 8,
        .unroll_limit = 2,
    };

    var result = try emitProbestack(testing.allocator, 4096 * 5, cfg);
    defer result.deinit();

    try testing.expect(result.insts.items.len > 0);

    var saw_subs = false;
    var saw_str = false;
    for (result.insts.items) |inst| {
        switch (inst) {
            .subs_imm => saw_subs = true,
            .str_imm => saw_str = true,
            else => {},
        }
    }

    try testing.expect(saw_subs);
    try testing.expect(saw_str);

    const last = result.insts.items[result.insts.items.len - 1];
    try testing.expect(last == .b_cond);
    try testing.expectEqual(CondCode.ne, last.b_cond.cond);
    switch (last.b_cond.target) {
        .offset => |off| try testing.expect(off < 0),
        else => try testing.expect(false),
    }
}
