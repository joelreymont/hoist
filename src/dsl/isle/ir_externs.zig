const root = @import("../../root.zig");

const InstructionData = root.instruction_data.InstructionData;
const IntCC = root.condcodes.IntCC;
const FloatCC = root.condcodes.FloatCC;
const MemFlags = root.memflags.MemFlags;
const Offset32 = root.immediates.Offset32;
const Ieee32 = root.immediates.Ieee32;
const Ieee64 = root.immediates.Ieee64;
const Opcode = root.opcodes.Opcode;
const Type = root.types.Type;
const Value = root.entities.Value;
const Inst = root.entities.Inst;
const Block = root.entities.Block;
const GlobalValue = root.entities.GlobalValue;
const JumpTable = root.entities.JumpTable;
const StackSlot = root.entities.StackSlot;
const AtomicOrdering = root.atomics.AtomicOrdering;
const AtomicRmwOp = root.atomics.AtomicRmwOp;
const ExternalName = root.extfunc.ExternalName;
const SymbolValueData = root.extfunc.SymbolValueData;
const FuncRefData = root.extfunc.FuncRefData;
const RelocDistance = root.extfunc.RelocDistance;
const SigRef = root.entities.SigRef;
const TrapCode = root.trapcode.TrapCode;

pub fn Externs(comptime Ctx: type) type {
    return struct {
        const has_lower = @hasField(Ctx, "lower_ctx");

        const Lc = if (has_lower)
            @TypeOf(@field(@as(Ctx, undefined), "lower_ctx"))
        else
            *Ctx;

        fn lc(ctx: *Ctx) Lc {
            if (has_lower) {
                return ctx.lower_ctx;
            } else {
                return ctx;
            }
        }

        const Bin = struct { arg0: Type, arg1: Value, arg2: Value };

        fn valTy(ctx: *Ctx, v: Value) ?Type {
            const l = lc(ctx);
            return l.func.dfg.valueType(v);
        }

        fn valInst(ctx: *Ctx, v: Value) ?Inst {
            const l = lc(ctx);
            const def = l.func.dfg.valueDef(v) orelse return null;
            return def.inst();
        }

        fn instData(ctx: *Ctx, inst: Inst) ?*const InstructionData {
            const l = lc(ctx);
            return l.func.dfg.insts.get(inst);
        }

        pub fn has_type_ext(ctx: *Ctx, input: Value) !?struct { arg0: Type, arg1: Value } {
            const ty = valTy(ctx, input) orelse return null;
            return .{ .arg0 = ty, .arg1 = input };
        }

        pub fn ty_vec_fits_in_register_ext(_: *Ctx, input: Type) !?Type {
            if (input.isVector() and input.bytes() <= 16) return input;
            return null;
        }

        pub fn ty_32_or_64_ext(_: *Ctx, input: Type) !?Type {
            if (input.eql(Type.I32) or input.eql(Type.I64)) return input;
            return null;
        }

        fn funcRefData(ctx: *Ctx, func_ref: root.entities.FuncRef) ?FuncRefData {
            const l = lc(ctx);
            const meta = l.func.func_metadata.getMetadata(func_ref) orelse return null;
            // TODO: plumb relocation distance/offset hints through FuncMetadata.
            return FuncRefData.init(meta.sig_ref, meta.name, .Far, 0);
        }

        fn binExt(
            ctx: *Ctx,
            input: Value,
            op: Opcode,
        ) ?Bin {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .binary => |b| {
                    if (b.opcode != op) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = b.args[0], .arg2 = b.args[1] };
                },
                else => return null,
            }
        }

        const BinImmI = struct { arg0: Type, arg1: Value, arg2: i64 };

        fn binImmIExt(ctx: *Ctx, input: Value, op: Opcode) ?BinImmI {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .binary_imm64 => |b| {
                    if (b.opcode != op) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = b.arg, .arg2 = b.imm.value };
                },
                else => return null,
            }
        }

        const BinImmU = struct { arg0: Type, arg1: Value, arg2: u64 };

        fn binImmBitsExt(ctx: *Ctx, input: Value, op: Opcode) ?BinImmU {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .binary_imm64 => |b| {
                    if (b.opcode != op) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    const imm_bits: u64 = @bitCast(b.imm.value);
                    return .{ .arg0 = ty, .arg1 = b.arg, .arg2 = imm_bits };
                },
                else => return null,
            }
        }

        fn binImmUExt(ctx: *Ctx, input: Value, op: Opcode) ?BinImmU {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .binary_imm64 => |b| {
                    if (b.opcode != op) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    const imm = b.imm.value;
                    if (imm < 0) return null;
                    const imm_u: u64 = @intCast(imm);
                    return .{ .arg0 = ty, .arg1 = b.arg, .arg2 = imm_u };
                },
                else => return null,
            }
        }

        const Tern = struct { arg0: Type, arg1: Value, arg2: Value, arg3: Value };

        fn ternExt(ctx: *Ctx, input: Value, op: Opcode) ?Tern {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .ternary => |t| {
                    if (t.opcode != op) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = t.args[0], .arg2 = t.args[1], .arg3 = t.args[2] };
                },
                else => return null,
            }
        }

        const Un = struct { arg0: Type, arg1: Value };

        fn unExt(ctx: *Ctx, input: Value, op: Opcode) ?Un {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != op) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = u.arg };
                },
                else => return null,
            }
        }

        const Conv = struct { arg0: Type, arg1: Type, arg2: Value };

        fn convExt(ctx: *Ctx, input: Value, op: Opcode) ?Conv {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != op) return null;
                    const dst_ty = valTy(ctx, input) orelse return null;
                    const src_ty = valTy(ctx, u.arg) orelse return null;
                    return .{ .arg0 = dst_ty, .arg1 = src_ty, .arg2 = u.arg };
                },
                else => return null,
            }
        }

        const BinV = struct { arg0: Value, arg1: Value };

        fn binVExt(ctx: *Ctx, input: Value, op: Opcode) ?BinV {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .binary => |b| {
                    if (b.opcode != op) return null;
                    return .{ .arg0 = b.args[0], .arg1 = b.args[1] };
                },
                else => return null,
            }
        }

        const TernV = struct { arg0: Value, arg1: Value, arg2: Value };

        fn ternVExt(ctx: *Ctx, input: Value, op: Opcode) ?TernV {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .ternary => |t| {
                    if (t.opcode != op) return null;
                    return .{ .arg0 = t.args[0], .arg1 = t.args[1], .arg2 = t.args[2] };
                },
                else => return null,
            }
        }

        const BinTrap = struct { arg0: Value, arg1: Value, arg2: TrapCode };

        fn binTrapExt(ctx: *Ctx, input: Value, op: Opcode) ?BinTrap {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .ternary_imm8 => |t| {
                    if (t.opcode != op) return null;
                    return .{
                        .arg0 = t.args[0],
                        .arg1 = t.args[1],
                        .arg2 = @enumFromInt(t.imm),
                    };
                },
                else => return null,
            }
        }

        pub fn iadd_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .iadd);
        }

        pub fn isub_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .isub);
        }

        pub fn imul_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .imul);
        }

        pub fn umul_hi_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .umulhi);
        }

        pub fn smul_hi_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .smulhi);
        }

        pub fn umulhi_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const v = binVExt(ctx, input, .umulhi) orelse return null;
            return .{ .arg0 = v.arg0, .arg1 = v.arg1 };
        }

        pub fn smulhi_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const v = binVExt(ctx, input, .smulhi) orelse return null;
            return .{ .arg0 = v.arg0, .arg1 = v.arg1 };
        }

        pub fn uadd_sat_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const v = binVExt(ctx, input, .uadd_sat) orelse return null;
            return .{ .arg0 = v.arg0, .arg1 = v.arg1 };
        }

        pub fn sadd_sat_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const v = binVExt(ctx, input, .sadd_sat) orelse return null;
            return .{ .arg0 = v.arg0, .arg1 = v.arg1 };
        }

        pub fn usub_sat_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const v = binVExt(ctx, input, .usub_sat) orelse return null;
            return .{ .arg0 = v.arg0, .arg1 = v.arg1 };
        }

        pub fn ssub_sat_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const v = binVExt(ctx, input, .ssub_sat) orelse return null;
            return .{ .arg0 = v.arg0, .arg1 = v.arg1 };
        }

        pub fn sqmul_round_sat_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .sqmul_round_sat);
        }

        pub fn sdiv_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .sdiv);
        }

        pub fn udiv_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .udiv);
        }

        pub fn srem_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .srem);
        }

        pub fn urem_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .urem);
        }

        pub fn smin_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .smin);
        }

        pub fn smax_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .smax);
        }

        pub fn imin_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const v = binVExt(ctx, input, .smin) orelse return null;
            return .{ .arg0 = v.arg0, .arg1 = v.arg1 };
        }

        pub fn imax_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const v = binVExt(ctx, input, .smax) orelse return null;
            return .{ .arg0 = v.arg0, .arg1 = v.arg1 };
        }

        pub fn umin_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .umin);
        }

        pub fn umax_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .umax);
        }

        pub fn avg_round_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const v = binVExt(ctx, input, .avg_round) orelse return null;
            return .{ .arg0 = v.arg0, .arg1 = v.arg1 };
        }

        pub fn reduce_add_ext(_: *Ctx, _: Value) !?struct { arg0: Value } {
            // No IR opcode yet; keep patterns non-fatal during matching.
            return null;
        }

        pub fn reduce_smin_ext(_: *Ctx, _: Value) !?struct { arg0: Value } {
            // No IR opcode yet; keep patterns non-fatal during matching.
            return null;
        }

        pub fn reduce_smax_ext(_: *Ctx, _: Value) !?struct { arg0: Value } {
            // No IR opcode yet; keep patterns non-fatal during matching.
            return null;
        }

        pub fn reduce_umin_ext(_: *Ctx, _: Value) !?struct { arg0: Value } {
            // No IR opcode yet; keep patterns non-fatal during matching.
            return null;
        }

        pub fn reduce_umax_ext(_: *Ctx, _: Value) !?struct { arg0: Value } {
            // No IR opcode yet; keep patterns non-fatal during matching.
            return null;
        }

        pub fn band_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .band);
        }

        pub fn bor_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .bor);
        }

        pub fn bxor_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .bxor);
        }

        pub fn band_not_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .band_not);
        }

        pub fn bor_not_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .bor_not);
        }

        pub fn bxor_not_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .bxor_not);
        }

        pub fn ishl_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .ishl);
        }

        pub fn ushr_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .ushr);
        }

        pub fn sshr_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .sshr);
        }

        pub fn rotl_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .rotl);
        }

        pub fn rotr_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .rotr);
        }

        pub fn ineg_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .ineg);
        }

        pub fn iabs_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .iabs);
        }

        pub fn bnot_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .bnot);
        }

        pub fn bitrev_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .bitrev);
        }

        pub fn clz_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .clz);
        }

        pub fn cls_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .cls);
        }

        pub fn ctz_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .ctz);
        }

        pub fn bswap_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .bswap);
        }

        pub fn popcnt_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .popcnt);
        }

        pub fn select_ext(ctx: *Ctx, input: Value) !?Tern {
            return ternExt(ctx, input, .select);
        }

        pub fn select_spectre_guard_ext(ctx: *Ctx, input: Value) !?Tern {
            return ternExt(ctx, input, .select_spectre_guard);
        }

        pub fn bitselect_ext(ctx: *Ctx, input: Value) !?Tern {
            return ternExt(ctx, input, .bitselect);
        }

        pub fn iadd_imm_ext(ctx: *Ctx, input: Value) !?BinImmI {
            return binImmIExt(ctx, input, .iadd_imm);
        }

        pub fn imul_imm_ext(ctx: *Ctx, input: Value) !?BinImmI {
            return binImmIExt(ctx, input, .imul_imm);
        }

        pub fn udiv_imm_ext(ctx: *Ctx, input: Value) !?BinImmI {
            return binImmIExt(ctx, input, .udiv_imm);
        }

        pub fn sdiv_imm_ext(ctx: *Ctx, input: Value) !?BinImmI {
            return binImmIExt(ctx, input, .sdiv_imm);
        }

        pub fn urem_imm_ext(ctx: *Ctx, input: Value) !?BinImmI {
            return binImmIExt(ctx, input, .urem_imm);
        }

        pub fn srem_imm_ext(ctx: *Ctx, input: Value) !?BinImmI {
            return binImmIExt(ctx, input, .srem_imm);
        }

        pub fn irsub_imm_ext(ctx: *Ctx, input: Value) !?BinImmI {
            return binImmIExt(ctx, input, .irsub_imm);
        }

        pub fn band_imm_ext(ctx: *Ctx, input: Value) !?BinImmU {
            return binImmBitsExt(ctx, input, .band_imm);
        }

        pub fn bor_imm_ext(ctx: *Ctx, input: Value) !?BinImmU {
            return binImmBitsExt(ctx, input, .bor_imm);
        }

        pub fn bxor_imm_ext(ctx: *Ctx, input: Value) !?BinImmU {
            return binImmBitsExt(ctx, input, .bxor_imm);
        }

        pub fn ishl_imm_ext(ctx: *Ctx, input: Value) !?BinImmU {
            return binImmUExt(ctx, input, .ishl_imm);
        }

        pub fn ushr_imm_ext(ctx: *Ctx, input: Value) !?BinImmU {
            return binImmUExt(ctx, input, .ushr_imm);
        }

        pub fn sshr_imm_ext(ctx: *Ctx, input: Value) !?BinImmU {
            return binImmUExt(ctx, input, .sshr_imm);
        }

        pub fn rotl_imm_ext(ctx: *Ctx, input: Value) !?BinImmU {
            return binImmUExt(ctx, input, .rotl_imm);
        }

        pub fn rotr_imm_ext(ctx: *Ctx, input: Value) !?BinImmU {
            return binImmUExt(ctx, input, .rotr_imm);
        }

        pub fn uadd_overflow_ext(ctx: *Ctx, input: Value) !?BinV {
            return binVExt(ctx, input, .uadd_overflow);
        }

        pub fn sadd_overflow_ext(ctx: *Ctx, input: Value) !?BinV {
            return binVExt(ctx, input, .sadd_overflow);
        }

        pub fn usub_overflow_ext(ctx: *Ctx, input: Value) !?BinV {
            return binVExt(ctx, input, .usub_overflow);
        }

        pub fn ssub_overflow_ext(ctx: *Ctx, input: Value) !?BinV {
            return binVExt(ctx, input, .ssub_overflow);
        }

        pub fn umul_overflow_ext(ctx: *Ctx, input: Value) !?BinV {
            return binVExt(ctx, input, .umul_overflow);
        }

        pub fn smul_overflow_ext(ctx: *Ctx, input: Value) !?BinV {
            return binVExt(ctx, input, .smul_overflow);
        }

        pub fn uadd_overflow_cin_ext(ctx: *Ctx, input: Value) !?TernV {
            return ternVExt(ctx, input, .uadd_overflow_cin);
        }

        pub fn sadd_overflow_cin_ext(ctx: *Ctx, input: Value) !?TernV {
            return ternVExt(ctx, input, .sadd_overflow_cin);
        }

        pub fn uadd_overflow_trap_ext(ctx: *Ctx, input: Value) !?BinTrap {
            return binTrapExt(ctx, input, .uadd_overflow_trap);
        }

        pub fn usub_overflow_trap_ext(ctx: *Ctx, input: Value) !?BinTrap {
            return binTrapExt(ctx, input, .usub_overflow_trap);
        }

        pub fn umul_overflow_trap_ext(ctx: *Ctx, input: Value) !?BinTrap {
            return binTrapExt(ctx, input, .umul_overflow_trap);
        }

        pub fn sadd_overflow_trap_ext(ctx: *Ctx, input: Value) !?BinTrap {
            return binTrapExt(ctx, input, .sadd_overflow_trap);
        }

        pub fn ssub_overflow_trap_ext(ctx: *Ctx, input: Value) !?BinTrap {
            return binTrapExt(ctx, input, .ssub_overflow_trap);
        }

        pub fn smul_overflow_trap_ext(ctx: *Ctx, input: Value) !?BinTrap {
            return binTrapExt(ctx, input, .smul_overflow_trap);
        }

        pub fn fadd_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .fadd);
        }

        pub fn fsub_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .fsub);
        }

        pub fn fmul_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .fmul);
        }

        pub fn fdiv_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .fdiv);
        }

        pub fn fmin_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .fmin);
        }

        pub fn fmax_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .fmax);
        }

        pub fn fma_ext(ctx: *Ctx, input: Value) !?Tern {
            return ternExt(ctx, input, .fma);
        }

        pub fn fneg_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .fneg);
        }

        pub fn fabs_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .fabs);
        }

        pub fn fcopysign_ext(ctx: *Ctx, input: Value) !?Bin {
            return binExt(ctx, input, .fcopysign);
        }

        pub fn nearest_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .nearest);
        }

        pub fn trunc_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .trunc);
        }

        pub fn ceil_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .ceil);
        }

        pub fn floor_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .floor);
        }

        pub fn sqrt_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .sqrt);
        }

        pub fn fsqrt_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .sqrt);
        }

        pub fn splat_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .splat);
        }

        pub fn extractlane_ext(ctx: *Ctx, input: Value) !?struct { arg0: Type, arg1: Value, arg2: u32 } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .extract_lane => |ex| {
                    if (ex.opcode != .extractlane) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = ex.arg, .arg2 = @as(u32, ex.lane) };
                },
                else => return null,
            }
        }

        pub fn insertlane_ext(ctx: *Ctx, input: Value) !?struct { arg0: Type, arg1: Value, arg2: Value, arg3: u32 } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .ternary_imm8 => |t| {
                    if (t.opcode != .insertlane) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = t.args[0], .arg2 = t.args[1], .arg3 = @as(u32, t.imm) };
                },
                else => return null,
            }
        }

        pub fn fdemote_ext(ctx: *Ctx, input: Value) !?Conv {
            return convExt(ctx, input, .fdemote);
        }

        pub fn fpromote_ext(ctx: *Ctx, input: Value) !?Conv {
            return convExt(ctx, input, .fpromote);
        }

        pub fn fvpromote_low_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .fvpromote_low) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn fvdemote_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .fvdemote) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn fcvt_from_sint_ext(ctx: *Ctx, input: Value) !?Conv {
            return convExt(ctx, input, .fcvt_from_sint);
        }

        pub fn fcvt_from_uint_ext(ctx: *Ctx, input: Value) !?Conv {
            return convExt(ctx, input, .fcvt_from_uint);
        }

        pub fn fcvt_to_sint_ext(ctx: *Ctx, input: Value) !?Conv {
            return convExt(ctx, input, .fcvt_to_sint);
        }

        pub fn fcvt_to_uint_ext(ctx: *Ctx, input: Value) !?Conv {
            return convExt(ctx, input, .fcvt_to_uint);
        }

        pub fn sextend_ext(ctx: *Ctx, input: Value) !?Conv {
            return convExt(ctx, input, .sextend);
        }

        pub fn uextend_ext(ctx: *Ctx, input: Value) !?Conv {
            return convExt(ctx, input, .uextend);
        }

        pub fn ireduce_ext(ctx: *Ctx, input: Value) !?Conv {
            return convExt(ctx, input, .ireduce);
        }

        pub fn bitcast_ext(ctx: *Ctx, input: Value) !?Un {
            return unExt(ctx, input, .bitcast);
        }

        pub fn bmask_ext(ctx: *Ctx, input: Value) !?Conv {
            return convExt(ctx, input, .bmask);
        }

        pub fn scalar_to_vector_ext(ctx: *Ctx, input: Value) !?struct { arg0: Type, arg1: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .scalar_to_vector) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = u.arg };
                },
                else => return null,
            }
        }

        pub fn swiden_low_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .swiden_low) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn swiden_high_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .swiden_high) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn uwiden_low_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .uwiden_low) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn uwiden_high_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .uwiden_high) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn iadd_pairwise_ext(ctx: *Ctx, input: Value) !?struct { arg0: Type, arg1: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .iadd_pairwise) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = u.arg };
                },
                else => return null,
            }
        }

        pub fn iconcat_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .binary => |b| {
                    if (b.opcode != .iconcat) return null;
                    return .{ .arg0 = b.args[0], .arg1 = b.args[1] };
                },
                else => return null,
            }
        }

        pub fn isplit_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .isplit) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn iconst_ext(ctx: *Ctx, input: Value) !?struct { arg0: Type, arg1: i64 } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary_imm => |u| {
                    if (u.opcode != .iconst) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = u.imm.value };
                },
                else => return null,
            }
        }

        pub fn f32const_ext(ctx: *Ctx, input: Value) !?Ieee32 {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary_imm => |u| {
                    if (u.opcode != .f32const) return null;
                    const bits: u32 = @truncate(@as(u64, @bitCast(u.imm.value)));
                    return Ieee32.new(bits);
                },
                else => return null,
            }
        }

        pub fn f64const_ext(ctx: *Ctx, input: Value) !?Ieee64 {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary_imm => |u| {
                    if (u.opcode != .f64const) return null;
                    const bits: u64 = @bitCast(u.imm.value);
                    return Ieee64.new(bits);
                },
                else => return null,
            }
        }

        pub fn vconst_ext(_: *Ctx, _: Value) !?struct { arg0: Type, arg1: u128 } {
            // The IR does not currently carry a vector-constant payload.
            // Returning null keeps vconst patterns from erroring during matching.
            return null;
        }

        pub fn shuffle_ext(ctx: *Ctx, input: Value) !?struct { arg0: Type, arg1: Value, arg2: Value, arg3: u128 } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .shuffle => |s| {
                    if (s.opcode != .shuffle) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    var imm: u128 = 0;
                    var i: usize = 0;
                    while (i < 16) : (i += 1) {
                        imm |= (@as(u128, s.mask.bytes[i]) << @intCast(i * 8));
                    }
                    return .{ .arg0 = ty, .arg1 = s.args[0], .arg2 = s.args[1], .arg3 = imm };
                },
                else => return null,
            }
        }

        pub fn icmp_ext(ctx: *Ctx, input: Value) !?struct { arg0: IntCC, arg1: Type, arg2: Value, arg3: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .int_compare => |cmp| {
                    if (cmp.opcode != .icmp) return null;
                    const ty = valTy(ctx, cmp.args[0]) orelse return null;
                    return .{ .arg0 = cmp.cond, .arg1 = ty, .arg2 = cmp.args[0], .arg3 = cmp.args[1] };
                },
                else => return null,
            }
        }

        pub fn icmp_imm_ext(ctx: *Ctx, input: Value) !?struct { arg0: IntCC, arg1: Type, arg2: Value, arg3: i64 } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .int_compare_imm => |cmp| {
                    if (cmp.opcode != .icmp_imm) return null;
                    const ty = valTy(ctx, cmp.arg) orelse return null;
                    return .{ .arg0 = cmp.cond, .arg1 = ty, .arg2 = cmp.arg, .arg3 = cmp.imm.value };
                },
                else => return null,
            }
        }

        pub fn fcmp_ext(ctx: *Ctx, input: Value) !?struct { arg0: FloatCC, arg1: Type, arg2: Value, arg3: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .float_compare => |cmp| {
                    if (cmp.opcode != .fcmp) return null;
                    const ty = valTy(ctx, cmp.args[0]) orelse return null;
                    return .{ .arg0 = cmp.cond, .arg1 = ty, .arg2 = cmp.args[0], .arg3 = cmp.args[1] };
                },
                else => return null,
            }
        }

        pub fn load_ext(ctx: *Ctx, input: Value) !?struct { arg0: Type, arg1: Value, arg2: MemFlags, arg3: Offset32 } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .load => |ld| {
                    if (ld.opcode != .load) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = ld.arg, .arg2 = ld.flags, .arg3 = Offset32.new(ld.offset) };
                },
                else => return null,
            }
        }

        const Store = struct { arg0: Value, arg1: Value, arg2: MemFlags, arg3: Offset32 };

        fn storeOpExt(ctx: *Ctx, input: Value, op: Opcode) ?Store {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .store => |st| {
                    if (st.opcode != op) return null;
                    return .{ .arg0 = st.args[1], .arg1 = st.args[0], .arg2 = st.flags, .arg3 = Offset32.new(st.offset) };
                },
                else => return null,
            }
        }

        pub fn store_ext(ctx: *Ctx, input: Value) !?Store {
            return storeOpExt(ctx, input, .store);
        }

        pub fn istore8_ext(ctx: *Ctx, input: Value) !?Store {
            return storeOpExt(ctx, input, .istore8);
        }

        pub fn istore16_ext(ctx: *Ctx, input: Value) !?Store {
            return storeOpExt(ctx, input, .istore16);
        }

        pub fn istore32_ext(ctx: *Ctx, input: Value) !?Store {
            return storeOpExt(ctx, input, .istore32);
        }

        const MemLoad = struct { arg0: Value, arg1: MemFlags, arg2: Offset32 };

        fn loadOpExt(ctx: *Ctx, input: Value, op: Opcode) ?MemLoad {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .load => |ld| {
                    if (ld.opcode != op) return null;
                    return .{ .arg0 = ld.arg, .arg1 = ld.flags, .arg2 = Offset32.new(ld.offset) };
                },
                else => return null,
            }
        }

        pub fn uload8_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .uload8);
        }

        pub fn uload16_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .uload16);
        }

        pub fn uload32_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .uload32);
        }

        pub fn sload8_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .sload8);
        }

        pub fn sload16_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .sload16);
        }

        pub fn sload32_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .sload32);
        }

        pub fn uload8x8_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .uload8x8);
        }

        pub fn sload8x8_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .sload8x8);
        }

        pub fn uload16x4_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .uload16x4);
        }

        pub fn sload16x4_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .sload16x4);
        }

        pub fn uload32x2_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .uload32x2);
        }

        pub fn sload32x2_ext(ctx: *Ctx, input: Value) !?MemLoad {
            return loadOpExt(ctx, input, .sload32x2);
        }

        pub fn pre_inc_ext(_: *Ctx, _: Value) !?struct { arg0: Value, arg1: Value } {
            return null;
        }

        pub fn post_inc_ext(_: *Ctx, _: Value) !?struct { arg0: Value, arg1: Value } {
            return null;
        }

        pub fn load_pair_ext(_: *Ctx, _: Value) !?struct { arg0: Type, arg1: Value, arg2: i64, arg3: i64 } {
            return null;
        }

        pub fn store_pair_ext(_: *Ctx, _: Value) !?struct { arg0: Value, arg1: Value, arg2: Value, arg3: i64, arg4: i64 } {
            return null;
        }

        pub fn stack_addr_ext(ctx: *Ctx, input: Value) !?struct { arg0: StackSlot, arg1: Offset32 } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .stack_load => |sl| {
                    if (sl.opcode != .stack_addr) return null;
                    return .{ .arg0 = sl.stack_slot, .arg1 = Offset32.new(sl.offset) };
                },
                else => return null,
            }
        }

        pub fn stack_load_ext(ctx: *Ctx, input: Value) !?struct { arg0: StackSlot, arg1: Offset32 } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .stack_load => |sl| {
                    if (sl.opcode != .stack_load) return null;
                    return .{ .arg0 = sl.stack_slot, .arg1 = Offset32.new(sl.offset) };
                },
                else => return null,
            }
        }

        pub fn stack_store_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: StackSlot, arg2: Offset32 } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .stack_store => |ss| {
                    if (ss.opcode != .stack_store) return null;
                    return .{ .arg0 = ss.arg, .arg1 = ss.stack_slot, .arg2 = Offset32.new(ss.offset) };
                },
                else => return null,
            }
        }

        pub fn dynamic_stack_addr_ext(ctx: *Ctx, input: Value) !?u64 {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary_imm => |u| {
                    if (u.opcode != .dynamic_stack_addr) return null;
                    return @bitCast(u.imm.value);
                },
                else => return null,
            }
        }

        pub fn dynamic_stack_load_ext(ctx: *Ctx, input: Value) !?u64 {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary_imm => |u| {
                    if (u.opcode != .dynamic_stack_load) return null;
                    return @bitCast(u.imm.value);
                },
                else => return null,
            }
        }

        pub fn dynamic_stack_store_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: u64 } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .binary_imm64 => |b| {
                    if (b.opcode != .dynamic_stack_store) return null;
                    return .{ .arg0 = b.arg, .arg1 = @bitCast(b.imm.value) };
                },
                else => return null,
            }
        }

        pub fn stack_switch_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .binary => |b| {
                    if (b.opcode != .stack_switch) return null;
                    return .{ .arg0 = b.args[0], .arg1 = b.args[1] };
                },
                else => return null,
            }
        }

        pub fn tls_value_ext(ctx: *Ctx, input: Value) !?u64 {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary_imm => |u| {
                    if (u.opcode != .tls_value) return null;
                    return @bitCast(u.imm.value);
                },
                else => return null,
            }
        }

        pub fn atomic_load_ext(ctx: *Ctx, input: Value) !?struct { arg0: Type, arg1: Value, arg2: MemFlags, arg3: AtomicOrdering } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .atomic_load => |ld| {
                    if (ld.opcode != .atomic_load) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{ .arg0 = ty, .arg1 = ld.addr, .arg2 = ld.flags, .arg3 = ld.ordering };
                },
                else => return null,
            }
        }

        pub fn atomic_store_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Value, arg2: MemFlags, arg3: AtomicOrdering } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .atomic_store => |st| {
                    if (st.opcode != .atomic_store) return null;
                    return .{ .arg0 = st.src, .arg1 = st.addr, .arg2 = st.flags, .arg3 = st.ordering };
                },
                else => return null,
            }
        }

        pub fn atomic_rmw_ext(ctx: *Ctx, input: Value) !?struct { arg0: AtomicRmwOp, arg1: Type, arg2: Value, arg3: Value, arg4: MemFlags, arg5: AtomicOrdering } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .atomic_rmw => |rmw| {
                    if (rmw.opcode != .atomic_rmw) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{
                        .arg0 = rmw.op,
                        .arg1 = ty,
                        .arg2 = rmw.addr,
                        .arg3 = rmw.src,
                        .arg4 = rmw.flags,
                        .arg5 = rmw.ordering,
                    };
                },
                else => return null,
            }
        }

        pub fn atomic_cas_ext(ctx: *Ctx, input: Value) !?struct { arg0: Type, arg1: Value, arg2: Value, arg3: Value, arg4: MemFlags, arg5: AtomicOrdering } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .atomic_cas => |cas| {
                    if (cas.opcode != .atomic_cas) return null;
                    const ty = valTy(ctx, input) orelse return null;
                    return .{
                        .arg0 = ty,
                        .arg1 = cas.addr,
                        .arg2 = cas.expected,
                        .arg3 = cas.replacement,
                        .arg4 = cas.flags,
                        .arg5 = cas.ordering,
                    };
                },
                else => return null,
            }
        }

        pub fn fence_ext(ctx: *Ctx, input: Value) !?struct { arg0: AtomicOrdering } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .fence => |f| {
                    if (f.opcode != .fence) return null;
                    return .{ .arg0 = f.ordering };
                },
                else => return null,
            }
        }

        pub fn trap_ext(_: *Ctx, _: Value) !?TrapCode {
            // The IR `trap` instruction does not currently carry a TrapCode payload.
            return null;
        }

        pub fn trapz_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: TrapCode } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary_with_trap => |u| {
                    if (u.opcode != .trapz) return null;
                    return .{ .arg0 = u.arg, .arg1 = u.trap_code };
                },
                else => return null,
            }
        }

        pub fn trapnz_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: TrapCode } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary_with_trap => |u| {
                    if (u.opcode != .trapnz) return null;
                    return .{ .arg0 = u.arg, .arg1 = u.trap_code };
                },
                else => return null,
            }
        }

        pub fn jump_ext(ctx: *Ctx, input: Value) !?struct { arg0: Block } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .jump => |j| {
                    if (j.opcode != .jump) return null;
                    return .{ .arg0 = j.destination };
                },
                else => return null,
            }
        }

        pub fn br_table_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: JumpTable, arg2: Block } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .branch_table => |brt| {
                    if (brt.opcode != .br_table) return null;
                    const l = lc(ctx);
                    const jt = l.func.jump_tables.get(brt.destination) orelse return null;
                    const default_call = jt.defaultBlock() orelse return null;
                    const default_block = default_call.block(&l.func.dfg.value_lists) catch return null;
                    return .{
                        .arg0 = brt.arg,
                        .arg1 = brt.destination,
                        .arg2 = default_block,
                    };
                },
                else => return null,
            }
        }

        pub fn brz_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Block } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .branch_z => |br| {
                    if (br.opcode != .brz) return null;
                    return .{ .arg0 = br.condition, .arg1 = br.destination };
                },
                else => return null,
            }
        }

        pub fn brnz_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Block } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .branch_z => |br| {
                    if (br.opcode != .brnz) return null;
                    return .{ .arg0 = br.condition, .arg1 = br.destination };
                },
                else => return null,
            }
        }

        pub fn brif_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value, arg1: Block } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .branch => |br| {
                    if (br.opcode != .brif) return null;
                    const dst = br.then_dest orelse return null;
                    return .{ .arg0 = br.condition, .arg1 = dst };
                },
                else => return null,
            }
        }

        pub fn return_ext(ctx: *Ctx, input: Value) !?Value {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .nullary => |n| if (n.opcode == .@"return") return input else return null,
                .unary => |u| if (u.opcode == .@"return") return input else return null,
                .@"return" => |r| if (r.opcode == .@"return") return input else return null,
                else => return null,
            }
        }

        pub fn debugtrap_ext(ctx: *Ctx, input: Value) !?Value {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .nullary => |n| if (n.opcode == .debugtrap) return input else return null,
                else => return null,
            }
        }

        pub fn nop_ext(ctx: *Ctx, input: Value) !?Value {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .nullary => |n| if (n.opcode == .nop) return input else return null,
                else => return null,
            }
        }

        pub fn sequence_point_ext(ctx: *Ctx, input: Value) !?Value {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .nullary => |n| if (n.opcode == .sequence_point) return input else return null,
                else => return null,
            }
        }

        pub fn spectre_fence_ext(ctx: *Ctx, input: Value) !?Value {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .nullary => |n| if (n.opcode == .spectre_fence) return input else return null,
                else => return null,
            }
        }

        pub fn landingpad_ext(ctx: *Ctx, input: Value) !?Value {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .nullary => |n| if (n.opcode == .landingpad) return input else return null,
                else => return null,
            }
        }

        pub fn get_frame_pointer_ext(ctx: *Ctx, input: Value) !?Value {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .nullary => |n| if (n.opcode == .get_frame_pointer) return input else return null,
                else => return null,
            }
        }

        pub fn get_stack_pointer_ext(ctx: *Ctx, input: Value) !?Value {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .nullary => |n| if (n.opcode == .get_stack_pointer) return input else return null,
                else => return null,
            }
        }

        pub fn get_return_address_ext(ctx: *Ctx, input: Value) !?Value {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .nullary => |n| if (n.opcode == .get_return_address) return input else return null,
                else => return null,
            }
        }

        pub fn get_pinned_reg_ext(ctx: *Ctx, input: Value) !?Value {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .nullary => |n| if (n.opcode == .get_pinned_reg) return input else return null,
                else => return null,
            }
        }

        pub fn set_pinned_reg_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .set_pinned_reg) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn vall_true_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .vall_true) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn vany_true_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .vany_true) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn vhigh_bits_ext(ctx: *Ctx, input: Value) !?struct { arg0: Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .unary => |u| {
                    if (u.opcode != .vhigh_bits) return null;
                    return .{ .arg0 = u.arg };
                },
                else => return null,
            }
        }

        pub fn global_value_ext(_: *Ctx, _: Value) !?GlobalValue {
            return null;
        }

        pub fn symbol_value_ext(_: *Ctx, _: Value) !?SymbolValueData {
            return null;
        }

        pub fn func_addr_ext(_: *Ctx, _: Value) !?FuncRefData {
            return null;
        }

        pub fn call_ext(ctx: *Ctx, input: Value) !?struct { arg0: FuncRefData, arg1: []const Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .call => |c| {
                    if (c.opcode != .call) return null;
                    const f = funcRefData(ctx, c.func_ref) orelse return null;
                    const l = lc(ctx);
                    return .{ .arg0 = f, .arg1 = l.func.dfg.value_lists.asSlice(c.args) };
                },
                else => return null,
            }
        }

        pub fn return_call_ext(ctx: *Ctx, input: Value) !?struct { arg0: FuncRefData, arg1: []const Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .call => |c| {
                    if (c.opcode != .return_call) return null;
                    const f = funcRefData(ctx, c.func_ref) orelse return null;
                    const l = lc(ctx);
                    return .{ .arg0 = f, .arg1 = l.func.dfg.value_lists.asSlice(c.args) };
                },
                else => return null,
            }
        }

        pub fn call_indirect_ext(ctx: *Ctx, input: Value) !?struct { arg0: SigRef, arg1: Value, arg2: []const Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .call_indirect => |c| {
                    if (c.opcode != .call_indirect) return null;
                    const l = lc(ctx);
                    const args_all = l.func.dfg.value_lists.asSlice(c.args);
                    if (args_all.len == 0) return null;
                    return .{ .arg0 = c.sig_ref, .arg1 = args_all[0], .arg2 = args_all[1..] };
                },
                else => return null,
            }
        }

        pub fn return_call_indirect_ext(ctx: *Ctx, input: Value) !?struct { arg0: SigRef, arg1: Value, arg2: []const Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .call_indirect => |c| {
                    if (c.opcode != .return_call_indirect) return null;
                    const l = lc(ctx);
                    const args_all = l.func.dfg.value_lists.asSlice(c.args);
                    if (args_all.len == 0) return null;
                    return .{ .arg0 = c.sig_ref, .arg1 = args_all[0], .arg2 = args_all[1..] };
                },
                else => return null,
            }
        }

        pub fn try_call_ext(ctx: *Ctx, input: Value) !?struct { arg0: FuncRefData, arg1: []const Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .try_call => |c| {
                    if (c.opcode != .try_call) return null;
                    const f = funcRefData(ctx, c.func_ref) orelse return null;
                    const l = lc(ctx);
                    return .{ .arg0 = f, .arg1 = l.func.dfg.value_lists.asSlice(c.args) };
                },
                else => return null,
            }
        }

        pub fn try_call_indirect_ext(ctx: *Ctx, input: Value) !?struct { arg0: SigRef, arg1: Value, arg2: []const Value } {
            const inst = valInst(ctx, input) orelse return null;
            const data = instData(ctx, inst) orelse return null;
            switch (data.*) {
                .try_call_indirect => |c| {
                    if (c.opcode != .try_call_indirect) return null;
                    const l = lc(ctx);
                    const args_all = l.func.dfg.value_lists.asSlice(c.args);
                    if (args_all.len == 0) return null;
                    return .{ .arg0 = c.sig_ref, .arg1 = args_all[0], .arg2 = args_all[1..] };
                },
                else => return null,
            }
        }

        pub fn func_ref_data_ext(_: *Ctx, input: FuncRefData) !?struct { arg0: SigRef, arg1: ExternalName, arg2: RelocDistance, arg3: i64 } {
            return .{ .arg0 = input.sig_ref, .arg1 = input.name, .arg2 = input.dist, .arg3 = input.offset };
        }

        pub fn symbol_value_data_ext(_: *Ctx, input: SymbolValueData) !?struct { arg0: ExternalName, arg1: RelocDistance, arg2: i64 } {
            return .{ .arg0 = input.name, .arg1 = input.dist, .arg2 = input.offset };
        }
    };
}
