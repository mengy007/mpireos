.pragma library
// MpireOS's own wallpapers, drawn by WallpaperLayer.qml (no image files):
// a diagonal wash from `from` to `to`, a soft glow, and broad light rings like
// the default backdrop. Colors come from the MpireOS palette (design-system.md).
// "fjord" (a moonlit lake, Fjord.qml) is Mpire Desktop's default; "mist" is
// the backdrop the installer and login screen use.
var builtIn = [
    { id: "mpire:fjord", name: "Night fjord", scene: "fjord", dark: true },
    { id: "mpire:mist", name: "Morning mist" },
    { id: "mpire:lagoon", name: "Lagoon", from: "#4DBDC0", to: "#094551", glow: "#B8ECEC", glowAt: [0.18, 0.12], ring: "#FFFFFF", ringOpacity: 0.22 },
    { id: "mpire:lavender", name: "Lavender", from: "#F5F2FC", to: "#C3B6EA", glow: "#FFFFFF", glowAt: [0.25, 0.2], ring: "#FFFFFF", ringOpacity: 0.5 },
    { id: "mpire:daybreak", name: "Daybreak", from: "#FDF4E6", to: "#F2B9C6", glow: "#FFF6DA", glowAt: [0.78, 0.18], ring: "#FFFFFF", ringOpacity: 0.45 },
    { id: "mpire:meadow", name: "Meadow", from: "#F1F7F2", to: "#9CC6AB", glow: "#FFFFFF", glowAt: [0.2, 0.15], ring: "#FFFFFF", ringOpacity: 0.42 },
    { id: "mpire:sky", name: "Open sky", from: "#F2F7FC", to: "#9DBCE4", glow: "#FFFFFF", glowAt: [0.7, 0.12], ring: "#FFFFFF", ringOpacity: 0.45 },
    { id: "mpire:sandstone", name: "Sandstone", from: "#FCF7EA", to: "#E2C79A", glow: "#FFFDF5", glowAt: [0.3, 0.2], ring: "#FFFFFF", ringOpacity: 0.4 },
    { id: "mpire:midnight", name: "Midnight", from: "#0B1F25", to: "#0E4A57", glow: "#269CA1", glowAt: [0.82, 0.86], ring: "#4DBDC0", ringOpacity: 0.16, dark: true }
];

// Solid colors offered in the picker.
var colors = [
    { color: "#E4EDEF", name: "Mist" },
    { color: "#F7F9FB", name: "Cloud" },
    { color: "#269CA1", name: "Teal" },
    { color: "#094551", name: "Deep teal" },
    { color: "#0B1F25", name: "Ink" },
    { color: "#A595D4", name: "Lavender" },
    { color: "#EEAEBF", name: "Rose" },
    { color: "#E6B072", name: "Apricot" },
    { color: "#8EB49B", name: "Sage" },
    { color: "#83A9D8", name: "Sky" }
];

function find(id) {
    for (var i = 0; i < builtIn.length; i++)
        if (builtIn[i].id === id) return builtIn[i];
    return null;
}

// "mpire" | "color" | "picture"
function kind(source) {
    if (source.indexOf("color:") === 0) return "color";
    if (source.indexOf("file:") === 0 || source.indexOf("/") === 0) return "picture";
    return "mpire";
}

function pictureUrl(source) {
    return source.indexOf("/") === 0 ? "file://" + source : source;
}
