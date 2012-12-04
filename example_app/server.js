var express = require('express');

var app = express.createServer(express.logger());

app.get('/', function(req, res) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.write(JSON.stringify({'message': 'Hello World!'}));
    res.end();
});

app.get('/env', function(req, res) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.write(JSON.stringify(process.env));
    res.end();
});

var port = process.env.PORT;
app.listen(port, function() {
    console.log("Listening on " + port);
});