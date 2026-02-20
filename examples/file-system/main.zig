//--------------------------------------------------------------------------------
// Copyright 2026, Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//--------------------------------  ------------------------------------------------

const std = @import("std");

pub const TEST_DIR = "test";
pub const TEST_DIR1 = "test/1";
pub const TEST_DIR2 = "test/1/2";
pub const TEST_DIR3 = "test/1/2/3";

pub const FILENAME1 = "test1.txt";
pub const FILENAME2 = "test2.txt";

const BRIGHT_ORANGE = "\x1B[38;5;214m";
const RESET = "\x1B[0m";

pub fn main() !void {
    //------------------------------------------------------------
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("{s}!!! MEMORY LEAK DETECTED !!!{s}\n\n", .{ BRIGHT_ORANGE, RESET });
    const allocator = gpa.allocator();
    //------------------------------------------------------------
    // Closing the returned `Dir` is checked illegal behavior.
    // Iterating over the result is illegal behavior.
    const dir = std.fs.cwd();
    //------------------------------------------------------------
    std.debug.print("\n", .{});
    const cwdString = try dir.realpathAlloc(allocator, ".");
    defer allocator.free(cwdString);
    std.debug.print("cwd: {s}\n", .{cwdString});
    std.debug.print("\n", .{});
    //------------------------------------------------------------
    if (dir.statFile(TEST_DIR)) |stat| {
        if (stat.kind == .file) {
            try dir.deleteFile(TEST_DIR);
        }
    } else |_| {}
    //------------------------------------------------------------
    dir.makeDir(TEST_DIR) catch |err| {
        if (err != error.PathAlreadyExists) {
            std.debug.print("makeDir: {s}\n", .{@errorName(err)});
            std.process.exit(1);
        }
    };
    std.debug.print("makeDir: directory created\n", .{});
    //------------------------------------------------------------
    dir.makePath(TEST_DIR2) catch |err| {
        std.debug.print("makePath: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    std.debug.print("makePath: directory created\n", .{});
    //------------------------------------------------------------
    const statExisting = try dir.statFile(TEST_DIR2);
    switch (statExisting.kind) {
        .directory => std.debug.print("statFile: directory exists\n", .{}),
        .file => std.debug.print("statFile: file exists\n", .{}),
        else => std.debug.print("statFile: exists, type: {s}\n", .{@tagName(statExisting.kind)}),
    }
    //------------------------------------------------------------
    if (dir.statFile(TEST_DIR3)) |statResult| {
        switch (statResult.kind) {
            .directory => std.debug.print("statFile: directory exists\n", .{}),
            .file => std.debug.print("statFile: file exists\n", .{}),
            else => std.debug.print("statFile: exists, type: {s}\n", .{@tagName(statResult.kind)}),
        }
    } else |err| {
        std.debug.print("statFile: {s}\n", .{@errorName(err)});
    }
    std.debug.print("\n", .{});
    //------------------------------------------------------------
    {
        //------------------------------------------------------------
        // createFile writeAll stat seekTo readAll
        //------------------------------------------------------------

        const file = try dir.createFile(FILENAME1, .{
            .read = true,
            .truncate = true, // truncate file if it exists (overwrite)
        });
        defer file.close();

        try file.writeAll("createFile test");

        const stat = try file.stat();

        var buffer1: [100]u8 = undefined;
        try file.seekTo(0); // required if reading data aftr
        // readAll (deprecated)
        const bytesRead1 = try file.readAll(&buffer1);

        var buffer2 = try allocator.alloc(u8, stat.size);
        defer allocator.free(buffer2);

        try file.seekTo(0); // required if reading data aftr
        // readAll (deprecated)
        const bytesRead2 = try file.readAll(buffer2);

        std.debug.print("createFile\n", .{});
        std.debug.print("writeAll (deprecated): stat.size: {d}\n", .{stat.size});
        std.debug.print("readAll (deprecated): bytesRead: {d}\n", .{bytesRead1});
        std.debug.print("readAll (deprecated): data: {s}\n", .{buffer1[0..bytesRead1]});
        std.debug.print("readAll (deprecated): bytesRead: {d}\n", .{bytesRead2});
        std.debug.print("readAll (deprecated): data: {s}\n", .{buffer2[0..bytesRead2]});
        std.debug.print("\n", .{});
    }
    //------------------------------------------------------------
    {
        //------------------------------------------------------------
        // openFile stat reader toOwnedSlice
        //------------------------------------------------------------

        const file = try dir.openFile(FILENAME1, .{});
        defer file.close();

        const stat = try file.stat();

        var read_buffer: [1024]u8 = undefined;
        var file_reader = file.reader(&read_buffer);

        const data = try file_reader.interface.readAlloc(
            allocator,
            stat.size,
        );
        defer allocator.free(data);

        std.debug.print("openFile: stat.size: {d}\n", .{stat.size});
        std.debug.print("reader: toOwnedSlice: {s}\n", .{data});
        std.debug.print("\n", .{});
    }
    //------------------------------------------------------------
    {
        //------------------------------------------------------------
        // openFile stat reader takeByte writer writeByte toOwnedSlice
        //------------------------------------------------------------

        const file = try dir.openFile(FILENAME1, .{});
        defer file.close();

        const stat = try file.stat();

        var read_buffer: [256]u8 = undefined;
        var read_buffer_reader = file.reader(&read_buffer);

        var write_buffer = std.ArrayList(u8){};
        defer write_buffer.deinit(allocator);

        while (read_buffer_reader.interface.takeByte()) |byte| {
            try write_buffer.writer(allocator).writeByte(byte);
        } else |_| {}

        const data = try write_buffer.toOwnedSlice(allocator);
        defer allocator.free(data);

        std.debug.print("openFile: stat.size: {d}\n", .{stat.size});
        std.debug.print("reader: writer: toOwnedSlice: {s}\n", .{data});
        std.debug.print("\n", .{});
    }
    //------------------------------------------------------------
    {
        //------------------------------------------------------------
        // openFile stat reader readAlloc createFile writer writeAll flush
        //------------------------------------------------------------

        const read_handle = try dir.openFile(FILENAME1, .{});
        defer read_handle.close();

        const read_stat = try read_handle.stat();

        var read_buffer: [1024]u8 = undefined;
        var reader = read_handle.reader(&read_buffer);

        const data = try reader.interface.readAlloc(
            allocator,
            read_stat.size,
        );
        defer allocator.free(data);

        std.debug.print("openFile: stat.size: {d}\n", .{read_stat.size});
        std.debug.print("reader: data: {s}\n", .{data});

        const write_handle = try dir.createFile(FILENAME2, .{});
        defer write_handle.close();
        var write_buffer: [1024]u8 = undefined;
        var writer = write_handle.writer(&write_buffer);

        try writer.interface.writeAll(data);
        try writer.interface.flush(); // required

        const write_stat = try write_handle.stat();

        std.debug.print("writer: stat.size: {d}\n", .{write_stat.size});
        std.debug.print("\n", .{});
    }
    //------------------------------------------------------------
    {
        //------------------------------------------------------------
        // iterate over directory entries
        //------------------------------------------------------------

        var opendir_handle = try dir.openDir(".", .{ .iterate = true });
        defer opendir_handle.close();

        const stat = try opendir_handle.stat();

        std.debug.print("openDir: mtime: {d}\n", .{stat.mtime});

        var dirIterator = opendir_handle.iterate();
        while (try dirIterator.next()) |dirEntry| {
            std.debug.print("iterate: {}: {s}\n", .{ dirEntry.kind, dirEntry.name });
        }

        std.debug.print("\n", .{});
    }
    //------------------------------------------------------------
}

//------------------------------------------------------------
