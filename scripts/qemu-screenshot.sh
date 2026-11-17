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
    qemu_screenshot_print "$shot"
}

# qemu_screenshot_print <shot.ppm>: prints a saved screenshot to the log.
qemu_screenshot_print() {
    if [[ -s $1 ]]; then
        echo "SCREENSHOT_BEGIN $(basename "$1").gz"
        gzip -c "$1" | base64 -w 0
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
