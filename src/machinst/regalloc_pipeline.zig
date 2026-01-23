//! Register allocation pipeline entry point.
//!
//! This module provides the main entry point for register allocation,
//! coordinating liveness analysis and register allocation algorithms.

const std = @import("std");
const Allocator = std.mem.Allocator;

const regalloc = @import("../regalloc/regalloc.zig");
const liveness_mod = @import("../regalloc/liveness.zig");
const linear_scan_mod = @import("../regalloc/linear_scan.zig");
const machinst = @import("machinst.zig");
const regalloc2_liveness = @import("regalloc2/liveness.zig");
const regalloc2_api = @import("regalloc2/api.zig");

const LivenessInfo = liveness_mod.LivenessInfo;
const LinearScanAllocator = linear_scan_mod.LinearScanAllocator;
const RegAllocResult = linear_scan_mod.RegAllocResult;
const SpillSlot = linear_scan_mod.SpillSlot;

/// Register allocation pipeline configuration.
pub const RegAllocConfig = struct {
    /// Number of general-purpose integer registers available.
    /// For AArch64: typically 31 (X0-X30, excluding XZR/SP).
    num_int_regs: u32 = 31,

    /// Number of floating-point/SIMD registers available.
    /// For AArch64: 32 (V0-V31).
    num_float_regs: u32 = 32,

    /// Number of vector registers available.
    /// For AArch64: same as float (V0-V31).
    num_vector_regs: u32 = 32,
};

/// Result of the register allocation pipeline.
pub const PipelineResult = struct {
    /// Register allocation result (vreg → preg and spill slot mappings).
    regalloc_result: RegAllocResult,

    /// Total frame size required for spilled registers (in bytes).
    frame_size: u32,

    pub fn deinit(self: *PipelineResult) void {
        self.regalloc_result.deinit();
    }
};

/// Run the complete register allocation pipeline.
///
/// This function performs:
/// 1. Liveness analysis (already computed, passed in)
/// 2. Linear scan register allocation
/// 3. Frame size calculation
///
/// Returns a PipelineResult containing register assignments and frame size.
pub fn runRegisterAllocation(
    allocator: Allocator,
    liveness_info: *LivenessInfo,
    config: RegAllocConfig,
) !PipelineResult {
    // Initialize linear scan allocator
    var allocator_state = try LinearScanAllocator.init(
        allocator,
        config.num_int_regs,
        config.num_float_regs,
        config.num_vector_regs,
    );
    defer allocator_state.deinit();

    // Run register allocation
    const regalloc_result = try allocator_state.allocate(liveness_info);

    // Calculate total frame size needed for spills
    var max_spill_offset: u32 = 0;
    var spill_iter = regalloc_result.vreg_to_spill.valueIterator();
    while (spill_iter.next()) |spill_slot| {
        const slot_end = spill_slot.offset + 8; // Assume 8-byte slots
        if (slot_end > max_spill_offset) {
            max_spill_offset = slot_end;
        }
    }

    // Align frame size to 16 bytes (AArch64 stack alignment requirement)
    const frame_size = (max_spill_offset + 15) & ~@as(u32, 15);

    return PipelineResult{
        .regalloc_result = regalloc_result,
        .frame_size = frame_size,
    };
}

// Tests

const testing = std.testing;

test "runRegisterAllocation with empty liveness" {
    var liveness_info = LivenessInfo.init(testing.allocator);
    defer liveness_info.deinit();

    const config = RegAllocConfig{};
    var result = try runRegisterAllocation(testing.allocator, &liveness_info, config);
    defer result.deinit();

    // No spills, frame size should be 0
    try testing.expectEqual(@as(u32, 0), result.frame_size);
}

test "runRegisterAllocation with single vreg" {
    var liveness_info = LivenessInfo.init(testing.allocator);
    defer liveness_info.deinit();

    // Add a single live range for vreg 0
    const vreg = machinst.VReg.new(0);
    try liveness_info.addRange(.{
        .vreg = vreg,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .int,
    });

    const config = RegAllocConfig{};
    var result = try runRegisterAllocation(testing.allocator, &liveness_info, config);
    defer result.deinit();

    // Single vreg should get a physical register, no spills
    const maybe_preg = result.regalloc_result.getPhysReg(vreg);
    try testing.expect(maybe_preg != null);
    try testing.expectEqual(@as(u32, 0), result.frame_size);
}

test "runRegisterAllocation frame size alignment" {
    var liveness_info = LivenessInfo.init(testing.allocator);
    defer liveness_info.deinit();

    // Create enough live ranges to force spilling
    // With 31 int registers, 32+ vregs will cause spills
    var i: u32 = 0;
    while (i < 35) : (i += 1) {
        try liveness_info.addRange(.{
            .vreg = machinst.VReg.new(i),
            .start_inst = 0,
            .end_inst = 100, // All overlap
            .reg_class = .int,
        });
    }

    const config = RegAllocConfig{};
    var result = try runRegisterAllocation(testing.allocator, &liveness_info, config);
    defer result.deinit();

    // Should have spills, frame size should be 16-byte aligned
    try testing.expect(result.frame_size > 0);
    try testing.expectEqual(@as(u32, 0), result.frame_size % 16);
}
