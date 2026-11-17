.pragma library
// Outline icons for MpireOS: 24x24 grid, 1.5 px strokes, round caps and joins.
// Drawn for MpireOS (design-system.md, Iconography). Filled icons start with "fill:".
var paths = {
    search: "<circle cx='11' cy='11' r='7'/><path d='M20 20l-3.6-3.6'/>",
    bell: "<path d='M6 9a6 6 0 0 1 12 0c0 6 2.5 8 2.5 8h-17S6 15 6 9'/><path d='M10.3 20.5a2 2 0 0 0 3.4 0'/>",
    wifi: "<path d='M4.9 12.5a10 10 0 0 1 14.2 0'/><path d='M2 9.2a14.5 14.5 0 0 1 20 0'/><path d='M8 15.8a5.5 5.5 0 0 1 8 0'/><path d='M12 19.5h.01'/>",
    sliders: "<path d='M4 7h9M17 7h3M4 12h3M11 12h9M4 17h11M19 17h1'/><circle cx='15' cy='7' r='2'/><circle cx='9' cy='12' r='2'/><circle cx='17' cy='17' r='2'/>",
    battery: "<rect x='2.5' y='7' width='17' height='10' rx='2.5'/><path d='M22 10.5v3'/><path d='M5.5 10v4M8.5 10v4M11.5 10v4M14.5 10v4'/>",
    folder: "<path d='M3.5 7.5a2 2 0 0 1 2-2h3.8l2 2h7.2a2 2 0 0 1 2 2v7.5a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z'/>",
    image: "<rect x='3.5' y='3.5' width='17' height='17' rx='3.5'/><circle cx='9' cy='9.5' r='1.8'/><path d='M20.5 15.5l-4.5-4.5-9.5 9.5'/>",
    play: "fill:<path d='M8 5.2v13.6a1 1 0 0 0 1.5.86l11-6.8a1 1 0 0 0 0-1.72l-11-6.8A1 1 0 0 0 8 5.2z'/>",
    refresh: "<path d='M20 11a8 8 0 0 0-14.3-4.7L4 8'/><path d='M4 4v4h4'/><path d='M4 13a8 8 0 0 0 14.3 4.7L20 16'/><path d='M20 20v-4h-4'/>",
    grid: "<rect x='4' y='4' width='6.5' height='6.5' rx='1.8'/><rect x='13.5' y='4' width='6.5' height='6.5' rx='1.8'/><rect x='4' y='13.5' width='6.5' height='6.5' rx='1.8'/><rect x='13.5' y='13.5' width='6.5' height='6.5' rx='1.8'/>",
    settings: "<circle cx='12' cy='12' r='3'/><path d='M12 3.5v2.2M12 18.3v2.2M3.5 12h2.2M18.3 12h2.2M6 6l1.6 1.6M16.4 16.4L18 18M6 18l1.6-1.6M16.4 7.6L18 6'/><circle cx='12' cy='12' r='6.3'/>",
    headphones: "<path d='M4 18v-5.5a8 8 0 0 1 16 0V18'/><rect x='3.5' y='14' width='4.5' height='6.5' rx='1.8'/><rect x='16' y='14' width='4.5' height='6.5' rx='1.8'/>",
    globe: "<circle cx='12' cy='12' r='8.5'/><path d='M3.5 12h17'/><path d='M12 3.5c2.4 2.3 3.6 5.1 3.6 8.5s-1.2 6.2-3.6 8.5c-2.4-2.3-3.6-5.1-3.6-8.5s1.2-6.2 3.6-8.5z'/>",
    terminal: "<rect x='3.5' y='4.5' width='17' height='15' rx='3'/><path d='M7.5 10l3 2.5-3 2.5M12.5 15.5h4'/>",
    notes: "<rect x='5' y='3.5' width='14' height='17' rx='2.5'/><path d='M8.5 8.5h7M8.5 12h7M8.5 15.5h4.5'/>",
    power: "<path d='M12 3.5v8'/><path d='M6.6 6.8a7.5 7.5 0 1 0 10.8 0'/>",
    arrowRight: "<path d='M5 12h14M13.5 6.5L19 12l-5.5 5.5'/>",
    focus: "<path d='M4 8.5V6.5a2.5 2.5 0 0 1 2.5-2.5h2M15.5 4h2A2.5 2.5 0 0 1 20 6.5v2M20 15.5v2a2.5 2.5 0 0 1-2.5 2.5h-2M8.5 20h-2A2.5 2.5 0 0 1 4 17.5v-2'/><circle cx='12' cy='12' r='3'/>",
    expand: "<path d='M7 17L17 7M9 7h8v8'/>",
    sparkle: "fill:<path d='M12 3c.5 4.2 2.6 6.4 7 7-4.4.6-6.5 2.8-7 7-.5-4.2-2.6-6.4-7-7 4.4-.6 6.5-2.8 7-7z'/>",
    chevronDown: "<path d='M7 10l5 5 5-5'/>",
    user: "<circle cx='12' cy='8.5' r='3.8'/><path d='M4.5 20a7.5 7.5 0 0 1 15 0'/>",
    lock: "<rect x='5' y='10.5' width='14' height='10' rx='2.5'/><path d='M8 10.5V8a4 4 0 0 1 8 0v2.5'/>",
    moon: "<path d='M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z'/>",
    keyboard: "<rect x='2.5' y='6' width='19' height='12' rx='2.5'/><path d='M6 10h.01M9.5 10h.01M13 10h.01M16.5 10h.01M7.5 14h9'/>",
    calendar: "<rect x='3.5' y='5' width='17' height='15.5' rx='2.5'/><path d='M3.5 10h17M8 3v4M16 3v4'/>",
    logo: "<path d='M6.5 16.5V8.5l5.5 4.5 5.5-4.5v8'/>",
    volume: "<path d='M4 9.5h3l4.5-4v13l-4.5-4H4z'/><path d='M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11'/>",
    volumeMute: "<path d='M4 9.5h3l4.5-4v13l-4.5-4H4z'/><path d='M16 9.5l5 5M21 9.5l-5 5'/>",
    sun: "<circle cx='12' cy='12' r='3.8'/><path d='M12 3v1.8M12 19.2V21M3 12h1.8M19.2 12H21M5.6 5.6l1.3 1.3M17.1 17.1l1.3 1.3M5.6 18.4l1.3-1.3M17.1 6.9l1.3-1.3'/>",
    logOut: "<path d='M14 4.5H7a2.5 2.5 0 0 0-2.5 2.5v10A2.5 2.5 0 0 0 7 19.5h7'/><path d='M11 12h9.5M17 8.5l3.5 3.5-3.5 3.5'/>",
    x: "<path d='M7 7l10 10M17 7L7 17'/>",
    wifiOff: "<path d='M8 15.8a5.5 5.5 0 0 1 8 0M12 19.5h.01'/><path d='M4 4l16 16'/><path d='M2 9.2a14.5 14.5 0 0 1 5-3.2M10.5 5.1A14.5 14.5 0 0 1 22 9.2M19.1 12.5a10 10 0 0 0-3.2-2.2'/>",
    bellOff: "<path d='M8.5 4.2A6 6 0 0 1 18 9c0 3 .6 5 1.3 6.3M17 17H3.5S6 15 6 9c0-.5 0-1 .2-1.5'/><path d='M10.3 20.5a2 2 0 0 0 3.4 0'/><path d='M3.5 3.5l17 17'/>",
    calculator: "<rect x='5' y='3' width='14' height='18' rx='2.5'/><path d='M8.5 7.5h7M8.5 12h.01M12 12h.01M15.5 12h.01M8.5 15.5h.01M12 15.5h.01M15.5 15.5h.01'/>",
    chevronRight: "<path d='M10 7l5 5-5 5'/>",
    ethernet: "<rect x='4' y='5' width='16' height='11' rx='2'/><path d='M8 16v3h8v-3M8 9v2.5M11 9v2.5M14 9v2.5'/>"
};

function url(name, color, weight) {
    var p = paths[name] || paths.grid;
    var w = weight || 1.6;
    var filled = p.indexOf("fill:") === 0;
    if (filled) p = p.substring(5);
    var c = String(color);
    var attrs = filled
        ? "fill='" + c + "' stroke='none'"
        : "fill='none' stroke='" + c + "' stroke-width='" + w + "' stroke-linecap='round' stroke-linejoin='round'";
    return "data:image/svg+xml;utf8," + encodeURIComponent(
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' " + attrs + ">" + p + "</svg>");
}
