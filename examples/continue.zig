const std = @import("std");

const ws = @import("ws-server");
const Server = ws.Server;
const Client = ws.Client;

fn _onText(client: *Client, data: ?[]const u8) anyerror!void {
    std.debug.print("DATA({any}): {s}\n", .{
        client.getAddress(),
        data.?,
    });

    var text_sent = try client.text("Hello client!", .{ .first_message = true, .last_message = false });
    if (!text_sent) {
        std.debug.print("({any}): \"textAll()\" could not be sent because the client lost the connection!\n", .{
            client.getAddress(),
        });
    }

    text_sent = try client.text(" :)", .{ .first_message = false, .last_message = true });
    if (!text_sent) {
        std.debug.print("({any}): \"textAll()\" could not be sent because the client lost the connection!\n", .{
            client.getAddress(),
        });
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = Server.create(&allocator, "127.0.0.1", 8080);
    server.onText(&_onText);
    try server.listen();
}
