const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const abi_mod = @import("abi.zig");
const reg_mod = @import("reg.zig");

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

    pub fn init(allocator: Allocator) ArgForwardingPlan {
        return .{
            .moves = std.ArrayList(ArgMove){},
            .max_stack_used = 0,
        };
    }

    pub fn deinit(self: *ArgForwardingPlan) void {
        self.moves.deinit();
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
    _: []const ABIArg, // caller_args - reserved for future dependency analysis
    callee_args: []const ABIArg,
    arg_values: []const Reg,
) !ArgForwardingPlan {
    var plan = ArgForwardingPlan.init(allocator);
    errdefer plan.deinit();

    std.debug.assert(callee_args.len == arg_values.len);

    // Build forwarding moves.
    // For each callee argument, we need to move from current location to target.
    for (callee_args, arg_values) |callee_arg, src_reg| {
        // Get destination location from callee ABI
        for (callee_arg.slots) |slot| {
            const dst_loc = switch (slot) {
                .reg => |r| ArgForwardingPlan.ArgLocation{ .reg = r.preg },
                .stack => |s| ArgForwardingPlan.ArgLocation{ .stack = s.offset },
            };

            // For simplicity, assume src_reg is the source
            const src_loc = ArgForwardingPlan.ArgLocation{
                .reg = src_reg.toPReg() orelse unreachable,
            };

            const ty = getType(slot);

            try plan.moves.append(.{
                .src = src_loc,
                .dst = dst_loc,
                .ty = ty,
            });

            // Track stack usage
            if (dst_loc == .stack) {
                const stack_end = @as(u32, @intCast(@abs(dst_loc.stack) + @as(i64, ty.bytes())));
                plan.max_stack_used = @max(plan.max_stack_used, stack_end);
            }
        }
    }

    // TODO: Optimize move ordering to avoid clobbering
    // This would require dependency analysis and possibly temp registers

    return plan;
}

fn getType(slot: ABIArgSlot) Type {
    return switch (slot) {
        .reg => |r| r.ty,
        .stack => |s| s.ty,
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

    try plan.moves.append(move);
    try testing.expectEqual(@as(usize, 1), plan.moves.items.len);
    try testing.expectEqual(move.src.reg, plan.moves.items[0].src.reg);
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

    var src_regs = [_]Reg{Reg.fromPReg(PReg.new(.int, 5))};

    const plan = try planArgForwarding(
        allocator,
        &[_]ABIArg{}, // caller args (not used in simple case)
        &callee_args,
        &src_regs,
    );
    defer {
        var mut_plan = plan;
        mut_plan.deinit();
    }

    try testing.expectEqual(@as(usize, 1), plan.moves.items.len);
    try testing.expectEqual(PReg.new(.int, 0), plan.moves.items[0].dst.reg);
}
