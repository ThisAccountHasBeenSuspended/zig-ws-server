const { WebSocket } = require('ws');
const client = new WebSocket("ws://127.0.0.1:8080/");

client.on('open', () => {
    console.log("CONNECTED!");

    // Message continuation.
    client.send("Hello",     { fin: false });
    client.send(" server ",  { fin: false });
    client.send(":)",        { fin: true  });

    client.send("Hello server!");
    client.send("Hello !server", { binary: true });

    client.ping("Hello Server! :]");
});

client.on('message', (data) => {
    console.log(data.toString());
});

client.on('close', (code, msg) => {
    console.log(`CLOSE: ${code} - ${msg.toString()}`);
});

client.on('ping', (msg) => {
    console.log(`PING: ${msg}`);
    setTimeout(() => client.pong("Hi server! :]"), 1000);
});

client.on('pong', (msg) => {
    console.log(`PONG: ${msg}`);
    setTimeout(() => client.ping("Hi server! :)"), 1000);
});

client.on('error', (msg) => {
    console.log(`ERROR: ${msg} - ${msg}`);
});