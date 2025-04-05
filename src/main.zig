const std = @import("std");
const io = std.io;

const qikvm = @import("qik.zig");
const QikError = qikvm.QikError;

pub fn main() !u8 {
    const allocator = std.heap.page_allocator;

    const stdout_file = io.getStdOut().writer();
    var bw = io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    defer bw.flush() catch {};

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try stdout.print("expected 'qik <file>'\n", .{});
        return 1;
    }

    const input = args[1];

    const dir = std.fs.cwd();

    const maxSize = std.math.maxInt(usize);
    const content = dir.readFileAlloc(allocator, input, maxSize) catch |err| switch (err) {
        std.posix.OpenError.FileNotFound => {
            try stdout.print("file '{s}' does not exist\n", .{input});
            return 1;
        },
        else => return err,
    };
    defer allocator.free(content);

    var vm = try qikvm.VM.init(allocator, io.getStdIn(), io.getStdOut());
    defer vm.deinit();

    const ecode = vm.execute(content) catch |e| switch (e) {
        QikError.NullRegisterAccess, QikError.InvalidOpcode, QikError.NotEnoughArguments, QikError.FunctionNotFound, QikError.MalformedBytecode => {
            try stdout.print("{s}\n", .{vm.err});
            try bw.flush();
            return 1;
        },
        else => return e,
    };

    return ecode;
}
