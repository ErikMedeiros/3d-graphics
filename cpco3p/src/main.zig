const std = @import("std");
const zmath = @import("zmath");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const result = zmath.add(1, 5);
    try stdout.print("1 + 5 = {d}\n", .{result});

    try bw.flush();
}
