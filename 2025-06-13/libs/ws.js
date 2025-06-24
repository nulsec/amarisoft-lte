#!/usr/bin/node
/*
 * Copyright (C) 2015-2025 Amarisoft
 * WebSocket example version 2025-06-13
 */

var fs = require("fs");
var tls = require('tls');

var server = null;
var ssl    = { enabled: false, options: {}};
var notif  = false;
var define = {};
var timeout = 60; // 1 minute
var password = null;
var loopCount = 0;
var noError = false;
var scriptMode = false;
var binFile = {};
var plugin = null;
var quiet = false;

for (var i = 2; i < process.argv.length; i++) {
    switch (process.argv[i]) {
    case '--script':
        scriptMode = true;
        break;
    case '-q':
        quiet = true;
        break;
    }
}

if (!scriptMode && !quiet)
    console.log("WebSocket remote API tool version 2025-06-13, Copyright (C) 2012-2025 Amarisoft");

function Help()
{
    console.error("Send messages:");
    console.error("  >", process.argv[1], "[options]", "<server name>", "[[<msg0> | -f <file0>]", "[<msg1> | -f <file1>]", "...]");
    console.error("  Examples:");
    console.error("    >", process.argv[1], "127.0.0.1:9000", "'{\"message\": \"config_get\"}'");
    console.error("    >", process.argv[1], "127.0.0.1:9000", "-f", '"message.json"');
    console.error("    >", process.argv[1], "127.0.0.1:9000", "'{\"message\": \"log_get\"}'", 'null', "'{\"message\": \"log_get\"}'");
    console.error("    Wait between messages:");
    console.error("    >", process.argv[1], "[options]", "<server name>", "<msg0>", "-w <delay in seconds>", "<msg1>", "...");
    console.error("Listen mode:");
    console.error("  >", process.argv[1], "[options]", "<server name>", "-l");
    console.error("  Examples:");
    console.error("    Listen for an event:");
    console.error("    >", process.argv[1], "[options]", "<server name>", "-e", "\"<event name>\"", "-l");
    console.error("Options:");
    console.error("    -f <filename>: use JSON file for message(s) (Can be array of message)");
    console.error("    --ssl: use SSL socket");
    console.error("    --ssl-cert <certificate file> <private key file>: use certificate for server authentication");
    console.error("    --ssl-ca <CA certificate file>");
    console.error("    --loop <n>: resend messages <n> times");
    console.error("    -t <timeout in s>: message timeout (default is 60 s)");
    console.error("    -D <name>=<value>: set name/value couple to replace in messages %<name>% pattern to <value>");
    console.error("    -p <password>: password used for authentication");
    console.error("    -w <duration>: wait for <duration> in seconds before sending next message");
    console.error("    --no-error: don't stop on error");
    console.error("    --script: don't display logs, only json responses (1 by line)");
    console.error("    --bin <file>: record signal events to file");
    console.error("    --bin-<label> <file>: record signal events with label <label> to file. Bin file can have the same name");
    console.error("    --plugin <filename>: use nodejs plugin");
    console.error("    -q: quiet mode");
    process.exit(1);
};

var ParseArgument = function (args)
{
    var arg = args.shift();

    switch (arg) {
    case '--ssl':
        ssl.enabled = true;
        break;
    case '--ssl-cert':
        ssl.options.cert = fs.readFileSync(args.shift());
        ssl.options.key = fs.readFileSync(args.shift());
        break;
    case '--ssl-ca':
        ssl.options.ca = fs.readFileSync(args.shift());
        break;
    case '-p':
        password = args.shift();
        break;
    case '-l':
        cmdList.push({type: 'listen'});
        break;
    case '-w':
        cmdList.push({type: 'wait', delay: args.shift() - 0});
        break;
    case '-e':
        cmdList.push({type: 'msg', msg: {message: "register", register: [args.shift()]}});
        break;
    case '-f':
        cmdList.push({type: 'msg', data: fs.readFileSync(args.shift(), "utf8")});
        break;
    case '-D':
        var d = args.shift().split(/=/);
        var name = d.shift();
        define[name] = d.join('=');
        break;
    case '-n':
        notif = true;
        break;
    case '-t':
        timeout = Math.max(1, args.shift() - 0 );
        break;
    case '--loop':
        loopCount = Math.max(1, args.shift() >>> 0);
        break;
    case '-h':
    case '--help':
        Help();
        break;
    case '--no-error':
        noError = true;
        break;
    case '--script':
    case '-q':
        break;
    case '--plugin':
        try {
            var name = args.shift();
            if (name.indexOf("/") < 0)
                name = './' + name;
            plugin = require(name);
            ParseArguments(plugin.onInit());
        } catch (e) {
            console.error("Can't load plugin: " + e);
            process.exit(1);
        }
        break;
    default:
        var m = arg.match(/^--bin(-(\w+))?$/);
        if (m) {
            var type = m[2];
            if (!type) type = 'all';
            var filename = args.shift();
            var b = binFile[type] = { filename: filename, fd: -1 };
            for (var id in binFile) {
                if (binFile[id].filename === filename) {
                    b.fd = binFile[id].fd;
                }
            }
            if (b.fd < 0)
                b.fd = fs.openSync(b.filename, 'w');
            break;
        }

        if (!server) {
            server = arg;
        } else {
            cmdList.push({type: 'msg', data: arg});
        }
        break;
    }
}

var ParseArguments = function (args)
{
    while (args.length)
        ParseArgument(args);
}

// Server name must be provided
var cmdList = [];

ParseArguments(process.argv.slice(2));




switch (server) {
case null:
case undefined:
case '':
    Help();
    break;
case 'mme':
    server = '127.0.0.1:9000';
    break;
case 'enb':
    server = '127.0.0.1:9001';
    break;
case 'ue':
    server = '127.0.0.1:9002';
    break;
case 'ims':
    server = '127.0.0.1:9003';
    break;
case 'mbms':
    server = '127.0.0.1:9004';
    break;
case 'n3iwf':
    server = '127.0.0.1:9005';
    break;
case 'license':
    server = '127.0.0.1:9006';
    break;
case 'mon':
    server = '127.0.0.1:9007';
    break;
case 'view':
    server = '127.0.0.1:9008';
    break;
case 'scan':
    server = '127.0.0.1:9009';
    break;
case 'probe':
    server = '127.0.0.1:9010';
    break;
}

/*
 * Check WebSocket module is present
 * If not, npm is required to download it
 */
try {
    var WebSocket = require('nodejs-websocket');
} catch (e) {
    console.error("Missing nodejs WebSocket module", e);
    console.error("Please install it:");
    console.error("  Copy node_modules from Amarisoft OTS package (ex: /root/ots/node_modules)");
    console.error("  Or install it:");
    console.error("    npm required:");
    console.error("      > dnf install -y npm");
    console.error("    module installation:");
    console.error("      > npm install -g nodejs-websocket");
    console.error("      or");
    console.error("      > npm install nodejs-websocket");
    process.exit(1);
}

// Create WebSocket client
var listen  = false;
var msg_id  = 0;
var arg_idx = 3;

var options = {extraHeaders: {"origin": "Test"}};
var proto = 'ws';
if (ssl.enabled) {
    //process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = '0';
    options.rejectUnauthorized = false;
    proto = 'wss';

    options.secureContext = tls.createSecureContext(ssl.options);
}
var ws = WebSocket.connect(proto + '://' + server + '/', options);
var connectTimer = setTimeout(function () {
    console.error(getHeader(), "!!! Connection timeout");
    process.exit(2);
}, timeout * 1000);

// Callbacks
ws.on('connect', function () {

    Log("### Connected to", server);
});

ws.on('text', function (msg) {

    var msg0 = JSON.parse(msg);

    if (msg0) {
        switch (msg0.message) {
        case 'authenticate':
            if (msg0.ready) {
                Log('### Authenticated');
                Start();
                return;
            }

            if (!password) {
                console.error('Authentication required, use -p option');
                process.exit(1);
            }

            if (msg0.error) {
                console.error('### Authentication error:', msg0.error);
                process.exit(1);
            }
            Log('### Authentication required: name=' + msg0.name + ', type=' + msg0.type + ', version=' + msg0.version);

            var hmac = require('crypto').createHmac('sha256', msg0.type + ':' + password + ':' + msg0.name);
            hmac.update(msg0.challenge);
            ws.send(JSON.stringify({message: 'authenticate', res: hmac.digest('hex')}));
            return;
        case 'ready':
            var info = ['name=' + msg0.name, 'type=' + msg0.type, 'version=' + msg0.version];
            if (msg0.product)
                info.push('product=' + msg0.product);
            Log('### Ready: ' + info.join(', '));
            Start();
            return;
        case 'error':
            console.log('### Error:', msg0.error);
            return;
        }
    }

    var index = -1;

    for (var i = 0; i < sentList.length; i++) {
        if (sentList[i].message_id === msg0.message_id) {
            var msg1 = sentList[i];
            break;
        }
    }


    if (msg1 || listen) {
        Log("==> Message received");

        if (scriptMode)
            console.log(JSON.stringify(msg0));
        else if (!quiet)
            console.log(JSON.stringify(msg0, null, 4));

        if (plugin) {
            plugin.onMessage(msg0);
            checkNext();
        }

        if (msg1 && (!msg0.notification || notif)) {
            sentList.splice(sentList.indexOf(msg1), 1);
            clearTimeout(msg1.__timer__);
            checkNext();
        }
    }
    if (msg0.error && !noError)
        process.exit(1);
});

ws.on('binary', function (stream) {

    var buffer = null;

    stream.on('readable', function () {
        var data = stream.read();
        if (data === null)
            return;

        buffer = buffer ? Buffer.concat([buffer, data]) : data;
        var byteLength = buffer.byteLength;

        // Enough data ?
        var size1 = buffer.readUInt32LE(0);
        if (size1 + 8 > byteLength)
            return;
        var size2 = buffer.readUInt32LE(4 + size1);
        var end = size1 + size2 + 8;

        if (byteLength < end)
            return;

        // Parse
        try {
            var log = JSON.parse(buffer.subarray(4, 4 + size1));
        } catch (e) {
            Log('Invalid binary data received');
            return;
        }

        Log('Binary log received');
        console.log('    Label:', log.label);
        console.log('    Log:', log.data);

        var type = buffer.readUInt32LE(size1 + 8);
        var len = buffer.readUInt32LE(size1 + 12);

        console.log('    Size:', size2);
        console.log('    Type:', type);
        console.log('    Len:', len);

        for (var id in binFile) {
            var b = binFile[id];
            if (id === 'all' || id === log.label)
                fs.writeFileSync(b.fd, buffer.subarray(size1 + 4, end));
        }
    });
});

ws.on('close', function () {
    Log("!!! Disconnected");
    process.exit(0);
});

ws.on('error', function (err) {
    if (ssl.enabled && !ws.socket.authorized && ws.socket.authorizationError) {
        console.error(getHeader(), 'SSL error:', ws.socket.authorizationError);
    } else {
        console.error(getHeader(), "!!! Error", err);
    }
    process.exit(1);
});


var msgTimeout = function (msg)
{
    delete msg.__timer__;
    console.error(getHeader(), "!!! Message timeout", msg);
    process.exit(12);
}

var Start = function ()
{
    clearTimeout(connectTimer);
    connectTimer = 0;
    if (plugin)
        plugin.onStart();
    checkNext();
}

var startTime = new Date() * 1;
var getHeader = function () {
    return '[' + ((new Date() - startTime) / 1000).toFixed(3) + ']';
};

var Log = function ()
{
    if (!scriptMode && !quiet) {
        process.stdout.write(getHeader() + ' ');
        console.log.apply(console, arguments);
    }
}

var cmdList0 = cmdList.slice(); // Copy
var sentList = [];
var checkNext = function()
{
    if (sentList.length)
        return;

    if (!cmdList.length) {
        if (loopCount-- > 0) {
            cmdList = cmdList0.slice();
            checkNext();
            return;
        }
        if (listen)
            return;
        process.exit(0);
    }

    var msgList = [];
    var cmd = cmdList.shift();
    switch (cmd.type) {
    case 'listen':
        listen = true;
        break;

    case 'wait':
        Log('*** Wait for', cmd.delay.toFixed(1), 's');
        setTimeout(checkNext, cmd.delay * 1000);
        return false;

    case 'msg':
        if (cmd.data) {
            if (fs.existsSync('json_util'))             var json_util = './json_util';
            else if (fs.existsSync('../json_util'))     var json_util = '../json_util';
            else if (fs.existsSync('../ots/json_util')) var json_util = '../ots/json_util';

            if (json_util) {
                var args = ['-i', '0', 'dump', '-'];
                for (var d in define) {
                    args.unshift(d + '=' + define[d]);
                    args.unshift('-D');
                }

                var p = require('child_process').spawnSync(json_util, args, {
                    maxBuffer: 32 * 1024 * 1024,
                    input: cmd.data,
                });

                if (p.status) {
                    console.error('Bad message:', cmd.data);
                    console.error('Error:', p.stderr.toString());
                    process.exit(p.status);
                }

                cmd.data = p.stdout.toString();
            }

            for (var i in define)
                cmd.data = cmd.data.replace(new RegExp('%' + i + '%', 'g'), define[i]);

            try {
                var list = JSON.parse(cmd.data);
            } catch (e) {
                console.error(getHeader(), "JSON error on sent message:", cmd.data);
                console.error(e);
                if (!json_util) {
                    console.error("json_util not found, JSON syntax must be strict");
                }
                process.exit(1);
            }

        } else {
            var list = cmd.msg;
        }


        if (!(list instanceof Array)) list = [list];

        for (var i in list) {
            var msg = list[i];
            if (msg.message_id === undefined)
                msg.message_id = "id#" + (++msg_id);
            msgList.push(msg);
            Log('<== Send message', msg.message, msg.message_id);
        }
        break;
    default:
        break;
    }

    // Send ?
    if (!msgList.length)
        return checkNext();

    if (msgList.length == 1) {
        ws.send(JSON.stringify(msgList[0]));
    } else {
        ws.send(JSON.stringify(msgList));
    }

    for (var i = 0; i < msgList.length; i++) {
        var msg = msgList[i];
        sentList.push(msg);
        var start = msg.start_time || 0;
        var duration = start;
        if (msg.end_time !== undefined) {
            // XXX: does not handle absolute time
            duration += msg.end_time - start;
        }
        msg.__timer__ = setTimeout(msgTimeout.bind(this, msgList[i]), (duration + timeout) * 1000);
    }
};

// For plugin
global.sendMsg = function (msg, cb)
{
    var id = "id#" + (++msg_id);
    cmdList.push({msg: msg, type: 'msg', cb});
    return id;
}

global.log = function ()
{
    if (!scriptMode) {
        process.stdout.write(getHeader() + '[PLUGIN] ');
        console.log.apply(console, arguments);
    }
}

