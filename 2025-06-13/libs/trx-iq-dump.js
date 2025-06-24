#!/usr/bin/node
/*
 * Copyright (C) 2024-2025 Amarisoft
 * IQ dump version 2025-06-13
 */
const fs = require('fs');

var config = {
    host: null,
    path: null,
    tx: false,
    rx: false,
    duration: 0,
    verbose: false,
    rf_port_index: [],
};

var Help = function (error, code)
{
    if (error)
        console.error(error);
    console.log('Usage:');
    console.log(process.argv[1], '[options]', '<host:[port]>', '<path>', '[duration is ms, default=1000]');
    console.log('    options:');
    console.log('      -v: verbose mode');
    console.log('      --tx: dump TX samples');
    console.log('      --rx: dump RX samples');
    console.log('      --rf-port <n>: dump samples for RF port <n> (default = all ports)');
    if (code === undefined)
        code = 1;
    process.exit(code);
}

for (var i = 2; i < process.argv.length;) {
    var arg = process.argv[i++];
    switch (arg) {
    case '--tx':
        config.tx = true;
        break;
    case '--rx':
        config.rx = true;
        break;
    case '--rf-port':
        config.rf_port_index.push(process.argv[i++] - 0);
        break;
    case '-v':
        config.verbose = true;
        break;
    case '-h':
    case '--help':
        Help(null, 0);
        break;
    default:
        if (!config.host) {
            config.host = arg;
        } else if (!config.path) {
            try {
                config.path = arg;
                config.path = fs.realpathSync(config.path);
                var stats = fs.lstatSync(config.path);
            } catch (e) {
                console.log(config.path + ' not found');
                process.exit();
            }
            if (!stats.isDirectory()) {
                console.log(config.path + ' is not a directory');
                process.exit();
            }

        } else if (!config.duration) {
            config.duration = arg - 0;
            if (isNaN(config.duration) || config.duration <= 0)
                Help('Bad duration');

        } else {
            Help('Bad argument: ' + arg);
        }
        break;
    }
}

if (!config.path)
    Help("Missing path");

if (!config.tx && !config.rx)
    Help("At least --tx or --rx must be set");

if (!config.duration)
    config.duration = 1000;

console.log("Clean directory");
try {
    var resp = require('child_process').execSync('rm -f ' + config.path + '/*', { maxBuffer: 32 * 1024 * 1024 }).toString();
} catch (e) {
    console.error(e);
    process.exit(1);
}

var GetWS = function(msg)
{
    if (config.verbose) console.log('<', JSON.stringify(msg));
    try {
        var resp = require('child_process').execSync('./ws.js ' + config.host + " --script '" + JSON.stringify(msg) + "' -t " + (config.duration / 1000 + 10).toString(3), { maxBuffer: 32 * 1024 * 1024 }).toString();
    } catch (e) {
        process.exit(1);
    }
    if (!resp) {
        console.error("Request aborted");
        process.exit(1);
    }

    if (config.verbose) console.log('>', resp);
    try {
        var data = JSON.parse(resp);
    } catch (e) {
        console.error(e);
        if (config.verbose) console.log('Message:', resp);

        process.exit(1);
    }
    return data;
}

/* Start capture */
console.log("Start capture");

var msg = {
    message: "trx_iq_dump",
    duration: config.duration,
};
if (config.rf_port_index.length)
    msg.rf_port = config.rf_port_index;
if (config.tx) {
    msg.tx_header = true;
    msg.tx_filename = config.path + '/tx%02d';
}
if (config.rx) {
    msg.rx_header = true;
    msg.rx_filename = config.path + '/rx%02d';
}
var resp = GetWS(msg);
if (resp.error) {
    console.error(resp.error);
    process.exit(1);
}
if (resp.dump_utc)
    console.log("Capture starts at " + new Date(resp.dump_utc));

const SIZE = 64e6;

var processPort = function (port, basename, file)
{
    var fdr = fs.openSync(file, 'r');
    var stats = fs.fstatSync(fdr);
    console.log('Process', file, '(' + stats.size + 'B)');

    var fds = {};
    var sps = port.sample_rate / 1000 / port.slots_per_subframe; // Samples per slots

    var slot_count = 10 * port.slots_per_subframe;
    var wrap = 10240 * port.slots_per_subframe;
    var loopIdx = null;

    // Local buffer
    var data = new Buffer.alloc(SIZE);
    var size = 0;
    var rpos = 0;

    var ts0 = -1;
    for (var pos = 0; pos < stats.size;) {

        if (rpos >= size - 12) {
            //console.log("Update 1", fdr, pos, stats.size, '/', rpos, size);
            size = fs.readSync(fdr, data, 0, SIZE, pos);
            rpos = 0;
        }

        var ts = data.readUInt32LE(rpos + 4) * 0x100000000 + data.readUInt32LE(rpos);
        if (ts0 === -1)
            ts0 = ts;
        var count = data.readUInt32LE(rpos + 8);
        pos += 12;
        if (pos + count * 8 > stats.size) {
            console.error('Overflow', pos + count * 8, stats.size);
            break;
        }

        rpos += 12;
        if (rpos + count * 8 >= size) {
            //console.log("Update 2", fdr, pos, stats.size, '/', rpos, size);
            size = fs.readSync(fdr, data, 0, SIZE, pos);
            rpos = 0;
        }

        var diff = Math.floor((ts - port.timestamp) / sps);
        var o = ts - (port.timestamp + diff * sps);
        var slot = port.frame * 10 * port.slots_per_subframe + port.slot + diff;

        if (loopIdx === null)
            loopIdx = Math.floor(slot / wrap);

        for (;count;) {
            var n = Math.min(count, sps - o);

            var slot0 = slot % wrap;
            if (slot0 < 0) slot0 += wrap;
            var loop = Math.floor(slot / wrap) - loopIdx;

            var n_f = Math.floor(slot0 / slot_count);
            var slots = slot0 % slot_count;
            var n_sf = Math.floor(slots / port.slots_per_subframe);
            slots = slots % port.slots_per_subframe;

            /* Filter your frame/subframe/slots here */
            /*if ((n_f & 1) || n_sf > 1)
                return null;*/

            var filename = basename + '-' + ('0' + loop).slice(-2) + '.' + ('000' + n_f).slice(-4) + '.' + n_sf;
            if (port.mu) {
                filename += '.' + ('0' + slots).slice(port.slots_per_subframe > 10 ? -2 : -1);
            }
            filename += '.bin';

            var fd = fds[filename];
            if (fd === undefined)
                fd = fds[filename] = fs.openSync(filename, 'w');

            var bytes = n * 8;
            fs.writeSync(fd, data, rpos, bytes, o * 8);

            count -= n;
            pos += bytes;
            rpos += bytes;
            slot++;
            o = 0;
        }
    }

    for (var fd in fds) {
        fs.closeSync(fds[fd]);
    }
    fs.unlinkSync(file);
}

/* Post processing */
console.log("Split by slot");
var cfg = GetWS({message: 'config_get'});
resp.rf_ports.forEach( (port) => {

    var index = port.index;
    var basename = config.path + '/rf_port' + index;

    port.cells = [];
    port.date = new Date(resp.dump_utc);

    for (var id in cfg.cells) {
        var cell = cfg.cells[id];
        if (cell.rf_port === index)
            port.cells.push(cell);
    }
    for (var id in cfg.nr_cells) {
        var cell = cfg.nr_cells[id];
        if (cell.rf_port === index)
            port.cells.push(cell);
    };
    for (var id in cfg.nb_cells) {
        var cell = cfg.nb_cells[id];
        if (cell.rf_port === index)
            port.cells.push(cell);
    };

    if (port.rx_overflows)
        console.error('Warning,', port.rx_overflows, ' RX samples lost on rf port', index);
    if (port.tx_overflows)
        console.error('Warning,', port.tx_overflows, ' TX samples lost on rf port', index);

    port.slots_per_subframe = 1 << port.mu;
    fs.writeFileSync(basename + '.json', JSON.stringify(port, null, 2));
    if (port.rx_files)
        port.rx_files.forEach( (file, idx) => { processPort(port, basename + '-rx' + idx, file); });
    if (port.tx_files)
        port.tx_files.forEach( (file, idx) => { processPort(port, basename + '-tx' + idx, file); });

});

