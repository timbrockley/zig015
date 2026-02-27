const std = @import("std");

const BRIGHT_ORANGE = "\x1B[38;5;214m";
const RESET = "\x1B[0m";

pub fn main() !void {
    //------------------------------------------------------------
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("{s}!!! MEMORY LEAK DETECTED !!!{s}\n\n", .{ BRIGHT_ORANGE, RESET });
    const allocator = gpa.allocator();
    //------------------------------------------------------------
    {
        //------------------------------------------------------------
        // quicker compilation and a smaller compiled binary
        // no memory allocation required and uses an iterator to return args
        //------------------------------------------------------------
        var it = std.process.args();
        _ = it.skip();

        const arg_a = if (it.next()) |a| a else "1";
        const a = try std.fmt.parseInt(u32, arg_a, 10);

        const arg_b = if (it.next()) |b| b else "2";
        const b = try std.fmt.parseInt(u32, arg_b, 10);

        const result: u32 = a + b;

        std.debug.print("{d} + {d} = {d}\n", .{ a, b, result });
        //------------------------------------------------------------
    }
    //------------------------------------------------------------
    {
        //------------------------------------------------------------
        // slower compilation and a larger compiled binary
        // uses memory allocation and returns a slice or args stored on the heap
        //------------------------------------------------------------
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        const a: u32 = if (args.len > 1) try std.fmt.parseInt(u32, args[1], 10) else 1;
        const b: u32 = if (args.len > 2) try std.fmt.parseInt(u32, args[2], 10) else 2;

        const result: u32 = a + b;

        std.debug.print("{d} + {d} = {d}\n", .{ a, b, result });
        //------------------------------------------------------------
    }
    //------------------------------------------------------------
    {
        //------------------------------------------------------------
        // stdin
        //------------------------------------------------------------

        //------------------------------------------------------------
        const stdin_file = std.fs.File.stdin();

        // const stdin_stat = try stdin_file.stat();
        // if (stdin_stat.kind != .character_device) {
        if (!stdin_file.isTty()) {

            //------------------------------------------------------------
            // piped from another process or terminal
            //------------------------------------------------------------

            //------------------------------------------------------------
            // allocated array list buffer using reader
            //------------------------------------------------------------

            var stdin_buffer: [256]u8 = undefined;
            var stdin_reader = stdin_file.reader(&stdin_buffer);

            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            while (stdin_reader.interface.takeByte()) |byte| {
                try buffer.writer(allocator).writeByte(byte);
            } else |_| {}

            const input = try buffer.toOwnedSlice(allocator);
            defer allocator.free(input);

            std.debug.print("stdin input: {s}\n", .{input});

            //----------------------------------------
            // fixed buffer using reader
            //----------------------------------------

            // var stdin_buffer: [256]u8 = undefined;
            // var stdin_reader = stdin_file.reader(&stdin_buffer);

            // read one byte at a time until end of stream error happens
            // var input: [10]u8 = undefined;
            // var bytes_read: usize = 0;
            // while (stdin_reader.interface.takeByte()) |byte| {
            //     if (bytes_read == input.len) break; // buffer full
            //     input[bytes_read] = byte;
            //     bytes_read += 1;
            // } else |_| {}

            // std.debug.print("bytes read: {d}\n", .{bytes_read});
            // std.debug.print("stdin input: {s}\n", .{input[0..bytes_read]});

            //--------------------------------------------------
            // allocated buffer using array list - deprecated
            //--------------------------------------------------

            // Deprecated in favour of 'Reader'.
            // const input = try stdin_file.readToEndAlloc(allocator, std.math.maxInt(usize));
            // defer allocator.free(input);

            // std.debug.print("stdin: {s}\n", .{input});

            //----------------------------------------
            // fixed buffer - deprecated
            //----------------------------------------

            // var buffer: [256]u8 = undefined;

            // Deprecated in favour of 'Reader'.
            // const bytes_read = try stdin_file.readAll(&buffer);

            // std.debug.print("bytes read: {d}\n", .{bytes_read});
            // std.debug.print("stdin input: {s}\n", .{buffer[0..bytes_read]});

            //------------------------------------------------------------
            // fixed buffer !!! buffer not filled if larger than bytes read !!!
            //------------------------------------------------------------

            // var stdin_buffer: [256]u8 = undefined;
            // var stdin_reader = stdin_file.reader(&stdin_buffer);

            // var buffer: [256]u8 = undefined;

            // reads into buffer. buffer not filled if larger than bytes read.
            // stdin_reader.interface.readSliceAll(&buffer) catch |_| {};

            // std.debug.print("stdin input: {s}\n", .{stdin_buffer});

            //------------------------------------------------------------

        } else {

            //------------------------------------------------------------
            // request input in terminal
            //------------------------------------------------------------

            //----------------------------------------
            // fixed buffer
            //----------------------------------------

            var buffer: [256]u8 = undefined;

            std.debug.print("enter stdin: ", .{});
            const bytes_read = try stdin_file.read(buffer[0..]);

            const input = std.mem.trimEnd(u8, buffer[0..bytes_read], "\r\n");

            std.debug.print("bytes read: {d}\n", .{bytes_read});
            std.debug.print("stdin input: {s}\n", .{input});

            //----------------------------------------
            // fixed buffer - deprecated
            //----------------------------------------

            // var buffer: [256]u8 = undefined;

            // std.debug.print("enter stdin (ctrl + D to end): ", .{});

            // Deprecated in favour of 'Reader'.
            // const bytes_read = try stdin_file.readAll(&buffer);

            // std.debug.print("bytes read: {d}\n", .{bytes_read});
            // std.debug.print("stdin input: {s}\n", .{input});

            //------------------------------------------------------------
        }

        //------------------------------------------------------------
    }
    //------------------------------------------------------------
}
