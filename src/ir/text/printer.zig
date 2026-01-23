const std = @import("std");
const Allocator = std.mem.Allocator;

const function_mod = @import("../function.zig");
const types_mod = @import("../types.zig");
const entities_mod = @import("../entities.zig");
const signature_mod = @import("../signature.zig");
const condcodes_mod = @import("../condcodes.zig");
const instruction_data_mod = @import("../instruction_data.zig");
const dfg_mod = @import("../dfg.zig");
const opcode_mod = @import("../opcodes.zig");

const Function = function_mod.Function;
const Type = types_mod.Type;
const Value = entities_mod.Value;
const Block = entities_mod.Block;
const Inst = entities_mod.Inst;
const Signature = signature_mod.Signature;
const IntCC = condcodes_mod.IntCC;
const FloatCC = condcodes_mod.FloatCC;
const Opcode = opcode_mod.Opcode;
const InstructionData = instruction_data_mod.InstructionData;

pub const Printer = struct {
    buf: std.ArrayList(u8),
    alloc: Allocator,
    func: *const Function,

    pub fn init(alloc: Allocator, func: *const Function) Printer {
        return .{
            .buf = .{},
            .alloc = alloc,
            .func = func,
        };
    }

    fn writer(self: *Printer) std.ArrayList(u8).Writer {
        return self.buf.writer(self.alloc);
    }

    pub fn deinit(self: *Printer) void {
        self.buf.deinit(self.alloc);
    }

    pub fn finish(self: *Printer) []const u8 {
        return self.buf.items;
    }

    pub fn print(self: *Printer) !void {
        try self.printSignature();
        try self.writer().writeAll(" {\n");

        var it = self.func.layout.blockIter();
        while (it.next()) |blk| {
            try self.printBlock(blk);
        }

        try self.writer().writeAll("}\n");
    }

    fn printSignature(self: *Printer) !void {
        try self.writer().writeAll("function");

        if (self.func.name.len > 0) {
            try self.writer().print(" \"{s}\"", .{self.func.name});
        }

        const sig = &self.func.sig;
        try self.writer().writeAll(" (");

        for (sig.params.items, 0..) |param, i| {
            if (i > 0) try self.writer().writeAll(", ");
            try self.printType(param.value_type);
        }

        try self.writer().writeAll(")");

        if (sig.returns.items.len > 0) {
            try self.writer().writeAll(" -> ");
            if (sig.returns.items.len == 1) {
                try self.printType(sig.returns.items[0].value_type);
            } else {
                try self.writer().writeAll("(");
                for (sig.returns.items, 0..) |ret, i| {
                    if (i > 0) try self.writer().writeAll(", ");
                    try self.printType(ret.value_type);
                }
                try self.writer().writeAll(")");
            }
        }
    }

    fn printBlock(self: *Printer, blk: Block) !void {
        try self.writer().print("  block{d}", .{blk.asU32()});

        const params = self.func.dfg.blockParams(blk);
        if (params.len > 0) {
            try self.writer().writeAll("(");
            for (params, 0..) |val, i| {
                if (i > 0) try self.writer().writeAll(", ");
                try self.printValue(val);
                try self.writer().writeAll(": ");
                try self.printType(self.func.dfg.valueType(val).?);
            }
            try self.writer().writeAll(")");
        }

        try self.writer().writeAll(":\n");

        var inst_iter = self.func.layout.blockInsts(blk);
        while (inst_iter.next()) |inst| {
            try self.printInst(inst);
        }
        try self.writer().writeAll("\n");
    }

    fn printInst(self: *Printer, inst: Inst) !void {
        const data = self.func.dfg.insts.get(inst).?.*;
        const results = self.func.dfg.instResults(inst);

        try self.writer().writeAll("    ");

        if (results.len > 0) {
            for (results, 0..) |val, i| {
                if (i > 0) try self.writer().writeAll(", ");
                try self.printValue(val);
            }
            try self.writer().writeAll(" = ");
        }

        try self.printInstData(data);
        try self.writer().writeAll("\n");
    }

    fn printInstData(self: *Printer, data: InstructionData) !void {
        switch (data) {
            .unary => |u| {
                try self.printOpcode(u.opcode);
                try self.writer().writeAll(" ");
                try self.printValue(u.arg);
            },
            .binary => |b| {
                try self.printOpcode(b.opcode);
                try self.writer().writeAll(" ");
                try self.printValue(b.args[0]);
                try self.writer().writeAll(", ");
                try self.printValue(b.args[1]);
            },

            .binary_imm64 => |bi| {
                try self.printOpcode(bi.opcode);
                try self.writer().writeAll(" ");
                try self.printValue(bi.arg);
                try self.writer().print(", {d}", .{bi.imm.value});
            },
            .int_compare => |ic| {
                try self.writer().writeAll("icmp ");
                try self.printIntCC(ic.cond);
                try self.writer().writeAll(" ");
                try self.printValue(ic.args[0]);
                try self.writer().writeAll(", ");
                try self.printValue(ic.args[1]);
            },
            .float_compare => |fc| {
                try self.writer().writeAll("fcmp ");
                try self.printFloatCC(fc.cond);
                try self.writer().writeAll(" ");
                try self.printValue(fc.args[0]);
                try self.writer().writeAll(", ");
                try self.printValue(fc.args[1]);
            },
            .unary_imm => |ui| {
                try self.printOpcode(ui.opcode);
                try self.writer().print(" {d}", .{ui.imm.value});
            },
            .jump => |j| {
                try self.printOpcode(j.opcode);
                try self.writer().writeAll(" ");
                try self.printBlockRef(j.destination);
            },
            .branch => |br| {
                try self.printOpcode(br.opcode);
                try self.writer().writeAll(" ");
                try self.printValue(br.condition);
                try self.writer().writeAll(", ");
                if (br.then_dest) |td| try self.printBlockRef(td);
                try self.writer().writeAll(", ");
                if (br.else_dest) |ed| try self.printBlockRef(ed);
            },
            .branch_z => |br| {
                try self.printOpcode(br.opcode);
                try self.writer().writeAll(" ");
                try self.printValue(br.condition);
                try self.writer().writeAll(", ");
                try self.printBlockRef(br.destination);
            },
            .call => |c| {
                try self.printOpcode(c.opcode);
                try self.writer().writeAll(" ");
                try self.writer().print("fn{d}", .{c.func_ref.asU32()});
            },
            .call_indirect => |ci| {
                try self.printOpcode(ci.opcode);
                try self.writer().writeAll(" ");
                try self.writer().print("sig{d}", .{ci.sig_ref.asU32()});
            },
            .nullary => |n| {
                try self.printOpcode(n.opcode);
            },
            .load => |l| {
                try self.printOpcode(l.opcode);
                try self.writer().writeAll(" ");
                try self.printValue(l.arg);
            },
            .store => |s| {
                try self.printOpcode(s.opcode);
                try self.writer().writeAll(" ");
                try self.printValue(s.args[0]);
                try self.writer().writeAll(", ");
                try self.printValue(s.args[1]);
            },
            .stack_load => |sl| {
                try self.writer().writeAll("stack_load ");
                try self.writer().print("ss{d}", .{sl.stack_slot.asU32()});
            },
            .stack_store => |ss| {
                try self.writer().writeAll("stack_store ");
                try self.printValue(ss.arg);
                try self.writer().print(", ss{d}", .{ss.stack_slot.asU32()});
            },
            else => {
                try self.writer().writeAll("???");
            },
        }
    }

    fn printOpcode(self: *Printer, opc: Opcode) !void {
        try self.writer().writeAll(@tagName(opc));
    }

    fn printIntCC(self: *Printer, cc: IntCC) !void {
        try self.writer().writeAll(@tagName(cc));
    }

    fn printFloatCC(self: *Printer, cc: FloatCC) !void {
        try self.writer().writeAll(@tagName(cc));
    }

    fn printValue(self: *Printer, val: Value) !void {
        try self.writer().print("v{d}", .{val.asU32()});
    }

    fn printBlockRef(self: *Printer, blk: Block) !void {
        try self.writer().print("block{d}", .{blk.asU32()});
    }

    fn printType(self: *Printer, ty: Type) !void {
        const name = if (ty.eql(Type.I8)) "i8"
        else if (ty.eql(Type.I16)) "i16"
        else if (ty.eql(Type.I32)) "i32"
        else if (ty.eql(Type.I64)) "i64"
        else if (ty.eql(Type.I128)) "i128"
        else if (ty.eql(Type.F32)) "f32"
        else if (ty.eql(Type.F64)) "f64"
        else "???";
        try self.writer().writeAll(name);
    }
};
