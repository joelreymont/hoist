const std = @import("std");
const testing = std.testing;

const root = @import("../root.zig");
const types = @import("types.zig");
const entities = @import("entities.zig");
const immediates = @import("immediates.zig");
const memflags = @import("memflags.zig");
const extfunc = @import("extfunc.zig");

const Type = types.Type;
const GlobalValue = entities.GlobalValue;
const Imm64 = immediates.Imm64;
const Offset32 = immediates.Offset32;
const MemFlags = memflags.MemFlags;
const ExternalName = extfunc.ExternalName;

/// Global value data - runtime-accessible globals.
pub const GlobalValueData = union(enum) {
    /// VM context struct address.
    vmctx,

    /// Load from memory pointed to by base global value.
    load: LoadData,

    /// Offset from another global value.
    iadd_imm: IAddImmData,

    /// Symbolic name resolved at link time.
    symbol: SymbolData,

    /// Dynamic scale target constant for scalable vectors.
    dyn_scale_target_const: DynScaleData,

    pub const LoadData = struct {
        base: GlobalValue,
        offset: Offset32,
        global_type: Type,
        flags: MemFlags,

        pub fn init(base: GlobalValue, offset: Offset32, ty: Type, flags: MemFlags) LoadData {
            return .{
                .base = base,
                .offset = offset,
                .global_type = ty,
                .flags = flags,
            };
        }
    };

    pub const IAddImmData = struct {
        base: GlobalValue,
        offset: Imm64,
        global_type: Type,

        pub fn init(base: GlobalValue, offset: Imm64, ty: Type) IAddImmData {
            return .{
                .base = base,
                .offset = offset,
                .global_type = ty,
            };
        }
    };

    pub const SymbolData = struct {
        name: ExternalName,

        pub fn init(name: ExternalName) SymbolData {
            return .{ .name = name };
        }
    };

    pub const DynScaleData = struct {
        vector_type: Type,

        pub fn init(vector_type: Type) DynScaleData {
            return .{ .vector_type = vector_type };
        }
    };

    pub fn format(self: GlobalValueData, writer: anytype) !void {
        switch (self) {
            .vmctx => try writer.writeAll("vmctx"),
            .load => |data| try writer.print("load[{}+{}]", .{ data.base, data.offset }),
            .iadd_imm => |data| try writer.print("iadd_imm[{}+{}]", .{ data.base, data.offset }),
            .symbol => |data| try writer.print("symbol[{}]", .{data.name}),
            .dyn_scale_target_const => |data| try writer.print("dyn_scale[{}]", .{data.vector_type}),
        }
    }
};

test "GlobalValueData vmctx" {
    const data = GlobalValueData{ .vmctx = {} };
    try testing.expectEqual(GlobalValueData.vmctx, data);
}

test "GlobalValueData load" {
    const load = GlobalValueData.LoadData.init(
        GlobalValue.new(0),
        Offset32.new(16),
        Type.I64,
        MemFlags.default(),
    );
    const data = GlobalValueData{ .load = load };
    try testing.expectEqual(GlobalValue.new(0), data.load.base);
    try testing.expectEqual(@as(i32, 16), data.load.offset.value);
    try testing.expectEqual(Type.I64, data.load.global_type);
}

test "GlobalValueData iadd_imm" {
    const iadd = GlobalValueData.IAddImmData.init(
        GlobalValue.new(1),
        Imm64.new(42),
        Type.I64,
    );
    const data = GlobalValueData{ .iadd_imm = iadd };
    try testing.expectEqual(GlobalValue.new(1), data.iadd_imm.base);
    try testing.expectEqual(@as(i64, 42), data.iadd_imm.offset.value);
    try testing.expectEqual(Type.I64, data.iadd_imm.global_type);
}

test "GlobalValueData symbol" {
    const sym = GlobalValueData.SymbolData.init(ExternalName.fromUser(0, 0));
    const data = GlobalValueData{ .symbol = sym };
    try testing.expect(data.symbol.name == .user);
}

test "GlobalValueData dyn_scale" {
    const scale = GlobalValueData.DynScaleData.init(Type.I32X4);
    const data = GlobalValueData{ .dyn_scale_target_const = scale };
    try testing.expectEqual(Type.I32X4, data.dyn_scale_target_const.vector_type);
}
