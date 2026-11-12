#!/usr/bin/env bash
# Boots an MpireOS ISO in QEMU and waits for the live desktop to start.
# Usage: scripts/smoke-test.sh path/to.iso [timeout-seconds]
# Passes when the image prints MPIREOS_DESKTOP_OK and MPIREOS_SETUP_OK (the
# installer opened by itself) on its serial console.
set -euo pipefail
iso="$1"
timeout="${2:-1200}"
log="${SERIAL_LOG:-serial.log}"
shot="$(realpath -m "${SCREENSHOT:-live-desktop.ppm}")"
monitor="$(mktemp -u /tmp/qemu-monitor.XXXXXX)"
: > "$log"

accel=(-accel tcg)
if [[ -w /dev/kvm ]]; then accel=(-enable-kvm -cpu host); fi

qemu-system-x86_64 "${accel[@]}" -m 4096 -smp 2 \
    -cdrom "$iso" -boot d \
    -vga std -display none \
    -serial "file:$log" \
    -monitor "unix:$monitor,server,nowait" \
    -nic user,model=virtio-net-pci &
qemu=$!
trap 'kill $qemu 2>/dev/null || true' EXIT

# Saves what the screen shows to $shot (PPM), and prints it gzipped and
# base64-encoded between markers so it can be read from the CI log too.
screenshot() {
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

for ((t = 0; t < timeout; t += 5)); do
    if grep -q MPIREOS_DESKTOP_OK "$log" && grep -q MPIREOS_SETUP_OK "$log"; then
        echo "PASS: desktop and installer started after ~${t}s"
        grep -a MPIREOS_SETUP_LOG "$log" || true
        screenshot
        exit 0
    fi
    if grep -q -e MPIREOS_DESKTOP_FAIL -e MPIREOS_SETUP_FAIL "$log"; then
        echo "FAIL: the desktop or the installer did not start"
        grep -a MPIREOS_ "$log" || true
        screenshot
        exit 1
    fi
    if ! kill -0 $qemu 2>/dev/null; then
        echo "FAIL: QEMU exited early"
        tail -n 50 "$log"
        exit 1
    fi
    sleep 5
done
echo "FAIL: timed out after ${timeout}s"
screenshot
tail -n 80 "$log"
exit 1
