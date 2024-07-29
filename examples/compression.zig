const std = @import("std");

const ws = @import("ws-server");
const Server = ws.Server;
const Client = ws.Client;

fn _onText(client: *Client, data: ?[]const u8) anyerror!void {
    if (data) |data_result| {
        std.debug.print("{s}\n", .{data_result});
    }
    _ = try client.text("Hello client!", null);
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = Server.create(&allocator, "127.0.0.1", 8080);
    server.setConfig(.{
        .permessage_deflate = .{
            // Set this value to true to compress data before sending.
            .enabled = true, // default: false
            // Determine how many bytes are needed to be compressed.
            .threshold = 1024, // default: 1024
        },
    });
    server.onText(&_onText);
    try server.listen();
}
