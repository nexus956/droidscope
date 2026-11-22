// net-enum-test.js — enumerate the app's real pin/trust classes (R8 renames them,
// so the stock class-name matching misses), hook every CertPinManager-shaped class,
// and fire a control request through the proxy to prove the pipeline.
Java.perform(function () {
    const seen = {};

    function hookByName(name) {
        try {
            const C = Java.use(name);
            let hooked = 0;
            ['isChainValid', 'checkChainPinning', 'checkTrusted', 'verifyChain'].forEach(function (m) {
                try {
                    if (C[m]) {
                        C[m].overloads.forEach(function (ov) {
                            ov.implementation = function () {
                                console.log('[HOOK-FIRE] ' + name + '.' + m);
                                try { return this[m].apply(this, arguments); } catch (e) { return true; }
                            };
                        });
                        hooked++;
                    }
                } catch (e) { /* method missing */ }
            });
            if (hooked) console.log('[HOOKED] ' + name + ' (' + hooked + ' methods)');
        } catch (e) { console.log('[HOOK-ERR] ' + name + ': ' + e.message); }
    }

    function sweep() {
        Java.performNow(function () {
            try {
                Java.enumerateLoadedClasses({
                    onMatch: function (name) {
                        if (/certpin|pinmanager|netsecurity|conscrypt/i.test(name) && !seen[name]) {
                            seen[name] = 1;
                            console.log('[ENUM] ' + name);
                            if (/certpin|pinmanager|netsecurity/i.test(name)) hookByName(name);
                        }
                    },
                    onComplete: function () { console.log('[ENUM] sweep done, ' + Object.keys(seen).length + ' matches'); }
                });
            } catch (e) { console.log('[ENUM-ERR] ' + e.message); }
        });
    }

    sweep();
    const t = setInterval(sweep, 2000);
    setTimeout(function () { clearInterval(t); }, 50000);

    // control request: plain HTTPS through the app's own JVM stack (honors proxy override)
    setTimeout(function () {
        Java.performNow(function () {
            try {
                const URL = Java.use('java.net.URL');
                const conn = URL.$new('https://example.com/').openConnection();
                conn.setConnectTimeout(Java.use('java.lang.Integer').valueOf(8000));
                conn.setReadTimeout(Java.use('java.lang.Integer').valueOf(8000));
                const code = conn.getResponseCode();
                console.log('[NET-TEST] example.com -> ' + code);
            } catch (e) {
                console.log('[NET-TEST] FAILED: ' + e.message);
            }
            try {
                const URL2 = Java.use('java.net.URL');
                const conn2 = URL2.$new('https://vpn.protonvpn.com/').openConnection();
                conn2.setConnectTimeout(Java.use('java.lang.Integer').valueOf(8000));
                conn2.setReadTimeout(Java.use('java.lang.Integer').valueOf(8000));
                const code2 = conn2.getResponseCode();
                console.log('[NET-TEST] vpn.protonvpn.com -> ' + code2);
            } catch (e) {
                console.log('[NET-TEST] proton FAILED: ' + e.message);
            }
        });
    }, 4000);
});
