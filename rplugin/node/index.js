module.exports = plugin => {

const nvim = plugin.nvim;

function debug(o) {
    // nvim.command("echom '" + o + "'");
}

var net           = require('net'),
    fs            = require('fs'),
    path          = require('path'),
    child_process = require('child_process');

var _sock;
var _foundvff = false;
var _findtext = "";
var _greptext = "";
var _path;

var pn = process.cwd();

while (true) {
    var p = path.parse(pn)
    if (p.root == p.dir) break;
    var tpn = path.join(pn, ".vff");
    try {
        fs.accessSync(tpn, fs.R_OK);
        _foundvff = true;
        _vffpath = tpn;
        _path = pn;
        break;
    } catch (e) {
    }
    pn = path.join(pn, "..");
}

function readline(sock, cb) {
    sock.once("line", cb);
}

var _connectcbs = []

function _connectcb(err, val) {
    _conninprogress = false;
    var c = _connectcbs;
    _connectcbs = [];
    for (x in c) {
        c[x](err, val);
    }
}

var _conninprogress;

function _donop(cb) {
    debug("_write nop");
    _sock.write("nop\n", function(err) {
        if (err) {
            debug("WRITE FAILED");
            cb(err);
        } else {
            debug("readline nop");
            readline(_sock, function(err, data) {
                debug("got: ", data);
                if (err) {
                    debug("READLINE FAILED");
                    cb(err);
                }
                cb(null);
            });
        }
    });
}

function _connect(nvim, cb) {
    _connectcbs.push(cb);

    if (_conninprogress) return;
    _conninprogress = true;

    // debug("_connect ", new Error().stack);
    if (!_foundvff) { _connectcb("NOVFF"); return; }

    if (_sock) {
        _donop(function(err) {
            if (err)
                _connect2(nvim);
            else
                _connectcb(null);
        });
    } else {
        _connect2(nvim);
    }
}

function emitLines(stream) {
    var backlog = '';
    stream.on('data', function (data) {
        try {
            backlog += data;
            var n = backlog.indexOf('\n');
            // got a \n? emit one or more 'line' events
            while (~n) {
                stream.emit('line', null, backlog.substring(0, n));
                backlog = backlog.substring(n + 1);
                n = backlog.indexOf('\n');
            }
        } catch (e) {
            debug(e);
        }
    });
    stream.on('error', function (err) {
        try {
            stream.emit('line', err, null);
        } catch (e) {
            debug(e);
        }
    });
    stream.on('end', function () {
        try {
            if (backlog)
                stream.emit('line', null, backlog);
            stream.emit('line', "CLOSED", null);
        } catch (e) {
            debug(e);
        }
    });
}

function _connect2(nvim) {
    debug("connect2");
    if (_sock) _sock.destroy();
    _sock = new net.Socket();
    _sock.once("close", function() { _sock = undefined; });

    var onfailsock = _sock;
    var onfail = function(err) { onfailsock.emit("connect", "closed"); };
    _sock.once("close", onfail);

    emitLines(_sock);
    nvim.command("call VffStatus('Connecting...')", function(err) { });
    debug("connecting");
    _sock.connect(20398, '127.0.0.1', function(err) {
        if (err) {
            debug("FAILEDTOCONNECT: ", err);
            nvim.command("call VffStatus('Starting VFFServer.exe')", function(err) { });
            setTimeout(function() {
                if (process.platform == "win32") {
                    var child = child_process.spawn(process.env.HOME + '/.vim/plugin/VFF/VFFServer.exe', [], { detached: true, stdio: [ 'ignore', 'ignore', 'ignore' ] });
                    var timer = setTimeout(function() { _connect2(nvim); }, 500);
                    child.once('error', function(err) {
                        debug(err);
                        clearTimeout(timer);
                        nvim.command("call VffStatus('Failed to run VFFServer.exe')", function(err) { });
                        _connectcb("FAILED_TO_START");
                    });
                    child.unref();
                } else {
                    var child = child_process.spawn("mono-sgen", [ process.env.HOME + '/.vim/plugin/VFF/VFFServer.exe' ], { detached: true, stdio: [ 'ignore', 'ignore', 'ignore' ] });
                    var timer = setTimeout(function() { _connect2(nvim); }, 500);
                    child.once('error', function(err) {
                        debug(err);
                        clearTimeout(timer);
                        nvim.command("call VffStatus('Failed to run VFFServer.exe')", function(err) { });
                        _connectcb("FAILED_TO_START");
                    });
                    child.unref();
                }
            }, 500);
            return;
        }
        debug("connected");
        _sock.removeListener("close", onfail);

        nvim.command("call VffStatus('Scanning')", function(err) { });
        _sock.write('config ' + _vffpath + '\n');
        _donop(function(err) {
            if (err)
                _connectcb(err);
            else {
                nvim.command("call VffStatus('OK')", function(err) { });
                _connectcb(null);
            }
        });
    });
}

plugin.registerFunction('VFFTextAppendSync', function( args, cb ) {
    var [mode, s] = args;
    if (mode == 'find') {
        _findtext += s;
        return _findtext;
    } else {
        _greptext += s;
        return _greptext;
    }
}, { sync: true });

plugin.registerFunction('VFFTextBackspaceSync', function( args, cb ) {
    var mode = args[0];
    if (mode == 'find') {
        _findtext = _findtext.substring(0, _findtext.length-1);
        return _findtext;
    } else {
        _greptext = _greptext.substring(0, _greptext.length-1);
        return _greptext;
    }
    return "";
}, { sync: true });

plugin.registerFunction('VFFTextClearSync', function( args, cb ) {
    var mode = args[0];
    if (mode == 'find')
        _findtext = "";
    else
        _greptext = "";
    return "";
}, { sync: true });


var _refreshseq = 0;
var _refreshinprogress;
var _refreshneeded;

plugin.registerFunction('VFFRefresh', function( args ) {
    _refresh(args[0]);
}, { sync: true });

plugin.registerFunction('VFFUpdateVffPath', function( args ) {
    _vffpath = args[0];
    _connect(nvim, function (err) {
        _sock.write('config ' + _vffpath + '\n');
    });
}, { sync: true });

function _refresh(mode) {
    // debug("want to refresh");
    if (!_foundvff) return;

    var seq = ++_refreshseq;

    if (_refreshinprogress) {
        _refreshneeded = mode;
        return;
    }
    _refreshinprogress = true;

    var waitchars = [ '|', '/', '-', '\\', '|', '/', '-', '\\' ];
    var waitpos = 0;
    var timer = setInterval(function() {
        nvim.command("call VffWaiting('" + waitchars[waitpos] + "')", function(err) { });
        waitpos = (waitpos + 1) % waitchars.length;
    }, 100);

    var cleanup = function(lines) {
        // debug("cleaning: " + lines.length);
        clearInterval(timer);
        _refreshinprogress = false;
        if (_refreshneeded) {
            var mode = _refreshneeded;
            _refreshneeded = undefined;
            _refresh(nvim, mode);

        } else {
            if (seq == _refreshseq) {
                // debug("SENT " + lines.length);
                nvim.command("call VffLines(\"" + lines + "\")", function(err) {
                    if (err) { debug(err); }
                });
            }
        }
    };

    _connect(nvim, function (err) {
        if (err) {
            cleanup('');
            return;
        }
        var lines = [];
        var text = mode == 'find' ? _findtext : _greptext;

        debug("got connected");

        var proceed;
        try { 
            proceed = ((mode == "find" && text != "") || (mode == "grep" && text.length >= 3));
        } catch (e) {
            debug("ERR");
            debug(e);
        }

        if (proceed) {
            debug("lets go");
            if (mode == 'find')
                _sock.write("find match " + text + "\n");
            else
                _sock.write("grep match " + text + "\n");

            var read = function() {
                readline(_sock, function(err, data) {
                    if (err) {
                        debug(err);
                        cleanup('');
                        return;
                    }
                    if (data != "") {
                        // debug("LINE: " + data.replace(/\\/g, "\\\\").replace(/\"/g, "\\\""));
                        lines.push(data.replace(/\\/g, "\\\\").replace(/\"/g, "\\\""));
                        read();
                    } else {
                        // debug("LINES: " + lines.length);
                        // debug("LINEDATAS: " + (lines.slice(0,100).join("\n")).length);
                        cleanup(lines.slice(0,100).join("\n"));
                        return;
                    }
                });
            };
            read();
        } else {
            debug("NO PROCEED");
            cleanup('');
            return;
        }
    });
}

plugin.registerFunction('VFFRelativePathSync', function( args, cb ) {
    var relativeto = args[0];
    var abspath = args[1];

    abspath = _path + abspath;
    var path = abspath.split("/")
    var rel = relativeto.split("/")
    while (path.length > 0 && path[0] == rel[0]) {
        path.shift();
        rel.shift();
    }
    var ret = "";
    var i = 0;
    while (i < rel.length) { ret += "../"; i++; }
    return ret + path.join("/");
}, { sync: true });

plugin.registerFunction('VFFEnterSync', function( args ) {
    var mode = args[0];

    var waitchars = [ '|', '/', '-', '\\', '|', '/', '-', '\\' ];
    var waitpos = 0;
    var timer = setInterval(function() {
        nvim.command("call VffWaiting('" + waitchars[waitpos] + "')", function(err) { });
        waitpos = (waitpos + 1) % waitchars.length;
    }, 100);

    _connect(nvim, function (err) {
        clearInterval(timer);
    });

    var r;
    if (_foundvff)
        r = [ _path, mode == "grep" ? _greptext : _findtext ];
    else
        r = undefined;

    debug("returning from EnterSync with", r);
    return r;
}, { sync: true });

};
