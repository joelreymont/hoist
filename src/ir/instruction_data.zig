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
const trapcode = @import("trapcode.zig");

const Opcode = opcodes.Opcode;
const Value = entities.Value;
const Type = types.Type;
const Imm64 = immediates.Imm64;
const Imm128 = immediates.Imm128;
const Uimm8 = immediates.Uimm8;
const Ieee32 = immediates.Ieee32;
const Ieee64 = immediates.Ieee64;
const IntCC = condcodes.IntCC;
const FloatCC = condcodes.FloatCC;
const MemFlags = memflags.MemFlags;
const ValueList = value_list.ValueList;
const ValueListPool = value_list.ValueListPool;
const AtomicOrdering = atomics.AtomicOrdering;
const AtomicRmwOp = atomics.AtomicRmwOp;
const TrapCode = trapcode.TrapCode;

/// Instruction data - core instruction representation.
pub const InstructionData = union(enum) {
    nullary: NullaryData,
    unary_imm: UnaryImmData,
    unary: UnaryData,
    unary_with_trap: UnaryWithTrapData,
    extract_lane: ExtractLaneData,
    ternary: TernaryData,
    ternary_imm8: TernaryImm8Data,
    shuffle: ShuffleData,
    binary: BinaryData,
    binary_imm64: BinaryImm64Data,
    int_compare: IntCompareData,
    int_compare_imm: IntCompareImmData,
    float_compare: FloatCompareData,
    branch: BranchData,
    jump: JumpData,
    branch_table: BranchTableData,
    branch_z: BranchZData,
    call: CallData,
    call_indirect: CallIndirectData,
    try_call: TryCallData,
    try_call_indirect: TryCallIndirectData,
    load: LoadData,
    store: StoreData,
    atomic_load: AtomicLoadData,
    atomic_store: AtomicStoreData,
    atomic_rmw: AtomicRmwData,
    atomic_cas: AtomicCasData,
    fence: FenceData,
    stack_load: StackLoadData,
    stack_store: StackStoreData,

    pub fn opcode(self: InstructionData) Opcode {
        return switch (self) {
            inline else => |data| data.opcode,
        };
    }

    pub fn forEachValueMut(
        self: *InstructionData,
        pool: *ValueListPool,
        ctx: anytype,
        func: anytype,
    ) @typeInfo(@TypeOf(func)).@"fn".return_type.? {
        return forEachValueImpl(self, pool, ctx, func);
    }

    pub fn forEachValue(
        self: *const InstructionData,
        pool: *const ValueListPool,
        ctx: anytype,
        func: anytype,
    ) @typeInfo(@TypeOf(func)).@"fn".return_type.? {
        return forEachValueImpl(self, pool, ctx, func);
    }

    fn listSlice(
        pool: anytype,
        list: ValueList,
    ) if (@typeInfo(@TypeOf(pool)).pointer.is_const) []const Value else []Value {
        if (comptime @typeInfo(@TypeOf(pool)).pointer.is_const) {
            return pool.asSlice(list);
        }
        return pool.asMutSlice(list);
    }

    fn forEachValueImpl(
        self: anytype,
        pool: anytype,
        ctx: anytype,
        func: anytype,
    ) @typeInfo(@TypeOf(func)).@"fn".return_type.? {
        const func_info = @typeInfo(@TypeOf(func)).@"fn";
        const ret_ty = func_info.return_type orelse void;
        const ret_info = @typeInfo(ret_ty);
        const ret_is_void = ret_info == .void;
        const ret_is_error_void = ret_info == .error_union and ret_info.error_union.payload == void;
        if (comptime !ret_is_void and !ret_is_error_void) {
            @compileError("forEachValue callback must return void or !void");
        }
        const is_error = comptime ret_info == .error_union;

        switch (self.*) {
            .unary => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.arg);
                } else {
                    func(ctx, &data.arg);
                }
            },
            .unary_with_trap => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.arg);
                } else {
                    func(ctx, &data.arg);
                }
            },
            .extract_lane => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.arg);
                } else {
                    func(ctx, &data.arg);
                }
            },
            .ternary => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.args[0]);
                    try func(ctx, &data.args[1]);
                    try func(ctx, &data.args[2]);
                } else {
                    func(ctx, &data.args[0]);
                    func(ctx, &data.args[1]);
                    func(ctx, &data.args[2]);
                }
            },
            .ternary_imm8 => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.args[0]);
                    try func(ctx, &data.args[1]);
                } else {
                    func(ctx, &data.args[0]);
                    func(ctx, &data.args[1]);
                }
            },
            .shuffle => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.args[0]);
                    try func(ctx, &data.args[1]);
                } else {
                    func(ctx, &data.args[0]);
                    func(ctx, &data.args[1]);
                }
            },
            .binary => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.args[0]);
                    try func(ctx, &data.args[1]);
                } else {
                    func(ctx, &data.args[0]);
                    func(ctx, &data.args[1]);
                }
            },
            .binary_imm64 => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.arg);
                } else {
                    func(ctx, &data.arg);
                }
            },
            .int_compare => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.args[0]);
                    try func(ctx, &data.args[1]);
                } else {
                    func(ctx, &data.args[0]);
                    func(ctx, &data.args[1]);
                }
            },
            .int_compare_imm => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.arg);
                } else {
                    func(ctx, &data.arg);
                }
            },
            .float_compare => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.args[0]);
                    try func(ctx, &data.args[1]);
                } else {
                    func(ctx, &data.args[0]);
                    func(ctx, &data.args[1]);
                }
            },
            .branch => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.condition);
                } else {
                    func(ctx, &data.condition);
                }
                const then_slice = listSlice(pool, data.then_args);
                for (then_slice) |*val| {
                    if (comptime is_error) {
                        try func(ctx, val);
                    } else {
                        func(ctx, val);
                    }
                }
                const else_slice = listSlice(pool, data.else_args);
                for (else_slice) |*val| {
                    if (comptime is_error) {
                        try func(ctx, val);
                    } else {
                        func(ctx, val);
                    }
                }
            },
            .jump => |*data| {
                const slice = listSlice(pool, data.args);
                for (slice) |*val| {
                    if (comptime is_error) {
                        try func(ctx, val);
                    } else {
                        func(ctx, val);
                    }
                }
            },
            .branch_table => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.arg);
                } else {
                    func(ctx, &data.arg);
                }
            },
            .branch_z => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.condition);
                } else {
                    func(ctx, &data.condition);
                }
                const slice = listSlice(pool, data.args);
                for (slice) |*val| {
                    if (comptime is_error) {
                        try func(ctx, val);
                    } else {
                        func(ctx, val);
                    }
                }
            },
            .call => |*data| {
                const slice = listSlice(pool, data.args);
                for (slice) |*val| {
                    if (comptime is_error) {
                        try func(ctx, val);
                    } else {
                        func(ctx, val);
                    }
                }
            },
            .call_indirect => |*data| {
                const slice = listSlice(pool, data.args);
                for (slice) |*val| {
                    if (comptime is_error) {
                        try func(ctx, val);
                    } else {
                        func(ctx, val);
                    }
                }
            },
            .try_call => |*data| {
                const slice = listSlice(pool, data.args);
                for (slice) |*val| {
                    if (comptime is_error) {
                        try func(ctx, val);
                    } else {
                        func(ctx, val);
                    }
                }
            },
            .try_call_indirect => |*data| {
                const slice = listSlice(pool, data.args);
                for (slice) |*val| {
                    if (comptime is_error) {
                        try func(ctx, val);
                    } else {
                        func(ctx, val);
                    }
                }
            },
            .load => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.arg);
                } else {
                    func(ctx, &data.arg);
                }
            },
            .store => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.args[0]);
                    try func(ctx, &data.args[1]);
                } else {
                    func(ctx, &data.args[0]);
                    func(ctx, &data.args[1]);
                }
            },
            .atomic_load => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.addr);
                } else {
                    func(ctx, &data.addr);
                }
            },
            .atomic_store => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.addr);
                    try func(ctx, &data.src);
                } else {
                    func(ctx, &data.addr);
                    func(ctx, &data.src);
                }
            },
            .atomic_rmw => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.addr);
                    try func(ctx, &data.src);
                } else {
                    func(ctx, &data.addr);
                    func(ctx, &data.src);
                }
            },
            .atomic_cas => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.addr);
                    try func(ctx, &data.expected);
                    try func(ctx, &data.replacement);
                } else {
                    func(ctx, &data.addr);
                    func(ctx, &data.expected);
                    func(ctx, &data.replacement);
                }
            },
            .stack_store => |*data| {
                if (comptime is_error) {
                    try func(ctx, &data.arg);
                } else {
                    func(ctx, &data.arg);
                }
            },
            .nullary,
            .unary_imm,
            .fence,
            .stack_load,
            => {},
        }
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

pub const UnaryWithTrapData = struct {
    opcode: Opcode,
    arg: Value,
    trap_code: TrapCode,

    pub fn init(op: Opcode, arg: Value, trap_code: TrapCode) UnaryWithTrapData {
        return .{ .opcode = op, .arg = arg, .trap_code = trap_code };
    }
};

pub const ExtractLaneData = struct {
    opcode: Opcode,
    arg: Value,
    lane: u8,

    pub fn init(op: Opcode, arg: Value, lane: u8) ExtractLaneData {
        return .{ .opcode = op, .arg = arg, .lane = lane };
    }
};

pub const TernaryData = struct {
    opcode: Opcode,
    args: [3]Value,

    pub fn init(op: Opcode, arg0: Value, arg1: Value, arg2: Value) TernaryData {
        return .{ .opcode = op, .args = .{ arg0, arg1, arg2 } };
    }
};

pub const TernaryImm8Data = struct {
    opcode: Opcode,
    args: [2]Value,
    imm: Uimm8,

    pub fn init(op: Opcode, arg0: Value, imm: Uimm8, arg1: Value) TernaryImm8Data {
        return .{ .opcode = op, .args = .{ arg0, arg1 }, .imm = imm };
    }
};

pub const ShuffleData = struct {
    opcode: Opcode,
    args: [2]Value,
    mask: Imm128,

    pub fn init(op: Opcode, arg0: Value, arg1: Value, mask: Imm128) ShuffleData {
        return .{ .opcode = op, .args = .{ arg0, arg1 }, .mask = mask };
    }
};

pub const BinaryData = struct {
    opcode: Opcode,
    args: [2]Value,

    pub fn init(op: Opcode, arg0: Value, arg1: Value) BinaryData {
        return .{ .opcode = op, .args = .{ arg0, arg1 } };
    }
};

pub const BinaryImm64Data = struct {
    opcode: Opcode,
    arg: Value,
    imm: Imm64,

    pub fn init(op: Opcode, arg: Value, imm: Imm64) BinaryImm64Data {
        return .{ .opcode = op, .arg = arg, .imm = imm };
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

pub const IntCompareImmData = struct {
    opcode: Opcode,
    cond: IntCC,
    arg: Value,
    imm: Imm64,

    pub fn init(op: Opcode, cond: IntCC, arg: Value, imm: Imm64) IntCompareImmData {
        return .{ .opcode = op, .cond = cond, .arg = arg, .imm = imm };
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
    then_args: ValueList = ValueList.default(),
    else_args: ValueList = ValueList.default(),

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
    args: ValueList = ValueList.default(),

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

pub const BranchZData = struct {
    opcode: Opcode,
    condition: Value,
    destination: entities.Block,
    args: ValueList = ValueList.default(),

    pub fn init(op: Opcode, cond: Value, dest: entities.Block) BranchZData {
        return .{ .opcode = op, .condition = cond, .destination = dest };
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

pub const TryCallData = struct {
    opcode: Opcode,
    func_ref: entities.FuncRef,
    args: ValueList,
    normal_successor: entities.Block,
    exception_successor: entities.Block,
};

pub const TryCallIndirectData = struct {
    opcode: Opcode,
    sig_ref: entities.SigRef,
    args: ValueList,
    normal_successor: entities.Block,
    exception_successor: entities.Block,
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

pub const StackLoadData = struct {
    opcode: Opcode,
    stack_slot: entities.StackSlot,
    offset: i32,

    pub fn init(op: Opcode, stack_slot: entities.StackSlot, offset: i32) StackLoadData {
        return .{ .opcode = op, .stack_slot = stack_slot, .offset = offset };
    }
};

pub const StackStoreData = struct {
    opcode: Opcode,
    arg: Value,
    stack_slot: entities.StackSlot,
    offset: i32,

    pub fn init(op: Opcode, arg: Value, stack_slot: entities.StackSlot, offset: i32) StackStoreData {
        return .{ .opcode = op, .arg = arg, .stack_slot = stack_slot, .offset = offset };
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
    const flags = MemFlags.default();
    const data = LoadData.init(.load, flags, Value.new(10), 0);
    try testing.expectEqual(Opcode.load, data.opcode);
    try testing.expectEqual(Value.new(10), data.arg);
}

test "StoreData" {
    const flags = MemFlags.default();
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
