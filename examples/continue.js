const { WebSocket } = require('ws');
const client = new WebSocket("ws://127.0.0.1:8080", {
    perMessageDeflate: false,
});

client.on('open', () => {
    let num = 0;
    client.send(`Hello server! #${++num}`,    { fin: false });
    client.send(` | Hello server! #${++num}`, { fin: false });
    client.send(` | Hello server! #${++num}`, { fin: false });
    client.send(` | Hello server! #${++num}`, { fin: false });
    client.send(` | Hello server! #${++num}`, { fin: true  });
    
    setInterval(() => {
        client.send(`Hello server! #${++num}`);
    }, 2500);
});

client.on('message', (msg) => {
    console.log(msg.toString());
});