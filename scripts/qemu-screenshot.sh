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
