#!/usr/bin/env bash
# Boots an MpireOS ISO in QEMU and waits for the live desktop to start.
# Usage: scripts/smoke-test.sh path/to.iso [timeout-seconds]
# Passes when the image prints MPIREOS_DESKTOP_OK (Mpire Desktop's shell is up)
# and MPIREOS_SETUP_OK (the installer opened by itself) on its serial console.
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
    -fw_cfg name=opt/mpireos/ci,string=1 \
    -nic user,model=virtio-net-pci &
qemu=$!
trap 'kill $qemu 2>/dev/null || true' EXIT

source "$(dirname "$0")/qemu-screenshot.sh"
screenshot() { qemu_screenshot "$monitor" "$shot"; }

for ((t = 0; t < timeout; t += 5)); do
    if grep -q MPIREOS_DESKTOP_OK "$log" && grep -q MPIREOS_SETUP_OK "$log"; then
        echo "PASS: desktop and installer started after ~${t}s"
        grep -a MPIREOS_SETUP_LOG "$log" || true
        screenshot
        # Close the installer (Alt+F4) to see the desktop behind it.
        qemu_key "$monitor" alt-f4
        sleep 8
        qemu_screenshot "$monitor" "${shot%.ppm}-desktop.ppm"
        # The boot check then opens an app (System Settings) to show window styling.
        for ((w = 0; w < 120; w += 5)); do
            grep -q MPIREOS_APP_OPENED "$log" && break
            sleep 5
        done
        qemu_screenshot "$monitor" "${shot%.ppm}-app.ppm"
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
