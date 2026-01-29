const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const types = @import("../ir/types.zig");
const sig_mod = @import("../ir/signature.zig");
const module = @import("../module/module.zig");
const symbols = @import("../module/symbols.zig");
const jit_mem = @import("memory.zig");

const FuncId = module.FuncId;
const DataId = module.DataId;
const Linkage = module.Linkage;
const ModuleDeclarations = module.ModuleDeclarations;
const DataDesc = module.DataDesc;

/// JIT-compiled blob with relocations.
const CompiledBlob = struct {
    ptr: [*]u8,
    size: usize,
    relocs: std.ArrayList(Reloc),

    fn init() CompiledBlob {
        return .{
            .ptr = undefined,
            .size = 0,
            .relocs = .{},
        };
    }

    fn deinit(self: *CompiledBlob, alloc: Allocator) void {
        self.relocs.deinit(alloc);
    }

    fn performRelocs(self: *const CompiledBlob, ctx: anytype) !void {
        for (self.relocs.items) |reloc| {
            const at = self.ptr + reloc.offset;
            const base = try ctx.getAddr(reloc.target);
            const what = base + @as(usize, @intCast(reloc.addend));

            switch (reloc.kind) {
                .abs8 => {
                    const ptr: *u64 = @ptrCast(@alignCast(at));
                    ptr.* = @intCast(what);
                },
                .arm64_call => {
                    const iptr: *u32 = @ptrCast(@alignCast(at));
                    const diff = @as(isize, @intCast(what)) - @as(isize, @intCast(@intFromPtr(at)));
                    const offset = @as(i32, @intCast(diff >> 2));
                    std.debug.assert((offset >> 26 == -1) or (offset >> 26 == 0));
                    const imm26 = @as(u32, @bitCast(offset)) & 0x3ffffff;
                    iptr.* |= imm26;
                },
                .aarch64_adr_prel_pg_hi21 => {
                    const get_page = struct {
                        fn f(x: usize) usize {
                            return x & ~@as(usize, 0xfff);
                        }
                    }.f;
                    const pcrel = @as(i32, @intCast(get_page(what) - get_page(@intFromPtr(at))));
                    const iptr: *u32 = @ptrCast(@alignCast(at));
                    const hi21 = @as(u32, @bitCast(pcrel >> 12));
                    const lo = (hi21 & 0x3) << 29;
                    const hi = (hi21 & 0x1ffffc) << 3;
                    iptr.* |= lo | hi;
                },
                .aarch64_add_abs_lo12_nc => {
                    const iptr: *u32 = @ptrCast(@alignCast(at));
                    const imm12 = @as(u32, @intCast(what & 0xfff)) << 10;
                    iptr.* |= imm12;
                },
            }
        }
    }
};

/// Relocation kind.
const RelocKind = enum {
    abs8,
    arm64_call,
    aarch64_adr_prel_pg_hi21,
    aarch64_add_abs_lo12_nc,
};

/// Module relocation.
const Reloc = struct {
    kind: RelocKind,
    offset: u32,
    target: RelocTarget,
    addend: i64,
};

/// Relocation target.
const RelocTarget = union(enum) {
    func: FuncId,
    data: DataId,
    symbol: []const u8,
};

/// JIT module.
pub const JitModule = struct {
    alloc: Allocator,
    code_mem: *jit_mem.Mem,
    data_mem: *jit_mem.Mem,
    decls: ModuleDeclarations,
    funcs: std.ArrayList(?CompiledBlob),
    data: std.ArrayList(?CompiledBlob),
    syms: std.StringHashMap(usize),
    to_finalize: std.ArrayList(FuncId),
    data_to_finalize: std.ArrayList(DataId),
    finalized: bool,

    pub fn init(alloc: Allocator) !JitModule {
        const code_mem = try alloc.create(jit_mem.Mem);
        errdefer alloc.destroy(code_mem);
        code_mem.* = try jit_mem.Mem.init(alloc, 1024 * 1024);
        errdefer code_mem.deinit();

        const data_mem = try alloc.create(jit_mem.Mem);
        errdefer alloc.destroy(data_mem);
        data_mem.* = try jit_mem.Mem.init(alloc, 1024 * 1024);
        errdefer data_mem.deinit();

        return .{
            .alloc = alloc,
            .code_mem = code_mem,
            .data_mem = data_mem,
            .decls = ModuleDeclarations.init(alloc),
            .funcs = .{},
            .data = .{},
            .syms = std.StringHashMap(usize).init(alloc),
            .to_finalize = .{},
            .data_to_finalize = .{},
            .finalized = false,
        };
    }

    pub fn deinit(self: *JitModule) void {
        for (self.funcs.items) |*maybe_blob| {
            if (maybe_blob.*) |*blob| {
                blob.deinit(self.alloc);
            }
        }
        for (self.data.items) |*maybe_blob| {
            if (maybe_blob.*) |*blob| {
                blob.deinit(self.alloc);
            }
        }
        self.funcs.deinit(self.alloc);
        self.data.deinit(self.alloc);
        self.syms.deinit();
        self.to_finalize.deinit(self.alloc);
        self.data_to_finalize.deinit(self.alloc);
        self.decls.deinit();
        self.code_mem.deinit();
        self.alloc.destroy(self.code_mem);
        self.data_mem.deinit();
        self.alloc.destroy(self.data_mem);
    }

    pub fn declareFunction(
        self: *JitModule,
        name: []const u8,
        linkage: Linkage,
        signature: sig_mod.Signature,
    ) !FuncId {
        if (self.finalized) return error.AlreadyFinalized;
        _ = signature;
        const name_copy = try self.alloc.dupe(u8, name);
        const id = FuncId.from(@intCast(self.funcs.items.len));
        try self.funcs.append(self.alloc, null);
        try self.decls.names.put(name_copy, .{ .func = id });
        _ = linkage;
        return id;
    }

    pub fn declareData(
        self: *JitModule,
        name: []const u8,
        linkage: Linkage,
        writable: bool,
        tls: bool,
    ) !DataId {
        if (self.finalized) return error.AlreadyFinalized;
        _ = linkage;
        _ = writable;
        _ = tls;
        const name_copy = try self.alloc.dupe(u8, name);
        const id = DataId.from(@intCast(self.data.items.len));
        try self.data.append(self.alloc, null);
        try self.decls.names.put(name_copy, .{ .data = id });
        return id;
    }

    pub fn defineFunction(
        self: *JitModule,
        id: FuncId,
        bytes: []const u8,
        relocs: []const Reloc,
    ) !void {
        if (self.finalized) return error.AlreadyFinalized;
        var blob = CompiledBlob.init();
        blob.size = bytes.len;
        try blob.relocs.appendSlice(self.alloc, relocs);

        // Allocate and copy
        const dest = try self.code_mem.alloc(bytes.len, 16);
        try self.code_mem.writeExec(dest, bytes);
        blob.ptr = dest.ptr;

        self.funcs.items[id.idx] = blob;
        try self.to_finalize.append(self.alloc, id);
    }

    pub fn defineData(
        self: *JitModule,
        id: DataId,
        desc: *const DataDesc,
    ) !void {
        if (self.finalized) return error.AlreadyFinalized;
        var blob = CompiledBlob.init();
        const alignment = desc.@"align" orelse 8;
        switch (desc.init) {
            .uninit => return error.UninitializedData,
            .zeros => |sz| {
                blob.size = sz;
                const dest = try self.data_mem.alloc(sz, alignment);
                @memset(dest, 0);
                blob.ptr = dest.ptr;
            },
            .bytes => |b| {
                blob.size = b.len;
                const dest = try self.data_mem.alloc(b.len, alignment);
                try self.data_mem.writeAt(dest, b);
                blob.ptr = dest.ptr;
            },
        }

        for (desc.func_relocs.items) |fr| {
            try blob.relocs.append(self.alloc, .{
                .kind = .abs8,
                .offset = fr.offset,
                .target = .{ .func = fr.func },
                .addend = 0,
            });
        }
        for (desc.data_relocs.items) |dr| {
            try blob.relocs.append(self.alloc, .{
                .kind = .abs8,
                .offset = dr.offset,
                .target = switch (dr.target) {
                    .func => |f| .{ .func = f },
                    .data => |d| .{ .data = d },
                    .symbol => |s| .{ .symbol = s },
                },
                .addend = dr.addend,
            });
        }

        self.data.items[id.idx] = blob;
        try self.data_to_finalize.append(self.alloc, id);
    }

    pub fn finalize(self: *JitModule) !void {
        if (self.finalized) return error.AlreadyFinalized;
        const RelocCtx = struct {
            s: *JitModule,

            fn getAddr(ctx: @This(), target: RelocTarget) !usize {
                return switch (target) {
                    .func => |fid| blk: {
                        if (fid.idx >= ctx.s.funcs.items.len) return error.MissingFunction;
                        const b = ctx.s.funcs.items[fid.idx] orelse return error.MissingFunction;
                        break :blk @intFromPtr(b.ptr);
                    },
                    .data => |did| blk: {
                        if (did.idx >= ctx.s.data.items.len) return error.MissingData;
                        const b = ctx.s.data.items[did.idx] orelse return error.MissingData;
                        break :blk @intFromPtr(b.ptr);
                    },
                    .symbol => |sym| ctx.s.syms.get(sym) orelse return error.MissingSymbol,
                };
            }
        };
        const ctx = RelocCtx{ .s = self };

        for (self.to_finalize.items) |id| {
            if (self.funcs.items[id.idx]) |*blob| {
                try blob.performRelocs(ctx);
                self.code_mem.flushCacheRange(blob.ptr, blob.size);
            }
        }
        self.to_finalize.clearRetainingCapacity();

        for (self.data_to_finalize.items) |id| {
            if (self.data.items[id.idx]) |*blob| {
                try blob.performRelocs(ctx);
            }
        }
        self.data_to_finalize.clearRetainingCapacity();

        try self.code_mem.setExec(true);
        self.finalized = true;
    }

    pub fn getFn(self: *const JitModule, id: FuncId, comptime T: type) !T {
        if (id.idx >= self.funcs.items.len) return error.MissingFunction;
        const blob = self.funcs.items[id.idx] orelse return error.MissingFunction;
        return @ptrCast(@alignCast(blob.ptr));
    }

    pub fn getData(self: *const JitModule, id: DataId, comptime T: type) !T {
        if (id.idx >= self.data.items.len) return error.MissingData;
        const blob = self.data.items[id.idx] orelse return error.MissingData;
        return @ptrCast(@alignCast(blob.ptr));
    }

    pub fn declarations(self: *const JitModule) *const ModuleDeclarations {
        return &self.decls;
    }
};
