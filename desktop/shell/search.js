.pragma library
// Search for the launcher and universal search: ranks apps, settings pages,
// and system actions for a query, and adds a calculator answer, unit
// conversions, and a web search. Pure functions, so tools/preview.py and the
// shell use the same logic.
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
            out.push({ kind: "app", title: a.name, subtitle: (a.genericName && a.genericName !== a.name ? a.genericName : a.comment) || "", icon: a.icon,
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

// ---- Unit conversions: "10 km in miles", "72 f to c", "2.5 gb in mb". ----
var units = (function () {
    var table = {};
    function add(kind, factor, names) {
        for (var i = 0; i < names.length; i++) table[names[i]] = { kind: kind, factor: factor, label: names[0] };
    }
    add("length", 0.001, ["mm", "millimeter", "millimeters", "millimetre", "millimetres"]);
    add("length", 0.01, ["cm", "centimeter", "centimeters", "centimetre", "centimetres"]);
    add("length", 1, ["m", "meter", "meters", "metre", "metres"]);
    add("length", 1000, ["km", "kilometer", "kilometers", "kilometre", "kilometres"]);
    add("length", 0.0254, ["in", "inch", "inches", "\""]);
    add("length", 0.3048, ["ft", "foot", "feet", "'"]);
    add("length", 0.9144, ["yd", "yard", "yards"]);
    add("length", 1609.344, ["mi", "mile", "miles"]);
    add("mass", 0.000001, ["mg", "milligram", "milligrams"]);
    add("mass", 0.001, ["g", "gram", "grams"]);
    add("mass", 1, ["kg", "kilogram", "kilograms", "kilo", "kilos"]);
    add("mass", 0.028349523125, ["oz", "ounce", "ounces"]);
    add("mass", 0.45359237, ["lb", "lbs", "pound", "pounds"]);
    add("mass", 6.35029318, ["st", "stone", "stones"]);
    add("volume", 0.001, ["ml", "milliliter", "milliliters", "millilitre", "millilitres"]);
    add("volume", 1, ["l", "liter", "liters", "litre", "litres"]);
    add("volume", 0.0295735295625, ["fl oz", "floz"]);
    add("volume", 0.2365882365, ["cup", "cups"]);
    add("volume", 0.473176473, ["pt", "pint", "pints"]);
    add("volume", 0.946352946, ["qt", "quart", "quarts"]);
    add("volume", 3.785411784, ["gal", "gallon", "gallons"]);
    add("data", 1, ["bytes", "byte"]);
    add("data", 1e3, ["kb", "kilobyte", "kilobytes"]);
    add("data", 1e6, ["mb", "megabyte", "megabytes"]);
    add("data", 1e9, ["gb", "gigabyte", "gigabytes"]);
    add("data", 1e12, ["tb", "terabyte", "terabytes"]);
    add("data", 1024, ["kib"]);
    add("data", 1048576, ["mib"]);
    add("data", 1073741824, ["gib"]);
    add("data", 1099511627776, ["tib"]);
    add("time", 1, ["s", "sec", "secs", "second", "seconds"]);
    add("time", 60, ["min", "mins", "minute", "minutes"]);
    add("time", 3600, ["h", "hr", "hrs", "hour", "hours"]);
    add("time", 86400, ["d", "day", "days"]);
    add("time", 604800, ["wk", "week", "weeks"]);
    add("speed", 1, ["m/s", "mps"]);
    add("speed", 1 / 3.6, ["km/h", "kph", "kmh"]);
    add("speed", 0.44704, ["mph"]);
    add("speed", 0.514444, ["kn", "knot", "knots"]);
    add("temp", 0, ["°c", "c", "celsius"]);
    add("temp", 0, ["°f", "f", "fahrenheit"]);
    add("temp", 0, ["k", "kelvin"]);
    return table;
})();

function round(n) {
    if (n === 0 || !isFinite(n)) return String(n);
    var digits = Math.abs(n) >= 1 ? 6 : 4;
    var s = String(Number(n.toPrecision(digits)));
    // 1234567 -> 1,234,567 (not in exponent form)
    if (s.indexOf("e") < 0) {
        var parts = s.split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        s = parts.join(".");
    }
    return s;
}

function convert(text) {
    var m = /^\s*(-?[\d.,]+)\s*([a-z°"'\/ ]+?)\s+(?:to|in|as|into|=)\s+([a-z°"'\/ ]+?)\s*$/i.exec(text);
    if (!m) return null;
    var value = parseFloat(m[1].replace(/,/g, ""));
    var from = units[m[2].toLowerCase().trim()], to = units[m[3].toLowerCase().trim()];
    if (isNaN(value) || !from || !to || from.kind !== to.kind) return null;
    var out;
    if (from.kind === "temp") {
        var c = from.label === "°c" ? value : from.label === "°f" ? (value - 32) * 5 / 9 : value - 273.15;
        out = to.label === "°c" ? c : to.label === "°f" ? c * 9 / 5 + 32 : c + 273.15;
    } else {
        out = value * from.factor / to.factor;
    }
    var shown = { "°c": "°C", "°f": "°F", "k": "K", "kb": "KB", "mb": "MB", "gb": "GB", "tb": "TB",
                  "kib": "KiB", "mib": "MiB", "gib": "GiB", "tib": "TiB" };
    var unitText = function (u) { return shown[u.label] || u.label; };
    return { value: round(out), text: round(out) + " " + unitText(to), from: round(value) + " " + unitText(from) };
}

// "15% of 80"
function percentOf(text) {
    var m = /^\s*([\d.]+)\s*%\s*of\s*([\d.,]+)\s*$/i.exec(text);
    if (!m) return null;
    var r = parseFloat(m[1]) / 100 * parseFloat(m[2].replace(/,/g, ""));
    return isFinite(r) ? round(r) : null;
}

// ---- Universal search (Meta+Space): everything at once, in sections. ----
// files: FileSearch results (src/filesearch.h). Returns rows; rows with
// kind "header" title a section and can't be picked.
function universal(query, apps, files) {
    var q = query.trim().toLowerCase();
    if (q.length === 0) return [];
    var rows = [];
    var top = null;

    // An answer (math, conversions) is always the top hit.
    var answer = calculate(query);
    var conv = answer === null ? convert(query) : null;
    var pct = answer === null && conv === null ? percentOf(query) : null;
    if (answer !== null)
        top = { kind: "calc", title: round(answer), subtitle: query.trim() + " =", glyph: "calculator", icon: "",
                hint: "Copy", value: String(answer), detail: "Calculator" };
    else if (conv !== null)
        top = { kind: "calc", title: conv.text, subtitle: conv.from + " =", glyph: "calculator", icon: "",
                hint: "Copy", value: conv.value.replace(/,/g, ""), detail: "Conversion" };
    else if (pct !== null)
        top = { kind: "calc", title: pct, subtitle: query.trim() + " =", glyph: "calculator", icon: "",
                hint: "Copy", value: pct.replace(/,/g, ""), detail: "Calculator" };

    var all = search(query, apps, 50).filter(function (r) { return r.kind !== "calc" && r.kind !== "web"; });
    var appRows = all.filter(function (r) { return r.kind === "app"; });
    var settingRows = all.filter(function (r) { return r.kind === "command"; });
    var actionRows = all.filter(function (r) { return r.kind === "system"; });
    var fileRows = (files || []).map(function (f) {
        return { kind: "file", title: f.name, subtitle: f.folder, icon: f.icon, glyph: f.isDir ? "folder" : "notes",
                 hint: "Open", url: f.url, path: f.path, isDir: f.isDir, fileKind: f.kind, size: f.size,
                 modified: f.modified, image: f.image, rank: f.rank - 6 };
    });

    if (!top) {
        // Otherwise the single best match of any kind, if it's a good one.
        var candidates = [appRows[0], fileRows[0], settingRows[0], actionRows[0]].filter(function (r) { return r && r.rank >= 70; });
        candidates.sort(function (a, b) { return b.rank - a.rank; });
        top = candidates[0] || null;
    }
    function section(title, list, max) {
        list = list.filter(function (r) { return r !== top; }).slice(0, max);
        if (list.length === 0) return;
        rows.push({ kind: "header", title: title });
        for (var i = 0; i < list.length; i++) rows.push(list[i]);
    }
    if (top) {
        rows.push({ kind: "header", title: "Top Hit" });
        rows.push(top);
    }
    section("Applications", appRows, 4);
    section("Files & Folders", fileRows, 5);
    section("Settings", settingRows, 3);
    section("Actions", actionRows, 3);
    rows.push({ kind: "header", title: "Web" });
    rows.push({ kind: "web", title: "Search the web for “" + query.trim() + "”", subtitle: "DuckDuckGo",
                icon: "", glyph: "globe", hint: "Search",
                url: "https://duckduckgo.com/?q=" + encodeURIComponent(query.trim()) });
    return rows;
}
