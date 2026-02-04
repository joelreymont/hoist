const inst_mod = @import("inst.zig");
const lower_mod = @import("../../machinst/lower.zig");

pub const Aarch64Inst = inst_mod.Inst;
pub const Reg = inst_mod.Reg;
pub const ImmLogic = inst_mod.ImmLogic;
pub const CondCode = inst_mod.CondCode;
pub const Cond = inst_mod.CondCode;
pub const VecALUOp = inst_mod.VecALUOp;
pub const VecALUModOp = inst_mod.VecALUModOp;
pub const VecElemSize = inst_mod.VecElemSize;
pub const VecMisc2 = inst_mod.VecMisc2;
pub const VecShiftImmOp = inst_mod.VecShiftImmOp;
pub const VectorSize = inst_mod.VectorSize;
pub const SveElemSize = inst_mod.SveElemSize;
pub const ExtendOp = inst_mod.ExtendOp;
pub const ShiftOp = inst_mod.ShiftOp;
pub const SystemReg = inst_mod.SystemReg;
pub const ValueRegs = lower_mod.ValueRegs;

pub const ShareabilityDomain = enum {
    SY,
    ISH,
    ISHLD,
    ISHST,
    NSH,
    OSH,
};

pub const ProducesFlags = union(enum) {
    ProducesFlagsReturnsResultWithConsumer: struct {
        inst: Aarch64Inst,
        result: Reg,
    },
    ProducesFlagsSideEffect: struct {
        inst: Aarch64Inst,
    },

    pub fn producesFlagsReturnsResultWithConsumer(inst: Aarch64Inst, result: Reg) ProducesFlags {
        return .{ .ProducesFlagsReturnsResultWithConsumer = .{ .inst = inst, .result = result } };
    }

    pub fn producesFlagsSideEffect(inst: Aarch64Inst) ProducesFlags {
        return .{ .ProducesFlagsSideEffect = .{ .inst = inst } };
    }
};

pub const ConsumesFlags = union(enum) {
    ConsumesFlagsReturnsResultWithProducer: struct {
        inst: Aarch64Inst,
        result: Reg,
    },
    ConsumesFlagsReturnsReg: struct {
        inst: Aarch64Inst,
        result: Reg,
    },
    ConsumesFlagsTwiceReturnsValueRegs: struct {
        inst1: Aarch64Inst,
        inst2: Aarch64Inst,
        result: ValueRegs,
    },

    pub fn consumesFlagsReturnsResultWithProducer(inst: Aarch64Inst, result: Reg) ConsumesFlags {
        return .{ .ConsumesFlagsReturnsResultWithProducer = .{ .inst = inst, .result = result } };
    }

    pub fn consumesFlagsReturnsReg(inst: Aarch64Inst, result: Reg) ConsumesFlags {
        return .{ .ConsumesFlagsReturnsReg = .{ .inst = inst, .result = result } };
    }

    pub fn consumesFlagsTwiceReturnsValueRegs(inst1: Aarch64Inst, inst2: Aarch64Inst, result: ValueRegs) ConsumesFlags {
        return .{
            .ConsumesFlagsTwiceReturnsValueRegs = .{
                .inst1 = inst1,
                .inst2 = inst2,
                .result = result,
            },
        };
    }
};
