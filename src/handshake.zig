const std = @import("std");
const Allocator = std.mem.Allocator;

const Utils = @import("./utils/lib.zig");
const ClientFile = @import("./client.zig");
const Client = ClientFile.Client;
const CallbacksFile = @import("./callbacks.zig");
const Callbacks = CallbacksFile.Callbacks;

pub fn handle(allocator: *const Allocator, conn: *const std.net.Server.Connection, cbs: *const Callbacks) anyerror!bool {
    errdefer {
        conn.stream.writeAll("HTTP/1.1 400 Bad Request\r\n\r\n") catch {};
    }

    const lines_buffer = try allocator.alloc(u8, 512);
    defer allocator.free(lines_buffer);
    const lines_size = conn.stream.read(lines_buffer) catch |e| {
        if (e == error.ConnectionResetByPeer) {
            return false;
        }
        return e;
    };
    const lines = lines_buffer[0..lines_size];

    if (cbs.handshake.handle(&conn.address, lines) == false) {
        // The handshake was refused.
        return false;
    }

    var raw_key: []const u8 = undefined;
    {
        const line_idx = std.mem.indexOf(u8, lines, "Sec-WebSocket-Key: ") orelse return error.MissingWebSocketKey;
        const line_idx_until = std.mem.indexOfScalar(u8, lines[(line_idx + 19)..], '\r') orelse return error.MissingLineEnd;
        raw_key = lines[(line_idx + 19)..(line_idx + 19 + line_idx_until)];
    }

    var extensions: ?[]const u8 = null;
    if (std.mem.indexOf(u8, lines, "Sec-WebSocket-Extensions: ")) |line_idx| {
        if (std.mem.indexOfScalar(u8, lines[(line_idx + 26)..], '\r')) |line_idx_until| {
            extensions = lines[(line_idx + 26)..(line_idx + 26 + line_idx_until)];
        }
    }

    const key = try _generateKey(allocator, raw_key[0..24]);
    defer allocator.free(key);

    const response = try _createResponse(allocator, key, extensions);
    defer allocator.free(response);

    conn.stream.writeAll(response) catch |e| {
        if (e == error.ConnectionResetByPeer) {
            // The connection has been closed.
            return false;
        }
        return e;
    };

    return true;
}

fn _generateKey(allocator: *const Allocator, key: []const u8) anyerror![]const u8 {
    var sha1_out: [20]u8 = undefined;
    var sha1 = std.crypto.hash.Sha1.init(.{});
    sha1.update(key);
    sha1.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
    sha1.final(&sha1_out);

    const result = try allocator.alloc(u8, 28);
    _ = std.base64.standard.Encoder.encode(result, sha1_out[0..]);

    return result;
}

fn _createResponse(allocator: *const Allocator, key: []const u8, extensions: ?[]const u8) anyerror![]const u8 {
    var result: ?[]const u8 = null;
    if (extensions != null) {
        if (Utils.str.contains(extensions.?, "permessage-deflate") == true) {
            result = try std.fmt.allocPrint(
                allocator.*,
                "HTTP/1.1 101 Switching Protocols\r\n" ++
                    "Upgrade: websocket\r\n" ++
                    "Connection: Upgrade\r\n" ++
                    "Sec-WebSocket-Extensions: permessage-deflate; client_no_context_takeover; server_no_context_takeover\r\n" ++
                    "Sec-WebSocket-Accept: {s}\r\n\r\n",
                .{key},
            );
        }
    }
    if (result == null) {
        result = try std.fmt.allocPrint(
            allocator.*,
            "HTTP/1.1 101 Switching Protocols\r\n" ++
                "Upgrade: websocket\r\n" ++
                "Connection: Upgrade\r\n" ++
                "Sec-WebSocket-Accept: {s}\r\n\r\n",
            .{key},
        );
    }
    return result.?;
}
