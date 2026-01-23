const std = @import("std");
const root = @import("../root.zig");

const Function = root.function.Function;
const InstructionData = root.instruction_data.InstructionData;
const Value = root.entities.Value;
const Block = root.entities.Block;
const MemFlags = root.memflags.MemFlags;
const Imm64 = root.immediates.Imm64;
const Imm128 = root.immediates.Imm128;

pub const PrintOptions = struct {
    show_types: bool = true,
};

pub fn writeFunction(writer: anytype, func: *const Function, options: PrintOptions) !void {
    try writer.print("function \"{s}\" {f}\n", .{ func.name, func.sig });

    var block_iter = func.layout.blockIter();
    while (block_iter.next()) |block| {
        try writer.print("{f}", .{block});
        const params = func.dfg.blockParams(block);
        if (params.len > 0) {
            try writer.writeAll("(");
            try writeValueList(writer, func, params, options);
            try writer.writeAll(")");
        }
        try writer.writeAll(":\n");

        var inst_iter = func.layout.blockInsts(block);
        while (inst_iter.next()) |inst| {
            try writer.writeAll("  ");
            const results = func.dfg.instResults(inst);
            if (results.len > 0) {
                try writeValueList(writer, func, results, options);
                try writer.writeAll(" = ");
            }

            const inst_data = func.dfg.insts.get(inst) orelse {
                try writer.writeAll("<missing>\n");
                continue;
            };
            try writeInstData(writer, func, inst_data.*, options);
            try writer.writeAll("\n");
        }
    }
}

fn writeInstData(writer: anytype, func: *const Function, data: InstructionData, options: PrintOptions) !void {
    switch (data) {
        .nullary => |d| {
            try writer.writeAll(@tagName(d.opcode));
        },
        .unary_imm => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeImm64(writer, d.imm);
        },
        .unary => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.arg, options);
        },
        .unary_with_trap => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.arg, options);
            try writer.print(" trap={any}", .{d.trap_code});
        },
        .extract_lane => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.arg, options);
            try writer.print(" lane={d}", .{d.lane});
        },
        .ternary => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.args[0], options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.args[1], options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.args[2], options);
        },
        .ternary_imm8 => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.args[0], options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.args[1], options);
            try writer.print(", imm={d}", .{d.imm});
        },
        .shuffle => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.args[0], options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.args[1], options);
            try writer.writeAll(", mask=");
            try writeImm128(writer, d.mask);
        },
        .binary => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.args[0], options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.args[1], options);
        },
        .binary_imm64 => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.arg, options);
            try writer.writeAll(", ");
            try writeImm64(writer, d.imm);
        },
        .int_compare => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.print(" {s} ", .{@tagName(d.cond)});
            try writeValue(writer, func, d.args[0], options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.args[1], options);
        },
        .int_compare_imm => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.print(" {s} ", .{@tagName(d.cond)});
            try writeValue(writer, func, d.arg, options);
            try writer.writeAll(", ");
            try writeImm64(writer, d.imm);
        },
        .float_compare => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.print(" {s} ", .{@tagName(d.cond)});
            try writeValue(writer, func, d.args[0], options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.args[1], options);
        },
        .branch => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.condition, options);
            try writer.writeAll(", ");
            if (d.then_dest) |then_blk| {
                const then_args = func.dfg.value_lists.asSlice(d.then_args);
                try writer.writeAll("then=");
                try writeBlockWithArgs(writer, func, then_blk, then_args, options);
            } else {
                try writer.writeAll("then=?");
            }
            try writer.writeAll(", ");
            if (d.else_dest) |else_blk| {
                const else_args = func.dfg.value_lists.asSlice(d.else_args);
                try writer.writeAll("else=");
                try writeBlockWithArgs(writer, func, else_blk, else_args, options);
            } else {
                try writer.writeAll("else=?");
            }
        },
        .jump => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            const args = func.dfg.value_lists.asSlice(d.args);
            try writeBlockWithArgs(writer, func, d.destination, args, options);
        },
        .branch_table => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.arg, options);
            try writer.writeAll(", ");
            try writer.print("{f}", .{d.destination});
        },
        .branch_z => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.condition, options);
            try writer.writeAll(", ");
            const args = func.dfg.value_lists.asSlice(d.args);
            try writeBlockWithArgs(writer, func, d.destination, args, options);
        },
        .call => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writer.print("{f}", .{d.func_ref});
            try writer.writeAll("(");
            try writeValueList(writer, func, func.dfg.value_lists.asSlice(d.args), options);
            try writer.writeAll(")");
        },
        .call_indirect => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writer.print("{f}", .{d.sig_ref});
            try writer.writeAll("(");
            try writeValueList(writer, func, func.dfg.value_lists.asSlice(d.args), options);
            try writer.writeAll(")");
        },
        .try_call => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writer.print("{f}", .{d.func_ref});
            try writer.writeAll("(");
            try writeValueList(writer, func, func.dfg.value_lists.asSlice(d.args), options);
            try writer.writeAll(")");
            try writer.print(" normal={f} exn={f}", .{ d.normal_successor, d.exception_successor });
        },
        .try_call_indirect => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writer.print("{f}", .{d.sig_ref});
            try writer.writeAll("(");
            try writeValueList(writer, func, func.dfg.value_lists.asSlice(d.args), options);
            try writer.writeAll(")");
            try writer.print(" normal={f} exn={f}", .{ d.normal_successor, d.exception_successor });
        },
        .load => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.arg, options);
            try writer.print(", offset={d} ", .{d.offset});
            try writeMemFlags(writer, d.flags);
        },
        .store => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.args[0], options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.args[1], options);
            try writer.print(", offset={d} ", .{d.offset});
            try writeMemFlags(writer, d.flags);
        },
        .atomic_load => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.addr, options);
            try writer.writeAll(" ");
            try writeMemFlags(writer, d.flags);
            try writer.print(" order={s}", .{@tagName(d.ordering)});
        },
        .atomic_store => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.addr, options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.src, options);
            try writer.writeAll(" ");
            try writeMemFlags(writer, d.flags);
            try writer.print(" order={s}", .{@tagName(d.ordering)});
        },
        .atomic_rmw => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writer.print("op={s} ", .{@tagName(d.op)});
            try writeValue(writer, func, d.addr, options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.src, options);
            try writer.writeAll(" ");
            try writeMemFlags(writer, d.flags);
            try writer.print(" order={s}", .{@tagName(d.ordering)});
        },
        .atomic_cas => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.addr, options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.expected, options);
            try writer.writeAll(", ");
            try writeValue(writer, func, d.replacement, options);
            try writer.writeAll(" ");
            try writeMemFlags(writer, d.flags);
            try writer.print(" order={s}", .{@tagName(d.ordering)});
        },
        .fence => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.print(" order={s}", .{@tagName(d.ordering)});
        },
        .stack_load => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writer.print("{f} offset={d}", .{ d.stack_slot, d.offset });
        },
        .stack_store => |d| {
            try writer.writeAll(@tagName(d.opcode));
            try writer.writeAll(" ");
            try writeValue(writer, func, d.arg, options);
            try writer.print(", {f} offset={d}", .{ d.stack_slot, d.offset });
        },
    }
}

fn writeValue(writer: anytype, func: *const Function, value: Value, options: PrintOptions) !void {
    try writer.print("{f}", .{value});
    if (!options.show_types) return;
    if (func.dfg.valueType(value)) |ty| {
        try writer.print(":{f}", .{ty});
    }
}

fn writeValueList(writer: anytype, func: *const Function, values: []const Value, options: PrintOptions) !void {
    for (values, 0..) |value, i| {
        if (i > 0) try writer.writeAll(", ");
        try writeValue(writer, func, value, options);
    }
}

fn writeBlockWithArgs(
    writer: anytype,
    func: *const Function,
    block: Block,
    args: []const Value,
    options: PrintOptions,
) !void {
    try writer.print("{f}", .{block});
    if (args.len == 0) return;
    try writer.writeAll("(");
    try writeValueList(writer, func, args, options);
    try writer.writeAll(")");
}

fn writeMemFlags(writer: anytype, flags: MemFlags) !void {
    try writer.print(
        "{{region={s}, volatile={any}, aligned={any}}}",
        .{ @tagName(flags.alias_region), flags.is_volatile, flags.aligned },
    );
}

fn writeImm64(writer: anytype, imm: Imm64) !void {
    try writer.print("{d}", .{imm.bits()});
}

fn writeImm128(writer: anytype, imm: Imm128) !void {
    try writer.writeAll("0x");
    for (imm.toBytes()) |byte| {
        try writer.print("{x:0>2}", .{byte});
    }
}

test "IR print basic" {
    const testing = std.testing;
    const OhSnap = @import("ohsnap");
    const ir = root;

    var sig = ir.signature.Signature.init(testing.allocator, .system_v);
    // Note: sig ownership transferred to func, func.deinit() frees it

    try sig.params.append(testing.allocator, ir.signature.AbiParam.new(ir.types.Type.I32));
    try sig.params.append(testing.allocator, ir.signature.AbiParam.new(ir.types.Type.I32));
    try sig.returns.append(testing.allocator, ir.signature.AbiParam.new(ir.types.Type.I32));

    var func = try ir.function.Function.init(testing.allocator, "print_test", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);
    try func.dfg.setBlockParams(entry, &[_]ir.types.Type{ ir.types.Type.I32, ir.types.Type.I32 });

    const params = func.dfg.blockParams(entry);

    const iconst = ir.instruction_data.InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = ir.immediates.Imm64.new(42),
        },
    };
    const iconst_inst = try func.dfg.makeInst(iconst);
    try func.layout.appendInst(iconst_inst, entry);
    const v_const = try func.dfg.appendInstResult(iconst_inst, ir.types.Type.I32);

    const add = ir.instruction_data.InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ params[0], v_const },
        },
    };
    const add_inst = try func.dfg.makeInst(add);
    try func.layout.appendInst(add_inst, entry);
    const add_res = try func.dfg.appendInstResult(add_inst, ir.types.Type.I32);

    const ret = ir.instruction_data.InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_res,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret);
    try func.layout.appendInst(ret_inst, entry);

    var out = std.ArrayList(u8){};
    defer out.deinit(testing.allocator);
    try writeFunction(out.writer(testing.allocator), &func, .{});

    const oh = OhSnap{};
    const Fmt = struct {
        text: []const u8,

        pub fn format(self: @This(), writer: anytype) !void {
            try writer.writeAll(self.text);
        }
    };

    try oh.snap(
        @src(),
        \\function "print_test" (i32, i32) -> i32 system_v
        \\block0(v0:i32, v1:i32):
        \\  v2:i32 = iconst 42
        \\  v3:i32 = iadd v0:i32, v2:i32
        \\  return v3:i32
        \\
        ,
    ).expectEqualFmt(Fmt{ .text = out.items });
}
