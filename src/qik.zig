const std = @import("std");
const fs = std.fs;
const io = std.io;

const variableCount = 256;

const standardInstructionSize = 3;

pub const QikError = error{ MalformedBytecode, InvalidOpcode, ReservedOpcode, NullRegisterAccess, FunctionNotFound, NotEnoughArguments };

const Opcode = enum(u8) { Nop, Halt, Call, Callext, Alloc, Free, Jmp, Set, _ };

const InstructionOpcode = struct {
    op: Opcode,
    imm: bool,
    ptr: bool,
    fn init(byte: u8) InstructionOpcode {
        return .{ .op = @enumFromInt(byte >> 2), .imm = byte & 0b10 == 2, .ptr = byte & 0b1 == 1 };
    }
};

const QikFunc = *const fn (*VM, [][]u8) anyerror!void;

const qikFuncs = struct {
    fn putc(vm: *VM, args: [][]u8) anyerror!void {
        try vm.expectArgs(1, &args);

        var bw = io.bufferedWriter(vm.out.writer());
        const outwtr = bw.writer();

        try outwtr.print("{c}", .{args[0][0]});
        try bw.flush();
    }
    fn print(vm: *VM, args: [][]u8) anyerror!void {
        try vm.expectArgs(1, &args);

        var bw = io.bufferedWriter(vm.out.writer());
        const outwtr = bw.writer();

        try outwtr.print("{s}", .{args[0]});
        try bw.flush();
    }
    fn readline(vm: *VM, args: [][]u8) anyerror {
        try vm.expectArgs(1, args);

        var bw = io.bufferedReader(vm.in.reader());
        const inrdr = bw.reader();

        try inrdr.readUntilDelimiter(args[0], '\n');
    }
};

pub const VM = struct {
    vars: [variableCount]?[]u8 = [_]?[]u8{null} ** variableCount,
    funcs: std.StringHashMap(QikFunc),
    pc: usize,
    allocator: std.mem.Allocator,
    in: fs.File,
    out: fs.File,
    err: []const u8,
    pub fn init(allocator: std.mem.Allocator, in: fs.File, out: fs.File) !VM {
        var inst = VM{
            .pc = 0,
            .allocator = allocator,
            .in = in,
            .out = out,
            .err = undefined,
            .funcs = std.StringHashMap(QikFunc).init(allocator),
        };

        try inst.funcs.put("putc", &qikFuncs.putc);
        try inst.funcs.put("print", &qikFuncs.print);

        return inst;
    }
    pub fn deinit(self: *VM) void {
        for (self.vars) |v| {
            if (v != null) {
                self.allocator.free(v.?);
            }
        }
    }
    fn errf(self: *VM, e: QikError, comptime fmt: []const u8, args: anytype) anyerror!void {
        self.err = try std.fmt.allocPrint(self.allocator, fmt, args);
        return e;
    }
    fn checkNull(self: *VM, ind: usize) !void {
        if (self.vars[ind] == null) {
            try self.errf(QikError.NullRegisterAccess, "attempt to access null register {d}", .{ind});
        }
    }
    fn expectArgs(vm: *VM, expected: usize, args: *const [][]u8) anyerror!void {
        if (args.len < expected) {
            try vm.errf(QikError.NotEnoughArguments, "expected {d} arguments but only {d} were given", .{ expected, args.len });
        }
    }
    fn advance(self: *VM) void {
        self.pc += standardInstructionSize;
    }
    pub fn loadArgs(self: *VM, args: [][]u8) !u8 {
        for (args, 0..) |a, i| {
            self.vars[i] = a;
        }
    }
    pub fn rget(self: *VM, ind: usize) ![]u8 {
        try self.checkNull(ind);
        return self.vars[ind].?;
    }
    pub fn rset(self: *VM, imm: bool, ind: usize, val: u8) !void {
        if (self.vars[ind] == null) {
            self.vars[ind] = try self.allocator.alloc(u8, 1);
        }

        if (imm) {
            self.vars[ind].?[0] = val;
        } else {
            self.vars[ind].?[0] = self.vars[@intCast(val)].?[0];
        }
    }
    pub fn execute(self: *VM, bytes: []const u8) !u8 {
        if (bytes.len >= 4) {
            if (bytes[0] == 'D' and bytes[1] == 'A' and bytes[2] == 'T' and bytes[3] == 'A') {
                if (bytes.len < 8) {
                    try self.errf(QikError.MalformedBytecode, "malformed bytecode, invalid DATA section", .{});
                }

                for (0..4) |i| {
                    self.pc <<= 8;
                    self.pc |= @intCast(bytes[4 + i]);
                }

                self.pc += 8;
            } else {
                try self.errf(QikError.MalformedBytecode, "malformed bytecode, no DATA section found", .{});
            }

            const valid = if (self.pc + 3 >= bytes.len)
                false
            else
                bytes[self.pc] == 'T' and
                    bytes[self.pc + 1] == 'E' and
                    bytes[self.pc + 2] == 'X' and
                    bytes[self.pc + 3] == 'T';

            if (!valid) {
                try self.errf(QikError.MalformedBytecode, "malformed bytecode, no TEXT section found", .{});
            }

            self.pc += 4;
        } else {
            try self.errf(QikError.MalformedBytecode, "malformed bytecode, no DATA or TEXT sections found", .{});
        }

        while (true) {
            const opcode = InstructionOpcode.init(bytes[self.pc]);

            switch (opcode.op) {
                .Nop => self.pc += 1, // nop
                .Halt => { // halt
                    const ecode = if (opcode.imm) {
                        return bytes[self.pc + 1];
                    } else {
                        const ind: usize = @intCast(bytes[self.pc + 1]);
                        try self.checkNull(ind);

                        return self.vars[ind].?[0];
                    };

                    return ecode;
                },
                .Call => { // call
                    const nameLength: usize = @intCast(bytes[self.pc + 1]);
                    var name = try self.allocator.alloc(u8, nameLength);
                    defer self.allocator.free(name);

                    for (0..nameLength) |i| {
                        name[i] = bytes[self.pc + 2 + i];
                    }

                    const argCount = bytes[self.pc + 2 + nameLength];
                    var args = try self.allocator.alloc([]u8, argCount);
                    defer self.allocator.free(args);

                    for (0..args.len) |i| {
                        args[i] = try self.rget(@intCast(bytes[self.pc + 3 + nameLength + i]));
                    }

                    if (self.funcs.get(name)) |f| {
                        try f(self, args);
                    } else {
                        try self.errf(QikError.FunctionNotFound, "function '{s}' does not exist", .{name});
                    }

                    self.pc += 3 + nameLength + argCount;
                },
                .Callext => { // callext
                    try self.errf(QikError.ReservedOpcode, "opcode {d} is reversed and should not be used", .{opcode.op});
                    self.pc += 1;
                },
                .Alloc => { // alloc
                    const ind: usize = @intCast(bytes[self.pc + 1]);
                    const amount: usize = @intCast(bytes[self.pc + 2]);

                    if (self.vars[ind] != null) {
                        self.allocator.free(self.vars[ind].?);
                    }

                    self.vars[ind] = try self.allocator.alloc(u8, if (opcode.imm) amount else @intCast((try self.rget(amount))[0]));

                    self.advance();
                },
                .Set => { // set
                    try self.rset(opcode.imm, @intCast(bytes[self.pc + 1]), bytes[self.pc + 2]);
                    self.advance();
                },
                _ => try self.errf(QikError.InvalidOpcode, "invalid opcode {d} for address {d}", .{ opcode.op, self.pc }),
            }
        }

        return 0;
    }
};
