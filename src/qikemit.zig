const std = @import("std");

pub const Opcode = enum(u8) { Nop, Halt, Call, Callext, Set };

fn splitSize(n: usize) []u8 {
    return &[_]u8{ @intCast(n >> 24), @intCast(n >> 16), @intCast(n >> 8), @intCast(n) };
}

const Emitter = struct {
    instructions: std.ArrayList(u8),
    data: std.ArrayList(u8),
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) Emitter {
        return .{ .instructions = std.ArrayList(u8).init(allocator), .data = std.ArrayList(u8).init(allocator), .allocator = allocator };
    }
    fn addData(self: *Emitter, b: []const u8) !void {
        try self.data.appendSlice(b);
    }
    fn emit(self: *Emitter, b: u8) !void {
        try self.data.append(b);
    }
    fn emitMany(self: *Emitter, b: []const u8) !void {
        try self.bytes.appendSlice(b);
    }
    pub fn emitIns(self: *Emitter, opcode: Opcode, a: u8, b: u8) !void {
        try self.emitMany(&[_]u8{ opcode << 2, a, b });
    }
    pub fn emitImm(self: *Emitter, opcode: Opcode, ind: u8, imm: u8) !void {
        try self.emitMany(&[_]u8{ (opcode << 2) | 2, ind, imm });
    }
    pub fn emitCall(self: *Emitter, opcode: Opcode, name: []const u8, args: []const u8) !void {
        try self.emit(opcode << 2);
        try self.emitMany(splitSize(name.len));
        try self.emitMany(name);
        try self.emitMany(splitSize(args.len));
        try self.emitMany(args);
    }
};
