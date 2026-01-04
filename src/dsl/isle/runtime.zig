const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("root");
const sema = @import("sema.zig");

const TypeId = sema.TypeId;
const TermId = sema.TermId;
const Sym = sema.Sym;
const Pattern = sema.Pattern;
const Expr = sema.Expr;
const TypeEnv = sema.TypeEnv;
const TermEnv = sema.TermEnv;

// Import IR types
const Value = root.entities.Value;
const Inst = root.entities.Inst;
const Type = root.types.Type;
const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;
const DataFlowGraph = root.dfg.DataFlowGraph;
const Imm64 = root.immediates.Imm64;
const IntCC = root.condcodes.IntCC;

/// Runtime context for ISLE pattern matching and construction.
/// Provides access to the IR and type environment during lowering.
pub const Context = struct {
    dfg: *DataFlowGraph,
    type_env: *const TypeEnv,
    term_env: *const TermEnv,
    allocator: Allocator,

    const Self = @This();

    pub fn init(
        dfg: *DataFlowGraph,
        type_env: *const TypeEnv,
        term_env: *const TermEnv,
        allocator: Allocator,
    ) Self {
        return .{
            .dfg = dfg,
            .type_env = type_env,
            .term_env = term_env,
            .allocator = allocator,
        };
    }

    // ========================================================================
    // Value Extraction Helpers
    // ========================================================================

    /// Get the nth operand of an instruction.
    pub fn getOperand(self: *Self, inst: Inst, n: usize) ?Value {
        const data = self.dfg.insts.get(inst) orelse return null;
        return switch (data) {
            .unary => |u| if (n == 0) u.arg else null,
            .binary => |b| if (n < 2) b.args[n] else null,
            .int_compare => |c| if (n < 2) c.args[n] else null,
            .float_compare => |c| if (n < 2) c.args[n] else null,
            .branch => |br| if (n == 0) br.condition else null,
            .load => |l| if (n == 0) l.addr else null,
            .store => |s| if (n == 0) s.addr else if (n == 1) s.value else null,
            else => null,
        };
    }

    /// Get all operands of an instruction as a slice.
    pub fn getOperands(self: *Self, inst: Inst) ![]Value {
        const data = self.dfg.insts.get(inst) orelse return &.{};
        return switch (data) {
            .unary => |u| try self.allocator.dupe(Value, &.{u.arg}),
            .binary => |b| try self.allocator.dupe(Value, &b.args),
            .int_compare => |c| try self.allocator.dupe(Value, &c.args),
            .float_compare => |c| try self.allocator.dupe(Value, &c.args),
            .branch => |br| try self.allocator.dupe(Value, &.{br.condition}),
            .load => |l| try self.allocator.dupe(Value, &.{l.addr}),
            .store => |s| try self.allocator.dupe(Value, &.{ s.addr, s.value }),
            else => &.{},
        };
    }

    /// Get the type of a value.
    pub fn getType(self: *Self, val: Value) Type {
        return self.dfg.value_type(val);
    }

    /// Get the defining instruction of a value.
    pub fn getDefInst(self: *Self, val: Value) ?Inst {
        const def = self.dfg.value_def(val);
        return def.inst();
    }

    /// Extract constant from iconst instruction.
    pub fn getConstant(self: *Self, val: Value) ?i64 {
        const inst = self.getDefInst(val) orelse return null;
        const data = self.dfg.insts.get(inst) orelse return null;

        return switch (data) {
            .nullary => null,
            .unary => null,
            else => null,
        };
    }

    /// Extract immediate value if instruction has one.
    pub fn getImmediate(self: *Self, inst: Inst) ?Imm64 {
        const data = self.dfg.insts.get(inst) orelse return null;
        _ = data;
        // Would extract from UnaryImm format
        return null;
    }

    // ========================================================================
    // Pattern Matching Utilities
    // ========================================================================

    /// Match instruction opcode.
    pub fn matchOpcode(self: *Self, inst: Inst, expected: Opcode) bool {
        const data = self.dfg.insts.get(inst) orelse return false;
        return data.opcode() == expected;
    }

    /// Match value type.
    pub fn matchType(self: *Self, val: Value, expected: Type) bool {
        const ty = self.getType(val);
        return ty.eql(expected);
    }

    /// Check if value is defined by an instruction with given opcode.
    pub fn matchValueOpcode(self: *Self, val: Value, expected: Opcode) bool {
        const inst = self.getDefInst(val) orelse return false;
        return self.matchOpcode(inst, expected);
    }

    /// Check if instruction has exactly N operands.
    pub fn matchArity(self: *Self, inst: Inst, n: usize) bool {
        const data = self.dfg.insts.get(inst) orelse return false;
        const actual = switch (data) {
            .nullary => 0,
            .unary => 1,
            .binary => 2,
            .int_compare => 2,
            .float_compare => 2,
            .branch => 1,
            .load => 1,
            .store => 2,
            else => return false,
        };
        return actual == n;
    }

    // ========================================================================
    // Type Queries and Conversions
    // ========================================================================

    /// Check if type is an integer type.
    pub fn isIntType(self: *Self, ty: Type) bool {
        _ = self;
        return ty.isInt();
    }

    // ========================================================================
    // Type Extractors
    // ========================================================================

    /// Extractor: Match multi-lane vector types, extracting (lane_bits, lane_count).
    /// Returns null for scalar types (lane_count == 1).
    pub fn multiLane(self: *Self, ty: Type) ?struct { bits: u32, lanes: u32 } {
        _ = self;
        const lane_count = ty.laneCount();
        if (lane_count > 1) {
            return .{
                .bits = ty.laneBits(),
                .lanes = lane_count,
            };
        }
        return null;
    }

    /// Extractor: Match 128-bit vector types.
    /// Returns the type if it's a vector with exactly 128 bits, else null.
    pub fn tyVec128(self: *Self, ty: Type) ?Type {
        _ = self;
        if (ty.isVector() and ty.bits() == 128) {
            return ty;
        }
        return null;
    }

    /// Extractor: Match 128-bit integer vector types.
    /// Returns the type if it's a 128-bit vector with integer lanes, else null.
    pub fn tyVec128Int(self: *Self, ty: Type) ?Type {
        _ = self;
        if (ty.isVector() and ty.bits() == 128 and ty.laneType().isInt()) {
            return ty;
        }
        return null;
    }

    /// Extractor: Match 64-bit vector types.
    /// Returns the type if it's a vector with exactly 64 bits, else null.
    pub fn tyVec64(self: *Self, ty: Type) ?Type {
        _ = self;
        if (ty.isVector() and ty.bits() == 64) {
            return ty;
        }
        return null;
    }

    /// Extractor: Match 64-bit integer vector types.
    /// Returns the type if it's a 64-bit vector with integer lanes, else null.
    pub fn tyVec64Int(self: *Self, ty: Type) ?Type {
        _ = self;
        if (ty.isVector() and ty.bits() == 64 and ty.laneType().isInt()) {
            return ty;
        }
        return null;
    }

    /// Check if type is a float type.
    pub fn isFloatType(self: *Self, ty: Type) bool {
        _ = self;
        return ty.isFloat();
    }

    /// Check if type is a vector type.
    pub fn isVectorType(self: *Self, ty: Type) bool {
        _ = self;
        return ty.isVector();
    }

    /// Get bit width of type.
    pub fn typeBits(self: *Self, ty: Type) u32 {
        _ = self;
        return ty.bits();
    }

    /// Get byte size of type.
    pub fn typeBytes(self: *Self, ty: Type) u32 {
        _ = self;
        return ty.bytes();
    }

    /// Get type mask (all 1s for type width).
    pub fn typeMask(self: *Self, ty: Type) u64 {
        _ = self;
        const bits = ty.bits();
        if (bits >= 64) return 0xFFFFFFFFFFFFFFFF;
        return (@as(u64, 1) << @intCast(bits)) - 1;
    }

    /// Check if type fits in N bits.
    pub fn typeFitsIn(self: *Self, ty: Type, bits: u32) bool {
        return self.typeBits(ty) <= bits;
    }

    // ========================================================================
    // Constructor Helpers
    // ========================================================================

    /// Create a new instruction in the DFG.
    pub fn makeInst(
        self: *Self,
        data: InstructionData,
        ty: Type,
    ) !Inst {
        return try self.dfg.makeInst(data, ty);
    }

    /// Create a unary instruction.
    pub fn makeUnary(
        self: *Self,
        opcode: Opcode,
        arg: Value,
        ty: Type,
    ) !Inst {
        const data = InstructionData{
            .unary = .{
                .opcode = opcode,
                .arg = arg,
            },
        };
        return try self.makeInst(data, ty);
    }

    /// Create a binary instruction.
    pub fn makeBinary(
        self: *Self,
        opcode: Opcode,
        arg0: Value,
        arg1: Value,
        ty: Type,
    ) !Inst {
        const data = InstructionData{
            .binary = .{
                .opcode = opcode,
                .args = .{ arg0, arg1 },
            },
        };
        return try self.makeInst(data, ty);
    }

    /// Create an integer compare instruction.
    pub fn makeIntCompare(
        self: *Self,
        cond: IntCC,
        arg0: Value,
        arg1: Value,
        ty: Type,
    ) !Inst {
        const data = InstructionData{
            .int_compare = .{
                .opcode = .icmp,
                .cond = cond,
                .args = .{ arg0, arg1 },
            },
        };
        return try self.makeInst(data, ty);
    }

    /// Create a value result for an instruction.
    pub fn makeValue(self: *Self, inst: Inst, index: usize, ty: Type) !Value {
        return try self.dfg.makeValue(inst, index, ty);
    }

    // ========================================================================
    // Utility Functions
    // ========================================================================

    /// Get opcode name as string.
    pub fn opcodeName(self: *Self, opcode: Opcode) []const u8 {
        _ = self;
        return opcode.name();
    }

    /// Get type name from type environment.
    pub fn typeName(self: *Self, ty_id: TypeId) []const u8 {
        const ty = self.type_env.getType(ty_id);
        return switch (ty) {
            .builtin => |b| switch (b) {
                .bool => "bool",
                .unit => "unit",
            },
            .primitive => |p| self.type_env.symName(p.name),
            .enum_type => |e| self.type_env.symName(e.name),
        };
    }

    /// Get term name from term environment.
    pub fn termName(self: *Self, term_id: TermId) []const u8 {
        const term = self.term_env.getTerm(term_id);
        return self.type_env.symName(term.name);
    }
};

// ========================================================================
// Tests
// ========================================================================

test "Context basic initialization" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    const ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);
    _ = ctx;
}

test "Context type queries" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    var ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);

    const i32_ty = Type.i32();
    const f64_ty = Type.f64();

    try testing.expect(ctx.isIntType(i32_ty));
    try testing.expect(!ctx.isFloatType(i32_ty));
    try testing.expect(!ctx.isIntType(f64_ty));
    try testing.expect(ctx.isFloatType(f64_ty));

    try testing.expectEqual(@as(u32, 32), ctx.typeBits(i32_ty));
    try testing.expectEqual(@as(u32, 4), ctx.typeBytes(i32_ty));
}

test "Context type mask computation" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    var ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);

    const i8_ty = Type.i8();
    const i16_ty = Type.i16();
    const i32_ty = Type.i32();

    try testing.expectEqual(@as(u64, 0xFF), ctx.typeMask(i8_ty));
    try testing.expectEqual(@as(u64, 0xFFFF), ctx.typeMask(i16_ty));
    try testing.expectEqual(@as(u64, 0xFFFFFFFF), ctx.typeMask(i32_ty));
}

test "Context type fits check" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    var ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);

    const i32_ty = Type.i32();
    const i64_ty = Type.i64();

    try testing.expect(ctx.typeFitsIn(i32_ty, 32));
    try testing.expect(ctx.typeFitsIn(i32_ty, 64));
    try testing.expect(!ctx.typeFitsIn(i64_ty, 32));
    try testing.expect(ctx.typeFitsIn(i64_ty, 64));
}

test "Context match opcode" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    var ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);

    // Create a simple binary instruction
    const val0 = try dfg.makeValue(Inst.reserved_value(), 0, Type.i32());
    const val1 = try dfg.makeValue(Inst.reserved_value(), 1, Type.i32());

    const data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ val0, val1 },
        },
    };
    const inst = try dfg.makeInst(data, Type.i32());

    try testing.expect(ctx.matchOpcode(inst, .iadd));
    try testing.expect(!ctx.matchOpcode(inst, .isub));
}

test "Context match arity" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    var ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);

    // Create binary instruction
    const val0 = try dfg.makeValue(Inst.reserved_value(), 0, Type.i32());
    const val1 = try dfg.makeValue(Inst.reserved_value(), 1, Type.i32());

    const data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ val0, val1 },
        },
    };
    const inst = try dfg.makeInst(data, Type.i32());

    try testing.expect(ctx.matchArity(inst, 2));
    try testing.expect(!ctx.matchArity(inst, 1));
    try testing.expect(!ctx.matchArity(inst, 3));
}

test "Context get operand" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    var ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);

    // Create binary instruction
    const val0 = try dfg.makeValue(Inst.reserved_value(), 0, Type.i32());
    const val1 = try dfg.makeValue(Inst.reserved_value(), 1, Type.i32());

    const data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ val0, val1 },
        },
    };
    const inst = try dfg.makeInst(data, Type.i32());

    const op0 = ctx.getOperand(inst, 0);
    const op1 = ctx.getOperand(inst, 1);
    const op2 = ctx.getOperand(inst, 2);

    try testing.expect(op0 != null);
    try testing.expect(op1 != null);
    try testing.expect(op2 == null);
    try testing.expect(op0.?.eql(val0));
    try testing.expect(op1.?.eql(val1));
}

test "multi_lane extractor" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    var ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);

    // Scalars should return null
    const i32_ty = Type.i32();
    try testing.expect(ctx.multiLane(i32_ty) == null);

    // Vector types should extract (lane_bits, lane_count)
    const i32x4 = Type.vector(Type.i32(), 4);
    const result = ctx.multiLane(i32x4);
    try testing.expect(result != null);
    try testing.expectEqual(@as(u32, 32), result.?.bits);
    try testing.expectEqual(@as(u32, 4), result.?.lanes);

    const i8x16 = Type.vector(Type.i8(), 16);
    const result2 = ctx.multiLane(i8x16);
    try testing.expect(result2 != null);
    try testing.expectEqual(@as(u32, 8), result2.?.bits);
    try testing.expectEqual(@as(u32, 16), result2.?.lanes);
}

test "ty_vec128 extractor" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    var ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);

    // Scalars should return null
    const i32_ty = Type.i32();
    try testing.expect(ctx.tyVec128(i32_ty) == null);

    // 64-bit vectors should return null
    const i32x2 = Type.vector(Type.i32(), 2);
    try testing.expect(ctx.tyVec128(i32x2) == null);

    // 128-bit vectors should return the type
    const i32x4 = Type.vector(Type.i32(), 4);
    const result = ctx.tyVec128(i32x4);
    try testing.expect(result != null);
    try testing.expect(result.?.eql(i32x4));

    const f32x4 = Type.vector(Type.f32(), 4);
    const result2 = ctx.tyVec128(f32x4);
    try testing.expect(result2 != null);
    try testing.expect(result2.?.eql(f32x4));

    const i8x16 = Type.vector(Type.i8(), 16);
    const result3 = ctx.tyVec128(i8x16);
    try testing.expect(result3 != null);
    try testing.expect(result3.?.eql(i8x16));
}

test "ty_vec128_int extractor" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    var ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);

    // Integer 128-bit vectors should match
    const i32x4 = Type.vector(Type.i32(), 4);
    const result = ctx.tyVec128Int(i32x4);
    try testing.expect(result != null);
    try testing.expect(result.?.eql(i32x4));

    // Float 128-bit vectors should return null
    const f32x4 = Type.vector(Type.f32(), 4);
    try testing.expect(ctx.tyVec128Int(f32x4) == null);
}

test "ty_vec64 extractor" {
    const type_env = TypeEnv.init(testing.allocator);
    const term_env = TermEnv.init(testing.allocator);
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    var ctx = Context.init(&dfg, &type_env, &term_env, testing.allocator);

    // 64-bit vectors should match
    const i32x2 = Type.vector(Type.i32(), 2);
    const result = ctx.tyVec64(i32x2);
    try testing.expect(result != null);
    try testing.expect(result.?.eql(i32x2));

    // 128-bit vectors should return null
    const i32x4 = Type.vector(Type.i32(), 4);
    try testing.expect(ctx.tyVec64(i32x4) == null);
}
