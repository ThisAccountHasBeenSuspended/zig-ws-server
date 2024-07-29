const std = @import("std");

const ws = @import("ws-server");
const Server = ws.Server;
const Client = ws.Client;
const Error = ws.Error;
const CloseCodes = ws.CloseCodes;

// When we have a new client, this function will be called
// before we can receive a message like "text" from the client.
fn _onHandshake(addr: *const std.net.Address, headers: []const u8) anyerror!bool {
    std.debug.print("Handshake from `{any}`: {s}\n", .{ addr, headers });

    return true; // false = Close connection
}

// If something went wrong unexpectedly, you can use this function to view some details of the error.
// After this function call, the connection to the client is immediately terminated.
fn _onError(_: ?*Client, info: *const Error) anyerror!void {
    std.debug.print("ERROR: {any}\n", .{info.getError()});

    if (info.getSymbolInfo()) |symbol_info| {
        defer info.deinit(&symbol_info);

        // EXAMPLE: `COMPILE_UNIT_NAME: root.exe.obj`.
        std.debug.print("COMPILE_UNIT_NAME: {s}\n", .{symbol_info.compile_unit_name});
        // EXAMPLE: `SYMBOL_NAME: _parsePayload`.
        std.debug.print("SYMBOL_NAME: {s}\n", .{symbol_info.symbol_name});

        if (symbol_info.line_info) |*line_info| {
            // EXAMPLE: `LINE_INFO: D:\GitHub\ws-server\src\frame.zig:180:9`.
            std.debug.print("LINE_INFO: {s}:{d}:{d}\n", .{ line_info.*.file_name, line_info.*.line, line_info.*.column });
        }
    }
}

// When the incoming message loop breaks this function is called.
fn _onDisconnect(client: *Client) anyerror!void {
    std.debug.print("Client ({any}) disconnected!\n", .{client.getAddress()});
}

// When a text message has been received from the client, this function is called.
fn _onText(client: *Client, data: ?[]const u8) anyerror!void {
    if (data) |data_result| {
        std.debug.print("MESSAGE RECEIVED: {s}\n", .{data_result});
    }

    const text_sent = try client.text("Hello client!", null);
    if (text_sent) {
        std.debug.print("The message was successfully sent to the client!\n", .{});
    }
}

// When a binary message has been received from the client, this function is called.
fn _onBinary(client: *Client, data: ?[]const u8) anyerror!void {
    if (data) |data_result| {
        std.debug.print("BINARY RECEIVED: {s}\n", .{data_result});
    }

    const binary_sent = try client.binary("Hello client! :)", null);
    if (binary_sent) {
        std.debug.print("The message was successfully sent to the client!\n", .{});
    }
}

// When the client has properly closed the connection with a message, this function is called.
fn _onClose(client: *Client, data: ?[]const u8) anyerror!void {
    if (data) |data_result| {
        std.debug.print("CLOSE RECEIVED!: {s}\n", .{data_result});
    } else {
        std.debug.print("CLOSE RECEIVED!\n", .{});
    }

    _ = client.close(null) catch {};
    client.closeImmediately();
}

// When the client pings this server, this function is called.
fn _onPing(client: *Client, data: ?[]const u8) anyerror!void {
    if (data) |data_result| {
        std.debug.print("PING RECEIVED!: {s}\n", .{data_result});
    } else {
        std.debug.print("PING RECEIVED!\n", .{});
    }

    const pong_sent = try client.pong("Blub :]");
    if (pong_sent) {
        std.debug.print("Pong was successfully sent to the client!\n", .{});
    }
}

// When we get a pong back from the client after a ping, this function is called.
//fn _onPong(client: *Client, data: ?[]const u8) anyerror!void {
//    if (data) |data_result| {
//        std.debug.print("PONG RECEIVED!: {s}\n", .{data_result});
//    } else {
//        std.debug.print("PONG RECEIVED!\n", .{});
//    }
//
//    const ping_sent = try client.ping("Blub :)");
//    if (ping_sent) {
//        std.debug.print("Ping was successfully sent to the client!\n", .{});
//    }
//}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var server = Server.create(&allocator, "127.0.0.1", 8080);
    server.setConfig(.{
        .read_buffer_size = 1024,
    });
    server.onHandshake(&_onHandshake);
    server.onDisconnect(&_onDisconnect);
    server.onError(&_onError);
    server.onText(&_onText);
    server.onBinary(&_onBinary);
    server.onClose(&_onClose);
    server.onPing(&_onPing);
    //server.onPong(&_onPong);
    try server.listen();
}
