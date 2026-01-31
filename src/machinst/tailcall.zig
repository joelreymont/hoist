const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const abi_mod = @import("abi.zig");
const reg_mod = @import("reg.zig");
const parallel_copy = @import("parallel_copy.zig");

pub const Type = abi_mod.Type;
pub const CallConv = abi_mod.CallConv;
pub const ABISignature = abi_mod.ABISignature;
pub const ABIArg = abi_mod.ABIArg;
pub const ABIArgSlot = abi_mod.ABIArgSlot;
pub const Reg = reg_mod.Reg;
pub const PReg = reg_mod.PReg;

/// Result of tail call analysis.
pub const TailCallAnalysis = struct {
    /// Can this call be converted to a tail call?
    is_valid: bool,
    /// Reason why tail call is invalid (if !is_valid).
    reason: InvalidReason,

    pub const InvalidReason = enum {
        none,
        /// Calling conventions are incompatible.
        incompatible_callconv,
        /// Stack cleanup is required after the call.
        requires_cleanup,
        /// Caller has more stack arguments than callee.
        insufficient_stack_space,
        /// Arguments require complex transformations.
        complex_arg_transforms,
        /// Return values are incompatible.
        incompatible_returns,
    };
};

/// Tail call detection and validation.
///
/// Determines if a call site can be converted to a tail call by checking:
/// 1. Calling conventions are compatible
/// 2. No cleanup is needed after the call
/// 3. Stack frame can be eliminated
/// 4. Arguments can be forwarded without stack growth
pub fn analyzeTailCall(
    caller_sig: ABISignature,
    callee_sig: ABISignature,
) TailCallAnalysis {
    // Check calling convention compatibility.
    // Tail calls require the caller to use a tail-call-supporting convention.
    if (!supportsTailCalls(caller_sig.call_conv)) {
        return .{
            .is_valid = false,
            .reason = .incompatible_callconv,
        };
    }

    // For simplicity, require exact calling convention match.
    // Advanced implementations could allow compatible conventions.
    if (caller_sig.call_conv != callee_sig.call_conv) {
        return .{
            .is_valid = false,
            .reason = .incompatible_callconv,
        };
    }

    // Check if caller's incoming stack args can accommodate callee's outgoing args.
    // For tail calls, we reuse the caller's stack arg space.
    const caller_stack_space = computeStackArgSpace(caller_sig.args);
    const callee_stack_space = computeStackArgSpace(callee_sig.args);

    if (callee_stack_space > caller_stack_space) {
        return .{
            .is_valid = false,
            .reason = .insufficient_stack_space,
        };
    }

    // Check return value compatibility.
    // Tail call must return values in the same way.
    if (!areReturnsCompatible(caller_sig.rets, callee_sig.rets)) {
        return .{
            .is_valid = false,
            .reason = .incompatible_returns,
        };
    }

    return .{
        .is_valid = true,
        .reason = .none,
    };
}

fn supportsTailCalls(call_conv: CallConv) bool {
    return switch (call_conv) {
        .system_v, .aapcs64 => true,
        .windows_fastcall => false, // Windows x64 doesn't support tail calls in general case
    };
}

/// Compute stack space required for arguments.
fn computeStackArgSpace(args: []const Type) u32 {
    var stack_offset: u32 = 0;
    for (args) |arg_type| {
        // Simplified: assume each arg takes 8 bytes if on stack
        // Real implementation would compute actual ABI layout
        const size = arg_type.bytes();
        // Round up to 8-byte alignment
        const aligned_size = std.mem.alignForward(u32, size, 8);
        stack_offset += aligned_size;
    }
    return stack_offset;
}

/// Check if return values are compatible for tail calls.
fn areReturnsCompatible(caller_rets: []const Type, callee_rets: []const Type) bool {
    if (caller_rets.len != callee_rets.len) return false;

    for (caller_rets, callee_rets) |caller_ret, callee_ret| {
        // For now, require exact type match.
        // More sophisticated: check if they use same registers.
        if (!std.meta.eql(caller_ret, callee_ret)) {
            return false;
        }
    }

    return true;
}

/// Argument forwarding plan for tail calls.
pub const ArgForwardingPlan = struct {
    /// Moves required to forward arguments.
    moves: std.ArrayList(ArgMove),
    /// Maximum stack offset used during forwarding.
    max_stack_used: u32,
    alloc: Allocator,

    pub fn init(allocator: Allocator) ArgForwardingPlan {
        return .{
            .moves = std.ArrayList(ArgMove){},
            .max_stack_used = 0,
            .alloc = allocator,
        };
    }

    pub fn deinit(self: *ArgForwardingPlan) void {
        self.moves.deinit(self.alloc);
    }

    /// Argument move operation.
    pub const ArgMove = struct {
        src: ArgLocation,
        dst: ArgLocation,
        ty: Type,
    };

    pub const ArgLocation = union(enum) {
        reg: PReg,
        stack: i64,
    };
};

/// Create a plan to forward arguments from caller to callee for a tail call.
///
/// This handles the complexity of moving arguments without clobbering:
/// - Uses temporary locations if source and destination overlap
/// - Orders moves to avoid conflicts
/// - Reuses caller's incoming argument space
pub fn planArgForwarding(
    allocator: Allocator,
    caller_args: []const ABIArg,
    callee_args: []const ABIArg,
    arg_locs: []const ArgForwardingPlan.ArgLocation,
    scratch: ?ArgForwardingPlan.ArgLocation,
) !ArgForwardingPlan {
    var plan = ArgForwardingPlan.init(allocator);
    errdefer plan.deinit();

    std.debug.assert(callee_args.len == arg_locs.len);

    // Build forwarding moves.
    // For each callee argument, we need to move from current location to target.
    for (callee_args, arg_locs) |callee_arg, src_loc| {
        // Get destination location from callee ABI
        for (callee_arg.slots) |slot| {
            const dst_loc = switch (slot) {
                .reg => |r| ArgForwardingPlan.ArgLocation{ .reg = r.preg },
                .stack => |s| ArgForwardingPlan.ArgLocation{ .stack = s.offset },
            };

            const ty = getType(slot);

            try plan.moves.append(allocator, .{
                .src = src_loc,
                .dst = dst_loc,
                .ty = ty,
            });

            // Track stack usage
            switch (dst_loc) {
                .stack => |offset| {
                    const stack_end = @as(u32, @intCast(@abs(offset) + @as(i64, ty.bytes())));
                    plan.max_stack_used = @max(plan.max_stack_used, stack_end);
                },
                else => {},
            }
        }
    }

    if (plan.moves.items.len > 0) {
        try orderArgMoves(allocator, caller_args, callee_args, scratch, &plan);
    }

    return plan;
}

fn getType(slot: ABIArgSlot) Type {
    return switch (slot) {
        .reg => |r| r.ty,
        .stack => |s| s.ty,
    };
}

fn orderArgMoves(
    allocator: Allocator,
    caller_args: []const ABIArg,
    callee_args: []const ABIArg,
    scratch: ?ArgForwardingPlan.ArgLocation,
    plan: *ArgForwardingPlan,
) !void {
    const temp_loc = scratch orelse pickStackScratch(caller_args, callee_args, plan.moves.items);

    var pc_moves: std.ArrayList(parallel_copy.Move) = .{};
    defer pc_moves.deinit(allocator);
    try pc_moves.ensureTotalCapacity(allocator, plan.moves.items.len);

    for (plan.moves.items, 0..) |move, idx| {
        pc_moves.appendAssumeCapacity(.{
            .src = argToLoc(move.src),
            .dst = argToLoc(move.dst),
            .origin = idx,
        });
    }

    const pc_temp = if (temp_loc) |t| argToLoc(t) else null;
    var resolved = try parallel_copy.resolve(allocator, pc_moves.items, pc_temp);
    defer resolved.deinit(allocator);

    var ordered: std.ArrayList(ArgForwardingPlan.ArgMove) = .{};
    errdefer ordered.deinit(allocator);
    try ordered.ensureTotalCapacity(allocator, resolved.items.len);

    for (resolved.items) |move| {
        const base = plan.moves.items[move.origin];
        ordered.appendAssumeCapacity(.{
            .src = locToArg(move.src),
            .dst = locToArg(move.dst),
            .ty = base.ty,
        });
    }

    plan.moves.deinit(allocator);
    plan.moves = ordered;

    if (temp_loc) |tmp| switch (tmp) {
        .stack => |offset| {
            const max_size = maxMoveSize(plan.moves.items);
            const end = @as(u64, @intCast(offset)) + max_size;
            if (end > plan.max_stack_used) {
                plan.max_stack_used = @intCast(end);
            }
        },
        else => {},
    };
}

fn maxMoveSize(moves: []const ArgForwardingPlan.ArgMove) u64 {
    var max_size: u64 = 0;
    for (moves) |move| {
        max_size = @max(max_size, @as(u64, @intCast(move.ty.bytes())));
    }
    return max_size;
}

fn pickStackScratch(
    caller_args: []const ABIArg,
    callee_args: []const ABIArg,
    moves: []const ArgForwardingPlan.ArgMove,
) ?ArgForwardingPlan.ArgLocation {
    const max_size = maxMoveSize(moves);
    if (max_size == 0) return null;

    const caller_max = stackExtent(caller_args);
    const callee_max = stackExtent(callee_args);

    if (caller_max <= callee_max) return null;
    if (caller_max < 0 or callee_max < 0) return null;

    const caller_limit: u64 = @intCast(caller_max);
    var candidate: u64 = std.mem.alignForward(u64, @intCast(callee_max), 8);
    while (candidate + max_size <= caller_limit) : (candidate += 8) {
        if (!stackOverlapsMoves(candidate, max_size, moves)) {
            return .{ .stack = @intCast(candidate) };
        }
    }

    return null;
}

fn stackOverlapsMoves(offset: u64, size: u64, moves: []const ArgForwardingPlan.ArgMove) bool {
    for (moves) |move| {
        const move_size: u64 = @intCast(move.ty.bytes());
        if (move_size == 0) continue;
        switch (move.src) {
            .stack => |src_off| {
                if (src_off < 0) return true;
                if (rangesOverlap(offset, offset + size, @intCast(src_off), @intCast(src_off) + move_size)) return true;
            },
            else => {},
        }
        switch (move.dst) {
            .stack => |dst_off| {
                if (dst_off < 0) return true;
                if (rangesOverlap(offset, offset + size, @intCast(dst_off), @intCast(dst_off) + move_size)) return true;
            },
            else => {},
        }
    }
    return false;
}

fn rangesOverlap(a_start: u64, a_end: u64, b_start: u64, b_end: u64) bool {
    return a_start < b_end and b_start < a_end;
}

fn stackExtent(args: []const ABIArg) i64 {
    var max_end: i64 = 0;
    for (args) |arg| {
        for (arg.slots) |slot| {
            switch (slot) {
                .stack => |s| {
                    const size: i64 = @intCast(s.ty.bytes());
                    const end = s.offset + size;
                    if (end > max_end) max_end = end;
                },
                else => {},
            }
        }
    }
    return max_end;
}

fn argToLoc(loc: ArgForwardingPlan.ArgLocation) parallel_copy.Location {
    return switch (loc) {
        .reg => |r| .{ .reg = r.index() },
        .stack => |s| .{ .stack = s },
    };
}

fn locToArg(loc: parallel_copy.Location) ArgForwardingPlan.ArgLocation {
    return switch (loc) {
        .reg => |r| .{ .reg = PReg{ .bits = r } },
        .stack => |s| .{ .stack = s },
    };
}

/// Backend hooks for tail call emission.
/// Each architecture backend implements this trait.
pub fn TailCallBackend(comptime MachInst: type) type {
    return struct {
        /// Generate instructions to forward arguments for a tail call.
        ///
        /// This moves arguments from their current locations to the positions
        /// expected by the callee, reusing the caller's stack frame.
        genForwardArgsFn: *const fn (
            plan: *const ArgForwardingPlan,
            insts: *std.ArrayList(MachInst),
        ) anyerror!void,

        /// Generate a tail call instruction.
        ///
        /// This performs the actual call without setting up a new frame.
        /// The call transfers control without return.
        genTailCallFn: *const fn (
            target: TailCallTarget,
            insts: *std.ArrayList(MachInst),
        ) anyerror!void,

        pub const TailCallTarget = union(enum) {
            /// Direct call to a known function.
            direct: u32, // Function index or address
            /// Indirect call through a register.
            indirect: Reg,
        };
    };
}

test "analyzeTailCall valid" {
    const args = [_]Type{ .i64, .i32 };
    const rets = [_]Type{.i64};

    const caller_sig = ABISignature{
        .args = &args,
        .rets = &rets,
        .call_conv = .system_v,
    };

    const callee_sig = ABISignature{
        .args = &args,
        .rets = &rets,
        .call_conv = .system_v,
    };

    const analysis = analyzeTailCall(caller_sig, callee_sig);
    try testing.expect(analysis.is_valid);
    try testing.expectEqual(TailCallAnalysis.InvalidReason.none, analysis.reason);
}

test "analyzeTailCall incompatible callconv" {
    const args = [_]Type{.i64};
    const rets = [_]Type{.i64};

    const caller_sig = ABISignature{
        .args = &args,
        .rets = &rets,
        .call_conv = .windows_fastcall,
    };

    const callee_sig = ABISignature{
        .args = &args,
        .rets = &rets,
        .call_conv = .system_v,
    };

    const analysis = analyzeTailCall(caller_sig, callee_sig);
    try testing.expect(!analysis.is_valid);
    try testing.expectEqual(TailCallAnalysis.InvalidReason.incompatible_callconv, analysis.reason);
}

test "analyzeTailCall incompatible returns" {
    const args = [_]Type{.i64};
    const caller_rets = [_]Type{.i64};
    const callee_rets = [_]Type{.i32};

    const caller_sig = ABISignature{
        .args = &args,
        .rets = &caller_rets,
        .call_conv = .system_v,
    };

    const callee_sig = ABISignature{
        .args = &args,
        .rets = &callee_rets,
        .call_conv = .system_v,
    };

    const analysis = analyzeTailCall(caller_sig, callee_sig);
    try testing.expect(!analysis.is_valid);
    try testing.expectEqual(TailCallAnalysis.InvalidReason.incompatible_returns, analysis.reason);
}

test "computeStackArgSpace" {
    const args = [_]Type{ .i32, .i64, .f32 };
    const space = computeStackArgSpace(&args);
    // i32: 8 bytes (aligned), i64: 8 bytes, f32: 8 bytes (aligned) = 24 bytes
    try testing.expectEqual(@as(u32, 24), space);
}

test "areReturnsCompatible" {
    const rets1 = [_]Type{ .i64, .f64 };
    const rets2 = [_]Type{ .i64, .f64 };
    const rets3 = [_]Type{ .i64, .i32 };
    const rets4 = [_]Type{.i64};

    try testing.expect(areReturnsCompatible(&rets1, &rets2));
    try testing.expect(!areReturnsCompatible(&rets1, &rets3));
    try testing.expect(!areReturnsCompatible(&rets1, &rets4));
}

test "ArgForwardingPlan basic" {
    var plan = ArgForwardingPlan.init(testing.allocator);
    defer plan.deinit();

    const move = ArgForwardingPlan.ArgMove{
        .src = .{ .reg = PReg.new(.int, 0) },
        .dst = .{ .reg = PReg.new(.int, 1) },
        .ty = .i64,
    };

    try plan.moves.append(plan.alloc, move);
    try testing.expectEqual(@as(usize, 1), plan.moves.items.len);
    try testing.expectEqual(move.src.reg.index(), plan.moves.items[0].src.reg.index());
}

test "planArgForwarding simple" {
    const allocator = testing.allocator;

    // Create simple ABI args
    var callee_slots = [_]ABIArgSlot{.{
        .reg = .{
            .preg = PReg.new(.int, 0),
            .ty = .i64,
            .extension = .none,
        },
    }};

    var callee_args = [_]ABIArg{.{ .slots = &callee_slots }};

    var src_locs = [_]ArgForwardingPlan.ArgLocation{
        .{ .reg = PReg.new(.int, 5) },
    };

    const plan = try planArgForwarding(
        allocator,
        &[_]ABIArg{}, // caller args (not used in simple case)
        &callee_args,
        &src_locs,
        null,
    );
    defer {
        var mut_plan = plan;
        mut_plan.deinit();
    }

    try testing.expectEqual(@as(usize, 1), plan.moves.items.len);
    try testing.expectEqual(PReg.new(.int, 0).index(), plan.moves.items[0].dst.reg.index());
}

test "planArgForwarding cycle uses scratch" {
    const allocator = testing.allocator;

    var callee_slots0 = [_]ABIArgSlot{.{
        .reg = .{
            .preg = PReg.new(.int, 0),
            .ty = .i64,
            .extension = .none,
        },
    }};
    var callee_slots1 = [_]ABIArgSlot{.{
        .reg = .{
            .preg = PReg.new(.int, 1),
            .ty = .i64,
            .extension = .none,
        },
    }};
    var callee_args = [_]ABIArg{ .{ .slots = &callee_slots0 }, .{ .slots = &callee_slots1 } };

    var src_locs = [_]ArgForwardingPlan.ArgLocation{
        .{ .reg = PReg.new(.int, 1) },
        .{ .reg = PReg.new(.int, 0) },
    };

    const plan = try planArgForwarding(
        allocator,
        &[_]ABIArg{},
        &callee_args,
        &src_locs,
        .{ .reg = PReg.new(.int, 2) },
    );
    defer {
        var mut_plan = plan;
        mut_plan.deinit();
    }

    try testing.expectEqual(@as(usize, 3), plan.moves.items.len);
    try testing.expectEqual(PReg.new(.int, 2).index(), plan.moves.items[0].dst.reg.index());
    try testing.expectEqual(PReg.new(.int, 0).index(), plan.moves.items[1].dst.reg.index());
    try testing.expectEqual(PReg.new(.int, 1).index(), plan.moves.items[2].dst.reg.index());
}

test "planArgForwarding stack args" {
    const allocator = testing.allocator;

    var callee_slots0 = [_]ABIArgSlot{.{
        .stack = .{
            .offset = 0,
            .ty = .i64,
            .extension = .none,
        },
    }};
    var callee_slots1 = [_]ABIArgSlot{.{
        .stack = .{
            .offset = 8,
            .ty = .i64,
            .extension = .none,
        },
    }};
    var callee_args = [_]ABIArg{ .{ .slots = &callee_slots0 }, .{ .slots = &callee_slots1 } };

    var caller_slots0 = [_]ABIArgSlot{.{
        .stack = .{
            .offset = 16,
            .ty = .i64,
            .extension = .none,
        },
    }};
    var caller_slots1 = [_]ABIArgSlot{.{
        .stack = .{
            .offset = 24,
            .ty = .i64,
            .extension = .none,
        },
    }};
    var caller_args = [_]ABIArg{ .{ .slots = &caller_slots0 }, .{ .slots = &caller_slots1 } };

    var src_locs = [_]ArgForwardingPlan.ArgLocation{
        .{ .stack = 16 },
        .{ .stack = 24 },
    };

    const plan = try planArgForwarding(
        allocator,
        &caller_args,
        &callee_args,
        &src_locs,
        null,
    );
    defer {
        var mut_plan = plan;
        mut_plan.deinit();
    }

    try testing.expectEqual(@as(usize, 2), plan.moves.items.len);
    try testing.expectEqual(@as(i64, 0), plan.moves.items[0].dst.stack);
    try testing.expectEqual(@as(i64, 8), plan.moves.items[1].dst.stack);
}
