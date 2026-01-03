const std = @import("std");
const testing = std.testing;

const root = @import("../root.zig");
const opcodes = @import("opcodes.zig");
const entities = @import("entities.zig");
const types = @import("types.zig");
const immediates = @import("immediates.zig");
const condcodes = @import("condcodes.zig");
const memflags = @import("memflags.zig");
const value_list = @import("value_list.zig");
const block_call = @import("block_call.zig");
const atomics = @import("atomics.zig");

const Opcode = opcodes.Opcode;
const Value = entities.Value;
const Type = types.Type;
const Imm64 = immediates.Imm64;
const Ieee32 = immediates.Ieee32;
const Ieee64 = immediates.Ieee64;
const IntCC = condcodes.IntCC;
const FloatCC = condcodes.FloatCC;
const MemFlags = memflags.MemFlags;
const ValueList = value_list.ValueList;
const BlockCall = block_call.BlockCall;
const AtomicOrdering = atomics.AtomicOrdering;
const AtomicRmwOp = atomics.AtomicRmwOp;

/// Instruction data - core instruction representation.
pub const InstructionData = union(enum) {
    nullary: NullaryData,
    unary_imm: UnaryImmData,
    unary: UnaryData,
    binary: BinaryData,
    int_compare: IntCompareData,
    float_compare: FloatCompareData,
    branch: BranchData,
    jump: JumpData,
    branch_table: BranchTableData,
    call: CallData,
    call_indirect: CallIndirectData,
    load: LoadData,
    store: StoreData,
    atomic_load: AtomicLoadData,
    atomic_store: AtomicStoreData,
    atomic_rmw: AtomicRmwData,
    atomic_cas: AtomicCasData,
    fence: FenceData,

    pub fn opcode(self: InstructionData) Opcode {
        return switch (self) {
            inline else => |data| data.opcode,
        };
    }
};

pub const NullaryData = struct {
    opcode: Opcode,

    pub fn init(op: Opcode) NullaryData {
        return .{ .opcode = op };
    }
};

pub const UnaryImmData = struct {
    opcode: Opcode,
    imm: Imm64,

    pub fn init(op: Opcode, imm: Imm64) UnaryImmData {
        return .{ .opcode = op, .imm = imm };
    }
};

pub const UnaryData = struct {
    opcode: Opcode,
    arg: Value,

    pub fn init(op: Opcode, arg: Value) UnaryData {
        return .{ .opcode = op, .arg = arg };
    }
};

pub const BinaryData = struct {
    opcode: Opcode,
    args: [2]Value,

    pub fn init(op: Opcode, arg0: Value, arg1: Value) BinaryData {
        return .{ .opcode = op, .args = .{ arg0, arg1 } };
    }
};

pub const IntCompareData = struct {
    opcode: Opcode,
    cond: IntCC,
    args: [2]Value,

    pub fn init(op: Opcode, cond: IntCC, arg0: Value, arg1: Value) IntCompareData {
        return .{ .opcode = op, .cond = cond, .args = .{ arg0, arg1 } };
    }
};

pub const FloatCompareData = struct {
    opcode: Opcode,
    cond: FloatCC,
    args: [2]Value,

    pub fn init(op: Opcode, cond: FloatCC, arg0: Value, arg1: Value) FloatCompareData {
        return .{ .opcode = op, .cond = cond, .args = .{ arg0, arg1 } };
    }
};

pub const BranchData = struct {
    opcode: Opcode,
    condition: Value,
    then_dest: ?entities.Block,
    else_dest: ?entities.Block,

    pub fn init(op: Opcode, cond: Value, then_dst: entities.Block, else_dst: entities.Block) BranchData {
        return .{
            .opcode = op,
            .condition = cond,
            .then_dest = then_dst,
            .else_dest = else_dst,
        };
    }
};

pub const JumpData = struct {
    opcode: Opcode,
    destination: entities.Block,

    pub fn init(op: Opcode, dest: entities.Block) JumpData {
        return .{ .opcode = op, .destination = dest };
    }
};

pub const BranchTableData = struct {
    opcode: Opcode,
    arg: Value,
    destination: entities.JumpTable,

    pub fn init(op: Opcode, arg: Value, table: entities.JumpTable) BranchTableData {
        return .{ .opcode = op, .arg = arg, .destination = table };
    }
};

pub const CallData = struct {
    opcode: Opcode,
    func_ref: entities.FuncRef,
    args: ValueList,
};

pub const CallIndirectData = struct {
    opcode: Opcode,
    sig_ref: entities.SigRef,
    args: ValueList,
};

pub const LoadData = struct {
    opcode: Opcode,
    flags: MemFlags,
    arg: Value,
    offset: i32,

    pub fn init(op: Opcode, flags: MemFlags, arg: Value, offset: i32) LoadData {
        return .{ .opcode = op, .flags = flags, .arg = arg, .offset = offset };
    }
};

pub const StoreData = struct {
    opcode: Opcode,
    flags: MemFlags,
    args: [2]Value,
    offset: i32,

    pub fn init(op: Opcode, flags: MemFlags, addr: Value, data: Value, offset: i32) StoreData {
        return .{ .opcode = op, .flags = flags, .args = .{ addr, data }, .offset = offset };
    }
};

pub const AtomicLoadData = struct {
    opcode: Opcode,
    flags: MemFlags,
    addr: Value,
    ordering: AtomicOrdering,

    pub fn init(op: Opcode, flags: MemFlags, addr: Value, ordering: AtomicOrdering) AtomicLoadData {
        return .{ .opcode = op, .flags = flags, .addr = addr, .ordering = ordering };
    }
};

pub const AtomicStoreData = struct {
    opcode: Opcode,
    flags: MemFlags,
    addr: Value,
    src: Value,
    ordering: AtomicOrdering,

    pub fn init(op: Opcode, flags: MemFlags, addr: Value, src: Value, ordering: AtomicOrdering) AtomicStoreData {
        return .{ .opcode = op, .flags = flags, .addr = addr, .src = src, .ordering = ordering };
    }
};

pub const AtomicRmwData = struct {
    opcode: Opcode,
    flags: MemFlags,
    addr: Value,
    src: Value,
    op: AtomicRmwOp,
    ordering: AtomicOrdering,

    pub fn init(
        opc: Opcode,
        flags: MemFlags,
        addr: Value,
        src: Value,
        rmw_op: AtomicRmwOp,
        ordering: AtomicOrdering,
    ) AtomicRmwData {
        return .{ .opcode = opc, .flags = flags, .addr = addr, .src = src, .op = rmw_op, .ordering = ordering };
    }
};

pub const AtomicCasData = struct {
    opcode: Opcode,
    flags: MemFlags,
    addr: Value,
    expected: Value,
    replacement: Value,
    ordering: AtomicOrdering,

    pub fn init(
        op: Opcode,
        flags: MemFlags,
        addr: Value,
        expected: Value,
        replacement: Value,
        ordering: AtomicOrdering,
    ) AtomicCasData {
        return .{
            .opcode = op,
            .flags = flags,
            .addr = addr,
            .expected = expected,
            .replacement = replacement,
            .ordering = ordering,
        };
    }
};

pub const FenceData = struct {
    opcode: Opcode,
    ordering: AtomicOrdering,

    pub fn init(op: Opcode, ordering: AtomicOrdering) FenceData {
        return .{ .opcode = op, .ordering = ordering };
    }
};

test "NullaryData" {
    const data = NullaryData.init(.nop);
    try testing.expectEqual(Opcode.nop, data.opcode);
}

test "UnaryData" {
    const data = UnaryData.init(.iadd, Value.new(42));
    try testing.expectEqual(Opcode.iadd, data.opcode);
    try testing.expectEqual(Value.new(42), data.arg);
}

test "BinaryData" {
    const data = BinaryData.init(.iadd, Value.new(1), Value.new(2));
    try testing.expectEqual(Opcode.iadd, data.opcode);
    try testing.expectEqual(Value.new(1), data.args[0]);
    try testing.expectEqual(Value.new(2), data.args[1]);
}

test "IntCompareData" {
    const data = IntCompareData.init(.icmp, .eq, Value.new(1), Value.new(2));
    try testing.expectEqual(Opcode.icmp, data.opcode);
    try testing.expectEqual(IntCC.eq, data.cond);
}

test "FloatCompareData" {
    const data = FloatCompareData.init(.fcmp, .eq, Value.new(1), Value.new(2));
    try testing.expectEqual(Opcode.fcmp, data.opcode);
    try testing.expectEqual(FloatCC.eq, data.cond);
}

test "JumpData" {
    const data = JumpData.init(.jump, entities.Block.new(0));
    try testing.expectEqual(Opcode.jump, data.opcode);
    try testing.expectEqual(entities.Block.new(0), data.destination);
}

test "BranchTableData" {
    const data = BranchTableData.init(.br_table, Value.new(1), entities.JumpTable.new(0));
    try testing.expectEqual(Opcode.br_table, data.opcode);
    try testing.expectEqual(Value.new(1), data.arg);
}

test "LoadData" {
    const flags = MemFlags.new();
    const data = LoadData.init(.load, flags, Value.new(10), 0);
    try testing.expectEqual(Opcode.load, data.opcode);
    try testing.expectEqual(Value.new(10), data.arg);
}

test "StoreData" {
    const flags = MemFlags.new();
    const data = StoreData.init(.store, flags, Value.new(10), Value.new(20), 8);
    try testing.expectEqual(Opcode.store, data.opcode);
    try testing.expectEqual(Value.new(10), data.args[0]);
    try testing.expectEqual(Value.new(20), data.args[1]);
    try testing.expectEqual(@as(i32, 8), data.offset);
}

test "InstructionData opcode" {
    const inst = InstructionData{ .binary = BinaryData.init(.iadd, Value.new(1), Value.new(2)) };
    try testing.expectEqual(Opcode.iadd, inst.opcode());
}
