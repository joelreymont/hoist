const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const machinst = @import("machinst.zig");
const reg_mod = @import("reg.zig");
const lower_mod = @import("lower.zig");

pub const Reg = reg_mod.Reg;
pub const PReg = reg_mod.PReg;
pub const VReg = reg_mod.VReg;
pub const RegClass = reg_mod.RegClass;
pub const MachLabel = machinst.MachLabel;
pub const MachTerminator = machinst.MachTerminator;
pub const CallType = machinst.CallType;

// Forward-declare IR types used in backend interface
pub const Type = @import("../ir/types.zig").Type;
pub const Opcode = @import("../ir/opcodes.zig").Opcode;

/// Backend capabilities and feature flags.
pub const BackendFeatures = packed struct {
    /// Backend supports vector operations (SIMD).
    has_vector: bool = false,
    /// Backend supports floating-point operations.
    has_float: bool = false,
    /// Backend supports atomic operations.
    has_atomics: bool = false,
    /// Backend supports unaligned memory access.
    has_unaligned_access: bool = false,
    /// Backend supports hardware division.
    has_div: bool = false,
    /// Backend supports fused multiply-add.
    has_fma: bool = false,
    /// Backend supports saturating arithmetic.
    has_saturating_arithmetic: bool = false,
    /// Backend has dedicated condition code flags (vs. condition registers).
    has_condition_codes: bool = false,

    _padding: u56 = 0,
};

/// Calling convention support.
pub const CallingConvention = enum {
    /// System V ABI (Unix, Linux).
    system_v,
    /// Windows x64 calling convention.
    windows_fastcall,
    /// Apple ARM64 calling convention.
    apple_aarch64,
    /// Custom fast calling convention.
    fast,
    /// Cold path calling convention (fewer saved registers).
    cold,
    /// Tail call optimized convention.
    tail,
};

/// Register allocation hint for an instruction operand.
pub const RegHint = union(enum) {
    /// No preference - allocator decides.
    none,
    /// Prefer to use the same register as another operand.
    reuse_input: u32,
    /// Prefer a specific physical register.
    fixed: PReg,
    /// Avoid certain registers.
    avoid: []const PReg,
};

/// Backend-specific optimization level for lowering.
pub const OptLevel = enum {
    /// No optimizations - generate simple code.
    none,
    /// Basic optimizations - instruction selection improvements.
    speed,
    /// Optimize for size - prefer smaller encodings.
    size,
    /// Aggressive optimizations - may increase code size.
    speed_and_size,
};

/// Type support classification for backend.
pub const TypeSupport = enum {
    /// Type is fully supported with native instructions.
    native,
    /// Type is supported via expansion (e.g., i128 on 64-bit).
    expanded,
    /// Type is supported via library calls.
    libcall,
    /// Type is not supported at all.
    unsupported,
};

/// Operation support classification.
pub const OpSupport = enum {
    /// Operation is fully supported with native instructions.
    native,
    /// Operation requires expansion into multiple instructions.
    expanded,
    /// Operation requires a library call.
    libcall,
    /// Operation is not supported.
    unsupported,
};

/// Information about a register move instruction.
pub const MoveInfo = struct {
    dst: Reg,
    src: Reg,
};

/// Backend trait for machine instruction lowering.
/// Each target architecture (x64, aarch64, riscv64, etc.) implements this interface.
pub fn LoweringBackend(comptime MachInst: type) type {
    return struct {
        ptr: *anyopaque,
        vtable: *const VTable,

        const Self = @This();

        pub const VTable = struct {
            // Core lowering operations
            lowerInst: *const fn (
                *anyopaque,
                *lower_mod.LowerCtx(MachInst),
                lower_mod.Inst,
            ) anyerror!bool,

            lowerBranch: *const fn (
                *anyopaque,
                *lower_mod.LowerCtx(MachInst),
                lower_mod.Inst,
                []const MachLabel,
            ) anyerror!bool,

            // Capability queries
            supportsType: *const fn (*anyopaque, Type) TypeSupport,
            supportsOp: *const fn (*anyopaque, Opcode, Type) OpSupport,
            features: *const fn (*anyopaque) BackendFeatures,

            // Register allocation hints
            regHintForInst: *const fn (
                *anyopaque,
                *const MachInst,
                u32, // operand index
            ) RegHint,

            // Calling convention support
            supportsCallingConvention: *const fn (*anyopaque, CallingConvention) bool,

            // Type mapping
            typeToRegClass: *const fn (*anyopaque, Type) ?RegClass,
            typeToRegClasses: *const fn (
                *anyopaque,
                Type,
                []RegClass,
            ) usize, // returns number of classes written

            // Optimization support
            preferredOptLevel: *const fn (*anyopaque) OptLevel,
            canFuseOps: *const fn (
                *anyopaque,
                Opcode, // first op
                Opcode, // second op
            ) bool,

            // Machine properties
            nativePointerType: *const fn (*anyopaque) Type,
            nativeIntType: *const fn (*anyopaque) Type,
            maxVectorLanes: *const fn (*anyopaque, Type) ?u32,

            // Instruction properties (for regalloc)
            instClobbers: *const fn (
                *anyopaque,
                *const MachInst,
                []PReg, // output buffer
            ) usize, // returns number of clobbers written

            isMove: *const fn (*anyopaque, *const MachInst) ?MoveInfo,

            isTerm: *const fn (*anyopaque, *const MachInst) MachTerminator,
            callType: *const fn (*anyopaque, *const MachInst) CallType,
        };

        /// Lower a single IR instruction to machine instructions.
        pub fn lowerInst(
            self: Self,
            ctx: *lower_mod.LowerCtx(MachInst),
            inst: lower_mod.Inst,
        ) !bool {
            return self.vtable.lowerInst(self.ptr, ctx, inst);
        }

        /// Lower a branch instruction with given target labels.
        pub fn lowerBranch(
            self: Self,
            ctx: *lower_mod.LowerCtx(MachInst),
            inst: lower_mod.Inst,
            targets: []const MachLabel,
        ) !bool {
            return self.vtable.lowerBranch(self.ptr, ctx, inst, targets);
        }

        /// Query if backend supports a given type.
        pub fn supportsType(self: Self, ty: Type) TypeSupport {
            return self.vtable.supportsType(self.ptr, ty);
        }

        /// Query if backend supports an operation on a given type.
        pub fn supportsOp(self: Self, op: Opcode, ty: Type) OpSupport {
            return self.vtable.supportsOp(self.ptr, op, ty);
        }

        /// Get backend feature flags.
        pub fn features(self: Self) BackendFeatures {
            return self.vtable.features(self.ptr);
        }

        /// Get register allocation hint for an instruction operand.
        pub fn regHintForInst(self: Self, inst: *const MachInst, operand_idx: u32) RegHint {
            return self.vtable.regHintForInst(self.ptr, inst, operand_idx);
        }

        /// Check if backend supports a calling convention.
        pub fn supportsCallingConvention(self: Self, cc: CallingConvention) bool {
            return self.vtable.supportsCallingConvention(self.ptr, cc);
        }

        /// Map IR type to register class (single-register types).
        pub fn typeToRegClass(self: Self, ty: Type) ?RegClass {
            return self.vtable.typeToRegClass(self.ptr, ty);
        }

        /// Map IR type to register classes (may use multiple registers).
        /// Returns the number of register classes written to the output buffer.
        pub fn typeToRegClasses(self: Self, ty: Type, out: []RegClass) usize {
            return self.vtable.typeToRegClasses(self.ptr, ty, out);
        }

        /// Get the preferred optimization level for this backend.
        pub fn preferredOptLevel(self: Self) OptLevel {
            return self.vtable.preferredOptLevel(self.ptr);
        }

        /// Check if two operations can be fused (e.g., multiply-add).
        pub fn canFuseOps(self: Self, op1: Opcode, op2: Opcode) bool {
            return self.vtable.canFuseOps(self.ptr, op1, op2);
        }

        /// Get the native pointer type for this backend.
        pub fn nativePointerType(self: Self) Type {
            return self.vtable.nativePointerType(self.ptr);
        }

        /// Get the native integer type for this backend (register width).
        pub fn nativeIntType(self: Self) Type {
            return self.vtable.nativeIntType(self.ptr);
        }

        /// Get maximum vector lanes supported for a given element type.
        pub fn maxVectorLanes(self: Self, elem_ty: Type) ?u32 {
            return self.vtable.maxVectorLanes(self.ptr, elem_ty);
        }

        /// Get the physical registers clobbered by an instruction.
        /// Returns the number of clobbers written to the output buffer.
        pub fn instClobbers(self: Self, inst: *const MachInst, out: []PReg) usize {
            return self.vtable.instClobbers(self.ptr, inst, out);
        }

        /// Check if instruction is a simple register move.
        pub fn isMove(self: Self, inst: *const MachInst) ?MoveInfo {
            return self.vtable.isMove(self.ptr, inst);
        }

        /// Check if instruction is a terminator and what kind.
        pub fn isTerm(self: Self, inst: *const MachInst) MachTerminator {
            return self.vtable.isTerm(self.ptr, inst);
        }

        /// Get the call type classification for an instruction.
        pub fn callType(self: Self, inst: *const MachInst) CallType {
            return self.vtable.callType(self.ptr, inst);
        }
    };
}

/// Helper to create a backend trait from a concrete implementation type.
pub fn backend(comptime MachInst: type, comptime Impl: type, impl: *Impl) LoweringBackend(MachInst) {
    const gen = struct {
        fn lowerInst(
            ptr: *anyopaque,
            ctx: *lower_mod.LowerCtx(MachInst),
            inst: lower_mod.Inst,
        ) anyerror!bool {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.lowerInst(ctx, inst);
        }

        fn lowerBranch(
            ptr: *anyopaque,
            ctx: *lower_mod.LowerCtx(MachInst),
            inst: lower_mod.Inst,
            targets: []const MachLabel,
        ) anyerror!bool {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.lowerBranch(ctx, inst, targets);
        }

        fn supportsType(ptr: *anyopaque, ty: Type) TypeSupport {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.supportsType(ty);
        }

        fn supportsOp(ptr: *anyopaque, op: Opcode, ty: Type) OpSupport {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.supportsOp(op, ty);
        }

        fn features(ptr: *anyopaque) BackendFeatures {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.features();
        }

        fn regHintForInst(ptr: *anyopaque, inst: *const MachInst, operand_idx: u32) RegHint {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.regHintForInst(inst, operand_idx);
        }

        fn supportsCallingConvention(ptr: *anyopaque, cc: CallingConvention) bool {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.supportsCallingConvention(cc);
        }

        fn typeToRegClass(ptr: *anyopaque, ty: Type) ?RegClass {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.typeToRegClass(ty);
        }

        fn typeToRegClasses(ptr: *anyopaque, ty: Type, out: []RegClass) usize {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.typeToRegClasses(ty, out);
        }

        fn preferredOptLevel(ptr: *anyopaque) OptLevel {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.preferredOptLevel();
        }

        fn canFuseOps(ptr: *anyopaque, op1: Opcode, op2: Opcode) bool {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.canFuseOps(op1, op2);
        }

        fn nativePointerType(ptr: *anyopaque) Type {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.nativePointerType();
        }

        fn nativeIntType(ptr: *anyopaque) Type {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.nativeIntType();
        }

        fn maxVectorLanes(ptr: *anyopaque, elem_ty: Type) ?u32 {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.maxVectorLanes(elem_ty);
        }

        fn instClobbers(ptr: *anyopaque, inst: *const MachInst, out: []PReg) usize {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.instClobbers(inst, out);
        }

        fn isMove(ptr: *anyopaque, inst: *const MachInst) ?struct { dst: Reg, src: Reg } {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.isMove(inst);
        }

        fn isTerm(ptr: *anyopaque, inst: *const MachInst) MachTerminator {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.isTerm(inst);
        }

        fn callType(ptr: *anyopaque, inst: *const MachInst) CallType {
            const self: *Impl = @ptrCast(@alignCast(ptr));
            return self.callType(inst);
        }

        const vtable = LoweringBackend(MachInst).VTable{
            .lowerInst = lowerInst,
            .lowerBranch = lowerBranch,
            .supportsType = supportsType,
            .supportsOp = supportsOp,
            .features = features,
            .regHintForInst = regHintForInst,
            .supportsCallingConvention = supportsCallingConvention,
            .typeToRegClass = typeToRegClass,
            .typeToRegClasses = typeToRegClasses,
            .preferredOptLevel = preferredOptLevel,
            .canFuseOps = canFuseOps,
            .nativePointerType = nativePointerType,
            .nativeIntType = nativeIntType,
            .maxVectorLanes = maxVectorLanes,
            .instClobbers = instClobbers,
            .isMove = isMove,
            .isTerm = isTerm,
            .callType = callType,
        };
    };

    return .{
        .ptr = impl,
        .vtable = &gen.vtable,
    };
}

// Tests

test "BackendFeatures packing" {
    const features = BackendFeatures{
        .has_vector = true,
        .has_float = true,
        .has_div = true,
    };

    try testing.expect(features.has_vector);
    try testing.expect(features.has_float);
    try testing.expect(features.has_div);
    try testing.expect(!features.has_atomics);
}

test "backend trait creation" {
    const TestInst = struct {
        opcode: u8,
    };

    const TestBackend = struct {
        opt_level: OptLevel,

        pub fn lowerInst(
            _: *@This(),
            _: *lower_mod.LowerCtx(TestInst),
            _: lower_mod.Inst,
        ) !bool {
            return false;
        }

        pub fn lowerBranch(
            _: *@This(),
            _: *lower_mod.LowerCtx(TestInst),
            _: lower_mod.Inst,
            _: []const MachLabel,
        ) !bool {
            return false;
        }

        pub fn supportsType(_: *@This(), ty: Type) TypeSupport {
            return if (ty.eql(Type.I32) or ty.eql(Type.I64))
                .native
            else
                .unsupported;
        }

        pub fn supportsOp(_: *@This(), _: Opcode, _: Type) OpSupport {
            return .native;
        }

        pub fn features(_: *@This()) BackendFeatures {
            return .{
                .has_float = true,
                .has_div = true,
            };
        }

        pub fn regHintForInst(_: *@This(), _: *const TestInst, _: u32) RegHint {
            return .none;
        }

        pub fn supportsCallingConvention(_: *@This(), cc: CallingConvention) bool {
            return cc == .system_v;
        }

        pub fn typeToRegClass(_: *@This(), ty: Type) ?RegClass {
            if (ty.eql(Type.I32) or ty.eql(Type.I64)) return .int;
            if (ty.eql(Type.F32) or ty.eql(Type.F64)) return .float;
            return null;
        }

        pub fn typeToRegClasses(_: *@This(), ty: Type, out: []RegClass) usize {
            if (ty.eql(Type.I32) or ty.eql(Type.I64)) {
                out[0] = .int;
                return 1;
            }
            return 0;
        }

        pub fn preferredOptLevel(self: *@This()) OptLevel {
            return self.opt_level;
        }

        pub fn canFuseOps(_: *@This(), _: Opcode, _: Opcode) bool {
            return false;
        }

        pub fn nativePointerType(_: *@This()) Type {
            return Type.I64;
        }

        pub fn nativeIntType(_: *@This()) Type {
            return Type.I64;
        }

        pub fn maxVectorLanes(_: *@This(), _: Type) ?u32 {
            return 16;
        }

        pub fn instClobbers(_: *@This(), _: *const TestInst, _: []PReg) usize {
            return 0;
        }

        pub fn isMove(_: *@This(), _: *const TestInst) ?MoveInfo {
            return null;
        }

        pub fn isTerm(_: *@This(), _: *const TestInst) MachTerminator {
            return .none;
        }

        pub fn callType(_: *@This(), _: *const TestInst) CallType {
            return .none;
        }
    };

    var impl = TestBackend{ .opt_level = .speed };
    const be = backend(TestInst, TestBackend, &impl);

    // Test capability queries
    try testing.expectEqual(TypeSupport.native, be.supportsType(Type.I32));
    try testing.expectEqual(TypeSupport.unsupported, be.supportsType(Type.F32));

    const feats = be.features();
    try testing.expect(feats.has_float);
    try testing.expect(feats.has_div);
    try testing.expect(!feats.has_vector);

    // Test calling convention
    try testing.expect(be.supportsCallingConvention(.system_v));
    try testing.expect(!be.supportsCallingConvention(.windows_fastcall));

    // Test type mapping
    try testing.expectEqual(RegClass.int, be.typeToRegClass(Type.I32).?);
    try testing.expectEqual(RegClass.float, be.typeToRegClass(Type.F32).?);

    var classes: [2]RegClass = undefined;
    const count = be.typeToRegClasses(Type.I64, &classes);
    try testing.expectEqual(@as(usize, 1), count);
    try testing.expectEqual(RegClass.int, classes[0]);

    // Test optimization
    try testing.expectEqual(OptLevel.speed, be.preferredOptLevel());

    // Test native types
    try testing.expect(be.nativePointerType().eql(Type.I64));
    try testing.expect(be.nativeIntType().eql(Type.I64));

    // Test vector support
    try testing.expectEqual(@as(u32, 16), be.maxVectorLanes(Type.I32).?);
}

test "RegHint variants" {
    const hint_none = RegHint.none;
    const hint_reuse = RegHint{ .reuse_input = 0 };
    const hint_fixed = RegHint{ .fixed = PReg.new(.int, 5) };

    try testing.expect(hint_none == .none);
    try testing.expect(hint_reuse == .reuse_input);
    try testing.expect(hint_fixed == .fixed);
}
