//! Cranelift IR type system.
//!
//! SSA value types for integers, floats, and SIMD vectors.
//! Encoded as u16 with the following ranges:
//! - 0x00: INVALID
//! - 0x01-0x6f: Special types
//! - 0x70-0x7d: Lane types (scalar int/float)
//! - 0x7e-0x7f: Reference types
//! - 0x80-0xff: Vector types (2-256 lanes, power of 2)
//! - 0x100-0x17f: Dynamic vector types

const std = @import("std");

// Type encoding constants
const LANE_BASE: u16 = 0x70;
const REFERENCE_BASE: u16 = 0x7E;
const VECTOR_BASE: u16 = 0x80;
const DYNAMIC_VECTOR_BASE: u16 = 0x100;
const STRUCT_BASE: u16 = 0x200;

/// A field within a struct type.
pub const StructField = struct {
    ty: Type,
    offset: u32,

    pub fn eql(a: StructField, b: StructField) bool {
        return a.ty.raw == b.ty.raw and a.offset == b.offset;
    }
};

/// Index into StructStore.
pub const StructId = enum(u16) {
    _,

    pub fn index(self: StructId) u16 {
        return @intFromEnum(self);
    }
};

/// SSA value type.
pub const Type = packed struct {
    raw: u16,

    pub const INVALID = Type{ .raw = 0 };

    // Scalar integers (from generated Cranelift types)
    pub const I8 = Type{ .raw = 0x74 };
    pub const I16 = Type{ .raw = 0x75 };
    pub const I32 = Type{ .raw = 0x76 };
    pub const I64 = Type{ .raw = 0x77 };
    pub const I128 = Type{ .raw = 0x78 };

    // Scalar floats
    pub const F16 = Type{ .raw = 0x79 };
    pub const F32 = Type{ .raw = 0x7a };
    pub const F64 = Type{ .raw = 0x7b };
    pub const F128 = Type{ .raw = 0x7c };

    // Reference types (WebAssembly)
    pub const FUNCREF = Type{ .raw = 0x7e }; // WebAssembly funcref
    pub const EXTERNREF = Type{ .raw = 0x7f }; // WebAssembly externref

    // Small vector types (sub-register, packed)
    pub const I8X2 = Type{ .raw = 0x84 }; // 16 bits total
    pub const I8X4 = Type{ .raw = 0x94 }; // 32 bits total
    pub const I8X8 = Type{ .raw = 0xa4 }; // 64 bits total
    pub const I16X2 = Type{ .raw = 0x85 }; // 32 bits total
    pub const I16X4 = Type{ .raw = 0x95 }; // 64 bits total
    pub const I32X2 = Type{ .raw = 0x86 }; // 64 bits total

    // Common 128-bit vector types
    pub const I8X16 = Type{ .raw = 0xb4 };
    pub const I16X8 = Type{ .raw = 0xa5 };
    pub const I32X4 = Type{ .raw = 0x96 };
    pub const I64X2 = Type{ .raw = 0x87 };
    pub const F32X4 = Type{ .raw = 0x9a };
    pub const F64X2 = Type{ .raw = 0x8b };
    pub const F32X2 = Type{ .raw = 0x8a }; // 64 bits total
    pub const F16X4 = Type{ .raw = 0x99 }; // 64 bits total
    pub const F16X8 = Type{ .raw = 0xa9 }; // 128 bits total

    // Dynamic/scalable vector types (SVE)
    // Encoding: DYNAMIC_VECTOR_BASE + (log2_min_lanes << 4) + lane_bits_encoding
    // These represent vectors with runtime-determined length (VL * min_lanes)
    pub const I8X8XN = Type{ .raw = 0x104 }; // min 8 lanes of i8, scalable
    pub const I8X16XN = Type{ .raw = 0x114 }; // min 16 lanes of i8, scalable
    pub const I16X4XN = Type{ .raw = 0x105 }; // min 4 lanes of i16, scalable
    pub const I16X8XN = Type{ .raw = 0x115 }; // min 8 lanes of i16, scalable
    pub const I32X2XN = Type{ .raw = 0x106 }; // min 2 lanes of i32, scalable
    pub const I32X4XN = Type{ .raw = 0x116 }; // min 4 lanes of i32, scalable
    pub const I64X2XN = Type{ .raw = 0x107 }; // min 2 lanes of i64, scalable
    pub const F32X2XN = Type{ .raw = 0x10a }; // min 2 lanes of f32, scalable
    pub const F32X4XN = Type{ .raw = 0x11a }; // min 4 lanes of f32, scalable
    pub const F64X2XN = Type{ .raw = 0x10b }; // min 2 lanes of f64, scalable
    pub const F16X4XN = Type{ .raw = 0x109 }; // min 4 lanes of f16, scalable
    pub const F16X8XN = Type{ .raw = 0x119 }; // min 8 lanes of f16, scalable

    pub fn eql(self: Type, other: Type) bool {
        return self.raw == other.raw;
    }

    pub fn isInvalid(self: Type) bool {
        return self.raw == 0;
    }

    pub fn isSpecial(self: Type) bool {
        return self.raw < LANE_BASE;
    }

    pub fn isLane(self: Type) bool {
        return self.raw >= LANE_BASE and self.raw < VECTOR_BASE;
    }

    pub fn isVector(self: Type) bool {
        return self.raw >= VECTOR_BASE and !self.isDynamicVector() and !self.isStruct();
    }

    pub fn isDynamicVector(self: Type) bool {
        return self.raw >= DYNAMIC_VECTOR_BASE and self.raw < STRUCT_BASE;
    }

    pub fn isStruct(self: Type) bool {
        return self.raw >= STRUCT_BASE;
    }

    pub fn getStructId(self: Type) ?StructId {
        if (!self.isStruct()) return null;
        return @enumFromInt(self.raw - STRUCT_BASE);
    }

    pub fn fromStructId(id: StructId) Type {
        return .{ .raw = STRUCT_BASE + id.index() };
    }

    /// Get struct fields from a StructStore. Returns null for non-structs.
    pub fn getStructFields(self: Type, store: *const StructStore) ?[]const StructField {
        const id = self.getStructId() orelse return null;
        return store.getFields(id);
    }

    /// Get struct size in bytes. Returns null for non-structs.
    pub fn structBytes(self: Type, store: *const StructStore) ?u32 {
        const id = self.getStructId() orelse return null;
        return store.getSize(id);
    }

    pub fn isInt(self: Type) bool {
        return self.eql(I8) or self.eql(I16) or self.eql(I32) or
            self.eql(I64) or self.eql(I128);
    }

    pub fn isFloat(self: Type) bool {
        return self.eql(F16) or self.eql(F32) or self.eql(F64) or self.eql(F128);
    }

    /// Check if type is a WebAssembly reference type.
    pub fn isRef(self: Type) bool {
        return self.raw >= REFERENCE_BASE and self.raw < VECTOR_BASE;
    }

    /// Check if type is funcref.
    pub fn isFuncRef(self: Type) bool {
        return self.eql(FUNCREF);
    }

    /// Check if type is externref.
    pub fn isExternRef(self: Type) bool {
        return self.eql(EXTERNREF);
    }

    /// Get lane type of vector (or self for scalars).
    pub fn laneType(self: Type) Type {
        if (self.raw < VECTOR_BASE) {
            return self;
        } else {
            return .{ .raw = LANE_BASE | (self.raw & 0x0f) };
        }
    }

    /// Log2 of lane count (0-8 for 1-256 lanes).
    pub fn log2LaneCount(self: Type) u32 {
        if (self.isDynamicVector()) {
            return 0;
        }
        const offset = if (self.raw >= LANE_BASE) self.raw - LANE_BASE else 0;
        return @intCast(offset >> 4);
    }

    /// Number of lanes (1 for scalars, 2-256 for vectors).
    pub fn laneCount(self: Type) u32 {
        if (self.isDynamicVector()) {
            return 0;
        } else {
            return @as(u32, 1) << @intCast(self.log2LaneCount());
        }
    }

    /// Number of bits in a single lane.
    pub fn laneBits(self: Type) u32 {
        return switch (self.laneType().raw) {
            I8.raw => 8,
            I16.raw, F16.raw => 16,
            I32.raw, F32.raw => 32,
            I64.raw, F64.raw => 64,
            I128.raw, F128.raw => 128,
            else => 0,
        };
    }

    /// Log2 of bits in a lane.
    pub fn log2LaneBits(self: Type) u32 {
        return switch (self.laneType().raw) {
            I8.raw => 3,
            I16.raw, F16.raw => 4,
            I32.raw, F32.raw => 5,
            I64.raw, F64.raw => 6,
            I128.raw, F128.raw => 7,
            else => 0,
        };
    }

    /// Total bits for this type.
    pub fn bits(self: Type) u32 {
        if (self.isDynamicVector()) {
            return 0;
        } else {
            return self.laneBits() * self.laneCount();
        }
    }

    /// Bytes required to store this type.
    pub fn bytes(self: Type) u32 {
        return (self.bits() + 7) / 8;
    }

    /// Get integer type with given bit width.
    pub fn int(width: u16) ?Type {
        return switch (width) {
            8 => I8,
            16 => I16,
            32 => I32,
            64 => I64,
            128 => I128,
            else => null,
        };
    }

    /// Get integer type with given byte size.
    pub fn intWithByteSize(size: u16) ?Type {
        const bits_opt = std.math.mul(u16, size, 8) catch null;
        return if (bits_opt) |b| Type.int(b) else null;
    }

    /// Create a vector type with the given lane type and lane count.
    pub fn vector(lane_type: Type, lane_count: u32) ?Type {
        if (!lane_type.isLane()) return null;
        if (lane_count < 2 or lane_count > 256) return null;
        if (!std.math.isPowerOfTwo(lane_count)) return null;
        const log2_lanes = std.math.log2_int(u32, lane_count);
        const lane_bits: u16 = lane_type.raw & 0x0f;
        return .{ .raw = LANE_BASE + (@as(u16, log2_lanes) << 4) + lane_bits };
    }

    /// Type with same lane count but different lane type.
    fn replaceLanes(self: Type, lane: Type) Type {
        std.debug.assert(lane.isLane() and !self.isSpecial());
        return .{ .raw = (lane.raw & 0x0f) | (self.raw & 0xf0) };
    }

    /// Convert to integer type (same width, int lanes).
    pub fn asInt(self: Type) Type {
        return self.replaceLanes(switch (self.laneType().raw) {
            I8.raw => I8,
            I16.raw, F16.raw => I16,
            I32.raw, F32.raw => I32,
            I64.raw, F64.raw => I64,
            I128.raw, F128.raw => I128,
            else => unreachable,
        });
    }

    /// Comparison result type (i8 for scalars, iN lanes for vectors).
    pub fn asTruthy(self: Type) Type {
        if (!self.isVector()) {
            return I8;
        } else {
            return self.asTruthyPedantic();
        }
    }

    fn asTruthyPedantic(self: Type) Type {
        return self.replaceLanes(switch (self.laneType().raw) {
            I8.raw => I8,
            I16.raw, F16.raw => I16,
            I32.raw, F32.raw => I32,
            I64.raw, F64.raw => I64,
            I128.raw, F128.raw => I128,
            else => I8,
        });
    }

    /// Half-width lanes (I32 -> I16, F64 -> F32, etc.).
    pub fn halfWidth(self: Type) ?Type {
        const half_lane = switch (self.laneType().raw) {
            I16.raw => I8,
            I32.raw => I16,
            I64.raw => I32,
            I128.raw => I64,
            F32.raw => F16,
            F64.raw => F32,
            F128.raw => F64,
            else => return null,
        };
        return self.replaceLanes(half_lane);
    }

    /// Double-width lanes (I32 -> I64, F32 -> F64, etc.).
    pub fn doubleWidth(self: Type) ?Type {
        const double_lane = switch (self.laneType().raw) {
            I8.raw => I16,
            I16.raw => I32,
            I32.raw => I64,
            I64.raw => I128,
            F16.raw => F32,
            F32.raw => F64,
            F64.raw => F128,
            else => return null,
        };
        return self.replaceLanes(double_lane);
    }

    /// Convert a fixed vector type to its scalable/dynamic counterpart.
    /// E.g., I32X4 -> I32X4XN (scalable with min 4 lanes).
    pub fn vectorToDynamic(self: Type) ?Type {
        if (!self.isVector()) return null;
        return switch (self.raw) {
            I8X8.raw => I8X8XN,
            I8X16.raw => I8X16XN,
            I16X4.raw => I16X4XN,
            I16X8.raw => I16X8XN,
            I32X2.raw => I32X2XN,
            I32X4.raw => I32X4XN,
            I64X2.raw => I64X2XN,
            F16X4.raw => F16X4XN,
            F16X8.raw => F16X8XN,
            F32X2.raw => F32X2XN,
            F32X4.raw => F32X4XN,
            F64X2.raw => F64X2XN,
            else => null,
        };
    }

    /// Convert a dynamic/scalable vector type to its fixed counterpart.
    /// E.g., I32X4XN -> I32X4 (fixed 4 lanes).
    pub fn dynamicToVector(self: Type) ?Type {
        if (!self.isDynamicVector()) return null;
        return switch (self.raw) {
            I8X8XN.raw => I8X8,
            I8X16XN.raw => I8X16,
            I16X4XN.raw => I16X4,
            I16X8XN.raw => I16X8,
            I32X2XN.raw => I32X2,
            I32X4XN.raw => I32X4,
            I64X2XN.raw => I64X2,
            F16X4XN.raw => F16X4,
            F16X8XN.raw => F16X8,
            F32X2XN.raw => F32X2,
            F32X4XN.raw => F32X4,
            F64X2XN.raw => F64X2,
            else => null,
        };
    }

    /// Get minimum lane count for dynamic vectors.
    /// For fixed vectors, returns the actual lane count.
    pub fn minLaneCount(self: Type) u32 {
        if (self.isDynamicVector()) {
            if (self.dynamicToVector()) |fixed| {
                return fixed.laneCount();
            }
            return 0;
        }
        return self.laneCount();
    }

    /// Format as string (i32, f64, i32x4, etc.).
    pub fn format(self: Type, writer: anytype) !void {
        if (self.isInvalid()) {
            try writer.writeAll("invalid");
            return;
        }

        const lane = self.laneType();
        const lane_str = switch (lane.raw) {
            I8.raw => "i8",
            I16.raw => "i16",
            I32.raw => "i32",
            I64.raw => "i64",
            I128.raw => "i128",
            F16.raw => "f16",
            F32.raw => "f32",
            F64.raw => "f64",
            F128.raw => "f128",
            else => "?",
        };

        if (self.isStruct()) {
            if (self.getStructId()) |id| {
                try writer.print("struct#{d}", .{id.index()});
            } else {
                try writer.writeAll("struct?");
            }
        } else if (self.isDynamicVector()) {
            try writer.print("{s}x{d}xn", .{ lane_str, self.minLaneCount() });
        } else if (self.isVector()) {
            try writer.print("{s}x{d}", .{ lane_str, self.laneCount() });
        } else {
            try writer.writeAll(lane_str);
        }
    }
};

/// Hash-consed storage for struct types.
pub const StructStore = struct {
    alloc: std.mem.Allocator,
    fields: std.ArrayListUnmanaged(StructField),
    /// Maps (start_idx, len) -> StructId for deduplication.
    structs: std.ArrayListUnmanaged(StructEntry),

    const StructEntry = struct {
        start: u32,
        len: u16,
        size: u32,
    };

    pub fn init(alloc: std.mem.Allocator) StructStore {
        return .{
            .alloc = alloc,
            .fields = .{},
            .structs = .{},
        };
    }

    pub fn deinit(self: *StructStore) void {
        self.fields.deinit(self.alloc);
        self.structs.deinit(self.alloc);
    }

    fn fieldsEql(a: []const StructField, b: []const StructField) bool {
        if (a.len != b.len) return false;
        for (a, b) |af, bf| {
            if (!af.eql(bf)) return false;
        }
        return true;
    }

    /// Intern a struct type, returning its ID.
    pub fn intern(self: *StructStore, fields: []const StructField, size: u32) !StructId {
        // Check for existing match
        for (self.structs.items, 0..) |entry, i| {
            if (entry.len == fields.len and entry.size == size) {
                const existing = self.fields.items[entry.start..][0..entry.len];
                if (fieldsEql(existing, fields)) {
                    return @enumFromInt(@as(u16, @intCast(i)));
                }
            }
        }

        // Add new struct
        const start: u32 = @intCast(self.fields.items.len);
        try self.fields.appendSlice(self.alloc, fields);
        const id: u16 = @intCast(self.structs.items.len);
        try self.structs.append(self.alloc, .{
            .start = start,
            .len = @intCast(fields.len),
            .size = size,
        });
        return @enumFromInt(id);
    }

    /// Get fields for a struct ID.
    pub fn getFields(self: *const StructStore, id: StructId) []const StructField {
        const entry = self.structs.items[id.index()];
        return self.fields.items[entry.start..][0..entry.len];
    }

    /// Get total size of a struct in bytes.
    pub fn getSize(self: *const StructStore, id: StructId) u32 {
        return self.structs.items[id.index()].size;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Type basic" {
    try std.testing.expect(!Type.INVALID.isInt());
    try std.testing.expect(Type.INVALID.isInvalid());
    try std.testing.expect(Type.I32.isInt());
    try std.testing.expect(!Type.I32.isFloat());
    try std.testing.expect(Type.F64.isFloat());
    try std.testing.expect(!Type.F64.isInt());
}

test "Type sizes" {
    try std.testing.expectEqual(@as(u32, 32), Type.I32.bits());
    try std.testing.expectEqual(@as(u32, 4), Type.I32.bytes());
    try std.testing.expectEqual(@as(u32, 128), Type.F128.bits());
    try std.testing.expectEqual(@as(u32, 16), Type.F128.bytes());
}

test "Type vector" {
    try std.testing.expect(Type.I32X4.isVector());
    try std.testing.expect(!Type.I32.isVector());
    try std.testing.expectEqual(@as(u32, 4), Type.I32X4.laneCount());
    try std.testing.expectEqual(@as(u32, 1), Type.I32.laneCount());
    try std.testing.expect(Type.I32X4.laneType().eql(Type.I32));
    try std.testing.expectEqual(@as(u32, 128), Type.I32X4.bits());
}

test "Type lane operations" {
    try std.testing.expectEqual(@as(u32, 32), Type.I32.laneBits());
    try std.testing.expectEqual(@as(u32, 5), Type.I32.log2LaneBits());
    try std.testing.expectEqual(@as(u32, 16), Type.F16.laneBits());
}

test "Type width conversion" {
    try std.testing.expect(Type.I32.halfWidth().?.eql(Type.I16));
    try std.testing.expect(Type.I16.doubleWidth().?.eql(Type.I32));
    try std.testing.expect(Type.F32.halfWidth().?.eql(Type.F16));
    try std.testing.expect(Type.F64.doubleWidth().?.eql(Type.F128));
    try std.testing.expect(Type.F128.doubleWidth() == null);
}

test "Type asInt" {
    try std.testing.expect(Type.F32.asInt().eql(Type.I32));
    try std.testing.expect(Type.F64.asInt().eql(Type.I64));
    try std.testing.expect(Type.I32.asInt().eql(Type.I32));
}

test "Type asTruthy" {
    try std.testing.expect(Type.I32.asTruthy().eql(Type.I8));
    try std.testing.expect(Type.F64.asTruthy().eql(Type.I8));
    try std.testing.expect(Type.I32X4.asTruthy().eql(Type.I32X4));
}

test "Type format" {
    var buf: [32]u8 = undefined;

    const s1 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I32});
    try std.testing.expectEqualStrings("i32", s1);

    const s2 = try std.fmt.bufPrint(&buf, "{f}", .{Type.F64});
    try std.testing.expectEqualStrings("f64", s2);

    const s3 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I32X4});
    try std.testing.expectEqualStrings("i32x4", s3);

    const s4 = try std.fmt.bufPrint(&buf, "{f}", .{Type.INVALID});
    try std.testing.expectEqualStrings("invalid", s4);
}

test "Type int constructors" {
    try std.testing.expect(Type.int(32).?.eql(Type.I32));
    try std.testing.expect(Type.int(64).?.eql(Type.I64));
    try std.testing.expect(Type.int(7) == null);

    try std.testing.expect(Type.intWithByteSize(4).?.eql(Type.I32));
    try std.testing.expect(Type.intWithByteSize(8).?.eql(Type.I64));
}

test "Type small vectors" {
    // I8X2: 2 lanes of i8 = 16 bits
    try std.testing.expect(Type.I8X2.isVector());
    try std.testing.expectEqual(@as(u32, 2), Type.I8X2.laneCount());
    try std.testing.expect(Type.I8X2.laneType().eql(Type.I8));
    try std.testing.expectEqual(@as(u32, 16), Type.I8X2.bits());
    try std.testing.expectEqual(@as(u32, 2), Type.I8X2.bytes());

    // I8X4: 4 lanes of i8 = 32 bits
    try std.testing.expect(Type.I8X4.isVector());
    try std.testing.expectEqual(@as(u32, 4), Type.I8X4.laneCount());
    try std.testing.expect(Type.I8X4.laneType().eql(Type.I8));
    try std.testing.expectEqual(@as(u32, 32), Type.I8X4.bits());
    try std.testing.expectEqual(@as(u32, 4), Type.I8X4.bytes());

    // I8X8: 8 lanes of i8 = 64 bits
    try std.testing.expect(Type.I8X8.isVector());
    try std.testing.expectEqual(@as(u32, 8), Type.I8X8.laneCount());
    try std.testing.expect(Type.I8X8.laneType().eql(Type.I8));
    try std.testing.expectEqual(@as(u32, 64), Type.I8X8.bits());
    try std.testing.expectEqual(@as(u32, 8), Type.I8X8.bytes());

    // I16X2: 2 lanes of i16 = 32 bits
    try std.testing.expect(Type.I16X2.isVector());
    try std.testing.expectEqual(@as(u32, 2), Type.I16X2.laneCount());
    try std.testing.expectEqual(@as(u32, 32), Type.I16X2.bits());

    // I16X4: 4 lanes of i16 = 64 bits
    try std.testing.expect(Type.I16X4.isVector());
    try std.testing.expectEqual(@as(u32, 4), Type.I16X4.laneCount());
    try std.testing.expectEqual(@as(u32, 64), Type.I16X4.bits());

    // I32X2: 2 lanes of i32 = 64 bits
    try std.testing.expect(Type.I32X2.isVector());
    try std.testing.expectEqual(@as(u32, 2), Type.I32X2.laneCount());
    try std.testing.expectEqual(@as(u32, 64), Type.I32X2.bits());

    // F32X2: 2 lanes of f32 = 64 bits
    try std.testing.expect(Type.F32X2.isVector());
    try std.testing.expectEqual(@as(u32, 2), Type.F32X2.laneCount());
    try std.testing.expect(Type.F32X2.laneType().eql(Type.F32));
    try std.testing.expectEqual(@as(u32, 64), Type.F32X2.bits());

    // F16X4: 4 lanes of f16 = 64 bits
    try std.testing.expect(Type.F16X4.isVector());
    try std.testing.expectEqual(@as(u32, 4), Type.F16X4.laneCount());
    try std.testing.expect(Type.F16X4.laneType().eql(Type.F16));
    try std.testing.expectEqual(@as(u32, 64), Type.F16X4.bits());

    // F16X8: 8 lanes of f16 = 128 bits
    try std.testing.expect(Type.F16X8.isVector());
    try std.testing.expectEqual(@as(u32, 8), Type.F16X8.laneCount());
    try std.testing.expectEqual(@as(u32, 128), Type.F16X8.bits());
}

test "Type vector constructor" {
    // Create small vectors via vector()
    try std.testing.expect(Type.vector(Type.I8, 2).?.eql(Type.I8X2));
    try std.testing.expect(Type.vector(Type.I8, 4).?.eql(Type.I8X4));
    try std.testing.expect(Type.vector(Type.I8, 8).?.eql(Type.I8X8));
    try std.testing.expect(Type.vector(Type.I8, 16).?.eql(Type.I8X16));
    try std.testing.expect(Type.vector(Type.I16, 2).?.eql(Type.I16X2));
    try std.testing.expect(Type.vector(Type.I32, 2).?.eql(Type.I32X2));
    try std.testing.expect(Type.vector(Type.F32, 2).?.eql(Type.F32X2));

    // Invalid: non-power-of-two
    try std.testing.expect(Type.vector(Type.I8, 3) == null);
    // Invalid: too small
    try std.testing.expect(Type.vector(Type.I8, 1) == null);
    // Invalid: non-lane type
    try std.testing.expect(Type.vector(Type.I8X2, 2) == null);
}

test "Type reference types" {
    // Funcref
    try std.testing.expect(Type.FUNCREF.isRef());
    try std.testing.expect(Type.FUNCREF.isFuncRef());
    try std.testing.expect(!Type.FUNCREF.isExternRef());
    try std.testing.expect(!Type.FUNCREF.isInt());
    try std.testing.expect(!Type.FUNCREF.isFloat());
    try std.testing.expect(!Type.FUNCREF.isVector());

    // Externref
    try std.testing.expect(Type.EXTERNREF.isRef());
    try std.testing.expect(Type.EXTERNREF.isExternRef());
    try std.testing.expect(!Type.EXTERNREF.isFuncRef());
    try std.testing.expect(!Type.EXTERNREF.isInt());
    try std.testing.expect(!Type.EXTERNREF.isFloat());

    // Non-reference types
    try std.testing.expect(!Type.I32.isRef());
    try std.testing.expect(!Type.F64.isRef());
    try std.testing.expect(!Type.I32X4.isRef());
}

test "Type dynamic vectors" {
    // isDynamicVector
    try std.testing.expect(Type.I32X4XN.isDynamicVector());
    try std.testing.expect(Type.I8X16XN.isDynamicVector());
    try std.testing.expect(Type.F32X4XN.isDynamicVector());
    try std.testing.expect(!Type.I32X4.isDynamicVector());
    try std.testing.expect(!Type.I32.isDynamicVector());

    // vectorToDynamic
    try std.testing.expect(Type.I32X4.vectorToDynamic().?.eql(Type.I32X4XN));
    try std.testing.expect(Type.I8X16.vectorToDynamic().?.eql(Type.I8X16XN));
    try std.testing.expect(Type.F32X4.vectorToDynamic().?.eql(Type.F32X4XN));
    try std.testing.expect(Type.F64X2.vectorToDynamic().?.eql(Type.F64X2XN));
    try std.testing.expect(Type.I32.vectorToDynamic() == null);

    // dynamicToVector
    try std.testing.expect(Type.I32X4XN.dynamicToVector().?.eql(Type.I32X4));
    try std.testing.expect(Type.I8X16XN.dynamicToVector().?.eql(Type.I8X16));
    try std.testing.expect(Type.F32X4XN.dynamicToVector().?.eql(Type.F32X4));
    try std.testing.expect(Type.F64X2XN.dynamicToVector().?.eql(Type.F64X2));
    try std.testing.expect(Type.I32X4.dynamicToVector() == null);

    // minLaneCount
    try std.testing.expectEqual(@as(u32, 4), Type.I32X4XN.minLaneCount());
    try std.testing.expectEqual(@as(u32, 16), Type.I8X16XN.minLaneCount());
    try std.testing.expectEqual(@as(u32, 4), Type.F32X4XN.minLaneCount());
    try std.testing.expectEqual(@as(u32, 2), Type.F64X2XN.minLaneCount());
    // Fixed vectors return actual lane count
    try std.testing.expectEqual(@as(u32, 4), Type.I32X4.minLaneCount());
}

test "StructStore basic" {
    var store = StructStore.init(std.testing.allocator);
    defer store.deinit();

    // Create struct { i32, f64 }
    const fields1 = [_]StructField{
        .{ .ty = Type.I32, .offset = 0 },
        .{ .ty = Type.F64, .offset = 8 },
    };
    const id1 = try store.intern(&fields1, 16);

    // Same fields should return same ID
    const id1_dup = try store.intern(&fields1, 16);
    try std.testing.expectEqual(id1.index(), id1_dup.index());

    // Different struct
    const fields2 = [_]StructField{
        .{ .ty = Type.F32, .offset = 0 },
        .{ .ty = Type.F32, .offset = 4 },
    };
    const id2 = try store.intern(&fields2, 8);
    try std.testing.expect(id1.index() != id2.index());

    // Retrieve fields
    const got = store.getFields(id1);
    try std.testing.expectEqual(@as(usize, 2), got.len);
    try std.testing.expect(got[0].ty.eql(Type.I32));
    try std.testing.expect(got[1].ty.eql(Type.F64));

    // Size
    try std.testing.expectEqual(@as(u32, 16), store.getSize(id1));
    try std.testing.expectEqual(@as(u32, 8), store.getSize(id2));
}

test "Type struct" {
    var store = StructStore.init(std.testing.allocator);
    defer store.deinit();

    const fields = [_]StructField{
        .{ .ty = Type.I32, .offset = 0 },
    };
    const id = try store.intern(&fields, 4);
    const ty = Type.fromStructId(id);

    try std.testing.expect(ty.isStruct());
    try std.testing.expect(!ty.isInt());
    try std.testing.expect(!ty.isVector());
    try std.testing.expectEqual(id.index(), ty.getStructId().?.index());

    const got = ty.getStructFields(&store);
    try std.testing.expect(got != null);
    try std.testing.expectEqual(@as(usize, 1), got.?.len);

    try std.testing.expectEqual(@as(u32, 4), ty.structBytes(&store).?);

    // Non-struct returns null
    try std.testing.expect(Type.I32.getStructFields(&store) == null);
    try std.testing.expect(Type.I32.structBytes(&store) == null);
}
