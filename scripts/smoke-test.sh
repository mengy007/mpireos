#!/usr/bin/env bash
# Boots an MpireOS ISO in QEMU and waits for the live desktop to start.
# Usage: scripts/smoke-test.sh path/to.iso [timeout-seconds]
# Passes when the image prints MPIREOS_DESKTOP_OK on its serial console.
set -euo pipefail
iso="$1"
timeout="${2:-1200}"
log="${SERIAL_LOG:-serial.log}"
: > "$log"

accel=(-accel tcg)
if [[ -w /dev/kvm ]]; then accel=(-enable-kvm -cpu host); fi

qemu-system-x86_64 "${accel[@]}" -m 4096 -smp 2 \
    -cdrom "$iso" -boot d \
    -vga std -display none \
    -serial "file:$log" \
    -nic user,model=virtio-net-pci &
qemu=$!
trap 'kill $qemu 2>/dev/null || true' EXIT

for ((t = 0; t < timeout; t += 5)); do
    if grep -q MPIREOS_DESKTOP_OK "$log"; then
        echo "PASS: desktop started after ~${t}s"
        exit 0
    fi
    if grep -q MPIREOS_DESKTOP_FAIL "$log"; then
        echo "FAIL: the desktop did not start"
        grep -a MPIREOS_ "$log" || true
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
tail -n 80 "$log"
exit 1
