const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const Function = root.function.Function;
const Block = root.entities.Block;
const Inst = root.entities.Inst;
const Value = root.entities.Value;
const Type = root.types.Type;
const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;
const Layout = root.layout.Layout;
const DataFlowGraph = root.dfg.DataFlowGraph;
const IntCC = root.condcodes.IntCC;

/// A runtime value in the interpreter.
pub const DataValue = union(enum) {
    i8: i8,
    i16: i16,
    i32: i32,
    i64: i64,
    i128: i128,
    f32: f32,
    f64: f64,
    // SIMD vectors (128-bit)
    i8x16: @Vector(16, i8),
    i16x8: @Vector(8, i16),
    i32x4: @Vector(4, i32),
    i64x2: @Vector(2, i64),
    f32x4: @Vector(4, f32),
    f64x2: @Vector(2, f64),

    pub fn fromI64(ty: Type, val: i64) DataValue {
        return switch (ty) {
            .I8 => .{ .i8 = @truncate(val) },
            .I16 => .{ .i16 = @truncate(val) },
            .I32 => .{ .i32 = @truncate(val) },
            .I64 => .{ .i64 = val },
            else => unreachable,
        };
    }

    pub fn toI64(self: DataValue) i64 {
        return switch (self) {
            .i8 => |v| @intCast(v),
            .i16 => |v| @intCast(v),
            .i32 => |v| @intCast(v),
            .i64 => |v| v,
            .i128 => |v| @truncate(v),
            else => unreachable,
        };
    }

    pub fn toU64(self: DataValue) u64 {
        return switch (self) {
            .i8 => |v| @bitCast(@as(u8, @bitCast(v))),
            .i16 => |v| @bitCast(@as(u16, @bitCast(v))),
            .i32 => |v| @bitCast(@as(u32, @bitCast(v))),
            .i64 => |v| @bitCast(v),
            .i128 => |v| @truncate(@as(u128, @bitCast(v))),
            else => unreachable,
        };
    }

    pub fn toBool(self: DataValue) bool {
        return self.toI64() != 0;
    }

    pub fn fromF32(val: f32) DataValue {
        return .{ .f32 = val };
    }

    pub fn fromF64(val: f64) DataValue {
        return .{ .f64 = val };
    }

    pub fn toF32(self: DataValue) f32 {
        return switch (self) {
            .f32 => |v| v,
            .f64 => |v| @floatCast(v),
            else => unreachable,
        };
    }

    pub fn toF64(self: DataValue) f64 {
        return switch (self) {
            .f32 => |v| @floatCast(v),
            .f64 => |v| v,
            else => unreachable,
        };
    }

    pub fn isFloat(self: DataValue) bool {
        return switch (self) {
            .f32, .f64 => true,
            else => false,
        };
    }

    pub fn isVector(self: DataValue) bool {
        return switch (self) {
            .i8x16, .i16x8, .i32x4, .i64x2, .f32x4, .f64x2 => true,
            else => false,
        };
    }

    /// Create a vector by splatting a scalar value.
    pub fn splat(ty: Type, scalar: DataValue) DataValue {
        return switch (ty) {
            .I8X16 => .{ .i8x16 = @splat(scalar.i8) },
            .I16X8 => .{ .i16x8 = @splat(scalar.i16) },
            .I32X4 => .{ .i32x4 = @splat(scalar.i32) },
            .I64X2 => .{ .i64x2 = @splat(scalar.i64) },
            .F32X4 => .{ .f32x4 = @splat(scalar.f32) },
            .F64X2 => .{ .f64x2 = @splat(scalar.f64) },
            else => unreachable,
        };
    }

    /// Extract a lane from a vector.
    pub fn extractLane(self: DataValue, lane: u8) DataValue {
        return switch (self) {
            .i8x16 => |v| .{ .i8 = v[lane] },
            .i16x8 => |v| .{ .i16 = v[lane] },
            .i32x4 => |v| .{ .i32 = v[lane] },
            .i64x2 => |v| .{ .i64 = v[lane] },
            .f32x4 => |v| .{ .f32 = v[lane] },
            .f64x2 => |v| .{ .f64 = v[lane] },
            else => unreachable,
        };
    }

    /// Insert a scalar into a vector lane.
    pub fn insertLane(self: DataValue, lane: u8, scalar: DataValue) DataValue {
        return switch (self) {
            .i8x16 => |v| blk: {
                var result = v;
                result[lane] = scalar.i8;
                break :blk .{ .i8x16 = result };
            },
            .i16x8 => |v| blk: {
                var result = v;
                result[lane] = scalar.i16;
                break :blk .{ .i16x8 = result };
            },
            .i32x4 => |v| blk: {
                var result = v;
                result[lane] = scalar.i32;
                break :blk .{ .i32x4 = result };
            },
            .i64x2 => |v| blk: {
                var result = v;
                result[lane] = scalar.i64;
                break :blk .{ .i64x2 = result };
            },
            .f32x4 => |v| blk: {
                var result = v;
                result[lane] = scalar.f32;
                break :blk .{ .f32x4 = result };
            },
            .f64x2 => |v| blk: {
                var result = v;
                result[lane] = scalar.f64;
                break :blk .{ .f64x2 = result };
            },
            else => unreachable,
        };
    }

    /// Vector add.
    pub fn vadd(self: DataValue, other: DataValue) DataValue {
        return switch (self) {
            .i8x16 => |v| .{ .i8x16 = v +% other.i8x16 },
            .i16x8 => |v| .{ .i16x8 = v +% other.i16x8 },
            .i32x4 => |v| .{ .i32x4 = v +% other.i32x4 },
            .i64x2 => |v| .{ .i64x2 = v +% other.i64x2 },
            .f32x4 => |v| .{ .f32x4 = v + other.f32x4 },
            .f64x2 => |v| .{ .f64x2 = v + other.f64x2 },
            else => unreachable,
        };
    }

    /// Vector subtract.
    pub fn vsub(self: DataValue, other: DataValue) DataValue {
        return switch (self) {
            .i8x16 => |v| .{ .i8x16 = v -% other.i8x16 },
            .i16x8 => |v| .{ .i16x8 = v -% other.i16x8 },
            .i32x4 => |v| .{ .i32x4 = v -% other.i32x4 },
            .i64x2 => |v| .{ .i64x2 = v -% other.i64x2 },
            .f32x4 => |v| .{ .f32x4 = v - other.f32x4 },
            .f64x2 => |v| .{ .f64x2 = v - other.f64x2 },
            else => unreachable,
        };
    }

    /// Vector multiply.
    pub fn vmul(self: DataValue, other: DataValue) DataValue {
        return switch (self) {
            .i8x16 => |v| .{ .i8x16 = v *% other.i8x16 },
            .i16x8 => |v| .{ .i16x8 = v *% other.i16x8 },
            .i32x4 => |v| .{ .i32x4 = v *% other.i32x4 },
            .i64x2 => |v| .{ .i64x2 = v *% other.i64x2 },
            .f32x4 => |v| .{ .f32x4 = v * other.f32x4 },
            .f64x2 => |v| .{ .f64x2 = v * other.f64x2 },
            else => unreachable,
        };
    }

    /// Vector bitwise AND.
    pub fn vand(self: DataValue, other: DataValue) DataValue {
        return switch (self) {
            .i8x16 => |v| .{ .i8x16 = v & other.i8x16 },
            .i16x8 => |v| .{ .i16x8 = v & other.i16x8 },
            .i32x4 => |v| .{ .i32x4 = v & other.i32x4 },
            .i64x2 => |v| .{ .i64x2 = v & other.i64x2 },
            else => unreachable,
        };
    }

    /// Vector bitwise OR.
    pub fn vor(self: DataValue, other: DataValue) DataValue {
        return switch (self) {
            .i8x16 => |v| .{ .i8x16 = v | other.i8x16 },
            .i16x8 => |v| .{ .i16x8 = v | other.i16x8 },
            .i32x4 => |v| .{ .i32x4 = v | other.i32x4 },
            .i64x2 => |v| .{ .i64x2 = v | other.i64x2 },
            else => unreachable,
        };
    }

    /// Vector bitwise XOR.
    pub fn vxor(self: DataValue, other: DataValue) DataValue {
        return switch (self) {
            .i8x16 => |v| .{ .i8x16 = v ^ other.i8x16 },
            .i16x8 => |v| .{ .i16x8 = v ^ other.i16x8 },
            .i32x4 => |v| .{ .i32x4 = v ^ other.i32x4 },
            .i64x2 => |v| .{ .i64x2 = v ^ other.i64x2 },
            else => unreachable,
        };
    }

    /// Vector negation.
    pub fn vneg(self: DataValue) DataValue {
        return switch (self) {
            .i8x16 => |v| .{ .i8x16 = -%v },
            .i16x8 => |v| .{ .i16x8 = -%v },
            .i32x4 => |v| .{ .i32x4 = -%v },
            .i64x2 => |v| .{ .i64x2 = -%v },
            .f32x4 => |v| .{ .f32x4 = -v },
            .f64x2 => |v| .{ .f64x2 = -v },
            else => unreachable,
        };
    }

    /// Vector bitwise NOT.
    pub fn vnot(self: DataValue) DataValue {
        return switch (self) {
            .i8x16 => |v| .{ .i8x16 = ~v },
            .i16x8 => |v| .{ .i16x8 = ~v },
            .i32x4 => |v| .{ .i32x4 = ~v },
            .i64x2 => |v| .{ .i64x2 = ~v },
            else => unreachable,
        };
    }

    /// Create a zero vector.
    pub fn vzero(ty: Type) DataValue {
        return switch (ty) {
            .I8X16 => .{ .i8x16 = @splat(0) },
            .I16X8 => .{ .i16x8 = @splat(0) },
            .I32X4 => .{ .i32x4 = @splat(0) },
            .I64X2 => .{ .i64x2 = @splat(0) },
            .F32X4 => .{ .f32x4 = @splat(0.0) },
            .F64X2 => .{ .f64x2 = @splat(0.0) },
            else => unreachable,
        };
    }

    /// Create vector from bytes.
    pub fn fromBytes(ty: Type, bytes: [16]u8) DataValue {
        return switch (ty) {
            .I8X16 => .{ .i8x16 = @bitCast(bytes) },
            .I16X8 => .{ .i16x8 = @bitCast(bytes) },
            .I32X4 => .{ .i32x4 = @bitCast(bytes) },
            .I64X2 => .{ .i64x2 = @bitCast(bytes) },
            .F32X4 => .{ .f32x4 = @bitCast(bytes) },
            .F64X2 => .{ .f64x2 = @bitCast(bytes) },
            else => unreachable,
        };
    }

    /// Convert vector to bytes.
    pub fn toBytes(self: DataValue) [16]u8 {
        return switch (self) {
            .i8x16 => |v| @bitCast(v),
            .i16x8 => |v| @bitCast(v),
            .i32x4 => |v| @bitCast(v),
            .i64x2 => |v| @bitCast(v),
            .f32x4 => |v| @bitCast(v),
            .f64x2 => |v| @bitCast(v),
            else => unreachable,
        };
    }
};

pub const InterpError = error{
    UnknownOpcode,
    TypeMismatch,
    OutOfBounds,
    DivisionByZero,
    StackUnderflow,
    UnknownValue,
    UnknownBlock,
    NoEntryBlock,
    MaxStepsExceeded,
    OutOfMemory,
};

/// Control flow result from executing an instruction.
pub const ControlFlow = union(enum) {
    /// Continue to next instruction
    cont,
    /// Jump to a block with arguments
    jump: struct { block: Block, args: []const DataValue },
    /// Return from function
    ret: []const DataValue,
    /// Trap occurred
    trap: []const u8,
};

/// Memory model for the interpreter.
pub const Memory = struct {
    heap: []u8,
    stack_slots: std.ArrayList([]u8),
    alloc: Allocator,

    const HEAP_SIZE = 64 * 1024; // 64KB heap

    pub fn init(alloc: Allocator) !Memory {
        const heap = try alloc.alloc(u8, HEAP_SIZE);
        @memset(heap, 0);
        return .{
            .heap = heap,
            .stack_slots = std.ArrayList([]u8).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Memory) void {
        for (self.stack_slots.items) |slot| {
            self.alloc.free(slot);
        }
        self.stack_slots.deinit();
        self.alloc.free(self.heap);
    }

    pub fn allocStackSlot(self: *Memory, size: usize) !usize {
        const slot = try self.alloc.alloc(u8, size);
        @memset(slot, 0);
        try self.stack_slots.append(slot);
        return self.stack_slots.items.len - 1;
    }

    pub fn getStackSlot(self: *const Memory, idx: usize) ?[]u8 {
        if (idx >= self.stack_slots.items.len) return null;
        return self.stack_slots.items[idx];
    }

    pub fn load(self: *const Memory, addr: u64, size: usize) !DataValue {
        if (addr >= HEAP_SIZE or addr + size > HEAP_SIZE) return error.OutOfBounds;
        const slice = self.heap[@intCast(addr)..][0..size];
        return switch (size) {
            1 => .{ .i8 = @bitCast(slice[0]) },
            2 => .{ .i16 = @bitCast(slice[0..2].*) },
            4 => .{ .i32 = @bitCast(slice[0..4].*) },
            8 => .{ .i64 = @bitCast(slice[0..8].*) },
            else => error.TypeMismatch,
        };
    }

    pub fn store(self: *Memory, addr: u64, val: DataValue) !void {
        const size: usize = switch (val) {
            .i8 => 1,
            .i16 => 2,
            .i32 => 4,
            .i64 => 8,
            .i128 => 16,
            .f32 => 4,
            .f64 => 8,
        };
        if (addr >= HEAP_SIZE or addr + size > HEAP_SIZE) return error.OutOfBounds;
        const slice = self.heap[@intCast(addr)..][0..size];
        switch (val) {
            .i8 => |v| slice[0] = @bitCast(v),
            .i16 => |v| slice[0..2].* = @bitCast(v),
            .i32 => |v| slice[0..4].* = @bitCast(v),
            .i64 => |v| slice[0..8].* = @bitCast(v),
            .f32 => |v| slice[0..4].* = @bitCast(v),
            .f64 => |v| slice[0..8].* = @bitCast(v),
            .i128 => |v| slice[0..16].* = @bitCast(v),
        }
    }
};

/// Frame for a function call.
pub const Frame = struct {
    func: *const Function,
    values: std.AutoHashMap(Value, DataValue),
    stack_base: std.AutoHashMap(u32, usize), // stack slot index -> memory slot index
    alloc: Allocator,

    pub fn init(alloc: Allocator, func: *const Function) Frame {
        return .{
            .func = func,
            .values = std.AutoHashMap(Value, DataValue).init(alloc),
            .stack_base = std.AutoHashMap(u32, usize).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Frame) void {
        self.values.deinit();
        self.stack_base.deinit();
    }

    pub fn get(self: *const Frame, val: Value) ?DataValue {
        return self.values.get(val);
    }

    pub fn set(self: *Frame, val: Value, data: DataValue) !void {
        try self.values.put(val, data);
    }
};

/// IR interpreter for Hoist functions.
pub const Interpreter = struct {
    alloc: Allocator,
    frame: ?Frame,
    memory: ?Memory,
    max_steps: usize,
    steps: usize,

    pub fn init(alloc: Allocator) Interpreter {
        return .{
            .alloc = alloc,
            .frame = null,
            .memory = null,
            .max_steps = 1_000_000,
            .steps = 0,
        };
    }

    pub fn deinit(self: *Interpreter) void {
        if (self.frame) |*f| f.deinit();
        if (self.memory) |*m| m.deinit();
    }

    /// Execute a function with the given arguments.
    pub fn call(self: *Interpreter, func: *const Function, args: []const DataValue) InterpError![]const DataValue {
        self.frame = Frame.init(self.alloc, func);
        self.memory = Memory.init(self.alloc) catch return error.OutOfMemory;
        errdefer if (self.frame) |*f| f.deinit();

        // Get entry block
        const entry = func.layout.entryBlock() orelse return error.NoEntryBlock;

        // Bind block parameters to arguments
        const params = func.dfg.getBlockParams(entry);
        if (params.len != args.len) return error.TypeMismatch;
        for (params, args) |param, arg| {
            try self.frame.?.set(param, arg);
        }

        // Execute starting from entry block
        return self.executeBlock(entry);
    }

    fn executeBlock(self: *Interpreter, block: Block) InterpError![]const DataValue {
        const func = self.frame.?.func;
        var cur_block = block;

        while (true) {
            // Execute all instructions in block
            var inst_iter = func.layout.blockInsts(cur_block);
            while (inst_iter.next()) |inst| {
                self.steps += 1;
                if (self.steps > self.max_steps) return error.MaxStepsExceeded;

                const result = try self.executeInst(inst);
                switch (result) {
                    .cont => {},
                    .jump => |j| {
                        // Bind jump arguments to block parameters
                        const params = func.dfg.getBlockParams(j.block);
                        if (params.len != j.args.len) return error.TypeMismatch;
                        for (params, j.args) |param, arg| {
                            try self.frame.?.set(param, arg);
                        }
                        cur_block = j.block;
                        break;
                    },
                    .ret => |vals| return vals,
                    .trap => return error.OutOfBounds,
                }
            } else {
                // Fall through - shouldn't happen in well-formed IR
                return error.UnknownBlock;
            }
        }
    }

    fn executeInst(self: *Interpreter, inst: Inst) InterpError!ControlFlow {
        const func = self.frame.?.func;
        const data = func.dfg.getInstData(inst) orelse return error.UnknownOpcode;

        return switch (data.*) {
            .unary_imm => |u| self.execUnaryImm(inst, u),
            .binary => |b| self.execBinary(inst, b),
            .binary_imm64 => |b| self.execBinaryImm64(inst, b),
            .unary => |u| self.execUnary(inst, u),
            .int_compare => |c| self.execIntCompare(inst, c),
            .float_compare => |c| self.execFloatCompare(inst, c),
            .branch => |b| self.execBranch(b),
            .brif => |b| self.execBrif(b),
            .jump => |j| self.execJump(j),
            .ternary => |t| self.execTernary(inst, t),
            .load => |l| self.execLoad(inst, l),
            .store => |s| self.execStore(s),
            .stack_load => |s| self.execStackLoad(inst, s),
            .stack_store => |s| self.execStackStore(s),
            .shuffle => |s| self.execShuffle(inst, s),
            .insert_lane => |s| self.execInsertLane(inst, s),
            .extract_lane => |s| self.execExtractLane(inst, s),
            else => error.UnknownOpcode,
        };
    }

    fn execUnaryImm(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;
        switch (data.opcode) {
            .iconst => {
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                const val = DataValue.fromI64(ty, @bitCast(data.imm.bits()));
                try self.frame.?.set(result, val);
                return .cont;
            },
            else => return error.UnknownOpcode,
        }
    }

    fn execBinary(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;
        const lhs = self.frame.?.get(data.args[0]) orelse return error.UnknownValue;
        const rhs = self.frame.?.get(data.args[1]) orelse return error.UnknownValue;

        const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
        const ty = func.dfg.valueType(result);

        const val: DataValue = switch (data.opcode) {
            .iadd => if (ty.isVector()) lhs.vadd(rhs) else DataValue.fromI64(ty, lhs.toI64() +% rhs.toI64()),
            .isub => if (ty.isVector()) lhs.vsub(rhs) else DataValue.fromI64(ty, lhs.toI64() -% rhs.toI64()),
            .imul => if (ty.isVector()) lhs.vmul(rhs) else DataValue.fromI64(ty, lhs.toI64() *% rhs.toI64()),
            .sdiv => blk: {
                const r = rhs.toI64();
                if (r == 0) return error.DivisionByZero;
                break :blk DataValue.fromI64(ty, @divTrunc(lhs.toI64(), r));
            },
            .udiv => blk: {
                const r = rhs.toU64();
                if (r == 0) return error.DivisionByZero;
                break :blk DataValue.fromI64(ty, @bitCast(@divTrunc(lhs.toU64(), r)));
            },
            .band => if (ty.isVector()) lhs.vand(rhs) else DataValue.fromI64(ty, lhs.toI64() & rhs.toI64()),
            .bor => if (ty.isVector()) lhs.vor(rhs) else DataValue.fromI64(ty, lhs.toI64() | rhs.toI64()),
            .bxor => if (ty.isVector()) lhs.vxor(rhs) else DataValue.fromI64(ty, lhs.toI64() ^ rhs.toI64()),
            .ishl => blk: {
                const shift: u6 = @truncate(rhs.toU64());
                break :blk DataValue.fromI64(ty, lhs.toI64() << shift);
            },
            .ushr => blk: {
                const shift: u6 = @truncate(rhs.toU64());
                break :blk DataValue.fromI64(ty, @bitCast(lhs.toU64() >> shift));
            },
            .sshr => blk: {
                const shift: u6 = @truncate(rhs.toU64());
                break :blk DataValue.fromI64(ty, lhs.toI64() >> shift);
            },
            .rotl => blk: {
                const bits: u6 = switch (ty) {
                    .I8 => 8,
                    .I16 => 16,
                    .I32 => 32,
                    .I64 => 64,
                    else => return error.TypeMismatch,
                };
                const shift: u6 = @truncate(rhs.toU64() % bits);
                const v = lhs.toU64();
                break :blk DataValue.fromI64(ty, @bitCast((v << shift) | (v >> (bits - shift))));
            },
            .rotr => blk: {
                const bits: u6 = switch (ty) {
                    .I8 => 8,
                    .I16 => 16,
                    .I32 => 32,
                    .I64 => 64,
                    else => return error.TypeMismatch,
                };
                const shift: u6 = @truncate(rhs.toU64() % bits);
                const v = lhs.toU64();
                break :blk DataValue.fromI64(ty, @bitCast((v >> shift) | (v << (bits - shift))));
            },
            // Floating-point operations
            .fadd => blk: {
                if (ty == .F32) {
                    break :blk DataValue.fromF32(lhs.toF32() + rhs.toF32());
                } else {
                    break :blk DataValue.fromF64(lhs.toF64() + rhs.toF64());
                }
            },
            .fsub => blk: {
                if (ty == .F32) {
                    break :blk DataValue.fromF32(lhs.toF32() - rhs.toF32());
                } else {
                    break :blk DataValue.fromF64(lhs.toF64() - rhs.toF64());
                }
            },
            .fmul => blk: {
                if (ty == .F32) {
                    break :blk DataValue.fromF32(lhs.toF32() * rhs.toF32());
                } else {
                    break :blk DataValue.fromF64(lhs.toF64() * rhs.toF64());
                }
            },
            .fdiv => blk: {
                if (ty == .F32) {
                    break :blk DataValue.fromF32(lhs.toF32() / rhs.toF32());
                } else {
                    break :blk DataValue.fromF64(lhs.toF64() / rhs.toF64());
                }
            },
            .fmin => blk: {
                if (ty == .F32) {
                    break :blk DataValue.fromF32(@min(lhs.toF32(), rhs.toF32()));
                } else {
                    break :blk DataValue.fromF64(@min(lhs.toF64(), rhs.toF64()));
                }
            },
            .fmax => blk: {
                if (ty == .F32) {
                    break :blk DataValue.fromF32(@max(lhs.toF32(), rhs.toF32()));
                } else {
                    break :blk DataValue.fromF64(@max(lhs.toF64(), rhs.toF64()));
                }
            },
            .fcopysign => blk: {
                if (ty == .F32) {
                    break :blk DataValue.fromF32(std.math.copysign(lhs.toF32(), rhs.toF32()));
                } else {
                    break :blk DataValue.fromF64(std.math.copysign(lhs.toF64(), rhs.toF64()));
                }
            },
            else => return error.UnknownOpcode,
        };

        try self.frame.?.set(result, val);
        return .cont;
    }

    fn execBinaryImm64(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;
        const lhs = self.frame.?.get(data.arg) orelse return error.UnknownValue;
        const rhs_val: i64 = @bitCast(data.imm.bits());

        const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
        const ty = func.dfg.valueType(result);

        const val: DataValue = switch (data.opcode) {
            .iadd_imm => DataValue.fromI64(ty, lhs.toI64() +% rhs_val),
            .isub_imm => DataValue.fromI64(ty, lhs.toI64() -% rhs_val),
            .imul_imm => DataValue.fromI64(ty, lhs.toI64() *% rhs_val),
            .band_imm => DataValue.fromI64(ty, lhs.toI64() & rhs_val),
            .bor_imm => DataValue.fromI64(ty, lhs.toI64() | rhs_val),
            .bxor_imm => DataValue.fromI64(ty, lhs.toI64() ^ rhs_val),
            else => return error.UnknownOpcode,
        };

        try self.frame.?.set(result, val);
        return .cont;
    }

    fn execUnary(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;

        switch (data.opcode) {
            .@"return" => {
                if (data.arg) |arg| {
                    const val = self.frame.?.get(arg) orelse return error.UnknownValue;
                    const vals = try self.alloc.alloc(DataValue, 1);
                    vals[0] = val;
                    return .{ .ret = vals };
                } else {
                    return .{ .ret = &.{} };
                }
            },
            .bnot => {
                const arg = self.frame.?.get(data.arg.?) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                try self.frame.?.set(result, DataValue.fromI64(ty, ~arg.toI64()));
                return .cont;
            },
            .ineg => {
                const arg = self.frame.?.get(data.arg.?) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                try self.frame.?.set(result, DataValue.fromI64(ty, -%arg.toI64()));
                return .cont;
            },
            .fneg => {
                const arg = self.frame.?.get(data.arg.?) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                if (ty == .F32) {
                    try self.frame.?.set(result, DataValue.fromF32(-arg.toF32()));
                } else {
                    try self.frame.?.set(result, DataValue.fromF64(-arg.toF64()));
                }
                return .cont;
            },
            .fabs => {
                const arg = self.frame.?.get(data.arg.?) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                if (ty == .F32) {
                    try self.frame.?.set(result, DataValue.fromF32(@abs(arg.toF32())));
                } else {
                    try self.frame.?.set(result, DataValue.fromF64(@abs(arg.toF64())));
                }
                return .cont;
            },
            .sqrt => {
                const arg = self.frame.?.get(data.arg.?) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                if (ty == .F32) {
                    try self.frame.?.set(result, DataValue.fromF32(@sqrt(arg.toF32())));
                } else {
                    try self.frame.?.set(result, DataValue.fromF64(@sqrt(arg.toF64())));
                }
                return .cont;
            },
            .ceil => {
                const arg = self.frame.?.get(data.arg.?) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                if (ty == .F32) {
                    try self.frame.?.set(result, DataValue.fromF32(@ceil(arg.toF32())));
                } else {
                    try self.frame.?.set(result, DataValue.fromF64(@ceil(arg.toF64())));
                }
                return .cont;
            },
            .floor => {
                const arg = self.frame.?.get(data.arg.?) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                if (ty == .F32) {
                    try self.frame.?.set(result, DataValue.fromF32(@floor(arg.toF32())));
                } else {
                    try self.frame.?.set(result, DataValue.fromF64(@floor(arg.toF64())));
                }
                return .cont;
            },
            .trunc => {
                const arg = self.frame.?.get(data.arg.?) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                if (ty == .F32) {
                    try self.frame.?.set(result, DataValue.fromF32(@trunc(arg.toF32())));
                } else {
                    try self.frame.?.set(result, DataValue.fromF64(@trunc(arg.toF64())));
                }
                return .cont;
            },
            .nearest => {
                const arg = self.frame.?.get(data.arg.?) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                if (ty == .F32) {
                    try self.frame.?.set(result, DataValue.fromF32(@round(arg.toF32())));
                } else {
                    try self.frame.?.set(result, DataValue.fromF64(@round(arg.toF64())));
                }
                return .cont;
            },
            .splat => {
                const arg = self.frame.?.get(data.arg.?) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                const ty = func.dfg.valueType(result);
                try self.frame.?.set(result, DataValue.splat(ty, arg));
                return .cont;
            },
            else => return error.UnknownOpcode,
        }
    }

    fn execIntCompare(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;
        const lhs = self.frame.?.get(data.args[0]) orelse return error.UnknownValue;
        const rhs = self.frame.?.get(data.args[1]) orelse return error.UnknownValue;

        const cmp: bool = switch (data.cond) {
            .eq => lhs.toI64() == rhs.toI64(),
            .ne => lhs.toI64() != rhs.toI64(),
            .slt => lhs.toI64() < rhs.toI64(),
            .sle => lhs.toI64() <= rhs.toI64(),
            .sgt => lhs.toI64() > rhs.toI64(),
            .sge => lhs.toI64() >= rhs.toI64(),
            .ult => lhs.toU64() < rhs.toU64(),
            .ule => lhs.toU64() <= rhs.toU64(),
            .ugt => lhs.toU64() > rhs.toU64(),
            .uge => lhs.toU64() >= rhs.toU64(),
        };

        const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
        try self.frame.?.set(result, DataValue{ .i32 = if (cmp) 1 else 0 });
        return .cont;
    }

    fn execFloatCompare(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;
        const lhs = self.frame.?.get(data.args[0]) orelse return error.UnknownValue;
        const rhs = self.frame.?.get(data.args[1]) orelse return error.UnknownValue;

        const lf = lhs.toF64();
        const rf = rhs.toF64();

        const FloatCC = root.condcodes.FloatCC;
        const cmp: bool = switch (data.cond) {
            FloatCC.ordered => !std.math.isNan(lf) and !std.math.isNan(rf),
            FloatCC.unordered => std.math.isNan(lf) or std.math.isNan(rf),
            FloatCC.eq => lf == rf,
            FloatCC.ne => lf != rf,
            FloatCC.lt => lf < rf,
            FloatCC.le => lf <= rf,
            FloatCC.gt => lf > rf,
            FloatCC.ge => lf >= rf,
            FloatCC.uno => std.math.isNan(lf) or std.math.isNan(rf),
            FloatCC.ord => !std.math.isNan(lf) and !std.math.isNan(rf),
            else => return error.UnknownOpcode,
        };

        const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
        try self.frame.?.set(result, DataValue{ .i32 = if (cmp) 1 else 0 });
        return .cont;
    }

    fn execBranch(self: *Interpreter, data: anytype) InterpError!ControlFlow {
        _ = self;
        return .{ .jump = .{ .block = data.dest, .args = &.{} } };
    }

    fn execBrif(self: *Interpreter, data: anytype) InterpError!ControlFlow {
        const cond = self.frame.?.get(data.cond) orelse return error.UnknownValue;
        const dest = if (cond.toBool()) data.then_dest else data.else_dest;
        return .{ .jump = .{ .block = dest, .args = &.{} } };
    }

    fn execJump(self: *Interpreter, data: anytype) InterpError!ControlFlow {
        _ = self;
        return .{ .jump = .{ .block = data.dest, .args = &.{} } };
    }

    fn execTernary(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;

        switch (data.opcode) {
            .select => {
                const cond = self.frame.?.get(data.args[0]) orelse return error.UnknownValue;
                const if_true = self.frame.?.get(data.args[1]) orelse return error.UnknownValue;
                const if_false = self.frame.?.get(data.args[2]) orelse return error.UnknownValue;
                const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
                try self.frame.?.set(result, if (cond.toBool()) if_true else if_false);
                return .cont;
            },
            else => return error.UnknownOpcode,
        }
    }

    fn execLoad(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;
        const addr_val = self.frame.?.get(data.addr) orelse return error.UnknownValue;
        const addr = addr_val.toU64() + data.offset;

        const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
        const ty = func.dfg.valueType(result);
        const size: usize = switch (ty) {
            .I8 => 1,
            .I16 => 2,
            .I32 => 4,
            .I64 => 8,
            else => return error.TypeMismatch,
        };

        const val = self.memory.?.load(addr, size) catch return error.OutOfBounds;
        try self.frame.?.set(result, val);
        return .cont;
    }

    fn execStore(self: *Interpreter, data: anytype) InterpError!ControlFlow {
        const addr_val = self.frame.?.get(data.addr) orelse return error.UnknownValue;
        const addr = addr_val.toU64() + data.offset;
        const val = self.frame.?.get(data.value) orelse return error.UnknownValue;

        self.memory.?.store(addr, val) catch return error.OutOfBounds;
        return .cont;
    }

    fn execStackLoad(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;
        const slot_idx = self.frame.?.stack_base.get(data.slot.index) orelse return error.OutOfBounds;
        const slot = self.memory.?.getStackSlot(slot_idx) orelse return error.OutOfBounds;

        const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
        const ty = func.dfg.valueType(result);
        const offset: usize = @intCast(data.offset);
        const size: usize = switch (ty) {
            .I8 => 1,
            .I16 => 2,
            .I32 => 4,
            .I64 => 8,
            else => return error.TypeMismatch,
        };

        if (offset + size > slot.len) return error.OutOfBounds;
        const val: DataValue = switch (size) {
            1 => .{ .i8 = @bitCast(slot[offset]) },
            2 => .{ .i16 = @bitCast(slot[offset..][0..2].*) },
            4 => .{ .i32 = @bitCast(slot[offset..][0..4].*) },
            8 => .{ .i64 = @bitCast(slot[offset..][0..8].*) },
            else => unreachable,
        };

        try self.frame.?.set(result, val);
        return .cont;
    }

    fn execStackStore(self: *Interpreter, data: anytype) InterpError!ControlFlow {
        const slot_idx = self.frame.?.stack_base.get(data.slot.index) orelse return error.OutOfBounds;
        const slot = self.memory.?.getStackSlot(slot_idx) orelse return error.OutOfBounds;

        const val = self.frame.?.get(data.value) orelse return error.UnknownValue;
        const offset: usize = @intCast(data.offset);
        const size: usize = switch (val) {
            .i8 => 1,
            .i16 => 2,
            .i32 => 4,
            .i64 => 8,
            .i128 => 16,
            .f32 => 4,
            .f64 => 8,
            .i8x16, .i16x8, .i32x4, .i64x2, .f32x4, .f64x2 => 16,
        };

        if (offset + size > slot.len) return error.OutOfBounds;
        switch (val) {
            .i8 => |v| slot[offset] = @bitCast(v),
            .i16 => |v| slot[offset..][0..2].* = @bitCast(v),
            .i32 => |v| slot[offset..][0..4].* = @bitCast(v),
            .i64 => |v| slot[offset..][0..8].* = @bitCast(v),
            .f32 => |v| slot[offset..][0..4].* = @bitCast(v),
            .f64 => |v| slot[offset..][0..8].* = @bitCast(v),
            .i128 => |v| slot[offset..][0..16].* = @bitCast(v),
            .i8x16 => |v| slot[offset..][0..16].* = @bitCast(v),
            .i16x8 => |v| slot[offset..][0..16].* = @bitCast(v),
            .i32x4 => |v| slot[offset..][0..16].* = @bitCast(v),
            .i64x2 => |v| slot[offset..][0..16].* = @bitCast(v),
            .f32x4 => |v| slot[offset..][0..16].* = @bitCast(v),
            .f64x2 => |v| slot[offset..][0..16].* = @bitCast(v),
        }
        return .cont;
    }

    fn execShuffle(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;
        const lhs = self.frame.?.get(data.args[0]) orelse return error.UnknownValue;
        const rhs = self.frame.?.get(data.args[1]) orelse return error.UnknownValue;

        // Get source bytes
        const lhs_bytes = lhs.toBytes();
        const rhs_bytes = rhs.toBytes();

        // Apply shuffle mask
        const mask = data.mask.bytes();
        var result_bytes: [16]u8 = undefined;
        for (0..16) |i| {
            const idx = mask[i];
            result_bytes[i] = if (idx < 16) lhs_bytes[idx] else rhs_bytes[idx - 16];
        }

        const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
        const ty = func.dfg.valueType(result);
        try self.frame.?.set(result, DataValue.fromBytes(ty, result_bytes));
        return .cont;
    }

    fn execInsertLane(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;
        // insert_lane uses ternary data: (vector, scalar, lane_imm)
        const vec = self.frame.?.get(data.args[0]) orelse return error.UnknownValue;
        const scalar = self.frame.?.get(data.args[1]) orelse return error.UnknownValue;
        const lane = data.imm;

        const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
        try self.frame.?.set(result, vec.insertLane(lane, scalar));
        return .cont;
    }

    fn execExtractLane(self: *Interpreter, inst: Inst, data: anytype) InterpError!ControlFlow {
        const func = self.frame.?.func;
        const vec = self.frame.?.get(data.arg) orelse return error.UnknownValue;
        const lane = data.lane;

        const result = func.dfg.firstResult(inst) orelse return error.UnknownValue;
        try self.frame.?.set(result, vec.extractLane(lane));
        return .cont;
    }
};

const testing = std.testing;

test "interpret iconst" {
    const alloc = testing.allocator;

    const sig = root.signature.Signature.init(alloc, .fast);
    var func = try Function.init(alloc, "test", sig);
    defer func.deinit();

    var builder = try root.builder.FunctionBuilder.init(alloc, &func);
    const b0 = try builder.createBlock();
    builder.switchToBlock(b0);
    const v0 = try builder.iconst(Type.I32, 42);
    try builder.ret(v0);

    var interp = Interpreter.init(alloc);
    defer interp.deinit();

    const result = try interp.call(&func, &.{});
    defer alloc.free(result);

    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expectEqual(@as(i32, 42), result[0].i32);
}

test "interpret iadd" {
    const alloc = testing.allocator;

    var sig = root.signature.Signature.init(alloc, .fast);
    // Note: sig ownership transferred to func, func.deinit() frees it
    try sig.params.append(alloc, root.signature.AbiParam.new(Type.I32));
    try sig.params.append(alloc, root.signature.AbiParam.new(Type.I32));
    try sig.returns.append(alloc, root.signature.AbiParam.new(Type.I32));

    var func = try Function.init(alloc, "add", sig);
    defer func.deinit();

    var builder = try root.builder.FunctionBuilder.init(alloc, &func);
    const b0 = try builder.createBlock();
    builder.switchToBlock(b0);
    const v0 = try builder.appendBlockParam(b0, Type.I32);
    const v1 = try builder.appendBlockParam(b0, Type.I32);
    const v2 = try builder.iadd(Type.I32, v0, v1);
    try builder.ret(v2);

    var interp = Interpreter.init(alloc);
    defer interp.deinit();

    const args = [_]DataValue{ .{ .i32 = 10 }, .{ .i32 = 32 } };
    const result = try interp.call(&func, &args);
    defer alloc.free(result);

    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expectEqual(@as(i32, 42), result[0].i32);
}

test "interpret icmp" {
    const alloc = testing.allocator;

    var sig = root.signature.Signature.init(alloc, .fast);
    // Note: sig ownership transferred to func, func.deinit() frees it
    try sig.params.append(alloc, root.signature.AbiParam.new(Type.I32));
    try sig.params.append(alloc, root.signature.AbiParam.new(Type.I32));
    try sig.returns.append(alloc, root.signature.AbiParam.new(Type.I32));

    var func = try Function.init(alloc, "cmp", sig);
    defer func.deinit();

    var builder = try root.builder.FunctionBuilder.init(alloc, &func);
    const b0 = try builder.createBlock();
    builder.switchToBlock(b0);
    const v0 = try builder.appendBlockParam(b0, Type.I32);
    const v1 = try builder.appendBlockParam(b0, Type.I32);
    const v2 = try builder.icmp(Type.I32, IntCC.slt, v0, v1);
    try builder.ret(v2);

    var interp = Interpreter.init(alloc);
    defer interp.deinit();

    // 10 < 20 = true
    const args1 = [_]DataValue{ .{ .i32 = 10 }, .{ .i32 = 20 } };
    const result1 = try interp.call(&func, &args1);
    defer alloc.free(result1);
    try testing.expectEqual(@as(i32, 1), result1[0].i32);

    // 20 < 10 = false
    interp.steps = 0;
    const args2 = [_]DataValue{ .{ .i32 = 20 }, .{ .i32 = 10 } };
    const result2 = try interp.call(&func, &args2);
    defer alloc.free(result2);
    try testing.expectEqual(@as(i32, 0), result2[0].i32);
}

test "memory load/store" {
    var mem = try Memory.init(testing.allocator);
    defer mem.deinit();

    // Store and load i32
    try mem.store(100, .{ .i32 = 0x12345678 });
    const val = try mem.load(100, 4);
    try testing.expectEqual(@as(i32, 0x12345678), val.i32);

    // Store and load i64
    try mem.store(200, .{ .i64 = 0x123456789ABCDEF0 });
    const val2 = try mem.load(200, 8);
    try testing.expectEqual(@as(i64, 0x123456789ABCDEF0), val2.i64);
}

test "memory stack slots" {
    var mem = try Memory.init(testing.allocator);
    defer mem.deinit();

    const slot = try mem.allocStackSlot(16);
    const slot_data = mem.getStackSlot(slot).?;

    // Write to slot
    slot_data[0..4].* = @bitCast(@as(i32, 42));

    // Read back
    const val: i32 = @bitCast(slot_data[0..4].*);
    try testing.expectEqual(@as(i32, 42), val);
}

test "DataValue floating-point" {
    // f32
    const f32_val = DataValue.fromF32(3.14);
    try testing.expectApproxEqRel(@as(f32, 3.14), f32_val.toF32(), 0.001);

    // f64
    const f64_val = DataValue.fromF64(2.718281828);
    try testing.expectApproxEqRel(@as(f64, 2.718281828), f64_val.toF64(), 0.0000001);

    // isFloat
    try testing.expect(f32_val.isFloat());
    try testing.expect(f64_val.isFloat());
    try testing.expect(!(DataValue{ .i32 = 42 }).isFloat());
}

test "FP binary operations" {
    // Test fadd, fsub, fmul, fdiv on f64
    const a = DataValue.fromF64(10.0);
    const b = DataValue.fromF64(3.0);

    // fadd
    const sum = DataValue.fromF64(a.toF64() + b.toF64());
    try testing.expectApproxEqRel(@as(f64, 13.0), sum.toF64(), 0.001);

    // fsub
    const diff = DataValue.fromF64(a.toF64() - b.toF64());
    try testing.expectApproxEqRel(@as(f64, 7.0), diff.toF64(), 0.001);

    // fmul
    const prod = DataValue.fromF64(a.toF64() * b.toF64());
    try testing.expectApproxEqRel(@as(f64, 30.0), prod.toF64(), 0.001);

    // fdiv
    const quot = DataValue.fromF64(a.toF64() / b.toF64());
    try testing.expectApproxEqRel(@as(f64, 3.333), quot.toF64(), 0.001);
}

test "FP unary operations" {
    // fneg
    const neg = DataValue.fromF64(-@as(f64, 5.0));
    try testing.expectApproxEqRel(@as(f64, -5.0), neg.toF64(), 0.001);

    // fabs
    const abs_val = DataValue.fromF64(@abs(@as(f64, -7.5)));
    try testing.expectApproxEqRel(@as(f64, 7.5), abs_val.toF64(), 0.001);

    // sqrt
    const sqrt_val = DataValue.fromF64(@sqrt(@as(f64, 16.0)));
    try testing.expectApproxEqRel(@as(f64, 4.0), sqrt_val.toF64(), 0.001);

    // ceil
    const ceil_val = DataValue.fromF64(@ceil(@as(f64, 2.3)));
    try testing.expectApproxEqRel(@as(f64, 3.0), ceil_val.toF64(), 0.001);

    // floor
    const floor_val = DataValue.fromF64(@floor(@as(f64, 2.7)));
    try testing.expectApproxEqRel(@as(f64, 2.0), floor_val.toF64(), 0.001);
}

test "interpret branch" {
    const alloc = testing.allocator;

    var sig = root.signature.Signature.init(alloc, .fast);
    // Note: sig ownership transferred to func, func.deinit() frees it
    try sig.params.append(alloc, root.signature.AbiParam.new(Type.I32));
    try sig.returns.append(alloc, root.signature.AbiParam.new(Type.I32));

    var func = try Function.init(alloc, "abs", sig);
    defer func.deinit();

    var builder = try root.builder.FunctionBuilder.init(alloc, &func);
    const b0 = try builder.createBlock();
    const b_pos = try builder.createBlock();
    const b_neg = try builder.createBlock();

    builder.switchToBlock(b0);
    const v0 = try builder.appendBlockParam(b0, Type.I32);
    const zero = try builder.iconst(Type.I32, 0);
    const cmp = try builder.icmp(Type.I32, IntCC.slt, v0, zero);
    try builder.brif(cmp, b_neg, b_pos);

    builder.switchToBlock(b_pos);
    try builder.ret(v0);

    builder.switchToBlock(b_neg);
    const neg_v0 = try builder.isub(Type.I32, zero, v0);
    try builder.ret(neg_v0);

    var interp = Interpreter.init(alloc);
    defer interp.deinit();

    // Positive input
    const args1 = [_]DataValue{.{ .i32 = 5 }};
    const result1 = try interp.call(&func, &args1);
    defer alloc.free(result1);
    try testing.expectEqual(@as(i32, 5), result1[0].i32);

    // Negative input
    interp.steps = 0;
    if (interp.frame) |*f| f.deinit();
    interp.frame = null;
    if (interp.memory) |*m| m.deinit();
    interp.memory = null;

    const args2 = [_]DataValue{.{ .i32 = -7 }};
    const result2 = try interp.call(&func, &args2);
    defer alloc.free(result2);
    try testing.expectEqual(@as(i32, 7), result2[0].i32);
}

test "interpret bitwise ops" {
    const alloc = testing.allocator;

    var sig = root.signature.Signature.init(alloc, .fast);
    // Note: sig ownership transferred to func, func.deinit() frees it
    try sig.params.append(alloc, root.signature.AbiParam.new(Type.I32));
    try sig.params.append(alloc, root.signature.AbiParam.new(Type.I32));
    try sig.returns.append(alloc, root.signature.AbiParam.new(Type.I32));

    // Test band
    {
        var func = try Function.init(alloc, "band", sig);
        defer func.deinit();

        var builder = try root.builder.FunctionBuilder.init(alloc, &func);
        const b0 = try builder.createBlock();
        builder.switchToBlock(b0);
        const v0 = try builder.appendBlockParam(b0, Type.I32);
        const v1 = try builder.appendBlockParam(b0, Type.I32);
        const v2 = try builder.band(Type.I32, v0, v1);
        try builder.ret(v2);

        var interp = Interpreter.init(alloc);
        defer interp.deinit();

        const args = [_]DataValue{ .{ .i32 = 0xFF00 }, .{ .i32 = 0x0FF0 } };
        const result = try interp.call(&func, &args);
        defer alloc.free(result);
        try testing.expectEqual(@as(i32, 0x0F00), result[0].i32);
    }

    // Test bor
    {
        var func = try Function.init(alloc, "bor", sig);
        defer func.deinit();

        var builder = try root.builder.FunctionBuilder.init(alloc, &func);
        const b0 = try builder.createBlock();
        builder.switchToBlock(b0);
        const v0 = try builder.appendBlockParam(b0, Type.I32);
        const v1 = try builder.appendBlockParam(b0, Type.I32);
        const v2 = try builder.bor(Type.I32, v0, v1);
        try builder.ret(v2);

        var interp = Interpreter.init(alloc);
        defer interp.deinit();

        const args = [_]DataValue{ .{ .i32 = 0xFF00 }, .{ .i32 = 0x00FF } };
        const result = try interp.call(&func, &args);
        defer alloc.free(result);
        try testing.expectEqual(@as(i32, 0xFFFF), result[0].i32);
    }

    // Test bxor
    {
        var func = try Function.init(alloc, "bxor", sig);
        defer func.deinit();

        var builder = try root.builder.FunctionBuilder.init(alloc, &func);
        const b0 = try builder.createBlock();
        builder.switchToBlock(b0);
        const v0 = try builder.appendBlockParam(b0, Type.I32);
        const v1 = try builder.appendBlockParam(b0, Type.I32);
        const v2 = try builder.bxor(Type.I32, v0, v1);
        try builder.ret(v2);

        var interp = Interpreter.init(alloc);
        defer interp.deinit();

        const args = [_]DataValue{ .{ .i32 = 0xFFFF }, .{ .i32 = 0x0F0F } };
        const result = try interp.call(&func, &args);
        defer alloc.free(result);
        try testing.expectEqual(@as(i32, 0xF0F0), result[0].i32);
    }
}

test "interpret select" {
    const alloc = testing.allocator;

    var sig = root.signature.Signature.init(alloc, .fast);
    // Note: sig ownership transferred to func, func.deinit() frees it
    try sig.params.append(alloc, root.signature.AbiParam.new(Type.I32));
    try sig.params.append(alloc, root.signature.AbiParam.new(Type.I32));
    try sig.params.append(alloc, root.signature.AbiParam.new(Type.I32));
    try sig.returns.append(alloc, root.signature.AbiParam.new(Type.I32));

    var func = try Function.init(alloc, "sel", sig);
    defer func.deinit();

    var builder = try root.builder.FunctionBuilder.init(alloc, &func);
    const b0 = try builder.createBlock();
    builder.switchToBlock(b0);
    const cond = try builder.appendBlockParam(b0, Type.I32);
    const if_true = try builder.appendBlockParam(b0, Type.I32);
    const if_false = try builder.appendBlockParam(b0, Type.I32);
    const result_val = try builder.select(Type.I32, cond, if_true, if_false);
    try builder.ret(result_val);

    var interp = Interpreter.init(alloc);
    defer interp.deinit();

    // cond = true
    const args1 = [_]DataValue{ .{ .i32 = 1 }, .{ .i32 = 100 }, .{ .i32 = 200 } };
    const result1 = try interp.call(&func, &args1);
    defer alloc.free(result1);
    try testing.expectEqual(@as(i32, 100), result1[0].i32);

    // cond = false
    interp.steps = 0;
    if (interp.frame) |*f| f.deinit();
    interp.frame = null;
    if (interp.memory) |*m| m.deinit();
    interp.memory = null;

    const args2 = [_]DataValue{ .{ .i32 = 0 }, .{ .i32 = 100 }, .{ .i32 = 200 } };
    const result2 = try interp.call(&func, &args2);
    defer alloc.free(result2);
    try testing.expectEqual(@as(i32, 200), result2[0].i32);
}

test "DataValue SIMD splat" {
    const splat_i32 = DataValue.splat(Type.I32X4, .{ .i32 = 42 });
    try testing.expect(splat_i32.isVector());
    try testing.expectEqual(@as(i32, 42), splat_i32.i32x4[0]);
    try testing.expectEqual(@as(i32, 42), splat_i32.i32x4[1]);
    try testing.expectEqual(@as(i32, 42), splat_i32.i32x4[2]);
    try testing.expectEqual(@as(i32, 42), splat_i32.i32x4[3]);

    const splat_f32 = DataValue.splat(Type.F32X4, .{ .f32 = 3.14 });
    try testing.expectApproxEqRel(@as(f32, 3.14), splat_f32.f32x4[0], 0.001);
}

test "DataValue SIMD extract/insert lane" {
    const vec = DataValue{ .i32x4 = .{ 1, 2, 3, 4 } };

    // Extract
    const lane0 = vec.extractLane(0);
    try testing.expectEqual(@as(i32, 1), lane0.i32);
    const lane2 = vec.extractLane(2);
    try testing.expectEqual(@as(i32, 3), lane2.i32);

    // Insert
    const modified = vec.insertLane(1, .{ .i32 = 99 });
    try testing.expectEqual(@as(i32, 1), modified.i32x4[0]);
    try testing.expectEqual(@as(i32, 99), modified.i32x4[1]);
    try testing.expectEqual(@as(i32, 3), modified.i32x4[2]);
    try testing.expectEqual(@as(i32, 4), modified.i32x4[3]);
}

test "DataValue SIMD vadd/vsub/vmul" {
    const a = DataValue{ .i32x4 = .{ 1, 2, 3, 4 } };
    const b = DataValue{ .i32x4 = .{ 10, 20, 30, 40 } };

    // vadd
    const sum = a.vadd(b);
    try testing.expectEqual(@as(i32, 11), sum.i32x4[0]);
    try testing.expectEqual(@as(i32, 22), sum.i32x4[1]);
    try testing.expectEqual(@as(i32, 33), sum.i32x4[2]);
    try testing.expectEqual(@as(i32, 44), sum.i32x4[3]);

    // vsub
    const diff = b.vsub(a);
    try testing.expectEqual(@as(i32, 9), diff.i32x4[0]);
    try testing.expectEqual(@as(i32, 18), diff.i32x4[1]);

    // vmul
    const prod = a.vmul(b);
    try testing.expectEqual(@as(i32, 10), prod.i32x4[0]);
    try testing.expectEqual(@as(i32, 40), prod.i32x4[1]);
    try testing.expectEqual(@as(i32, 90), prod.i32x4[2]);
    try testing.expectEqual(@as(i32, 160), prod.i32x4[3]);
}

test "DataValue SIMD bitwise ops" {
    const a = DataValue{ .i32x4 = .{ 0xFF00, 0x0FF0, 0xF0F0, 0x0F0F } };
    const b = DataValue{ .i32x4 = .{ 0x0F0F, 0xF0F0, 0xFF00, 0x00FF } };

    // vand
    const and_result = a.vand(b);
    try testing.expectEqual(@as(i32, 0x0F00), and_result.i32x4[0]);
    try testing.expectEqual(@as(i32, 0x00F0), and_result.i32x4[1]);

    // vor
    const or_result = a.vor(b);
    try testing.expectEqual(@as(i32, 0xFF0F), or_result.i32x4[0]);
    try testing.expectEqual(@as(i32, 0xFFF0), or_result.i32x4[1]);

    // vxor
    const xor_result = a.vxor(b);
    try testing.expectEqual(@as(i32, 0xF00F), xor_result.i32x4[0]);
    try testing.expectEqual(@as(i32, 0xFF00), xor_result.i32x4[1]);
}

test "DataValue SIMD vneg/vnot" {
    const a = DataValue{ .i32x4 = .{ 1, -2, 3, -4 } };

    // vneg
    const neg = a.vneg();
    try testing.expectEqual(@as(i32, -1), neg.i32x4[0]);
    try testing.expectEqual(@as(i32, 2), neg.i32x4[1]);
    try testing.expectEqual(@as(i32, -3), neg.i32x4[2]);
    try testing.expectEqual(@as(i32, 4), neg.i32x4[3]);

    // vnot
    const b = DataValue{ .i32x4 = .{ 0, -1, 0x7FFFFFFF, @as(i32, @bitCast(@as(u32, 0x80000000))) } };
    const not = b.vnot();
    try testing.expectEqual(@as(i32, -1), not.i32x4[0]);
    try testing.expectEqual(@as(i32, 0), not.i32x4[1]);
}

test "DataValue SIMD toBytes/fromBytes" {
    const vec = DataValue{ .i32x4 = .{ 0x04030201, 0x08070605, 0x0C0B0A09, 0x100F0E0D } };
    const bytes = vec.toBytes();

    // Little-endian byte order
    try testing.expectEqual(@as(u8, 0x01), bytes[0]);
    try testing.expectEqual(@as(u8, 0x02), bytes[1]);
    try testing.expectEqual(@as(u8, 0x03), bytes[2]);
    try testing.expectEqual(@as(u8, 0x04), bytes[3]);

    // Round-trip
    const restored = DataValue.fromBytes(Type.I32X4, bytes);
    try testing.expectEqual(@as(i32, 0x04030201), restored.i32x4[0]);
    try testing.expectEqual(@as(i32, 0x08070605), restored.i32x4[1]);
}

test "DataValue SIMD f32x4 ops" {
    const a = DataValue{ .f32x4 = .{ 1.0, 2.0, 3.0, 4.0 } };
    const b = DataValue{ .f32x4 = .{ 0.5, 1.5, 2.5, 3.5 } };

    // vadd
    const sum = a.vadd(b);
    try testing.expectApproxEqRel(@as(f32, 1.5), sum.f32x4[0], 0.001);
    try testing.expectApproxEqRel(@as(f32, 3.5), sum.f32x4[1], 0.001);

    // vsub
    const diff = a.vsub(b);
    try testing.expectApproxEqRel(@as(f32, 0.5), diff.f32x4[0], 0.001);

    // vmul
    const prod = a.vmul(b);
    try testing.expectApproxEqRel(@as(f32, 0.5), prod.f32x4[0], 0.001);
    try testing.expectApproxEqRel(@as(f32, 3.0), prod.f32x4[1], 0.001);

    // vneg
    const neg = a.vneg();
    try testing.expectApproxEqRel(@as(f32, -1.0), neg.f32x4[0], 0.001);
    try testing.expectApproxEqRel(@as(f32, -2.0), neg.f32x4[1], 0.001);
}
