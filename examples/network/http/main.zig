//--------------------------------------------------------------------------------
const std = @import("std");
//--------------------------------------------------------------------------------
const SERVER_ADDR = "127.0.0.1";
const SERVER_PORT = 3000;
//--------------------------------------------------------------------------------
pub fn main() !void {
    //------------------------------------------------------------
    const server_thread = try std.Thread.spawn(.{}, serverFunc, .{});
    server_thread.detach();
    //------------------------------------------------------------
    std.Thread.sleep(100 * std.time.ns_per_ms);
    //------------------------------------------------------------
    try clientFunc();
    //------------------------------------------------------------
    // std.Thread.sleep(3000 * std.time.ns_per_ms);
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn clientFunc() !void {
    //------------------------------------------------------------
    const address = try std.net.Address.parseIp4(SERVER_ADDR, SERVER_PORT);
    //------------------------------------------------------------
    var stream = try std.net.tcpConnectToAddress(address);
    defer stream.close();
    //------------------------------------------------------------
    // var reader_buf: [1024]u8 = undefined;
    var writer_buf: [1024]u8 = undefined;
    //------------------------------------------------------------
    // var reader = stream.reader(&reader_buf).file_reader;
    var writer = stream.writer(&writer_buf).file_writer;
    //------------------------------------------------------------
    // Send HTTP request
    //------------------------------------------------------------
    try writer.interface.writeAll(
        "GET / HTTP/1.1\r\n" ++
            "Host: 127.0.0.1\r\n" ++
            "Connection: close\r\n" ++
            "\r\n",
    );
    try writer.interface.flush();
    //------------------------------------------------------------
    // Read response
    //------------------------------------------------------------
    var buf: [1024]u8 = undefined;
    while (true) {
        const n = try stream.read(&buf);
        if (n == 0) break;
        std.debug.print("{s}", .{buf[0..n]});
    }
    //------------------------------------------------------------
    std.debug.print("\n", .{});
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
pub fn serverFunc() !void {
    //------------------------------------------------------------
    const address = try std.net.Address.parseIp4(SERVER_ADDR, SERVER_PORT);
    //------------------------------------------------------------
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();
    //------------------------------------------------------------
    const conn = try server.accept();
    defer conn.stream.close();

    var reader_buf: [1024]u8 = undefined;
    var writer_buf: [1024]u8 = undefined;

    var reader = conn.stream.reader(&reader_buf).file_reader;
    var writer = conn.stream.writer(&writer_buf).file_writer;

    var server_http = std.http.Server.init(&reader.interface, &writer.interface);

    var req = try server_http.receiveHead();

    try req.respond("hello from server", .{});
    //------------------------------------------------------------
}
//--------------------------------------------------------------------------------
