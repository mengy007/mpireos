#!/usr/bin/env bash
# End-to-end install test under UEFI (OVMF):
#   1. Boot the ISO with mpire.autoinstall, which installs MpireOS to a blank disk
#      using the bundled CI plan and powers off.
#   2. Boot the installed disk on its own and wait for the login screen.
# Usage: scripts/install-test.sh path/to.iso [timeout-seconds-per-phase]
set -euo pipefail
iso="$(realpath "$1")"
timeout="${2:-2400}"
work="${WORK_DIR:-$(mktemp -d)}"
mkdir -p "$work"
install_log="${INSTALL_LOG:-$work/install-serial.log}"
boot_log="${BOOT_LOG:-$work/installed-serial.log}"

ovmf_code=""; ovmf_vars=""
for dir in /usr/share/OVMF /usr/share/edk2/x64 /usr/share/edk2-ovmf/x64; do
    for c in OVMF_CODE_4M.fd OVMF_CODE.4m.fd OVMF_CODE.fd; do
        [[ -z $ovmf_code && -f $dir/$c ]] && ovmf_code="$dir/$c"
    done
    for v in OVMF_VARS_4M.fd OVMF_VARS.4m.fd OVMF_VARS.fd; do
        [[ -z $ovmf_vars && -f $dir/$v ]] && ovmf_vars="$dir/$v"
    done
done
[[ -n $ovmf_code && -n $ovmf_vars ]] || { echo "OVMF firmware not found" >&2; exit 1; }
cp "$ovmf_vars" "$work/vars.fd"

accel=(-accel tcg)
if [[ -w /dev/kvm ]]; then accel=(-enable-kvm -cpu host); fi
common=("${accel[@]}" -m 4096 -smp 2 -vga std -display none
        -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code"
        -drive "if=pflash,format=raw,file=$work/vars.fd"
        -drive "file=$work/disk.qcow2,if=virtio,format=qcow2"
        -nic user,model=virtio-net-pci)

qemu-img create -q -f qcow2 "$work/disk.qcow2" 24G

# Boot the ISO's kernel directly so we can add mpire.autoinstall to its command line.
label="$(blkid -o value -s LABEL "$iso")"
xorriso -osirrox on -indev "$iso" \
    -extract /arch/boot/x86_64/vmlinuz-linux "$work/vmlinuz" \
    -extract /arch/boot/x86_64/initramfs-linux.img "$work/initramfs.img" >/dev/null 2>&1

wait_for() {  # log ok-marker fail-marker pid
    local log=$1 ok=$2 fail=$3 pid=$4 t
    for ((t = 0; t < timeout; t += 5)); do
        grep -qa "$ok" "$log" && { echo "  ok after ~${t}s"; return 0; }
        grep -qaE "$fail|Falling back to interactive prompt|Kernel panic" "$log" && { echo "  FAIL"; grep -a "MPIREOS_" "$log" | tail -n 60; return 1; }
        kill -0 "$pid" 2>/dev/null || { echo "  QEMU exited"; tail -n 60 "$log"; return 1; }
        sleep 5
    done
    echo "  timed out after ${timeout}s"; tail -n 60 "$log"; return 1
}

echo "==> Phase 1: unattended install"
: > "$install_log"
# The ISO is attached as a second virtio disk (it is a hybrid image), so the target
# stays /dev/vda; under OVMF the emulated CD drive was not found by the initramfs.
qemu-system-x86_64 "${common[@]}" -drive "file=$iso,if=virtio,format=raw,readonly=on" \
    -kernel "$work/vmlinuz" -initrd "$work/initramfs.img" \
    -append "archisobasedir=arch archisolabel=$label mpire.autoinstall console=tty0 console=ttyS0,115200" \
    -serial "file:$install_log" &
qemu=$!
wait_for "$install_log" MPIREOS_INSTALL_OK MPIREOS_INSTALL_FAIL $qemu || { kill $qemu 2>/dev/null; exit 1; }
grep -a "MPIREOS_INSTALL {" "$install_log" | sed 's/^.*MPIREOS_INSTALL /  /' || true
for _ in $(seq 1 60); do kill -0 $qemu 2>/dev/null || break; sleep 2; done
kill $qemu 2>/dev/null || true

echo "==> Phase 2: boot the installed system"
: > "$boot_log"
qemu-system-x86_64 "${common[@]}" -serial "file:$boot_log" &
qemu=$!
trap 'kill $qemu 2>/dev/null || true' EXIT
wait_for "$boot_log" MPIREOS_GREETER_OK MPIREOS_DESKTOP_FAIL $qemu
echo "PASS: installed system boots to the login screen"
