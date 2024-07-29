A simple WebSocket server for the Zig(-lang) programming language. Feel free to contribute and improve this implementation.

> [!TIP]
> Documentation can be found in the source code of our [examples](https://github.com/ws-zig/ws-server/blob/a0bc7ccf59d378cb23d8e0525dd0cf4db80ee102/examples).

## Installation ([`zig-0.12.0`](https://github.com/ziglang/zig/releases/tag/0.12.0))
- [Download the source code](https://github.com/ws-zig/ws-server/archive/refs/heads/main.zip).
- Unzip the folder somewhere.
- Open your `build.zig`.
- Look for the following code:
```zig
    const exe = b.addExecutable(.{
        .name = "YOUR_PROJECT_NAME",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
```
- Paste the following source code below:
```zig
    const wsServerModule = b.addModule("ws-server", .{ .root_source_file = .{ .path = "PATH_TO_DIRECTORY/ws-server-main/src/main.zig" } });
    exe.root_module.addImport("ws-server", wsServerModule);
```
- Save the file and you're done!

#### To build or run your project, you can use the following commands:
- build:
- - `zig build`
  - `zig build -Doptimize=ReleaseSafe`
- run:
- - `zig run --dep ws-server --mod root ./src/main.zig --mod ws-server PATH_TO_DIRECTORY/ws-server-main/src/main.zig`
  - `zig run --dep ws-server -Mroot=PATH/src/main.zig -Mws-server=PATH_TO_DIRECTORY/ws-server-main/src/main.zig`

## Example
### Server:
This little example starts a server on port `8080` and sends `Hello client!` to the client, whenever a text message arrives.
```zig
const std = @import("std");

const ws = @import("ws-server");
const Server = ws.Server;
const Client = ws.Client;

fn _onText(client: *Client, data: ?[]const u8) anyerror!void {
    if (data != null) {
        std.debug.print("DATA({any}): {s}\n", .{
            client.getAddress(),
            data.?,
        });
    }

    const text_sent = try client.text("Hello client!", null);
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
    server.setConfig(.{
        .permessage_deflate = .{
            .enabled = true,
            .threshold = 1,
        },
    });
    server.onText(&_onText);
    try server.listen();
}
```

### Client:
For testing we use [NodeJS](https://nodejs.org/) with the [`ws`](https://www.npmjs.com/package/ws) package.
```js
const { WebSocket } = require('ws');
const client = new WebSocket("ws://127.0.0.1:8080", {
    perMessageDeflate: {
        // Absolutely necessary if compression is used!
        clientNoContextTakeover: true,
        serverNoContextTakeover: true,
        
        threshold: 1, // Optional
    },
});

client.on('open', () => {
    let num = 0;
    setInterval(() => {
        client.send(`Hello server! #${++num}`);
    }, 2500);
});

client.on('message', (msg) => {
    console.log(msg.toString());
});
```

### Result:
![image](https://github.com/ws-zig/ws-server/assets/154023155/fbcea6fb-58e0-41ea-822c-abc3c9497c29)

## Errors
This is a list of all possible errors you can get with the error callback.

> [!IMPORTANT]
> Possible errors from the `std` library are not listed, but can also happen!

_(13 possible errors)_
- `MessageContinue_LastMessageIsMissing`.
- - The first message with the message type is missing
- `MessageContinue_WrongLastMessageType`
- - The previous message has neither the message type text nor binary.
- `MessageContinue_LastMessageNotExpected`
- - The message has already been marked as complete.
- `LastMessageExpected`
- - The message with type close, ping or pong was marked as incomplete.
- `Frame_TooFewBytes`
- - The frame of the received message contains too few bytes.
- `Frame_64bitRequired`
- - The architecture used does not support the required `u64` data type for reading and writing messages.
- `Frame_MissingBytes`
- - There are not enough bytes to read the received message.
  - This can happen if `read_buffer_size` is too low.
- `MissingWebSocketKey`
- - The line with `Sec-WebSocket-Key` is missing in the handshake.
- `MissingLineEnd`
- - The end of each line in the handshake (`\r`) is missing.
- `MessageType_Unknown`
- - The message type of the received message does not exist.
- `MaxMsgSizeExceeded`
- - The `max_msg_size` configuration was exceeded for this message.
  - This can happen if the last bytes of this message are longer than the "max_msg_size" configuration and this message is accidentally exceeded with the message type continue.
- `MsgBufferSizeExceeded`
- If the architecture does not support the `u64` data type, `read_buffer_size` must be set to less than 65535 in the configuration.
- `MaxMsgSizeTooLow`
- - The `max_msg_size` must equal to or be larger than `read_buffer_size`.