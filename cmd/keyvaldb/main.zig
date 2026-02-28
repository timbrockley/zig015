//--------------------------------------------------------------------------------
// Copyright 2026, Tim Brockley. All rights reserved.
// This software is licensed under the MIT License.
//--------------------------------------------------------------------------------
const std: type = @import("std");
const tbt = @import("libs/time26049.zig");
//--------------------------------------------------------------------------------
pub const config_filename = ".keyvaldb.conf";
//--------------------------------------------------------------------------------
pub const BRIGHT_ORANGE = "\x1B[38;5;214m";
pub const RESET = "\x1B[0m";
//--------------------------------------------------------------------------------
pub fn main() !void {
    //------------------------------------------------------------
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("{s}!!! MEMORY LEAK DETECTED !!!{s}\n\n", .{ BRIGHT_ORANGE, RESET });
    const allocator = gpa.allocator();
    //------------------------------------------------------------
    const output: []const u8 = try processArguments(allocator);
    defer allocator.free(output);
    //------------------------------------------------------------
    try std.fs.File.stdout().writeAll(output);
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn processArguments(allocator: std.mem.Allocator) ![]const u8 {
    //------------------------------------------------------------
    var it = std.process.args();
    //------------------------------------------------------------
    const cmd_name = if (it.next()) |s| std.fs.path.basename(s) else "";
    //------------------------------------------------------------
    const _directory = if (it.next()) |s| s else "";
    const directory = std.mem.trimRight(u8, _directory, "/");
    //------------------------------------------------------------
    if (std.mem.eql(u8, directory, "") or
        std.mem.eql(u8, directory, "help") or
        std.mem.eql(u8, directory, "--help") or
        std.mem.eql(u8, directory, "-h"))
    {
        //----------------------------------------
        return printHelp(allocator, cmd_name);
        //----------------------------------------
    }
    //------------------------------------------------------------
    const _instruction = if (it.next()) |s| s else "";
    //------------------------------------------------------------
    const Instruction = enum { create, repair, drop, list, set, get, mtime, remove };
    const instruction = std.meta.stringToEnum(Instruction, _instruction) orelse {
        return error.InvalidInstruction;
    };
    //------------------------------------------------------------
    const key = if (it.next()) |s| s else "";
    const value = if (it.next()) |s| s else "";
    //------------------------------------------------------------
    return switch (instruction) {
        .create => createDatabase(allocator, directory),
        .repair => repairDatabase(allocator, directory),
        .drop => dropDatabase(allocator, directory),
        .list => listKeys(allocator, directory),
        .set => setKey(allocator, directory, key, value),
        .get => getKey(allocator, directory, key),
        .mtime => mtimeKey(allocator, directory, key),
        .remove => removeKey(allocator, directory, key),
    };
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn createDatabase(allocator: std.mem.Allocator, directory: []const u8) ![]const u8 {
    //------------------------------------------------------------
    try checkDirectoryPath(allocator, directory);
    //------------------------------------------------------------
    const config_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, config_filename });
    defer allocator.free(config_filepath);
    //------------------------------------------------------------
    if (exists(directory)) {
        if (!isDirectory(directory)) return error.InvalidDatabaseFilepath;
        if (exists(config_filepath) and isFile(config_filepath)) {
            return error.DatabaseAlreadyExists;
        }
        return error.InvalidConfigFile;
    }
    //------------------------------------------------------------
    try std.fs.cwd().makeDir(directory);
    //------------------------------------------------------------
    const file = try std.fs.cwd().createFile(config_filepath, .{ .read = true, .truncate = true });
    defer file.close();
    //------------------------------------------------------------
    return try allocator.alloc(u8, 0);
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn repairDatabase(allocator: std.mem.Allocator, directory: []const u8) ![]const u8 {
    //------------------------------------------------------------
    try checkDirectoryPath(allocator, directory);
    //------------------------------------------------------------
    if (!exists(directory)) return error.DatabaseDoesNotExist;
    //------------------------------------------------------------
    const config_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, config_filename });
    defer allocator.free(config_filepath);
    //------------------------------------------------------------
    if (!exists(config_filepath)) {
        const file = try std.fs.cwd().createFile(config_filepath, .{ .read = true, .truncate = true });
        defer file.close();
    }
    //------------------------------------------------------------
    return try allocator.alloc(u8, 0);
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn dropDatabase(allocator: std.mem.Allocator, directory: []const u8) ![]const u8 {
    //------------------------------------------------------------
    try checkDirectoryPath(allocator, directory);
    //------------------------------------------------------------
    if (!exists(directory)) return error.DatabaseDoesNotExist;
    //------------------------------------------------------------
    const config_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, config_filename });
    defer allocator.free(config_filepath);
    //------------------------------------------------------------
    if (!exists(config_filepath)) return error.InvalidConfigFile;
    //------------------------------------------------------------
    try std.fs.cwd().deleteTree(directory);
    //------------------------------------------------------------
    return try allocator.alloc(u8, 0);
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn listKeys(allocator: std.mem.Allocator, directory: []const u8) ![]const u8 {
    //------------------------------------------------------------
    try checkDirectoryPath(allocator, directory);
    //------------------------------------------------------------
    if (!exists(directory)) return error.DatabaseDoesNotExist;
    //------------------------------------------------------------
    const config_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, config_filename });
    defer allocator.free(config_filepath);
    //------------------------------------------------------------
    if (!exists(config_filepath)) return error.InvalidConfigFile;
    //------------------------------------------------------------
    var dir = try std.fs.cwd().openDir(directory, .{ .iterate = true });
    defer dir.close();
    //------------------------------------------------------------
    var max_key_len: usize = 3;
    var count: usize = 0;
    //------------------------------------------------------------
    var dirIterator = dir.iterate();
    //----------------------------------------
    while (try dirIterator.next()) |dirEntry| {
        //----------------------------------------
        if (std.mem.eql(u8, dirEntry.name, config_filename)) continue;
        //----------------------------------------
        if (max_key_len < dirEntry.name.len) max_key_len = dirEntry.name.len;
        //----------------------------------------
        count += 1;
        //----------------------------------------
    }
    //------------------------------------------------------------
    if (count == 0) {
        //------------------------------------------------------------
        return try allocator.dupe(u8, "no key-value pairs exist\n");
        //------------------------------------------------------------
    } else {
        //------------------------------------------------------------
        var buffer = std.ArrayList(u8){};
        errdefer buffer.deinit(allocator);
        //------------------------------------------------------------
        const header_key = try rightPad(allocator, "KEY", max_key_len);
        defer allocator.free(header_key);
        try buffer.writer(allocator).print("\n{s}  VALUE\n", .{header_key});
        //------------------------------------------------------------
        dirIterator = dir.iterate();
        while (try dirIterator.next()) |dirEntry| {
            //----------------------------------------
            if (std.mem.eql(u8, dirEntry.name, config_filename)) continue;
            //----------------------------------------
            const key = try rightPad(allocator, dirEntry.name, max_key_len);
            defer allocator.free(key);
            //----------------------------------------
            const value = getKey(allocator, directory, dirEntry.name) catch |err| {
                try buffer.writer(allocator).print("{s}  {s}{}{s}\n", .{ key, BRIGHT_ORANGE, err, RESET });
                continue;
            };
            defer allocator.free(value);
            //----------------------------------------
            escapeString(value);
            //----------------------------------------
            try buffer.writer(allocator).print("{s}  {s}\n", .{ key, value });
            //----------------------------------------
        }
        //------------------------------------------------------------
        try buffer.writer(allocator).print("\n", .{});
        //------------------------------------------------------------
        return try buffer.toOwnedSlice(allocator);
        //------------------------------------------------------------
    }
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn setKey(allocator: std.mem.Allocator, directory: []const u8, key: []const u8, value: []const u8) ![]const u8 {
    //------------------------------------------------------------
    try checkDirectoryPath(allocator, directory);
    //------------------------------------------------------------
    if (!exists(directory)) return error.DatabaseDoesNotExist;
    //------------------------------------------------------------
    const config_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, config_filename });
    defer allocator.free(config_filepath);
    //------------------------------------------------------------
    if (!exists(config_filepath)) return error.InvalidConfigFile;
    //------------------------------------------------------------
    if (!checkKeyName(key)) return error.InvalidKeyName;
    //------------------------------------------------------------
    const key_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, key });
    defer allocator.free(key_filepath);
    //------------------------------------------------------------
    if (exists(key_filepath) and !isFile(key_filepath)) return error.InvalidKeyFile;
    //------------------------------------------------------------
    const file = try std.fs.cwd().createFile(key_filepath, .{ .read = true, .truncate = true });
    defer file.close();
    //------------------------------------------------------------
    const stdin_file = std.fs.File.stdin();
    //------------------------------------------------------------
    // const stdin_stat = try stdin_file.stat();
    // if (value.len == 0 and stdin_stat.kind != .character_device) {
    if (value.len == 0 and !stdin_file.isTty()) {
        //----------------------------------------
        const data = try stdin_file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(data);
        //----------------------------------------
        try file.writeAll(data);
        //----------------------------------------
    } else {
        //----------------------------------------
        try file.writeAll(value);
        //----------------------------------------
    }
    //------------------------------------------------------------
    return try allocator.alloc(u8, 0);
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn getKey(allocator: std.mem.Allocator, directory: []const u8, key: []const u8) ![]u8 {
    //------------------------------------------------------------
    try checkDirectoryPath(allocator, directory);
    //------------------------------------------------------------
    if (!exists(directory)) return error.DatabaseDoesNotExist;
    //------------------------------------------------------------
    const config_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, config_filename });
    defer allocator.free(config_filepath);
    //------------------------------------------------------------
    if (!exists(config_filepath)) return error.InvalidConfigFile;
    //------------------------------------------------------------
    if (!checkKeyName(key)) return error.InvalidKeyName;
    //------------------------------------------------------------
    const key_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, key });
    defer allocator.free(key_filepath);
    //------------------------------------------------------------
    if (exists(key_filepath) and !isFile(key_filepath)) return error.InvalidKeyFile;
    //------------------------------------------------------------
    const file = std.fs.cwd().openFile(key_filepath, .{}) catch |err| {
        if (err == error.FileNotFound) return try allocator.alloc(u8, 0);
        return err;
    };
    defer file.close();
    //------------------------------------------------------------
    const stat = try file.stat();
    //------------------------------------------------------------
    var buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);
    const bytesRead = try file.readAll(buffer);
    //------------------------------------------------------------
    return try allocator.dupe(u8, buffer[0..bytesRead]);
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn mtimeKey(allocator: std.mem.Allocator, directory: []const u8, key: []const u8) ![]const u8 {
    //------------------------------------------------------------
    try checkDirectoryPath(allocator, directory);
    //------------------------------------------------------------
    if (!exists(directory)) return error.DatabaseDoesNotExist;
    //------------------------------------------------------------
    const config_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, config_filename });
    defer allocator.free(config_filepath);
    //------------------------------------------------------------
    if (!exists(config_filepath)) return error.InvalidConfigFile;
    //------------------------------------------------------------
    if (!checkKeyName(key)) return error.InvalidKeyName;
    //------------------------------------------------------------
    const key_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, key });
    defer allocator.free(key_filepath);
    //------------------------------------------------------------
    if (exists(key_filepath) and !isFile(key_filepath)) return error.InvalidKeyFile;
    //------------------------------------------------------------
    const file = try std.fs.cwd().openFile(key_filepath, .{});
    defer file.close();
    //------------------------------------------------------------
    const stat = try file.stat();
    //------------------------------------------------------------
    const utms: i64 = @intCast(@divTrunc(stat.mtime, 1_000_000));
    const datetime = try tbt.unix_milliseconds_to_datetime(utms);
    //------------------------------------------------------------
    var buffer: [20]u8 = undefined;
    _ = try tbt.format(datetime, "CY-m-dThh:mm:ss.", &buffer);
    //------------------------------------------------------------
    return try std.fmt.allocPrint(
        allocator,
        "{s}{d:0>9}Z",
        .{ buffer, @as(u64, @intCast(@mod(stat.mtime, 1_000_000_000))) },
    );
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn removeKey(allocator: std.mem.Allocator, directory: []const u8, key: []const u8) ![]const u8 {
    //------------------------------------------------------------
    try checkDirectoryPath(allocator, directory);
    //------------------------------------------------------------
    if (!exists(directory)) return error.DatabaseDoesNotExist;
    //------------------------------------------------------------
    const config_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, config_filename });
    defer allocator.free(config_filepath);
    //------------------------------------------------------------
    if (!exists(config_filepath)) return error.InvalidConfigFile;
    //------------------------------------------------------------
    if (!checkKeyName(key)) return error.InvalidKeyName;
    //------------------------------------------------------------
    const key_filepath = try std.fs.path.join(allocator, &[_][]const u8{ directory, key });
    defer allocator.free(key_filepath);
    //------------------------------------------------------------
    if (exists(key_filepath) and !isFile(key_filepath)) return error.InvalidKeyFile;
    //------------------------------------------------------------
    if (exists(key_filepath) and isFile(key_filepath)) {
        try std.fs.cwd().deleteFile(key_filepath);
    }
    //------------------------------------------------------------
    return try allocator.alloc(u8, 0);
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn printHelp(allocator: std.mem.Allocator, cmd_name: []const u8) ![]const u8 {
    //------------------------------------------------------------
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);
    //------------------------------------------------------------
    try buffer.writer(allocator).print(
        \\
        \\{s} <DATABASE_DIRECTORY> create
        \\{s} <DATABASE_DIRECTORY> repair
        \\{s} <DATABASE_DIRECTORY> drop
        \\{s} <DATABASE_DIRECTORY> list
        \\{s} <DATABASE_DIRECTORY> set <KEY> <VALUE>
        \\{s} <DATABASE_DIRECTORY> set <KEY> <<< "STDIN_DATA"
        \\{s} <DATABASE_DIRECTORY> get <KEY>
        \\{s} <DATABASE_DIRECTORY> mtime <KEY>
        \\{s} <DATABASE_DIRECTORY> remove <KEY>
        \\
        \\
    , .{cmd_name} ** 9);
    //------------------------------------------------------------
    return try buffer.toOwnedSlice(allocator);
    //------------------------------------------------------------
}

//--------------------------------------------------------------------------------
pub fn checkDirectoryPath(allocator: std.mem.Allocator, directory: []const u8) !void {
    //------------------------------------------------------------
    if (std.mem.eql(u8, directory, "")) return error.InvalidDirectoryLocation;
    if (std.mem.eql(u8, directory, "/")) return error.InvalidDirectoryLocation;
    if (std.mem.eql(u8, directory, "/root")) return error.InvalidDirectoryLocation;
    if (std.mem.eql(u8, directory, "/tmp")) return error.InvalidDirectoryLocation;
    if (std.mem.eql(u8, directory, "~")) return error.InvalidDirectoryLocation;
    //------------------------------------------------------------
    const home_directory = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_directory);
    //------------------------------------------------------------
    if (std.mem.eql(u8, directory, home_directory)) return error.InvalidDirectoryLocation;
    //------------------------------------------------------------
    if (!checkDirectoryName(std.fs.path.basename(directory))) return error.InvalidDatabaseName;
    //------------------------------------------------------------
    return;
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn checkDirectoryName(name: []const u8) bool {
    //------------------------------------------------------------
    if (name.len == 0) return false;
    //------------------------------------------------------------
    for (name) |char| {
        switch (char) {
            '.', '_', '0'...'9', 'A'...'Z', 'a'...'z' => continue,
            else => return false,
        }
    }
    //------------------------------------------------------------
    return true;
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn checkKeyName(name: []const u8) bool {
    //------------------------------------------------------------
    if (name.len == 0 or std.mem.eql(u8, name, config_filename)) {
        return false;
    }
    //------------------------------------------------------------
    for (name) |char| {
        switch (char) {
            '_', '0'...'9', 'A'...'Z', 'a'...'z' => continue,
            else => return false,
        }
    }
    //------------------------------------------------------------
    return true;
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn escapeString(data: []u8) void {
    for (data) |*char| {
        if ((char.* >= 0x00 and char.* <= 0x20) or char.* == 0x7F) char.* = 0x20;
    }
}
//--------------------------------------------------------------------------------
pub fn exists(filepath: []const u8) bool {
    if (std.fs.cwd().statFile(filepath)) |stat| {
        if (stat.kind == .directory or stat.kind == .file or stat.kind == .sym_link) return true;
    } else |_| {}
    return false;
}
//--------------------------------------------------------------------------------
pub fn isDirectory(filepath: []const u8) bool {
    if (std.fs.cwd().statFile(filepath)) |stat| {
        if (stat.kind == .directory) return true;
    } else |_| {}
    return false;
}
//--------------------------------------------------------------------------------
pub fn isFile(filepath: []const u8) bool {
    if (std.fs.cwd().statFile(filepath)) |stat| {
        if (stat.kind == .file) return true;
    } else |_| {}
    return false;
}
//--------------------------------------------------------------------------------
pub fn rightPad(allocator: std.mem.Allocator, input: []const u8, min_len: usize) ![]u8 {
    //------------------------------------------------------------
    if (input.len >= min_len) return try allocator.dupe(u8, input);
    //------------------------------------------------------------
    const output = try allocator.alloc(u8, min_len);
    //------------------------------------------------------------
    std.mem.copyForwards(u8, output[0..input.len], input);
    @memset(output[input.len..], ' ');
    //------------------------------------------------------------
    return output;
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
