const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Type = hoist.types.Type;
const StructField = hoist.types.StructField;
const StructStore = hoist.types.StructStore;
const AbiParam = hoist.signature.AbiParam;
const a64_abi = hoist.aarch64_abi;

fn expectIntReg(loc: a64_abi.ArgLoc, idx: u6) !void {
    try testing.expect(loc == .reg);
    try testing.expectEqual(@as(u8, @intFromEnum(hoist.machinst.RegClass.int)), @as(u8, @intFromEnum(loc.reg.class())));
    try testing.expectEqual(@as(u6, idx), loc.reg.hwEnc());
}

test "struct args: 16-byte struct uses register pair x0/x1" {
    var store = StructStore.init(testing.allocator);
    defer store.deinit();

    const fields = [_]StructField{
        .{ .ty = Type.I64, .offset = 0 },
        .{ .ty = Type.I64, .offset = 8 },
    };
    const id = try store.intern(&fields, 16);
    const struct_ty = Type.fromStructId(id);

    const params = [_]AbiParam{AbiParam.new(struct_ty)};
    const locs = try a64_abi.computeArgLocs(testing.allocator, &params, false, &store);
    defer testing.allocator.free(locs);

    try testing.expectEqual(@as(usize, 1), locs.len);
    try testing.expect(locs[0] == .reg_pair);
    try testing.expectEqual(@as(u6, 0), locs[0].reg_pair.lo.hwEnc());
    try testing.expectEqual(@as(u6, 1), locs[0].reg_pair.hi.hwEnc());
}

test "struct args: >16-byte struct is passed indirectly in x0" {
    var store = StructStore.init(testing.allocator);
    defer store.deinit();

    const fields = [_]StructField{
        .{ .ty = Type.I64, .offset = 0 },
        .{ .ty = Type.I64, .offset = 8 },
        .{ .ty = Type.I64, .offset = 16 },
    };
    const id = try store.intern(&fields, 24);
    const struct_ty = Type.fromStructId(id);

    const params = [_]AbiParam{AbiParam.new(struct_ty)};
    const locs = try a64_abi.computeArgLocs(testing.allocator, &params, false, &store);
    defer testing.allocator.free(locs);

    try testing.expectEqual(@as(usize, 1), locs.len);
    try testing.expect(locs[0] == .indirect_reg);
    try testing.expectEqual(@as(u6, 0), locs[0].indirect_reg.hwEnc());
}

test "struct args: HFA f32x2 uses v0-v1" {
    var store = StructStore.init(testing.allocator);
    defer store.deinit();

    const fields = [_]StructField{
        .{ .ty = Type.F32, .offset = 0 },
        .{ .ty = Type.F32, .offset = 4 },
    };
    const id = try store.intern(&fields, 8);
    const struct_ty = Type.fromStructId(id);

    const params = [_]AbiParam{AbiParam.new(struct_ty)};
    const locs = try a64_abi.computeArgLocs(testing.allocator, &params, false, &store);
    defer testing.allocator.free(locs);

    try testing.expectEqual(@as(usize, 1), locs.len);
    try testing.expect(locs[0] == .hfa);
    try testing.expectEqual(@as(u8, 0), locs[0].hfa.base_reg);
    try testing.expectEqual(@as(u8, 2), locs[0].hfa.count);
}

test "struct args: HFA f64x4 uses v0-v3" {
    var store = StructStore.init(testing.allocator);
    defer store.deinit();

    const fields = [_]StructField{
        .{ .ty = Type.F64, .offset = 0 },
        .{ .ty = Type.F64, .offset = 8 },
        .{ .ty = Type.F64, .offset = 16 },
        .{ .ty = Type.F64, .offset = 24 },
    };
    const id = try store.intern(&fields, 32);
    const struct_ty = Type.fromStructId(id);

    const params = [_]AbiParam{AbiParam.new(struct_ty)};
    const locs = try a64_abi.computeArgLocs(testing.allocator, &params, false, &store);
    defer testing.allocator.free(locs);

    try testing.expectEqual(@as(usize, 1), locs.len);
    try testing.expect(locs[0] == .hfa);
    try testing.expectEqual(@as(u8, 0), locs[0].hfa.base_reg);
    try testing.expectEqual(@as(u8, 4), locs[0].hfa.count);
}

test "struct args: mixed i32/f32 is not HFA and uses x0" {
    var store = StructStore.init(testing.allocator);
    defer store.deinit();

    const fields = [_]StructField{
        .{ .ty = Type.I32, .offset = 0 },
        .{ .ty = Type.F32, .offset = 4 },
    };
    const id = try store.intern(&fields, 8);
    const struct_ty = Type.fromStructId(id);

    const params = [_]AbiParam{AbiParam.new(struct_ty)};
    const locs = try a64_abi.computeArgLocs(testing.allocator, &params, false, &store);
    defer testing.allocator.free(locs);

    try testing.expectEqual(@as(usize, 1), locs.len);
    try expectIntReg(locs[0], 0);
}

test "struct args: multiple small structs keep integer register order" {
    var store = StructStore.init(testing.allocator);
    defer store.deinit();

    const s1_fields = [_]StructField{
        .{ .ty = Type.I32, .offset = 0 },
        .{ .ty = Type.I32, .offset = 4 },
    };
    const s2_fields = [_]StructField{.{ .ty = Type.I64, .offset = 0 }};

    const s1_id = try store.intern(&s1_fields, 8);
    const s2_id = try store.intern(&s2_fields, 8);
    const s1_ty = Type.fromStructId(s1_id);
    const s2_ty = Type.fromStructId(s2_id);

    const params = [_]AbiParam{
        AbiParam.new(s1_ty),
        AbiParam.new(s2_ty),
        AbiParam.new(Type.I32),
    };
    const locs = try a64_abi.computeArgLocs(testing.allocator, &params, false, &store);
    defer testing.allocator.free(locs);

    try testing.expectEqual(@as(usize, 3), locs.len);
    try expectIntReg(locs[0], 0);
    try expectIntReg(locs[1], 1);
    try expectIntReg(locs[2], 2);
}
