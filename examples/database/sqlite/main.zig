//--------------------------------------------------------------------------------
//
// sudo apt install libsqlite3-dev
//
//--------------------------------------------------------------------------------
const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});
//--------------------------------------------------------------------------------
const OUTPUT_PATH = "zig-out";
//--------------------------------------------------------------------------------
pub fn main() !u8 {
    //------------------------------------------------------------
    const database_filename = "test.db";
    //------------------------------------------------------------
    var db: ?*c.sqlite3 = undefined;
    var rc = c.sqlite3_open(database_filename, &db);
    defer _ = c.sqlite3_close(db);
    if (rc != c.SQLITE_OK) {
        std.debug.print("Cannot open database: {s}\n", .{c.sqlite3_errmsg(db)});
        return 1;
    }
    //----------------------------------------
    {
        //----------------------------------------
        const stmt = "CREATE TABLE IF NOT EXISTS cars (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(255));";
        //----------------------------------------
        var zErrMsg: [*c]u8 = undefined;
        rc = c.sqlite3_exec(db, stmt, callback, null, &zErrMsg);
        if (rc != c.SQLITE_OK) {
            defer c.sqlite3_free(zErrMsg);
            std.debug.print("SQL error: {s}\n", .{zErrMsg});
            return 1;
        }
        //----------------------------------------
    }
    //----------------------------------------
    {
        //----------------------------------------
        const stmt = "INSERT INTO cars (name) VALUES('name1');";
        //----------------------------------------
        var zErrMsg: [*c]u8 = undefined;
        rc = c.sqlite3_exec(db, stmt, callback, null, &zErrMsg);
        if (rc != c.SQLITE_OK) {
            defer c.sqlite3_free(zErrMsg);
            std.debug.print("SQL error: {s}\n", .{zErrMsg});
            return 1;
        }
        //----------------------------------------
    }
    //----------------------------------------
    {
        //----------------------------------------
        const stmt = "SELECT * FROM cars;";
        //----------------------------------------
        var zErrMsg: [*c]u8 = undefined;
        rc = c.sqlite3_exec(db, stmt, callback, null, &zErrMsg);
        if (rc != c.SQLITE_OK) {
            defer c.sqlite3_free(zErrMsg);
            std.debug.print("SQL error: {s}\n", .{zErrMsg});
            return 1;
        }
        //----------------------------------------
    }
    //------------------------------------------------------------
    return 0;
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
fn callback(
    _: ?*anyopaque,
    argc: c_int,
    argv: [*c][*c]u8,
    azColName: [*c][*c]u8,
) callconv(.c) c_int {
    //----------------------------------------
    for (0..@intCast(argc)) |i| {
        if (argv[i] == null) {
            std.debug.print("{s} = NULL\n", .{azColName[i]});
        } else {
            std.debug.print("{s} = {s}\n", .{ azColName[i], argv[i] });
        }
    }
    //----------------------------------------
    return 0;
    //----------------------------------------
}
//--------------------------------------------------------------------------------
