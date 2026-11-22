// trace-kill.js — catch who terminates the process: hook exit/_exit/abort/kill/raise, log backtraces
function bt(ctx) {
    try {
        return Thread.backtrace(ctx, Backtracer.ACCURATE).map(DebugSymbol.fromAddress).join('\n    ');
    } catch (e) {
        return 'no-bt: ' + e;
    }
}

['exit', '_exit', 'abort'].forEach(function (n) {
    var p = Module.findExportByName('libc.so', n);
    if (p) {
        Interceptor.attach(p, {
            onEnter: function (a) {
                send('[KILL] libc ' + n + '(' + a[0] + ')\n    ' + bt(this.context));
            }
        });
    }
});

var k = Module.findExportByName('libc.so', 'kill');
if (k) {
    Interceptor.attach(k, {
        onEnter: function (a) {
            var pid = a[0].toInt32 ? a[0].toInt32() : a[0];
            var sig = a[1].toInt32 ? a[1].toInt32() : a[1];
            send('[KILL] kill(' + pid + ', sig=' + sig + ')\n    ' + bt(this.context));
        }
    });
}

var r = Module.findExportByName('libc.so', 'raise');
if (r) {
    Interceptor.attach(r, {
        onEnter: function (a) {
            var sig = a[0].toInt32 ? a[0].toInt32() : a[0];
            send('[KILL] raise(sig=' + sig + ')\n    ' + bt(this.context));
        }
    });
}

send('hooks armed');
