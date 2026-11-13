.pragma library
// The launcher's search: ranks apps, settings pages, and system actions for a
// query, and adds a calculator answer and a web search. Pure functions, so
// tools/preview.py and the shell use the same logic.
//
// A result: { kind, title, subtitle, icon (theme icon name or ""), glyph (MpireOS
// icon name), hint (what Enter does), and one of: id (app), command, action
// (systemStatus method), value (calculator), url }.

var settingsPages = [
    { title: "Wi-Fi & Internet", keywords: "wifi wi-fi network internet ethernet vpn", command: "kcmshell6 kcm_networkmanagement", glyph: "wifi" },
    { title: "Display", keywords: "display screen monitor resolution scale night", command: "kcmshell6 kcm_kscreen", glyph: "image" },
    { title: "Sound", keywords: "sound audio volume speaker microphone", command: "kcmshell6 kcm_pulseaudio", glyph: "volume" },
    { title: "Bluetooth", keywords: "bluetooth headphones devices pair", command: "kcmshell6 kcm_bluetooth", glyph: "headphones" },
    { title: "Keyboard", keywords: "keyboard layout language typing", command: "kcmshell6 kcm_keyboard", glyph: "keyboard" },
    { title: "Users", keywords: "users account password avatar", command: "kcmshell6 kcm_users", glyph: "user" },
    { title: "Date & Time", keywords: "date time clock timezone", command: "kcmshell6 kcm_clock", glyph: "calendar" },
    { title: "Power", keywords: "power battery energy sleep", command: "kcmshell6 kcm_powerdevilprofilesconfig", glyph: "battery" }
];

var systemActions = [
    { title: "Lock screen", keywords: "lock screen away", action: "lock", glyph: "lock" },
    { title: "Sleep", keywords: "sleep suspend", action: "suspend", glyph: "moon" },
    { title: "Log out", keywords: "log out logout sign out signout", action: "logOut", glyph: "logOut" },
    { title: "Restart", keywords: "restart reboot", action: "restart", glyph: "refresh" },
    { title: "Shut down", keywords: "shut down shutdown power off poweroff turn off", action: "powerOff", glyph: "power" }
];

// How well `text` matches `q` (both lowercase): 0 for no match.
function score(text, q) {
    if (!text) return 0;
    if (text === q) return 100;
    if (text.indexOf(q) === 0) return 90;
    var words = text.split(/[\s\-_.]+/);
    for (var i = 0; i < words.length; i++)
        if (words[i].indexOf(q) === 0) return 75;
    if (text.indexOf(q) >= 0) return 55;
    return 0;
}

function best(q, fields) {
    // fields: [[text, weight], ...]
    var top = 0;
    for (var i = 0; i < fields.length; i++) {
        var s = score((fields[i][0] || "").toLowerCase(), q) * fields[i][1];
        if (s > top) top = s;
    }
    return top;
}

// ---- Calculator: + - * / % ^, parentheses, decimals. No eval. ----
function calculate(text) {
    var src = text.replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, "");
    if (!/^[-+*/%^().0-9]+$/.test(src) || !/[0-9]/.test(src) || !/[-+*/%^]/.test(src.replace(/^-/, "")))
        return null;
    var pos = 0;
    function peek() { return src[pos]; }
    function number() {
        var start = pos;
        while (pos < src.length && /[0-9.]/.test(src[pos])) pos++;
        if (start === pos) throw "number";
        var n = parseFloat(src.substring(start, pos));
        if (isNaN(n)) throw "number";
        return n;
    }
    function atom() {
        if (peek() === "-") { pos++; return -atom(); }
        if (peek() === "+") { pos++; return atom(); }
        if (peek() === "(") {
            pos++;
            var v = sum();
            if (peek() !== ")") throw "paren";
            pos++;
            return v;
        }
        return number();
    }
    function power() {
        var base = atom();
        if (peek() === "^") { pos++; return Math.pow(base, power()); }
        return base;
    }
    function product() {
        var v = power();
        while (peek() === "*" || peek() === "/" || peek() === "%") {
            var op = src[pos++];
            var r = power();
            v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        }
        return v;
    }
    function sum() {
        var v = product();
        while (peek() === "+" || peek() === "-") {
            var op = src[pos++];
            var r = product();
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }
    try {
        var result = sum();
        if (pos !== src.length || !isFinite(result)) return null;
        return Math.round(result * 1e10) / 1e10;
    } catch (e) {
        return null;
    }
}

function search(query, apps, limit) {
    var q = query.trim().toLowerCase();
    if (q.length === 0) return [];
    var out = [];

    var answer = calculate(query);
    if (answer !== null)
        out.push({ kind: "calc", title: String(answer), subtitle: query.trim() + " =", glyph: "calculator",
                   icon: "", hint: "Copy", value: String(answer), rank: 1000 });

    for (var i = 0; i < apps.length; i++) {
        var a = apps[i];
        var r = best(q, [[a.name, 1], [a.genericName, 0.8], [a.keywords, 0.7], [a.comment, 0.45]]);
        if (r > 0)
            out.push({ kind: "app", title: a.name, subtitle: a.genericName || a.comment || "", icon: a.icon,
                       glyph: "grid", hint: "Open", id: a.id, rank: r + 5 });
    }
    for (var j = 0; j < settingsPages.length; j++) {
        var p = settingsPages[j];
        var rp = best(q, [[p.title, 1], [p.keywords, 0.7]]);
        if (rp > 0)
            out.push({ kind: "command", title: p.title, subtitle: "Settings", icon: "", glyph: p.glyph,
                       hint: "Open", command: p.command, rank: rp });
    }
    for (var k = 0; k < systemActions.length; k++) {
        var s = systemActions[k];
        var rs = best(q, [[s.title, 1], [s.keywords, 0.8]]);
        if (rs > 0)
            out.push({ kind: "system", title: s.title, subtitle: "System", icon: "", glyph: s.glyph,
                       hint: "Run", action: s.action, rank: rs - 2 });
    }
    out.sort(function (x, y) { return y.rank - x.rank || x.title.localeCompare(y.title); });
    out = out.slice(0, limit || 7);
    out.push({ kind: "web", title: "Search the web for “" + query.trim() + "”", subtitle: "DuckDuckGo",
               icon: "", glyph: "globe", hint: "Search",
               url: "https://duckduckgo.com/?q=" + encodeURIComponent(query.trim()), rank: 0 });
    return out;
}
