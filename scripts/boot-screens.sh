#!/usr/bin/env bash
# Screenshots of every boot stage, to review MpireOS's boot look:
#   bios-menu, bios-splash        the ISO on legacy BIOS (SeaBIOS, SYSLINUX menu)
#   uefi-menu, uefi-splash        the ISO on UEFI (OVMF, GRUB menu)
#   installed-menu, installed-snapshots, installed-splash, installed-login
#                                 an installed disk (GRUB menu opened with F4)
# Usage: scripts/boot-screens.sh path/to.iso out-dir [install-work-dir]
#   install-work-dir: scripts/install-test.sh's WORK_DIR (disk.qcow2, vars.fd).
# Screenshots are saved as out-dir/boot-*.ppm and printed to the log (see
# qemu-screenshot.sh). This is for review, not a pass/fail test: a stage it
# couldn't catch is reported and skipped.
set -uo pipefail
iso="$(realpath "$1")"
out="$(realpath -m "$2")"
install_work="${3:-}"
mkdir -p "$out"
source "$(dirname "$0")/qemu-screenshot.sh"

accel=(-accel tcg)
if [[ -w /dev/kvm ]]; then accel=(-enable-kvm -cpu host); fi
ovmf_code=""; ovmf_vars=""
for dir in /usr/share/OVMF /usr/share/edk2/x64 /usr/share/edk2-ovmf/x64; do
    for c in OVMF_CODE_4M.fd OVMF_CODE.4m.fd OVMF_CODE.fd; do [[ -z $ovmf_code && -f $dir/$c ]] && ovmf_code="$dir/$c"; done
    for v in OVMF_VARS_4M.fd OVMF_VARS.4m.fd OVMF_VARS.fd; do [[ -z $ovmf_vars && -f $dir/$v ]] && ovmf_vars="$dir/$v"; done
done

monitor="$out/monitor.sock"
qemu=""
start_vm() {  # serial-log qemu-args...
    local log=$1; shift
    : > "$log"
    rm -f "$monitor"
    qemu-system-x86_64 "${accel[@]}" -m 4096 -smp 2 -vga std -display none \
        -serial "file:$log" -monitor "unix:$monitor,server,nowait" \
        -nic user,model=virtio-net-pci "$@" &
    qemu=$!
    for _ in $(seq 1 50); do [[ -S $monitor ]] && break; sleep 0.2; done
}
stop_vm() { kill "$qemu" 2>/dev/null; wait "$qemu" 2>/dev/null; qemu=""; }
trap stop_vm EXIT

grab() { python3 - "$monitor" "$1" <<'PY'
import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1])
s.sendall(f"screendump {sys.argv[2]}\n".encode()); time.sleep(1.5); s.close()
PY
}

# classify <ppm>: prints "splash" for the MpireOS splash (the teal mark a little
# above center and nothing else teal at the spinner's height but the spinner),
# "menu" for a themed boot menu (the mark near the top, a white card in the
# middle), else "other".
classify() { python3 - "$1" <<'PY'
import sys
def load(path):
    with open(path, "rb") as f:
        data = f.read()
    parts, i = [], 0
    while len(parts) < 4:
        while data[i:i+1].isspace(): i += 1
        if data[i:i+1] == b"#":
            while data[i:i+1] != b"\n": i += 1
            continue
        j = i
        while not data[j:j+1].isspace(): j += 1
        parts.append(data[i:j]); i = j
    w, h = int(parts[1]), int(parts[2])
    return w, h, data[i+1:]
try:
    w, h, px = load(sys.argv[1])
except Exception:
    print("other"); sys.exit()
def pixel(x, y):
    o = (y * w + x) * 3
    return px[o], px[o+1], px[o+2]
def share(x0, y0, x1, y1, test, step=3):
    n = hit = 0
    for y in range(max(0, y0), min(h, y1), step):
        for x in range(max(0, x0), min(w, x1), step):
            n += 1; hit += test(*pixel(x, y))
    return hit / max(n, 1)
teal = lambda r, g, b: g > r + 40 and b > r + 30 and r < 90
light = lambda r, g, b: r > 200 and g > 210 and b > 210
cx = w // 2
mark = share(cx - 30, int(h * 0.36), cx + 30, int(h * 0.44), teal)
bg = share(0, 0, w, h, light, 9)
card = share(cx - 100, int(h * 0.45), cx + 100, int(h * 0.55), lambda r, g, b: r > 245 and g > 245 and b > 245)
top_mark = share(cx - 20, int(h * 0.07), cx + 20, int(h * 0.22), teal)
if mark > 0.4 and bg > 0.8:
    print("splash")
elif card > 0.4 and top_mark > 0.2 and bg > 0.7:
    print("menu")
else:
    print("other")
PY
}

# shoot_menu <name> <serial-log> <text>: waits for the boot menu (its text on
# the serial console), then saves a screenshot.
shoot_menu() {
    local name=$1 log=$2 text=$3
    for _ in $(seq 1 120); do grep -qa "$text" "$log" && break; sleep 0.5; done
    sleep 1.5
    grab "$out/boot-$name.ppm"
    echo "boot-$name: $(classify "$out/boot-$name.ppm")"
}

# shoot_splash <name> <seconds>: screenshots every 2 s and keeps the second
# frame that shows the splash (the first can be mid fade-in).
shoot_splash() {
    local name=$1 seconds=$2 seen=0 t
    for ((t = 0; t < seconds; t += 2)); do
        grab "$out/frame.ppm"
        [[ $t -eq 10 ]] && cp "$out/frame.ppm" "$out/boot-$name-at10s.ppm"
        if [[ $(classify "$out/frame.ppm") == splash ]]; then
            seen=$((seen + 1))
            cp "$out/frame.ppm" "$out/boot-$name.ppm"
            [[ $seen -ge 2 ]] && break
        fi
        sleep 0.5
    done
    rm -f "$out/frame.ppm"
    if [[ $seen -gt 0 ]]; then
        echo "boot-$name: splash after ~${t}s"; rm -f "$out/boot-$name-at10s.ppm"
    else
        echo "boot-$name: no splash seen in ${seconds}s (boot-$name-at10s shows the screen 10 s in)"
    fi
}

print_shots() {
    local f
    for f in "$@"; do [[ -s $out/boot-$f.ppm ]] && qemu_screenshot_print "$out/boot-$f.ppm"; done
}

echo "==> ISO on BIOS"
start_vm "$out/boot-bios-serial.log" -cdrom "$iso" -boot d
shoot_menu bios-menu "$out/boot-bios-serial.log" "Start MpireOS"
qemu_key "$monitor" ret
shoot_splash bios-splash 120
stop_vm

if [[ -n $ovmf_code ]]; then
    echo "==> ISO on UEFI"
    cp "$ovmf_vars" "$out/vars.fd"
    # Attached as a disk (it's a hybrid image): the initramfs finds it there on OVMF.
    start_vm "$out/boot-uefi-serial.log" \
        -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code" -drive "if=pflash,format=raw,file=$out/vars.fd" \
        -drive "file=$iso,if=virtio,format=raw,readonly=on"
    shoot_menu uefi-menu "$out/boot-uefi-serial.log" "Start MpireOS"
    qemu_key "$monitor" ret
    shoot_splash uefi-splash 120
    stop_vm
fi

if [[ -n $install_work && -f $install_work/disk.qcow2 && -n $ovmf_code ]]; then
    echo "==> Installed system"
    log="$out/boot-installed-serial.log"
    start_vm "$log" \
        -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code" -drive "if=pflash,format=raw,file=$install_work/vars.fd" \
        -drive "file=$install_work/disk.qcow2,if=virtio,format=qcow2"
    # The menu is hidden unless a key is pressed while GRUB waits (3 s): keep
    # pressing F4 (OVMF ignores it) until the themed menu shows.
    found=""
    for _ in $(seq 1 60); do
        qemu_key "$monitor" f4
        grab "$out/frame.ppm"
        if [[ $(classify "$out/frame.ppm") == menu ]]; then found=1; break; fi
    done
    if [[ -n $found ]]; then
        sleep 1
        grab "$out/boot-installed-menu.ppm"
        echo "boot-installed-menu: menu"
        # "MpireOS snapshots" is the last entry (firmware entries come before it).
        qemu_key "$monitor" end; qemu_key "$monitor" ret
        sleep 2
        grab "$out/boot-installed-snapshots.ppm"
        qemu_key "$monitor" esc
        sleep 1
        qemu_key "$monitor" home; qemu_key "$monitor" ret
    else
        echo "boot-installed-menu: menu not caught"
    fi
    rm -f "$out/frame.ppm"
    shoot_splash installed-splash 120
    for _ in $(seq 1 120); do grep -qa MPIREOS_GREETER_OK "$log" && break; sleep 2; done
    grab "$out/boot-installed-login.ppm"
    stop_vm
fi

print_shots bios-menu bios-splash bios-splash-at10s uefi-menu uefi-splash uefi-splash-at10s \
    installed-menu installed-snapshots installed-splash installed-login
exit 0
