# Sourced by the QEMU test scripts.
# qemu_screenshot <monitor-socket> <out.ppm>: saves what the VM's screen shows,
# and prints it gzipped and base64-encoded between markers, so it can be read
# from the CI log as well as from the artifact.
qemu_screenshot() {
    local monitor=$1 shot=$2
    python3 - "$monitor" "$shot" <<'PY' || true
import socket, sys, time
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
s.sendall(f"screendump {sys.argv[2]}\n".encode())
time.sleep(3)
s.close()
PY
    if [[ -s $shot ]]; then
        echo "SCREENSHOT_BEGIN $(basename "$shot").gz"
        gzip -c "$shot" | base64 -w 0
        echo
        echo "SCREENSHOT_END"
    fi
}

# qemu_key <monitor-socket> <key>: presses a key combination, e.g. alt-f4.
qemu_key() {
    python3 - "$1" "$2" <<'PY' || true
import socket, sys, time
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
s.sendall(f"sendkey {sys.argv[2]}\n".encode())
time.sleep(1)
s.close()
PY
}

# qemu_pointer <qmp-socket> <x> <y>: puts an absolute pointer (usb-tablet) at
# x, y, each 0-32767 across the screen. Uses QMP: HMP's mouse_move did not
# move the pointer in the guest.
qemu_pointer() {
    python3 - "$1" "$2" "$3" <<'PY' || true
import json, socket, sys, time
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
f = s.makefile("rw")
f.readline()                                   # greeting
def call(cmd, **args):
    f.write(json.dumps({"execute": cmd, "arguments": args} if args else {"execute": cmd}) + "\n")
    f.flush()
    return f.readline().strip()
call("qmp_capabilities")
print("qmp:", call("input-send-event", events=[
    {"type": "abs", "data": {"axis": "x", "value": int(sys.argv[2])}},
    {"type": "abs", "data": {"axis": "y", "value": int(sys.argv[3])}}]))
time.sleep(1)
s.close()
PY
}

# qemu_click <qmp-socket> <x-px> <y-px> [left|right] [screen-ppm]: moves the
# pointer to pixel x, y and clicks. Pixels are converted to usb-tablet units
# using the size of the screen in screen-ppm (a screendump), else 1280x800.
qemu_click() {
    python3 - "$1" "$2" "$3" "${4:-left}" "${5:-}" <<'PY' || true
import json, os, socket, sys, time
qmp, x, y, button, ppm = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4], sys.argv[5]
w, h = 1280, 800
if ppm and os.path.exists(ppm):
    with open(ppm, "rb") as f:
        fields = []
        while len(fields) < 3:
            line = f.readline()
            if not line.startswith(b"#"):
                fields += line.split()
        w, h = int(fields[1]), int(fields[2])
s = socket.socket(socket.AF_UNIX)
s.connect(qmp)
f = s.makefile("rw")
f.readline()
def call(cmd, **args):
    f.write(json.dumps({"execute": cmd, "arguments": args} if args else {"execute": cmd}) + "\n")
    f.flush()
    return f.readline().strip()
call("qmp_capabilities")
ax, ay = int(x * 32767 / (w - 1)), int(y * 32767 / (h - 1))
call("input-send-event", events=[{"type": "abs", "data": {"axis": "x", "value": ax}},
                                 {"type": "abs", "data": {"axis": "y", "value": ay}}])
time.sleep(0.4)
for down in (True, False):
    print("qmp click:", button, down, call("input-send-event", events=[{"type": "btn", "data": {"down": down, "button": button}}]))
    time.sleep(0.15)
time.sleep(0.5)
s.close()
PY
}
