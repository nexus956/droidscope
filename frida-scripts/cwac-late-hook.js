// cwac-late-hook.js — the app's CWAC netsecurity CertPinManager loads lazily
// (long after frida attaches), so the stock unpinning pass misses it and every
// MITM'd request dies at the pin check. This watches for the class and hooks
// it the moment it exists: isChainValid / checkChainPinning -> true.
Java.perform(function () {
    let done = false;

    function arm() {
        Java.performNow(function () {
            if (done) return;
            try {
                const CP = Java.use('com.commonsware.cwac.netsecurity.conscrypt.CertPinManager');

                if (CP.isChainValid) {
                    CP.isChainValid.overloads.forEach(function (m) {
                        m.implementation = function () { return true; };
                    });
                    send('[CWAC-LATE] isChainValid -> true (' + CP.isChainValid.overloads.length + ' overloads)');
                }

                if (CP.checkChainPinning) {
                    CP.checkChainPinning.overloads.forEach(function (m) {
                        m.implementation = function () { return true; };
                    });
                    send('[CWAC-LATE] checkChainPinning -> true');
                }

                done = true;
                send('[CWAC-LATE] CertPinManager hooked');
            } catch (e) {
                // class not loaded yet — keep waiting
            }
        });
    }

    arm();
    const timer = setInterval(function () {
        arm();
        if (done) clearInterval(timer);
    }, 500);
});
